--!strict
-- LondonServer.ThroneRoom: throne room protocol and the audience queue (COURT_PARLIAMENT §4,
-- TASKS T36). Per server. The room is the part Config.THRONE_ROOM_ZONE under
-- Workspace.PalaceInteriors.ThroneRoom.Gameplay.
-- States, set by the King or Queen or the Lord Chamberlain (or, with no Lord Chamberlain, the
-- senior royal): workspace.PalaceInteriors.ThroneRoom attribute "Protocol"
--   "Open"     anyone may come in and talk.
--   "Closed"   only the Household (King, Queen, royal family, Lord Chamberlain, Private Secretary,
--              Equerries) and invited guests; anyone else in the room is shown out to
--              Config.THRONE_ROOM_EXIT.
--   "Session"  the court is sitting: inside the room only the Monarch and whoever has the floor
--              are heard (chat in RBXGeneral via ShouldDeliverCallback, and quick phrases via
--              Speech.allow); those outside aren't heard inside. Speaking out of turn earns a
--              warning; after Config.CONTEMPT_WARNINGS the next is shown out (contempt, LAW §2 later).
-- The floor: one player at a time, for Config.FLOOR_SECONDS (Extend adds as much again).
-- Audiences: at the audience book by the door (Config.THRONE_ROOM_LEDGER, a prompt) a player asks
--   for an audience with a reason (filtered). Those who preside see the queue: Call (the
--   petitioner is announced in the room, becomes a guest, is shown the mark before the thrones and
--   given the floor), Decline, or Up (move up the queue).
-- Remotes (Room domain, calls): Get, SetState { state }, Request { reason }, Withdraw, Call
--   { target }, Decline { target }, Up { target }, GiveFloor { target }, Extend, TakeFloor,
--   Invite { target }, Uninvite { target }.
-- Pushes: Room.State { state, floor?, floorEnds? } (everyone), Room.Queue (to those who preside),
--   Room.Ask (open the reason box: to one player), Room.Called { text } (to those in the room),
--   Room.Mark { pos } (to the petitioner), Room.Warn { text }, Room.Notice { text }.
--   ThroneRoom.inside(player) -> bool   ThroneRoom.state() -> string   ThroneRoom.maySpeak(player)
--   ThroneRoom.shouldDeliver(speaker, listener) -> bool   ThroneRoom.presides(player) -> bool
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Palette = require(Shared:WaitForChild("Palette"))
local Roles = require(Shared:WaitForChild("Roles"))
local Text = require(Shared:WaitForChild("Text"))
local World = require(script.Parent:WaitForChild("World"))
local Identity = require(script.Parent:WaitForChild("Identity"))
local AdminLog = require(script.Parent:WaitForChild("AdminLog"))
local Speech = require(script.Parent:WaitForChild("Speech"))

local ThroneRoom = {}

ThroneRoom.STATES = { "Open", "Closed", "Session" }
local HOUSEHOLD = { King = true, Queen = true, Royal = true, LordChamberlain = true, PrivateSecretary = true, Equerry = true }

type Petition = { player: Player, reason: string, at: number }

local protocol = "Open"
local queue: { Petition } = {}
local guests: { [Player]: boolean } = {}
local floor: Player? = nil
local floorEnds = 0
local floorStamp = 0
local warnings: { [Player]: number } = {}
local room: Instance? = nil
local zone: BasePart? = nil

local function nameOf(p: Player): string
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

local function rootOf(p: Player): BasePart?
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp else nil
end

local function vec(t: { x: number, y: number, z: number }): Vector3
	return Vector3.new(t.x, t.y, t.z)
end

function ThroneRoom.state(): string
	return protocol
end

function ThroneRoom.inside(p: Player): boolean
	local z, hrp = zone, rootOf(p)
	if not z or not hrp then
		return false
	end
	local rel = z.CFrame:PointToObjectSpace(hrp.Position)
	local h = z.Size / 2
	return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y + 4 and math.abs(rel.Z) <= h.Z
end

-- The King or Queen, the Lord Chamberlain, or with no Lord Chamberlain the senior royal.
function ThroneRoom.presides(p: Player): boolean
	local role = Roles.roleOf(p)
	if role == "King" or role == "Queen" or role == "LordChamberlain" then
		return true
	end
	return #Identity.holdersOf("LordChamberlain") == 0 and Identity.holdersOf("Royal")[1] == p
end

local function admitted(p: Player): boolean
	return HOUSEHOLD[Roles.roleOf(p)] == true or guests[p] == true
end

function ThroneRoom.maySpeak(p: Player): boolean
	if protocol ~= "Session" or not ThroneRoom.inside(p) then
		return true
	end
	local role = Roles.roleOf(p)
	return role == "King" or role == "Queen" or floor == p
