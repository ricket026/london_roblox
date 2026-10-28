--!strict
-- LondonServer.Throne: the King's and Queen's thrones (COURT_PARLIAMENT §2.1, TASKS T34). Per
-- server (Q4). The two throne seats in the throne room (Config.THRONE_SEATS) each carry a "Claim
-- the throne" prompt while that throne is free and nobody is being offered it. When a throne falls
-- empty (abdication, leaving the server, switching character) it's offered down the line of
-- succession: royal family members in the order they joined it (Identity.holdersOf("Royal")), each
-- with Config.THRONE_OFFER_SECONDS to accept; then anyone eligible may claim it (the role's playtime
-- gate in Shared.Stations). A new monarch is proclaimed to the whole server, and the reign is
-- counted in progress.honours as the entry "reign:<role>:<n>" (cosmetic, "Reigned as Queen of
-- London, 3 times"). Only the monarch may sit on their throne.
-- Remotes (Throne domain, calls): Get, Accept { role }, Decline { role }, Abdicate.
-- Pushes: Throne.Offer { role, seconds } (to one royal), Throne.Proclaim { text } (to everyone),
--   Throne.State { King?, Queen? } (monarchs' names, to everyone), Throne.Notice { text }.
--   Throne.monarch(role) -> Player?   Throne.claim(player, role) -> ok, why
--   Throne.accept(player, role)   Throne.abdicate(player)   Throne.reigns(progress, role) -> n
--   Throne.proclaim(text) (the banner every player sees; LondonServer.Court uses it too)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local Stations = require(Shared:WaitForChild("Stations"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Identity = require(script.Parent:WaitForChild("Identity"))

local Throne = {}

local THRONES = { "King", "Queen" }
local offers: { [string]: { player: Player, expires: number, asked: { [Player]: boolean } } } = {}
local prompts: { [string]: ProximityPrompt } = {}

local function nameOf(p: Player): string
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

function Throne.monarch(role: string): Player?
	return Identity.holdersOf(role)[1]
end

function Throne.proclaim(text: string)
	Net.pushAll("Throne", "Proclaim", { text = text })
end

local function view(): { [string]: any }
	local k, q = Throne.monarch("King"), Throne.monarch("Queen")
	return { King = if k then nameOf(k) else nil, Queen = if q then nameOf(q) else nil }
end

local function pushState()
	Net.pushAll("Throne", "State", view())
end

-- Times a character has reigned as role (from the "reign:<role>:<n>" honours entry).
function Throne.reigns(prog: { honours: { string } }, role: string): number
	for _, h in prog.honours do
		local r, n = string.match(h, "^reign:(%a+):(%d+)$")
		if r == role then
			return tonumber(n) or 0
		end
	end
	return 0
end

local function countReign(player: Player, role: string)
	local prog = Profiles.progress(player)
	if not prog then
		return
	end
	local n = Throne.reigns(prog, role) + 1
	for i, h in prog.honours do
		if string.match(h, "^reign:" .. role .. ":") then
			table.remove(prog.honours, i)
			break
		end
	end
	table.insert(prog.honours, string.format("reign:%s:%d", role, n))
end

local function seat(role: string): Seat?
	local rooms = workspace:FindFirstChild("PalaceInteriors")
	local room = rooms and rooms:FindFirstChild("ThroneRoom")
	local gameplay = room and room:FindFirstChild("Gameplay")
	local s = gameplay and gameplay:FindFirstChild(Config.THRONE_SEATS[role])
	return if s and s:IsA("Seat") then s else nil
end

local function refreshPrompt(role: string)
	local pp = prompts[role]
	if pp then
		pp.Enabled = Throne.monarch(role) == nil and offers[role] == nil
	end
end

local function accede(player: Player, role: string)
	offers[role] = nil
	Identity.grant(player, role)
	countReign(player, role)
	Throne.proclaim(string.format("God save the %s! %s has come to the throne.", role, nameOf(player)))
	refreshPrompt(role)
	pushState()
end

-- Claim a free throne (not on offer). Returns ok, or false and why.
function Throne.claim(player: Player, role: string): (boolean, string?)
	if not table.find(THRONES, role) then
		return false, "There's no such throne."
	end
	if Throne.monarch(role) then
		return false, "The throne is taken."
	end
	if offers[role] then
		return false, "The throne is being offered to the royal family."
	end
	if player:GetAttribute("CharSlot") == nil then
		return false, "Choose a character first."
	end
	local current = Roles.roleOf(player)
	if current == "King" or current == "Queen" then
		return false, "You're on a throne already."
	end
	local r = Stations.BY_ID[role]
	if r and r.minPlaytime and Profiles.playtime(player) < r.minPlaytime then
		return false, string.format("The throne needs %d h of playtime.", math.ceil(r.minPlaytime / 3600))
	end
	accede(player, role)
	return true
end

-- Offers a free throne to the next royal not yet asked; with nobody left, opens it to claims.
local function offerNext(role: string)
	if Throne.monarch(role) then
		offers[role] = nil
		return
	end
	local o = offers[role] or { player = nil :: any, expires = 0, asked = {} }
	offers[role] = o
	for _, royal in Identity.holdersOf("Royal") do
		if not o.asked[royal] and royal.Parent == Players then
			o.asked[royal] = true
			o.player = royal
			o.expires = os.clock() + Config.THRONE_OFFER_SECONDS
			Net.push(royal, "Throne", "Offer", { role = role, seconds = Config.THRONE_OFFER_SECONDS })
			refreshPrompt(role)
			local expires = o.expires
			task.delay(Config.THRONE_OFFER_SECONDS, function()
				if offers[role] == o and o.expires == expires then
					offerNext(role)
				end
			end)
			return
		end
	end
	offers[role] = nil
	refreshPrompt(role)
end

-- A throne fell empty: start the succession (if it wasn't already).
function Throne.vacated(role: string)
	if Throne.monarch(role) == nil and offers[role] == nil then
		Throne.proclaim(string.format("The %s's throne is empty.", string.lower(role)))
		pushState()
		offerNext(role)
	end
end

function Throne.accept(player: Player, role: string): (boolean, string?)
	local o = offers[role]
	if not o or o.player ~= player or os.clock() > o.expires then
		return false, "The offer has passed."
	end
	if Roles.roleOf(player) ~= "Royal" then
		return false, "Only the royal family is offered the throne."
	end
	accede(player, role)
	return true
end

function Throne.abdicate(player: Player): (boolean, string?)
	local role = Roles.roleOf(player)
	if role ~= "King" and role ~= "Queen" then
		return false, "You're not on a throne."
	end
	Throne.proclaim(string.format("%s has given up the throne.", nameOf(player)))
	Identity.grant(player, Config.DEFAULT_ROLE) -- the role watcher starts the succession
	return true
end

-- Only the monarch sits on their throne; anyone else is stood up.
local function guardSeat(role: string, s: Seat)
	s:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = s.Occupant
		local p = if hum then Players:GetPlayerFromCharacter(hum.Parent) else nil
		if hum and p ~= Throne.monarch(role) then
			hum.Sit = false
			hum.Jump = true
		end
	end)
end

function Throne.init()
	for _, role in THRONES do
		local s = seat(role)
		if s then
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Claim the throne"
			pp.ObjectText = role .. "'s throne"
			pp.HoldDuration = 2
			pp.MaxActivationDistance = 10
			pp.RequiresLineOfSight = false
			pp.Parent = s
			pp.Triggered:Connect(function(player)
				local good, why = Throne.claim(player, role)
				if not good then
					Net.push(player, "Throne", "Notice", { text = why })
				end
			end)
			prompts[role] = pp
			refreshPrompt(role)
			guardSeat(role, s)
		end
	end
	local V = Net.V
	local roleV = V.enum(THRONES)
	Net.handle("Throne", "Get", { rate = Config.THRONE_RATE, call = true }, function(player)
		local out = view()
		for role, o in offers do
			if o.player == player then
				out.offer = { role = role, seconds = math.max(0, o.expires - os.clock()) }
			end
		end
		return out
	end)
	Net.handle("Throne", "Accept", { schema = { role = roleV }, rate = Config.THRONE_RATE, call = true }, function(player, a)
		local good, why = Throne.accept(player, a.role)
		if not good then
			return nil, why
		end
		return {}
	end)
	Net.handle("Throne", "Decline", { schema = { role = roleV }, rate = Config.THRONE_RATE, call = true }, function(player, a)
		local o = offers[a.role]
		if o and o.player == player then
			o.expires = 0
			offerNext(a.role)
		end
		return {}
	end)
	Net.handle("Throne", "Abdicate", { rate = Config.THRONE_RATE, call = true }, function(player)
		local good, why = Throne.abdicate(player)
		if not good then
			return nil, why
		end
		return {}
	end)
	-- A monarch who changes role (abdicating, switching character) or leaves frees the throne.
	-- This is the one place a vacancy starts, so it's proclaimed once.
	local function watch(player: Player)
		local last = Roles.roleOf(player)
		player:GetAttributeChangedSignal(Roles.ROLE_ATTR):Connect(function()
			local now = Roles.roleOf(player)
			if (last == "King" or last == "Queen") and now ~= last then
				local was = last
				task.defer(Throne.vacated, was)
			end
			last = now
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local role = Roles.roleOf(player)
		if role == "King" or role == "Queen" then
			task.defer(Throne.vacated, role) -- after Identity has freed the seat
		end
		for r, o in offers do
			if o.player == player then
				o.expires = 0
				task.defer(offerNext, r) -- don't wait out a gone royal's offer
			end
		end
	end)
	pushState()
end

return Throne
