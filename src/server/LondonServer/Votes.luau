--!strict
-- LondonServer.Votes: votes of no confidence and vote-kicks (DESIGN §10, COURT_PARLIAMENT §2;
-- TASKS T38). There are no staff (Q11): the players present moderate the server. Per server.
--   No confidence: against anyone holding a seated role (Shared.Stations `seats`: the King or
--     Queen, the royal family, the Household, magistrates and judges, MPs). Passes with at least
--     Config.CONFIDENCE_SHARE of the votes cast as yes and Config.CONFIDENCE_VOTES_MIN votes cast.
--     The holder is put back to the default role, barred from that role for
--     Config.CONFIDENCE_BAR_SECONDS (Identity.bar), and grants they made in the last
--     Config.COURT_UNDO_WINDOW are undone (Court.undoGrantsBy). A holder faces at most one vote
--     per Config.CONFIDENCE_TARGET_COOLDOWN.
--   Vote-kick: passes with yes votes from Config.KICK_SHARE of the other players in the server and
--     at least Config.KICK_YES_MIN. The player is kicked and can't rejoin this server for
--     Config.KICK_BAR_SECONDS.
-- One vote at a time in a server, open for Config.VOTE_SECONDS (it closes early once everyone
-- has voted). Starting one counts as your yes; a player may start one per
-- Config.VOTE_START_COOLDOWN. Reasons come from fixed lists (Config.*_REASONS), so there's no
-- text to filter. Everything is logged (AdminLog "vote.confidence" / "vote.kick") and the
-- result is proclaimed.
-- Remotes (Vote domain, calls): Get, Start { target, kind, reason }, Cast { id, yes }.
-- Pushes (to everyone): Vote.Open { id, kind, target, targetId, role?, reason, by, byId, seconds,
--   yes, no },
--   Vote.Tally { id, yes, no }, Vote.Closed { id, passed, text }.
--   Votes.start(by, target, kind, reason) -> ok, why   Votes.cast(player, id, yes) -> ok, why
--   Votes.current() -> Vote?   Votes.close() (ends the running vote now)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local Stations = require(Shared:WaitForChild("Stations"))
local Identity = require(script.Parent:WaitForChild("Identity"))
local AdminLog = require(script.Parent:WaitForChild("AdminLog"))
local Throne = require(script.Parent:WaitForChild("Throne"))
local Court = require(script.Parent:WaitForChild("Court"))

local Votes = {}

export type Vote = {
	id: number, kind: string, target: Player, targetId: number, role: string?, reason: string,
	by: Player, yes: { [Player]: boolean }, no: { [Player]: boolean }, ends: number,
}

local running: Vote? = nil
local nextId = 0
local startedAt: { [number]: number } = {} -- userId -> os.clock() they last started a vote
local facedAt: { [number]: number } = {} -- userId -> os.clock() they last faced no confidence
local kickedUntil: { [number]: number } = {} -- userId -> os.time() they may rejoin

local function nameOf(p: Player): string
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

local function count(set: { [Player]: boolean }): number
	local n = 0
	for p in set do
		if p.Parent == Players then
			n += 1
		end
	end
	return n
end

function Votes.current(): Vote?
	return running
end

local function seated(role: string): boolean
	local r = Stations.BY_ID[role]
	return r ~= nil and r.seats ~= nil and role ~= Config.DEFAULT_ROLE
end

local function payload(v: Vote): { [string]: any }
	local r = if v.role then Stations.BY_ID[v.role] else nil
	return {
		id = v.id,
		kind = v.kind,
		target = nameOf(v.target),
		targetId = v.targetId,
		role = if r then r.name else nil,
		reason = v.reason,
		by = nameOf(v.by),
		byId = v.by.UserId,
		seconds = math.max(0, math.ceil(v.ends - os.clock())),
		yes = count(v.yes),
		no = count(v.no),
	}
end

-- Yes votes a kick needs now: a share of the other players here, and at least the minimum.
function Votes.kickNeeds(): number
	local others = #Players:GetPlayers() - 1
	return math.max(Config.KICK_YES_MIN, math.ceil(Config.KICK_SHARE * others - 1e-9))
end

local function finish(v: Vote, passed: boolean, text: string)
	running = nil
	AdminLog.add(v.by.UserId, "vote." .. v.kind, v.targetId, string.format("%s (%s) yes %d no %d: %s", v.reason, v.role or "-", count(v.yes), count(v.no), if passed then "passed" else "failed"))
	Net.pushAll("Vote", "Closed", { id = v.id, passed = passed, text = text })
end

-- Ends the running vote now and applies the result.
function Votes.close()
	local v = running
	if not v then
		return
	end
	local yes, no = count(v.yes), count(v.no)
	local target = v.target
	if target.Parent ~= Players then
		finish(v, false, string.format("The vote on %s lapsed: they left.", nameOf(target)))
		return
	end
	if v.kind == "confidence" then
		local role = v.role :: string
		local cast = yes + no
		local passed = cast >= Config.CONFIDENCE_VOTES_MIN and yes >= Config.CONFIDENCE_SHARE * cast - 1e-9
		if not passed then
			finish(v, false, string.format("%s keeps the confidence of the server (%d for removal, %d against).", nameOf(target), yes, no))
			return
		end
		if Roles.roleOf(target) ~= role then
			finish(v, false, string.format("%s has left that role already.", nameOf(target)))
			return
		end
		Court.undoGrantsBy(target)
		Identity.grant(target, Config.DEFAULT_ROLE)
		Identity.bar(target, role, Config.CONFIDENCE_BAR_SECONDS)
		local text = string.format("By a vote of no confidence (%d to %d), %s is removed as %s.", yes, no, nameOf(target), Stations.BY_ID[role].name)
		Throne.proclaim(text)
		finish(v, true, text)
	else
		local passed = yes >= Votes.kickNeeds()
		if not passed then
			finish(v, false, string.format("The vote to remove %s failed (%d yes; %d needed).", nameOf(target), yes, Votes.kickNeeds()))
			return
		end
		kickedUntil[v.targetId] = os.time() + Config.KICK_BAR_SECONDS
		local text = string.format("%s has been removed from this server by a vote of the players.", nameOf(target))
		finish(v, true, text)
		Throne.proclaim(text)
		target:Kick(string.format("Removed from this server by a vote of the players (%s). You can rejoin it in %d minutes.", v.reason, math.ceil(Config.KICK_BAR_SECONDS / 60)))
	end
