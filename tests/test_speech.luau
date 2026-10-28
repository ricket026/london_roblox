-- T05: quick phrases as speech bubbles, the chat line for those nearby, and the Say panel.
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0 -- daily money is tested in test_daily; keep balances exact here
local Net = require(Shared.Net)
local Phrases = require(Shared.Phrases)

__run(__find("ServerScriptService.LondonServer"))

local function call(p, domain, action, args)
	local msg = table.clone(args or {})
	msg.t = action
	return Net._dispatch(p, domain, msg, true)
end
local function join(id, name)
	local p = __addPlayer(id, name)
	for _ = 1, 200 do
		if p:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	assert(call(p, "Character", "Create", { slot = "1", first = name, last = "Tester", skin = 1, hair = "own", outfit = "frock" }).ok)
	return p
end
local function stand(p, at)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(at)
end

test("every phrase has a category in the menu and fits a bubble", function()
	ok(#Phrases.LIST >= 40)
	for _, p in Phrases.LIST do
		ok(table.find(Phrases.CATEGORIES, p.cat) ~= nil, p.id)
		ok(#p.text <= 40, p.id .. " is short enough for a bubble")
	end
end)

local A, B, SpeechUI
test("saying a phrase from the panel: a bubble for everyone, a chat line nearby", function()
	A = join(1201, "Alfred")
	__asClient(A, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		SpeechUI = require(__find(root .. "SpeechUI"))
		SpeechUI.init()
	end)
	B = join(1202, "Beatrice")
	local far = join(1203, "Faraway")
	stand(A, Vector3.new(0, 3, 0))
	stand(B, Vector3.new(10, 3, 0))
	stand(far, Vector3.new(500, 3, 0))
	local gui = A.PlayerGui.Economy
	ok(gui.SayButton.Visible)
	gui.SayButton.Activated:Fire()
	ok(gui.SpeechPanel.Visible)
	local hello
	for _, d in gui.SpeechPanel:GetDescendants() do
		if d:IsA("TextButton") and d.Text == "Good day!" then
			hello = d
		end
	end
	hello.Activated:Fire()
	local bubble = A.Character.Head:FindFirstChild("Speech")
	ok(bubble ~= nil, "a bubble over Alfred's head")
	eq(bubble:FindFirstChildWhichIsA("TextLabel").Text, "Good day!")
	eq(gui.SpeechPanel.Visible, false, "the panel closes")
	local heard = __received(B, "PhraseEvent", "Said")
	eq(#heard, 1)
	eq(heard[1].from, "Alfred Tester")
	eq(#__received(far, "PhraseEvent", "Said"), 0, "too far to hear")
	__advance(Config.SPEECH_SECONDS + 0.5)
	eq(A.Character.Head:FindFirstChild("Speech"), nil, "and it goes")
end)

test("unknown phrases and spamming are refused", function()
	SpeechUI.say("not_a_phrase")
	eq(A.Character.Head:FindFirstChild("Speech"), nil)
	__advance(Config.SPEECH_RATE.per) -- a fresh rate window
	for _ = 1, Config.SPEECH_RATE.count + 2 do
		SpeechUI.say("bravo")
	end
	eq(#__received(B, "PhraseEvent", "Said"), 1 + Config.SPEECH_RATE.count, "rate limited")
end)

test("gestures without an animation say so", function()
	eq(SpeechUI.emote("bow"), false)
	ok(string.find(A.PlayerGui.Economy.Toast.Text, "isn't ready"), A.PlayerGui.Economy.Toast.Text)
end)
