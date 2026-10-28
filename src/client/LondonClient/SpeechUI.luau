--!strict
-- LondonClient.SpeechUI (stub): the quick-phrase wheel and etiquette emotes (DESIGN §9, TASKS T05).
-- Plain on purpose. A "Say" button (bottom left, by the Station button) opens the phrases by
-- category and the emotes; a phrase goes to the server by id (Phrase.Say) and appears as a
-- speech bubble for everyone. Lines said nearby (Phrase.Said) also go in the chat window.
-- Emotes: Roblox's default wave / cheer / point (Humanoid:PlayEmote); the rest play
-- Config.EMOTE_ANIMATIONS once the user has published them (0 = not yet).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Text = require(Shared:WaitForChild("Text"))
local Phrases = require(Shared:WaitForChild("Phrases"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local SpeechUI = {}

local ui = EconomyUI.ui
local C = ui.colours
local player = Players.LocalPlayer

local button: TextButton
local panel: Frame
local body: ScrollingFrame
local catIndex = 1

function SpeechUI.say(id: string)
	Net.send("Phrase", "Say", { id = id })
end

function SpeechUI.emote(id: string): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return false
	end
	for _, e in Phrases.EMOTES do
		if e.id == id then
			if e.builtin then
				local ok, played = pcall(hum.PlayEmote, hum, e.builtin)
				return ok and played == true
			end
			local anim = Config.EMOTE_ANIMATIONS[id] or 0
			local animator = hum:FindFirstChildOfClass("Animator")
			if anim == 0 or not animator then
				EconomyUI.toast("That gesture isn't ready yet.", true)
				return false
			end
			local a = Instance.new("Animation")
			a.AnimationId = "rbxassetid://" .. anim
			animator:LoadAnimation(a):Play()
			return true
		end
	end
	return false
end

local function render()
	ui.clear(body)
	local o = ui.counter()
	local cat = Phrases.CATEGORIES[catIndex]
	local _, nav = ui.row(body, o(), cat, { { "◀" }, { "▶" } }, 44)
	nav[1].Activated:Connect(function()
		catIndex = (catIndex - 2) % #Phrases.CATEGORIES + 1
		render()
	end)
	nav[2].Activated:Connect(function()
		catIndex = catIndex % #Phrases.CATEGORIES + 1
		render()
	end)
	for _, p in Phrases.LIST do
		if p.cat == cat then
			local b = ui.button(body, p.text, { LayoutOrder = o(), Size = UDim2.new(1, 0, 0, 32), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left })
			b.Activated:Connect(function()
				SpeechUI.say(p.id)
				panel.Visible = false
			end)
		end
	end
	ui.line(body, o(), "Gestures", C.MUTED, 16)
	local labels = {}
	for k, e in Phrases.EMOTES do
		labels[k] = { e.name }
	end
	-- two rows of four
	for start = 1, #labels, 4 do
		local slice = {}
		for k = start, math.min(#labels, start + 3) do
			table.insert(slice, labels[k])
		end
		local _, eb = ui.row(body, o(), "", slice, 86)
		for k, b in eb do
			local e = Phrases.EMOTES[start + k - 1]
			b.Activated:Connect(function()
				SpeechUI.emote(e.id)
			end)
		end
	end
end

function SpeechUI.init()
	local gui = EconomyUI.gui()
	button = ui.button(gui, "Say", { Name = "SayButton", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 240, 1, -12), Size = UDim2.fromOffset(90, 40), Visible = false })
	panel, body = ui.panel("SpeechPanel", "Say")
	button.Activated:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then
			render()
			ui.focus(panel:FindFirstChild("Close") :: GuiObject?)
		end
	end)
	local function refresh()
		button.Visible = player:GetAttribute("CharSlot") ~= nil
		if not button.Visible then
			panel.Visible = false
		end
	end
	player:GetAttributeChangedSignal("CharSlot"):Connect(refresh)
	refresh()
	Net.listen("Phrase", "Said", function(msg)
		if type(msg.text) ~= "string" or type(msg.from) ~= "string" then
			return
		end
		local channels = TextChatService:FindFirstChild("TextChannels")
		local system = if channels then channels:FindFirstChild("RBXSystem") else nil
		if system and system:IsA("TextChannel") then
			system:DisplaySystemMessage(string.format("<b>%s</b>: %s", Text.escapeRich(msg.from), Text.escapeRich(msg.text)))
		end
	end)
end

return SpeechUI
