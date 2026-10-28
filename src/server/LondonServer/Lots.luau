--!strict
-- LondonServer.Lots: the building plots (Workspace.Map.Plots, made by MapGreybox) for property.
-- For each plot it works out once which side faces the street (the frontage side nearest a road
-- in ServerStorage.MapLayoutData), sets the lot-space attributes Shared.Kit reads (LotOrigin,
-- LotRight, LotIn, LotW, LotD) and an address (LotAddress: "No. 14, Berkeley Square"), keeps
-- track of which plots are taken in this server, and shows a template house on every plot that
-- has no player build (BUILDING §6; Config.LOT_TEMPLATES).
--   Lots.get(name) -> Lot?         Lots.kindOf(name) -> kind?      Lots.all() -> { Lot }
--   Lots.claim(name, userId, deedId) -> bool   Lots.release(name)   Lots.claimOf(name) -> claim?
--   Lots.choose(kind, preferred?, near?) -> name?       (PROPERTY §4 order)
--   Lots.toLot(name, worldPos) -> x, y, z (studs)       Lots.inside(name, worldPos, margin?) -> bool
--   Lots.showTemplate(name) / Lots.hideTemplate(name)
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Kit = require(Shared:WaitForChild("Kit"))
local Palette = require(Shared:WaitForChild("Palette"))
local World = require(script.Parent:WaitForChild("World"))

local Lots = {}

export type Lot = {
	name: string, id: number, part: BasePart, lotType: string, kind: string?, district: string,
	w: number, d: number, frame: Kit.Frame, street: string, centre: Vector3,
}
type Claim = { userId: number, deedId: string }

local lots: { [string]: Lot } = {}
local order: { string } = {}
local claims: { [string]: Claim } = {}
local templates: { [string]: Model } = {}
local kindByType: { [string]: string } = {}
local templateFolder: Folder? = nil

-- Roads from the map layout (centre lines + class widths), in a coarse grid for nearest lookups.
type Seg = { ax: number, az: number, bx: number, bz: number, half: number, name: string }
local CELL = 128
local grid: { [number]: { Seg } } = {}
local haveRoads = false

local function cellKey(cx: number, cz: number): number
	return cx * 100000 + cz
end

local function loadRoads()
	local mod = ServerStorage:FindFirstChild("MapLayoutData")
	if not mod or not mod:IsA("ModuleScript") then
		warn("[Lots] ServerStorage.MapLayoutData not found: every plot faces -Z")
		return
	end
	local okJson, data = pcall(function()
		local json: any = require(mod)
		return HttpService:JSONDecode(json)
	end)
	if not okJson or type(data) ~= "table" or type(data.roads) ~= "table" then
		warn("[Lots] couldn't read MapLayoutData: " .. tostring(data))
		return
	end
	for _, r in data.roads do
		local cls = data.classes[r.c]
		local half = if cls then cls.w / 2 else 6
		for s = 1, #r.p - 1 do
			local a, b = r.p[s], r.p[s + 1]
			local seg: Seg = { ax = a[1], az = a[2], bx = b[1], bz = b[2], half = half, name = r.n }
			local pad = half + 60
			for cx = math.floor((math.min(a[1], b[1]) - pad) / CELL), math.floor((math.max(a[1], b[1]) + pad) / CELL) do
				for cz = math.floor((math.min(a[2], b[2]) - pad) / CELL), math.floor((math.max(a[2], b[2]) + pad) / CELL) do
					local k = cellKey(cx, cz)
					local list = grid[k] or {}
					grid[k] = list
					table.insert(list, seg)
				end
			end
		end
	end
	haveRoads = true
end

local function segDist(px: number, pz: number, s: Seg): number
	local dx, dz = s.bx - s.ax, s.bz - s.az
	local len2 = dx * dx + dz * dz
	local t = if len2 == 0 then 0 else math.clamp(((px - s.ax) * dx + (pz - s.az) * dz) / len2, 0, 1)
	local qx, qz = s.ax + t * dx - px, s.az + t * dz - pz
	return math.sqrt(qx * qx + qz * qz) - s.half
end

