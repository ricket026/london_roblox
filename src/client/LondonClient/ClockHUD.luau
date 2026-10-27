--!strict
-- LondonClient.ClockHUD (stub): the in-game time at the top of the screen, e.g. "6:45 pm · Dusk".
-- Reads Lighting.ClockTime and the "Phase" attribute set by LondonServer.WorldClock.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local ClockHUD = {}

function ClockHUD.format(h: number): string
	local hour = math.floor(h) % 24
	local minute = math.floor((h % 1) * 60 / 5) * 5 -- 5-minute steps so it doesn't flicker
	local suffix = if hour < 12 then "am" else "pm"
	local h12 = if hour % 12 == 0 then 12 else hour % 12
	return string.format("%d:%02d %s", h12, minute, suffix)
end

function ClockHUD.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ClockHUD"
	gui.ResetOnSpawn = false
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, 6)
	l.Size = UDim2.fromOffset(220, 26)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Garamond
	l.TextSize = 20
	l.TextColor3 = Color3.fromRGB(240, 232, 214)
	l.TextStrokeTransparency = 0.5
	l.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local function update()
		local phase = Lighting:GetAttribute("Phase")
		l.Text = ClockHUD.format(Lighting.ClockTime) .. (if type(phase) == "string" then " · " .. phase else "")
	end
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(update)
	Lighting:GetAttributeChangedSignal("Phase"):Connect(update)
	update()
end

return ClockHUD
