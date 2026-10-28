--!strict
-- LondonServer.Events: the event framework (EVENTS.md §1, §3, §4; TASKS T39). Per server.
-- An event is data in Config.EVENTS (where, steps, roles, rewards, trigger) plus optional hooks
-- here (Events.hook(id, { start, step, finish })). A run goes:
--   Announce (banner, a flag at the place, sign-up)  →  Gather (Config gather seconds)  →
--   Steps (each for its seconds; a host may advance)  →  Finish (rewards, the result).
-- Triggers: "host" (one of `hosts` roles, or the owner, starts it from the Events menu),
-- "schedule" (every `every` seconds of server time), "random" (about once per `mean` seconds with
-- `minPlayers` here), and decree = true (a lever in the Crown's decree menu, LondonServer.Decrees).
-- Rules: one major event at a time and Config.EVENT_MAJOR_GAP between them; minor events overlap;
-- a scheduled event due while a major one runs is skipped until its next time; `cooldown` per
-- event. Rewards: `pay` pence + `xp` (to their job) for those signed up and at the place at the
-- end; `spectator` pence + `memento` for anyone near for Config.EVENT_SPECTATE_SECONDS (once per
-- run); Daily.record(player, "event").
-- Remotes (Event domain, calls): Get, Start { id }, SignUp { id, role }, Leave { id },
--   Advance { id }, End { id }.
-- Pushes (everyone): Event.Announce { id, name, place, pos?, seconds, roles?, host? },
--   Event.Step { id, name, index, of, text, seconds }, Event.Finished { id, name, text };
--   Event.Notice { text } (to one player).
--   Events.start(id, host?) -> ok, why   Events.advance(id)   Events.finish(id, cancelled?)
--   Events.running(id) -> Run?   Events.hook(id, hooks)   Events.tick(dt) (each second)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local Collection = require(Shared:WaitForChild("Collection"))
local Palette = require(Shared:WaitForChild("Palette"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local World = require(script.Parent:WaitForChild("World"))
local Jobs = require(script.Parent:WaitForChild("Jobs"))
local Daily = require(script.Parent:WaitForChild("Daily"))
local WorldClock = require(script.Parent:WaitForChild("WorldClock"))
local Decrees = require(script.Parent:WaitForChild("Decrees"))
local Throne = require(script.Parent:WaitForChild("Throne"))

local Events = {}

export type Run = {
	id: string, def: { [string]: any }, host: Player?, phase: string, step: number, endsAt: number,
	signups: { [Player]: string }, seen: { [Player]: number }, flag: Instance?,
}
export type Hooks = {
	start: ((Run) -> ())?, step: ((Run, number) -> ())?, finish: ((Run, boolean) -> ())?,
	check: ((Player?) -> string?)?,
}

local runs: { [string]: Run } = {}
local lastRun: { [string]: number } = {} -- id -> os.clock() it last finished
local lastMajorEnd = -math.huge
local hooks: { [string]: Hooks } = {}
local scheduledSlot: { [string]: number } = {}

local function nameOf(p: Player): string
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

local function placeOf(def: { [string]: any }): Vector3?
	if type(def.x) ~= "number" or type(def.z) ~= "number" then
		return nil
	end
	return (World.ground(def.x, def.z))
end

function Events.hook(id: string, h: Hooks)
	hooks[id] = h
end

function Events.running(id: string): Run?
	return runs[id]
end

local function majorRunning(): Run?
	for _, r in runs do
		if r.def.major then
			return r
		end
	end
	return nil
end

local function isOwner(p: Player): boolean
	return Roles.staffLevel(p) >= Config.STAFF_LEVEL.ADMIN
end

-- Why `id` can't start now (for `host`, or automatically when host is nil), or nil.
function Events.whyNot(id: string, host: Player?): string?
	local def = Config.EVENTS[id]
	if not def then
		return "There's no such event."
	end
	if runs[id] then
		return "It's happening already."
	end
	if host and not isOwner(host) then
		local allowed = false
		for _, r in def.hosts or {} do
			if Roles.roleOf(host) == r then
				allowed = true
			end
		end
		if not allowed then
			return "You can't host that."
		end
	end
	if def.major then
		local m = majorRunning()
		if m then
			return m.def.name .. " is under way."
		end
		local gap = Config.EVENT_MAJOR_GAP - (os.clock() - lastMajorEnd)
		if gap > 0 then
			return string.format("Another occasion can begin in %d min.", math.ceil(gap / 60))
		end
	end
	local cd = (def.cooldown or 0) - (os.clock() - (lastRun[id] or -math.huge))
	if cd > 0 then
		return string.format("%s was held a short while ago; again in %d min.", def.name, math.ceil(cd / 60))
	end
	if #Players:GetPlayers() < (def.minPlayers or 0) then
		return "Not enough people here."
	end
	local h = hooks[id]
	if h and h.check then
		return h.check(host)
	end
	return nil
end

local function makeFlag(run: Run)
	local pos = placeOf(run.def)
	if not pos then
		return
	end
	local m = Instance.new("Model")
	m.Name = "Event_" .. run.id
	local pole = World.part({ Name = "Pole", Size = Vector3.new(0.3, 14, 0.3), CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)), Color = Palette.color("iron_black"), Material = Enum.Material.Metal })
	pole.Parent = m
	local flag = World.part({ Name = "Flag", Size = Vector3.new(3, 2, 0.1), CFrame = CFrame.new(pos + Vector3.new(1.6, 12.8, 0)), Color = Palette.color("livery_royal_red"), Material = Enum.Material.Fabric, CanCollide = false })
	flag.Parent = m
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 40)
	bb.StudsOffset = Vector3.new(0, 9, 0)
	bb.MaxDistance = 400
	bb.Parent = pole
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GaramondBold
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(240, 228, 200)
	l.TextStrokeTransparency = 0.4
	l.Text = run.def.name
	l.Parent = bb
	m.Parent = World.folder("Events")
	run.flag = m
