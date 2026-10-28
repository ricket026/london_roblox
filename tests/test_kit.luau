-- Shared.Kit against its contract (art/kit.md) and the building rules (BUILDING §3).
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)

-- art/kit.md piece tables: | `id` | class | w | d | h | front | colour slots | tris | what |
local function contract()
	local rows = {}
	for line in string.gmatch(__readText("art/kit.md"), "[^\n]+") do
		local id, rest = string.match(line, "^| `([%w_]+)` | (.*)$")
		if id and not string.find(line, "^| `[%w_]+` | [%w_]+ |%s*%d") == false then
			local cells = {}
			for cell in string.gmatch(rest, "([^|]*)|") do
				table.insert(cells, (string.gsub(cell, "^%s*(.-)%s*$", "%1")))
			end
			if #cells >= 7 and tonumber(cells[2]) then
				table.insert(rows, { id = id, class = cells[1], w = tonumber(cells[2]), d = tonumber(cells[3]), h = tonumber(cells[4]), front = cells[5] == "yes", slots = cells[6], tris = tonumber(cells[7]) })
			end
		end
	end
	return rows
end

test("every piece matches art/kit.md, in the same order", function()
	local rows = contract()
	eq(#rows, #Kit.ORDER, "piece count")
	for k, row in rows do
		local d = Kit.PIECES[row.id]
		ok(d ~= nil, "missing in Kit: " .. row.id)
		eq(Kit.ORDER[k], row.id, "order")
		eq(d.class, row.class, row.id .. " class")
		eq(d.w, row.w, row.id .. " w")
		eq(d.d, row.d, row.id .. " d")
		eq(d.h, row.h, row.id .. " h")
		eq(d.front, row.front, row.id .. " front")
		eq(d.tris, row.tris, row.id .. " tris")
		-- slots: names in order; a default given in the table must match
		local k2 = 0
		for item in string.gmatch(row.slots .. ",", "%s*([^,]+),") do
			k2 += 1
			local name, default = string.match(item, "^(%w+) %(`([%w_]+)`%)$")
			name = name or string.match(item, "^(%w+)$")
			ok(d.slots[k2] ~= nil, row.id .. " has fewer slots than the table")
			eq(d.slots[k2][1], name, row.id .. " slot " .. k2)
			if default then
				eq(d.slots[k2][2], default, row.id .. " default for " .. name)
			end
		end
		eq(#d.slots, k2, row.id .. " slot count")
	end
end)

test("palette ids exist for every slot default and match style.md", function()
	for _, id in Kit.ORDER do
		for _, s in Kit.PIECES[id].slots do
			ok(Palette.get(s[2]) ~= nil, id .. " default " .. s[2])
			ok(Palette.GROUPS[s[1]] ~= nil, id .. " slot group " .. s[1])
		end
	end
	local md = __readText("art/style.md")
	local n = 0
	for id, r, g, b in string.gmatch(md, "| `([%w_]+)` | (%d+), (%d+), (%d+) |") do
		n += 1
		local c = Palette.get(id)
		ok(c ~= nil, "style.md colour missing in Palette: " .. id)
		eq(c.rgb[1] .. "," .. c.rgb[2] .. "," .. c.rgb[3], r .. "," .. g .. "," .. b, id)
	end
	ok(n >= 40, "read the palette table")
end)

test("every shape box stays near its footprint and has a known colour", function()
	for _, id in Kit.ORDER do
		local d = Kit.PIECES[id]
		ok(#d.shape >= 1 and #d.shape <= 6, id .. " greybox parts")
		for _, b in d.shape do
			ok(b[4] > b[1] and b[5] > b[2] and b[6] > b[3], id .. " box has size")
			ok(b[2] >= 0 and b[5] <= d.h + 0.001, id .. " box within height")
			local out = if d.front then 2 else 0.5
			ok(b[3] >= -out - 0.001 and b[6] <= d.d + 0.5, id .. " box depth")
		end
	end
end)

local function lotFor(kind, w, d)
	local k = Config.PROPERTY_KINDS[kind]
	return { w = w, d = d, storeys = k.storeys, budget = k.budget }
end
local function empty(kind)
	return { v = 1, kind = kind, w = 26, d = 43, pieces = {}, nextKey = 1, published = false }
end
local function piece(id, xs, zs, y, r, k)
	return { id = id, x = xs * 2, z = zs * 2, y = y or 0, r = r or 0, c = 0, k = k or 1 }
end

test("starter houses obey every rule and can be published, for every kind and lot size", function()
	for _, kind in Config.PROPERTY_ORDER do
		for _, size in { { 14, 14 }, { 22, 35 }, { 25, 37 }, { 26, 43 }, { 29, 43 }, { 30, 46 }, { 44, 58 } } do
			for variant = 1, 3 do
				local lot = lotFor(kind, size[1], size[2])
				local build = empty(kind)
				for _, p in Kit.starter(kind, size[1], size[2], variant, lot.budget) do
					local good, why = Kit.check(build, lot, p)
					ok(good, string.format("%s %dx%d v%d: %s at %g,%g y%d: %s", kind, size[1], size[2], variant, p.id, p.x / 2, p.z / 2, p.y, tostring(why)))
					table.insert(build.pieces, p)
				end
				local good, why = Kit.publishable(build, lot)
				ok(good, string.format("%s %dx%d v%d not publishable: %s", kind, size[1], size[2], variant, tostring(why)))
			end
		end
	end
end)

test("placement rules", function()
	local lot = lotFor("terrace", 26, 43)
	local b = empty("terrace")
	ok(Kit.check(b, lot, piece("wall_plain", 0, 0)))
	local function no(p, pattern, msg)
		local good, why = Kit.check(b, lot, p)
		eq(good, false, msg)
		ok(string.find(why or "", pattern), msg .. ": " .. tostring(why))
	end
	no(piece("wall_plain", 23, 0), "Outside", "past the side of the plot")
	no(piece("wall_plain", 0, -1), "Outside", "walls can't stand in front of the street edge")
	ok(Kit.check(b, lot, piece("steps", 0, -2)), "front pieces may stand 2 studs out")
	no(piece("steps", 0, -4), "Outside", "but not further")
	no(piece("wall_plain", 0, 0, 3), "Too high", "a terrace has 3 storeys")
	ok(Kit.check(b, lot, piece("roof_pitch", 0, 0, 3)), "roofs go on the storey above the top")
	no(piece("lawn", 0, 20, 1), "ground", "garden pieces only on the ground")
	no(piece("floor_boards", 1, 0), "grid", "floors on the 2-stud grid")
	ok(Kit.check(b, lot, piece("wall_plain", 1, 4, 0, 1)), "walls on a 1-stud grid")
	no(piece("balcony", 0, -2, 0), "storey", "balconies from the first floor up")
	no({ id = "chair", x = 3, z = 10, y = 0, r = 24, c = 0, k = 1 }, "rotation", "furniture turns 0-23")
	no({ id = "wall_plain", x = 0, z = 0, y = 0, r = 0, c = Palette.index("door_green"), k = 1 }, "colour", "a door colour isn't a wall face colour")
	ok(Kit.check(b, lot, { id = "wall_plain", x = 0, z = 0, y = 0, r = 0, c = Palette.index("stucco_white"), k = 9 }), "stucco is")
	no({ id = "nope", x = 0, z = 0, y = 0, r = 0, c = 0, k = 1 }, "kit", "unknown pieces")

	table.insert(b.pieces, piece("wall_plain", 0, 0, 0, 0, 1))
	no(piece("wall_sash", 2, 0, 0, 0, 2), "overlaps the plain wall", "walls don't overlap walls")
	ok(Kit.check(b, lot, piece("floor_boards", 0, 0, 0, 0, 2)), "floors may overlap walls")
	ok(Kit.check(b, lot, piece("cornice", 0, 0, 0, 0, 2)), "trim may overlap walls")
	ok(Kit.check(b, lot, piece("wall_sash", 2, 0, 0, 0, 1), 1), "moving a piece ignores itself")
	no(piece("bed_single", 4, 4, 1, 0, 3), "floor under", "furniture upstairs needs a floor")
	table.insert(b.pieces, piece("floor_boards", 4, 4, 1, 0, 4))
	ok(Kit.check(b, lot, piece("chair", 5, 5, 1, 0, 5)), "now it has one")
	table.insert(b.pieces, piece("rug", 4, 4, 1, 0, 6))
	ok(Kit.check(b, lot, piece("chair", 5, 5, 1, 0, 5)), "furniture may stand on a rug")
	table.insert(b.pieces, piece("chair", 5, 5, 1, 0, 7))
	no(piece("table_small", 5, 5, 1, 0, 8), "overlaps the chair", "furniture doesn't overlap furniture")

	-- stairs keep their well clear on the storey above
	table.insert(b.pieces, piece("stairs", 12, 8, 0, 0, 9))
	no(piece("floor_boards", 12, 8, 1, 0, 10), "overlaps the stairs", "no floor over the stairwell")
	ok(Kit.check(b, lot, piece("floor_boards", 16, 8, 1, 0, 10)), "next to it is fine")

	-- chimneys stand in roofs; roofs don't overlap roofs
	table.insert(b.pieces, piece("roof_pitch", 0, 0, 3, 0, 11))
	ok(Kit.check(b, lot, piece("chimney", 0, 2, 3, 0, 12)))
	no(piece("roof_flat", 0, 0, 3, 0, 12), "overlaps the pitched roof", "roof on roof")
end)

test("the budget is the most pieces a property can hold", function()
	local lot = { w = 40, d = 40, storeys = 1, budget = 3 }
	local b = empty("lodging")
	for k = 1, 3 do
		local p = piece("floor_boards", (k - 1) * 4, 0, 0, 0, k)
		ok(Kit.check(b, lot, p))
		table.insert(b.pieces, p)
	end
	local good, why = Kit.check(b, lot, piece("floor_boards", 20, 0, 0, 0, 4))
	eq(good, false)
	ok(string.find(why, "most"), why)
	ok(Kit.check(b, lot, piece("floor_boards", 20, 0, 0, 0, 1), 1), "moving one still fits")
end)

test("publishing needs a whole street front, a door and a roof", function()
	local lot = lotFor("terrace", 26, 43)
	local b = empty("terrace")
	b.pieces = Kit.starter("terrace", 26, 43, 1)
	ok(Kit.publishable(b, lot))
	local function without(pred)
		local c = table.clone(b)
		c.pieces = {}
		for _, p in b.pieces do
			if not pred(p) then
				table.insert(c.pieces, p)
			end
		end
		return c
	end
	local gap = without(function(p)
		return p.y == 0 and p.z == 0 and p.x == 8 and p.id == "wall_sash"
	end)
	local good, why = Kit.publishable(gap, lot)
	eq(good, false)
	ok(string.find(why, "gap"), why)
	good, why = Kit.publishable(without(function(p)
		return p.id == "wall_door" and p.z == 0
	end), lot)
	eq(good, false)
	ok(string.find(why or "", "street front"), tostring(why))
	good, why = Kit.publishable(without(function(p)
		return p.id == "roof_pitch"
	end), lot)
	eq(good, false)
	ok(string.find(why, "roof"), why)
end)

test("footprints turn with the piece", function()
	local x0, z0, x1, z1 = Kit.footprint(piece("wall_plain", 0, 1, 0, 1))
	eq(x1 - x0, 1)
	eq(z1 - z0, 4)
	eq(z0, 1)
	x0, z0, x1, z1 = Kit.footprint({ id = "sofa", x = 0, z = 0, y = 0, r = 3, c = 0, k = 1 }) -- 45°
	near(x1 - x0, (6 + 2.5) * math.sqrt(0.5), 1e-6)
	near(z1 - z0, (6 + 2.5) * math.sqrt(0.5), 1e-6)
	local _, y0, _, _, y1 = Kit.box(piece("chandelier", 0, 0, 1))
	eq(y1, 24, "a chandelier hangs from the ceiling")
	_, y0 = Kit.box(piece("chair", 0, 0, 1))
	eq(y0, 12 + Kit.FLOOR, "furniture stands on the floor")
end)

-- a plot whose street is on its -Z side: street-left corner at (maxX, top, minZ)
local FRAME = { origin = Vector3.new(100, 0.6, 50), right = Vector3.new(-1, 0, 0), inward = Vector3.new(0, 0, 1) }

test("pieces land in the right place in the world", function()
	local m = Kit.makePiece(piece("wall_plain", 0, 0, 0, 0, 7), FRAME)
	eq(m.Name, "7")
	local wall = m:GetChildren()[1]
	ok((wall.Position - Vector3.new(98, 6.6, 50.5)).Magnitude < 1e-6, tostring(wall.Position))
	eq(wall.Size, Vector3.new(4, 12, 1))
	-- a side wall (r = 1) runs into the plot
	local side = Kit.makePiece(piece("wall_plain", 0, 1, 0, 1, 8), FRAME):GetChildren()[1]
	ok((side.Position - Vector3.new(99.5, 6.6, 53)).Magnitude < 1e-6, tostring(side.Position))
	ok(math.abs(side.CFrame.RightVector:Dot(FRAME.inward)) > 0.999, "its length runs into the plot")
	-- upstairs
	local up = Kit.makePiece(piece("floor_boards", 4, 4, 2, 0, 9), FRAME):GetChildren()[1]
	ok((up.Position - Vector3.new(94, 0.6 + 24.2, 56)).Magnitude < 1e-6, tostring(up.Position))
end)

test("roofs and stairs rise inward; seats face the street; doors swing inward", function()
	local roof = Kit.makePiece(piece("roof_pitch", 0, 0, 1), FRAME):GetChildren()[1]
	eq(roof.ClassName, "WedgePart")
	ok(roof.CFrame.ZVector:Dot(FRAME.inward) > 0.999, "a wedge is tall at its +Z: the back of the house")
	local back = Kit.makePiece(piece("roof_pitch", 0, 8, 1, 2), FRAME):GetChildren()[1]
	ok(back.CFrame.ZVector:Dot(FRAME.inward) < -0.999, "the back pitch rises toward the street: a ridge")
	local seat = Kit.makePiece(piece("chair", 0, 0, 0), FRAME):FindFirstChildWhichIsA("Seat")
	ok(seat ~= nil, "chairs are seats")
	ok(seat.CFrame.LookVector:Dot(FRAME.inward) < -0.999, "a chair at r = 0 faces the street")
	local door
	for _, p in Kit.makePiece(piece("wall_door", 0, 0, 0, 0, 3), FRAME, { doorGroup = "test:", doorLot = "Lot_1" }):GetChildren() do
		if p:GetAttribute("DoorHinge") then
			door = p
		end
	end
	ok(door ~= nil, "the door leaf is tagged for Doors")
	ok(door:HasTag(Config.DOOR_TAG))
	eq(door:GetAttribute("DoorGroup"), "test:3")
	eq(door:GetAttribute("DoorLot"), "Lot_1")
	local hinge = door:GetAttribute("DoorHinge")
	ok((hinge - Vector3.new(99.5, 0.6, 50.5)).Magnitude < 1e-6, "hinged on its left edge, seen from the street: " .. tostring(hinge))
	-- Doors opens with pivot * Angles(0, deg) * pivot:Inverse() * closed
	local pivot = CFrame.new(hinge)
	local open = pivot * CFrame.Angles(0, math.rad(door:GetAttribute("DoorOpenDeg")), 0) * pivot:Inverse() * door.CFrame
	ok((open.Position - door.Position):Dot(FRAME.inward) > 1, "it swings into the house")
	-- a quarter turn clockwise (seen from above): the chair that faced the street (-z) now faces
	-- -x, and its backrest (at +z) moves to +x
	local turned = Kit.makePiece({ id = "chair", x = 20, z = 20, y = 0, r = 6, c = 0, k = 4 }, FRAME)
	local s2 = turned:FindFirstChildWhichIsA("Seat")
	ok(s2.CFrame.LookVector:Dot(FRAME.right) < -0.999, "turned chair faces -x")
	local backrest
	for _, p in turned:GetChildren() do
		if not p:IsA("Seat") then
			backrest = p
		end
	end
	local rel = backrest.Position - s2.Position
	ok(rel:Dot(FRAME.right) > 0.3, "backrest on the +x side: " .. tostring(rel))
	ok(math.abs(rel:Dot(FRAME.inward)) < 1e-6, "and level with the seat in z")
	local ghost = Kit.makePiece(piece("wall_door", 0, 0, 0, 0, 3), FRAME, { ghost = true })
	for _, p in ghost:GetChildren() do
		eq(p.CanCollide, false)
		eq(p:GetAttribute("DoorHinge"), nil, "ghosts have no working doors")
	end
end)
