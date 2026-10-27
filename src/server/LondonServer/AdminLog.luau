--!strict
-- LondonServer.AdminLog: staff action log. Newest Config.ADMIN_LOG_MEMORY kept in this server,
-- and appended to Config.ADMIN_LOG_STORE under "d_<yyyymmdd>" (UTC, capped per day).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Store = require(script.Parent:WaitForChild("Store"))

local AdminLog = {}
local store = Store.open(Config.ADMIN_LOG_STORE)
local recent: { Types.LogEntry } = {}

function AdminLog.dayKey(t: number): string
	local d = os.date("!*t", t)
	return string.format("d_%04d%02d%02d", d.year, d.month, d.day)
end

function AdminLog.add(by: number, action: string, target: number?, reason: string?, minutes: number?)
	local entry: Types.LogEntry = {
		at = os.time(),
		by = by,
		action = action,
		target = target,
		reason = reason,
		minutes = minutes,
		server = game.JobId,
	}
	table.insert(recent, 1, entry)
	if #recent > Config.ADMIN_LOG_MEMORY then
		table.remove(recent)
	end
	print(string.format("[Admin] %d %s %s %s", by, action, tostring(target), reason or ""))
	task.spawn(function()
		local ok, err = pcall(function()
			store:update(AdminLog.dayKey(entry.at), function(list: any)
				list = if type(list) == "table" then list else {}
				if #list >= Config.ADMIN_LOG_DAY_CAP then
					return nil
				end
				table.insert(list, entry)
				return list
			end)
		end)
		if not ok then
			warn("[AdminLog] store error: " .. tostring(err))
		end
	end)
end

-- Newest first.
function AdminLog.recent(n: number): { Types.LogEntry }
	local out = {}
	for i = 1, math.min(n, #recent) do
		out[i] = recent[i]
	end
	return out
end

-- Stored entries for one UTC day (yields).
function AdminLog.day(t: number): { Types.LogEntry }
	local ok, list = pcall(function()
		return store:get(AdminLog.dayKey(t))
	end)
	return if ok and type(list) == "table" then list else {}
end

return AdminLog
