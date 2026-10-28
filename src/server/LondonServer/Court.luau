--!strict
-- LondonServer.Court: honours, offices and grants (COURT_PARLIAMENT §2, §5; TASKS T35, T08). Per
-- server (Q4): nothing here outlives the session except the cosmetic "highest honour" entry
-- ("honour:<id>" in progress.honours, Shared.Titles.better).
--   Titles (Shared.Titles.RANKS, Duke … Knight): granted by the King or Queen to a player present,
--     "of" a place from Titles.PLACES; caps per server in Config.COURT_TITLE_CAPS; one title per
--     player (a higher one replaces a lower). Held as the attributes Title / TitlePlace, and
--     dropped when the player switches character or leaves.
--   Offices (Household roles in Shared.Stations): Lord Chamberlain and Private Secretary by the
--     Monarch; Equerries by the Monarch or the Lord Chamberlain (or, with no Lord Chamberlain,
--     the senior royal). An office is a role, so it's offered and must be accepted.
--   Royal family: the Monarch may invite a player to it (an offer), within the seat limit.
-- Every grant or revocation: the granter waits Config.COURT_GRANT_COOLDOWN before the next, it's
-- logged (AdminLog "court.*") and proclaimed (Throne.proclaim). Revocation needs a reason
-- (filtered, logged). A player chooses their form of address (profile.settings.address).
-- Remotes (Court domain, calls): Get, GrantTitle { target, rank, place }, Appoint { target,
--   office }, InviteRoyal { target }, Answer { id, accept }, Revoke { target, kind, reason },
--   Renounce, SetForm { form }.
-- Pushes: Court.Offer { id, text, seconds } (to the one offered), Court.Closed { id, result }
--   (to the granter), Court.Changed (to everyone: refresh an open menu), Court.Notice { text }.
--   Court.grantTitle(by, target, rank, place)   Court.appoint(by, target, office)
--   Court.inviteRoyal(by, target)   Court.answer(player, id, accept)   Court.revoke(by, target,
--   kind, reason)   Court.renounce(player)   Court.setForm(player, form)
--   Court.undoGrantsBy(granter) (no-confidence, T38)   Court.view(player)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local Stations = require(Shared:WaitForChild("Stations"))
local Text = require(Shared:WaitForChild("Text"))
local Titles = require(Shared:WaitForChild("Titles"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Identity = require(script.Parent:WaitForChild("Identity"))
local AdminLog = require(script.Parent:WaitForChild("AdminLog"))
local Throne = require(script.Parent:WaitForChild("Throne"))

local Court = {}

Court.OFFICES = { "LordChamberlain", "PrivateSecretary", "Equerry" }

type Grant = { by: Player, target: Player, kind: string, id: string, at: number }
type Offer = { id: number, from: Player, to: Player, role: string, expires: number }

local grants: { Grant } = {}
local lastGrant: { [Player]: number } = {}
local offers: { [number]: Offer } = {}
local nextOffer = 0

local function nameOf(p: Player): string
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

local function formOf(p: Player): string?
	local profile = Profiles.get(p)
	return if profile then profile.settings.address else nil
end

local function isMonarch(p: Player): boolean
	local r = Roles.roleOf(p)
	return r == "King" or r == "Queen"
end

-- Who appoints Equerries: the Monarch, the Lord Chamberlain, or with no Lord Chamberlain the
-- senior royal (first in the line of succession).
local function actsAsChamberlain(p: Player): boolean
	if Roles.roleOf(p) == "LordChamberlain" then
		return true
	end
	if #Identity.holdersOf("LordChamberlain") > 0 then
		return false
	end
	return Identity.holdersOf("Royal")[1] == p
end

function Court.canAppoint(p: Player, office: string): boolean
	if isMonarch(p) then
		return true
	end
	return office == "Equerry" and actsAsChamberlain(p)
end

function Court.titleOf(p: Player): (string?, string?)
	local t, place = p:GetAttribute(Titles.ATTR), p:GetAttribute(Titles.PLACE_ATTR)
	return if type(t) == "string" then t else nil, if type(place) == "string" then place else nil
end

local function holdersOfRank(rank: string): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if Court.titleOf(p) == rank then
			table.insert(out, p)
		end
	end
	return out
end

local function rankIndex(rank: string?): number
	return if rank then table.find(Titles.RANK_IDS, rank) or math.huge else math.huge
end

-- "the Earl of Kew" / "the Countess of Kew" / "a Knight" for proclamations, in the holder's form.
local function titleText(rank: string, place: string?, form: string?): string
	local r = Titles.rankOf(rank)
	if not r then
		return rank
	end
	local word = if form == "her" then r.her else r.his
	if not r.peer then
		return if form == "her" then "a Dame" else "a Knight"
	end
	return string.format("the %s%s", word, if place then (if r.of then " of " else " ") .. place else "")
end

-- "Earl of Kew" (titleText without the leading "the").
local function bare(s: string): string
	local out = string.gsub(s, "^the ", "")
	return out
end

local function remember(p: Player, honour: string)
	local prog = Profiles.progress(p)
	if not prog then
		return
	end
	local best: string? = nil
	local at = 0
	for i, h in prog.honours do
		local id = string.match(h, "^honour:(%w+)$")
		if id then
			best, at = id, i
		end
	end
	if Titles.better(honour, best) then
		if at > 0 then
			table.remove(prog.honours, at)
		end
		table.insert(prog.honours, "honour:" .. honour)
	end
end

-- The highest honour this character has ever held, or nil.
function Court.highestHonour(p: Player): string?
	local prog = Profiles.progress(p)
	for _, h in if prog then prog.honours else {} do
		local id = string.match(h, "^honour:(%w+)$")
		if id then
			return id
		end
	end
	return nil
end

local function cooling(by: Player): string?
	local left = Config.COURT_GRANT_COOLDOWN - (os.clock() - (lastGrant[by] or -math.huge))
	if left > 0 then
		return string.format("You can make another grant in %d s.", math.ceil(left))
	end
	return nil
end

local function present(target: Player): string?
	if target.Parent ~= Players or target:GetAttribute("CharSlot") == nil or target:GetAttribute("RPName") == nil then
		return "They aren't here as a character."
	end
	return nil
end

local function changed()
	Net.pushAll("Court", "Changed", {})
end

-- Titles ----------------------------------------------------------------------------------
function Court.grantTitle(by: Player, target: Player, rank: string, place: string): (boolean, string?)
	if not isMonarch(by) then
		return false, "Only the King or Queen grants titles."
	end
	local r = Titles.rankOf(rank)
	if not r then
		return false, "There's no such title."
	end
	if target == by then
		return false, "The Crown can't honour itself."
	end
	local why = present(target) or cooling(by)
	if why then
		return false, why
	end
	local current, currentPlace = Court.titleOf(target)
	if current == rank and (not r.peer or currentPlace == place) then
		return false, "They hold that title already."
	end
	if current and rankIndex(current) < rankIndex(rank) then
		return false, "They hold a higher title already."
	end
	if #holdersOfRank(rank) >= (Config.COURT_TITLE_CAPS[rank] or 0) and current ~= rank then
		return false, string.format("There are as many %s as this server allows.", rank .. (if string.sub(rank, -1) == "s" then "es" else "s"))
	end
	if r.peer then
		if not table.find(Titles.PLACES, place) then
			return false, "Choose a place for the title."
		end
		for _, p in holdersOfRank(rank) do
			if p ~= target and select(2, Court.titleOf(p)) == place then
				return false, string.format("%s is %s already.", nameOf(p), titleText(rank, place, formOf(p)))
			end
		end
	end
	lastGrant[by] = os.clock()
	target:SetAttribute(Titles.ATTR, rank)
	target:SetAttribute(Titles.PLACE_ATTR, if r.peer then place else nil)
	table.insert(grants, { by = by, target = target, kind = "title", id = rank, at = os.clock() })
	remember(target, rank)
	AdminLog.add(by.UserId, "court.title", target.UserId, rank .. (if r.peer then " of " .. place else ""))
	Throne.proclaim(string.format("By order of the Crown, %s is made %s.", nameOf(target), titleText(rank, if r.peer then place else nil, formOf(target))))
	changed()
	return true
end

local function clearTitle(p: Player)
	if Court.titleOf(p) then
		p:SetAttribute(Titles.ATTR, nil)
		p:SetAttribute(Titles.PLACE_ATTR, nil)
		changed()
	end
end

function Court.renounce(p: Player): (boolean, string?)
	local rank, place = Court.titleOf(p)
	if not rank then
		return false, "You hold no title."
	end
	clearTitle(p)
	Throne.proclaim(string.format("%s has given up the title of %s.", nameOf(p), bare(titleText(rank, place, formOf(p)))))
	return true
end

-- Offices and the royal family (offers) ----------------------------------------------------
local function seatsFree(role: string): boolean
	local r = Stations.BY_ID[role]
	return r ~= nil and (r.seats == nil or #Identity.holdersOf(role) < r.seats)
end

local function offer(by: Player, target: Player, role: string, text: string): (boolean, string?)
	for _, o in offers do
		if o.to == target then
			return false, "They're considering another offer."
		end
	end
	lastGrant[by] = os.clock()
	nextOffer += 1
	local o: Offer = { id = nextOffer, from = by, to = target, role = role, expires = os.clock() + Config.COURT_OFFER_SECONDS }
	offers[o.id] = o
	Net.push(target, "Court", "Offer", { id = o.id, text = text, seconds = Config.COURT_OFFER_SECONDS })
	task.delay(Config.COURT_OFFER_SECONDS, function()
		if offers[o.id] == o then
			offers[o.id] = nil
			Net.push(target, "Court", "Closed", { id = o.id, result = "expired" })
			if by.Parent == Players then
				Net.push(by, "Court", "Closed", { id = o.id, result = "expired" })
			end
		end
	end)
	return true
end

local function canTakeRole(target: Player, role: string): string?
	local current = Roles.roleOf(target)
	if current == role then
		return "They hold that already."
	end
	if current == "King" or current == "Queen" then
		return "The King or Queen can't take another role."
	end
	if not seatsFree(role) then
		return "There's no seat free."
	end
	if Identity.barred(target, role) then
		return "They were voted out of that role a short while ago."
	end
	return nil
end

function Court.appoint(by: Player, target: Player, office: string): (boolean, string?)
	if not table.find(Court.OFFICES, office) then
		return false, "There's no such office."
	end
	if not Court.canAppoint(by, office) then
		return false, "You can't appoint to that office."
	end
	if target == by then
		return false, "You can't appoint yourself."
	end
	local why = present(target) or canTakeRole(target, office) or cooling(by)
	if why then
		return false, why
	end
	return offer(by, target, office, string.format("%s offers you the office of %s. It replaces your role.", nameOf(by), Stations.BY_ID[office].name))
end

function Court.inviteRoyal(by: Player, target: Player): (boolean, string?)
	if not isMonarch(by) then
		return false, "Only the King or Queen invites players into the royal family."
	end
	if target == by then
		return false, "You're royal already."
	end
	local why = present(target) or canTakeRole(target, "Royal") or cooling(by)
	if why then
		return false, why
	end
	return offer(by, target, "Royal", string.format("%s invites you into the royal family (and the line of succession). It replaces your role.", nameOf(by)))
end

function Court.answer(p: Player, id: number, accept: boolean): (boolean, string?)
	local o = offers[id]
	if not o or o.to ~= p then
		return false, "That offer has passed."
	end
	offers[id] = nil
	local from = o.from
	local function closed(result: string)
		if from.Parent == Players then
			Net.push(from, "Court", "Closed", { id = id, result = result })
		end
	end
	if not accept then
		closed("declined")
		return true
	end
	local still = if o.role == "Royal" then isMonarch(from) else Court.canAppoint(from, o.role)
	if not still then
		closed("failed")
		return false, "The one who offered it can no longer appoint you."
	end
	local why = canTakeRole(p, o.role)
	if why then
		closed("failed")
		return false, why
	end
	Identity.grant(p, o.role)
	table.insert(grants, { by = from, target = p, kind = "office", id = o.role, at = os.clock() })
	if o.role ~= "Royal" then
		remember(p, o.role)
	end
	AdminLog.add(from.UserId, "court.appoint", p.UserId, o.role)
	local roleName = Stations.BY_ID[o.role].name
	if o.role == "Royal" then
		Throne.proclaim(string.format("%s is welcomed into the royal family.", nameOf(p)))
	else
		Throne.proclaim(string.format("%s is appointed %s.", nameOf(p), roleName))
	end
	closed("done")
	changed()
	return true
end

-- Revocation ------------------------------------------------------------------------------
function Court.revoke(by: Player, target: Player, kind: string, reason: string): (boolean, string?)
	local why = cooling(by)
	if why then
		return false, why
	end
	local role = Roles.roleOf(target)
	if kind == "title" then
		if not isMonarch(by) then
			return false, "Only the King or Queen takes titles away."
		end
		if not Court.titleOf(target) then
			return false, "They hold no title."
		end
	elseif kind == "office" then
		if not table.find(Court.OFFICES, role) and role ~= "Royal" then
			return false, "They hold no Household office."
		end
		if not (isMonarch(by) or (role == "Equerry" and actsAsChamberlain(by))) then
			return false, "You can't remove them from that."
		end
	else
		return false, "Revoke what?"
	end
	local clean = Text.filterBroadcast(reason, by.UserId)
	if not clean or clean == "" then
		return false, "Give a reason (it couldn't be checked; try again)."
	end
	lastGrant[by] = os.clock()
	local what: string
	if kind == "title" then
		local rank, place = Court.titleOf(target)
		what = bare(titleText(rank :: string, place, formOf(target)))
		clearTitle(target)
	else
		what = Stations.BY_ID[role].name
		Identity.grant(target, Config.DEFAULT_ROLE)
	end
	AdminLog.add(by.UserId, "court.revoke", target.UserId, what .. ": " .. clean)
	Throne.proclaim(string.format("By order of the Crown, %s is no longer %s.", nameOf(target), what))
	changed()
	return true
end

-- Grants made in the last Config.COURT_UNDO_WINDOW seconds by `granter` that still stand are
-- undone (a granter removed by no confidence, COURT §2). Returns how many.
function Court.undoGrantsBy(granter: Player): number
	local n = 0
	for _, g in grants do
		if g.by == granter and os.clock() - g.at <= Config.COURT_UNDO_WINDOW and g.target.Parent == Players then
			if g.kind == "title" and Court.titleOf(g.target) == g.id then
				clearTitle(g.target)
				n += 1
			elseif g.kind == "office" and Roles.roleOf(g.target) == g.id then
				Identity.grant(g.target, Config.DEFAULT_ROLE)
				n += 1
			end
		end
	end
	if n > 0 then
		AdminLog.add(granter.UserId, "court.undo", nil, tostring(n))
		changed()
	end
	return n
end

-- Form of address -------------------------------------------------------------------------
function Court.setForm(p: Player, form: string): (boolean, string?)
	local profile = Profiles.get(p)
	if not profile or not table.find(Titles.FORMS, form) then
		return false, "Not now."
	end
	profile.settings.address = form
	Identity.refreshTag(p)
	return true
end

-- What the Court menu shows this player.
function Court.view(p: Player): { [string]: any }
	local list = {}
	for _, q in Players:GetPlayers() do
		if q:GetAttribute("RPName") ~= nil and q:GetAttribute("CharSlot") ~= nil then
			local rank, place = Court.titleOf(q)
			table.insert(list, {
				userId = q.UserId,
				name = nameOf(q),
				role = Roles.roleOf(q),
				title = if rank then bare(titleText(rank, place, formOf(q))) else nil,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	local caps = {}
	for _, rank in Titles.RANK_IDS do
		caps[rank] = { used = #holdersOfRank(rank), cap = Config.COURT_TITLE_CAPS[rank] or 0 }
	end
	local seats = {}
	for _, role in { "LordChamberlain", "PrivateSecretary", "Equerry", "Royal" } do
		seats[role] = { used = #Identity.holdersOf(role), cap = Stations.BY_ID[role].seats or 0 }
	end
	local appoint = {}
	for _, office in Court.OFFICES do
		if Court.canAppoint(p, office) then
			table.insert(appoint, office)
		end
	end
	local rank, place = Court.titleOf(p)
	local _, styleLine = Titles.address({ first = "", last = "", role = Roles.roleOf(p), title = rank, place = place, form = formOf(p) })
	local left = Config.COURT_GRANT_COOLDOWN - (os.clock() - (lastGrant[p] or -math.huge))
	return {
		monarch = isMonarch(p),
		appoint = appoint,
		players = list,
		caps = caps,
		seats = seats,
		places = Titles.PLACES,
		form = formOf(p) or "neutral",
		title = rank,
		style = styleLine,
		cooldown = math.max(0, math.ceil(left)),
	}
end

function Court.init()
	local V = Net.V
	local rate = Config.COURT_RATE
	local function reply(good: boolean, why: string?): (any, string?)
		if not good then
			return nil, why
		end
		return {}
	end
	Net.handle("Court", "Get", { rate = rate, call = true }, function(p)
		return Court.view(p)
	end)
	Net.handle("Court", "GrantTitle", { schema = { target = V.player(), rank = V.enum(Titles.RANK_IDS), place = V.enum(Titles.PLACES) }, rate = rate, call = true }, function(p, a)
		return reply(Court.grantTitle(p, a.target, a.rank, a.place))
	end)
	Net.handle("Court", "Appoint", { schema = { target = V.player(), office = V.enum(Court.OFFICES) }, rate = rate, call = true }, function(p, a)
		return reply(Court.appoint(p, a.target, a.office))
	end)
	Net.handle("Court", "InviteRoyal", { schema = { target = V.player() }, rate = rate, call = true }, function(p, a)
		return reply(Court.inviteRoyal(p, a.target))
	end)
	Net.handle("Court", "Answer", { schema = { id = V.int(1, 2 ^ 31), accept = V.bool() }, rate = rate, call = true }, function(p, a)
		return reply(Court.answer(p, a.id, a.accept))
	end)
	Net.handle("Court", "Revoke", { schema = { target = V.player(), kind = V.enum({ "title", "office" }), reason = V.str(Config.COURT_REASON_MAX) }, rate = rate, call = true }, function(p, a)
		return reply(Court.revoke(p, a.target, a.kind, a.reason))
	end)
	Net.handle("Court", "Renounce", { rate = rate, call = true }, function(p)
		return reply(Court.renounce(p))
	end)
	Net.handle("Court", "SetForm", { schema = { form = V.enum(Titles.FORMS) }, rate = rate, call = true }, function(p, a)
		return reply(Court.setForm(p, a.form))
	end)
	-- a title belongs to the character it was granted to
	local function watch(p: Player)
		p:GetAttributeChangedSignal("CharSlot"):Connect(function()
			clearTitle(p)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastGrant[p] = nil
		for id, o in offers do
			if o.to == p or o.from == p then
				offers[id] = nil
				local other = if o.to == p then o.from else o.to
				if other.Parent == Players then
					Net.push(other, "Court", "Closed", { id = id, result = "left" })
				end
			end
		end
		for i = #grants, 1, -1 do
			if grants[i].target == p or grants[i].by == p then
				table.remove(grants, i)
			end
		end
		if Court.titleOf(p) then
			task.defer(changed)
		end
	end)
end

return Court
