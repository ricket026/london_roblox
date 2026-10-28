-- Phase 3 server: plots, estate agents, rent/buy/sell, builds (place, rules, publish, save, load),
-- keys and doors, linger, lapse, reports. Plots are real ones from london.rbxl (Aldersgate Street
-- in Clerkenwell, and one off Long Acre), with the lot types set for the test.
local Players = game:GetService("Players")
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0 -- daily money is tested in test_daily; keep balances exact here
local Net = require(Shared.Net)
local Kit = require(Shared.Kit)

-- the map: four plots
local map = Instance.new("Folder")
map.Name = "Map"
local plots = Instance.new("Folder")
plots.Name = "Plots"
plots.Parent = map
local function plot(id, x, z, sx, sz, lotType, district)
	local p = Instance.new("Part")
	p.Name = "Lot_" .. id
	p.Anchored = true
	p.Size = Vector3.new(sx, 2.6, sz)
	p.CFrame = CFrame.new(x, -0.7, z)
	p:SetAttribute("LotId", id)
	p:SetAttribute("District", district)
	p:SetAttribute("LotType", lotType)
	p:SetAttribute("Frontage", math.floor(sx))
	p:SetAttribute("Depth", math.floor(sz))
	p.Parent = plots
	return p
end
plot(1433, -792.2857, -2199.2, 29.714, 46.4, "Terrace", "Holborn & Bloomsbury")
plot(1434, -762.5714, -2199.2, 29.714, 46.4, "Terrace", "Holborn & Bloomsbury")
plot(1435, -732.8571, -2199.2, 29.714, 46.4, "Terrace", "Holborn & Bloomsbury")
plot(2434, -289.6, -1212, 26.4, 40, "Shop", "Covent Garden")
map.Parent = workspace

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Economy = require(__find(LS .. "Economy"))
local Inventory = require(__find(LS .. "Inventory"))
local Lots = require(__find(LS .. "Lots"))
local Builds = require(__find(LS .. "Builds"))
local Property = require(__find(LS .. "Property"))
local Doors = require(__find(LS .. "Doors"))
local Store = require(__find(LS .. "Store"))

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
	local res
	if Profiles.get(p).slots["1"] then
		res = call(p, "Character", "Select", { slot = "1" })
	else
		res = call(p, "Character", "Create", { slot = "1", first = name, last = "Tester", skin = 1, hair = "own", outfit = "frock" })
	end
	assert(res.ok, tostring(res.err))
	return p
end
local function stand(p, at)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(at)
end
local AGENT = "estate_holborn"
local function atAgent(p)
	stand(p, workspace.Counters[AGENT].Counter.Position + Vector3.new(0, 0, -4))
end
local function onLot(p, lot)
	local l = Lots.get(lot)
	stand(p, Kit.toWorld(l.frame, l.w / 2, 3, l.d / 2))
end
local function settle()
	for _ = 1, 20 do
		task.wait(0.1)
	end
end
local function deedOf(p)
	for _, d in Profiles.get(p).properties do
		return d
	end
end

