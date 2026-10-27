--!strict
-- LondonServer.Profiles: player profiles (schema v1, TECH.md §5.1) in Config.PROFILE_STORE under
-- "u_<userId>". Stored record: { data = Profile, lock = { id, t }?, savedAt }.
-- Session lock: a server claims the record with UpdateAsync; other servers wait LOCK_RETRY and
-- give up after LOCK_MAX_WAIT, unless the lock is older than LOCK_STALE (dead server: taken over).
-- Saves on leave (releases the lock), every AUTOSAVE_SECONDS (refreshes it) and on BindToClose.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Store = require(script.Parent:WaitForChild("Store"))

type Profile = Types.Profile
type Entry = { data: Profile, token: string, saving: boolean, lastTick: number, isNew: boolean }

local Profiles = {}
Profiles.VERSION = 1
Profiles.TOKEN = (if game.JobId ~= "" then game.JobId else "studio") .. "/" .. HttpService:GenerateGUID(false)

local store = Store.open(Config.PROFILE_STORE)
local active: { [number]: Entry } = {}
local loading: { [number]: boolean } = {}
local pending = 0 -- releases in flight (BindToClose waits for these)
local loadedEvent = Instance.new("BindableEvent")
Profiles.Loaded = loadedEvent.Event -- (player, profile)

-- MIGRATIONS[n] upgrades a v(n) profile to v(n+1) in place.
local MIGRATIONS: { [number]: (any) -> () } = {}

local function key(userId: number): string
	return "u_" .. userId
end

function Profiles.defaults(): Profile
	return {
		v = Profiles.VERSION,
		name = { first = "", last = "", changedAt = 0 },
		pence = Config.START_PENCE,
		bank = 0,
		jobs = {},
		titles = {},
		offices = {},
		outfits = { owned = {}, equipped = {} },
		rental = { houseId = nil, paidUntil = 0 },
		vehicles = {},
		licences = { cab = false, omnibus = false, motor = false },
		record = { arrests = 0, warnings = {}, mutedUntil = 0 },
		settings = {},
		firstJoin = os.time(),
		playtime = 0,
	}
end

-- Adds keys missing from older saves. Only recurses into non-empty default tables (structs);
-- maps and lists (jobs, titles...) are kept as saved.
local function reconcile(data: any, defaults: any)
	for k, v in defaults do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

local function upgrade(data: any): (Profile?, string?)
	if type(data) ~= "table" then
		return Profiles.defaults()
	end
	local v = tonumber(data.v) or 1
	if v > Profiles.VERSION then
		return nil, "newer"
	end
	while v < Profiles.VERSION do
		MIGRATIONS[v](data)
		v += 1
		data.v = v
	end
	reconcile(data, Profiles.defaults())
	return data
end

-- One UpdateAsync attempt to claim the lock. Returns "ok" or "locked", and the saved data.
local function claim(userId: number, token: string): (string, any)
	local status, saved = "locked", nil
	store:update(key(userId), function(rec: any)
		rec = if type(rec) == "table" then rec else {}
		local now = os.time()
		local lock = rec.lock
		if type(lock) == "table" and lock.id ~= token and now - (tonumber(lock.t) or 0) < Config.LOCK_STALE_SECONDS then
			status = "locked"
			return nil
		end
		status, saved = "ok", rec.data
		rec.lock = { id = token, t = now }
		return rec
	end)
	return status, saved
end

local function unlock(userId: number, token: string)
	pcall(function()
		store:update(key(userId), function(rec: any)
			if type(rec) ~= "table" or type(rec.lock) ~= "table" or rec.lock.id ~= token then
				return nil
			end
			rec.lock = nil
			return rec
		end)
	end)
end

-- Loads and locks a profile (does not register it). Reasons: "locked", "store error", "newer".
-- Third result is true when nothing was saved before (first join).
function Profiles.load(userId: number, token: string?, maxWait: number?): (Profile?, string?, boolean)
	local tok = token or Profiles.TOKEN
	local deadline = os.clock() + (maxWait or Config.LOCK_MAX_WAIT)
	local errors = 0
	while true do
		local ok, status, saved = pcall(claim, userId, tok)
		if ok and status == "ok" then
			local data, why = upgrade(saved)
			if not data then
				unlock(userId, tok)
			end
			return data, why, type(saved) ~= "table"
		end
		if not ok then
			errors += 1
			warn(string.format("[Profiles] load error for %d: %s", userId, tostring(status)))
			if errors >= Config.LOAD_RETRIES then
				return nil, "store error", false
			end
		elseif os.clock() >= deadline then
			return nil, "locked", false
		end
		task.wait(Config.LOCK_RETRY_SECONDS)
	end
