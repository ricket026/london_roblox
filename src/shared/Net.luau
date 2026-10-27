--!strict
-- Shared.Net: one RemoteEvent + one RemoteFunction per domain in ReplicatedStorage.Remotes
-- (TECH.md §7). Client messages are { t = "Action", ...fields }. The server checks, in order:
-- shape, known action, channel (event vs call), rate limit, schema (unknown fields rejected),
-- Roles.can, then runs the handler in pcall. Calls return { ok, data?, err? }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)
local Roles = require(script.Parent.Roles)
local Text = require(script.Parent.Text)

export type Validator = (any) -> (boolean, any) -- ok, cleaned value
export type Spec = {
	schema: { [string]: Validator }?,
	can: string?, -- Roles action required
	target: string?, -- schema field passed to Roles.can as the target
	rate: { count: number, per: number }?,
	call: boolean?, -- true = RemoteFunction
}
type Handler = { spec: Spec, fn: (Player, any) -> (any, string?) }

local IS_SERVER = RunService:IsServer()
local Net = {}

-- Validators ------------------------------------------------------------------
local V = {}
Net.V = V

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function V.int(min: number, max: number): Validator
	return function(x)
		if not finite(x) or x % 1 ~= 0 or x < min or x > max then
			return false, nil
		end
		return true, x
	end
end

function V.num(min: number, max: number): Validator
	return function(x)
		if not finite(x) or x < min or x > max then
			return false, nil
		end
		return true, x
	end
end

function V.bool(): Validator
	return function(x)
		return type(x) == "boolean", x
	end
end

-- Sanitised string (see Text.sanitize).
function V.str(maxLen: number, allowEmpty: boolean?): Validator
	return function(x)
		local s = Text.sanitize(x, maxLen)
		if s == nil or (s == "" and not allowEmpty) then
			return false, nil
		end
		return true, s
	end
end

function V.enum(values: { string }): Validator
	local set: { [string]: boolean } = {}
	for _, v in values do
		set[v] = true
	end
	return function(x)
		return type(x) == "string" and set[x] == true, x
	end
end

-- Any plausible userId; negative ids are Studio test players and only pass in Studio.
function V.userId(): Validator
	return function(x)
		if not finite(x) or x % 1 ~= 0 or x == 0 or math.abs(x) > 2 ^ 53 then
			return false, nil
		end
		if x < 0 and not RunService:IsStudio() then
			return false, nil
		end
		return true, x
	end
end

function V.player(): Validator
	return function(x)
		if typeof(x) ~= "Instance" or not x:IsA("Player") or x.Parent ~= Players then
			return false, nil
		end
		return true, x
	end
end

function V.optional(inner: Validator): Validator
	return function(x)
		if x == nil then
			return true, nil
		end
		return inner(x)
	end
end

-- Remotes folder ----------------------------------------------------------------
local remoteFolder: Folder? = nil
local function folder(): Folder
	if remoteFolder then
		return remoteFolder
	end
	local f: Folder
	if IS_SERVER then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing and existing:IsA("Folder") then
			f = existing
		else
			f = Instance.new("Folder")
			f.Name = "Remotes"
			f.Parent = ReplicatedStorage
		end
	else
		f = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	remoteFolder = f
	return f
end

local function message(action: string, payload: { [string]: any }?): { [string]: any }
	local msg = if payload then table.clone(payload) else {}
	msg.t = action
	return msg
end

-- Server ----------------------------------------------------------------------
local handlers: { [string]: { [string]: Handler } } = {}
local buckets: { [Player]: { [string]: { n: number, t: number } } } = {}
local rejects: { [Player]: number } = {}

local function reject(player: Player, where: string, why: string)
	local n = (rejects[player] or 0) + 1
	rejects[player] = n
	if n == 1 or n % Config.NET_REJECT_WARN_EVERY == 0 then
		warn(string.format("[Net] rejected %s from %s: %s (%d total)", where, player.Name, why, n))
	end
	return { ok = false, err = why }
end

local function allow(player: Player, key: string, rate: { count: number, per: number }): boolean
	local now = os.clock()
	local pb = buckets[player]
	if not pb then
		pb = {}
		buckets[player] = pb
	end
	local b = pb[key]
	if not b or now - b.t >= rate.per then
		b = { n = 0, t = now }
		pb[key] = b
	end
	b.n += 1
	return b.n <= rate.count
end

