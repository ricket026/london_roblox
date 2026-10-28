--!strict
-- LondonClient.EventUI (stub): events (EVENTS.md §1). Plain on purpose.
--   A line under the proclamation banner while something is on: its name, the step (or "begins
--   in"), time left and how far away it is.
--   "Events" in the More menu (top right): what's on (sign up to a part, leave; the host:
--   Next step, End) and, for those who may host, what they can start.
-- Server: LondonServer.Events (Event.Get / Start / SignUp / Leave / Advance / End; pushes
--   Announce, Step, Finished, Notice).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local EventUI = {}

local ui = EconomyUI.ui
local C = ui.colours
local player = Players.LocalPlayer

local line: TextLabel
local button: TextButton
local panel: Frame
local body: ScrollingFrame
-- what's on, by id: { name, place, pos?, text, endsAt, started }
local on: { [string]: { [string]: any } } = {}
local view: { [string]: any } = {}

local function request(action: string, args: { [string]: any }?): boolean
	local ok, res = Net.request("Event", action, args)
	if not ok then
		EconomyUI.toast(tostring(res), true)
	end
	return ok
end

local function clock(s: number): string
	local n = math.max(0, math.floor(s))
	return string.format("%d:%02d", n // 60, n % 60)
end

local function rootPos(): Vector3?
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp.Position else nil
end

local function refreshLine()
	local best: { [string]: any }? = nil
	for _, e in on do
		if not best or e.endsAt < best.endsAt then
			best = e
		end
	end
	local here = player:GetAttribute("CharSlot") ~= nil
	line.Visible = here and best ~= nil
	button.Visible = here
	if not here then
		panel.Visible = false
	end
	local e = best
	if e then
		local me, pos = rootPos(), e.pos
		local far = if typeof(pos) == "Vector3" and me then string.format(" · %d studs", math.floor((pos - me).Magnitude)) else ""
		local what = if e.started then e.text else "begins in " .. clock(e.endsAt - os.clock())
		line.Text = string.format("%s · %s%s%s", e.name, what, if e.started then " · " .. clock(e.endsAt - os.clock()) else "", far)
	end
end

local render: () -> ()

local function fetch()
	local ok, res = Net.request("Event", "Get")
	if ok then
		view = res
		render()
	end
end

render = function()
	ui.clear(body)
	local o = ui.counter()
	if #(view.running or {}) == 0 then
		ui.line(body, o(), "Nothing is on just now.", C.MUTED, 16)
	end
	for _, r in view.running or {} do
		ui.line(body, o(), string.format("%s at %s · %s", r.name, r.place, if r.step then r.step else "gathering, " .. clock(r.seconds)), C.GOLD, 17)
		for _, role in r.roles or {} do
			local taken = #role.names
			local label = string.format("%s (%d/%d)%s", role.name, taken, role.max, if taken > 0 then ": " .. table.concat(role.names, ", ") else "")
			local mine = r.mine == role.id
			local _, b = ui.row(body, o(), label, { { if mine then "Leave" else "Join" } }, 76)
			b[1].Activated:Connect(function()
				if mine then
					request("Leave", { id = r.id })
				else
					request("SignUp", { id = r.id, role = role.id })
				end
				fetch()
			end)
		end
		if r.hosting then
			local _, b = ui.row(body, o(), "You're hosting", { { "Next step" }, { "End" } }, 96)
			b[1].Activated:Connect(function()
				request("Advance", { id = r.id })
				fetch()
			end)
			b[2].Activated:Connect(function()
				request("End", { id = r.id })
				fetch()
			end)
		end
	end
	if #(view.startable or {}) > 0 then
		ui.line(body, o(), "You may hold:", C.GOLD, 17)
	end
	for _, s in view.startable or {} do
		local _, b = ui.row(body, o(), s.name .. " at " .. s.place .. (if s.why then " · " .. s.why else ""), { { "Start" } }, 76)
		b[1].Activated:Connect(function()
			if request("Start", { id = s.id }) then
				EconomyUI.toast(s.name .. " is announced.")
			end
			fetch()
		end)
	end
end

function EventUI.state(): { [string]: { [string]: any } }
	return on
end

function EventUI.init()
	local gui = EconomyUI.gui()
	line = ui.text(gui, "TextLabel", {
		Name = "EventLine",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(420, 22),
		TextSize = 16,
		TextColor3 = C.GOLD,
		TextStrokeTransparency = 0.5,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = false,
	})
	button = EconomyUI.menuButton("EventsButton", "Events", 10)
	panel, body = ui.panel("EventPanel", "Events")
	button.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			fetch()
		end
	end)
	Net.listen("Event", "Announce", function(msg)
		on[msg.id] = { name = msg.name, place = msg.place, pos = msg.pos, text = "", endsAt = os.clock() + (msg.seconds or 0), started = false }
		refreshLine()
		if panel.Visible then
			fetch()
		end
	end)
	Net.listen("Event", "Step", function(msg)
		local e = on[msg.id] or { name = msg.name, place = "" }
		e.text, e.endsAt, e.started = msg.text, os.clock() + (msg.seconds or 0), true
		on[msg.id] = e
		refreshLine()
	end)
	Net.listen("Event", "Finished", function(msg)
		on[msg.id] = nil
		refreshLine()
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
		if panel.Visible then
			fetch()
		end
	end)
	Net.listen("Event", "Notice", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)
	player:GetAttributeChangedSignal("CharSlot"):Connect(refreshLine)
	refreshLine()
	task.spawn(function()
		local ok, res = Net.request("Event", "Get")
		if ok then
			for _, r in res.running or {} do
				on[r.id] = { name = r.name, place = r.place, pos = r.pos, text = r.step or "", endsAt = os.clock() + (r.seconds or 0), started = r.phase == "step" }
			end
		end
		while true do
			task.wait(0.5)
			refreshLine()
		end
	end)
end

return EventUI