end

local function signupList(run: Run): { { [string]: any } }
	local out = {}
	for _, role in run.def.roles or {} do
		local names = {}
		for p, r in run.signups do
			if r == role.id and p.Parent == Players then
				table.insert(names, nameOf(p))
			end
		end
		table.sort(names)
		table.insert(out, { id = role.id, name = role.name, max = role.max, names = names })
	end
	return out
end

local function announce(run: Run)
	Net.pushAll("Event", "Announce", {
		id = run.id,
		name = run.def.name,
		place = run.def.place,
		pos = placeOf(run.def),
		seconds = math.max(0, math.ceil(run.endsAt - os.clock())),
		roles = signupList(run),
		host = if run.host then nameOf(run.host) else nil,
	})
end

function Events.start(id: string, host: Player?): (boolean, string?)
	local why = Events.whyNot(id, host)
	if why then
		return false, why
	end
	local def = Config.EVENTS[id]
	local run: Run = { id = id, def = def, host = host, phase = "gather", step = 0, endsAt = os.clock() + (def.gather or 0), signups = {}, seen = {} }
	runs[id] = run
	makeFlag(run)
	local h = hooks[id]
	if h and h.start then
		h.start(run)
	end
	announce(run)
	if def.major then
		Throne.proclaim(string.format("%s at %s%s.", def.name, def.place, if (def.gather or 0) > 0 then string.format(", in %d minutes", math.max(1, math.floor((def.gather or 0) / 60 + 0.5))) else ""))
	end
	if (def.gather or 0) <= 0 then
		Events.advance(id)
	end
	return true
end

local function reward(run: Run, p: Player, pence: number, xp: number, why: string)
	if pence > 0 then
		Economy.pay(p, pence, "event", run.id)
	end
	if xp > 0 then
		local job = Roles.roleOf(p)
		if Config.JOBS[job] then
			Jobs.addXp(p, job, xp)
		end
	end
	Daily.record(p, "event")
	local it = run.def.memento and Collection.BY_ID[run.def.memento]
	local profile = Profiles.get(p)
	local got = ""
	if it and profile then
		local n = (profile.collection[it.id] or 0) + 1
		profile.collection[it.id] = n
		got = string.format(" %s for your collection book%s.", it.name, if n == 1 then " (new)" else "")
	end
	Net.push(p, "Event", "Notice", { text = why .. got })
end

