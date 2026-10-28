--!strict
-- LondonServer.Daily: reasons to come back tomorrow (PLAYER_GATHERING §4; TASKS T16, T33).
--   Stipend: the first time each UTC day an account's character arrives in the city it's paid
--   Config.STIPEND_PER_DAY × its streak (days in a row, up to Config.STIPEND_MAX_STREAK).
--   Tasks: Config.DAILY_TASKS a day per account, picked from Config.DAILY_POOL (the same choice all
--   day), Config.DAILY_TASK_PAY each when done. Other systems report what players do:
--   Daily.record(player, event, n?)   events "job:<Job>", "lamp", "shop_buy", "counter_buy",
--   "activity:<Activity>", "appointment", "event" (Config.DAILY_POOL[].event)
--   Daily.onRecord(fn) hears every recorded event too (LondonServer.Onboarding's goals).
-- Remote (Daily domain, call): Get. Pushes Daily.State { day, streak, tasks } and Daily.Notice.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Money = require(Shared:WaitForChild("Money"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Economy = require(script.Parent:WaitForChild("Economy"))

local Daily = {}

local POOL: { [string]: { [string]: any } } = {}
for _, t in Config.DAILY_POOL do
	POOL[t.id] = t
end

function Daily.today(): number
	return os.time() // 86400
end

-- Today's tasks for this account (picked the first time they're needed each day).
function Daily.tasks(player: Player): { { id: string, n: number, done: boolean } }?
	local p = Profiles.get(player)
	if not p then
		return nil
	end
	local d = p.limits.daily
	local day = Daily.today()
	if d.day ~= day then
		local rng = Random.new(day * 7919 + player.UserId)
		local ids = {}
		for _, t in Config.DAILY_POOL do
			table.insert(ids, t.id)
		end
		local tasks = {}
		for _ = 1, math.min(Config.DAILY_TASKS, #ids) do
			local id = table.remove(ids, rng:NextInteger(1, #ids))
			table.insert(tasks, { id = id, n = 0, done = false })
		end
		d.day, d.tasks = day, tasks
	end
	return d.tasks
end

function Daily.view(player: Player): { [string]: any }
	local p = Profiles.get(player)
	local out = {}
	for _, t in Daily.tasks(player) or {} do
		local def = POOL[t.id]
		if def then
			table.insert(out, { id = t.id, text = def.text, n = math.min(t.n, def.n), of = def.n, done = t.done })
		end
	end
	return { day = Daily.today(), streak = if p then p.limits.streak else 0, tasks = out, payText = Money.format(Config.DAILY_TASK_PAY) }
end

local function push(player: Player)
	Net.push(player, "Daily", "State", Daily.view(player))
end

-- Other systems that want every recorded event (the "Next steps" goals): fn(player, event, n).
local listeners: { (Player, string, number) -> () } = {}
function Daily.onRecord(fn: (Player, string, number) -> ())
	table.insert(listeners, fn)
end

function Daily.record(player: Player, event: string, n: number?)
	local tasks = Daily.tasks(player)
	if not tasks or not Profiles.progress(player) then
		return -- at the character menu
	end
	for _, fn in listeners do
		task.spawn(fn, player, event, n or 1)
	end
	local changed = false
	for _, t in tasks do
		local def = POOL[t.id]
		if def and not t.done and def.event == event then
			t.n += n or 1
			changed = true
			if t.n >= def.n then
				t.done = true
				if Config.DAILY_TASK_PAY > 0 then
					Economy.pay(player, Config.DAILY_TASK_PAY, "stipend", "task:" .. t.id)
				end
				Net.push(player, "Daily", "Notice", { text = string.format("Daily task done: %s (+%s).", def.text, Money.format(Config.DAILY_TASK_PAY)) })
			end
		end
	end
	if changed then
		push(player)
	end
end

-- The first arrival of the UTC day pays the stipend and moves the streak.
function Daily.arrive(player: Player)
	local p = Profiles.get(player)
	if not p then
		return
	end
	local day = Daily.today()
	local lim = p.limits
	if lim.stipendDay ~= day then
		lim.streak = if lim.stipendDay == day - 1 then math.min(lim.streak + 1, Config.STIPEND_MAX_STREAK) else 1
		lim.stipendDay = day
		local pence = Config.STIPEND_PER_DAY * lim.streak
		if pence > 0 then
			Economy.pay(player, pence, "stipend", "day " .. lim.streak)
		end
		Net.push(player, "Daily", "Notice", { text = string.format("Daily stipend: %s (day %d of your streak).", Money.format(pence), lim.streak) })
	end
	push(player)
end

function Daily.init()
	Net.handle("Daily", "Get", { call = true }, function(player)
		return Daily.view(player)
	end)
	local function watch(player: Player)
		player:GetAttributeChangedSignal("CharSlot"):Connect(function()
			if player:GetAttribute("CharSlot") ~= nil then
				Daily.arrive(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
end

return Daily
