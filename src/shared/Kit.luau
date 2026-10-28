--!strict
-- Shared.Kit: the building kit (art/kit.md is the contract: same ids, sizes and pivots; checked by
-- tests/test_kit.luau). Used by the server (rules, rendering published builds and templates) and
-- the client (ghost preview, draft rendering), so both apply the same rules.
--
-- Lot space (art/kit.md "Coordinates"): origin at the plot's street-left corner on its top
-- surface, +X along the street (to your right facing the house from the street), +Z into the plot,
-- +Y up. A placed piece is { id, x, z, y, r, c, k }: x/z in half-studs (min corner of its rotated
-- footprint), y = storey index, r = quarter turns clockwise from above (furniture: 15° steps,
-- 0-23), c = palette index of its first colour slot (0 = default), k = key, unique in the build.
--   Kit.PIECES[id], Kit.ORDER (catalogue order), Kit.GROUPS
--   Kit.footprint(p) -> x0, z0, x1, z1 (studs);  Kit.box(p) -> x0, y0, z0, x1, y1, z1 (studs)
--   Kit.check(build, lot, p, ignoreKey?) -> ok, reason   one placement against the rules
--   Kit.publishable(build, lot) -> ok, reason              the street-front rule (BUILDING §3)
--   Kit.lotFrame(plotPart) -> Frame?                        from the attributes LondonServer.Lots sets
--   Kit.makePiece(p, frame, opts?) -> Model                 greybox parts for one piece
--   Kit.starter(kind, w, d, variant, budget?) -> { Piece }  a ready, publishable house
-- `lot` in these calls is { w = frontage, d = depth, storeys = n, budget = n } (studs).
local Config = require(script.Parent:WaitForChild("Config"))
local Palette = require(script.Parent:WaitForChild("Palette"))

local Kit = {}

Kit.STOREY = 12 -- studs per storey
Kit.FLOOR = 0.4 -- floor thickness; furniture stands on top of it
Kit.FRONT_OUT = 2 -- studs a `front` piece may stand in front of the street edge
Kit.ROOF_MAX = 8 -- studs a roof may rise above the top storey
Kit.TOLERANCE = 0.01 -- studs of overlap ignored by the box test
Kit.GRID = { wall = 2, trim = 2, floor = 4, roof = 4, outside = 4, furniture = 1, rug = 1 } -- half-studs

export type Piece = { id: string, x: number, z: number, y: number, r: number, c: number, k: number }
export type Build = { v: number, kind: string, w: number, d: number, pieces: { Piece }, nextKey: number, published: boolean, faces: { [string]: any }? }
export type Lot = { w: number, d: number, storeys: number, budget: number }
export type Frame = { origin: Vector3, right: Vector3, inward: Vector3 }
-- A greybox box in piece space at r = 0: x across the width, y up from the piece base, z from the
-- street-facing side (0) back to the depth. flags: glass, door, seat, wedge (rises toward +z),
-- light (PointLight), soft (no collision).
type Box = { number | string }
export type Def = {
	id: string, class: string, w: number, d: number, h: number, front: boolean,
	slots: { { string } }, tris: number, group: string, starter: boolean, name: string,
	base: number?, minY: number?, shape: { Box },
}

local function def(id: string, class: string, w: number, d: number, h: number, front: boolean, slots: { { string } }, tris: number, name: string, shape: { Box }, extra: { [string]: any }?): Def
	local group = if class == "rug" then "furniture" else class
	local d0: Def = {
		id = id, class = class, w = w, d = d, h = h, front = front, slots = slots, tris = tris,
		group = if group == "wall" then "walls" elseif group == "floor" then "floors" elseif group == "roof" then "roofs" else group,
		starter = class ~= "furniture" and class ~= "rug", name = name, shape = shape,
	}
	local anyDef: any = d0
	for k, v in extra or {} do
		anyDef[k] = v
	end
	return d0
end

local F, T, DR, FR = { "face", "brick_stock_sooted" }, { "trim", "stone_portland" }, { "door", "door_black" }, { "frame", "shop_maroon" }
local WOOD, CLOTH, METAL = { "wood", "timber_dark" }, { "cloth", "stucco_cream" }, { "metal", "gilt" }

