--!strict
-- LondonClient.ThroneUI (stub): the throne (COURT_PARLIAMENT §2.1). Plain on purpose.
--   A banner under the clock for proclamations (accessions, abdications, an empty throne).
--   A succession offer in the middle of the screen: Accept / Decline with a countdown.
--   While you reign: a small panel top left with Abdicate (tap twice to confirm).
-- The "Claim the throne" prompt is a ProximityPrompt on the throne seat, made by the server.
-- Server: LondonServer.Throne (Throne.Get / Accept / Decline / Abdicate; pushes Offer, Proclaim,
--   State, Notice).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local ThroneUI = {}

local ui = EconomyUI.ui
local C = ui.colours
local player = Players.LocalPlayer

local banner: TextLabel
local offerFrame: Frame
local offerText: TextLabel
local reignFrame: Frame
local reignText: TextLabel
local abdicate: TextButton
local offer: { role: string, endsAt: number }? = nil
local monarchs: { [string]: any } = {}
local confirmUntil = 0

function ThroneUI.proclaim(text: string)
	banner.Text = text
	banner.Visible = true
	task.delay(Config.THRONE_PROCLAIM_SECONDS, function()
		if banner.Text == text then
			banner.Visible = false
		end
	end)
end

local function refreshOffer()
	local o = offer
	local left = if o then math.ceil(o.endsAt - os.clock()) else 0
	if o and left <= 0 then
		offer = nil
	end
	offerFrame.Visible = offer ~= nil
	if o and offer then
		offerText.Text = string.format("The %s's throne is empty and you are next in line. Take it? (%d s)", string.lower(o.role), left)
	end
end

local function refreshReign()
	local role = Roles.roleOf(player)
	local reigning = role == "King" or role == "Queen"
	reignFrame.Visible = reigning and player:GetAttribute("CharSlot") ~= nil
	reignText.Text = if reigning then "You reign as " .. role .. "." else ""
	abdicate.Text = if os.clock() < confirmUntil then "Sure? Tap again" else "Abdicate"
end

function ThroneUI.apply(msg: { [string]: any })
	monarchs = { King = msg.King, Queen = msg.Queen }
	if type(msg.offer) == "table" then
		offer = { role = msg.offer.role, endsAt = os.clock() + (msg.offer.seconds or 0) }
	end
	refreshOffer()
	refreshReign()
end

function ThroneUI.state(): ({ [string]: any }, { role: string, endsAt: number }?)
	return monarchs, offer
end

local function answer(accept: boolean)
	local o = offer
	if not o then
		return
	end
	offer = nil
	refreshOffer()
	local ok, res = Net.request("Throne", if accept then "Accept" else "Decline", { role = o.role })
	if not ok then
		EconomyUI.toast(tostring(res), true)
	end
end

function ThroneUI.init()
	local gui = EconomyUI.gui()
	banner = ui.text(gui, "TextLabel", {
		Name = "Proclamation",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 86),
		Size = UDim2.fromOffset(420, 44),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = C.PAPER,
		TextColor3 = C.GOLD,
		TextSize = 19,
		TextWrapped = true,
		Visible = false,
	})
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 44)
	limit.Parent = banner

	offerFrame = Instance.new("Frame")
	offerFrame.Name = "ThroneOffer"
	offerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	offerFrame.Position = UDim2.fromScale(0.5, 0.5)
	offerFrame.Size = UDim2.fromOffset(330, 112)
	offerFrame.BackgroundColor3 = C.PAPER
	offerFrame.BorderSizePixel = 0
	offerFrame.Visible = false
	offerFrame.Parent = gui
	offerText = ui.text(offerFrame, "TextLabel", { Name = "Text", TextWrapped = true, TextSize = 18, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 54) })
	local yes = ui.button(offerFrame, "Accept", { Name = "Accept", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -4, 1, -8), Size = UDim2.fromOffset(120, 34) })
	local no = ui.button(offerFrame, "Decline", { Name = "Decline", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 4, 1, -8), Size = UDim2.fromOffset(120, 34) })
	yes.Activated:Connect(function()
		answer(true)
	end)
	no.Activated:Connect(function()
		answer(false)
	end)

	-- top left, where the job tracker sits (a monarch has no job)
	reignFrame = Instance.new("Frame")
	reignFrame.Name = "Reign"
	reignFrame.Position = UDim2.fromOffset(12, 44)
	reignFrame.Size = UDim2.fromOffset(220, 64)
	reignFrame.BackgroundColor3 = C.PAPER
	reignFrame.BackgroundTransparency = 0.2
	reignFrame.BorderSizePixel = 0
	reignFrame.Visible = false
	reignFrame.Parent = gui
	reignText = ui.text(reignFrame, "TextLabel", { Name = "Text", Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 22), TextSize = 17, TextColor3 = C.GOLD, TextXAlignment = Enum.TextXAlignment.Left })
	abdicate = ui.button(reignFrame, "Abdicate", { Name = "Abdicate", Position = UDim2.fromOffset(8, 30), Size = UDim2.fromOffset(150, 28), TextSize = 16 })
	abdicate.Activated:Connect(function()
		if os.clock() >= confirmUntil then
			confirmUntil = os.clock() + 4
			refreshReign()
			task.delay(4, refreshReign)
			return
		end
		confirmUntil = 0
		refreshReign()
		local ok, res = Net.request("Throne", "Abdicate")
		if not ok then
			EconomyUI.toast(tostring(res), true)
		end
	end)

	Net.listen("Throne", "State", ThroneUI.apply)
	Net.listen("Throne", "Offer", function(msg)
		offer = { role = msg.role, endsAt = os.clock() + (msg.seconds or 0) }
		refreshOffer()
	end)
	Net.listen("Throne", "Proclaim", function(msg)
		if type(msg.text) == "string" then
			ThroneUI.proclaim(msg.text)
		end
	end)
	Net.listen("Throne", "Notice", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text, true)
		end
	end)
	player:GetAttributeChangedSignal(Roles.ROLE_ATTR):Connect(refreshReign)
	player:GetAttributeChangedSignal("CharSlot"):Connect(refreshReign)
	task.spawn(function()
		local ok, res = Net.request("Throne", "Get")
		if ok then
			ThroneUI.apply(res)
		end
		while true do
			task.wait(0.5)
			if offer then
				refreshOffer()
			end
		end
	end)
end

return ThroneUI
