--!strict
-- Shared.Looks: character look presets (Config.SKIN_TONES / HAIR_STYLES / OUTFITS), checked on
-- both sides. The server turns a Look into a HumanoidDescription (LondonServer.Characters).
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Looks = {}

function Looks.hair(id: string): any
	for _, h in Config.HAIR_STYLES do
		if h.id == id then
			return h
		end
	end
	return nil
end

function Looks.outfit(id: string): any
	for _, o in Config.OUTFITS do
		if o.id == id then
			return o
		end
	end
	return nil
end

function Looks.default(): Types.Look
	return { skin = 1, hair = Config.HAIR_STYLES[1].id, outfit = Config.OUTFITS[1].id }
end

-- A clean copy of a client-sent look, or nil if any part is unknown.
function Looks.clean(skin: any, hair: any, outfit: any): Types.Look?
	if type(skin) ~= "number" or skin % 1 ~= 0 or skin < 1 or skin > #Config.SKIN_TONES then
		return nil
	end
	if type(hair) ~= "string" or not Looks.hair(hair) or type(outfit) ~= "string" or not Looks.outfit(outfit) then
		return nil
	end
	return { skin = skin, hair = hair, outfit = outfit }
end

-- Saved looks can outlive a preset that was removed from Config: fall back per field.
function Looks.repair(look: any): Types.Look
	local d = Looks.default()
	if type(look) ~= "table" then
		return d
	end
	return Looks.clean(look.skin, look.hair, look.outfit) or {
		skin = if type(look.skin) == "number" and look.skin >= 1 and look.skin <= #Config.SKIN_TONES then look.skin // 1 else d.skin,
		hair = if type(look.hair) == "string" and Looks.hair(look.hair) then look.hair else d.hair,
		outfit = if type(look.outfit) == "string" and Looks.outfit(look.outfit) then look.outfit else d.outfit,
	}
end

return Looks
