--!strict
-- LondonClient: client boot. Requires and inits the UI modules (children of this script) and shows
-- staff notices in chat. The wallet is shown by EconomyUI (Net.listen keeps one listener per
-- action, so only one module may listen to Profile.Wallet).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Text = require(Shared:WaitForChild("Text"))

require(script:WaitForChild("CharacterUI")).init()
require(script:WaitForChild("IdentityUI")).init()
require(script:WaitForChild("ClockHUD")).init()
require(script:WaitForChild("Activities")).init()
require(script:WaitForChild("EconomyUI")).init() -- wallet, bag, counters, hand-overs (Phase 2)
require(script:WaitForChild("BuildUI")).init() -- build mode (Phase 3)
require(script:WaitForChild("PropertyUI")).init() -- estate agents, your properties, keys (Phase 3)
require(script:WaitForChild("ShopUI")).init() -- shop tills, market stalls, suppliers (Phase 4)
require(script:WaitForChild("JobUI")).init() -- job tracker (Phase 5)
require(script:WaitForChild("DailyUI")).init() -- appointments countdown, today's tasks (Phase 6)
require(script:WaitForChild("SpeechUI")).init() -- quick phrases and gestures (T05)
require(script:WaitForChild("ThroneUI")).init() -- the throne: offers, proclamations, abdicate (T34)
require(script:WaitForChild("CourtUI")).init() -- titles, offices, forms of address (T35, T08)

Net.listen("Admin", "Notice", function(msg)
	if type(msg.text) ~= "string" then
		return
	end
	local channels = TextChatService:FindFirstChild("TextChannels")
	local system = if channels then channels:FindFirstChild("RBXSystem") else nil
	if system and system:IsA("TextChannel") then
		system:DisplaySystemMessage("<font color=\"#d9b36c\">[Staff]</font> " .. Text.escapeRich(msg.text))
	end
end)
