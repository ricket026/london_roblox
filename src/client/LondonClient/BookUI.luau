--!strict
-- LondonClient.BookUI (stub): the collection book (ACTIVITIES §4). Plain on purpose.
--   A "Book" button (top right, under Events) opens one page at a time (◀ ▶): what you've found
--   and how often, "? ? ?" for what you haven't, the page count, and a mark when it's complete.
--   The Pastimes tab: each hobby's level and XP, the titles it unlocks, Wear / Take off.
-- Server: LondonServer.Book (Book.Get / Pastimes / Wear; pushes Completed, Notice).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local BookUI = {}

local ui = EconomyUI.ui
local C = ui.colours
local player = Players.LocalPlayer

local button: TextButton
local panel: Frame
local body: ScrollingFrame
local title: TextLabel
local book: { [string]: any } = { pages = {} }
local pastimes: { [string]: any } = { hobbies = {} }
local pageIndex = 1
local tab = "book"

local render: () -> ()

local function tabs(o: () -> number)
	local _, b = ui.row(body, o(), "", { { if tab == "book" then "• Book" else "Book" }, { if tab == "pastimes" then "• Pastimes" else "Pastimes" } }, 100)
	b[1].Activated:Connect(function()
		tab = "book"
		render()
	end)
	b[2].Activated:Connect(function()
		tab = "pastimes"
		local ok, res = Net.request("Book", "Pastimes")
		if ok then
			pastimes = res
		end
		render()
	end)
end

local function renderPastimes(o: () -> number)
	title.Text = "Pastimes"
	ui.line(body, o(), "Wearing: " .. (pastimes.wearing or "no title"), C.INK, 16)
	if pastimes.wearing then
		local _, off = ui.row(body, o(), "", { { "Take off" } }, 96)
		off[1].Activated:Connect(function()
			local ok, res = Net.request("Book", "Wear", {})
			if ok then
				pastimes = res
				render()
			end
		end)
	end
	for _, h in pastimes.hobbies or {} do
		ui.line(body, o(), string.format("%s · level %d · %d%s XP", h.name, h.level, h.xp, if h.next then "/" .. h.next else ""), C.GOLD, 17)
		for _, t in h.titles do
			if t.unlocked then
				local _, b = ui.row(body, o(), t.text, { { if pastimes.wearing == t.text then "Worn" else "Wear" } }, 76)
				b[1].Activated:Connect(function()
					local ok, res = Net.request("Book", "Wear", { hobby = h.name, level = t.level })
					if ok then
						pastimes = res
						render()
					else
						EconomyUI.toast(tostring(res), true)
					end
				end)
			else
				ui.line(body, o(), string.format("%s (level %d)", t.text, t.level), C.MUTED, 15)
			end
		end
	end
end

render = function()
	ui.clear(body)
	local o = ui.counter()
	tabs(o)
	if tab == "pastimes" then
		renderPastimes(o)
		return
	end
	local pages = book.pages or {}
	local page = pages[pageIndex]
	if not page then
		ui.line(body, o(), "Nothing to show yet.", C.MUTED, 16)
		return
	end
	title.Text = string.format("Collection book · %d/%d", book.found or 0, book.of or 0)
	local _, nav = ui.row(body, o(), string.format("%s (%d/%d)%s", page.name, page.found, page.of, if page.complete then " ✓" else ""), { { "◀" }, { "▶" } }, 40)
	nav[1].Activated:Connect(function()
		pageIndex = (pageIndex - 2) % #pages + 1
		render()
	end)
	nav[2].Activated:Connect(function()
		pageIndex = pageIndex % #pages + 1
		render()
	end)
	if page.complete then
		ui.line(body, o(), "Page complete.", C.GOLD, 16)
	end
	for _, it in page.items do
		if it.count > 0 then
			ui.line(body, o(), string.format("%s ×%d%s", it.name, it.count, if it.value then " · worth " .. it.value else ""), C.INK, 17)
		else
			ui.line(body, o(), "? ? ?", C.MUTED, 17)
		end
	end
end

function BookUI.open()
	local ok, res = Net.request("Book", "Get")
	if ok then
		book = res
	end
	panel.Visible = true
	render()
end

function BookUI.state(): { [string]: any }
	return book
end

function BookUI.init()
	local gui = EconomyUI.gui()
	button = ui.button(gui, "Book", { Name = "BookButton", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 240), Size = UDim2.fromOffset(84, 30), TextSize = 16, Visible = false })
	panel, body, title = ui.panel("BookPanel", "Collection book")
	button.Activated:Connect(function()
		if panel.Visible then
			panel.Visible = false
		else
			BookUI.open()
		end
	end)
	Net.listen("Book", "Notice", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)
	Net.listen("Book", "Completed", function(msg)
		if msg.who ~= player:GetAttribute("RPName") then
			EconomyUI.toast(string.format("%s has completed the page %s in their collection book.", tostring(msg.who), tostring(msg.page)))
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

return BookUI
