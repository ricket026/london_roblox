--!strict
-- LondonClient.PropertyUI (stub): homes and shops (PROPERTY.md §8). Plain on purpose (ART §8).
--   Estate agents: the counter kind "estate" in EconomyUI's counter panel: rent or buy each kind,
--     sell back or give up what you have (Property.Rent / Buy / Sell).
--   "Property" button (top right): your properties: address, rent, lock, At Home, name plate,
--     keys (give / change / take back, Property.Key), Build (opens LondonClient.BuildUI).
--   "Report this house": shown when you stand at someone else's house (Property.Report).
-- Server: LondonServer.Property (pushes Property.State, Property.Notice).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Kit = require(Shared:WaitForChild("Kit"))
local EconomyUI = require(script.Parent:WaitForChild("EconomyUI"))
local BuildUI = require(script.Parent:WaitForChild("BuildUI"))

local PropertyUI = {}

local player = Players.LocalPlayer
local ui = EconomyUI.ui
local C = ui.colours

local state: { [string]: any } = { deeds = {} }
local button: TextButton
local panel: Frame
local body: ScrollingFrame
local keysPanel: Frame
local keysBody: ScrollingFrame
local reportButton: TextButton
local reportLot: string? = nil

local PERMS = { "enter", "decorate", "build", "sell" }
local PERM_NAMES = { enter = "Enter", decorate = "Decorate", build = "Build", sell = "Till" }

local function request(action: string, args: { [string]: any }?): (boolean, any)
	local ok, res = Net.request("Property", action, args)
	if not ok then
		EconomyUI.toast(tostring(res), true)
	end
	return ok, res
end

local function rootPos(p: Player): Vector3?
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp.Position else nil
end

local function plotsFolder(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Plots")
end

-- The plot (with lot attributes) that contains a world point, if any.
local function plotAt(pos: Vector3, margin: number): Instance?
	local plots = plotsFolder()
	if not plots then
		return nil
	end
	for _, p in plots:GetChildren() do
		local f = Kit.lotFrame(p)
		local w, d = p:GetAttribute("LotW"), p:GetAttribute("LotD")
		if f and type(w) == "number" and type(d) == "number" then
			local rel = pos - f.origin
			local x, z = rel:Dot(f.right), rel:Dot(f.inward)
			if x >= -margin and x <= w + margin and z >= -Kit.FRONT_OUT - margin and z <= d + margin and math.abs(rel.Y) < 60 then
				return p
			end
		end
	end
	return nil
end

-- My properties ----------------------------------------------------------------------------
local renderPanel: () -> ()
local openKeys: (deed: { [string]: any }) -> ()

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- "28 Oct" (the table form of os.date works everywhere in Roblox).
local function dateText(t: number): string
	local d = os.date("*t", t) :: any
	return string.format("%d %s", d.day, MONTHS[d.month])
end

renderPanel = function()
	ui.clear(body)
	local o = ui.counter()
	local deeds = state.deeds or {}
	ui.line(body, o(), string.format("Homes %d of %d · businesses %d of %d", state.homes or 0, state.maxHomes or Config.PROPERTY_HOMES, state.businesses or 0, state.maxBusinesses or Config.PROPERTY_BUSINESSES), C.MUTED, 16)
	if #deeds == 0 then
		ui.line(body, o(), "You haven't a home yet. Estate agents in Mayfair, Holborn, Covent Garden and Spitalfields let and sell them.", C.MUTED)
	end
	for _, d in deeds do
		local title = (if d.name ~= "" then d.name .. ", " else "") .. (d.address or d.kindName)
		ui.line(body, o(), title, C.GOLD, 19)
		local terms = if d.tenure == "own" then "Owned" else string.format("Rented, %s a week, paid to %s", d.rentText or "?", dateText(d.paidUntil or 0))
		if d.lapsed then
			ui.line(body, o(), d.kindName .. " · the tenancy has ended. Rent one again at an estate agent to get it back, as you left it.", C.ERROR, 16)
		else
			ui.line(body, o(), d.kindName .. " · " .. terms .. (if d.lot then "" else " · no plot in this server yet"), C.MUTED, 16)
			local _, b = ui.row(body, o(), "", {
				{ if d.locked then "Unlock" else "Lock" },
				{ if d.atHome then "Not at home" else "At home" },
				{ "Keys" },
				{ "Build" },
			}, 86)
			b[1].Activated:Connect(function()
				request("Lock", { deed = d.id, locked = not d.locked })
			end)
			b[2].Activated:Connect(function()
				request("AtHome", { deed = d.id, on = not d.atHome })
			end)
			b[3].Activated:Connect(function()
				openKeys(d)
			end)
			b[4].Activated:Connect(function()
				if not d.lot then
					EconomyUI.toast("It has no plot in this server yet.", true)
					return
				end
				panel.Visible = false
				BuildUI.enter(d.lot)
			end)
			-- name plate
			local r = Instance.new("Frame")
			r.LayoutOrder = o()
			r.BackgroundTransparency = 1
			r.Size = UDim2.new(1, 0, 0, 34)
			r.Parent = body
			local box = ui.text(r, "TextBox", {
				Text = d.name or "",
				PlaceholderText = "House name (optional)",
				PlaceholderColor3 = C.MUTED,
				ClearTextOnFocus = false,
				BackgroundTransparency = 0,
				BackgroundColor3 = Color3.fromRGB(34, 30, 26),
				Size = UDim2.new(1, -96, 0, 30),
				Position = UDim2.fromOffset(0, 2),
			})
			local save = ui.button(r, "Name", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(88, 30) })
			save.Activated:Connect(function()
				if request("Name", { deed = d.id, text = box.Text }) then
					EconomyUI.toast("Name plate changed.")
				end
			end)
		end
	end
