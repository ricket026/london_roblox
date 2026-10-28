-- T36: the throne room. Who's inside (RoomZone), Open / Closed / Session, showing out those not
-- admitted, guests, speaking only with the floor in session (chat delivery and quick phrases),
-- warnings and contempt, the floor's time, the audience book and queue, and the Room panel.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0
Config.GOALS = {} -- the "Next steps" bonuses are tested in test_onboarding
local Net = require(Shared.Net)

-- the throne room as london.rbxl has it
local rooms = Instance.new("Folder")
rooms.Name = "PalaceInteriors"
local room = Instance.new("Model")
room.Name = "ThroneRoom"
room.Parent = rooms
local gameplay = Instance.new("Folder")
gameplay.Name = "Gameplay"
gameplay.Parent = room
local zone = Instance.new("Part")
zone.Name = "RoomZone"
zone.Anchored, zone.CanCollide, zone.Transparency = true, false, 1
zone.Size = Vector3.new(96.3, 19.4, 32)
zone.CFrame = CFrame.new(142.35, 28.3, 476.5)
zone.Parent = gameplay
rooms.Parent = workspace

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Identity = require(__find(LS .. "Identity"))
local Throne = require(__find(LS .. "Throne"))
local ThroneRoom = require(__find(LS .. "ThroneRoom"))
local Speech = require(__find(LS .. "Speech"))
local AdminLog = require(__find(LS .. "AdminLog"))

