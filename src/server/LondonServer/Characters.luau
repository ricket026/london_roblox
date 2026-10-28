--!strict
-- LondonServer.Characters: character creation and save slots (Shared.Types Slot / Progress).
-- Every session starts at the character menu; the avatar only spawns once a slot is picked
-- (Players.CharacterAutoLoads is off, and this module respawns players after death).
--   Create  a fresh character in an empty slot (first slot free, then Config.SLOT_NEW_PRICE)
--   Link    a new slot sharing an existing character's progress (Config.SLOT_LINK_PRICE): own name
--           and look, same job ranks / hobbies / licences / bests, and progress counts for both
--   Select  play as a slot (Config.CHARACTER_SWITCH_COOLDOWN between switches)
--   Rename  a slot (Config.NAME_CHANGE_COOLDOWN from creation or the last rename)
--   Delete  a slot (must send its full name to confirm); its progress is deleted only if no
--           other slot links to it
-- Character purchases and changes save immediately (Profiles.save).
-- Remotes (Character domain, calls): List, Create, Link, Select, Rename, Delete. Push: List.
-- Player attributes: RPName (Identity tags), CharSlot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Text = require(Shared:WaitForChild("Text"))
local Money = require(Shared:WaitForChild("Money"))
local Names = require(Shared:WaitForChild("Names"))
local Looks = require(Shared:WaitForChild("Looks"))
local Hobbies = require(Shared:WaitForChild("Hobbies"))
local Types = require(Shared:WaitForChild("Types"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Wardrobe = require(script.Parent:WaitForChild("Wardrobe"))
local World = require(script.Parent:WaitForChild("World"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Analytics = require(script.Parent:WaitForChild("Analytics"))
local Identity = require(script.Parent:WaitForChild("Identity"))

local V = Net.V
local Characters = {}
Characters.SLOT_ATTR = "CharSlot"

local baseDescription: { [Player]: HumanoidDescription } = {} -- the player's own avatar, fetched once
local beforeChange: { (Player) -> () } = {}
local switchedAt: { [Player]: number } = {}
local busy: { [Player]: boolean } = {} -- one character change at a time per player

local function slotKey(i: number): string
	return tostring(i)
end

local function fullName(slot: Types.Slot): string
	return slot.name.first .. " " .. slot.name.last
end

-- Seconds until a slot may be renamed. A character never renamed gets one free fix within
-- Config.NAME_FIX_GRACE of its creation; after that, Config.NAME_CHANGE_COOLDOWN applies.
local function renameIn(slot: Types.Slot): number
	local now = os.time()
	if slot.name.changedAt == slot.createdAt and now - slot.createdAt < Config.NAME_FIX_GRACE then
		return 0
	end
	return math.max(0, Config.NAME_CHANGE_COOLDOWN - (now - slot.name.changedAt))
end

-- How many slots point at a progress id.
local function linkCount(p: Types.Profile, char: string): number
	local n = 0
	for _, s in p.slots do
		if s.char == char then
			n += 1
		end
	end
	return n
end

local function usedSlots(p: Types.Profile): number
	local n = 0
	for _ in p.slots do
		n += 1
	end
	return n
end

-- A line under the name in the menu: best hobby levels so players recognise their characters.
local function summary(prog: Types.Progress?): string
	if not prog then
		return ""
	end
	local parts = {}
	for hobby, xp in prog.hobbies do
		local lvl = Hobbies.level(xp)
		if lvl > 1 then
			table.insert(parts, { hobby = hobby, lvl = lvl })
		end
	end
	table.sort(parts, function(a, b)
		return a.lvl > b.lvl
	end)
	local out = {}
	for i = 1, math.min(3, #parts) do
		table.insert(out, string.format("%s %d", parts[i].hobby, parts[i].lvl))
	end
	return if #out > 0 then table.concat(out, " · ") else "New to the city"
end

function Characters.list(player: Player): { [string]: any }
	local p = Profiles.get(player)
	if not p then
		return { loaded = false }
	end
	local slots = {}
	for i = 1, Config.MAX_SLOTS do
		local s = p.slots[slotKey(i)]
		if s then
			slots[slotKey(i)] = {
				first = s.name.first,
				last = s.name.last,
				look = s.look,
				summary = summary(p.progress[s.char]),
				linked = linkCount(p, s.char) > 1,
				shared = linkCount(p, s.char), -- slots sharing this progress (incl. this one)
				renameIn = renameIn(s),
			}
		end
	end
	return {
		loaded = true,
		slots = slots,
		active = p.active,
		maxSlots = Config.MAX_SLOTS,
		newPrice = if usedSlots(p) == 0 then 0 else Config.SLOT_NEW_PRICE,
		linkPrice = Config.SLOT_LINK_PRICE,
		newPriceText = Money.format(if usedSlots(p) == 0 then 0 else Config.SLOT_NEW_PRICE),
		linkPriceText = Money.format(Config.SLOT_LINK_PRICE),
		money = p.pence + p.bank,
		switchIn = math.max(0, Config.CHARACTER_SWITCH_COOLDOWN - (os.clock() - (switchedAt[player] or -math.huge))),
	}
end

local function pushList(player: Player)
	Net.push(player, "Character", "List", Characters.list(player))
end

-- Names -----------------------------------------------------------------------------------
-- Returns first, last (tidied, filtered) or nil, nil, reason.
local function checkName(player: Player, first: any, last: any): (string?, string?, string?)
	local f, whyF = Names.cleanPart(first)
	if not f then
		return nil, nil, whyF
	end
	local l, whyL = Names.cleanPart(last)
	if not l then
		return nil, nil, whyL
	end
	if Names.isBlocked(f, l) then
		return nil, nil, "That's a real person's name. Please pick a fictional one."
	end
	local full = f .. " " .. l
	local filtered = Text.filterBroadcast(full, player.UserId)
	if filtered == nil then
		return nil, nil, "The name check isn't answering. Please try again."
	end
	if filtered ~= full then
		return nil, nil, "That name isn't allowed. Please pick another."
	end
	return f, l, nil
end

-- Looks -------------------------------------------------------------------------------------
local function avatarDescription(player: Player): HumanoidDescription
	local cached = baseDescription[player]
	if cached then
		return cached
	end
	local desc: HumanoidDescription
	local ok, res = pcall(Players.GetHumanoidDescriptionFromUserId, Players, player.UserId)
	if ok and res then
		desc = res
	else
		desc = Instance.new("HumanoidDescription") -- Studio test players (negative ids) and outages
	end
	baseDescription[player] = desc
	return desc
end

-- The player's avatar (face, head, body shape, animations) in the character's look. Modern
-- clothing and accessories are removed (PROPERTY_WARDROBE §3: period clothing everywhere).
function Characters.describe(player: Player, look: Types.Look): HumanoidDescription
	local desc = avatarDescription(player):Clone()
	local hair = Looks.hair(look.hair) or Config.HAIR_STYLES[1]
	local outfit = Looks.outfit(look.outfit) or Config.OUTFITS[1]
	local keep = {}
	if hair.id == "own" then
		for _, a in desc:GetAccessories(true) do
			if a.AccessoryType == Enum.AccessoryType.Hair then
				table.insert(keep, a)
			end
		end
	end
	for _, id in hair.assets do
		table.insert(keep, { AssetId = id, AccessoryType = Enum.AccessoryType.Hair, IsLayered = false })
	end
	for i, piece in outfit.layered do
		table.insert(keep, { AssetId = piece.id, AccessoryType = (Enum.AccessoryType :: any)[piece.type], IsLayered = true, Order = i })
	end
	desc:SetAccessories(keep, true)
	desc.Shirt = outfit.shirt
	desc.Pants = outfit.pants
	desc.GraphicTShirt = 0
	local skin = Config.SKIN_TONES[look.skin] or Config.SKIN_TONES[1]
	desc.HeadColor = skin
	desc.TorsoColor = outfit.coat
	desc.LeftArmColor = outfit.coat
	desc.RightArmColor = outfit.coat
	desc.LeftLegColor = outfit.lower
	desc.RightLegColor = outfit.lower
	return desc
end

-- Spawning ----------------------------------------------------------------------------------
-- Where characters arrive (T03): the terminus forecourt (Config.SPAWN_POINT), spread over
-- Config.SPAWN_RADIUS, standing on the ground found by raycast.
local spawnRng = Random.new()
function Characters.spawnPoint(): CFrame
	local centre = Vector3.new(Config.SPAWN_POINT.x, 0, Config.SPAWN_POINT.z)
	local a = spawnRng:NextNumber() * math.pi * 2
	local r = math.sqrt(spawnRng:NextNumber()) * Config.SPAWN_RADIUS
	local g = World.ground(centre.X + math.cos(a) * r, centre.Z + math.sin(a) * r)
	return CFrame.new(g + Vector3.new(0, 3, 0)) * CFrame.Angles(0, a, 0)
end

function Characters.spawn(player: Player)
	local slot = Profiles.activeSlot(player)
	if not slot or player.Parent ~= Players then
		return
	end
	local desc = Characters.describe(player, slot.look)
	local ok, err = pcall(player.LoadCharacterWithHumanoidDescription, player, desc)
	if not ok then
		warn(string.format("[Characters] spawn with look failed for %s: %s", player.Name, tostring(err)))
		pcall(player.LoadCharacter, player) -- never leave a player without a body
	end
	local character = player.Character
	if character then
		Wardrobe.dress(character, slot.look.outfit) -- the 3D outfit (T06)
		character:PivotTo(Characters.spawnPoint()) -- the terminus platforms (T03)
	end
end

local function despawn(player: Player)
	local c = player.Character
	player.Character = nil
	if c then
		c:Destroy()
	end
end

-- fn(player) runs right before the active character changes or is deleted, while
-- Profiles.progress(player) is still the old character: settle activities there. Plain
-- callbacks, not a signal, because deferred signals would run after the switch.
function Characters.onBeforeChange(fn: (Player) -> ())
	table.insert(beforeChange, fn)
end

local function leaving(player: Player)
	for _, fn in beforeChange do
		local ok, err = pcall(fn, player)
		if not ok then
			warn("[Characters] before-change hook failed: " .. tostring(err))
		end
	end
end

-- Slot actions -------------------------------------------------------------------------------
local function play(player: Player, p: Types.Profile, key: string)
	if p.active ~= "" then
		leaving(player)
	end
	local slot = p.slots[key]
	p.active = key
	switchedAt[player] = os.clock()
	player:SetAttribute(Characters.SLOT_ATTR, key)
	player:SetAttribute(Identity.NAME_ATTR, fullName(slot))
	Identity.resetRole(player)
	Characters.spawn(player)
end

local function newSlot(p: Types.Profile, key: string, char: string, first: string, last: string, look: Types.Look)
	local now = os.time()
	p.slots[key] = {
		char = char,
		name = { first = first, last = last, changedAt = now }, -- == createdAt marks "never renamed"
		look = look,
		createdAt = now,
	}
end

-- Shared checks for Create / Link. Returns the profile, or nil and a reason.
local function canFill(player: Player, key: string): (Types.Profile?, string?)
	local p = Profiles.get(player)
	if not p then
		return nil, "Your profile isn't loaded yet."
	end
	local i = tonumber(key)
	if not i or i < 1 or i > Config.MAX_SLOTS or i % 1 ~= 0 then
		return nil, "That slot doesn't exist."
	end
	if p.slots[key] then
		return nil, "That slot is already in use."
	end
	return p, nil
end

function Characters.create(player: Player, key: string, first: any, last: any, look: Types.Look): string?
	local p, why = canFill(player, key)
	if not p then
		return why
	end
	local isFirst = usedSlots(p) == 0
	local price = if isFirst then 0 else Config.SLOT_NEW_PRICE
	local f, l, whyName = checkName(player, first, last)
	if not f or not l then
		return whyName
	end
	if p.slots[key] then -- the name check yields; another request may have filled the slot
		return "That slot is already in use."
	end
	if price > 0 and not Economy.charge(player, price, "character", "slot " .. key) then
		return string.format("A new character costs %s.", Money.format(price))
	end
	local char = "c" .. p.nextChar
	p.nextChar += 1
	p.progress[char] = Profiles.progressDefaults()
	newSlot(p, key, char, f, l, look)
	Profiles.save(player)
	if isFirst then
		Analytics.onboardingStep(player, "Name")
		Analytics.onboardingStep(player, "Look")
	end
	Analytics.event(player, "CharacterCreated", tonumber(key))
	return nil
end

function Characters.link(player: Player, key: string, fromKey: string, first: any, last: any, look: Types.Look): string?
	local p, why = canFill(player, key)
	if not p then
		return why
	end
	local from = p.slots[fromKey]
	if not from then
		return "Pick a character to share progress with."
	end
	local f, l, whyName = checkName(player, first, last)
	if not f or not l then
		return whyName
	end
	if p.slots[key] or p.slots[fromKey] ~= from then -- changed while the name check yielded
		return "Your slots changed. Please try again."
	end
	if not Economy.charge(player, Config.SLOT_LINK_PRICE, "character", "link " .. key) then
		return string.format("Sharing a character's progress costs %s.", Money.format(Config.SLOT_LINK_PRICE))
	end
	newSlot(p, key, from.char, f, l, look)
	Profiles.save(player)
	Analytics.event(player, "CharacterLinked", tonumber(key))
	return nil
end

function Characters.select(player: Player, key: string): string?
	local p = Profiles.get(player)
	if not p then
		return "Your profile isn't loaded yet."
	end
	if not p.slots[key] then
		return "That slot is empty."
	end
	if p.active == key and player.Character then
		return "You're already playing as this character."
	end
	local since = os.clock() - (switchedAt[player] or -math.huge)
	if p.active ~= "" and since < Config.CHARACTER_SWITCH_COOLDOWN then
		return string.format("You can switch character again in %d s.", math.ceil(Config.CHARACTER_SWITCH_COOLDOWN - since))
	end
	play(player, p, key)
	return nil
end

function Characters.rename(player: Player, key: string, first: any, last: any): string?
	local p = Profiles.get(player)
	local slot = p and p.slots[key]
	if not p or not slot then
		return "That slot is empty."
	end
	local left = renameIn(slot)
	if left > 0 then
		return string.format("This character can be renamed again in %d days.", math.ceil(left / 86400))
	end
	local f, l, whyName = checkName(player, first, last)
	if not f or not l then
		return whyName
	end
	if p.slots[key] ~= slot then
		return "Your slots changed. Please try again."
	end
	slot.name = { first = f, last = l, changedAt = os.time() }
	if p.active == key then
		player:SetAttribute(Identity.NAME_ATTR, fullName(slot))
	end
	Profiles.save(player)
	return nil
end

function Characters.delete(player: Player, key: string, confirm: string): string?
	local p = Profiles.get(player)
	local slot = p and p.slots[key]
	if not p or not slot then
		return "That slot is empty."
	end
	if confirm ~= fullName(slot) then
		return "Type the character's full name to confirm."
	end
	if p.active == key then
		leaving(player)
	end
	p.slots[key] = nil
	if linkCount(p, slot.char) == 0 then
		p.progress[slot.char] = nil -- nothing links to it any more
	end
	if p.active == key then
		p.active = ""
		player:SetAttribute(Characters.SLOT_ATTR, nil)
		player:SetAttribute(Identity.NAME_ATTR, nil)
		Identity.resetRole(player)
		despawn(player)
	end
	Profiles.save(player)
	Analytics.event(player, "CharacterDeleted", tonumber(key))
	return nil
end

-- Lifecycle ----------------------------------------------------------------------------------
function Characters.onProfileLoaded(player: Player)
	local p = Profiles.get(player)
	if p then
		for _, s in p.slots do
			s.look = Looks.repair(s.look) -- a preset may have been removed from Config since it was saved
		end
	end
	task.spawn(avatarDescription, player) -- warm the cache while they read the menu
	pushList(player)
end

function Characters.onPlayerRemoving(player: Player)
	baseDescription[player] = nil
	switchedAt[player] = nil
	busy[player] = nil
end

-- Studio test hook: create (or reuse) slot "1" with a test name and play it.
function Characters.debugQuickStart(player: Player): boolean
	local p = Profiles.get(player)
	if not p then
		return false
	end
	if not p.slots["1"] then
		local char = "c" .. p.nextChar
		p.nextChar += 1
		p.progress[char] = Profiles.progressDefaults()
		newSlot(p, "1", char, "Test", "Player" .. math.abs(player.UserId), Looks.default())
	end
	play(player, p, "1")
	pushList(player)
	return true
end

function Characters.init()
	Players.CharacterAutoLoads = false

	-- Every call: one at a time per player, then the fresh list (or the reason it failed).
	local function handle(action: string, schema: { [string]: Net.Validator }, rate: { count: number, per: number }, fn: (Player, any) -> string?)
		Net.handle("Character", action, { schema = schema, rate = rate, call = true }, function(player, a)
			if busy[player] then
				return nil, "One moment..."
			end
			busy[player] = true
			local ok, why = pcall(fn, player, a)
			busy[player] = nil
			if not ok then
				warn(string.format("[Characters] %s failed for %s: %s", action, player.Name, tostring(why)))
				return nil, "Something went wrong. Please try again."
			end
			if why then
				return nil, why
			end
			return Characters.list(player)
		end)
	end
	local slot = V.enum((function()
		local keys = {}
		for i = 1, Config.MAX_SLOTS do
			table.insert(keys, slotKey(i))
		end
		return keys
	end)())
	local nameField = V.str(Config.NAME_MAX * 2)
	local lookSchema = {
		skin = V.int(1, #Config.SKIN_TONES),
		hair = V.str(32),
		outfit = V.str(32),
	}
	local function withLook(extra: { [string]: Net.Validator }): { [string]: Net.Validator }
		local s = table.clone(lookSchema)
		for k, v in extra do
			s[k] = v
		end
		return s
	end

	Net.handle("Character", "List", { call = true }, function(player)
		return Characters.list(player)
	end)
	handle("Create", withLook({ slot = slot, first = nameField, last = nameField }), Config.NAME_RATE, function(player, a)
		local look = Looks.clean(a.skin, a.hair, a.outfit)
		if not look then
			return "Please pick a look."
		end
		local why = Characters.create(player, a.slot, a.first, a.last, look)
		if not why then
			local p = Profiles.get(player)
			if p and p.active == "" then
				play(player, p, a.slot) -- straight into the city with a new character
			end
		end
		return why
	end)
	handle("Link", withLook({ slot = slot, from = slot, first = nameField, last = nameField }), Config.NAME_RATE, function(player, a)
		local look = Looks.clean(a.skin, a.hair, a.outfit)
		if not look then
			return "Please pick a look."
		end
		return Characters.link(player, a.slot, a.from, a.first, a.last, look)
	end)
	handle("Select", { slot = slot }, Config.CHARACTER_RATE, function(player, a)
		return Characters.select(player, a.slot)
	end)
	handle("Rename", { slot = slot, first = nameField, last = nameField }, Config.NAME_RATE, function(player, a)
		return Characters.rename(player, a.slot, a.first, a.last)
	end)
	handle("Delete", { slot = slot, confirm = V.str(Config.NAME_MAX * 2 + 1) }, Config.CHARACTER_RATE, function(player, a)
		return Characters.delete(player, a.slot, a.confirm)
	end)

	-- Respawn after death (CharacterAutoLoads is off).
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			local hum = character:WaitForChild("Humanoid", 10)
			if hum and hum:IsA("Humanoid") then
				hum.Died:Connect(function()
					task.delay(Config.RESPAWN_SECONDS, function()
						if player.Character == character and player.Parent == Players then
							Characters.spawn(player)
						end
					end)
				end)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
end

return Characters