-- Distance from a point to the nearest road edge, and that road's name.
local function nearestRoad(x: number, z: number): (number, string)
	local best, name = math.huge, ""
	for _, s in grid[cellKey(math.floor(x / CELL), math.floor(z / CELL))] or {} do
		local d = segDist(x, z, s)
		if d < best then
			best, name = d, s.name
		end
	end
	return best, name
end

local function kindFor(lotType: string): string?
	return kindByType[lotType]
end

-- Works out a plot's street side and frame, and stamps the attributes on the part.
local function describe(part: BasePart): Lot?
	local id = part:GetAttribute("LotId")
	if type(id) ~= "number" then
		return nil
	end
	local frontage = part:GetAttribute("Frontage")
	local cf, size = part.CFrame, part.Size
	local axX, axZ = cf.RightVector, -cf.LookVector -- the part's local +X and +Z in the world
	local fx = if type(frontage) == "number" then frontage else size.X
	-- the frontage runs along whichever local axis matches its length; the street is on one of
	-- the two long sides across from it
	local along, across, alongLen, acrossLen
	if math.abs(size.X - fx) <= math.abs(size.Z - fx) then
		along, across, alongLen, acrossLen = axX, axZ, size.X, size.Z
	else
		along, across, alongLen, acrossLen = axZ, axX, size.Z, size.X
	end
	local centre = cf.Position
	local out = across -- outward normal of the street side
	local street = ""
	if haveRoads then
		local m1 = centre + across * (acrossLen / 2)
		local m2 = centre - across * (acrossLen / 2)
		local d1, n1 = nearestRoad(m1.X, m1.Z)
		local d2, n2 = nearestRoad(m2.X, m2.Z)
		if d2 < d1 then
			out, street = -across, n2
		else
			street = n1
		end
	else
		-- no road data: face -Z or -X, whichever side is across the frontage
		out = if across:Dot(Vector3.new(-1, 0, -1)) > 0 then across else -across
	end
	local inward = -out
	local right = inward:Cross(Vector3.yAxis).Unit
	local top = centre.Y + size.Y / 2
	local frontMid = Vector3.new(centre.X, top, centre.Z) + out * (acrossLen / 2)
	local origin = frontMid - right * (alongLen / 2)
	local w, d = math.floor(alongLen + 0.01), math.floor(acrossLen + 0.01)
	part:SetAttribute("LotOrigin", origin)
	part:SetAttribute("LotRight", right)
	part:SetAttribute("LotIn", inward)
	part:SetAttribute("LotW", w)
	part:SetAttribute("LotD", d)
	local lotType = part:GetAttribute("LotType")
	local district = part:GetAttribute("District")
	local lt = if type(lotType) == "string" then lotType else ""
	return {
		name = part.Name, id = id, part = part, lotType = lt, kind = kindFor(lt),
		district = if type(district) == "string" then district else "",
		w = w, d = d, frame = { origin = origin, right = right, inward = inward }, street = street, centre = centre,
	}
end

-- Numbers along each street, in order along its main axis.
local function numberStreets()
	local byStreet: { [string]: { Lot } } = {}
	for _, name in order do
		local l = lots[name]
		if l.street ~= "" then
			local list = byStreet[l.street] or {}
			byStreet[l.street] = list
			table.insert(list, l)
		end
	end
	for street, list in byStreet do
		local alongX = math.abs(list[1].frame.right.X) >= math.abs(list[1].frame.right.Z)
		table.sort(list, function(a, b)
			local ka = if alongX then a.centre.X else a.centre.Z
			local kb = if alongX then b.centre.X else b.centre.Z
			if ka ~= kb then
				return ka < kb
			end
			return a.id < b.id
		end)
		for k, l in list do
			l.part:SetAttribute("LotAddress", string.format("No. %d, %s", k, street))
		end
	end
end

function Lots.get(name: string): Lot?
	return lots[name]
end

function Lots.all(): { Lot }
	local out = {}
	for _, name in order do
		table.insert(out, lots[name])
	end
	return out
end

function Lots.kindOf(name: string): string?
	local l = lots[name]
	return if l then l.kind else nil
end

function Lots.address(name: string): string
	local l = lots[name]
	local a = l and l.part:GetAttribute("LotAddress")
	return if type(a) == "string" then a elseif l then l.district else ""
