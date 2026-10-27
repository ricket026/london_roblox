--!strict
-- Shared.Config: every tunable value, with a comment (TECH.md §4). Read-only at runtime.
local Config = {}

-- Identity ------------------------------------------------------------------
Config.GAME_NAME = "Crown & Court" -- working title (OPEN_QUESTIONS Q1 default)
Config.SETTING_LINE = "London, 1897" -- loading screen subtitle (era changed from 1770 on 2026-10-24)

-- Staff ---------------------------------------------------------------------
Config.GROUP_ID = 0 -- Roblox group for ranks; 0 = no group yet (pre-M0 checklist, needed by M3)
Config.STAFF_LEVEL = { NONE = 0, MOD = 1, ADMIN = 2, OWNER = 3 } -- tiers used by Roles.ACTIONS
Config.GROUP_RANK_STAFF = { [250] = 1, [254] = 2, [255] = 3 } -- min group rank -> staff level (when GROUP_ID ~= 0)
Config.STAFF_USER_IDS = { [3967616473] = 3 } -- userId -> staff level without a group (place owner)
Config.STUDIO_TEST_STAFF = { [-1] = 3, [-2] = 1 } -- Studio local-server test players: Player1 owner, Player2 mod

-- Data stores ---------------------------------------------------------------
Config.PROFILE_STORE = "Profile_v1" -- player profiles, key "u_<userId>" (TECH.md §5.1)
Config.BANS_STORE = "Bans_v1" -- key "u_<userId>" -> { reason, by, at, untilT (0 = permanent) }
Config.ADMIN_LOG_STORE = "AdminLog_v1" -- key "d_<yyyymmdd>" -> list of staff actions that day
Config.STUDIO_USE_REAL_STORE = false -- true once the place is published and Studio API access is on
Config.MOCK_LATENCY = 0.05 -- seconds each mock store call yields, so ordering bugs show up in Studio
Config.AUTOSAVE_SECONDS = 120 -- periodic profile save; also refreshes the session lock
Config.LOCK_STALE_SECONDS = 360 -- a lock older than this belongs to a dead server and is taken over
Config.LOCK_RETRY_SECONDS = 3 -- wait between claims while another server holds the lock
Config.LOCK_MAX_WAIT = 30 -- give up after this long (player is kicked with a rejoin message)
Config.LOAD_RETRIES = 3 -- store errors tolerated while loading before giving up
Config.SAVE_RETRIES = 3 -- attempts per save
Config.SAVE_RETRY_SECONDS = 2 -- wait between save attempts
Config.CLOSE_SAVE_TIMEOUT = 25 -- BindToClose budget for final saves (Roblox allows 30)

-- Money (pence are the only stored unit; 12d = 1s, 20s = £1) -----------------
Config.PENCE_PER_SHILLING = 12 -- pre-decimal: 12 pence to the shilling
Config.SHILLINGS_PER_POUND = 20 -- 20 shillings to the pound
Config.START_PENCE = 60 -- new profile wallet (5s)
Config.PENCE_MAX = 240 * 1000000 -- wallet / bank cap (£1,000,000)

-- Admin ---------------------------------------------------------------------
Config.REASON_MAX = 200 -- characters in a kick/ban/mute reason
Config.MAX_BAN_MINUTES = 60 * 24 * 365 -- longest timed ban (0 = permanent is separate)
Config.MAX_MUTE_MINUTES = 60 * 24 * 7 -- longest mute
Config.MUTE_CHECK_SECONDS = 15 -- how often expired mutes are lifted
Config.ADMIN_LOG_MEMORY = 200 -- newest staff actions kept in this server for /logs
Config.ADMIN_LOG_DAY_CAP = 500 -- max entries stored per day key
Config.ADMIN_LOG_SHOW = 5 -- entries shown by the /logs chat command
Config.ADMIN_TOPIC = "LondonAdmin" -- MessagingService topic for cross-server bans
Config.ADMIN_RATE = { count = 5, per = 10 } -- Admin remote calls per player per action

-- Net -----------------------------------------------------------------------
Config.NET_RATE_DEFAULT = { count = 10, per = 1 } -- messages per player per action when a handler sets none
Config.NET_REJECT_WARN_EVERY = 20 -- warn on the 1st and every Nth rejected message per player (Guard reads these later)

