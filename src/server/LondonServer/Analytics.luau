--!strict
-- LondonServer.Analytics: AnalyticsService wrapper (systems/PLAYER_GATHERING.md §7).
-- Onboarding funnel steps (Config.ONBOARDING_STEPS, first join only, each step once per
-- session) and custom events. In Studio nothing is sent unless Config.ANALYTICS_IN_STUDIO;
-- events are kept in memory either way (Analytics.recent) for tests and the staff summary.
-- D1/D7/D30 retention comes from Roblox's own dashboard; no code needed.
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Analytics = {}
local SEND = not RunService:IsStudio() or Config.ANALYTICS_IN_STUDIO
local stepIndex: { [string]: number } = {}
for i, name in Config.ONBOARDING_STEPS do
	stepIndex[name] = i
end
local done: { [Player]: { [string]: boolean } } = {}
local joinedAt: { [Player]: number } = {}
local recent: { { player: number, kind: string, name: string, value: number? } } = {}

local function remember(player: Player, kind: string, name: string, value: number?)
	table.insert(recent, 1, { player = player.UserId, kind = kind, name = name, value = value })
	if #recent > Config.ANALYTICS_MEMORY then
		table.remove(recent)
	end
end

function Analytics.onboardingStep(player: Player, step: string)
	local i = stepIndex[step]
	local d = done[player]
	if not i or not d or d[step] then
		return
	end
	d[step] = true
	remember(player, "onboarding", step, i)
	if SEND then
		pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, i, step)
	end
end

function Analytics.event(player: Player, name: string, value: number?)
	remember(player, "custom", name, value)
	if SEND then
		pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1)
	end
end

-- isNew = first join (only new players walk the onboarding funnel).
function Analytics.onProfileLoaded(player: Player, isNew: boolean)
	joinedAt[player] = joinedAt[player] or os.clock()
	if isNew then
		done[player] = done[player] or {}
		Analytics.onboardingStep(player, "ProfileLoaded")
	end
end

function Analytics.onPlayerRemoving(player: Player)
	local t = joinedAt[player]
	if t then
		Analytics.event(player, "SessionSeconds", math.floor(os.clock() - t))
	end
	done[player] = nil
	joinedAt[player] = nil
end

function Analytics.recent(n: number): { any }
	local out = {}
	for i = 1, math.min(n, #recent) do
		out[i] = recent[i]
	end
	return out
end

return Analytics