end

-- Chat delivery while in session: a speaker in the room is heard only with leave to speak; those
-- outside aren't heard inside.
function ThroneRoom.shouldDeliver(speaker: Player?, listener: Player?): boolean
	if protocol ~= "Session" or not speaker or not listener then
		return true
	end
	if ThroneRoom.inside(speaker) then
		return ThroneRoom.maySpeak(speaker)
	end
	return not ThroneRoom.inside(listener)
end

local function showOut(p: Player, why: string)
	local hrp = rootOf(p)
	if hrp and p.Character then
		p.Character:PivotTo(CFrame.new(vec(Config.THRONE_ROOM_EXIT)))
	end
	Net.push(p, "Room", "Notice", { text = why })
end

local function view(p: Player): { [string]: any }
	local out: { [string]: any } = {
		state = protocol,
		floor = if floor then nameOf(floor) else nil,
		floorSeconds = if floor then math.max(0, math.ceil(floorEnds - os.clock())) else nil,
		presides = ThroneRoom.presides(p),
		inside = ThroneRoom.inside(p),
		guest = guests[p] == true,
	}
	if out.presides then
		local q = {}
		for _, e in queue do
			table.insert(q, { userId = e.player.UserId, name = nameOf(e.player), reason = e.reason })
		end
		out.queue = q
		local here = {}
		for _, o in Players:GetPlayers() do
			if o ~= p and ThroneRoom.inside(o) then
				table.insert(here, { userId = o.UserId, name = nameOf(o), guest = guests[o] == true })
			end
		end
		out.here = here
	else
		for i, e in queue do
			if e.player == p then
				out.place = i
			end
		end
	end
	return out
end

local function pushState()
	Net.pushAll("Room", "State", { state = protocol, floor = if floor then nameOf(floor) else nil, floorSeconds = if floor then math.max(0, math.ceil(floorEnds - os.clock())) else nil })
	for _, p in Players:GetPlayers() do
		if ThroneRoom.presides(p) then
			Net.push(p, "Room", "Queue", view(p))
		end
	end
end

local function toRoom(text: string)
	for _, p in Players:GetPlayers() do
		if ThroneRoom.inside(p) then
			Net.push(p, "Room", "Called", { text = text })
		end
	end
end

-- States ----------------------------------------------------------------------------------
function ThroneRoom.setState(by: Player, state: string): (boolean, string?)
	if not ThroneRoom.presides(by) then
		return false, "Only the King or Queen or the Lord Chamberlain sets the protocol."
	end
	if not table.find(ThroneRoom.STATES, state) then
		return false, "No such state."
	end
	protocol = state
	if room then
		room:SetAttribute("Protocol", state)
	end
	warnings = {}
	AdminLog.add(by.UserId, "court.protocol", nil, state)
	toRoom(if state == "Session" then "The court is in session. Speak only when given the floor." elseif state == "Closed" then "The throne room is closed to all but the Household and guests." else "The throne room is open.")
	pushState()
	return true
end

-- The floor -------------------------------------------------------------------------------
local function endFloor()
	floor = nil
	floorStamp += 1
	pushState()
end

function ThroneRoom.giveFloor(by: Player, target: Player, seconds: number?): (boolean, string?)
	if not ThroneRoom.presides(by) then
		return false, "Only those who preside give the floor."
	end
	if target.Parent ~= Players or not ThroneRoom.inside(target) then
		return false, "They must be in the throne room."
	end
	floor = target
	floorEnds = os.clock() + (seconds or Config.FLOOR_SECONDS)
	floorStamp += 1
	local stamp = floorStamp
	task.delay(seconds or Config.FLOOR_SECONDS, function()
		if floorStamp == stamp and os.clock() >= floorEnds - 0.01 then
			endFloor()
		end
	end)
	Net.push(target, "Room", "Notice", { text = string.format("You have the floor for %d minutes.", math.ceil((seconds or Config.FLOOR_SECONDS) / 60)) })
	pushState()
	return true
end

function ThroneRoom.extend(by: Player): (boolean, string?)
	if not ThroneRoom.presides(by) or not floor then
		return false, "Nobody has the floor."
	end
	local holder = floor :: Player
	return ThroneRoom.giveFloor(by, holder, math.max(0, floorEnds - os.clock()) + Config.FLOOR_SECONDS)
end

function ThroneRoom.takeFloor(by: Player): (boolean, string?)
	if not ThroneRoom.presides(by) or not floor then
		return false, "Nobody has the floor."
	end
	endFloor()
	return true
end

