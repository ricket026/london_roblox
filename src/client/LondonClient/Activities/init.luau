--!strict
-- LondonClient.Activities (stub UI): reward toasts and notices for every activity, plus the
-- per-activity UIs in child modules (Strength, Chess). Plain until the UI pass (ART §8, M8).
-- Server: LondonServer.Activities (pushes Activity.Reward / Activity.Notice).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Activities = {}
Activities.CHILDREN = { "Strength", "Chess" }

local INK = Color3.fromRGB(240, 232, 214)
local GOLD = Color3.fromRGB(240, 205, 120)

local gui: ScreenGui
local stack: Frame
local order = 0

-- A short message at the right of the screen that fades after a few seconds.
function Activities.toast(lines: { string }, colour: Color3?)
	if #lines == 0 then
		return
	end
	order += 1
	local f = Instance.new("TextLabel")
	f.LayoutOrder = order
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Size = UDim2.new(1, 0, 0, 0)
	f.BackgroundColor3 = Color3.fromRGB(18, 16, 14)
	f.BackgroundTransparency = 0.2
	f.BorderSizePixel = 0
	f.Font = Enum.Font.Garamond
	f.TextSize = 20
	f.TextWrapped = true
	f.TextColor3 = colour or INK
	f.Text = table.concat(lines, "\n")
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = f
	f.Parent = stack
	task.delay(4, function()
		local info = TweenInfo.new(0.6)
		TweenService:Create(f, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.6)
		f:Destroy()
	end)
end

local function onReward(msg: any)
	local lines = {}
	local gold = false
	if type(msg.pence) == "string" then
		table.insert(lines, "+" .. msg.pence)
	end
	if type(msg.xp) == "number" and type(msg.hobby) == "string" then
		table.insert(lines, string.format("+%d %s", msg.xp, msg.hobby))
		if msg.levelUp then
			table.insert(lines, string.format("%s is now level %d!", msg.hobby, msg.level))
			gold = true
		end
	end
	if type(msg.items) == "table" then
		for _, it in msg.items do
			if it.new then
				table.insert(lines, "New for your collection: " .. tostring(it.name))
				gold = true
			else
				table.insert(lines, "Found: " .. tostring(it.name))
			end
		end
	end
	if msg.capped then
		table.insert(lines, "(No more pay from pastimes this hour)")
	end
	Activities.toast(lines, if gold then GOLD else nil)
end

function Activities.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Activities"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	stack = Instance.new("Frame")
	stack.AnchorPoint = Vector2.new(1, 0.5)
	stack.Position = UDim2.new(1, -12, 0.45, 0)
	stack.Size = UDim2.fromOffset(280, 300)
	stack.BackgroundTransparency = 1
	stack.Parent = gui
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Padding = UDim.new(0, 6)
	list.Parent = stack
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Net.listen("Activity", "Reward", onReward)
	Net.listen("Activity", "Notice", function(msg)
		if type(msg.text) == "string" then
			Activities.toast({ msg.text })
		end
	end)
	for _, name in Activities.CHILDREN do
		require(script:WaitForChild(name) :: ModuleScript).init(Activities)
	end
end

return Activities