local function dispatch(player: Player, domain: string, msg: any, isCall: boolean): any
	if type(msg) ~= "table" or type(msg.t) ~= "string" then
		return reject(player, domain, "bad message")
	end
	local where = domain .. "." .. string.sub(msg.t, 1, 40)
	local h = handlers[domain] and handlers[domain][msg.t]
	if not h then
		return reject(player, where, "unknown action")
	end
	local spec = h.spec
	if (spec.call == true) ~= isCall then
		return reject(player, where, "wrong channel")
	end
	if not allow(player, where, spec.rate or Config.NET_RATE_DEFAULT) then
		return reject(player, where, "rate limit")
	end
	local schema = spec.schema or {}
	for k in msg do
		if k ~= "t" and (type(k) ~= "string" or schema[k] == nil) then
			return reject(player, where, "unknown field")
		end
	end
	local args: { [string]: any } = {}
	for k, check in schema do
		local ok, v = check(msg[k])
		if not ok then
			return reject(player, where, "bad field " .. k)
		end
		args[k] = v
	end
	if spec.can and not Roles.can(player, spec.can, if spec.target then args[spec.target] else nil) then
		return reject(player, where, "not permitted")
	end
	local ok, data, err = pcall(h.fn, player, args)
	if not ok then
		warn(string.format("[Net] %s handler error: %s", where, tostring(data)))
		return { ok = false, err = "server error" }
	end
	if err ~= nil then
		return { ok = false, err = err }
	end
	return { ok = true, data = data }
end

local function ensureDomain(name: string)
	if handlers[name] then
		return
	end
	handlers[name] = {}
	local f = folder()
	local ev = Instance.new("RemoteEvent")
	ev.Name = name .. "Event"
	ev.OnServerEvent:Connect(function(player, msg)
		dispatch(player, name, msg, false)
	end)
	ev.Parent = f
	local fn = Instance.new("RemoteFunction")
	fn.Name = name .. "Fn"
	fn.OnServerInvoke = function(player, msg)
		return dispatch(player, name, msg, true)
	end
	fn.Parent = f
end

function Net.domain(name: string)
	assert(IS_SERVER, "Net.domain is server-only")
	ensureDomain(name)
end

-- fn(player, args) returns (data) or (nil, errString).
function Net.handle(domain: string, action: string, spec: Spec, fn: (Player, any) -> (any, string?))
	assert(IS_SERVER, "Net.handle is server-only")
	ensureDomain(domain)
	handlers[domain][action] = { spec = spec, fn = fn }
end

function Net.push(player: Player, domain: string, action: string, payload: { [string]: any }?)
	ensureDomain(domain)
	local ev = folder():FindFirstChild(domain .. "Event") :: RemoteEvent
	ev:FireClient(player, message(action, payload))
end

function Net.pushAll(domain: string, action: string, payload: { [string]: any }?)
	ensureDomain(domain)
	local ev = folder():FindFirstChild(domain .. "Event") :: RemoteEvent
	ev:FireAllClients(message(action, payload))
end

if IS_SERVER then
	Net._dispatch = dispatch -- Studio test hook (LondonServer.Debug)
	Players.PlayerRemoving:Connect(function(p)
		buckets[p] = nil
		rejects[p] = nil
	end)
end

-- Client ----------------------------------------------------------------------
local listeners: { [string]: { [string]: (any) -> () } } = {}

local function remote(domain: string, kind: string): Instance
	return folder():WaitForChild(domain .. kind)
end

function Net.send(domain: string, action: string, payload: { [string]: any }?)
	local ev = remote(domain, "Event") :: RemoteEvent
	ev:FireServer(message(action, payload))
end

-- Returns ok, data (or ok=false, err).
function Net.request(domain: string, action: string, payload: { [string]: any }?): (boolean, any)
	local fn = remote(domain, "Fn") :: RemoteFunction
	local ok, res = pcall(fn.InvokeServer, fn, message(action, payload))
	if not ok or type(res) ~= "table" then
		return false, "no response"
	end
	if res.ok then
		return true, res.data
	end
	return false, res.err
end

function Net.listen(domain: string, action: string, fn: (any) -> ())
	local domainListeners = listeners[domain]
	if not domainListeners then
		domainListeners = {}
		listeners[domain] = domainListeners
		local ev = remote(domain, "Event") :: RemoteEvent
		ev.OnClientEvent:Connect(function(msg)
			if type(msg) ~= "table" then
				return
			end
			local l = listeners[domain][msg.t]
			if l then
				l(msg)
			end
		end)
	end
	listeners[domain][action] = fn
end

return Net
