--!strict
-- LondonServer.Store: thin DataStore wrapper. In Studio, unless Config.STUDIO_USE_REAL_STORE is
-- on, every store is an in-memory mock that JSON round-trips values like a real save and yields
-- Config.MOCK_LATENCY per call. Mock data lasts until Play stops. Methods raise; callers pcall.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type Handle = {
	name: string,
	get: (self: Handle, key: string) -> any,
	update: (self: Handle, key: string, fn: (any) -> any) -> any, -- fn returns nil to cancel
	remove: (self: Handle, key: string) -> (),
}

local Store = {}
Store.isMock = RunService:IsStudio() and not Config.STUDIO_USE_REAL_STORE

local mock: { [string]: { [string]: string } } = {} -- store name -> key -> JSON
local handles: { [string]: Handle } = {}

local function decode(s: string?): any
	if s == nil then
		return nil
	end
	return HttpService:JSONDecode(s)
end

function Store.open(name: string): Handle
	local existing = handles[name]
	if existing then
		return existing
	end
	local h: Handle
	if Store.isMock then
		local data = mock[name] or {}
		mock[name] = data
		h = {
			name = name,
			get = function(_, key)
				task.wait(Config.MOCK_LATENCY)
				return decode(data[key])
			end,
			update = function(_, key, fn)
				task.wait(Config.MOCK_LATENCY)
				local new = fn(decode(data[key]))
				if new == nil then
					return nil
				end
				data[key] = HttpService:JSONEncode(new)
				return decode(data[key])
			end,
			remove = function(_, key)
				task.wait(Config.MOCK_LATENCY)
				data[key] = nil
			end,
		}
	else
		local ds = DataStoreService:GetDataStore(name)
		h = {
			name = name,
			get = function(_, key)
				return ds:GetAsync(key)
			end,
			update = function(_, key, fn)
				return ds:UpdateAsync(key, function(old)
					return fn(old)
				end)
			end,
			remove = function(_, key)
				ds:RemoveAsync(key)
			end,
		}
	end
	handles[name] = h
	return h
end

-- Studio test hooks (mock only): raw JSON of a key, or overwrite it (nil deletes).
function Store.debugRaw(name: string, key: string): string?
	local d = mock[name]
	return if d then d[key] else nil
end

function Store.debugSetRaw(name: string, key: string, json: string?)
	mock[name] = mock[name] or {}
	mock[name][key] = json
end

return Store
