--!strict
-- LondonClient.LettersUI (stub): letters (PLAYER_GATHERING §4). Plain on purpose.
--   "Letters" in the More menu (with the unread count): your letterbox (Read, Delete), a letter,
--   and Write: pick someone (here or a Roblox friend), write up to Config.LETTER_MAX letters,
--   Send (a stamp).
-- Server: LondonServer.Letters (Letter.Contacts / Box / Read / Delete / Send; pushes Count, Arrived).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local LettersUI = {}

local ui = EconomyUI.ui
local C = ui.colours
local player = Players.LocalPlayer

local button: TextButton
local panel: Frame
local body: ScrollingFrame
local title: TextLabel
local view = "box" -- "box" | "letter" | "contacts" | "write"
local letters: { { [string]: any } } = {}
local open: { [string]: any }? = nil
local contacts: { { [string]: any } } = {}
local stamp = ""
local to: { [string]: any }? = nil
local draft = ""
local unread = 0

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- "28 Oct" (Roblox's os.date only gives tables, "*t" / "!*t").
local function when(at: number): string
	local d = os.date("*t", at) :: any
	return string.format("%d %s", d.day, MONTHS[d.month])
end

local function request(action: string, args: { [string]: any }?): (boolean, any)
	local ok, res = Net.request("Letter", action, args)
	if not ok then
		EconomyUI.toast(tostring(res), true)
	end
	return ok, res
end

local function label()
	button.Text = if unread > 0 then string.format("Letters (%d)", unread) else "Letters"
end

local render: () -> ()

local function loadBox()
	local ok, res = request("Box")
	if ok then
		letters = res.letters or {}
		unread = 0
		for _, l in letters do
			unread += if l.read then 0 else 1
		end
		label()
	end
end

render = function()
	ui.clear(body)
	local o = ui.counter()
	if view == "letter" and open then
		local l = open
		title.Text = "A letter"
		ui.line(body, o(), string.format("From %s, %s", l.fromName, when(l.at)), C.GOLD, 17)
		ui.line(body, o(), l.text, C.INK, 17)
		local _, b = ui.row(body, o(), "", { { "Back" } }, 84)
		b[1].Activated:Connect(function()
			view = "box"
			render()
		end)
		return
	end
	if view == "contacts" then
		title.Text = "Write to…"
		if #contacts == 0 then
			ui.line(body, o(), "Nobody to write to: letters go to people here or your Roblox friends.", C.MUTED, 16)
		end
		for _, c in contacts do
			local _, b = ui.row(body, o(), c.name .. (if c.here then " (here)" else " (friend)"), { { "Write" } }, 76)
			b[1].Activated:Connect(function()
				to, view = c, "write"
				render()
			end)
		end
		local _, back = ui.row(body, o(), "", { { "Back" } }, 84)
		back[1].Activated:Connect(function()
			view = "box"
			render()
		end)
		return
	end
	if view == "write" and to then
		local recipient = to
		title.Text = "To " .. recipient.name
		local r = Instance.new("Frame")
		r.LayoutOrder = o()
		r.BackgroundTransparency = 1
		r.Size = UDim2.new(1, 0, 0, 124)
		r.Parent = body
		local boxT = ui.text(r, "TextBox", {
			Name = "LetterText",
			Text = draft,
			PlaceholderText = string.format("Dear %s… (up to %d letters)", recipient.name, Config.LETTER_MAX),
			PlaceholderColor3 = C.MUTED,
			ClearTextOnFocus = false,
			MultiLine = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(34, 30, 26),
			TextSize = 16,
			Size = UDim2.new(1, 0, 0, 120),
			Position = UDim2.fromOffset(0, 2),
		})
		boxT:GetPropertyChangedSignal("Text"):Connect(function()
			draft = boxT.Text
		end)
		local _, b = ui.row(body, o(), "A stamp: " .. stamp, { { "Send" }, { "Back" } }, 76)
		b[1].Activated:Connect(function()
			if draft == "" then
				EconomyUI.toast("Write something first.", true)
				return
			end
			if request("Send", { to = recipient.userId, text = draft }) then
				EconomyUI.toast("Posted to " .. recipient.name .. ".")
				draft, to, view = "", nil, "box"
				render()
			end
		end)
		b[2].Activated:Connect(function()
			view = "contacts"
			render()
		end)
		return
	end
	title.Text = "Your letterbox"
	local _, w = ui.row(body, o(), "", { { "Write" } }, 84)
	w[1].Activated:Connect(function()
		local ok, res = request("Contacts")
		if ok then
			contacts, stamp = res.contacts or {}, res.stamp or ""
			view = "contacts"
			render()
		end
	end)
	if #letters == 0 then
		ui.line(body, o(), "No letters.", C.MUTED, 16)
	end
	for _, l in letters do
		local _, b = ui.row(body, o(), string.format("%s%s · %s", if l.read then "" else "• ", l.fromName, when(l.at)), { { "Read" }, { "Delete" } }, 72)
		b[1].Activated:Connect(function()
			local ok, res = request("Read", { id = l.id })
			if ok then
				open, view = res, "letter"
				if not l.read then
					l.read = true
					unread = math.max(0, unread - 1)
					label()
				end
				render()
			end
		end)
		b[2].Activated:Connect(function()
			if request("Delete", { id = l.id }) then
				loadBox()
				render()
			end
		end)
	end
end

function LettersUI.open()
	view = "box"
	panel.Visible = true
	loadBox()
	render()
end

function LettersUI.state(): ({ { [string]: any } }, number)
	return letters, unread
end

function LettersUI.init()
	button = EconomyUI.menuButton("LettersButton", "Letters", 40)
	panel, body, title = ui.panel("LettersPanel", "Letters")
	button.Activated:Connect(function()
		if panel.Visible then
			panel.Visible = false
		else
			LettersUI.open()
		end
	end)
	Net.listen("Letter", "Count", function(msg)
		unread = msg.unread or 0
		label()
		if unread > 0 then
			EconomyUI.toast(string.format("You have %d unread letter%s (More › Letters).", unread, if unread == 1 then "" else "s"))
		end
	end)
	Net.listen("Letter", "Arrived", function(msg)
		unread += 1
		label()
		EconomyUI.toast(string.format("A letter from %s has arrived.", tostring(msg.from)))
		if panel.Visible and view == "box" then
			loadBox()
			render()
		end
	end)
	local function refresh()
		button.Visible = player:GetAttribute("CharSlot") ~= nil
		if not button.Visible then
			panel.Visible = false
		end
	end
	player:GetAttributeChangedSignal("CharSlot"):Connect(refresh)
	refresh()
end

return LettersUI
