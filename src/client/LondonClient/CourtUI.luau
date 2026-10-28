--!strict
-- LondonClient.CourtUI (stub): the Court menu (COURT_PARLIAMENT §3, §5). Plain on purpose.
--   A "Court" button top left for anyone royal, titled or in a Household office. The panel:
--   your style and form of address (Their / His / Her), Renounce title; and, for those who may
--   grant, every player here: titles (with a place), offices, the royal family, revocations
--   (with a reason). Every grant asks to confirm first.
--   For the King or Queen: Issue a decree (title, words, and a lever such as a bank holiday).
--   An offered office or royal invitation: Accept / Decline in the middle of the screen.
--   A royal decree for everyone: a banner at the top (Close), with the bell if Config has one.
-- Server: LondonServer.Court (Court.Get / GrantTitle / Appoint / InviteRoyal / Answer / Revoke /
--   Renounce / SetForm; pushes Offer, Closed, Changed, Notice), LondonServer.Decrees (Decree.Get /
--   Issue; pushes Issued, Notice).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Roles = require(Shared:WaitForChild("Roles"))
local Titles = require(Shared:WaitForChild("Titles"))
local Stations = require(Shared:WaitForChild("Stations"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))

local CourtUI = {}

local ui = EconomyUI.ui
local C = ui.colours
local player = Players.LocalPlayer

local COURT_ROLES = { King = true, Queen = true, Royal = true, LordChamberlain = true, PrivateSecretary = true, Equerry = true }
local FORM_LABEL = { neutral = "Their", his = "His", her = "Her" }
local CLOSED_TEXT = { done = "They accepted.", declined = "They said no.", expired = "No answer came.", left = "They've gone.", failed = "It couldn't be done." }

local button: TextButton
local panel: Frame
local body: ScrollingFrame
local offerFrame: Frame
local offerText: TextLabel
local view: { [string]: any } = {}
local chosen: number? = nil -- userId of the player the grant section is about
local placeIndex = 1
local pending: { domain: string, action: string, args: { [string]: any }, text: string }? = nil
local decrees: { [string]: any } = {} -- Decree.Get, for the King or Queen
local draft = { title = "", text = "", lever = "" } -- the decree being written ("" = no lever)
local decreeFrame: Frame
local decreeShown = 0
local offer: { id: number, endsAt: number, text: string }? = nil
local renounceUntil = 0

local function request(action: string, args: { [string]: any }?, domain: string?): boolean
	local ok, res = Net.request(domain or "Court", action, args)
	if not ok then
		EconomyUI.toast(tostring(res), true)
	end
	return ok
end

local function refreshButton()
	local here = player:GetAttribute("CharSlot") ~= nil
	button.Visible = here and (COURT_ROLES[Roles.roleOf(player)] == true or player:GetAttribute(Titles.ATTR) ~= nil)
	if not button.Visible then
		panel.Visible = false
	end
end

local function target(): Player?
	return if chosen then Players:GetPlayerByUserId(chosen) else nil
end

local render: () -> ()

local function fetch()
	local ok, res = Net.request("Court", "Get")
	if ok then
		view = res
		if view.monarch then
			local good, d = Net.request("Decree", "Get")
			decrees = if good then d else {}
		end
		render()
	end
end

local function ask(action: string, args: { [string]: any }, text: string, domain: string?)
	pending = { domain = domain or "Court", action = action, args = args, text = text }
	render()
end

local function box(o: () -> number, name: string, value: string, placeholder: string, height: number, onChange: (string) -> ()): TextBox
	local r = Instance.new("Frame")
	r.LayoutOrder = o()
	r.BackgroundTransparency = 1
	r.Size = UDim2.new(1, 0, 0, height + 4)
	r.Parent = body
	local b = ui.text(r, "TextBox", {
		Name = name,
		Text = value,
		PlaceholderText = placeholder,
		PlaceholderColor3 = C.MUTED,
		ClearTextOnFocus = false,
		MultiLine = height > 40,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(34, 30, 26),
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, height),
		Position = UDim2.fromOffset(0, 2),
	})
	b:GetPropertyChangedSignal("Text"):Connect(function()
		onChange(b.Text)
	end)
	return b
end

