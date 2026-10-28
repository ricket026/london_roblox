--!strict
-- LondonClient.DailyUI (stub): what's on and what to do today (PLAYER_GATHERING §2, §4). Plain on purpose.
--   Under the clock: the next appointment at a hub and a countdown ("Now:" while it's on, with
--   how far away it is). A "Today" button opens the day's tasks and the stipend streak.
-- Server: LondonServer.Appointments (Appointment.Get; pushes Next, Notice), LondonServer.Daily
--   (Daily.Get; pushes State, Notice).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local DailyUI = {}

local ui = EconomyUI.ui
local C = ui.colours
local player = Players.LocalPlayer

local nextApp: { [string]: any } = {}
local today: { [string]: any } = { tasks = {} }
local label: TextLabel
local button: TextButton
local panel: Frame
local body: ScrollingFrame

function DailyUI.countdown(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function rootPos(): Vector3?
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp.Position else nil
end

local function refresh()
	local here = player:GetAttribute("CharSlot") ~= nil
	label.Visible = here and nextApp.title ~= nil
	button.Visible = here
	if not here then
		panel.Visible = false
	end
	if nextApp.title then
		local t = workspace:GetServerTimeNow()
		if t >= (nextApp.startsAt or 0) and t < (nextApp.endsAt or 0) then
			local pos, me = nextApp.pos, rootPos()
			local far = if typeof(pos) == "Vector3" and me then string.format(" · %d studs", math.floor((pos - me).Magnitude)) else ""
			label.Text = string.format("Now: %s at %s%s", nextApp.title, nextApp.place, far)
			label.TextColor3 = C.GOLD
		else
			label.Text = string.format("Next: %s at %s · %s", nextApp.title, nextApp.place, DailyUI.countdown((nextApp.startsAt or t) - t))
			label.TextColor3 = C.INK
		end
	end
	local done = 0
	for _, task in today.tasks or {} do
		done += if task.done then 1 else 0
	end
	button.Text = string.format("Today %d/%d", done, #(today.tasks or {}))
end

local function render()
	ui.clear(body)
	local o = ui.counter()
	ui.line(body, o(), string.format("Stipend streak: day %d (come back tomorrow for more).", today.streak or 0), C.MUTED, 16)
	for _, task in today.tasks or {} do
		local mark = if task.done then "✓ " else ""
		ui.line(body, o(), string.format("%s%s · %d/%d · %s", mark, task.text, task.n, task.of, today.payText or ""), if task.done then C.MUTED else C.INK)
	end
	if nextApp.title then
		ui.line(body, o(), string.format("Next appointment: %s at %s. Be there for half a minute for a memento.", nextApp.title, nextApp.place), C.MUTED, 15)
	end
end

function DailyUI.state(): ({ [string]: any }, { [string]: any })
	return nextApp, today
end

function DailyUI.init()
	local gui = EconomyUI.gui()
	label = ui.text(gui, "TextLabel", {
		Name = "Appointment",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 32),
		Size = UDim2.fromOffset(380, 22),
		TextSize = 16,
		TextStrokeTransparency = 0.5,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = false,
	})
	button = ui.button(gui, "Today", { Name = "TodayButton", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(96, 26), TextSize = 15, Visible = false })
	panel, body = ui.panel("DailyPanel", "Today")
	button.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			render()
		end
	end)
	Net.listen("Appointment", "Next", function(msg)
		nextApp = msg
		refresh()
	end)
	Net.listen("Appointment", "Notice", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)
	Net.listen("Daily", "State", function(msg)
		today = msg
		refresh()
		if panel.Visible then
			render()
		end
	end)
	Net.listen("Daily", "Notice", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)
	player:GetAttributeChangedSignal("CharSlot"):Connect(refresh)
	task.spawn(function()
		while not player:GetAttribute("ProfileLoaded") do
			task.wait(0.2)
		end
		local ok, res = Net.request("Appointment", "Get")
		if ok then
			nextApp = res
		end
		local okDaily, d = Net.request("Daily", "Get")
		if okDaily then
			today = d
		end
		refresh()
		while true do
			task.wait(0.5)
			refresh()
		end
	end)
end

return DailyUI
