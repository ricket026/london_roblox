--!strict
-- LondonClient.Activities.Strength (stub UI): the swing meter for test your strength.
-- Draws Shared.Meter on the server clock and sends the press time; the server scores it.
-- Swing: the SWING button, F, or a gamepad R2 / A.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Meter = require(Shared:WaitForChild("Meter"))

local Strength = {}

local gui: ScreenGui
local marker: Frame
local info: TextLabel
local session: { start: number, period: number, left: number }? = nil
local stepConn: RBXScriptConnection? = nil

local ACTION = "LondonStrengthSwing"

local function swing()
	if not session or session.left <= 0 then
		return
	end
	Net.send("Activity", "StrengthSwing", { t = workspace:GetServerTimeNow() })
end

local function stop()
	session = nil
	ContextActionService:UnbindAction(ACTION)
	if stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
	gui.Enabled = false
end

function Strength.init(_activities: any)
	gui = Instance.new("ScreenGui")
	gui.Name = "StrengthMeter"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	-- Everything stays within ~130 px of the centre: a landscape phone is ~360 px tall.
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(1, 0.5)
	bar.Position = UDim2.new(0.5, -110, 0.5, 0)
	bar.Size = UDim2.new(0, 40, 0.7, 0)
	local barLimit = Instance.new("UISizeConstraint")
	barLimit.MaxSize = Vector2.new(40, 300)
	barLimit.Parent = bar
	bar.BackgroundColor3 = Color3.fromRGB(40, 34, 28)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local bellLine = Instance.new("Frame") -- the gold zone at the top that rings the bell
	bellLine.Size = UDim2.new(1, 0, 1 - Config.STRENGTH_BELL / 100, 0)
	bellLine.BackgroundColor3 = Color3.fromRGB(200, 160, 60)
	bellLine.BorderSizePixel = 0
	bellLine.Parent = bar
	marker = Instance.new("Frame")
	marker.AnchorPoint = Vector2.new(0, 0.5)
	marker.Size = UDim2.new(1, 12, 0, 6)
	marker.Position = UDim2.new(0, -6, 1, 0)
	marker.BackgroundColor3 = Color3.fromRGB(240, 232, 214)
	marker.BorderSizePixel = 0
	marker.Parent = bar
	info = Instance.new("TextLabel")
	info.AnchorPoint = Vector2.new(0, 1)
	info.Position = UDim2.new(0.5, -90, 0.5, -6)
	info.Size = UDim2.fromOffset(320, 50)
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.BackgroundTransparency = 1
	info.Font = Enum.Font.Garamond
	info.TextSize = 24
	info.TextColor3 = Color3.fromRGB(240, 232, 214)
	info.TextStrokeTransparency = 0.5
	info.Parent = gui
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0, 0)
	button.Position = UDim2.new(0.5, -90, 0.5, 6)
	button.Size = UDim2.fromOffset(180, 56)
	button.BackgroundColor3 = Color3.fromRGB(150, 40, 35)
	button.Font = Enum.Font.GaramondBold
	button.TextSize = 28
	button.TextColor3 = Color3.fromRGB(250, 230, 180)
	button.Text = "SWING"
	button.Parent = gui
	button.Activated:Connect(swing)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Net.listen("Activity", "StrengthStart", function(msg)
		session = { start = msg.start, period = msg.period, left = msg.swings }
		info.Text = string.format("%d swings. Hit the gold for the bell!", msg.swings)
		gui.Enabled = true
		ContextActionService:BindAction(ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				swing()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonA)
		if stepConn then
			stepConn:Disconnect()
		end
		stepConn = RunService.RenderStepped:Connect(function()
			local s = session
			if not s then
				return
			end
			local elapsed = workspace:GetServerTimeNow() - s.start
			local v = if elapsed < 0 then 0 else Meter.value(elapsed, s.period)
			marker.Position = UDim2.new(0, -6, 1 - v, 0)
		end)
	end)
	Net.listen("Activity", "StrengthResult", function(msg)
		if session then
			session.left = msg.left
		end
		local head = if msg.bell then string.format("DING! %d", msg.score) else tostring(msg.score)
		info.Text = head .. (if msg.left > 0 then string.format("   (%d left)", msg.left) else "")
	end)
	Net.listen("Activity", "StrengthEnd", function(msg)
		info.Text = string.format("Best: %d", msg.best)
		session = nil
		task.delay(1.5, function()
			if not session then
				stop()
			end
		end)
	end)
end

return Strength
