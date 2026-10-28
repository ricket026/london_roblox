-- T34: the throne. Claiming an empty throne (playtime gate), only the monarch sits on it, the
-- line of succession (royals in join order, 20 s each, decline, time out, leaving), abdication,
-- the vacancy when a monarch leaves or switches character, the reign count, and the client UI.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0
Config.GOALS = {} -- the "Next steps" bonuses are tested in test_onboarding
local Net = require(Shared.Net)
local Roles = require(Shared.Roles)

-- the throne room as the place has it
local rooms = Instance.new("Folder")
rooms.Name = "PalaceInteriors"
local room = Instance.new("Model")
room.Name = "ThroneRoom"
room.Parent = rooms
local gameplay = Instance.new("Folder")
gameplay.Name = "Gameplay"
gameplay.Parent = room
local seats = {}
for k, role in { "King", "Queen" } do
	local s = Instance.new("Seat")
	s.Name = "ThroneSeat" .. k
	s.Anchored = true
	s.CFrame = CFrame.new(-1200 + k * 6, 4, -800)
	s.Parent = gameplay
	seats[role] = s
end
rooms.Parent = workspace

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Identity = require(__find(LS .. "Identity"))
local Throne = require(__find(LS .. "Throne"))

local function call(p, action, args, domain)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain or "Throne", msg, true)
end
local function join(uid, first, hours)
	local p = __addPlayer(uid, first)
	for _ = 1, 200 do
		if p:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	ok(call(p, "Create", { slot = "1", first = first, last = "Tester", skin = 1, hair = "own", outfit = "frock" }, "Character").ok)
	Profiles.get(p).playtime = hours * 3600
	return p
end
local function got(p, remote, action)
	return #__received(p, remote, action) > 0
end
local function prompt(role)
	return seats[role]:FindFirstChildWhichIsA("ProximityPrompt")
end

local A, B, C, ui
test("each throne has a claim prompt while it's empty", function()
	A = join(1101, "Albert", 3)
	ok(prompt("King") ~= nil and prompt("Queen") ~= nil)
	ok(prompt("King").Enabled)
	eq(Throne.monarch("King"), nil)
end)

test("the throne needs 2 h of playtime; a claim crowns you, proclaims it and counts the reign", function()
	local young = join(1102, "Young", 1)
	local good, why = Throne.claim(young, "King")
	ok(not good)
	ok(string.find(why, "2 h"), why)
	__clearInbox(young)
	good, why = Throne.claim(A, "King")
	ok(good, tostring(why))
	eq(Roles.roleOf(A), "King")
	eq(Throne.monarch("King"), A)
	ok(not prompt("King").Enabled, "no prompt while there's a King")
	ok(prompt("Queen").Enabled, "the Queen's throne is still free")
	ok(got(young, "ThroneEvent", "Proclaim"), "everyone hears the accession")
	eq(Throne.reigns(Profiles.progress(A), "King"), 1)
	eq(table.find(Profiles.progress(A).honours, "reign:King:1") ~= nil, true)
	local again
	good, again = Throne.claim(young, "King")
	ok(not good)
	eq(again, "The throne is taken.")
	good, again = Throne.claim(A, "Queen")
	ok(not good, "one throne at a time")
	__removePlayer(young)
end)

test("only the monarch may sit on the throne", function()
	B = join(1103, "Beatrice", 2)
	local hum = B.Character.Humanoid
	hum.Sit = true
	seats.King.Occupant = hum
	eq(hum.Sit, false, "stood up")
	local king = A.Character.Humanoid
	king.Sit = true
	seats.King.Occupant = king
	eq(king.Sit, true, "the King stays seated")
	seats.King.Occupant = nil
end)