-- Text ----------------------------------------------------------------------
Config.TEXT_FILTER_RETRIES = 2 -- FilterStringAsync attempts; failure = text is not shown (fail closed)

-- Analytics (systems/PLAYER_GATHERING.md §7) ---------------------------------
Config.ANALYTICS_IN_STUDIO = false -- false = Studio only records events in memory, nothing is sent
Config.ONBOARDING_STEPS = { -- funnel order (systems/LOW_POP_AND_ONBOARDING.md §3); M0 logs step 1 only
	"ProfileLoaded", "Arrival", "Name", "Look", "Rules", "FirstJob", "FirstPay", "Tour",
}
Config.ANALYTICS_MEMORY = 100 -- recent events kept in memory for tests / the staff summary

-- Loading screen ------------------------------------------------------------
Config.LOADING_MIN_SECONDS = 1.5 -- keep the title card up at least this long
Config.LOADING_TIMEOUT = 45 -- drop the card even if the profile never arrives

-- Doors (ServerScriptService.LondonServer.Doors) ------------------------------
Config.DOOR_TAG = "Door" -- CollectionService tag on swinging leaves (attrs DoorHinge, DoorOpenDeg, DoorGroup)
Config.DOOR_SWING_TIME = 0.8 -- seconds to swing open or shut
Config.DOOR_PROMPT_DISTANCE = 8 -- studs from the prompt a player can open a door
Config.DOOR_PROMPT_HEIGHT = 3.4 -- prompt height above the sill (ring-pull height)
Config.DOOR_AUTO_CLOSE = 0 -- seconds before an opened door shuts itself; 0 = stays open

-- Characters & save slots (LondonServer.Characters) --------------------------
-- Money, Robux purchases, the collection book and the moderation record belong to the account.
-- Each slot has its own name and look; job ranks, hobbies, licences and bests belong to the
-- slot's progress, which linked slots share.
Config.MAX_SLOTS = 3 -- character slots per account
Config.SLOT_NEW_PRICE = 0 -- pence for a fresh character in a slot after the first (the first is always free)
Config.SLOT_LINK_PRICE = 240 * 100 -- £100: a new slot linked to an existing character's progression
Config.CHARACTER_SWITCH_COOLDOWN = 60 -- seconds between switching characters in a session
Config.CHARACTER_RATE = { count = 4, per = 5 } -- Character remote calls per player per action
Config.RESPAWN_SECONDS = 5 -- after death (LAW §1 hospital respawn replaces the spawn point in M5)
-- Where the camera looks while the character menu is open (The Mall, facing the palace).
Config.MENU_CAMERA = { from = Vector3.new(0, 38, -170), to = Vector3.new(0, 28, 260) }

-- Character looks (Shared.Looks). Outfits colour the body until catalog clothing is picked:
-- coat = torso + arms (gloved hands), lower = legs (trousers or skirts). Set shirt / pants to
-- classic clothing asset ids, or layered = { { id = assetId, type = "Jacket" / "DressSkirt" /
-- "Pants" / "Shirt"... (Enum.AccessoryType name) } } in wearing order, once chosen (ART §7).
Config.SKIN_TONES = {
	Color3.fromRGB(255, 224, 196), Color3.fromRGB(241, 194, 158), Color3.fromRGB(224, 172, 128),
	Color3.fromRGB(198, 140, 99), Color3.fromRGB(161, 105, 70), Color3.fromRGB(124, 78, 50),
	Color3.fromRGB(92, 58, 38), Color3.fromRGB(64, 42, 30),
}
Config.HAIR_STYLES = { -- "own" keeps the player's Roblox hair; others list hair accessory asset ids
	{ id = "own", name = "My own hair", assets = {} },
	{ id = "none", name = "No hair (wear a hat)", assets = {} },
}
Config.OUTFITS = {
	{ id = "frock", name = "Frock coat", coat = Color3.fromRGB(28, 28, 32), lower = Color3.fromRGB(70, 70, 76), shirt = 0, pants = 0, layered = {} },
	{ id = "tweed", name = "Tweed suit", coat = Color3.fromRGB(110, 92, 66), lower = Color3.fromRGB(96, 80, 58), shirt = 0, pants = 0, layered = {} },
	{ id = "work", name = "Working clothes", coat = Color3.fromRGB(78, 62, 48), lower = Color3.fromRGB(52, 48, 44), shirt = 0, pants = 0, layered = {} },
	{ id = "daydress", name = "Day dress", coat = Color3.fromRGB(70, 40, 60), lower = Color3.fromRGB(70, 40, 60), shirt = 0, pants = 0, layered = {} },
	{ id = "walking", name = "Walking costume", coat = Color3.fromRGB(34, 52, 70), lower = Color3.fromRGB(46, 60, 74), shirt = 0, pants = 0, layered = {} },
	{ id = "plain", name = "Plain dress & apron", coat = Color3.fromRGB(96, 92, 86), lower = Color3.fromRGB(120, 112, 100), shirt = 0, pants = 0, layered = {} },
}