-- Pieces in catalogue order (art/kit.md tables, in the same order).
local LIST: { Def } = {
	-- walls: bays 4 wide, one storey tall, 1 thick; the face looks toward -z (the street) at r = 0
	def("wall_plain", "wall", 4, 1, 12, false, { F }, 60, "Plain wall", { { 0, 0, 0, 4, 12, 1, "face" } }),
	def("wall_half", "wall", 2, 1, 12, false, { F }, 40, "Narrow wall", { { 0, 0, 0, 2, 12, 1, "face" } }),
	def("wall_sash", "wall", 4, 1, 12, false, { F, T }, 300, "Sash window", {
		{ 0, 0, 0, 1, 12, 1, "face" }, { 3, 0, 0, 4, 12, 1, "face" }, { 1, 0, 0, 3, 3, 1, "face" },
		{ 1, 9, 0, 3, 12, 1, "face" }, { 1, 3, 0.4, 3, 9, 0.6, "glass" }, { 0.8, 2.7, -0.2, 3.2, 3, 0.4, "trim" },
	}),
	def("wall_sash_tall", "wall", 4, 1, 12, false, { F, T }, 320, "Tall sash window", {
		{ 0, 0, 0, 1, 12, 1, "face" }, { 3, 0, 0, 4, 12, 1, "face" }, { 1, 0, 0, 3, 2, 1, "face" },
		{ 1, 10, 0, 3, 12, 1, "face" }, { 1, 2, 0.4, 3, 10, 0.6, "glass" }, { 0.8, 1.7, -0.2, 3.2, 2, 0.4, "trim" },
	}),
	def("wall_bay", "wall", 4, 1, 12, true, { F, T }, 600, "Bay window", {
		{ 0, 0, 0, 4, 2.5, 1, "face" }, { 0, 9.5, 0, 4, 12, 1, "face" }, { 0, 2.5, 0, 0.5, 9.5, 1, "face" },
		{ 3.5, 2.5, 0, 4, 9.5, 1, "face" }, { 0.5, 2.5, -1.5, 3.5, 9.5, -1.3, "glass" }, { 0.3, 2, -1.5, 3.7, 2.5, 0, "trim" },
	}),
	def("wall_door", "wall", 4, 1, 12, false, { F, DR, T }, 420, "Front door", {
		{ 0, 0, 0, 0.5, 12, 1, "face" }, { 3.5, 0, 0, 4, 12, 1, "face" }, { 0.5, 9.5, 0, 3.5, 12, 1, "face" },
		{ 0.5, 8, 0.4, 3.5, 9.5, 0.6, "glass" }, { 0.5, 0, 0.35, 3.5, 8, 0.65, "door", "door" },
	}),
	def("wall_shopfront", "wall", 4, 1, 12, false, { F, FR, T }, 700, "Shopfront", {
		{ 0, 0, 0, 2.6, 1.5, 1, "frame" }, { 0, 1.5, 0.4, 2.6, 8, 0.6, "glass" }, { 2.6, 0, 0.35, 3.8, 8, 0.65, "frame", "door" },
		{ 3.8, 0, 0, 4, 8, 1, "frame" }, { 0, 8, -0.3, 4, 9.5, 1, "frame" }, { 0, 9.5, 0, 4, 12, 1, "face" },
	}),
	def("wall_arch", "wall", 4, 1, 12, false, { F, { "door", "timber_dark" } }, 380, "Carriage arch", {
		{ 0, 0, 0, 0.25, 12, 1, "face" }, { 3.75, 0, 0, 4, 12, 1, "face" }, { 0.25, 9, 0, 3.75, 12, 1, "face" },
		{ 0.25, 0, 0.4, 3.75, 9, 0.6, "door", "door" },
	}),
	def("wall_interior", "wall", 4, 0.5, 12, false, { { "face", "white_wash" } }, 24, "Partition", { { 0, 0, 0, 4, 12, 0.5, "face" } }),
	def("wall_interior_door", "wall", 4, 0.5, 12, false, { { "face", "white_wash" }, { "door", "timber_dark" } }, 200, "Partition with door", {
		{ 0, 0, 0, 0.5, 12, 0.5, "face" }, { 3.5, 0, 0, 4, 12, 0.5, "face" }, { 0.5, 8, 0, 3.5, 12, 0.5, "face" },
		{ 0.5, 0, 0.15, 3.5, 8, 0.35, "door", "door" },
	}),
	-- floors and stairs
	def("floor_boards", "floor", 4, 4, 0.4, false, { { "finish", "timber_light" } }, 12, "Floorboards", { { 0, 0, 0, 4, 0.4, 4, "finish" } }),
	def("floor_parquet", "floor", 4, 4, 0.4, false, { { "finish", "timber_light" } }, 12, "Parquet", { { 0, 0, 0, 4, 0.4, 4, "finish" } }),
	def("floor_tiles", "floor", 4, 4, 0.4, false, { { "finish", "stone_portland" } }, 12, "Tiled floor", { { 0, 0, 0, 4, 0.4, 4, "finish" } }),
	def("floor_flags", "floor", 4, 4, 0.4, false, { { "finish", "flagstone" } }, 12, "Flagstones", { { 0, 0, 0, 4, 0.4, 4, "finish" } }),
	def("stairs", "floor", 4, 8, 12.4, false, { { "finish", "timber_dark" } }, 400, "Stairs", { { 0, 0, 0, 4, 12.4, 8, "finish", "wedge" } }),
	-- roofs and chimneys (they may sit on the storey above the top one)
	def("roof_flat", "roof", 4, 4, 1, false, { { "finish", "lead" } }, 20, "Flat roof", { { 0, 0, 0, 4, 0.6, 4, "finish" }, { 0, 0.6, 0, 4, 1, 0.3, "finish" } }),
	def("roof_pitch", "roof", 4, 8, 6, false, { { "finish", "slate" } }, 40, "Pitched roof", { { 0, 0, 0, 4, 6, 8, "finish", "wedge" } }),
	def("roof_mansard", "roof", 4, 4, 8, false, { { "finish", "slate" } }, 60, "Mansard roof", { { 0, 0, 0, 4, 8, 4, "finish", "wedge" } }),
	def("roof_mansard_dormer", "roof", 4, 4, 8, false, { { "finish", "slate" }, { "trim", "stucco_white" } }, 300, "Mansard with dormer", {
		{ 0, 0, 0, 4, 8, 4, "finish", "wedge" }, { 1, 1, 0.6, 3, 5, 2.4, "trim" }, { 1.3, 1.5, 0.5, 2.7, 4.5, 0.6, "glass" },
	}),
	def("chimney", "roof", 2, 2, 6, false, { F, { "pots", "chimney_pot" } }, 150, "Chimney stack", { { 0, 0, 0, 2, 5, 2, "face" }, { 0.4, 5, 0.4, 1.6, 6, 1.6, "pots" } }),
	-- trim
	def("cornice", "trim", 4, 1, 1.5, true, { { "face", "stone_portland" } }, 80, "Cornice", { { 0, 0, -0.5, 4, 1.5, 1, "face" } }, { base = 10.5 }),
	def("string_course", "trim", 4, 1, 0.6, true, { { "face", "stone_portland" } }, 30, "String course", { { 0, 0, -0.2, 4, 0.6, 1, "face" } }, { base = 11.4 }),
	def("portico", "trim", 4, 2, 10, true, { { "face", "stucco_white" } }, 900, "Portico", {
		{ 0.2, 0, 0.2, 0.9, 9, 0.9, "face" }, { 3.1, 0, 0.2, 3.8, 9, 0.9, "face" }, { 0, 9, 0, 4, 10, 2, "face" },
	}),
	def("steps", "trim", 4, 2, 1.5, true, { { "face", "stone_portland" } }, 60, "Front steps", {
		{ 0, 0, 0, 4, 0.5, 2, "face" }, { 0, 0.5, 0.67, 4, 1, 2, "face" }, { 0, 1, 1.33, 4, 1.5, 2, "face" },
	}),
	def("railings", "trim", 4, 0.5, 3, true, { { "face", "iron_black" } }, 400, "Railings", {
		{ 0, 0, 0, 4, 0.3, 0.5, "face" }, { 0, 2.7, 0, 4, 3, 0.5, "face" }, { 0.1, 0.3, 0.2, 3.9, 2.7, 0.3, "face", "bars" },
	}),
	def("balcony", "trim", 4, 1.5, 3.5, true, { { "face", "iron_black" } }, 500, "Balcony", {
		{ 0, 0, 0, 4, 0.3, 1.5, "face" }, { 0, 0.3, 0, 4, 3.5, 0.1, "face", "bars" }, { 0, 3.3, 0, 4, 3.5, 1.5, "face" },
	}, { minY = 1 }),
	-- outside (ground storey only)
	def("garden_wall", "outside", 4, 1, 4, false, { F }, 40, "Garden wall", { { 0, 0, 0, 4, 4, 1, "face" } }),
	def("garden_gate", "outside", 4, 1, 4, false, { { "face", "timber_dark" } }, 120, "Garden gate", {
		{ 0, 0, 0, 0.5, 4, 1, "face" }, { 3.5, 0, 0, 4, 4, 1, "face" }, { 0.5, 0, 0.4, 3.5, 3.5, 0.6, "face", "door" },
	}),
	def("lawn", "outside", 4, 4, 0.3, false, { { "finish", "grass" } }, 12, "Lawn", { { 0, 0, 0, 4, 0.3, 4, "finish" } }),
	def("path", "outside", 4, 4, 0.3, false, { { "finish", "gravel" } }, 12, "Path", { { 0, 0, 0, 4, 0.3, 4, "finish" } }),
	def("flower_bed", "outside", 4, 2, 1, false, { { "finish", "foliage" } }, 200, "Flower bed", { { 0, 0, 0, 4, 1, 2, "finish" } }),
	def("tree_small", "outside", 2, 2, 10, false, { { "finish", "foliage" } }, 400, "Small tree", {
		{ 0.75, 0, 0.75, 1.25, 5, 1.25, "trunk" }, { -0.3, 4, -0.3, 2.3, 10, 2.3, "finish", "soft" },
	}),
	-- furniture (half-stud grid, stands on a floor); seats face -z at r = 0
	def("bed_single", "furniture", 3, 6, 2.5, false, { WOOD, CLOTH }, 400, "Single bed", { { 0, 0, 0, 3, 1.5, 6, "cloth" }, { 0, 0, 5.6, 3, 2.5, 6, "wood" } }),
	def("bed_double", "furniture", 5, 6, 3, false, { WOOD, CLOTH }, 600, "Double bed", { { 0, 0, 0, 5, 1.6, 6, "cloth" }, { 0, 0, 5.5, 5, 3, 6, "wood" } }),
	def("wardrobe", "furniture", 4, 2, 7, false, { WOOD }, 300, "Wardrobe", { { 0, 0, 0, 4, 7, 2, "wood" } }),
	def("washstand", "furniture", 3, 1.5, 3, false, { WOOD }, 300, "Washstand", { { 0, 0, 0, 3, 2.6, 1.5, "wood" }, { 0.9, 2.6, 0.3, 2.1, 3, 1.2, "basin" } }),
	def("table_dining", "furniture", 4, 6, 3, false, { WOOD }, 300, "Dining table", { { 0, 2.6, 0, 4, 3, 6, "wood" }, { 1.6, 0, 2.6, 2.4, 2.6, 3.4, "wood" } }),
	def("table_small", "furniture", 2.5, 2.5, 3, false, { WOOD }, 200, "Side table", { { 0, 2.6, 0, 2.5, 3, 2.5, "wood" }, { 1, 0, 1, 1.5, 2.6, 1.5, "wood" } }),
	def("chair", "furniture", 1.5, 1.5, 3.5, false, { WOOD, CLOTH }, 250, "Chair", { { 0, 0, 0, 1.5, 1.6, 1.5, "wood", "seat" }, { 0, 1.6, 1.3, 1.5, 3.5, 1.5, "wood" } }),
	def("armchair", "furniture", 2.5, 2.5, 3.5, false, { { "cloth", "door_oxblood" } }, 500, "Armchair", { { 0, 0, 0, 2.5, 1.6, 2.5, "cloth", "seat" }, { 0, 1.6, 2, 2.5, 3.5, 2.5, "cloth" } }),
	def("sofa", "furniture", 6, 2.5, 3.5, false, { CLOTH }, 700, "Chesterfield", {
		{ 0, 0, 0, 3, 1.6, 2.5, "cloth", "seat" }, { 3, 0, 0, 6, 1.6, 2.5, "cloth", "seat" }, { 0, 1.6, 2, 6, 3.5, 2.5, "cloth" },
	}),
	def("sideboard", "furniture", 5, 1.5, 3.5, false, { WOOD }, 300, "Sideboard", { { 0, 0, 0, 5, 3.5, 1.5, "wood" } }),
	def("bookcase", "furniture", 4, 1.5, 7, false, { WOOD }, 500, "Bookcase", { { 0, 0, 0, 4, 7, 1.5, "wood" } }),
	def("desk", "furniture", 4, 2.5, 3, false, { WOOD }, 300, "Writing desk", { { 0, 2.6, 0, 4, 3, 2.5, "wood" }, { 0, 0, 0, 1.2, 2.6, 2.5, "wood" }, { 2.8, 0, 0, 4, 2.6, 2.5, "wood" } }),
	def("fireplace", "furniture", 4, 1.5, 4.5, false, { { "face", "stone_portland" } }, 400, "Fireplace", {
		{ 0, 0, 0.5, 4, 4, 1.5, "face" }, { -0.2, 4, 0, 4.2, 4.5, 1.5, "face" }, { 1, 0, 0.3, 3, 2.2, 0.5, "fire", "light" },
	}),
	def("standard_lamp", "furniture", 1, 1, 5, false, { METAL }, 200, "Standard lamp", { { 0.4, 0, 0.4, 0.6, 4, 0.6, "metal" }, { 0, 4, 0, 1, 5, 1, "shade", "light" } }),
	def("chandelier", "furniture", 3, 3, 3, false, { METAL }, 800, "Chandelier", { { 1.4, 1.5, 1.4, 1.6, 3, 1.6, "metal" }, { 0, 0, 0, 3, 1.5, 3, "metal", "light" } }, { base = 9 }),
	def("clock_long", "furniture", 1.5, 1, 7, false, { WOOD }, 300, "Longcase clock", { { 0, 0, 0, 1.5, 7, 1, "wood" } }),
	def("plant_pot", "furniture", 1.5, 1.5, 3, false, { { "finish", "foliage" } }, 300, "Aspidistra", { { 0.25, 0, 0.25, 1.25, 1, 1.25, "pot" }, { 0, 1, 0, 1.5, 3, 1.5, "finish", "soft" } }),
	def("piano_upright", "furniture", 5, 2, 4.5, false, { WOOD }, 600, "Upright piano", { { 0, 0, 0.5, 5, 4.5, 2, "wood" }, { 0, 2.4, 0, 5, 2.8, 0.5, "keys" } }),
	def("kitchen_range", "furniture", 4, 2, 4, false, { { "metal", "iron_black" } }, 500, "Kitchen range", { { 0, 0, 0, 4, 3, 2, "metal" }, { 0.5, 3, 1.2, 3.5, 4, 2, "metal" } }),
	def("dresser", "furniture", 4, 1.5, 7, false, { WOOD }, 500, "Dresser", { { 0, 0, 0, 4, 3, 1.5, "wood" }, { 0, 3, 0.8, 4, 7, 1.5, "wood" } }),
	def("sink", "furniture", 3, 2, 3, false, { { "face", "stone_portland" } }, 200, "Stone sink", { { 0, 0, 0, 3, 3, 2, "face" } }),
	def("rug", "rug", 6, 4, 0.1, false, { { "cloth", "door_oxblood" } }, 8, "Rug", { { 0, 0, 0, 6, 0.1, 4, "cloth", "soft" } }),
	def("counter", "furniture", 4, 2, 3.5, false, { WOOD, { "top", "timber_light" } }, 250, "Shop counter", { { 0, 0, 0, 4, 3.2, 2, "wood" }, { 0, 3.2, 0, 4, 3.5, 2, "top" } }),
	def("counter_till", "furniture", 4, 2, 4.5, false, { WOOD, { "top", "timber_light" } }, 450, "Counter with till", {
		{ 0, 0, 0, 4, 3.2, 2, "wood" }, { 0, 3.2, 0, 4, 3.5, 2, "top" }, { 2.6, 3.5, 0.6, 3.6, 4.5, 1.6, "brass" },
	}),
	def("display_case", "furniture", 4, 2, 3.5, false, { WOOD }, 400, "Display case", { { 0, 0, 0, 4, 2.6, 2, "wood" }, { 0, 2.6, 0, 4, 3.5, 2, "glass" } }),
	def("shelving", "furniture", 4, 1.5, 8, false, { WOOD }, 300, "Shelving", { { 0, 0, 1.2, 4, 8, 1.5, "wood" }, { 0, 0, 0, 4, 0.3, 1.5, "wood" }, { 0, 3, 0, 4, 3.3, 1.5, "wood" }, { 0, 6, 0, 4, 6.3, 1.5, "wood" } }),
	def("barrel", "furniture", 2, 2, 3, false, { WOOD }, 200, "Barrel", { { 0, 0, 0, 2, 3, 2, "wood" } }),
	def("crate", "furniture", 2, 2, 2, false, { WOOD }, 24, "Crate", { { 0, 0, 0, 2, 2, 2, "wood" } }),
	def("flower_stand", "furniture", 4, 2, 3, false, { WOOD }, 600, "Flower stand", { { 0, 0, 0, 4, 1, 2, "wood" }, { 0, 1, 0.7, 4, 2, 2, "wood" }, { 0, 2, 1.4, 4, 3, 2, "flowers" } }),
}

