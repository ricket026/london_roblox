--!strict
-- LondonServer.WorldClock: the in-game day (Q10: Config.DAY_MINUTES real minutes per day).
-- The clock is derived from server time, so every server shows the same hour; that lets the
-- cross-server "What's on" feed (M3b) and clock-time events line up. Drives Lighting.ClockTime
-- (replicates to clients) and sets Lighting attribute "Phase" (Dawn / Day / Dusk / Night).
-- Other systems: WorldClock.hour(), WorldClock.phase(), WorldClock.PhaseChanged:Connect(fn(name)).
-- Each phase tweens Lighting and the Atmosphere to Config.LIGHTING (art/style.md §6, TASKS T07);
-- WorldClock.setWeather("clear" | "rain" | "fog") adds Config.WEATHER on top (events, pea-soupers).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WorldClock = {}
local phaseEvent = Instance.new("BindableEvent")
WorldClock.PhaseChanged = phaseEvent.Event

local debugShift = 0 -- hours added in Studio by WorldClock.debugSetHour
local currentPhase = ""
local weather = "clear"

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function atmosphere(): Atmosphere
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if a then
		return a
	end
	local made = Instance.new("Atmosphere")
	made.Parent = Lighting
	return made
end

-- Tweens the sky to the phase's look plus the weather.
local function applyLook(instant: boolean?)
	local look = Config.LIGHTING[currentPhase]
	if not look then
		return
	end
	local w = Config.WEATHER[weather] or Config.WEATHER.clear
	local info = TweenInfo.new(if instant then 0 else Config.LIGHTING_TWEEN, Enum.EasingStyle.Sine)
	TweenService:Create(Lighting, info, { Brightness = look.brightness * w.brightness, OutdoorAmbient = rgb(look.ambient) }):Play()
	TweenService:Create(atmosphere(), info, {
		Density = math.min(1, look.density + w.density),
		Haze = look.haze,
		Glare = look.glare,
		Color = rgb(w.colour or look.colour),
	}):Play()
end

-- "clear", "rain" or "fog" (Config.WEATHER); the sky changes at once (over LIGHTING_TWEEN).
function WorldClock.setWeather(kind: string): boolean
	if not Config.WEATHER[kind] then
		return false
	end
	weather = kind
	Lighting:SetAttribute("Weather", kind)
	applyLook()
	return true
end

function WorldClock.weather(): string
	return weather
end

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
		local first = currentPhase == ""
		currentPhase = p
		Lighting:SetAttribute("Phase", p)
		applyLook(first)
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
	Lighting:SetAttribute("Weather", weather)
	update()
	task.spawn(function()
		while true do
			task.wait(Config.CLOCK_TICK)
			update()
		end
	end)
end

return WorldClock
