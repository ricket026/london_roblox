-- T06: 3D part outfits on R15 and R6 rigs.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
local OutfitParts = require(Shared.OutfitParts)
local Wardrobe = require(__find("ServerScriptService.LondonServer.Wardrobe"))

-- an R15 character standing at the origin (Roblox default limb sizes)
local LIMBS = {
	Head = { 1.2, 1.2, 1.2, 0, 4.6, 0 },
	UpperTorso = { 2, 1.6, 1, 0, 3.2, 0 },
	LowerTorso = { 2, 0.4, 1, 0, 2.2, 0 },
	LeftUpperArm = { 1, 1.2, 1, -1.5, 3.4, 0 }, RightUpperArm = { 1, 1.2, 1, 1.5, 3.4, 0 },
	LeftLowerArm = { 1, 1.1, 1, -1.5, 2.3, 0 }, RightLowerArm = { 1, 1.1, 1, 1.5, 2.3, 0 },
	LeftUpperLeg = { 1, 1.2, 1, -0.5, 1.4, 0 }, RightUpperLeg = { 1, 1.2, 1, 0.5, 1.4, 0 },
	LeftLowerLeg = { 1, 1.1, 1, -0.5, 0.5, 0 }, RightLowerLeg = { 1, 1.1, 1, 0.5, 0.5, 0 },
}
local function rig(kind)
	local m = Instance.new("Model")
	local hum = Instance.new("Humanoid")
	hum.RigType = if kind == "R6" then Enum.HumanoidRigType.R6 else Enum.HumanoidRigType.R15
	hum.Parent = m
	local names = if kind == "R6" then { Head = LIMBS.Head, Torso = { 2, 2, 1, 0, 3, 0 } } else LIMBS
	for name, l in names do
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(l[1], l[2], l[3])
		p.CFrame = CFrame.new(l[4], l[5], l[6])
		p.Parent = m
	end
	m.Parent = workspace
	return m
end

test("every outfit in Config has 3D pieces, and every piece names a real limb", function()
	for _, o in Config.OUTFITS do
		local pieces = OutfitParts.OUTFITS[o.id]
		ok(pieces ~= nil and #pieces >= 5, o.id .. " has pieces")
		ok(typeof(o.trim) == "Color3" and typeof(o.hat) == "Color3", o.id .. " has trim and hat colours")
		for _, p in pieces do
			ok(LIMBS[p.limb] ~= nil, o.id .. "." .. p.name .. " on " .. p.limb)
		end
	end
end)

test("dressing an R15 character: welded, massless, never in the way", function()
	for _, o in Config.OUTFITS do
		local m = rig("R15")
		local n = Wardrobe.dress(m, o.id)
		eq(n, #OutfitParts.OUTFITS[o.id], o.id .. ": every piece found its limb")
		for _, p in m.Outfit:GetChildren() do
			eq(p.Massless, true)
			eq(p.CanCollide, false)
			eq(p.CanQuery, false)
			eq(p.CanTouch, false)
			eq(p.Anchored, false)
			local weld = p:FindFirstChildWhichIsA("WeldConstraint")
			ok(weld ~= nil and weld.Part0 ~= nil and weld.Part0.Parent == m, p.Name .. " welded to a limb")
			local limb = weld.Part0
			ok((p.Position - limb.Position).Magnitude < 3, string.format("%s.%s stays near %s", o.id, p.Name, limb.Name))
		end
		m:Destroy()
	end
end)

test("hats sit on top of the head; skirts reach the ground; coats face the right way", function()
	local m = rig("R15")
	Wardrobe.dress(m, "frock")
	local head = m.Head
	ok(m.Outfit.HatCrown.Position.Y > head.Position.Y + head.Size.Y / 2, "the top hat is above the head")
	ok(m.Outfit.Waistcoat.Position.Z < m.UpperTorso.Position.Z, "the waistcoat is on the front (-Z, where the character faces)")
	ok(m.Outfit.Skirts.Position.Z > m.LowerTorso.Position.Z, "frock coat tails hang at the back")
	m:Destroy()
	m = rig("R15")
	Wardrobe.dress(m, "daydress")
	local hem = m.Outfit.SkirtHem
	local bottom = hem.Position.Y - hem.Size.X / 2
	ok(bottom < 0.1 and bottom > -0.5, "the skirt brushes the ground: bottom at " .. bottom)
	ok(math.abs(hem.CFrame.RightVector.Y) > 0.99, "the skirt cylinder stands upright")
	m:Destroy()
end)

test("dressing again replaces the outfit; R6 gets torso and hat pieces only", function()
	local m = rig("R15")
	Wardrobe.dress(m, "frock")
	Wardrobe.dress(m, "tweed")
	eq(#m:GetChildren(), 1 + 11 + 1, "humanoid, limbs, one Outfit folder")
	ok(m.Outfit:FindFirstChild("CapPeak") ~= nil, "now a flat cap")
	local r6 = rig("R6")
	local n = Wardrobe.dress(r6, "frock")
	local expected = 0
	for _, p in OutfitParts.OUTFITS.frock do
		if OutfitParts.R6_MAP[p.limb] then
			expected += 1
		end
	end
	eq(n, expected)
	ok(n > 0)
	eq(Wardrobe.dress(m, "nonsense"), 0, "unknown outfit: nothing")
end)
