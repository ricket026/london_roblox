-- T37: royal decrees. Only the Crown, one per 10 minutes a server, filtered, banner to everyone,
-- the decree boards, the log, the bank holiday lever (job pay ×1.5 for a game day, once a real
-- day), and writing one from the Court menu.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0
local Net = require(Shared.Net)

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Throne = require(__find(LS .. "Throne"))
local Decrees = require(__find(LS .. "Decrees"))
local Jobs = require(__find(LS .. "Jobs"))
local AdminLog = require(__find(LS .. "AdminLog"))

local function call(p, action, args, domain)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain or "Decree", msg, true)
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
local function boardText(k)
	local board = workspace.DecreeBoards:FindFirstChild("DecreeBoard" .. k).Board
	for _, g in board:GetChildren() do
		if g:IsA("SurfaceGui") and g.Face == Enum.NormalId.Front then
			return g:FindFirstChildWhichIsA("TextLabel").Text
		end
	end
	return nil
end

local Q, P
test("the decree boards stand at their places", function()
	eq(#workspace.DecreeBoards:GetChildren(), #Config.DECREE_BOARDS)
	ok(string.find(boardText(1), "None yet"), boardText(1))
	eq(workspace.DecreeBoards.DecreeBoard2:GetAttribute("Place"), "Charing Cross")
end)

test("only the King or Queen issues decrees; everyone sees it; boards and the log keep it", function()
	Q = join(1401, "Quentin", 3)
	P = join(1402, "Prudence", 1)
	local res = call(P, "Issue", { title = "Free buns", text = "Buns for all." })
	ok(not res.ok)
	ok(string.find(res.err, "King or Queen"), res.err)
	ok(Throne.claim(Q, "King"))
	__censor = { "rotten" }
	res = call(Q, "Issue", { title = "On the rotten fish", text = "Fishmongers shall sell no rotten fish." })
	ok(res.ok, tostring(res.err))
	local d = last(P, "DecreeEvent", "Issued")
	ok(d ~= nil, "everyone hears it")
	eq(d.title, "On the ###### fish", "filtered")
	ok(string.find(d.by, "Quentin Tester, His Majesty the King"), d.by)
	ok(string.find(boardText(3), "ON THE ###### FISH"), boardText(3))
	eq(AdminLog.recent(1)[1].action, "court.decree")
	eq(#Decrees.recent(), 1)
	__censor = {}
end)

test("one decree per ten minutes; titles are cut to length; words are needed", function()
	local res = call(Q, "Issue", { title = "Again", text = "More." })
	ok(not res.ok)
	ok(string.find(res.err, "next decree"), res.err)
	ok(not call(Q, "Issue", { title = "No words", text = "" }).ok, "empty text is rejected")
	__advance(Config.DECREE_COOLDOWN + 1)
	res = call(Q, "Issue", { title = string.rep("Long ", 30), text = "A long title." })
	ok(res.ok, tostring(res.err))
	ok(#Decrees.recent()[1].title <= Config.DECREE_TITLE_MAX, "cut to " .. Config.DECREE_TITLE_MAX)
	eq(Decrees.recent()[2].title, "On the ###### fish", "newest first")
end)

test("a bank holiday: job pay and its cap ×1.5 for a game day, once a real day", function()
	ok(call(P, "ChooseRole", { role = "Postman" }, "Identity").ok)
	local before = Jobs.pay(P, "Postman", 100, "test")
	eq(before, 100)
	__advance(Config.DECREE_COOLDOWN + 1)
	local res = call(Q, "Issue", { title = "A bank holiday", text = "Rest and be merry.", lever = "bank_holiday" })
	ok(res.ok, tostring(res.err))
	ok(Decrees.holiday())
	eq(Jobs.pay(P, "Postman", 100, "test"), 150)
	ok(not call(Q, "Issue", { title = "x", text = "y", lever = "dragons" }).ok, "unknown levers are rejected")
	__advance(Config.DECREE_COOLDOWN + 1)
	res = call(Q, "Issue", { title = "Another holiday", text = "More rest.", lever = "bank_holiday" })
	ok(not res.ok)
	ok(string.find(res.err, "today already"), res.err)
	__advance(Config.BANK_HOLIDAY_SECONDS)
	ok(not Decrees.holiday(), "over after a game day")
	local after = Jobs.pay(P, "Postman", 100, "test")
	ok(after == 100 or after < 100, "back to normal pay (or the cap)")
	local view = call(Q, "Get").data
	ok(view.levers[1].why ~= nil, "the menu says why the lever is spent")
end)

test("writing a decree in the Court menu, and the banner", function()
	__asClient(Q, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		require(__find(root .. "CourtUI")).init()
	end)
	__advance(Config.DECREE_COOLDOWN + 1)
	local gui = Q.PlayerGui.Economy
	gui.CourtButton.Activated:Fire()
	__advance(0)
	local body = gui.CourtPanel.Body
	local title, text
	for _, d in body:GetDescendants() do
		if d.Name == "DecreeTitle" then
			title = d
		elseif d.Name == "DecreeText" then
			text = d
		end
	end
	ok(title and text, "the decree boxes")
	title.Text = "The Season opens"
	text.Text = "Let there be a ball at the palace."
	local function press(label)
		for _, d in body:GetDescendants() do
			if d:IsA("TextButton") and d.Text == label then
				d.Activated:Fire()
				__advance(0)
				return true
			end
		end
		return false
	end
	ok(press("Issue"))
	ok(press("Confirm"), "asks first")
	eq(Decrees.recent()[1].title, "The Season opens")
	ok(gui.Decree.Visible, "the banner")
	ok(string.find(gui.Decree.Head.Text, "THE SEASON OPENS"), gui.Decree.Head.Text)
	__advance(Config.DECREE_SHOW_SECONDS + 1)
	ok(not gui.Decree.Visible, "and it goes")
end)
