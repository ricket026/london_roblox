-- Phase 4 server: wholesale suppliers, a property shop (fitting out, stock, till, prices, trade,
-- sign, opening and closing, NPC customers), staff by key, and market stalls.
local Players = game:GetService("Players")
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0 -- daily money is tested in test_daily; keep balances exact here
local Net = require(Shared.Net)
local Kit = require(Shared.Kit)

local map = Instance.new("Folder")
map.Name = "Map"
local plots = Instance.new("Folder")
plots.Name = "Plots"
plots.Parent = map
local lot = Instance.new("Part")
lot.Name = "Lot_2434"
lot.Anchored = true
lot.Size = Vector3.new(26.4, 2.6, 40)
lot.CFrame = CFrame.new(-289.6, -0.7, -1212)
lot:SetAttribute("LotId", 2434)
lot:SetAttribute("District", "Covent Garden")
lot:SetAttribute("LotType", "Shop")
lot:SetAttribute("Frontage", 26)
lot:SetAttribute("Depth", 40)
lot.Parent = plots
map.Parent = workspace

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Economy = require(__find(LS .. "Economy"))
local Inventory = require(__find(LS .. "Inventory"))
local Counters = require(__find(LS .. "Counters"))
local Lots = require(__find(LS .. "Lots"))
local Builds = require(__find(LS .. "Builds"))
local Shops = require(__find(LS .. "Shops"))

local function call(p, domain, action, args)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain, msg, true)
end
local function join(id, name)
	local p = __addPlayer(id, name)
	for _ = 1, 200 do
		if p:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	assert(call(p, "Character", "Create", { slot = "1", first = name, last = "Tester", skin = 1, hair = "own", outfit = "frock" }).ok)
	return p
end
local function stand(p, at)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(at)
end
local function at(p, counter)
	stand(p, workspace.Counters[counter].Counter.Position + Vector3.new(0, 0, -4))
end
local function settle()
	for _ = 1, 20 do
		task.wait(0.1)
	end
end
local SHOP = "Lot_2434"
local function atTill(p)
	stand(p, Shops.tillPosition(Shops.get(SHOP)) + Vector3.new(0, 1, -3))
end

local S, Cu
test("wholesale: lots at 60%, only in opening hours, carried or delivered", function()
	S = join(701, "Sidney")
	Economy.pay(S, 60000, "admin", "test")
	local sup = Counters.get("supplier_spitalfields")
	sup.hours = { 0, 24 }
	at(S, "supplier_spitalfields")
	local before = Profiles.get(S).pence
	local res = call(S, "Counter", "Wholesale", { counter = "supplier_spitalfields", item = "bun", size = 10, deliver = false })
	ok(res.ok, tostring(res.err))
	eq(Profiles.get(S).pence, before - 6, "10 buns at 60% of 1d = 6d")
	eq(Inventory.count(S, "bun"), 10)
	res = call(S, "Counter", "Wholesale", { counter = "supplier_spitalfields", item = "bun", size = 7, deliver = false })
	eq(res.ok, false, "lots are 5, 10 or 20")
	res = call(S, "Counter", "Wholesale", { counter = "supplier_spitalfields", item = "apple", size = 5, deliver = true })
	ok(res.ok, tostring(res.err))
	eq(Inventory.count(S, "apple", "storage"), 0, "not there yet")
	__advance(Config.DELIVERY_SECONDS + 1)
	eq(Inventory.count(S, "apple", "storage"), 5, "delivered to storage")
	sup.hours = { 5, 6 }
	game:GetService("Lighting").ClockTime = 20
	__advance(Config.COUNTER_RATE.per)
	res = call(S, "Counter", "Wholesale", { counter = "supplier_spitalfields", item = "bun", size = 5, deliver = false })
	eq(res.ok, false)
	ok(string.find(res.err, "Closed"), res.err)
	sup.hours = { 0, 24 }
end)

test("a shop must be fitted out before it opens", function()
	at(S, "estate_covent")
	local res = call(S, "Property", "Buy", { counter = "estate_covent", kind = "shop" })
	ok(res.ok, tostring(res.err))
	eq(res.data.lot, SHOP)
	settle()
	local s = Shops.get(SHOP)
	ok(s ~= nil, "a shop")
	eq(Shops.tillPosition(s), nil, "the starter shop has a plain counter, no till")
	-- fit it out: a counter with a till and a display case, from storage
	Inventory.add(S, "counter_till", 1, "storage")
	Inventory.add(S, "display_case", 1, "storage")
	local l = Lots.get(SHOP)
	stand(S, Kit.toWorld(l.frame, l.w / 2, 3, l.d / 2))
	ok(call(S, "Build", "Enter", { lot = SHOP }).ok)
	res = call(S, "Build", "Place", { lot = SHOP, id = "counter_till", x = 24, z = 16, y = 0, r = 0, c = 0 }) -- clear of the stairs (x 4-8)
	ok(res.ok, tostring(res.err))
	atTill(S)
	res = call(S, "Shop", "Open", { shop = SHOP, open = true })
	eq(res.ok, false)
	ok(string.find(res.err, "display"), res.err)
	res = call(S, "Build", "Place", { lot = SHOP, id = "display_case", x = 24, z = 8, y = 0, r = 0, c = 0 })
	ok(res.ok, tostring(res.err))
	call(S, "Build", "Exit", { lot = SHOP })
	atTill(S)
	res = call(S, "Shop", "Open", { shop = SHOP, open = true })
	ok(res.ok, tostring(res.err))
	eq(Shops.get(SHOP).open, true)
	eq(lot:GetAttribute("ShopOpen"), true, "the plot shows the shop is open")
	local till
	for _, pm in workspace.Properties[SHOP]:GetChildren() do
		if pm:GetAttribute("Piece") == "counter_till" then
			till = pm
		end
	end
	ok(till:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil, "the till has a Shop prompt")
end)

