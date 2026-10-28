--!strict
-- LondonServer.Property: homes and shops (PROPERTY.md). Deeds live in the account profile
-- (profile.properties, so every character shares them); each server puts them on free plots
-- (Lots) while the owner is here and for Config.PROPERTY_LINGER after, and shows their builds
-- (Builds). Estate agents are Config.COUNTERS of kind "estate".
--   Rent: the first period up front, then every Config.RENT_PERIOD from the bank (then the
--   wallet); Config.RENT_GRACE later an unpaid tenancy lapses. Nothing built is lost: renting
--   that kind again restores the deed and its build.
--   Buy: once; selling back pays Config.PROPERTY_SELL_BACK of the price. Ending a tenancy is free.
--   Keys: up to Config.PROPERTY_KEYS holders, each with enter / decorate / build / sell.
--   Doors of a property open for the owner, key holders with enter, anyone when it's unlocked or
--   the owner is "At Home", and always from inside (BUILDING §7).
-- Remotes (Property domain, calls): Get, Rent { counter, kind }, Buy { counter, kind },
--   Sell { counter, deed }, Lock { deed, locked }, Key { deed, userId, enter, decorate, build, sell },
--   AtHome { deed, on }, Name { deed, text }, Report { lot, reason }.
-- Pushes Property.State { deeds } after changes and Property.Notice { text }.
--   Property.can(player, lotName, perm) -> bool   Property.mayEnter(player, lotName) -> bool
--   Property.onProfileLoaded(player)  Property.onPlayerRemoving(player)  (from the boot script)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Money = require(Shared:WaitForChild("Money"))
local Text = require(Shared:WaitForChild("Text"))
local Types = require(Shared:WaitForChild("Types"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Counters = require(script.Parent:WaitForChild("Counters"))
local AdminLog = require(script.Parent:WaitForChild("AdminLog"))
local Doors = require(script.Parent:WaitForChild("Doors"))
local Lots = require(script.Parent:WaitForChild("Lots"))
local Builds = require(script.Parent:WaitForChild("Builds"))

local Property = {}

type Deed = Types.Deed
local PERMS = { "enter", "decorate", "build", "sell" }

local placed: { [number]: { [string]: string } } = {} -- userId -> deedId -> lot name
local leftAt: { [number]: number } = {} -- userId -> os.clock() they last left (linger token)
local warned: { [number]: { [string]: boolean } } = {} -- grace warnings sent this session
local reports: { [string]: { [number]: boolean } } = {} -- lot -> reporter userIds this session
local hiddenFor: { [string]: boolean } = {} -- lots hidden by reports this session

local function notice(player: Player, text: string)
	Net.push(player, "Property", "Notice", { text = text })
end

local function kindDef(kind: string): { [string]: any }?
	return Config.PROPERTY_KINDS[kind]
end

local function deedsOf(player: Player): { [string]: Deed }?
	local p = Profiles.get(player)
	return if p then p.properties else nil
end

local function lotOf(userId: number, deedId: string): string?
	local mine = placed[userId]
	return if mine then mine[deedId] else nil
end

-- Who owns the build on a lot, and the deed (nil if the owner isn't in this server).
function Property.deedAt(lotName: string): (Player?, Deed?)
	local c = Lots.claimOf(lotName)
	local owner = if c then Players:GetPlayerByUserId(c.userId) else nil
	local deeds = if owner then deedsOf(owner) else nil
	return owner, if deeds and c then deeds[c.deedId] else nil
end

function Property.can(player: Player, lotName: string, perm: string): boolean
	local c = Lots.claimOf(lotName)
	if not c then
		return false
	end
	if c.userId == player.UserId then
		return true
	end
	local _, deed = Property.deedAt(lotName)
	local k = deed and deed.keys and deed.keys[tostring(player.UserId)]
	return type(k) == "table" and k[perm] == true
end

function Property.mayEnter(player: Player, lotName: string): boolean
	local l = Lots.get(lotName)
	if not l then
		return true
	end
	-- read from the plot, so it still works while the owner is away and the house lingers
	local c = Lots.claimOf(lotName)
	if l.part:GetAttribute("LotLocked") ~= true or l.part:GetAttribute("AtHome") == true then
		return true
	end
	local enter = l.part:GetAttribute("LotEnter")
	if (c and c.userId == player.UserId) or (type(enter) == "string" and string.find(enter, "," .. player.UserId .. ",", 1, true)) then
		return true
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and hrp:IsA("BasePart") and Lots.inside(lotName, hrp.Position, -1) -- leaving
end

local function counts(deeds: { [string]: Deed }): (number, number)
	local homes, businesses = 0, 0
	for _, d in deeds do
		local k = kindDef(d.kind)
		if k and not d.lapsed then
			if k.home then
				homes += 1
			else
				businesses += 1
			end
		end
	end
	return homes, businesses
end

local function describe(player: Player, d: Deed): { [string]: any }
	local k = kindDef(d.kind) or {}
	local lot = lotOf(player.UserId, d.id)
	local keys = {}
	for uid, perms in d.keys or {} do
		local holder = Players:GetPlayerByUserId(tonumber(uid) or 0)
		table.insert(keys, { userId = tonumber(uid), name = if holder then holder.DisplayName else nil, perms = perms })
	end
	return {
		id = d.id,
		kind = d.kind,
		kindName = k.name,
		name = d.name,
		tenure = d.tenure,
		lapsed = d.lapsed,
		paidUntil = d.paidUntil,
		rentText = if d.tenure == "rent" then Money.format(k.rent or 0) else nil,
		sellText = if d.tenure == "own" then Money.format(math.floor((k.buy or 0) * Config.PROPERTY_SELL_BACK)) else nil,
		lot = lot,
		address = if lot then Lots.address(lot) else nil,
		locked = d.locked,
		atHome = d.atHome,
		keys = keys,
	}
end

function Property.list(player: Player): { [string]: any }
	local deeds = deedsOf(player) or {}
	local out = {}
	for _, d in deeds do
		table.insert(out, describe(player, d))
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	local homes, businesses = counts(deeds)
	return { deeds = out, homes = homes, businesses = businesses, maxHomes = Config.PROPERTY_HOMES, maxBusinesses = Config.PROPERTY_BUSINESSES }
end

local function pushState(player: Player)
	Net.push(player, "Property", "State", Property.list(player))
end

-- Placing deeds on plots ---------------------------------------------------------------------
local placeWaiting: () -> ()

-- The plot carries what visitors need while the owner may be away (the house lingers): lock,
-- At Home, name plate and who holds an enter key (",123,456,").
local function stampPlot(lotName: string?, d: Deed?)
	local l = if lotName then Lots.get(lotName) else nil
	if not l then
		return
	end
	if not d then
		for _, attr in { "LotLocked", "AtHome", "LotName", "LotEnter" } do
			l.part:SetAttribute(attr, nil)
		end
		return
	end
	local enter = ","
	for uid, perms in d.keys or {} do
		if type(perms) == "table" and perms.enter then
			enter ..= uid .. ","
		end
	end
	l.part:SetAttribute("LotLocked", d.locked == true)
	l.part:SetAttribute("AtHome", if d.atHome then true else nil)
	l.part:SetAttribute("LotName", if d.name ~= "" then d.name else nil)
	l.part:SetAttribute("LotEnter", enter)
end

local function unplace(userId: number, deedId: string)
	local mine = placed[userId]
	local lot = mine and mine[deedId]
	if lot then
		mine[deedId] = nil
		Builds.hide(lot)
		Lots.release(lot)
		stampPlot(lot, nil)
		reports[lot], hiddenFor[lot] = nil, nil
		task.defer(placeWaiting)
	end
end

-- Puts a deed on a plot in this server and shows its build. `near` steers a first placement.
function Property.place(player: Player, d: Deed, near: Vector3?): string?
	if d.lapsed then
		return nil
	end
	local uid = player.UserId
	placed[uid] = placed[uid] or {}
	local lot = placed[uid][d.id]
	if not lot then
		Lots.waitReady()
		lot = Lots.choose(d.kind, if d.lotId ~= "" then d.lotId else nil, near)
		if not lot or not Lots.claim(lot, uid, d.id) then
			notice(player, string.format("There's no free %s plot in this server; yours will appear when one is free.", string.lower((kindDef(d.kind) or {}).name or "")))
			return nil
		end
		placed[uid][d.id] = lot
		d.lotId = lot
	end
	stampPlot(lot, d)
	task.spawn(Builds.show, player, d, lot)
	return lot
end

-- A plot came free: put down any deed of a player here that had no plot.
placeWaiting = function()
	for _, player in Players:GetPlayers() do
		for _, d in deedsOf(player) or {} do
			if not d.lapsed and not lotOf(player.UserId, d.id) then
				local free = Lots.choose(d.kind, if d.lotId ~= "" then d.lotId else nil)
				if free then
					Property.place(player, d)
					pushState(player)
				end
			end
		end
	end
end

-- Rent ---------------------------------------------------------------------------------------
-- Pays any rent that has fallen due (bank first); lapses the tenancy after the grace period.
function Property.settle(player: Player, d: Deed)
	if d.tenure ~= "rent" or d.lapsed then
		return
	end
	local k = kindDef(d.kind)
	if not k then
		return
	end
	local now = os.time()
	local guard = 0
	while d.paidUntil <= now and guard < 520 do
		guard += 1
		local good = Economy.charge(player, k.rent, "rent", d.id, true)
		if not good then
			break
		end
		d.paidUntil += Config.RENT_PERIOD
	end
	if d.paidUntil > now then
		return
	end
	if now > d.paidUntil + Config.RENT_GRACE then
		d.lapsed = true
		local lot = lotOf(player.UserId, d.id)
		if lot then
			Builds.save(lot)
		end
		unplace(player.UserId, d.id)
		notice(player, string.format("You couldn't pay the rent on your %s, so the tenancy has ended. Everything you built is kept: rent one again to get it back.", string.lower(k.name)))
		pushState(player)
	else
		warned[player.UserId] = warned[player.UserId] or {}
		if not warned[player.UserId][d.id] then
			warned[player.UserId][d.id] = true
			notice(player, string.format("Rent of %s is due on your %s. Put money in the bank within %d days or the tenancy ends.", Money.format(k.rent), string.lower(k.name), Config.RENT_GRACE // 86400))
		end
	end
end

-- Estate agents ------------------------------------------------------------------------------
local function atAgent(player: Player, counter: string): (boolean, Vector3?)
	if not Counters.isAt(player, counter, "estate") then
		return false, nil
	end
	local def = Counters.get(counter)
	return true, if def then Vector3.new(def.x, 0, def.z) else nil
end

local function canTake(player: Player, kind: string): (boolean, string?)
	local k = kindDef(kind)
	if not k or k.later then
		return false, "That isn't to let yet."
	end
	local deeds = deedsOf(player)
	if not deeds then
		return false, "Your profile isn't loaded yet."
	end
	local homes, businesses = counts(deeds)
	if k.home and homes >= Config.PROPERTY_HOMES then
		return false, string.format("You have %d homes already.", homes)
	end
	if not k.home and businesses >= Config.PROPERTY_BUSINESSES then
		return false, string.format("You have %d businesses already.", businesses)
	end
	return true
end

local function newDeed(player: Player, kind: string, tenure: string): Deed
	local p = Profiles.get(player) :: Types.Profile
	local id = "p" .. p.nextDeed
	p.nextDeed += 1
	local d: Deed = {
		id = id, kind = kind, district = "", tenure = tenure, paidUntil = 0, lapsed = false, lotId = "",
		name = "", doorColour = 0, keys = {}, locked = true, atHome = false, reportSessions = 0, createdAt = os.time(),
	}
	p.properties[id] = d
	return d
end

function Property.rent(player: Player, counter: string, kind: string): ({ [string]: any }?, string?)
	local here, near = atAgent(player, counter)
	if not here then
		return nil, "Speak to an estate agent."
	end
	local good, why = canTake(player, kind)
	if not good then
		return nil, why
	end
	local k = kindDef(kind) :: { [string]: any }
	local paid, payWhy = Economy.charge(player, k.rent, "rent", kind)
	if not paid then
		return nil, payWhy
	end
	-- a lapsed tenancy of the same kind comes back with its build
	local d: Deed? = nil
	for _, old in deedsOf(player) :: { [string]: Deed } do
		if old.kind == kind and old.lapsed and old.tenure == "rent" then
			d = old
			break
		end
	end
	local deed = d or newDeed(player, kind, "rent")
	deed.lapsed = false
	deed.paidUntil = os.time() + Config.RENT_PERIOD
	local lot = Property.place(player, deed, near)
	Profiles.save(player)
	pushState(player)
	return { deed = deed.id, lot = lot, address = if lot then Lots.address(lot) else nil }
end

function Property.buy(player: Player, counter: string, kind: string): ({ [string]: any }?, string?)
	local here, near = atAgent(player, counter)
	if not here then
		return nil, "Speak to an estate agent."
	end
	local good, why = canTake(player, kind)
	if not good then
		return nil, why
	end
	local k = kindDef(kind) :: { [string]: any }
	local paid, payWhy = Economy.charge(player, k.buy, "property_buy", kind)
	if not paid then
		return nil, payWhy
	end
	local deed = newDeed(player, kind, "own")
	local lot = Property.place(player, deed, near)
	Profiles.save(player)
	pushState(player)
	return { deed = deed.id, lot = lot, address = if lot then Lots.address(lot) else nil }
end

-- Selling back (owned) or ending a tenancy (rented): furniture to storage, the build deleted.
function Property.sell(player: Player, counter: string, deedId: string): ({ [string]: any }?, string?)
	if not atAgent(player, counter) then
		return nil, "Speak to an estate agent."
	end
	local deeds = deedsOf(player)
	local d = deeds and deeds[deedId]
	if not deeds or not d then
		return nil, "That isn't yours."
	end
	local k = kindDef(d.kind) or { buy = 0, name = "property" }
	local lot = lotOf(player.UserId, deedId)
	if not Builds.dissolve(player, deedId, lot) then
		return nil, "The house couldn't be cleared just now; try again in a minute."
	end
	if lot then
		placed[player.UserId][deedId] = nil
		Lots.release(lot)
		task.defer(placeWaiting)
	end
	deeds[deedId] = nil
	local paid = 0
	if d.tenure == "own" then
		paid = math.floor(k.buy * Config.PROPERTY_SELL_BACK)
		Economy.pay(player, paid, "property_sell", d.kind)
	end
	Profiles.save(player)
	pushState(player)
	return { paid = paid, paidText = Money.format(paid) }
end

local function estatePayload(player: Player): { [string]: any }
	local kinds = {}
	Lots.waitReady()
	for _, kind in Config.PROPERTY_ORDER do
		local k = kindDef(kind) :: { [string]: any }
		if not k.later then
			table.insert(kinds, {
				kind = kind, name = k.name, home = k.home,
				rent = k.rent, rentText = Money.format(k.rent), buy = k.buy, buyText = Money.format(k.buy),
				free = Lots.freeCount(kind), storeys = k.storeys,
			})
		end
	end
	local mine = Property.list(player)
	mine.kinds = kinds
	return mine
end

-- The owner's menu -----------------------------------------------------------------------------
local function myDeed(player: Player, deedId: string): (Deed?, string?)
	local deeds = deedsOf(player)
	local d = deeds and deeds[deedId]
	if not d then
		return nil, "That isn't yours."
	end
	return d, nil
end

function Property.setKey(player: Player, deedId: string, userId: number, perms: { [string]: boolean }): (boolean, string?)
	local d, why = myDeed(player, deedId)
	if not d then
		return false, why
	end
	if userId == player.UserId then
		return false, "You have every key already."
	end
	local any = false
	local clean = {}
	for _, perm in PERMS do
		clean[perm] = perms[perm] == true
		any = any or clean[perm]
	end
	d.keys = d.keys or {}
	local id = tostring(userId)
	if not any then
		d.keys[id] = nil
		return true
	end
	local n = 0
	for uid in d.keys do
		if uid ~= id then
			n += 1
		end
	end
	if n >= Config.PROPERTY_KEYS then
		return false, string.format("A property can have %d key holders.", Config.PROPERTY_KEYS)
	end
	d.keys[id] = clean
	return true
end

function Property.setName(player: Player, deedId: string, text: string): (boolean, string?)
	local d, why = myDeed(player, deedId)
	if not d then
		return false, why
	end
	local clean = Text.sanitize(text, Config.PROPERTY_NAME_MAX)
	if clean == nil then
		return false, "That name can't be used."
	end
	if clean == "" then
		d.name = ""
		return true
	end
	local filtered = Text.filterBroadcast(clean, player.UserId)
	if not filtered or filtered ~= clean then
		return false, "That name can't be used."
	end
	d.name = filtered
	stampPlot(lotOf(player.UserId, deedId), d)
	return true
end

-- "Report this building" (BUILDING §7).
function Property.report(player: Player, lotName: string, reason: string): (boolean, string?)
	local owner, d = Property.deedAt(lotName)
	if not owner or not d then
		return false, "There's nothing to report here."
	end
	if owner == player then
		return false, "That's your own house."
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") or not Lots.inside(lotName, hrp.Position, 40) then
		return false, "Stand near the building to report it."
	end
	local set = reports[lotName] or {}
	reports[lotName] = set
	if set[player.UserId] then
		return true
	end
	set[player.UserId] = true
	AdminLog.add(player.UserId, "report:building", owner.UserId, reason .. " (" .. lotName .. ")")
	local n = 0
	for _ in set do
		n += 1
	end
	if n >= Config.REPORTS_TO_HIDE and not hiddenFor[lotName] then
		hiddenFor[lotName] = true
		Builds.setHidden(lotName, true)
		notice(owner, "Several people reported your house, so this server shows a plain house instead for now.")
		d.reportSessions = (d.reportSessions or 0) + 1
		if d.reportSessions >= Config.REPORT_SESSIONS_TO_DRAFT then
			d.reportSessions = 0
			local a = Builds.get(lotName)
			if a then
				a.build.published = false
				a.dirty = true
			end
			notice(owner, "Your house has been reported in more than one server; it's a draft again until you publish it.")
		end
	end
	return true
end

-- Lifecycle ------------------------------------------------------------------------------------
function Property.onProfileLoaded(player: Player)
	local deeds = deedsOf(player)
	if not deeds then
		return
	end
	leftAt[player.UserId] = nil
	for _, d in deeds do
		Property.settle(player, d)
	end
	for _, d in deeds do
		Property.place(player, d)
	end
	pushState(player)
end

-- Saves builds now (before the profile goes); the plots stay taken for Config.PROPERTY_LINGER.
function Property.onPlayerRemoving(player: Player)
	local uid = player.UserId
	Builds.saveOwner(uid)
	warned[uid] = nil
	local stamp = os.clock()
	leftAt[uid] = stamp
	task.delay(Config.PROPERTY_LINGER, function()
		if leftAt[uid] ~= stamp or Players:GetPlayerByUserId(uid) then
			return
		end
		for deedId in placed[uid] or {} do
			unplace(uid, deedId)
		end
		placed[uid] = nil
		leftAt[uid] = nil
	end)
end

function Property.init()
	Builds.can = Property.can
	Doors.canOpen = function(player: Player, leaf: BasePart): boolean
		local lot = leaf:GetAttribute("DoorLot")
		return type(lot) ~= "string" or Property.mayEnter(player, lot)
	end
	Counters.onOpen("estate", estatePayload)
	local V = Net.V
	local rate = Config.PROPERTY_RATE
	local deedV = V.str(12)
	Net.handle("Property", "Get", { call = true, rate = rate }, function(player)
		return Property.list(player)
	end)
	Net.handle("Property", "Rent", { schema = { counter = V.str(40), kind = V.str(20) }, rate = rate, call = true }, function(player, a)
		return Property.rent(player, a.counter, a.kind)
	end)
	Net.handle("Property", "Buy", { schema = { counter = V.str(40), kind = V.str(20) }, rate = rate, call = true }, function(player, a)
		return Property.buy(player, a.counter, a.kind)
	end)
	Net.handle("Property", "Sell", { schema = { counter = V.str(40), deed = deedV }, rate = rate, call = true }, function(player, a)
		return Property.sell(player, a.counter, a.deed)
	end)
	Net.handle("Property", "Lock", { schema = { deed = deedV, locked = V.bool() }, rate = rate, call = true }, function(player, a)
		local d, why = myDeed(player, a.deed)
		if not d then
			return nil, why
		end
		d.locked = a.locked
		stampPlot(lotOf(player.UserId, a.deed), d)
		pushState(player)
		return {}
	end)
	Net.handle("Property", "AtHome", { schema = { deed = deedV, on = V.bool() }, rate = rate, call = true }, function(player, a)
		local d, why = myDeed(player, a.deed)
		if not d then
			return nil, why
		end
		d.atHome = a.on
		stampPlot(lotOf(player.UserId, a.deed), d)
		pushState(player)
		return {}
	end)
	Net.handle("Property", "Key", {
		schema = { deed = deedV, userId = V.userId(), enter = V.bool(), decorate = V.bool(), build = V.bool(), sell = V.bool() },
		rate = rate,
		call = true,
	}, function(player, a)
		local good, why = Property.setKey(player, a.deed, a.userId, { enter = a.enter, decorate = a.decorate, build = a.build, sell = a.sell })
		if not good then
			return nil, why
		end
		stampPlot(lotOf(player.UserId, a.deed), (deedsOf(player) or {})[a.deed])
		pushState(player)
		return {}
	end)
	Net.handle("Property", "Name", { schema = { deed = deedV, text = V.str(Config.PROPERTY_NAME_MAX * 4) }, rate = rate, call = true }, function(player, a)
		local good, why = Property.setName(player, a.deed, a.text)
		if not good then
			return nil, why
		end
		pushState(player)
		return {}
	end)
	Net.handle("Property", "Report", {
		schema = { lot = V.str(20), reason = V.enum(Config.REPORT_REASONS) },
		rate = rate,
		call = true,
	}, function(player, a)
		local good, why = Property.report(player, a.lot, a.reason)
		if not good then
			return nil, why
		end
		return {}
	end)
	task.spawn(function()
		while true do
			task.wait(Config.RENT_CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				for _, d in deedsOf(player) or {} do
					Property.settle(player, d)
				end
			end
		end
	end)
end

return Property
