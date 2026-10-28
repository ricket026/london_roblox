--!strict
-- LondonServer.Speech: quick phrases (Shared.Phrases, TASKS T05). A phrase is sent by id, so it's
-- game text, not player chat: the server shows it in a speech bubble over the speaker's head
-- for Config.SPEECH_SECONDS (everyone sees it) and sends the line to players within
-- Config.SPEECH_RANGE for their chat window.
-- Remote (Phrase domain, event): Say { id }. Push: Phrase.Said { from, text } to those nearby.
--   Speech.allow(player) -> boolean: a hook other modules set (the throne room in session lets
--   only the Monarch and whoever has the floor speak); nil = everyone may.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Phrases = require(Shared:WaitForChild("Phrases"))
local World = require(script.Parent:WaitForChild("World"))

local Speech = {}
Speech.allow = nil :: ((Player) -> boolean)?

local stamps: { [Player]: number } = {}

local function nameOf(p: Player): string
	local n = p:GetAttribute("RPName")
	return if type(n) == "string" then n else p.DisplayName
end

function Speech.say(player: Player, id: string): boolean
	local phrase = Phrases.get(id)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not phrase or not head or not head:IsA("BasePart") or player:GetAttribute("CharSlot") == nil then
		return false
	end
	local allow = Speech.allow
	if allow and not allow(player) then
		return false
	end
	local old = head:FindFirstChild("Speech")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Speech"
	bb.Size = UDim2.fromOffset(220, 46)
	bb.StudsOffset = Vector3.new(0, 4.6, 0)
	bb.MaxDistance = Config.SPEECH_RANGE * 1.5
	bb.Adornee = head
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = Color3.fromRGB(240, 232, 214)
	l.BackgroundTransparency = 0.1
	l.Font = Enum.Font.Garamond
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(28, 24, 20)
	l.Text = phrase.text
	l.Parent = bb
	bb.Parent = head
	local stamp = os.clock()
	stamps[player] = stamp
	task.delay(Config.SPEECH_SECONDS, function()
		if stamps[player] == stamp and bb.Parent then
			bb:Destroy()
		end
	end)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local from = if root and root:IsA("BasePart") then root.Position else head.Position
	for _, other in Players:GetPlayers() do
		if World.near(other, from, Config.SPEECH_RANGE) then
			Net.push(other, "Phrase", "Said", { from = nameOf(player), text = phrase.text })
		end
	end
	return true
end

function Speech.init()
	local V = Net.V
	Net.handle("Phrase", "Say", { schema = { id = V.str(30) }, rate = Config.SPEECH_RATE }, function(player, a)
		Speech.say(player, a.id)
	end)
	Players.PlayerRemoving:Connect(function(p)
		stamps[p] = nil
	end)
end

return Speech
