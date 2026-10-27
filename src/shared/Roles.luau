--!strict
-- Shared.Roles: the single permission check, Roles.can(player, action, target?) (TECH.md §6).
-- M0 input: staff level (group rank or Config lists), set by the server as the "StaffLevel"
-- attribute at join. Titles, offices, station role and presiding rules plug in from M1/M3.
-- The client may call Roles.can to grey out menus; only the server's answer counts.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)

local L = Config.STAFF_LEVEL
local Roles = {}
Roles.STAFF_ATTR = "StaffLevel"
Roles.ROLE_ATTR = "Role" -- Shared.Stations id held in this server, set by LondonServer.Identity

export type Rule = {
	staff: number?, -- minimum staff level
	outranks: boolean?, -- the target must have a lower staff level than the actor
	studio: boolean?, -- only inside Studio
}

-- Every permissioned action, readable in one place.
Roles.ACTIONS = {
	["admin.kick"] = { staff = L.MOD, outranks = true },
	["admin.mute"] = { staff = L.MOD, outranks = true },
	["admin.unmute"] = { staff = L.MOD },
	["admin.ban"] = { staff = L.ADMIN, outranks = true },
	["admin.unban"] = { staff = L.ADMIN },
	["admin.logs"] = { staff = L.MOD },
	["debug.use"] = { staff = L.ADMIN, studio = true },
} :: { [string]: Rule }

-- Staff level from Config lists only (works for offline targets).
function Roles.configLevel(userId: number): number
	local lvl = Config.STAFF_USER_IDS[userId] or 0
	if RunService:IsStudio() then
		lvl = math.max(lvl, Config.STUDIO_TEST_STAFF[userId] or 0)
	end
	return lvl
end

-- Server only; yields on the group rank lookup.
function Roles.computeStaffLevel(player: Player): number
	local lvl = Roles.configLevel(player.UserId)
	if Config.GROUP_ID ~= 0 then
		local ok, rank = pcall(player.GetRankInGroup, player, Config.GROUP_ID)
		if ok and type(rank) == "number" then
			for minRank, l in Config.GROUP_RANK_STAFF do
				if rank >= minRank and l > lvl then
					lvl = l
				end
			end
		end
	end
	return lvl
end

function Roles.staffLevel(who: Player | number): number
	if type(who) == "number" then
		local p = Players:GetPlayerByUserId(who)
		if p then
			return Roles.staffLevel(p)
		end
		return Roles.configLevel(who)
	end
	local a = (who :: Player):GetAttribute(Roles.STAFF_ATTR)
	return if type(a) == "number" then a else 0
end

-- Station role held in this server (Shared.Stations id).
function Roles.roleOf(player: Player): string
	local a = player:GetAttribute(Roles.ROLE_ATTR)
	return if type(a) == "string" then a else Config.DEFAULT_ROLE
end

function Roles.can(player: Player, action: string, target: (Player | number)?): boolean
	local rule = Roles.ACTIONS[action]
	if not rule then
		return false
	end
	if rule.studio and not RunService:IsStudio() then
		return false
	end
	local lvl = Roles.staffLevel(player)
	if lvl < (rule.staff or 0) then
		return false
	end
	if rule.outranks and target ~= nil and Roles.staffLevel(target) >= lvl then
		return false
	end
	return true
end

return Roles
