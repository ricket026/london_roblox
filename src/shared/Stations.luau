--!strict
-- Shared.Stations: every role a player can hold in a server (DESIGN §5, COURT_PARLIAMENT §2).
-- Roles are per server (Q4) and live in memory; the profile never stores them.
-- claim: "open"     anyone, any time
--        "claim"    from the role menu while a seat is free, after minPlaytime seconds
--        "appoint"  granted by another role (Court/Parliament, M4/M7); not in the role menu
--        "throne"   claimed at the throne (M4); not in the role menu
-- seats = nil means unlimited. Jobs (M3) attach to these ids.
local Stations = {}

export type Role = {
	id: string,
	name: string, -- shown in the role menu and on the overhead tag
	station: string, -- group heading in the menu
	claim: string,
	seats: number?,
	minPlaytime: number?, -- seconds of saved playtime
	blurb: string,
}

local HOUR = 3600

Stations.ORDER = { "Labour", "Transport", "The Law", "Professions", "Gentry", "Justice", "The Crown" }

Stations.ROLES = {
	{ id = "Citizen", name = "Citizen", station = "Gentry", claim = "open", blurb = "No occupation. Take in the city." },
	{ id = "Newsboy", name = "Newsboy", station = "Labour", claim = "open", blurb = "Sell the papers on busy corners." },
	{ id = "Lamplighter", name = "Lamplighter", station = "Labour", claim = "open", blurb = "Light the gas lamps at dusk." },
	{ id = "Postman", name = "Postman", station = "Labour", claim = "open", blurb = "Deliver the letters." },
	{ id = "Cabbie", name = "Cabbie", station = "Transport", claim = "open", blurb = "Drive a hansom cab for fares." },
	{ id = "OmnibusDriver", name = "Omnibus Driver", station = "Transport", claim = "open", blurb = "Run the omnibus route." },
	{ id = "Constable", name = "Constable", station = "The Law", claim = "open", blurb = "Walk the beat; keep the peace." },
	{ id = "Physician", name = "Physician", station = "Professions", claim = "open", blurb = "Revive the injured." },
	{ id = "Journalist", name = "Journalist", station = "Professions", claim = "open", blurb = "Write for the Gazette." },
	{ id = "Magistrate", name = "Magistrate", station = "Justice", claim = "claim", seats = 2, minPlaytime = 2 * HOUR, blurb = "Hear cases at the police court." },
	{ id = "Judge", name = "Judge", station = "Justice", claim = "claim", seats = 2, minPlaytime = 3 * HOUR, blurb = "Preside over full trials." },
	{ id = "Royal", name = "Royal Family", station = "The Crown", claim = "claim", seats = 8, minPlaytime = 1 * HOUR, blurb = "Join the line of succession." },
	{ id = "King", name = "King", station = "The Crown", claim = "throne", seats = 1, minPlaytime = 2 * HOUR, blurb = "Claimed at the empty throne." },
	{ id = "Queen", name = "Queen", station = "The Crown", claim = "throne", seats = 1, minPlaytime = 2 * HOUR, blurb = "Claimed at the empty throne." },
	{ id = "MP", name = "Member of Parliament", station = "Justice", claim = "appoint", seats = 12, blurb = "Won in the server's election." },
} :: { Role }

Stations.BY_ID = {} :: { [string]: Role }
Stations.IDS = {} :: { string }
for _, r in Stations.ROLES do
	Stations.BY_ID[r.id] = r
	table.insert(Stations.IDS, r.id)
end

-- Roles shown in the role menu (open + claimable).
function Stations.selectable(role: Role): boolean
	return role.claim == "open" or role.claim == "claim"
end

return Stations