-- The King or Queen writes a decree.
local function decreeSection(o: () -> number)
	ui.line(body, o(), "Issue a decree" .. (if (decrees.cooldown or 0) > 0 then string.format(" (next in %d s)", decrees.cooldown) else ""), C.GOLD, 18)
	box(o, "DecreeTitle", draft.title, string.format("Title (up to %d letters)", Config.DECREE_TITLE_MAX), 30, function(t)
		draft.title = t
	end)
	box(o, "DecreeText", draft.text, string.format("The decree (up to %d letters)", Config.DECREE_TEXT_MAX), 84, function(t)
		draft.text = t
	end)
	local choices = { { id = "", name = "No lever (proclamation only)" } }
	for _, l in decrees.levers or {} do
		table.insert(choices, l)
	end
	for _, c in choices do
		local mark = if draft.lever == c.id then "• " else ""
		local _, b = ui.row(body, o(), mark .. c.name .. (if c.why then " · " .. c.why else ""), { { if draft.lever == c.id then "Chosen" else "Choose" } }, 84)
		b[1].Activated:Connect(function()
			draft.lever = c.id
			render()
		end)
	end
	local _, issue = ui.row(body, o(), "", { { "Issue" } }, 96)
	issue[1].Activated:Connect(function()
		if draft.title == "" or draft.text == "" then
			EconomyUI.toast("A decree needs a title and some words.", true)
			return
		end
		local args: { [string]: any } = { title = draft.title, text = draft.text }
		if draft.lever ~= "" then
			args.lever = draft.lever
		end
		ask("Issue", args, string.format("Issue the decree \"%s\" to the whole city?", draft.title), "Decree")
	end)
end

local function grantSection(o: () -> number)
	local who = target()
	local entry
	for _, e in view.players or {} do
		if e.userId == chosen then
			entry = e
		end
	end
	if not who or not entry then
		chosen = nil
		return
	end
	local r = Stations.BY_ID[entry.role]
	ui.line(body, o(), string.format("%s · %s%s", entry.name, if r then r.name else entry.role, if entry.title then " · " .. entry.title else ""), C.GOLD, 18)
	local places = view.places or Titles.PLACES
	local place = places[placeIndex] or places[1]
	if view.monarch then
		local _, pick = ui.row(body, o(), "Place: " .. tostring(place), { { "◀" }, { "▶" } }, 40)
		pick[1].Activated:Connect(function()
			placeIndex = (placeIndex - 2) % #places + 1
			render()
		end)
		pick[2].Activated:Connect(function()
			placeIndex = placeIndex % #places + 1
			render()
		end)
		for _, rank in Titles.RANK_IDS do
			local cap = (view.caps or {})[rank] or { used = 0, cap = 0 }
			local _, b = ui.row(body, o(), string.format("%s (%d/%d)", rank, cap.used, cap.cap), { { "Grant" } })
			local rk = Titles.rankOf(rank)
			b[1].Activated:Connect(function()
				local what = if rk and rk.peer then string.format("%s of %s", rank, place) else rank
				ask("GrantTitle", { target = who, rank = rank, place = place }, string.format("Make %s %s?", entry.name, what))
			end)
		end
	end
	for _, office in view.appoint or {} do
		local seat = (view.seats or {})[office] or { used = 0, cap = 0 }
		local _, b = ui.row(body, o(), string.format("%s (%d/%d)", Stations.BY_ID[office].name, seat.used, seat.cap), { { "Offer" } })
		b[1].Activated:Connect(function()
			ask("Appoint", { target = who, office = office }, string.format("Offer %s the office of %s?", entry.name, Stations.BY_ID[office].name))
		end)
	end
	if view.monarch then
		local seat = (view.seats or {}).Royal or { used = 0, cap = 0 }
		local _, b = ui.row(body, o(), string.format("Royal family (%d/%d)", seat.used, seat.cap), { { "Invite" } })
		b[1].Activated:Connect(function()
			ask("InviteRoyal", { target = who }, string.format("Invite %s into the royal family?", entry.name))
		end)
	end
	-- revocation, with a reason
	local r2 = Instance.new("Frame")
	r2.LayoutOrder = o()
	r2.BackgroundTransparency = 1
	r2.Size = UDim2.new(1, 0, 0, 34)
	r2.Parent = body
	local reason = ui.text(r2, "TextBox", {
		Name = "Reason",
		Text = "",
		PlaceholderText = "Reason (to take a title or office away)",
		PlaceholderColor3 = C.MUTED,
		ClearTextOnFocus = false,
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(34, 30, 26),
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 2),
	})
	local _, rb = ui.row(body, o(), "Take away:", { { "Title" }, { "Office" } }, 80)
	for k, kind in { "title", "office" } do
		rb[k].Activated:Connect(function()
			if reason.Text == "" then
				EconomyUI.toast("Give a reason first.", true)
				return
			end
			ask("Revoke", { target = who, kind = kind, reason = reason.Text }, string.format("Take %s's %s away?", entry.name, kind))
		end)
	end
	local _, back = ui.row(body, o(), "", { { "Back" } })
	back[1].Activated:Connect(function()
		chosen = nil
		render()
	end)
