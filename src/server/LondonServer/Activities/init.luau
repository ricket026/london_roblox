--!strict
-- LondonServer.Activities: the shared Activity framework (systems/ACTIVITIES.md §1) and one
-- child module per activity (Ducks, Strength, Mudlark, Chess). Each child returns { init(A) }
-- and builds its own site in workspace.Activities from greybox coordinates in Config.
-- The framework gives every activity:
--   A.claim / A.release / A.current   one activity at a time per player
--   A.reward(player, opts)            pence (capped per hour), hobby XP + level-ups, collection
--   A.score(id, player, n, mode)      per-server daily board + saved personal best
--   A.board(id, title, unit, cframe)  a site board showing today's top names in this server
--   A.ground, A.part, A.prompt, A.notice   building and messaging helpers
-- Client: LondonClient.Activities (reward toasts) + per-activity UI modules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Money = require(Shared:WaitForChild("Money"))
local Hobbies = require(Shared:WaitForChild("Hobbies"))
local Collection = require(Shared:WaitForChild("Collection"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))

local A = {}
A.MODULES = { "Ducks", "Strength", "Mudlark", "Chess" }

export type RewardOpts = {
	activity: string, -- activity id, for analytics
	hobby: string?,
	xp: number?,
	pence: number?,
	items: { string }?, -- Shared.Collection ids
}

local root: Folder
local busy: { [Player]: string } = {}
local payWindow: { [Player]: { t: number, paid: number } } = {}
type BoardEntry = { userId: number, name: string, score: number }
local boards: { [string]: { title: string, unit: string, rows: { BoardEntry }, labels: { TextLabel } } } = {}
local boardDay = os.date("!%Y%m%d")

-- One activity at a time -------------------------------------------------------------
function A.current(player: Player): string?
	return busy[player]
end

function A.claim(player: Player, id: string): boolean
	local cur = busy[player]
	if cur and cur ~= id then
		A.notice(player, "Finish what you're doing first.")
		return false
	end
	busy[player] = id
	return true
end

function A.release(player: Player, id: string)
	if busy[player] == id then
		busy[player] = nil
	end
end

-- Rewards --------------------------------------------------------------------------------
function A.notice(player: Player, text: string)
	Net.push(player, "Activity", "Notice", { text = text })
end

-- Pence this player may still earn from activities this hour.
local function payRoom(player: Player): number
	local w = payWindow[player]
	local now = os.clock()
	if not w or now - w.t >= 3600 then
		w = { t = now, paid = 0 }
		payWindow[player] = w
	end
	return math.max(0, Config.ACTIVITY_PAY_PER_HOUR - w.paid)
end

function A.reward(player: Player, opts: RewardOpts)
	local p = Profiles.get(player)
	if not p then
		return
	end
	local msg: { [string]: any } = { activity = opts.activity }
	local pence = math.min(math.floor(opts.pence or 0), payRoom(player))
	if pence > 0 and Profiles.addPence(player, pence) then
		payWindow[player].paid += pence
		msg.pence = Money.format(pence)
	elseif (opts.pence or 0) > 0 then
		msg.capped = true -- the hourly activity cap is reached; XP and finds still count
	end
	if opts.hobby and Hobbies.isHobby(opts.hobby) and (opts.xp or 0) > 0 then
		local before = p.hobbies[opts.hobby] or 0
		local after = before + math.floor(opts.xp :: number)
		p.hobbies[opts.hobby] = after
		msg.hobby = opts.hobby
		msg.xp = after - before
		msg.level = Hobbies.level(after)
		msg.levelUp = Hobbies.level(before) < msg.level
	end
	if opts.items then
		local found = {}
		for _, id in opts.items do
			local it = Collection.BY_ID[id]
			if it then
				local n = (p.collection[id] or 0) + 1
				p.collection[id] = n
				table.insert(found, { name = it.name, page = it.page, new = n == 1 })
			end
		end
		msg.items = found
	end
	Analytics.event(player, "Activity_" .. opts.activity)
	Net.push(player, "Activity", "Reward", msg)
end

-- Boards ---------------------------------------------------------------------------------
local function renderBoard(id: string)
	local b = boards[id]
	if not b then
		return
	end
	for i, l in b.labels do
		local row = b.rows[i]
		l.Text = if row then string.format("%d.  %s — %d %s", i, row.name, row.score, b.unit) else ""
	end
