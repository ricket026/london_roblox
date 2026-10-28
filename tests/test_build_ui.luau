-- Phase 3 client: PropertyUI and BuildUI driven as a player would, against the real server.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0 -- daily money is tested in test_daily; keep balances exact here
local Net = require(Shared.Net)
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)

local map = Instance.new("Folder")
map.Name = "Map"
local plots = Instance.new("Folder")
plots.Name = "Plots"
plots.Parent = map
for k, x in { -792.2857, -762.5714, -732.8571 } do
	local p = Instance.new("Part")
	p.Name = "Lot_" .. (1432 + k)
	p.Anchored = true
	p.Size = Vector3.new(29.714, 2.6, 46.4)
	p.CFrame = CFrame.new(x, -0.7, -2199.2)
	p:SetAttribute("LotId", 1432 + k)
	p:SetAttribute("District", "Holborn & Bloomsbury")
	p:SetAttribute("LotType", "Terrace")
	p:SetAttribute("Frontage", 29)
	p:SetAttribute("Depth", 46)
	p.Parent = plots
end
map.Parent = workspace

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Economy = require(__find(LS .. "Economy"))
local Builds = require(__find(LS .. "Builds"))
local Lots = require(__find(LS .. "Lots"))

local function call(p, domain, action, args)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain, msg, true)
end
local function stand(p, at)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(at)
end
local function settle()
	for _ = 1, 20 do
		task.wait(0.1)
	end
end
local function findButton(root, label)
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and d.Text == label then
			return d
		end
	end
	return nil
end
local function press(b)
	assert(b, "no such button")
	b.Activated:Fire()
end

local A, gui, BuildUI, LOT
test("setup: a player rents a terrace and opens the property menu", function()
	A = __addPlayer(601, "Hattie")
	for _ = 1, 200 do
		if A:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	__asClient(A, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		BuildUI = require(__find(root .. "BuildUI"))
		BuildUI.init()
		require(__find(root .. "PropertyUI")).init()
	end)
	gui = A.PlayerGui.Economy
	ok(call(A, "Character", "Create", { slot = "1", first = "Hattie", last = "Tester", skin = 1, hair = "own", outfit = "frock" }).ok)
	ok(gui.PropertyButton.Visible, "the Property button shows in the city")
	Economy.pay(A, 10000, "admin", "test")
	stand(A, workspace.Counters.estate_holborn.Counter.Position + Vector3.new(0, 0, -4))
	workspace.Counters.estate_holborn.Counter.ProximityPrompt.Triggered:Fire(A)
	ok(gui.CounterPanel.Visible)
	press(findButton(gui.CounterPanel, "Rent £4 a week"))
	settle() -- the rent call saves the profile, so its answer comes a moment later
	ok(string.find(tostring(gui.Toast.Text), "Your new home"), tostring(gui.Toast.Text))
	LOT = "Lot_1435"
	ok(Builds.get(LOT) ~= nil)
	press(gui.PropertyButton)
	ok(gui.PropertyPanel.Visible)
	ok(findButton(gui.PropertyPanel, "Build") ~= nil, "a Build button for the house")
end)

test("entering build mode from the property menu", function()
	local l = Lots.get(LOT)
	stand(A, Kit.toWorld(l.frame, l.w / 2, 3, l.d / 2))
	press(findButton(gui.PropertyPanel, "Build"))
	local s = BuildUI.session()
	ok(s ~= nil, "in build mode")
	ok(A.PlayerGui.BuildMode.Enabled)
	eq(workspace.CurrentCamera.CameraType, Enum.CameraType.Scriptable, "the build camera")
	ok(findButton(A.PlayerGui.BuildMode, "Plain wall") ~= nil, "the catalogue shows walls")
end)

test("the ghost: snaps, shows why it can't go somewhere, places", function()
	BuildUI.pick("crate")
	BuildUI.aim(100, 30)
	local reason = A.PlayerGui.BuildMode.Reason.Text
	ok(string.find(reason, "Outside"), reason)
	BuildUI.aim(6.3, 30.2)
	eq(A.PlayerGui.BuildMode.Reason.Text, "")
	ok(workspace.LocalDrafts:FindFirstChild("BuildGhost") ~= nil, "a ghost")
	local k = BuildUI.place()
	ok(k ~= nil, "placed")
	local found
	for _, p in Builds.get(LOT).build.pieces do
		if p.k == k then
			found = p
		end
	end
	ok(found ~= nil and found.id == "crate")
	eq(found.x, 11, "snapped to the half-stud grid: centre 6.3 - 1 = 5.3 -> 5.5")
	eq(found.z, 58)
	ok(workspace.Properties[LOT]:FindFirstChild(tostring(k)) ~= nil, "the server shows it")
end)

