--!strict
-- Shared.OutfitParts: 3D period outfits built from parts (TASKS T06, OPEN_QUESTIONS Q23: hats come
-- with the outfit). LondonServer.Wardrobe welds these onto a character after it spawns; every
-- piece is massless and never collides, so walking, jumping and sitting are unchanged. Sizes and
-- positions are relative to the limb a piece is fixed to, so they fit any body scale:
--   size = limb.Size * rel + add (studs);  position = limb centre + limb.Size * at + shift (studs)
--   shape "Block" | "Cylinder" | "Ball" | "Wedge"; up = true turns a cylinder upright
--   colour = an outfit colour slot ("coat", "lower", "trim", "hat", "shirt") or a fixed Color3
-- R15 limb names. On R6 (Torso, Head) only torso and head pieces are used (R6_MAP).
-- The art pass can swap any piece for a Blender MeshPart with the same name (art/blender.md).
local OutfitParts = {}

export type Piece = {
	name: string, limb: string, shape: string, rel: { number }, add: { number }?, at: { number },
	shift: { number }?, colour: any, material: Enum.Material?, up: boolean?, turn: { number }?,
}

local M = Enum.Material
local WHITE = Color3.fromRGB(236, 232, 222)
local BLACK = Color3.fromRGB(24, 24, 26)

-- Shared building blocks -------------------------------------------------------------------
local function coat(long: boolean): { Piece }
	local list: { Piece } = {
		{ name = "Coat", limb = "UpperTorso", shape = "Block", rel = { 1.1, 1.06, 1.18 }, at = { 0, 0, 0 }, colour = "coat", material = M.Fabric },
		{ name = "CoatHips", limb = "LowerTorso", shape = "Block", rel = { 1.12, 1.4, 1.2 }, at = { 0, 0, 0 }, colour = "coat", material = M.Fabric },
		{ name = "SleeveL", limb = "LeftUpperArm", shape = "Block", rel = { 1.12, 1.04, 1.12 }, at = { 0, 0, 0 }, colour = "coat", material = M.Fabric },
		{ name = "SleeveR", limb = "RightUpperArm", shape = "Block", rel = { 1.12, 1.04, 1.12 }, at = { 0, 0, 0 }, colour = "coat", material = M.Fabric },
		{ name = "CuffL", limb = "LeftLowerArm", shape = "Block", rel = { 1.12, 1.04, 1.12 }, at = { 0, 0, 0 }, colour = "coat", material = M.Fabric },
		{ name = "CuffR", limb = "RightLowerArm", shape = "Block", rel = { 1.12, 1.04, 1.12 }, at = { 0, 0, 0 }, colour = "coat", material = M.Fabric },
	}
	if long then
		-- frock coat skirts to the knee, open at the front
		table.insert(list, { name = "Skirts", limb = "LowerTorso", shape = "Block", rel = { 1.14, 0, 0.5 }, add = { 0, 1.4, 0 }, at = { 0, -0.5, 0.28 }, shift = { 0, -0.7, 0 }, colour = "coat", material = M.Fabric })
	end
	return list
end

local function waistcoat(colour: any): { Piece }
	return {
		{ name = "Waistcoat", limb = "UpperTorso", shape = "Block", rel = { 0.5, 0.8, 0 }, add = { 0, 0, 0.06 }, at = { 0, -0.05, -0.6 }, colour = colour, material = M.Fabric },
		{ name = "Cravat", limb = "UpperTorso", shape = "Block", rel = { 0.18, 0.18, 0 }, add = { 0, 0, 0.08 }, at = { 0, 0.4, -0.62 }, colour = WHITE, material = M.Fabric },
	}
end

local function trousers(): { Piece }
	local list: { Piece } = {}
	for _, side in { "Left", "Right" } do
		table.insert(list, { name = "Trouser" .. side, limb = side .. "UpperLeg", shape = "Block", rel = { 1.08, 1.02, 1.08 }, at = { 0, 0, 0 }, colour = "lower", material = M.Fabric })
		table.insert(list, { name = "Shin" .. side, limb = side .. "LowerLeg", shape = "Block", rel = { 1.08, 1.02, 1.08 }, at = { 0, 0, 0 }, colour = "lower", material = M.Fabric })
	end
	return list
end

-- A bell skirt from the waist to the ground: two tiers, wider at the hem.
local function skirt(colour: any, flare: number): { Piece }
	return {
		{ name = "SkirtTop", limb = "LowerTorso", shape = "Cylinder", up = true, rel = { 0, 0, 0 }, add = { 1.4, 2.3, 2.3 }, at = { 0, 0, 0 }, shift = { 0, -0.5, 0 }, colour = colour, material = M.Fabric },
		{ name = "SkirtHem", limb = "LowerTorso", shape = "Cylinder", up = true, rel = { 0, 0, 0 }, add = { 1.6, 2.3 + flare, 2.3 + flare }, at = { 0, 0, 0 }, shift = { 0, -1.7, 0 }, colour = colour, material = M.Fabric },
	}
end

local function bodice(colour: any, puff: number): { Piece }
	return {
		{ name = "Bodice", limb = "UpperTorso", shape = "Block", rel = { 1.06, 1.04, 1.12 }, at = { 0, 0, 0 }, colour = colour, material = M.Fabric },
		{ name = "SleeveL", limb = "LeftUpperArm", shape = "Ball", rel = { puff, 0.9, puff }, at = { 0, 0.15, 0 }, colour = colour, material = M.Fabric },
		{ name = "SleeveR", limb = "RightUpperArm", shape = "Ball", rel = { puff, 0.9, puff }, at = { 0, 0.15, 0 }, colour = colour, material = M.Fabric },
		{ name = "ForearmL", limb = "LeftLowerArm", shape = "Block", rel = { 1.08, 1.02, 1.08 }, at = { 0, 0, 0 }, colour = colour, material = M.Fabric },
		{ name = "ForearmR", limb = "RightLowerArm", shape = "Block", rel = { 1.08, 1.02, 1.08 }, at = { 0, 0, 0 }, colour = colour, material = M.Fabric },
	}
