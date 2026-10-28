--!strict
-- LondonServer.Jobs: the job framework (JOBS.md §1) and the first two jobs, Postman and Newsboy.
-- Jobs here: Postman, Newsboy, and the makers Baker and Carpenter (steps that use up `need` from the
-- bag and make `give`, tagged "made by" the player: SHOPS §3, §7).
-- A job is a station role (Shared.Stations; chosen in the role menu, and Identity applies the
-- switch cooldown): holding the role is being on duty. On duty the server hands out tasks, each a
-- list of steps: "goto" (reach a place) or "hold" (hold the prompt there for a few seconds). Pay
-- and XP come only from server-checked steps; pay rises Config.JOB_RANK_PAY a rank (Shared.Ranks)
-- and each job has an hourly cap (Config.JOBS[job].cap, kept in profile.limits). XP and ranks live
-- in Profiles.progress(player).jobs, so linked character slots share them.
--   Jobs.register(jobId, start(player) -> Task?)   more jobs (cabbie, lamplighter...) plug in here
--   Jobs.pay(player, jobId, pence, ref) -> paid     Jobs.addXp(player, jobId, xp)
--   Jobs.current(player) -> Task?                    Jobs.rankOf(player, jobId) -> rank
-- Remotes (Job domain, calls): Get, Hold { step }, Skip.
-- Pushes: Job.Task (the task and where you are in it), Job.Done { text }, Job.Off, Job.Notice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Money = require(Shared:WaitForChild("Money"))
local Items = require(Shared:WaitForChild("Items"))
local Roles = require(Shared:WaitForChild("Roles"))
local Ranks = require(Shared:WaitForChild("Ranks"))
local Kit = require(Shared:WaitForChild("Kit"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Counters = require(script.Parent:WaitForChild("Counters"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))
local World = require(script.Parent:WaitForChild("World"))
local Lots = require(script.Parent:WaitForChild("Lots"))

local Jobs = {}
Jobs.rng = Random.new()

export type Step = {
	kind: string, pos: Vector3, radius: number, seconds: number, text: string, action: string, pay: number?,
	need: { [string]: number }?, give: { [string]: number }?, -- items used up / made at this step
}
export type Task = { job: string, title: string, steps: { Step }, index: number, stepAt: number, pay: number, xp: number, ref: string }

local starters: { [string]: (Player) -> Task? } = {}
local tasks: { [Player]: Task } = {}
local duty: { [Player]: string } = {}
local shift: { [Player]: number } = {}
local lastSkip: { [Player]: number } = {}

function Jobs.register(jobId: string, start: (Player) -> Task?)
	starters[jobId] = start
end

function Jobs.current(player: Player): Task?
	return tasks[player]
end

local function record(player: Player, jobId: string): { [string]: number }?
	local prog = Profiles.progress(player)
	if not prog then
		return nil
	end
	local r = prog.jobs[jobId]
	if type(r) ~= "table" then
		r = { xp = 0, rank = 1, done = 0 }
		prog.jobs[jobId] = r
	end
	return r
end

function Jobs.rankOf(player: Player, jobId: string): number
	local r = record(player, jobId)
	return if r then r.rank else 1
end

-- Pays job money with the rank bonus, within the job's hourly cap. Returns what was paid.
function Jobs.pay(player: Player, jobId: string, pence: number, ref: string): number
	local p = Profiles.get(player)
	local def = Config.JOBS[jobId]
	if not p or not def or pence <= 0 then
		return 0
	end
	local hour = os.time() // 3600
	if p.limits.jobHour ~= hour then
		p.limits.jobHour = hour
		p.limits.jobPaid = {}
	end
	local paid = p.limits.jobPaid[jobId] or 0
	local amount = math.min(math.floor(pence * Ranks.payMultiplier(Jobs.rankOf(player, jobId)) + 0.5), def.cap - paid)
	if amount <= 0 then
		return 0
	end
	if not Economy.pay(player, amount, "job_pay", jobId .. ":" .. ref) then
		return 0
	end
	p.limits.jobPaid[jobId] = paid + amount
	shift[player] = (shift[player] or 0) + amount
	return amount
end

function Jobs.addXp(player: Player, jobId: string, xp: number)
	local r = record(player, jobId)
	if not r then
		return
	end
	r.xp += xp
	local rank = Ranks.rankFor(r.xp)
	if rank > r.rank then
		r.rank = rank
		Net.push(player, "Job", "Notice", { text = string.format("You're now rank %d. Pay is up to %d%%.", rank, math.floor(Ranks.payMultiplier(rank) * 100 + 0.5)) })
	end
end

local function view(player: Player): { [string]: any }
	local t = tasks[player]
	local job = duty[player]
	local r = if job then record(player, job) else nil
	local steps = {}
	if t then
		for k, s in t.steps do
			steps[k] = { kind = s.kind, pos = s.pos, radius = s.radius, seconds = s.seconds, text = s.text, action = s.action }
		end
	end
	return {
		job = job,
		title = if t then t.title else nil,
		steps = steps,
		index = if t then t.index else 0,
		rank = if r then r.rank else 1,
		xp = if r then r.xp else 0,
		nextXp = if r and r.rank < Config.JOB_MAX_RANK then Ranks.xpFor(r.rank + 1) else nil,
		shift = shift[player] or 0,
		shiftText = Money.format(shift[player] or 0),
	}
end

local function pushTask(player: Player)
	Net.push(player, "Job", "Task", view(player))
end

local function newTask(player: Player)
	local job = duty[player]
	local start = job and starters[job]
	if not job or not start then
		return
	end
	local t = start(player)
	if not t then
		tasks[player] = nil
		Net.push(player, "Job", "Notice", { text = "No work here just now; trying again shortly." })
		task.delay(Config.JOB_RETRY_SECONDS, function()
			if duty[player] == job and not tasks[player] then
				newTask(player)
			end
		end)
		pushTask(player)
		return
	end
	t.index, t.stepAt = 1, os.clock()
	tasks[player] = t
	pushTask(player)
end

local function complete(player: Player, t: Task)
	local paid = Jobs.pay(player, t.job, t.pay, t.ref)
	Jobs.addXp(player, t.job, t.xp)
	local r = record(player, t.job)
	if r then
		r.done += 1
	end
	Net.push(player, "Job", "Done", { text = string.format("%s done: %s, +%d XP.", t.title, Money.format(paid), t.xp) })
	tasks[player] = nil
	task.delay(1, function()
		if duty[player] == t.job and not tasks[player] then
			newTask(player)
		end
	end)
end

local function advance(player: Player)
	local t = tasks[player]
	if not t then
		return
	end
	local s = t.steps[t.index]
	if s.pay then
		Jobs.pay(player, t.job, s.pay, t.ref)
	end
	t.index += 1
	t.stepAt = os.clock()
	if t.index > #t.steps then
		complete(player, t)
	else
		pushTask(player)
	end
end

function Jobs.hold(player: Player, index: number): (boolean, string?)
	local t = tasks[player]
	local s = t and t.steps[index]
	if not t or not s or t.index ~= index or s.kind ~= "hold" then
		return false, "That isn't your next stop."
	end
	if not World.near(player, s.pos, s.radius) then
		return false, "You're not there yet."
	end
	if os.clock() - t.stepAt < s.seconds - 0.2 then
		return false, "Too quick."
	end
	-- making things: everything needed in the bag, room for what's made, then swap them
	for id, n in s.need or {} do
		if Inventory.count(player, id) < n then
			local it = Items.get(id)
			return false, string.format("You need %d × %s.", n, if it then it.name else id)
		end
	end
	for id, n in s.give or {} do
		if not Inventory.canAdd(player, id, n, nil, player.UserId) then
			return false, "Your bag is full."
		end
	end
	for id, n in s.need or {} do
		Inventory.remove(player, id, n)
	end
	local name = player:GetAttribute("RPName")
	for id, n in s.give or {} do
		Inventory.add(player, id, n, nil, player.UserId, if type(name) == "string" then name else player.DisplayName)
	end
	advance(player)
	return true
end

local function onRole(player: Player)
	local role = player:GetAttribute(Roles.ROLE_ATTR)
	local job = if type(role) == "string" and starters[role] then role else nil
	if duty[player] == job then
		return
	end
	duty[player] = job
	tasks[player] = nil
	shift[player] = 0
	if job then
		newTask(player)
	else
		Net.push(player, "Job", "Off", {})
	end
end

-- Postman: collect at the nearest post office, deliver to doors near it -----------------------
local function frontDoor(l: Lots.Lot): Vector3
	return Kit.toWorld(l.frame, l.w / 2, 3, -1.5)
end

-- Orders points by walking each time to the nearest one left.
local function route(from: Vector3, points: { any }, pos: (any) -> Vector3): { any }
	local left = table.clone(points)
	local out = {}
	local at = from
	while #left > 0 do
		local best, bestD = 1, math.huge
		for k, p in left do
			local d = (pos(p) - at).Magnitude
			if d < bestD then
				best, bestD = k, d
			end
		end
		local p = table.remove(left, best)
		table.insert(out, p)
		at = pos(p)
	end
	return out
end

local function nearestCounter(player: Player, pred: (Counters.Def) -> boolean): (Counters.Def?, Vector3?)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local here = if hrp and hrp:IsA("BasePart") then hrp.Position else Vector3.zero
	local best, bestPos, bestD = nil, nil, math.huge
	for _, def in Config.COUNTERS do
		local pos = Counters.position(def.id)
		local d = Counters.get(def.id)
		if pos and d and pred(d) and (pos - here).Magnitude < bestD then
			best, bestPos, bestD = d, pos, (pos - here).Magnitude
		end
	end
	return best, bestPos
end

local function postman(player: Player): Task?
	local def = Config.JOBS.Postman
	local office, at = nearestCounter(player, function(d)
		return d.kind == "bank" and string.sub(d.id, 1, 3) == "po_"
	end)
	if not office or not at then
		return nil
	end
	local near = {}
	for _, l in Lots.all() do
		if (frontDoor(l) - at).Magnitude <= def.range and l.part:GetAttribute("LotAddress") then
			table.insert(near, l)
		end
	end
	if #near < def.stops then
		return nil
	end
	local chosen = {}
	for _ = 1, def.stops do
		table.insert(chosen, table.remove(near, Jobs.rng:NextInteger(1, #near)))
	end
	local steps: { Step } = {
		{ kind = "hold", pos = at, radius = Config.COUNTER_RANGE, seconds = def.hold, text = "Collect the post at the " .. office.name, action = "Collect" },
	}
	for _, l in route(at, chosen, frontDoor) do
		table.insert(steps, { kind = "hold", pos = frontDoor(l), radius = 8, seconds = def.hold, text = "Deliver to " .. Lots.address(l.name), action = "Deliver" })
	end
	return { job = "Postman", title = "Round", steps = steps, index = 1, stepAt = 0, pay = def.pay, xp = def.xp, ref = office.id }
end

-- Newsboy: a bundle from the newsagent, sold on busy corners ---------------------------------
local function cornerPos(c: { [string]: any }): Vector3
	return World.ground(c.x, c.z) + Vector3.new(0, 3, 0)
end

local function newsboy(player: Player): Task?
	local def = Config.JOBS.Newsboy
	local at = Counters.position(def.depot)
	local agent = Counters.get(def.depot)
	if not at or not agent then
		return nil
	end
	local near = {}
	for _, c in Config.NEWSBOY_CORNERS do
		if (cornerPos(c) - at).Magnitude <= def.range then
			table.insert(near, c)
		end
	end
	if #near == 0 then
		return nil
	end
	local chosen = {}
	for _ = 1, math.min(def.corners, #near) do
		table.insert(chosen, table.remove(near, Jobs.rng:NextInteger(1, #near)))
	end
	local steps: { Step } = {
		{ kind = "hold", pos = at, radius = Config.COUNTER_RANGE, seconds = def.hold, text = string.format("Collect a bundle of %d papers at the %s", def.bundle, agent.name), action = "Collect" },
	}
	local left = def.bundle
	local ordered = route(at, chosen, cornerPos)
	for k, c in ordered do
		local copies = if k == #ordered then left else math.floor(def.bundle / #ordered)
		left -= copies
		table.insert(steps, {
			kind = "hold", pos = cornerPos(c), radius = 10, seconds = def.hold,
			text = string.format("Sell %d papers at %s", copies, c.name), action = "Sell", pay = copies * def.copyPay,
		})
	end
	return { job = "Newsboy", title = "Bundle", steps = steps, index = 1, stepAt = 0, pay = def.bundleBonus, xp = def.xp, ref = def.depot }
end

-- Makers: one step at their workplace, using up `need` and making `give` -------------------------
local function needText(need: { [string]: number }): string
	local parts = {}
	for id, n in need do
		local it = Items.get(id)
		table.insert(parts, string.format("%d × %s", n, if it then it.name else id))
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

local function maker(jobId: string, verb: string): (Player) -> Task?
	return function(_player: Player): Task?
		local def = Config.JOBS[jobId]
		local at = Counters.position(def.workplace)
		local place = Counters.get(def.workplace)
		if not at or not place then
			return nil
		end
		local give = def.give
		if def.makes then
			give = { [def.makes[Jobs.rng:NextInteger(1, #def.makes)]] = 1 }
		end
		local made = {}
		for id, n in give do
			local it = Items.get(id)
			table.insert(made, (if n > 1 then n .. " × " else "") .. (if it then it.name else id))
		end
		return {
			job = jobId, title = verb, index = 1, stepAt = 0, pay = def.pay, xp = def.xp, ref = def.workplace,
			steps = {
				{
					kind = "hold", pos = at, radius = Config.COUNTER_RANGE, seconds = def.hold, action = verb, need = def.need, give = give,
					text = string.format("%s %s at the %s (needs %s)", verb, table.concat(made, ", "), place.name, needText(def.need)),
				},
			},
		}
	end
end

function Jobs.init()
	Jobs.register("Postman", postman)
	Jobs.register("Newsboy", newsboy)
	Jobs.register("Baker", maker("Baker", "Bake"))
	Jobs.register("Carpenter", maker("Carpenter", "Make"))
	local V = Net.V
	Net.handle("Job", "Get", { call = true, rate = Config.JOB_RATE }, function(player)
		return view(player)
	end)
	Net.handle("Job", "Hold", { schema = { step = V.int(1, 100) }, rate = Config.JOB_RATE, call = true }, function(player, a)
		local good, why = Jobs.hold(player, a.step)
		if not good then
			return nil, why
		end
		return {}
	end)
	Net.handle("Job", "Skip", { call = true, rate = Config.JOB_RATE }, function(player)
		if not duty[player] then
			return nil, "You're not on duty."
		end
		if os.clock() - (lastSkip[player] or -math.huge) < Config.JOB_SKIP_SECONDS then
			return nil, "Finish this one first, or wait a little."
		end
		lastSkip[player] = os.clock()
		tasks[player] = nil
		newTask(player)
		return {}
	end)
	local function watch(player: Player)
		player:GetAttributeChangedSignal(Roles.ROLE_ATTR):Connect(function()
			onRole(player)
		end)
		onRole(player)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		tasks[p], duty[p], shift[p], lastSkip[p] = nil, nil, nil, nil
	end)
	-- "goto" steps finish themselves when you arrive
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, t in tasks do
				local s = t.steps[t.index]
				if s and s.kind == "goto" and World.near(player, s.pos, s.radius) then
					advance(player)
				end
			end
		end
	end)
end

return Jobs
