--!strict
-- LondonClient.ThroneRoomUI (stub): throne room protocol and audiences (COURT_PARLIAMENT §4).
-- Plain on purpose.
--   In the throne room: a line at the bottom with the state and who has the floor.
--   The audience book (a prompt by the door) opens a box for your reason; Ask / Withdraw.
--   For those who preside, a "Room" button (top left, under Court): Open / Closed / Session,
--   the floor (Extend, Take back), the queue (Call, Up, No), who's in the room (Floor, Invite),
--   and everyone else (Invite).
--   When you're called, a marker over the mark before the thrones.
-- Server: LondonServer.ThroneRoom (Room.Get / SetState / Request / Withdraw / Call / Decline / Up /
--   GiveFloor / Extend / TakeFloor / Invite / Uninvite; pushes State, Queue, Ask, Called, Mark,
--   Warn, Notice).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local ThroneRoomUI = {}

local ui = EconomyUI.ui
local C = ui.colours
local player = Players.LocalPlayer

local PRESIDING = { King = true, Queen = true, LordChamberlain = true, Royal = true }
local STATE_TEXT = { Open = "Open", Closed = "Closed", Session = "In session" }

local status: TextLabel
local button: TextButton
local panel: Frame
local body: ScrollingFrame
local ask: Frame
local askBox: TextBox
local askText: TextLabel
local state: { [string]: any } = { state = "Open" }
local floorEndsAt = 0
local view: { [string]: any } = {}
local marker: Part? = nil

local function request(action: string, args: { [string]: any }?): (boolean, any)
	local ok, res = Net.request("Room", action, args)
	if not ok then
		EconomyUI.toast(tostring(res), true)
	end
	return ok, res
end

local function zone(): BasePart?
	local rooms = workspace:FindFirstChild("PalaceInteriors")
	local room = rooms and rooms:FindFirstChild("ThroneRoom")
	local gameplay = room and room:FindFirstChild("Gameplay")
	local z = gameplay and gameplay:FindFirstChild(Config.THRONE_ROOM_ZONE)
	return if z and z:IsA("BasePart") then z else nil
end

local function inside(): boolean
	local z = zone()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not z or not hrp or not hrp:IsA("BasePart") then
		return false
	end
	local rel = z.CFrame:PointToObjectSpace(hrp.Position)
	local h = z.Size / 2
	return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y + 4 and math.abs(rel.Z) <= h.Z
end

