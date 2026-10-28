--!strict
-- LondonServer.Book: the collection book (ACTIVITIES §4; TASKS T27). Account-wide, from
-- profile.collection[id] = times found (Shared.Collection; filled by Activities, Appointments and
-- Events). A page is complete when every item on it has been found once: that's saved in
-- profile.settings.pagesDone[page] (once), the player is told, and the server hears of it (a
-- Gazette mention comes with the newspaper, T23). Pages are checked when the book is opened and
-- every Config.BOOK_CHECK seconds.
-- Remote (Book domain, call): Get -> { pages = { { name, found, of, complete, items = { { id,
--   name, count, value } } } }, found, of }.
-- Pushes: Book.Completed { who, page } (to everyone), Book.Notice { text } (to one player).
--   Book.view(player)   Book.check(player) -> pages newly completed
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Collection = require(Shared:WaitForChild("Collection"))
local Money = require(Shared:WaitForChild("Money"))
local Net = require(Shared:WaitForChild("Net"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local Book = {}

local function nameOf(p: Player): string
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

function Book.view(p: Player): { [string]: any }
	local profile = Profiles.get(p)
	local have = if profile then profile.collection else {}
	local done = if profile then profile.settings.pagesDone or {} else {}
	local pages = {}
	local found, of = 0, 0
	for _, page in Collection.PAGES do
		local items = {}
		local f = 0
		for _, it in Collection.ITEMS do
			if it.page == page then
				local n = have[it.id] or 0
				f += if n > 0 then 1 else 0
				table.insert(items, { id = it.id, name = it.name, count = n, value = if it.value > 0 then Money.format(it.value) else nil })
			end
		end
		found += f
		of += #items
		table.insert(pages, { name = page, found = f, of = #items, complete = done[page] == true or (f == #items and #items > 0), items = items })
	end
	return { pages = pages, found = found, of = of }
end

function Book.check(p: Player): { string }
	local profile = Profiles.get(p)
	if not profile then
		return {}
	end
	profile.settings.pagesDone = profile.settings.pagesDone or {}
	local done = profile.settings.pagesDone
	local newly = {}
	for _, page in Collection.PAGES do
		if not done[page] then
			local all, any = true, false
			for _, it in Collection.ITEMS do
				if it.page == page then
					any = true
					if (profile.collection[it.id] or 0) <= 0 then
						all = false
					end
				end
			end
			if all and any then
				done[page] = true
				table.insert(newly, page)
				Net.push(p, "Book", "Notice", { text = string.format("Page complete: %s!", page) })
				Net.pushAll("Book", "Completed", { who = nameOf(p), page = page })
			end
		end
	end
	return newly
end

function Book.init()
	Net.handle("Book", "Get", { rate = Config.BOOK_RATE, call = true }, function(p)
		Book.check(p)
		return Book.view(p)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.BOOK_CHECK)
			for _, p in Players:GetPlayers() do
				if p:GetAttribute("CharSlot") ~= nil then
					Book.check(p)
				end
			end
		end
	end)
end

return Book
