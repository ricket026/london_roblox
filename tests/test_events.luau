-- T39: the event framework. Hosting (who may), announce + flag, gather, steps, spectators and
-- sign-ups rewarded, one major event at a time and the gap, cooldowns, the coronation's crown,
-- a decree lever, a random minor event (the pea-souper fog), calling off, and the Events menu.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0
Config.GOALS = {} -- the "Next steps" bonuses are tested in test_onboarding
local Net = require(Shared.Net)

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Throne = require(__find(LS .. "Throne"))
local Events = require(__find(LS .. "Events"))
local Decrees = require(__find(LS .. "Decrees"))
local Jobs = require(__find(LS .. "Jobs"))
local WorldClock = require(__find(LS .. "WorldClock"))

local function call(p, action, args, domain)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain or "Event", msg, true)
end
local function last(p, remote, action)
	local list = __received(p, remote, action)
	return list[#list]
end
local function join(uid, first)
	local p = __addPlayer(uid, first)
	for _ = 1, 200 do
		if p:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	ok(call(p, "Create", { slot = "1", first = first, last = "Tester", skin = 1, hair = "own", outfit = "frock" }, "Character").ok)
	Profiles.get(p).playtime = 3 * 3600
	return p
end
local function stand(p, x, z)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(x, 3, z)
end
local function rest(seconds)
	-- step the clock a second at a time so the per-second tick sees everyone
	for _ = 1, seconds do
		__advance(1)
	end
end
local function wallet(p)
	return Profiles.get(p).pence
end

-- no random events unless a test asks
Events.rng = { NextNumber = function()
	return 1
end }

local K, S, F, A, ui
test("only a host starts a host event; it's announced with a flag", function()
	K = join(1701, "Kit")
	S = join(1702, "Sally")
	F = join(1703, "Frank")
	A = join(1704, "Abel")
	__asClient(S, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		ui = require(__find(root .. "EventUI"))
		ui.init()
	end)
	__advance(0)
	local res = call(S, "Start", { id = "balcony" })
	ok(not res.ok)
	ok(string.find(res.err, "can't host"), res.err)
	ok(not call(S, "Start", { id = "peasouper" }).ok, "random events aren't started by hand")
	ok(Throne.claim(K, "King"))
	res = call(K, "Start", { id = "balcony" })
	ok(res.ok, tostring(res.err))
	local a = last(S, "EventEvent", "Announce")
	ok(a and a.name == "A balcony appearance", "announced")
	eq(a.seconds, Config.EVENTS.balcony.gather)
	ok(workspace.Events:FindFirstChild("Event_balcony") ~= nil, "a flag at the place")
	ok(string.find(last(S, "ThroneEvent", "Proclaim").text, "balcony appearance at the Palace"), "proclaimed")
	local res2 = call(K, "Start", { id = "coronation" })
	ok(not res2.ok, "one major event at a time")
	ok(string.find(res2.err, "under way"), res2.err)
	ok(S.PlayerGui.Economy.EventLine.Visible)
	ok(string.find(S.PlayerGui.Economy.EventLine.Text, "begins in"), S.PlayerGui.Economy.EventLine.Text)
end)

test("gather, steps, then spectators near it are rewarded once", function()
	stand(S, 0, 20)
	stand(F, 900, -2000)
	local before, farBefore = wallet(S), wallet(F)
	rest(Config.EVENTS.balcony.gather + 1)
	local step = last(S, "EventEvent", "Step")
	ok(step and step.index == 1, "the first step")
	ok(string.find(S.PlayerGui.Economy.EventLine.Text, "The crowd gathers"), S.PlayerGui.Economy.EventLine.Text)
	local total = 0
	for _, s in Config.EVENTS.balcony.steps do
		total += s.seconds
	end
	rest(total + 1)
	eq(Events.running("balcony"), nil, "over")
	ok(last(S, "EventEvent", "Finished") ~= nil)
	eq(wallet(S), before + Config.EVENTS.balcony.spectator, "the spectator's stipend")
	eq(Profiles.get(S).collection.memento_balcony, 1, "and a memento")
	eq(wallet(F), farBefore, "nothing for someone across town")
	ok(workspace.Events:FindFirstChild("Event_balcony") == nil, "the flag comes down")
	ok(not S.PlayerGui.Economy.EventLine.Visible)
end)

test("the gap between major events; sign-ups; the host moves it along; the coronation crowns", function()
	local res = call(K, "Start", { id = "coronation" })
	ok(not res.ok)
	ok(string.find(res.err, "can begin in"), res.err)
	__advance(Config.EVENT_MAJOR_GAP)
	ok(call(K, "Start", { id = "coronation" }).ok)
	ok(call(A, "ChooseRole", { role = "Postman" }, "Identity").ok)
	ok(call(A, "SignUp", { id = "coronation", role = "Archbishop" }).ok)
	ok(not call(S, "SignUp", { id = "coronation", role = "Archbishop" }).ok, "one archbishop")
	ok(not call(S, "SignUp", { id = "coronation", role = "Pope" }).ok, "no such part")
	ok(call(S, "SignUp", { id = "coronation", role = "Choir" }).ok)
	ok(call(S, "Leave", { id = "coronation" }).ok)
	local v = call(K, "Get").data
	eq(v.running[1].roles[1].names[1], "Abel Tester")
	ok(v.running[1].hosting)
	ok(not call(S, "Advance", { id = "coronation" }).ok, "only the host")
	stand(A, 880, -960)
	stand(K, 880, -960)
	local before = wallet(A)
	for _ = 1, #Config.EVENTS.coronation.steps + 1 do
		ok(call(K, "Advance", { id = "coronation" }).ok)
		rest(Config.EVENT_SPECTATE_SECONDS // 4)
	end
	eq(Events.running("coronation"), nil, "the host took it to the end")
	eq(wallet(A), before + Config.EVENTS.coronation.pay, "the Archbishop is paid")
	ok(Jobs.rankOf(A, "Postman") >= 1)
	eq(Profiles.progress(A).jobs.Postman.xp, Config.EVENTS.coronation.xp, "XP to his job")
	ok(table.find(Profiles.progress(K).honours, "crowned:King") ~= nil, "the King is crowned")
	ok(string.find(last(S, "ThroneEvent", "Proclaim").text, "is crowned"), "and it's proclaimed")
	__advance(Config.EVENTS.coronation.cooldown + Config.EVENT_MAJOR_GAP)
	local res3 = call(K, "Start", { id = "coronation" })
	ok(not res3.ok)
	ok(string.find(res3.err, "crowned already"), res3.err)
end)

test("an event can be called by decree", function()
	ok(Decrees.LEVERS["event:coronation"] ~= nil, "the coronation is a decree lever")
	local d = call(K, "Get", nil, "Decree").data
	local found = false
	for _, l in d.levers do
		if l.id == "event:coronation" then
			found = true
			ok(l.why and string.find(l.why, "crowned already"), "and says why it can't be now")
		end
	end
	ok(found)
	ok(not call(K, "Issue", { title = "x", text = "y", lever = "event:dragons" }, "Decree").ok, "unknown levers still fail")
end)

test("a random minor event: the pea-souper brings the fog and takes it away, alongside a major one", function()
	Events.rng = { NextNumber = function()
		return 0
	end }
	rest(Config.EVENT_RANDOM_CHECK + 1)
	Events.rng = { NextNumber = function()
		return 1
	end }
	ok(Events.running("peasouper") ~= nil, "it rolled")
	eq(WorldClock.weather(), "fog")
	ok(call(K, "Start", { id = "balcony" }).ok, "a major event may run during a minor one")
	local total = 0
	for _, s in Config.EVENTS.peasouper.steps do
		total += s.seconds
	end
	rest(total + 2)
	eq(Events.running("peasouper"), nil)
	eq(WorldClock.weather(), "clear", "the fog lifts")
end)

test("calling an event off before it starts pays nothing; the owner may start anything", function()
	-- the balcony from the last test has finished by now
	eq(Events.running("balcony"), nil)
	__advance(Config.EVENTS.balcony.cooldown + Config.EVENT_MAJOR_GAP)
	ok(call(K, "Start", { id = "balcony" }).ok)
	local before = wallet(S)
	stand(S, 0, 20)
	ok(call(K, "End", { id = "balcony" }).ok)
	ok(string.find(last(S, "EventEvent", "Finished").text, "called off"))
	eq(wallet(S), before)
	F:SetAttribute("StaffLevel", Config.STAFF_LEVEL.OWNER)
	__advance(Config.EVENTS.balcony.cooldown + Config.EVENT_MAJOR_GAP)
	ok(call(F, "Start", { id = "balcony" }).ok, "the owner account can start any event")
	ok(call(F, "End", { id = "balcony" }).ok)
end)

test("the Events menu: what's on, Join", function()
	__advance(Config.EVENTS.coronation.cooldown + Config.EVENT_MAJOR_GAP)
	ok(Events.start("coronation", nil))
	__advance(0)
	local gui = S.PlayerGui.Economy
	ok(gui.More.EventsButton.Visible)
	ok(gui.MoreButton.Visible, "the More menu shows")
	gui.MoreButton.Activated:Fire()
	ok(gui.More.Visible)
	gui.More.EventsButton.Activated:Fire()
	__advance(0)
	ok(not gui.More.Visible, "it closes when a button is chosen")
	__advance(0)
	ok(gui.EventPanel.Visible)
	local joined = false
	for _, d in gui.EventPanel.Body:GetDescendants() do
		if d:IsA("TextButton") and d.Text == "Join" and string.find(d.Parent.Label.Text, "^Choir") then
			d.Activated:Fire()
			joined = true
			break
		end
	end
	ok(joined)
	__advance(0)
	eq(Events.running("coronation").signups[S], "Choir")
end)
