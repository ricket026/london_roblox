--!strict
-- Shared.Types: shared type definitions.

-- How a character looks (Shared.Looks validates; ids index Config.HAIR_STYLES / Config.OUTFITS).
export type Look = {
	skin: number, -- index into Config.SKIN_TONES
	hair: string,
	outfit: string,
}

-- One save slot: who the character is. What they've earned lives in Progress (shared by linked slots).
export type Slot = {
	char: string, -- Progress id ("c1"); linked slots share it
	name: { first: string, last: string, changedAt: number }, -- changedAt starts the rename cooldown
	look: Look,
	createdAt: number,
}

-- Grind that linked slots share (systems/JOBS.md ranks, ACTIVITIES.md hobbies...).
export type Progress = {
	jobs: { [string]: { xp: number, rank: number } },
	hobbies: { [string]: number }, -- hobby -> XP (Shared.Hobbies)
	bests: { [string]: number }, -- activity id -> personal best score
	licences: { cab: boolean, omnibus: boolean, motor: boolean },
	honours: { string }, -- cosmetic "highest honour held" records (COURT_PARLIAMENT, Q4)
}

-- One stack of items (Shared.Items). `by` / `byName`: the maker of a player-made item.
export type Stack = { i: string, n: number, by: number?, byName: string? }

-- A property deed (PROPERTY.md §6); filled in by LondonServer.Property.
export type Deed = { [string]: any }

-- Schema v3 (TECH.md §5.1; v2 2026-10-27 character slots, v3 2026-10-28 inventory + property). One per account.
export type Profile = {
	v: number, -- schema version, migrated on load
	-- account-wide
	pence: number, -- wallet, integer pence
	bank: number, -- banked pence
	collection: { [string]: number }, -- Shared.Collection id -> times found
	purchases: { [string]: number }, -- Robux gamepass / product id -> count (M9)
	outfits: { owned: { string }, equipped: { [string]: string } },
	vehicles: { { id: string, kind: string, livery: string, condition: number } },
	record: { arrests: number, warnings: { any }, mutedUntil: number },
	limits: {
		activityWindow: number, activityPaid: number, -- hourly pastime pay cap (os.time window start)
		transferDay: string, transferred: number, -- pence handed to others on that UTC day (new accounts)
	},
	inventory: { bag: { Stack }, storage: { Stack } }, -- bag = carried (Config.BAG_SLOTS); storage = home/shop
	properties: { [string]: Deed }, -- deed id -> deed (PROPERTY.md)
	nextDeed: number,
	settings: { [string]: any },
	firstJoin: number,
	playtime: number, -- seconds, whole account
	-- characters
	slots: { [string]: Slot }, -- keys "1".."MAX_SLOTS" (string keys: DataStore JSON can't hold sparse arrays)
	active: string, -- slot key being played this session, "" = none
	progress: { [string]: Progress },
	nextChar: number, -- next Progress id number
}

export type LogEntry = {
	at: number,
	by: number, -- actor userId, 0 = server/console
	action: string,
	target: number?,
	reason: string?,
	minutes: number?,
	server: string,
}

return {}
