--!strict
-- LondonServer.Letters: letters to friends (PLAYER_GATHERING §4, TECH §8; TASKS T33). A letter
-- goes to a player in this server or a Roblox friend (online or not) and waits in their letterbox
-- (DataStore Config.LETTER_STORE, key "m_<userId>", at most Config.LETTER_BOX letters, kept
-- Config.LETTER_KEEP_DAYS days) until they read it, here or in any server. Safety (TECH §8): a
-- letter can only be sent, and only be read, when TextChatService:CanUsersDirectChatAsync allows
-- the two to chat; the text is stored as written and filtered for the reader when it's read
-- (Shared.Text.filterFor, fail closed). A stamp costs Config.LETTER_STAMP; Config.LETTER_DAILY a day.
-- When a character arrives, the player is told how many unread letters wait.
-- Remotes (Letter domain, calls): Contacts, Box, Read { id }, Delete { id }, Send { to, text }.
-- Pushes: Letter.Count { unread } (to one player), Letter.Arrived { from } (to the recipient here).
--   Letters.send(from, toUserId, text) -> ok, why   Letters.box(player) -> list
--   Letters.read(player, id) -> letter?, why
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Money = require(Shared:WaitForChild("Money"))
local Net = require(Shared:WaitForChild("Net"))
local Text = require(Shared:WaitForChild("Text"))
local Store = require(script.Parent:WaitForChild("Store"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Economy = require(script.Parent:WaitForChild("Economy"))

local Letters = {}

export type Letter = { id: string, from: number, fromName: string, at: number, text: string, read: boolean? }

local store = Store.open(Config.LETTER_STORE)

local function key(userId: number): string
	return "m_" .. tostring(userId)
end

local function nameOf(p: Player): string
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

-- May these two users exchange private text? Asked of a player who is in this server. Fails closed.
local function mayWrite(requester: Player, other: number): boolean
	local ok, res = pcall(TextChatService.CanUsersDirectChatAsync, TextChatService, requester.UserId, { other })
	return ok and type(res) == "table" and table.find(res, other) ~= nil
end

local function fresh(list: any): { Letter }
	local out = {}
	local cutoff = os.time() - Config.LETTER_KEEP_DAYS * 86400
	for _, l in if type(list) == "table" then list else {} do
		if type(l) == "table" and type(l.at) == "number" and l.at >= cutoff then
			table.insert(out, l)
		end
	end
	return out
end

function Letters.box(p: Player): { Letter }
	local ok, list = pcall(store.get, store, key(p.UserId))
	return if ok then fresh(list) else {}
end

local function friends(p: Player, other: number): boolean
	if Players:GetPlayerByUserId(other) then
		return true -- here in this server
	end
	local ok, yes = pcall(p.IsFriendsWith, p, other)
	return ok and yes == true
end

function Letters.send(from: Player, to: number, text: string): (boolean, string?)
	local profile = Profiles.get(from)
	if not profile or from:GetAttribute("CharSlot") == nil then
		return false, "Choose a character first."
	end
	if to == from.UserId then
		return false, "You can't write to yourself."
	end
	local body = Text.sanitize(text, Config.LETTER_MAX)
	if not body or body == "" then
		return false, "Write something first."
	end
	local day = os.time() // 86400
	if profile.settings.letterDay ~= day then
		profile.settings.letterDay, profile.settings.lettersSent = day, 0
	end
	if (profile.settings.lettersSent or 0) >= Config.LETTER_DAILY then
		return false, string.format("You've sent %d letters today; more tomorrow.", Config.LETTER_DAILY)
	end
	if not friends(from, to) then
		return false, "You can write to people here, or to your Roblox friends."
	end
	if not mayWrite(from, to) then
		return false, "You can't send letters to that player."
	end
	if profile.pence + profile.bank < Config.LETTER_STAMP then
		return false, string.format("A stamp costs %s.", Money.format(Config.LETTER_STAMP))
	end
	local letter: Letter = { id = string.format("%d-%d-%d", from.UserId, os.time(), math.random(1, 1e6)), from = from.UserId, fromName = nameOf(from), at = os.time(), text = body }
	local full = false
	local ok = pcall(store.update, store, key(to), function(old: any): any
		local list = fresh(old)
		if #list >= Config.LETTER_BOX then
			full = true
			return nil
		end
		table.insert(list, letter)
		return list
	end)
	if not ok or full then
		return false, if full then "Their letterbox is full." else "The post couldn't take it just now; try again."
	end
	Economy.charge(from, Config.LETTER_STAMP, "purchase", "stamp") -- after it's posted, so a failed post costs nothing
	profile.settings.lettersSent = (profile.settings.lettersSent or 0) + 1
	local here = Players:GetPlayerByUserId(to)
	if here then
		Net.push(here, "Letter", "Arrived", { from = letter.fromName })
	end
	return true
end

local function update(p: Player, fn: ({ Letter }) -> { Letter }?): boolean
	local ok = pcall(store.update, store, key(p.UserId), function(old: any): any
		return fn(fresh(old))
	end)
	return ok
end

function Letters.read(p: Player, id: string): ({ [string]: any }?, string?)
	local found: Letter? = nil
	for _, l in Letters.box(p) do
		if l.id == id then
			found = l
		end
	end
	if not found then
		return nil, "That letter isn't in your letterbox."
	end
	local l = found :: Letter
	if not mayWrite(p, l.from) then
		return nil, "You can't read letters from that player."
	end
	local clean = Text.filterFor(l.text, l.from, p.UserId)
	if not clean then
		return nil, "This letter couldn't be read just now; try again."
	end
	if not l.read then
		update(p, function(list)
			for _, x in list do
				if x.id == id then
					x.read = true
				end
			end
			return list
		end)
	end
	return { id = l.id, fromName = l.fromName, at = l.at, text = clean }
end

local function unread(p: Player): number
	local n = 0
	for _, l in Letters.box(p) do
		n += if l.read then 0 else 1
	end
	return n
end

function Letters.init()
	local V = Net.V
	local rate = Config.LETTER_RATE
	Net.handle("Letter", "Contacts", { rate = rate, call = true }, function(p)
		local out = {}
		for _, q in Players:GetPlayers() do
			if q ~= p and q:GetAttribute("CharSlot") ~= nil then
				table.insert(out, { userId = q.UserId, name = nameOf(q), here = true })
			end
		end
		local ok, pages = pcall(Players.GetFriendsAsync, Players, p.UserId)
		if ok and pages then
			local got, page = pcall(pages.GetCurrentPage, pages)
			for _, f in if got and type(page) == "table" then page else {} do
				if not Players:GetPlayerByUserId(f.Id) then
					table.insert(out, { userId = f.Id, name = f.DisplayName or f.Username, here = false })
				end
			end
		end
		return { contacts = out, stamp = Money.format(Config.LETTER_STAMP) }
	end)
	Net.handle("Letter", "Box", { rate = rate, call = true }, function(p)
		local out = {}
		for _, l in Letters.box(p) do
			table.insert(out, { id = l.id, fromName = l.fromName, at = l.at, read = l.read == true })
		end
		table.sort(out, function(a, b)
			return a.at > b.at
		end)
		return { letters = out }
	end)
	Net.handle("Letter", "Read", { schema = { id = V.str(48) }, rate = rate, call = true }, function(p, a)
		return Letters.read(p, a.id)
	end)
	Net.handle("Letter", "Delete", { schema = { id = V.str(48) }, rate = rate, call = true }, function(p, a)
		local good = update(p, function(list)
			for i = #list, 1, -1 do
				if list[i].id == a.id then
					table.remove(list, i)
				end
			end
			return list
		end)
		if not good then
			return nil, "Try again in a moment."
		end
		return {}
	end)
	Net.handle("Letter", "Send", { schema = { to = V.userId(), text = V.str(Config.LETTER_MAX) }, rate = rate, call = true }, function(p, a)
		local good, why = Letters.send(p, a.to, a.text)
		if not good then
			return nil, why
		end
		return {}
	end)
	local function watch(p: Player)
		p:GetAttributeChangedSignal("CharSlot"):Connect(function()
			if p:GetAttribute("CharSlot") ~= nil then
				task.spawn(function()
					local n = unread(p)
					if n > 0 and p.Parent == Players then
						Net.push(p, "Letter", "Count", { unread = n })
					end
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
end

return Letters