end

render = function()
	ui.clear(body)
	local o = ui.counter()
	if pending then
		local p = pending
		ui.line(body, o(), p.text, C.GOLD, 19)
		local _, b = ui.row(body, o(), "", { { "Confirm" }, { "Cancel" } }, 96)
		b[1].Activated:Connect(function()
			pending = nil
			if request(p.action, p.args, p.domain) then
				EconomyUI.toast(if p.action == "Appoint" or p.action == "InviteRoyal" then "Offered. Waiting for an answer." else "Done.")
				if p.domain == "Decree" then
					draft = { title = "", text = "", lever = "" }
				end
			end
			fetch()
		end)
		b[2].Activated:Connect(function()
			pending = nil
			render()
		end)
		return
	end
	ui.line(body, o(), "Your style: " .. (if view.style and view.style ~= "" then view.style else "none"), C.INK, 17)
	local _, forms = ui.row(body, o(), "Address me as", { { "Their" }, { "His" }, { "Her" } }, 60)
	for k, form in Titles.FORMS do
		if form == view.form then
			forms[k].Text = "• " .. FORM_LABEL[form]
		end
		forms[k].Activated:Connect(function()
			if request("SetForm", { form = form }) then
				fetch()
			end
		end)
	end
	if view.title then
		local _, b = ui.row(body, o(), "Your title", { { if os.clock() < renounceUntil then "Sure?" else "Renounce" } }, 96)
		b[1].Activated:Connect(function()
			if os.clock() >= renounceUntil then
				renounceUntil = os.clock() + 4
				render()
				return
			end
			renounceUntil = 0
			if request("Renounce") then
				fetch()
			end
		end)
	end
	if view.monarch and not chosen then
		decreeSection(o)
	end
	local grants = view.monarch or #(view.appoint or {}) > 0
	if not grants then
		return
	end
	if (view.cooldown or 0) > 0 then
		ui.line(body, o(), string.format("Next grant in %d s.", view.cooldown), C.MUTED, 15)
	end
	if chosen then
		grantSection(o)
		if chosen then
			return
		end
	end
	ui.line(body, o(), "Choose who to honour or appoint:", C.MUTED, 16)
	for _, e in view.players or {} do
		if e.userId ~= player.UserId then
			local r = Stations.BY_ID[e.role]
			local label = e.name .. (if e.title then " · " .. e.title elseif r and e.role ~= "Citizen" then " · " .. r.name else "")
			local _, b = ui.row(body, o(), label, { { "Choose" } }, 84)
			b[1].Activated:Connect(function()
				chosen = e.userId
				render()
			end)
		end
	end
end

local function refreshOffer()
	local o = offer
	if o and os.clock() >= o.endsAt then
		offer = nil
	end
	offerFrame.Visible = offer ~= nil
	if offer then
		offerText.Text = string.format("%s (%d s)", offer.text, math.ceil(offer.endsAt - os.clock()))
	end
end

local function answer(accept: boolean)
	local o = offer
	if not o then
		return
	end
	offer = nil
	refreshOffer()
	if request("Answer", { id = o.id, accept = accept }) and accept then
		EconomyUI.toast("Accepted.")
	end
end

function CourtUI.state(): ({ [string]: any }, { id: number, endsAt: number, text: string }?)
	return view, offer
end

