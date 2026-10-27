--!strict
-- LondonClient.CharacterUI (stub): the character menu shown at the start of every session, and
-- from the "Characters" button. Pick a slot to play, create a character (name + skin + hair +
-- outfit), share an existing character's progress into a new slot, rename or delete.
-- Plain on purpose: the real look comes from the user's references in the UI pass (ART §8, M8).
-- Server: LondonServer.Characters (Character.List / Create / Link / Select / Rename / Delete).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Names = require(Shared:WaitForChild("Names"))
local Money = require(Shared:WaitForChild("Money"))
local Looks = require(Shared:WaitForChild("Looks"))

local CharacterUI = {}

local INK = Color3.fromRGB(230, 220, 200)
local PAPER = Color3.fromRGB(18, 16, 14)
local MUTED = Color3.fromRGB(150, 140, 125)
local ERROR = Color3.fromRGB(220, 120, 100)
local BUTTON = Color3.fromRGB(60, 52, 42)
local PICKED = Color3.fromRGB(150, 120, 60)

local player = Players.LocalPlayer
local rng = Random.new()
local list: any = { loaded = false }

local gui: ScreenGui
local openButton: TextButton
local menu: GuiObject -- slot list
local form: GuiObject -- create / link / rename (scrolls)
local confirmBox: GuiObject -- delete

-- Shared builders ---------------------------------------------------------------------------
local function make(cls: string, parent: Instance, props: { [string]: any }): any
	local o: any = Instance.new(cls :: any)
	if o:IsA("GuiObject") then
		o.BorderSizePixel = 0
	end
	if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
		o.BackgroundTransparency = 1
		o.Font = Enum.Font.Garamond
		o.TextColor3 = INK
		o.TextSize = 20
	end
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function button(parent: Instance, text: string, props: { [string]: any }): TextButton
	local b = make("TextButton", parent, props)
	b.Text = text
	b.BackgroundTransparency = 0
	b.BackgroundColor3 = props.BackgroundColor3 or BUTTON
	b.AutoButtonColor = true
	return b
end

local function panel(name: string, w: number, h: number, scrolls: boolean?): GuiObject
	local f = make(if scrolls then "ScrollingFrame" else "Frame", gui, {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.94, 0, 0.9, 0),
		BackgroundColor3 = PAPER,
		BackgroundTransparency = 0.08,
		Visible = false,
	})
	if scrolls then -- phones in landscape are ~360 px tall: let long forms scroll
		f.AutomaticCanvasSize = Enum.AutomaticSize.Y
		f.CanvasSize = UDim2.new()
		f.ScrollBarThickness = 6
	end
	make("UISizeConstraint", f, { MaxSize = Vector2.new(w, h) })
	return f
end

local function padList(parent: Instance, padding: number)
	make("UIListLayout", parent, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, padding), HorizontalAlignment = Enum.HorizontalAlignment.Center })
	make("UIPadding", parent, { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) })
end

local function hasCharacter(): boolean
	return list.loaded and list.active ~= "" and list.slots[list.active] ~= nil
end

local function show(which: GuiObject?)
	menu.Visible = which == menu
	form.Visible = which == form
	confirmBox.Visible = which == confirmBox
	openButton.Visible = which == nil and hasCharacter()
end

-- Camera while no character is in the world ------------------------------------------------------
local function menuCamera()
	local cam = workspace.CurrentCamera
	if not player.Character and cam then
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(Config.MENU_CAMERA.from, Config.MENU_CAMERA.to)
	end
end

-- Slot list ----------------------------------------------------------------------------------------
local menuBody: ScrollingFrame
local menuError: TextLabel
local renderMenu: () -> ()
local openForm: (mode: string, key: string) -> ()
local openDelete: (key: string) -> ()

local function call(action: string, payload: { [string]: any }, errLabel: TextLabel): boolean
	errLabel.Text = "One moment..."
	local ok, res = Net.request("Character", action, payload)
	if ok then
		errLabel.Text = ""
		list = res
		renderMenu()
		return true
	end
	errLabel.Text = tostring(res)
	return false
end

