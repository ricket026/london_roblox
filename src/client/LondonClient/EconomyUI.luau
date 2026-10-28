--!strict
-- LondonClient.EconomyUI (stub): wallet, bag, counter menus and hand-overs (Phase 2), kept in one
-- module so there is one script to paste. Plain on purpose (ART §8); the UI pass restyles it.
--   Wallet (top right): Profile.Wallet pushes. Shown only once a character is in the city.
--   Bag (button or B): Inventory.Get / Inventory.State; Use, Hold / Put away, Give.
--   Give: to a nearby player, money (£ s d boxes) and/or part of a stack (Exchange.Offer, Cancel).
--   Counters: Counter.Open opens the menu for its kind: shop (Counter.Buy), bank (Economy.Bank);
--     other systems add kinds with EconomyUI.onCounter(kind, fn(body, msg, order) -> nil).
--   Offers to you: Exchange.Offered -> Accept / Decline (Exchange.Answer); Exchange.Closed.
--   EconomyUI.toast(text) shows a short message at the bottom of the screen.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Money = require(Shared:WaitForChild("Money"))

local EconomyUI = {}

local INK = Color3.fromRGB(230, 220, 200)
local PAPER = Color3.fromRGB(18, 16, 14)
local MUTED = Color3.fromRGB(150, 140, 125)
local GOLD = Color3.fromRGB(240, 205, 120)
local ERROR = Color3.fromRGB(220, 120, 100)
local BUTTON = Color3.fromRGB(60, 52, 42)

local player = Players.LocalPlayer
local wallet, bank = 0, 0
local inv: { [string]: any } = { bag = {}, storage = {}, slots = Config.BAG_SLOTS }
local counterKinds: { [string]: (ScrollingFrame, { [string]: any }, () -> number) -> () } = {}

local gui: ScreenGui
local walletLabel: TextLabel
local bankLabel: TextLabel
local bagButton: TextButton
local bagPanel: Frame
local bagBody: ScrollingFrame
local givePanel: Frame
local giveBody: ScrollingFrame
local counterPanel: Frame
local counterBody: ScrollingFrame
local counterTitle: TextLabel
local offerFrame: Frame
local offerText: TextLabel
local toastLabel: TextLabel

local counterMsg: { [string]: any }? = nil
local counterFrom: Vector3? = nil
local offersIn: { { [string]: any } } = {} -- offers waiting for my answer, oldest first
local outgoing: number? = nil -- id of my offer that is waiting

-- Widgets ----------------------------------------------------------------------------------
local function text(parent: Instance, cls: string, props: { [string]: any }): any
	local o = Instance.new(cls :: any) :: any
	o.BackgroundTransparency = 1
	o.Font = Enum.Font.Garamond
	o.TextColor3 = INK
	o.TextSize = 19
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
	b.BackgroundColor3 = BUTTON
	b.AutoButtonColor = true
	return b
end

local function rootPos(p: Player): Vector3?
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp.Position else nil
end

local function focus(b: GuiObject?)
	if b and UserInputService.GamepadEnabled then
		GuiService.SelectedObject = b
	end
end

function EconomyUI.toast(msg: string, isError: boolean?)
	toastLabel.Text = msg
	toastLabel.TextColor3 = if isError then ERROR else INK
	toastLabel.Visible = true
	local shown = msg
	task.delay(3, function()
		if toastLabel.Text == shown then
			toastLabel.Visible = false
		end
	end)
end

-- A centred panel with a title, a Close button and a scrolling body laid out top to bottom.
local function panel(name: string, title: string): (Frame, ScrollingFrame, TextLabel)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(0.9, 0.85)
	f.BackgroundColor3 = PAPER
	f.BackgroundTransparency = 0.08
	f.BorderSizePixel = 0
	f.Visible = false
	f.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 520)
	limit.Parent = f
	local head = text(f, "TextLabel", {
		Text = title,
		Font = Enum.Font.GaramondBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -112, 0, 30),
	})
	local close = button(f, "Close", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Size = UDim2.fromOffset(84, 30) })
	close.Activated:Connect(function()
		f.Visible = false
	end)
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, 42)
	body.Size = UDim2.new(1, 0, 1, -42)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 6
	body.Parent = f
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = body
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 8)
	pad.Parent = body
	return f, body, head
end