-- Free and unlimited furniture (art/kit.md "Starter set"); the rest is bought and kept in storage.
local STARTER_FURNITURE = { bed_single = true, chair = true, table_small = true, washstand = true, rug = true, counter = true, shelving = true, crate = true }

Kit.PIECES = {} :: { [string]: Def }
Kit.ORDER = {} :: { string }
for _, d0 in LIST do
	if d0.class == "furniture" or d0.class == "rug" then
		d0.starter = STARTER_FURNITURE[d0.id] == true
	end
	Kit.PIECES[d0.id] = d0
	table.insert(Kit.ORDER, d0.id)
end
Kit.GROUPS = { "walls", "floors", "roofs", "trim", "outside", "furniture" }
Kit.EXTERIOR_WALLS = { wall_plain = true, wall_half = true, wall_sash = true, wall_sash_tall = true, wall_bay = true, wall_door = true, wall_shopfront = true, wall_arch = true }
Kit.ENTRANCES = { wall_door = true, wall_shopfront = true, wall_arch = true }

-- Colours of the fixed (non-slot) parts in shapes.
local FIXED = {
	glass = { "glass", 0.45 }, trunk = { "timber_dark", 0 }, fire = { "chimney_pot", 0 }, shade = { "stucco_cream", 0 },
	pot = { "brick_red", 0 }, basin = { "white_wash", 0 }, keys = { "white_wash", 0 }, brass = { "gilt", 0 },
	flowers = { "canvas_stripe_red", 0 },
}

