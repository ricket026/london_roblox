--!strict
-- Shared.Chess: chess rules, used by the server (authority) and the client (move hints).
-- Squares are 1..64: a1 = 1, h1 = 8, a8 = 57. Pieces are "wK", "bP"...; empty squares are "".
-- Full rules: castling, en passant, promotion (always to a queen), check, checkmate, stalemate,
-- the fifty-move rule and bare kings. No threefold repetition (players can agree a draw).
local Chess = {}

export type State = {
	board: { string }, -- 64 entries
	turn: string, -- "w" or "b"
	castle: { [string]: boolean }, -- wK, wQ, bK, bQ
	ep: number, -- en passant target square, 0 = none
	halfmove: number, -- plies since the last capture or pawn move
	plies: number,
}
export type Move = { from: number, to: number }

local function sq(file: number, rank: number): number?
	if file < 1 or file > 8 or rank < 1 or rank > 8 then
		return nil
	end
	return (rank - 1) * 8 + file
end
Chess.sq = sq

function Chess.fileRank(i: number): (number, number)
	return (i - 1) % 8 + 1, (i - 1) // 8 + 1
end
local fileRank = Chess.fileRank

local function other(c: string): string
	return if c == "w" then "b" else "w"
end

local KNIGHT = { { 1, 2 }, { 2, 1 }, { -1, 2 }, { -2, 1 }, { 1, -2 }, { 2, -1 }, { -1, -2 }, { -2, -1 } }
local KING = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
local ROOK = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local BISHOP = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

function Chess.new(): State
	local board = table.create(64, "")
	local back = { "R", "N", "B", "Q", "K", "B", "N", "R" }
	for f = 1, 8 do
		board[f] = "w" .. back[f]
		board[8 + f] = "wP"
		board[48 + f] = "bP"
		board[56 + f] = "b" .. back[f]
	end
	return { board = board, turn = "w", castle = { wK = true, wQ = true, bK = true, bQ = true }, ep = 0, halfmove = 0, plies = 0 }
end

-- Is square i attacked by colour `by`?
function Chess.attacked(board: { string }, i: number, by: string): boolean
	local f, r = fileRank(i)
	local dir = if by == "w" then -1 else 1 -- attacking pawns sit one rank behind, from their side
	for _, df in { -1, 1 } do
		local s = sq(f + df, r + dir)
		if s and board[s] == by .. "P" then
			return true
		end
	end
	for _, d in KNIGHT do
		local s = sq(f + d[1], r + d[2])
		if s and board[s] == by .. "N" then
			return true
		end
	end
	for _, d in KING do
		local s = sq(f + d[1], r + d[2])
		if s and board[s] == by .. "K" then
			return true
		end
	end
	local function slide(dirs: { { number } }, a: string, b: string): boolean
		for _, d in dirs do
			local nf, nr = f + d[1], r + d[2]
			local s = sq(nf, nr)
			while s do
				local p = board[s]
				if p ~= "" then
					if p == by .. a or p == by .. b then
						return true
					end
					break
				end
				nf += d[1]
				nr += d[2]
				s = sq(nf, nr)
			end
		end
		return false
	end
	return slide(ROOK, "R", "Q") or slide(BISHOP, "B", "Q")
end

local function kingSquare(board: { string }, c: string): number
	return table.find(board, c .. "K") or 0
end

function Chess.inCheck(state: State, c: string?): boolean
	local col = c or state.turn
	local k = kingSquare(state.board, col)
	return k ~= 0 and Chess.attacked(state.board, k, other(col))
end

