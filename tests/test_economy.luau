-- Phase 2: the ledger, NPC counters, bank, inventory and hand-overs, through the real server.
local Players = game:GetService("Players")
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0 -- daily money is tested in test_daily; keep balances exact here
local Net = require(Shared.Net)
local Money = require(Shared.Money)
__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Economy = require(__find(LS .. "Economy"))
local Inventory = require(__find(LS .. "Inventory"))
local Counters = require(__find(LS .. "Counters"))
local Store = require(__find(LS .. "Store"))

local function call(p, domain, action, args)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain, msg, true)
end
local function join(id, name, first)
	local p = __addPlayer(id, name)
	for _ = 1, 200 do
		if p:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	local res = call(p, "Character", "Create", { slot = "1", first = first or name, last = "Tester", skin = 1, hair = "own", outfit = "frock" })
	assert(res.ok, tostring(res.err))
	return p
end
local function stand(p, at)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(at)
end
local function counterPos(id)
	local c = workspace.Counters[id].Counter
	return c.Position
end

test("pay, charge (wallet then bank) and refusals", function()
	local p = join(301, "Ivy")
	local prof = Profiles.get(p)
	eq(prof.pence, Config.START_PENCE)
	ok(Economy.pay(p, 100, "job_pay", "test"))
	eq(prof.pence, Config.START_PENCE + 100)
	prof.bank = 50
	local good, why = Economy.charge(p, prof.pence + 60, "purchase", "big")
	eq(good, false, "can't afford wallet + bank")
	ok(string.find(why, "costs"), why)
	ok(Economy.charge(p, prof.pence + 20, "purchase", "big"))
	eq(prof.pence, 0)
	eq(prof.bank, 30, "rest came from the bank")
	eq((Economy.change(p, -1, "purchase")), false, "no going below zero")
	ok(Economy.change(p, -100, "fine", "test"), "fines may make debt")
	eq(prof.pence, -100)
	eq((Economy.change(p, -Config.DEBT_MAX, "fine")), false, "debt is capped")
	raises(function()
		Economy.pay(p, 5, "not_a_reason")
	end, "bad reason")
end)