end

-- Hats ---------------------------------------------------------------------------------------
local function topHat(): { Piece }
	return {
		{ name = "HatBrim", limb = "Head", shape = "Cylinder", up = true, rel = { 0, 0, 0 }, add = { 0.12, 1.75, 1.75 }, at = { 0, 0.5, 0 }, shift = { 0, 0.02, 0 }, colour = "hat", material = M.Fabric },
		{ name = "HatCrown", limb = "Head", shape = "Cylinder", up = true, rel = { 0, 0, 0 }, add = { 1.1, 1.15, 1.15 }, at = { 0, 0.5, 0 }, shift = { 0, 0.6, 0 }, colour = "hat", material = M.Fabric },
		{ name = "HatBand", limb = "Head", shape = "Cylinder", up = true, rel = { 0, 0, 0 }, add = { 0.2, 1.17, 1.17 }, at = { 0, 0.5, 0 }, shift = { 0, 0.18, 0 }, colour = "trim", material = M.Fabric },
	}
end

local function flatCap(): { Piece }
	return {
		{ name = "CapCrown", limb = "Head", shape = "Cylinder", up = true, rel = { 0, 0, 0 }, add = { 0.35, 1.3, 1.3 }, at = { 0, 0.45, 0 }, shift = { 0, 0.05, 0 }, colour = "hat", material = M.Fabric },
		{ name = "CapPeak", limb = "Head", shape = "Block", rel = { 0, 0, 0 }, add = { 0.9, 0.08, 0.5 }, at = { 0, 0.45, -0.5 }, shift = { 0, -0.05, -0.15 }, colour = "hat", material = M.Fabric },
	}
end

local function bonnet(): { Piece }
	return {
		{ name = "Bonnet", limb = "Head", shape = "Ball", rel = { 1.2, 1.1, 1.25 }, at = { 0, 0.12, 0.08 }, colour = "hat", material = M.Fabric },
		{ name = "BonnetBrim", limb = "Head", shape = "Block", rel = { 1.25, 0.95, 0 }, add = { 0, 0, 0.12 }, at = { 0, 0.1, -0.45 }, colour = "trim", material = M.Fabric },
	}
end

local function hatWithBrim(): { Piece }
	return {
		{ name = "HatBrim", limb = "Head", shape = "Cylinder", up = true, rel = { 0, 0, 0 }, add = { 0.1, 2.1, 2.1 }, at = { 0, 0.5, 0 }, colour = "hat", material = M.Fabric },
		{ name = "HatCrown", limb = "Head", shape = "Cylinder", up = true, rel = { 0, 0, 0 }, add = { 0.5, 1.15, 1.15 }, at = { 0, 0.5, 0 }, shift = { 0, 0.25, 0 }, colour = "hat", material = M.Fabric },
		{ name = "HatFeather", limb = "Head", shape = "Block", rel = { 0, 0, 0 }, add = { 0.12, 0.5, 0.7 }, at = { 0.35, 0.5, 0 }, shift = { 0, 0.55, 0.1 }, colour = "trim", material = M.Fabric },
	}
end

local function mobCap(): { Piece }
	return {
		{ name = "MobCap", limb = "Head", shape = "Ball", rel = { 1.15, 0.85, 1.15 }, at = { 0, 0.3, 0.05 }, colour = WHITE, material = M.Fabric },
	}
end

local function apron(): { Piece }
	return {
		{ name = "ApronBib", limb = "UpperTorso", shape = "Block", rel = { 0.6, 0.7, 0 }, add = { 0, 0, 0.06 }, at = { 0, -0.1, -0.62 }, colour = WHITE, material = M.Fabric },
		{ name = "Apron", limb = "LowerTorso", shape = "Block", rel = { 0.95, 0, 0 }, add = { 0, 2.6, 0.08 }, at = { 0, 0, 0 }, shift = { 0, -1.3, -1.25 }, colour = WHITE, material = M.Fabric },
	}
end

local function join(...: { Piece }): { Piece }
	local out = {}
	for _, list in { ... } do
		for _, p in list do
			table.insert(out, p)
		end
	end
	return out
end

-- Outfit id (Config.OUTFITS) -> pieces.
OutfitParts.OUTFITS = {
	frock = join(coat(true), waistcoat("trim"), trousers(), topHat()),
	tweed = join(coat(false), waistcoat("trim"), trousers(), flatCap()),
	work = join(waistcoat("coat"), trousers(), flatCap()),
	daydress = join(bodice("coat", 1.45), skirt("lower", 0.9), bonnet()),
	walking = join(bodice("coat", 1.2), skirt("lower", 0.5), hatWithBrim()),
	plain = join(bodice("coat", 1.1), skirt("lower", 0.6), apron(), mobCap()),
}

-- R6 rigs have Torso and Head only: torso pieces go on the Torso, limbs are skipped.
OutfitParts.R6_MAP = { UpperTorso = "Torso", LowerTorso = "Torso", Head = "Head" }

OutfitParts.BLACK = BLACK
OutfitParts.WHITE = WHITE

return OutfitParts
