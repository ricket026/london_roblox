# Economy spec

All money is stored as integer **pence**. £1 = 20s = 240d. 1 guinea = 21s = 252d.
Display: `£1 4s 6d`, `7s 6d`, `9d`; prices over £20 may show in guineas (`15 gns`).
All numbers below are starting values in `Config.Economy` and will be tuned in M9.

## 1. Time base
- 1 in-game day = 24 real minutes. 1 real hour = 2.5 in-game days.
- "Per hour" below means per real hour of active play.

## 2. Income targets (per real hour, active)

| Tier | Example roles | Target | Notes |
|---|---|---|---|
| New player | Newsboy, lamplighter rank 1 | £1 10s | Enough for a bicycle in ~5 h |
| Labour (ranked) | Lamplighter 5, postman, baker | £2 10s | |
| Transport | Cabbie, omnibus driver | £3–4 gross | Minus cab hire (§5) |
| Police | Constable → Inspector | £2–3.5 salary + rewards | Salary paid while on duty and active |
| Professions | Physician, journalist, engineer | £3–4 | |
| Offices | Household posts, MPs, ministers | +£2 salary on top | Paid only while present and active |
| Crown / peers | | +£3 "civil list" / estate income | Peers' income scales with rank |

**Active** = has moved or done a job action in the last 3 minutes. No AFK income.

## 3. Prices

| Item | Price | Hours of labour (~£2.5/h) |
|---|---|---|
| Lodging (East End), per real week | £1 | 0.4 |
| Flat (West End), per real week | £4 | 1.6 |
| Townhouse with mews, per real week | £15 | 6 |
| Basic outfit | 5s – £1 | < 0.5 |
| Fine outfit / uniform tailoring | £3 – £10 | 1–4 |
| Court dress / ball gown | 10 – 30 gns | 4–12 |
| Safety bicycle | £8 | 3 |
| Penny-farthing | £6 | 2.5 |
| Riding horse | £25 + feed | 10 |
| Brougham carriage + horse | £120 | 48 |
| Landau | £200 | 80 |
| Motor carriage (2-seat) | 300 gns | 126 |
| Motor tourer (4-seat) | 500 gns | 210 |
| Cab licence | £2 + test | 1 |
| Motor licence | £5 + test | 2 |
| Firearms certificate | £5 | 2 |
| Pocket pistol / service revolver / shotgun | £4 / £8 / £12 | 1.6 / 3 / 5 |
| Ammunition (box) | 1s | – |
| Tea / bun (cosmetic consumable) | 1d – 3d | – |
| Omnibus fare | 1d per stop (max 6d) | – |
| Cab fare | 6d flag + 3d per 100 studs | – |
| Hospital respawn fee | 5s | – |

Motor cars are meant to take dedicated players weeks. That's intentional: they're the status
symbol (DESIGN pillar 5). **Royals and senior officials get state vehicles free while in role**
(VEHICLES §4a); everyone else pays these hefty prices (Q13).

## 4. Money faucets (where money comes from)
Job pay, salaries, NPC fares, event prizes, daily login stipend (1s, streak to 7s at 7 days).

## 5. Money sinks (where it goes)
Rent, vehicle purchase and upkeep (feed 6d per in-game day per horse; motor fuel 1s per tank;
repairs 5s–£5), cab hire from the cab yard (5s per shift if you don't own a cab), licences,
outfits, fines, hospital fee, taxes, cosmetic consumables, house furniture layouts.
Target: sinks remove **~70%** of faucet money at steady state. The ledger (§8) lets us measure it.

## 6. Tax & the Treasury
- **Income tax** on job pay and salaries, set by Parliament: 0–15%, default 5%.
- **Purchase duty** on vehicles and luxury goods: 0–20%, default 10%.
- Taxes go to the **server treasury** (per-server, resets each server start with a seed of
  £200 from the Config).
- The treasury pays: police salaries above the base (police budget lever), event prizes, lamp
  wages bonus, and office salaries. If it runs dry, those bonus payments stop and the Chancellor
  is warned. Base wages never depend on the treasury, so a bad Chancellor can't break new players.

## 7. Bank
- Wallet (carried, can be pickpocketed: 5% up to £2 per theft) vs **bank** (safe).
- Deposit/withdraw at the Bank (City) or any post office counter. No interest in v1.
- Player-to-player transfer: in person (hand over, both confirm) or by cheque at the Bank.
  Daily cap £100 to new accounts (< 5 h playtime), to slow alt-account farming.

## 8. Ledger
Every change of money is one call `Economy.change(player, deltaPence, reason, ref?)`.
- Rejects going below 0 (except fines, which may create debt up to £5).
- Writes the profile delta, fires the wallet update to the client, and adds a ledger record.
- Reasons are an enum (`job_pay`, `salary`, `fare`, `rent`, `tax`, `fine`, `purchase`,
  `transfer_in/out`, `theft_in/out`, `admin`, `product`).
- Transfers and thefts over £10 and every `admin` / `product` change are logged for the owner.
- Server totals per reason are kept for balancing (faucet vs sink report in the owner panel).

## 9a. Robux products (Q6)
- **Money packs** (Developer Products, ledger reason `product`), deposited to the bank. Proposed
  tiers: £10, £50, £150, £500, priced so a pack is clearly better value than grinding but a top
  motor car still needs several packs or real play.
- **Special furniture** (Developer Products or gamepasses): premium furniture sets and rooms that
  can't be bought with £.
- **Gamepasses** (final list at M9): extra wardrobe slots, premium outfits, vehicle liveries,
  summon your carriage anywhere, gramophone/radio, house tier discount.
- Receipt handling: save the profile **before** granting; on save failure return
  `NotProcessedYet` (CoverFire Sim.Store pattern).
- Never for Robux or £: the throne, offices, titles, licences, job ranks. Q21 decides whether
  any big purchase (top motor cars) also needs a job rank.

## 9. Anti-exploit
- Job pay is only granted by server-validated task completion (positions, timers, cooldowns).
- Per-job hourly pay cap (2× target) to blunt macros.
- Fare loops between alt accounts: fares between the same two accounts pay nothing after the
  3rd ride per hour.
