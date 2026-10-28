--!strict
-- LondonServer.Economy: the money ledger (ECONOMY.md §7-9). Every change of money goes through
-- here with a reason, so the game knows where money comes from (faucets) and goes (sinks).
--   Economy.change(player, delta, reason, ref?)   wallet +/-; refuses to go below 0 (fines: to -DEBT_MAX)
--   Economy.pay(player, pence, reason, ref?)      into the wallet
--   Economy.charge(player, pence, reason, ref?)   from the wallet, then the bank; all or nothing
--   Economy.deposit / Economy.withdraw(player, pence)   wallet <-> bank
--   Economy.transfer(from, to, pence, reason)     player to player (new-account daily cap)
--   Economy.balance(player) -> wallet, bank;  Economy.recent(player) -> ledger lines;  Economy.totals()
-- Changes of Config.LEDGER_LOG_OVER or more, and every "admin"/"product" change, go to AdminLog.
-- Remotes (Economy domain, calls): Ledger, Bank { counter, action, pence } (at a bank counter).
-- Pushes Profile.Wallet (via Profiles.pushWallet) after every change.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Money = require(Shared:WaitForChild("Money"))
local Profiles = require(script.Parent:WaitForChild("Profiles"))
local AdminLog = require(script.Parent:WaitForChild("AdminLog"))

local Economy = {}

-- Reasons (ECONOMY §8 + SHOPS §10). Faucets bring money into the game, sinks take it out,
-- moves shift it between players or accounts.
Economy.REASONS = {
	job_pay = "faucet", salary = "faucet", pastime = "faucet", fare = "move", prize = "faucet",
	stipend = "faucet", shop_sale = "move", npc_sale = "faucet", wage_staff = "move",
	property_sell = "faucet", product = "faucet", admin = "faucet",
	rent = "sink", tax = "sink", fine = "sink", purchase = "sink", wholesale = "sink",
	delivery = "sink", property_buy = "sink", stall_rent = "sink", character = "sink",
	licence = "sink", hospital = "sink", upkeep = "sink",
	transfer_in = "move", transfer_out = "move", theft_in = "move", theft_out = "move",
	shop_buy = "move", item_trade = "move", deposit = "move", withdraw = "move",
}

export type Line = { t: number, d: number, reason: string, ref: string?, wallet: number, bank: number }

local recentLines: { [Player]: { Line } } = {}
local totals: { [string]: number } = {}

local function record(player: Player, delta: number, reason: string, ref: string?)
	local p = Profiles.get(player)
	if not p then
		return
	end
	local lines = recentLines[player] or {}
	recentLines[player] = lines
	table.insert(lines, 1, { t = os.time(), d = delta, reason = reason, ref = ref, wallet = p.pence, bank = p.bank })
	if #lines > Config.LEDGER_MEMORY then
		table.remove(lines)
	end
	totals[reason] = (totals[reason] or 0) + delta
	if math.abs(delta) >= Config.LEDGER_LOG_OVER or reason == "admin" or reason == "product" then
		AdminLog.add(0, "money:" .. reason, player.UserId, (if delta < 0 then "-" else "+") .. Money.format(math.abs(delta)) .. (if ref then " " .. ref else ""))
	end
end

local function valid(reason: string, pence: number): boolean
	return Economy.REASONS[reason] ~= nil and type(pence) == "number" and pence % 1 == 0
end

function Economy.balance(player: Player): (number, number)
	local p = Profiles.get(player)
	if not p then
		return 0, 0
	end
	return p.pence, p.bank
end

-- Wallet change. Returns ok, or false and a reason the player can read.
function Economy.change(player: Player, delta: number, reason: string, ref: string?): (boolean, string?)
	local p = Profiles.get(player)
	if not p then
		return false, "Your profile isn't loaded yet."
	end
	assert(valid(reason, delta), "Economy.change: bad reason or amount (" .. tostring(reason) .. ", " .. tostring(delta) .. ")")
	local floor = if reason == "fine" then -Config.DEBT_MAX else 0
	local new = p.pence + delta
	if delta < 0 and new < floor then
		return false, "You haven't enough money."
	end
	if new > Config.PENCE_MAX then
		return false, "Your wallet can't hold that much. Bank some first."
	end
	p.pence = new
	record(player, delta, reason, ref)
	Profiles.pushWallet(player)
	return true
end

function Economy.pay(player: Player, pence: number, reason: string, ref: string?): (boolean, string?)
	assert(pence >= 0, "Economy.pay: negative amount")
	return Economy.change(player, pence, reason, ref)
end

-- From the wallet, then the bank. Nothing is taken unless the whole amount can be.
function Economy.charge(player: Player, pence: number, reason: string, ref: string?): (boolean, string?)
	local p = Profiles.get(player)
	if not p then
		return false, "Your profile isn't loaded yet."
	end
	assert(valid(reason, pence) and pence >= 0, "Economy.charge: bad reason or amount")
	if p.pence + p.bank < pence then
		return false, string.format("That costs %s; you have %s.", Money.format(pence), Money.format(math.max(0, p.pence + p.bank)))
	end
	local fromWallet = math.min(math.max(p.pence, 0), pence)
	p.pence -= fromWallet
	p.bank -= pence - fromWallet
	record(player, -pence, reason, ref)
	Profiles.pushWallet(player)
	return true
