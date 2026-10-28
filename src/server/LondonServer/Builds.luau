--!strict
-- LondonServer.Builds: what players build on their plots (BUILDING §3-5). Holds the build of every
-- property shown in this server, renders published builds for everyone (workspace.Properties),
-- sends drafts to the owner and whoever is building, checks every edit with Shared.Kit, and saves
-- builds in their own store (Config.BUILD_STORE, key u_<userId>_<deedId>) only while the owner's
-- profile is open here. A build that failed to load is never saved over.
-- Remotes (Build domain, calls): Enter { lot }, Exit { lot }, Place { lot, id, x, z, y, r, c },
--   Remove { lot, k }, Move { lot, k, x, z, y, r }, Paint { lot, k, c }, Publish { lot },
--   Starter { lot, variant }.
-- Pushes: Build.State { lot, build, ... } (on Enter and to the owner on show), Build.Changed
--   { lot, add?, remove?, published } after each edit, Build.Notice { text }.
--   Builds.show(owner, deed, lotName)   Builds.hide(lotName)   Builds.save(lotName) -> bool
--   Builds.get(lotName) -> Active?      Builds.setHidden(lotName, hidden)
--   Builds.saveOwner(userId)            Builds.dissolve(owner, deedId, lotName?) (selling)
--   Builds.can(player, lotName, perm) -> bool   (set by Property; perm "build" or "decorate")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Kit = require(Shared:WaitForChild("Kit"))
local Items = require(Shared:WaitForChild("Items"))
local Palette = require(Shared:WaitForChild("Palette"))
local Store = require(script.Parent:WaitForChild("Store"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))
local Lots = require(script.Parent:WaitForChild("Lots"))
local World = require(script.Parent:WaitForChild("World"))

local Builds = {}

export type Active = {
	lot: string, owner: number, deedId: string, kind: string, build: Kit.Build,
	model: Model?, dirty: boolean, loadFailed: boolean, hidden: boolean, editors: { [Player]: boolean },
}

local active: { [string]: Active } = {}
local store = Store.open(Config.BUILD_STORE)
local folder: Folder

-- Set by Property (avoids a require cycle): may this player do `perm` on this lot?
Builds.can = function(_player: Player, _lot: string, _perm: string): boolean
	return false
end

local function key(userId: number, deedId: string): string
	return "u_" .. userId .. "_" .. deedId
end

function Builds.lotInfo(lotName: string, kind: string): Kit.Lot
	local l = Lots.get(lotName)
	local k = Config.PROPERTY_KINDS[kind]
	return { w = if l then l.w else 0, d = if l then l.d else 0, storeys = k.storeys, budget = k.budget }
end

function Builds.get(lotName: string): Active?
	return active[lotName]
end

local function ownerPlayer(a: Active): Player?
	return Players:GetPlayerByUserId(a.owner)
end

-- Saved form (BUILDING §5): pieces as { id, x, y, z, r, c }; keys are re-made on load.
local function encode(b: Kit.Build): { [string]: any }
	local pieces = {}
	for k, p in b.pieces do
		pieces[k] = { p.id, p.x, p.y, p.z, p.r, p.c }
	end
	return { v = 1, kind = b.kind, w = b.w, d = b.d, pieces = pieces, published = b.published, faces = b.faces or {} }
end

local function decode(raw: any, kind: string): Kit.Build?
	if type(raw) ~= "table" or type(raw.pieces) ~= "table" then
		return nil
	end
	local b: Kit.Build = { v = 1, kind = kind, w = raw.w or 0, d = raw.d or 0, pieces = {}, nextKey = 1, published = raw.published == true, faces = raw.faces }
	for _, e in raw.pieces do
		if type(e) == "table" and type(e[1]) == "string" then
			table.insert(b.pieces, { id = e[1], x = e[2], y = e[3], z = e[4], r = e[5], c = e[6] or 0, k = b.nextKey })
			b.nextKey += 1
		end
	end
	return b
end

local function itemFor(pieceId: string): string?
	local it = Items.get(pieceId)
	return if it and it.furniture == pieceId then it.id else nil
end

-- Furniture that isn't free goes back to the owner's storage when it leaves the build.
local function toStorage(a: Active, p: Kit.Piece)
	local d0 = Kit.PIECES[p.id]
	local item = itemFor(p.id)
	local owner = ownerPlayer(a)
	if d0 and not d0.starter and item and owner then
		Inventory.add(owner, item, 1, "storage")
	end
end

