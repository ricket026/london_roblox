--!strict
-- Activities.Ducks: feeding the ducks & pigeons at St James's Park lake (ACTIVITIES §2, wave 1).
-- Buy a bag of seed (1d) at the stand; water birds swim over to the shore in front of you and
-- pigeons land at your feet, for everyone to see. Which water bird comes depends on the in-game
-- hour (pelicans at half past two, swans at dawn), never on chance. Pays no money (it costs 1d);
-- gives Outdoors XP and collection entries.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Profiles = require(script.Parent.Parent:WaitForChild("Profiles"))
local WorldClock = require(script.Parent.Parent:WaitForChild("WorldClock"))

local Ducks = {}
local A: any -- the Activities framework, set in init

type Look = { body: Color3, head: Color3, size: number, neck: number }
local LOOKS: { [string]: Look } = {
	bird_mallard = { body = Color3.fromRGB(120, 100, 80), head = Color3.fromRGB(30, 90, 50), size = 1, neck = 0.5 },
	bird_swan = { body = Color3.fromRGB(245, 245, 240), head = Color3.fromRGB(245, 245, 240), size = 1.8, neck = 1.4 },
	bird_pelican = { body = Color3.fromRGB(235, 230, 225), head = Color3.fromRGB(235, 200, 120), size = 2, neck = 0.9 },
	bird_pigeon = { body = Color3.fromRGB(120, 120, 135), head = Color3.fromRGB(90, 100, 110), size = 0.6, neck = 0.3 },
}

local rng = Random.new()
local live = 0
local lastFeed: { [Player]: number } = {}
local folder: Folder

local function species(): string
	local h = WorldClock.hour()
	for _, s in Config.DUCKS_SPECIES do
		if h >= s.from and h < s.to then
			return s.id
		end
	end
	return "bird_mallard"
end

local function makeBird(kind: string, at: CFrame): Model
	local look = LOOKS[kind]
	local s = look.size
	local m = Instance.new("Model")
	m.Name = kind
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(1.4, 1, 2) * s -- a Ball part is always round; the sphere mesh makes it oval
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	body.Color = look.body
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CastShadow = false
	body.CFrame = at
	body.Parent = m
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(0.6, 0.6, 0.6) * s
	head.Color = look.head
	head.Anchored = true
	head.CanCollide = false
	head.CanQuery = false
	head.CastShadow = false
	head.CFrame = at * CFrame.new(0, look.neck * s, -0.9 * s)
	head.Parent = m
	m.PrimaryPart = body
	return m
end

-- Moves a two-part bird (anchored) by tweening a CFrameValue.
local function glide(m: Model, to: CFrame, seconds: number)
	local body = m.PrimaryPart :: BasePart
	local head = m:FindFirstChild("Head") :: BasePart
	local offset = body.CFrame:ToObjectSpace(head.CFrame)
	local v = Instance.new("CFrameValue")
	v.Value = body.CFrame
	v.Changed:Connect(function(cf)
		body.CFrame = cf
		head.CFrame = cf * offset
	end)
	local t = TweenService:Create(v, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = to })
	t.Completed:Connect(function()
		v:Destroy()
	end)
	t:Play()
end

local function facing(from: Vector3, to: Vector3): CFrame
	local flat = Vector3.new(to.X, from.Y, to.Z)
	if (flat - from).Magnitude < 0.01 then
		return CFrame.new(from)
	end
	return CFrame.lookAt(from, flat)
end

-- A point on the lake, `inset` (0-1) of the way from the shore to the centre, in the direction of `toward`.
local function lakePoint(toward: Vector3, inset: number, spread: number): Vector3
	local L = Config.DUCKS_LAKE
	local dx, dz = (toward.X - L.cx) / L.rx, (toward.Z - L.cz) / L.rz
	local a = math.atan2(dz, dx) + rng:NextNumber(-spread, spread)
	local k = 1 - inset
	return Vector3.new(L.cx + math.cos(a) * L.rx * k, L.surface + 0.3, L.cz + math.sin(a) * L.rz * k)
