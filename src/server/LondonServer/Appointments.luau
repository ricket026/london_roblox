--!strict
-- LondonServer.Appointments: something at a hub every Config.APPOINTMENT_SECONDS (PLAYER_GATHERING §2,
-- TASKS T30): a train arrival, a band concert, the Changing of the Guard, the flower auction, in
-- turn. Times come from the shared server clock, so every server has the same appointment at the
-- same moment (the "What's on" feed can join them up later, T31). Each runs for
-- Config.APPOINTMENT_LENGTH at the end of its slot; a flag marks the spot while it's on. Anyone
-- within Config.APPOINTMENT_RADIUS for Config.APPOINTMENT_STAY seconds gets its memento in their
-- collection book (Shared.Collection) and a tick for "be there" daily tasks (Daily.record).
--   Appointments.at(t) -> def, startsAt, endsAt   the appointment that's next (or on) at server time t
-- Remote (Appointment domain, call): Get. Pushes Appointment.Next { id, title, place, pos,
--   startsAt, endsAt } when it changes, and Appointment.Notice { text }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Collection = require(Shared:WaitForChild("Collection"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local World = require(script.Parent:WaitForChild("World"))
local Daily = require(script.Parent:WaitForChild("Daily"))

local Appointments = {}

local stayed: { [Player]: number } = {}
local rewarded: { [Player]: number } = {} -- slot each player last got a memento for
local flag: Model? = nil
local shownSlot = -1

local function now(): number
	return workspace:GetServerTimeNow()
end

-- The appointment of a slot: when it starts and ends (server time).
local function slotTimes(slot: number): ({ [string]: any }, number, number)
	local def = Config.APPOINTMENTS[(slot % #Config.APPOINTMENTS) + 1]
	local ends = (slot + 1) * Config.APPOINTMENT_SECONDS
	return def, ends - Config.APPOINTMENT_LENGTH, ends
end

-- What's next (or on now) at server time t.
function Appointments.at(t: number): ({ [string]: any }, number, number, number)
	local slot = math.floor(t / Config.APPOINTMENT_SECONDS)
	local def, starts, ends = slotTimes(slot)
	if t >= ends then
		slot += 1
		def, starts, ends = slotTimes(slot)
	end
	return def, starts, ends, slot
end

local function spot(def: { [string]: any }): Vector3
	return World.ground(def.x, def.z)
end

local function view(): { [string]: any }
	local def, starts, ends = Appointments.at(now())
	return { id = def.id, title = def.title, place = def.place, pos = spot(def), startsAt = starts, endsAt = ends }
end

local function showFlag(def: { [string]: any }?)
	if flag then
		flag:Destroy()
		flag = nil
	end
	if not def then
		return
	end
	local g = spot(def)
	local m = Instance.new("Model")
	m.Name = "Appointment"
	local pole = World.part({ Name = "Pole", Size = Vector3.new(0.4, 16, 0.4), CFrame = CFrame.new(g + Vector3.new(0, 8, 0)), Color = Color3.fromRGB(28, 28, 30), Material = Enum.Material.Metal })
	pole.Parent = m
	local cloth = World.part({ Name = "Flag", Size = Vector3.new(4, 2.4, 0.1), CFrame = CFrame.new(g + Vector3.new(2.2, 14.6, 0)), Color = Color3.fromRGB(170, 24, 30), Material = Enum.Material.Fabric, CanCollide = false })
	cloth.Parent = m
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 50)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.MaxDistance = 400
	bb.AlwaysOnTop = true
	bb.Parent = pole
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GaramondBold
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(240, 205, 120)
	l.TextStrokeTransparency = 0.3
	l.Text = def.title
	l.Parent = bb
	m.Parent = World.folder("Appointments")
	flag = m
end

local function reward(player: Player, def: { [string]: any }, slot: number)
	rewarded[player] = slot
	local p = Profiles.get(player)
	local it = Collection.BY_ID[def.memento]
	if p and it then
		local n = (p.collection[it.id] or 0) + 1
		p.collection[it.id] = n
		Net.push(player, "Appointment", "Notice", { text = string.format("You were there for %s: %s for your collection book%s.", string.lower(def.title), it.name, if n == 1 then " (new)" else "") })
	end
	Daily.record(player, "appointment")
end

-- Once a second: the flag, the "what's next" push, and who has been there long enough.
function Appointments.tick(dt: number)
	local t = now()
	local def, starts, ends, slot = Appointments.at(t)
	local on = t >= starts and t < ends
	if slot ~= shownSlot then
		shownSlot = slot
		Net.pushAll("Appointment", "Next", view())
	end
	if on and not flag then
		showFlag(def)
	elseif not on and flag then
		showFlag(nil)
		stayed = {}
	end
	if not on then
		return
	end
	local pos = spot(def)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("CharSlot") ~= nil and World.near(player, pos, Config.APPOINTMENT_RADIUS) then
			stayed[player] = (stayed[player] or 0) + dt
			if stayed[player] >= Config.APPOINTMENT_STAY and rewarded[player] ~= slot then
				reward(player, def, slot)
			end
		end
	end
end

function Appointments.init()
	Net.handle("Appointment", "Get", { call = true }, function()
		return view()
	end)
	Players.PlayerRemoving:Connect(function(p)
		stayed[p], rewarded[p] = nil, nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			Appointments.tick(1)
		end
	end)
end

return Appointments
