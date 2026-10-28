--!strict
-- Shared.Titles: titles, forms of address and precedence (COURT_PARLIAMENT §1, §3; TASKS T08).
-- A title is per server (Q4): the player attributes "Title" (a RANKS id) and "TitlePlace" (one of
-- PLACES), set by LondonServer.Court. The form a player is addressed by is their own choice in
-- profile.settings.address: "his", "her" or "neutral" (the default: "Their Majesty", "The Rt Hon.").
--   Titles.address(info) -> line1, line2   (the overhead tag: name line, style/role line)
--   Titles.style(rank, place, form) -> "The Rt Hon. the Earl of Kew"
--   Titles.precedence(role, rank?) -> number (higher outranks)   Titles.rankOf(id) -> Rank?
--   Titles.better(a, b) -> boolean (honour a outranks honour b; for the saved "highest honour")
local Titles = {}

Titles.ATTR = "Title"
Titles.PLACE_ATTR = "TitlePlace"
Titles.BADGE_ATTR = "Badge" -- the hobby title worn (LondonServer.Book)
Titles.FORMS = { "neutral", "his", "her" }

export type Rank = { id: string, his: string, her: string, of: boolean, peer: boolean }

-- Highest first. `of`: "the Earl of Kew" (true) or "the Viscount Kew" (false).
Titles.RANKS = {
	{ id = "Duke", his = "Duke", her = "Duchess", of = true, peer = true },
	{ id = "Marquess", his = "Marquess", her = "Marchioness", of = true, peer = true },
	{ id = "Earl", his = "Earl", her = "Countess", of = true, peer = true },
	{ id = "Viscount", his = "Viscount", her = "Viscountess", of = false, peer = true },
	{ id = "Baron", his = "Baron", her = "Baroness", of = false, peer = true },
	{ id = "Knight", his = "Knight", her = "Dame", of = false, peer = false },
} :: { Rank }
Titles.RANK_IDS = {} :: { string }
local BY_ID: { [string]: Rank } = {}
for _, r in Titles.RANKS do
	BY_ID[r.id] = r
	table.insert(Titles.RANK_IDS, r.id)
end

-- Places a peerage is "of": London districts with no real peerage of that name in use.
Titles.PLACES = {
	"Kew", "Mayfair", "Bloomsbury", "Clerkenwell", "Wapping", "Limehouse", "Shoreditch",
	"Spitalfields", "Bermondsey", "Rotherhithe", "Vauxhall", "Pimlico", "Soho", "Hoxton",
	"Smithfield", "Blackfriars", "Aldgate", "Bankside", "Highbury", "Primrose Hill",
}

function Titles.rankOf(id: any): Rank?
	return if type(id) == "string" then BY_ID[id] else nil
end

local function possessive(form: string?): string
	return if form == "his" then "His" elseif form == "her" then "Her" else "Their"
end

local function rankWord(r: Rank, form: string?): string
	return if form == "her" then r.her else r.his
end

-- The style of a peer: "Their Grace the Duke of Kew", "The Rt Hon. the Countess of Soho",
-- "The Rt Hon. the Lord Pimlico" (a baron, addressed by "his"). Knights have no style line.
function Titles.style(rankId: string, place: string?, form: string?): string?
	local r = BY_ID[rankId]
	if not r or not r.peer then
		return nil
	end
	local word = rankWord(r, form)
	if r.id == "Baron" and form ~= "neutral" and form ~= nil then
		word = if form == "her" then "Lady" else "Lord"
	end
	local named = if place and place ~= "" then string.format("%s %s%s", word, if r.of then "of " else "", place) else word
	if r.id == "Duke" then
		return string.format("%s Grace the %s", possessive(form), named)
	end
	return "The Rt Hon. the " .. named
end

-- Roles whose tag line is a style rather than the role's own name.
local STYLED_ROLES = { King = true, Queen = true, Royal = true, MP = true, Constable = true }

export type Info = {
	first: string, last: string, role: string?, roleName: string?, title: string?, place: string?, form: string?,
	badge: string?, -- a hobby title the player wears ("Keen Naturalist"), last on the tag
}

-- The two lines of the overhead tag. line1 is the name as addressed ("Sir Albert Tester",
-- "Constable Tester", "Albert Tester MP"); line2 the style and role ("Her Majesty the Queen",
-- "The Rt Hon. the Earl of Kew · Postman"), or "" for a plain citizen.
function Titles.address(info: Info): (string, string)
	local name = info.first .. " " .. info.last
	local form = info.form
	local role = info.role or "Citizen"
	local r = BY_ID[info.title or ""]
	local parts: { string } = {}
	if role == "King" or role == "Queen" then
		table.insert(parts, string.format("%s Majesty the %s", possessive(form), role))
	elseif role == "Royal" then
		local royal = possessive(form) .. " Royal Highness"
		if r and r.peer then
			royal ..= string.format(" the %s%s", rankWord(r, form), if info.place then (if r.of then " of " else " ") .. info.place else "")
			r = nil -- the peerage is in the royal style
		end
		table.insert(parts, royal)
	elseif role == "MP" then
		name ..= " MP"
	elseif role == "Constable" then
		name = "Constable " .. info.last
	end
	if r then
		if r.peer then
			table.insert(parts, Titles.style(r.id, info.place, form) :: string)
		elseif form == "his" then
			name = "Sir " .. name
		elseif form == "her" then
			name = "Dame " .. name
		else
			table.insert(parts, "Knight of the Realm")
		end
	end
	if not STYLED_ROLES[role] and role ~= "Citizen" and info.roleName then
		table.insert(parts, info.roleName)
	end
	if info.badge and info.badge ~= "" then
		table.insert(parts, info.badge)
	end
	return name, table.concat(parts, " · ")
end

-- Precedence (§1): higher outranks. A player ranks by the higher of their role and title.
local ROLE_PRECEDENCE = {
	King = 100, Queen = 100, Royal = 90, PrimeMinister = 80, LordChamberlain = 75,
	Chancellor = 45, HomeSecretary = 45, MP = 35, PrivateSecretary = 30, Equerry = 30,
	GuardOfficer = 25,
}
local RANK_PRECEDENCE = { Duke = 70, Marquess = 65, Earl = 60, Viscount = 55, Baron = 50, Knight = 40 }

function Titles.precedence(role: string?, rank: string?): number
	return math.max(ROLE_PRECEDENCE[role or ""] or 0, RANK_PRECEDENCE[rank or ""] or 0)
end

-- Honours saved as "highest ever held" (progress.honours "honour:<id>"): ranks and offices.
function Titles.better(a: string, b: string?): boolean
	if not b then
		return true
	end
	return (RANK_PRECEDENCE[a] or ROLE_PRECEDENCE[a] or 0) > (RANK_PRECEDENCE[b] or ROLE_PRECEDENCE[b] or 0)
end

return Titles
