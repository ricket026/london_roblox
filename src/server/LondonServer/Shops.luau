--!strict
-- LondonServer.Shops: shopkeeping (SHOPS.md §2-5). A shop is either a property of kind "shop" with
-- a counter_till piece in its build (settings, stock and till in deed.shop, in the owner's
-- profile), or a market stall (Config.COUNTERS kind "stall") rented per in-game day in this server.
-- Customers buy at the till; the money waits in the till and banks itself at
-- Config.SHOP_TILL_BANK_AT, when the shop closes, or when someone presses "Bank the till".
--   A shop is open only while its owner is in the server and someone who may sell (the owner,
--   a key holder with "sell", the stall's renter) is within Config.SHOP_TILL_RANGE of the till.
--   A property shop also needs a shopfront on the street, a counter with a till and a display.
--   NPC customers (first slice: no walking NPCs yet): every Config.SHOP_NPC_SECONDS an open shop
--   may sell one or two of an item of its trade; the chance follows price, appeal (fittings, lamps, plants),
--   footfall and a quiet-server bonus, at most Config.SHOP_NPC_HOURLY_CAP pence an hour.
-- Remotes (Shop domain, calls): Menu { shop }, Buy { shop, item, by, count }, Open { shop, open },
--   Restock { shop, slot, count, from }, Unstock { shop, item, by, count },
--   Price { shop, item, pence }, Settings { shop, trade, sign }, BankTill { shop },
--   Wage { shop, userId, pence } (owner: an assistant's wage per in-game day, 0 = none),
--   RentStall { counter }, LeaveStall { counter }.   ("shop" = the plot name or the stall id)
-- The till's prompt pushes Counter.Open { kind = "playershop" }; a stall's counter pushes
-- Counter.Open { kind = "stall" }. Pushes Shop.Notice { text } to whoever minds the shop.
-- Shop assistants (SHOPS §6): a key holder with Till who holds the ShopAssistant role and minds an
-- open shop is paid their wage from the owner's bank each minute (ledger "wage_staff"), and gets
-- Config.JOBS.ShopAssistant.xpPerSale job XP for each sale made while they mind it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Money = require(Shared:WaitForChild("Money"))
local Items = require(Shared:WaitForChild("Items"))
local Text = require(Shared:WaitForChild("Text"))
local Types = require(Shared:WaitForChild("Types"))
local Kit = require(Shared:WaitForChild("Kit"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))
local Counters = require(script.Parent:WaitForChild("Counters"))
local World = require(script.Parent:WaitForChild("World"))
local Lots = require(script.Parent:WaitForChild("Lots"))
local Builds = require(script.Parent:WaitForChild("Builds"))
local Property = require(script.Parent:WaitForChild("Property"))
local Jobs = require(script.Parent:WaitForChild("Jobs"))
local Daily = require(script.Parent:WaitForChild("Daily"))
local Roles = require(Shared:WaitForChild("Roles"))

local Shops = {}
Shops.rng = Random.new()

type Stack = Types.Stack
export type Data = {
	trade: string, sign: string, prices: { [string]: number }, stock: { Stack },
	till: number, tillNpc: number, tradeAt: number, wages: { [string]: number }?,
}
export type Shop = {
	id: string, kind: string, lot: string?, counter: string?, ownerId: number, data: Data,
	open: boolean, npcHour: number, npcSpent: number, paidUntil: number,
}

local propertyShops: { [string]: Shop } = {}
local stalls: { [string]: Shop } = {}
local owed: { [Player]: number } = {} -- fractions of a penny of wages not yet paid

local function newData(trade: string, sign: string): Data
	return { trade = trade, sign = sign, prices = {}, stock = {}, till = 0, tillNpc = 0, tradeAt = 0 }
end

local function displayName(p: Player): string
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

-- The shop with this id, if it exists and is still valid (a property shop needs its owner here).
function Shops.get(id: string): Shop?
	local stall = stalls[id]
	if stall then
		return stall
	end
	if Lots.kindOf(id) ~= "shop" then
		return nil
	end
	local owner, deed = Property.deedAt(id)
	if not owner or not deed or deed.kind ~= "shop" then
		return nil
	end
	deed.shop = deed.shop or newData("grocer", "")
	local s = propertyShops[id]
	if not s or s.ownerId ~= owner.UserId or s.data ~= deed.shop then
		s = { id = id, kind = "property", lot = id, counter = nil, ownerId = owner.UserId, data = deed.shop, open = false, npcHour = 0, npcSpent = 0, paidUntil = 0 }
		propertyShops[id] = s
	end
	return s
end

local function owner(s: Shop): Player?
	return Players:GetPlayerByUserId(s.ownerId)
end

local function isOwner(player: Player, s: Shop): boolean
	return player.UserId == s.ownerId
end

local function canSell(player: Player, s: Shop): boolean
	if s.kind == "stall" then
		return isOwner(player, s)
	end
	return Property.can(player, s.lot :: string, "sell")
end

local function cats(s: Shop): { string }
	if s.kind == "stall" then
		return Config.STALL_CATS
	end
	local t = Config.SHOP_TRADES[s.data.trade]
	return if t then t.cats else {}
end

local function fits(s: Shop, itemId: string): boolean
	local it = Items.get(itemId)
	return it ~= nil and table.find(cats(s), it.cat) ~= nil
end

local function priceOf(s: Shop, itemId: string): number
	local it = Items.get(itemId)
	return s.data.prices[itemId] or (if it then it.base else 0)
end

-- The pieces of a property shop's build (none for a stall).
local function pieces(s: Shop): { Kit.Piece }
	local a = if s.lot then Builds.get(s.lot) else nil
	return if a then a.build.pieces else {}
end

-- Where the till is: the counter_till piece of a property shop, the stall's counter.
function Shops.tillPosition(s: Shop): Vector3?
	if s.kind == "stall" then
		return Counters.position(s.counter :: string)
	end
	local l = Lots.get(s.lot :: string)
	if not l then
		return nil
	end
	for _, p in pieces(s) do
		if p.id == "counter_till" then
			local x0, z0, x1, z1 = Kit.footprint(p)
			return Kit.toWorld(l.frame, (x0 + x1) / 2, p.y * Kit.STOREY + 2, (z0 + z1) / 2)
		end
	end
	return nil
end

local function near(player: Player, s: Shop, range: number): boolean
	local pos = Shops.tillPosition(s)
	return pos ~= nil and World.near(player, pos, range)
end

-- SHOPS §2: a shopfront on the street, a counter with a till, something to display stock on.
function Shops.fittedOut(s: Shop): (boolean, string?)
	if s.kind == "stall" then
		return true
	end
	local front, till, display = false, false, false
	for _, p in pieces(s) do
		if p.id == "wall_shopfront" and p.y == 0 and p.z == 0 then
			front = true
		elseif p.id == "counter_till" then
			till = true
		elseif p.id == "display_case" or p.id == "shelving" then
			display = true
		end
	end
	if not front then
		return false, "A shop needs a shopfront on the street."
	end
	if not till then
		return false, "Put a counter with a till in the shop."
	end
	if not display then
		return false, "Put up a display case or shelving for the stock."
	end
	return true
end

-- Appeal for NPC customers, 0-1: fittings, lamps, plants and rugs (stalls: a fixed 0.3).
function Shops.appeal(s: Shop): number
	if s.kind == "stall" then
		return 0.3
	end
	local score = 0
	for _, p in pieces(s) do
		if p.id == "display_case" or p.id == "shelving" then
			score += 0.15
		elseif p.id == "standard_lamp" or p.id == "chandelier" then
			score += 0.1
		elseif p.id == "plant_pot" or p.id == "flower_stand" or p.id == "rug" then
			score += 0.05
		end
	end
	return math.min(1, score)
end

local function minders(s: Shop): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if canSell(p, s) and near(p, s, Config.SHOP_TILL_RANGE) then
			table.insert(out, p)
		end
	end
	return out
end

local function tell(s: Shop, text: string)
	for _, p in minders(s) do
		Net.push(p, "Shop", "Notice", { text = text })
	end
end

-- Assistants on duty at this shop now: minding it, not the owner, holding the ShopAssistant role.
local function assistants(s: Shop): { Player }
	local out = {}
	if s.kind ~= "property" then
		return out
	end
	for _, p in minders(s) do
		if p.UserId ~= s.ownerId and p:GetAttribute(Roles.ROLE_ATTR) == "ShopAssistant" then
			table.insert(out, p)
		end
	end
	return out
end

local function creditSale(s: Shop)
	for _, p in assistants(s) do
		Jobs.addXp(p, "ShopAssistant", Config.JOBS.ShopAssistant.xpPerSale)
	end
end

local function title(s: Shop): string
	if s.data.sign ~= "" then
		return s.data.sign
	end
	if s.kind == "stall" then
		local o = owner(s)
		return if o then displayName(o) .. "'s Stall" else "Market Stall"
	end
	local t = Config.SHOP_TRADES[s.data.trade]
	return if t then t.name else "Shop"
end

-- Sign boards: the stall's counter sign, a property shop's shopfront fascias.
local function refreshSign(s: Shop)
	if s.kind == "stall" then
		local m = workspace:FindFirstChild("Counters")
		local c = m and m:FindFirstChild(s.counter :: string)
		local label = c and c:FindFirstChild("Sign") and c.Sign:FindFirstChildWhichIsA("SurfaceGui")
		local l = label and label:FindFirstChildWhichIsA("TextLabel")
		if l then
			l.Text = title(s)
		end
		return
	end
	local props = workspace:FindFirstChild("Properties")
	local m = props and props:FindFirstChild(s.lot :: string)
	if not m then
		return
	end
	for _, pm in m:GetChildren() do
		if pm:GetAttribute("Piece") == "wall_shopfront" then
			local fascia = pm:FindFirstChild("frame5")
			if fascia and fascia:IsA("BasePart") then
				local old = fascia:FindFirstChild("ShopSign")
				if old then
					old:Destroy()
				end
				local l = World.sign(fascia, Enum.NormalId.Back, title(s), Color3.fromRGB(196, 160, 72))
				local gui = l.Parent :: Instance
				gui.Name = "ShopSign"
			end
		end
	end
end

-- Till -------------------------------------------------------------------------------------
function Shops.bankTill(s: Shop)
	local o = owner(s)
	if not o or not Profiles.get(o) then
		return
	end
	if s.data.till > 0 and Economy.payBank(o, s.data.till, "shop_sale", s.id) then
		s.data.till = 0
	end
	if s.data.tillNpc > 0 and Economy.payBank(o, s.data.tillNpc, "npc_sale", s.id) then
		s.data.tillNpc = 0
	end
end

local function setOpen(s: Shop, open: boolean)
	if s.open == open then
		return
	end
	s.open = open
	if not open then
		Shops.bankTill(s)
	end
	if s.lot then
		local l = Lots.get(s.lot)
		if l then
			l.part:SetAttribute("ShopOpen", if open then true else nil)
			l.part:SetAttribute("ShopTrade", if open then s.data.trade else nil)
		end
	end
end

-- Stock ------------------------------------------------------------------------------------
local function findStack(s: Shop, itemId: string, by: number?): (Stack?, number?)
	for i, st in s.data.stock do
		if st.i == itemId and (st.by or 0) == (by or 0) then
			return st, i
		end
	end
	return nil, nil
end

local function addStock(s: Shop, st: Stack): boolean
	local have = findStack(s, st.i, st.by)
	if have then
		have.n += st.n
		return true
	end
	if #s.data.stock >= Config.SHOP_STOCK_STACKS then
		return false
	end
	table.insert(s.data.stock, { i = st.i, n = st.n, by = st.by, byName = st.byName })
	return true
end

local function takeStock(s: Shop, itemId: string, by: number?, n: number): Stack?
	local st, i = findStack(s, itemId, by)
	if not st or not i or st.n < n then
		return nil
	end
	st.n -= n
	if st.n == 0 then
		table.remove(s.data.stock, i)
	end
	return { i = st.i, n = n, by = st.by, byName = st.byName }
end

-- The menu ----------------------------------------------------------------------------------
function Shops.payload(player: Player, s: Shop): { [string]: any }
	local wallet, bank = Economy.balance(player)
	local stock = {}
	for _, st in s.data.stock do
		local it = Items.get(st.i)
		if it then
			local price = priceOf(s, st.i)
			table.insert(stock, {
				item = st.i, by = st.by or 0, name = it.name, byName = st.byName, n = st.n,
				price = price, priceText = Money.format(price),
				min = math.max(1, math.ceil(it.base * Config.SHOP_PRICE_MIN)), max = math.floor(it.base * Config.SHOP_PRICE_MAX),
			})
		end
	end
	local staff = canSell(player, s)
	local msg: { [string]: any } = {
		id = s.counter or s.id, shop = s.id, kind = if s.kind == "stall" then "stall" else "playershop",
		name = title(s), open = s.open, trade = s.data.trade, sign = s.data.sign,
		tradeName = (Config.SHOP_TRADES[s.data.trade] or {}).name, stock = stock,
		staff = staff, owner = isOwner(player, s), wallet = wallet, bank = bank,
		rented = true, mine = isOwner(player, s),
	}
	if staff then
		msg.till = s.data.till + s.data.tillNpc
		msg.tillText = Money.format(msg.till)
		local bag = {}
		for slot, st in (Profiles.get(player) :: Types.Profile).inventory.bag do
			if fits(s, st.i) then
				local it = Items.get(st.i) :: Items.Item
				table.insert(bag, { slot = slot, id = st.i, name = it.name, n = st.n, byName = st.byName })
			end
		end
		msg.bag = bag
		local fitted, why = Shops.fittedOut(s)
		msg.fitted = fitted
		msg.fittedWhy = why
	end
	if isOwner(player, s) and s.kind == "property" then
		local trades = {}
		for _, id in Config.SHOP_TRADE_ORDER do
			table.insert(trades, { id = id, name = Config.SHOP_TRADES[id].name })
		end
		msg.trades = trades
		-- key holders with Till, and their wages
		local _, deed = Property.deedAt(s.lot :: string)
		local staff = {}
		for uid, perms in (if deed then deed.keys else nil) or {} do
			if type(perms) == "table" and perms.sell then
				local p = Players:GetPlayerByUserId(tonumber(uid) or 0)
				local wage = (s.data.wages or {})[uid] or 0
				table.insert(staff, { userId = tonumber(uid), name = if p then displayName(p) else "Player " .. uid, wage = wage, wageText = Money.format(wage) })
			end
		end
		msg.staffList = staff
		msg.minWage, msg.maxWage = Config.SHOP_MIN_WAGE, Config.SHOP_MAX_WAGE
	end
	return msg
end

local function stallPayload(player: Player, def: Counters.Def): { [string]: any }
	local s = stalls[def.id]
	if s then
		return Shops.payload(player, s)
	end
	return { shop = def.id, rented = false, mine = false, rentText = Money.format(Config.STALL_RENT), stock = {}, open = false }
end

function Shops.openMenu(player: Player, id: string)
	local s = Shops.get(id)
	if s then
		Net.push(player, "Counter", "Open", Shops.payload(player, s))
	end
end

-- Actions ----------------------------------------------------------------------------------
function Shops.buy(player: Player, id: string, itemId: string, by: number, count: number): ({ [string]: any }?, string?)
	local s = Shops.get(id)
	if not s or not s.open then
		return nil, "The shop is closed."
	end
	if isOwner(player, s) then
		return nil, "That's your own shop."
	end
	if not near(player, s, Config.COUNTER_RANGE) then
		return nil, "Step up to the counter."
	end
	local st = findStack(s, itemId, if by == 0 then nil else by)
	if not st or st.n < count or count < 1 then
		return nil, "They haven't that many."
	end
	if not Inventory.canAdd(player, itemId, count, nil, st.by) then
		return nil, "Your bag is full."
	end
	local total = priceOf(s, itemId) * count
	local paid, why = Economy.charge(player, total, "shop_buy", s.id)
	if not paid then
		return nil, why
	end
	local taken = takeStock(s, itemId, st.by, count) :: Stack
	Inventory.add(player, itemId, count, nil, taken.by, taken.byName)
	s.data.till += total
	creditSale(s)
	Daily.record(player, "shop_buy")
	local it = Items.get(itemId) :: Items.Item
	tell(s, string.format("Sold %d × %s to %s for %s.", count, it.name, displayName(player), Money.format(total)))
	if s.data.till + s.data.tillNpc >= Config.SHOP_TILL_BANK_AT then
		Shops.bankTill(s)
	end
	local wallet, bank = Economy.balance(player)
	return { wallet = wallet, bank = bank, bought = it.name, count = count }
end

local function staffAt(player: Player, id: string): (Shop?, string?)
	local s = Shops.get(id)
	if not s then
		return nil, "That isn't a shop."
	end
	if not canSell(player, s) then
		return nil, "You don't work here."
	end
	if not near(player, s, Config.SHOP_TILL_RANGE) then
		return nil, "Go to the till."
	end
	return s, nil
end

function Shops.setOpen(player: Player, id: string, open: boolean): (boolean, string?)
	local s, why = staffAt(player, id)
	if not s then
		return false, why
	end
	if open then
		local fitted, fitWhy = Shops.fittedOut(s)
		if not fitted then
			return false, fitWhy
		end
	end
	setOpen(s, open)
	refreshSign(s)
	return true
end

function Shops.restock(player: Player, id: string, slot: number, count: number, from: string): (boolean, string?)
	local s, why = staffAt(player, id)
	if not s then
		return false, why
	end
	local st = Inventory.stackAt(player, slot, from)
	if not st or count < 1 or st.n < count then
		return false, "You haven't that many."
	end
	if not fits(s, st.i) then
		return false, "That isn't something this shop sells."
	end
	if not findStack(s, st.i, st.by) and #s.data.stock >= Config.SHOP_STOCK_STACKS then
		return false, "The shop has no room for anything new."
	end
	local taken = Inventory.take(player, slot, count, from)
	if not taken then
		return false, "You haven't that many."
	end
	addStock(s, taken)
	return true
end

function Shops.unstock(player: Player, id: string, itemId: string, by: number, count: number): (boolean, string?)
	local s = Shops.get(id)
	if not s or not isOwner(player, s) then
		return false, "Only the owner can take stock away."
	end
	local st = findStack(s, itemId, if by == 0 then nil else by)
	if not st or st.n < count or count < 1 then
		return false, "There aren't that many."
	end
	if not Inventory.canAdd(player, itemId, count, "bag", st.by) then
		return false, "Your bag is full."
	end
	local taken = takeStock(s, itemId, st.by, count) :: Stack
	Inventory.add(player, itemId, count, "bag", taken.by, taken.byName)
	return true
end

function Shops.setPrice(player: Player, id: string, itemId: string, pence: number): (boolean, string?)
	local s = Shops.get(id)
	if not s or not isOwner(player, s) then
		return false, "Only the owner sets prices."
	end
	local it = Items.get(itemId)
	if not it then
		return false, "Unknown item."
	end
	local lo, hi = math.max(1, math.ceil(it.base * Config.SHOP_PRICE_MIN)), math.max(1, math.floor(it.base * Config.SHOP_PRICE_MAX))
	if pence < lo or pence > hi then
		return false, string.format("Between %s and %s.", Money.format(lo), Money.format(hi))
	end
	s.data.prices[itemId] = pence
	return true
end

function Shops.settings(player: Player, id: string, trade: string, sign: string): (boolean, string?)
	local s = Shops.get(id)
	if not s or not isOwner(player, s) then
		return false, "Only the owner can change that."
	end
	if s.kind == "property" and trade ~= s.data.trade then
		if not Config.SHOP_TRADES[trade] then
			return false, "Unknown trade."
		end
		if s.data.tradeAt > 0 and os.time() - s.data.tradeAt < Config.SHOP_TRADE_CHANGE then
			return false, "A shop can change its trade once a week."
		end
		s.data.trade = trade
		s.data.tradeAt = os.time()
	end
	local clean = Text.sanitize(sign, Config.SHOP_SIGN_MAX)
	if clean == nil then
		return false, "That sign can't be used."
	end
	if clean ~= "" then
		local filtered = Text.filterBroadcast(clean, player.UserId)
		if not filtered or filtered ~= clean then
			return false, "That sign can't be used."
		end
	end
	s.data.sign = clean
	refreshSign(s)
	return true
end

-- Wages ----------------------------------------------------------------------------------------
function Shops.setWage(player: Player, id: string, userId: number, pence: number): (boolean, string?)
	local s = Shops.get(id)
	if not s or s.kind ~= "property" or not isOwner(player, s) then
		return false, "Only the owner sets wages."
	end
	if pence ~= 0 and (pence < Config.SHOP_MIN_WAGE or pence > Config.SHOP_MAX_WAGE) then
		return false, string.format("Between %s and %s a day.", Money.format(Config.SHOP_MIN_WAGE), Money.format(Config.SHOP_MAX_WAGE))
	end
	s.data.wages = s.data.wages or {}
	local wages = s.data.wages :: { [string]: number }
	wages[tostring(userId)] = if pence > 0 then pence else nil
	return true
end

-- One minute of wages for every assistant on duty at an open shop.
function Shops.payWages(seconds: number)
	local day = Config.DAY_MINUTES * 60
	for _, s in propertyShops do
		local o = owner(s)
		if s.open and o then
			for _, a in assistants(s) do
				local wage = (s.data.wages or {})[tostring(a.UserId)]
				if wage and wage > 0 then
					local due = (owed[a] or 0) + wage * seconds / day
					local whole = math.floor(due)
					owed[a] = due - whole
					if whole > 0 then
						if Economy.charge(o, whole, "wage_staff", s.id, true) then
							Economy.pay(a, whole, "wage_staff", s.id)
						else
							Net.push(a, "Shop", "Notice", { text = "The owner couldn't pay your wage." })
							Net.push(o, "Shop", "Notice", { text = "You haven't the money to pay your assistant." })
						end
					end
				end
			end
		end
	end
end

-- Market stalls ------------------------------------------------------------------------------
local function stallOf(player: Player): Shop?
	for _, s in stalls do
		if s.ownerId == player.UserId then
			return s
		end
	end
	return nil
end

function Shops.rentStall(player: Player, counter: string): (boolean, string?)
	if not Counters.isAt(player, counter, "stall") then
		return false, "Stand at the stall."
	end
	if stalls[counter] then
		return false, "Someone has this stall."
	end
	if stallOf(player) then
		return false, "You have a stall already."
	end
	local paid, why = Economy.charge(player, Config.STALL_RENT, "stall_rent", counter)
	if not paid then
		return false, why
	end
	local s: Shop = {
		id = counter, kind = "stall", lot = nil, counter = counter, ownerId = player.UserId,
		data = newData("", ""), open = false, npcHour = 0, npcSpent = 0,
		paidUntil = os.clock() + Config.DAY_MINUTES * 60,
	}
	stalls[counter] = s
	refreshSign(s)
	return true
end

-- Gives up a stall: the stock goes back to the renter (bag, then storage), the till is banked.
function Shops.leaveStall(counter: string)
	local s = stalls[counter]
	if not s then
		return
	end
	setOpen(s, false)
	local o = owner(s)
	if o and Profiles.get(o) then
		Shops.bankTill(s)
		for _, st in s.data.stock do
			if Inventory.add(o, st.i, st.n, "bag", st.by, st.byName) == 0 then
				Inventory.add(o, st.i, st.n, "storage", st.by, st.byName)
			end
		end
	end
	stalls[counter] = nil
	refreshSign({ id = counter, kind = "stall", counter = counter, ownerId = 0, data = newData("", ""), open = false, npcHour = 0, npcSpent = 0, paidUntil = 0 } :: any)
end

-- NPC customers ------------------------------------------------------------------------------
local function priceFactor(s: Shop, itemId: string): number
	local it = Items.get(itemId)
	if not it then
		return 0
	end
	local ratio = priceOf(s, itemId) / it.base
	return if ratio <= 1 then 1 elseif ratio <= 1.5 then 0.5 else 0.15
end

function Shops.npcTick(s: Shop)
	if not s.open then
		return
	end
	local hour = math.floor(os.time() / 3600)
	if s.npcHour ~= hour then
		s.npcHour, s.npcSpent = hour, 0
	end
	local choices, total = {}, 0
	for _, st in s.data.stock do
		if st.n > 0 and fits(s, st.i) then
			local w = priceFactor(s, st.i)
			if priceOf(s, st.i) + s.npcSpent <= Config.SHOP_NPC_HOURLY_CAP then
				table.insert(choices, { st = st, w = w })
				total += w
			end
		end
	end
	if total <= 0 then
		return
	end
	local pos = Shops.tillPosition(s)
	local crowd = 0
	for _, p in Players:GetPlayers() do
		if pos and World.near(p, pos, Config.SHOP_NPC_FOOTFALL_RANGE) then
			crowd += 1
		end
	end
	local quiet = if #Players:GetPlayers() < Config.SHOP_NPC_QUIET_PLAYERS then Config.SHOP_NPC_QUIET_BONUS else 1
	local chance = Config.SHOP_NPC_CHANCE * (0.5 + Shops.appeal(s)) * (1 + math.min(0.5, 0.1 * crowd)) * quiet * (total / #choices)
	if Shops.rng:NextNumber() >= chance then
		return
	end
	local roll = Shops.rng:NextNumber() * total
	for _, c in choices do
		roll -= c.w
		if roll <= 0 then
			local it = Items.get(c.st.i) :: Items.Item
			local price = priceOf(s, c.st.i)
			local n = if Shops.rng:NextNumber() < Config.SHOP_NPC_SECOND_ITEM and c.st.n >= 2 and s.npcSpent + 2 * price <= Config.SHOP_NPC_HOURLY_CAP then 2 else 1
			takeStock(s, c.st.i, c.st.by, n)
			s.data.tillNpc += price * n
			s.npcSpent += price * n
			creditSale(s)
			tell(s, string.format("A customer bought %s%s for %s.", if n > 1 then "2 × " else "", it.name, Money.format(price * n)))
			if s.data.till + s.data.tillNpc >= Config.SHOP_TILL_BANK_AT then
				Shops.bankTill(s)
			end
			return
		end
	end
end

-- Lifecycle ----------------------------------------------------------------------------------
-- Closes shops nobody is minding, banks full tills, charges stall rent each in-game day.
function Shops.check()
	for id, s in propertyShops do
		local valid = Shops.get(id) == s
		if s.open and (not valid or #minders(s) == 0) then
			setOpen(s, false)
			refreshSign(s)
		end
		if not valid then
			propertyShops[id] = nil
		end
	end
	for counter, s in stalls do
		if s.open and #minders(s) == 0 then
			setOpen(s, false)
		end
		if os.clock() >= s.paidUntil then
			local o = owner(s)
			if o and Economy.charge(o, Config.STALL_RENT, "stall_rent", counter) then
				s.paidUntil += Config.DAY_MINUTES * 60
			else
				if o then
					Net.push(o, "Shop", "Notice", { text = "You couldn't pay for your stall, so it's been let to someone else." })
				end
				Shops.leaveStall(counter)
			end
		end
	end
end

function Shops.onPlayerRemoving(player: Player)
	local stall = stallOf(player)
	if stall then
		Shops.leaveStall(stall.id)
	end
	for _, s in propertyShops do
		if s.ownerId == player.UserId then
			setOpen(s, false)
			Shops.bankTill(s)
		end
	end
end

-- On shutdown, before profiles save: stall stock back to its renters, every till banked.
function Shops.closeAll()
	for counter in stalls do
		Shops.leaveStall(counter)
	end
	for _, s in propertyShops do
		setOpen(s, false)
		Shops.bankTill(s)
	end
end

-- Till prompts and shop signs on property shops' builds, as their pieces are rendered.
local function watchBuild(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local piece = inst:GetAttribute("Piece")
	local lotModel = inst.Parent
	local lot = if lotModel then lotModel.Name else ""
	if Lots.kindOf(lot) ~= "shop" then
		return
	end
	if piece == "counter_till" then
		local part = inst:FindFirstChildWhichIsA("BasePart")
		if part then
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Shop"
			pp.ObjectText = "Till"
			pp.MaxActivationDistance = 8
			pp.RequiresLineOfSight = false
			pp.Parent = part
			pp.Triggered:Connect(function(player)
				Shops.openMenu(player, lot)
			end)
		end
	elseif piece == "wall_shopfront" then
		local s = Shops.get(lot)
		if s then
			task.defer(refreshSign, s)
		end
	end
end

function Shops.init()
	Counters.onOpen("stall", stallPayload)
	local props = World.folder("Properties")
	props.DescendantAdded:Connect(watchBuild)
	local V = Net.V
	local rate = Config.SHOP_RATE
	local shopV = V.str(40)
	local function result(good: boolean, why: string?): ({}?, string?)
		if good then
			return {}, nil
		end
		return nil, why
	end
	Net.handle("Shop", "Menu", { schema = { shop = shopV }, rate = rate, call = true }, function(player, a)
		local shop = Shops.get(a.shop)
		if shop then
			return Shops.payload(player, shop)
		end
		local def = Counters.get(a.shop)
		if def and def.kind == "stall" then
			return stallPayload(player, def)
		end
		return nil, "That shop has gone."
	end)
	Net.handle("Shop", "Buy", { schema = { shop = shopV, item = V.str(40), by = V.int(0, 2 ^ 53), count = V.int(1, 99) }, rate = rate, call = true }, function(player, a)
		return Shops.buy(player, a.shop, a.item, a.by, a.count)
	end)
	Net.handle("Shop", "Open", { schema = { shop = shopV, open = V.bool() }, rate = rate, call = true }, function(player, a)
		return result(Shops.setOpen(player, a.shop, a.open))
	end)
	Net.handle("Shop", "Restock", {
		schema = { shop = shopV, slot = V.int(1, Config.BAG_SLOTS * 10), count = V.int(1, 999), from = V.enum({ "bag", "storage" }) },
		rate = rate,
		call = true,
	}, function(player, a)
		return result(Shops.restock(player, a.shop, a.slot, a.count, a.from))
	end)
	Net.handle("Shop", "Unstock", { schema = { shop = shopV, item = V.str(40), by = V.int(0, 2 ^ 53), count = V.int(1, 999) }, rate = rate, call = true }, function(player, a)
		return result(Shops.unstock(player, a.shop, a.item, a.by, a.count))
	end)
	Net.handle("Shop", "Price", { schema = { shop = shopV, item = V.str(40), pence = V.int(1, 100000) }, rate = rate, call = true }, function(player, a)
		return result(Shops.setPrice(player, a.shop, a.item, a.pence))
	end)
	Net.handle("Shop", "Settings", { schema = { shop = shopV, trade = V.str(20), sign = V.str(Config.SHOP_SIGN_MAX * 4) }, rate = rate, call = true }, function(player, a)
		return result(Shops.settings(player, a.shop, a.trade, a.sign))
	end)
	Net.handle("Shop", "BankTill", { schema = { shop = shopV }, rate = rate, call = true }, function(player, a)
		local s, why = staffAt(player, a.shop)
		if not s then
			return nil, why
		end
		Shops.bankTill(s)
		return {}
	end)
	Net.handle("Shop", "Wage", { schema = { shop = shopV, userId = V.userId(), pence = V.int(0, Config.SHOP_MAX_WAGE) }, rate = rate, call = true }, function(player, a)
		return result(Shops.setWage(player, a.shop, a.userId, a.pence))
	end)
	Net.handle("Shop", "RentStall", { schema = { counter = shopV }, rate = rate, call = true }, function(player, a)
		return result(Shops.rentStall(player, a.counter))
	end)
	Net.handle("Shop", "LeaveStall", { schema = { counter = shopV }, rate = rate, call = true }, function(player, a)
		local s = stalls[a.counter]
		if not s or not isOwner(player, s) then
			return nil, "That isn't your stall."
		end
		Shops.leaveStall(a.counter)
		return {}
	end)
	task.spawn(function()
		while true do
			task.wait(Config.SHOP_CHECK_SECONDS)
			Shops.check()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			Shops.payWages(60)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		owed[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.SHOP_NPC_SECONDS)
			for _, s in propertyShops do
				Shops.npcTick(s)
			end
			for _, s in stalls do
				Shops.npcTick(s)
			end
		end
	end)
end

return Shops
