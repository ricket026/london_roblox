--!strict
-- LondonServer.World: small helpers for building things in the city from map coordinates.
--   World.ground(x, z, fromY?) -> Vector3, Material?   ground point by raycast (and what it hit),
--                                            ignoring markers and built props
--   World.part(props) -> BasePart            anchored part with properties (ClassName = "Seat" etc.)
--   World.folder(name) -> Folder              a top-level folder in workspace (created once)
--   World.near(player, pos, range) -> bool   is the player's character within range?
--   World.sign(part, face, text, size?)       a SurfaceGui label on a part face
-- Activities has its own copies of ground/part (older); new systems use these.
local Players = game:GetService("Players")

local World = {}

-- Folders a ground ray must pass through: map markers and everything our systems build.
World.SKIP_MAP = { "JobSites", "Labels", "CabRanks", "BusStops", "Routes", "Bounds", "Spawns", "Landmarks_Greybox" }
World.SKIP_ROOT = { "Activities", "Counters", "Properties", "Shops", "LotTemplates", "Lamps" }

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function World.ground(x: number, z: number, fromY: number?): (Vector3, Enum.Material?)
	local skip: { Instance } = {}
	local map = workspace:FindFirstChild("Map")
	if map then
		for _, name in World.SKIP_MAP do
			local f = map:FindFirstChild(name)
			if f then
				table.insert(skip, f)
			end
		end
	end
	for _, name in World.SKIP_ROOT do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(skip, f)
		end
	end
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(skip, plr.Character)
		end
	end
	rayParams.FilterDescendantsInstances = skip
	local top = fromY or 300
	local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -top - 300, 0), rayParams)
	if hit then
		return hit.Position, hit.Material
	end
	return Vector3.new(x, math.min(top, 0), z), nil
end

function World.part(props: { [string]: any }): BasePart
	local p: any = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "ClassName" then
			p[k] = v
		end
	end
	return p
end

function World.folder(name: string): Folder
	local f = workspace:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = name
	nf.Parent = workspace
	return nf
end

function World.near(player: Player, pos: Vector3, range: number): boolean
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and hrp:IsA("BasePart") and (hrp.Position - pos).Magnitude <= range
end

function World.sign(part: BasePart, face: Enum.NormalId, text: string, textColor: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GaramondBold
	l.TextScaled = true
	l.TextColor3 = textColor or Color3.fromRGB(240, 228, 200)
	l.Text = text
	l.Parent = gui
	gui.Parent = part
	return l
end

return World