end

function Lots.claimOf(name: string): Claim?
	return claims[name]
end

function Lots.claim(name: string, userId: number, deedId: string): boolean
	local c = claims[name]
	if not lots[name] or (c and (c.userId ~= userId or c.deedId ~= deedId)) then
		return false
	end
	claims[name] = { userId = userId, deedId = deedId }
	lots[name].part:SetAttribute("LotOwner", userId)
	return true
end

function Lots.release(name: string)
	claims[name] = nil
	local l = lots[name]
	if l then
		l.part:SetAttribute("LotOwner", nil)
	end
end

function Lots.isFree(name: string): boolean
	return lots[name] ~= nil and claims[name] == nil
end

-- PROPERTY §4: the preferred plot if it's free; else the nearest free plot of the kind in the
-- preferred plot's district; else the free plot of the kind nearest to `near` (or to the
-- preferred plot); with neither, the first free one.
function Lots.choose(kind: string, preferred: string?, near: Vector3?): string?
	if preferred and Lots.isFree(preferred) and Lots.kindOf(preferred) == kind then
		return preferred
	end
	local pl = if preferred then lots[preferred] else nil
	local from = near or (if pl then pl.centre else nil)
	local district = if pl then pl.district else nil
	local bestIn, dIn, best, dAny = nil, math.huge, nil, math.huge
	for _, name in order do
		local l = lots[name]
		if l.kind == kind and claims[name] == nil then
			local dist = if from then (l.centre - from).Magnitude else l.id
			if district and l.district == district and dist < dIn then
				bestIn, dIn = name, dist
			end
			if dist < dAny then
				best, dAny = name, dist
			end
		end
	end
	return bestIn or best
end

function Lots.freeCount(kind: string): number
	local n = 0
	for _, name in order do
		if lots[name].kind == kind and claims[name] == nil then
			n += 1
		end
	end
	return n
end

-- World point -> lot space (studs).
function Lots.toLot(name: string, pos: Vector3): (number, number, number)
	local l = lots[name]
	if not l then
		return math.huge, math.huge, math.huge
	end
	local rel = pos - l.frame.origin
	return rel:Dot(l.frame.right), rel.Y, rel:Dot(l.frame.inward)
end

function Lots.inside(name: string, pos: Vector3, margin: number?): boolean
	local l = lots[name]
	if not l then
		return false
	end
	local m = margin or 0
	local x, y, z = Lots.toLot(name, pos)
	return x >= -m and x <= l.w + m and z >= -Kit.FRONT_OUT - m and z <= l.d + m and y > -10 and y < 80
end

-- Templates (BUILDING §6, art/kit.md): at most 8 parts, picked by LotId so neighbours differ.
local STOREYS = { Lodging = 2, Terrace = 3, Townhouse = 4, Shop = 3, Workshop = 2, Warehouse = 4 }
local FACES = {
	Townhouse = { "stucco_white", "stucco_cream", "stucco_white", "brick_stock" },
	Terrace = { "brick_stock", "brick_stock_sooted", "brick_red", "brick_stock" },
	Lodging = { "brick_stock_sooted", "render_grey", "brick_stock_sooted", "brick_red" },
	Shop = { "brick_red", "brick_stock", "stucco_cream", "brick_stock_sooted" },
	Workshop = { "brick_stock_sooted", "brick_red", "brick_stock_sooted" },
	Warehouse = { "brick_stock_sooted", "brick_blue", "brick_stock_sooted" },
	Office = { "stone_portland", "brick_red", "stone_sooted" },
	Club = { "stone_portland", "stucco_white" },
	Government = { "stone_portland", "stone_bath" },
}
local DOORS = { "door_black", "door_green", "door_oxblood", "door_navy" }