-- Ends a run: rewards (unless cancelled before any step), then the gap and cooldown.
function Events.finish(id: string, cancelled: boolean?)
	local run = runs[id]
	if not run then
		return
	end
	runs[id] = nil
	local def = run.def
	local held = not cancelled or run.step > 0
	local h = hooks[id]
	if h and h.finish then
		h.finish(run, held)
	end
	if held then
		local pos = placeOf(def)
		local paid: { [Player]: boolean } = {}
		for p, _ in run.signups do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			local there = pos == nil or (hrp and hrp:IsA("BasePart") and (hrp.Position - pos).Magnitude <= (def.radius or 60) * 1.5)
			if p.Parent == Players and there then
				paid[p] = true
				reward(run, p, def.pay or 0, def.xp or 0, string.format("You took part in %s.", string.lower(def.name)))
			end
		end
		for p, seconds in run.seen do
			if not paid[p] and p.Parent == Players and seconds >= Config.EVENT_SPECTATE_SECONDS then
				reward(run, p, def.spectator or 0, 0, string.format("You saw %s.", string.lower(def.name)))
			end
		end
	end
	if run.flag then
		run.flag:Destroy()
	end
	lastRun[id] = os.clock()
	if def.major then
		lastMajorEnd = os.clock()
	end
	Net.pushAll("Event", "Finished", { id = id, name = def.name, text = if held then def.name .. " is over." else def.name .. " has been called off." })
end

