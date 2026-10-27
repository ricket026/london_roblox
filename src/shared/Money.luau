--!strict
-- Shared.Money: pre-decimal money. Everything is stored as integer pence; this only converts
-- and formats. 12d = 1s, 20s = £1 (240d).
local Config = require(script.Parent.Config)

local Money = {}
local D_PER_S = Config.PENCE_PER_SHILLING
local D_PER_L = Config.PENCE_PER_SHILLING * Config.SHILLINGS_PER_POUND

function Money.fromLsd(pounds: number, shillings: number, pence: number): number
	return pounds * D_PER_L + shillings * D_PER_S + pence
end

-- Returns pounds, shillings, pence of |pence|.
function Money.split(pence: number): (number, number, number)
	local p = math.abs(math.floor(pence))
	return p // D_PER_L, (p % D_PER_L) // D_PER_S, p % D_PER_S
end

local function commas(n: number): string
	local s = tostring(n)
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return s .. out
end

-- 270 -> "£1 2s 6d", 60 -> "5s", 3 -> "3d", 0 -> "0d", -15 -> "-1s 3d"
function Money.format(pence: number): string
	local l, s, d = Money.split(pence)
	local parts = {}
	if l > 0 then
		table.insert(parts, "£" .. commas(l))
	end
	if s > 0 then
		table.insert(parts, s .. "s")
	end
	if d > 0 or #parts == 0 then
		table.insert(parts, d .. "d")
	end
	local out = table.concat(parts, " ")
	return if pence < 0 then "-" .. out else out
end

function Money.isValidAmount(pence: any): boolean
	return type(pence) == "number" and pence % 1 == 0 and pence >= 0 and pence <= Config.PENCE_MAX
end

return Money
