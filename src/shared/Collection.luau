--!strict
-- Shared.Collection: every collectable for the collection book (ACTIVITIES §4).
-- Saved in the profile as collection[id] = count. value = pence paid when found (mudlark
-- finds are "sold" on the spot); weight = relative find chance inside its source table.
-- Finds are free to dig, so chance here is not paid chance (ACTIVITIES §1).
local Collection = {}

export type Item = {
	id: string,
	name: string,
	page: string, -- collection book page
	value: number, -- pence
	weight: number?, -- for random finds
	source: string?, -- which activity rolls this item
}

Collection.PAGES = { "Birds of the Park", "Mudlark Finds" }

Collection.ITEMS = {
	{ id = "bird_mallard", name = "Mallard", page = "Birds of the Park", value = 0 },
	{ id = "bird_pigeon", name = "London Pigeon", page = "Birds of the Park", value = 0 },
	{ id = "bird_swan", name = "Mute Swan", page = "Birds of the Park", value = 0 },
	{ id = "bird_pelican", name = "Pelican", page = "Birds of the Park", value = 0 },

	{ id = "mud_pipe", name = "Clay Pipe Stem", page = "Mudlark Finds", value = 1, weight = 40, source = "Mudlark" },
	{ id = "mud_bottle", name = "Ginger Beer Bottle", page = "Mudlark Finds", value = 1, weight = 22, source = "Mudlark" },
	{ id = "mud_button", name = "Brass Button", page = "Mudlark Finds", value = 2, weight = 18, source = "Mudlark" },
	{ id = "mud_farthing", name = "Worn Farthing", page = "Mudlark Finds", value = 1, weight = 14, source = "Mudlark" },
	{ id = "mud_token", name = "Tradesman's Token", page = "Mudlark Finds", value = 3, weight = 7, source = "Mudlark" },
	{ id = "mud_georgian", name = "Georgian Penny", page = "Mudlark Finds", value = 6, weight = 4, source = "Mudlark" },
	{ id = "mud_pin", name = "Tudor Dress Pin", page = "Mudlark Finds", value = 8, weight = 2, source = "Mudlark" },
	{ id = "mud_ring", name = "Silver Ring", page = "Mudlark Finds", value = 9, weight = 1.5, source = "Mudlark" },
	{ id = "mud_roman", name = "Roman Coin", page = "Mudlark Finds", value = 12, weight = 0.8, source = "Mudlark" },
} :: { Item }

Collection.BY_ID = {} :: { [string]: Item }
for _, it in Collection.ITEMS do
	Collection.BY_ID[it.id] = it
end

-- Weighted pick among the items of one source.
function Collection.roll(source: string, rng: Random): Item
	local total = 0
	for _, it in Collection.ITEMS do
		if it.source == source then
			total += it.weight or 0
		end
	end
	local x = rng:NextNumber() * total
	local last: Item? = nil
	for _, it in Collection.ITEMS do
		if it.source == source then
			x -= it.weight or 0
			last = it
			if x <= 0 then
				return it
			end
		end
	end
	return assert(last, "no items for source " .. source)
end

return Collection
