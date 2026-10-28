-- T27: the collection book. Pages from Shared.Collection, found counts, hidden missing items,
-- a completed page saved once and announced, and the Book panel's pages.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0
Config.GOALS = {}
local Net = require(Shared.Net)
local Collection = require(Shared.Collection)

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Book = require(__find(LS .. "Book"))

local function call(p, action, args, domain)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain or "Book", msg, true)
end
local function last(p, remote, action)
	local list = __received(p, remote, action)
	return list[#list]
end

local P, Q
test("the book lists every page; a page is complete once everything on it is found", function()
	P = __addPlayer(1901, "Percy")
	Q = __addPlayer(1902, "Queenie")
	for _, p in { P, Q } do
		for _ = 1, 200 do
			if p:GetAttribute("ProfileLoaded") then
				break
			end
			task.wait(0.1)
		end
		ok(call(p, "Create", { slot = "1", first = p.Name, last = "Tester", skin = 1, hair = "own", outfit = "frock" }, "Character").ok)
	end
	local v = call(P, "Get").data
	eq(#v.pages, #Collection.PAGES)
	eq(v.found, 0)
	eq(v.of, #Collection.ITEMS)
	local col = Profiles.get(P).collection
	col.bird_mallard = 3
	v = call(P, "Get").data
	eq(v.pages[1].found, 1)
	eq(v.pages[1].items[1].count, 3)
	ok(not v.pages[1].complete)
	col.bird_pigeon, col.bird_swan, col.bird_pelican = 1, 1, 1
	__clearInbox(Q)
	v = call(P, "Get").data
	ok(v.pages[1].complete, "Birds of the Park complete")
	ok(Profiles.get(P).settings.pagesDone["Birds of the Park"])
	ok(string.find(last(P, "BookEvent", "Notice").text, "Page complete"), "told")
	local c = last(Q, "BookEvent", "Completed")
	ok(c and c.page == "Birds of the Park", "the server hears of it")
	eq(#Book.check(P), 0, "only once")
end)

test("pages complete by themselves on the timer", function()
	for _, it in Collection.ITEMS do
		if it.page == "Mementos" then
			Profiles.get(Q).collection[it.id] = 1
		end
	end
	__advance(Config.BOOK_CHECK + 1)
	ok(Profiles.get(Q).settings.pagesDone and Profiles.get(Q).settings.pagesDone.Mementos)
end)

test("the Book panel: pages, found and missing", function()
	__asClient(P, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		require(__find(root .. "BookUI")).init()
	end)
	__advance(0)
	local gui = P.PlayerGui.Economy
	ok(gui.More.BookButton.Visible)
	gui.More.BookButton.Activated:Fire()
	__advance(0)
	ok(gui.BookPanel.Visible)
	local function texts()
		local out = {}
		for _, d in gui.BookPanel.Body:GetChildren() do
			if d:IsA("TextLabel") then
				table.insert(out, d.Text)
			end
		end
		return table.concat(out, "|")
	end
	ok(string.find(texts(), "Mallard ×3"), texts())
	ok(string.find(texts(), "Page complete"))
	for _, d in gui.BookPanel.Body:GetDescendants() do
		if d:IsA("TextButton") and d.Text == "▶" then
			d.Activated:Fire()
			break
		end
	end
	__advance(0)
	ok(string.find(texts(), "%? %? %?"), "missing finds are hidden: " .. texts())
end)

local Hobbies = require(Shared.Hobbies)
local Daily = require(__find(LS .. "Daily"))

test("pastimes: levels unlock titles; wear one on the name tag; it's saved and comes back", function()
	local prog = Profiles.progress(P)
	prog.hobbies.Outdoors = Hobbies.xpFor(3)
	local v = call(P, "Pastimes").data
	local outdoors
	for _, h in v.hobbies do
		if h.name == "Outdoors" then
			outdoors = h
		end
	end
	eq(outdoors.level, 3)
	ok(outdoors.titles[1].unlocked and not outdoors.titles[2].unlocked)
	ok(not call(P, "Wear", { hobby = "Outdoors", level = 6 }).ok, "not until level 6")
	ok(not call(P, "Wear", { hobby = "Outdoors", level = 4 }).ok, "no title at level 4")
	ok(call(P, "Wear", { hobby = "Outdoors", level = 3 }).ok)
	eq(P:GetAttribute("Badge"), "Friend of the Ducks")
	local tag = P.Character:FindFirstChild("RPTag")
	ok(string.find(tag.RPRole.Text, "Friend of the Ducks"), tag.RPRole.Text)
	ok(table.find(prog.honours, "badge:Outdoors:3") ~= nil, "saved with the character")
	P:SetAttribute("CharSlot", "x")
	P:SetAttribute("CharSlot", "1")
	eq(P:GetAttribute("Badge"), "Friend of the Ducks", "put back on arrival")
	ok(call(P, "Wear", {}).ok)
	eq(P:GetAttribute("Badge"), nil, "taken off")
	eq(table.find(prog.honours, "badge:Outdoors:3"), nil)
end)

test("a new title is announced after the activity that earns it", function()
	Daily.record(P, "activity:Ducks") -- first look this session: nothing new
	__advance(0)
	__clearInbox(P)
	Profiles.progress(P).hobbies.Outdoors = Hobbies.xpFor(6)
	Daily.record(P, "activity:Ducks")
	__advance(0)
	local n = __received(P, "BookEvent", "Notice")
	ok(#n > 0 and string.find(n[#n].text, "Keen Naturalist"), "announced")
end)

test("the Pastimes tab: Wear", function()
	local gui = P.PlayerGui.Economy
	gui.BookPanel.Visible = true
	local function press(label)
		for _, d in gui.BookPanel.Body:GetDescendants() do
			if d:IsA("TextButton") and d.Text == label then
				d.Activated:Fire()
				__advance(0)
				return true
			end
		end
		return false
	end
	ok(press("Pastimes"))
	ok(press("Wear"), "an unlocked title has Wear")
	ok(P:GetAttribute("Badge") ~= nil)
	ok(press("Take off"))
	eq(P:GetAttribute("Badge"), nil)
end)
