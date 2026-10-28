--!strict
-- LondonServer.Inventory: items owned by the account (SHOPS.md §1). Two lists of stacks in the
-- profile: `bag` (carried, Config.BAG_SLOTS stacks) and `storage` (at home or the shop; no limit;
-- furniture always goes here). A stack is { i = itemId, n = count, by?, byName? }: player-made
-- items keep their maker, and only stack with items by the same maker.
--   Inventory.count(player, id, where?) -> n        Inventory.canAdd(player, id, n, where?) -> bool
--   Inventory.add(player, id, n, where?, by?, byName?) -> added count (all or nothing)
--   Inventory.remove(player, id, n, where?, by?) -> bool (all or nothing)
--   Inventory.take(player, slot, n, where) -> the stack taken (for hand-overs and shops)
--   Inventory.list(player) -> what the client shows
-- Remotes (Inventory domain, calls): Get, Use { slot }, Hold { slot } (slot 0 = put away).
-- Push: Inventory.State after every change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Items = require(Shared:WaitForChild("Items"))
local Types = require(Shared:WaitForChild("Types"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local Inventory = {}
Inventory.HELD_NAME = "HeldItem"

type Stack = Types.Stack

local function lists(player: Player): (({ Stack })?, ({ Stack })?)
	local p = Profiles.get(player)
	if not p then
		return nil, nil
	end
	return p.inventory.bag, p.inventory.storage
end

local function listFor(player: Player, where: string?): { Stack }?
	local bag, storage = lists(player)
	return if where == "storage" then storage else bag
end

local function defaultWhere(id: string, where: string?): string
	return where or (if Items.goesToStorage(id) then "storage" else "bag")
end

function Inventory.count(player: Player, id: string, where: string?, by: number?): number
	local list = listFor(player, defaultWhere(id, where))
	local n = 0
	for _, s in list or {} do
		if s.i == id and (by == nil or s.by == by) then
			n += s.n
		end
	end
	return n
end

-- Room for n of an item: existing stacks of the same item (and maker) first, then free slots.
function Inventory.canAdd(player: Player, id: string, n: number, where: string?, by: number?): boolean
	local it = Items.get(id)
	local w = defaultWhere(id, where)
	local list = listFor(player, w)
	if not it or not list or n <= 0 then
		return false
	end
	if w == "storage" then
		return true
	end
	local room = 0
	for _, s in list do
		if s.i == id and s.by == by then
			room += it.stack - s.n
		end
	end
	room += (Config.BAG_SLOTS - #list) * it.stack
	return room >= n
end

local function pushState(player: Player)
	Net.push(player, "Inventory", "State", Inventory.list(player))
end

function Inventory.add(player: Player, id: string, n: number, where: string?, by: number?, byName: string?): number
	if not Inventory.canAdd(player, id, n, where, by) then
		return 0
	end
	local it = Items.get(id) :: Items.Item
	local w = defaultWhere(id, where)
	local list = listFor(player, w) :: { Stack }
	local left = n
	local cap = if w == "storage" then math.huge else it.stack
	for _, s in list do
		if left == 0 then
			break
		end
		if s.i == id and s.by == by and s.n < cap then
			local put = math.min(left, cap - s.n)
			s.n += put
			left -= put
		end
	end
	while left > 0 do
		local put = math.min(left, cap)
		table.insert(list, { i = id, n = put, by = by, byName = byName })
		left -= put
	end
	pushState(player)
	return n
end

function Inventory.remove(player: Player, id: string, n: number, where: string?, by: number?): boolean
	local w = defaultWhere(id, where)
	local list = listFor(player, w)
	if not list or n <= 0 or Inventory.count(player, id, w, by) < n then
		return false
	end
	local left = n
	for k = #list, 1, -1 do -- newest stacks first
		local s = list[k]
		if s.i == id and (by == nil or s.by == by) then
			local take = math.min(left, s.n)
			s.n -= take
			left -= take
			if s.n == 0 then
				table.remove(list, k)
			end
			if left == 0 then
				break
			end
		end
	end
	Inventory.refreshHeld(player)
	pushState(player)
	return true
end

-- Takes n from one stack by slot number; returns a copy of what was taken (nil if it can't).
function Inventory.take(player: Player, slot: number, n: number, where: string): Stack?
	local list = listFor(player, where)
	local s = list and list[slot]
	if not s or n <= 0 or s.n < n then
		return nil
	end
	s.n -= n
	if s.n == 0 then
		table.remove(list :: { Stack }, slot)
	end
	Inventory.refreshHeld(player)
	pushState(player)
	return { i = s.i, n = n, by = s.by, byName = s.byName }
end

function Inventory.stackAt(player: Player, slot: number, where: string?): Stack?
	local list = listFor(player, where or "bag")
	return list and list[slot]
end

function Inventory.list(player: Player): { [string]: any }
	local bag, storage = lists(player)
	local function show(list: { Stack }?)
		local out = {}
		for k, s in list or {} do
			local it = Items.get(s.i)
			out[k] = {
				slot = k,
				id = s.i,
				n = s.n,
				name = if it then it.name else s.i,
				byName = s.byName,
				use = if it then it.use else nil,
				hold = if it then it.hold == true else false,
			}
		end
		return out
	end
	local held = player:GetAttribute("HeldItem")
	return { bag = show(bag), storage = show(storage), slots = Config.BAG_SLOTS, held = if type(held) == "string" then held else nil }
end

-- Held items ---------------------------------------------------------------------------------
local function clearHeld(player: Player)
	local c = player.Character
	local old = c and c:FindFirstChild(Inventory.HELD_NAME)
	if old then
		old:Destroy()
	end
	player:SetAttribute("HeldItem", nil)
end

local function hold(player: Player, id: string): boolean
	clearHeld(player)
	local c = player.Character
	local hand = c and (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm"))
	local it = Items.get(id)
	if not hand or not hand:IsA("BasePart") or not it then
		return false
	end
	local part = Instance.new("Part")
	part.Name = Inventory.HELD_NAME
	part.Size = Vector3.one * Config.HOLD_PART_SIZE
	part.Color = it.colour or Color3.fromRGB(200, 190, 170)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, -0.2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = part
	weld.Parent = part
	part:SetAttribute("Item", id)
	part.Parent = c
	player:SetAttribute("HeldItem", id)
	return true
end

function Inventory.init()
	local V = Net.V
	Net.handle("Inventory", "Get", { call = true }, function(player)
		return Inventory.list(player)
	end)
	Net.handle("Inventory", "Use", { schema = { slot = V.int(1, Config.BAG_SLOTS) }, rate = Config.INVENTORY_RATE, call = true }, function(player, a)
		local s = Inventory.stackAt(player, a.slot)
		local it = s and Items.get(s.i)
		if not s or not it or not it.use then
			return nil, "That can't be used."
		end
		local id = s.i
		Inventory.take(player, a.slot, 1, "bag")
		if player:GetAttribute("HeldItem") == id and Inventory.count(player, id) == 0 then
			clearHeld(player)
		end
		return { text = Items.useText(it) }
	end)
	Net.handle("Inventory", "Hold", { schema = { slot = V.int(0, Config.BAG_SLOTS) }, rate = Config.INVENTORY_RATE, call = true }, function(player, a)
		if a.slot == 0 then
			clearHeld(player)
			pushState(player)
			return {}
		end
		local s = Inventory.stackAt(player, a.slot)
		local it = s and Items.get(s.i)
		if not s or not it or not it.hold then
			return nil, "You can't hold that."
		end
		if not hold(player, s.i) then
			return nil, "You need to be in the city to hold things."
		end
		pushState(player)
		return {}
	end)
	-- a held item goes away with the body; and if the last one is given away, drop it
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			player:SetAttribute("HeldItem", nil)
		end)
	end)
end

-- Called by anything that removes items, so a held item vanishes when none are left.
function Inventory.refreshHeld(player: Player)
	local held = player:GetAttribute("HeldItem")
	if type(held) == "string" and Inventory.count(player, held) == 0 then
		clearHeld(player)
	end
end

return Inventory
