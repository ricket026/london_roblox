-- T03 / T04 / T07 / T18: terminus spawn, gas lamps on every road, the lamplighter's rounds, the
-- city's own lamplighters, lighting by phase and weather.
local Lighting = game:GetService("Lighting")
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0 -- daily money is tested in test_daily; keep balances exact here
local Net = require(Shared.Net)

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Lamps = require(__find(LS .. "Lamps"))
local Lots = require(__find(LS .. "Lots"))
local Jobs = require(__find(LS .. "Jobs"))
local WorldClock = require(__find(LS .. "WorldClock"))
local Characters = require(__find(LS .. "Characters"))

local function call(p, domain, action, args)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain, msg, true)
end
local function stand(p, at)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(at)
end

test("lamps along every road: within the part budget, kerbside, spaced, in routes of 12", function()
	local all = Lamps.all()
	ok(#all > 400 and #all < 800, "lamp count " .. #all)
	local parts = 0
	for _, d in workspace.Lamps:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	ok(parts < 1500, "parts " .. parts)
	for _, id in Lamps.routeIds() do
		ok(#Lamps.route(id) <= Config.LAMP_ROUTE, id)
	end
	-- every lamp sits on a pavement: just off some road's kerb line
	local segs = Lots.roads()
	for k = 1, #all, 37 do
		local p = all[k].Position
		local best = math.huge
		for _, s in segs do
			local dx, dz = s.bx - s.ax, s.bz - s.az
			local l2 = dx * dx + dz * dz
			local t = math.clamp(((p.X - s.ax) * dx + (p.Z - s.az) * dz) / l2, 0, 1)
			local d = math.sqrt((s.ax + t * dx - p.X) ^ 2 + (s.az + t * dz - p.Z) ^ 2) - s.half
			best = math.min(best, math.abs(d - Config.LAMP_KERB))
		end
		ok(best < 0.5, "lamp " .. k .. " is " .. best .. " studs off its kerb spot")
	end
	-- no two lamps closer than the minimum gap
	for k = 1, #all, 11 do
		for j = k + 1, math.min(#all, k + 40) do
			ok((all[k].Position - all[j].Position).Magnitude >= Config.LAMP_MIN_GAP - 0.01, "gap " .. k .. "-" .. j)
		end
	end
	ok(all[1]:HasTag(Lamps.TAG))
	ok(type(all[1]:GetAttribute("Route")) == "string")
end)

local L
test("new characters arrive at the terminus", function()
	L = __addPlayer(1001, "Lionel")
	for _ = 1, 200 do
		if L:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	ok(call(L, "Character", "Create", { slot = "1", first = "Lionel", last = "Tester", skin = 1, hair = "own", outfit = "frock" }).ok)
	local p = L.Character.HumanoidRootPart.Position
	local d = Vector3.new(p.X - Config.SPAWN_POINT.x, 0, p.Z - Config.SPAWN_POINT.z).Magnitude
	ok(d <= Config.SPAWN_RADIUS + 0.01, "within the spawn circle: " .. d)
	ok(L.Character:FindFirstChild("Outfit") ~= nil, "dressed")
end)

test("dusk: the lamplighter lights a route, 2d a lamp; the sky changes", function()
	WorldClock.debugSetHour(18.2)
	eq(Lighting:GetAttribute("Phase"), "Dusk")
	ok(Lamps.wanted())
	local lit = 0
	for _, l in Lamps.all() do
		lit += if l:GetAttribute("Lit") then 1 else 0
	end
	eq(lit, 0, "nobody has lit them yet")
	ok(call(L, "Identity", "ChooseRole", { role = "Lamplighter" }).ok)
	local t = Jobs.current(L)
	ok(t ~= nil and #t.steps > 0 and #t.steps <= Config.LAMP_ROUTE, "a round")
	local wallet = Profiles.get(L).pence
	for k = 1, #t.steps do
		__advance(Config.LAMP_HOLD + 0.1)
		stand(L, t.steps[k].pos)
		local res = call(L, "Job", "Hold", { step = k })
		ok(res.ok, tostring(res.err))
	end
	eq(Profiles.get(L).pence, wallet + #t.steps * Config.JOBS.Lamplighter.lampPay)
	eq(Lamps.pending(t.ref), 0, "the whole route is lit")
	local lamp = Lamps.route(t.ref)[1]
	eq(lamp.Material, Enum.Material.Neon)
	eq(lamp:FindFirstChildWhichIsA("PointLight").Enabled, true)
	__advance(Config.LIGHTING_TWEEN + 1)
	near(Lighting.Brightness, Config.LIGHTING.Dusk.brightness, 1e-6)
end)

test("the city's own lamplighters light the rest; at dawn they're put out", function()
	__advance(Config.LAMP_NPC_DELAY + 1)
	local unlit = 0
	for _, l in Lamps.all() do
		unlit += if l:GetAttribute("Lit") then 0 else 1
	end
	eq(unlit, 0, "all lit by the fallback")
	WorldClock.debugSetHour(5.1)
	eq(Lighting:GetAttribute("Phase"), "Dawn")
	eq(Lamps.wanted(), false)
	__advance(Config.LAMP_NPC_DELAY + 1)
	local lit = 0
	for _, l in Lamps.all() do
		lit += if l:GetAttribute("Lit") then 1 else 0
	end
	eq(lit, 0, "all out")
end)

test("night lighting and a pea-souper", function()
	WorldClock.debugSetHour(22)
	__advance(Config.LIGHTING_TWEEN + 1)
	near(Lighting.Brightness, Config.LIGHTING.Night.brightness, 1e-6)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	near(atmo.Density, Config.LIGHTING.Night.density, 1e-6)
	ok(WorldClock.setWeather("fog"))
	__advance(Config.LIGHTING_TWEEN + 1)
	near(atmo.Density, Config.LIGHTING.Night.density + Config.WEATHER.fog.density, 1e-6)
	eq(Lighting:GetAttribute("Weather"), "fog")
	eq(WorldClock.setWeather("blizzard"), false, "unknown weather")
	WorldClock.setWeather("clear")
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