-- RP names (LondonServer.Characters, DESIGN §6.1) -----------------------------
Config.NAME_MIN = 2 -- characters in a first or last name
Config.NAME_MAX = 14 -- characters in a first or last name
Config.NAME_CHANGE_COOLDOWN = 60 * 60 * 24 * 7 -- seconds between renames of a character (from its creation)
Config.NAME_RATE = { count = 4, per = 20 } -- calls that run the text filter (create, link, rename) per player
-- Words a name may not contain (lowercase): titles and ranks are granted, never typed (TECH §8).
Config.NAME_RESERVED = {
	"king", "queen", "prince", "princess", "duke", "duchess", "marquess", "earl", "count", "viscount",
	"baron", "lord", "lady", "sir", "dame", "majesty", "highness", "royal", "rt hon", "mp",
	"admin", "mod", "staff", "owner", "roblox",
}
-- Whole names of real royals and politicians of the period (lowercase "first last"). Fictional families only (Q2).
Config.NAME_BLOCKED = {
	"victoria hanover", "albert edward", "edward saxe", "alexandra dagmar", "george hanover",
	"william gladstone", "robert gascoyne", "robert cecil", "benjamin disraeli", "arthur balfour",
	"jack ripper", "victoria regina",
}

-- Stations (Shared.Stations, LondonServer.Identity) ---------------------------
Config.ROLE_SWITCH_COOLDOWN = 120 -- seconds between role changes (JOBS §1: 2 min)
Config.ROLE_RATE = { count = 3, per = 5 } -- ChooseRole calls per player
Config.DEFAULT_ROLE = "Citizen" -- role everyone holds until they pick one

-- Overhead tags (LondonServer.Identity) ----------------------------------------
Config.TAG_MAX_DISTANCE = 60 -- studs; tags fade out past this so a 50-player hub stays readable
Config.TAG_OFFSET = 2.6 -- studs above the head
Config.TAG_SIZE = { w = 8, h = 1.6 } -- studs (scales with distance like the world)

-- World clock (LondonServer.WorldClock, Q10) -----------------------------------
Config.DAY_MINUTES = 24 -- real minutes per in-game day (ECONOMY §1)
Config.CLOCK_OFFSET_HOURS = 6 -- shifts the shared clock so it isn't midnight at 00:00 UTC
Config.CLOCK_TICK = 0.5 -- seconds between Lighting.ClockTime updates
Config.CLOCK_PHASES = { -- in-game hour each phase starts (lamplighters: JOBS §2, dusk 18-20, dawn 5-7)
	{ name = "Dawn", hour = 5 },
	{ name = "Day", hour = 7 },
	{ name = "Dusk", hour = 18 },
	{ name = "Night", hour = 20 },
}

-- Activities (LondonServer.Activities, systems/ACTIVITIES.md) ----------------
-- Sites are greybox map coordinates (map_layout_v2.json); Y comes from a raycast to the ground.
Config.ACTIVITY_PAY_PER_HOUR = 120 -- pence all activities together may pay a player per real hour (10s; jobs pay more, §1)
Config.ACTIVITY_BOARD_SIZE = 5 -- names shown on each site's "Today in this server" board
Config.HOBBIES = { "Sport", "Music", "Performance", "Outdoors", "Collecting", "Games" } -- ACTIVITIES §3
Config.HOBBY_MAX_LEVEL = 10
Config.HOBBY_XP_BASE = 100 -- XP to reach level n = BASE * (n - 1) ^ EXP (l2 100, l5 800, l10 2700)
Config.HOBBY_XP_EXP = 1.5