end

function Economy.deposit(player: Player, pence: number): (boolean, string?)
	local p = Profiles.get(player)
	if not p then
		return false, "Your profile isn't loaded yet."
	end
	if pence <= 0 or pence % 1 ~= 0 then
		return false, "Choose an amount."
	end
	if p.pence < pence then
		return false, "You aren't carrying that much."
	end
	if p.bank + pence > Config.PENCE_MAX then
		return false, "The bank can't hold that much."
	end
	p.pence -= pence
	p.bank += pence
	record(player, 0, "deposit", Money.format(pence))
	Profiles.pushWallet(player)
	return true
end

function Economy.withdraw(player: Player, pence: number): (boolean, string?)
	local p = Profiles.get(player)
	if not p then
		return false, "Your profile isn't loaded yet."
	end
	if pence <= 0 or pence % 1 ~= 0 then
		return false, "Choose an amount."
	end
	if p.bank < pence then
		return false, "You haven't that much in the bank."
	end
	if p.pence + pence > Config.PENCE_MAX then
		return false, "Your wallet can't hold that much."
	end
	p.bank -= pence
	p.pence += pence
	record(player, 0, "withdraw", Money.format(pence))
	Profiles.pushWallet(player)
	return true
end

local function today(): string
	return os.date("!%Y%m%d") :: string
end

-- How much more this account may hand to others today (new-account cap, ECONOMY §7).
function Economy.transferRoom(player: Player): number
	local p = Profiles.get(player)
	if not p then
		return 0
	end
	if Profiles.playtime(player) >= Config.NEW_ACCOUNT_SECONDS then
		return math.huge
	end
	if p.limits.transferDay ~= today() then
		p.limits.transferDay = today()
		p.limits.transferred = 0
	end
	return math.max(0, Config.NEW_ACCOUNT_DAILY_TRANSFER - p.limits.transferred)
end

-- Wallet to wallet. Both players must be loaded; all or nothing.
function Economy.transfer(from: Player, to: Player, pence: number, ref: string?): (boolean, string?)
	local pf, pt = Profiles.get(from), Profiles.get(to)
	if not pf or not pt then
		return false, "That player isn't ready."
	end
	if from == to or pence <= 0 or pence % 1 ~= 0 then
		return false, "Choose an amount."
	end
	if pf.pence < pence then
		return false, "You aren't carrying that much."
	end
	if pence > Economy.transferRoom(from) then
		return false, string.format("New accounts can hand over %s a day.", Money.format(Config.NEW_ACCOUNT_DAILY_TRANSFER))
	end
	if pt.pence + pence > Config.PENCE_MAX then
		return false, "Their wallet can't hold that much."
	end
	pf.pence -= pence
	pt.pence += pence
	if Profiles.playtime(from) < Config.NEW_ACCOUNT_SECONDS then
		pf.limits.transferred += pence
	end
	record(from, -pence, "transfer_out", ref or tostring(to.UserId))
	record(to, pence, "transfer_in", ref or tostring(from.UserId))
	Profiles.pushWallet(from)
	Profiles.pushWallet(to)
	return true
end

function Economy.recent(player: Player): { Line }
	return recentLines[player] or {}
end

-- Server totals per reason since start (faucet vs sink report for the owner).
function Economy.totals(): { [string]: number }
	return table.clone(totals)
end

function Economy.onPlayerRemoving(player: Player)
	recentLines[player] = nil
end

-- isAtBank(player, counterId) is supplied by Counters (avoids a require cycle).
Economy.isAtBank = function(_player: Player, _counter: string): boolean
	return false
end

function Economy.init()
	local V = Net.V
	Net.handle("Economy", "Ledger", { call = true }, function(player)
		local p = Profiles.get(player)
		return { lines = Economy.recent(player), wallet = if p then p.pence else 0, bank = if p then p.bank else 0 }
	end)
	Net.handle("Economy", "Bank", {
		schema = { counter = V.str(40), action = V.enum({ "deposit", "withdraw" }), pence = V.int(1, Config.PENCE_MAX) },
		rate = Config.BANK_RATE,
		call = true,
	}, function(player, a)
		if not Economy.isAtBank(player, a.counter) then
			return nil, "Go to a bank or post office counter."
		end
		local ok, why
		if a.action == "deposit" then
			ok, why = Economy.deposit(player, a.pence)
		else
			ok, why = Economy.withdraw(player, a.pence)
		end
		if not ok then
			return nil, why
		end
		local p = Profiles.get(player)
		return { wallet = if p then p.pence else 0, bank = if p then p.bank else 0 }
	end)
end

return Economy