function Events.advance(id: string)
	local run = runs[id]
	if not run then
		return
	end
	run.step += 1
	local steps = run.def.steps or {}
	local s = steps[run.step]
	if not s then
		Events.finish(id)
		return
	end
	run.phase = "step"
	run.endsAt = os.clock() + s.seconds
	local h = hooks[id]
	if h and h.step then
		h.step(run, run.step)
	end
	Net.pushAll("Event", "Step", { id = id, name = run.def.name, index = run.step, of = #steps, text = s.text, seconds = s.seconds })
end

-- Each second: timers, spectators, schedules and random rolls.
local randomClock = 0
function Events.tick(dt: number)
	for id, run in runs do
		if run.phase == "step" then
			local pos = placeOf(run.def)
			for _, p in Players:GetPlayers() do
				local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") and p:GetAttribute("CharSlot") ~= nil and (pos == nil or (hrp.Position - pos).Magnitude <= (run.def.radius or 60)) then
					run.seen[p] = (run.seen[p] or 0) + dt
				end
			end
		end
		if os.clock() >= run.endsAt then
			Events.advance(id)
		end
	end
	local t = workspace:GetServerTimeNow()
	randomClock += dt
	local roll = randomClock >= Config.EVENT_RANDOM_CHECK
	if roll then
		randomClock = 0
	end
	for id, def in Config.EVENTS do
		if def.trigger == "schedule" and type(def.every) == "number" then
			local slot = (t - (def.offset or 0)) // def.every
			if scheduledSlot[id] ~= slot then
				local first = scheduledSlot[id] == nil
				scheduledSlot[id] = slot
				if not first then
					Events.start(id) -- skipped (whyNot) if a major event is running
				end
			end
		elseif def.trigger == "random" and roll and type(def.mean) == "number" and not runs[id] then
			if Events.rng:NextNumber() < Config.EVENT_RANDOM_CHECK / def.mean then
				Events.start(id)
			end
		end
	end
end

Events.rng = Random.new()

-- What the Events menu shows a player.
function Events.view(p: Player): { [string]: any }
	local running = {}
	for id, run in runs do
		local steps = run.def.steps or {}
		table.insert(running, {
			id = id,
			name = run.def.name,
			place = run.def.place,
			pos = placeOf(run.def),
			phase = run.phase,
			step = if run.phase == "step" then steps[run.step].text else nil,
			seconds = math.max(0, math.ceil(run.endsAt - os.clock())),
			roles = signupList(run),
			mine = run.signups[p],
			hosting = run.host == p or isOwner(p),
		})
	end
	local startable = {}
	for id, def in Config.EVENTS do
		if def.trigger == "host" then
			local mayHost = isOwner(p)
			for _, r in def.hosts or {} do
				mayHost = mayHost or Roles.roleOf(p) == r
			end
			if mayHost then
				table.insert(startable, { id = id, name = def.name, place = def.place, why = Events.whyNot(id, p) })
			end
		end
	end
	table.sort(startable, function(a, b)
		return a.name < b.name
	end)
	return { running = running, startable = startable }
end

function Events.signUp(p: Player, id: string, roleId: string): (boolean, string?)
	local run = runs[id]
	if not run then
		return false, "That isn't happening now."
	end
	if p:GetAttribute("CharSlot") == nil then
		return false, "Choose a character first."
	end
	local role
	for _, r in run.def.roles or {} do
		if r.id == roleId then
			role = r
		end
	end
	if not role then
		return false, "There's no such part to play."
	end
	local n = 0
	for q, r in run.signups do
		if r == roleId and q ~= p and q.Parent == Players then
			n += 1
		end
	end
	if n >= role.max then
		return false, "That part is taken."
	end
	run.signups[p] = roleId
	announce(run)
	return true
end

-- Coronation: crowns the monarch who hosts it (a cosmetic honour entry), once per reign.
local crowned: { [Player]: string } = {}
Events.hook("coronation", {
	check = function(host: Player?): string?
		if host and crowned[host] == Roles.roleOf(host) then
			return "You've been crowned already this reign."
		end
		return nil
	end,
	finish = function(run: Run, held: boolean)
		local host = run.host
		if not held or not host or host.Parent ~= Players then
			return
		end
		local role = Roles.roleOf(host)
		if role ~= "King" and role ~= "Queen" then
			return
		end
		crowned[host] = role
		local prog = Profiles.progress(host)
		if prog and not table.find(prog.honours, "crowned:" .. role) then
			table.insert(prog.honours, "crowned:" .. role)
		end
		Throne.proclaim(string.format("%s is crowned! God save the %s!", nameOf(host), role))
	end,
})

-- Pea-souper: the fog comes in with the first step and lifts at the end.
Events.hook("peasouper", {
	step = function(_run: Run, i: number)
		if i == 1 then
			WorldClock.setWeather("fog")
		end
	end,
	finish = function()
		WorldClock.setWeather("clear")
	end,
})

function Events.init()
	local V = Net.V
	local ids = {}
	for id in Config.EVENTS do
		table.insert(ids, id)
	end
	table.sort(ids)
	local rate = Config.EVENT_RATE
	local function reply(good: boolean, why: string?): (any, string?)
		if not good then
			return nil, why
		end
		return {}
	end
	local function mayRun(p: Player, id: string): boolean
		local run = runs[id]
		return run ~= nil and (run.host == p or isOwner(p))
	end
	Net.handle("Event", "Get", { rate = rate, call = true }, function(p)
		return Events.view(p)
	end)
	Net.handle("Event", "Start", { schema = { id = V.enum(ids) }, rate = rate, call = true }, function(p, a)
		local def = Config.EVENTS[a.id]
		if def.trigger ~= "host" and not isOwner(p) then
			return nil, "That happens by itself."
		end
		return reply(Events.start(a.id, p))
	end)
	Net.handle("Event", "SignUp", { schema = { id = V.enum(ids), role = V.str(24) }, rate = rate, call = true }, function(p, a)
		return reply(Events.signUp(p, a.id, a.role))
	end)
	Net.handle("Event", "Leave", { schema = { id = V.enum(ids) }, rate = rate, call = true }, function(p, a)
		local run = runs[a.id]
		if run and run.signups[p] then
			run.signups[p] = nil
			announce(run)
		end
		return {}
	end)
	Net.handle("Event", "Advance", { schema = { id = V.enum(ids) }, rate = rate, call = true }, function(p, a)
		if not mayRun(p, a.id) then
			return nil, "Only the host moves it along."
		end
		Events.advance(a.id)
		return {}
	end)
	Net.handle("Event", "End", { schema = { id = V.enum(ids) }, rate = rate, call = true }, function(p, a)
		if not mayRun(p, a.id) then
			return nil, "Only the host ends it."
		end
		Events.finish(a.id, true)
		return {}
	end)
	-- decree levers for events that may be called by decree
	for _, id in ids do
		local def = Config.EVENTS[id]
		if def.decree then
			Decrees.lever("event:" .. id, {
				name = "Call " .. string.lower(string.sub(def.name, 1, 1)) .. string.sub(def.name, 2),
				check = function(p: Player): string?
					return Events.whyNot(id, p)
				end,
				apply = function(p: Player)
					Events.start(id, p)
				end,
			})
		end
	end
	Players.PlayerRemoving:Connect(function(p)
		crowned[p] = nil
		for _, run in runs do
			run.signups[p], run.seen[p] = nil, nil
			if run.host == p then
				run.host = nil -- it carries on by its timers
			end
		end
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(1)
			Events.tick(dt)
		end
	end)
end

return Events