test("stock from the bag, a customer buys, the till fills", function()
	__advance(Config.SHOP_RATE.per)
	local slot
	for k, st in Profiles.get(S).inventory.bag do
		if st.i == "bun" then
			slot = k
		end
	end
	local res = call(S, "Shop", "Restock", { shop = SHOP, slot = slot, count = 10, from = "bag" })
	ok(res.ok, tostring(res.err))
	eq(Inventory.count(S, "bun"), 0)
	Cu = join(702, "Celia")
	atTill(Cu)
	local wallet = Profiles.get(Cu).pence
	res = call(Cu, "Shop", "Buy", { shop = SHOP, item = "bun", by = 0, count = 2 })
	ok(res.ok, tostring(res.err))
	eq(Profiles.get(Cu).pence, wallet - 2)
	eq(Inventory.count(Cu, "bun"), 2)
	eq(Shops.get(SHOP).data.till, 2)
	res = call(S, "Shop", "Buy", { shop = SHOP, item = "bun", by = 0, count = 1 })
	eq(res.ok, false, "not from your own shop")
	res = call(Cu, "Shop", "Restock", { shop = SHOP, slot = 1, count = 1, from = "bag" })
	eq(res.ok, false, "customers can't stock the shelves")
	-- the menu a customer sees
	res = call(Cu, "Shop", "Menu", { shop = SHOP })
	ok(res.ok)
	eq(res.data.stock[1].n, 8)
	eq(res.data.staff, false)
	eq(res.data.till, nil, "customers don't see the till")
end)

test("prices within 0.8x-3x of base; trade once a week; the sign", function()
	local res = call(S, "Shop", "Price", { shop = SHOP, item = "bun", pence = 2 })
	ok(res.ok, tostring(res.err))
	res = call(S, "Shop", "Price", { shop = SHOP, item = "bun", pence = 4 })
	eq(res.ok, false, "more than 3x base")
	res = call(Cu, "Shop", "Price", { shop = SHOP, item = "bun", pence = 1 })
	eq(res.ok, false, "only the owner")
	res = call(S, "Shop", "Settings", { shop = SHOP, trade = "baker", sign = "Tester's Bakery" })
	ok(res.ok, tostring(res.err))
	eq(Shops.get(SHOP).data.trade, "baker")
	__advance(Config.SHOP_RATE.per)
	res = call(S, "Shop", "Settings", { shop = SHOP, trade = "florist", sign = "Tester's Bakery" })
	eq(res.ok, false)
	ok(string.find(res.err, "once a week"), res.err)
	local sign
	for _, pm in workspace.Properties[SHOP]:GetChildren() do
		local g = pm:FindFirstChild("ShopSign", true)
		if g then
			sign = g:FindFirstChildWhichIsA("TextLabel")
		end
	end
	ok(sign ~= nil, "the fascia has the sign")
	eq(sign.Text, "Tester's Bakery")
end)

test("NPC customers buy what fits the trade, up to the hourly cap", function()
	local s = Shops.get(SHOP)
	Shops.rng = { NextNumber = function()
		return 0
	end }
	local n = s.data.stock[1].n
	Shops.npcTick(s)
	eq(s.data.stock[1].n, n - 2, "a customer bought two (the stub always rolls 0)")
	eq(s.data.tillNpc, 4, "at the shop's price")
	s.npcSpent = Config.SHOP_NPC_HOURLY_CAP - 1
	Shops.npcTick(s)
	eq(s.data.stock[1].n, n - 2, "the cap stops it")
	Shops.rng = Random.new()
end)

test("a key holder with Till may run it; the shop closes when nobody minds the till", function()
	local E = join(703, "Edna")
	ok(call(S, "Property", "Key", { deed = (function()
		for id in Profiles.get(S).properties do
			return id
		end
	end)(), userId = 703, enter = true, decorate = false, build = false, sell = true }).ok)
	atTill(E)
	local res = call(E, "Shop", "BankTill", { shop = SHOP })
	ok(res.ok, tostring(res.err))
	eq(Shops.get(SHOP).data.till, 0, "banked")
	res = call(E, "Shop", "Price", { shop = SHOP, item = "bun", pence = 1 })
	eq(res.ok, false, "staff don't set prices")
	-- everyone walks off
	local bank = Profiles.get(S).bank
	Shops.get(SHOP).data.till = 5
	for _, p in { S, E, Cu } do
		stand(p, Vector3.new(0, 3, 0))
	end
	__advance(Config.SHOP_CHECK_SECONDS + 1)
	eq(Shops.get(SHOP).open, false, "closed")
	eq(Profiles.get(S).bank, bank + 5, "and the till banked")
	atTill(Cu)
	res = call(Cu, "Shop", "Buy", { shop = SHOP, item = "bun", by = 0, count = 1 })
	eq(res.ok, false)
	ok(string.find(res.err, "closed"), res.err)
end)