local function notify(player: Player?, text: string)
	if player then
		Net.push(player, "Build", "Notice", { text = text })
	end
end

-- Rendering ----------------------------------------------------------------------------------
local function lotModel(a: Active): Model
	if a.model and a.model.Parent then
		return a.model
	end
	local m = Instance.new("Model")
	m.Name = a.lot
	m:SetAttribute("Owner", a.owner)
	m.Parent = folder
	a.model = m
	return m
end

local function shown(a: Active): boolean
	return a.build.published and not a.hidden
end

local function renderPiece(a: Active, p: Kit.Piece)
	local l = Lots.get(a.lot)
	if not l or not shown(a) then
		return
	end
	local m = lotModel(a)
	local old = m:FindFirstChild(tostring(p.k))
	if old then
		old:Destroy()
	end
	local pm = Kit.makePiece(p, l.frame, { doorGroup = a.lot .. ":", doorLot = a.lot })
	pm.Parent = m
end

local function unrenderPiece(a: Active, k: number)
	local old = a.model and a.model:FindFirstChild(tostring(k))
	if old then
		old:Destroy()
	end
end

local function renderAll(a: Active)
	if a.model then
		a.model:Destroy()
		a.model = nil
	end
	if not shown(a) then
		Lots.showTemplate(a.lot)
		return
	end
	Lots.hideTemplate(a.lot)
	for _, p in a.build.pieces do
		renderPiece(a, p)
	end
end

-- Who gets draft updates: the owner (they see their draft) and everyone in build mode here.
local function audience(a: Active): { Player }
	local out = {}
	local o = ownerPlayer(a)
	if o then
		table.insert(out, o)
	end
	for p in a.editors do
		if p ~= o and p.Parent == Players then
			table.insert(out, p)
		end
	end
	return out
end

local function state(a: Active, player: Player): { [string]: any }
	local info = Builds.lotInfo(a.lot, a.kind)
	return {
		lot = a.lot,
		build = a.build,
		kind = a.kind,
		storeys = info.storeys,
		budget = info.budget,
		w = info.w,
		d = info.d,
		canBuild = Builds.can(player, a.lot, "build"),
		canDecorate = Builds.can(player, a.lot, "decorate"),
		readOnly = a.loadFailed,
		hidden = a.hidden,
		storage = if ownerPlayer(a) then Inventory.list(ownerPlayer(a) :: Player).storage else {},
	}
end

local function changed(a: Active, delta: { [string]: any })
	delta.lot = a.lot
	delta.published = a.build.published
	for _, p in audience(a) do
		Net.push(p, "Build", "Changed", delta)
	end
end

-- After an edit: a published build that no longer meets the street-front rule becomes a draft.
local function recheck(a: Active)
	if a.build.published then
		local ok, why = Kit.publishable(a.build, Builds.lotInfo(a.lot, a.kind))
		if not ok then
			a.build.published = false
			renderAll(a)
			for _, p in audience(a) do
				notify(p, "This is a draft now; other people see a plain house until it's published. " .. tostring(why))
			end
		end
	end
end

-- Show / hide -------------------------------------------------------------------------------
-- Loads (or starts) the build for a deed and shows it on the lot. Yields (DataStore).
function Builds.show(owner: Player, deed: { [string]: any }, lotName: string)
	local existing = active[lotName]
	if existing and existing.owner == owner.UserId and existing.deedId == deed.id then
		renderAll(existing)
		Net.push(owner, "Build", "State", state(existing, owner)) -- back within the linger
		return
	end
	local l = Lots.get(lotName)
	if not l then
		return
	end
	local kind = deed.kind
	local a: Active = {
		lot = lotName, owner = owner.UserId, deedId = deed.id, kind = kind,
		build = { v = 1, kind = kind, w = l.w, d = l.d, pieces = {}, nextKey = 1, published = false },
		model = nil, dirty = false, loadFailed = false, hidden = false, editors = {},
	}
	active[lotName] = a
	local okGet, raw = pcall(function()
		return store:get(key(owner.UserId, deed.id))
	end)
	if active[lotName] ~= a then
		return -- hidden while loading
	end
	local info = Builds.lotInfo(lotName, kind)
	local loaded = if okGet then decode(raw, kind) else nil
	if not okGet then
		warn("[Builds] load failed for " .. key(owner.UserId, deed.id) .. ": " .. tostring(raw))
		a.loadFailed = true
	elseif not loaded then
		-- never built: start from a starter house, varied by the plot
		for _, p in Kit.starter(kind, l.w, l.d, (l.id % 3) + 1, info.budget) do
			table.insert(a.build.pieces, p)
		end
		a.build.nextKey = #a.build.pieces + 1
		a.build.published = true
		a.dirty = true
	else
		-- fit the saved build to this plot: anything that no longer passes the rules comes out
		a.build.published = loaded.published
		a.build.faces = loaded.faces
		local dropped = 0
		for _, p in loaded.pieces do
			p.k = a.build.nextKey
			if Kit.PIECES[p.id] and Kit.check(a.build, info, p) then
				table.insert(a.build.pieces, p)
				a.build.nextKey += 1
			else
				dropped += 1
				if Kit.PIECES[p.id] then
					toStorage(a, p)
				end
			end
		end
		if dropped > 0 then
			a.dirty = true
			notify(owner, string.format("%d piece(s) didn't fit this plot; furniture went to your storage.", dropped))
		end
		if a.build.published and not Kit.publishable(a.build, info) then
			a.build.published = false
			a.dirty = true
		end
	end
	a.build.w, a.build.d = l.w, l.d
	renderAll(a)
	Net.push(owner, "Build", "State", state(a, owner))
