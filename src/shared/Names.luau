--!strict
-- Shared.Names: RP name rules (both sides, so the client can explain a refusal before sending)
-- and period suggestions for the name picker's "Suggest" button. The server also filters
-- (Text.filterBroadcast) and checks Config.NAME_BLOCKED.
local Config = require(script.Parent.Config)
local Text = require(script.Parent.Text)

local Names = {}

Names.FIRST = {
	"Arthur", "Albert", "Alfred", "Archibald", "Bertram", "Cecil", "Charles", "Clement", "Edmund",
	"Ernest", "Frederick", "Harold", "Herbert", "Horace", "Jasper", "Leonard", "Percival", "Reginald",
	"Rupert", "Sidney", "Thomas", "Walter", "Wilfred", "Ada", "Agnes", "Beatrice", "Clara", "Constance",
	"Dora", "Edith", "Eleanor", "Florence", "Georgiana", "Harriet", "Ivy", "Lavinia", "Lillian", "Mabel",
	"Maud", "Millicent", "Rosalind", "Violet", "Winifred",
}
Names.LAST = {
	"Ashworth", "Blackwood", "Bramley", "Carlisle", "Cartwright", "Dalton", "Fairfax", "Fletcher",
	"Grimshaw", "Hargreaves", "Hawthorne", "Kingsley", "Lockwood", "Marsh", "Pemberton", "Penrose",
	"Quill", "Radcliffe", "Sedgwick", "Thackeray", "Thornbury", "Wainwright", "Whitlock", "Yardley",
}

function Names.suggest(rng: Random): (string, string)
	return Names.FIRST[rng:NextInteger(1, #Names.FIRST)], Names.LAST[rng:NextInteger(1, #Names.LAST)]
end

-- "o'brien-smith" -> "O'Brien-Smith"
local function capitalise(s: string): string
	local out = string.gsub(string.lower(s), "(%f[%a]%a)", string.upper)
	return out
end

-- Returns the tidied name part, or nil and a reason the player can read.
function Names.cleanPart(s: any): (string?, string?)
	local clean = Text.sanitize(s, Config.NAME_MAX)
	if not clean or clean == "" then
		return nil, "Please enter a name."
	end
	local len = utf8.len(clean) or 0
	if len < Config.NAME_MIN then
		return nil, string.format("Names need at least %d letters.", Config.NAME_MIN)
	end
	if not string.match(clean, "^%a[%a' %-]*%a$") or string.find(clean, "['%- ][' %-]") then
		return nil, "Names may only use letters, one space, hyphen or apostrophe at a time."
	end
	local lower = " " .. string.lower(clean) .. " "
	for _, word in Config.NAME_RESERVED do
		if string.find(lower, "%f[%a]" .. word .. "%f[%A]") then
			return nil, "Titles are granted in the game, not chosen. Please pick another name."
		end
	end
	return capitalise(clean)
end

function Names.isBlocked(first: string, last: string): boolean
	local full = string.lower(first .. " " .. last)
	for _, b in Config.NAME_BLOCKED do
		if full == b then
			return true
		end
	end
	return false
end

return Names