local function clear(body: Instance)
	for _, c in body:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function counter(): () -> number
	local n = 0
	return function(): number
		n += 1
		return n
	end
end

local function line(body: Instance, order: number, s: string, color: Color3?, size: number?): TextLabel
	return text(body, "TextLabel", {
		LayoutOrder = order,
		Text = s,
		TextColor3 = color or INK,
		TextSize = size or 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
end

-- A row: a label on the left and buttons (fixed width) on the right. Returns the row and buttons.
local function row(body: Instance, order: number, label: string, buttons: { { string } }, width: number?): (Frame, { TextButton })
	local w = width or 72
	local r = Instance.new("Frame")
	r.LayoutOrder = order
	r.BackgroundTransparency = 1
	r.Size = UDim2.new(1, 0, 0, 34)
	r.Parent = body
	text(r, "TextLabel", {
		Name = "Label",
		Text = label,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -(#buttons * (w + 4)), 1, 0),
	})
	local out = {}
	for k, b in buttons do
		local x = -(#buttons - k) * (w + 4)
		out[k] = button(r, b[1], { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, x, 0, 2), Size = UDim2.fromOffset(w, 30) })
	end
	return r, out
end

-- Wallet ------------------------------------------------------------------------------------
local function refreshWallet()
	walletLabel.Text = Money.format(wallet)
	bankLabel.Text = "Bank " .. Money.format(bank)
end

local function inCity(): boolean
	return player:GetAttribute("CharSlot") ~= nil
end

local function refreshVisible()
	local here = inCity()
	walletLabel.Visible = here
	bankLabel.Visible = here
	bagButton.Visible = here
	if not here then
		bagPanel.Visible = false
		givePanel.Visible = false
		counterPanel.Visible = false
	end
end

-- Give --------------------------------------------------------------------------------------
local function nearbyPlayers(): { Player }
	local me = rootPos(player)
	local out = {}
	if not me then
		return out
	end
	for _, p in Players:GetPlayers() do
		local pos = p ~= player and rootPos(p)
		if pos and (pos - me).Magnitude <= Config.EXCHANGE_RANGE then
			table.insert(out, p)
		end
	end
	return out
end

local function displayName(p: Player): string
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

local function openGive(stack: { [string]: any }?)
	clear(giveBody)
	local o = counter()
	local count = 1
	if stack then
		local _, b = row(giveBody, o(), stack.name, { { "−" }, { "1" }, { "+" } }, 40)
		b[2].AutoButtonColor = false
		b[1].Activated:Connect(function()
			count = math.max(1, count - 1)
			b[2].Text = tostring(count)
		end)
		b[3].Activated:Connect(function()
			count = math.min(stack.n, count + 1)
			b[2].Text = tostring(count)
		end)
	end
	line(giveBody, o(), if stack then "And money, if you like:" else "How much?", MUTED, 16)
	local boxes = Instance.new("Frame")
	boxes.LayoutOrder = o()
	boxes.BackgroundTransparency = 1
	boxes.Size = UDim2.new(1, 0, 0, 34)
	boxes.Parent = giveBody
	local fields: { TextBox } = {}
	for k, unit in { "£", "s", "d" } do
		local tb = text(boxes, "TextBox", {
			PlaceholderText = unit,
			Text = "",
			ClearTextOnFocus = false,
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(34, 30, 26),
			PlaceholderColor3 = MUTED,
			Position = UDim2.new((k - 1) / 3, 2, 0, 2),
			Size = UDim2.new(1 / 3, -4, 0, 30),
		})
		fields[k] = tb
	end
	local err = line(giveBody, o(), "", ERROR, 16)
	local function amount(): number?
		local parts = {}
		for k, tb in fields do
			local v = if tb.Text == "" then 0 else tonumber(tb.Text)
			if not v or v < 0 or v % 1 ~= 0 then
				return nil
			end
			parts[k] = v
		end
		return Money.fromLsd(parts[1], parts[2], parts[3])
	end
	line(giveBody, o(), "Give to:", MUTED, 16)
	local people = nearbyPlayers()
	if #people == 0 then
		line(giveBody, o(), "Nobody is close enough. Stand next to them.", MUTED)
	end
	for _, p in people do
		local _, b = row(giveBody, o(), displayName(p), { { "Give" } })
		b[1].Activated:Connect(function()
			local pence = amount()
			if not pence or pence > Config.PENCE_MAX then
				err.Text = "Write whole numbers in the £, s and d boxes."
				return
			end
			if pence > wallet then
				err.Text = "You aren't carrying that much."
				return
			end
			if not stack and pence == 0 then
				err.Text = "Write how much to give."
				return
			end
			local ok, res = Net.request("Exchange", "Offer", {
				to = p.UserId,
				pence = pence,
				slot = if stack then stack.slot else 0,
				count = if stack then count else 0,
			})
			if not ok then
				err.Text = tostring(res)
				return
			end
			outgoing = res.id
			givePanel.Visible = false
			EconomyUI.toast("Waiting for " .. displayName(p) .. " to accept…")
		end)
	end
	if outgoing then
		local _, b = row(giveBody, o(), "You have an offer waiting.", { { "Cancel" } }, 84)
		b[1].Activated:Connect(function()
			if outgoing then
				Net.request("Exchange", "Cancel", { id = outgoing })
			end
		end)
	end
	givePanel.Visible = true
	bagPanel.Visible = false
	focus(fields[1])
end

-- Bag ---------------------------------------------------------------------------------------
local function renderBag()
	clear(bagBody)
	local o = counter()
	local bag = inv.bag or {}
	local stored = 0
	for _, s in inv.storage or {} do
		stored += s.n
	end
	line(bagBody, o(), string.format("%d of %d places used · %d stored at home", #bag, inv.slots or Config.BAG_SLOTS, stored), MUTED, 16)
	local _, give = row(bagBody, o(), "Money: " .. Money.format(wallet), { { "Give" } })
	give[1].Activated:Connect(function()
		openGive(nil)
	end)
	if #bag == 0 then
		line(bagBody, o(), "Your bag is empty.", MUTED)
	end
	for _, s in bag do
		local label = s.name .. (if s.n > 1 then " ×" .. s.n else "") .. (if s.byName then " (made by " .. s.byName .. ")" else "")
		local actions = {}
		if s.use then
			table.insert(actions, { "Use" })
		end
		if s.hold then
			table.insert(actions, { if inv.held == s.id then "Put away" else "Hold" })
		end
		table.insert(actions, { "Give" })
		local _, b = row(bagBody, o(), label, actions, 76)
		local k = 1
		if s.use then
			local btn = b[k]
			btn.Activated:Connect(function()
				local ok, res = Net.request("Inventory", "Use", { slot = s.slot })
				if ok then
					EconomyUI.toast(res.text)
				else
					EconomyUI.toast(tostring(res), true)
				end
			end)
			k += 1
		end
		if s.hold then
			local btn = b[k]
			btn.Activated:Connect(function()
				local slot = if inv.held == s.id then 0 else s.slot
				local ok, res = Net.request("Inventory", "Hold", { slot = slot })
				if not ok then
					EconomyUI.toast(tostring(res), true)
				end
			end)
			k += 1
		end
		b[k].Activated:Connect(function()
			openGive(s)
		end)
	end
end

local function toggleBag()
	if not inCity() then
		return
	end
	bagPanel.Visible = not bagPanel.Visible
	if bagPanel.Visible then
		givePanel.Visible = false
		counterPanel.Visible = false
		renderBag()
		focus(bagPanel:FindFirstChild("Close") :: GuiObject?)
	end
end

-- Counters ----------------------------------------------------------------------------------
local renderCounter: (msg: { [string]: any }) -> ()

local function balances(body: Instance, order: number)
	line(body, order, "Carried " .. Money.format(wallet) .. " · In the bank " .. Money.format(bank), MUTED, 16)
end

counterKinds.shop = function(body, msg, o)
	for _, s in msg.stock or {} do
		local n = 1
		local label = s.name .. " · " .. s.priceText .. (if s.toStorage then " (sent home)" else "")
		local _, b = row(body, o(), label, { { "−" }, { "1" }, { "+" }, { "Buy" } }, 40)
		b[2].AutoButtonColor = false
		b[1].Activated:Connect(function()
			n = math.max(1, n - 1)
			b[2].Text = tostring(n)
		end)
		b[3].Activated:Connect(function()
			n = math.min(s.stack, n + 1)
			b[2].Text = tostring(n)
		end)
		b[4].Activated:Connect(function()
			local ok, res = Net.request("Counter", "Buy", { counter = msg.id, item = s.item, count = n })
			if not ok then
				EconomyUI.toast(tostring(res), true)
				return
			end
			wallet, bank = res.wallet, res.bank
			refreshWallet()
			local what = (if res.count > 1 then res.count .. " × " else "") .. res.bought
			EconomyUI.toast("Bought " .. what .. (if res.toStorage then ". It's been sent to your storage." else "."))
			renderCounter(msg)
		end)
	end
	if #(msg.stock or {}) == 0 then
		line(body, o(), "Nothing for sale today.", MUTED)
	end
end

counterKinds.bank = function(body, msg, o)
	for _, action in { "deposit", "withdraw" } do
		line(body, o(), if action == "deposit" then "Pay in" else "Draw out", MUTED, 16)
		local amounts = table.clone(msg.presets or Config.BANK_PRESETS)
		local labels = {}
		for k, v in amounts do
			labels[k] = { Money.format(v) }
		end
		table.insert(labels, { "All" })
		local _, b = row(body, o(), "", labels, 64)
		for k, btn in b do
			btn.Activated:Connect(function()
				local pence = amounts[k] or (if action == "deposit" then wallet else bank)
				if pence <= 0 then
					EconomyUI.toast(if action == "deposit" then "You aren't carrying any money." else "There's nothing in the bank.", true)
					return
				end
				local ok, res = Net.request("Economy", "Bank", { counter = msg.id, action = action, pence = pence })
				if not ok then
					EconomyUI.toast(tostring(res), true)
					return
				end
				wallet, bank = res.wallet, res.bank
				refreshWallet()
				EconomyUI.toast((if action == "deposit" then "Paid in " else "Drew out ") .. Money.format(pence) .. ".")
				renderCounter(msg)
			end)
		end
	end
end

renderCounter = function(msg: { [string]: any })
	clear(counterBody)
	local o = counter()
	counterTitle.Text = msg.name or "Counter"
	balances(counterBody, o())
	local fn = counterKinds[msg.kind]
	if fn then
		fn(counterBody, msg, o)
	else
		line(counterBody, o(), "Nothing here yet.", MUTED)
	end
end

function EconomyUI.onCounter(kind: string, fn: (ScrollingFrame, { [string]: any }, () -> number) -> ())
	counterKinds[kind] = fn
end

local function openCounter(msg: { [string]: any })
	if type(msg.id) ~= "string" then
		return
	end
	if type(msg.wallet) == "number" then
		wallet, bank = msg.wallet, msg.bank or bank
		refreshWallet()
	end
	counterMsg = msg
	counterFrom = rootPos(player)
	bagPanel.Visible = false
	givePanel.Visible = false
	renderCounter(msg)
	counterPanel.Visible = true
	focus(counterPanel:FindFirstChild("Close") :: GuiObject?)
end

-- Offers to me ------------------------------------------------------------------------------
local function showOffer()
	local o = offersIn[1]
	offerFrame.Visible = o ~= nil
	if not o then
		return
	end
	local what = {}
	if o.penceText then
		table.insert(what, o.penceText)
	end
	if o.itemName then
		table.insert(what, o.itemName .. (if o.count > 1 then " ×" .. o.count else ""))
	end
	offerText.Text = string.format("%s offers you %s.", o.fromName or "Someone", table.concat(what, " and "))
end

local function answer(accept: boolean)
	local o = offersIn[1]
	if not o then
		return
	end
	table.remove(offersIn, 1)
	showOffer()
	local ok, res = Net.request("Exchange", "Answer", { id = o.id, accept = accept })
	if not ok then
		EconomyUI.toast(tostring(res), true)
	elseif accept then
		EconomyUI.toast("Done.")
	end
end

local CLOSED_TEXT = {
	done = "They accepted.",
	declined = "They said no.",
	expired = "Your offer ran out.",
	left = "They've gone.",
	cancelled = "Offer withdrawn.",
}

local function onClosed(msg: { [string]: any })
	for k, o in offersIn do
		if o.id == msg.id then
			table.remove(offersIn, k)
			showOffer()
			break
		end
	end
	if msg.id == outgoing then
		outgoing = nil
		local s = if msg.result == "failed" then "It didn't go through: " .. tostring(msg.why or "") else CLOSED_TEXT[msg.result]
		if s then
			EconomyUI.toast(s, msg.result ~= "done")
		end
	end
end

-- Build -------------------------------------------------------------------------------------
local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Economy"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	walletLabel = text(gui, "TextLabel", {
		Name = "Wallet",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.fromOffset(200, 26),
		Font = Enum.Font.GaramondBold,
		TextSize = 22,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	bankLabel = text(gui, "TextLabel", {
		Name = "Bank",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 30),
		Size = UDim2.fromOffset(200, 18),
		TextSize = 16,
		TextColor3 = MUTED,
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	bagButton = button(gui, "Bag", { Name = "BagButton", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 52), Size = UDim2.fromOffset(84, 34) })
	bagButton.Activated:Connect(toggleBag)

	bagPanel, bagBody = panel("BagPanel", "Bag")
	givePanel, giveBody = panel("GivePanel", "Give")
	counterPanel, counterBody, counterTitle = panel("CounterPanel", "Counter")

	offerFrame = Instance.new("Frame")
	offerFrame.Name = "Offer"
	offerFrame.AnchorPoint = Vector2.new(0.5, 0)
	offerFrame.Position = UDim2.new(0.5, 0, 0, 36)
	offerFrame.Size = UDim2.new(0.9, 0, 0, 84)
	offerFrame.BackgroundColor3 = PAPER
	offerFrame.BackgroundTransparency = 0.08
	offerFrame.BorderSizePixel = 0
	offerFrame.Visible = false
	offerFrame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 84)
	limit.Parent = offerFrame
	offerText = text(offerFrame, "TextLabel", { TextWrapped = true, TextSize = 18, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 40) })
	local yes = button(offerFrame, "Accept", { Name = "Accept", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -4, 1, -6), Size = UDim2.fromOffset(110, 32) })
	local no = button(offerFrame, "Decline", { Name = "Decline", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 4, 1, -6), Size = UDim2.fromOffset(110, 32) })
	yes.Activated:Connect(function()
		answer(true)
	end)
	no.Activated:Connect(function()
		answer(false)
	end)

	toastLabel = text(gui, "TextLabel", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -60),
		Size = UDim2.new(0.8, 0, 0, 28),
		TextSize = 19,
		TextWrapped = true,
		TextStrokeTransparency = 0.4,
		Visible = false,
	})
	gui.Parent = player:WaitForChild("PlayerGui")
