--!strict
-- Shared.Phrases: the quick-phrase wheel (DESIGN §9 chat-light roleplay, TASKS T05). Game-written
-- period lines sent by id and shown as a speech bubble to everyone, so players can roleplay
-- without typing (Roblox chat can't cross age groups). Add lines freely; ids must stay unique.
--   Phrases.get(id) -> Phrase?    Phrases.CATEGORIES (menu order)    Phrases.EMOTES
local Phrases = {}

export type Phrase = { id: string, text: string, cat: string }

Phrases.CATEGORIES = { "Greetings", "Courtesy", "The Crown", "The Street", "Trade", "The Law", "Feelings", "Farewells" }

local LIST: { { string } } = {
	{ "Greetings", "hello", "Good day!" }, { "Greetings", "morning", "Good morning." }, { "Greetings", "evening", "Good evening." },
	{ "Greetings", "howdo", "How do you do?" }, { "Greetings", "pleased", "Pleased to make your acquaintance." },
	{ "Greetings", "sir", "Good day, sir." }, { "Greetings", "madam", "Good day, madam." },
	{ "Courtesy", "thanks", "Thank you kindly." }, { "Courtesy", "after", "After you." }, { "Courtesy", "pardon", "I beg your pardon." },
	{ "Courtesy", "sorry", "Terribly sorry." }, { "Courtesy", "notatall", "Not at all." }, { "Courtesy", "please", "If you would be so kind." },
	{ "The Crown", "majesty", "Your Majesty." }, { "The Crown", "highness", "Your Royal Highness." },
	{ "The Crown", "godsaveking", "God save the King!" }, { "The Crown", "godsavequeen", "God save the Queen!" },
	{ "The Crown", "cheersking", "Three cheers for the King!" }, { "The Crown", "cheersqueen", "Three cheers for the Queen!" },
	{ "The Crown", "hurrah", "Hip, hip, hurrah!" },
	{ "The Street", "cabsir", "Cab, sir?" }, { "The Street", "cabmadam", "Cab, madam?" }, { "The Street", "flowers", "Fresh flowers! Lovely violets!" },
	{ "The Street", "papers", "Paper! Read all about it!" }, { "The Street", "buns", "Hot buns! Penny a piece!" },
	{ "The Street", "taxi", "Cabby! Over here!" }, { "The Street", "where", "Which way to the Strand?" },
	{ "Trade", "what", "What'll it be?" }, { "Trade", "open", "Come in, we're open!" }, { "Trade", "tuppence", "That'll be tuppence." },
	{ "Trade", "bargain", "A bargain at the price." }, { "Trade", "anything", "Will there be anything else?" },
	{ "The Law", "thief", "Stop, thief!" }, { "The Law", "police", "Help! Police!" }, { "The Law", "moveon", "Move along there." },
	{ "The Law", "allright", "Evening, all." }, { "The Law", "whatsthis", "What's all this, then?" }, { "The Law", "arrest", "You're nicked!" },
	{ "Feelings", "splendid", "Splendid!" }, { "Feelings", "heavens", "Good heavens!" }, { "Feelings", "dear", "Oh dear." },
	{ "Feelings", "hear", "Hear, hear!" }, { "Feelings", "bravo", "Bravo!" }, { "Feelings", "rather", "Rather!" },
	{ "Feelings", "shocking", "Shocking!" },
	{ "Farewells", "goodday", "Good day to you." }, { "Farewells", "cheerio", "Cheerio!" }, { "Farewells", "until", "Until next time." },
	{ "Farewells", "goodnight", "Good night." }, { "Farewells", "bye", "Goodbye." },
}

Phrases.LIST = {} :: { Phrase }
local byId: { [string]: Phrase } = {}
for _, e in LIST do
	local p: Phrase = { cat = e[1], id = e[2], text = e[3] }
	assert(byId[p.id] == nil, "duplicate phrase id " .. p.id)
	byId[p.id] = p
	table.insert(Phrases.LIST, p)
end

function Phrases.get(id: string): Phrase?
	return byId[id]
end

-- Etiquette emotes. builtin = a Roblox default emote (Humanoid:PlayEmote); otherwise the
-- animation id lives in Config.EMOTE_ANIMATIONS (0 until the user publishes one: never guess).
Phrases.EMOTES = {
	{ id = "wave", name = "Wave", builtin = "wave" },
	{ id = "cheer", name = "Cheer", builtin = "cheer" },
	{ id = "point", name = "Point", builtin = "point" },
	{ id = "bow", name = "Bow" },
	{ id = "curtsy", name = "Curtsy" },
	{ id = "doff", name = "Doff hat" },
	{ id = "salute", name = "Salute" },
	{ id = "applaud", name = "Applaud" },
}

return Phrases