local function isFurniture(d0: Def): boolean
	return d0.class == "furniture" or d0.class == "rug"
end

-- Rotation in degrees, clockwise from above.
local function degrees(d0: Def, r: number): number
	return if isFurniture(d0) then r * 15 else r * 90
end

-- Footprint extents of a rotated piece (studs): exact for quarter turns, the bounding box otherwise.
local function extents(d0: Def, r: number): (number, number)
	local deg = degrees(d0, r)
	if deg % 90 == 0 then
		if (deg // 90) % 2 == 0 then
			return d0.w, d0.d
		end
		return d0.d, d0.w
	end
	local a = math.rad(deg)
	local c, s = math.abs(math.cos(a)), math.abs(math.sin(a))
	return d0.w * c + d0.d * s, d0.w * s + d0.d * c
end

function Kit.footprint(p: Piece): (number, number, number, number)
	local d0 = Kit.PIECES[p.id]
	local w, dd = extents(d0, p.r)
	local x, z = p.x / 2, p.z / 2
	return x, z, x + w, z + dd
end

function Kit.base(d0: Def, y: number): number
	local b = d0.base or (if isFurniture(d0) then Kit.FLOOR else 0)
	return y * Kit.STOREY + b
end

function Kit.box(p: Piece): (number, number, number, number, number, number)
	local d0 = Kit.PIECES[p.id]
	local x0, z0, x1, z1 = Kit.footprint(p)
	local y0 = Kit.base(d0, p.y)
	return x0, y0, z0, x1, y0 + d0.h, z1
end

-- Pairs of classes that may overlap (art/kit.md "Classes"); chimneys stand in roofs.
local OVERLAP = {
	["wall|floor"] = true, ["floor|wall"] = true, ["wall|trim"] = true, ["trim|wall"] = true,
	["furniture|rug"] = true, ["rug|furniture"] = true,
}
local function mayOverlap(a: Def, b: Def): boolean
	if OVERLAP[a.class .. "|" .. b.class] then
		return true
	end
	return (a.id == "chimney" and b.class == "roof") or (b.id == "chimney" and a.class == "roof")
end

local function overlaps(p: Piece, q: Piece): boolean
	local ax0, ay0, az0, ax1, ay1, az1 = Kit.box(p)
	local bx0, by0, bz0, bx1, by1, bz1 = Kit.box(q)
	local t = Kit.TOLERANCE
	return ax0 < bx1 - t and bx0 < ax1 - t and ay0 < by1 - t and by0 < ay1 - t and az0 < bz1 - t and bz0 < az1 - t
end

local function isInt(n: any): boolean
	return type(n) == "number" and n % 1 == 0 and n == n
end

-- One placement against the rules (BUILDING §3, art/kit.md). ignoreKey: the piece being moved.
function Kit.check(build: Build, lot: Lot, p: Piece, ignoreKey: number?): (boolean, string?)
	local d0 = Kit.PIECES[p.id]
	if not d0 then
		return false, "That isn't part of the kit."
	end
	if not (isInt(p.x) and isInt(p.z) and isInt(p.y) and isInt(p.r) and isInt(p.c)) then
		return false, "Bad position."
	end
	if p.r < 0 or p.r > (if isFurniture(d0) then 23 else 3) then
		return false, "Bad rotation."
	end
	if p.c ~= 0 then
		local colour = Palette.at(p.c)
		local group = Palette.GROUPS[d0.slots[1][1]]
		if not colour or not group or not table.find(group, colour.id) then
			return false, "That colour isn't in the palette for this piece."
		end
	end
	local grid = Kit.GRID[d0.class]
	if p.x % grid ~= 0 or p.z % grid ~= 0 then
		return false, "Off the grid."
	end
	local top = if d0.class == "roof" then lot.storeys else lot.storeys - 1
	if p.y < (d0.minY or 0) or p.y > top then
		return false, if p.y > top then "Too high for this property." else "Not on this storey."
	end
	if d0.class == "outside" and p.y ~= 0 then
		return false, "Garden pieces go on the ground."
	end
	local x0, z0, x1, z1 = Kit.footprint(p)
	local t = Kit.TOLERANCE
	local front = if d0.front then -Kit.FRONT_OUT else 0
	if x0 < -t or x1 > lot.w + t or z0 < front - t or z1 > lot.d + t then
		return false, "Outside your plot."
	end
	local _, _, _, _, y1 = Kit.box(p)
	if y1 > lot.storeys * Kit.STOREY + Kit.ROOF_MAX + t then
		return false, "Too high for this property."
	end
	local count = 0
	local onFloor = p.y == 0 or not isFurniture(d0)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	for _, q in build.pieces do
		if q.k == ignoreKey then
			continue
		end
		count += 1
		local e = Kit.PIECES[q.id]
		if e and overlaps(p, q) and not mayOverlap(d0, e) then
			return false, "It overlaps the " .. string.lower(e.name) .. "."
		end
		if not onFloor and e and e.class == "floor" and q.y == p.y then
			local qx0, qz0, qx1, qz1 = Kit.footprint(q)
			onFloor = cx >= qx0 and cx <= qx1 and cz >= qz0 and cz <= qz1
		end
	end
	if not onFloor then
		return false, "It needs a floor under it."
	end
	if count + 1 > lot.budget then
		return false, string.format("That's the most this property can hold (%d pieces).", lot.budget)
	end
	return true
end

-- The street-front rule (BUILDING §3): ground-floor exterior walls along the whole street edge
-- (at most 1 stud uncovered, at the ends), at least one entrance among them, and a roof over the
-- street-front walls of the top storey.
function Kit.publishable(build: Build, lot: Lot): (boolean, string?)
	local spans: { { number } } = {}
	local entrance = false
	local topY = -1
	for _, q in build.pieces do
		local e = Kit.PIECES[q.id]
		if e and e.class == "wall" then
			topY = math.max(topY, q.y)
		end
	end
	for _, q in build.pieces do
		if Kit.EXTERIOR_WALLS[q.id] and q.y == 0 and (q.r == 0 or q.r == 2) then
			local x0, z0, x1 = Kit.footprint(q)
			if math.abs(z0) < Kit.TOLERANCE then
				table.insert(spans, { x0, x1 })
				entrance = entrance or Kit.ENTRANCES[q.id] == true
			end
		end
	end
	table.sort(spans, function(a, b)
		return a[1] < b[1]
	end)
	local covered, reach, start = 0, nil :: number?, nil :: number?
	for _, s in spans do
		if reach and s[1] > reach + Kit.TOLERANCE then
			return false, string.format("The street front has a gap at %g–%g studs.", reach, s[1])
		end
		start = start or s[1]
		reach = math.max(reach or s[2], s[2])
	end
	if start and reach then
		covered = reach - start
	end
	if covered < lot.w - 1 - Kit.TOLERANCE then
		return false, "Build walls along the whole street front."
	end
	if not entrance then
		return false, "The street front needs a door."
	end
	-- every street-front wall bay of the top storey needs a roof piece above it (narrow walls
	-- are let off: a 2-stud gap in a roof line is only cosmetic)
	for _, q in build.pieces do
		local e = Kit.PIECES[q.id]
		local x0, z0, x1 = 0, 1, 0
		if e then
			x0, z0, x1 = Kit.footprint(q)
		end
		if e and e.class == "wall" and q.id ~= "wall_half" and q.y == topY and math.abs(z0) < Kit.TOLERANCE then
			local roofed = false
			for _, rf in build.pieces do
				local re = Kit.PIECES[rf.id]
				if re and re.class == "roof" and rf.id ~= "chimney" and rf.y == topY + 1 then
					local rx0, rz0, rx1 = Kit.footprint(rf)
					if rx0 < x1 - Kit.TOLERANCE and x0 < rx1 - Kit.TOLERANCE and rz0 <= 1 then
						roofed = true
						break
					end
				end
			end
			if not roofed then
				return false, "Put a roof over the top storey."
			end
		end
	end
	return true
end

-- Geometry -----------------------------------------------------------------------------------
-- The lot frame from the attributes LondonServer.Lots puts on each plot part.
function Kit.lotFrame(plot: Instance): Frame?
	local o, r, i = plot:GetAttribute("LotOrigin"), plot:GetAttribute("LotRight"), plot:GetAttribute("LotIn")
	if typeof(o) ~= "Vector3" or typeof(r) ~= "Vector3" or typeof(i) ~= "Vector3" then
		return nil
	end
	return { origin = o, right = r, inward = i }
end

function Kit.toWorld(f: Frame, x: number, y: number, z: number): Vector3
	return f.origin + f.right * x + Vector3.yAxis * y + f.inward * z
end

-- A part CFrame at lot point (x, y, z), its axes along the lot (X = right, Z = toward the street),
-- turned clockwise from above by deg.
function Kit.frameAt(f: Frame, x: number, y: number, z: number, deg: number): CFrame
	return CFrame.fromMatrix(Kit.toWorld(f, x, y, z), f.right, Vector3.yAxis) * CFrame.Angles(0, -math.rad(deg), 0)
end

local function slotColour(d0: Def, p: Piece, slot: string): (Color3, Enum.Material, number)
	local fixed = FIXED[slot]
	if fixed then
		local c = Palette.get(fixed[1])
		return Palette.color(fixed[1]), if c then c.material else Enum.Material.SmoothPlastic, fixed[2]
	end
	local id: string? = nil
	for k, s in d0.slots do
		if s[1] == slot then
			id = s[2]
			if k == 1 and p.c ~= 0 then
				local chosen = Palette.at(p.c)
				id = if chosen then chosen.id else id
			end
		end
	end
	local c = Palette.get(id or "white_wash")
	return if c then c.color else Color3.new(1, 0, 1), if c then c.material else Enum.Material.SmoothPlastic, 0
end

-- Greybox parts for one piece. opts.ghost: see-through, no collisions, doors, seats or lights.
-- Door leaves get the Doors module's tag and attributes (DoorGroup = opts.doorGroup .. k,
-- DoorLot = opts.doorLot).
function Kit.makePiece(p: Piece, f: Frame, opts: { [string]: any }?): Model
	local o = opts or {}
	local d0 = Kit.PIECES[p.id]
	local model = Instance.new("Model")
	model.Name = tostring(p.k)
	model:SetAttribute("Piece", p.id)
	local deg = degrees(d0, p.r)
	local a = math.rad(deg)
	local cosA, sinA = math.cos(a), math.sin(a)
	local x0, z0, x1, z1 = Kit.footprint(p)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local yBase = Kit.base(d0, p.y)
	for n, b in d0.shape do
		local bx0, by0, bz0, bx1, by1, bz1 = b[1] :: number, b[2] :: number, b[3] :: number, b[4] :: number, b[5] :: number, b[6] :: number
		local slot, flag = b[7] :: string, b[8] :: string?
		-- box centre relative to the footprint centre at r = 0, then turned clockwise by deg
		local du, dv = (bx0 + bx1) / 2 - d0.w / 2, (bz0 + bz1) / 2 - d0.d / 2
		local ru, rv = du * cosA + dv * sinA, -du * sinA + dv * cosA
		local wedge = flag == "wedge"
		local part: BasePart = Instance.new(if wedge then "WedgePart" elseif flag == "seat" and not o.ghost then "Seat" else "Part") :: any
		part.Name = slot .. n
		part.Anchored = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Size = Vector3.new(bx1 - bx0, by1 - by0, bz1 - bz0)
		local cf = Kit.frameAt(f, cx + ru, yBase + (by0 + by1) / 2, cz + rv, deg)
		part.CFrame = if wedge then cf * CFrame.Angles(0, math.pi, 0) elseif flag == "seat" then cf * CFrame.Angles(0, math.pi, 0) else cf
		local colour, material, transparency = slotColour(d0, p, slot)
		part.Color = colour
		part.Material = material
		part.Transparency = if flag == "bars" then 0.55 else transparency
		part.CanCollide = flag ~= "soft" and not o.ghost
		part.CastShadow = transparency == 0
		if o.ghost then
			part.Transparency = math.max(part.Transparency, 0.5)
			part.CanQuery = false
			part.CanTouch = false
		elseif flag == "door" then
			-- hinge on the leaf's left edge (piece space), swinging inward (Doors: +deg about +Y)
			local hu, hv = bx0 - d0.w / 2, (bz0 + bz1) / 2 - d0.d / 2
			local hru, hrv = hu * cosA + hv * sinA, -hu * sinA + hv * cosA
			part:SetAttribute("DoorHinge", Kit.toWorld(f, cx + hru, yBase + by0, cz + hrv))
			part:SetAttribute("DoorOpenDeg", 90)
			part:SetAttribute("DoorGroup", (o.doorGroup or "kit:") .. p.k)
			if o.doorLot then
				part:SetAttribute("DoorLot", o.doorLot)
			end
			part:AddTag(Config.DOOR_TAG)
		elseif flag == "light" then
			local light = Instance.new("PointLight")
			light.Range = if p.id == "chandelier" then 18 else 12
			light.Brightness = 1.2
			light.Color = Color3.fromRGB(255, 196, 120)
			light.Shadows = false
			light.Parent = part
			part.Material = Enum.Material.Neon
		end
		part.Parent = model
	end
	return model
