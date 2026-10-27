--!strict
-- Activities.Chess: outdoor chess tables by the bandstand (ACTIVITIES §2, wave 1). No money
-- changes hands between players (§1); the game pays a little from Config.CHESS_PAY.
-- Sit at either side; when both seats are taken the game starts. Standing up resigns. The side
-- to move loses on time after Config.CHESS_MOVE_TIMEOUT. Rules: Shared.Chess (server is the
-- authority). Spectators watch the board on the table top; players get LondonClient.Activities.Chess.
-- Remotes: Activity.ChessMove { table, from, to }, Activity.ChessResign { table }.
-- Pushes: Activity.ChessState (full state to both players), Activity.ChessLeave.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Rules = require(Shared:WaitForChild("Chess"))

local ChessActivity = {}
local A: any -- the Activities framework, set in init

type Table = {
	id: number,
	seats: { [string]: Seat }, -- "w" / "b"
	players: { [string]: Player }, -- "w" / "b" while seated
	game: Rules.State?,
	status: string,
	last: { from: number, to: number }?,
	lastMoveAt: number,
	result: string?, -- "w", "b" or "draw" once over
	reason: string?,
	labels: { TextLabel },
	squares: { Frame },
}
local tables: { Table } = {}

local LIGHT = Color3.fromRGB(222, 205, 170)
local DARK = Color3.fromRGB(120, 85, 55)
local HIGHLIGHT = Color3.fromRGB(205, 180, 90)

local function colourOf(t: Table, player: Player): string?
	for c, p in t.players do
		if p == player then
			return c
		end
	end
	return nil
end

local function nameOf(p: Player?): string
	if not p then
		return ""
	end
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

local function render(t: Table)
	local g = t.game
	for i = 1, 64 do
		local piece = if g then g.board[i] else ""
		local l = t.labels[i]
		l.Text = if piece ~= "" then (Config.CHESS_GLYPHS :: any)[string.sub(piece, 2, 2)] or "?" else ""
		l.TextColor3 = if string.sub(piece, 1, 1) == "w" then Color3.fromRGB(250, 248, 240) else Color3.fromRGB(20, 18, 16)
		local f, r = Rules.fileRank(i)
		local base = if (f + r) % 2 == 0 then DARK else LIGHT
		local lit = t.last ~= nil and (t.last.from == i or t.last.to == i)
		t.squares[i].BackgroundColor3 = if lit then HIGHLIGHT else base
	end
end

local function payload(t: Table, forColour: string): { [string]: any }
	local g = t.game
	return {
		table = t.id,
		you = forColour,
		board = if g then g.board else nil,
		turn = if g then g.turn else "w",
		castle = if g then g.castle else nil,
		ep = if g then g.ep else 0,
		halfmove = if g then g.halfmove else 0,
		plies = if g then g.plies else 0,
		status = t.status,
		last = t.last,
		result = t.result,
		reason = t.reason,
		white = nameOf(t.players.w),
		black = nameOf(t.players.b),
		deadline = if g and not t.result then workspace:GetServerTimeNow() + Config.CHESS_MOVE_TIMEOUT - (os.clock() - t.lastMoveAt) else nil,
	}
end

local function push(t: Table)
	render(t)
	for _, c in { "w", "b" } do
		local p = t.players[c]
		if p then
			Net.push(p, "Activity", "ChessState", payload(t, c))
		end
	end
end

local startGame: (t: Table) -> ()

local function finish(t: Table, result: string, reason: string)
	local g = t.game
	if not g or t.result then
		return
	end
	t.result = result
	t.reason = reason
	t.status = "over"
	if g.plies >= Config.CHESS_MIN_PLIES then
		for _, c in { "w", "b" } do
			local p = t.players[c]
			if p then
				local outcome = if result == "draw" then "draw" elseif result == c then "win" else "loss"
				A.reward(p, { activity = "Chess", hobby = "Games", xp = (Config.CHESS_XP :: any)[outcome], pence = (Config.CHESS_PAY :: any)[outcome] })
				if outcome == "win" then
					A.score("Chess", p, 1, "sum")
				end
			end
		end
	end
	push(t)
	task.delay(6, function()
		if t.game == g then
			t.game = nil
			t.last = nil
			render(t)
			startGame(t)
		end
	end)
end

startGame = function(t: Table)
	if t.game or not t.players.w or not t.players.b then
		return
	end
	task.delay(Config.CHESS_START_DELAY, function()
		if t.game or not t.players.w or not t.players.b then
			return
		end
		t.game = Rules.new()
		t.status = "play"
		t.last = nil
		t.result = nil
		t.reason = nil
		t.lastMoveAt = os.clock()
		push(t)
	end)
end

local function leave(t: Table, c: string)
	local p = t.players[c]
	if not p then
		return
	end
	if t.game and not t.result then
		if t.game.plies > 0 then
			finish(t, if c == "w" then "b" else "w", "resigned")
		else
			t.game = nil -- nobody moved yet: just call it off
			t.status = "waiting"
			render(t)
		end
	end
	t.players[c] = nil
	A.release(p, "Chess")
	if p.Parent == Players then
		Net.push(p, "Activity", "ChessLeave", { table = t.id })
	end
	push(t)
end

