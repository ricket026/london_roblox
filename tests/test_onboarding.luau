-- T25: the first join. The arrival camera (Skip), the rules card, the starter job card, the
-- funnel steps, the "Next steps" goals (events and checks, each paid once), folding the list,
-- and a returning account skipping the cards.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0
local Net = require(Shared.Net)
local Roles = require(Shared.Roles)

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Daily = require(__find(LS .. "Daily"))
local Analytics = require(__find(LS .. "Analytics"))
local Onboarding = require(__find(LS .. "Onboarding"))

local function call(p, action, args, domain)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain or "Onboarding", msg, true)
end
local function steps(uid)
	local out = {}
	for _, e in Analytics.recent(100) do
		if e.player == uid and e.kind == "onboarding" then
			out[e.name] = true
		end
	end
	return out
end
local function pressText(root, pattern)
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and d.Visible ~= false and string.find(d.Text, pattern) then
			d.Activated:Fire()
			__advance(0.2)
			return true
		end
	end
	return false
end

local N, ui
test("a new player: the arrival camera, Skip, the rules card", function()
	N = __addPlayer(1801, "Nell")
	for _ = 1, 200 do
		if N:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	__asClient(N, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		ui = require(__find(root .. "OnboardingUI"))
		ui.init()
	end)
	ok(call(N, "Create", { slot = "1", first = "Nell", last = "Tester", skin = 1, hair = "own", outfit = "plain" }, "Character").ok)
	__advance(0.5)
	local gui = N.PlayerGui.Economy
	ok(gui.SkipArrival.Visible, "the arrival plays")
	eq(workspace.CurrentCamera.CameraType, Enum.CameraType.Scriptable)
	gui.SkipArrival.Activated:Fire()
	__advance(0.5)
	eq(workspace.CurrentCamera.CameraType, Enum.CameraType.Custom, "skipped")
	ok(steps(1801).Arrival, "Arrival logged")
	ok(gui.Welcome.Visible, "the rules card")
	local found = false
	for _, d in gui.Welcome.Body:GetChildren() do
		if d:IsA("TextLabel") and string.find(d.Text, "personal details") then
			found = true
		end
	end
	ok(found, "lists the rules")
	ok(pressText(gui.Welcome, "^I agree$"))
	ok(Profiles.get(N).settings.rulesAccepted)
	ok(steps(1801).Rules)
end)

test("the starter job card puts you on duty", function()
	local gui = N.PlayerGui.Economy
	eq(gui.Welcome.Title.Text, "Your first job")
	ok(pressText(gui.Welcome, "^Newsboy"))
	eq(Roles.roleOf(N), "Newsboy")
	ok(Profiles.get(N).settings.starterPicked)
	ok(steps(1801).FirstJob)
	ok(not gui.Welcome.Visible, "the card is done")
	ok(not call(N, "PickJob", { job = "Baker" }).ok, "only the starter jobs")
end)

test("Next steps: events, checks, each bonus once, fold the list", function()
	local gui = N.PlayerGui.Economy
	__advance(0.5)
	ok(gui.Goals.Visible)
	ok(string.find(gui.Goals.Body.Text, "Earn your first wages"), gui.Goals.Body.Text)
	local w = Profiles.get(N).pence
	Daily.record(N, "job:Newsboy")
	__advance(0.2)
	eq(Profiles.get(N).pence, w + 6, "the bonus")
	ok(steps(1801).FirstPay)
	ok(not string.find(gui.Goals.Body.Text, "first wages"), "gone from the list")
	ok(string.find(gui.Goals.Head.Text, "1/" .. #Config.GOALS), gui.Goals.Head.Text)
	Daily.record(N, "job:Newsboy")
	__advance(0.2)
	eq(Profiles.get(N).pence, w + 6, "once only")
	Daily.record(N, "event")
	__advance(0.2)
	ok(Profiles.get(N).settings.goals.occasion, "a list of events")
	Daily.record(N, "activity:Ducks")
	__advance(0.2)
	ok(Profiles.get(N).settings.goals.pastime, "a prefix")
	Profiles.get(N).bank = 300
	__advance(6)
	ok(Profiles.get(N).settings.goals.save, "a check: £1 in the bank")
	gui.Goals.Head.Activated:Fire()
	__advance(0.2)
	ok(Profiles.get(N).settings.goalsHidden)
	ok(not gui.Goals.Body.Visible, "folded")
end)

test("a returning account skips the cards; Not now leaves the role alone", function()
	local R = __addPlayer(1802, "Ralph")
	for _ = 1, 200 do
		if R:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	ok(call(R, "Create", { slot = "1", first = "Ralph", last = "Tester", skin = 1, hair = "own", outfit = "frock" }, "Character").ok)
	local v = call(R, "Get").data
	eq(v.rulesAccepted, false)
	eq(#v.starters, #Config.STARTER_JOBS)
	ok(call(R, "AcceptRules").ok)
	ok(call(R, "PickJob", {}).ok)
	eq(Roles.roleOf(R), Config.DEFAULT_ROLE)
	v = call(R, "Get").data
	ok(v.rulesAccepted and v.starterPicked, "nothing left to show")
	Onboarding.check(R)
end)
