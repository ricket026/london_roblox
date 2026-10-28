--!strict
-- LondonServer.Decrees: royal decrees (COURT_PARLIAMENT §6, TASKS T37). Per server (Q4).
-- The King or Queen issues a decree: a title (≤ Config.DECREE_TITLE_MAX) and text
-- (≤ Config.DECREE_TEXT_MAX), both filtered (fail closed). One decree per Config.DECREE_COOLDOWN
-- in a server. It's shown to everyone as a big banner (with the bell, Config.DECREE_BELL_SOUND),
-- posted on the decree boards (Config.DECREE_BOARDS, newest 3) and kept for the session
-- (Decrees.recent, for the Gazette's front page later).
-- A decree is flavour unless it pulls a lever only the Crown controls (Decrees.LEVERS):
--   "bank_holiday"  job pay ×Config.BANK_HOLIDAY_PAY for one in-game day, once per real day per
--                   server (workspace attribute BankHolidayUntil = server time it ends; Jobs reads it)
-- Later levers (pardon, summon / dissolve Parliament, a ball or procession) register with
-- Decrees.lever(id, def) from their own modules.
-- Remotes (Decree domain, calls): Get, Issue { title, text, lever }.
-- Pushes: Decree.Issued { title, text, by, lever? } (to everyone), Decree.Notice { text }.
--   Decrees.issue(player, title, text, lever) -> ok, why   Decrees.recent() -> { Decree }
--   Decrees.lever(id, { name, check(player) -> why?, apply(player) })   Decrees.holiday() -> bool
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Palette = require(Shared:WaitForChild("Palette"))
local Roles = require(Shared:WaitForChild("Roles"))
local Text = require(Shared:WaitForChild("Text"))
local World = require(script.Parent:WaitForChild("World"))
local AdminLog = require(script.Parent:WaitForChild("AdminLog"))

local Decrees = {}

export type Decree = { title: string, text: string, by: string, lever: string?, at: number }
export type Lever = { name: string, check: ((Player) -> string?)?, apply: (Player) -> () }

Decrees.HOLIDAY_ATTR = "BankHolidayUntil"
Decrees.LEVERS = {} :: { [string]: Lever }
Decrees.ORDER = {} :: { string }

local recent: { Decree } = {}
local lastAt = -math.huge
local boards: { TextLabel } = {}

function Decrees.lever(id: string, def: Lever)
	if not Decrees.LEVERS[id] then
		table.insert(Decrees.ORDER, id)
	end
	Decrees.LEVERS[id] = def
end

function Decrees.recent(): { Decree }
	return recent
end

function Decrees.holiday(): boolean
	local untilT = workspace:GetAttribute(Decrees.HOLIDAY_ATTR)
	return type(untilT) == "number" and workspace:GetServerTimeNow() < untilT
end

local function nameOf(p: Player): string
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

local function utcDay(): number
	return os.time() // 86400
end

-- The bank holiday ------------------------------------------------------------------------
local holidayDay = -1
Decrees.lever("bank_holiday", {
	name = "Declare a bank holiday",
	check = function(): string?
		if holidayDay == utcDay() then
			return "There has been a bank holiday today already."
		end
		return nil
	end,
	apply = function()
		holidayDay = utcDay()
		workspace:SetAttribute(Decrees.HOLIDAY_ATTR, workspace:GetServerTimeNow() + Config.BANK_HOLIDAY_SECONDS)
	end,
})

-- Boards ----------------------------------------------------------------------------------
local function boardText(): string
	if #recent == 0 then
		return "ROYAL DECREES\n\nNone yet this session."
	end
	local parts = { "ROYAL DECREES" }
	for i = 1, math.min(3, #recent) do
		local d = recent[i]
		table.insert(parts, string.format("%s\n%s\n(%s)", string.upper(d.title), d.text, d.by))
	end
	return table.concat(parts, "\n\n")
end

local function refreshBoards()
	local t = boardText()
	for _, l in boards do
		l.Text = t
	end
end

local function buildBoards()
	local folder = World.folder("DecreeBoards")
	for k, b in Config.DECREE_BOARDS do
		local g = World.ground(b.x, b.z)
		local frame = CFrame.new(g) * CFrame.Angles(0, math.rad(b.yaw or 0), 0)
		local model = Instance.new("Model")
		model.Name = "DecreeBoard" .. k
		for _, side in { -1, 1 } do
			local post = World.part({ Name = "Post", Size = Vector3.new(0.4, 7, 0.4), CFrame = frame * CFrame.new(side * 2.3, 3.5, 0), Color = Palette.color("timber_dark"), Material = Enum.Material.Wood })
			post.Parent = model
		end
		local board = World.part({ Name = "Board", Size = Vector3.new(4.4, 3.6, 0.3), CFrame = frame * CFrame.new(0, 4.8, 0), Color = Palette.color("stucco_cream"), Material = Enum.Material.WoodPlanks })
		board.Parent = model
		local head = World.part({ Name = "Head", Size = Vector3.new(4.8, 0.4, 0.5), CFrame = frame * CFrame.new(0, 6.8, 0), Color = Palette.color("livery_royal_red"), Material = Enum.Material.SmoothPlastic })
		head.Parent = model
		local label = World.sign(board, Enum.NormalId.Front, boardText(), Palette.color("iron_black"))
		label.Font = Enum.Font.Garamond
		label.TextWrapped = true
		label.TextYAlignment = Enum.TextYAlignment.Top
		local back = World.sign(board, Enum.NormalId.Back, "By order of the Crown", Palette.color("iron_black"))
		back.TextScaled = true
		model:SetAttribute("Place", b.name)
		model.Parent = folder
		table.insert(boards, label)
	end
end

-- Issuing ---------------------------------------------------------------------------------
function Decrees.cooldown(): number
	return math.max(0, math.ceil(Config.DECREE_COOLDOWN - (os.clock() - lastAt)))
end

function Decrees.issue(player: Player, title: string, text: string, leverId: string?): (boolean, string?)
	local role = Roles.roleOf(player)
	if role ~= "King" and role ~= "Queen" then
		return false, "Only the King or Queen issues decrees."
	end
	if Decrees.cooldown() > 0 then
		return false, string.format("The next decree can be issued in %d s.", Decrees.cooldown())
	end
	local lever = if leverId then Decrees.LEVERS[leverId] else nil
	if leverId and not lever then
		return false, "There's no such decree."
	end
	if lever and lever.check then
		local why = lever.check(player)
		if why then
			return false, why
		end
	end
	local t = Text.sanitize(title, Config.DECREE_TITLE_MAX)
	local body = Text.sanitize(text, Config.DECREE_TEXT_MAX)
	if not t or t == "" or not body or body == "" then
		return false, "A decree needs a title and some words."
	end
	local ft = Text.filterBroadcast(t, player.UserId)
	local fb = Text.filterBroadcast(body, player.UserId)
	if not ft or not fb then
		return false, "The decree couldn't be checked; try again."
	end
	if Decrees.cooldown() > 0 then -- another decree went out while this one was filtered
		return false, "Another decree has just been issued."
	end
	lastAt = os.clock()
	if lever then
		lever.apply(player)
	end
	local style = if role == "King" then "His Majesty the King" else "Her Majesty the Queen"
	local d: Decree = { title = ft, text = fb, by = string.format("%s, %s", nameOf(player), style), lever = leverId, at = os.time() }
	table.insert(recent, 1, d)
	while #recent > Config.DECREE_KEEP do
		table.remove(recent)
	end
	refreshBoards()
	AdminLog.add(player.UserId, "court.decree", nil, ft .. (if leverId then " [" .. leverId .. "]" else ""))
	Net.pushAll("Decree", "Issued", { title = ft, text = fb, by = d.by, lever = leverId, bell = Config.DECREE_BELL_SOUND })
	return true
end

function Decrees.init()
	buildBoards()
	local V = Net.V
	Net.handle("Decree", "Get", { rate = Config.DECREE_RATE, call = true }, function(player)
		local levers = {}
		for _, id in Decrees.ORDER do
			local l = Decrees.LEVERS[id]
			table.insert(levers, { id = id, name = l.name, why = if l.check then l.check(player) else nil })
		end
		local list = {}
		for _, d in recent do
			table.insert(list, { title = d.title, text = d.text, by = d.by })
		end
		return { recent = list, cooldown = Decrees.cooldown(), levers = levers, holiday = Decrees.holiday() }
	end)
	Net.handle("Decree", "Issue", {
		schema = {
			title = V.str(Config.DECREE_TITLE_MAX),
			text = V.str(Config.DECREE_TEXT_MAX),
			lever = V.optional(V.enum(Decrees.ORDER)),
		},
		rate = Config.DECREE_RATE,
		call = true,
	}, function(player, a)
		local good, why = Decrees.issue(player, a.title, a.text, a.lever)
		if not good then
			return nil, why
		end
		return {}
	end)
	Players.PlayerAdded:Connect(function(p)
		if Decrees.holiday() then
			task.delay(5, function()
				if p.Parent == Players and Decrees.holiday() then
					Net.push(p, "Decree", "Notice", { text = "It's a bank holiday: job pay is up today." })
				end
			end)
		end
	end)
end

return Decrees
