--!strict
-- LondonClient.IdentityUI (stub): first-join name picker and the station/role menu (M1).
-- Plain on purpose: the real look comes from the user's references in the UI pass (ART §8, M8).
-- Server: LondonServer.Identity (Identity.Get / SetName / ChooseRole, pushes State and Seats).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Names = require(Shared:WaitForChild("Names"))
local Stations = require(Shared:WaitForChild("Stations"))

local IdentityUI = {}

local INK = Color3.fromRGB(230, 220, 200)
local PAPER = Color3.fromRGB(18, 16, 14)
local MUTED = Color3.fromRGB(150, 140, 125)
local ERROR = Color3.fromRGB(220, 120, 100)

local player = Players.LocalPlayer
local rng = Random.new()
local current: { [string]: any } = {}
local seats: { [string]: number } = {}

local gui: ScreenGui
local namePanel: Frame
local firstBox: TextBox
local lastBox: TextBox
local nameError: TextLabel
local roleButton: TextButton
local rolePanel: ScrollingFrame
local roleError: TextLabel
local rows: { [string]: TextButton } = {}

local function text(parent: Instance, cls: string, props: { [string]: any }): any
	local o = Instance.new(cls :: any) :: any
	o.BackgroundTransparency = 1
	o.Font = Enum.Font.Garamond
	o.TextColor3 = INK
	o.TextSize = 20
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function button(parent: Instance, label: string, props: { [string]: any }): TextButton
	local b = text(parent, "TextButton", props)
	b.Text = label
	b.BackgroundTransparency = 0
	b.BackgroundColor3 = Color3.fromRGB(60, 52, 42)
	b.AutoButtonColor = true
	return b
end