end

local function rollDay()
	local today = os.date("!%Y%m%d")
	if today ~= boardDay then
		boardDay = today
		for id, b in boards do
			b.rows = {}
			renderBoard(id)
		end
	end
end

-- mode "max": keep each player's best; "sum": add up (e.g. wins today).
function A.score(id: string, player: Player, n: number, mode: string)
	rollDay()
	local p = Profiles.get(player)
	if p and mode == "max" and n > (p.bests[id] or -math.huge) then
		p.bests[id] = n
	end
	local b = boards[id]
	if not b then
		return
	end
	local name = player:GetAttribute("RPName")
	local entry: BoardEntry? = nil
	for _, r in b.rows do
		if r.userId == player.UserId then
			entry = r
		end
	end
	if not entry then
		local e: BoardEntry = { userId = player.UserId, name = "", score = if mode == "max" then -math.huge else 0 }
		table.insert(b.rows, e)
		entry = e
	end
	local e = entry :: BoardEntry
	e.name = if type(name) == "string" then name else player.DisplayName
	e.score = if mode == "max" then math.max(e.score, n) else e.score + n
	table.sort(b.rows, function(x, y)
		return x.score > y.score
	end)
	renderBoard(id)
end

-- A notice board facing along cframe.LookVector, showing today's top names in this server.
function A.board(id: string, title: string, unit: string, cframe: CFrame)
	local part = A.part({ Name = "Board", Size = Vector3.new(7, 5, 0.4), CFrame = cframe * CFrame.new(0, 3.5, 0), Color = Color3.fromRGB(70, 48, 30), Material = Enum.Material.Wood })
	A.part({ Name = "Post", Size = Vector3.new(0.4, 3.5, 0.4), CFrame = cframe * CFrame.new(0, 1.0, 0.4), Color = Color3.fromRGB(50, 34, 22), Material = Enum.Material.Wood }).Parent = part
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local function line(text: string, size: number, order: number): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, size + 10)
		l.Font = Enum.Font.Garamond
		l.TextSize = size
		l.TextColor3 = Color3.fromRGB(240, 228, 200)
		l.Text = text
		l.LayoutOrder = order
		l.Parent = gui
		return l
	end
	line(title, 34, 0)
	line("Today in this server", 22, 1)
	local labels = {}
	for i = 1, Config.ACTIVITY_BOARD_SIZE do
		table.insert(labels, line("", 24, 1 + i))
	end
	gui.Parent = part
	boards[id] = { title = title, unit = unit, rows = {}, labels = labels }
	renderBoard(id)
	return part
end

-- Building helpers ----------------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Ground point under (x, z), ignoring map markers, characters and other activity props.
function A.ground(x: number, z: number): Vector3
	local skip: { Instance } = { root }
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, name in { "JobSites", "Labels", "CabRanks", "BusStops", "Routes", "Bounds", "Spawns", "Landmarks_Greybox" } do
			local f = map:FindFirstChild(name)
			if f then
				table.insert(skip, f)
			end
		end
	end
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(skip, plr.Character)
		end
	end
	rayParams.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rayParams)
	return if hit then hit.Position else Vector3.new(x, 0, z)
end

-- Anchored part with properties; parent defaults to nothing (set .Parent or use A.site).
function A.part(props: { [string]: any }): BasePart
	local cls = props.ClassName or "Part"
	local p: any = Instance.new(cls)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "ClassName" then
			p[k] = v
		end
	end
	return p
end

-- A folder for one activity's site inside workspace.Activities.
function A.site(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

function A.prompt(parent: Instance, action: string, object: string, hold: number?): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

-- Is the player's character within `range` studs of a point?
function A.near(player: Player, pos: Vector3, range: number): boolean
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and hrp:IsA("BasePart") and (hrp.Position - pos).Magnitude <= range
end

function A.onPlayerRemoving(player: Player)
	busy[player] = nil
	payWindow[player] = nil
end

function A.init()
	root = Instance.new("Folder")
	root.Name = "Activities"
	root.Parent = workspace
	Net.domain("Activity")
	for _, name in A.MODULES do
		local ok, err = pcall(function()
			require(script:WaitForChild(name) :: ModuleScript).init(A)
		end)
		if not ok then
			warn(string.format("[Activities] %s failed to start: %s", name, tostring(err)))
		end
	end
end

return A
