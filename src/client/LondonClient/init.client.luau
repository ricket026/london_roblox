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
