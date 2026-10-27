--!strict
-- Shared.Hobbies: hobby levels from activity XP (ACTIVITIES §3). Profile: hobbies[name] = xp.
local Config = require(script.Parent.Config)

local Hobbies = {}

-- Total XP needed to reach a level (level 1 = 0).
function Hobbies.xpFor(level: number): number
	return math.floor(Config.HOBBY_XP_BASE * (level - 1) ^ Config.HOBBY_XP_EXP)
end

function Hobbies.level(xp: number): number
	local lvl = 1
	while lvl < Config.HOBBY_MAX_LEVEL and xp >= Hobbies.xpFor(lvl + 1) do
		lvl += 1
	end
	return lvl
end

function Hobbies.isHobby(name: string): boolean
	return table.find(Config.HOBBIES, name) ~= nil
end

return Hobbies
