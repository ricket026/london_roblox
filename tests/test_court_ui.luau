-- T35: the Court offer popup and button for the one offered (one client per file in this harness).
local Shared = __find("ReplicatedStorage.Shared")
local Config = require(Shared.Config)
Config.STIPEND_PER_DAY, Config.DAILY_TASK_PAY = 0, 0
Config.GOALS = {} -- the "Next steps" bonuses are tested in test_onboarding
local Net = require(Shared.Net)
local Roles = require(Shared.Roles)

__run(__find("ServerScriptService.LondonServer"))
local LS = "ServerScriptService.LondonServer."
local Profiles = require(__find(LS .. "Profiles"))
local Throne = require(__find(LS .. "Throne"))
local Court = require(__find(LS .. "Court"))

local function join(uid, first, hours)
	local p = __addPlayer(uid, first)
	for _ = 1, 200 do
		if p:GetAttribute("ProfileLoaded") then
			break
		end
		task.wait(0.1)
	end
	local msg = { t = "Create", slot = "1", first = first, last = "Tester", skin = 1, hair = "own", outfit = "frock" }
	ok(Net._dispatch(p, "Character", msg, true).ok)
	Profiles.get(p).playtime = hours * 3600
	return p
end

test("an offered office pops up, counts down and is accepted from the screen", function()
	local K = join(1301, "Kenneth", 3)
	local E = join(1302, "Esme", 1)
	local ui
	__asClient(E, function()
		local root = "StarterPlayer.StarterPlayerScripts.LondonClient."
		require(__find(root .. "EconomyUI")).init()
		ui = require(__find(root .. "CourtUI"))
		ui.init()
	end)
	__advance(0)
	local gui = E.PlayerGui.Economy
	ok(not gui.CourtButton.Visible, "a plain citizen has no Court button")
	ok(Throne.claim(K, "King"))
	ok(Court.appoint(K, E, "PrivateSecretary"))
	ok(gui.CourtOffer.Visible, "the offer shows")
	ok(string.find(gui.CourtOffer.Text.Text, "Private Secretary"), gui.CourtOffer.Text.Text)
	ok(string.find(gui.CourtOffer.Text.Text, "%(30 s%)"), gui.CourtOffer.Text.Text)
	__advance(10)
	ok(string.find(gui.CourtOffer.Text.Text, "%(20 s%)"), "counts down: " .. gui.CourtOffer.Text.Text)
	gui.CourtOffer.Accept.Activated:Fire()
	__advance(0)
	eq(Roles.roleOf(E), "PrivateSecretary")
	ok(not gui.CourtOffer.Visible)
	ok(gui.CourtButton.Visible, "an officer of the Household has the Court button")
	-- an offer that runs out disappears
	__advance(Config.COURT_GRANT_COOLDOWN + 1)
	ok(Court.inviteRoyal(K, E))
	ok(gui.CourtOffer.Visible)
	__advance(Config.COURT_OFFER_SECONDS + 1)
	ok(not gui.CourtOffer.Visible, "gone when it runs out")
	eq(Roles.roleOf(E), "PrivateSecretary")
	-- the panel for a non-granter: style and form only
	gui.CourtButton.Activated:Fire()
	__advance(0)
	ok(gui.CourtPanel.Visible)
	local choose = false
	for _, d in gui.CourtPanel.Body:GetDescendants() do
		if d:IsA("TextButton") and d.Text == "Choose" then
			choose = true
		end
	end
	ok(not choose, "no grant list for a Private Secretary")
	local view = ui.state()
	eq(view.monarch, false)
end)
