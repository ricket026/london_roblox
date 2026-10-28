--!strict
-- LondonServer: server boot. Wires the player lifecycle: staff level -> ban check -> profile.
-- Systems live in the child ModuleScripts (TECH.md §3); later milestones add theirs here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Roles = require(Shared:WaitForChild("Roles"))
local Store = require(script:WaitForChild("Store"))
local Profiles = require(script:WaitForChild("Profiles"))
local Admin = require(script:WaitForChild("Admin"))
local Analytics = require(script:WaitForChild("Analytics"))
local Doors = require(script:WaitForChild("Doors"))
local Identity = require(script:WaitForChild("Identity"))
local Characters = require(script:WaitForChild("Characters"))
local Economy = require(script:WaitForChild("Economy"))
local Inventory = require(script:WaitForChild("Inventory"))
local Counters = require(script:WaitForChild("Counters"))
local Exchange = require(script:WaitForChild("Exchange"))
local Lots = require(script:WaitForChild("Lots"))
local Builds = require(script:WaitForChild("Builds"))
local Property = require(script:WaitForChild("Property"))
local Shops = require(script:WaitForChild("Shops"))
local Jobs = require(script:WaitForChild("Jobs"))
local WorldClock = require(script:WaitForChild("WorldClock"))
local Lamps = require(script:WaitForChild("Lamps"))
local Activities = require(script:WaitForChild("Activities"))

Profiles.init()
Admin.init()
Doors.init()
Identity.init()
Characters.init()
Economy.init()
Inventory.init()
Counters.init()
Exchange.init()
Lots.init()
Builds.init()
Property.init()
Shops.init()
Jobs.init()
WorldClock.init()
Lamps.init()
Activities.init()
if RunService:IsStudio() then
	require(script:WaitForChild("Debug")).init()
end

local function onPlayerAdded(player: Player)
	player:SetAttribute(Roles.STAFF_ATTR, Roles.computeStaffLevel(player))
	if Admin.checkBan(player) then
		return
	end
	local profile = Profiles.onPlayerAdded(player)
	if profile then
		Admin.onProfileLoaded(player, profile)
		Identity.onProfileLoaded(player)
		Characters.onProfileLoaded(player)
		Property.onProfileLoaded(player)
		Analytics.onProfileLoaded(player, Profiles.isNew(player))
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	Admin.onPlayerRemoving(player)
	Identity.onPlayerRemoving(player)
	Characters.onPlayerRemoving(player)
	Economy.onPlayerRemoving(player)
	Shops.onPlayerRemoving(player)
	Property.onPlayerRemoving(player)
	Activities.onPlayerRemoving(player)
	Analytics.onPlayerRemoving(player)
	Profiles.onPlayerRemoving(player)
end)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end
game:BindToClose(function()
	Shops.closeAll()
	Builds.closeAll()
	Profiles.closeAll()
end)

print(string.format("[LondonServer] ready (store: %s)", if Store.isMock then "Studio mock" else "DataStore"))
