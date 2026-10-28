-- Phase 5: the job framework (duty by role, steps checked by the server, pay with rank and the
-- hourly cap, XP and ranks shared by linked slots), Postman and Newsboy, and the tracker UI.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0 -- daily money is tested in test_daily; keep balances exact here
local Net = require(Shared.Net)
local Ranks = require(Shared.Ranks)

-- six houses near the Charing Cross post office
local map = Instance.new("Folder")
map.Name = "Map"
local plots = Instance.new("Folder")
plots.Name = "Plots"
plots.Parent = map
for k = 1, 6 do
	local p = Instance.new("Part")
	p.Name = "Lot_" .. (900 + k)
	p.Anchored = true
	p.Size = Vector3.new(28, 2.6, 40)
	p.CFrame = CFrame.new(-150 + k * 30, -0.7, -1260)
	p:SetAttribute("LotId", 900 + k)
	p:SetAttribute("District", "Covent Garden")
	p:SetAttribute("LotType", "Shop")
	p:SetAttribute("Frontage", 28)
	p:SetAttribute("Depth", 40)
	p.Parent = plots
end
map.Parent = workspace

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Jobs = require(__find(LS .. "Jobs"))

local function call(p, domain, action, args)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain, msg, true)
end
local function stand(p, at)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(at)
end

test("ranks: 150 × n^1.6, +10% pay a rank", function()
	eq(Ranks.xpFor(1), 0)
	eq(Ranks.xpFor(2), 454)
	eq(Ranks.xpFor(5), 1969)
	eq(Ranks.rankFor(0), 1)
	eq(Ranks.rankFor(454), 2)
	eq(Ranks.rankFor(100000), 5)
	near(Ranks.payMultiplier(3), 1.2, 1e-9)
end)