local function panel(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = PAPER
	f.BackgroundTransparency = 0.1
	f.BorderSizePixel = 0
	local any: any = f
	for k, v in props do
		any[k] = v
	end
	f.Parent = gui
	return f
end

-- Name picker ----------------------------------------------------------------------
local function buildNamePanel()
	namePanel = panel({
		Name = "NamePanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0, 270),
		Visible = false,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(440, 270)
	limit.Parent = namePanel
	text(namePanel, "TextLabel", { Text = "What is your name?", TextSize = 30, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 34) })
	text(namePanel, "TextLabel", { Text = "It will be shown over your head.", TextColor3 = MUTED, TextSize = 18, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 22) })
	local function box(x: number, placeholder: string): TextBox
		local b = text(namePanel, "TextBox", {
			PlaceholderText = placeholder,
			Text = "",
			ClearTextOnFocus = false,
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(38, 34, 29),
			Position = UDim2.new(x, 8, 0, 86),
			Size = UDim2.new(0.5, -16, 0, 40),
		})
		b:GetPropertyChangedSignal("Text"):Connect(function()
			local len = utf8.len(b.Text) or 0
			if len > Config.NAME_MAX then
				b.Text = string.sub(b.Text, 1, (utf8.offset(b.Text, Config.NAME_MAX + 1) or (#b.Text + 1)) - 1)
			end
		end)
		return b
	end
	firstBox = box(0, "First name")
	lastBox = box(0.5, "Last name")
	nameError = text(namePanel, "TextLabel", { Text = "", TextColor3 = ERROR, TextSize = 17, TextWrapped = true, Position = UDim2.new(0, 12, 0, 134), Size = UDim2.new(1, -24, 0, 44) })
	local suggest = button(namePanel, "Suggest", { Position = UDim2.new(0, 8, 1, -60), Size = UDim2.new(0.5, -16, 0, 44) })
	local confirm = button(namePanel, "Confirm", { Position = UDim2.new(0.5, 8, 1, -60), Size = UDim2.new(0.5, -16, 0, 44) })

	suggest.Activated:Connect(function()
		firstBox.Text, lastBox.Text = Names.suggest(rng)
		nameError.Text = ""
	end)
	local busy = false
	confirm.Activated:Connect(function()
		if busy then
			return
		end
		-- explain local rule breaks without a round trip
		for _, b in { firstBox, lastBox } do
			local _, why = Names.cleanPart(b.Text)
			if why then
				nameError.Text = why
				return
			end
		end
		busy = true
		nameError.Text = "Checking..."
		local ok, res = Net.request("Identity", "SetName", { first = firstBox.Text, last = lastBox.Text })
		busy = false
		if ok then
			nameError.Text = ""
			IdentityUI.apply(res)
		else
			nameError.Text = tostring(res)
		end
	end)
end

-- Role menu --------------------------------------------------------------------------
local function rowText(r: Stations.Role): string
	local s = r.name
	if r.seats then
		s ..= string.format("  (%d/%d)", seats[r.id] or 0, r.seats)
	end
	if r.minPlaytime then
		s ..= string.format("  · %d h played", math.ceil(r.minPlaytime / 3600))
	end
	return s
end

local function refreshRows()
	for id, b in rows do
		local r = Stations.BY_ID[id]
		local full = r.seats ~= nil and (seats[id] or 0) >= r.seats
		local mine = current.role == id
		b.Text = (if mine then "▸ " else "") .. rowText(r)
		b.TextColor3 = if mine then Color3.fromRGB(240, 205, 120) elseif full then MUTED else INK
	end
	local r = Stations.BY_ID[current.role or Config.DEFAULT_ROLE]
	roleButton.Text = "Station: " .. (if r then r.name else "?")
end

local function buildRolePanel()
	roleButton = button(gui, "Station: Citizen", {
		Name = "RoleButton",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(220, 40),
	})
	rolePanel = Instance.new("ScrollingFrame")
	rolePanel.Name = "RolePanel"
	rolePanel.AnchorPoint = Vector2.new(0, 1)
	rolePanel.Position = UDim2.new(0, 12, 1, -60)
	rolePanel.Size = UDim2.new(0.9, 0, 0.6, 0)
	rolePanel.BackgroundColor3 = PAPER
	rolePanel.BackgroundTransparency = 0.1
	rolePanel.BorderSizePixel = 0
	rolePanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rolePanel.CanvasSize = UDim2.new()
	rolePanel.ScrollBarThickness = 6
	rolePanel.Visible = false
	rolePanel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(380, 520)
	limit.Parent = rolePanel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = rolePanel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = rolePanel

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	roleError = text(rolePanel, "TextLabel", { LayoutOrder = nextOrder(), Text = "", TextColor3 = ERROR, TextSize = 17, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	for _, station in Stations.ORDER do
		local shown = false
		for _, r in Stations.ROLES do
			if r.station ~= station or not Stations.selectable(r) then
				continue
			end
			if not shown then
				shown = true
				text(rolePanel, "TextLabel", { LayoutOrder = nextOrder(), Text = station, TextColor3 = MUTED, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 24) })
			end
			local b = button(rolePanel, r.name, { LayoutOrder = nextOrder(), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 34) })
			local p = Instance.new("UIPadding")
			p.PaddingLeft = UDim.new(0, 8)
			p.Parent = b
			text(rolePanel, "TextLabel", { LayoutOrder = nextOrder(), Text = r.blurb, TextColor3 = MUTED, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18) })
			rows[r.id] = b
			b.Activated:Connect(function()
				roleError.Text = ""
				local ok, res = Net.request("Identity", "ChooseRole", { role = r.id })
				if ok then
					IdentityUI.apply(res)
				else
					roleError.Text = tostring(res)
				end
			end)
		end
	end
	roleButton.Activated:Connect(function()
		rolePanel.Visible = not rolePanel.Visible
		roleError.Text = ""
	end)
end

-- State ----------------------------------------------------------------------------------
function IdentityUI.apply(s: any)
	if type(s) ~= "table" then
		return
	end
	current = s
	if type(s.seats) == "table" then
		seats = s.seats
	end
	namePanel.Visible = s.needsName == true
	roleButton.Visible = s.needsName ~= true
	if s.needsName then
		rolePanel.Visible = false
	end
	refreshRows()
end

function IdentityUI.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Identity"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	buildNamePanel()
	buildRolePanel()
	roleButton.Visible = false
	gui.Parent = player:WaitForChild("PlayerGui")

	Net.listen("Identity", "State", IdentityUI.apply)
	Net.listen("Identity", "Seats", function(msg)
		if type(msg.seats) == "table" then
			seats = msg.seats
			refreshRows()
		end
	end)
	task.spawn(function()
		while not player:GetAttribute("ProfileLoaded") do
			task.wait(0.2)
		end
		local ok, res = Net.request("Identity", "Get")
		if ok then
			IdentityUI.apply(res)
		end
	end)
end

return IdentityUI
