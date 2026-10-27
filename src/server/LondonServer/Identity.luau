--!strict
-- LondonServer.Identity: RP names, station roles and overhead tags (M1, DESIGN §5-6.1).
-- Names are saved in the profile (filtered, cooldown after the first pick). Roles are per
-- server (Q4): held in memory, with seat limits and playtime gates from Shared.Stations.
-- Player attributes (read by tags, Roles.roleOf and the client): RPName, Role.
-- Remotes (Identity domain, calls): Get, SetName { first, last }, ChooseRole { role }.
-- Pushes: Identity.State (to one player), Identity.Seats (to everyone, on any seat change).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local Text = require(Shared:WaitForChild("Text"))
local Names = require(Shared:WaitForChild("Names"))
local Stations = require(Shared:WaitForChild("Stations"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))

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

local function nameCooldownLeft(player: Player): number
	local p = Profiles.get(player)
	if not p or p.name.first == "" then
		return 0
	end
	return math.max(0, Config.NAME_CHANGE_COOLDOWN - (os.time() - p.name.changedAt))
end

local function state(player: Player): { [string]: any }
	local p = Profiles.get(player)
	return {
		first = if p then p.name.first else "",
		last = if p then p.name.last else "",
		needsName = rpName(player) == nil,
		nameCooldown = nameCooldownLeft(player),
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
	if roleId ~= Config.DEFAULT_ROLE and not rpName(player) then
		return "Choose your name first."
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

-- Names ---------------------------------------------------------------------------
-- Returns the full name, or nil and a reason.
function Identity.setName(player: Player, first: any, last: any): (string?, string?)
	local p = Profiles.get(player)
	if not p then
		return nil, "Your profile isn't loaded yet."
	end
	local left = nameCooldownLeft(player)
	if left > 0 then
		return nil, string.format("You can change your name again in %d days.", math.ceil(left / 86400))
	end
	local f, whyF = Names.cleanPart(first)
	if not f then
		return nil, whyF
	end
	local l, whyL = Names.cleanPart(last)
	if not l then
		return nil, whyL
	end
	if Names.isBlocked(f, l) then
		return nil, "That's a real person's name. Please pick a fictional one."
	end
	local full = f .. " " .. l
	local filtered = Text.filterBroadcast(full, player.UserId)
	if filtered == nil then
		return nil, "The name check isn't answering. Please try again."
	end
	if filtered ~= full then
		return nil, "That name isn't allowed. Please pick another."
	end
	local firstPick = p.name.first == ""
	p.name = { first = f, last = l, changedAt = if firstPick then 0 else os.time() }
	player:SetAttribute(Identity.NAME_ATTR, full)
	if firstPick then
		Analytics.onboardingStep(player, "Name")
	end
	return full
end

-- Lifecycle --------------------------------------------------------------------------
function Identity.onProfileLoaded(player: Player, profile: any)
	if profile.name.first ~= "" then
		player:SetAttribute(Identity.NAME_ATTR, profile.name.first .. " " .. profile.name.last)
	end
	player:SetAttribute(Roles.ROLE_ATTR, Config.DEFAULT_ROLE)
	if player.Character then
		task.spawn(buildTag, player, player.Character)
	end
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
	Net.handle("Identity", "SetName", {
		schema = { first = V.str(Config.NAME_MAX * 2), last = V.str(Config.NAME_MAX * 2) },
		rate = Config.NAME_RATE,
		call = true,
	}, function(player, a)
		local full, why = Identity.setName(player, a.first, a.last)
		if not full then
			return nil, why
		end
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