end

-- Writes the entry. Returns "ok", "error" or "lost" (another server owns the lock now).
local function commit(userId: number, entry: Entry, release: boolean): string
	while entry.saving do
		task.wait()
	end
	entry.saving = true
	local now = os.time()
	entry.data.playtime += now - entry.lastTick
	entry.lastTick = now
	local result = "error"
	for _ = 1, Config.SAVE_RETRIES do
		local lost = false
		local ok, err = pcall(function()
			store:update(key(userId), function(rec: any)
				rec = if type(rec) == "table" then rec else {}
				if type(rec.lock) == "table" and rec.lock.id ~= entry.token then
					lost = true
					return nil
				end
				lost = false
				rec.data = entry.data
				rec.savedAt = os.time()
				rec.lock = if release then nil else { id = entry.token, t = os.time() }
				return rec
			end)
		end)
		if ok then
			result = if lost then "lost" else "ok"
			break
		end
		warn(string.format("[Profiles] save error for %d: %s", userId, tostring(err)))
		task.wait(Config.SAVE_RETRY_SECONDS)
	end
	entry.saving = false
	if result == "lost" then
		warn(string.format("[Profiles] session for %d was taken by another server; not saved", userId))
	end
	return result
end

function Profiles.get(player: Player): Profile?
	local e = active[player.UserId]
	return if e then e.data else nil
end

-- Saved playtime plus this session's unsaved seconds.
function Profiles.playtime(player: Player): number
	local e = active[player.UserId]
	return if e then e.data.playtime + (os.time() - e.lastTick) else 0
end

-- True when this session created the profile (first join).
function Profiles.isNew(player: Player): boolean
	local e = active[player.UserId]
	return e ~= nil and e.isNew
end

function Profiles.pushWallet(player: Player)
	local p = Profiles.get(player)
	if p then
		Net.push(player, "Profile", "Wallet", { pence = p.pence, bank = p.bank })
	end
end

-- Integer wallet change; refuses to go below 0 or above PENCE_MAX.
function Profiles.addPence(player: Player, delta: number): boolean
	local p = Profiles.get(player)
	if not p or type(delta) ~= "number" or delta % 1 ~= 0 then
		return false
	end
	local new = p.pence + delta
	if new < 0 or new > Config.PENCE_MAX then
		return false
	end
	p.pence = new
	Profiles.pushWallet(player)
	return true
end

function Profiles.onPlayerAdded(player: Player): Profile?
	local userId = player.UserId
	local existing = active[userId]
	if existing then
		return existing.data
	end
	if loading[userId] then
		return nil
	end
	loading[userId] = true
	local data, why, isNew = Profiles.load(userId)
	loading[userId] = nil
	if not data then
		if player.Parent == Players then
			player:Kick(if why == "locked"
				then "Your profile is still open on another server. Please rejoin in a minute."
				else "Your profile could not be loaded. Please rejoin.")
		end
		return nil
	end
	local entry: Entry = { data = data, token = Profiles.TOKEN, saving = false, lastTick = os.time(), isNew = isNew }
	active[userId] = entry
	if player.Parent ~= Players then
		Profiles.release(userId)
		return nil
	end
	player:SetAttribute("ProfileLoaded", true)
	Profiles.pushWallet(player)
	loadedEvent:Fire(player, data)
	return data
end

function Profiles.release(userId: number): boolean
	local entry = active[userId]
	if not entry then
		return false
	end
	active[userId] = nil
	pending += 1
	local result = commit(userId, entry, true)
	pending -= 1
	return result == "ok"
end

function Profiles.onPlayerRemoving(player: Player)
	Profiles.release(player.UserId)
end

function Profiles.closeAll()
	for userId in active do
		task.spawn(Profiles.release, userId)
	end
	local deadline = os.clock() + Config.CLOSE_SAVE_TIMEOUT
	while pending > 0 and os.clock() < deadline do
		task.wait()
	end
end

-- Studio test hook: the leave + join path on the same Player (save, unlock, load again).
function Profiles.debugRejoin(player: Player): boolean
	player:SetAttribute("ProfileLoaded", nil)
	if not Profiles.release(player.UserId) then
		return false
	end
	return Profiles.onPlayerAdded(player) ~= nil
end

function Profiles.init()
	Net.domain("Profile")
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_SECONDS)
			for userId, entry in active do
				task.spawn(function()
					if commit(userId, entry, false) == "lost" and active[userId] == entry then
						active[userId] = nil
						local p = Players:GetPlayerByUserId(userId)
						if p then
							p:Kick("Your profile was opened on another server.")
						end
					end
				end)
			end
		end
	end)
end

return Profiles