local function call(p, action, args, domain)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain or "Room", msg, true)
end
local function last(p, remote, action)
	local list = __received(p, remote, action)
	return list[#list]
end
local function join(uid, first)
	local p = __addPlayer(uid, first)
	for _ = 1, 200 do
		if p:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	ok(call(p, "Create", { slot = "1", first = first, last = "Tester", skin = 1, hair = "own", outfit = "frock" }, "Character").ok)
	Profiles.get(p).playtime = 3 * 3600
	return p
end
local IN = Vector3.new(150, 21.6, 476)
local OUT = Vector3.new(60, 21.6, 476)
local LEDGER = Vector3.new(Config.THRONE_ROOM_LEDGER.x + 3, 21.6, Config.THRONE_ROOM_LEDGER.z)
local function stand(p, at)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(at)
end
local function pos(p)
	return p.Character.HumanoidRootPart.Position
end

local K, L, A, B, roomUI
test("who is in the room; the audience book stands by the door", function()
	K = join(1601, "Kingsley")
	L = join(1602, "Lavinia")
	A = join(1603, "Archie")
	B = join(1604, "Blanche")
	stand(A, IN)
	ok(ThroneRoom.inside(A))
	stand(A, OUT)
	ok(not ThroneRoom.inside(A))
	ok(workspace.ThroneRoomProps.AudienceBook:FindFirstChildWhichIsA("ProximityPrompt") ~= nil)
	eq(room:GetAttribute("Protocol"), "Open")
end)

test("only those who preside set the protocol; a closed room shows out all but the Household and guests", function()
	ok(not call(A, "SetState", { state = "Closed" }).ok)
	ok(Throne.claim(K, "King"))
	ok(Identity.grant(L, "LordChamberlain"))
	ok(ThroneRoom.presides(L))
	stand(K, IN)
	stand(A, IN)
	stand(B, IN)
	ok(call(K, "Invite", { target = B }).ok)
	ok(call(L, "SetState", { state = "Closed" }).ok)
	eq(room:GetAttribute("Protocol"), "Closed")
	__advance(Config.THRONE_ROOM_CHECK + 0.1)
	ok(not ThroneRoom.inside(A), "Archie is shown out")
	ok((pos(A) - Vector3.new(Config.THRONE_ROOM_EXIT.x, Config.THRONE_ROOM_EXIT.y, Config.THRONE_ROOM_EXIT.z)).Magnitude < 1, "to the South Saloon door")
	ok(ThroneRoom.inside(K), "the King stays")
	ok(ThroneRoom.inside(B), "a guest stays")
	ok(string.find(last(A, "RoomEvent", "Notice").text, "closed"), "told why")
	eq(AdminLog.recent(1)[1].action, "court.protocol")
end)

test("in session only the Monarch and the floor are heard inside; outsiders aren't heard in", function()
	ok(call(K, "SetState", { state = "Session" }).ok)
	stand(A, IN)
	ok(ThroneRoom.maySpeak(K))
	ok(not ThroneRoom.maySpeak(A))
	ok(ThroneRoom.maySpeak(L) or not ThroneRoom.inside(L), "outside the room anyone talks")
	ok(not ThroneRoom.shouldDeliver(A, B), "Archie isn't heard")
	ok(ThroneRoom.shouldDeliver(K, B), "the King is")
	stand(L, OUT)
	ok(not ThroneRoom.shouldDeliver(L, B), "outside isn't heard inside")
	ok(ThroneRoom.shouldDeliver(L, A) == false, "Archie is inside too")
	stand(A, OUT)
	ok(ThroneRoom.shouldDeliver(L, A), "outside to outside is fine")
	stand(A, IN)
	-- quick phrases too, with warnings, then contempt
	ok(not Speech.say(A, "morning") or false)
	ok(string.find(last(A, "RoomEvent", "Warn").text, "warning 1 of 2"), last(A, "RoomEvent", "Warn").text)
	Speech.say(A, "morning")
	Speech.say(A, "morning")
	__advance(0)
	ok(not ThroneRoom.inside(A), "shown out for contempt")
	eq(AdminLog.recent(1)[1].action, "court.contempt")
end)

test("the floor: given, timed, extended, taken back", function()
	stand(A, IN)
	ok(not call(A, "GiveFloor", { target = A }).ok, "not by just anyone")
	stand(B, OUT)
	ok(not call(K, "GiveFloor", { target = B }).ok, "only to someone in the room")
	ok(call(K, "GiveFloor", { target = A }).ok)
	ok(ThroneRoom.maySpeak(A))
	ok(Speech.say(A, "morning"), "now Archie may speak")
	__advance(Config.FLOOR_SECONDS - 10)
	ok(call(L, "Extend").ok)
	__advance(20)
	ok(ThroneRoom.maySpeak(A), "extended")
	ok(call(L, "TakeFloor").ok)
	ok(not ThroneRoom.maySpeak(A))
	ok(call(K, "GiveFloor", { target = A }).ok)
	__advance(Config.FLOOR_SECONDS + 1)
	ok(not ThroneRoom.maySpeak(A), "the floor runs out")
end)

test("audiences: ask at the book, the queue, Up, Call (announced, a guest, the mark, the floor), Decline", function()
	stand(A, OUT)
	ok(not call(A, "Request", { reason = "A petition" }).ok, "only at the audience book")
	stand(A, LEDGER)
	stand(B, LEDGER)
	ok(call(A, "Request", { reason = "To ask for a pardon" }).ok)
	ok(not call(A, "Request", { reason = "Again" }).ok, "once")
	ok(call(B, "Request", { reason = "To present a gift" }).ok)
	eq(call(A, "Get").data.place, 1)
	local q = call(L, "Get").data.queue
	eq(#q, 2)
	eq(q[1].name, "Archie Tester")
	ok(call(L, "Up", { target = B }).ok)
	eq(call(L, "Get").data.queue[1].name, "Blanche Tester")
	__clearInbox(K)
	ok(call(L, "Call", { target = B }).ok)
	ok(string.find(last(K, "RoomEvent", "Called").text, "Blanche Tester, for an audience: \"To present a gift\""), "announced in the room")
	ok(last(B, "RoomEvent", "Mark") ~= nil, "shown the mark")
	ok(call(B, "Get").data.guest, "a guest of a closed room")
	stand(B, IN)
	ok(ThroneRoom.maySpeak(B), "and has the floor")
	eq(AdminLog.recent(1)[1].action, "court.audience")
	ok(call(L, "Decline", { target = A }).ok)
	ok(string.find(last(A, "RoomEvent", "Notice").text, "declined"))
	eq(#call(L, "Get").data.queue, 0)
end)

test("the Room panel and the audience box", function()
	__asClient(K, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		roomUI = require(__find(root .. "ThroneRoomUI"))
		roomUI.init()
	end)
	__advance(1)
	local gui = K.PlayerGui.Economy
	ok(gui.RoomButton.Visible, "the King has the Room button")
	stand(K, IN)
	__advance(1)
	ok(gui.RoomStatus.Visible)
	ok(string.find(gui.RoomStatus.Text, "In session"), gui.RoomStatus.Text)
	gui.RoomButton.Activated:Fire()
	__advance(0)
	local pressed = false
	for _, d in gui.RoomPanel.Body:GetDescendants() do
		if d:IsA("TextButton") and d.Text == "Open" then
			d.Activated:Fire()
			pressed = true
			break
		end
	end
	ok(pressed)
	__advance(0)
	eq(ThroneRoom.state(), "Open")
	-- the audience box (the prompt at the book pushes Ask)
	stand(K, LEDGER)
	Net.push(K, "Room", "Ask", {})
	__advance(0)
	ok(gui.AudienceAsk.Visible)
	gui.AudienceAsk.Reason.Text = "To ask myself a question"
	gui.AudienceAsk.Ask.Activated:Fire()
	__advance(0)
	eq(call(K, "Get").data.queue[1].name, "Kingsley Tester")
	ok(not gui.AudienceAsk.Visible)
end)

test("leaving clears the floor and the queue", function()
	__advance(Config.AUDIENCE_RATE.per) -- past the call rate limit
	stand(A, LEDGER)
	ok(call(A, "Request", { reason = "One more thing" }).ok)
	stand(A, IN)
	ok(call(K, "GiveFloor", { target = A }).ok)
	__removePlayer(A)
	__advance(0)
	local v = call(K, "Get").data
	eq(v.floor, nil)
	eq(#v.queue, 1, "only the King's own petition is left")
end)
