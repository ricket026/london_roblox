--!strict
-- Shared.Items: every item a player can own, carry, use, place or sell (SHOPS.md §1).
-- base = reference price in pence (NPC counters sell at base x markup; shops price 0.8-3x base,
-- wholesale is 60% of base). stack = most per bag stack. Flags:
--   use = "eat" | "drink" | "read": consumable (used up, with a message)
--   hold = true: can be held in the hand (greybox part on the right hand)
--   furniture = Shared.Kit piece id: placeable in build mode; bought into storage, not the bag
--   made = true: only players make it (no NPC source); carries a "Made by" name
-- No alcohol, no tobacco (DESIGN §12).
local Items = {}

export type Item = {
	id: string,
	name: string,
	cat: string, -- category (SHOPS §1), also the shop trades that may stock it
	base: number,
	stack: number,
	use: string?,
	hold: boolean?,
	furniture: string?,
	made: boolean?,
	colour: Color3?, -- greybox colour when held
}

Items.CATEGORIES = { "food", "flowers", "stationery", "toys", "tools", "chemist", "furniture", "ingredients" }

local ITEMS: { Item } = {
	-- food & drink
	{ id = "tea", name = "Cup of Tea", cat = "food", base = 1, stack = 5, use = "drink", hold = true, colour = Color3.fromRGB(236, 232, 222) },
	{ id = "coffee", name = "Cup of Coffee", cat = "food", base = 1, stack = 5, use = "drink", hold = true, colour = Color3.fromRGB(236, 232, 222) },
	{ id = "lemonade", name = "Lemonade", cat = "food", base = 1, stack = 5, use = "drink", hold = true, colour = Color3.fromRGB(230, 220, 150) },
	{ id = "bun", name = "Currant Bun", cat = "food", base = 1, stack = 10, use = "eat", colour = Color3.fromRGB(196, 150, 90) },
	{ id = "sandwich", name = "Cress Sandwich", cat = "food", base = 2, stack = 10, use = "eat" },
	{ id = "cake_slice", name = "Slice of Victoria Sponge", cat = "food", base = 2, stack = 10, use = "eat" },
	{ id = "pie", name = "Pork Pie", cat = "food", base = 3, stack = 10, use = "eat" },
	{ id = "bread_loaf", name = "Cottage Loaf", cat = "food", base = 2, stack = 10, use = "eat", made = true },
	{ id = "apple", name = "Apple", cat = "food", base = 1, stack = 10, use = "eat", hold = true, colour = Color3.fromRGB(170, 40, 40) },
	{ id = "orange", name = "Orange", cat = "food", base = 1, stack = 10, use = "eat", hold = true, colour = Color3.fromRGB(230, 140, 40) },
	-- flowers
	{ id = "violets", name = "Bunch of Violets", cat = "flowers", base = 1, stack = 10, hold = true, colour = Color3.fromRGB(110, 70, 160) },
	{ id = "rose", name = "Red Rose", cat = "flowers", base = 2, stack = 10, hold = true, colour = Color3.fromRGB(180, 30, 40) },
	{ id = "bouquet", name = "Bouquet", cat = "flowers", base = 4, stack = 5, hold = true, made = true, colour = Color3.fromRGB(220, 120, 150) },
	-- stationery & papers
	{ id = "newspaper", name = "The Daily Courier", cat = "stationery", base = 1, stack = 10, use = "read", hold = true, colour = Color3.fromRGB(220, 214, 196) },
	{ id = "letter_paper", name = "Writing Paper", cat = "stationery", base = 1, stack = 20 },
	{ id = "calling_card", name = "Calling Cards", cat = "stationery", base = 2, stack = 20 },
	-- toys
	{ id = "spinning_top", name = "Spinning Top", cat = "toys", base = 3, stack = 5, hold = true },
	{ id = "hoop_stick", name = "Hoop and Stick", cat = "toys", base = 4, stack = 1, hold = true },
	{ id = "kite", name = "Paper Kite", cat = "toys", base = 6, stack = 1, hold = true },
	-- tools
	{ id = "watering_can", name = "Watering Can", cat = "tools", base = 6, stack = 1, hold = true, colour = Color3.fromRGB(80, 90, 80) },
	{ id = "seed_packet", name = "Packet of Seeds", cat = "tools", base = 1, stack = 20 },
	{ id = "fishing_rod_fine", name = "Split-Cane Rod", cat = "tools", base = 12, stack = 1, hold = true },
	-- chemist
	{ id = "smelling_salts", name = "Smelling Salts", cat = "chemist", base = 6, stack = 5 },
	{ id = "motor_spirit", name = "Can of Motor Spirit", cat = "chemist", base = 12, stack = 3 },
	-- ingredients (makers, SHOPS §7)
	{ id = "flour", name = "Sack of Flour", cat = "ingredients", base = 1, stack = 20 },
	{ id = "timber", name = "Timber", cat = "ingredients", base = 2, stack = 20 },
	{ id = "cloth", name = "Bolt of Cloth", cat = "ingredients", base = 3, stack = 20 },
	-- furniture (Shared.Kit ids; the starter set is free in build mode and not sold)
	{ id = "bed_double", name = "Double Bed", cat = "furniture", base = 240, stack = 99, furniture = "bed_double" },
	{ id = "wardrobe", name = "Wardrobe", cat = "furniture", base = 180, stack = 99, furniture = "wardrobe" },
	{ id = "table_dining", name = "Dining Table", cat = "furniture", base = 120, stack = 99, furniture = "table_dining" },
	{ id = "armchair", name = "Button-back Armchair", cat = "furniture", base = 120, stack = 99, furniture = "armchair" },
	{ id = "sofa", name = "Chesterfield", cat = "furniture", base = 240, stack = 99, furniture = "sofa" },
	{ id = "sideboard", name = "Sideboard", cat = "furniture", base = 150, stack = 99, furniture = "sideboard" },
	{ id = "bookcase", name = "Bookcase", cat = "furniture", base = 120, stack = 99, furniture = "bookcase" },
	{ id = "desk", name = "Writing Desk", cat = "furniture", base = 120, stack = 99, furniture = "desk" },
	{ id = "fireplace", name = "Fireplace", cat = "furniture", base = 180, stack = 99, furniture = "fireplace" },
	{ id = "standard_lamp", name = "Standard Lamp", cat = "furniture", base = 60, stack = 99, furniture = "standard_lamp" },
	{ id = "chandelier", name = "Chandelier", cat = "furniture", base = 480, stack = 99, furniture = "chandelier" },
	{ id = "clock_long", name = "Longcase Clock", cat = "furniture", base = 240, stack = 99, furniture = "clock_long" },
	{ id = "plant_pot", name = "Aspidistra", cat = "furniture", base = 24, stack = 99, furniture = "plant_pot" },
	{ id = "piano_upright", name = "Upright Piano", cat = "furniture", base = 960, stack = 99, furniture = "piano_upright" },
	{ id = "kitchen_range", name = "Kitchen Range", cat = "furniture", base = 240, stack = 99, furniture = "kitchen_range" },
	{ id = "dresser", name = "Kitchen Dresser", cat = "furniture", base = 150, stack = 99, furniture = "dresser" },
	{ id = "sink", name = "Stone Sink", cat = "furniture", base = 60, stack = 99, furniture = "sink" },
	{ id = "counter_till", name = "Counter with Till", cat = "furniture", base = 180, stack = 99, furniture = "counter_till" },
	{ id = "display_case", name = "Display Case", cat = "furniture", base = 150, stack = 99, furniture = "display_case" },
	{ id = "barrel", name = "Barrel", cat = "furniture", base = 12, stack = 99, furniture = "barrel" },
	{ id = "flower_stand", name = "Flower Stand", cat = "furniture", base = 90, stack = 99, furniture = "flower_stand" },
}
Items.LIST = ITEMS

Items.BY_ID = {} :: { [string]: Item }
for _, it in ITEMS do
	assert(Items.BY_ID[it.id] == nil, "duplicate item id " .. it.id)
	assert(table.find(Items.CATEGORIES, it.cat) ~= nil, "unknown category for " .. it.id)
	Items.BY_ID[it.id] = it
end

function Items.get(id: string): Item?
	return Items.BY_ID[id]
end

-- Stored furniture goes to storage; everything else to the bag.
function Items.goesToStorage(id: string): boolean
	local it = Items.BY_ID[id]
	return it ~= nil and it.furniture ~= nil
end

-- What using an item says in the player's toast.
function Items.useText(it: Item): string
	if it.use == "eat" then
		return "You eat the " .. string.lower(it.name) .. "."
	elseif it.use == "drink" then
		return "You drink the " .. string.lower(it.name) .. "."
	elseif it.use == "read" then
		return "You read " .. it.name .. "."
	end
	return ""
end

return Items
