--!strict
-- LondonServer.WorldClock: the in-game day (Q10: Config.DAY_MINUTES real minutes per day).
-- The clock is derived from server time, so every server shows the same hour; that lets the
-- cross-server "What's on" feed (M3b) and clock-time events line up. Drives Lighting.ClockTime
-- (replicates to clients) and sets Lighting attribute "Phase" (Dawn / Day / Dusk / Night).
-- Other systems: WorldClock.hour(), WorldClock.phase(), WorldClock.PhaseChanged:Connect(fn(name)).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WorldClock = {}
local phaseEvent = Instance.new("BindableEvent")
WorldClock.PhaseChanged = phaseEvent.Event

local debugShift = 0 -- hours added in Studio by WorldClock.debugSetHour
local currentPhase = ""

-- In-game hour, 0 <= h < 24.
function WorldClock.hour(): number
	local dayLength = Config.DAY_MINUTES * 60
	local h = (workspace:GetServerTimeNow() / dayLength) * 24 + Config.CLOCK_OFFSET_HOURS + debugShift
	return h % 24
end

function WorldClock.phaseAt(h: number): string
	local name = Config.CLOCK_PHASES[#Config.CLOCK_PHASES].name -- before the first start = last phase (night)
	for _, p in Config.CLOCK_PHASES do
		if h >= p.hour then
			name = p.name
		end
	end
	return name
end

function WorldClock.phase(): string
	return currentPhase
end

local function update()
	local h = WorldClock.hour()
	Lighting.ClockTime = h
	local p = WorldClock.phaseAt(h)
	if p ~= currentPhase then
		currentPhase = p
		Lighting:SetAttribute("Phase", p)
		phaseEvent:Fire(p)
	end
end

-- Studio test hook: jump the clock to an hour (0-24).
function WorldClock.debugSetHour(h: number): boolean
	if not RunService:IsStudio() then
		return false
	end
	debugShift = 0
	debugShift = (h - WorldClock.hour()) % 24
	update()
	return true
end

function WorldClock.init()
	Lighting:SetAttribute("DayMinutes", Config.DAY_MINUTES)
	update()
	task.spawn(function()
		while true do
			task.wait(Config.CLOCK_TICK)
			update()
		end
	end)
end

return WorldClock
