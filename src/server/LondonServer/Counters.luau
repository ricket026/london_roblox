--!strict
-- LondonServer.Counters: NPC counters (TASKS T15). Built from Config.COUNTERS at start; other
-- systems add their own with Counters.add (estate agents, wholesale suppliers).
--   kind "shop": sells its `stock` (Shared.Items ids) at base price x `markup` (default 1)
--   kind "bank": bank / post office: deposits and withdrawals (Economy.Bank remote)
--   other kinds: Counters.onOpen(kind, fn(player, def) -> payload) supplies what the menu shows
-- Every counter has a prompt; triggering it pushes Counter.Open { id, kind, name, ... } to the
-- player, and the client's CounterUI shows the menu for that kind.
--   Counters.add(def), Counters.get(id), Counters.isAt(player, id, kind?) -> bool, Counters.price(def, itemId)
-- Remote (Counter domain, call): Buy { counter, item, count }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Money = require(Shared:WaitForChild("Money"))
local Items = require(Shared:WaitForChild("Items"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))
local World = require(script.Parent:WaitForChild("World"))

local Counters = {}

export type Def = {
	id: string,
	kind: string,
	name: string,
	x: number,
	z: number,
	yaw: number?,
	stock: { string }?,
	markup: number?,
	[string]: any,
}

local defs: { [string]: Def } = {}
local positions: { [string]: Vector3 } = {}
local openers: { [string]: (Player, Def) -> { [string]: any } } = {}
local folder: Folder

local WOOD = Color3.fromRGB(96, 66, 42)
local CANOPY = { shop = Color3.fromRGB(52, 104, 70), bank = Color3.fromRGB(28, 38, 64) }

function Counters.price(def: Def, itemId: string): number
	local it = Items.get(itemId)
	if not it then
		return 0
	end
	return math.max(1, math.floor(it.base * (def.markup or 1) + 0.5))
end

function Counters.get(id: string): Def?
	return defs[id]
end

function Counters.isAt(player: Player, id: string, kind: string?): boolean
	local def = defs[id]
	local pos = positions[id]
	if not def or not pos or (kind and def.kind ~= kind) then
		return false
	end
	return World.near(player, pos, Config.COUNTER_RANGE)
end

function Counters.onOpen(kind: string, fn: (Player, Def) -> { [string]: any })
	openers[kind] = fn
end

local function stockList(def: Def): { { [string]: any } }
	local out = {}
	for _, id in def.stock or {} do
		local it = Items.get(id)
		if it then
			local price = Counters.price(def, id)
			table.insert(out, { item = id, name = it.name, price = price, priceText = Money.format(price), stack = it.stack, toStorage = it.furniture ~= nil })
		end
	end
	return out
end

function Counters.payload(player: Player, def: Def): { [string]: any }
	local wallet, bank = Economy.balance(player)
	local msg: { [string]: any } = { id = def.id, kind = def.kind, name = def.name, wallet = wallet, bank = bank }
	if def.kind == "shop" then
		msg.stock = stockList(def)
	elseif def.kind == "bank" then
		msg.presets = Config.BANK_PRESETS
	end
	local extra = openers[def.kind]
	if extra then
		for k, v in extra(player, def) do
			msg[k] = v
		end
	end
	return msg
end

local function build(def: Def): Vector3
	local g = World.ground(def.x, def.z)
	local cf = CFrame.new(g) * CFrame.Angles(0, math.rad(def.yaw or 0), 0)
	local model = Instance.new("Model")
	model.Name = def.id
	local counter = World.part({ Name = "Counter", Size = Vector3.new(6, 3.5, 2), CFrame = cf * CFrame.new(0, 1.75, 0), Color = WOOD, Material = Enum.Material.Wood })
	counter.Parent = model
	local back = World.part({ Name = "Back", Size = Vector3.new(6, 8, 0.4), CFrame = cf * CFrame.new(0, 4, 2.2), Color = WOOD, Material = Enum.Material.Wood })
	back.Parent = model
	local canopy = World.part({ Name = "Canopy", Size = Vector3.new(7, 0.3, 4), CFrame = cf * CFrame.new(0, 8.2, 0.6), Color = CANOPY[def.kind] or WOOD, Material = Enum.Material.Fabric })
	canopy.Parent = model
	local sign = World.part({ Name = "Sign", Size = Vector3.new(6, 1.2, 0.2), CFrame = cf * CFrame.new(0, 7.2, -0.9), Color = Color3.fromRGB(28, 28, 30), Material = Enum.Material.Wood, CanCollide = false })
	World.sign(sign, Enum.NormalId.Front, def.name, Color3.fromRGB(196, 160, 72))
	sign.Parent = model
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = if def.kind == "bank" then "Bank" elseif def.kind == "shop" then "Buy" else "Speak"
	pp.ObjectText = def.name
	pp.MaxActivationDistance = 8
	pp.RequiresLineOfSight = false
	pp.Parent = counter
	pp.Triggered:Connect(function(player)
		Net.push(player, "Counter", "Open", Counters.payload(player, def))
	end)
	model.PrimaryPart = counter
	model.Parent = folder
	return counter.Position
end

function Counters.add(def: Def)
	assert(defs[def.id] == nil, "duplicate counter " .. def.id)
	defs[def.id] = def
	positions[def.id] = build(def)
end

-- Buy from a shop counter. Returns the new balances, or nil and a reason.
function Counters.buy(player: Player, counterId: string, itemId: string, count: number): ({ [string]: any }?, string?)
	local def = defs[counterId]
	if not def or def.kind ~= "shop" then
		return nil, "That counter doesn't sell things."
	end
	if not Counters.isAt(player, counterId) then
		return nil, "Step up to the counter."
	end
	if not table.find(def.stock or {}, itemId) then
		return nil, "They don't sell that here."
	end
	local it = Items.get(itemId)
	if not it or count < 1 or count > it.stack then
		return nil, "Choose how many."
	end
	if not Inventory.canAdd(player, itemId, count) then
		return nil, "Your bag is full."
	end
	local total = Counters.price(def, itemId) * count
	local ok, why = Economy.charge(player, total, "purchase", counterId .. ":" .. itemId)
	if not ok then
		return nil, why
	end
	Inventory.add(player, itemId, count)
	local p = Profiles.get(player)
	return { wallet = if p then p.pence else 0, bank = if p then p.bank else 0, bought = it.name, count = count, toStorage = it.furniture ~= nil }
end

function Counters.init()
	folder = World.folder("Counters")
	for _, def in Config.COUNTERS do
		Counters.add(def :: any)
	end
	Economy.isAtBank = function(player, id)
		return Counters.isAt(player, id, "bank")
	end
	local V = Net.V
	Net.handle("Counter", "Buy", {
		schema = { counter = V.str(40), item = V.str(40), count = V.int(1, 99) },
		rate = Config.COUNTER_RATE,
		call = true,
	}, function(player, a)
		return Counters.buy(player, a.counter, a.item, a.count)
	end)
end

return Counters
