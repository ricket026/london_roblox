-- Phase 4 client: ShopUI as the shopkeeper sees it (supplier menu, the till's staff menu).
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0 -- daily money is tested in test_daily; keep balances exact here
Config.GOALS = {} -- the "Next steps" bonuses are tested in test_onboarding
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
local Shops = require(__find(LS .. "Shops"))

local function call(p, domain, action, args)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain, msg, true)
end
local function stand(p, at)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(at)
end
local function settle()
	for _ = 1, 20 do
		task.wait(0.1)
	end
end
local function findButton(root, label, rowText)
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and d.Text == label then
			local l = d.Parent and d.Parent:FindFirstChild("Label")
			if not rowText or (l and string.find(l.Text, rowText, 1, true)) then
				return d
			end
		end
	end
	return nil
end
local function press(b, what)
	assert(b, "no such button: " .. tostring(what))
	b.Activated:Fire()
end
local SHOP = "Lot_2434"

local S, gui
test("setup: the shopkeeper's client, a shop fitted out", function()
	S = __addPlayer(801, "Sidney")
	for _ = 1, 200 do
		if S:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	__asClient(S, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		require(__find(root .. "BuildUI")).init()
		require(__find(root .. "PropertyUI")).init()
		require(__find(root .. "ShopUI")).init()
	end)
	gui = S.PlayerGui.Economy
	ok(call(S, "Character", "Create", { slot = "1", first = "Sidney", last = "Tester", skin = 1, hair = "own", outfit = "frock" }).ok)
	Economy.pay(S, 60000, "admin", "test")
	stand(S, workspace.Counters.estate_covent.Counter.Position + Vector3.new(0, 0, -4))
	ok(call(S, "Property", "Buy", { counter = "estate_covent", kind = "shop" }).ok)
	settle()
	Inventory.add(S, "counter_till", 1, "storage")
	Inventory.add(S, "display_case", 1, "storage")
	local l = Lots.get(SHOP)
	stand(S, Kit.toWorld(l.frame, l.w / 2, 3, l.d / 2))
	ok(call(S, "Build", "Enter", { lot = SHOP }).ok)
	ok(call(S, "Build", "Place", { lot = SHOP, id = "counter_till", x = 24, z = 16, y = 0, r = 0, c = 0 }).ok)
	ok(call(S, "Build", "Place", { lot = SHOP, id = "display_case", x = 24, z = 8, y = 0, r = 0, c = 0 }).ok)
	call(S, "Build", "Exit", { lot = SHOP })
end)

test("the supplier menu: lots, carry or deliver", function()
	Counters.get("supplier_spitalfields").hours = { 0, 24 }
	stand(S, workspace.Counters.supplier_spitalfields.Counter.Position + Vector3.new(0, 0, -4))
	workspace.Counters.supplier_spitalfields.Counter.ProximityPrompt.Triggered:Fire(S)
	ok(gui.CounterPanel.Visible)
	press(findButton(gui.CounterPanel, "10 · 6d", "Currant Bun"), "10 buns")
	eq(Inventory.count(S, "bun"), 10)
	press(findButton(gui.CounterPanel, "Change", "You carry it"), "deliver toggle")
	ok(findButton(gui.CounterPanel, "Change", "Delivered to your storage") ~= nil, "now delivering")
	__advance(Config.COUNTER_RATE.per)
	press(findButton(gui.CounterPanel, "5 · 3d", "Apple"), "5 apples")
	ok(string.find(gui.Toast.Text, "delivered"), gui.Toast.Text)
	__advance(Config.DELIVERY_SECONDS + 1)
	eq(Inventory.count(S, "apple", "storage"), 5, "delivered to storage")
end)

test("the till: stock from the bag, open, price, sign, close", function()
	stand(S, Shops.tillPosition(Shops.get(SHOP)) + Vector3.new(0, 1, -3))
	local till
	for _, pm in workspace.Properties[SHOP]:GetChildren() do
		if pm:GetAttribute("Piece") == "counter_till" then
			till = pm
		end
	end
	till:FindFirstChildWhichIsA("ProximityPrompt", true).Triggered:Fire(S)
	ok(gui.CounterPanel.Visible, "the till menu")
	press(findButton(gui.CounterPanel, "Add all", "Currant Bun"), "add buns")
	settle()
	eq(Inventory.count(S, "bun"), 0)
	eq(Shops.get(SHOP).data.stock[1].n, 10, "on the shelves")
	press(findButton(gui.CounterPanel, "Open", "Till"), "open")
	settle()
	eq(Shops.get(SHOP).open, true)
	press(findButton(gui.CounterPanel, "+1d", "Currant Bun"), "price up")
	settle()
	eq(Shops.get(SHOP).data.prices.bun, 2)
	local box
	for _, d in gui.CounterPanel:GetDescendants() do
		if d:IsA("TextBox") and d.PlaceholderText == "Shop sign" then
			box = d
		end
	end
	box.Text = "Tester & Sons"
	press(findButton(gui.CounterPanel, "Save"), "save sign")
	settle()
	eq(Shops.get(SHOP).data.sign, "Tester & Sons")
	-- a customer (server side) buys: the shopkeeper hears about it
	local Cu = __addPlayer(802, "Celia")
	for _ = 1, 200 do
		if Cu:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	ok(call(Cu, "Character", "Create", { slot = "1", first = "Celia", last = "Tester", skin = 1, hair = "own", outfit = "frock" }).ok)
	stand(Cu, Shops.tillPosition(Shops.get(SHOP)) + Vector3.new(0, 1, -4))
	ok(call(Cu, "Shop", "Buy", { shop = SHOP, item = "bun", by = 0, count = 1 }).ok)
	ok(string.find(gui.Toast.Text, "Sold 1 × Currant Bun"), gui.Toast.Text)
	press(findButton(gui.CounterPanel, "Close", "Till"), "close")
	settle()
	eq(Shops.get(SHOP).open, false)
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