local P, tracker
test("choosing Postman in the role menu puts you on duty with a round", function()
	P = __addPlayer(901, "Percy")
	for _ = 1, 200 do
		if P:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	__asClient(P, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		tracker = require(__find(root .. "JobUI"))
		tracker.init()
	end)
	ok(call(P, "Character", "Create", { slot = "1", first = "Percy", last = "Tester", skin = 1, hair = "own", outfit = "frock" }).ok)
	stand(P, Vector3.new(40, 3, -1150))
	local res = call(P, "Identity", "ChooseRole", { role = "Postman" })
	ok(res.ok, tostring(res.err))
	local t = Jobs.current(P)
	ok(t ~= nil, "a task")
	eq(#t.steps, 1 + Config.JOBS.Postman.stops)
	ok(string.find(t.steps[1].text, "Charing Cross"), t.steps[1].text)
	ok(string.find(t.steps[2].text, "^Deliver to No%. %d+, "), t.steps[2].text)
	eq(tracker.state().job, "Postman", "the tracker has it")
	ok(P.PlayerGui.Economy.JobTracker.Visible)
	ok(workspace:FindFirstChild("JobMarker") ~= nil, "a marker over the next stop")
end)

test("steps are checked: in order, in place, not instantly", function()
	local t = Jobs.current(P)
	local res = call(P, "Job", "Hold", { step = 2 })
	eq(res.ok, false, "not the next step")
	stand(P, Vector3.new(0, 3, 0))
	__advance(2)
	res = call(P, "Job", "Hold", { step = 1 })
	eq(res.ok, false, "not there")
	stand(P, t.steps[1].pos)
	res = call(P, "Job", "Hold", { step = 1 })
	ok(res.ok, tostring(res.err))
	eq(t.index, 2)
	stand(P, t.steps[2].pos)
	res = call(P, "Job", "Hold", { step = 2 })
	eq(res.ok, false, "too quick after the last one")
end)

test("finishing the round pays (rank bonus, ledger) and gives XP; a new round follows", function()
	local t = Jobs.current(P)
	local wallet = Profiles.get(P).pence
	for k = t.index, #t.steps do
		__advance(Config.JOBS.Postman.hold + 0.1)
		stand(P, t.steps[k].pos)
		local res = call(P, "Job", "Hold", { step = k })
		ok(res.ok, tostring(res.err))
	end
	eq(Profiles.get(P).pence, wallet + Config.JOBS.Postman.pay, "rank 1 pay")
	local rec = Profiles.progress(P).jobs.Postman
	eq(rec.xp, Config.JOBS.Postman.xp)
	eq(rec.done, 1)
	__advance(2)
	ok(Jobs.current(P) ~= nil and Jobs.current(P) ~= t, "the next round")
	ok(string.find(P.PlayerGui.Economy.Toast.Text, "Round done"), P.PlayerGui.Economy.Toast.Text)
end)

test("rank up raises pay; the hourly cap stops pay", function()
	Profiles.progress(P).jobs.Postman.xp = Ranks.xpFor(3) - 1
	Jobs.addXp(P, "Postman", 1)
	eq(Jobs.rankOf(P, "Postman"), 3)
	local wallet = Profiles.get(P).pence
	eq(Jobs.pay(P, "Postman", 10, "test"), 12, "+20% at rank 3")
	eq(Profiles.get(P).pence, wallet + 12)
	local lim = Profiles.get(P).limits
	lim.jobPaid.Postman = Config.JOBS.Postman.cap - 5
	eq(Jobs.pay(P, "Postman", 10, "test"), 5, "only up to the cap")
	eq(Jobs.pay(P, "Postman", 10, "test"), 0, "then nothing this hour")
end)

test("Newsboy: collect a bundle, sell it on corners, a bonus at the end", function()
	__advance(Config.CHARACTER_SWITCH_COOLDOWN or 0)
	local res = call(P, "Identity", "ChooseRole", { role = "Newsboy" })
	if not res.ok then
		__advance(300)
		res = call(P, "Identity", "ChooseRole", { role = "Newsboy" })
	end
	ok(res.ok, tostring(res.err))
	local t = Jobs.current(P)
	eq(t.job, "Newsboy")
	eq(#t.steps, 1 + Config.JOBS.Newsboy.corners)
	local copies = 0
	for k = 2, #t.steps do
		copies += t.steps[k].pay
	end
	eq(copies, Config.JOBS.Newsboy.bundle, "the whole bundle is sold across the corners")
	Profiles.get(P).limits.jobPaid = {}
	local wallet = Profiles.get(P).pence
	for k = 1, #t.steps do
		__advance(Config.JOBS.Newsboy.hold + 0.1)
		stand(P, t.steps[k].pos)
		res = call(P, "Job", "Hold", { step = k })
		ok(res.ok, tostring(res.err))
	end
	eq(Profiles.get(P).pence, wallet + Config.JOBS.Newsboy.bundle + Config.JOBS.Newsboy.bundleBonus, "copies + bonus (rank 1)")
end)

test("Baker: needs flour, makes loaves tagged with the maker", function()
	local Inventory = require(__find(LS .. "Inventory"))
	__advance(300)
	ok(call(P, "Identity", "ChooseRole", { role = "Baker" }).ok)
	local t = Jobs.current(P)
	eq(t.job, "Baker")
	ok(string.find(t.steps[1].text, "4 × Cottage Loaf"), t.steps[1].text)
	stand(P, t.steps[1].pos)
	__advance(Config.JOBS.Baker.hold + 0.1)
	local res = call(P, "Job", "Hold", { step = 1 })
	eq(res.ok, false)
	ok(string.find(res.err, "2 × Sack of Flour"), res.err)
	Inventory.add(P, "flour", 3)
	res = call(P, "Job", "Hold", { step = 1 })
	ok(res.ok, tostring(res.err))
	eq(Inventory.count(P, "flour"), 1, "used 2")
	eq(Inventory.count(P, "bread_loaf", nil, 901), 4, "4 loaves made by Percy")
	local stack
	for _, st in Profiles.get(P).inventory.bag do
		if st.i == "bread_loaf" then
			stack = st
		end
	end
	eq(stack.byName, "Percy Tester", "the 'made by' name")
end)

test("Carpenter: timber into furniture, which goes to storage", function()
	local Inventory = require(__find(LS .. "Inventory"))
	__advance(300)
	ok(call(P, "Identity", "ChooseRole", { role = "Carpenter" }).ok)
	local t = Jobs.current(P)
	local made
	for id in t.steps[1].give do
		made = id
	end
	ok(table.find(Config.JOBS.Carpenter.makes, made) ~= nil, tostring(made))
	Inventory.add(P, "timber", 4)
	stand(P, t.steps[1].pos)
	__advance(Config.JOBS.Carpenter.hold + 0.1)
	local res = call(P, "Job", "Hold", { step = 1 })
	ok(res.ok, tostring(res.err))
	eq(Inventory.count(P, "timber"), 0)
	eq(Inventory.count(P, made, "storage", 901), 1, "made by Percy, in storage")
end)

test("going off duty clears the task and the tracker", function()
	__advance(300)
	local res = call(P, "Identity", "ChooseRole", { role = "Citizen" })
	ok(res.ok, tostring(res.err))
	eq(Jobs.current(P), nil)
	eq(P.PlayerGui.Economy.JobTracker.Visible, false)
	eq(workspace:FindFirstChild("JobMarker"), nil)
end)

test("no unexpected warnings", function()
	local w = {}
	for _, line in __warnings() do
		if not string.find(line, "^%[Net%] rejected") then
			table.insert(w, line)
		end
	end
	eq(#w, 0, table.concat(w, " | "))
end)