test("abdication offers the throne down the line of succession, 20 s each", function()
	C = join(1104, "Charles", 2)
	ok(call(B, "ChooseRole", { role = "Royal" }, "Identity").ok)
	ok(call(C, "ChooseRole", { role = "Royal" }, "Identity").ok)
	eq(Identity.holdersOf("Royal")[1], B, "Beatrice joined first")
	__asClient(B, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		ui = require(__find(root .. "ThroneUI"))
		ui.init()
	end)
	__advance(0)
	__clearInbox(B)
	__clearInbox(C)
	local res = call(A, "Abdicate")
	ok(res.ok, tostring(res.err))
	eq(Roles.roleOf(A), Config.DEFAULT_ROLE)
	__advance(0)
	ok(got(B, "ThroneEvent", "Offer"), "Beatrice is asked first")
	ok(not got(C, "ThroneEvent", "Offer"))
	ok(not prompt("King").Enabled, "no claims while it's on offer")
	local good, why = Throne.claim(A, "King")
	ok(not good)
	ok(string.find(why, "offered"), why)
	ok(B.PlayerGui.Economy.ThroneOffer.Visible, "the offer shows")
	ok(string.find(B.PlayerGui.Economy.ThroneOffer.Text.Text, "king's throne"), B.PlayerGui.Economy.ThroneOffer.Text.Text)
	-- Beatrice lets it pass; Charles is asked
	__advance(Config.THRONE_OFFER_SECONDS + 1)
	ok(got(C, "ThroneEvent", "Offer"), "then Charles")
	ok(not B.PlayerGui.Economy.ThroneOffer.Visible, "Beatrice's offer has gone")
	res = call(B, "Accept", { role = "King" })
	ok(not res.ok, "too late")
	res = call(C, "Decline", { role = "King" })
	ok(res.ok)
	-- nobody left in line: open to claims
	ok(prompt("King").Enabled)
	local good2 = Throne.claim(A, "King")
	ok(good2, "anyone eligible may claim it now")
	eq(Throne.reigns(Profiles.progress(A), "King"), 2, "a second reign")
	eq(#Profiles.progress(A).honours, 1, "one honours entry, counted up")
end)

test("a monarch leaving the server: the line is asked again, and the UI accepts", function()
	__clearInbox(B)
	__removePlayer(A)
	__advance(0)
	eq(Throne.monarch("King"), nil)
	ok(got(B, "ThroneEvent", "Offer"), "a new vacancy asks from the top")
	ok(B.PlayerGui.Economy.ThroneOffer.Visible)
	B.PlayerGui.Economy.ThroneOffer.Accept.Activated:Fire()
	__advance(0)
	eq(Roles.roleOf(B), "King")
	eq(Throne.monarch("King"), B)
	eq(#Identity.holdersOf("Royal"), 1, "her royal seat is free")
	eq(Identity.holdersOf("Royal")[1], C)
	eq(Throne.reigns(Profiles.progress(B), "King"), 1)
	ok(B.PlayerGui.Economy.Reign.Visible, "the reign panel")
	ok(not B.PlayerGui.Economy.ThroneOffer.Visible)
	local monarchs = ui.state()
	eq(monarchs.King, "Beatrice Tester")
end)

test("abdicate from the UI takes two taps", function()
	local abdicate = B.PlayerGui.Economy.Reign.Abdicate
	abdicate.Activated:Fire()
	__advance(0)
	eq(Roles.roleOf(B), "King", "the first tap only asks")
	eq(abdicate.Text, "Sure? Tap again")
	abdicate.Activated:Fire()
	__advance(0)
	eq(Roles.roleOf(B), Config.DEFAULT_ROLE)
	ok(not B.PlayerGui.Economy.Reign.Visible)
	ok(got(C, "ThroneEvent", "Offer"), "Charles is next in line")
	ok(call(C, "Accept", { role = "King" }).ok)
	eq(Throne.monarch("King"), C)
end)

test("switching character frees the throne", function()
	__clearInbox(B)
	Identity.resetRole(C) -- what Characters does on a switch
	__advance(0)
	eq(Throne.monarch("King"), nil)
	ok(got(B, "ThroneEvent", "Proclaim"), "the empty throne is proclaimed")
	ok(prompt("King").Enabled, "no royals left: open to claims")
	ok(not call(B, "Abdicate").ok, "only a monarch can abdicate")
	ok(not call(B, "Accept", { role = "Queen" }).ok, "nothing on offer")
	ok(not call(B, "Accept", { role = "Emperor" }).ok, "no such throne")
end)
