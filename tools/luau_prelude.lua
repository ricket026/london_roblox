-- Test prelude: Luau shims and a small Roblox stand-in, so modules from src/ (converted by
-- tools/luau2lua.py) can be required and exercised by tests/*.luau. Loaded by tools/luau_test.py.
-- Lenient on purpose: unset properties read as nil; unknown *methods* error (catches typos).
-- Time is virtual: task.wait / task.delay / os.clock / os.time follow __now, moved by __advance().

---------------------------------------------------------------------------------------------
-- Luau library shims
---------------------------------------------------------------------------------------------
unpack = table.unpack
function table.find(t, v, init)
	for i = init or 1, #t do
		if t[i] == v then
			return i
		end
	end
	return nil
end
function table.clone(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return setmetatable(c, getmetatable(t))
end
function table.create(n, v)
	local t = {}
	for i = 1, n do
		t[i] = v
	end
	return t
end
function table.freeze(t)
	return t
end
function table.isfrozen()
	return false
end
function table.clear(t)
	for k in pairs(t) do
		t[k] = nil
	end
end
function math.clamp(x, lo, hi)
	if lo > hi then
		error("math.clamp: max must be >= min")
	end
	return math.max(lo, math.min(hi, x))
end
function math.round(x)
	return x >= 0 and math.floor(x + 0.5) or -math.floor(-x + 0.5)
end
function math.sign(x)
	return x > 0 and 1 or (x < 0 and -1 or 0)
end
function string.split(s, sep)
	sep = sep or ","
	local out, start = {}, 1
	while true do
		local i, j = string.find(s, sep, start, true)
		if not i then
			table.insert(out, string.sub(s, start))
			return out
		end
		table.insert(out, string.sub(s, start, i - 1))
		start = j + 1
	end
end
-- Luau generalized iteration: `for k, v in t do`
function __iter(a, ...)
	if type(a) == "table" and not (getmetatable(a) and getmetatable(a).__call) then
		return next, a, nil
	end
	return a, ...
end
-- Lua prints integral floats as "3.0"; Luau prints "3"
local rawtostring = tostring
function tostring(v)
	if math.type(v) == "float" and v == math.floor(v) and v > -1e15 and v < 1e15 then
		return string.format("%d", v)
	end
	return rawtostring(v)
end
local rawformat = string.format
function string.format(fmt, ...)
	local args = table.pack(...)
	for i = 1, args.n do
		local a = args[i]
		if math.type(a) == "float" and a == math.floor(a) then
			args[i] = math.tointeger(a) or a
		end
	end
	return rawformat(fmt, table.unpack(args, 1, args.n))
end

__log = {} -- every print/warn, for tests to inspect
function print(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	table.insert(__log, { kind = "print", text = table.concat(parts, " ") })
end
function warn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	table.insert(__log, { kind = "warn", text = table.concat(parts, " ") })
end
function __warnings()
	local out = {}
	for _, e in ipairs(__log) do
		if e.kind == "warn" then
			table.insert(out, e.text)
		end
	end
	return out
end

---------------------------------------------------------------------------------------------
-- Scheduler (virtual time)
---------------------------------------------------------------------------------------------
__now = 0
__epoch = 1800000000 -- os.time() at the start of a test (Jan 2027)
local queue = {} -- { at, seq, co | fn, args }
local seq = 0
local function schedule(at, co, fn, args)
	seq = seq + 1
	table.insert(queue, { at = at, seq = seq, co = co, fn = fn, args = args })
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error(debug.traceback(co, tostring(err)), 0)
	end
end
task = {}
function task.spawn(f, ...)
	if type(f) == "thread" then
		resume(f, ...)
		return f
	end
	local co = coroutine.create(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	schedule(__now, nil, f, table.pack(...))
end
function task.delay(t, f, ...)
	schedule(__now + (t or 0), nil, f, table.pack(...))
end
function task.wait(t)
	local co, main = coroutine.running()
	if main or not co then
		error("task.wait outside a coroutine (tests run inside one; use __advance)")
	end
	local start = __now
	schedule(__now + math.max(t or 0, 1 / 60), co)
	coroutine.yield()
	return __now - start
end
function task.cancel() end
function wait(t)
	return task.wait(t)
end
-- Run everything due up to now + dt, in time order.
function __advance(dt)
	local target = __now + (dt or 0)
	while true do
		table.sort(queue, function(a, b)
			if a.at ~= b.at then
				return a.at < b.at
			end
			return a.seq < b.seq
		end)
		local item = queue[1]
		if not item or item.at > target then
			break
		end
		table.remove(queue, 1)
		__now = math.max(__now, item.at)
		if item.co then
			if coroutine.status(item.co) == "suspended" then
				resume(item.co)
			end
		else
			task.spawn(item.fn, table.unpack(item.args, 1, item.args.n))
		end
	end
	__now = math.max(__now, target) -- a nested __advance (from inside a test) may have gone further
end
local rawclock = os.clock
os.clock = function()
	return __now
end
local rawtime = os.time
os.time = function(t)
	if t then
		return rawtime(t)
	end
	return math.floor(__epoch + __now)
end
function tick()
	return __epoch + __now
end

---------------------------------------------------------------------------------------------
-- Signals
---------------------------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {}, waiting = {} }, Signal)
end
function Signal:Connect(fn)
	local conn = { Connected = true }
	local entry = { fn = fn, conn = conn }
	table.insert(self.handlers, entry)
	function conn.Disconnect()
		conn.Connected = false
		for i, e in ipairs(self.handlers) do
			if e == entry then
				table.remove(self.handlers, i)
				break
			end
		end
	end
	conn.disconnect = conn.Disconnect
	return setmetatable(conn, { __index = { Disconnect = conn.Disconnect } })
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end
function Signal:Fire(...)
	local list = {}
	for i, e in ipairs(self.handlers) do
		list[i] = e
	end
	for _, e in ipairs(list) do
		if e.conn.Connected then
			task.spawn(e.fn, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, co in ipairs(waiting) do
		resume(co, ...)
	end
end
function Signal:Wait()
	local co = coroutine.running()
	table.insert(self.waiting, co)
	return coroutine.yield()
end
__Signal = Signal

---------------------------------------------------------------------------------------------
-- Data types
---------------------------------------------------------------------------------------------
local function typed(mt, name)
	mt.__type = name
	return mt
end

Vector3 = {}
local V3 = typed({}, "Vector3")
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return v3(0 / 0, 0 / 0, 0 / 0)
		end
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif k == "x" then
		return v.X
	elseif k == "y" then
		return v.Y
	elseif k == "z" then
		return v.Z
	end
	return rawget(Vector3, k)
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(v)
	return string.format("%g, %g, %g", v.X, v.Y, v.Z)
end
function Vector3.new(x, y, z)
	return v3(x, y, z)
end
function Vector3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function Vector3.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function Vector3.Lerp(a, b, t)
	return a + (b - a) * t
end
function Vector3.Max(a, b)
	return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function Vector3.Min(a, b)
	return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function Vector3.Abs(a)
	return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function Vector3.FuzzyEq(a, b, eps)
	eps = eps or 1e-5
	return math.abs(a.X - b.X) <= eps and math.abs(a.Y - b.Y) <= eps and math.abs(a.Z - b.Z) <= eps
end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)

Vector2 = {}
local V2 = typed({}, "Vector2")
V2.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	end
	return rawget(Vector2, k)
end
V2.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, V2)
end
Vector2.zero = Vector2.new(0, 0)

Color3 = {}
local C3 = typed({}, "Color3")
C3.__index = Color3
C3.__eq = function(a, b)
	return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6
end
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	return Color3.new(v, v, v)
end
function Color3:Lerp(o, t)
	return Color3.new(self.R + (o.R - self.R) * t, self.G + (o.G - self.G) * t, self.B + (o.B - self.B) * t)
end
function Color3:ToHex()
	return string.format("%02x%02x%02x", math.floor(self.R * 255 + 0.5), math.floor(self.G * 255 + 0.5), math.floor(self.B * 255 + 0.5))
end

UDim = {}
local UD = typed({}, "UDim")
UD.__index = UDim
function UDim.new(s, o)
	return setmetatable({ Scale = s or 0, Offset = o or 0 }, UD)
end
UDim2 = {}
local UD2 = typed({}, "UDim2")
UD2.__index = UDim2
UD2.__add = function(a, b)
	return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
end
function UDim2.new(xs, xo, ys, yo)
	return setmetatable({ X = UDim.new(xs, xo), Y = UDim.new(ys, yo) }, UD2)
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end

NumberRange = {
	new = function(a, b)
		return { Min = a, Max = b or a }
	end,
}
NumberSequence = {
	new = function(...)
		return { ... }
	end,
}
ColorSequence = NumberSequence
Rect = {
	new = function(...)
		return { ... }
	end,
}
TweenInfo = {
	new = function(t, style, dir, ...)
		return { Time = t or 1, EasingStyle = style, EasingDirection = dir }
	end,
}
PhysicalProperties = {
	new = function(...)
		return { ... }
	end,
}
DateTime = {
	now = function()
		return { UnixTimestamp = os.time(), UnixTimestampMillis = math.floor((__epoch + __now) * 1000) }
	end,
}

-- CFrame: position + 3x3 rotation (rows), Roblox conventions (LookVector = -Z column).
CFrame = {}
local CF = typed({}, "CFrame")
local function cf(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return setmetatable({
		X = x, Y = y, Z = z,
		r = { r00 or 1, r01 or 0, r02 or 0, r10 or 0, r11 or 1, r12 or 0, r20 or 0, r21 or 0, r22 or 1 },
	}, CF)
end
CF.__index = function(c, k)
	local r = rawget(c, "r")
	if k == "Position" or k == "p" then
		return v3(c.X, c.Y, c.Z)
	elseif k == "LookVector" then
		return v3(-r[3], -r[6], -r[9])
	elseif k == "RightVector" then
		return v3(r[1], r[4], r[7])
	elseif k == "UpVector" or k == "YVector" then
		return v3(r[2], r[5], r[8])
	elseif k == "XVector" then
		return v3(r[1], r[4], r[7])
	elseif k == "ZVector" then
		return v3(r[3], r[6], r[9])
	elseif k == "Rotation" then
		return cf(0, 0, 0, table.unpack(r))
	end
	return rawget(CFrame, k)
end
local function rotmul(a, b)
	local o = {}
	for i = 0, 2 do
		for j = 0, 2 do
			o[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return o
end
local function apply(c, v)
	local r = c.r
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z + c.X, r[4] * v.X + r[5] * v.Y + r[6] * v.Z + c.Y, r[7] * v.X + r[8] * v.Y + r[9] * v.Z + c.Z)
end
CF.__mul = function(a, b)
	if getmetatable(b) == V3 then
		return apply(a, b)
	end
	local p = apply(a, v3(b.X, b.Y, b.Z))
	local r = rotmul(a.r, b.r)
	return cf(p.X, p.Y, p.Z, table.unpack(r))
end
CF.__add = function(a, v)
	return cf(a.X + v.X, a.Y + v.Y, a.Z + v.Z, table.unpack(a.r))
end
CF.__sub = function(a, v)
	return cf(a.X - v.X, a.Y - v.Y, a.Z - v.Z, table.unpack(a.r))
end
CF.__eq = function(a, b)
	if a.X ~= b.X or a.Y ~= b.Y or a.Z ~= b.Z then
		return false
	end
	for i = 1, 9 do
		if math.abs(a.r[i] - b.r[i]) > 1e-9 then
			return false
		end
	end
	return true
end
CF.__tostring = function(c)
	return string.format("CFrame(%g, %g, %g)", c.X, c.Y, c.Z)
end
function CFrame.new(x, y, z, ...)
	if getmetatable(x) == V3 then
		if getmetatable(y) == V3 then -- CFrame.new(pos, lookAt)
			return CFrame.lookAt(x, y)
		end
		return cf(x.X, x.Y, x.Z)
	end
	if select("#", ...) == 9 then
		return cf(x, y, z, ...)
	end
	return cf(x or 0, y or 0, z or 0)
end
local function axis(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local X = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Y = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Z = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return X, Y, Z
end
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or Vector3.Cross(vx, vy)
	return cf(pos.X, pos.Y, pos.Z, vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z)
end
function CFrame.Angles(rx, ry, rz) -- X, then Y, then Z (R = X * Y * Z)
	local X, Y, Z = axis(rx or 0, ry or 0, rz or 0)
	return cf(0, 0, 0, table.unpack(rotmul(rotmul(X, Y), Z)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(rx, ry, rz)
	local X, Y, Z = axis(rx or 0, ry or 0, rz or 0)
	return cf(0, 0, 0, table.unpack(rotmul(rotmul(Y, X), Z)))
end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.fromAxisAngle(ax, a)
	local u = ax.Unit
	local c, s, t = math.cos(a), math.sin(a), 1 - math.cos(a)
	return cf(0, 0, 0,
		t * u.X * u.X + c, t * u.X * u.Y - s * u.Z, t * u.X * u.Z + s * u.Y,
		t * u.X * u.Y + s * u.Z, t * u.Y * u.Y + c, t * u.Y * u.Z - s * u.X,
		t * u.X * u.Z - s * u.Y, t * u.Y * u.Z + s * u.X, t * u.Z * u.Z + c)
end
function CFrame.lookAt(at, target, up)
	up = up or v3(0, 1, 0)
	local look = (target - at)
	if look.Magnitude < 1e-9 then
		return cf(at.X, at.Y, at.Z)
	end
	look = look.Unit
	local right = Vector3.Cross(look, up)
	if right.Magnitude < 1e-9 then
		right = v3(1, 0, 0)
	else
		right = right.Unit
	end
	local upv = Vector3.Cross(right, look)
	return cf(at.X, at.Y, at.Z, right.X, upv.X, -look.X, right.Y, upv.Y, -look.Y, right.Z, upv.Z, -look.Z)
end
function CFrame:Inverse()
	local r = self.r
	local t = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
	local p = v3(-(t[1] * self.X + t[2] * self.Y + t[3] * self.Z), -(t[4] * self.X + t[5] * self.Y + t[6] * self.Z), -(t[7] * self.X + t[8] * self.Y + t[9] * self.Z))
	return cf(p.X, p.Y, p.Z, table.unpack(t))
end
function CFrame:ToObjectSpace(o)
	return self:Inverse() * o
end
function CFrame:ToWorldSpace(o)
	return self * o
end
function CFrame:PointToObjectSpace(v)
	return self:Inverse() * v
end
function CFrame:PointToWorldSpace(v)
	return self * v
end
function CFrame:VectorToWorldSpace(v)
	return self.Rotation * v
end
function CFrame:VectorToObjectSpace(v)
	return self.Rotation:Inverse() * v
end
function CFrame:GetComponents()
	return self.X, self.Y, self.Z, table.unpack(self.r)
end
function CFrame:Lerp(o, t)
	return cf(self.X + (o.X - self.X) * t, self.Y + (o.Y - self.Y) * t, self.Z + (o.Z - self.Z) * t, table.unpack(t < 0.5 and self.r or o.r))
end
function CFrame:ToEulerAnglesYXZ()
	local r = self.r
	local x = math.asin(-math.max(-1, math.min(1, r[6])))
	local y = math.atan(r[3], r[9])
	local z = math.atan(r[4], r[5])
	return x, y, z
end
CFrame.identity = cf(0, 0, 0)

-- Seeded random (deterministic per seed)
Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ s = math.floor(seed or 12345) % 2147483647 + 1 }, Random)
end
function Random:_next()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function Random:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:_next()
end
function Random:NextInteger(a, b)
	return a + math.floor(self:_next() * (b - a + 1))
end

-- Enum: Enum.Material.Wood etc. Identity-stable items with Name and EnumType.
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, typeName)
		local t = enumCache[typeName]
		if not t then
			t = setmetatable({}, {
				__index = function(tt, itemName)
					local item = setmetatable({ Name = itemName, EnumType = typeName, Value = 0 }, typed({ __tostring = function()
						return "Enum." .. typeName .. "." .. itemName
					end }, "EnumItem"))
					rawset(tt, itemName, item)
					return item
				end,
			})
			enumCache[typeName] = t
		end
		return t
	end,
})

function typeof(v)
	local mt = getmetatable(v)
	if type(v) == "table" and mt then
		if mt.__type then
			return mt.__type
		end
		if mt.__instance then
			return "Instance"
		end
	end
	return type(v)
end

---------------------------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------------------------
local SUPER = {
	Part = "BasePart", MeshPart = "BasePart", WedgePart = "BasePart", Seat = "BasePart", SpawnLocation = "BasePart",
	TrussPart = "BasePart", UnionOperation = "BasePart", CornerWedgePart = "BasePart", VehicleSeat = "BasePart",
	BasePart = "PVInstance", Model = "PVInstance", Workspace = "Model",
	TextLabel = "GuiObject", TextButton = "GuiButton", ImageButton = "GuiButton", GuiButton = "GuiObject",
	TextBox = "GuiObject", Frame = "GuiObject", ScrollingFrame = "GuiObject", ImageLabel = "GuiObject",
	ViewportFrame = "GuiObject", CanvasGroup = "GuiObject", GuiObject = "GuiBase2d",
	ScreenGui = "LayerCollector", BillboardGui = "LayerCollector", SurfaceGui = "LayerCollector",
	LayerCollector = "GuiBase2d",
	Script = "BaseScript", LocalScript = "BaseScript", BaseScript = "LuaSourceContainer",
	ModuleScript = "LuaSourceContainer",
	StringValue = "ValueBase", NumberValue = "ValueBase", IntValue = "ValueBase", BoolValue = "ValueBase",
	ObjectValue = "ValueBase", CFrameValue = "ValueBase", Vector3Value = "ValueBase",
	UIListLayout = "UIComponent", UIGridLayout = "UIComponent", UIPadding = "UIComponent",
	UISizeConstraint = "UIComponent", UIStroke = "UIComponent", UICorner = "UIComponent",
	PointLight = "Light", SpotLight = "Light", SurfaceLight = "Light",
	Sparkles = "Instance",
}
local EVENTS = {
	ChildAdded = true, ChildRemoved = true, DescendantAdded = true, DescendantRemoving = true,
	AncestryChanged = true, Changed = true, AttributeChanged = true, Destroying = true,
	OnServerEvent = true, OnClientEvent = true, Event = true, Triggered = true, TriggerEnded = true,
	PromptShown = true, PromptHidden = true, Activated = true, MouseButton1Click = true,
	MouseButton1Down = true, MouseEnter = true, MouseLeave = true, FocusLost = true, Focused = true,
	Touched = true, TouchEnded = true, Died = true, CharacterAdded = true, CharacterRemoving = true,
	CharacterAppearanceLoaded = true, PlayerAdded = true, PlayerRemoving = true, Completed = true,
	Heartbeat = true, RenderStepped = true, Stepped = true, PreSimulation = true, PostSimulation = true,
	InputBegan = true, InputEnded = true, InputChanged = true, Chatted = true, MessageReceived = true,
	Running = true, Seated = true, StateChanged = true, HealthChanged = true, MoveToFinished = true,
	PromptButtonHoldBegan = true, PromptButtonHoldEnded = true, Idled = true, TouchTapInWorld = true,
	TouchStarted = true, TouchEnded2 = true, LastInputTypeChanged = true,
}

local Inst = {}
local InstMT = { __instance = true }
local nextId = 0

function __isA(class, want)
	local c = class
	while c do
		if c == want then
			return true
		end
		c = SUPER[c]
	end
	return want == "Instance"
end

local function fireAncestors(obj, eventName, arg)
	local p = rawget(obj, "_props").Parent
	while p do
		local sig = rawget(p, "_signals")[eventName]
		if sig then
			sig:Fire(arg)
		end
		p = rawget(p, "_props").Parent
	end
end

local CLASS_DEFAULTS = {}
local CLASS_METHODS = {}

InstMT.__index = function(obj, k)
	local props = rawget(obj, "_props")
	local v = props[k]
	if v ~= nil then
		return v
	end
	local cls = props.ClassName
	local c = cls
	while c do
		local m = CLASS_METHODS[c]
		if m and m[k] ~= nil then
			return m[k]
		end
		c = SUPER[c]
	end
	if Inst[k] ~= nil then
		return Inst[k]
	end
	if EVENTS[k] then
		local s = rawget(obj, "_signals")[k] or Signal.new()
		rawget(obj, "_signals")[k] = s
		return s
	end
	-- a child by name (Roblox lets obj.ChildName work)
	for _, ch in ipairs(rawget(obj, "_children")) do
		if rawget(ch, "_props").Name == k then
			return ch
		end
	end
	return nil
end

local function setParent(obj, parent)
	local props = rawget(obj, "_props")
	local old = props.Parent
	if old == parent then
		return
	end
	if old then
		local kids = rawget(old, "_children")
		for i, ch in ipairs(kids) do
			if ch == obj then
				table.remove(kids, i)
				break
			end
		end
		local s = rawget(old, "_signals").ChildRemoved
		if s then
			s:Fire(obj)
		end
	end
	props.Parent = parent
	if parent then
		table.insert(rawget(parent, "_children"), obj)
		local s = rawget(parent, "_signals").ChildAdded
		if s then
			s:Fire(obj)
		end
		local function each(o)
			fireAncestors(o, "DescendantAdded", o)
			for _, ch in ipairs(rawget(o, "_children")) do
				each(ch)
			end
		end
		each(obj)
	end
	local s = rawget(obj, "_signals").AncestryChanged
	if s then
		s:Fire(obj, parent)
	end
end

-- CollectionService signals: a tagged instance entering / leaving the DataModel counts as the
-- tag being added / removed (as in Roblox).
local function inGame(o)
	while o do
		if o == game then
			return true
		end
		o = rawget(o, "_props").Parent
	end
	return false
end
function __tagMoved(obj, wasIn)
	local nowIn = inGame(obj)
	if wasIn == nowIn then
		return
	end
	local function each(o)
		local tags = rawget(o, "_tags")
		if tags then
			for _, t in ipairs(tags) do
				__tagSignal(nowIn and "added" or "removed", t, o)
			end
		end
		for _, ch in ipairs(rawget(o, "_children")) do
			each(ch)
		end
	end
	each(obj)
end
local propHooks = {} -- class -> prop -> fn(obj, value) run after a set

InstMT.__newindex = function(obj, k, v)
	local props = rawget(obj, "_props")
	if k == "Parent" then
		if rawget(obj, "_destroyed") then
			error("The Parent property of " .. tostring(props.Name) .. " is locked")
		end
		local wasIn = inGame(obj)
		setParent(obj, v)
		__tagMoved(obj, wasIn)
	else
		if props[k] == v then
			return
		end
		props[k] = v
	end
	local c = props.ClassName
	while c do
		local h = propHooks[c] and propHooks[c][k]
		if h then
			h(obj, v)
			break
		end
		c = SUPER[c]
	end
	local ps = rawget(obj, "_propSignals")[k]
	if ps then
		ps:Fire()
	end
	local ch = rawget(obj, "_signals").Changed
	if ch then
		ch:Fire(k)
	end
end
InstMT.__tostring = function(obj)
	return rawget(obj, "_props").Name
end

function __newInstance(class, name)
	nextId = nextId + 1
	local obj = setmetatable({
		_props = { ClassName = class, Name = name or class },
		_children = {}, _signals = {}, _propSignals = {}, _attrs = {}, _attrSignals = {}, _id = nextId,
	}, InstMT)
	local d = CLASS_DEFAULTS[class]
	if d then
		d(obj)
	end
	return obj
end

function Inst:IsA(want)
	return __isA(self.ClassName, want)
end
function Inst:FindFirstChild(name, recursive)
	for _, ch in ipairs(rawget(self, "_children")) do
		if ch.Name == name then
			return ch
		end
	end
	if recursive then
		for _, ch in ipairs(rawget(self, "_children")) do
			local f = ch:FindFirstChild(name, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function Inst:FindFirstChildOfClass(class)
	for _, ch in ipairs(rawget(self, "_children")) do
		if ch.ClassName == class then
			return ch
		end
	end
	return nil
end
function Inst:FindFirstChildWhichIsA(class, recursive)
	for _, ch in ipairs(rawget(self, "_children")) do
		if ch:IsA(class) then
			return ch
		end
	end
	if recursive then
		for _, ch in ipairs(rawget(self, "_children")) do
			local f = ch:FindFirstChildWhichIsA(class, true)
			if f then
				return f
			end
		end
	end
	return nil
end
function Inst:FindFirstAncestor(name)
	local p = self.Parent
	while p do
		if p.Name == name then
			return p
		end
		p = p.Parent
	end
	return nil
end
function Inst:FindFirstAncestorWhichIsA(class)
	local p = self.Parent
	while p do
		if p:IsA(class) then
			return p
		end
		p = p.Parent
	end
	return nil
end
function Inst:WaitForChild(name, timeout)
	local found = self:FindFirstChild(name)
	if found then
		return found
	end
	local co, main = coroutine.running()
	if main then
		error("WaitForChild('" .. name .. "') on " .. self:GetFullName() .. " would yield in the main thread")
	end
	local deadline = __now + (timeout or 5)
	while __now < deadline do
		task.wait(0.05)
		found = self:FindFirstChild(name)
		if found then
			return found
		end
	end
	if timeout then
		return nil
	end
	error("Infinite yield: WaitForChild('" .. name .. "') on " .. self:GetFullName())
end
function Inst:GetChildren()
	local out = {}
	for i, ch in ipairs(rawget(self, "_children")) do
		out[i] = ch
	end
	return out
end
function Inst:GetDescendants()
	local out = {}
	local function walk(o)
		for _, ch in ipairs(rawget(o, "_children")) do
			table.insert(out, ch)
			walk(ch)
		end
	end
	walk(self)
	return out
end
function Inst:IsDescendantOf(anc)
	local p = self.Parent
	while p do
		if p == anc then
			return true
		end
		p = p.Parent
	end
	return false
end
function Inst:IsAncestorOf(d)
	return d:IsDescendantOf(self)
end
function Inst:GetFullName()
	local parts, o = {}, self
	while o and o.ClassName ~= "DataModel" do
		table.insert(parts, 1, o.Name)
		o = o.Parent
	end
	return table.concat(parts, ".")
end
function Inst:Destroy()
	local s = rawget(self, "_signals").Destroying
	if s then
		s:Fire()
	end
	for _, ch in ipairs(self:GetChildren()) do
		ch:Destroy()
	end
	if self.Parent then
		local wasIn = inGame(self)
		setParent(self, nil)
		__tagMoved(self, wasIn)
	end
	rawset(self, "_destroyed", true)
end
function Inst:ClearAllChildren()
	for _, ch in ipairs(self:GetChildren()) do
		ch:Destroy()
	end
end
function Inst:Clone()
	local c = __newInstance(self.ClassName, self.Name)
	for k, v in pairs(rawget(self, "_props")) do
		if k ~= "Parent" then
			rawget(c, "_props")[k] = v
		end
	end
	for k, v in pairs(rawget(self, "_attrs")) do
		rawget(c, "_attrs")[k] = v
	end
	for _, ch in ipairs(rawget(self, "_children")) do
		ch:Clone().Parent = c
	end
	return c
end
function Inst:SetAttribute(k, v)
	local attrs = rawget(self, "_attrs")
	if attrs[k] == v then
		return
	end
	attrs[k] = v
	local s = rawget(self, "_attrSignals")[k]
	if s then
		s:Fire()
	end
	local a = rawget(self, "_signals").AttributeChanged
	if a then
		a:Fire(k)
	end
end
function Inst:GetAttribute(k)
	return rawget(self, "_attrs")[k]
end
function Inst:GetAttributes()
	return table.clone(rawget(self, "_attrs"))
end
function Inst:GetAttributeChangedSignal(k)
	local s = rawget(self, "_attrSignals")[k] or Signal.new()
	rawget(self, "_attrSignals")[k] = s
	return s
end
function Inst:GetPropertyChangedSignal(k)
	local s = rawget(self, "_propSignals")[k] or Signal.new()
	rawget(self, "_propSignals")[k] = s
	return s
end
function Inst:GetPivot()
	return self.CFrame or (self.PrimaryPart and self.PrimaryPart.CFrame) or CFrame.new()
end
function Inst:PivotTo(c)
	if self:IsA("BasePart") then
		self.CFrame = c
	elseif self.PrimaryPart then
		local offset = self.PrimaryPart.CFrame:Inverse()
		for _, d in ipairs(self:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CFrame = c * (offset * d.CFrame)
			end
		end
	end
end
function Inst:GetTags()
	return table.clone(rawget(self, "_tags") or {})
end
function Inst:AddTag(tag)
	game:GetService("CollectionService"):AddTag(self, tag)
end
function Inst:HasTag(tag)
	return game:GetService("CollectionService"):HasTag(self, tag)
end
function Inst:RemoveTag(tag)
	game:GetService("CollectionService"):RemoveTag(self, tag)
end

-- class defaults and methods -------------------------------------------------------------------
local function defaults(classes, fn)
	for _, c in ipairs(classes) do
		CLASS_DEFAULTS[c] = fn
	end
end
local function methods(class, t)
	CLASS_METHODS[class] = CLASS_METHODS[class] or {}
	for k, v in pairs(t) do
		CLASS_METHODS[class][k] = v
	end
end

defaults({ "Part", "MeshPart", "WedgePart", "Seat", "SpawnLocation", "TrussPart", "VehicleSeat" }, function(o)
	local p = rawget(o, "_props")
	p.Size = v3(4, 1, 2)
	p.CFrame = cf(0, 0, 0)
	p.Position = v3(0, 0, 0)
	p.Anchored = false
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = true
	p.Transparency = 0
	p.Color = Color3.fromRGB(163, 162, 165)
end)
propHooks.BasePart = {
	CFrame = function(o, v)
		rawget(o, "_props").Position = v3(v.X, v.Y, v.Z)
	end,
	Position = function(o, v)
		local c = rawget(o, "_props").CFrame or cf(0, 0, 0)
		rawget(o, "_props").CFrame = cf(v.X, v.Y, v.Z, table.unpack(c.r))
	end,
}
methods("BasePart", {
	GetMass = function(self)
		return self.Size.X * self.Size.Y * self.Size.Z * 0.7
	end,
	SetNetworkOwner = function() end,
	GetNetworkOwner = function()
		return nil
	end,
	ApplyImpulse = function() end,
	GetTouchingParts = function()
		return {}
	end,
})
defaults({ "Model" }, function(o)
	rawget(o, "_props").WorldPivot = cf(0, 0, 0)
end)
methods("Model", {
	GetBoundingBox = function(self)
		return self:GetPivot(), v3(1, 1, 1)
	end,
	GetExtentsSize = function()
		return v3(1, 1, 1)
	end,
	ScaleTo = function() end,
})

-- Remotes copy what they carry (Roblox serialises it): plain tables arrive as new tables;
-- instances and engine values (Vector3, CFrame, ...) arrive as themselves.
local function wire(v, seen)
	if type(v) ~= "table" or getmetatable(v) ~= nil then
		return v
	end
	seen = seen or {}
	if seen[v] then
		return seen[v]
	end
	local out = {}
	seen[v] = out
	for k, x in pairs(v) do
		out[wire(k, seen)] = wire(x, seen)
	end
	return out
end
local function wireAll(packed)
	local out = { n = packed.n }
	for i = 1, packed.n do
		out[i] = wire(packed[i])
	end
	return out
end
defaults({ "RemoteEvent", "UnreliableRemoteEvent" }, function() end)
methods("RemoteEvent", {
	FireServer = function(self, ...)
		local args = wireAll(table.pack(...))
		self.OnServerEvent:Fire(__localPlayer, table.unpack(args, 1, args.n))
	end,
	FireClient = function(self, player, ...)
		__clientInbox(player, self, wireAll(table.pack(...)))
	end,
	FireAllClients = function(self, ...)
		for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
			__clientInbox(p, self, wireAll(table.pack(...)))
		end
	end,
})
methods("RemoteFunction", {
	InvokeServer = function(self, ...)
		local f = self.OnServerInvoke
		if not f then
			error("no OnServerInvoke on " .. self:GetFullName())
		end
		local args = wireAll(table.pack(...))
		local res = wireAll(table.pack(f(__localPlayer, table.unpack(args, 1, args.n))))
		return table.unpack(res, 1, res.n)
	end,
	InvokeClient = function()
		error("InvokeClient is not used in this code base")
	end,
})
methods("BindableEvent", {
	Fire = function(self, ...)
		self.Event:Fire(...)
	end,
})
methods("BindableFunction", {
	Invoke = function(self, ...)
		return self.OnInvoke(...)
	end,
})

-- Remote messages to clients are recorded per player; tests read them with __received(player).
__inbox = {}
function __clientInbox(player, remote, args)
	local box = __inbox[player] or {}
	__inbox[player] = box
	table.insert(box, { remote = remote.Name, args = args })
	if player == __localPlayer and __clientListening then
		remote.OnClientEvent:Fire(table.unpack(args, 1, args.n))
	end
end
function __received(player, remoteName, action)
	local out = {}
	for _, m in ipairs(__inbox[player] or {}) do
		local msg = m.args[1]
		if (not remoteName or m.remote == remoteName) and (not action or (type(msg) == "table" and msg.t == action)) then
			table.insert(out, msg)
		end
	end
	return out
end
function __clearInbox(player)
	__inbox[player] = {}
end

methods("Humanoid", {
	TakeDamage = function(self, n)
		self.Health = math.max(0, (self.Health or 100) - n)
		if self.Health <= 0 then
			self.Died:Fire()
		end
	end,
	ApplyDescription = function(self, d)
		self.__description = d
	end,
	GetAppliedDescription = function(self)
		return self.__description or __newInstance("HumanoidDescription")
	end,
	MoveTo = function() end,
	ChangeState = function() end,
	GetState = function()
		return Enum.HumanoidStateType.Running
	end,
	LoadAnimation = function()
		return { Play = function() end, Stop = function() end }
	end,
})
defaults({ "Humanoid" }, function(o)
	local p = rawget(o, "_props")
	p.Health = 100
	p.MaxHealth = 100
	p.WalkSpeed = 16
	p.JumpPower = 50
end)
methods("HumanoidDescription", {
	GetAccessories = function(self)
		return table.clone(self.__accessories or {})
	end,
	SetAccessories = function(self, list)
		self.__accessories = list
	end,
})

methods("TextBox", {
	CaptureFocus = function() end,
	ReleaseFocus = function() end,
	IsFocused = function()
		return false
	end,
})

Instance = {}
function Instance.new(class, parent)
	local o = __newInstance(class)
	if parent then
		o.Parent = parent
	end
	return o
end

---------------------------------------------------------------------------------------------
-- Services
---------------------------------------------------------------------------------------------
game = __newInstance("DataModel", "Game")
rawget(game, "_props").JobId = ""
rawget(game, "_props").PlaceId = 0
local services = {}
local function service(name, class)
	local s = __newInstance(class or name, name)
	rawget(s, "_props").Parent = game
	table.insert(rawget(game, "_children"), s)
	services[name] = s
	return s
end
methods("DataModel", {
	GetService = function(self, name)
		local s = services[name]
		if not s then
			s = service(name)
		end
		return s
	end,
	BindToClose = function(self, fn)
		__closeHandlers = __closeHandlers or {}
		table.insert(__closeHandlers, fn)
	end,
	IsLoaded = function()
		return true
	end,
})
game.FindService = game.GetService

workspace = service("Workspace")
game.Workspace = workspace
rawget(workspace, "_props").CurrentCamera = __newInstance("Camera", "Camera")
rawget(workspace.CurrentCamera, "_props").CFrame = CFrame.new(0, 20, 20)
rawget(workspace.CurrentCamera, "_props").ViewportSize = Vector2.new(800, 400)
rawget(workspace.CurrentCamera, "_props").FieldOfView = 70
Ray = {}
function Ray.new(origin, direction)
	return { Origin = origin, Direction = direction, Unit = { Origin = origin, Direction = direction.Unit } }
end
-- A ray through a viewport point, with a simple pinhole camera (tests aim with lot coordinates).
methods("Camera", {
	ViewportPointToRay = function(self, x, y)
		local cf = self.CFrame
		local size = self.ViewportSize
		local t = math.tan(math.rad(self.FieldOfView / 2))
		local dx = (x / size.X * 2 - 1) * t * size.X / size.Y
		local dy = (1 - y / size.Y * 2) * t
		local dir = (cf.LookVector + cf.RightVector * dx + cf.UpVector * dy).Unit
		return Ray.new(cf.Position, dir)
	end,
	ScreenPointToRay = function(self, x, y)
		return self:ViewportPointToRay(x, y)
	end,
})
methods("Workspace", {
	GetServerTimeNow = function()
		return __epoch + __now
	end,
	Raycast = function(self, origin, dir, params)
		if __raycast then
			return __raycast(origin, dir, params)
		end
		return nil
	end,
	GetPartBoundsInBox = function()
		return {}
	end,
	GetPartsInPart = function()
		return {}
	end,
})
RaycastParams = {
	new = function()
		return { FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false }
	end,
}
OverlapParams = RaycastParams

local Players = service("Players")
rawget(Players, "_props").CharacterAutoLoads = true
rawget(Players, "_props").RespawnTime = 5
methods("Players", {
	GetPlayers = function(self)
		local out = {}
		for _, ch in ipairs(rawget(self, "_children")) do
			if ch.ClassName == "Player" then
				table.insert(out, ch)
			end
		end
		return out
	end,
	GetPlayerByUserId = function(self, id)
		for _, p in ipairs(self:GetPlayers()) do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end,
	GetPlayerFromCharacter = function(self, model)
		for _, p in ipairs(self:GetPlayers()) do
			if p.Character == model then
				return p
			end
		end
		return nil
	end,
	GetHumanoidDescriptionFromUserId = function(self, id)
		local d = __newInstance("HumanoidDescription")
		d.__fromUser = id
		return d
	end,
	GetNameFromUserIdAsync = function(self, id)
		return "User" .. tostring(id)
	end,
	CreateHumanoidModelFromDescription = function()
		return __newCharacter()
	end,
})
function __newCharacter(name)
	local m = __newInstance("Model", name or "Character")
	local hum = __newInstance("Humanoid", "Humanoid")
	hum.Parent = m
	local root = __newInstance("Part", "HumanoidRootPart")
	root.Size = v3(2, 2, 1)
	root.CFrame = cf(0, 3, 0)
	root.Parent = m
	local head = __newInstance("Part", "Head")
	head.Size = v3(2, 1, 1)
	head.CFrame = cf(0, 4.5, 0)
	head.Parent = m
	for _, hand in ipairs({ "RightHand", "LeftHand" }) do
		local h = __newInstance("Part", hand)
		h.Size = v3(0.6, 0.6, 0.6)
		h.CFrame = cf(hand == "RightHand" and 1.5 or -1.5, 2, 0)
		h.Parent = m
	end
	m.PrimaryPart = root
	return m
end
methods("Player", {
	Kick = function(self, msg)
		self.__kicked = msg or ""
		__removePlayer(self)
	end,
	LoadCharacter = function(self)
		local old = self.Character
		if old then
			self.CharacterRemoving:Fire(old)
			old:Destroy()
		end
		local m = __newCharacter(self.Name)
		local spawn = __spawnCFrame or cf(0, 3, 0)
		m.HumanoidRootPart.CFrame = spawn
		m.Parent = workspace
		self.Character = m
		self.CharacterAdded:Fire(m)
	end,
	LoadCharacterWithHumanoidDescription = function(self, desc)
		self:LoadCharacter()
		self.Character.Humanoid.__description = desc
	end,
	GetRankInGroup = function()
		return 0
	end,
	IsInGroup = function()
		return false
	end,
	GetJoinData = function()
		return {}
	end,
})
-- Test helpers: add / remove a player as the server would see it.
function __addPlayer(userId, name)
	local p = __newInstance("Player", name or ("Player" .. tostring(userId)))
	rawget(p, "_props").UserId = userId
	rawget(p, "_props").DisplayName = name or ("Player" .. tostring(userId))
	local gui = __newInstance("PlayerGui", "PlayerGui")
	rawget(gui, "_props").Parent = p
	table.insert(rawget(p, "_children"), gui)
	local scripts = __newInstance("PlayerScripts", "PlayerScripts")
	scripts.Parent = p
	p.Parent = Players
	Players.PlayerAdded:Fire(p)
	return p
end
function __removePlayer(p)
	if p.Parent ~= Players then
		return
	end
	Players.PlayerRemoving:Fire(p)
	p.Parent = nil
end

local RunService = service("RunService")
__isServer = true
methods("RunService", {
	IsStudio = function()
		return true
	end,
	IsServer = function()
		return __isServer
	end,
	IsClient = function()
		return not __isServer
	end,
	IsRunning = function()
		return true
	end,
	BindToRenderStep = function() end,
	UnbindFromRenderStep = function() end,
})

local Http = service("HttpService")
local guid = 0
methods("HttpService", {
	GenerateGUID = function(self, braces)
		guid = guid + 1
		return string.format("00000000-0000-0000-0000-%012d", guid)
	end,
	JSONEncode = function(self, v)
		return __json_encode(v)
	end,
	JSONDecode = function(self, s)
		return __json_decode(s)
	end,
})

service("ReplicatedStorage")
service("ReplicatedFirst")
service("ServerScriptService")
service("ServerStorage")
local StarterPlayer = service("StarterPlayer")
local sps = __newInstance("StarterPlayerScripts", "StarterPlayerScripts")
sps.Parent = StarterPlayer
local scs = __newInstance("StarterCharacterScripts", "StarterCharacterScripts")
scs.Parent = StarterPlayer
service("StarterGui")
local Lighting = service("Lighting")
rawget(Lighting, "_props").ClockTime = 12

local TextService = service("TextService")
__censor = {} -- words that the fake filter turns into hashes
methods("TextService", {
	FilterStringAsync = function(self, s, userId, ctx)
		local out = s
		for _, w in ipairs(__censor) do
			out = string.gsub(out, w, string.rep("#", #w))
		end
		return {
			GetNonChatStringForBroadcastAsync = function()
				return out
			end,
			GetNonChatStringForUserAsync = function()
				return out
			end,
			GetChatForUserAsync = function()
				return out
			end,
		}
	end,
	GetTextSize = function(self, text, size)
		return Vector2.new(#text * size * 0.5, size)
	end,
})

local Tween = service("TweenService")
methods("TweenService", {
	Create = function(self, obj, info, goal)
		local t = __newInstance("Tween", "Tween")
		function t.Play()
			for k, v in pairs(goal) do
				obj[k] = v
			end
			task.delay((info and info.Time) or 0, function()
				t.Completed:Fire(Enum.PlaybackState.Completed)
			end)
		end
		function t.Cancel() end
		function t.Pause() end
		return t
	end,
})

local Collection = service("CollectionService")
local tagged = {}
local tagSigs = { added = {}, removed = {} }
function tagSignals(kind, tag)
	tagSigs[kind][tag] = tagSigs[kind][tag] or Signal.new()
	return tagSigs[kind][tag]
end
-- added: only while the instance is in the DataModel (AddTag on a loose instance fires on parenting)
function __tagSignal(kind, tag, obj)
	if kind == "added" and not inGame(obj) then
		return
	end
	local sig = tagSigs[kind][tag]
	if sig then
		sig:Fire(obj)
	end
end
methods("CollectionService", {
	AddTag = function(self, obj, tag)
		tagged[tag] = tagged[tag] or {}
		if not table.find(tagged[tag], obj) then
			table.insert(tagged[tag], obj)
			local tags = rawget(obj, "_tags") or {}
			table.insert(tags, tag)
			rawset(obj, "_tags", tags)
			__tagSignal("added", tag, obj)
		end
	end,
	RemoveTag = function(self, obj, tag)
		local list = tagged[tag] or {}
		local i = table.find(list, obj)
		if i then
			table.remove(list, i)
			local tags = rawget(obj, "_tags") or {}
			local j = table.find(tags, tag)
			if j then
				table.remove(tags, j)
			end
			__tagSignal("removed", tag, obj)
		end
	end,
	HasTag = function(self, obj, tag)
		return table.find(tagged[tag] or {}, obj) ~= nil
	end,
	GetTagged = function(self, tag) -- only instances in the DataModel, as in Roblox
		local out = {}
		for _, o in ipairs(tagged[tag] or {}) do
			if inGame(o) then
				table.insert(out, o)
			end
		end
		return out
	end,
	GetInstanceAddedSignal = function(self, tag)
		return tagSignals("added", tag)
	end,
	GetInstanceRemovedSignal = function(self, tag)
		return tagSignals("removed", tag)
	end,
})

-- DataStores (in memory, JSON round-trip like the real thing)
local stores = {}
__datastores = stores
local DSS = service("DataStoreService")
methods("DataStoreService", {
	GetDataStore = function(self, name)
		stores[name] = stores[name] or {}
		local data = stores[name]
		return {
			GetAsync = function(_, key)
				local s = data[key]
				return s and __json_decode(s) or nil
			end,
			SetAsync = function(_, key, v)
				data[key] = __json_encode(v)
			end,
			UpdateAsync = function(_, key, fn)
				local cur = data[key] and __json_decode(data[key]) or nil
				local new = fn(cur)
				if new ~= nil then
					data[key] = __json_encode(new)
				end
				return new
			end,
			RemoveAsync = function(_, key)
				data[key] = nil
			end,
		}
	end,
	GetOrderedDataStore = function(self, name)
		return self:GetDataStore("ordered:" .. name)
	end,
})

local Messaging = service("MessagingService")
methods("MessagingService", {
	PublishAsync = function(self, topic, msg)
		local subs = rawget(self, "_subs") or {}
		for _, fn in ipairs(subs[topic] or {}) do
			task.spawn(fn, { Data = msg, Sent = os.time() })
		end
	end,
	SubscribeAsync = function(self, topic, fn)
		local subs = rawget(self, "_subs") or {}
		rawset(self, "_subs", subs)
		subs[topic] = subs[topic] or {}
		table.insert(subs[topic], fn)
		return { Disconnect = function() end }
	end,
})
local Analytics = service("AnalyticsService")
__analytics = {}
methods("AnalyticsService", {
	LogOnboardingFunnelStepEvent = function(self, p, i, name)
		table.insert(__analytics, { "funnel", i, name })
	end,
	LogCustomEvent = function(self, p, name, v)
		table.insert(__analytics, { "custom", name, v })
	end,
	LogEconomyEvent = function(self, ...)
		table.insert(__analytics, { "economy", ... })
	end,
	LogProgressionEvent = function() end,
})
local Marketplace = service("MarketplaceService")
methods("MarketplaceService", {
	UserOwnsGamePassAsync = function()
		return false
	end,
	PromptProductPurchase = function() end,
	PromptGamePassPurchase = function() end,
	GetProductInfo = function()
		return { Name = "?", PriceInRobux = 0 }
	end,
})
local TextChat = service("TextChatService")
methods("TextChatService", {
	CanUsersChatAsync = function()
		return true
	end,
	CanUsersDirectChatAsync = function()
		return true
	end,
	DisplayBubble = function() end,
})
methods("TextChannel", {
	DisplaySystemMessage = function() end,
	SendAsync = function() end,
})
local CAS = service("ContextActionService")
methods("ContextActionService", {
	BindAction = function(self, name, fn)
		rawset(self, "_bound", rawget(self, "_bound") or {})
		rawget(self, "_bound")[name] = fn
	end,
	UnbindAction = function(self, name)
		local b = rawget(self, "_bound")
		if b then
			b[name] = nil
		end
	end,
	SetTitle = function() end,
	SetPosition = function() end,
})
local UIS = service("UserInputService")
rawget(UIS, "_props").TouchEnabled = false
rawget(UIS, "_props").GamepadEnabled = false
rawget(UIS, "_props").KeyboardEnabled = true
methods("UserInputService", {
	GetMouseLocation = function()
		return Vector2.new(0, 0)
	end,
	IsKeyDown = function()
		return false
	end,
	GetFocusedTextBox = function()
		return nil
	end,
})
service("SoundService")
service("Debris")
methods("Debris", {
	AddItem = function(self, obj, t)
		task.delay(t or 10, function()
			if obj.Parent then
				obj:Destroy()
			end
		end)
	end,
})
service("PhysicsService")
methods("PhysicsService", {
	RegisterCollisionGroup = function() end,
	CollisionGroupSetCollidable = function() end,
	IsCollisionGroupRegistered = function()
		return true
	end,
})
service("TeleportService")
service("GroupService")
service("BadgeService")
service("PolicyService")
methods("PolicyService", {
	GetPolicyInfoForPlayerAsync = function()
		return { ArePaidRandomItemsRestricted = true, AllowedExternalLinkReferences = {} }
	end,
})
service("ChangeHistoryService")
service("InsertService")
service("AssetService")
service("GuiService")
service("StarterPack")
service("SocialService")

---------------------------------------------------------------------------------------------
-- JSON (for HttpService and the DataStore stand-in)
---------------------------------------------------------------------------------------------
local function isArray(t)
	local n = 0
	for k in pairs(t) do
		if type(k) ~= "number" or k % 1 ~= 0 or k < 1 then
			return false
		end
		n = n + 1
	end
	for i = 1, n do
		if t[i] == nil then
			error("JSON: sparse array can't be saved")
		end
	end
	return true, n
end
function __json_encode(v)
	local t = type(v)
	if v == nil then
		return "null"
	elseif t == "boolean" then
		return v and "true" or "false"
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			error("JSON: can't save NaN or infinity")
		end
		if math.type(v) == "integer" or v == math.floor(v) then
			return string.format("%d", v)
		end
		return string.format("%.17g", v)
	elseif t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
			return map[c] or string.format("\\u%04x", c:byte())
		end) .. '"'
	elseif t == "table" then
		if getmetatable(v) and getmetatable(v).__instance then
			error("JSON: can't save an Instance")
		end
		local arr, n = isArray(v)
		if arr and n > 0 then
			local parts = {}
			for i = 1, n do
				parts[i] = __json_encode(v[i])
			end
			return "[" .. table.concat(parts, ",") .. "]"
		elseif arr then
			return "[]"
		end
		local keys = {}
		for k in pairs(v) do
			if type(k) ~= "string" then
				error("JSON: mixed or non-string keys can't be saved (key " .. tostring(k) .. ")")
			end
			table.insert(keys, k)
		end
		table.sort(keys)
		local parts = {}
		for _, k in ipairs(keys) do
			table.insert(parts, __json_encode(k) .. ":" .. __json_encode(v[k]))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("JSON: can't save a " .. t)
end
function __json_decode(s)
	local pos = 1
	local function ws()
		pos = s:find("[^ \t\r\n]", pos) or #s + 1
	end
	local value
	local function str()
		local out = {}
		pos = pos + 1
		while true do
			local c = s:sub(pos, pos)
			if c == '"' then
				pos = pos + 1
				return table.concat(out)
			elseif c == "\\" then
				local e = s:sub(pos + 1, pos + 1)
				local map = { n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				if e == "u" then
					table.insert(out, utf8.char(tonumber(s:sub(pos + 2, pos + 5), 16)))
					pos = pos + 6
				else
					table.insert(out, map[e])
					pos = pos + 2
				end
			else
				table.insert(out, c)
				pos = pos + 1
			end
		end
	end
	function value()
		ws()
		local c = s:sub(pos, pos)
		if c == "{" then
			local t = {}
			pos = pos + 1
			ws()
			if s:sub(pos, pos) == "}" then
				pos = pos + 1
				return t
			end
			while true do
				ws()
				local k = str()
				ws()
				pos = pos + 1 -- :
				t[k] = value()
				ws()
				local d = s:sub(pos, pos)
				pos = pos + 1
				if d == "}" then
					return t
				end
			end
		elseif c == "[" then
			local t = {}
			pos = pos + 1
			ws()
			if s:sub(pos, pos) == "]" then
				pos = pos + 1
				return t
			end
			while true do
				table.insert(t, value())
				ws()
				local d = s:sub(pos, pos)
				pos = pos + 1
				if d == "]" then
					return t
				end
			end
		elseif c == '"' then
			return str()
		elseif s:sub(pos, pos + 3) == "true" then
			pos = pos + 4
			return true
		elseif s:sub(pos, pos + 4) == "false" then
			pos = pos + 5
			return false
		elseif s:sub(pos, pos + 3) == "null" then
			pos = pos + 4
			return nil
		else
			local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
			pos = pos + #num
			return math.tointeger(tonumber(num)) or tonumber(num)
		end
	end
	return value()
end

---------------------------------------------------------------------------------------------
-- Module system: script instances mirror default.project.json; require() loads src files.
---------------------------------------------------------------------------------------------
local loaded = {}
function __makeScript(parent, name, class, path)
	local s = __newInstance(class, name)
	rawget(s, "_props").__path = path
	s.Parent = parent
	return s
end
function __load(obj)
	local path = obj.__path
	if not path then
		error("no source for " .. obj:GetFullName())
	end
	local src = __source(path) -- provided by the Python runner (converted Luau)
	local env = setmetatable({ script = obj }, { __index = _G, __newindex = _G })
	local fn, err = load(src, "@" .. path, "t", env)
	if not fn then
		error(err, 0)
	end
	return fn
end
local clientLoaded = {}
local loadingClient = false
local rawrequire = require
function require(obj)
	if type(obj) ~= "table" then
		return rawrequire(obj)
	end
	if not obj:IsA("ModuleScript") then
		error("require() needs a ModuleScript, got " .. tostring(obj.ClassName) .. " " .. obj:GetFullName())
	end
	local cache = loadingClient and clientLoaded or loaded
	local hit = cache[obj]
	if hit then
		if hit.loading then
			error("circular require of " .. obj:GetFullName())
		end
		return hit.value
	end
	cache[obj] = { loading = true }
	local v = __load(obj)()
	cache[obj] = { value = v }
	return v
end
-- Client side: __asClient(player, fn) runs fn as that player's client. Players.LocalPlayer is
-- set, pushes to that player fire OnClientEvent, client calls come from them, and require()
-- inside fn loads separate client copies of modules (a client has its own Net, listeners...).
-- Only loading is switched, so fn must not yield; code that runs later keeps its copies.
function __asClient(player, fn)
	rawget(game:GetService("Players"), "_props").LocalPlayer = player
	__localPlayer = player
	__clientListening = true
	local wasServer = __isServer
	__isServer, loadingClient = false, true
	local ok, err = pcall(fn)
	__isServer, loadingClient = wasServer, false
	if not ok then
		error(err, 0)
	end
end
-- Run a Script/LocalScript (boot scripts) in its own thread.
function __run(obj)
	return task.spawn(__load(obj))
end
function __find(path) -- "ServerScriptService.LondonServer.Profiles"
	local o = game
	for part in string.gmatch(path, "[^%.]+") do
		if o == game then
			o = game:GetService(part)
		else
			o = o:FindFirstChild(part)
		end
		if not o then
			error("no instance at " .. path)
		end
	end
	return o
end

---------------------------------------------------------------------------------------------
-- Test API
---------------------------------------------------------------------------------------------
__results = { passed = 0, failed = 0, failures = {} }
local function fmt(v)
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end
function eq(actual, expected, msg)
	if actual ~= expected then
		error((msg and (msg .. ": ") or "") .. "expected " .. fmt(expected) .. ", got " .. fmt(actual), 2)
	end
end
function ok(cond, msg)
	if not cond then
		error(msg or "expected true", 2)
	end
	return cond
end
function near(a, b, eps, msg)
	if math.abs(a - b) > (eps or 1e-6) then
		error((msg and (msg .. ": ") or "") .. "expected ~" .. tostring(b) .. ", got " .. tostring(a), 2)
	end
end
function raises(fn, pattern)
	local good, err = pcall(fn)
	if good then
		error("expected an error" .. (pattern and (" matching " .. pattern) or ""), 2)
	end
	if pattern and not string.find(tostring(err), pattern) then
		error("error didn't match " .. pattern .. ": " .. tostring(err), 2)
	end
end
function test(name, fn)
	local co = coroutine.create(fn)
	local good, err = coroutine.resume(co)
	if good and coroutine.status(co) ~= "dead" then
		-- the test yielded (task.wait): drive time until it finishes
		for _ = 1, 100000 do
			local stepped, stepErr = pcall(__advance, 0.05)
			if not stepped then
				good, err = false, stepErr
				break
			end
			if coroutine.status(co) == "dead" then
				break
			end
		end
		if good and coroutine.status(co) ~= "dead" then
			good, err = false, "test never finished (still waiting after virtual time ran out)"
		end
	end
	if good then
		__results.passed = __results.passed + 1
	else
		__results.failed = __results.failed + 1
		table.insert(__results.failures, { name = name, err = debug.traceback(co, tostring(err)) })
	end
end
