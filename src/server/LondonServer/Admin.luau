--!strict
-- LondonServer.Admin: staff kick / ban / mute. Ban check on join, cross-server bans over
-- MessagingService, chat commands (/kick /ban /unban /smute /sunmute /logs; /mute is taken by
-- Roblox's own local mute) and "Admin" remotes for the future staff panel.
-- Every action is checked here with Roles.can (actor nil = server/console) and logged.
-- M0 limit: mutes need the target in this server (stored on their profile, record.mutedUntil).
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local Text = require(Shared:WaitForChild("Text"))
local Types = require(Shared:WaitForChild("Types"))
local Store = require(script.Parent:WaitForChild("Store"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local AdminLog = require(script.Parent:WaitForChild("AdminLog"))

local V = Net.V
local Admin = {}
local bans = Store.open(Config.BANS_STORE)
local muted: { [number]: number } = {} -- userId -> mutedUntil (os.time)

local function banKey(userId: number): string
	return "u_" .. userId
end

local function actorId(actor: Player?): number
	return if actor then actor.UserId else 0
end

local function authorize(actor: Player?, action: string, target: number?): (boolean, string?)
	if actor == nil or Roles.can(actor, action, target) then
		return true, nil
	end
	return false, "not permitted"
end

local function cleanReason(reason: string?): string
	return Text.sanitize(reason or "", Config.REASON_MAX) or ""
end

-- The reason the target sees goes through the filter; a failed filter shows a generic line.
local function reasonFor(by: number, reason: string, toUserId: number): string
	if reason == "" then
		return "No reason given."
	end
	return Text.filterFor(reason, if by ~= 0 then by else toUserId, toUserId) or "See the rules."
end

local function describe(minutes: number): string
	if minutes == 0 then
		return "permanently"
	elseif minutes % 1440 == 0 then
		return string.format("for %d day(s)", minutes // 1440)
	elseif minutes % 60 == 0 then
		return string.format("for %d hour(s)", minutes // 60)
	end
	return string.format("for %d minute(s)", minutes)
end

local function notify(player: Player?, text: string)
	if player and player.Parent == Players then
		Net.push(player, "Admin", "Notice", { text = text })
	end
end

local function banMessage(rec: any, toUserId: number): string
	local untilT = tonumber(rec.untilT) or 0
	local span = if untilT == 0
		then "permanently"
		else describe(math.max(1, math.ceil((untilT - os.time()) / 60))) .. " more"
	return string.format("You are banned %s. Reason: %s", span, reasonFor(tonumber(rec.by) or 0, tostring(rec.reason or ""), toUserId))
end

local function writeBan(userId: number, record: any?): boolean
	for _ = 1, Config.SAVE_RETRIES do
		local ok, err = pcall(function()
			if record then
				bans:update(banKey(userId), function()
					return record
				end)
			else
				bans:remove(banKey(userId))
			end
		end)
		if ok then
			return true
		end
		warn("[Admin] ban store error: " .. tostring(err))
		task.wait(Config.SAVE_RETRY_SECONDS)
	end
	return false
end

local function broadcast(kind: string, userId: number)
	if Store.isMock then
		return
	end
	task.spawn(function()
		pcall(MessagingService.PublishAsync, MessagingService, Config.ADMIN_TOPIC, { kind = kind, userId = userId })
	end)
end

-- Kicks the player if banned. Store errors let the player in (logged).
function Admin.checkBan(player: Player): boolean
	local ok, rec = pcall(function()
		return bans:get(banKey(player.UserId))
	end)
	if not ok then
		warn("[Admin] ban check failed: " .. tostring(rec))
		return false
	end
	if type(rec) ~= "table" then
		return false
	end
	local untilT = tonumber(rec.untilT) or 0
	if untilT ~= 0 and untilT <= os.time() then
		task.spawn(writeBan, player.UserId, nil)
		return false
	end
	player:Kick(banMessage(rec, player.UserId))
	return true
end

function Admin.kick(actor: Player?, userId: number, reason: string?): (boolean, string?)
	local ok, err = authorize(actor, "admin.kick", userId)
	if not ok then
		return false, err
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target then
		return false, "player not in this server"
	end
	local r = cleanReason(reason)
	AdminLog.add(actorId(actor), "kick", userId, r)
	target:Kick("Removed by staff. Reason: " .. reasonFor(actorId(actor), r, userId))
	return true, nil
end

-- minutes = 0 is permanent.
function Admin.ban(actor: Player?, userId: number, minutes: number, reason: string?): (boolean, string?)
	local ok, err = authorize(actor, "admin.ban", userId)
	if not ok then
		return false, err
	end
	if minutes % 1 ~= 0 or minutes < 0 or minutes > Config.MAX_BAN_MINUTES then
		return false, "bad duration"
	end
	local r = cleanReason(reason)
	local now = os.time()
	local record = { reason = r, by = actorId(actor), at = now, untilT = if minutes == 0 then 0 else now + minutes * 60 }
	if not writeBan(userId, record) then
		return false, "ban store unavailable"
	end
	AdminLog.add(actorId(actor), "ban", userId, r, minutes)
	local target = Players:GetPlayerByUserId(userId)
	if target then
		target:Kick(banMessage(record, userId))
	end
	broadcast("ban", userId)
	return true, nil
end

function Admin.unban(actor: Player?, userId: number): (boolean, string?)
	local ok, err = authorize(actor, "admin.unban", userId)
	if not ok then
		return false, err
	end
	if not writeBan(userId, nil) then
		return false, "ban store unavailable"
	end
	AdminLog.add(actorId(actor), "unban", userId)
	return true, nil
end

function Admin.isMuted(userId: number): boolean
	local u = muted[userId]
	return u ~= nil and os.time() < u
end

local function applyMute(userId: number)
	local on = Admin.isMuted(userId)
	for _, d in TextChatService:GetDescendants() do
		if d:IsA("TextSource") and d.UserId == userId then
			d.CanSend = not on
		end
	end
end

local function lift(userId: number)
	muted[userId] = nil
	local p = Players:GetPlayerByUserId(userId)
	local prof = if p then Profiles.get(p) else nil
	if prof then
		prof.record.mutedUntil = 0
	end
	applyMute(userId)
end

function Admin.mute(actor: Player?, userId: number, minutes: number, reason: string?): (boolean, string?)
	local ok, err = authorize(actor, "admin.mute", userId)
	if not ok then
		return false, err
	end
	if minutes % 1 ~= 0 or minutes < 1 or minutes > Config.MAX_MUTE_MINUTES then
		return false, "bad duration"
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target then
		return false, "player not in this server"
	end
	local r = cleanReason(reason)
	local untilT = os.time() + minutes * 60
	muted[userId] = untilT
	local prof = Profiles.get(target)
	if prof then
		prof.record.mutedUntil = untilT
	end
	applyMute(userId)
	AdminLog.add(actorId(actor), "mute", userId, r, minutes)
	notify(target, string.format("You have been muted %s. Reason: %s", describe(minutes), reasonFor(actorId(actor), r, userId)))
	return true, nil
end

function Admin.unmute(actor: Player?, userId: number): (boolean, string?)
	local ok, err = authorize(actor, "admin.unmute", userId)
	if not ok then
		return false, err
	end
	if muted[userId] == nil then
		return false, "not muted"
	end
	lift(userId)
	AdminLog.add(actorId(actor), "unmute", userId)
	notify(Players:GetPlayerByUserId(userId), "You may speak again.")
	return true, nil
end

function Admin.logs(actor: Player?, count: number): ({ Types.LogEntry }?, string?)
	local ok, err = authorize(actor, "admin.logs")
	if not ok then
		return nil, err
	end
	return AdminLog.recent(count), nil
end

function Admin.onProfileLoaded(player: Player, profile: Types.Profile)
	if profile.record.mutedUntil > os.time() then
		muted[player.UserId] = profile.record.mutedUntil
		applyMute(player.UserId)
	end
end

function Admin.onPlayerRemoving(player: Player)
	muted[player.UserId] = nil
end

-- Chat commands -------------------------------------------------------------------
-- Player by exact name, unique name/display-name prefix, or a userId number.
local function findTarget(token: string?): number?
	if not token then
		return nil
	end
	local id = tonumber(token)
	if id and id % 1 == 0 then
		return id
	end
	local lower = string.lower(token)
	local found: Player? = nil
	for _, p in Players:GetPlayers() do
		local n, dn = string.lower(p.Name), string.lower(p.DisplayName)
		if n == lower then
			return p.UserId
		end
		if string.sub(n, 1, #lower) == lower or string.sub(dn, 1, #lower) == lower then
			if found then
				return nil -- ambiguous
			end
			found = p
		end
	end
	return if found then found.UserId else nil
end

-- "perm"/"0" -> 0, "30" or "30m" -> 30, "2h" -> 120, "3d" -> 4320.
local function parseMinutes(token: string?): number?
	if not token then
		return nil
	end
	local t = string.lower(token)
	if t == "perm" or t == "0" then
		return 0
	end
	local n, unit = string.match(t, "^(%d+)([mhd]?)$")
	local num = tonumber(n)
	if not num then
		return nil
	end
	return num * (if unit == "h" then 60 elseif unit == "d" then 1440 else 1)
end

local USAGE = {
	kick = "/kick <player> [reason]",
	ban = "/ban <player|userId> <30m|2h|3d|perm> [reason]",
	unban = "/unban <userId>",
	smute = "/smute <player> <30m|2h> [reason]",
	sunmute = "/sunmute <player>",
	logs = "/logs",
}

local function runCommand(actor: Player, name: string, text: string)
	local words = {}
	for _, w in string.split(text, " ") do
		if w ~= "" then
			table.insert(words, w)
		end
	end
	if name == "logs" then
		local list, err = Admin.logs(actor, Config.ADMIN_LOG_SHOW)
		if not list then
			notify(actor, "Failed: " .. tostring(err))
			return
		end
		if #list == 0 then
			notify(actor, "No staff actions in this server yet.")
		end
		for _, e in list do
			notify(actor, string.format("%s by %d -> %s %s", e.action, e.by, tostring(e.target), e.reason or ""))
		end
		return
	end
	local targetId = findTarget(words[2])
	if not targetId then
		notify(actor, "Player not found. Usage: " .. USAGE[name])
		return
	end
	local ok, err
	if name == "kick" then
		ok, err = Admin.kick(actor, targetId, table.concat(words, " ", 3))
	elseif name == "ban" or name == "smute" then
		local minutes = parseMinutes(words[3])
		if not minutes then
			notify(actor, "Usage: " .. USAGE[name])
			return
		end
		if name == "ban" then
			ok, err = Admin.ban(actor, targetId, minutes, table.concat(words, " ", 4))
		else
			ok, err = Admin.mute(actor, targetId, minutes, table.concat(words, " ", 4))
		end
	elseif name == "unban" then
		ok, err = Admin.unban(actor, targetId)
	elseif name == "sunmute" then
		ok, err = Admin.unmute(actor, targetId)
	end
	notify(actor, if ok then string.format("Done: %s %d", name, targetId) else "Failed: " .. tostring(err))
end

local function result(ok: boolean, err: string?): (any, string?)
	if ok then
		return true, nil
	end
	return nil, err or "failed"
end

function Admin.init()
	-- chat commands
	local cmdFolder = Instance.new("Folder")
	cmdFolder.Name = "LondonCommands"
	for name in USAGE do
		local cmd = Instance.new("TextChatCommand")
		cmd.Name = "London_" .. name
		cmd.PrimaryAlias = "/" .. name
		cmd.Triggered:Connect(function(source: TextSource, text: string)
			local actor = Players:GetPlayerByUserId(source.UserId)
			if actor then
				runCommand(actor, name, text)
			end
		end)
		cmd.Parent = cmdFolder
	end
	cmdFolder.Parent = TextChatService

	-- new chat sources pick up an existing mute
	TextChatService.DescendantAdded:Connect(function(d)
		if d:IsA("TextSource") and Admin.isMuted(d.UserId) then
			d.CanSend = false
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.MUTE_CHECK_SECONDS)
			for userId, untilT in muted do
				if os.time() >= untilT then
					lift(userId)
					notify(Players:GetPlayerByUserId(userId), "Your mute has ended.")
				end
			end
		end
	end)

	-- remotes for the staff panel
	local rate = Config.ADMIN_RATE
	local reason = V.optional(V.str(Config.REASON_MAX, true))
	Net.handle("Admin", "Kick", { schema = { userId = V.userId(), reason = reason }, can = "admin.kick", target = "userId", rate = rate }, function(p, a)
		return result(Admin.kick(p, a.userId, a.reason))
	end)
	Net.handle("Admin", "Ban", { schema = { userId = V.userId(), minutes = V.int(0, Config.MAX_BAN_MINUTES), reason = reason }, can = "admin.ban", target = "userId", rate = rate }, function(p, a)
		return result(Admin.ban(p, a.userId, a.minutes, a.reason))
	end)
	Net.handle("Admin", "Unban", { schema = { userId = V.userId() }, can = "admin.unban", rate = rate }, function(p, a)
		return result(Admin.unban(p, a.userId))
	end)
	Net.handle("Admin", "Mute", { schema = { userId = V.userId(), minutes = V.int(1, Config.MAX_MUTE_MINUTES), reason = reason }, can = "admin.mute", target = "userId", rate = rate }, function(p, a)
		return result(Admin.mute(p, a.userId, a.minutes, a.reason))
	end)
	Net.handle("Admin", "Unmute", { schema = { userId = V.userId() }, can = "admin.unmute", rate = rate }, function(p, a)
		return result(Admin.unmute(p, a.userId))
	end)
	Net.handle("Admin", "Logs", { schema = { count = V.int(1, Config.ADMIN_LOG_MEMORY) }, can = "admin.logs", rate = rate, call = true }, function(p, a)
		return Admin.logs(p, a.count)
	end)

	-- cross-server bans
	if not Store.isMock then
		pcall(function()
			MessagingService:SubscribeAsync(Config.ADMIN_TOPIC, function(m)
				local d = m.Data
				if type(d) == "table" and d.kind == "ban" and type(d.userId) == "number" then
					local p = Players:GetPlayerByUserId(d.userId)
					if p then
						Admin.checkBan(p)
					end
				end
			end)
		end)
	end
end

return Admin
