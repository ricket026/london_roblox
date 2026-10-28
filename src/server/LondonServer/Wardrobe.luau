--!strict
-- LondonServer.Wardrobe: dresses a character in its 3D outfit (Shared.OutfitParts, TASKS T06)
-- right after it spawns. Pieces are welded to the limbs, massless, and never collide, touch or
-- block clicks, so movement, sitting and prompts are unchanged. They live in a folder "Outfit"
-- in the character (replaced on every spawn).
--   Wardrobe.dress(character, outfitId) -> number of parts added
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Looks = require(Shared:WaitForChild("Looks"))
local OutfitParts = require(Shared:WaitForChild("OutfitParts"))

local Wardrobe = {}

local function colourOf(outfit: { [string]: any }, slot: any): Color3
	if typeof(slot) == "Color3" then
		return slot
	end
	local c = outfit[slot]
	return if typeof(c) == "Color3" then c else OutfitParts.BLACK
end

local function vec(t: { number }?): Vector3
	return if t then Vector3.new(t[1], t[2], t[3]) else Vector3.zero
end

function Wardrobe.dress(character: Model, outfitId: string): number
	local old = character:FindFirstChild("Outfit")
	if old then
		old:Destroy()
	end
	local pieces = OutfitParts.OUTFITS[outfitId]
	local outfit = Looks.outfit(outfitId)
	if not pieces or not outfit then
		return 0
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local r6 = hum ~= nil and hum.RigType == Enum.HumanoidRigType.R6
	local folder = Instance.new("Folder")
	folder.Name = "Outfit"
	local n = 0
	for _, piece in pieces do
		local limbName = if r6 then OutfitParts.R6_MAP[piece.limb] else piece.limb
		local limb = if limbName then character:FindFirstChild(limbName) else nil
		if limb and limb:IsA("BasePart") then
			local p = Instance.new("Part")
			p.Name = piece.name
			local size = limb.Size * vec(piece.rel) + vec(piece.add)
			p.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
			if piece.shape == "Cylinder" then
				p.Shape = Enum.PartType.Cylinder
			elseif piece.shape == "Wedge" then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Wedge
				mesh.Parent = p
			elseif piece.shape == "Ball" then
				local mesh = Instance.new("SpecialMesh") -- an ellipsoid the size of the part
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = p
			end
			local cf = limb.CFrame * CFrame.new(limb.Size * vec(piece.at) + vec(piece.shift))
			if piece.up then
				cf *= CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis is X: stand it upright
			end
			p.CFrame = cf
			p.Color = colourOf(outfit, piece.colour)
			p.Material = piece.material or Enum.Material.Fabric
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CastShadow = true
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = limb
			weld.Part1 = p
			weld.Parent = p
			p.Parent = folder
			n += 1
		end
	end
	folder.Parent = character
	return n
end

return Wardrobe
