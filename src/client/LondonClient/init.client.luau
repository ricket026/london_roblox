--!strict
-- LondonClient: client boot. M0: wallet state and staff notices in chat. UI modules arrive from
-- M1 as children of this script (UIKit, HUD, RoleMenu... TECH.md §3).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Text = require(Shared:WaitForChild("Text"))

require(script:WaitForChild("CharacterUI")).init()
require(script:WaitForChild("IdentityUI")).init()
require(script:WaitForChild("ClockHUD")).init()
require(script:WaitForChild("Activities")).init()

local State = { pence = 0, bank = 0 }

Net.listen("Profile", "Wallet", function(msg)
	if type(msg.pence) == "number" then
		State.pence = msg.pence
	end
	if type(msg.bank) == "number" then
		State.bank = msg.bank
	end
	script:SetAttribute("Pence", State.pence) -- read by tests until the HUD exists (M2)
end)

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
