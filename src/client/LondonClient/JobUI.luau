--!strict
-- LondonClient.JobUI (stub): the job tracker (JOBS.md §1 "Tracker HUD"). Plain on purpose.
--   Top left: job, rank and XP, the next step, its distance, pay this shift, and Skip.
--   A marker over the next stop, and (for "hold" steps) a prompt there to hold.
-- Server: LondonServer.Jobs (Job.Get / Hold / Skip; pushes Task, Done, Off, Notice).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local JobUI = {}

local ui = EconomyUI.ui
local C = ui.colours
local player = Players.LocalPlayer

local state: { [string]: any } = {}
local frame: Frame
local headLabel: TextLabel
local stepLabel: TextLabel
local footLabel: TextLabel
local marker: Part? = nil
local prompt: ProximityPrompt? = nil

local function currentStep(): { [string]: any }?
	local steps = state.steps or {}
	return steps[state.index or 0]
end

local function clearMarker()
	if marker then
		marker:Destroy()
		marker, prompt = nil, nil
	end
end

local function placeMarker()
	clearMarker()
	local s = currentStep()
	if not s or typeof(s.pos) ~= "Vector3" then
		return
	end
	local p = Instance.new("Part")
	p.Name = "JobMarker"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(s.pos)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(40, 40)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.Parent = p
	ui.text(bb, "TextLabel", { Text = "▼", TextColor3 = C.GOLD, TextStrokeTransparency = 0.3, TextSize = 30, Size = UDim2.fromScale(1, 1) })
	if s.kind == "hold" then
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = s.action or "Do"
		pp.ObjectText = state.job or "Job"
		pp.HoldDuration = s.seconds or 1
		pp.MaxActivationDistance = math.max(6, (s.radius or 8) - 1)
		pp.RequiresLineOfSight = false
		pp.Parent = p
		local index = state.index
		pp.Triggered:Connect(function()
			local ok, res = Net.request("Job", "Hold", { step = index })
			if not ok then
				EconomyUI.toast(tostring(res), true)
			end
		end)
		prompt = pp
	end
	p.Parent = workspace
	marker = p
end

local function rootPos(): Vector3?
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp.Position else nil
end

local function refresh()
	local onDuty = type(state.job) == "string"
	frame.Visible = onDuty and player:GetAttribute("CharSlot") ~= nil
	if not onDuty then
		clearMarker()
		return
	end
	headLabel.Text = string.format("%s · rank %d · %d%s XP", state.job, state.rank or 1, state.xp or 0, if state.nextXp then "/" .. state.nextXp else "")
	local s = currentStep()
	stepLabel.Text = if s then s.text else "Waiting for work…"
	local pos, here = s and s.pos, rootPos()
	local dist = if typeof(pos) == "Vector3" and here then math.floor((pos - here).Magnitude) else nil
	footLabel.Text = (if dist then dist .. " studs · " else "") .. "this shift " .. (state.shiftText or "0d")
end

function JobUI.apply(msg: { [string]: any })
	state = msg
	placeMarker()
	refresh()
end

function JobUI.state(): { [string]: any }
	return state
end

function JobUI.init()
	local gui = EconomyUI.gui()
	frame = Instance.new("Frame")
	frame.Name = "JobTracker"
	frame.Position = UDim2.fromOffset(12, 44)
	frame.Size = UDim2.fromOffset(280, 92)
	frame.BackgroundColor3 = C.PAPER
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	headLabel = ui.text(frame, "TextLabel", { Name = "Head", Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 20), TextSize = 16, TextColor3 = C.GOLD, TextXAlignment = Enum.TextXAlignment.Left })
	stepLabel = ui.text(frame, "TextLabel", { Name = "Step", Position = UDim2.fromOffset(8, 24), Size = UDim2.new(1, -16, 0, 40), TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	footLabel = ui.text(frame, "TextLabel", { Name = "Foot", Position = UDim2.fromOffset(8, 66), Size = UDim2.new(1, -80, 0, 20), TextSize = 14, TextColor3 = C.MUTED, TextXAlignment = Enum.TextXAlignment.Left })
	local skip = ui.button(frame, "Skip", { Name = "Skip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -6), Size = UDim2.fromOffset(60, 24), TextSize = 15 })
	skip.Activated:Connect(function()
		local ok, res = Net.request("Job", "Skip")
		if not ok then
			EconomyUI.toast(tostring(res), true)
		end
	end)
	Net.listen("Job", "Task", JobUI.apply)
	Net.listen("Job", "Off", function()
		JobUI.apply({})
	end)
	Net.listen("Job", "Done", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)
	Net.listen("Job", "Notice", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)
	player:GetAttributeChangedSignal("CharSlot"):Connect(refresh)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if frame.Visible then
				refresh()
			end
		end
	end)
end

return JobUI
