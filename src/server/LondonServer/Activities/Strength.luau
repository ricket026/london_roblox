--!strict
-- Activities.Strength: test your strength at the fairground (ACTIVITIES §2, wave 1).
-- Step up, take Config.STRENGTH_SWINGS swings; each swing is a timing press on a meter
-- (Shared.Meter). The puck flies up the pole for everyone to see and rings the bell at
-- Config.STRENGTH_BELL+. Pays per bell, Sport XP from the best swing, board = best swing today.
-- Remote: Activity.StrengthSwing { t = server time of the press }.
-- Pushes: Activity.StrengthStart { start, period, swings }, StrengthResult { score, bell, left },
--         StrengthEnd { best }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Meter = require(Shared:WaitForChild("Meter"))

local Strength = {}
local A: any -- the Activities framework, set in init

type Session = { player: Player, start: number, period: number, swings: number, best: number, bells: number, last: number }
local session: Session? = nil
local rng = Random.new()

local puck: BasePart
local bell: BasePart
local puckHome: CFrame
local padPos: Vector3
local bellSound: Sound?

local function finish(s: Session)
	if session ~= s then
		return
	end
	session = nil
	A.release(s.player, "Strength")
	if s.player.Parent ~= Players then
		return
	end
	Net.push(s.player, "Activity", "StrengthEnd", { best = s.best })
	if s.swings > 0 then
		A.reward(s.player, {
			activity = "Strength",
			hobby = "Sport",
			xp = Config.STRENGTH_XP.base + (s.best // 10) * Config.STRENGTH_XP.perTen,
			pence = s.bells * Config.STRENGTH_PAY_BELL,
		})
		A.score("Strength", s.player, s.best, "max")
	end
end

local function ring()
	local old = bell.Color
	bell.Material = Enum.Material.Neon
	bell.Color = Color3.fromRGB(255, 230, 120)
	if bellSound then
		bellSound:Play()
	end
	task.delay(0.6, function()
		bell.Material = Enum.Material.Metal
		bell.Color = old
	end)
end

local function launch(score: number)
	local up = Config.STRENGTH_POLE * score / 100
	local flyUp = TweenService:Create(puck, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = puckHome * CFrame.new(0, up, 0) })
	flyUp.Completed:Connect(function()
		if score >= Config.STRENGTH_BELL then
			ring()
		end
		TweenService:Create(puck, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = puckHome }):Play()
	end)
	flyUp:Play()
end

local function start(player: Player)
	if session then
		if session.player ~= player then
			A.notice(player, "Someone's swinging. Wait your turn!")
		end
		return
	end
	if not A.claim(player, "Strength") then
		return
	end
	local s: Session = {
		player = player,
		start = workspace:GetServerTimeNow() + 0.5,
		period = rng:NextNumber(Config.STRENGTH_PERIOD.min, Config.STRENGTH_PERIOD.max),
		swings = 0,
		best = 0,
		bells = 0,
		last = 0,
	}
	session = s
	Net.push(player, "Activity", "StrengthStart", { start = s.start, period = s.period, swings = Config.STRENGTH_SWINGS })
	task.delay(Config.STRENGTH_TIMEOUT, function()
		if session == s then
			finish(s)
		end
	end)
end

local function swing(player: Player, t: number)
	local s = session
	if not s or s.player ~= player then
		return
	end
	local now = workspace:GetServerTimeNow()
	if t < s.start or t > now + 0.3 or t < s.last + 0.6 then
		return -- pressed before the meter started, from the future, or too fast after the last swing
	end
	if not A.near(player, padPos, Config.STRENGTH_RANGE) then
		finish(s)
		return
	end
	s.last = t
	s.swings += 1
	local score = math.clamp(math.floor(Meter.value(t - s.start, s.period) * 100 + 0.5), 0, 100)
	local isBell = score >= Config.STRENGTH_BELL
	s.best = math.max(s.best, score)
	if isBell then
		s.bells += 1
	end
	launch(score)
	local left = Config.STRENGTH_SWINGS - s.swings
	Net.push(player, "Activity", "StrengthResult", { score = score, bell = isBell, left = left })
	if left <= 0 then
		task.delay(1, finish, s)
	end
end

function Strength.init(framework: any)
	A = framework
	local folder = A.site("Strength")
	local g = A.ground(Config.STRENGTH_SITE.x, Config.STRENGTH_SITE.z)
	local base = CFrame.new(g) -- faces -Z (east, toward the market)
	local wood = Color3.fromRGB(150, 40, 35)
	local pad = A.part({ Name = "Pad", Size = Vector3.new(3, 0.6, 3), CFrame = base * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(60, 50, 40), Material = Enum.Material.Wood })
	pad.Parent = folder
	padPos = pad.Position
	local pole = A.part({ Name = "Pole", Size = Vector3.new(1.2, Config.STRENGTH_POLE + 2, 0.6), CFrame = base * CFrame.new(0, 0.6 + (Config.STRENGTH_POLE + 2) / 2, -2.5), Color = wood, Material = Enum.Material.Wood })
	pole.Parent = folder
	for i = 1, 10 do -- painted marks every tenth
		A.part({ Name = "Mark", Size = Vector3.new(1.3, 0.12, 0.62), CFrame = base * CFrame.new(0, 1.2 + Config.STRENGTH_POLE * i / 10, -2.5), Color = Color3.fromRGB(240, 220, 160), Material = Enum.Material.SmoothPlastic, CanCollide = false }).Parent = folder
	end
	puckHome = base * CFrame.new(0, 1.2, -2.0)
	puck = A.part({ Name = "Puck", Size = Vector3.new(0.8, 0.5, 0.4), CFrame = puckHome, Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.Metal, CanCollide = false })
	puck.Parent = folder
	bell = A.part({ ClassName = "Part", Name = "Bell", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = base * CFrame.new(0, 1.2 + Config.STRENGTH_POLE + 0.9, -2.0), Color = Color3.fromRGB(200, 160, 60), Material = Enum.Material.Metal })
	bell.Parent = folder
	if Config.STRENGTH_BELL_SOUND ~= "" then
		local snd = Instance.new("Sound")
		snd.SoundId = Config.STRENGTH_BELL_SOUND
		snd.RollOffMaxDistance = 150
		snd.Parent = bell
		bellSound = snd
	end
	local sign = A.part({ Name = "Sign", Size = Vector3.new(6, 1.6, 0.3), CFrame = base * CFrame.new(0, Config.STRENGTH_POLE + 5, -2.5), Color = Color3.fromRGB(30, 60, 40), Material = Enum.Material.Wood, CanCollide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back -- the side facing the pad (+Z)
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GaramondBold
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(250, 220, 120)
	t.Text = "TEST YOUR STRENGTH"
	t.Parent = sg
	sg.Parent = sign
	sign.Parent = folder
	local pp = A.prompt(pad, "Swing the mallet", "Test your strength")
	pp.Triggered:Connect(start)
	A.board("Strength", "Test Your Strength", "", base * CFrame.new(6, 0, 0) * CFrame.Angles(0, math.rad(180), 0)).Parent = folder

	Net.handle("Activity", "StrengthSwing", { schema = { t = Net.V.num(0, 2 ^ 40) }, rate = { count = 4, per = 1 } }, function(player, a)
		swing(player, a.t)
		return nil
	end)
	Players.PlayerRemoving:Connect(function(p)
		local s = session
		if s and s.player == p then
			finish(s)
		end
	end)
end

return Strength