-- The decree banner everyone sees.
function CourtUI.showDecree(msg: { [string]: any })
	decreeShown += 1
	local shown = decreeShown
	local head = decreeFrame:FindFirstChild("Head") :: TextLabel
	local words = decreeFrame:FindFirstChild("Words") :: TextLabel
	head.Text = "ROYAL DECREE · " .. string.upper(tostring(msg.title))
	words.Text = string.format("%s\n— %s", tostring(msg.text), tostring(msg.by))
	decreeFrame.Visible = true
	if type(msg.bell) == "number" and msg.bell ~= 0 then
		local bell = Instance.new("Sound")
		bell.SoundId = "rbxassetid://" .. msg.bell
		bell.Parent = decreeFrame
		bell:Play()
		bell.Ended:Connect(function()
			bell:Destroy()
		end)
	end
	task.delay(Config.DECREE_SHOW_SECONDS, function()
		if decreeShown == shown then
			decreeFrame.Visible = false
		end
	end)
end

function CourtUI.open()
	panel.Visible = true
	chosen, pending = nil, nil
	fetch()
end

function CourtUI.init()
	local gui = EconomyUI.gui()
	button = ui.button(gui, "Court", { Name = "CourtButton", Position = UDim2.fromOffset(12, 140), Size = UDim2.fromOffset(96, 28), TextSize = 16, Visible = false })
	panel, body = ui.panel("CourtPanel", "The Court")
	button.Activated:Connect(function()
		if panel.Visible then
			panel.Visible = false
		else
			CourtUI.open()
		end
	end)

	offerFrame = Instance.new("Frame")
	offerFrame.Name = "CourtOffer"
	offerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	offerFrame.Position = UDim2.fromScale(0.5, 0.5)
	offerFrame.Size = UDim2.fromOffset(340, 120)
	offerFrame.BackgroundColor3 = C.PAPER
	offerFrame.BorderSizePixel = 0
	offerFrame.Visible = false
	offerFrame.Parent = gui
	offerText = ui.text(offerFrame, "TextLabel", { Name = "Text", TextWrapped = true, TextSize = 17, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 62) })
	local yes = ui.button(offerFrame, "Accept", { Name = "Accept", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -4, 1, -8), Size = UDim2.fromOffset(120, 34) })
	local no = ui.button(offerFrame, "Decline", { Name = "Decline", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 4, 1, -8), Size = UDim2.fromOffset(120, 34) })
	yes.Activated:Connect(function()
		answer(true)
	end)
	no.Activated:Connect(function()
		answer(false)
	end)

	decreeFrame = Instance.new("Frame")
	decreeFrame.Name = "Decree"
	decreeFrame.AnchorPoint = Vector2.new(0.5, 0)
	decreeFrame.Position = UDim2.new(0.5, 0, 0, 86)
	decreeFrame.Size = UDim2.new(0.9, 0, 0, 168)
	decreeFrame.BackgroundColor3 = C.PAPER
	decreeFrame.BorderSizePixel = 0
	decreeFrame.Visible = false
	decreeFrame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 168)
	limit.Parent = decreeFrame
	ui.text(decreeFrame, "TextLabel", { Name = "Head", Font = Enum.Font.GaramondBold, TextColor3 = C.GOLD, TextSize = 19, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -96, 0, 26) })
	ui.text(decreeFrame, "TextLabel", { Name = "Words", TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 1, -38) })
	local closeDecree = ui.button(decreeFrame, "Close", { Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4), Size = UDim2.fromOffset(78, 26), TextSize = 15 })
	closeDecree.Activated:Connect(function()
		decreeFrame.Visible = false
	end)
	Net.listen("Decree", "Issued", CourtUI.showDecree)
	Net.listen("Decree", "Notice", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)

	Net.listen("Court", "Offer", function(msg)
		offer = { id = msg.id, endsAt = os.clock() + (msg.seconds or 0), text = tostring(msg.text) }
		refreshOffer()
	end)
	Net.listen("Court", "Closed", function(msg)
		if offer and offer.id == msg.id then
			offer = nil
			refreshOffer()
		elseif CLOSED_TEXT[msg.result] then
			EconomyUI.toast(CLOSED_TEXT[msg.result], msg.result ~= "done")
		end
	end)
	Net.listen("Court", "Changed", function()
		if panel.Visible and not pending then
			fetch()
		end
	end)
	Net.listen("Court", "Notice", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)
	for _, attr in { Roles.ROLE_ATTR, Titles.ATTR, "CharSlot" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshButton)
	end
	refreshButton()
	task.spawn(function()
		while true do
			task.wait(0.5)
			if offer then
				refreshOffer()
			end
		end
	end)
end

return CourtUI