end

function EconomyUI.init()
	build()
	refreshWallet()
	refreshVisible()
	player:GetAttributeChangedSignal("CharSlot"):Connect(refreshVisible)

	Net.listen("Profile", "Wallet", function(msg)
		if type(msg.pence) == "number" then
			wallet = msg.pence
		end
		if type(msg.bank) == "number" then
			bank = msg.bank
		end
		refreshWallet()
		if counterPanel.Visible and counterMsg then
			renderCounter(counterMsg)
		end
	end)
	Net.listen("Inventory", "State", function(msg)
		inv = msg
		if bagPanel.Visible then
			renderBag()
		end
	end)
	Net.listen("Counter", "Open", openCounter)
	Net.listen("Exchange", "Offered", function(msg)
		if type(msg.id) == "number" then
			table.insert(offersIn, msg)
			showOffer()
			focus(offerFrame:FindFirstChild("Accept") :: GuiObject?)
			local id = msg.id
			task.delay(msg.seconds or Config.EXCHANGE_TIMEOUT, function()
				onClosed({ id = id, result = "expired" })
			end)
		end
	end)
	Net.listen("Exchange", "Closed", onClosed)

	ContextActionService:BindAction("LondonBag", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggleBag()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B)

	-- walking away from a counter closes its menu
	task.spawn(function()
		while true do
			task.wait(0.5)
			if counterPanel.Visible and counterFrom then
				local now = rootPos(player)
				if not now or (now - counterFrom).Magnitude > Config.COUNTER_RANGE then
					counterPanel.Visible = false
				end
			end
		end
	end)
	task.spawn(function()
		while not player:GetAttribute("ProfileLoaded") do
			task.wait(0.2)
		end
		local ok, res = Net.request("Inventory", "Get")
		if ok then
			inv = res
		end
		-- the first wallet push can arrive before this module listens, so ask once
		local gotLedger, ledger = Net.request("Economy", "Ledger")
		if gotLedger then
			wallet, bank = ledger.wallet, ledger.bank
			refreshWallet()
		end
	end)
end

return EconomyUI
