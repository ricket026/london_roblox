--!strict
-- LondonClient.ShopUI (stub): shop menus in EconomyUI's counter panel (SHOPS.md §9). Plain on purpose.
--   "playershop" (a shop's till) and "stall" (a market stall): buy; for staff, open/close, bank
--   the till, stock from the bag; for the owner, prices, taking stock back, trade and sign;
--   a free stall can be rented, and given up.
--   "supplier" (wholesale): lots of 5/10/20, carried or delivered to storage.
-- Server: LondonServer.Shops (Shop.*), LondonServer.Counters (Counter.Wholesale, Delivered push).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Money = require(Shared:WaitForChild("Money"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local ShopUI = {}

local ui = EconomyUI.ui
local C = ui.colours
local deliver = false -- supplier menu: carry (false) or deliver to storage (true)

local function refresh(shop: string)
	local ok, msg = Net.request("Shop", "Menu", { shop = shop })
	if ok then
		EconomyUI.openCounter(msg)
	end
end

-- A shop call; on success, toast and refresh the menu.
local function act(shop: string, action: string, args: { [string]: any }, done: string?): boolean
	args.shop = args.shop or shop
	local ok, res = Net.request("Shop", action, args)
	if not ok then
		EconomyUI.toast(tostring(res), true)
		return false
	end
	if done then
		EconomyUI.toast(done)
	end
	refresh(shop)
	return true
end

local function shopMenu(body: ScrollingFrame, msg: { [string]: any }, o: () -> number)
	local shop = msg.shop :: string
	if msg.kind == "stall" or msg.rented == false then
		if not msg.rented then
			ui.line(body, o(), string.format("This stall is free: %s an in-game day, paid as you go.", msg.rentText or Money.format(Config.STALL_RENT)), C.INK)
			local _, b = ui.row(body, o(), "", { { "Rent this stall" } }, 150)
			b[1].Activated:Connect(function()
				local ok, res = Net.request("Shop", "RentStall", { counter = shop })
				if ok then
					EconomyUI.toast("The stall is yours. Put stock out from your bag, then open.")
					refresh(shop)
				else
					EconomyUI.toast(tostring(res), true)
				end
			end)
			return
		end
	end
	ui.line(body, o(), (if msg.open then "Open" else "Closed") .. (if msg.tradeName then " · " .. msg.tradeName else ""), if msg.open then C.GOLD else C.MUTED, 17)
	-- customers
	if not msg.owner then
		if not msg.open then
			ui.line(body, o(), "Come back when someone is at the till.", C.MUTED)
		elseif #(msg.stock or {}) == 0 then
			ui.line(body, o(), "Nothing on the shelves.", C.MUTED)
		end
		if msg.open then
			for _, st in msg.stock or {} do
				local n = 1
				local label = string.format("%s ×%d · %s%s", st.name, st.n, st.priceText, if st.byName then " (made by " .. st.byName .. ")" else "")
				local _, b = ui.row(body, o(), label, { { "−" }, { "1" }, { "+" }, { "Buy" } }, 40)
				b[2].AutoButtonColor = false
				b[1].Activated:Connect(function()
					n = math.max(1, n - 1)
					b[2].Text = tostring(n)
				end)
				b[3].Activated:Connect(function()
					n = math.min(st.n, n + 1)
					b[2].Text = tostring(n)
				end)
				b[4].Activated:Connect(function()
					act(shop, "Buy", { item = st.item, by = st.by, count = n }, string.format("Bought %d × %s.", n, st.name))
				end)
			end
		end
	end
	if not msg.staff then
		return
	end
	-- staff
	ui.line(body, o(), "Behind the counter", C.MUTED, 16)
	if not msg.fitted then
		ui.line(body, o(), tostring(msg.fittedWhy or ""), C.ERROR, 16)
	end
	local _, b = ui.row(body, o(), "Till: " .. (msg.tillText or "0d"), { { if msg.open then "Close" else "Open" }, { "Bank it" } }, 84)
	b[1].Activated:Connect(function()
		act(shop, "Open", { open = not msg.open }, if msg.open then "Closed and banked." else "Open for business.")
	end)
	b[2].Activated:Connect(function()
		act(shop, "BankTill", {}, "Banked.")
	end)
	if #(msg.bag or {}) > 0 then
		ui.line(body, o(), "Put out from your bag:", C.MUTED, 16)
	end
	for _, st in msg.bag or {} do
		local _, rb = ui.row(body, o(), string.format("%s ×%d", st.name, st.n), { { "Add 1" }, { "Add all" } }, 72)
		rb[1].Activated:Connect(function()
			act(shop, "Restock", { slot = st.slot, count = 1, from = "bag" })
		end)
		rb[2].Activated:Connect(function()
			act(shop, "Restock", { slot = st.slot, count = st.n, from = "bag" })
		end)
	end
	if msg.owner then
		if #(msg.stock or {}) > 0 then
			ui.line(body, o(), "Your stock and prices:", C.MUTED, 16)
		end
		for _, st in msg.stock or {} do
			local _, pb = ui.row(body, o(), string.format("%s ×%d · %s", st.name, st.n, st.priceText), { { "−1d" }, { "+1d" }, { "Take 1" } }, 62)
			pb[1].Activated:Connect(function()
				act(shop, "Price", { item = st.item, pence = math.max(st.min, st.price - 1) })
			end)
			pb[2].Activated:Connect(function()
				act(shop, "Price", { item = st.item, pence = math.min(st.max, st.price + 1) })
			end)
			pb[3].Activated:Connect(function()
				act(shop, "Unstock", { item = st.item, by = st.by, count = 1 })
			end)
		end
		-- trade (property shops) and sign
		local trade = msg.trade or ""
		if msg.trades then
			local names = msg.trades
			local idx = 1
			for k, t in names do
				if t.id == trade then
					idx = k
				end
			end
			local _, tb = ui.row(body, o(), "Trade: " .. (names[idx] and names[idx].name or "?"), { { "Change" } }, 84)
			tb[1].Activated:Connect(function()
				idx = idx % #names + 1
				trade = names[idx].id
				local row = tb[1].Parent
				local label = if row then row:FindFirstChild("Label") else nil
				if label and label:IsA("TextLabel") then
					label.Text = "Trade: " .. names[idx].name .. " (save to keep)"
				end
			end)
		end
		local r = Instance.new("Frame")
		r.LayoutOrder = o()
		r.BackgroundTransparency = 1
		r.Size = UDim2.new(1, 0, 0, 34)
		r.Parent = body
		local box = ui.text(r, "TextBox", {
			Text = msg.sign or "",
			PlaceholderText = "Shop sign",
			PlaceholderColor3 = C.MUTED,
			ClearTextOnFocus = false,
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(34, 30, 26),
			Size = UDim2.new(1, -96, 0, 30),
			Position = UDim2.fromOffset(0, 2),
		})
		local save = ui.button(r, "Save", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(88, 30) })
		save.Activated:Connect(function()
			act(shop, "Settings", { trade = trade, sign = box.Text }, "Saved.")
		end)
		if msg.kind == "stall" then
			local _, lb = ui.row(body, o(), "", { { "Give up the stall" } }, 160)
			lb[1].Activated:Connect(function()
				local ok, res = Net.request("Shop", "LeaveStall", { counter = shop })
				if ok then
					EconomyUI.toast("Stall given up; the stock is back in your bag.")
					refresh(shop)
				else
					EconomyUI.toast(tostring(res), true)
				end
			end)
		end
	end
end

local function supplierMenu(body: ScrollingFrame, msg: { [string]: any }, o: () -> number)
	local hours = msg.hours or { 0, 24 }
	ui.line(body, o(), if msg.open then string.format("Open until %d o'clock.", hours[2]) else string.format("Closed now. Open from %d to %d o'clock.", hours[1], hours[2]), if msg.open then C.GOLD else C.ERROR, 16)
	local _, db = ui.row(body, o(), if deliver then "Delivered to your storage (+" .. tostring(msg.deliveryText) .. " a lot)" else "You carry it (bag)", { { "Change" } }, 84)
	db[1].Activated:Connect(function()
		deliver = not deliver
		EconomyUI.openCounter(msg)
	end)
	for _, lot in msg.lots or {} do
		local labels = {}
		for k, l in lot.lots do
			labels[k] = { string.format("%d · %s", l.size, l.priceText) }
		end
		local _, b = ui.row(body, o(), lot.name, labels, 76)
		for k, l in lot.lots do
			b[k].Activated:Connect(function()
				local ok, res = Net.request("Counter", "Wholesale", { counter = msg.id, item = lot.item, size = l.size, deliver = deliver })
				if not ok then
					EconomyUI.toast(tostring(res), true)
					return
				end
				EconomyUI.toast(string.format("Bought %d × %s%s", l.size, lot.name, if deliver then "; it will be delivered to your storage." else "."))
			end)
		end
	end
end

function ShopUI.init()
	EconomyUI.onCounter("playershop", shopMenu)
	EconomyUI.onCounter("stall", shopMenu)
	EconomyUI.onCounter("supplier", supplierMenu)
	Net.listen("Shop", "Notice", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)
	Net.listen("Counter", "Delivered", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)
end

return ShopUI
