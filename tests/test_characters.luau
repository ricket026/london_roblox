-- Boots the real server (LondonServer + all modules) and drives Characters through Net, the way
local Players = game:GetService("Players")
-- the client does. Profiles use the Studio mock store, so leaving and rejoining round-trips JSON.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
__run(__find("ServerScriptService.LondonServer"))
local Profiles = require(__find("ServerScriptService.LondonServer.Profiles"))

local function call(p, action, args)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, "Character", msg, true)
end
local function join(id, name)
	local p = __addPlayer(id, name)
	for _ = 1, 200 do
		if p:GetAttribute("ProfileLoaded") then
			return p
		end
		task.wait(0.1)
	end
	error("profile never loaded")
end
local look = { skin = 2, hair = "own", outfit = "frock" }
local function with(t, extra)
	local o = table.clone(t)
	for k, v in extra do
		o[k] = v
	end
	return o
end

test("first character is free, spawns, and gets a name tag attribute", function()
	local p = join(101, "Ada")
	eq(p.Character, nil, "no body before picking a character")
	local res = call(p, "Create", with(look, { slot = "1", first = "ada", last = "lovelace" }))
	ok(res.ok, tostring(res.err))
	eq(p:GetAttribute("RPName"), "Ada Lovelace")
	ok(p.Character ~= nil, "spawned")
	eq(res.data.active, "1")
	eq(Profiles.get(p).pence, Config.START_PENCE, "first slot cost nothing")
end)

test("bad looks and names are refused", function()
	local p = Players:GetPlayerByUserId(101)
	local res = call(p, "Create", with(look, { slot = "2", first = "Lord", last = "Byron" }))
	eq(res.ok, false)
	res = call(p, "Create", with(look, { slot = "2", first = "Ada", last = "Byron", outfit = "spacesuit" }))
	eq(res.ok, false)
	res = call(p, "Create", { slot = "2", first = "Ada", last = "Byron" }) -- missing look fields
	eq(res.ok, false, "schema rejects a payload without the look")
end)

test("linking costs £100 and shares progress", function()
	local p = Players:GetPlayerByUserId(101)
	local res = call(p, "Link", with(look, { slot = "3", from = "1", first = "Charles", last = "Babbage" }))
	eq(res.ok, false, "can't afford it")
	ok(string.find(res.err, "£100"), res.err)
	Profiles.addPence(p, Config.SLOT_LINK_PRICE)
	res = call(p, "Link", with(look, { slot = "3", from = "1", first = "Charles", last = "Babbage" }))
	ok(res.ok, tostring(res.err))
	local prof = Profiles.get(p)
	eq(prof.pence, Config.START_PENCE, "charged exactly the link price")
	eq(prof.slots["3"].char, prof.slots["1"].char, "same progress id")
	eq(res.data.slots["3"].shared, 2)
end)

test("switching has a cooldown and keeps shared progress", function()
	local p = Players:GetPlayerByUserId(101)
	local res = call(p, "Select", { slot = "3" })
	eq(res.ok, false, "switch cooldown")
	__advance(Config.CHARACTER_SWITCH_COOLDOWN + 1)
	local before = Profiles.progress(p)
	before.hobbies.Sport = 500
	res = call(p, "Select", { slot = "3" })
	ok(res.ok, tostring(res.err))
	eq(p:GetAttribute("RPName"), "Charles Babbage")
	eq(Profiles.progress(p).hobbies.Sport, 500, "linked slot sees the same hobbies")
end)

test("rename: one free fix right after creating, then the cooldown", function()
	local p = Players:GetPlayerByUserId(101)
	local res = call(p, "Rename", { slot = "3", first = "Charlie", last = "Babbage" })
	ok(res.ok, tostring(res.err))
	eq(p:GetAttribute("RPName"), "Charlie Babbage", "active character renamed live")
	res = call(p, "Rename", { slot = "3", first = "Chas", last = "Babbage" })
	eq(res.ok, false, "second rename waits for the cooldown")
end)

test("delete needs the full name; shared progress survives", function()
	local p = Players:GetPlayerByUserId(101)
	local prof = Profiles.get(p)
	local char = prof.slots["1"].char
	local res = call(p, "Delete", { slot = "1", confirm = "Ada" })
	eq(res.ok, false)
	res = call(p, "Delete", { slot = "1", confirm = "Ada Lovelace" })
	ok(res.ok, tostring(res.err))
	eq(prof.slots["1"], nil)
	ok(prof.progress[char] ~= nil, "still linked from slot 3")
end)

test("leaving and rejoining keeps the slots; the session starts at the menu", function()
	local p = Players:GetPlayerByUserId(101)
	__removePlayer(p)
	__advance(2)
	local p2 = join(101, "Ada")
	local prof = Profiles.get(p2)
	ok(prof.slots["3"] ~= nil, "slot 3 saved")
	eq(prof.slots["3"].name.first, "Charlie")
	eq(prof.active, "", "starts at the character menu")
	eq(p2.Character, nil)
	eq(prof.progress[prof.slots["3"].char].hobbies.Sport, 500)
end)

test("no unexpected warnings (Net rejections above are deliberate)", function()
	local w = {}
	for _, line in __warnings() do
		if not string.find(line, "^%[Net%] rejected") then
			table.insert(w, line)
		end
	end
	eq(#w, 0, table.concat(w, " | "))
end)