-- Speaking out of turn in session.
function ThroneRoom.outOfTurn(p: Player)
	local n = (warnings[p] or 0) + 1
	warnings[p] = n
	if n > Config.CONTEMPT_WARNINGS then
		warnings[p] = 0
		AdminLog.add(p.UserId, "court.contempt", nil, "shown out of the throne room")
		showOut(p, "You were shown out for speaking out of turn while the court sat.")
		return
	end
	Net.push(p, "Room", "Warn", { text = string.format("The court is in session: wait to be given the floor (warning %d of %d).", n, Config.CONTEMPT_WARNINGS) })
end

-- Guests and audiences --------------------------------------------------------------------
function ThroneRoom.invite(by: Player, target: Player, yes: boolean): (boolean, string?)
	if not ThroneRoom.presides(by) then
		return false, "Only those who preside invite guests."
	end
	guests[target] = if yes then true else nil
	Net.push(target, "Room", "Notice", { text = if yes then "You're invited into the throne room." else "Your invitation to the throne room is withdrawn." })
	pushState()
	return true
end

local function near(p: Player, pos: Vector3, range: number): boolean
	local hrp = rootOf(p)
	return hrp ~= nil and (hrp.Position - pos).Magnitude <= range
end

function ThroneRoom.request(p: Player, reason: string): (boolean, string?)
	if p:GetAttribute("CharSlot") == nil then
		return false, "Choose a character first."
	end
	if not near(p, vec(Config.THRONE_ROOM_LEDGER), 16) then
		return false, "Ask at the audience book by the throne room door."
	end
	for _, e in queue do
		if e.player == p then
			return false, "You're waiting for an audience already."
		end
	end
	if #queue >= Config.AUDIENCE_QUEUE_MAX then
		return false, "The queue is full; try again later."
	end
	local clean = Text.filterBroadcast(reason, p.UserId)
	if not clean or clean == "" then
		return false, "Your reason couldn't be checked; try again."
	end
	table.insert(queue, { player = p, reason = clean, at = os.clock() })
	Net.push(p, "Room", "Notice", { text = string.format("You're number %d in the queue for an audience.", #queue) })
	pushState()
	return true
end

local function take(target: Player): Petition?
	for i, e in queue do
		if e.player == target then
			table.remove(queue, i)
			return e
		end
	end
	return nil
end

function ThroneRoom.withdraw(p: Player): boolean
	local e = take(p)
	pushState()
	return e ~= nil
end

function ThroneRoom.call(by: Player, target: Player): (boolean, string?)
	if not ThroneRoom.presides(by) then
		return false, "Only those who preside call petitioners."
	end
	local e = take(target)
	if not e then
		return false, "They aren't in the queue."
	end
	guests[target] = true
	local text = string.format("%s, for an audience: \"%s\"", nameOf(target), e.reason)
	toRoom(text)
	Net.push(target, "Room", "Called", { text = "You are called: go to the mark before the thrones, bow, and speak." })
	Net.push(target, "Room", "Mark", { pos = vec(Config.THRONE_ROOM_MARK) })
	floor = target
	floorEnds = os.clock() + Config.FLOOR_SECONDS
	floorStamp += 1
	local stamp = floorStamp
	task.delay(Config.FLOOR_SECONDS, function()
		if floorStamp == stamp then
			endFloor()
		end
	end)
	AdminLog.add(by.UserId, "court.audience", target.UserId, e.reason)
	pushState()
	return true
end

function ThroneRoom.decline(by: Player, target: Player): (boolean, string?)
	if not ThroneRoom.presides(by) then
		return false, "Only those who preside decline petitioners."
	end
	if not take(target) then
		return false, "They aren't in the queue."
	end
	Net.push(target, "Room", "Notice", { text = "Your audience was declined today." })
	pushState()
	return true
end

function ThroneRoom.up(by: Player, target: Player): (boolean, string?)
	if not ThroneRoom.presides(by) then
		return false, "Only those who preside order the queue."
	end
	for i, e in queue do
		if e.player == target and i > 1 then
			queue[i], queue[i - 1] = queue[i - 1], e
			pushState()
			return true
		end
	end
	return false, "They're at the front already."
end

-- Every second: those not admitted are shown out of a closed room.
local function sweep()
	if protocol ~= "Closed" then
		return
	end
	for _, p in Players:GetPlayers() do
		if ThroneRoom.inside(p) and not admitted(p) then
			showOut(p, "The throne room is closed to all but the Household and invited guests.")
		end
	end
end

local function buildLedger()
	local folder = World.folder("ThroneRoomProps")
	local pos = vec(Config.THRONE_ROOM_LEDGER)
	local stand = World.part({ Name = "AudienceBook", Size = Vector3.new(1.6, 3.4, 1.2), CFrame = CFrame.new(pos + Vector3.new(0, 1.7, 0)), Color = Palette.color("timber_dark"), Material = Enum.Material.Wood })
	stand.Parent = folder
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Ask for an audience"
	pp.ObjectText = "Audience book"
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Parent = stand
	pp.Triggered:Connect(function(p)
		Net.push(p, "Room", "Ask", { max = Config.AUDIENCE_REASON_MAX })
	end)
	local mark = World.part({ Name = "Mark", Size = Vector3.new(3, 0.1, 3), CFrame = CFrame.new(vec(Config.THRONE_ROOM_MARK) + Vector3.new(0, 0.05, 0)), Color = Palette.color("gilt"), Material = Enum.Material.Metal, CanCollide = false })
	mark.Parent = folder
end

local function hookChat()
	local channels = TextChatService:WaitForChild("TextChannels", 30)
	local general = channels and channels:WaitForChild("RBXGeneral", 30)
	if not general or not general:IsA("TextChannel") then
		return
	end
	local warned: { [string]: boolean } = {}
	general.ShouldDeliverCallback = function(message: TextChatMessage, target: TextSource): boolean
		local from = message.TextSource
		local speaker = if from then Players:GetPlayerByUserId(from.UserId) else nil
		local listener = Players:GetPlayerByUserId(target.UserId)
		local deliver = ThroneRoom.shouldDeliver(speaker, listener)
		if not deliver and speaker and ThroneRoom.inside(speaker) and not warned[message.MessageId] then
			warned[message.MessageId] = true
			task.defer(ThroneRoom.outOfTurn, speaker)
		end
		return deliver or speaker == listener
	end
end

function ThroneRoom.init()
	local rooms = workspace:FindFirstChild("PalaceInteriors")
	room = rooms and rooms:FindFirstChild("ThroneRoom")
	local gameplay = room and room:FindFirstChild("Gameplay")
	local z = gameplay and gameplay:FindFirstChild(Config.THRONE_ROOM_ZONE)
	zone = if z and z:IsA("BasePart") then z else nil
	if not zone then
		print("[ThroneRoom] no PalaceInteriors.ThroneRoom.Gameplay." .. Config.THRONE_ROOM_ZONE .. ": protocol off")
	end
	if room then
		room:SetAttribute("Protocol", protocol)
	end
	buildLedger()
	Speech.allow = function(p: Player): boolean
		if ThroneRoom.maySpeak(p) then
			return true
		end
		ThroneRoom.outOfTurn(p)
		return false
	end
	task.spawn(hookChat)

	local V = Net.V
	local rate = Config.AUDIENCE_RATE
	local function reply(good: boolean, why: string?): (any, string?)
		if not good then
			return nil, why
		end
		return {}
	end
	Net.handle("Room", "Get", { rate = rate, call = true }, function(p)
		return view(p)
	end)
	Net.handle("Room", "SetState", { schema = { state = V.enum(ThroneRoom.STATES) }, rate = rate, call = true }, function(p, a)
		return reply(ThroneRoom.setState(p, a.state))
	end)
	Net.handle("Room", "Request", { schema = { reason = V.str(Config.AUDIENCE_REASON_MAX) }, rate = rate, call = true }, function(p, a)
		return reply(ThroneRoom.request(p, a.reason))
	end)
	Net.handle("Room", "Withdraw", { rate = rate, call = true }, function(p)
		return reply(ThroneRoom.withdraw(p), "You aren't in the queue.")
	end)
	for action, fn in { Call = ThroneRoom.call, Decline = ThroneRoom.decline, Up = ThroneRoom.up, GiveFloor = ThroneRoom.giveFloor } do
		Net.handle("Room", action, { schema = { target = V.player() }, rate = rate, call = true }, function(p, a)
			return reply(fn(p, a.target))
		end)
	end
	Net.handle("Room", "Extend", { rate = rate, call = true }, function(p)
		return reply(ThroneRoom.extend(p))
	end)
	Net.handle("Room", "TakeFloor", { rate = rate, call = true }, function(p)
		return reply(ThroneRoom.takeFloor(p))
	end)
	Net.handle("Room", "Invite", { schema = { target = V.player() }, rate = rate, call = true }, function(p, a)
		return reply(ThroneRoom.invite(p, a.target, true))
	end)
	Net.handle("Room", "Uninvite", { schema = { target = V.player() }, rate = rate, call = true }, function(p, a)
		return reply(ThroneRoom.invite(p, a.target, false))
	end)
	Players.PlayerRemoving:Connect(function(p)
		guests[p], warnings[p] = nil, nil
		local changed = take(p) ~= nil
		if floor == p then
			floor = nil
			floorStamp += 1
			changed = true
		end
		if changed then
			task.defer(pushState)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.THRONE_ROOM_CHECK)
			sweep()
		end
	end)
end

return ThroneRoom
