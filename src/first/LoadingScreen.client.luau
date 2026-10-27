--!strict
-- LoadingScreen (stub): a plain title card until the server says the profile is loaded.
-- Real art comes with the UI pass (M8) from the user's references; don't style this further.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local start = os.clock()

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(18, 16, 14)
bg.BorderSizePixel = 0
bg.Parent = gui

local function label(y: number, h: number, text: string, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.new(0.9, 0, 0, h)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Garamond
	l.TextColor3 = Color3.fromRGB(230, 220, 200)
	l.TextSize = size
	l.Text = text
	l.Parent = bg
	return l
end
local title = label(0.45, 60, "Crown & Court", 48)
local subtitle = label(0.53, 30, "", 22)
local status = label(0.62, 24, "Loading...", 18)

gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
title.Text = Config.GAME_NAME
subtitle.Text = Config.SETTING_LINE

if not game:IsLoaded() then
	game.Loaded:Wait()
end
status.Text = "Opening your ledger..."
while not player:GetAttribute("ProfileLoaded") and os.clock() - start < Config.LOADING_TIMEOUT do
	task.wait(0.1)
end
local left = Config.LOADING_MIN_SECONDS - (os.clock() - start)
if left > 0 then
	task.wait(left)
end

local info = TweenInfo.new(0.6)
for _, d in bg:GetChildren() do
	if d:IsA("TextLabel") then
		TweenService:Create(d, info, { TextTransparency = 1 }):Play()
	end
end
local fade = TweenService:Create(bg, info, { BackgroundTransparency = 1 })
fade:Play()
fade.Completed:Wait()
gui:Destroy()
