--!strict
-- LondonServer.Lamps: gas lamps along every road (TASKS T04, JOBS §2 Lamplighter). Built at start
-- from the road centre lines in ServerStorage.MapLayoutData (Lots.roads()): one lamp every
-- Config.LAMP_SPACING studs, alternating sides, on the pavement by the kerb, none over water, on a
-- building plot, inside a landmark, or within Config.LAMP_MIN_GAP of another. Each lamp is a pole and a lantern in workspace.Lamps; the
-- lantern has tag "Lamp", attributes Route ("R12": lamps 12 to a route along their road), LampId
-- and Lit, and a PointLight.
-- From dusk the lamps want lighting and from dawn putting out: lamplighters do it (Jobs), and
-- whatever is left is done by the city's own lamplighters Config.LAMP_NPC_DELAY seconds into the
-- phase. A new server starts with every lamp as it should be.
--   Lamps.wanted() -> lit?   Lamps.setLit(lantern, lit)   Lamps.all() -> { BasePart }
--   Lamps.route(id) -> { BasePart }   Lamps.routeIds() -> { string }   Lamps.pending(id) -> n
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Palette = require(Shared:WaitForChild("Palette"))
local World = require(script.Parent:WaitForChild("World"))
local Lots = require(script.Parent:WaitForChild("Lots"))
local WorldClock = require(script.Parent:WaitForChild("WorldClock"))

local Lamps = {}
Lamps.TAG = "Lamp"

local lanterns: { BasePart } = {}
local routes: { [string]: { BasePart } } = {}
local routeOrder: { string } = {}
local folder: Folder
local phaseStamp = 0

local LIT = Color3.fromRGB(Config.LAMP_LIGHT_COLOUR[1], Config.LAMP_LIGHT_COLOUR[2], Config.LAMP_LIGHT_COLOUR[3])
local UNLIT = Color3.fromRGB(70, 74, 70)

function Lamps.all(): { BasePart }
	return lanterns
end

function Lamps.route(id: string): { BasePart }
	return routes[id] or {}
end

function Lamps.routeIds(): { string }
	return routeOrder
end

-- Lamps should be lit at dusk and through the night, out at dawn and through the day.
function Lamps.wanted(): boolean
	local p = Lighting:GetAttribute("Phase")
	return p == "Dusk" or p == "Night"
end

function Lamps.setLit(lantern: BasePart, lit: boolean)
	lantern:SetAttribute("Lit", lit)
	lantern.Material = if lit then Enum.Material.Neon else Enum.Material.Glass
	lantern.Color = if lit then LIT else UNLIT
	local light = lantern:FindFirstChildWhichIsA("PointLight")
	if light then
		light.Enabled = lit
	end
end

-- Lamps on a route that aren't as they should be now.
function Lamps.pending(id: string): number
	local want = Lamps.wanted()
	local n = 0
	for _, l in Lamps.route(id) do
		if l:GetAttribute("Lit") ~= want then
			n += 1
		end
	end
	return n
end

local function build(pos: Vector3, routeId: string, n: number): BasePart
	local model = Instance.new("Model")
	model.Name = "Lamp" .. n
	local pole = World.part({ Name = "Pole", Size = Vector3.new(0.35, 9, 0.35), CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0)), Color = Palette.color("iron_black"), Material = Enum.Material.Metal })
	pole.Parent = model
	local lantern = World.part({ Name = "Lantern", Size = Vector3.new(0.9, 1.3, 0.9), CFrame = CFrame.new(pos + Vector3.new(0, 9.6, 0)), CanCollide = false })
	if Config.LAMP_LIGHTS then
		local light = Instance.new("PointLight")
		light.Range = Config.LAMP_LIGHT_RANGE
		light.Brightness = 1.4
		light.Color = LIT
		light.Shadows = false
		light.Parent = lantern
	end
	lantern:SetAttribute("Route", routeId)
	lantern:SetAttribute("LampId", n)
	lantern.Parent = model
	CollectionService:AddTag(lantern, Lamps.TAG)
	model.Parent = folder
	return lantern
end

