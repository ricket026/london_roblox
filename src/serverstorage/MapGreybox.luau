-- MapGreybox v3: builds the London greybox from ServerStorage.MapLayoutData (JSON).
-- Ground, grass, paths, pavements and roads are Terrain (one surface at Y 0, no z-fighting).
-- Curved roads ("s":1) are Chaikin-smoothed; kerbs are rotated stone strips along carriageway edges.
-- Building lots are raised slabs from an 8-stud raster that keeps clear of every pavement.
local M = {}
local X0, X1, Z0, Z1 = -1150, 1900, -3320, 850
local RIVER_LO, RIVER_HI = 1144, 1456 -- terrain/kerbs skip this X band (river + walls, bridges are parts)
local Mt = Enum.Material
local rgb = Color3.fromRGB
local T = workspace.Terrain
local LOTCOL = {
	Townhouse = rgb(214,200,170), Shop = rgb(205,176,140), Club = rgb(200,196,184), Terrace = rgb(184,140,116),
	Office = rgb(190,186,176), Government = rgb(222,220,210), Workshop = rgb(160,130,104),
	Warehouse = rgb(140,104,86), Lodging = rgb(150,132,112),
}
local TERRAIN_COL = {
	[Mt.Pavement] = rgb(172,168,160), [Mt.Cobblestone] = rgb(108,102,94), [Mt.Sandstone] = rgb(160,98,80),
	[Mt.Ground] = rgb(170,150,114), [Mt.Sand] = rgb(196,176,130), [Mt.Grass] = rgb(92,124,60),
	[Mt.LeafyGrass] = rgb(72,108,50), [Mt.Limestone] = rgb(196,190,176), [Mt.Mud] = rgb(72,64,50),
}
local ROADMAT = {grand = Mt.Sandstone, main = Mt.Cobblestone, second = Mt.Cobblestone, mews = Mt.Cobblestone, lane = Mt.Cobblestone}
local ORDER = {lane = 1, mews = 2, second = 3, main = 4, grand = 5}
local KERB_COL = rgb(150,146,138)

local count = 0
local function tick(n) count += n or 1; if count % 300 == 0 then task.wait() end end
local function part(parent, name, x1, x2, y1, y2, z1, z2, mat, col)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Size = Vector3.new(math.abs(x2 - x1), math.abs(y2 - y1), math.abs(z2 - z1))
	p.CFrame = CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2)
	p.Material = mat or Mt.SmoothPlastic
	p.Color = col or rgb(180, 180, 180)
	p:SetAttribute("Greybox", true)
	p.Parent = parent
	tick()
	return p
end
local function tiled(parent, name, x1, x2, y1, y2, z1, z2, mat, col)
	local nx, nz = math.ceil(math.abs(x2 - x1) / 1000), math.ceil(math.abs(z2 - z1) / 1000)
	for a = 0, nx - 1 do for b = 0, nz - 1 do
		part(parent, name, x1 + (x2 - x1) * a / nx, x1 + (x2 - x1) * (a + 1) / nx, y1, y2, z1 + (z2 - z1) * b / nz, z1 + (z2 - z1) * (b + 1) / nz, mat, col)
	end end
end
local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if f then f:Destroy() end
	f = Instance.new("Folder"); f.Name = name; f.Parent = parent
	return f
end
local function tag(p, text, y, maxd, w)
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromOffset(w or 200, 36)
	g.StudsOffsetWorldSpace = Vector3.new(0, y, 0)
	g.MaxDistance = maxd
	g.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = text; t.TextScaled = true
	t.Font = Enum.Font.SourceSansBold; t.TextColor3 = Color3.new(1, 1, 1); t.TextStrokeTransparency = 0.3
	t.Parent = g
	g.Parent = p
end
local function ghost(p) p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch = 1, false, false, false; return p end
local function marker(parent, name, x, z, h, col)
	local p = part(parent, name, x - 1, x + 1, 0, h, z - 1, z + 1, Mt.SmoothPlastic, col)
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	tag(p, name, h / 2 + 3, 400, 180)
	return p
end
local function spans(a, b, gaps)
	table.sort(gaps, function(p, q) return p[1] < q[1] end)
	local out, cur = {}, a
	for _, g in gaps do
		if g[1] > cur then table.insert(out, {cur, math.min(g[1], b)}) end
		cur = math.max(cur, g[2])
	end
	if cur < b then table.insert(out, {cur, b}) end
	return out
end

-- terrain helpers: Roblox shows a filled surface 2 studs above the fill top, so fills stop at Y -2 for a surface at 0
local function tBlock(x1, x2, z1, z2, y1, y2, mat)
	if x1 > x2 then x1, x2 = x2, x1 end
	if z1 > z2 then z1, z2 = z2, z1 end
	local nx, nz = math.ceil((x2 - x1) / 1000), math.ceil((z2 - z1) / 1000)
	for a = 0, nx - 1 do for b = 0, nz - 1 do
		local ax, bx = x1 + (x2 - x1) * a / nx, x1 + (x2 - x1) * (a + 1) / nx
		local az, bz = z1 + (z2 - z1) * b / nz, z1 + (z2 - z1) * (b + 1) / nz
		T:FillBlock(CFrame.new((ax + bx) / 2, (y1 + y2) / 2, (az + bz) / 2), Vector3.new(bx - ax, y2 - y1, bz - az), mat)
		tick(20)
	end end
end
-- land-only rectangle (skips the river band)
local function tLand(x1, x2, z1, z2, y1, y2, mat)
	if x1 > x2 then x1, x2 = x2, x1 end
	if x1 < RIVER_LO then tBlock(x1, math.min(x2, RIVER_LO), z1, z2, y1, y2, mat) end
	if x2 > RIVER_HI then tBlock(math.max(x1, RIVER_HI), x2, z1, z2, y1, y2, mat) end
