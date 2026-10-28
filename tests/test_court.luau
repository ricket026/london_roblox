-- T35 + T08: forms of address (Shared.Titles), titles and caps, offices and royal invitations
-- (offers), revocation with a reason, the grant cooldown, logging, the saved highest honour,
-- titles ending with the character, undoing a removed granter's grants, and the Court menu.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0
local Net = require(Shared.Net)
local Roles = require(Shared.Roles)
local Titles = require(Shared.Titles)

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Identity = require(__find(LS .. "Identity"))
local Throne = require(__find(LS .. "Throne"))
local Court = require(__find(LS .. "Court"))
local AdminLog = require(__find(LS .. "AdminLog"))

local function call(p, action, args, domain)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain or "Court", msg, true)
end
local function got(p, remote, action)
	return #__received(p, remote, action) > 0
end
local function last(p, remote, action)
	local list = __received(p, remote, action)
	return list[#list]
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
local function tag(p)
	local t = p.Character:FindFirstChild("RPTag")
	return t.RPName.Text, t.RPRole.Text
end
local function wait(s)
	__advance(s or Config.COURT_GRANT_COOLDOWN + 1)
end

test("forms of address", function()
	local function a(info)
		info.first, info.last = info.first or "Ada", info.last or "Grey"
		return table.pack(Titles.address(info))
	end
	local t = a({ role = "Citizen" })
	eq(t[1], "Ada Grey")
	eq(t[2], "")
	eq(a({ role = "Queen" })[2], "Their Majesty the Queen", "neutral by default")
	eq(a({ role = "Queen", form = "her" })[2], "Her Majesty the Queen")
	eq(a({ role = "Royal", form = "his", title = "Duke", place = "Kew" })[2], "His Royal Highness the Duke of Kew")
	eq(a({ role = "Citizen", title = "Duke", place = "Kew" })[2], "Their Grace the Duke of Kew")
	eq(a({ role = "Postman", roleName = "Postman", title = "Earl", place = "Soho", form = "her" })[2], "The Rt Hon. the Countess of Soho · Postman")
	eq(a({ title = "Viscount", place = "Pimlico" })[2], "The Rt Hon. the Viscount Pimlico")
	eq(a({ title = "Baron", place = "Pimlico", form = "his" })[2], "The Rt Hon. the Lord Pimlico")
	eq(a({ title = "Baron", place = "Pimlico" })[2], "The Rt Hon. the Baron Pimlico")
	t = a({ title = "Knight", form = "her" })
	eq(t[1], "Dame Ada Grey")
	eq(t[2], "")
	eq(a({ title = "Knight", form = "his" })[1], "Sir Ada Grey")
	eq(a({ title = "Knight" })[2], "Knight of the Realm")
	eq(a({ role = "MP" })[1], "Ada Grey MP")
	eq(a({ role = "Constable" })[1], "Constable Grey")
	ok(Titles.precedence("King") > Titles.precedence("Citizen", "Duke"))
	ok(Titles.precedence("Citizen", "Duke") > Titles.precedence("MP", "Knight"))
	ok(Titles.better("Earl", "Knight"))
	ok(not Titles.better("Baron", "Earl"))
	ok(Titles.better("Knight", nil))
end)

local M, A, B, C, D
test("only the Crown grants titles; a grant is proclaimed, logged, shown on the tag and remembered", function()
	M = join(1201, "Margaret", 3)
	A = join(1202, "Agnes", 1)
	B = join(1203, "Bertram", 1)
	C = join(1204, "Cyril", 1)
	D = join(1205, "Dora", 2)
	local good, why = Court.grantTitle(A, B, "Earl", "Kew")
	ok(not good)
	ok(string.find(why, "King or Queen"), why)
	ok(Throne.claim(M, "Queen"))
	local n1, n2 = tag(M)
	eq(n1, "Margaret Tester")
	eq(n2, "Their Majesty the Queen")
	__clearInbox(B)
	local res = call(M, "GrantTitle", { target = A, rank = "Earl", place = "Kew" })
	ok(res.ok, tostring(res.err))
	eq(A:GetAttribute("Title"), "Earl")
	eq(A:GetAttribute("TitlePlace"), "Kew")
	local p = last(B, "ThroneEvent", "Proclaim")
	ok(p and string.find(p.text, "Agnes Tester is made the Earl of Kew"), p and p.text)
	eq(AdminLog.recent(1)[1].action, "court.title")
	eq(AdminLog.recent(1)[1].target, A.UserId)
	eq(select(2, tag(A)), "The Rt Hon. the Earl of Kew")
	eq(Court.highestHonour(A), "Earl")
	res = call(M, "GrantTitle", { target = M, rank = "Duke", place = "Soho" })
	ok(not res.ok, "not to yourself")
end)

test("one grant a minute; caps, places and the order of ranks", function()
	local good, why = Court.grantTitle(M, B, "Duke", "Soho")
	ok(not good)
	ok(string.find(why, "another grant in"), why)
	wait()
	good, why = Court.grantTitle(M, B, "Earl", "Kew")
	ok(not good, "one Earl of Kew at a time")
	ok(string.find(why, "Agnes Tester is the Earl of Kew already"), why)
	ok(Court.grantTitle(M, B, "Duke", "Soho"))
	wait()
	ok(Court.grantTitle(M, C, "Duke", "Hoxton"))
	wait()
	good, why = Court.grantTitle(M, D, "Duke", "Wapping")
	ok(not good)
	ok(string.find(why, "as many Dukes"), why)
	good, why = Court.grantTitle(M, A, "Knight", "Kew")
	ok(not good)
	eq(why, "They hold a higher title already.")
	ok(Court.grantTitle(M, A, "Marquess", "Kew"), "a promotion replaces the lower title")
	eq(A:GetAttribute("Title"), "Marquess")
	eq(Court.highestHonour(A), "Marquess")
	local n = 0
	for _, h in Profiles.progress(A).honours do
		n += if string.find(h, "^honour:") then 1 else 0
	end
	eq(n, 1, "one saved honour, the highest")
	local v = Court.view(M)
	eq(v.caps.Duke.used, 2)
	eq(v.caps.Duke.cap, 2)
	ok(v.cooldown > 0)
	ok(v.monarch)
end)

test("the player chooses how they're addressed", function()
	ok(call(A, "SetForm", { form = "her" }).ok)
	eq(Profiles.get(A).settings.address, "her")
	eq(select(2, tag(A)), "The Rt Hon. the Marchioness of Kew")
	ok(not call(A, "SetForm", { form = "milady" }).ok, "only the three forms")
	eq(Court.view(A).style, "The Rt Hon. the Marchioness of Kew")
end)

test("an office is offered and must be accepted; the Lord Chamberlain appoints Equerries", function()
	wait()
	__clearInbox(B)
	local res = call(M, "Appoint", { target = B, office = "LordChamberlain" })
	ok(res.ok, tostring(res.err))
	eq(Roles.roleOf(B), "Citizen", "not until they accept")
	local o = last(B, "CourtEvent", "Offer")
	ok(o and string.find(o.text, "Lord Chamberlain"), o and o.text)
	ok(not call(C, "Answer", { id = o.id, accept = true }).ok, "only the one offered")
	ok(call(B, "Answer", { id = o.id, accept = true }).ok)
	eq(Roles.roleOf(B), "LordChamberlain")
	eq(Court.highestHonour(B), "LordChamberlain", "the office outranks a dukedom")
	eq(select(2, tag(B)), "Their Grace the Duke of Soho · Lord Chamberlain")
	ok(got(M, "CourtEvent", "Closed"))
	-- the Lord Chamberlain appoints an Equerry, but not a Private Secretary
	local good, why = Court.appoint(B, C, "PrivateSecretary")
	ok(not good)
	ok(string.find(why, "can't appoint"), why)
	__clearInbox(B)
	ok(Court.appoint(B, C, "Equerry"))
	o = last(C, "CourtEvent", "Offer")
	ok(call(C, "Answer", { id = o.id, accept = false }).ok)
	eq(Roles.roleOf(C), "Citizen")
	eq(last(B, "CourtEvent", "Closed").result, "declined")
end)

test("offers run out; the royal family by invitation", function()
	wait()
	__clearInbox(M)
	ok(Court.appoint(M, D, "Equerry"))
	local o = last(D, "CourtEvent", "Offer")
	__advance(Config.COURT_OFFER_SECONDS + 1)
	eq(last(M, "CourtEvent", "Closed").result, "expired")
	ok(not call(D, "Answer", { id = o.id, accept = true }).ok, "too late")
	wait()
	ok(Court.inviteRoyal(M, D))
	o = last(D, "CourtEvent", "Offer")
	ok(string.find(o.text, "royal family"), o.text)
	ok(call(D, "Answer", { id = o.id, accept = true }).ok)
	eq(Roles.roleOf(D), "Royal")
	ok(table.find(Identity.holdersOf("Royal"), D) ~= nil)
	eq(select(2, tag(D)), "Their Royal Highness")
end)

test("revoking needs a reason, is logged and proclaimed", function()
	wait()
	local res = call(M, "Revoke", { target = A, kind = "title", reason = "" })
	ok(not res.ok, "no reason, no revocation")
	res = call(M, "Revoke", { target = A, kind = "title", reason = "Rude at court" })
	ok(res.ok, tostring(res.err))
	eq(A:GetAttribute("Title"), nil)
	eq(AdminLog.recent(1)[1].action, "court.revoke")
	ok(string.find(AdminLog.recent(1)[1].reason, "Rude at court"), AdminLog.recent(1)[1].reason)
	ok(string.find(last(C, "ThroneEvent", "Proclaim").text, "no longer Marchioness of Kew"))
	eq(Court.highestHonour(A), "Marquess", "the saved honour stays")
	wait()
	ok(call(M, "Revoke", { target = B, kind = "office", reason = "Retired" }).ok)
	eq(Roles.roleOf(B), Config.DEFAULT_ROLE)
	wait()
	ok(not call(M, "Revoke", { target = A, kind = "office", reason = "x" }).ok, "nothing to take")
end)

test("a title ends with the character; a removed granter's recent grants are undone", function()
	wait()
	ok(Court.grantTitle(M, A, "Knight", "Kew"))
	eq(A:GetAttribute("TitlePlace"), nil, "knights have no place")
	A:SetAttribute("CharSlot", "2") -- switching character
	eq(A:GetAttribute("Title"), nil)
	A:SetAttribute("CharSlot", "1")
	__advance(Config.COURT_UNDO_WINDOW)
	ok(Court.grantTitle(M, A, "Baron", "Pimlico"))
	wait()
	ok(Court.inviteRoyal(M, B))
	ok(call(B, "Answer", { id = last(B, "CourtEvent", "Offer").id, accept = true }).ok)
	eq(Court.undoGrantsBy(M), 2, "Agnes's barony and Bertram's royal seat")
	eq(A:GetAttribute("Title"), nil)
	eq(Roles.roleOf(B), Config.DEFAULT_ROLE)
	eq(Roles.roleOf(D), "Royal", "older than the undo window")
	eq(C:GetAttribute("Title"), "Duke")
	eq(AdminLog.recent(1)[1].action, "court.undo")
end)

test("the Court menu: choose, grant with a confirm", function()
	local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
	__asClient(M, function()
		require(__find(root .. "EconomyUI")).init()
		require(__find(root .. "CourtUI")).init()
	end)
	__advance(0)
	local gui = M.PlayerGui.Economy
	ok(gui.CourtButton.Visible, "the Queen has the Court button")
	wait()
	gui.CourtButton.Activated:Fire()
	__advance(0)
	ok(gui.CourtPanel.Visible)
	local function press(rowStart, label)
		for _, d in gui.CourtPanel.Body:GetDescendants() do
			if d:IsA("TextButton") and d.Text == label then
				local lab = d.Parent:FindFirstChild("Label")
				if rowStart == nil or (lab and string.sub(lab.Text, 1, #rowStart) == rowStart) then
					d.Activated:Fire()
					__advance(0)
					return true
				end
			end
		end
		return false
	end
	ok(press("Cyril Tester", "Choose"), "Cyril is listed")
	ok(press("Viscount", "Grant"))
	local confirm = false
	for _, d in gui.CourtPanel.Body:GetChildren() do
		if d:IsA("TextLabel") and string.find(d.Text, "Make Cyril Tester Viscount of Kew%?") then
			confirm = true
		end
	end
	ok(confirm, "asks first")
	eq(C:GetAttribute("Title"), "Duke", "nothing yet")
	ok(press(nil, "Confirm"))
	eq(C:GetAttribute("Title"), "Duke", "a Duke can't be made a Viscount")
	wait()
	ok(press("Equerry", "Offer"), "still on Cyril after a grant")
	ok(press(nil, "Confirm"))
	local o = last(C, "CourtEvent", "Offer")
	ok(o and string.find(o.text, "Equerry"), "Cyril is offered it")
	ok(call(C, "Answer", { id = o.id, accept = true }).ok)
	eq(Roles.roleOf(C), "Equerry")
	ok(gui.CourtPanel.Visible, "the menu stays open and refreshes")
	-- the form of address buttons
	ok(press("Address me as", "His"))
	eq(Profiles.get(M).settings.address, "his")
	eq(select(2, tag(M)), "His Majesty the Queen")
end)

test("an offer lapses if the one who made it can no longer appoint", function()
	wait()
	ok(Court.appoint(M, A, "Equerry"))
	local o = last(A, "CourtEvent", "Offer")
	ok(Throne.abdicate(M))
	__advance(0)
	local res = call(A, "Answer", { id = o.id, accept = true })
	ok(not res.ok)
	ok(string.find(res.err, "no longer"), res.err)
	eq(Roles.roleOf(A), Config.DEFAULT_ROLE)
end)