end

-- Keys -----------------------------------------------------------------------------------------
openKeys = function(d: { [string]: any })
	ui.clear(keysBody)
	local o = ui.counter()
	ui.line(keysBody, o(), "Key holders may: Enter (open the doors when locked), Decorate (furniture), Build (walls and roofs), Till (run the shop).", C.MUTED, 15)
	local holders: { [number]: boolean } = {}
	for _, k in d.keys or {} do
		holders[k.userId] = true
		local perms = table.clone(k.perms or {})
		ui.line(keysBody, o(), k.name or ("Player " .. tostring(k.userId)), C.INK, 18)
		local labels = {}
		for i, perm in PERMS do
			labels[i] = { (if perms[perm] then "✓ " else "") .. PERM_NAMES[perm] }
		end
		table.insert(labels, { "Take back" })
		local _, b = ui.row(keysBody, o(), "", labels, 78)
		for i, perm in PERMS do
			b[i].Activated:Connect(function()
				perms[perm] = not perms[perm]
				request("Key", { deed = d.id, userId = k.userId, enter = perms.enter == true, decorate = perms.decorate == true, build = perms.build == true, sell = perms.sell == true })
			end)
		end
		b[#PERMS + 1].Activated:Connect(function()
			request("Key", { deed = d.id, userId = k.userId, enter = false, decorate = false, build = false, sell = false })
		end)
	end
	ui.line(keysBody, o(), "Give a key (enter and decorate) to someone near you:", C.MUTED, 16)
	local me = rootPos(player)
	local any = false
	for _, p in Players:GetPlayers() do
		local pos = rootPos(p)
		if p ~= player and not holders[p.UserId] and me and pos and (pos - me).Magnitude <= 20 then
			any = true
			local n = p:GetAttribute("RPName")
			local _, b = ui.row(keysBody, o(), if type(n) == "string" then n else p.DisplayName, { { "Give key" } }, 96)
			b[1].Activated:Connect(function()
				request("Key", { deed = d.id, userId = p.UserId, enter = true, decorate = true, build = false, sell = false })
			end)
		end
	end
	if not any then
		ui.line(keysBody, o(), "Nobody is close enough.", C.MUTED)
	end
	keysPanel:SetAttribute("Deed", d.id)
	keysPanel.Visible = true
	panel.Visible = false
end