renderMenu = function()
	for _, c in menuBody:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if not list.loaded then
		return
	end
	local filled = 0
	for _ in list.slots do
		filled += 1
	end
	for i = 1, list.maxSlots do
		local key = tostring(i)
		local s = list.slots[key]
		local row = make("Frame", menuBody, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = Color3.fromRGB(34, 30, 26) })
		if s then
			make("TextLabel", row, { Text = s.first .. " " .. s.last, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 30) })
			local sub = s.summary
			if s.linked then
				sub ..= string.format("  ·  shares progress with %d other slot%s", s.shared - 1, if s.shared > 2 then "s" else "")
			end
			make("TextLabel", row, { Text = sub, TextSize = 16, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 20) })
			local isActive = list.active == key
			local play = button(row, if isActive then "Playing" else "Play", { Position = UDim2.new(0, 12, 1, -36), Size = UDim2.fromOffset(110, 30), BackgroundColor3 = if isActive then PICKED else BUTTON })
			play.Activated:Connect(function()
				if not isActive and call("Select", { slot = key }, menuError) then
					show(nil)
				end
			end)
			local rename = button(row, if s.renameIn > 0 then string.format("Rename (%dd)", math.ceil(s.renameIn / 86400)) else "Rename", { Position = UDim2.new(0, 130, 1, -36), Size = UDim2.fromOffset(120, 30) })
			rename.Activated:Connect(function()
				openForm("rename", key)
			end)
			local del = button(row, "Delete", { Position = UDim2.new(1, -102, 1, -36), Size = UDim2.fromOffset(90, 30) })
			del.Activated:Connect(function()
				openDelete(key)
			end)
		else
			make("TextLabel", row, { Text = string.format("Slot %d: empty", i), TextSize = 22, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 30) })
			local newText = if list.newPrice > 0 then "New character · " .. list.newPriceText else "New character"
			local new = button(row, newText, { Position = UDim2.new(0, 12, 1, -40), Size = UDim2.new(0.5, -18, 0, 32) })
			new.Activated:Connect(function()
				openForm("new", key)
			end)
			if filled > 0 then
				local link = button(row, "Share progress · " .. list.linkPriceText, { Position = UDim2.new(0.5, 6, 1, -40), Size = UDim2.new(0.5, -18, 0, 32) })
				link.Activated:Connect(function()
					openForm("link", key)
				end)
			end
		end
	end
	make("TextLabel", menuBody, { LayoutOrder = 100, Text = "Funds (wallet + bank): " .. Money.format(list.money), TextSize = 18, TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 24) })
	if hasCharacter() then
		local close = button(menuBody, "Back to the city", { LayoutOrder = 101, Size = UDim2.fromOffset(200, 36) })
		close.Activated:Connect(function()
			show(nil)
		end)
	end
end

local function buildMenu()
	menu = panel("CharacterMenu", 560, 560)
	make("TextLabel", menu, { Text = "Your Characters", TextSize = 32, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 38) })
	make("TextLabel", menu, {
		Text = "Money and your collection book are shared by all your characters. Sharing progress gives a new character the same job ranks, hobbies and licences, and progress counts for both.",
		TextSize = 16, TextColor3 = MUTED, TextWrapped = true, Position = UDim2.new(0, 16, 0, 50), Size = UDim2.new(1, -32, 0, 40),
	})
	menuError = make("TextLabel", menu, { Text = "", TextColor3 = ERROR, TextSize = 17, TextWrapped = true, Position = UDim2.new(0, 16, 0, 92), Size = UDim2.new(1, -32, 0, 22) })
	menuBody = make("ScrollingFrame", menu, {
		Position = UDim2.fromOffset(0, 116), Size = UDim2.new(1, 0, 1, -116), BackgroundTransparency = 1,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6,
	})
	padList(menuBody, 8)
end

-- Create / link / rename form ------------------------------------------------------------------------
local formTitle: TextLabel
local formError: TextLabel
local firstBox: TextBox
local lastBox: TextBox
local lookRows: { GuiObject } = {}
local linkRow: Frame
local pick = { skin = 1, hair = Config.HAIR_STYLES[1].id, outfit = Config.OUTFITS[1].id, from = "" }
local formMode, formKey = "new", "1"
local refreshPicks: () -> ()

