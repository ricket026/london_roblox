--!strict
-- LondonClient.BookUI (stub): the collection book (ACTIVITIES §4). Plain on purpose.
--   A "Book" button (top right, under Events) opens one page at a time (◀ ▶): what you've found
--   and how often, "? ? ?" for what you haven't, the page count, and a mark when it's complete.
-- Server: LondonServer.Book (Book.Get; pushes Completed, Notice).
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
local pageIndex = 1

local function render()
	ui.clear(body)
	local o = ui.counter()
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