end

function Builds.hide(lotName: string)
	local a = active[lotName]
	if not a then
		return
	end
	active[lotName] = nil
	if a.model then
		a.model:Destroy()
	end
	for p in a.editors do
		Net.push(p, "Build", "Closed", { lot = lotName })
	end
	Lots.showTemplate(lotName)
end

-- Reports (BUILDING §7): the template instead of this build for the rest of the session.
function Builds.setHidden(lotName: string, hidden: boolean)
	local a = active[lotName]
	if a and a.hidden ~= hidden then
		a.hidden = hidden
		renderAll(a)
	end
end

-- Saving -------------------------------------------------------------------------------------
function Builds.save(lotName: string): boolean
	local a = active[lotName]
	if not a or not a.dirty then
		return true
	end
	local owner = ownerPlayer(a)
	if a.loadFailed or not owner or not Profiles.get(owner) then
		return false -- only the server holding the owner's profile writes their builds
	end
	local data = encode(a.build)
	local bytes = #HttpService:JSONEncode(data)
	if bytes > Config.BUILD_MAX_BYTES then
		warn(string.format("[Builds] %s is %d bytes; not saved", lotName, bytes))
		return false
	end
	a.dirty = false
	local okSave, err = pcall(function()
		store:update(key(a.owner, a.deedId), function()
			return data
		end)
	end)
	if not okSave then
		a.dirty = true
		warn("[Builds] save failed for " .. lotName .. ": " .. tostring(err))
	end
	return okSave
end

-- Saves every build of this owner (before their profile is released).
function Builds.saveOwner(userId: number)
	for name, a in active do
		if a.owner == userId then
			Builds.save(name)
		end
	end
end

function Builds.deleteSaved(userId: number, deedId: string)
	pcall(function()
		store:remove(key(userId, deedId))
	end)
end

-- On shutdown: save every changed build, waiting up to Config.CLOSE_SAVE_TIMEOUT.
function Builds.closeAll()
	local pending = 0
	for name in active do
		pending += 1
		task.spawn(function()
			Builds.save(name)
			pending -= 1
		end)
	end
	local deadline = os.clock() + Config.CLOSE_SAVE_TIMEOUT
	while pending > 0 and os.clock() < deadline do
		task.wait()
	end
end

-- Edits --------------------------------------------------------------------------------------
local function find(a: Active, k: number): (Kit.Piece?, number?)
	for i, p in a.build.pieces do
		if p.k == k then
			return p, i
		end
	end
	return nil, nil
end

-- The lot being edited, if this player may edit it with `perm` right now.
local function editable(player: Player, lotName: string, perm: string): (Active?, string?)
	local a = active[lotName]
	if not a or not a.editors[player] then
		return nil, "Open build mode at your property first."
	end
	if a.loadFailed then
		return nil, "This build couldn't be loaded, so it can't be changed this visit."
	end
	local owner = ownerPlayer(a)
	if not owner or not Profiles.get(owner) then
		return nil, "The owner has to be here to change the house."
	end
	if not Builds.can(player, lotName, perm) then
		return nil, if perm == "build" then "You may decorate here, but not build." else "You may not change this house."
	end
	return a, nil
end

local function permFor(id: string): string
	local d0 = Kit.PIECES[id]
	return if d0 and (d0.class == "furniture" or d0.class == "rug") then "decorate" else "build"
