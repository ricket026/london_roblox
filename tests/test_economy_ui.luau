-- Phase 2 client: EconomyUI driven as a player would, against the real server.
local Players = game:GetService("Players")
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0 -- daily money is tested in test_daily; keep balances exact here
Config.GOALS = {} -- the "Next steps" bonuses are tested in test_onboarding
local Net = require(Shared.Net)
local Money = require(Shared.Money)
__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Economy = require(__find(LS .. "Economy"))
local Inventory = require(__find(LS .. "Inventory"))

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
	local res = call(p, "Character", "Create", { slot = "1", first = name, last = "Tester", skin = 1, hair = "own", outfit = "frock" })
	assert(res.ok, tostring(res.err))
	return p
end
local function stand(p, at)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(at)
end
local function counterPos(id)
	return workspace.Counters[id].Counter.Position
end
-- the first TextButton under root whose text is `label` (inside a row whose label starts with `rowText`)
local function findButton(root, label, rowText)
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and d.Text == label then
			local row = d.Parent
			local l = row and row:FindFirstChild("Label")
			if not rowText or (l and string.sub(l.Text, 1, #rowText) == rowText) then
				return d
			end
		end
	end
	return nil
end
local function press(b)
	assert(b, "no such button")
	b.Activated:Fire()
end

local p, gui

test("wallet shows once in the city and follows the server", function()
	p = join(401, "Clara")
	__asClient(p, function()
		require(__find("StarterPlayer.StarterPlayerScripts.LondonClient.EconomyUI")).init()
	end)
	gui = p.PlayerGui.Economy
	ok(gui.Wallet.Visible, "a character is chosen")
	Economy.pay(p, 30, "admin", "test")
	eq(gui.Wallet.Text, Money.format(Profiles.get(p).pence))
	eq(gui.Bank.Text, "Bank 0d")
end)

test("buying two cups of tea at the kiosk", function()
	stand(p, counterPos("kiosk_park") + Vector3.new(0, 0, -4))
	workspace.Counters.kiosk_park.Counter.ProximityPrompt.Triggered:Fire(p)
	ok(gui.CounterPanel.Visible, "menu opened")
	press(findButton(gui.CounterPanel, "+", "Cup of Tea"))
	press(findButton(gui.CounterPanel, "Buy", "Cup of Tea"))
	eq(Inventory.count(p, "tea"), 2)
	eq(gui.Toast.Text, "Bought 2 × Cup of Tea.")
	eq(gui.Wallet.Text, Money.format(Profiles.get(p).pence))
end)

test("walking away closes the counter menu", function()
	stand(p, counterPos("kiosk_park") + Vector3.new(0, 0, -40))
	__advance(1)
	eq(gui.CounterPanel.Visible, false)
end)

test("the bag: use and hold", function()
	local bound = game:GetService("ContextActionService")._bound
	bound.LondonBag("LondonBag", Enum.UserInputState.Begin)
	ok(gui.BagPanel.Visible, "B opens the bag")
	press(findButton(gui.BagPanel, "Hold", "Cup of Tea"))
	eq(p:GetAttribute("HeldItem"), "tea")
	ok(findButton(gui.BagPanel, "Put away", "Cup of Tea"), "re-rendered after the push")
	press(findButton(gui.BagPanel, "Use", "Cup of Tea"))
	eq(Inventory.count(p, "tea"), 1)
	ok(string.find(gui.Toast.Text, "drink"), gui.Toast.Text)
	__advance(Config.INVENTORY_RATE.per)
end)

test("banking at the post office", function()
	__advance(Config.COUNTER_RATE.per)
	stand(p, counterPos("po_trafalgar") + Vector3.new(0, 0, -4))
	workspace.Counters.po_trafalgar.Counter.ProximityPrompt.Triggered:Fire(p)
	ok(gui.CounterPanel.Visible)
	local w = Profiles.get(p).pence
	press(findButton(gui.CounterPanel, Money.format(Config.BANK_PRESETS[1])))
	eq(Profiles.get(p).bank, Config.BANK_PRESETS[1])
	eq(Profiles.get(p).pence, w - Config.BANK_PRESETS[1])
	eq(gui.Bank.Text, "Bank " .. Money.format(Config.BANK_PRESETS[1]))
end)

test("someone offers me money: accept", function()
	local b = join(402, "Dora")
	Economy.pay(b, 100, "admin", "test")
	stand(p, Vector3.new(800, 3, 800))
	stand(b, Vector3.new(800, 3, 804))
	local res = call(b, "Exchange", "Offer", { to = 401, pence = 12, slot = 0, count = 0 })
	ok(res.ok, tostring(res.err))
	ok(gui.Offer.Visible, "popup shown")
	ok(string.find(gui.Offer.TextLabel.Text, "Dora Tester offers you 1s"), gui.Offer.TextLabel.Text)
	local w = Profiles.get(p).pence
	press(gui.Offer.Accept)
	eq(Profiles.get(p).pence, w + 12)
	eq(gui.Offer.Visible, false)
end)

test("I give someone money and an item from the bag", function()
	local b = Players:GetPlayerByUserId(402)
	gui.BagPanel.Visible = false
	game:GetService("ContextActionService")._bound.LondonBag("LondonBag", Enum.UserInputState.Begin)
	press(findButton(gui.BagPanel, "Give", "Cup of Tea"))
	ok(gui.GivePanel.Visible)
	local boxes = {}
	for _, d in gui.GivePanel:GetDescendants() do
		if d:IsA("TextBox") then
			boxes[d.PlaceholderText] = d
		end
	end
	boxes.d.Text = "3"
	press(findButton(gui.GivePanel, "Give", "Dora Tester"))
	eq(gui.GivePanel.Visible, false, tostring(gui.GivePanel.Body:FindFirstChildWhichIsA("TextLabel", true)))
	local offered = __received(b, "ExchangeEvent", "Offered")
	local o = offered[#offered]
	eq(o.pence, 3)
	eq(o.item, "tea")
	local wb = Profiles.get(b).pence
	local res = call(b, "Exchange", "Answer", { id = o.id, accept = true })
	ok(res.ok, tostring(res.err))
	eq(Profiles.get(b).pence, wb + 3)
	eq(Inventory.count(b, "tea"), 1)
	eq(Inventory.count(p, "tea"), 0)
	eq(gui.Toast.Text, "They accepted.")
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