-- Moves for the piece on `from` that may leave its own king in check.
local function pseudo(state: State, from: number): { number }
	local board = state.board
	local piece = board[from]
	local out = {}
	if piece == "" then
		return out
	end
	local c, kind = string.sub(piece, 1, 1), string.sub(piece, 2, 2)
	local f, r = fileRank(from)
	local function add(s: number?): boolean -- true = keep sliding
		if not s then
			return false
		end
		local p = board[s]
		if p == "" then
			table.insert(out, s)
			return true
		end
		if string.sub(p, 1, 1) ~= c then
			table.insert(out, s)
		end
		return false
	end
	if kind == "P" then
		local dir = if c == "w" then 1 else -1
		local one = sq(f, r + dir)
		if one and board[one] == "" then
			table.insert(out, one)
			local startRank = if c == "w" then 2 else 7
			local two = sq(f, r + 2 * dir)
			if r == startRank and two and board[two] == "" then
				table.insert(out, two)
			end
		end
		for _, df in { -1, 1 } do
			local s = sq(f + df, r + dir)
			if s and ((board[s] ~= "" and string.sub(board[s], 1, 1) ~= c) or s == state.ep) then
				table.insert(out, s)
			end
		end
	elseif kind == "N" or kind == "K" then
		for _, d in (if kind == "N" then KNIGHT else KING) do
			add(sq(f + d[1], r + d[2]))
		end
		if kind == "K" then
			local home = if c == "w" then 1 else 8
			local foe = other(c)
			if r == home and f == 5 and not Chess.attacked(board, from, foe) then
				local function clear(files: { number }): boolean
					for _, ff in files do
						if board[sq(ff, home) :: number] ~= "" then
							return false
						end
					end
					return true
				end
				if state.castle[c .. "K"] and board[sq(8, home) :: number] == c .. "R" and clear({ 6, 7 })
					and not Chess.attacked(board, sq(6, home) :: number, foe) then
					table.insert(out, sq(7, home) :: number)
				end
				if state.castle[c .. "Q"] and board[sq(1, home) :: number] == c .. "R" and clear({ 2, 3, 4 })
					and not Chess.attacked(board, sq(4, home) :: number, foe) then
					table.insert(out, sq(3, home) :: number)
				end
			end
		end
	else
		local dirs = if kind == "R" then ROOK elseif kind == "B" then BISHOP else KING
		for _, d in dirs do
			local nf, nr = f + d[1], r + d[2]
			while add(sq(nf, nr)) do
				nf += d[1]
				nr += d[2]
			end
		end
	end
	return out
end

-- Returns the position after a move (no legality check; see Chess.legalFrom).
function Chess.apply(state: State, from: number, to: number): State
	local board = table.clone(state.board)
	local piece = board[from]
	local c, kind = string.sub(piece, 1, 1), string.sub(piece, 2, 2)
	local captured = board[to] ~= ""
	local castle = table.clone(state.castle)
	local ff, fr = fileRank(from)
	local tf, tr = fileRank(to)
	local ep = 0
	board[to] = piece
	board[from] = ""
	if kind == "P" then
		if to == state.ep and tf ~= ff then -- en passant: the captured pawn sits beside us
			board[sq(tf, fr) :: number] = ""
			captured = true
		end
		if math.abs(tr - fr) == 2 then
			ep = sq(ff, (fr + tr) // 2) :: number
		end
		if tr == 8 or tr == 1 then
			board[to] = c .. "Q"
		end
	elseif kind == "K" then
		castle[c .. "K"] = false
		castle[c .. "Q"] = false
		if math.abs(tf - ff) == 2 then -- castling: bring the rook across
			local rookFrom = sq(if tf == 7 then 8 else 1, fr) :: number
			local rookTo = sq(if tf == 7 then 6 else 4, fr) :: number
			board[rookTo] = board[rookFrom]
			board[rookFrom] = ""
		end
	end
	-- a rook leaving or being taken on its corner loses that castling right
	for corner, right in { [1] = "wQ", [8] = "wK", [57] = "bQ", [64] = "bK" } do
		if from == corner or to == corner then
			castle[right] = false
		end
	end
	return {
		board = board,
		turn = other(c),
		castle = castle,
		ep = ep,
		halfmove = if captured or kind == "P" then 0 else state.halfmove + 1,
		plies = state.plies + 1,
	}
end

-- Legal destination squares for the piece on `from` (empty if it isn't that side's turn).
function Chess.legalFrom(state: State, from: number): { number }
	local piece = state.board[from]
	if piece == "" or string.sub(piece, 1, 1) ~= state.turn then
		return {}
	end
	local out = {}
	for _, to in pseudo(state, from) do
		if not Chess.inCheck(Chess.apply(state, from, to), state.turn) then
			table.insert(out, to)
		end
	end
	return out
end

function Chess.isLegal(state: State, from: number, to: number): boolean
	return table.find(Chess.legalFrom(state, from), to) ~= nil
end

local function hasMove(state: State): boolean
	for i = 1, 64 do
		if #Chess.legalFrom(state, i) > 0 then
			return true
		end
	end
	return false
end

-- "play", "check", "checkmate", "stalemate", "fifty" or "bare" (only kings left).
function Chess.status(state: State): string
	if not hasMove(state) then
		return if Chess.inCheck(state) then "checkmate" else "stalemate"
	end
	if state.halfmove >= 100 then
		return "fifty"
	end
	local pieces = 0
	for _, p in state.board do
		if p ~= "" then
			pieces += 1
		end
	end
	if pieces == 2 then
		return "bare"
	end
	return if Chess.inCheck(state) then "check" else "play"
end

function Chess.isOver(status: string): boolean
	return status ~= "play" and status ~= "check"
end

return Chess