end

local function feed(player: Player, standPos: Vector3)
	local now = os.clock()
	if now - (lastFeed[player] or -math.huge) < Config.DUCKS_COOLDOWN then
		return
	end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or (hrp.Position - standPos).Magnitude > 20 then
		return
	end
	if live >= Config.DUCKS_MAX_LIVE then
		A.notice(player, "The birds are busy. Try again in a moment.")
		return
	end
	if not Profiles.addPence(player, -Config.DUCKS_SEED_PRICE) then
		A.notice(player, string.format("A bag of seed costs %dd.", Config.DUCKS_SEED_PRICE))
		return
	end
	lastFeed[player] = now
	local kind = species()
	local feet = hrp.Position - Vector3.new(0, 2.5, 0)
	local birds: { Model } = {}
	for _ = 1, Config.DUCKS_BIRDS do
		local start = lakePoint(feet, 0.5, 0.25)
		local stop = lakePoint(feet, 0.06, 0.06)
		local m = makeBird(kind, facing(start, stop))
		m.Parent = folder
		glide(m, facing(stop, feet) * CFrame.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-2, 2)), rng:NextNumber(3, 5))
		table.insert(birds, m)
	end
	for _ = 1, Config.DUCKS_PIGEONS do
		local land = feet + Vector3.new(rng:NextNumber(-4, 4), 0.3, rng:NextNumber(-4, 4))
		local m = makeBird("bird_pigeon", facing(land + Vector3.new(rng:NextNumber(-20, 20), 25, rng:NextNumber(-20, 20)), land))
		m.Parent = folder
		glide(m, facing(land, feet), rng:NextNumber(1.5, 2.5))
		table.insert(birds, m)
	end
	live += #birds
	A.reward(player, { activity = "Ducks", hobby = "Outdoors", xp = Config.DUCKS_XP, items = { kind, "bird_pigeon" } })
	A.score("Ducks", player, 1, "sum")
	task.delay(Config.DUCKS_STAY, function()
		for _, m in birds do
			local body = m.PrimaryPart :: BasePart
			local away = if m.Name == "bird_pigeon"
				then body.Position + Vector3.new(rng:NextNumber(-30, 30), 30, rng:NextNumber(-30, 30))
				else lakePoint(body.Position, 0.6, 0.3)
			glide(m, CFrame.lookAt(away, away + (away - body.Position).Unit), 4)
		end
		task.wait(4.2)
		for _, m in birds do
			m:Destroy()
		end
		live -= #birds
	end)
end

function Ducks.init(framework: any)
	A = framework
	folder = A.site("Ducks")
	local g = A.ground(Config.DUCKS_SITE.x, Config.DUCKS_SITE.z)
	local L = Config.DUCKS_LAKE
	local look = CFrame.lookAt(g, Vector3.new(L.cx, g.Y, Config.DUCKS_SITE.z)) -- face the water
	local stand = A.part({ Name = "SeedStand", Size = Vector3.new(4, 3, 2), CFrame = look * CFrame.new(-5, 1.5, 0), Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.Wood })
	A.part({ Name = "Awning", Size = Vector3.new(4.6, 0.3, 2.6), CFrame = look * CFrame.new(-5, 4.6, 0), Color = Color3.fromRGB(40, 90, 60), Material = Enum.Material.Fabric }).Parent = stand
	stand.Parent = folder
	local pp = A.prompt(stand, string.format("Feed the birds (%dd)", Config.DUCKS_SEED_PRICE), "Seed stand")
	pp.Triggered:Connect(function(player)
		feed(player, stand.Position)
	end)
	A.board("Ducks", "Feeding the Birds", "bags", look * CFrame.new(-10, 0, 1) * CFrame.Angles(0, math.rad(180), 0)).Parent = folder
	Players.PlayerRemoving:Connect(function(p)
		lastFeed[p] = nil
	end)
end

return Ducks
