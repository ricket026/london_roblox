-- Shared modules that have no engine dependencies: Money, Hobbies, Names, Looks, Chess.
local Shared = __find("ReplicatedStorage.Shared")
local Money = require(Shared.Money)
local Hobbies = require(Shared.Hobbies)
local Names = require(Shared.Names)
local Looks = require(Shared.Looks)
local Chess = require(Shared.Chess)
local Config = require(Shared.Config)

test("Money.format", function()
	eq(Money.format(270), "£1 2s 6d")
	eq(Money.format(60), "5s")
	eq(Money.format(3), "3d")
	eq(Money.format(0), "0d")
	eq(Money.format(-15), "-1s 3d")
	eq(Money.format(240 * 1234), "£1,234")
	eq(Money.fromLsd(1, 2, 6), 270)
end)

test("Hobbies levels follow 100 * (n-1)^1.5", function()
	eq(Hobbies.level(0), 1)
	eq(Hobbies.level(99), 1)
	eq(Hobbies.level(100), 2)
	eq(Hobbies.xpFor(5), 800)
	eq(Hobbies.level(10 ^ 9), Config.HOBBY_MAX_LEVEL)
end)

test("Names.cleanPart tidies and refuses", function()
	eq((Names.cleanPart("  o'brien-smith ")), "O'Brien-Smith")
	eq((Names.cleanPart("ada")), "Ada")
	local n, why = Names.cleanPart("Lord")
	eq(n, nil)
	ok(why and string.find(why, "Titles"), "reserved word refused")
	ok(Names.cleanPart("Earlington") ~= nil, "a reserved word inside a longer name is fine")
	eq((Names.cleanPart("A")), nil, "too short")
	eq((Names.cleanPart("Bob--Ross")), nil, "double separator")
	eq((Names.cleanPart("Bob-")), nil, "trailing separator")
	eq((Names.cleanPart("R2D2")), nil, "digits")
	ok(Names.isBlocked("Victoria", "Hanover"), "real royal blocked")
end)

test("Looks.clean and repair", function()
	ok(Looks.clean(1, "own", "frock") ~= nil)
	eq(Looks.clean(0, "own", "frock"), nil)
	eq(Looks.clean(1, "nope", "frock"), nil)
	local r = Looks.repair({ skin = 3, hair = "gone", outfit = "frock" })
	eq(r.skin, 3)
	eq(r.hair, Config.HAIR_STYLES[1].id)
	eq(Looks.repair(nil).outfit, Config.OUTFITS[1].id)
end)

local function perft(state, depth)
	if depth == 0 then
		return 1
	end
	local n = 0
	for from = 1, 64 do
		for _, to in Chess.legalFrom(state, from) do
			n += perft(Chess.apply(state, from, to), depth - 1)
		end
	end
	return n
end

test("Chess perft from the start position (the real Luau source)", function()
	local s = Chess.new()
	eq(perft(s, 1), 20)
	eq(perft(s, 2), 400)
	eq(perft(s, 3), 8902)
end)

test("Chess fool's mate is checkmate", function()
	local s = Chess.new()
	local sq = Chess.sq
	for _, m in { { sq(6, 2), sq(6, 3) }, { sq(5, 7), sq(5, 5) }, { sq(7, 2), sq(7, 4) }, { sq(4, 8), sq(8, 4) } } do
		ok(Chess.isLegal(s, m[1], m[2]), "legal move")
		s = Chess.apply(s, m[1], m[2])
	end
	eq(Chess.status(s), "checkmate")
end)
