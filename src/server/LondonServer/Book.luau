--!strict
-- LondonServer.Book: the collection book (ACTIVITIES §4; TASKS T27). Account-wide, from
-- profile.collection[id] = times found (Shared.Collection; filled by Activities, Appointments and
-- Events). A page is complete when every item on it has been found once: that's saved in
-- profile.settings.pagesDone[page] (once), the player is told, and the server hears of it (a
-- Gazette mention comes with the newspaper, T23). Pages are checked when the book is opened and
-- every Config.BOOK_CHECK seconds.
-- Pastimes (ACTIVITIES §3; TASKS T28): hobby levels from Profiles.progress(player).hobbies
-- (Shared.Hobbies), and the titles they unlock (Config.HOBBY_TITLES). A player wears one: it's the
-- attribute Badge (Shared.Titles.BADGE_ATTR, shown on the name tag) and is saved in the
-- character's progress.honours as "badge:<hobby>:<level>", put back on whenever they arrive.
-- A newly unlocked title is announced to the player after the activity that earned it.
-- Remotes (Book domain, calls): Get -> { pages = { { name, found, of, complete, items = { { id,
--   name, count, value } } } }, found, of }; Pastimes -> { hobbies = { { name, level, xp, next?,
--   titles = { { level, text, unlocked } } } }, wearing? }; Wear { hobby?, level? } (none = take off).
-- Pushes: Book.Completed { who, page } (to everyone), Book.Notice { text } (to one player).
--   Book.view(player)   Book.check(player) -> pages newly completed   Book.pastimes(player)
--   Book.wear(player, hobby?, level?) -> ok, why
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Collection = require(Shared:WaitForChild("Collection"))
local Hobbies = require(Shared:WaitForChild("Hobbies"))
local Titles = require(Shared:WaitForChild("Titles"))
local Money = require(Shared:WaitForChild("Money"))
local Net = require(Shared:WaitForChild("Net"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Daily = require(script.Parent:WaitForChild("Daily"))

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

-- Pastimes --------------------------------------------------------------------------------
local function titleFor(hobby: string, level: number): string?
	for _, t in Config.HOBBY_TITLES[hobby] or {} do
		if t[1] == level then
			return t[2]
		end
	end
	return nil
end

local function savedBadge(prog: { honours: { string } }): (string?, number?, number?)
	for i, h in prog.honours do
		local hobby, level = string.match(h, "^badge:(%a+):(%d+)$")
		if hobby then
			return hobby, tonumber(level), i
		end
	end
	return nil, nil, nil
end

function Book.pastimes(p: Player): { [string]: any }
	local prog = Profiles.progress(p)
	local list = {}
	for _, hobby in Config.HOBBIES do
		local xp = if prog then prog.hobbies[hobby] or 0 else 0
		local level = Hobbies.level(xp)
		local titles = {}
		for _, t in Config.HOBBY_TITLES[hobby] or {} do
			table.insert(titles, { level = t[1], text = t[2], unlocked = level >= t[1] })
		end
		table.insert(list, {
			name = hobby,
			level = level,
			xp = xp,
			next = if level < Config.HOBBY_MAX_LEVEL then Hobbies.xpFor(level + 1) else nil,
			titles = titles,
		})
	end
	local wearing = p:GetAttribute(Titles.BADGE_ATTR)
	return { hobbies = list, wearing = if type(wearing) == "string" then wearing else nil }
end

function Book.wear(p: Player, hobby: string?, level: number?): (boolean, string?)
	local prog = Profiles.progress(p)
	if not prog then
		return false, "Choose a character first."
	end
	local _, _, at = savedBadge(prog)
	if not hobby then
		if at then
			table.remove(prog.honours, at)
		end
		p:SetAttribute(Titles.BADGE_ATTR, nil)
		return true
	end
	local text = titleFor(hobby, level or 0)
	if not text then
		return false, "There's no such title."
	end
	if Hobbies.level(prog.hobbies[hobby] or 0) < (level :: number) then
		return false, string.format("Reach %s level %d first.", string.lower(hobby), level)
	end
	if at then
		table.remove(prog.honours, at)
	end
	table.insert(prog.honours, string.format("badge:%s:%d", hobby, level))
	p:SetAttribute(Titles.BADGE_ATTR, text)
	return true
end

-- Puts the saved title back on when a character arrives.
local function arrive(p: Player)
	local prog = Profiles.progress(p)
	local hobby, level = nil, nil
	if prog then
		hobby, level = savedBadge(prog)
	end
	p:SetAttribute(Titles.BADGE_ATTR, if hobby and level then titleFor(hobby, level) else nil)
end

-- Highest unlocked title level per hobby this session, to announce new ones.
local known: { [Player]: { [string]: number } } = {}
local function unlockedLevel(hobby: string, xp: number): number
	local best = 0
	for _, t in Config.HOBBY_TITLES[hobby] or {} do
		if Hobbies.level(xp) >= t[1] then
			best = math.max(best, t[1])
		end
	end
	return best
end

local function noticeTitles(p: Player)
	local prog = Profiles.progress(p)
	if not prog then
		return
	end
	local k = known[p]
	if not k then
		k = {}
		for _, hobby in Config.HOBBIES do
			k[hobby] = unlockedLevel(hobby, prog.hobbies[hobby] or 0)
		end
		known[p] = k
		return
	end
	for _, hobby in Config.HOBBIES do
		local now = unlockedLevel(hobby, prog.hobbies[hobby] or 0)
		if now > (k[hobby] or 0) then
			k[hobby] = now
			Net.push(p, "Book", "Notice", { text = string.format("New title: %s. Wear it from the Book (Pastimes).", titleFor(hobby, now) or "?") })
		end
	end
end

function Book.init()
	Net.handle("Book", "Get", { rate = Config.BOOK_RATE, call = true }, function(p)
		Book.check(p)
		return Book.view(p)
	end)
	Net.handle("Book", "Pastimes", { rate = Config.BOOK_RATE, call = true }, function(p)
		return Book.pastimes(p)
	end)
	local V = Net.V
	Net.handle("Book", "Wear", { schema = { hobby = V.optional(V.enum(Config.HOBBIES)), level = V.optional(V.int(1, Config.HOBBY_MAX_LEVEL)) }, rate = Config.BOOK_RATE, call = true }, function(p, a)
		local good, why = Book.wear(p, a.hobby, a.level)
		if not good then
			return nil, why
		end
		return Book.pastimes(p)
	end)
	Daily.onRecord(function(p: Player, event: string)
		if string.sub(event, 1, 9) == "activity:" then
			noticeTitles(p)
		end
	end)
	local function watch(p: Player)
		p:GetAttributeChangedSignal("CharSlot"):Connect(function()
			known[p] = nil
			arrive(p)
			noticeTitles(p)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		known[p] = nil
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
