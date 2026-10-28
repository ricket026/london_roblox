-- T33: letters. To someone here or a Roblox friend (offline too), the direct-chat check on send
-- and on read, filtered for the reader, the stamp, the daily limit, a full letterbox, letters
-- waiting for the next join, old letters thrown away, and the Letters panel.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0
Config.GOALS = {}
Config.LETTER_DAILY, Config.LETTER_BOX = 4, 3
local Net = require(Shared.Net)

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Letters = require(__find(LS .. "Letters"))

local function call(p, action, args, domain)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain or "Letter", msg, true)
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
	return p
end

local A, B, ui
test("a letter to someone here: the stamp, it arrives, read once filtered", function()
	A = join(2001, "Ada")
	B = join(2002, "Bert")
	__asClient(B, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		ui = require(__find(root .. "LettersUI"))
		ui.init()
	end)
	__advance(0)
	Profiles.get(A).pence = 100
	local c = call(A, "Contacts").data
	eq(c.contacts[1].name, "Bert Tester")
	ok(c.contacts[1].here)
	__censor = { "beastly" }
	local res = call(A, "Send", { to = B.UserId, text = "Dear Bert, a beastly day. Tea at four?" })
	ok(res.ok, tostring(res.err))
	eq(Profiles.get(A).pence, 100 - Config.LETTER_STAMP, "a stamp")
	ok(last(B, "LetterEvent", "Arrived") ~= nil, "Bert hears it arrive")
	local box = call(B, "Box").data.letters
	eq(#box, 1)
	eq(box[1].fromName, "Ada Tester")
	eq(box[1].read, false)
	local l = call(B, "Read", { id = box[1].id }).data
	eq(l.text, "Dear Bert, a ####### day. Tea at four?", "filtered for the reader")
	ok(call(B, "Box").data.letters[1].read, "marked read")
	__censor = {}
	ok(not call(A, "Read", { id = box[1].id }).ok, "only from your own letterbox")
end)

test("only to people here or friends; never when they may not chat", function()
	__advance(Config.LETTER_RATE.per) -- past the call rate limit
	local res = call(A, "Send", { to = 2003, text = "Hello" })
	ok(not res.ok)
	ok(string.find(res.err, "Roblox friends"), res.err)
	__friends["2001:2003"] = true
	ok(call(A, "Send", { to = 2003, text = "Hello, old friend" }).ok, "a friend who isn't here")
	__noDirectChat["2001:2002"] = true
	res = call(A, "Send", { to = B.UserId, text = "Again" })
	ok(not res.ok)
	ok(string.find(res.err, "can't send"), res.err)
	local id = call(B, "Box").data.letters[1].id
	ok(not call(B, "Read", { id = id }).ok, "nor read")
	__noDirectChat = {}
	ok(not call(A, "Send", { to = A.UserId, text = "Me" }).ok, "not to yourself")
end)

test("the daily limit, a full letterbox, no money for a stamp", function()
	__advance(Config.LETTER_RATE.per) -- past the call rate limit
	ok(call(A, "Send", { to = B.UserId, text = "Three" }).ok)
	ok(call(A, "Send", { to = B.UserId, text = "Four" }).ok)
	local res = call(A, "Send", { to = B.UserId, text = "Five" })
	ok(not res.ok)
	ok(string.find(res.err, "today"), res.err)
	local C = join(2004, "Cora")
	Profiles.get(C).pence = 10
	res = call(C, "Send", { to = B.UserId, text = "Hello" })
	ok(not res.ok, "Bert's letterbox holds 3")
	ok(string.find(res.err, "full"), res.err)
	eq(Profiles.get(C).pence, 10, "no stamp for a letter that wasn't posted")
	ok(call(B, "Delete", { id = call(B, "Box").data.letters[1].id }).ok)
	Profiles.get(C).pence, Profiles.get(C).bank = 0, 0
	res = call(C, "Send", { to = B.UserId, text = "Hello" })
	ok(not res.ok)
	ok(string.find(res.err, "stamp costs"), res.err)
end)

test("letters wait for the next join; old ones are thrown away", function()
	__advance(Config.LETTER_RATE.per) -- past the call rate limit
	local D = join(2003, "Dot")
	__advance(0.5)
	local n = last(D, "LetterEvent", "Count")
	ok(n and n.unread == 1, "told of the letter from Ada")
	-- backdate the letter rather than run the clock for a month
	local store = require(__find(LS .. "Store")).open(Config.LETTER_STORE)
	store:update("m_" .. D.UserId, function(list)
		for _, l in list do
			l.at -= Config.LETTER_KEEP_DAYS * 86400 + 60
		end
		return list
	end)
	eq(#Letters.box(D), 0, "thrown away after the keep days")
end)

test("the Letters panel: the count, Read, Write", function()
	__advance(Config.LETTER_RATE.per) -- past the call rate limit
	local gui = B.PlayerGui.Economy
	Profiles.get(A).settings.letterDay = nil -- a new day for Ada
	ok(call(A, "Send", { to = B.UserId, text = "A fresh note" }).ok)
	__advance(0)
	ok(string.find(gui.More.LettersButton.Text, "Letters %(%d%)"), gui.More.LettersButton.Text)
	gui.More.LettersButton.Activated:Fire()
	__advance(1) -- the letterbox is read from the (mock) DataStore
	ok(gui.LettersPanel.Visible)
	local function press(label)
		for _, d in gui.LettersPanel.Body:GetDescendants() do
			if d:IsA("TextButton") and d.Text == label then
				d.Activated:Fire()
				__advance(1)
				return true
			end
		end
		return false
	end
	ok(press("Read"))
	local text = ""
	for _, d in gui.LettersPanel.Body:GetChildren() do
		if d:IsA("TextLabel") then
			text ..= d.Text .. "|"
		end
	end
	ok(string.find(text, "A fresh note"), text)
	ok(press("Back"))
	Profiles.get(B).pence = 50
	ok(press("Write"))
	ok(press("Write"), "pick Ada")
	local box
	for _, d in gui.LettersPanel.Body:GetDescendants() do
		if d.Name == "LetterText" then
			box = d
		end
	end
	box.Text = "Thank you, Ada."
	ok(press("Send"))
	ok(#Letters.box(A) == 1, "Ada has Bert's reply")
end)