local function sat(t: Table, c: string)
	local seat = t.seats[c]
	local hum = seat.Occupant
	local player = if hum then Players:GetPlayerFromCharacter(hum.Parent) else nil
	local current = t.players[c]
	if current == player then
		return
	end
	if current then
		leave(t, c)
	end
	if not player or not hum then
		return
	end
	if not A.claim(player, "Chess") then
		hum.Sit = false
		hum.Jump = true
		return
	end
	t.players[c] = player
	t.status = "waiting"
	push(t)
	startGame(t)
end

local function move(player: Player, id: number, from: number, to: number)
	local t = tables[id]
	local g = t and t.game
	if not g or t.result or colourOf(t, player) ~= g.turn then
		return
	end
	if not Rules.isLegal(g, from, to) then
		push(t) -- resync a confused client
		return
	end
	t.game = Rules.apply(g, from, to)
	t.last = { from = from, to = to }
	t.lastMoveAt = os.clock()
	local status = Rules.status(t.game :: Rules.State)
	t.status = status
	if status == "checkmate" then
		finish(t, g.turn, "checkmate")
	elseif Rules.isOver(status) then
		finish(t, "draw", status)
	else
		push(t)
	end
end

local function build(folder: Folder, i: number, pos: Vector3): Table
	local cf = CFrame.new(pos)
	local wood = Color3.fromRGB(95, 65, 40)
	local top = A.part({ Name = "Table" .. i, Size = Vector3.new(4.4, 0.3, 4.4), CFrame = cf * CFrame.new(0, 2.6, 0), Color = wood, Material = Enum.Material.Wood })
	A.part({ Name = "Leg", Size = Vector3.new(0.6, 2.45, 0.6), CFrame = cf * CFrame.new(0, 1.225, 0), Color = wood, Material = Enum.Material.Wood }).Parent = top
	local board = A.part({ Name = "Board", Size = Vector3.new(3.6, 0.06, 3.6), CFrame = cf * CFrame.new(0, 2.78, 0), Color = DARK, Material = Enum.Material.SmoothPlastic, CanCollide = false })
	board.Parent = top
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0.4
	local labels, squares = {}, {}
	for s = 1, 64 do
		local f, r = Rules.fileRank(s)
		local sq = Instance.new("Frame")
		sq.BorderSizePixel = 0
		sq.Size = UDim2.fromScale(1 / 8, 1 / 8)
		sq.Position = UDim2.fromScale((f - 1) / 8, (8 - r) / 8) -- rank 8 at the top edge (far side from white)
		sq.BackgroundColor3 = if (f + r) % 2 == 0 then DARK else LIGHT
		sq.Parent = sg
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.TextScaled = true
		l.TextStrokeTransparency = 0.6
		l.Text = ""
		l.Parent = sq
		labels[s] = l
		squares[s] = sq
	end
	sg.Parent = board
	local function seat(z: number, yaw: number): Seat
		local s = A.part({ ClassName = "Seat", Name = "Seat", Size = Vector3.new(2, 0.4, 2), CFrame = cf * CFrame.new(0, 1.6, z) * CFrame.Angles(0, math.rad(yaw), 0), Color = wood, Material = Enum.Material.Wood }) :: Seat
		s.Parent = top
		return s
	end
	local t: Table = {
		id = i,
		seats = { w = seat(3.3, 0), b = seat(-3.3, 180) },
		players = {},
		game = nil,
		status = "waiting",
		last = nil,
		lastMoveAt = 0,
		labels = labels,
		squares = squares,
	}
	top.Parent = folder
	for _, c in { "w", "b" } do
		local s = t.seats[c]
		s:GetPropertyChangedSignal("Occupant"):Connect(function()
			sat(t, c)
		end)
	end
	return t
end

-- Stands this player up from any table (resigning a game in progress); called on a character switch.
function ChessActivity.leave(player: Player)
	for _, t in tables do
		local c = colourOf(t, player)
		if c then
			leave(t, c)
		end
	end
end

function ChessActivity.init(framework: any)
	A = framework
	local folder = A.site("Chess")
	for i, p in Config.CHESS_TABLES do
		table.insert(tables, build(folder, i, A.ground(p.x, p.z)))
	end
	local first = Config.CHESS_TABLES[1]
	A.board("Chess", "Chess Club", "wins", CFrame.new(A.ground(first.x - 12, first.z))).Parent = folder

	local V = Net.V
	Net.handle("Activity", "ChessMove", { schema = { table = V.int(1, #tables), from = V.int(1, 64), to = V.int(1, 64) }, rate = { count = 4, per = 1 } }, function(player, a)
		move(player, a.table, a.from, a.to)
		return nil
	end)
	Net.handle("Activity", "ChessResign", { schema = { table = V.int(1, #tables) }, rate = { count = 2, per = 1 } }, function(player, a)
		local t = tables[a.table]
		local c = colourOf(t, player)
		if c and t.game and not t.result and t.game.plies > 0 then
			finish(t, if c == "w" then "b" else "w", "resigned")
		end
		return nil
	end)
	-- lose on time
	task.spawn(function()
		while true do
			task.wait(1)
			for _, t in tables do
				local g = t.game
				if g and not t.result and os.clock() - t.lastMoveAt > Config.CHESS_MOVE_TIMEOUT then
					finish(t, if g.turn == "w" then "b" else "w", "time")
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		for _, t in tables do
			local c = colourOf(t, p)
			if c then
				leave(t, c)
			end
		end
	end)
end

return ChessActivity