end
-- clip a segment to the parts outside the river band
local function clipRiver(ax, az, bx, bz)
	local function inR(x) return x > RIVER_LO and x < RIVER_HI end
	if not inR(ax) and not inR(bx) and ((ax <= RIVER_LO and bx <= RIVER_LO) or (ax >= RIVER_HI and bx >= RIVER_HI)) then return {{ax, az, bx, bz}} end
	local dx = bx - ax
	if math.abs(dx) < 1e-6 then return if inR(ax) then {} else {{ax, az, bx, bz}} end
	local out = {}
	local ts = {0}
	for _, X in {RIVER_LO, RIVER_HI} do local t = (X - ax) / dx; if t > 0 and t < 1 then table.insert(ts, t) end end
	table.insert(ts, 1); table.sort(ts)
	for i = 1, #ts - 1 do
		local t1, t2 = ts[i], ts[i + 1]
		local mx = ax + dx * (t1 + t2) / 2
		if not inR(mx) then table.insert(out, {ax + dx * t1, az + (bz - az) * t1, ax + dx * t2, az + (bz - az) * t2}) end
	end
	return out
end
-- FillCylinder ignores the -2 offset (surface lands at +2), so joints are mitred blocks and discs are rows
local function tSeg(ax, az, bx, bz, hw, mat, ea, eb)
	local dx, dz = bx - ax, bz - az
	local L = math.sqrt(dx * dx + dz * dz)
	if L < 0.05 then return end
	local ux, uz = dx / L, dz / L
	for _, s in clipRiver(ax - ux * ea, az - uz * ea, bx + ux * eb, bz + uz * eb) do
		local a, b = Vector3.new(s[1], -8, s[2]), Vector3.new(s[3], -8, s[4])
		local SL = (b - a).Magnitude
		if SL > 0.05 then T:FillBlock(CFrame.lookAt((a + b) / 2, b), Vector3.new(hw * 2, 12, SL), mat) end
	end
	tick(2)
end
-- polyline as blocks; each block is lengthened by hw*tan(turn/2) at bends so outer corners stay filled
local function tPoly(P, hw, mat)
	local n = #P
	local closed = n > 2 and (P[1][1] - P[n][1]) ^ 2 + (P[1][2] - P[n][2]) ^ 2 < 1
	local function dir(i)
		local dx, dz = P[i + 1][1] - P[i][1], P[i + 1][2] - P[i][2]
		local L = math.max(1e-6, math.sqrt(dx * dx + dz * dz))
		return dx / L, dz / L
	end
	local ext = {}
	for v = 1, n do
		local a, b = v - 1, v
		if closed and v == 1 then a = n - 1 elseif closed and v == n then a, b = n - 1, 1 end
		if a >= 1 and b <= n - 1 then
			local ax, az = dir(a)
			local bx, bz = dir(b)
			local c = math.clamp(ax * bx + az * bz, -1, 1)
			ext[v] = math.min(hw * 2, hw * math.tan(math.acos(c) / 2))
		else
			ext[v] = 0
		end
	end
	for i = 1, n - 1 do tSeg(P[i][1], P[i][2], P[i + 1][1], P[i + 1][2], hw, mat, ext[i], ext[i + 1]) end
end
local function tDisc(x0, z0, r, mat)
	for z = z0 - r, z0 + r - 2, 2 do
		local f = 1 - ((z + 1 - z0) / r) ^ 2
		if f > 0 then
			local hx = r * math.sqrt(f)
			T:FillBlock(CFrame.new(x0, -8, z + 1), Vector3.new(hx * 2, 12, 2), mat)
		end
	end
	tick(4)
end

