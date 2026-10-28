--!strict
-- LondonClient.OnboardingUI (stub): the first five minutes and the "Next steps" list
-- (LOW_POP_AND_ONBOARDING §3-4). Plain on purpose.
--   The first time a character arrives on an account that hasn't seen the rules: the camera
--   sweeps down over the terminus (Skip), then the rules card (I agree), then the starter job
--   card (three jobs, or Not now).
--   Left side, under the top-left buttons: "Next steps" with the next goals and their bonus;
--   tap the heading to fold it away.
-- Server: LondonServer.Onboarding (Onboarding.Get / Arrived / AcceptRules / PickJob / HideGoals;
--   pushes Goals, Notice).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local OnboardingUI = {}

local ui = EconomyUI.ui
local C = ui.colours
local player = Players.LocalPlayer

local goalsFrame: Frame
local goalsHead: TextButton
local goalsBody: TextLabel
local card: Frame
local cardBody: ScrollingFrame
local cardTitle: TextLabel
local skip: TextButton
local goals: { [string]: any } = { goals = {} }
local flowRunning = false
local skipped = false

local function request(action: string, args: { [string]: any }?): (boolean, any)
	local ok, res = Net.request("Onboarding", action, args)
	if not ok then
		EconomyUI.toast(tostring(res), true)
	end
	return ok, res
end

local function renderGoals()
	local here = player:GetAttribute("CharSlot") ~= nil
	local list = goals.goals or {}
	goalsFrame.Visible = here and #list > 0
	goalsHead.Text = string.format("Next steps (%d/%d) %s", goals.done or 0, goals.of or 0, if goals.hidden then "▸" else "▾")
	goalsBody.Visible = not goals.hidden
	local lines = {}
	for _, g in list do
		table.insert(lines, string.format("• %s (%s)", g.text, g.bonus))
	end
	goalsBody.Text = table.concat(lines, "\n")
	goalsFrame.Size = UDim2.fromOffset(240, if goals.hidden then 24 else 24 + 34 * #list)
end

-- The arrival: the camera sweeps from above the terminus down to the player.
local function arrival()
	task.wait(0.3) -- let the spawn place the character on the forecourt first
	local cam = workspace.CurrentCamera
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not cam or not hrp or not hrp:IsA("BasePart") then
		return
	end
	skipped = false
	skip.Visible = true
	local a = Config.ARRIVAL_CAMERA
	local target = hrp.Position
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(Vector3.new(a.x, a.y, a.z), target)
	local tween = TweenService:Create(cam, TweenInfo.new(Config.ARRIVAL_SECONDS, Enum.EasingStyle.Sine), {
		CFrame = CFrame.lookAt(target + Vector3.new(0, 8, 16), target),
	})
	tween:Play()
	local t = 0
	while t < Config.ARRIVAL_SECONDS and not skipped do
		t += task.wait(0.1)
	end
	tween:Cancel()
	cam.CameraType = Enum.CameraType.Custom
	skip.Visible = false
	request("Arrived")
end

local function showCard(title: string)
	cardTitle.Text = title
	ui.clear(cardBody)
	card.Visible = true
end

-- Waits for one of the card's buttons; returns its value.
local function choose(options: { { any } }): any
	local picked: any = nil
	local o = ui.counter()
	for _, opt in options do
		local b = ui.button(cardBody, opt[1], { LayoutOrder = o(), Size = UDim2.new(1, 0, 0, 34), TextSize = 17 })
		b.Activated:Connect(function()
			picked = opt[2]
		end)
	end
	while picked == nil do
		task.wait(0.1)
	end
	return picked
end

-- Arrival → rules → starter job, for an account that hasn't seen them.
function OnboardingUI.run(view: { [string]: any })
	if flowRunning then
		return
	end
	flowRunning = true
	if not view.rulesAccepted then
		arrival()
		showCard("Welcome to London, 1897")
		local o = ui.counter()
		ui.line(cardBody, o(), "Before you go out into the city:", C.GOLD, 18)
		for _, r in view.rules or {} do
			ui.line(cardBody, o(), "• " .. r, C.INK, 17)
		end
		while true do
			choose({ { "I agree", true } })
			if request("AcceptRules") then
				break
			end
		end
	end
	if not view.starterPicked then
		showCard("Your first job")
		local o = ui.counter()
		ui.line(cardBody, o(), "Pick one to start earning. You can change it any time at the Station button.", C.INK, 16)
		local options = {}
		for _, s in view.starters or {} do
			table.insert(options, { string.format("%s: %s", s.name, s.blurb), s.id })
		end
		table.insert(options, { "Not now", false })
		while true do
			local job = choose(options)
			if request("PickJob", if job then { job = job } else {}) then
				if job then
					EconomyUI.toast("You're on duty: follow the marker.")
				end
				break
			end
		end
	end
	card.Visible = false
	flowRunning = false
end

function OnboardingUI.state(): { [string]: any }
	return goals
end

function OnboardingUI.init()
	local gui = EconomyUI.gui()
	goalsFrame = Instance.new("Frame")
	goalsFrame.Name = "Goals"
	goalsFrame.Position = UDim2.fromOffset(12, 206)
	goalsFrame.Size = UDim2.fromOffset(240, 90)
	goalsFrame.BackgroundColor3 = C.PAPER
	goalsFrame.BackgroundTransparency = 0.25
	goalsFrame.BorderSizePixel = 0
	goalsFrame.Visible = false
	goalsFrame.Parent = gui
	goalsHead = ui.text(goalsFrame, "TextButton", { Name = "Head", Text = "Next steps", Font = Enum.Font.GaramondBold, TextSize = 16, TextColor3 = C.GOLD, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 20) })
	goalsBody = ui.text(goalsFrame, "TextLabel", { Name = "Body", TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(8, 24), Size = UDim2.new(1, -16, 1, -26) })
	goalsHead.Activated:Connect(function()
		local ok, res = request("HideGoals", { hidden = not goals.hidden })
		if ok then
			goals = res
			renderGoals()
		end
	end)

	card, cardBody, cardTitle = ui.panel("Welcome", "Welcome")
	cardTitle.Name = "Title"
	local close = card:FindFirstChild("Close")
	if close and close:IsA("GuiObject") then
		close.Visible = false -- the card is answered, not closed
	end
	skip = ui.button(gui, "Skip", { Name = "SkipArrival", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -60), Size = UDim2.fromOffset(90, 34), Visible = false })
	skip.Activated:Connect(function()
		skipped = true
	end)

	Net.listen("Onboarding", "Goals", function(msg)
		goals = msg
		renderGoals()
	end)
	Net.listen("Onboarding", "Notice", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)
	local function arrived()
		renderGoals()
		if player:GetAttribute("CharSlot") == nil then
			return
		end
		task.spawn(function()
			local ok, view = Net.request("Onboarding", "Get")
			if not ok then
				return
			end
			goals = view
			renderGoals()
			if not view.rulesAccepted or not view.starterPicked then
				if not player.Character then
					player.CharacterAdded:Wait()
				end
				OnboardingUI.run(view)
			end
		end)
	end
	player:GetAttributeChangedSignal("CharSlot"):Connect(arrived)
	arrived()
end

return OnboardingUI
