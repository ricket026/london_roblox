--!strict
-- Doors: swinging door leaves. Any BasePart tagged Config.DOOR_TAG with attributes
--   DoorHinge   Vector3  world point on the pintle axis (closed position)
--   DoorOpenDeg number   swing about +Y that opens it (sign from the model, e.g. Parliament manifest)
--   DoorGroup   string   leaves sharing a group open and close together (double doors)
--   DoorLocked  boolean  optional; true hides the prompt (Property system sets it later)
-- gets one ProximityPrompt per group, on the leaf whose name sorts first. Server-authoritative.
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Doors = {}

type Leaf = { part: BasePart, closed: CFrame, open: CFrame }
type Group = { leaves: { Leaf }, isOpen: boolean, prompt: ProximityPrompt?, busy: boolean, openedAt: number }

local groups: { [string]: Group } = {}

local function swing(g: Group, open: boolean)
	g.isOpen = open
	local info = TweenInfo.new(Config.DOOR_SWING_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	for _, leaf in g.leaves do
		TweenService:Create(leaf.part, info, { CFrame = if open then leaf.open else leaf.closed }):Play()
	end
	if g.prompt then
		g.prompt.ActionText = if open then "Close" else "Open"
	end
end

function Doors.toggle(groupName: string)
	local g = groups[groupName]
	if not g or g.busy then
		return
	end
	g.busy = true
	swing(g, not g.isOpen)
	task.delay(Config.DOOR_SWING_TIME, function()
		g.busy = false
	end)
	if g.isOpen and Config.DOOR_AUTO_CLOSE > 0 then
		local stamp = os.clock()
		g.openedAt = stamp
		task.delay(Config.DOOR_AUTO_CLOSE, function()
			if g.isOpen and g.openedAt == stamp then
				swing(g, false)
			end
		end)
	end
end

function Doors.isOpen(groupName: string): boolean
	local g = groups[groupName]
	return g ~= nil and g.isOpen
end

local function refreshPrompt(g: Group)
	if g.prompt then
		g.prompt:Destroy()
		g.prompt = nil
	end
	table.sort(g.leaves, function(a, b)
		return a.part.Name < b.part.Name
	end)
	local leaf = g.leaves[1]
	local hinge = leaf.part:GetAttribute("DoorHinge") :: Vector3
	local at = Instance.new("Attachment")
	at.Name = "DoorPromptAt"
	at.Parent = leaf.part
	at.WorldPosition = Vector3.new(leaf.part.Position.X, hinge.Y + Config.DOOR_PROMPT_HEIGHT, leaf.part.Position.Z)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Open"
	p.ObjectText = "Door"
	p.HoldDuration = 0
	p.MaxActivationDistance = Config.DOOR_PROMPT_DISTANCE
	p.RequiresLineOfSight = false
	p.Enabled = not leaf.part:GetAttribute("DoorLocked")
	p.Parent = at
	g.prompt = p
	local name = leaf.part:GetAttribute("DoorGroup") :: string
	p.Triggered:Connect(function(player: Player)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (root.Position - at.WorldPosition).Magnitude > Config.DOOR_PROMPT_DISTANCE + 4 then
			return -- server-side distance check
		end
		if leaf.part:GetAttribute("DoorLocked") then
			return
		end
		Doors.toggle(name)
	end)
	leaf.part:GetAttributeChangedSignal("DoorLocked"):Connect(function()
		p.Enabled = not leaf.part:GetAttribute("DoorLocked")
	end)
end

local function addLeaf(inst: Instance)
	if not inst:IsA("BasePart") or not inst:IsDescendantOf(workspace) then
		return
	end
	local hinge = inst:GetAttribute("DoorHinge")
	local deg = inst:GetAttribute("DoorOpenDeg")
	if typeof(hinge) ~= "Vector3" or typeof(deg) ~= "number" then
		warn("[Doors] missing DoorHinge / DoorOpenDeg on " .. inst:GetFullName())
		return
	end
	local name = inst:GetAttribute("DoorGroup")
	if typeof(name) ~= "string" then
		name = inst:GetFullName()
		inst:SetAttribute("DoorGroup", name)
	end
	inst.Anchored = true
	local pivot = CFrame.new(hinge)
	local leaf: Leaf = {
		part = inst,
		closed = inst.CFrame,
		open = pivot * CFrame.Angles(0, math.rad(deg), 0) * pivot:Inverse() * inst.CFrame,
	}
	local g = groups[name]
	if not g then
		g = { leaves = {}, isOpen = false, prompt = nil, busy = false, openedAt = 0 }
		groups[name] = g
	end
	table.insert(g.leaves, leaf)
	refreshPrompt(g)
end

function Doors.init()
	for _, inst in CollectionService:GetTagged(Config.DOOR_TAG) do
		addLeaf(inst)
	end
	CollectionService:GetInstanceAddedSignal(Config.DOOR_TAG):Connect(addLeaf)
end

return Doors