end

-- Starter layouts (BUILDING §4 "templates"): a plain house of `storeys` floors, 16 studs deep,
-- with a door, windows, floors, stairs, a pitched roof, chimneys and a few starter furnishings.
-- variant 1-3 puts the door in the first, middle or last bay. The house is as wide as the
-- frontage allows within `budget` pieces; any frontage left over gets a ground-floor wall.
Kit.STARTER_STOREYS = { lodging = 2, terrace = 2, townhouse = 3, shop = 2, workshop = 1, warehouse = 2 }

local function layout(kind: string, w: number, d: number, variant: number, bays: number): { Piece }
	local pieces: { Piece } = {}
	local key = 0
	local function add(id: string, x: number, z: number, y: number, r: number)
		key += 1
		table.insert(pieces, { id = id, x = math.floor(x * 2 + 0.5), z = math.floor(z * 2 + 0.5), y = y, r = r, c = 0, k = key })
	end
	local storeys = Kit.STARTER_STOREYS[kind] or 2
	local W = bays * 4
	local D = math.max(8, math.min(16, 4 * math.floor((d - 2) / 4)))
	local doorBay = if variant == 2 then bays // 2 elseif variant == 3 then bays - 1 else 0
	local shop = kind == "shop"
	for y = 0, storeys - 1 do
		for i = 0, bays - 1 do
			local id = "wall_sash"
			if y == 0 and i == doorBay then
				id = "wall_door"
			elseif y == 0 and shop then
				id = "wall_shopfront"
			elseif y == 1 and kind == "townhouse" then
				id = "wall_sash_tall"
			end
			add(id, i * 4, 0, y, 0)
			add(if y == 0 and i == doorBay then "wall_door" else "wall_plain", i * 4, D - 1, y, 2)
		end
		-- side walls between the front and back walls: whole bays, then a narrow one
		local z = 1
		while z + 4 <= D - 1 do
			add("wall_plain", 0, z, y, 1)
			add("wall_plain", W - 1, z, y, 1)
			z += 4
		end
		if z < D - 1 then
			add("wall_half", 0, z, y, 1)
			add("wall_half", W - 1, z, y, 1)
		end
		-- floors, leaving the stairwell open (stairs climb from this storey and from the one below)
		local stairX = if y % 2 == 0 then 4 else 8
		local belowX = if y % 2 == 0 then 8 else 4
		for tx = 0, W - 4, 4 do
			for tz = 0, D - 4, 4 do
				local inStairs = y < storeys - 1 and tx == stairX and tz >= 4 and tz < 12 and D >= 12
				local inWell = y > 0 and tx == belowX and tz >= 4 and tz < 12 and D >= 12
				if not inStairs and not inWell then
					add("floor_boards", tx, tz, y, 0)
				end
			end
		end
		if y < storeys - 1 and D >= 12 and W >= 12 then
			add("stairs", stairX, 4, y, 0)
		end
	end
	-- frontage beyond the house: ground-floor walls (whole bays, then a narrow one)
	local x = W
	while x + 4 <= w do
		add("wall_plain", x, 0, 0, 0)
		x += 4
	end
	if w - x >= 2 then
		add("wall_half", x, 0, 0, 0)
	end
	-- roof: pairs of pitches meet at a ridge; what's left is flat
	local z = 0
	while z < D do
		local left = D - z
		for i = 0, bays - 1 do
			if left >= 16 then
				add("roof_pitch", i * 4, z, storeys, 0)
				add("roof_pitch", i * 4, z + 8, storeys, 2)
			elseif left >= 8 then
				add("roof_pitch", i * 4, z, storeys, 0)
			else
				add("roof_flat", i * 4, z, storeys, 0)
			end
		end
		z += if left >= 16 then 16 elseif left >= 8 then 8 else 4
	end
	add("chimney", 0, 6, storeys, 0)
	if bays >= 4 then
		add("chimney", W - 2, 6, storeys, 0)
	end
	-- a few starter furnishings, clear of the stairs (x 4-12, z 4-12)
	local top = storeys - 1
	if W >= 16 and D >= 16 then
		add("bed_single", W - 4.5, D - 7.5, top, 0)
		add("washstand", 1.5, D - 3, top, 0)
		add("table_small", W - 5, 2, 0, 0)
		add("chair", W - 6.5, 2.5, 0, 6)
		if shop then
			add("counter", W - 6, 6, 0, 0)
		else
			add("rug", W - 7, 1.5, 0, 0)
		end
	end
	return pieces
end

function Kit.starter(kind: string, w: number, d: number, variant: number, budget: number?): { Piece }
	local most = budget or math.huge
	local bays = math.max(2, math.floor(w / 4))
	while bays > 2 do
		local pieces = layout(kind, w, d, variant, bays)
		if #pieces <= most then
			return pieces
		end
		bays -= 1
	end
	return layout(kind, w, d, variant, bays)
end

return Kit
