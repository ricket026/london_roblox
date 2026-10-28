-- T16 / T30 / T33: the daily stipend streak, daily tasks fed by what players do, and the hub
-- appointments (shared-clock schedule, flag, mementos), with DailyUI.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Daily = require(__find(LS .. "Daily"))
local Appointments = require(__find(LS .. "Appointments"))

local function call(p, domain, action, args)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain, msg, true)
end
local function stand(p, at)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(at)
end

local P, UI
test("the first arrival of the day pays the stipend", function()
	P = __addPlayer(1101, "Daisy")
	for _ = 1, 200 do
		if P:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	__asClient(P, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		UI = require(__find(root .. "DailyUI"))
		UI.init()
	end)
	ok(call(P, "Character", "Create", { slot = "1", first = "Daisy", last = "Tester", skin = 1, hair = "own", outfit = "frock" }).ok)
	local prof = Profiles.get(P)
	eq(prof.pence, Config.START_PENCE + Config.STIPEND_PER_DAY, "day 1: 1s")
	eq(prof.limits.streak, 1)
	ok(string.find(P.PlayerGui.Economy.Toast.Text, "stipend"), P.PlayerGui.Economy.Toast.Text)
	-- the same day again: nothing more
	Daily.arrive(P)
	eq(prof.pence, Config.START_PENCE + Config.STIPEND_PER_DAY)
end)

test("the streak grows day by day up to 7, and resets after a missed day", function()
	local prof = Profiles.get(P)
	local today = Daily.today()
	prof.limits.stipendDay, prof.limits.streak = today - 1, 3
	local before = prof.pence
	Daily.arrive(P)
	eq(prof.limits.streak, 4)
	eq(prof.pence, before + 4 * Config.STIPEND_PER_DAY)
	prof.limits.stipendDay, prof.limits.streak = today - 1, Config.STIPEND_MAX_STREAK
	before = prof.pence
	Daily.arrive(P)
	eq(prof.limits.streak, Config.STIPEND_MAX_STREAK, "stays at 7")
	eq(prof.pence, before + Config.STIPEND_MAX_STREAK * Config.STIPEND_PER_DAY)
	prof.limits.stipendDay, prof.limits.streak = today - 3, 5
	Daily.arrive(P)
	eq(prof.limits.streak, 1, "a gap starts it again")
end)

test("three tasks a day, the same all day, from the pool", function()
	local a = Daily.tasks(P)
	eq(#a, Config.DAILY_TASKS)
	local seen = {}
	for _, t in a do
		ok(not seen[t.id], "distinct")
		seen[t.id] = true
	end
	local b = Daily.tasks(P)
	eq(a, b, "the same list all day")
end)

test("tasks complete from what you do: a kiosk purchase, lamps", function()
	local prof = Profiles.get(P)
	prof.limits.daily = { day = Daily.today(), tasks = { { id = "kiosk", n = 0, done = false }, { id = "lamps", n = 0, done = false }, { id = "appointment", n = 0, done = false } } }
	stand(P, workspace.Counters.kiosk_park.Counter.Position + Vector3.new(0, 0, -4))
	local before = prof.pence
	local res = call(P, "Counter", "Buy", { counter = "kiosk_park", item = "tea", count = 1 })
	ok(res.ok, tostring(res.err))
	eq(prof.pence, before - 1 + Config.DAILY_TASK_PAY, "tea 1d, task 2s")
	eq(prof.limits.daily.tasks[1].done, true)
	Daily.record(P, "lamp", 4)
	eq(prof.limits.daily.tasks[2].done, false, "4 of 6")
	Daily.record(P, "lamp", 2)
	eq(prof.limits.daily.tasks[2].done, true)
	local view = Daily.view(P)
	eq(view.tasks[2].n, 6)
	eq(P.PlayerGui.Economy.TodayButton.Text, "Today 2/3", "the client shows it")
end)

test("appointments: the same schedule everywhere, a flag while on, a memento for being there", function()
	local t = workspace:GetServerTimeNow()
	local def, starts, ends = Appointments.at(t)
	eq(ends - starts, Config.APPOINTMENT_LENGTH)
	local slot = math.floor(starts / Config.APPOINTMENT_SECONDS)
	eq(def.id, Config.APPOINTMENTS[(slot % #Config.APPOINTMENTS) + 1].id, "picked by the shared clock")
	ok(string.find(P.PlayerGui.Economy.Appointment.Text, def.title, 1, true), P.PlayerGui.Economy.Appointment.Text)
	stand(P, Vector3.new(def.x, 3, def.z))
	__advance(starts - t + 1)
	ok(workspace.Appointments:FindFirstChild("Appointment") ~= nil, "the flag is up")
	__advance(0.6)
	ok(string.find(P.PlayerGui.Economy.Appointment.Text, "^Now:"), P.PlayerGui.Economy.Appointment.Text)
	local prof = Profiles.get(P)
	local before = prof.collection[def.memento] or 0
	__advance(Config.APPOINTMENT_STAY + 2)
	eq(prof.collection[def.memento], before + 1, "the memento")
	eq(prof.limits.daily.tasks[3].done, true, "and the daily task")
	__advance(Config.APPOINTMENT_STAY + 2)
	eq(prof.collection[def.memento], before + 1, "once per appointment")
	__advance(ends - workspace:GetServerTimeNow() + 2)
	eq(workspace.Appointments:FindFirstChild("Appointment"), nil, "the flag comes down")
	local nexts = __received(P, "AppointmentEvent", "Next")
	ok(#nexts >= 1)
	ok(nexts[#nexts].id ~= def.id, "the next one is announced")
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
