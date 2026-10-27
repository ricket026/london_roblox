--!strict
-- LondonClient.Activities.Chess (stub UI): the board for the two seated players.
-- Tap one of your pieces to see its moves (Shared.Chess), tap a square to move. The server
-- checks every move. Spectators watch the board on the table top instead.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Rules = require(Shared:WaitForChild("Chess"))

local Chess = {}

local LIGHT = Color3.fromRGB(222, 205, 170)
local DARK = Color3.fromRGB(120, 85, 55)
local LAST = Color3.fromRGB(205, 180, 90)
local SELECTED = Color3.fromRGB(120, 160, 90)
local TARGET = Color3.fromRGB(150, 190, 120)

local gui: ScreenGui
local header: TextLabel
local statusLabel: TextLabel
local resign: TextButton
local cells: { TextButton } = {} -- indexed by board square 1..64
local current: any = nil
local selected = 0
local targets: { number } = {}

local REASONS = { checkmate = "by checkmate", resigned = "by resignation", time = "on time", stalemate = "stalemate", fifty = "fifty-move rule", bare = "only kings left" }

local function stateOf(s: any): Rules.State
	return { board = s.board, turn = s.turn, castle = s.castle, ep = s.ep, halfmove = s.halfmove, plies = s.plies }
end

local function myTurn(): boolean
	return current ~= nil and current.board ~= nil and current.result == nil and current.turn == current.you
end

local function draw()
	local s = current
	if not s then
		return
	end
	local flip = s.you == "b"
	for i = 1, 64 do
		local b = cells[i]
		local f, r = Rules.fileRank(i)
		local col = if flip then 8 - f else f - 1
		local row = if flip then r - 1 else 8 - r
		b.Position = UDim2.fromScale(col / 8, row / 8)
		local piece = if s.board then s.board[i] else ""
		b.Text = if piece ~= "" then (Config.CHESS_GLYPHS :: any)[string.sub(piece, 2, 2)] or "?" else ""
		b.TextColor3 = if string.sub(piece, 1, 1) == "w" then Color3.fromRGB(250, 248, 240) else Color3.fromRGB(20, 18, 16)
		local colour = if (f + r) % 2 == 0 then DARK else LIGHT
		if s.last and (s.last.from == i or s.last.to == i) then
			colour = LAST
		end
		if i == selected then
			colour = SELECTED
		elseif table.find(targets, i) then
			colour = TARGET
		end
		b.BackgroundColor3 = colour
	end
	header.Text = string.format("White: %s   ·   Black: %s", s.white ~= "" and s.white or "(empty seat)", s.black ~= "" and s.black or "(empty seat)")
	resign.Visible = s.board ~= nil and s.result == nil and s.plies > 0
end

local function statusText(): string
	local s = current
	if not s then
		return ""
	end
	if s.result then
		local why = REASONS[s.reason] or ""
		if s.result == "draw" then
			return "Drawn: " .. why
		end
		return (if s.result == s.you then "You win " else "You lose ") .. why
	end
	if not s.board then
		return if s.white ~= "" and s.black ~= "" then "Setting up the pieces..." else "Waiting for an opponent to sit down"
	end
	local left = if s.deadline then math.max(0, math.floor(s.deadline - workspace:GetServerTimeNow())) else 0
	local who = if myTurn() then "Your move" else "Their move"
	return string.format("%s%s   (%d:%02d)", who, if s.status == "check" then " — check!" else "", left // 60, left % 60)
end

local function click(i: number)
	local s = current
	if not myTurn() then
		return
	end
	if selected ~= 0 and table.find(targets, i) then
		Net.send("Activity", "ChessMove", { table = s.table, from = selected, to = i })
		selected, targets = 0, {}
		draw()
		return
	end
	local piece = s.board[i]
	if piece ~= "" and string.sub(piece, 1, 1) == s.you then
		selected = i
		targets = Rules.legalFrom(stateOf(s), i)
	else
		selected, targets = 0, {}
	end
	draw()
end

function Chess.init(_activities: any)
	gui = Instance.new("ScreenGui")
	gui.Name = "ChessBoard"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.62, 0.62)
	frame.SizeConstraint = Enum.SizeConstraint.RelativeYY -- square, sized from the screen height
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 480)
	limit.Parent = frame
	for i = 1, 64 do
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromScale(1 / 8, 1 / 8)
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		b.TextScaled = true
		b.Font = Enum.Font.SourceSans
		b.TextStrokeTransparency = 0.6
		b.Text = ""
		b.Parent = frame
		b.Activated:Connect(function()
			click(i)
		end)
		cells[i] = b
	end
	local function label(y: number, size: number): TextLabel
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, if y < 0 then 1 else 0)
		l.Position = UDim2.new(0.5, 0, if y < 0 then 0 else 1, y)
		l.Size = UDim2.new(1.4, 0, 0, size + 8)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Garamond
		l.TextSize = size
		l.TextColor3 = Color3.fromRGB(240, 232, 214)
		l.TextStrokeTransparency = 0.4
		l.Parent = frame
		return l
	end
	header = label(-8, 20)
	statusLabel = label(6, 22)
	resign = Instance.new("TextButton")
	resign.AnchorPoint = Vector2.new(0.5, 0)
	resign.Position = UDim2.new(0.5, 0, 1, 42)
	resign.Size = UDim2.fromOffset(140, 38)
	resign.BackgroundColor3 = Color3.fromRGB(60, 52, 42)
	resign.Font = Enum.Font.Garamond
	resign.TextSize = 20
	resign.TextColor3 = Color3.fromRGB(240, 232, 214)
	resign.Text = "Resign"
	resign.Parent = frame
	resign.Activated:Connect(function()
		if current then
			Net.send("Activity", "ChessResign", { table = current.table })
		end
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Net.listen("Activity", "ChessState", function(msg)
		current = msg
		selected, targets = 0, {}
		gui.Enabled = true
		draw()
	end)
	Net.listen("Activity", "ChessLeave", function()
		current = nil
		gui.Enabled = false
	end)
	RunService.Heartbeat:Connect(function()
		if gui.Enabled then
			statusLabel.Text = statusText()
		end
	end)
end

return Chess
