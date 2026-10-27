--!strict
-- Activities.Mudlark: mudlarking on the Thames foreshore (ACTIVITIES §2, wave 1).
-- At low tide (Config.TIDE_LOW, from the world clock) glints appear on the foreshore; hold the
-- prompt to dig. Each find is rolled from Shared.Collection ("Mudlark" source; digging is free,
-- so this is not paid chance), sold on the spot for its value, and added to the collection
-- book. Glints are shared: first to dig gets it. At high tide they vanish and the sign says
-- when the water goes out again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Collection = require(Shared:WaitForChild("Collection"))
local WorldClock = require(script.Parent.Parent:WaitForChild("WorldClock"))

local Mudlark = {}
local A: any -- the Activities framework, set in init

local rng = Random.new()
local folder: Folder
local glints: { [BasePart]: boolean } = {}
local lowTide = false
local signText: TextLabel

function Mudlark.isLowTide(h: number): boolean
	for _, w in Config.TIDE_LOW do
		if h >= w.from and h < w.to then
			return true
		end
	end
	return false
end

-- In-game hour the next low tide starts.
local function nextLow(h: number): number
	local best, bestWait = Config.TIDE_LOW[1].from, math.huge
	for _, w in Config.TIDE_LOW do
		local wait = (w.from - h) % 24
		if wait < bestWait then
			best, bestWait = w.from, wait
		end
	end
	return best
end

local function hourText(h: number): string
	local hour = math.floor(h) % 24
	return string.format("%d %s", if hour % 12 == 0 then 12 else hour % 12, if hour < 12 then "am" else "pm")
end

local function showGlint(g: BasePart, on: boolean)
	g.Transparency = if on then 0.15 else 1
	local sp = g:FindFirstChildOfClass("Sparkles")
	if sp then
		sp.Enabled = on
	end
	local pp = g:FindFirstChildOfClass("ProximityPrompt")
	if pp then
		pp.Enabled = on
	end
end

local spawnGlint: () -> ()

local function dig(g: BasePart, player: Player)
	if not lowTide or not glints[g] or not A.near(player, g.Position, 12) then
		return
	end
	glints[g] = nil
	g:Destroy()
	local item = Collection.roll("Mudlark", rng)
	A.reward(player, { activity = "Mudlark", hobby = "Collecting", xp = Config.MUDLARK_XP, pence = item.value, items = { item.id } })
	A.score("Mudlark", player, 1, "sum")
	task.delay(rng:NextNumber(Config.MUDLARK_RESPAWN.min, Config.MUDLARK_RESPAWN.max), spawnGlint)
end

spawnGlint = function()
	local area = Config.MUDLARK_AREA
	local pos = A.ground(rng:NextNumber(area.x[1], area.x[2]), rng:NextNumber(math.min(area.z[1], area.z[2]), math.max(area.z[1], area.z[2])), Config.MUDLARK_RAY_FROM)
	local g = A.part({ ClassName = "Part", Name = "Glint", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), CFrame = CFrame.new(pos + Vector3.new(0, 0.25, 0)), Color = Color3.fromRGB(255, 240, 190), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
	local sp = Instance.new("Sparkles")
	sp.SparkleColor = Color3.fromRGB(255, 245, 210)
	sp.Parent = g
	local pp = A.prompt(g, "Dig", "Something glints in the mud", Config.MUDLARK_DIG_SECONDS)
	pp.MaxActivationDistance = 8
	pp.Triggered:Connect(function(player)
		dig(g, player)
	end)
	showGlint(g, lowTide)
	glints[g] = true
	g.Parent = folder
end

local function updateTide()
	local h = WorldClock.hour()
	local low = Mudlark.isLowTide(h)
	if low ~= lowTide then
		lowTide = low
		for g in glints do
			showGlint(g, low)
		end
	end
	signText.Text = if low
		then "Low tide\nDig for curios on the foreshore"
		else "The tide is in\nBack at low tide, " .. hourText(nextLow(h))
end

function Mudlark.init(framework: any)
	A = framework
	folder = A.site("Mudlark")
	local top = A.ground(Config.MUDLARK_SIGN.x, Config.MUDLARK_SIGN.z) -- on the embankment by the river stairs
	local face = CFrame.lookAt(top, top + Vector3.new(-1, 0, 0)) -- facing the street (west)
	local sign = A.part({ Name = "TideSign", Size = Vector3.new(6, 3, 0.3), CFrame = face * CFrame.new(0, 4, 0), Color = Color3.fromRGB(40, 50, 60), Material = Enum.Material.Wood })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Font = Enum.Font.Garamond
	signText.TextScaled = true
	signText.TextColor3 = Color3.fromRGB(235, 225, 200)
	signText.Parent = sg
	sg.Parent = sign
	sign.Parent = folder
	A.board("Mudlark", "Mudlarks", "finds", face * CFrame.new(8, 0, 0)).Parent = folder

	lowTide = Mudlark.isLowTide(WorldClock.hour())
	updateTide()
	for _ = 1, Config.MUDLARK_GLINTS do
		spawnGlint()
	end
	task.spawn(function()
		while true do
			task.wait(1)
			updateTide()
		end
	end)
end

return Mudlark