test("shop assistants: a wage from the owner's bank while on duty, XP for sales", function()
	local E = game:GetService("Players"):GetPlayerByUserId(703)
	__advance(300)
	ok(call(E, "Identity", "ChooseRole", { role = "ShopAssistant" }).ok)
	atTill(S)
	ok(call(S, "Shop", "Open", { shop = SHOP, open = true }).ok)
	local res = call(S, "Shop", "Wage", { shop = SHOP, userId = 703, pence = 30 })
	eq(res.ok, false, "below the minimum wage")
	ok(call(S, "Shop", "Wage", { shop = SHOP, userId = 703, pence = 120 }).ok)
	local menu = call(S, "Shop", "Menu", { shop = SHOP })
	eq(menu.data.staffList[1].wage, 120, "the owner sees the wage")
	atTill(E)
	stand(S, Shops.tillPosition(Shops.get(SHOP)) + Vector3.new(4, 1, -3))
	local Profiles2 = Profiles
	local bank, wallet = Profiles2.get(S).bank, Profiles2.get(E).pence
	Shops.payWages(60)
	local due = 120 * 60 // (Config.DAY_MINUTES * 60)
	eq(Profiles2.get(E).pence, wallet + due, "a minute's wage")
	eq(Profiles2.get(S).bank, bank - due, "from the owner's bank")
	-- a sale while E minds the till
	local slot
	Inventory.add(S, "bun", 2)
	for k, st in Profiles2.get(S).inventory.bag do
		if st.i == "bun" then
			slot = k
		end
	end
	ok(call(S, "Shop", "Restock", { shop = SHOP, slot = slot, count = 2, from = "bag" }).ok)
	atTill(Cu)
	ok(call(Cu, "Shop", "Buy", { shop = SHOP, item = "bun", by = 0, count = 1 }).ok)
	eq(Profiles2.progress(E).jobs.ShopAssistant.xp, Config.JOBS.ShopAssistant.xpPerSale)
	ok(call(S, "Shop", "Open", { shop = SHOP, open = false }).ok)
end)

test("market stalls: rent per in-game day, run from the bag, give up", function()
	local D = join(704, "Dulcie")
	Economy.pay(D, 1000, "admin", "test")
	Inventory.add(D, "violets", 6)
	at(D, "stall_cg_1")
	local before = Profiles.get(D).pence
	local res = call(D, "Shop", "RentStall", { counter = "stall_cg_1" })
	ok(res.ok, tostring(res.err))
	eq(Profiles.get(D).pence, before - Config.STALL_RENT)
	res = call(Cu, "Shop", "RentStall", { counter = "stall_cg_1" })
	eq(res.ok, false, "taken")
	local slot
	for k, st in Profiles.get(D).inventory.bag do
		if st.i == "violets" then
			slot = k
		end
	end
	ok(call(D, "Shop", "Restock", { shop = "stall_cg_1", slot = slot, count = 6, from = "bag" }).ok)
	ok(call(D, "Shop", "Open", { shop = "stall_cg_1", open = true }).ok)
	at(Cu, "stall_cg_1")
	res = call(Cu, "Shop", "Buy", { shop = "stall_cg_1", item = "violets", by = 0, count = 1 })
	ok(res.ok, tostring(res.err))
	eq(workspace.Counters.stall_cg_1.Sign:FindFirstChildWhichIsA("SurfaceGui"):FindFirstChildWhichIsA("TextLabel").Text, "Dulcie Tester's Stall")
	-- shut (or NPC customers would buy the rest during the day), then a day later, rent again
	ok(call(D, "Shop", "Open", { shop = "stall_cg_1", open = false }).ok)
	eq(Profiles.get(D).bank, 1, "closing banks the till")
	local p2 = Profiles.get(D).pence
	__advance(Config.DAY_MINUTES * 60 + Config.SHOP_CHECK_SECONDS)
	eq(Profiles.get(D).pence, p2 - Config.STALL_RENT, "rent for the next day")
	ok(call(D, "Shop", "LeaveStall", { counter = "stall_cg_1" }).ok)
	eq(Inventory.count(D, "violets"), 5, "unsold stock back in the bag")
	eq(workspace.Counters.stall_cg_1.Sign:FindFirstChildWhichIsA("SurfaceGui"):FindFirstChildWhichIsA("TextLabel").Text, "Market Stall")
end)

test("no unexpected warnings", function()
	local w = {}
	for _, line in __warnings() do
		if not string.find(line, "^%[Net%] rejected") then
			table.insert(w, line)
		end
	end
	eq(#w, 0, table.concat(w, " | "))
end)
