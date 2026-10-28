--!strict
-- LondonServer.Exchange: hand-overs between two players in person (ECONOMY §7, SHOPS §1).
-- The giver offers money and/or one stack's worth of an item; the receiver accepts or declines.
-- Nothing moves until the receiver accepts, and everything is checked again at that moment:
-- both still in the server and within Config.EXCHANGE_RANGE, the giver still has it, the
-- receiver has room, and new accounts stay under the daily transfer cap (Economy.transfer).
-- Remotes (Exchange domain, calls): Offer { to, pence, slot, count } (slot 0 = money only),
--   Answer { id, accept }, Cancel { id }.
-- Pushes: Exchange.Offered (to the receiver), Exchange.Closed { id, result, why? } (to both;
--   result is done / declined / failed / cancelled / expired / left).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Money = require(Shared:WaitForChild("Money"))
local Items = require(Shared:WaitForChild("Items"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))

local Exchange = {}

type Offer = {
	id: number,
	from: Player,
	to: Player,
	pence: number,
	item: string?,
	by: number?, -- maker of the offered stack (player-made items)
	byName: string?,
	count: number,
	expires: number,
}

local offers: { [number]: Offer } = {}
local nextId = 0

local function nameOf(p: Player): string
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

local function rootPos(p: Player): Vector3?
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp.Position else nil
end

local function close(o: Offer, result: string, why: string?)
	offers[o.id] = nil
	for _, p in { o.from, o.to } do
		if p.Parent == Players then
			Net.push(p, "Exchange", "Closed", { id = o.id, result = result, why = why })
		end
	end
end

local function inRange(a: Player, b: Player): boolean
	local pa, pb = rootPos(a), rootPos(b)
	return pa ~= nil and pb ~= nil and (pa - pb).Magnitude <= Config.EXCHANGE_RANGE
end

-- Returns the offer id, or nil and a reason.
function Exchange.offer(from: Player, toUserId: number, pence: number, slot: number, count: number): (number?, string?)
	local to = Players:GetPlayerByUserId(toUserId)
	if not to or to == from then
		return nil, "Choose someone nearby."
	end
	if not inRange(from, to) then
		return nil, "Stand closer to hand something over."
	end
	if pence == 0 and slot == 0 then
		return nil, "Offer some money or an item."
	end
	local wallet = Economy.balance(from)
	if pence > wallet then
		return nil, "You aren't carrying that much."
	end
	local item, by, byName = nil, nil, nil
	if slot > 0 then
		local s = Inventory.stackAt(from, slot)
		if not s or count < 1 or s.n < count then
			return nil, "You haven't got that many."
		end
		item, by, byName = s.i, s.by, s.byName
	end
	for _, o in offers do
		if o.from == from and o.to == to then
			return nil, "You've already offered them something."
		end
	end
	nextId += 1
	local o: Offer = {
		id = nextId, from = from, to = to, pence = pence, item = item, by = by, byName = byName,
		count = if item then count else 0, expires = os.clock() + Config.EXCHANGE_TIMEOUT,
	}
	offers[o.id] = o
	local it = item and Items.get(item)
	Net.push(to, "Exchange", "Offered", {
		id = o.id,
		fromName = nameOf(from),
		pence = pence,
		penceText = if pence > 0 then Money.format(pence) else nil,
		item = item,
		itemName = if it then it.name else nil,
		count = o.count,
		seconds = Config.EXCHANGE_TIMEOUT,
	})
	return o.id
end

-- The receiver accepts: check everything again, then move it all or nothing.
function Exchange.accept(o: Offer): (boolean, string?)
	local from, to = o.from, o.to
	if os.clock() > o.expires then
		return false, "The offer ran out."
	end
	if from.Parent ~= Players or to.Parent ~= Players then
		return false, "They've gone."
	end
	if not inRange(from, to) then
		return false, "You're too far apart now."
	end
	if o.pence > Economy.balance(from) then
		return false, "They no longer have the money."
	end
	if o.pence > Economy.transferRoom(from) then
		return false, "Their account can't hand over that much today."
	end
	if o.item then
		if Inventory.count(from, o.item, "bag", o.by) < o.count then
			return false, "They no longer have it."
		end
		if not Inventory.canAdd(to, o.item, o.count, "bag", o.by) then
			return false, "Your bag is full."
		end
	end
	-- money first (it can still fail on the receiver's wallet limit), then the item
	if o.pence > 0 then
		local ok, why = Economy.transfer(from, to, o.pence, "exchange")
		if not ok then
			return false, why
		end
	end
	if o.item then
		Inventory.remove(from, o.item, o.count, "bag", o.by)
		Inventory.add(to, o.item, o.count, "bag", o.by, o.byName)
	end
	return true
end

function Exchange.init()
	local V = Net.V
	Net.handle("Exchange", "Offer", {
		schema = { to = V.userId(), pence = V.int(0, Config.PENCE_MAX), slot = V.int(0, Config.BAG_SLOTS), count = V.int(0, 99) },
		rate = Config.EXCHANGE_RATE,
		call = true,
	}, function(player, a)
		local id, why = Exchange.offer(player, a.to, a.pence, a.slot, a.count)
		if not id then
			return nil, why
		end
		return { id = id }
	end)
	Net.handle("Exchange", "Answer", { schema = { id = V.int(1, 2 ^ 31), accept = V.bool() }, rate = Config.EXCHANGE_RATE, call = true }, function(player, a)
		local o = offers[a.id]
		if not o or o.to ~= player then
			return nil, "That offer has gone."
		end
		if not a.accept then
			close(o, "declined")
			return { result = "declined" }
		end
		local ok, why = Exchange.accept(o)
		close(o, if ok then "done" else "failed", why)
		if not ok then
			return nil, why
		end
		return { result = "done" }
	end)
	Net.handle("Exchange", "Cancel", { schema = { id = V.int(1, 2 ^ 31) }, rate = Config.EXCHANGE_RATE, call = true }, function(player, a)
		local o = offers[a.id]
		if o and o.from == player then
			close(o, "cancelled")
		end
		return {}
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for _, o in offers do
				if now > o.expires then
					close(o, "expired")
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		for _, o in offers do
			if o.from == p or o.to == p then
				close(o, "left")
			end
		end
	end)
end

return Exchange