local function pick(list: { string }, n: number): string
	return list[(n % #list) + 1]
end

function Lots.buildTemplate(l: Lot): Model
	local model = Instance.new("Model")
	model.Name = l.name
	local f = l.frame
	local storeys = STOREYS[l.lotType] or 3
	local H = storeys * Kit.STOREY
	local W = l.w
	local D = math.max(8, math.min(l.d - 4, 18))
	local face = pick(FACES[l.lotType] or FACES.Terrace, l.id)
	local function box(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, colour: string, extra: { [string]: any }?): BasePart
		local cls = if extra and extra.ClassName then extra.ClassName else "Part"
		local p = World.part({ ClassName = cls, Name = name, Size = Vector3.new(x1 - x0, y1 - y0, z1 - z0) })
		p.CFrame = Kit.frameAt(f, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, 0)
		local c = Palette.get(colour)
		p.Color = Palette.color(colour)
		p.Material = if c then c.material else Enum.Material.SmoothPlastic
		local anyPart: any = p
		for k, v in extra or {} do
			if k ~= "ClassName" then
				anyPart[k] = v
			end
		end
		p.Parent = model
		return p
	end
	box("Body", 0, 0, 0, W, H, D, face)
	-- one window band per storey (shops: a shopfront band on the ground floor)
	for s = 0, storeys - 1 do
		local shopFloor = s == 0 and l.lotType == "Shop"
		local y0 = s * Kit.STOREY + (if shopFloor then 1.5 else 3)
		local y1 = s * Kit.STOREY + (if shopFloor then 8 else 9)
		box("Windows" .. s, 1, y0, -0.1, W - 1, y1, 0.05, "glass", { Transparency = 0.2, Material = Enum.Material.Glass })
	end
	local bays = math.max(1, math.floor(W / 4))
	local doorX = 4 * ((l.id * 7) % bays) + 0.5
	box("Door", doorX, 0, -0.15, doorX + 3, 8, 0.05, pick(DOORS, l.id * 3))
	if l.lotType == "Warehouse" or l.lotType == "Office" or l.lotType == "Government" then
		box("Roof", -0.3, H, -0.3, W + 0.3, H + 1, D + 0.3, "lead")
	else
		-- a single pitch rising from the street to the back of the house
		local roof = box("Roof", 0, H, 0, W, H + 6, D, "slate", { ClassName = "WedgePart" })
		roof.CFrame = roof.CFrame * CFrame.Angles(0, math.pi, 0)
	end
	local cx = if l.id % 2 == 0 then 1 else W - 3
	box("Chimney", cx, H, D - 4, cx + 2, H + 8, D - 2, face)
	return model
end

function Lots.showTemplate(name: string)
	local l = lots[name]
	if not l or templates[name] or not Config.LOT_TEMPLATES or not templateFolder then
		return
	end
	local m = Lots.buildTemplate(l)
	m.Parent = templateFolder
	templates[name] = m
end

function Lots.hideTemplate(name: string)
	local m = templates[name]
	if m then
		m:Destroy()
		templates[name] = nil
	end
end

function Lots.hasTemplate(name: string): boolean
	return templates[name] ~= nil
end

-- Reads every plot (no yielding: ~4,000 plots take a few milliseconds), then builds the
-- templates in the background, Config.LOT_TEMPLATE_BATCH plots per frame.
Lots.ready = false
function Lots.init()
	for kind, k in Config.PROPERTY_KINDS do
		kindByType[k.lotType] = kind
	end
	loadRoads()
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if not plots then
		if map then
			warn("[Lots] Workspace.Map.Plots not found: no property plots")
		else
			print("[Lots] no Workspace.Map in this place: no property plots")
		end
		Lots.ready = true
		return
	end
	templateFolder = World.folder("LotTemplates")
	for _, part in plots:GetChildren() do
		if part:IsA("BasePart") then
			local l = describe(part)
			if l then
				lots[l.name] = l
				table.insert(order, l.name)
			end
		end
	end
	table.sort(order, function(a, b)
		return lots[a].id < lots[b].id
	end)
	numberStreets()
	Lots.ready = true
	if Config.LOT_TEMPLATES then
		task.spawn(function()
			for k, name in order do
				if not claims[name] then
					Lots.showTemplate(name)
				end
				if k % Config.LOT_TEMPLATE_BATCH == 0 then
					task.wait()
				end
			end
		end)
	end
end

-- Waits (yielding) until the plots have been read.
function Lots.waitReady()
	while not Lots.ready do
		task.wait(0.1)
	end
end

return Lots
