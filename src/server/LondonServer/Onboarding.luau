--!strict
-- LondonServer.Onboarding: the first five minutes and the "Next steps" goals
-- (LOW_POP_AND_ONBOARDING §3-4; TASKS T25). Account-wide, in profile.settings:
--   rulesAccepted  the rules card (Config.RULES) was accepted
--   starterPicked  the starter job card was answered (a job, or "not now")
--   goals          { [goal id] = true } for Config.GOALS done (each pays its bonus once)
--   goalsHidden    the player folded the goals list away
-- The client runs the arrival camera, then the rules card, then the starter job card (one of
-- Config.STARTER_JOBS, taken through Identity's normal checks). Goals listen to Daily.record events
-- (Daily.onRecord) and check balances, deeds and ranks every few seconds. Each funnel step is
-- logged with Analytics.onboardingStep: Arrival, Rules, FirstJob, FirstPay (Name and Look are
-- logged by Characters).
-- Remotes (Onboarding domain, calls): Get, Arrived, AcceptRules, PickJob { job? }, HideGoals { hidden }.
-- Pushes: Onboarding.Goals { goals, hidden } (to one player), Onboarding.Notice { text }.
--   Onboarding.view(player)   Onboarding.check(player) (re-test the goals now)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Money = require(Shared:WaitForChild("Money"))
local Net = require(Shared:WaitForChild("Net"))
local Stations = require(Shared:WaitForChild("Stations"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Identity = require(script.Parent:WaitForChild("Identity"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))
local Daily = require(script.Parent:WaitForChild("Daily"))

local Onboarding = {}

local function settings(p: Player): { [string]: any }?
	local profile = Profiles.get(p)
	return if profile then profile.settings else nil
end

local function goalsView(p: Player): { [string]: any }
	local s = settings(p) or {}
	local done = s.goals or {}
	local list = {}
	for _, g in Config.GOALS do
		if not done[g.id] then
			table.insert(list, { id = g.id, text = g.text, bonus = Money.format(g.bonus) })
			if #list >= Config.GOALS_SHOWN then
				break
			end
		end
	end
	local n = 0
	for _ in done do
		n += 1
	end
	return { goals = list, hidden = s.goalsHidden == true, done = n, of = #Config.GOALS }
end

function Onboarding.view(p: Player): { [string]: any }
	local s = settings(p) or {}
	local starters = {}
	for _, id in Config.STARTER_JOBS do
		local r = Stations.BY_ID[id]
		if r then
			table.insert(starters, { id = id, name = r.name, blurb = r.blurb })
		end
	end
	local out = goalsView(p)
	out.rulesAccepted = s.rulesAccepted == true
	out.starterPicked = s.starterPicked == true
	out.rules = Config.RULES
	out.starters = starters
	return out
end

local function complete(p: Player, g: { [string]: any })
	local s = settings(p)
	if not s then
		return
	end
	s.goals = s.goals or {}
	if s.goals[g.id] then
		return
	end
	s.goals[g.id] = true
	if (g.bonus or 0) > 0 then
		Economy.pay(p, g.bonus, "prize", "goal:" .. g.id)
	end
	Net.push(p, "Onboarding", "Notice", { text = string.format("Next step done: %s (+%s).", g.text, Money.format(g.bonus or 0)) })
	Net.push(p, "Onboarding", "Goals", goalsView(p))
end

local function matches(want: any, event: string): boolean
	if type(want) == "table" then
		for _, w in want do
			if matches(w, event) then
				return true
			end
		end
		return false
	end
	if type(want) ~= "string" then
		return false
	end
	if string.sub(want, -1) == ":" then
		return string.sub(event, 1, #want) == want
	end
	return want == event
end

local function onRecord(p: Player, event: string)
	if string.sub(event, 1, 4) == "job:" then
		Analytics.onboardingStep(p, "FirstPay")
	end
	local done = (settings(p) or {}).goals or {}
	for _, g in Config.GOALS do
		if g.event and not done[g.id] and matches(g.event, event) then
			complete(p, g)
		end
	end
end

-- Goals that are a state rather than an event.
function Onboarding.check(p: Player)
	local profile = Profiles.get(p)
	if not profile then
		return
	end
	local done = profile.settings.goals or {}
	for _, g in Config.GOALS do
		if g.check and not done[g.id] then
			local met = false
			if g.check == "bank" then
				met = profile.bank >= (g.value or 0)
			elseif g.check == "property" then
				local n = 0
				for _ in profile.properties or {} do
					n += 1
				end
				met = n >= (g.value or 1)
			elseif g.check == "rank" then
				local prog = Profiles.progress(p)
				for _, j in if prog then prog.jobs else {} do
					met = met or (j.rank or 1) >= (g.value or 2)
				end
			end
			if met then
				complete(p, g)
			end
		end
	end
end

function Onboarding.init()
	local V = Net.V
	local rate = Config.ONBOARDING_RATE
	Daily.onRecord(onRecord)
	Net.handle("Onboarding", "Get", { rate = rate, call = true }, function(p)
		return Onboarding.view(p)
	end)
	Net.handle("Onboarding", "Arrived", { rate = rate, call = true }, function(p)
		Analytics.onboardingStep(p, "Arrival")
		return {}
	end)
	Net.handle("Onboarding", "AcceptRules", { rate = rate, call = true }, function(p)
		local s = settings(p)
		if not s then
			return nil, "Not now."
		end
		s.rulesAccepted = true
		Analytics.onboardingStep(p, "Rules")
		return {}
	end)
	Net.handle("Onboarding", "PickJob", { schema = { job = V.optional(V.enum(Config.STARTER_JOBS)) }, rate = rate, call = true }, function(p, a)
		local s = settings(p)
		if not s then
			return nil, "Not now."
		end
		if a.job then
			local why = Identity.canTake(p, a.job)
			if why then
				return nil, why
			end
			Identity.grant(p, a.job)
			Analytics.onboardingStep(p, "FirstJob")
		end
		s.starterPicked = true
		return {}
	end)
	Net.handle("Onboarding", "HideGoals", { schema = { hidden = V.bool() }, rate = rate, call = true }, function(p, a)
		local s = settings(p)
		if not s then
			return nil, "Not now."
		end
		s.goalsHidden = a.hidden
		return goalsView(p)
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			for _, p in Players:GetPlayers() do
				if p:GetAttribute("CharSlot") ~= nil then
					Onboarding.check(p)
				end
			end
		end
	end)
end

return Onboarding
