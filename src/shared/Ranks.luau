--!strict
-- Shared.Ranks: job ranks (JOBS.md §1). XP to reach rank n is Config.JOB_RANK_XP * n ^ JOB_RANK_EXP
-- (cumulative; rank 1 needs none): r2 455, r3 870, r4 1380, r5 1970. Pay rises
-- Config.JOB_RANK_PAY per rank above 1.
--   Ranks.xpFor(rank) -> xp     Ranks.rankFor(xp) -> rank     Ranks.payMultiplier(rank) -> number
local Config = require(script.Parent:WaitForChild("Config"))

local Ranks = {}

function Ranks.xpFor(rank: number): number
	if rank <= 1 then
		return 0
	end
	return math.floor(Config.JOB_RANK_XP * rank ^ Config.JOB_RANK_EXP)
end

function Ranks.rankFor(xp: number): number
	local r = 1
	while r < Config.JOB_MAX_RANK and xp >= Ranks.xpFor(r + 1) do
		r += 1
	end
	return r
end

function Ranks.payMultiplier(rank: number): number
	return 1 + Config.JOB_RANK_PAY * (math.clamp(rank, 1, Config.JOB_MAX_RANK) - 1)
end

return Ranks
