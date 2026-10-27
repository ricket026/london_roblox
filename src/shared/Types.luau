--!strict
-- Shared.Types: shared type definitions.
export type Profile = {
	v: number, -- schema version, migrated on load
	name: { first: string, last: string, changedAt: number },
	pence: number, -- wallet, integer pence
	bank: number, -- banked pence
	jobs: { [string]: { xp: number, rank: number } },
	titles: { string }, -- persistent grants (Titles registry ids)
	offices: { string },
	outfits: { owned: { string }, equipped: { [string]: string } },
	rental: { houseId: string?, paidUntil: number },
	vehicles: { { id: string, kind: string, livery: string, condition: number } },
	licences: { cab: boolean, omnibus: boolean, motor: boolean },
	record: { arrests: number, warnings: { any }, mutedUntil: number },
	settings: { [string]: any },
	firstJoin: number,
	playtime: number, -- seconds
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