-- Feeding the ducks & pigeons (St James's Park lake)
Config.DUCKS_SITE = { x = 268, z = -330 } -- 14 studs back from the lake's west shore (shore is x 282 here)
Config.DUCKS_LAKE = { cx = 330, cz = -470, rx = 55, rz = 280, surface = -1 } -- same as map_layout_v2 water.lake
Config.DUCKS_SEED_PRICE = 1 -- pence per bag of seed (ACTIVITIES §2)
Config.DUCKS_COOLDOWN = 15 -- seconds between feeds per player
Config.DUCKS_BIRDS = 6 -- water birds that come per feed
Config.DUCKS_PIGEONS = 3 -- pigeons that land at your feet per feed
Config.DUCKS_STAY = 12 -- seconds the birds stay before leaving
Config.DUCKS_MAX_LIVE = 48 -- cap on birds in the world at once
Config.DUCKS_XP = 4 -- Outdoors XP per feed
-- Which bird comes depends on the time of day, not chance (no paid chance, §1).
Config.DUCKS_SPECIES = { -- first match wins; hours are in-game
	{ id = "bird_pelican", from = 14, to = 15 }, -- the park's pelicans are fed at half past two
	{ id = "bird_swan", from = 5, to = 7 },
	{ id = "bird_mallard", from = 0, to = 24 },
}

-- Test your strength (fairground, Covent Garden)
Config.STRENGTH_SITE = { x = -140, z = -1318 }
Config.STRENGTH_SWINGS = 3 -- swings per go
Config.STRENGTH_PERIOD = { min = 0.9, max = 1.3 } -- seconds for the meter to sweep up and down
Config.STRENGTH_TIMEOUT = 25 -- seconds a go may last before it ends itself
Config.STRENGTH_BELL = 95 -- score (0-100) that rings the bell
Config.STRENGTH_POLE = 22 -- studs from the base to the bell
Config.STRENGTH_PAY_BELL = 2 -- pence per bell rung
Config.STRENGTH_XP = { base = 4, perTen = 1 } -- Sport XP per go: base + best score / 10 * perTen
Config.STRENGTH_RANGE = 14 -- studs a swinger may stand from the machine
Config.STRENGTH_BELL_SOUND = "" -- rbxassetid for the bell; "" = silent (pick one from the audio library)

-- Mudlarking (Thames foreshore below the Temple)
Config.MUDLARK_AREA = { x = { 1154, 1182 }, z = { -1745, -2100 } } -- inside map_layout_v2 water.foreshore
Config.MUDLARK_RAY_FROM = -4 -- glints raycast down from here: below Blackfriars Bridge deck (bottom -3), above the foreshore (-10)
Config.MUDLARK_SIGN = { x = 1138, z = -1751 } -- street side of the river wall parapet, by the stairs
Config.MUDLARK_GLINTS = 10 -- glints on the foreshore at once (shared: first to dig gets it)
Config.MUDLARK_RESPAWN = { min = 8, max = 20 } -- seconds before a dug glint reappears elsewhere
Config.MUDLARK_DIG_SECONDS = 2 -- hold time on a glint
Config.MUDLARK_XP = 6 -- Collecting XP per find
Config.TIDE_LOW = { { from = 0, to = 6 }, { from = 12, to = 18 } } -- in-game hours of low tide (2 x 6 real min a day)

-- Chess (outdoor tables by the bandstand)
Config.CHESS_TABLES = { { x = 140, z = -330 }, { x = 140, z = -352 }, { x = 118, z = -341 } }
Config.CHESS_MOVE_TIMEOUT = 120 -- seconds the side to move has before losing on time
Config.CHESS_MIN_PLIES = 10 -- half-moves before a game pays out (stops instant-resign farming)
Config.CHESS_PAY = { win = 6, draw = 3, loss = 0 } -- pence
Config.CHESS_XP = { win = 30, draw = 20, loss = 15 } -- Games XP
Config.CHESS_START_DELAY = 3 -- seconds after both sit before the first move
-- Board glyphs; swap for letters ("K", "Q"...) if a device lacks the chess font.
Config.CHESS_GLYPHS = { K = "♚", Q = "♛", R = "♜", B = "♝", N = "♞", P = "♟" }

return Config
