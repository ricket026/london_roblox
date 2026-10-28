--!strict
-- Shared.Palette: the named colours of art/style.md §4 (same ids, same RGB) with the Roblox
-- material each uses in greybox. Builds save a colour as its index in Palette.ORDER, so only ever
-- add colours at the END of the list (an index must keep meaning the same colour forever).
--   Palette.get(id) -> Colour?          Palette.index(id) -> number?      Palette.at(index) -> Colour?
--   Palette.color(id) -> Color3          Palette.WALLPAPERS: interior finishes (BUILDING §2)
--   Palette.GROUPS: which colours a player may choose for a slot kind (face, door, ...)
local Palette = {}

export type Colour = { id: string, rgb: { number }, material: Enum.Material, color: Color3, index: number }

local M = Enum.Material
-- { id, r, g, b, material }; order is the saved index (append only)
local LIST: { { any } } = {
	{ "brick_stock", 196, 170, 120, M.Brick },
	{ "brick_stock_sooted", 120, 104, 82, M.Brick },
	{ "brick_red", 150, 72, 54, M.Brick },
	{ "brick_blue", 64, 66, 76, M.Brick },
	{ "stucco_white", 236, 232, 222, M.Concrete },
	{ "stucco_cream", 224, 212, 186, M.Concrete },
	{ "stone_portland", 214, 208, 194, M.Limestone },
	{ "stone_bath", 206, 186, 146, M.Limestone },
	{ "stone_sooted", 120, 116, 108, M.Limestone },
	{ "render_grey", 168, 164, 156, M.Concrete },
	{ "slate", 74, 78, 86, M.Slate },
	{ "lead", 110, 114, 118, M.Metal },
	{ "chimney_pot", 172, 98, 70, M.Brick },
	{ "iron_black", 28, 28, 30, M.Metal },
	{ "iron_green", 52, 82, 66, M.Metal },
	{ "timber_dark", 76, 54, 38, M.Wood },
	{ "timber_light", 156, 120, 80, M.WoodPlanks },
	{ "glass", 150, 170, 180, M.Glass },
	{ "door_black", 22, 22, 24, M.SmoothPlastic },
	{ "door_green", 30, 64, 46, M.SmoothPlastic },
	{ "door_oxblood", 96, 28, 28, M.SmoothPlastic },
	{ "door_navy", 28, 38, 64, M.SmoothPlastic },
	{ "door_ochre", 180, 132, 52, M.SmoothPlastic },
	{ "shop_cream", 232, 220, 190, M.SmoothPlastic },
	{ "shop_maroon", 104, 34, 40, M.SmoothPlastic },
	{ "shop_teal", 40, 92, 96, M.SmoothPlastic },
	{ "gilt", 196, 160, 72, M.Metal },
	{ "livery_royal_red", 170, 24, 30, M.SmoothPlastic },
	{ "livery_police_navy", 24, 30, 52, M.SmoothPlastic },
	{ "livery_cab_green", 44, 70, 52, M.SmoothPlastic },
	{ "livery_omnibus_red", 150, 40, 36, M.SmoothPlastic },
	{ "livery_omnibus_yellow", 196, 160, 60, M.SmoothPlastic },
	{ "canvas_stripe_red", 170, 54, 48, M.Fabric },
	{ "canvas_stripe_green", 52, 104, 70, M.Fabric },
	{ "grass", 82, 112, 60, M.Grass },
	{ "foliage", 60, 88, 48, M.Grass },
	{ "gravel", 178, 166, 140, M.Pebble },
	{ "setts", 102, 102, 106, M.Cobblestone },
	{ "flagstone", 150, 146, 138, M.Slate },
	{ "water_thames", 76, 84, 78, M.SmoothPlastic }, -- Water is terrain-only
	{ "water_lake", 86, 104, 96, M.SmoothPlastic },
	{ "white_wash", 240, 236, 226, M.SmoothPlastic },
}

Palette.ORDER = {} :: { Colour }
local byId: { [string]: Colour } = {}
for k, e in LIST do
	local c: Colour = { id = e[1], rgb = { e[2], e[3], e[4] }, material = e[5], color = Color3.fromRGB(e[2], e[3], e[4]), index = k }
	Palette.ORDER[k] = c
	byId[c.id] = c
end

function Palette.get(id: string): Colour?
	return byId[id]
end

function Palette.index(id: string): number?
	local c = byId[id]
	return if c then c.index else nil
end

function Palette.at(index: number): Colour?
	return Palette.ORDER[index]
end

function Palette.color(id: string): Color3
	local c = byId[id]
	return if c then c.color else Color3.fromRGB(255, 0, 255) -- magenta: an unknown id shows up
end

-- What a player may pick for each kind of colour slot (Shared.Kit pieces name their slots).
Palette.GROUPS = {
	face = { "brick_stock", "brick_stock_sooted", "brick_red", "brick_blue", "stucco_white", "stucco_cream",
		"stone_portland", "stone_bath", "stone_sooted", "render_grey", "white_wash" },
	trim = { "stone_portland", "stone_bath", "stucco_white", "stucco_cream", "white_wash", "iron_black" },
	door = { "door_black", "door_green", "door_oxblood", "door_navy", "door_ochre", "timber_dark", "timber_light" },
	frame = { "shop_cream", "shop_maroon", "shop_teal", "door_black", "door_green", "door_navy", "door_ochre" },
	finish = { "timber_light", "timber_dark", "stone_portland", "flagstone", "slate", "lead", "grass", "gravel", "foliage" },
	wood = { "timber_dark", "timber_light", "door_black", "door_oxblood" },
	cloth = { "door_oxblood", "door_green", "door_navy", "stucco_cream", "shop_teal", "canvas_stripe_red" },
	metal = { "iron_black", "gilt", "lead", "iron_green" },
	pots = { "chimney_pot", "brick_red" },
	top = { "timber_light", "timber_dark", "stone_portland" },
}

-- Interior wallpapers (style.md §4): saved by index in this list (append only).
Palette.WALLPAPERS = {
	{ id = "morris_leaf", name = "Leaf pattern", color = Color3.fromRGB(92, 110, 78) },
	{ id = "damask_red", name = "Red damask", color = Color3.fromRGB(122, 40, 42) },
	{ id = "damask_green", name = "Green damask", color = Color3.fromRGB(52, 84, 60) },
	{ id = "stripe_cream", name = "Cream stripe", color = Color3.fromRGB(226, 214, 184) },
	{ id = "stripe_blue", name = "Blue stripe", color = Color3.fromRGB(86, 104, 130) },
	{ id = "flock_gold", name = "Gold flock", color = Color3.fromRGB(176, 142, 70) },
	{ id = "plain_ochre", name = "Ochre", color = Color3.fromRGB(196, 150, 72) },
	{ id = "plain_sage", name = "Sage", color = Color3.fromRGB(142, 156, 124) },
	{ id = "plain_duck_egg", name = "Duck-egg", color = Color3.fromRGB(170, 196, 190) },
	{ id = "panelled_oak", name = "Oak panelling", color = Color3.fromRGB(120, 86, 52) },
}

return Palette
