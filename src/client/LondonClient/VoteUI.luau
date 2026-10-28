--!strict
-- LondonClient.VoteUI (stub): votes of no confidence and vote-kicks (DESIGN §10). Plain on purpose.
--   "Votes" in the More menu (top right): every player here, with "Kick" and, for those
--   holding an office, "No confidence"; then a reason from the list, then Start.
--   While a vote runs, a box low in the middle for everyone: who, why, time left, the tally, Yes / No
--   (the one voted on sees it without the buttons).
-- Server: LondonServer.Votes (Vote.Get / Start / Cast; pushes Open, Tally, Closed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local Stations = require(Shared:WaitForChild("Stations"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local VoteUI = {}

local ui = EconomyUI.ui
local C = ui.colours
local player = Players.LocalPlayer

local button: TextButton
local panel: Frame
local body: ScrollingFrame
local box: Frame
local boxText: TextLabel
local yesB: TextButton
local noB: TextButton
local vote: { [string]: any }? = nil -- the running vote (Vote.Open + Tally)
local endsAt = 0
local mine: string? = nil
local picking: { target: Player, kind: string }? = nil
local cooldown = 0

local function request(action: string, args: { [string]: any }?): (boolean, any)
	local ok, res = Net.request("Vote", action, args)
	if not ok then
		EconomyUI.toast(tostring(res), true)
	end
	return ok, res
end

local function describe(v: { [string]: any }): string
	if v.kind == "confidence" then
		return string.format("No confidence in %s as %s: %s.", v.target, v.role or "office holder", v.reason)
	end
	return string.format("Remove %s from this server: %s.", v.target, v.reason)
end

local function refreshBox()
	local v = vote
	box.Visible = v ~= nil
	if not v then
		return
	end
	local left = math.max(0, math.ceil(endsAt - os.clock()))
	local aboutMe = v.targetId == player.UserId
	boxText.Text = string.format("%s%s\nStarted by %s · %d s · yes %d, no %d", if aboutMe then "A vote about you. " else "Vote: ", describe(v), v.by, left, v.yes or 0, v.no or 0)
	yesB.Visible, noB.Visible = not aboutMe, not aboutMe
	yesB.Text = if mine == "yes" then "• Yes" else "Yes"
	noB.Text = if mine == "no" then "• No" else "No"
end

local function render()
	ui.clear(body)
	local o = ui.counter()
	local p = picking
	if p then
		local r = Stations.BY_ID[Roles.roleOf(p.target)]
		local name = p.target:GetAttribute("RPName") or p.target.DisplayName
		local what = if p.kind == "confidence" then string.format("Remove %s as %s. Why?", name, if r then r.name else "office holder") else string.format("Remove %s from this server. Why?", name)
		ui.line(body, o(), what, C.GOLD, 18)
		for _, reason in if p.kind == "confidence" then Config.CONFIDENCE_REASONS else Config.KICK_REASONS do
			local _, b = ui.row(body, o(), reason, { { "Start" } })
			b[1].Activated:Connect(function()
				picking = nil
				if request("Start", { target = p.target, kind = p.kind, reason = reason }) then
					panel.Visible = false
				else
					render()
				end
			end)
		end
		local _, back = ui.row(body, o(), "", { { "Back" } })
		back[1].Activated:Connect(function()
			picking = nil
			render()
		end)
		return
	end
	if vote then
		ui.line(body, o(), "A vote is running: " .. describe(vote), C.GOLD, 16)
	elseif cooldown > 0 then
		ui.line(body, o(), string.format("You can start another vote in %d min.", math.ceil(cooldown / 60)), C.MUTED, 16)
	end
	ui.line(body, o(), string.format("No confidence: %d%% of the votes cast and at least %d votes. Kick: %d%% of the server and at least %d yes.", math.floor(Config.CONFIDENCE_SHARE * 100), Config.CONFIDENCE_VOTES_MIN, math.floor(Config.KICK_SHARE * 100), Config.KICK_YES_MIN), C.MUTED, 14)
	for _, q in Players:GetPlayers() do
		if q ~= player and q:GetAttribute("CharSlot") ~= nil then
			local role = Roles.roleOf(q)
			local r = Stations.BY_ID[role]
			local seated = r ~= nil and r.seats ~= nil
			local name = q:GetAttribute("RPName") or q.DisplayName
			local label = tostring(name) .. (if r and role ~= Config.DEFAULT_ROLE then " · " .. r.name else "")
			local buttons = if seated then { { "No conf." }, { "Kick" } } else { { "Kick" } }
			local _, b = ui.row(body, o(), label, buttons, 76)
			if seated then
				b[1].Activated:Connect(function()
					picking = { target = q, kind = "confidence" }
					render()
				end)
			end
			b[#b].Activated:Connect(function()
				picking = { target = q, kind = "kick" }
				render()
			end)
		end
	end
end

function VoteUI.open()
	picking = nil
	local ok, res = Net.request("Vote", "Get")
	if ok then
		cooldown = res.cooldown or 0
	end
	panel.Visible = true
	render()
end

function VoteUI.state(): { [string]: any }?
	return vote
end

local function cast(yes: boolean)
	local v = vote
	if not v then
		return
	end
	if request("Cast", { id = v.id, yes = yes }) then
		mine = if yes then "yes" else "no"
		refreshBox()
	end
end

local function onOpen(msg: { [string]: any })
	vote = msg
	endsAt = os.clock() + (msg.seconds or 0)
	mine = if msg.mine then msg.mine elseif msg.byId == player.UserId then "yes" else nil -- starting it is your yes
	refreshBox()
end

function VoteUI.init()
	local gui = EconomyUI.gui()
	button = EconomyUI.menuButton("VotesButton", "Votes", 30)
	panel, body = ui.panel("VotePanel", "Votes")
	button.Activated:Connect(function()
		if panel.Visible then
			panel.Visible = false
		else
			VoteUI.open()
		end
	end)

	box = Instance.new("Frame")
	box.Name = "VoteBox"
	-- low in the middle: clear of the top-right buttons, above the room line and the toast
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -118)
	box.Size = UDim2.fromOffset(300, 108)
	box.BackgroundColor3 = C.PAPER
	box.BackgroundTransparency = 0.1
	box.BorderSizePixel = 0
	box.Visible = false
	box.Parent = gui
	boxText = ui.text(box, "TextLabel", { Name = "Text", TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 62) })
	yesB = ui.button(box, "Yes", { Name = "Yes", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -4, 1, -6), Size = UDim2.fromOffset(110, 30) })
	noB = ui.button(box, "No", { Name = "No", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 4, 1, -6), Size = UDim2.fromOffset(110, 30) })
	yesB.Activated:Connect(function()
		cast(true)
	end)
	noB.Activated:Connect(function()
		cast(false)
	end)

	Net.listen("Vote", "Open", onOpen)
	Net.listen("Vote", "Tally", function(msg)
		if vote and vote.id == msg.id then
			vote.yes, vote.no = msg.yes, msg.no
			refreshBox()
		end
	end)
	Net.listen("Vote", "Closed", function(msg)
		if vote and vote.id == msg.id then
			vote, mine = nil, nil
			refreshBox()
		end
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text, not msg.passed)
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
	task.spawn(function()
		local ok, res = Net.request("Vote", "Get")
		if ok and res.current then
			onOpen(res.current)
		end
		while true do
			task.wait(0.5)
			if vote then
				refreshBox()
			end
		end
	end)
end

return VoteUI