local function clock(s: number): string
	local n = math.max(0, math.floor(s))
	return string.format("%d:%02d", n // 60, n % 60)
end

local function refreshStatus()
	local here = inside()
	status.Visible = here
	if here then
		local floorText = if state.floor then string.format(" · the floor: %s (%s)", state.floor, clock(floorEndsAt - os.clock())) else ""
		status.Text = "Throne room: " .. (STATE_TEXT[state.state] or "Open") .. floorText
		status.TextColor3 = if state.state == "Session" then C.GOLD else C.INK
	end
	button.Visible = player:GetAttribute("CharSlot") ~= nil and PRESIDING[Roles.roleOf(player)] == true
	if not button.Visible then
		panel.Visible = false
	end
end

local render: () -> ()

local function fetch()
	local ok, res = Net.request("Room", "Get")
	if ok then
		view = res
		if panel.Visible then
			render()
		end
	end
end

-- The server answers every change with a Room.Queue push to those who preside, so no re-fetch.
local function act(action: string, args: { [string]: any }?)
	request(action, args)
end

render = function()
	ui.clear(body)
	local o = ui.counter()
	if not view.presides then
		ui.line(body, o(), "Only the King or Queen, or the Lord Chamberlain, presides here.", C.MUTED, 16)
		return
	end
	local _, states = ui.row(body, o(), "Protocol", { { "Open" }, { "Closed" }, { "Session" } }, 76)
	for k, s in { "Open", "Closed", "Session" } do
		if view.state == s then
			states[k].Text = "• " .. s
		end
		states[k].Activated:Connect(function()
			act("SetState", { state = s })
		end)
	end
	if view.floor then
		local _, f = ui.row(body, o(), string.format("The floor: %s (%s)", view.floor, clock(view.floorSeconds or 0)), { { "Extend" }, { "Take back" } }, 84)
		f[1].Activated:Connect(function()
			act("Extend")
		end)
		f[2].Activated:Connect(function()
			act("TakeFloor")
		end)
	end
	ui.line(body, o(), if #(view.queue or {}) > 0 then "Waiting for an audience:" else "Nobody is waiting for an audience.", C.GOLD, 17)
	for _, e in view.queue or {} do
		local target = Players:GetPlayerByUserId(e.userId)
		local _, b = ui.row(body, o(), string.format("%s: \"%s\"", e.name, e.reason), { { "Call" }, { "Up" }, { "No" } }, 56)
		for k, action in { "Call", "Up", "Decline" } do
			b[k].Activated:Connect(function()
				if target then
					act(action, { target = target })
				end
			end)
		end
	end
	local hereIds: { [number]: boolean } = {}
	if #(view.here or {}) > 0 then
		ui.line(body, o(), "In the room:", C.GOLD, 17)
	end
	for _, e in view.here or {} do
		hereIds[e.userId] = true
		local target = Players:GetPlayerByUserId(e.userId)
		local _, b = ui.row(body, o(), e.name, { { "Floor" }, { if e.guest then "Uninvite" else "Invite" } }, 84)
		b[1].Activated:Connect(function()
			if target then
				act("GiveFloor", { target = target })
			end
		end)
		b[2].Activated:Connect(function()
			if target then
				act(if e.guest then "Uninvite" else "Invite", { target = target })
			end
		end)
	end
	ui.line(body, o(), "Invite into a closed room:", C.MUTED, 16)
	for _, q in Players:GetPlayers() do
		if q ~= player and not hereIds[q.UserId] and q:GetAttribute("CharSlot") ~= nil then
			local name = q:GetAttribute("RPName") or q.DisplayName
			local _, b = ui.row(body, o(), tostring(name), { { "Invite" } }, 84)
			b[1].Activated:Connect(function()
				act("Invite", { target = q })
			end)
		end
	end
end

local function showMark(pos: Vector3)
	if marker then
		marker:Destroy()
	end
	local p = Instance.new("Part")
	p.Name = "AudienceMarker"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(40, 40)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.Parent = p
	ui.text(bb, "TextLabel", { Text = "▼", TextColor3 = C.GOLD, TextStrokeTransparency = 0.3, TextSize = 30, Size = UDim2.fromScale(1, 1) })
	p.Parent = workspace
	marker = p
	task.delay(Config.FLOOR_SECONDS, function()
		if marker == p then
			p:Destroy()
			marker = nil
		end
	end)
end

function ThroneRoomUI.state(): ({ [string]: any }, { [string]: any })
	return state, view
end

function ThroneRoomUI.openAsk()
	askBox.Text = ""
	local ok, res = Net.request("Room", "Get")
	local place = if ok then res.place else nil
	askText.Text = if place then string.format("You're number %d in the queue.", place) else string.format("Why do you seek an audience? (up to %d letters)", Config.AUDIENCE_REASON_MAX)
	ask.Visible = true
end

function ThroneRoomUI.init()
	local gui = EconomyUI.gui()
	status = ui.text(gui, "TextLabel", {
		Name = "RoomStatus",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -92), -- above the toast line
		Size = UDim2.fromOffset(380, 24),
		TextSize = 17,
		TextStrokeTransparency = 0.5,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = false,
	})
	button = ui.button(gui, "Room", { Name = "RoomButton", Position = UDim2.fromOffset(12, 172), Size = UDim2.fromOffset(96, 28), TextSize = 16, Visible = false })
	panel, body = ui.panel("RoomPanel", "The throne room")
	button.Activated:Connect(function()
		if panel.Visible then
			panel.Visible = false
		else
			panel.Visible = true
			fetch()
			render()
		end
	end)

	ask = Instance.new("Frame")
	ask.Name = "AudienceAsk"
	ask.AnchorPoint = Vector2.new(0.5, 0.5)
	ask.Position = UDim2.fromScale(0.5, 0.5)
	ask.Size = UDim2.fromOffset(340, 130)
	ask.BackgroundColor3 = C.PAPER
	ask.BorderSizePixel = 0
	ask.Visible = false
	ask.Parent = gui
	askText = ui.text(ask, "TextLabel", { Name = "Text", TextSize = 16, TextWrapped = true, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 36) })
	askBox = ui.text(ask, "TextBox", {
		Name = "Reason",
		Text = "",
		PlaceholderText = "To ask for…",
		PlaceholderColor3 = C.MUTED,
		ClearTextOnFocus = false,
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(34, 30, 26),
		TextSize = 16,
		Position = UDim2.fromOffset(10, 44),
		Size = UDim2.new(1, -20, 0, 30),
	})
	local go = ui.button(ask, "Ask", { Name = "Ask", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -8), Size = UDim2.fromOffset(96, 32) })
	local withdraw = ui.button(ask, "Withdraw", { Name = "Withdraw", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(96, 32) })
	local cancel = ui.button(ask, "Close", { Name = "Close", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.fromOffset(96, 32) })
	go.Activated:Connect(function()
		if askBox.Text == "" then
			EconomyUI.toast("Give a reason.", true)
			return
		end
		if request("Request", { reason = askBox.Text }) then
			ask.Visible = false
		end
	end)
	withdraw.Activated:Connect(function()
		if request("Withdraw") then
			ask.Visible = false
			EconomyUI.toast("You've left the queue.")
		end
	end)
	cancel.Activated:Connect(function()
		ask.Visible = false
	end)

	Net.listen("Room", "State", function(msg)
		state = msg
		floorEndsAt = os.clock() + (msg.floorSeconds or 0)
		refreshStatus()
	end)
	Net.listen("Room", "Queue", function(msg)
		view = msg
		if panel.Visible then
			render()
		end
	end)
	Net.listen("Room", "Ask", function()
		ThroneRoomUI.openAsk()
	end)
	Net.listen("Room", "Mark", function(msg)
		if typeof(msg.pos) == "Vector3" then
			showMark(msg.pos)
		end
	end)
	for _, action in { "Called", "Notice" } do
		Net.listen("Room", action, function(msg)
			if type(msg.text) == "string" then
				EconomyUI.toast(msg.text)
			end
		end)
	end
	Net.listen("Room", "Warn", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text, true)
		end
	end)
	for _, attr in { Roles.ROLE_ATTR, "CharSlot" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshStatus)
	end
	refreshStatus()
	task.spawn(function()
		local ok, res = Net.request("Room", "Get")
		if ok then
			state = { state = res.state, floor = res.floor }
			floorEndsAt = os.clock() + (res.floorSeconds or 0)
		end
		while true do
			task.wait(0.5)
			refreshStatus()
		end
	end)
end

return ThroneRoomUI