-- Walks every road, dropping a lamp each LAMP_SPACING studs, alternating kerbs.
function Lamps.layout(): { { any } }
	local spots: { { any } } = {}
	local taken: { [number]: { Vector3 } } = {}
	local cell = Config.LAMP_MIN_GAP
	local function free(p: Vector3): boolean
		local cx, cz = math.floor(p.X / cell), math.floor(p.Z / cell)
		for dx = -1, 1 do
			for dz = -1, 1 do
				for _, q in taken[(cx + dx) * 100000 + cz + dz] or {} do
					if (q - p).Magnitude < Config.LAMP_MIN_GAP then
						return false
					end
				end
			end
		end
		return true
	end
	local carry, side, road = Config.LAMP_SPACING / 2, 1, -1
	for _, s in Lots.roads() do
		if s.road ~= road then
			road, carry = s.road, Config.LAMP_SPACING / 2
		end
		local dx, dz = s.bx - s.ax, s.bz - s.az
		local len = math.sqrt(dx * dx + dz * dz)
		if len > 0 then
			local ux, uz = dx / len, dz / len
			local d = carry
			while d <= len do
				local off = s.half + Config.LAMP_KERB
				local x = s.ax + ux * d - uz * off * side
				local z = s.az + uz * d + ux * off * side
				local p = Vector3.new(x, 0, z)
				if free(p) then
					local key = math.floor(x / cell) * 100000 + math.floor(z / cell)
					taken[key] = taken[key] or {}
					table.insert(taken[key], p)
					table.insert(spots, { x, z, s.road })
				end
				side = -side
				d += Config.LAMP_SPACING
			end
			carry = d - len
		end
	end
	return spots
end

-- Plots and landmark volumes a lamp mustn't stand in (axis-aligned boxes in x/z).
local function blockers(): (x: number, z: number) -> boolean
	local cell = 64
	local grid: { [number]: { { number } } } = {}
	local function add(x0: number, x1: number, z0: number, z1: number)
		for cx = math.floor(x0 / cell), math.floor(x1 / cell) do
			for cz = math.floor(z0 / cell), math.floor(z1 / cell) do
				local k = cx * 100000 + cz
				grid[k] = grid[k] or {}
				table.insert(grid[k], { x0, x1, z0, z1 })
			end
		end
	end
	for _, l in Lots.all() do
		local c, sz = l.part.Position, l.part.Size
		add(c.X - sz.X / 2, c.X + sz.X / 2, c.Z - sz.Z / 2, c.Z + sz.Z / 2)
	end
	local map = workspace:FindFirstChild("Map")
	local marks = map and map:FindFirstChild("Landmarks_Greybox")
	for _, p in if marks then marks:GetDescendants() else {} do
		if p:IsA("BasePart") then
			local c, sz = p.Position, p.Size
			add(c.X - sz.X / 2, c.X + sz.X / 2, c.Z - sz.Z / 2, c.Z + sz.Z / 2)
		end
	end
	return function(x: number, z: number): boolean
		for _, b in grid[math.floor(x / cell) * 100000 + math.floor(z / cell)] or {} do
			if x >= b[1] and x <= b[2] and z >= b[3] and z <= b[4] then
				return true
			end
		end
		return false
	end
end

local function setAll(lit: boolean)
	for _, l in lanterns do
		Lamps.setLit(l, lit)
	end
end

-- The city's own lamplighters: what players haven't done by LAMP_NPC_DELAY into the phase.
local function onPhase(phase: string)
	if phase ~= "Dusk" and phase ~= "Dawn" then
		return
	end
	phaseStamp += 1
	local stamp = phaseStamp
	local want = phase == "Dusk"
	task.delay(Config.LAMP_NPC_DELAY, function()
		if stamp == phaseStamp and Lamps.wanted() == want then
			setAll(want)
		end
	end)
end

function Lamps.init()
	folder = World.folder("Lamps")
	Lots.waitReady()
	local n = 0
	local count: { [number]: number } = {}
	local blocked = blockers()
	for _, spot in Lamps.layout() do
		local g, material = World.ground(spot[1], spot[2])
		if g.Y > -1 and material ~= Enum.Material.Water and not blocked(spot[1], spot[2]) then
			n += 1
			local road = spot[3] :: number
			count[road] = (count[road] or 0) + 1
			local id = string.format("R%d-%d", road, (count[road] - 1) // Config.LAMP_ROUTE + 1)
			local lantern = build(g, id, n)
			table.insert(lanterns, lantern)
			if not routes[id] then
				routes[id] = {}
				table.insert(routeOrder, id)
			end
			table.insert(routes[id], lantern)
		end
	end
	setAll(Lamps.wanted())
	WorldClock.PhaseChanged:Connect(onPhase)
end

return Lamps