test("the ledger records reasons and the wallet push goes out", function()
	local p = Players:GetPlayerByUserId(301)
	local lines = Economy.recent(p)
	eq(#lines, 3, "pay, charge, fine (refusals aren't recorded)")
	eq(lines[1].reason, "fine")
	ok(Economy.totals().job_pay >= 100)
	local pushes = __received(p, "ProfileEvent", "Wallet")
	ok(#pushes > 0, "wallet pushed to the client")
	eq(pushes[#pushes].pence, Profiles.get(p).pence)
end)

test("buying at a counter: must stand there, pays, goes in the bag", function()
	local p = join(302, "Ada")
	local prof = Profiles.get(p)
	stand(p, Vector3.new(0, 3, 0))
	local res = call(p, "Counter", "Buy", { counter = "kiosk_park", item = "tea", count = 2 })
	eq(res.ok, false, "too far")
	stand(p, counterPos("kiosk_park") + Vector3.new(0, 0, -4))
	res = call(p, "Counter", "Buy", { counter = "kiosk_park", item = "tea", count = 2 })
	ok(res.ok, tostring(res.err))
	eq(prof.pence, Config.START_PENCE - 2)
	eq(Inventory.count(p, "tea"), 2)
	res = call(p, "Counter", "Buy", { counter = "kiosk_park", item = "piano_upright", count = 1 })
	eq(res.ok, false, "kiosk doesn't sell pianos")
	res = call(p, "Counter", "Buy", { counter = "kiosk_park", item = "tea", count = 50 })
	eq(res.ok, false, "more than a stack")
end)

test("furniture goes to storage; a full bag refuses before charging", function()
	local p = Players:GetPlayerByUserId(302)
	local prof = Profiles.get(p)
	Economy.pay(p, 2000, "admin", "test")
	stand(p, counterPos("furniture_clerkenwell") + Vector3.new(0, 0, -4))
	local res = call(p, "Counter", "Buy", { counter = "furniture_clerkenwell", item = "armchair", count = 1 })
	ok(res.ok, tostring(res.err))
	eq(Inventory.count(p, "armchair", "storage"), 1)
	eq(#prof.inventory.bag, 1, "only the tea in the bag")
	for i = 1, Config.BAG_SLOTS - 1 do
		prof.inventory.bag[#prof.inventory.bag + 1] = { i = "kite", n = 1 }
	end
	local before = prof.pence
	stand(p, counterPos("kiosk_park") + Vector3.new(0, 0, -4))
	res = call(p, "Counter", "Buy", { counter = "kiosk_park", item = "bun", count = 1 })
	eq(res.ok, false)
	eq(res.err, "Your bag is full.")
	eq(prof.pence, before, "nothing charged")
	__advance(Config.COUNTER_RATE.per)
	res = call(p, "Counter", "Buy", { counter = "kiosk_park", item = "tea", count = 3 })
	ok(res.ok, tostring(res.err) .. ": tea still fits on the existing stack (5 per stack)")
	for _ = 1, Config.BAG_SLOTS - 1 do
		table.remove(prof.inventory.bag)
	end
end)

test("bank: deposits and withdrawals only at a bank counter", function()
	local p = Players:GetPlayerByUserId(302)
	local prof = Profiles.get(p)
	local res = call(p, "Economy", "Bank", { counter = "po_trafalgar", action = "deposit", pence = 100 })
	eq(res.ok, false, "not at the post office")
	stand(p, counterPos("po_trafalgar") + Vector3.new(0, 0, -4))
	local w, b = prof.pence, prof.bank
	res = call(p, "Economy", "Bank", { counter = "po_trafalgar", action = "deposit", pence = 100 })
	ok(res.ok, tostring(res.err))
	eq(prof.pence, w - 100)
	eq(prof.bank, b + 100)
	res = call(p, "Economy", "Bank", { counter = "po_trafalgar", action = "withdraw", pence = b + 101 })
	eq(res.ok, false, "can't withdraw more than banked")
	res = call(p, "Economy", "Bank", { counter = "kiosk_park", action = "deposit", pence = 1 })
	eq(res.ok, false, "a kiosk isn't a bank")
end)

test("using and holding items", function()
	local p = Players:GetPlayerByUserId(302)
	local slot
	for k, s in Profiles.get(p).inventory.bag do
		if s.i == "tea" then
			slot = k
		end
	end
	local n = Inventory.count(p, "tea")
	local res = call(p, "Inventory", "Hold", { slot = slot })
	ok(res.ok, tostring(res.err))
	eq(p:GetAttribute("HeldItem"), "tea")
	ok(p.Character:FindFirstChild("HeldItem") ~= nil, "held part on the character")
	res = call(p, "Inventory", "Use", { slot = slot })
	ok(res.ok, tostring(res.err))
	ok(string.find(res.data.text, "drink"), res.data.text)
	eq(Inventory.count(p, "tea"), n - 1)
	res = call(p, "Inventory", "Hold", { slot = 0 })
	eq(p:GetAttribute("HeldItem"), nil)
end)

test("hand-overs: offer, accept, and every check on accept", function()
	local a = Players:GetPlayerByUserId(302)
	local b = join(303, "Bea")
	local pa, pb = Profiles.get(a), Profiles.get(b)
	stand(a, Vector3.new(500, 3, 500))
	stand(b, Vector3.new(500, 3, 530))
	local res = call(a, "Exchange", "Offer", { to = 303, pence = 10, slot = 0, count = 0 })
	eq(res.ok, false, "too far apart")
	stand(b, Vector3.new(500, 3, 505))
	local slot
	for k, s in pa.inventory.bag do
		if s.i == "tea" then
			slot = k
		end
	end
	res = call(a, "Exchange", "Offer", { to = 303, pence = 10, slot = slot, count = 1 })
	ok(res.ok, tostring(res.err))
	local offered = __received(b, "ExchangeEvent", "Offered")
	eq(#offered, 1)
	eq(offered[1].penceText, "10d")
	local wa, wb = pa.pence, pb.pence
	res = call(b, "Exchange", "Answer", { id = res.data.id, accept = true })
	ok(res.ok, tostring(res.err))
	eq(pa.pence, wa - 10)
	eq(pb.pence, wb + 10)
	eq(Inventory.count(b, "tea"), 1)
	-- moving apart before accepting
	res = call(a, "Exchange", "Offer", { to = 303, pence = 5, slot = 0, count = 0 })
	ok(res.ok)
	stand(b, Vector3.new(500, 3, 560))
	res = call(b, "Exchange", "Answer", { id = res.data.id, accept = true })
	eq(res.ok, false)
	eq(pa.pence, wa - 10, "nothing moved")
	-- someone else can't answer an offer meant for b
	stand(b, Vector3.new(500, 3, 505))
	res = call(a, "Exchange", "Offer", { to = 303, pence = 5, slot = 0, count = 0 })
	local wrong = call(a, "Exchange", "Answer", { id = res.data.id, accept = true })
	eq(wrong.ok, false, "the giver can't accept their own offer")
	__advance(Config.EXCHANGE_TIMEOUT + 2)
	res = call(b, "Exchange", "Answer", { id = res.data.id, accept = true })
	eq(res.ok, false, "expired")
end)

test("new accounts can hand over at most £100 a day", function()
	local a = Players:GetPlayerByUserId(302)
	local b = Players:GetPlayerByUserId(303)
	Economy.pay(a, Config.NEW_ACCOUNT_DAILY_TRANSFER * 2, "admin", "test")
	stand(a, Vector3.new(500, 3, 500))
	stand(b, Vector3.new(500, 3, 505))
	local res = call(a, "Exchange", "Offer", { to = 303, pence = Config.NEW_ACCOUNT_DAILY_TRANSFER + 1, slot = 0, count = 0 })
	ok(res.ok, tostring(res.err) .. ": the offer itself is allowed")
	res = call(b, "Exchange", "Answer", { id = res.data.id, accept = true })
	eq(res.ok, false, "but accepting it is over the daily cap")
	ok(string.find(res.err, "today"), res.err)
end)

test("a v2 profile migrates to v3 on load", function()
	local raw = Store.debugRaw(Config.PROFILE_STORE, "u_304")
	eq(raw, nil)
	Store.debugSetRaw(Config.PROFILE_STORE, "u_304", game:GetService("HttpService"):JSONEncode({
		data = { v = 2, pence = 99, bank = 0, slots = {}, progress = {}, active = "", nextChar = 1,
			rental = { paidUntil = 0 }, limits = { activityWindow = 0, activityPaid = 0 } },
	}))
	local p = __addPlayer(304, "Old")
	for _ = 1, 100 do
		if p:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	local prof = Profiles.get(p)
	eq(prof.v, 3)
	eq(prof.pence, 99, "kept")
	eq(prof.rental, nil, "unused lease field dropped")
	ok(prof.inventory and prof.inventory.bag, "inventory added")
	ok(prof.properties ~= nil, "properties added")
	eq(prof.limits.transferred, 0, "new limits filled in")
end)

test("every counter's stock is a real item with a price", function()
	local Items = require(Shared.Items)
	for _, def in Config.COUNTERS do
		for _, id in def.stock or {} do
			local it = Items.get(id)
			ok(it ~= nil, def.id .. " sells unknown item " .. id)
			ok(it.base >= 1 and it.base % 1 == 0, id .. " needs a whole-pence base price")
		end
	end
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
