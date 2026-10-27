--!strict
-- Shared.Text: sanitising (both sides) and TextService filtering (server only).
-- Filtering fails closed: on any error the caller gets nil and must not show the text.
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Config = require(script.Parent.Config)

local Text = {}

-- Strips control characters, collapses whitespace, trims, checks UTF-8, cuts to maxLen characters.
-- Returns nil for non-strings, invalid UTF-8 or absurdly long input.
function Text.sanitize(s: any, maxLen: number): string?
	if type(s) ~= "string" or #s > maxLen * 4 + 64 or utf8.len(s) == nil then
		return nil
	end
	local clean = string.gsub(s, "%c", " ")
	clean = string.gsub(clean, "%s+", " ")
	clean = string.match(clean, "^%s*(.-)%s*$") or ""
	local cut = utf8.offset(clean, maxLen + 1)
	if cut then
		clean = string.sub(clean, 1, cut - 1)
	end
	return clean
end

-- For RichText labels.
function Text.escapeRich(s: string): string
	local out = string.gsub(s, "&", "&amp;")
	out = string.gsub(out, "<", "&lt;")
	out = string.gsub(out, ">", "&gt;")
	out = string.gsub(out, "\"", "&quot;")
	return out
end

local function filterResult(s: string, fromUserId: number): TextFilterResult?
	assert(RunService:IsServer(), "Text filtering is server-only")
	for _ = 1, Config.TEXT_FILTER_RETRIES do
		local ok, res = pcall(TextService.FilterStringAsync, TextService, s, fromUserId, Enum.TextFilterContext.PublicChat)
		if ok then
			return res
		end
		task.wait(0.5)
	end
	return nil
end

-- Text everyone may see (decrees, names, signs).
function Text.filterBroadcast(s: string, fromUserId: number): string?
	local r = filterResult(s, fromUserId)
	if not r then
		return nil
	end
	local ok, out = pcall(r.GetNonChatStringForBroadcastAsync, r)
	return if ok then out else nil
end

-- Text shown to one user (staff reasons, private notes).
function Text.filterFor(s: string, fromUserId: number, toUserId: number): string?
	local r = filterResult(s, fromUserId)
	if not r then
		return nil
	end
	local ok, out = pcall(r.GetNonChatStringForUserAsync, r, toUserId)
	return if ok then out else nil
end

return Text