-- Estate agents --------------------------------------------------------------------------------
local function estate(cbody: ScrollingFrame, msg: { [string]: any }, o: () -> number)
	ui.line(cbody, o(), "To let or for sale in this part of London:", C.MUTED, 16)
	for _, k in msg.kinds or {} do
		ui.line(cbody, o(), string.format("%s · %d storeys · %d free here", k.name, k.storeys, k.free), C.INK, 18)
		local _, b = ui.row(cbody, o(), "", { { "Rent " .. k.rentText .. " a week" }, { "Buy " .. k.buyText } }, 150)
		b[1].Activated:Connect(function()
			local ok, res = request("Rent", { counter = msg.id, kind = k.kind })
			if ok then
				EconomyUI.toast(if res.address then "Your new home: " .. res.address .. "." else "Rented; it will appear when a plot is free.")
			end
		end)
		b[2].Activated:Connect(function()
			local ok, res = request("Buy", { counter = msg.id, kind = k.kind })
			if ok then
				EconomyUI.toast(if res.address then "Bought: " .. res.address .. "." else "Bought; it will appear when a plot is free.")
			end
		end)
	end
	if #(msg.deeds or {}) > 0 then
		ui.line(cbody, o(), "Yours:", C.MUTED, 16)
	end
	for _, d in msg.deeds or {} do
		local label = (d.address or d.kindName) .. (if d.lapsed then " (ended)" else "")
		local action = if d.tenure == "own" then "Sell for " .. (d.sellText or "?") else "Give up"
		local _, b = ui.row(cbody, o(), label, { { action } }, 140)
		local armed = false
		b[1].Activated:Connect(function()
			if not armed then
				armed = true
				b[1].Text = "Sure? Press again"
				return
			end
			local ok, res = request("Sell", { counter = msg.id, deed = d.id })
			if ok then
				EconomyUI.toast(if res.paid > 0 then "Sold for " .. res.paidText .. "; your furniture is in storage." else "Given up; your furniture is in storage.")
				b[1].Text = "Done"
				b[1].Active = false
			end
		end)
	end
end

-- Report -----------------------------------------------------------------------------------
local function refreshReport()
	local pos = rootPos(player)
	local plot = if pos then plotAt(pos, 6) else nil
	local owner = plot and plot:GetAttribute("LotOwner")
	reportLot = if plot and type(owner) == "number" and owner ~= player.UserId then plot.Name else nil
	reportButton.Visible = reportLot ~= nil and player:GetAttribute("CharSlot") ~= nil
end

local function openReport()
	local lot = reportLot
	if not lot then
		return
	end
	ui.clear(keysBody)
	local o = ui.counter()
	ui.line(keysBody, o(), "Report this house to the moderators. Why?", C.INK)
	for _, reason in Config.REPORT_REASONS do
		local _, b = ui.row(keysBody, o(), reason, { { "Report" } }, 96)
		b[1].Activated:Connect(function()
			if request("Report", { lot = lot, reason = reason }) then
				EconomyUI.toast("Thank you; it has been noted.")
				keysPanel.Visible = false
			end
		end)
	end
	keysPanel.Visible = true
end

function PropertyUI.apply(s: any)
	if type(s) ~= "table" then
		return
	end
	state = s
	if panel.Visible then
		renderPanel()
	end
	local open = keysPanel:GetAttribute("Deed")
	if keysPanel.Visible and type(open) == "string" then
		for _, d in state.deeds or {} do
			if d.id == open then
				openKeys(d)
			end
		end
	end
end

function PropertyUI.init()
	local gui = EconomyUI.gui()
	button = ui.button(gui, "Property", { Name = "PropertyButton", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 92), Size = UDim2.fromOffset(84, 34), Visible = false })
	panel, body = ui.panel("PropertyPanel", "Your properties")
	keysPanel, keysBody = ui.panel("KeysPanel", "Keys")
	reportButton = ui.button(gui, "Report this house", { Name = "ReportButton", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 132), Size = UDim2.fromOffset(150, 30), TextSize = 16, Visible = false })
	button.Activated:Connect(function()
		panel.Visible = not panel.Visible
		keysPanel.Visible = false
		if panel.Visible then
			renderPanel()
			ui.focus(panel:FindFirstChild("Close") :: GuiObject?)
		end
	end)
	reportButton.Activated:Connect(openReport)
	local function refreshButton()
		button.Visible = player:GetAttribute("CharSlot") ~= nil
		if not button.Visible then
			panel.Visible = false
			keysPanel.Visible = false
		end
	end
	player:GetAttributeChangedSignal("CharSlot"):Connect(refreshButton)
	refreshButton()
	EconomyUI.onCounter("estate", estate)
	Net.listen("Property", "State", PropertyUI.apply)
	Net.listen("Property", "Notice", function(msg)
		if type(msg.text) == "string" then
			EconomyUI.toast(msg.text)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			refreshReport()
		end
	end)
end

return PropertyUI