end

local function everyoneVoted(v: Vote): boolean
	for _, p in Players:GetPlayers() do
		if p ~= v.target and not v.yes[p] and not v.no[p] then
			return false
		end
	end
	return true
end

function Votes.start(by: Player, target: Player, kind: string, reason: string): (boolean, string?)
	if running then
		return false, "A vote is already running."
	end
	if target == by then
		return false, "You can't start a vote on yourself."
	end
	if target.Parent ~= Players or target:GetAttribute("CharSlot") == nil then
		return false, "They aren't here as a character."
	end
	if by:GetAttribute("CharSlot") == nil then
		return false, "Choose a character first."
	end
	local left = Config.VOTE_START_COOLDOWN - (os.clock() - (startedAt[by.UserId] or -math.huge))
	if left > 0 then
		return false, string.format("You can start another vote in %d min.", math.ceil(left / 60))
	end
	local role: string? = nil
	if kind == "confidence" then
		if not table.find(Config.CONFIDENCE_REASONS, reason) then
			return false, "Choose a reason."
		end
		role = Roles.roleOf(target)
		if not seated(role :: string) then
			return false, "They hold no office to be removed from."
		end
		local faced = Config.CONFIDENCE_TARGET_COOLDOWN - (os.clock() - (facedAt[target.UserId] or -math.huge))
		if faced > 0 then
			return false, string.format("They faced a vote a short while ago; try again in %d min.", math.ceil(faced / 60))
		end
		facedAt[target.UserId] = os.clock()
	elseif kind == "kick" then
		if not table.find(Config.KICK_REASONS, reason) then
			return false, "Choose a reason."
		end
	else
		return false, "There's no such vote."
	end
	startedAt[by.UserId] = os.clock()
	nextId += 1
	local v: Vote = {
		id = nextId, kind = kind, target = target, targetId = target.UserId, role = role, reason = reason,
		by = by, yes = { [by] = true }, no = {}, ends = os.clock() + Config.VOTE_SECONDS,
	}
	running = v
	Net.pushAll("Vote", "Open", payload(v))
	task.delay(Config.VOTE_SECONDS, function()
		if running == v then
			Votes.close()
		end
	end)
	if everyoneVoted(v) then
		Votes.close()
	end
	return true
end

function Votes.cast(player: Player, id: number, yes: boolean): (boolean, string?)
	local v = running
	if not v or v.id ~= id then
		return false, "That vote has closed."
	end
	if player == v.target then
		return false, "You can't vote on yourself."
	end
	v.yes[player], v.no[player] = if yes then true else nil, if yes then nil else true
	Net.pushAll("Vote", "Tally", { id = v.id, yes = count(v.yes), no = count(v.no) })
	if everyoneVoted(v) then
		Votes.close()
	end
	return true
end

function Votes.init()
	local V = Net.V
	local reasons = table.clone(Config.CONFIDENCE_REASONS)
	for _, r in Config.KICK_REASONS do
		table.insert(reasons, r)
	end
	Net.handle("Vote", "Get", { rate = Config.VOTE_RATE, call = true }, function(player)
		local left = Config.VOTE_START_COOLDOWN - (os.clock() - (startedAt[player.UserId] or -math.huge))
		local v = running
		local current = if v then payload(v) else nil
		if current and v then
			current.mine = if v.yes[player] then "yes" elseif v.no[player] then "no" else nil
		end
		return { current = current, cooldown = math.max(0, math.ceil(left)), kickNeeds = Votes.kickNeeds() }
	end)
	Net.handle("Vote", "Start", { schema = { target = V.player(), kind = V.enum({ "confidence", "kick" }), reason = V.enum(reasons) }, rate = Config.VOTE_RATE, call = true }, function(player, a)
		local good, why = Votes.start(player, a.target, a.kind, a.reason)
		if not good then
			return nil, why
		end
		return {}
	end)
	Net.handle("Vote", "Cast", { schema = { id = V.int(1, 2 ^ 31), yes = V.bool() }, rate = Config.VOTE_RATE, call = true }, function(player, a)
		local good, why = Votes.cast(player, a.id, a.yes)
		if not good then
			return nil, why
		end
		return {}
	end)
	local function barred(p: Player)
		local untilT = kickedUntil[p.UserId]
		if untilT and os.time() < untilT then
			p:Kick(string.format("You were removed from this server by a vote. You can rejoin it in %d minutes, or join another server now.", math.ceil((untilT - os.time()) / 60)))
		end
	end
	Players.PlayerAdded:Connect(barred)
	for _, p in Players:GetPlayers() do
		barred(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		local v = running
		if not v then
			return
		end
		if v.target == p then
			task.defer(Votes.close) -- lapses: they left
			return
		end
		if v.yes[p] or v.no[p] then
			v.yes[p], v.no[p] = nil, nil
			task.defer(function()
				if running == v then
					Net.pushAll("Vote", "Tally", { id = v.id, yes = count(v.yes), no = count(v.no) })
				end
			end)
		end
	end)
end

return Votes