end

function Builds.place(player: Player, lotName: string, p: Kit.Piece): (number?, string?)
	local a, why = editable(player, lotName, permFor(p.id))
	if not a then
		return nil, why
	end
	p.k = a.build.nextKey
	local good, reason = Kit.check(a.build, Builds.lotInfo(lotName, a.kind), p)
	if not good then
		return nil, reason
	end
	local d0 = Kit.PIECES[p.id]
	local item = itemFor(p.id)
	if not d0.starter then
		local owner = ownerPlayer(a) :: Player
		if not item or not Inventory.remove(owner, item, 1, "storage") then
			return nil, "There isn't one in storage. Buy one from a furniture dealer."
		end
	end
	table.insert(a.build.pieces, p)
	a.build.nextKey += 1
	a.dirty = true
	renderPiece(a, p)
	recheck(a)
	changed(a, { add = p })
	return p.k
end

function Builds.remove(player: Player, lotName: string, k: number): (boolean, string?)
	local a0 = active[lotName]
	local p0 = a0 and find(a0, k)
	local a, why = editable(player, lotName, if p0 then permFor(p0.id) else "build")
	if not a then
		return false, why
	end
	local p, i = find(a, k)
	if not p or not i then
		return false, "That piece has gone."
	end
	table.remove(a.build.pieces, i)
	toStorage(a, p)
	a.dirty = true
	unrenderPiece(a, k)
	recheck(a)
	changed(a, { remove = k })
	return true
end

function Builds.move(player: Player, lotName: string, k: number, x: number, z: number, y: number, r: number): (boolean, string?)
	local a0 = active[lotName]
	local p0 = a0 and find(a0, k)
	local a, why = editable(player, lotName, if p0 then permFor(p0.id) else "build")
	if not a then
		return false, why
	end
	local p = find(a, k)
	if not p then
		return false, "That piece has gone."
	end
	local moved: Kit.Piece = { id = p.id, x = x, z = z, y = y, r = r, c = p.c, k = k }
	local good, reason = Kit.check(a.build, Builds.lotInfo(lotName, a.kind), moved, k)
	if not good then
		return false, reason
	end
	p.x, p.z, p.y, p.r = x, z, y, r
	a.dirty = true
	renderPiece(a, p)
	recheck(a)
	changed(a, { add = p })
	return true
end

function Builds.paint(player: Player, lotName: string, k: number, c: number): (boolean, string?)
	local a, why = editable(player, lotName, "decorate")
	if not a then
		return false, why
	end
	local p = find(a, k)
	if not p then
		return false, "That piece has gone."
	end
	local painted: Kit.Piece = { id = p.id, x = p.x, z = p.z, y = p.y, r = p.r, c = c, k = k }
	local good, reason = Kit.check(a.build, Builds.lotInfo(lotName, a.kind), painted, k)
	if not good then
		return false, reason
	end
	p.c = c
	a.dirty = true
	renderPiece(a, p)
	changed(a, { add = p })
	return true
end

function Builds.publish(player: Player, lotName: string): (boolean, string?)
	local a, why = editable(player, lotName, "build")
	if not a then
		return false, why
	end
	local good, reason = Kit.publishable(a.build, Builds.lotInfo(lotName, a.kind))
	if not good then
		return false, reason
	end
	if not a.build.published then
		a.build.published = true
		a.dirty = true
		renderAll(a)
		changed(a, {})
	end
	return true
end

-- Start again from a starter house; bought furniture goes back to storage.
function Builds.starter(player: Player, lotName: string, variant: number): (boolean, string?)
	local a, why = editable(player, lotName, "build")
	if not a then
		return false, why
	end
	local l = Lots.get(lotName) :: Lots.Lot
	for _, p in a.build.pieces do
		toStorage(a, p)
	end
	local info = Builds.lotInfo(lotName, a.kind)
	a.build.pieces = Kit.starter(a.kind, l.w, l.d, variant, info.budget)
	a.build.nextKey = #a.build.pieces + 1
	a.build.published = true
	a.dirty = true
	renderAll(a)
	for _, p in audience(a) do
		Net.push(p, "Build", "State", state(a, p))
	end
	return true
end

function Builds.enter(player: Player, lotName: string): ({ [string]: any }?, string?)
	local a = active[lotName]
	if not a then
		return nil, "Nobody's house is shown on this plot."
	end
	if not Builds.can(player, lotName, "build") and not Builds.can(player, lotName, "decorate") then
		return nil, "You haven't a key that lets you build here."
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") or not Lots.inside(lotName, hrp.Position, 12) then
		return nil, "Stand at the property to build."
	end
	a.editors[player] = true
	return state(a, player)
