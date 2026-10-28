-- T38: votes of no confidence and vote-kicks. Thresholds, one vote at a time, cooldowns, the bar
-- on a removed holder, undoing their recent grants, the kick and the rejoin bar, a target leaving,
-- closing early, the log, and the vote box on a voter's screen.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0
Config.GOALS = {} -- the "Next steps" bonuses are tested in test_onboarding
local Net = require(Shared.Net)
local Roles = require(Shared.Roles)

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Throne = require(__find(LS .. "Throne"))
local Court = require(__find(LS .. "Court"))
local Votes = require(__find(LS .. "Votes"))
local AdminLog = require(__find(LS .. "AdminLog"))

local function call(p, action, args, domain)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain or "Vote", msg, true)
end
local function last(p, remote, action)
	local list = __received(p, remote, action)
	return list[#list]
end
local NAMES = { "Alfred", "Bella", "Cecil", "Daisy", "Edwin", "Flora", "Giles", "Hattie", "Ivor", "Jane" }
local P = {}
local function join(k)
	local p = __addPlayer(1500 + k, NAMES[k])
	for _ = 1, 200 do
		if p:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	ok(call(p, "Create", { slot = "1", first = NAMES[k], last = "Tester", skin = 1, hair = "own", outfit = "frock" }, "Character").ok)
	Profiles.get(p).playtime = 3 * 3600
	return p
end
local function cast(k, yes, id)
	return call(P[k], "Cast", { id = id or Votes.current().id, yes = yes })
end

local voter
test("ten players; the King grants a title", function()
	for k = 1, 10 do
		P[k] = join(k)
	end
	__asClient(P[5], function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		voter = require(__find(root .. "VoteUI"))
		voter.init()
	end)
	__advance(0)
	ok(Throne.claim(P[1], "King"))
	ok(Court.grantTitle(P[1], P[2], "Earl", "Kew"))
	ok(P[5].PlayerGui.Economy.VotesButton.Visible)
end)

test("no confidence: only against an office; one vote at a time; 60% of at least 6 votes removes the King", function()
	local res = call(P[3], "Start", { target = P[2], kind = "confidence", reason = "Abusing the role" })
	ok(not res.ok)
	ok(string.find(res.err, "no office"), res.err)
	ok(not call(P[3], "Start", { target = P[1], kind = "confidence", reason = "Griefing" }).ok, "a kick reason isn't a confidence reason")
	res = call(P[3], "Start", { target = P[1], kind = "confidence", reason = "Abusing the role" })
	ok(res.ok, tostring(res.err))
	local open = last(P[9], "VoteEvent", "Open")
	ok(open and open.role == "King", "everyone is told")
	ok(not call(P[4], "Start", { target = P[2], kind = "kick", reason = "Griefing" }).ok, "one vote at a time")
	ok(not cast(1, false).ok, "the King can't vote on himself")
	-- the voter's screen
	local box = P[5].PlayerGui.Economy.VoteBox
	ok(box.Visible)
	ok(string.find(box.Text.Text, "No confidence in Alfred Tester as King"), box.Text.Text)
	box.Yes.Activated:Fire()
	__advance(0)
	eq(box.Yes.Text, "• Yes")
	ok(cast(4, true).ok)
	ok(cast(6, true).ok)
	ok(cast(7, false).ok)
	ok(cast(8, false).ok)
	eq(last(P[9], "VoteEvent", "Tally").yes, 4)
	__advance(Config.VOTE_SECONDS + 1)
	local closed = last(P[9], "VoteEvent", "Closed")
	ok(closed and closed.passed, closed and closed.text)
	eq(Roles.roleOf(P[1]), Config.DEFAULT_ROLE)
	eq(P[2]:GetAttribute("Title"), nil, "his grant from the last 10 minutes is undone")
	local good, why = Throne.claim(P[1], "King")
	ok(not good)
	ok(string.find(why, "voted out"), why)
	eq(AdminLog.recent(2)[1].action, "vote.confidence")
	eq(AdminLog.recent(2)[2].action, "court.undo")
	ok(not box.Visible, "the box goes when the vote closes")
end)

test("too few votes fail; a holder faces one vote per 15 minutes; a starter one per 10", function()
	ok(Throne.claim(P[2], "Queen"))
	ok(call(P[4], "Start", { target = P[2], kind = "confidence", reason = "Never here" }).ok)
	ok(cast(6, true).ok)
	ok(cast(7, true).ok)
	__advance(Config.VOTE_SECONDS + 1)
	eq(last(P[9], "VoteEvent", "Closed").passed, false, "3 votes are too few")
	eq(Roles.roleOf(P[2]), "Queen")
	local res = call(P[6], "Start", { target = P[2], kind = "confidence", reason = "Never here" })
	ok(not res.ok)
	ok(string.find(res.err, "faced a vote"), res.err)
	res = call(P[4], "Start", { target = P[3], kind = "kick", reason = "Griefing" })
	ok(not res.ok)
	ok(string.find(res.err, "another vote in"), res.err)
end)

test("a vote closes early once everyone has voted", function()
	ok(call(P[6], "Start", { target = P[2], kind = "kick", reason = "Harassment" }).ok)
	local id = Votes.current().id
	for k = 1, 10 do
		if k ~= 2 and k ~= 6 then
			ok(cast(k, false, id).ok)
		end
	end
	eq(Votes.current(), nil, "closed")
	eq(last(P[9], "VoteEvent", "Closed").passed, false)
	ok(P[2].Parent ~= nil, "not kicked")
end)

test("vote-kick: needs 8 yes (60% of the others); the kicked player can't rejoin for 30 minutes", function()
	eq(Votes.kickNeeds(), 8)
	ok(call(P[7], "Start", { target = P[10], kind = "kick", reason = "Griefing" }).ok)
	for _, k in { 1, 2, 3, 4, 5, 6 } do
		ok(cast(k, true).ok)
	end
	__advance(Config.VOTE_SECONDS + 1)
	eq(last(P[9], "VoteEvent", "Closed").passed, false, "7 yes isn't enough")
	ok(P[10].Parent ~= nil)
	ok(call(P[8], "Start", { target = P[10], kind = "kick", reason = "Griefing" }).ok)
	for _, k in { 1, 2, 3, 4, 5, 6, 7 } do
		ok(cast(k, true).ok)
	end
	ok(cast(9, false).ok) -- everyone has voted: it closes now
	eq(Votes.current(), nil)
	eq(last(P[9], "VoteEvent", "Closed").passed, true)
	ok(P[10].Parent == nil, "kicked")
	ok(string.find(P[10].__kicked, "30 minutes"), P[10].__kicked)
	eq(AdminLog.recent(1)[1].action, "vote.kick")
	local again = __addPlayer(1510, "Jane")
	ok(again.Parent == nil, "kicked again on rejoin")
	__advance(Config.KICK_BAR_SECONDS + 1)
	P[10] = __addPlayer(1510, "Jane")
	ok(P[10].Parent ~= nil, "welcome back after the bar")
end)

test("a vote on someone who leaves lapses", function()
	ok(call(P[9], "Start", { target = P[8], kind = "kick", reason = "Exploiting" }).ok)
	__removePlayer(P[8])
	__advance(0)
	eq(Votes.current(), nil)
	ok(string.find(last(P[9], "VoteEvent", "Closed").text, "lapsed"), last(P[9], "VoteEvent", "Closed").text)
end)