test("plots: street side from the road data, frame and addresses", function()
	Lots.waitReady()
	local l = Lots.get("Lot_1433")
	ok(l ~= nil)
	eq(l.kind, "terrace")
	eq(l.street, "Aldersgate Street")
	ok((l.frame.inward - Vector3.new(0, 0, -1)).Magnitude < 1e-6, "the street (z -2150) is on the plot's +Z side, so 'into the plot' is -Z: " .. tostring(l.frame.inward))
	ok((l.frame.right - Vector3.new(1, 0, 0)).Magnitude < 1e-6, "right along the street is +X")
	ok((l.frame.origin - Vector3.new(-807.1428, 0.6, -2176)).Magnitude < 0.01, "street-left corner: " .. tostring(l.frame.origin))
	eq(l.w, 29)
	eq(l.d, 46)
	eq(Lots.address("Lot_1433"), "No. 1, Aldersgate Street")
	eq(Lots.address("Lot_1435"), "No. 3, Aldersgate Street")
	eq(Lots.kindOf("Lot_2434"), "shop")
	settle()
	local t = workspace.LotTemplates:FindFirstChild("Lot_1433")
	ok(t ~= nil, "unused plots show a template house")
	ok(#t:GetChildren() <= 8, "templates are at most 8 parts")
	eq(#workspace.LotTemplates:GetChildren(), 4)
end)

local A, B
test("renting a terrace: paid up front, nearest free plot, a starter house", function()
	A = join(501, "Agnes")
	Economy.pay(A, 10000, "admin", "test")
	atAgent(A)
	local before = Profiles.get(A).pence
	local res = call(A, "Property", "Rent", { counter = AGENT, kind = "terrace" })
	ok(res.ok, tostring(res.err))
	eq(Profiles.get(A).pence, before - Config.PROPERTY_KINDS.terrace.rent)
	eq(res.data.lot, "Lot_1435", "the plot nearest the agent")
	eq(res.data.address, "No. 3, Aldersgate Street")
	settle()
	local m = workspace.Properties:FindFirstChild("Lot_1435")
	ok(m ~= nil, "the house is built")
	ok(#m:GetChildren() > 50, "with its pieces")
	eq(workspace.LotTemplates:FindFirstChild("Lot_1435"), nil, "the template is gone")
	-- every part stands on the plot (or up to 2 studs in front of it)
	for _, pm in m:GetChildren() do
		for _, part in pm:GetChildren() do
			local x, _, z = Lots.toLot("Lot_1435", part.Position)
			ok(x > -0.6 and x < 29.6 and z > -2.6 and z < 46.6, pm:GetAttribute("Piece") .. " off the plot at " .. x .. "," .. z)
		end
	end
	local d = deedOf(A)
	eq(d.tenure, "rent")
	eq(d.lotId, "Lot_1435")
	ok(d.paidUntil > os.time(), "paid for a week")
end)

test("a second player gets another plot; the doors work for the owner only when locked", function()
	B = join(502, "Bertie")
	Economy.pay(B, 10000, "admin", "test")
	atAgent(B)
	local res = call(B, "Property", "Rent", { counter = AGENT, kind = "terrace" })
	ok(res.ok, tostring(res.err))
	eq(res.data.lot, "Lot_1434")
	settle()
	local door
	for _, part in workspace.Properties.Lot_1435:GetDescendants() do
		if part:GetAttribute("DoorLot") == "Lot_1435" then
			door = part
		end
	end
	ok(door ~= nil, "front door tagged for Doors")
	stand(B, Vector3.new(0, 3, 0))
	stand(A, Vector3.new(0, 3, 0))
	eq(Doors.canOpen(B, door), false, "locked to strangers")
	eq(Doors.canOpen(A, door), true, "the owner may")
	onLot(B, "Lot_1435")
	eq(Doors.canOpen(B, door), true, "anyone inside may get out")
	stand(B, Vector3.new(0, 3, 0))
	ok(call(A, "Property", "Lock", { deed = deedOf(A).id, locked = false }).ok)
	eq(Doors.canOpen(B, door), true, "unlocked")
	ok(call(A, "Property", "Lock", { deed = deedOf(A).id, locked = true }).ok)
end)

test("build mode: furniture from storage, rules, permissions by key", function()
	local res = call(A, "Build", "Enter", { lot = "Lot_1435" })
	eq(res.ok, false, "must stand at the property")
	onLot(A, "Lot_1435")
	res = call(A, "Build", "Enter", { lot = "Lot_1435" })
	ok(res.ok, tostring(res.err))
	eq(res.data.budget, Config.PROPERTY_KINDS.terrace.budget)
	-- a free chair in the back garden, then a bought armchair
	res = call(A, "Build", "Place", { lot = "Lot_1435", id = "chair", x = 20, z = 60, y = 0, r = 0, c = 0 })
	ok(res.ok, tostring(res.err))
	res = call(A, "Build", "Place", { lot = "Lot_1435", id = "armchair", x = 26, z = 60, y = 0, r = 0, c = 0 })
	eq(res.ok, false)
	ok(string.find(res.err, "storage"), res.err)
	Inventory.add(A, "armchair", 1, "storage")
	res = call(A, "Build", "Place", { lot = "Lot_1435", id = "armchair", x = 26, z = 60, y = 0, r = 0, c = 0 })
	ok(res.ok, tostring(res.err))
	eq(Inventory.count(A, "armchair", "storage"), 0, "taken from storage")
	local armK = res.data.k
	res = call(A, "Build", "Place", { lot = "Lot_1435", id = "wall_plain", x = 80, z = 0, y = 0, r = 0, c = 0 })
	eq(res.ok, false, "past the side of the plot")
	ok(call(A, "Build", "Remove", { lot = "Lot_1435", k = armK }).ok)
	eq(Inventory.count(A, "armchair", "storage"), 1, "back in storage")
	-- B can't build here without a key; with a decorate key, furniture only
	onLot(B, "Lot_1435")
	eq(call(B, "Build", "Enter", { lot = "Lot_1435" }).ok, false, "no key")
	ok(call(A, "Property", "Key", { deed = deedOf(A).id, userId = 502, enter = true, decorate = true, build = false, sell = false }).ok)
	res = call(B, "Build", "Enter", { lot = "Lot_1435" })
	ok(res.ok, tostring(res.err))
	eq(res.data.canBuild, false)
	eq(res.data.canDecorate, true)
	ok(call(B, "Build", "Place", { lot = "Lot_1435", id = "crate", x = 30, z = 70, y = 0, r = 0, c = 0 }).ok, "decorating")
	res = call(B, "Build", "Place", { lot = "Lot_1435", id = "lawn", x = 40, z = 80, y = 0, r = 0, c = 0 })
	eq(res.ok, false)
	ok(string.find(res.err, "not build"), res.err)
	call(B, "Build", "Exit", { lot = "Lot_1435" })
end)

test("breaking the street front makes a draft; publishing needs it whole again", function()
	__advance(1)
	local a = Builds.get("Lot_1435")
	local wall
	for _, p in a.build.pieces do
		if p.id == "wall_sash" and p.y == 0 and p.z == 0 and p.x > 0 then -- a middle bay: a gap
			wall = p
			break
		end
	end
	ok(wall ~= nil)
	ok(call(A, "Build", "Remove", { lot = "Lot_1435", k = wall.k }).ok)
	eq(a.build.published, false, "a draft now")
	eq(workspace.Properties:FindFirstChild("Lot_1435"), nil, "others see the template")
	ok(workspace.LotTemplates:FindFirstChild("Lot_1435") ~= nil)
	local changes = __received(A, "BuildEvent", "Changed")
	eq(changes[#changes].published, false, "the owner is told")
	local res = call(A, "Build", "Publish", { lot = "Lot_1435" })
	eq(res.ok, false)
	ok(string.find(res.err, "gap"), res.err)
	res = call(A, "Build", "Place", { lot = "Lot_1435", id = "wall_bay", x = wall.x, z = 0, y = 0, r = 0, c = 0 })
	ok(res.ok, tostring(res.err))
	ok(call(A, "Build", "Publish", { lot = "Lot_1435" }).ok)
	ok(workspace.Properties:FindFirstChild("Lot_1435") ~= nil, "shown again")
	eq(workspace.LotTemplates:FindFirstChild("Lot_1435"), nil)
	call(A, "Build", "Exit", { lot = "Lot_1435" })
end)

test("leaving: the build is saved and lingers; then the plot is free; rejoining gets it back", function()
	__advance(1)
	local deedId = deedOf(A).id
	__removePlayer(A)
	settle()
	local raw = Store.debugRaw(Config.BUILD_STORE, "u_501_" .. deedId)
	ok(raw ~= nil, "saved in its own store")
	ok(string.find(raw, "wall_bay"), "with the edits: " .. string.sub(tostring(raw), 1, 300))
	ok(workspace.Properties:FindFirstChild("Lot_1435") ~= nil, "still standing for visitors")
	local door
	for _, part in workspace.Properties.Lot_1435:GetDescendants() do
		if part:GetAttribute("DoorLot") == "Lot_1435" then
			door = part
		end
	end
	stand(B, Vector3.new(0, 3, 0))
	eq(Doors.canOpen(B, door), true, "with the owner away, a key holder still gets in")
	local stranger = join(510, "Ivy")
	stand(stranger, Vector3.new(0, 3, 0))
	eq(Doors.canOpen(stranger, door), false, "but it stays locked to strangers")

	__advance(Config.PROPERTY_LINGER + 2)
	eq(workspace.Properties:FindFirstChild("Lot_1435"), nil, "gone after the linger")
	ok(workspace.LotTemplates:FindFirstChild("Lot_1435") ~= nil)
	eq(Lots.claimOf("Lot_1435"), nil)
	A = join(501, "Agnes")
	settle()
	eq(deedOf(A).lotId, "Lot_1435", "the usual address, free again")
	local a = Builds.get("Lot_1435")
	ok(a ~= nil and a.owner == 501)
	local bay = false
	for _, p in a.build.pieces do
		bay = bay or p.id == "wall_bay"
	end
	ok(bay, "the saved build came back")
	eq(a.build.published, true)
end)

test("rent: paid from the bank when due; unpaid past the grace, the tenancy lapses and comes back", function()
	local d = deedOf(A)
	local prof = Profiles.get(A)
	prof.bank = 2000
	local wallet = prof.pence
	d.paidUntil = os.time() - 5
	Property.settle(A, d)
	eq(prof.bank, 2000 - Config.PROPERTY_KINDS.terrace.rent, "from the bank first")
	eq(prof.pence, wallet)
	ok(d.paidUntil > os.time())
	-- broke and past the grace period
	prof.bank, prof.pence = 0, 0
	d.paidUntil = os.time() - Config.RENT_GRACE - 5
	Property.settle(A, d)
	eq(d.lapsed, true)
	eq(Lots.claimOf("Lot_1435"), nil, "the plot is free")
	settle()
	ok(workspace.LotTemplates:FindFirstChild("Lot_1435") ~= nil)
	-- renting a terrace again brings the same deed and build back
	Economy.pay(A, 5000, "admin", "test")
	atAgent(A)
	__advance(Config.PROPERTY_RATE.per)
	local res = call(A, "Property", "Rent", { counter = AGENT, kind = "terrace" })
	ok(res.ok, tostring(res.err))
	eq(res.data.deed, d.id, "the same deed")
	eq(d.lapsed, false)
	settle()
	local a = Builds.get(res.data.lot)
	local bay = false
	for _, p in a.build.pieces do
		bay = bay or p.id == "wall_bay"
	end
	ok(bay, "with its build")
end)

test("limits: two homes per account", function()
	atAgent(A)
	Economy.pay(A, 100000, "admin", "test")
	__advance(Config.PROPERTY_RATE.per)
	local res = call(A, "Property", "Rent", { counter = AGENT, kind = "terrace" })
	ok(res.ok, tostring(res.err))
	eq(res.data.lot, "Lot_1433", "the last free terrace")
	res = call(A, "Property", "Rent", { counter = AGENT, kind = "lodging" })
	eq(res.ok, false)
	ok(string.find(res.err, "homes"), res.err)
	res = call(A, "Property", "Rent", { counter = "kiosk_park", kind = "terrace" })
	eq(res.ok, false, "only at an estate agent")
end)

test("buying a shop, then selling it back for half; furniture goes to storage", function()
	local C = join(503, "Cora")
	Economy.pay(C, 60000, "admin", "test")
	atAgent(C)
	local res = call(C, "Property", "Buy", { counter = AGENT, kind = "shop" })
	ok(res.ok, tostring(res.err))
	eq(res.data.lot, "Lot_2434")
	eq(Profiles.get(C).pence, 60060 - Config.PROPERTY_KINDS.shop.buy)
	settle()
	Inventory.add(C, "display_case", 1, "storage")
	onLot(C, "Lot_2434")
	ok(call(C, "Build", "Enter", { lot = "Lot_2434" }).ok)
	res = call(C, "Build", "Place", { lot = "Lot_2434", id = "display_case", x = 10, z = 60, y = 0, r = 0, c = 0 })
	ok(res.ok, tostring(res.err))
	eq(Inventory.count(C, "display_case", "storage"), 0)
	call(C, "Build", "Exit", { lot = "Lot_2434" })
	settle()
	atAgent(C)
	local d = deedOf(C)
	local pence = Profiles.get(C).pence
	res = call(C, "Property", "Sell", { counter = AGENT, deed = d.id })
	ok(res.ok, tostring(res.err))
	eq(Profiles.get(C).pence, pence + Config.PROPERTY_KINDS.shop.buy // 2)
	eq(Inventory.count(C, "display_case", "storage"), 1, "furniture back in storage")
	eq(Profiles.get(C).properties[d.id], nil, "deed gone")
	eq(Lots.claimOf("Lot_2434"), nil)
	eq(Store.debugRaw(Config.BUILD_STORE, "u_503_" .. d.id), nil, "saved build deleted")
end)

test("three reports hide a house in this server", function()
	local lot = deedOf(A).lotId
	local owner = Builds.get(lot)
	ok(owner ~= nil)
	for k, id in { 504, 505, 506 } do
		local r = join(id, ({ "Dora", "Edith", "Flora" })[k])
		onLot(r, lot)
		local res = call(r, "Property", "Report", { lot = lot, reason = Config.REPORT_REASONS[1] })
		ok(res.ok, tostring(res.err))
	end
	settle()
	eq(workspace.Properties:FindFirstChild(lot), nil, "hidden")
	ok(workspace.LotTemplates:FindFirstChild(lot) ~= nil, "template instead")
	local notes = __received(A, "PropertyEvent", "Notice")
	ok(string.find(notes[#notes].text, "reported"), notes[#notes].text)
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