local function choiceRow(order: number, title: string, items: { { id: any, text: string, colour: Color3? } }, field: string, swatch: boolean): Frame
	local row = make("Frame", form, { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	make("UIListLayout", row, { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) })
	make("TextLabel", row, { LayoutOrder = 0, Text = title, TextSize = 18, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22) })
	local wrap = make("Frame", row, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
	make("UIGridLayout", wrap, {
		CellSize = if swatch then UDim2.fromOffset(40, 40) else UDim2.fromOffset(160, 34),
		CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for i, it in items do
		local b = button(wrap, if swatch then "" else it.text, { LayoutOrder = i, TextSize = 17 })
		if it.colour then
			b.BackgroundColor3 = it.colour
		end
		b:SetAttribute("Field", field)
		b:SetAttribute("Value", it.id)
		b.Activated:Connect(function()
			local picks: any = pick
			picks[field] = it.id
			refreshPicks()
		end)
	end
	return row
end

refreshPicks = function()
	for _, d in form:GetDescendants() do
		if d:IsA("TextButton") and d:GetAttribute("Field") then
			local chosen = (pick :: any)[d:GetAttribute("Field") :: string] == d:GetAttribute("Value")
			local isSwatch = d:GetAttribute("Field") == "skin"
			if isSwatch then
				local stroke = d:FindFirstChildOfClass("UIStroke") or make("UIStroke", d, { Thickness = 3 })
				stroke.Color = PICKED
				stroke.Enabled = chosen
			else
				d.BackgroundColor3 = if chosen then PICKED else BUTTON
			end
		end
	end
end

local function rebuildLinkRow()
	if linkRow then
		linkRow:Destroy()
	end
	local items = {}
	for i = 1, list.maxSlots do
		local s = list.slots[tostring(i)]
		if s then
			table.insert(items, { id = tostring(i), text = s.first .. " " .. s.last })
		end
	end
	linkRow = choiceRow(2, "Share progress with", items, "from", false)
	pick.from = if items[1] then items[1].id else ""
end

local function buildForm()
	form = panel("CharacterForm", 560, 640, true)
	padList(form, 8)
	formTitle = make("TextLabel", form, { LayoutOrder = 0, Text = "", TextSize = 30, Size = UDim2.new(1, 0, 0, 36) })
	local names = make("Frame", form, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 })
	local function box(x: number, placeholder: string): TextBox
		local b = make("TextBox", names, {
			PlaceholderText = placeholder, Text = "", ClearTextOnFocus = false, BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(38, 34, 29), Position = UDim2.new(x, 0, 0, 0), Size = UDim2.new(0.38, -6, 1, 0),
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
	lastBox = box(0.38, "Last name")
	local suggest = button(names, "Suggest", { Position = UDim2.new(0.76, 0, 0, 0), Size = UDim2.new(0.24, 0, 1, 0) })
	suggest.Activated:Connect(function()
		firstBox.Text, lastBox.Text = Names.suggest(rng)
	end)

	local skins = {}
	for i, c in Config.SKIN_TONES do
		table.insert(skins, { id = i, text = "", colour = c })
	end
	local hairs, outfits = {}, {}
	for _, h in Config.HAIR_STYLES do
		table.insert(hairs, { id = h.id, text = h.name })
	end
	for _, o in Config.OUTFITS do
		table.insert(outfits, { id = o.id, text = o.name })
	end
	lookRows = {
		choiceRow(3, "Skin tone", skins, "skin", true),
		choiceRow(4, "Hair", hairs, "hair", false),
		choiceRow(5, "Outfit", outfits, "outfit", false),
	}
	formError = make("TextLabel", form, { LayoutOrder = 6, Text = "", TextColor3 = ERROR, TextSize = 17, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40) })
	local buttons = make("Frame", form, { LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	local back = button(buttons, "Back", { Size = UDim2.new(0.5, -6, 1, 0) })
	local confirm = button(buttons, "Confirm", { Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0) })
	back.Activated:Connect(function()
		show(menu)
	end)
	local busy = false
	confirm.Activated:Connect(function()
		if busy then
			return
		end
		for _, b in { firstBox, lastBox } do -- explain local rule breaks without a round trip
			local _, why = Names.cleanPart(b.Text)
			if why then
				formError.Text = why
				return
			end
		end
		local look = Looks.clean(pick.skin, pick.hair, pick.outfit)
		if formMode ~= "rename" and not look then
			formError.Text = "Please pick a look."
			return
		end
		busy = true
		local payload: { [string]: any } = { slot = formKey, first = firstBox.Text, last = lastBox.Text }
		local action = "Rename"
		if formMode ~= "rename" then
			payload.skin, payload.hair, payload.outfit = pick.skin, pick.hair, pick.outfit
			action = "Create"
			if formMode == "link" then
				payload.from = pick.from
				action = "Link"
			end
		end
		local ok = call(action, payload, formError)
		busy = false
		if ok then
			-- a first character is played at once: straight into the city
			show(if action == "Create" and list.active == formKey then nil else menu)
		end
	end)
end

openForm = function(mode: string, key: string)
	formMode, formKey = mode, key
	formError.Text = ""
	local s = list.slots[key]
	if mode == "rename" and s then
		formTitle.Text = "Rename " .. s.first .. " " .. s.last
		firstBox.Text, lastBox.Text = s.first, s.last
	else
		formTitle.Text = if mode == "link" then "New character, shared progress" else "New character"
		firstBox.Text, lastBox.Text = "", ""
		pick.skin, pick.hair, pick.outfit = Looks.default().skin, Looks.default().hair, Looks.default().outfit
	end
	for _, r in lookRows do
		r.Visible = mode ~= "rename"
	end
	if mode == "link" then
		rebuildLinkRow()
	elseif linkRow then
		linkRow:Destroy()
		linkRow = nil :: any
	end
	if mode == "link" then
		formError.Text = "Costs " .. list.linkPriceText .. " from your funds."
	elseif mode == "new" and list.newPrice > 0 then
		formError.Text = "Costs " .. list.newPriceText .. " from your funds."
	end
	refreshPicks()
	show(form)
end

-- Delete confirmation ---------------------------------------------------------------------------------
local confirmText: TextLabel
local confirmInput: TextBox
local confirmError: TextLabel
local deleteKey = ""

local function buildConfirm()
	confirmBox = panel("CharacterDelete", 480, 280)
	padList(confirmBox, 8)
	confirmText = make("TextLabel", confirmBox, { LayoutOrder = 1, Text = "", TextWrapped = true, TextSize = 19, Size = UDim2.new(1, 0, 0, 90) })
	confirmInput = make("TextBox", confirmBox, { LayoutOrder = 2, Text = "", PlaceholderText = "Full name", ClearTextOnFocus = false, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(38, 34, 29), Size = UDim2.new(1, 0, 0, 38) })
	confirmError = make("TextLabel", confirmBox, { LayoutOrder = 3, Text = "", TextColor3 = ERROR, TextSize = 17, Size = UDim2.new(1, 0, 0, 22) })
	local buttons = make("Frame", confirmBox, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 })
	local back = button(buttons, "Keep", { Size = UDim2.new(0.5, -6, 1, 0) })
	local del = button(buttons, "Delete forever", { Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), BackgroundColor3 = Color3.fromRGB(120, 40, 35) })
	back.Activated:Connect(function()
		show(menu)
	end)
	del.Activated:Connect(function()
		if call("Delete", { slot = deleteKey, confirm = confirmInput.Text }, confirmError) then
			menuCamera() -- deleting the character being played removes its body
			show(menu)
		end
	end)
end

openDelete = function(key: string)
	local s = list.slots[key]
	if not s then
		return
	end
	deleteKey = key
	local full = s.first .. " " .. s.last
	local keeps = if s.shared > 1 then "Their progress stays with the other slot that shares it." else "Their job ranks, hobbies and licences will be lost. Money and your collection stay on your account."
	confirmText.Text = string.format("Delete %s? %s\nType \"%s\" to confirm.", full, keeps, full)
	confirmInput.Text = ""
	confirmError.Text = ""
	show(confirmBox)
end

-- Boot ---------------------------------------------------------------------------------------------------
function CharacterUI.open()
	renderMenu()
	if list.loaded and next(list.slots) == nil then
		openForm("new", "1") -- first visit: straight to the creator
	else
		show(menu)
	end
end

function CharacterUI.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Characters"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = true
	buildMenu()
	buildForm()
	buildConfirm()
	openButton = button(gui, "Characters", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 240, 1, -12), Size = UDim2.fromOffset(140, 40), Visible = false })
	openButton.Activated:Connect(CharacterUI.open)
	gui.Parent = player:WaitForChild("PlayerGui")

	Net.listen("Character", "List", function(msg)
		list = msg
		if menu.Visible then
			renderMenu()
		end
	end)
	player.CharacterAdded:Connect(function(character)
		local cam = workspace.CurrentCamera
		local hum = character:WaitForChild("Humanoid", 10)
		if cam and hum then
			cam.CameraType = Enum.CameraType.Custom
			cam.CameraSubject = hum :: Humanoid
		end
		if not menu.Visible and not form.Visible and not confirmBox.Visible then
			show(nil)
		end
	end)
	task.spawn(function()
		while not player:GetAttribute("ProfileLoaded") do
			task.wait(0.2)
		end
		local ok, res = Net.request("Character", "List")
		if ok then
			list = res
		end
		menuCamera()
		if not player.Character then
			CharacterUI.open()
		else
			show(nil)
		end
	end)
end

return CharacterUI