test("undo and redo", function()
	local function count(id)
		local n = 0
		for _, p in Builds.get(LOT).build.pieces do
			if p.id == id then
				n += 1
			end
		end
		return n
	end
	eq(count("crate"), 1)
	BuildUI.undo()
	eq(count("crate"), 0, "undone")
	BuildUI.redo()
	eq(count("crate"), 1, "redone")
	BuildUI.undo()
	BuildUI.redo()
	eq(count("crate"), 1, "redo of a redo uses the new key")
end)

test("select, turn, paint and delete", function()
	local s = BuildUI.session()
	local wall
	for _, p in s.build.pieces do
		if p.id == "wall_sash" and p.y == 1 and p.z == 0 then
			wall = p
			break
		end
	end
	ok(wall ~= nil)
	BuildUI.select(wall.k)
	BuildUI.paint()
	local served
	for _, p in Builds.get(LOT).build.pieces do
		if p.k == wall.k then
			served = p
		end
	end
	local group = Palette.GROUPS.face
	eq(served.c, Palette.index(group[(table.find(group, "brick_stock_sooted") % #group) + 1]), "the next face colour")
	BuildUI.undo()
	eq(served.c, 0, "paint undone")
	-- a crate can be turned 90° and deleted
	local crate
	for _, p in s.build.pieces do
		if p.id == "crate" then
			crate = p
		end
	end
	BuildUI.select(crate.k)
	BuildUI.rotate(1)
	local turned
	for _, p in BuildUI.session().build.pieces do
		if p.k == crate.k then
			turned = p
		end
	end
	eq(turned.r, 6, "furniture turns a quarter (6 × 15°)")
	BuildUI.remove()
	local still = false
	for _, p in Builds.get(LOT).build.pieces do
		still = still or p.k == crate.k
	end
	eq(still, false, "deleted")
end)

test("a draft is drawn here only; publishing hands it back to the server", function()
	__advance(1)
	local s = BuildUI.session()
	local wall
	for _, p in s.build.pieces do
		if p.id == "wall_sash" and p.y == 0 and p.z == 0 and p.x > 0 then
			wall = p
			break
		end
	end
	BuildUI.select(wall.k)
	BuildUI.remove()
	eq(Builds.get(LOT).build.published, false, "a draft on the server")
	local draft = workspace.LocalDrafts:FindFirstChild(LOT)
	ok(draft ~= nil, "drawn locally")
	ok(#draft:GetChildren() > 50)
	local t = workspace.LotTemplates:FindFirstChild(LOT)
	ok(t ~= nil, "the server shows the template")
	eq(t:GetChildren()[1].LocalTransparencyModifier, 1, "hidden here under the draft")
	ok(string.find(A.PlayerGui.BuildMode.Top.Title.Text, "draft"), A.PlayerGui.BuildMode.Top.Title.Text)
	BuildUI.undo()
	BuildUI.publish()
	eq(Builds.get(LOT).build.published, true)
	eq(workspace.LocalDrafts:FindFirstChild(LOT), nil, "local draft gone")
	ok(workspace.Properties:FindFirstChild(LOT) ~= nil, "the server's house again")
end)

test("exit restores the camera and saves", function()
	BuildUI.exit()
	eq(BuildUI.session(), nil)
	eq(A.PlayerGui.BuildMode.Enabled, false)
	eq(workspace.CurrentCamera.CameraType, Enum.CameraType.Custom)
	settle()
	eq(Builds.get(LOT).dirty, false, "saved on exit")
end)

test("no unexpected warnings", function()
	local w = {}
	for _, line in __warnings() do
		if not string.find(line, "^%[Net%] rejected") then
			table.insert(w, line)
		end
	end
	eq(#w, 0, table.concat(w, " | "))
end)
