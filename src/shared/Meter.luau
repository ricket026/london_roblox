--!strict
-- Shared.Meter: timing meters for skill minigames (test your strength now; fishing, cricket and
-- rowing later). The server picks the start time (server clock) and period; the client draws the
-- same curve and reports when the player pressed, and the server scores that moment itself.
local Meter = {}

-- 0..1..0 over one period, spending less time near the top so a perfect hit takes timing.
function Meter.value(elapsed: number, period: number): number
	local phase = (elapsed / period) % 1
	local tri = 1 - math.abs(phase * 2 - 1)
	return tri ^ 1.6
end

return Meter
