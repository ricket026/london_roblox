--!strict
-- LondonClient.BuildUI (stub): build mode on your property (BUILDING §4). Plain on purpose.
--   Orbit camera round the plot (on-screen ◀ ▶ − +, mouse wheel, Q/E), a catalogue by group,
--   a ghost that snaps to the grid and turns red with the reason when a rule says no (the same
--   Shared.Kit rules the server applies), storey selector, Place / Select modes, rotate (R),
--   paint (palette for the piece's colour slot), delete, undo/redo (Config.BUILD_UNDO steps),
--   publish, exit (saves). Every action has a button, so touch and gamepad work.
--   Drafts (unpublished builds) are rendered here for the owner and builders only; everyone else
--   sees the template the server shows. Published builds are the server's parts.
-- Server: LondonServer.Builds (Build.Enter / Exit / Place / Remove / Move / Paint / Publish /
--   Starter; pushes Build.State, Changed, Notice, Closed).
--   BuildUI.enter(lot), BuildUI.exit(), BuildUI.pick(id), BuildUI.aim(x, z) (lot studs),
--   BuildUI.place(), BuildUI.select(k), BuildUI.remove(), BuildUI.paint(), BuildUI.rotate(n),
--   BuildUI.undo(), BuildUI.redo(), BuildUI.publish(), BuildUI.session() (for tests)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Kit = require(Shared:WaitForChild("Kit"))
local Palette = require(Shared:WaitForChild("Palette"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local BuildUI = {}

local player = Players.LocalPlayer
local ui = EconomyUI.ui
local C = ui.colours

type Op = { kind: string, piece: Kit.Piece?, k: number?, from: Kit.Piece?, to: Kit.Piece? }
type Session = {
	lot: string, frame: Kit.Frame, info: Kit.Lot, build: Kit.Build, canBuild: boolean, canDecorate: boolean,
	storage: { { [string]: any } }, storey: number, mode: string, pick: string?, r: number, c: number,
	aimX: number, aimZ: number, selected: number?, moving: number?, undo: { Op }, redo: { Op },
	remap: { [number]: number }, yaw: number, pitch: number, dist: number,
}

local known: { [string]: { [string]: any } } = {} -- lot -> last Build.State (kept in step by Changed)
local drafts: { [string]: Model } = {} -- lot -> local render of an unpublished build
local draftFolder: Folder
local session: Session? = nil
local ghost: Model? = nil
local ghostOk = false

local gui: ScreenGui
local topLabel: TextLabel
local storeyLabel: TextLabel
local reasonLabel: TextLabel
local catalogue: ScrollingFrame
local groupLabel: TextLabel
local modeButton: TextButton
local groupIndex = 1

-- Lots and drafts --------------------------------------------------------------------------
local function plot(lot: string): Instance?
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	return plots and plots:FindFirstChild(lot)
end

local function setTemplateHidden(lot: string, hidden: boolean)
	local folder = workspace:FindFirstChild("LotTemplates")
	local m = folder and folder:FindFirstChild(lot)
	if not m then
		return
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = if hidden then 1 else 0
			p.CanCollide = not hidden
			p.CanQuery = not hidden
		end
	end
end

local function clearDraft(lot: string)
	local m = drafts[lot]
	if m then
		m:Destroy()
		drafts[lot] = nil
	end
	setTemplateHidden(lot, false)
end

local function drawPiece(lot: string, p: Kit.Piece)
	local m = drafts[lot]
	local pl = plot(lot)
	local f = pl and Kit.lotFrame(pl)
	if not m or not f then
		return
	end
	local old = m:FindFirstChild(tostring(p.k))
	if old then
		old:Destroy()
	end
	Kit.makePiece(p, f, { doorGroup = "draft:" }).Parent = m
end

-- Draws a draft locally (an unpublished build); a published one is the server's to show.
local function refreshDraft(lot: string)
	local st = known[lot]
	if not st or st.build.published then
		clearDraft(lot)
		return
	end
	if drafts[lot] then
		drafts[lot]:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = lot
	m.Parent = draftFolder
	drafts[lot] = m
	for _, p in st.build.pieces do
		drawPiece(lot, p)
	end
	setTemplateHidden(lot, true)
end

local function findPiece(build: Kit.Build, k: number): (Kit.Piece?, number?)
	for i, p in build.pieces do
		if p.k == k then
			return p, i
		end
	end
	return nil, nil
end

local function applyChange(msg: { [string]: any })
	local st = known[msg.lot]
	if not st then
		return
	end
	local b: Kit.Build = st.build
	local wasPublished = b.published
	if type(msg.remove) == "number" then
		local _, i = findPiece(b, msg.remove)
		if i then
			table.remove(b.pieces, i)
		end
		local m = drafts[msg.lot]
		local old = m and m:FindFirstChild(tostring(msg.remove))
		if old then
			old:Destroy()
		end
	end
	if type(msg.add) == "table" then
		local p = msg.add :: Kit.Piece
		local existing, i = findPiece(b, p.k)
		if existing and i then
			b.pieces[i] = p
		else
			table.insert(b.pieces, p)
		end
		b.nextKey = math.max(b.nextKey or 1, p.k + 1)
		if not b.published then
			drawPiece(msg.lot, p)
		end
	end
	b.published = msg.published == true
	if wasPublished ~= b.published then
		refreshDraft(msg.lot)
	end
end

-- Ghost ------------------------------------------------------------------------------------
local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
end

local function storageCount(s: Session, id: string): number
	for _, st in s.storage do
		if st.id == id then
			return st.n
		end
	end
	return 0
end

-- The piece the ghost stands for: the catalogue pick (or the piece being moved) at the aim point.
local function ghostPiece(s: Session): Kit.Piece?
	local id = s.pick
	local c = s.c
	if s.moving then
		local p = findPiece(s.build, s.moving)
		if not p then
			return nil
		end
		id, c = p.id, p.c
	end
	local d0 = id and Kit.PIECES[id]
	if not d0 or not id then
		return nil
	end
	local probe: Kit.Piece = { id = id, x = 0, z = 0, y = s.storey, r = s.r, c = 0, k = 0 }
	local _, _, ew, ed = Kit.footprint(probe)
	local g = Kit.GRID[d0.class]
	local function snap(v: number): number
		return math.floor(v * 2 / g + 0.5) * g
	end
	local y = if d0.class == "outside" then 0 else s.storey
	return { id = id, x = snap(s.aimX - ew / 2), z = snap(s.aimZ - ed / 2), y = y, r = s.r, c = c, k = s.moving or 0 }
end

local function updateGhost()
	clearGhost()
	local s = session
	if not s or s.mode ~= "place" then
		reasonLabel.Text = ""
		return
	end
	local p = ghostPiece(s)
	if not p then
		reasonLabel.Text = if s.moving then "" else "Pick something from the list."
		return
	end
	local good, why = Kit.check(s.build, s.info, p, s.moving)
	local d0 = Kit.PIECES[p.id]
	if good and not d0.starter and not s.moving and storageCount(s, p.id) < 1 then
		good, why = false, "None in storage: buy one from a furniture dealer."
	end
	ghostOk = good
	reasonLabel.Text = if good then "" else tostring(why)
	local m = Kit.makePiece(p, s.frame, { ghost = true })
	if not good then
		for _, part in m:GetDescendants() do
			if part:IsA("BasePart") then
				part.Color = Color3.fromRGB(200, 60, 50)
			end
		end
	end
	m.Name = "BuildGhost"
	m.Parent = draftFolder
	ghost = m
end

-- Camera -----------------------------------------------------------------------------------
local function updateCamera()
	local s = session
	local cam = workspace.CurrentCamera
	if not s or not cam then
		return
	end
	local focus = Kit.toWorld(s.frame, s.info.w / 2, s.storey * Kit.STOREY + 4, s.info.d / 2)
	local yaw, pitch = math.rad(s.yaw), math.rad(s.pitch)
	-- yaw 0 looks from the street into the plot
	local back = -s.frame.inward * math.cos(yaw) + s.frame.right * math.sin(yaw)
	local offset = back * math.cos(pitch) * s.dist + Vector3.yAxis * math.sin(pitch) * s.dist
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(focus + offset, focus)
end

-- World point under a screen position, on the current storey's floor level (lot studs).
local function aimFromScreen(x: number, y: number)
	local s = session
	local cam = workspace.CurrentCamera
	if not s or not cam then
		return
	end
	local ray = cam:ViewportPointToRay(x, y)
	local level = s.frame.origin.Y + s.storey * Kit.STOREY
	if math.abs(ray.Direction.Y) < 1e-4 then
		return
	end
	local t = (level - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return
	end
	local hit = ray.Origin + ray.Direction * t
	local rel = hit - s.frame.origin
	BuildUI.aim(rel:Dot(s.frame.right), rel:Dot(s.frame.inward))
end

-- The piece key under a screen position (published: server parts; draft: local parts).
local function pieceAtScreen(x: number, y: number): number?
	local s = session
	local cam = workspace.CurrentCamera
	if not s or not cam then
		return nil
	end
	local roots: { Instance } = {}
	local props = workspace:FindFirstChild("Properties")
	local served = props and props:FindFirstChild(s.lot)
	if served then
		table.insert(roots, served)
	end
	if drafts[s.lot] then
		table.insert(roots, drafts[s.lot])
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = roots
	local ray = cam:ViewportPointToRay(x, y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	local inst: Instance? = hit and hit.Instance
	while inst and inst.Parent and not (inst.Parent == served or inst.Parent == drafts[s.lot]) do
		inst = inst.Parent
	end
	return if inst then tonumber(inst.Name) else nil
end

-- UI ---------------------------------------------------------------------------------------
local function pieceCount(s: Session): number
	return #s.build.pieces
end

local function refreshTop()
	local s = session
	if not s then
		return
	end
	local pl = plot(s.lot)
	local address = pl and pl:GetAttribute("LotAddress")
	topLabel.Text = string.format("%s · %d/%d pieces%s", if type(address) == "string" then address else s.lot, pieceCount(s), s.info.budget, if s.build.published then "" else " · draft")
	storeyLabel.Text = if s.storey == 0 then "Ground" else "Storey " .. s.storey
	modeButton.Text = if s.mode == "place" then "Place" else "Select"
end

local function renderCatalogue()
	ui.clear(catalogue)
	local s = session
	if not s then
		return
	end
	local group = Kit.GROUPS[groupIndex]
	groupLabel.Text = string.upper(string.sub(group, 1, 1)) .. string.sub(group, 2)
	local o = ui.counter()
	for _, id in Kit.ORDER do
		local d0 = Kit.PIECES[id]
		if d0.group == group then
			local allowed = if d0.class == "furniture" or d0.class == "rug" then s.canDecorate else s.canBuild
			local extra = if d0.starter then "" else string.format(" (%d)", storageCount(s, id))
			local b = ui.button(catalogue, (if s.pick == id then "▸ " else "") .. d0.name .. extra, {
				LayoutOrder = o(),
				Size = UDim2.new(1, 0, 0, 30),
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if allowed then C.INK else C.MUTED,
			})
			b.Activated:Connect(function()
				if allowed then
					BuildUI.pick(id)
				else
					EconomyUI.toast("Your key doesn't let you place that.", true)
				end
			end)
		end
	end
end

local function send(action: string, args: { [string]: any }): (boolean, any)
	local s = session
	if not s then
		return false, "not building"
	end
	args.lot = s.lot
	local ok, res = Net.request("Build", action, args)
	if not ok then
		EconomyUI.toast(tostring(res), true)
	end
	return ok, res
end

local function push(s: Session, op: Op)
	table.insert(s.undo, op)
	if #s.undo > Config.BUILD_UNDO then
		table.remove(s.undo, 1)
	end
	s.redo = {}
end

local function resolve(s: Session, k: number): number
	local seen = 0
	while s.remap[k] and seen < 100 do
		k = s.remap[k]
		seen += 1
	end
	return k
end

-- Actions -----------------------------------------------------------------------------------
function BuildUI.pick(id: string)
	local s = session
	if not s then
		return
	end
	s.pick, s.mode, s.moving, s.selected, s.c = id, "place", nil, nil, 0
	renderCatalogue()
	refreshTop()
	updateGhost()
end

function BuildUI.aim(x: number, z: number)
	local s = session
	if not s then
		return
	end
	s.aimX, s.aimZ = x, z
	updateGhost()
end

function BuildUI.rotate(steps: number)
	local s = session
	if not s then
		return
	end
	local id = if s.moving then (findPiece(s.build, s.moving) or {} :: any).id elseif s.mode == "select" and s.selected then nil else s.pick
	if s.mode == "select" and s.selected then
		local p = findPiece(s.build, s.selected)
		if p then
			local d0 = Kit.PIECES[p.id]
			local turn = if d0.class == "furniture" or d0.class == "rug" then 6 else 1
			local before = table.clone(p)
			local r = (p.r + turn * steps) % (if turn == 6 then 24 else 4)
			if send("Move", { k = p.k, x = p.x, z = p.z, y = p.y, r = r }) then
				push(s, { kind = "move", k = p.k, from = before, to = { id = p.id, x = p.x, z = p.z, y = p.y, r = r, c = p.c, k = p.k } })
			end
		end
		return
	end
	local d0 = id and Kit.PIECES[id]
	local furniture = d0 and (d0.class == "furniture" or d0.class == "rug")
	s.r = (s.r + (if furniture then 6 else 1) * steps) % (if furniture then 24 else 4)
	updateGhost()
end

function BuildUI.setStorey(y: number)
	local s = session
	if not s then
		return
	end
	s.storey = math.clamp(y, 0, s.info.storeys)
	refreshTop()
	updateCamera()
	updateGhost()
end

function BuildUI.place(): number?
	local s = session
	if not s or s.mode ~= "place" then
		return nil
	end
	local p = ghostPiece(s)
	if not p then
		return nil
	end
	if s.moving then
		local before = findPiece(s.build, s.moving)
		local from = before and table.clone(before)
		if send("Move", { k = s.moving, x = p.x, z = p.z, y = p.y, r = p.r }) and from then
			push(s, { kind = "move", k = s.moving, from = from, to = table.clone(p) })
			s.moving, s.mode, s.selected = nil, "select", nil
			refreshTop()
			updateGhost()
			return p.k
		end
		return nil
	end
	local ok, res = send("Place", { id = p.id, x = p.x, z = p.z, y = p.y, r = p.r, c = p.c })
	if not ok then
		return nil
	end
	p.k = res.k
	push(s, { kind = "place", piece = table.clone(p) })
	refreshTop()
	updateGhost()
	return res.k
end

function BuildUI.select(k: number?)
	local s = session
	if not s then
		return
	end
	s.mode, s.selected, s.moving = "select", k, nil
	clearGhost()
	local p = k and findPiece(s.build, k)
	reasonLabel.Text = if p then Kit.PIECES[p.id].name .. " selected" else ""
	refreshTop()
end

function BuildUI.move()
	local s = session
	if not s or not s.selected then
		return
	end
	local p = findPiece(s.build, s.selected)
	if not p then
		return
	end
	s.moving, s.mode, s.r = p.k, "place", p.r
	local x0, z0, x1, z1 = Kit.footprint(p)
	s.aimX, s.aimZ = (x0 + x1) / 2, (z0 + z1) / 2
	updateGhost()
end

function BuildUI.remove()
	local s = session
	if not s or not s.selected then
		return
	end
	local p = findPiece(s.build, s.selected)
	if p and send("Remove", { k = p.k }) then
		push(s, { kind = "remove", piece = table.clone(p) })
		BuildUI.select(nil)
	end
end

-- Next colour in the palette group of the piece's first colour slot.
function BuildUI.paint()
	local s = session
	if not s then
		return
	end
	local target = if s.mode == "select" and s.selected then findPiece(s.build, s.selected) else nil
	local id = if target then target.id else s.pick
	local d0 = id and Kit.PIECES[id]
	if not d0 then
		return
	end
	local group = Palette.GROUPS[d0.slots[1][1]] or {}
	local current = if target then target.c else s.c
	local currentId = if current ~= 0 then (Palette.at(current) or {} :: any).id else d0.slots[1][2]
	local i = table.find(group, currentId) or 0
	local nextId = group[(i % #group) + 1]
	local c = Palette.index(nextId) or 0
	if target then
		local before = table.clone(target)
		if send("Paint", { k = target.k, c = c }) then
			local after = table.clone(target)
			after.c = c
			push(s, { kind = "paint", k = target.k, from = before, to = after })
			EconomyUI.toast(nextId)
		end
	else
		s.c = c
		EconomyUI.toast(nextId)
		updateGhost()
	end
end

local function replay(s: Session, op: Op, forward: boolean): boolean
	if op.kind == "place" or op.kind == "remove" then
		local adding = (op.kind == "place") == forward
		local p = op.piece :: Kit.Piece
		if adding then
			local ok, res = send("Place", { id = p.id, x = p.x, z = p.z, y = p.y, r = p.r, c = p.c })
			if ok then
				s.remap[p.k] = res.k
				p.k = res.k
			end
			return ok
		end
		return (send("Remove", { k = resolve(s, p.k) }))
	end
	local target = (if forward then op.to else op.from) :: Kit.Piece
	local k = resolve(s, op.k :: number)
	if op.kind == "move" then
		return (send("Move", { k = k, x = target.x, z = target.z, y = target.y, r = target.r }))
	end
	return (send("Paint", { k = k, c = target.c }))
end

function BuildUI.undo()
	local s = session
	local op = s and table.remove(s.undo)
	if s and op then
		if replay(s, op, false) then
			table.insert(s.redo, op)
		end
		refreshTop()
		updateGhost()
	end
end

function BuildUI.redo()
	local s = session
	local op = s and table.remove(s.redo)
	if s and op then
		if replay(s, op, true) then
			table.insert(s.undo, op)
		end
		refreshTop()
		updateGhost()
	end
end

function BuildUI.publish()
	if send("Publish", {}) then
		EconomyUI.toast("Published: everyone can see your house.")
	end
end

function BuildUI.session(): Session?
	return session
end

-- Enter / exit -------------------------------------------------------------------------------
function BuildUI.enter(lot: string): boolean
	local pl = plot(lot)
	local f = pl and Kit.lotFrame(pl)
	if not f then
		EconomyUI.toast("That plot isn't ready.", true)
		return false
	end
	local ok, st = Net.request("Build", "Enter", { lot = lot })
	if not ok then
		EconomyUI.toast(tostring(st), true)
		return false
	end
	known[lot] = st
	session = {
		lot = lot, frame = f, info = { w = st.w, d = st.d, storeys = st.storeys, budget = st.budget },
		build = st.build, canBuild = st.canBuild == true, canDecorate = st.canDecorate == true,
		storage = st.storage or {}, storey = 0, mode = "place", pick = nil, r = 0, c = 0,
		aimX = st.w / 2, aimZ = 2, selected = nil, moving = nil, undo = {}, redo = {}, remap = {},
		yaw = 0, pitch = 40, dist = math.max(st.w, st.d) * 1.3,
	}
	groupIndex = if st.canBuild then 1 else table.find(Kit.GROUPS, "furniture") or 1
	refreshDraft(lot)
	gui.Enabled = true
	renderCatalogue()
	refreshTop()
	updateCamera()
	updateGhost()
	return true
end

function BuildUI.exit()
	local s = session
	if not s then
		return
	end
	session = nil
	clearGhost()
	gui.Enabled = false
	Net.request("Build", "Exit", { lot = s.lot })
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "BuildMode"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 14
	gui.Enabled = false
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BackgroundColor3 = C.PAPER
	top.BackgroundTransparency = 0.15
	top.BorderSizePixel = 0
	top.Size = UDim2.new(1, 0, 0, 38)
	top.Parent = gui
	topLabel = ui.text(top, "TextLabel", { Name = "Title", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -470, 0, 30), TextSize = 17 })
	local function topButton(label: string, x: number, w: number, fn: () -> ()): TextButton
		local b = ui.button(top, label, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -x, 0, 4), Size = UDim2.fromOffset(w, 30), TextSize = 16 })
		b.Activated:Connect(fn)
		return b
	end
	topButton("Exit", 8, 64, BuildUI.exit)
	topButton("Publish", 78, 80, BuildUI.publish)
	topButton("+", 164, 30, function()
		local s = session
		if s then
			BuildUI.setStorey(s.storey + 1)
		end
	end)
	storeyLabel = ui.text(top, "TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -198, 0, 4), Size = UDim2.fromOffset(84, 30), TextSize = 16 })
	topButton("−", 286, 30, function()
		local s = session
		if s then
			BuildUI.setStorey(s.storey - 1)
		end
	end)
	topButton("Start again", 322, 110, function()
		local s = session
		if s and send("Starter", { variant = math.random(1, 3) }) then
			s.undo, s.redo = {}, {}
		end
	end)

	local side = Instance.new("Frame")
	side.Name = "Catalogue"
	side.BackgroundColor3 = C.PAPER
	side.BackgroundTransparency = 0.15
	side.BorderSizePixel = 0
	side.Position = UDim2.fromOffset(8, 46)
	side.Size = UDim2.new(0, 190, 1, -146)
	side.Parent = gui
	local prev = ui.button(side, "◀", { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(30, 28) })
	local nextB = ui.button(side, "▶", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(30, 28) })
	groupLabel = ui.text(side, "TextLabel", { Position = UDim2.fromOffset(36, 4), Size = UDim2.new(1, -72, 0, 28), TextSize = 17 })
	prev.Activated:Connect(function()
		groupIndex = (groupIndex - 2) % #Kit.GROUPS + 1
		renderCatalogue()
	end)
	nextB.Activated:Connect(function()
		groupIndex = groupIndex % #Kit.GROUPS + 1
		renderCatalogue()
	end)
	catalogue = Instance.new("ScrollingFrame")
	catalogue.Name = "List"
	catalogue.BackgroundTransparency = 1
	catalogue.BorderSizePixel = 0
	catalogue.Position = UDim2.fromOffset(4, 36)
	catalogue.Size = UDim2.new(1, -8, 1, -40)
	catalogue.AutomaticCanvasSize = Enum.AutomaticSize.Y
	catalogue.CanvasSize = UDim2.new()
	catalogue.ScrollBarThickness = 6
	catalogue.Parent = side
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 3)
	list.Parent = catalogue

	reasonLabel = ui.text(gui, "TextLabel", { Name = "Reason", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 100, 1, -56), Size = UDim2.new(1, -230, 0, 24), TextColor3 = C.ERROR, TextStrokeTransparency = 0.4, TextSize = 17 })
	local bar = Instance.new("Frame")
	bar.Name = "Actions"
	bar.BackgroundColor3 = C.PAPER
	bar.BackgroundTransparency = 0.15
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 8, 1, -8)
	bar.Size = UDim2.new(1, -16, 0, 44)
	bar.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = bar
	local function action(label: string, w: number, fn: () -> ()): TextButton
		local b = ui.button(bar, label, { Size = UDim2.fromOffset(w, 36), TextSize = 16 })
		b.Activated:Connect(fn)
		return b
	end
	modeButton = action("Place", 66, function()
		local s = session
		if s then
			if s.mode == "place" then
				BuildUI.select(nil)
			else
				s.mode = "place"
				refreshTop()
				updateGhost()
			end
		end
	end)
	action("Put", 52, function()
		BuildUI.place()
	end)
	action("Turn", 52, function()
		BuildUI.rotate(1)
	end)
	action("Move", 54, BuildUI.move)
	action("Paint", 54, BuildUI.paint)
	action("Delete", 62, BuildUI.remove)
	action("Undo", 52, BuildUI.undo)
	action("Redo", 52, BuildUI.redo)
	local function cam(label: string, fn: (Session) -> ())
		action(label, 32, function()
			local s = session
			if s then
				fn(s)
				updateCamera()
			end
		end)
	end
	cam("◀", function(s)
		s.yaw -= 30
	end)
	cam("▶", function(s)
		s.yaw += 30
	end)
	cam("−", function(s)
		s.dist = math.min(s.dist * 1.25, 160)
	end)
	cam("+", function(s)
		s.dist = math.max(s.dist / 1.25, 12)
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function BuildUI.init()
	draftFolder = Instance.new("Folder")
	draftFolder.Name = "LocalDrafts"
	draftFolder.Parent = workspace
	build()
	Net.listen("Build", "State", function(msg)
		if type(msg.lot) ~= "string" or type(msg.build) ~= "table" then
			return
		end
		known[msg.lot] = msg
		local s = session
		if s and s.lot == msg.lot then
			s.build = msg.build
			s.storage = msg.storage or s.storage
			s.undo, s.redo = {}, {}
			refreshTop()
			renderCatalogue()
			updateGhost()
		end
		refreshDraft(msg.lot)
	end)
	Net.listen("Build", "Changed", function(msg)
		if type(msg.lot) ~= "string" then
			return
		end
		applyChange(msg)
		local s = session
		if s and s.lot == msg.lot then
			s.build = known[msg.lot].build
			refreshTop()
			updateGhost()
		end
	end)
	Net.listen("Build", "Notice", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)
	Net.listen("Build", "Closed", function(msg)
		local s = session
		if s and s.lot == msg.lot then
			BuildUI.exit()
		end
		known[msg.lot] = nil
		clearDraft(msg.lot)
	end)
	-- the template can come back (the server rebuilds it): keep it hidden under a draft
	task.spawn(function()
		local templates = workspace:WaitForChild("LotTemplates")
		templates.ChildAdded:Connect(function(m)
			if drafts[m.Name] then
				task.defer(setTemplateHidden, m.Name, true)
			end
		end)
	end)
	-- build mode ends with the body (respawn, character switch)
	player.CharacterRemoving:Connect(function()
		BuildUI.exit()
	end)
	-- mouse and touch: aim (and click to put or select)
	UserInputService.InputChanged:Connect(function(input, processed)
		if session and not processed and input.UserInputType == Enum.UserInputType.MouseMovement then
			aimFromScreen(input.Position.X, input.Position.Y)
		elseif session and input.UserInputType == Enum.UserInputType.MouseWheel then
			local s = session :: Session
			s.dist = math.clamp(s.dist * (if input.Position.Z > 0 then 0.85 else 1.15), 12, 160)
			updateCamera()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		local s = session
		if not s or processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if s.mode == "place" then
				aimFromScreen(input.Position.X, input.Position.Y)
				BuildUI.place()
			else
				BuildUI.select(pieceAtScreen(input.Position.X, input.Position.Y))
			end
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(pos, processed)
		local s = session
		if not s or processed then
			return
		end
		if s.mode == "place" then
			aimFromScreen(pos.X, pos.Y) -- touch: tap to aim, then "Put"
		else
			BuildUI.select(pieceAtScreen(pos.X, pos.Y))
		end
	end)
	ContextActionService:BindAction("LondonBuildKeys", function(name, st, input)
		local s = session
		if not s or st ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local key = input.KeyCode
		local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		if key == Enum.KeyCode.R then
			BuildUI.rotate(1)
		elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.E then
			s.yaw += if key == Enum.KeyCode.Q then -30 else 30
			updateCamera()
		elseif key == Enum.KeyCode.Delete or key == Enum.KeyCode.X then
			BuildUI.remove()
		elseif key == Enum.KeyCode.Z and ctrl then
			BuildUI.undo()
		elseif key == Enum.KeyCode.Y and ctrl then
			BuildUI.redo()
		else
			return Enum.ContextActionResult.Pass
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.R, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Delete, Enum.KeyCode.X, Enum.KeyCode.Z, Enum.KeyCode.Y)
end

return BuildUI