end

function Builds.exit(player: Player, lotName: string)
	local a = active[lotName]
	if a and a.editors[player] then
		a.editors[player] = nil
		task.spawn(Builds.save, lotName)
	end
end

-- Selling or giving up a property: bought furniture back to storage, the saved build deleted.
-- Yields when the build isn't shown here (it's loaded to find the furniture).
function Builds.dissolve(owner: Player, deedId: string, lotName: string?): boolean
	local a = if lotName then active[lotName] else nil
	local pieces: { Kit.Piece } = {}
	if a and a.owner == owner.UserId and a.deedId == deedId then
		if a.loadFailed then
			return false
		end
		pieces = a.build.pieces
		a.build.pieces = {}
		Builds.hide(a.lot)
	else
		local okGet, raw = pcall(function()
			return store:get(key(owner.UserId, deedId))
		end)
		if not okGet then
			return false
		end
		local b = decode(raw, "")
		pieces = if b then b.pieces else {}
	end
	for _, p in pieces do
		local d0 = Kit.PIECES[p.id]
		local item = itemFor(p.id)
		if d0 and not d0.starter and item then
			Inventory.add(owner, item, 1, "storage")
		end
	end
	Builds.deleteSaved(owner.UserId, deedId)
	return true
end

local function result(good: boolean, why: string?): ({}?, string?)
	if good then
		return {}, nil
	end
	return nil, why
end

function Builds.init()
	folder = World.folder("Properties")
	local V = Net.V
	local lotV = V.str(20)
	local half = V.int(-2 * Kit.FRONT_OUT, 400) -- half-studs; the largest plots are under 120 studs
	local rate = Config.BUILD_RATE
	Net.handle("Build", "Enter", { schema = { lot = lotV }, rate = Config.PROPERTY_RATE, call = true }, function(player, args)
		return Builds.enter(player, args.lot)
	end)
	Net.handle("Build", "Exit", { schema = { lot = lotV }, rate = Config.PROPERTY_RATE, call = true }, function(player, args)
		Builds.exit(player, args.lot)
		return {}
	end)
	Net.handle("Build", "Place", {
		schema = { lot = lotV, id = V.str(30), x = half, z = half, y = V.int(0, 8), r = V.int(0, 23), c = V.int(0, #Palette.ORDER) },
		rate = rate,
		call = true,
	}, function(player, args)
		local k, why = Builds.place(player, args.lot, { id = args.id, x = args.x, z = args.z, y = args.y, r = args.r, c = args.c, k = 0 })
		if not k then
			return nil, why
		end
		return { k = k }
	end)
	Net.handle("Build", "Remove", { schema = { lot = lotV, k = V.int(1, 2 ^ 30) }, rate = rate, call = true }, function(player, args)
		local good, why = Builds.remove(player, args.lot, args.k)
		return result(good, why)
	end)
	Net.handle("Build", "Move", {
		schema = { lot = lotV, k = V.int(1, 2 ^ 30), x = half, z = half, y = V.int(0, 8), r = V.int(0, 23) },
		rate = rate,
		call = true,
	}, function(player, args)
		local good, why = Builds.move(player, args.lot, args.k, args.x, args.z, args.y, args.r)
		return result(good, why)
	end)
	Net.handle("Build", "Paint", { schema = { lot = lotV, k = V.int(1, 2 ^ 30), c = V.int(0, #Palette.ORDER) }, rate = rate, call = true }, function(player, args)
		local good, why = Builds.paint(player, args.lot, args.k, args.c)
		return result(good, why)
	end)
	Net.handle("Build", "Publish", { schema = { lot = lotV }, rate = Config.PROPERTY_RATE, call = true }, function(player, args)
		local good, why = Builds.publish(player, args.lot)
		return result(good, why)
	end)
	Net.handle("Build", "Starter", { schema = { lot = lotV, variant = V.int(1, 3) }, rate = Config.PROPERTY_RATE, call = true }, function(player, args)
		local good, why = Builds.starter(player, args.lot, args.variant)
		return result(good, why)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.BUILD_SAVE_SECONDS)
			for name, a in active do
				if a.dirty then
					task.spawn(Builds.save, name)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, a in active do
			a.editors[player] = nil
		end
	end)
end

return Builds