local function chaikin(P, it)
	for _ = 1, it do
		local Q = {P[1]}
		for i = 1, #P - 1 do
			local a, b = P[i], P[i + 1]
			table.insert(Q, {0.75 * a[1] + 0.25 * b[1], 0.75 * a[2] + 0.25 * b[2]})
			table.insert(Q, {0.25 * a[1] + 0.75 * b[1], 0.25 * a[2] + 0.75 * b[2]})
		end
		table.insert(Q, P[#P])
		P = Q
	end
	return P
end
-- smooth "s" roads, keeping vertices that other roads attach to
local function smoothRoads(roads)
	local pts = {}
	for ri, r in roads do for _, p in r.p do table.insert(pts, {p[1], p[2], ri}) end end
	for ri, r in roads do
		if r.s then
			local pin = {}
			for vi, p in r.p do
				if vi == 1 or vi == #r.p then pin[vi] = true else
					for _, q in pts do if q[3] ~= ri and (q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2 <= 36 then pin[vi] = true; break end end
				end
			end
			local out, piece = {r.p[1]}, {r.p[1]}
			for vi = 2, #r.p do
				table.insert(piece, r.p[vi])
				if pin[vi] then
					local sm = chaikin(piece, 3)
					for k = 2, #sm do table.insert(out, sm[k]) end
					piece = {r.p[vi]}
				end
			end
			r.p = out
		end
	end
end

local function buildGraph(data, map)
	local R = folder(map, "Roads")
	local GF = folder(R, "_Graph")
	local nodes, grid = {}, {}
	local function node(x, z)
		local gx, gz = math.floor(x / 12), math.floor(z / 12)
		for a = -1, 1 do for b = -1, 1 do
			local l = grid[(gx + a) * 100000 + gz + b]
			if l then for _, n in l do if (n.x - x) ^ 2 + (n.z - z) ^ 2 <= 36 then return n end end end
		end end
		local n = {x = x, z = z, id = #nodes + 1, links = {}}
		nodes[n.id] = n
		local k = gx * 100000 + gz
		grid[k] = grid[k] or {}
		table.insert(grid[k], n)
		return n
	end
	local function link(a, b, road, cls, w)
		if a == b or a.links[b] then return end
		local mx = (a.x + b.x) / 2
		local info = {road = road, cls = cls, w = w, bridge = mx > 1146 and mx < 1454}
		a.links[b], b.links[a] = info, info
	end
	local segs = {}
	for _, r in data.roads do
		for s = 1, #r.p - 1 do table.insert(segs, {r.p[s][1], r.p[s][2], r.p[s + 1][1], r.p[s + 1][2], r.n, r.c, data.classes[r.c].w}) end
	end
	local rings = {}
	for _, c in data.circuses do
		local rm = (c.r[1] + c.r[2]) / 2
		local ring = {}
		for k = 0, 15 do ring[k + 1] = node(c.x + rm * math.cos(k * math.pi / 8), c.z + rm * math.sin(k * math.pi / 8)) end
		for k = 1, 16 do link(ring[k], ring[k % 16 + 1], c.n, c.c, data.classes[c.c].w) end
		table.insert(rings, {c = c, ring = ring})
		local keep, R2 = {}, (c.r[2] + 4) ^ 2
		for _, sg in segs do
			local inA = (sg[1] - c.x) ^ 2 + (sg[2] - c.z) ^ 2 <= R2
			local inB = (sg[3] - c.x) ^ 2 + (sg[4] - c.z) ^ 2 <= R2
			if not (inA and inB) then
				if inA or inB then
					local dx, dz = sg[3] - sg[1], sg[4] - sg[2]
					local fx, fz = sg[1] - c.x, sg[2] - c.z
					local a, b, q = dx * dx + dz * dz, 2 * (fx * dx + fz * dz), fx * fx + fz * fz - rm * rm
					local disc = b * b - 4 * a * q
					if disc >= 0 then
						local t = if inA then (-b + math.sqrt(disc)) / (2 * a) else (-b - math.sqrt(disc)) / (2 * a)
						if t >= 0 and t <= 1 then
							if inA then sg[1], sg[2] = sg[1] + t * dx, sg[2] + t * dz else sg[3], sg[4] = sg[1] + t * dx, sg[2] + t * dz end
						end
					end
				end
				table.insert(keep, sg)
			end
		end
		segs = keep
	end
	for si, s in segs do
		local ax, az, bx, bz = s[1], s[2], s[3], s[4]
		local dx, dz = bx - ax, bz - az
		local L2 = dx * dx + dz * dz
		if L2 >= 1 then
			local ts = {0, 1}
			for sj, o in segs do
				if sj ~= si then
					local ex, ez = o[3] - o[1], o[4] - o[2]
					local den = dx * ez - dz * ex
					if math.abs(den) > 1e-6 then
						local t = ((o[1] - ax) * ez - (o[2] - az) * ex) / den
						local u = ((o[1] - ax) * dz - (o[2] - az) * dx) / den
						if t > 1e-4 and t < 1 - 1e-4 and u >= -1e-4 and u <= 1 + 1e-4 then table.insert(ts, t) end
					end
					for e = 1, 3, 2 do
						local t = ((o[e] - ax) * dx + (o[e + 1] - az) * dz) / L2
						if t > 0 and t < 1 and (ax + t * dx - o[e]) ^ 2 + (az + t * dz - o[e + 1]) ^ 2 <= 36 then table.insert(ts, t) end
					end
				end
			end
			table.sort(ts)
			local prev = node(ax, az)
			for _, t in ts do
				local n = node(ax + t * dx, az + t * dz)
				if n ~= prev then link(prev, n, s[5], s[6], s[7]); prev = n end
			end
		end
		if si % 100 == 0 then task.wait() end
	end
	for _, rg in rings do
		local c, member = rg.c, {}
		for _, n in rg.ring do member[n] = true end
		for _, n in nodes do
			if not member[n] and (n.x - c.x) ^ 2 + (n.z - c.z) ^ 2 <= (c.r[2] + 6) ^ 2 then
				local best, bd = nil, math.huge
				for _, r in rg.ring do local d = (r.x - n.x) ^ 2 + (r.z - n.z) ^ 2; if d < bd then best, bd = r, d end end
				link(n, best, c.n, c.c, data.classes[c.c].w)
			end
		end
	end
	local parts, nl = {}, 0
	for _, n in nodes do
		local p = Instance.new("Part")
		p.Name = "N" .. n.id
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(2, 2, 2)
		p.Position = Vector3.new(n.x, 1, n.z)
		p:SetAttribute("Greybox", true)
		parts[n] = p
	end
	for i, n in nodes do
		for o, info in n.links do
			local v = Instance.new("ObjectValue")
			v.Name = "L"; v.Value = parts[o]
			v:SetAttribute("Road", info.road); v:SetAttribute("Class", info.cls)
			v:SetAttribute("Width", info.w); v:SetAttribute("Bridge", info.bridge)
			v.Parent = parts[n]
			nl += 1
		end
		parts[n].Parent = GF
		if i % 300 == 0 then task.wait() end
	end
	local NF = folder(R, "_Names")
	for _, r in data.roads do
		local best, bl = 1, -1
		for s = 1, #r.p - 1 do local l = (r.p[s + 1][1] - r.p[s][1]) ^ 2 + (r.p[s + 1][2] - r.p[s][2]) ^ 2; if l > bl then best, bl = s, l end end
		local a, b = r.p[best], r.p[best + 1]
		local x, z = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
		tag(ghost(part(NF, r.n, x - 0.5, x + 0.5, 0, 1, z - 0.5, z + 0.5)), r.n, 5, 260, 220)
	end
	return #nodes, nl // 2
end

function M.Build(data, map)
	local function status(s) map:SetAttribute("BuildStatus", s) end
	count = 0
	smoothRoads(data.roads)
	local w, rv = data.water, data.water.river
	local roads = table.clone(data.roads)
	table.sort(roads, function(a, b) return ORDER[a.c] < ORDER[b.c] end)

	status("terrain")
	for m, c in TERRAIN_COL do T:SetMaterialColor(m, c) end
	tLand(X0, X1, Z0, Z1, -2, 60, Mt.Air)
	-- paint materials on the 4-stud voxel grid, then fill merged axis-aligned rects
	-- (rotated FillBlocks drop voxels on diagonals; FillCylinder ignores the -2 offset)
	local VC, VX0, VZ0 = 4, -1152, -3324
	local VNX, VNZ = (1904 - VX0) // VC, (852 - VZ0) // VC
	local MATS = {Mt.Pavement, Mt.Grass, Mt.LeafyGrass, Mt.Limestone, Mt.Ground, Mt.Sand, Mt.Cobblestone, Mt.Sandstone}
	local vb = buffer.create(VNX * VNZ)
	buffer.fill(vb, 0, 1)
	local function vr(a, b, o, n)
		if a > b then a, b = b, a end
		return math.max(0, math.ceil((a - o) / VC - 0.5)), math.min(n - 1, math.floor((b - o) / VC - 0.5))
	end
	local function vRect(xr, zr, v)
		local a1, a2 = vr(xr[1], xr[2], VX0, VNX)
		local b1, b2 = vr(zr[1], zr[2], VZ0, VNZ)
		for j = b1, b2 do for i = a1, a2 do buffer.writeu8(vb, j * VNX + i, v) end end
	end
	local function vCap(ax, az, bx, bz, hw, v, only)
		local dx, dz = bx - ax, bz - az
		local L2 = dx * dx + dz * dz
		local a1, a2 = vr(math.min(ax, bx) - hw, math.max(ax, bx) + hw, VX0, VNX)
		local b1, b2 = vr(math.min(az, bz) - hw, math.max(az, bz) + hw, VZ0, VNZ)
		for j = b1, b2 do
			local z = VZ0 + (j + 0.5) * VC
			for i = a1, a2 do
				local x = VX0 + (i + 0.5) * VC
				local t = if L2 > 0 then math.clamp(((x - ax) * dx + (z - az) * dz) / L2, 0, 1) else 0
				if (ax + t * dx - x) ^ 2 + (az + t * dz - z) ^ 2 <= hw * hw then
					local k = j * VNX + i
					if not only or only[buffer.readu8(vb, k)] then buffer.writeu8(vb, k, v) end
				end
			end
		end
	end
	local function vPoly(P, hw, v, only) for q = 1, #P - 1 do vCap(P[q][1], P[q][2], P[q + 1][1], P[q + 1][2], hw, v, only) end end
	local function vRing(x0, z0, r1, r2, v, only)
		local a1, a2 = vr(x0 - r2, x0 + r2, VX0, VNX)
		local b1, b2 = vr(z0 - r2, z0 + r2, VZ0, VNZ)
		for j = b1, b2 do
			local z = VZ0 + (j + 0.5) * VC - z0
			for i = a1, a2 do
				local x = VX0 + (i + 0.5) * VC - x0
				local d2 = x * x + z * z
				if d2 >= r1 * r1 and d2 <= r2 * r2 then
					local k = j * VNX + i
					if not only or only[buffer.readu8(vb, k)] then buffer.writeu8(vb, k, v) end
				end
			end
		end
	end
	for _, a in data.parks do vRect(a.x, a.z, 2) end
	for _, a in data.gardens do vRect(a.x, a.z, 3) end
	for _, a in data.plazas do vRect(a.x, a.z, 4) end
	local green = {[2] = true, [3] = true}
	for _, pth in data.paths do vPoly(pth.p, pth.w / 2, if pth.sand then 6 else 5, green) end
	for _, r in roads do local cl = data.classes[r.c]; if cl.p > 0 then vPoly(r.p, cl.w / 2 + cl.p, 1) end end
	for _, r in roads do vPoly(r.p, data.classes[r.c].w / 2, if r.c == "grand" then 8 else 7) end
	for _, c in data.circuses do
		vRing(c.x, c.z, c.r[2], c.r[2] + 8, 1, {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true})
		vRing(c.x, c.z, c.r[1], c.r[2], 7)
		vRing(c.x, c.z, 0, c.r[1], 4)
	end
	task.wait()
	local nFill = 0
	for j = 0, VNZ - 1 do
		for i = 0, VNX - 1 do
			local k = j * VNX + i
			local v = buffer.readu8(vb, k)
			if v ~= 0 then
				local e = i
				while e + 1 < VNX and buffer.readu8(vb, k + e + 1 - i) == v do e += 1 end
				local f = j
				while f + 1 < VNZ do
					local base, ok = (f + 1) * VNX, true
					for ii = i, e do if buffer.readu8(vb, base + ii) ~= v then ok = false; break end end
					if not ok then break end
					f += 1
				end
				for jj = j, f do local base = jj * VNX; for ii = i, e do buffer.writeu8(vb, base + ii, 0) end end
				tLand(VX0 + i * VC, VX0 + (e + 1) * VC, VZ0 + j * VC, VZ0 + (f + 1) * VC, -14, -2, MATS[v])
				nFill += 1
			end
		end
		if j % 25 == 0 then task.wait() end
	end
	-- palace garden sits at -4.5; Parliament's yard floor is at +0.05, so drop terrain under it
	local pg = data.palaceGarden
	tBlock(pg.x[1], pg.x[2], pg.z[1], pg.z[2], -12, 8, Mt.Air)
	tBlock(pg.x[1], pg.x[2], pg.z[1], pg.z[2], -14, pg.top - 2, Mt.Grass)
	local parl = data.protected[2]
	tBlock(parl.x[1] + 4, math.min(parl.x[2], RIVER_LO) - 2, parl.z[1] - 4, parl.z[2] + 4, -6, 4, Mt.Air)
	-- St James's Park lake: 4-stud rows of an ellipse
	local lk = w.lake
	for z = lk.cz - lk.rz, lk.cz + lk.rz, 4 do
		local f = 1 - ((z + 2 - lk.cz) / lk.rz) ^ 2
		if f > 0 then
			local hx = lk.rx * math.sqrt(f)
			tBlock(lk.cx - hx, lk.cx + hx, z, z + 4, lk.bed - 2, 4, Mt.Air)
			tBlock(lk.cx - hx, lk.cx + hx, z, z + 4, -14, lk.bed - 2, Mt.Mud)
			tBlock(lk.cx - hx, lk.cx + hx, z, z + 4, lk.bed - 2, lk.surface, Mt.Water)
		end
	end
	local dk = w.docks
	for _, r in dk.rects do
		tBlock(r.x[1], r.x[2], r.z[1], r.z[2], dk.bed - 4, 4, Mt.Air)
		tBlock(r.x[1], r.x[2], r.z[1], r.z[2], dk.bed, dk.surface, Mt.Water)
	end

	status("kerbs")
	for _, n in {"Districts","JobSites","Ground","Plots","Kerbs","Water","Landmarks_Greybox","Roads","BusStops","CabRanks","Routes","Bounds","Bridges","Labels"} do
		local f = map:FindFirstChild(n); if f then f:Destroy() end
	end
	local K = folder(map, "Kerbs")
	-- spatial buckets of carriageway segments (100-stud cells)
	local buckets, segList = {}, {}
	for ri, r in data.roads do
		local hw = data.classes[r.c].w / 2
		local closed = (r.p[1][1] - r.p[#r.p][1]) ^ 2 + (r.p[1][2] - r.p[#r.p][2]) ^ 2 < 1
		r._closed = closed
		for s = 1, #r.p - 1 do
			local a, b = r.p[s], r.p[s + 1]
			local sg = {a[1], a[2], b[1], b[2], hw, ri, s}
			table.insert(segList, sg)
			for gx = math.floor((math.min(a[1], b[1]) - hw - 2) / 100), math.floor((math.max(a[1], b[1]) + hw + 2) / 100) do
				for gz = math.floor((math.min(a[2], b[2]) - hw - 2) / 100), math.floor((math.max(a[2], b[2]) + hw + 2) / 100) do
					local k = gx * 100000 + gz
					buckets[k] = buckets[k] or {}
					table.insert(buckets[k], sg)
				end
			end
		end
	end
	local function open(x, z, ri, si, nseg, closed)
		if x > RIVER_LO - 1 and x < RIVER_HI + 1 then return true end
		for _, c in data.circuses do if (x - c.x) ^ 2 + (z - c.z) ^ 2 < (c.r[2] + 1) ^ 2 then return true end end
		local l = buckets[math.floor(x / 100) * 100000 + math.floor(z / 100)]
		if not l then return false end
		for _, sg in l do
			local same = sg[6] == ri and (math.abs(sg[7] - si) <= 1 or (closed and math.abs(sg[7] - si) == nseg - 1))
			if not same then
				local dx, dz = sg[3] - sg[1], sg[4] - sg[2]
				local L2 = dx * dx + dz * dz
				local t = if L2 > 0 then math.clamp(((x - sg[1]) * dx + (z - sg[2]) * dz) / L2, 0, 1) else 0
				if (sg[1] + t * dx - x) ^ 2 + (sg[2] + t * dz - z) ^ 2 < (sg[5] + 0.4) ^ 2 then return true end
			end
		end
		return false
	end
	local function kerbPiece(ax, az, bx, bz)
		local a, b = Vector3.new(ax, -0.25, az), Vector3.new(bx, -0.25, bz) -- kerb stands 0.5 above the road
		local L = (b - a).Magnitude
		if L < 0.5 then return end
		local p = Instance.new("Part")
		p.Name = "Kerb"; p.Anchored = true; p.Material = Mt.Concrete; p.Color = KERB_COL
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Size = Vector3.new(1, 1.5, L + 0.4)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		p:SetAttribute("Greybox", true)
		p.Parent = K
		tick()
	end
	local nk = 0
	for ri, r in data.roads do
		local cl = data.classes[r.c]
		if cl.p > 0 then
			local P, n = r.p, #r.p
			local nseg = n - 1
			local norms = {}
			for i = 1, nseg do
				local dx, dz = P[i + 1][1] - P[i][1], P[i + 1][2] - P[i][2]
				local L = math.max(1e-6, math.sqrt(dx * dx + dz * dz))
				norms[i] = {-dz / L, dx / L}
			end
			local function miter(v)
				local na = norms[v - 1] or (r._closed and norms[nseg])
				local nb = norms[v] or (r._closed and norms[1])
				na, nb = na or nb, nb or na
				local mx, mz = na[1] + nb[1], na[2] + nb[2]
				local ml = math.sqrt(mx * mx + mz * mz)
				if ml < 1e-6 then return nb end
				mx, mz = mx / ml, mz / ml
				local d = math.max(0.35, mx * nb[1] + mz * nb[2])
				return {mx / d, mz / d}
			end
			local mit = {}
			for v = 1, n do mit[v] = miter(v) end
			local o = cl.w / 2 + 0.5
			for _, sgn in {1, -1} do
				for i = 1, nseg do
					local ax, az = P[i][1] + sgn * o * mit[i][1], P[i][2] + sgn * o * mit[i][2]
					local bx, bz = P[i + 1][1] + sgn * o * mit[i + 1][1], P[i + 1][2] + sgn * o * mit[i + 1][2]
					local L = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
					local steps = math.max(1, math.floor(L))
					local runStart = nil
					for k = 0, steps do
						local t = k / steps
						local x, z = ax + (bx - ax) * t, az + (bz - az) * t
						local closedHere = k < steps and not open(x, z, ri, i, nseg, r._closed)
						if closedHere and not runStart then runStart = t end
						if (not closedHere or k == steps) and runStart then
							local t2 = if closedHere then 1 else t
							kerbPiece(ax + (bx - ax) * runStart, az + (bz - az) * runStart, ax + (bx - ax) * t2, az + (bz - az) * t2)
							nk += 1
							runStart = nil
						end
					end
				end
			end
		end
	end
	for _, c in data.circuses do
		for _, rad in {c.r[1] - 0.5, c.r[2] + 0.5} do
			for k = 0, 47 do
				local a1, a2 = k * math.pi / 24, (k + 1) * math.pi / 24
				local ax, az = c.x + rad * math.cos(a1), c.z + rad * math.sin(a1)
				local bx, bz = c.x + rad * math.cos(a2), c.z + rad * math.sin(a2)
				local mx, mz = (ax + bx) / 2, (az + bz) / 2
				local blocked = false
				if rad > c.r[1] then
					local l = buckets[math.floor(mx / 100) * 100000 + math.floor(mz / 100)] or {}
					for _, sg in l do
						local dx, dz = sg[3] - sg[1], sg[4] - sg[2]
						local L2 = dx * dx + dz * dz
						local t = if L2 > 0 then math.clamp(((mx - sg[1]) * dx + (mz - sg[2]) * dz) / L2, 0, 1) else 0
						if (sg[1] + t * dx - mx) ^ 2 + (sg[2] + t * dz - mz) ^ 2 < (sg[5] + 1) ^ 2 then blocked = true; break end
					end
				end
				if not blocked then kerbPiece(ax, az, bx, bz); nk += 1 end
			end
		end
	end

	status("lots")
	local LC = 8
	local LNX, LNZ = math.ceil((X1 - X0) / LC), math.ceil((Z1 - Z0) / LC)
	local lot, ldis = buffer.create(LNX * LNZ), buffer.create(LNX * LNZ)
	local function inside(a, b, o, n) if a > b then a, b = b, a end; return math.max(0, math.ceil((a - o) / LC)), math.min(n - 1, math.floor((b - o) / LC) - 1) end
	local function touching(a, b, o, n) if a > b then a, b = b, a end; return math.max(0, math.floor((a - o) / LC)), math.min(n - 1, math.ceil((b - o) / LC) - 1) end
	for d, a in data.districts do
		local i1, i2 = inside(a.x[1], a.x[2], X0, LNX); local j1, j2 = inside(a.z[1], a.z[2], Z0, LNZ)
		for j = j1, j2 do for i = i1, i2 do buffer.writeu8(lot, j * LNX + i, 1); buffer.writeu8(ldis, j * LNX + i, d) end end
	end
	local function clear(xr, zr, m)
		local i1, i2 = touching(xr[1] - m, xr[2] + m, X0, LNX); local j1, j2 = touching(math.min(zr[1], zr[2]) - m, math.max(zr[1], zr[2]) + m, Z0, LNZ)
		for j = j1, j2 do for i = i1, i2 do buffer.writeu8(lot, j * LNX + i, 0) end end
	end
	local function clearCapsule(ax, az, bx, bz, r)
		local i1, i2 = touching(math.min(ax, bx) - r, math.max(ax, bx) + r, X0, LNX)
		local j1, j2 = touching(math.min(az, bz) - r, math.max(az, bz) + r, Z0, LNZ)
		local dx, dz = bx - ax, bz - az
		local L2 = dx * dx + dz * dz
		for j = j1, j2 do
			local z = Z0 + (j + 0.5) * LC
			for i = i1, i2 do
				local x = X0 + (i + 0.5) * LC
				local t = if L2 > 0 then math.clamp(((x - ax) * dx + (z - az) * dz) / L2, 0, 1) else 0
				if (ax + t * dx - x) ^ 2 + (az + t * dz - z) ^ 2 <= r * r then buffer.writeu8(lot, j * LNX + i, 0) end
			end
		end
	end
	for _, a in data.protected do clear(a.x, a.z, 0) end
	clear(pg.x, pg.z, 0)
	clear({RIVER_LO, RIVER_HI}, {Z0, Z1}, 0)
	for _, r in dk.rects do clear(r.x, r.z, 2) end
	clear({lk.cx - lk.rx, lk.cx + lk.rx}, {lk.cz - lk.rz, lk.cz + lk.rz}, 4)
	for _, list in {data.parks, data.gardens, data.plazas, data.promenades} do for _, a in list do clear(a.x, a.z, 0) end end
	for _, l in data.landmarks do clear(l.x, l.z, 4) end
	for _, r in data.roads do
		local cl = data.classes[r.c]
		for s = 1, #r.p - 1 do local a, b = r.p[s], r.p[s + 1]; clearCapsule(a[1], a[2], b[1], b[2], cl.w / 2 + cl.p + 5.7) end
	end
	for _, c in data.circuses do clearCapsule(c.x, c.z, c.x, c.z, c.r[2] + 8 + 5.7) end
	local rail = data.rail
	clearCapsule(rail.p[1][1], rail.p[1][2], rail.p[2][1], rail.p[2][2], rail.w / 2 + 5.7)
	task.wait()
	local P = folder(map, "Plots")
	local lotId = 0
	for j = 0, LNZ - 1 do
		for i = 0, LNX - 1 do
			local k = j * LNX + i
			if buffer.readu8(lot, k) == 1 then
				local d = buffer.readu8(ldis, k)
				local function free(ii, jj) local kk = jj * LNX + ii; return buffer.readu8(lot, kk) == 1 and buffer.readu8(ldis, kk) == d end
				local ra = i
				while ra + 1 < LNX and free(ra + 1, j) do ra += 1 end
				local rb = j
				while rb + 1 < LNZ do
					local ok = true
					for ii = i, ra do if not free(ii, rb + 1) then ok = false; break end end
					if not ok then break end
					rb += 1
				end
				local cb = j
				while cb + 1 < LNZ and free(i, cb + 1) do cb += 1 end
				local ca = i
				while ca + 1 < LNX do
					local ok = true
					for jj = j, cb do if not free(ca + 1, jj) then ok = false; break end end
					if not ok then break end
					ca += 1
				end
				local i2, j2 = ra, rb
				if (ca - i + 1) * (cb - j + 1) > (ra - i + 1) * (rb - j + 1) then i2, j2 = ca, cb end
				for jj = j, j2 do local base = jj * LNX; for ii = i, i2 do buffer.writeu8(lot, base + ii, 0) end end
				local x1, x2, z1, z2 = X0 + i * LC, X0 + (i2 + 1) * LC, Z0 + j * LC, Z0 + (j2 + 1) * LC
				local sx, sz = x2 - x1, z2 - z1
				if sx >= 14 and sz >= 14 then
					local dd = data.districts[d]
					local f = dd.f
					local dmax = math.max(36, f * 1.6)
					local alongX = sx >= sz
					local L, S = if alongX then sx else sz, if alongX then sz else sx
					local rows, cols = math.max(1, math.floor(S / dmax + 0.5)), math.max(1, math.floor(L / f + 0.5))
					local base = LOTCOL[dd.lot]
					for rr = 0, rows - 1 do
						for cc = 0, cols - 1 do
							lotId += 1
							local a1, a2, b1, b2 = L * cc / cols, L * (cc + 1) / cols, S * rr / rows, S * (rr + 1) / rows
							local px1, px2, pz1, pz2
							if alongX then px1, px2, pz1, pz2 = x1 + a1, x1 + a2, z1 + b1, z1 + b2
							else px1, px2, pz1, pz2 = x1 + b1, x1 + b2, z1 + a1, z1 + a2 end
							local sh = if (rr + cc) % 2 == 0 then 1 else 0.9
							local p = part(P, "Lot_" .. lotId, px1, px2, -2, 0.6, pz1, pz2, Mt.SmoothPlastic, Color3.new(base.R * sh, base.G * sh, base.B * sh))
							p:SetAttribute("LotId", lotId); p:SetAttribute("District", dd.n); p:SetAttribute("LotType", dd.lot)
							p:SetAttribute("Frontage", math.floor(L / cols)); p:SetAttribute("Depth", math.floor(S / rows))
						end
					end
				end
			end
		end
		if j % 60 == 0 then task.wait() end
	end

	status("water")
	local Wt = folder(map, "Water")
	local mud = rgb(72, 64, 50)
	for _, r in dk.rects do
		part(Wt, "DockBed", r.x[1], r.x[2], dk.bed - 2, dk.bed, r.z[1], r.z[2], Mt.Mud, mud)
		local zl, zh = math.min(r.z[1], r.z[2]), math.max(r.z[1], r.z[2])
		part(Wt, "Quay", r.x[1], r.x[1] + 2, dk.bed, 0.6, zl, zh, Mt.Concrete, rgb(150,144,132))
		part(Wt, "Quay", r.x[2] - 2, r.x[2], dk.bed, 0.6, zl, zh, Mt.Concrete, rgb(150,144,132))
		part(Wt, "Quay", r.x[1] + 2, r.x[2] - 2, dk.bed, 0.6, zl, zl + 2, Mt.Concrete, rgb(150,144,132))
		part(Wt, "Quay", r.x[1] + 2, r.x[2] - 2, dk.bed, 0.6, zh - 2, zh, Mt.Concrete, rgb(150,144,132))
	end
	local wallCol, stone = rgb(150, 144, 132), Mt.Concrete
	tiled(Wt, "RiverBed", rv.x[1], rv.x[2], rv.bed - 4, rv.bed, Z0, Z1, Mt.Mud, mud)
	local bridgeGaps, stairGaps = {}, {}
	for _, b in data.bridges do table.insert(bridgeGaps, {b.z - 20, b.z + 20}) end
	for _, s in w.stairs do table.insert(stairGaps, {s - 10, s}) end
	for _, side in {{RIVER_LO, rv.x[1], RIVER_LO, RIVER_LO + 1}, {rv.x[2], RIVER_HI, RIVER_HI - 1, RIVER_HI}} do
		for _, g in bridgeGaps do part(Wt, "RiverWall", side[1], side[2], rv.bed - 4, -3, g[1], g[2], stone, wallCol) end
		for _, s in spans(Z0, Z1, table.clone(bridgeGaps)) do tiled(Wt, "RiverWall", side[1], side[2], rv.bed - 4, 0, s[1], s[2], stone, wallCol) end
		local gaps = table.clone(bridgeGaps)
		if side[1] < 1200 then for _, g in stairGaps do table.insert(gaps, g) end end
		for _, s in spans(Z0, Z1, gaps) do tiled(Wt, "Parapet", side[3], side[4], 0, 3.5, s[1], s[2], stone, wallCol) end
	end
	local fs = w.foreshore
	part(Wt, "Foreshore", fs.x[1], fs.x[2], rv.bed, fs.top, fs.z[1], fs.z[2], Mt.Mud, rgb(96, 84, 64))
	for _, s in w.stairs do
		part(Wt, "StairLanding", rv.x[1], rv.x[1] + 10, fs.top, 0, s - 10, s, stone, wallCol)
		local wd = Instance.new("WedgePart")
		wd.Name = "Stairs"; wd.Anchored = true; wd.Material = stone; wd.Color = wallCol
		wd.Size = Vector3.new(10, -fs.top, 40)
		wd.CFrame = CFrame.new(rv.x[1] + 5, fs.top / 2, s - 30)
		wd:SetAttribute("Greybox", true)
		wd.Parent = Wt
	end

	status("bridges")
	local BR = folder(map, "Bridges")
	local roadCol, paveCol = TERRAIN_COL[Mt.Cobblestone], TERRAIN_COL[Mt.Pavement]
	local bx1, bx2 = RIVER_LO, RIVER_HI
	for _, b in data.bridges do
		local f = Instance.new("Folder"); f.Name = b.n; f.Parent = BR
		local deck = part(f, "Carriageway", bx1, bx2, -3, 0, b.z - 12, b.z + 12, Mt.Cobblestone, roadCol)
		deck:SetAttribute("Bridge", true)
		for _, sgn in {1, -1} do
			part(f, "Pavement", bx1, bx2, -3, 0.6, b.z + sgn * 12, b.z + sgn * 20, Mt.Pavement, paveCol)
			part(f, "Parapet", bx1, bx2, 0.6, 3.6, b.z + sgn * 19, b.z + sgn * 20, stone, wallCol)
		end
		for _, px in b.towers or {1210, 1300, 1390} do
			local hw = if b.towers then 20 else 6
			part(f, "Pier", px - hw, px + hw, rv.bed - 4, -3, b.z - 30, b.z + 30, stone, wallCol)
		end
		if b.towers then
			for _, px in b.towers do
				for _, sgn in {1, -1} do part(f, "TowerLeg", px - 15, px + 15, 0.6, 40, b.z + sgn * 20.5, b.z + sgn * 31, stone, rgb(170, 160, 140)) end
				tag(part(f, "Tower", px - 15, px + 15, 40, 120, b.z - 31, b.z + 31, stone, rgb(170, 160, 140)), b.n, 46, 2500, 200)
			end
			part(f, "HighWalkway", b.towers[1] + 15, b.towers[2] - 15, 100, 106, b.z - 5, b.z + 5, stone, rgb(120, 140, 160))
		else
			tag(deck, b.n, 8, 900, 200)
		end
	end
	local RF = Instance.new("Folder"); RF.Name = "Hungerford Railway Bridge"; RF.Parent = BR
	local hw, rz = rail.w / 2, rail.p[1][2]
	tag(part(RF, "Viaduct", rail.p[1][1], rail.p[2][1], rail.deck - 4, rail.deck, rz - hw, rz + hw, Mt.Brick, rgb(120, 70, 56)), rail.n, 8, 900, 220)
	for _, sgn in {1, -1} do part(RF, "Parapet", rail.p[1][1], rail.p[2][1], rail.deck, rail.deck + 3, rz + sgn * (hw - 1), rz + sgn * hw, Mt.Brick, rgb(120, 70, 56)) end
	local nPier = 0
	for x = rail.p[1][1] + 30, rail.p[2][1] - 10, 40 do
		local onRoad = false
		for _, sg in buckets[math.floor(x / 100) * 100000 + math.floor(rz / 100)] or {} do
			local dx, dz = sg[3] - sg[1], sg[4] - sg[2]
			local L2 = dx * dx + dz * dz
			local t = if L2 > 0 then math.clamp(((x - sg[1]) * dx + (rz - sg[2]) * dz) / L2, 0, 1) else 0
			if (sg[1] + t * dx - x) ^ 2 + (sg[2] + t * dz - rz) ^ 2 < (sg[5] + 12) ^ 2 then onRoad = true end
		end
		if not onRoad then
			local wet = x > RIVER_LO and x < RIVER_HI
			part(RF, "Pier", x - 4, x + 4, if wet then rv.bed - 4 else -2, rail.deck - 4, rz - hw, rz + hw, Mt.Brick, rgb(110, 64, 50))
			nPier += 1
		end
	end

	status("landmarks")
	local LM = folder(map, "Landmarks_Greybox")
	for _, l in data.landmarks do
		local p = part(LM, l.n, l.x[1], l.x[2], -2, l.h, l.z[1], l.z[2], Mt.SmoothPlastic, rgb(214, 208, 192))
		if l.n:find("Column") or l.n:find("Monument") or l.n:find("Dome") then
			local s = p.Size
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(s.Y, s.X, s.Z)
			p.CFrame = p.CFrame * CFrame.Angles(0, 0, math.pi / 2)
		end
		if not l.n:find("Dome") then tag(p, l.n, l.h / 2 + 8, 1500, 220) end
	end
	for _, c in data.circuses do
		tag(part(LM, c.monument, c.x - 6, c.x + 6, -2, c.h, c.z - 6, c.z + 6, Mt.SmoothPlastic, rgb(214, 208, 192)), c.n, c.h / 2 + 6, 1200, 220)
	end
	local LB = folder(map, "Labels")
	local seen = {}
	for _, a in data.districts do
		if not seen[a.n] then
			seen[a.n] = true
			local x, z = (a.x[1] + a.x[2]) / 2, (a.z[1] + a.z[2]) / 2
			tag(ghost(part(LB, a.n, x - 0.5, x + 0.5, 80, 81, z - 0.5, z + 0.5)), a.n:upper(), 0, 4000, 320)
		end
	end

	status("graph")
	local nNodes, nLinks = buildGraph(data, map)

	status("markers")
	local BS = folder(map, "BusStops")
	local route = Instance.new("Folder"); route.Name = "_Route"; route.Parent = BS
	for i, pt in data.bus.p do ghost(part(route, "W" .. i, pt[1] - 0.5, pt[1] + 0.5, 0, 1, pt[2] - 0.5, pt[2] + 0.5)):SetAttribute("Index", i) end
	for _, s in data.bus.stops do marker(BS, s[1], s[2], s[3], 9, rgb(200, 60, 50)):SetAttribute("BusStop", true) end
	local CR = folder(map, "CabRanks")
	for _, c in data.cabRanks do
		local lx, lz = if c[4] == "x" then 20 else 4, if c[4] == "z" then 20 else 4
		local p = part(CR, c[1], c[2] - lx, c[2] + lx, 0, 0.15, c[3] - lz, c[3] + lz, Mt.SmoothPlastic, rgb(240, 200, 60))
		p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch = 0.5, false, false, false
		tag(p, "Cab rank: " .. c[1], 6, 400, 200)
	end
	local JS = folder(map, "JobSites")
	for _, s in data.spots do marker(JS, s[1], s[2], s[3], 6, rgb(60, 140, 220)) end
	local RT = folder(map, "Routes")
	for _, e in data.events do
		local f = Instance.new("Folder"); f.Name = e.n; f.Parent = RT
		for i, pt in e.p do ghost(part(f, "W" .. i, pt[1] - 0.5, pt[1] + 0.5, 0, 1, pt[2] - 0.5, pt[2] + 0.5)):SetAttribute("Index", i) end
	end
	local BD = folder(map, "Bounds")
	for _, wl in {{X0 - 2, X0, Z0, Z1}, {X1, X1 + 2, Z0, Z1}, {X0, X1, Z0 - 2, Z0}, {X0, X1, Z1, Z1 + 2}} do
		tiled(BD, "Bound", wl[1], wl[2], -40, 300, wl[3], wl[4])
	end
	for _, p in BD:GetChildren() do p.Transparency = 1; p.CanQuery = false end
	status("done")
	return {parts = count, kerbs = nk, lots = lotId, nodes = nNodes, links = nLinks, railPiers = nPier}
end
return M
