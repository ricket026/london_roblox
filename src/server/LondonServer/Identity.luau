--!strict
-- LondonServer.Identity: station roles and overhead tags (M1, DESIGN §5-6.1). RP names come
-- from the character being played (LondonServer.Characters sets RPName). Roles are per server
-- (Q4): held in memory, with seat limits and playtime gates from Shared.Stations, and reset to
-- Config.DEFAULT_ROLE whenever the player switches character.
-- Player attributes (read by tags, Roles.roleOf and the client): RPName, Role.
-- Remotes (Identity domain, calls): Get, ChooseRole { role }.
-- Pushes: Identity.State (to one player), Identity.Seats (to everyone, on any seat change).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local Stations = require(Shared:WaitForChild("Stations"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))

local V = Net.V
local Identity = {}
Identity.NAME_ATTR = "RPName"

local holders: { [string]: { Player } } = {} -- roleId -> players holding a limited seat
local switchedAt: { [Player]: number } = {}

local function rpName(player: Player): string?
	local a = player:GetAttribute(Identity.NAME_ATTR)
	return if type(a) == "string" and a ~= "" then a else nil
end

local function seatCounts(): { [string]: number }
	local out = {}
	for id, list in holders do
		out[id] = #list
	end
	return out
end

local function state(player: Player): { [string]: any }
	return {
		hasCharacter = rpName(player) ~= nil,
		role = Roles.roleOf(player),
		roleCooldown = math.max(0, Config.ROLE_SWITCH_COOLDOWN - (os.clock() - (switchedAt[player] or -math.huge))),
		playtime = Profiles.playtime(player),
		seats = seatCounts(),
	}
end

local function pushState(player: Player)
	Net.push(player, "Identity", "State", state(player))
end

-- Overhead tags ----------------------------------------------------------------
local function label(parent: Instance, name: string, y: number, h: number, bold: boolean): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromScale(0, y)
	l.Size = UDim2.fromScale(1, h)
	l.Font = if bold then Enum.Font.GaramondBold else Enum.Font.Garamond
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(240, 232, 214)
	l.TextStrokeTransparency = 0.4
	l.Parent = parent
	return l
end

local function refreshTag(player: Player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("RPTag")
	if not tag then
		return
	end
	local name = tag:FindFirstChild("RPName") :: TextLabel
	local role = tag:FindFirstChild("RPRole") :: TextLabel
	name.Text = rpName(player) or player.DisplayName
	name.TextTransparency = if rpName(player) then 0 else 0.35
	local r = Stations.BY_ID[Roles.roleOf(player)]
	role.Text = if r and r.id ~= Config.DEFAULT_ROLE then r.name else ""
end

local function buildTag(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not head:IsA("BasePart") then
		return
	end
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local old = head:FindFirstChild("RPTag")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "RPTag"
	bb.Size = UDim2.fromScale(Config.TAG_SIZE.w, Config.TAG_SIZE.h)
	bb.StudsOffsetWorldSpace = Vector3.new(0, Config.TAG_OFFSET, 0)
	bb.MaxDistance = Config.TAG_MAX_DISTANCE
	bb.LightInfluence = 0
	label(bb, "RPName", 0, 0.6, true)
	label(bb, "RPRole", 0.6, 0.4, false)
	bb.Adornee = head
	bb.Parent = head
	refreshTag(player)
end

-- Seats --------------------------------------------------------------------------
local function leaveSeat(player: Player)
	local current = Roles.roleOf(player)
	local list = holders[current]
	if list then
		local i = table.find(list, player)
		if i then
			table.remove(list, i)
		end
	end
end

local function setRole(player: Player, roleId: string)
	leaveSeat(player)
	local r = Stations.BY_ID[roleId]
	if r.seats then
		local list = holders[roleId] or {}
		holders[roleId] = list
		table.insert(list, player)
	end
	player:SetAttribute(Roles.ROLE_ATTR, roleId)
	Net.pushAll("Identity", "Seats", { seats = seatCounts() })
end

-- Returns nil if the player may take the role, else the reason.
function Identity.canTake(player: Player, roleId: string): string?
	local r = Stations.BY_ID[roleId]
	if not r or not Stations.selectable(r) then
		return "That role can't be chosen from the menu."
	end
	if Roles.roleOf(player) == roleId then
		return "You already hold that role."
	end
	if not rpName(player) then
		return "Choose a character first."
	end
	local since = os.clock() - (switchedAt[player] or -math.huge)
	if since < Config.ROLE_SWITCH_COOLDOWN then
		return string.format("You can change role again in %d s.", math.ceil(Config.ROLE_SWITCH_COOLDOWN - since))
	end
	if r.minPlaytime and Profiles.playtime(player) < r.minPlaytime then
		return string.format("Needs %d h of playtime.", math.ceil(r.minPlaytime / 3600))
	end
	if r.seats and #(holders[roleId] or {}) >= r.seats then
		return "All seats are taken in this server."
	end
	return nil
end

-- Lifecycle --------------------------------------------------------------------------
-- Back to the default role (frees any limited seat). Called when the character changes, so
-- a seat earned as one character isn't carried into another.
function Identity.resetRole(player: Player)
	if Roles.roleOf(player) ~= Config.DEFAULT_ROLE or player:GetAttribute(Roles.ROLE_ATTR) == nil then
		setRole(player, Config.DEFAULT_ROLE)
	end
	pushState(player)
end

function Identity.onProfileLoaded(player: Player)
	player:SetAttribute(Roles.ROLE_ATTR, Config.DEFAULT_ROLE)
	pushState(player)
end

function Identity.onPlayerRemoving(player: Player)
	local held = Stations.BY_ID[Roles.roleOf(player)]
	leaveSeat(player)
	switchedAt[player] = nil
	if held and held.seats then
		Net.pushAll("Identity", "Seats", { seats = seatCounts() })
	end
end

-- Studio test hook: skips cooldowns and playtime gates.
function Identity.debugSetRole(player: Player, roleId: string): boolean
	if not Stations.BY_ID[roleId] then
		return false
	end
	setRole(player, roleId)
	pushState(player)
	return true
end

function Identity.init()
	Net.handle("Identity", "Get", { call = true }, function(player)
		return state(player)
	end)
	Net.handle("Identity", "ChooseRole", {
		schema = { role = V.enum(Stations.IDS) },
		rate = Config.ROLE_RATE,
		call = true,
	}, function(player, a)
		local why = Identity.canTake(player, a.role)
		if why then
			return nil, why
		end
		setRole(player, a.role)
		switchedAt[player] = os.clock()
		return state(player)
	end)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			buildTag(player, character)
		end)
		player:GetAttributeChangedSignal(Identity.NAME_ATTR):Connect(function()
			refreshTag(player)
		end)
		player:GetAttributeChangedSignal(Roles.ROLE_ATTR):Connect(function()
			refreshTag(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
end

return Identity
