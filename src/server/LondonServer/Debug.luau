--!strict
-- LondonServer.Debug: Studio-only test bindable, ServerStorage.LondonDebug (never created live).
-- From the Server datamodel: game.ServerStorage.LondonDebug:Invoke("givePence", userId, 120)
-- Commands: profile, givePence, setStaff, rejoin, lockTest, raw, setRaw, admin, net, analytics,
-- setRole, clock, play, giveItem, ledger, totals, weather.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local Store = require(script.Parent:WaitForChild("Store"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local Admin = require(script.Parent:WaitForChild("Admin")) :: any
local Analytics = require(script.Parent:WaitForChild("Analytics"))
local Identity = require(script.Parent:WaitForChild("Identity"))
local Characters = require(script.Parent:WaitForChild("Characters"))
local WorldClock = require(script.Parent:WaitForChild("WorldClock"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Inventory = require(script.Parent:WaitForChild("Inventory"))

local Debug = {}

local function plr(userId: number): Player
	return assert(Players:GetPlayerByUserId(userId), "no player " .. tostring(userId))
end

local cmds: { [string]: (...any) -> any } = {
	analytics = function(n)
		return HttpService:JSONEncode(Analytics.recent(n or 10))
	end,
	profile = function(userId)
		return HttpService:JSONEncode(Profiles.get(plr(userId)))
	end,
	givePence = function(userId, n)
		return (Economy.change(plr(userId), n, "admin", "debug"))
	end,
	-- giveItem(userId, itemId, count): into the bag (furniture into storage)
	giveItem = function(userId, itemId, count)
		return Inventory.add(plr(userId), itemId, count or 1)
	end,
	-- ledger(userId): this session's money lines, newest first
	ledger = function(userId)
		return HttpService:JSONEncode(Economy.recent(plr(userId)))
	end,
	-- weather(kind): "clear", "rain" or "fog" (a pea-souper)
	weather = function(kind)
		return WorldClock.setWeather(kind)
	end,
	-- totals(): money in (+) and out (-) of this server by reason since it started
	totals = function()
		return HttpService:JSONEncode(Economy.totals())
	end,
	setStaff = function(userId, lvl)
		plr(userId):SetAttribute(Roles.STAFF_ATTR, lvl)
		return true
	end,
	rejoin = function(userId)
		return Profiles.debugRejoin(plr(userId))
	end,
	-- a second "server" tries to load a key: expect "locked" while it is held
	lockTest = function(userId, maxWait)
		local data, why = Profiles.load(userId, "debug-other-server", maxWait or 4)
		return if data then "loaded" else why
	end,
	raw = function(storeName, key)
		return Store.debugRaw(storeName, key)
	end,
	setRaw = function(storeName, key, json)
		Store.debugSetRaw(storeName, key, json)
		return true
	end,
	-- admin(action, actorUserId (0 = console), ...args)
	admin = function(action, actorUserId, ...)
		local actor = if actorUserId == 0 then nil else plr(actorUserId)
		return Admin[action](actor, ...)
	end,
	-- setRole(userId, roleId): skips cooldowns, seat checks still count the seat
	setRole = function(userId, roleId)
		return Identity.debugSetRole(plr(userId), roleId)
	end,
	-- play(userId): skip the character menu (makes slot 1 "Test Player<id>" if empty)
	play = function(userId)
		return Characters.debugQuickStart(plr(userId))
	end,
	-- clock(hour): jump the world clock, e.g. clock(18) for dusk
	clock = function(hour)
		return WorldClock.debugSetHour(hour)
	end,
	-- net(userId, domain, msg, isCall): runs the server validator path as that player
	net = function(userId, domain, msg, isCall)
		return Net._dispatch(plr(userId), domain, msg, isCall == true)
	end,
}

function Debug.init()
	if not RunService:IsStudio() then
		return
	end
	local bf = Instance.new("BindableFunction")
	bf.Name = "LondonDebug"
	bf.OnInvoke = function(cmd: string, ...)
		local f = cmds[cmd]
		if not f then
			return "unknown command"
		end
		return f(...)
	end
	bf.Parent = ServerStorage
end

return Debug
