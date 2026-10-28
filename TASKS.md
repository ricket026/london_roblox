# Task backlog

Agent-sized tasks in build order. Read `CLAUDE.md` first (workflow, rules, install instructions).
Specs are the source of numbers; this file says what to build and when it's done.

**Status:** ⬜ to do · 🟡 partly done · ✅ built (Play-tested only if it says so) · 🔒 blocked on
the user (a decision, assets or Studio). **Size:** S ≈ one module, M ≈ 2–4 modules, L ≈ split it.

How to take a task: pick the first ⬜ whose dependencies are ✅, mark it 🟡 with your branch name,
keep the scripts you touch to the list (or say why), run `tools/check_luau.py`, update
`INSTALL.md` and `DESIGN_NOTES`, and mark it ✅ with what still needs a Play-test.

---

## Done so far (2026-10-28, branch `m1-identity`)

| | What | Notes |
|---|---|---|
| ✅ | M0 foundations | Play-tested by the previous agent (DESIGN_NOTES) |
| ✅ | Scripts in git (`src/`), Rojo project, `tools/` checks | |
| ✅ | Character creator + save slots, profile schema v2 | **Play-tested by the user: works.** Name tag fix pending re-paste (INSTALL step 1b) |
| ✅ | Station roles with seat limits + playtime gates, overhead tags | Not Play-tested |
| ✅ | World clock (24-min day, phases) + clock HUD | Not Play-tested |
| ✅ | Activity framework + ducks, test your strength, mudlarking, chess | Not Play-tested; chess rules pass perft |
| ✅ | Phase 2 economy core: ledger, wallet HUD, bag, NPC counters, bank, hand-overs (T09, T10, T11, T15, P01) | Not Play-tested; `tests/test_economy*.luau`; INSTALL step 4 |
| ✅ | Daily stipend streak (T16), daily tasks (T33 part), hub appointments every 10 min with mementos (T30), DailyUI | Not Play-tested; `tests/test_daily.luau`; INSTALL steps 4, 9 |
| ✅ | Streets: gas lamps (T04), lamplighter (T18), lighting by phase + weather (T07), terminus spawn (T03) | Not Play-tested; `tests/test_lamps.luau`; INSTALL steps 4, 6, 8 |
| ✅ | 3D part outfits and hats for all six outfits (T06) | Not Play-tested; `tests/test_wardrobe.luau`; INSTALL step 4 |
| ✅ | Phase 5 start: job framework (T17) + Postman, Newsboy (selling), Baker, Carpenter (S07), shop assistant wages (S05), job tracker | Not Play-tested; `tests/test_jobs.luau`, wages in `test_shops.luau`; INSTALL step 8 |
| ✅ | Phase 4 shops: tills, stock, prices, trade, sign, staff by key, wholesale suppliers + delivery, NPC customers (at the till), market stalls (S01–S04; S05, S06 partly) | Not Play-tested; `tests/test_shops.luau`, `test_shop_ui.luau`; INSTALL step 8 |
| ✅ | Phase 3 homes and building: kit, plots, templates, estate agents, rent/buy/sell, build mode, save/load, keys, locks, reports (P02–P07, P09; P08, P10 partly) | Not Play-tested; `tests/test_kit.luau`, `test_property.luau`, `test_build_ui.luau`; INSTALL step 7 |

---

## Now: finish getting the current work into the game

### T01 · Install steps 1b–5 and fix what the Play-test finds ⬜ 🔒
- **Depends** user time in Studio · **Size** S each
- Walk the user through `INSTALL.md` one step at a time; fix each error they paste back.
- Known things to verify: chess table-top board orientation for white (SurfaceGui on a Top face;
  flip `sq.Position` rows in `Activities/Chess.luau` if rank 8 is at white's end); swatch outline;
  activity sites not inside anything; bell timing feels fair at `STRENGTH_BELL = 85`.
- **Done when** every step is ✅ in INSTALL.md with no red Output lines.

### T02 · Merge `m1-identity` into `main` ⬜ 🔒
- Ask the user; open a PR when they say so. Afterwards update links in INSTALL.md/CLAUDE.md to `main`.

---

## Property, building and shops (ROADMAP Phases 2–4, next after Phase 1)

Specs: `PROPERTY.md`, `BUILDING.md`, `SHOPS.md` (user decisions 2026-10-27: portable deeds,
rent or buy, kit building + decor, wholesale + player-made goods). Do them in this order; the
economy core (T09, T10, T15, T11) comes first and is listed under M2 below.

### P01 · Items and inventory ✅ (2026-10-28, not Play-tested)
- **Specs** SHOPS §1 · **Depends** T09 · **Size** M
- `Shared.Items` (definitions + categories), server `Inventory` (bag 20 stacks, storage), give
  prompt (both confirm), consumable/holdable use. Profile v3 field `inventory`.
- **Done when** a player buys a bun at a counter (T15), carries it, gives it to a friend, who eats it.
- **Built:** `Shared.Items`, `LondonServer.Inventory`, `LondonServer.Exchange`, client `EconomyUI`
  (bag, Give, offer popup). Play-test: the held part's grip on R15 and R6, Give with 2 players.

### P02 · Profile v3: deeds and storage ✅ (2026-10-28)
- **Specs** PROPERTY §6 · **Size** S · `properties`, `storage` (removals), `inventory` (P01) with a
  v2 → v3 migration in `Profiles`; new store `PropertyBuild_v1` written under the profile's lock
  token. Update `Shared.Types` and TECH §5.1.

### P03 · Estate agents, rent and buy, plot assignment ✅ (2026-10-28, not Play-tested)
- **Specs** PROPERTY §2–4 · **Depends** P02, T15 · **Size** M
- Server `Property` module: deed kinds from Config, rent (weekly from the bank, 3-day grace,
  lapse keeps the build), buy and sell-back, per-server lot assignment (saved lot → same
  district → same kind → hotel/stall), addresses from road names, 10-minute linger after leaving.
- **Done when** two players rent terraces in one server and get different lots, and one of them
  gets the same address back after rejoining an empty server.
- **Built:** `LondonServer.Property` + `Lots` (both done-when cases are in `tests/test_property.luau`).
  Not yet: the hotel room / market stall fallback (Q27: the deed waits for a free plot instead).

### P04 · The kit: piece data and builder ✅ (2026-10-28)
- **Specs** BUILDING §1–2 · **Size** M · `Shared.Kit` (piece ids, sizes, grid footprint, colour
  slots, groups) and a builder that makes a piece (greybox parts now) at a grid position on a lot.
  Lot `Front` side computed from the road data (once, cached as an attribute).
- **Done when** a test command lays out one of every piece on a lot, at the right scale next to
  an R15 character.
- **Built:** `Shared.Kit` + `Shared.Palette`; `tests/test_kit.luau` checks every piece against
  art/kit.md and the geometry (rotation, wedges, seats, door hinges). Still wanted: the Studio
  layout command, to eyeball scale next to a character.

### P05 · Templates on every unused plot ✅ (2026-10-28, not Play-tested)
- **Specs** BUILDING §6 · **Depends** P04 · **Size** M · ≤ 6 parts per unused lot, varied by
  `LotId`, district style (stock brick in the East End, stucco in Belgravia...). Full-detail only
  near players. Check part counts and FPS with all ~4,000 lots.
- **Done when** every street has houses and a phone keeps 30 FPS walking through Mayfair.
- **Built:** `Lots.buildTemplate` (≤ 8 parts, colour, door, roof and chimney by `LotId` and lot
  type). FPS unmeasured: `Config.LOT_TEMPLATES` turns them off (Q28).

### P06 · Build mode: place, rotate, move, delete, rules ✅ (2026-10-28, not Play-tested)
- **Specs** BUILDING §3–4 · **Depends** P03, P04 · **Size** L (split client UI / server rules)
- Build camera, catalogue, ghost preview with rule reasons, budget meter, storey selector,
  undo/redo, templates to start from, draft vs published (street-front rule). Server validates
  every edit (bounds, height, budget, permissions, rate limit). Touch and gamepad from day one.
- **Built:** server `Builds`, client `BuildUI` (orbit camera by buttons/wheel/Q-E, catalogue,
  ghost with reasons, storeys, Place/Select, turn, move, paint, delete, undo/redo, "Start again",
  publish). Not yet: copy, a storey cut-away view, drag-to-orbit on touch.

### P07 · Save and load builds ✅ (2026-10-28)
- **Specs** BUILDING §5 · **Depends** P06 · **Size** S · Relative-to-lot format, validate on load,
  pieces that don't fit go to storage, size budget per property.

### P08 · Decorating: furniture, paint, wallpaper, storage 🟡 (furniture from storage, starter set, paint, lamps; wallpaper per face and a flickering fire to do)
- **Specs** BUILDING §2, SHOPS §1 · **Depends** P06, P01 · **Size** M · Free starter set, bought
  furniture from storage, paint/wallpaper per face, fireplaces and lamps that light.

### P09 · "Report this building" ✅ (2026-10-28) · **Specs** BUILDING §7 · 3 reports in a server → template for the session; logged.
### P10 · Keys, locks, "At Home", visiting 🟡 (keys, locks, At Home = doors open; knocking, map markers and visiting to do, Q26) · **Specs** PROPERTY §5 · Uses `Doors`; key permissions enter/decorate/build/sell.

### S01 · Shop settings, till, opening, selling to players ✅ (2026-10-28, not Play-tested)
- **Specs** SHOPS §2, §4 · **Depends** P03, P06, P01 · **Size** M · Trade choice, filtered sign,
  prices 0.8–3× base, stock on displays, open only while a seller is present, till auto-banks.
- **Built:** `LondonServer.Shops` + client `ShopUI`. Not yet: stock *showing* on the display
  fittings, the map marker for open shops (the plot has `ShopOpen` / `ShopTrade` attributes).
### S02 · Wholesale suppliers and deliveries ✅ (in `Counters`, kind "supplier"; deliveries go to storage) · **Specs** SHOPS §3 · Supplier counters (T15) by in-game hours, 60% of base, delivery 2d.
### S03 · NPC customers 🟡 (sales at the till by trade, price, appeal, footfall, quiet bonus and hourly cap; no walking NPCs until T24) · **Specs** SHOPS §4, LOW_POP §1 · First slice of the NPC framework (T24): walk in, buy by trade/price/footfall/appeal, hourly cap.
### S04 · Market stalls ✅ (8 stalls in Config.COUNTERS, per server, rent each in-game day; Market Day doubling waits for EVENTS) · **Specs** SHOPS §5, PROPERTY §2 · Daily rent, fixed stall, Market Day doubling.
### S05 · Staff and the shop-assistant job ✅ (ShopAssistant role: wage from the owner's bank while on duty, XP per sale; ranks unlock nothing yet) · **Specs** SHOPS §6 · Needs the job framework (T17) for ranks; wages per in-game day.
### S06 · Selling player-made goods to shops 🟡 (stock keeps "made by"; the sell-to-shop offer flow waits for makers, S07) · **Specs** SHOPS §3 · "Made by" tag, shop buying prices, both confirm.
### S07 · Makers: baker and carpenter jobs ✅ (one hold at the bakehouse / workshop turns flour or timber into "made by" goods; the crafting minigame is still to come) · **Specs** SHOPS §7, JOBS §3 · Depends T17, P01.
### S08 · Shoplifting ⬜ · **Specs** SHOPS §8 · With M5 law (T43).

---

## M1: greybox city + identity (finish)

### T03 · Spawn at the terminus ✅ (2026-10-28: `Characters.spawnPoint`, on the station forecourt; the platforms marker is inside the solid greybox station; not Play-tested)
- **Specs** LOW_POP §3 step 1, PLAYER_GATHERING §1 (terminus is a hub) · **Size** S
- New characters and returning players spawn on the platforms (`Map.JobSites["Spawn: terminus
  platforms"]`, ~(555, ?, −1350)): add `SpawnLocation`s from code or pick a spot and set the
  character's CFrame after `LoadCharacterWithHumanoidDescription` in `Characters.spawn`.
- **Files** `Characters.luau`, `Config` (spawn points). **Done when** a new character appears on a
  platform, not at the old baseplate `SpawnLocation`.

### T04 · Gas lamps on every street ✅ (2026-10-28: `LondonServer.Lamps`, ~700 lamps / ~1,400 parts; not Play-tested)
- **Specs** JOBS §4 (tagged `Lamp`, `Route` attribute), §2 Lamplighter · **Size** M
- Generate lamps along `Map.Roads` (the road graph in the place / `map_layout_v2.json` roads) at
  ~40-stud spacing on pavements, each with a `PointLight` (off), tag `Lamp`, attribute `Route`
  (10–14 lamps per route, grouped by district). Server module `Lamps` builds them at start (like
  activities do) so it needs no Studio work; lights on/off from `WorldClock.PhaseChanged` until
  the lamplighter job (T18) takes over.
- **Done when** every street has lamps that light at Dusk and go out at Dawn; < 1,500 parts.

### T05 · Quick-phrase wheel + etiquette emotes ⬜
- **Specs** DESIGN §9 (chat-light RP is core, Q5), COURT §4 bow/curtsy · **Size** M
- Game-written phrase list in a Shared module (period lines: "Good day!", "Your Majesty.",
  "Stop, thief!", "Cab, sir?"...), sent by id, shown as speech bubbles to everyone nearby
  (`TextChatService` bubble or BillboardGui). Emotes: bow, curtsy, doff hat, salute, wave,
  applaud, cheer (animation IDs in Config, 🔒 user publishes animations; fall back to none).
- **Done when** two clients see each other's phrases without typing; works on touch/gamepad.

### T06 · 3D part outfits and hats ✅ (2026-10-28, not Play-tested; INSTALL step 4)
- **Specs** PROPERTY_WARDROBE §3; designed with the user 2026-10-27 · **Size** M
- Build each `Config.OUTFITS` entry from welded, massless, non-colliding parts sized from the
  character's limbs (frock coat tails + waistcoat + cravat + top hat; bell skirt + bodice +
  bonnet; etc.). New `Shared.OutfitParts` (piece definitions) + server `Wardrobe` (attach after
  spawn); `Characters.spawn` calls it. Same attach system can take Blender MeshParts later.
- 🔒 OPEN_QUESTIONS Q23: hats as a separate creator choice (adds a "Hat" row) or part of the outfit?
- **Done when** all six outfits look distinct on R15 and survive walking/jumping/sitting.
- **Built:** `Shared.OutfitParts` (pieces relative to limb sizes) + server `Wardrobe`, called by
  `Characters.spawn`. Hats come with the outfit (Q23 default). Play-test: proportions, clipping
  when sitting, the skirts with long strides; tune sizes in OutfitParts.

### T07 · Day/night lighting, fog and weather 🟡 (phase lighting + `WorldClock.setWeather` clear/rain/fog done; rain particles and window glow to do)
- **Specs** DESIGN §6.10, EVENTS (pea-souper) · **Size** S
- Extend `WorldClock`: Atmosphere density/colour and Lighting brightness per phase (tween),
  thicker fog at night, light rain. Keep values in Config. Expose `WorldClock.setFog(level)` for
  the pea-souper event (T53).

### T08 · Forms of address and the Titles module ⬜
- **Specs** COURT_PARLIAMENT §3, DESIGN §6.1 · **Size** S
- `Shared.Titles`: address strings by role/title/rank ("His/Her/Their Majesty", "The Rt Hon. the
  Earl of Kew", "Constable Last"), neutral by default, player setting His/Her/Their
  (`profile.settings.address`). Identity tags and announcements use it.

---

## M2: economy and vehicles

### T09 · Economy ledger ✅ (2026-10-28, not Play-tested)
- **Specs** ECONOMY §8, §9 · **Size** M
- `Economy.change(player, delta, reason, ref?)` per spec: reason enum, debt only for fines (to
  −£5), large-transfer and admin/product logging, per-server totals per reason. Replace every
  `Profiles.addPence` / `Profiles.charge` call (Activities, Characters, Ducks).
- **Done when** all money moves through it and an owner command prints faucet/sink totals.
- **Built:** `LondonServer.Economy`; totals via Debug `totals` (Studio). A live-server owner chat
  command (`/money`) is still to add to `Admin` with the staff panel.

### T10 · Wallet HUD ✅ (in `EconomyUI`, not Play-tested)
- Client stub showing wallet (and bank on tap) in £sd from `Profile.Wallet`. **Size** S

### T11 · Bank and transfers ✅ (2026-10-28, not Play-tested)
- **Specs** ECONOMY §7 · **Depends** T09 · **Size** M
- Deposit/withdraw at the Bank of England counter and post offices (prompts), hand-over transfer
  (both confirm), daily £100 cap for accounts with < 5 h playtime.

### T12 · Tax and the server treasury ⬜
- **Specs** ECONOMY §6 · **Depends** T09 · **Size** S
- Income tax on job pay/salaries, purchase duty, per-server treasury (seed £200 from Config),
  treasury-paid bonuses stop when empty. Levers are plain Config/server values until T50.

### T13 · Vehicle framework ⬜
- **Specs** VEHICLES §2–5, §7, §10 · **Size** L (split: chassis+seats / ownership+summon /
  rules+security)
- One chassis controller tuned per class (table §1), driver network ownership, server speed and
  teleport checks, enter/exit prompts, **no-vehicle-kill shove**, pedestrian-only zones, caps
  (`MAX_LIVE_VEHICLES` 40, motors 6), idle despawn, condition. Drive on the left.

### T14 · First vehicles: bicycle, hansom cab, horse omnibus ⬜
- **Depends** T13 · **Size** M · Greybox models built from parts; horse feel = speed steps.
- **Done when** (ROADMAP M2) a player buys a bicycle that persists; a second player rides in a
  cab and an omnibus; hitting a pedestrian never hurts them.

### T15 · Counter menu (buying from NPC sellers) ✅ (2026-10-28, not Play-tested)
- **Depends** T09, P01 · **Size** S · ROADMAP Phase 2 · A generic counter: prompt → list of items
  with prices (from Config / `Shared.Items`) → buy into the bag or storage. Reused by estate agents
  (P03), wholesale suppliers (S02), kiosks, the bicycle shop and tailors. Player-run shops (S01)
  use the same menu with the shop's own stock and prices.
- **Built:** `LondonServer.Counters` (Config.COUNTERS: 5 banks/post offices, 6 shops, positions
  pass `tools/check_sites.py`) + the counter panel in `EconomyUI`. New kinds:
  `Counters.onOpen` (server) and `EconomyUI.onCounter` (client).

### T16 · Daily stipend and streak ✅ (2026-10-28, `LondonServer.Daily`; not Play-tested)
- **Specs** ECONOMY §4, PLAYER_GATHERING §4 · **Size** S · 1s, rising to 7s over a 7-day streak.

---

## M3: jobs, activities, NPCs

### T17 · Job framework ✅ (2026-10-28, not Play-tested)
- **Specs** JOBS §1 · **Depends** T09 · **Size** M
- On/off duty at depots, one job at a time (2 min switch cooldown), tasks with checkpoints,
  XP to rank n = `150 × n^1.6`, +10% pay per rank, tracker HUD, anti-AFK, hourly pay cap.
  XP/ranks live in `Profiles.progress(player).jobs` (so linked slots share them).
- **Built:** `LondonServer.Jobs` (duty = the station role; steps "goto"/"hold" with `need`/`give`;
  `Jobs.register(jobId, start)` for new jobs), `Shared.Ranks`, client `JobUI` tracker with a marker
  and hold prompt. Anti-AFK is by design (pay only for server-checked steps) plus the hourly cap.
  Not yet: depots/uniforms/tools on going on duty, rank perks, training.

### T18 · Lamplighter ✅ (rounds from dusk and dawn, 2d a lamp, city fallback after Config.LAMP_NPC_DELAY; repairs wait for vandalism/events) · **Depends** T04, T17 · Dusk/dawn routes, repairs, NPC fallback 10 min after dusk.
### T19 · Cabbie ⬜ · **Depends** T14, T17, T21 · Meter fares (VEHICLES §8), hailing, NPC fares at ranks.
### T20 · Omnibus driver + conductor ⬜ · **Depends** T14, T17 · Fixed route (`Map.BusStops`), stop timing.
### T21 · Licences and the driving test ⬜ · **Specs** VEHICLES §6 · Public Carriage Office course, revocation.
### T22 · Police constable (beat + whistle) ⬜ · **Specs** JOBS §2, LAW §4 step 1 · Arrests come in M5.
### T23b · Postman ✅ (rounds from the nearest post office to 5 doors near it; letters between players come with T33) · **Specs** JOBS §3
### T23 · Newsboy and journalist (the Gazette) 🟡 (Newsboy selling bundles on corners works; journalist, editions and selling to players to do) · **Specs** JOBS §2 · Filtered articles, editions, selling.

### T24 · NPC framework and low-pop fallbacks ⬜
- **Specs** LOW_POP §1, PLAYER_GATHERING §1 (ambient crowds), VEHICLES §9 · **Size** L
- Population budget that shrinks as players rise; walking lanes and idle crowds in hubs; NPC fares,
  buyers, shopkeepers, lamplighter; later NPC traffic. Simple rigs, a few lines of speech.

### T25 · First-join flow and goals HUD ⬜
- **Specs** LOW_POP §3–4, Config.ONBOARDING_STEPS · **Depends** T03, T17 · **Size** M
- Arrival cinematic (skippable) → character creator (exists) → rules card → pick a starter job
  with a 60-second guided task → first pay → "Next steps" goals list. Log each funnel step.

### T26 · Activities ⬜ (one task per activity)
**Specs** `activities/` (a full design per activity: site, rules, controls, rewards, checks,
"done when"). Follow the build order in `activities/README.md`:
1. **T26a framework pieces** F5 controls kit, F1 lobby, F2 rounds, F9 thrown things (then F3, F4,
   F6–F8, F11 as activities need them; `activities/framework.md`).
2. **Batch A** (framework only): coconut shy, hoop-la, croquet, fishing, curiosities hunt, rowing,
   carousel & swing boats, Rotten Row promenade, kite flying, model boats, cricket nets, and the
   follow-ups for ducks, strength, mudlarking and chess (+ draughts).
3. **Batch B** (🔒 sounds/animations from the user): bandstand, music hall, busking, waltz, piano,
   Punch & Judy.
4. **Batch C** (needs other systems): races, regatta, sports day, tea room, flower selling, picnic,
   auction, photography, detective mysteries, allotments, ice skating, balloon.
Mark progress in the table in `activities/README.md`.

### T27 · Collection book UI ⬜ · **Specs** ACTIVITIES §4 · Pages from `Collection.PAGES`, found/missing, page rewards.
### T28 · Hobby level rewards ⬜ · **Specs** ACTIVITIES §3 · Cosmetic per level (ribbons, title tags) + unlocks.
### T29 · All-time leaderboards ⬜ · OrderedDataStore per activity (live servers), "Hall of Champions" board.

---

## M3b: getting players together (top priority per PLAYER_GATHERING)

### T30 · Hub appointments ✅ (2026-10-28, `LondonServer.Appointments`: train, concert, guard, auction in turn; mementos; HUD countdown; the events themselves (music, NPC passengers, guards marching) come with T39/T24)
- **Specs** PLAYER_GATHERING §2 · **Size** M · Something at a hub every ~10 real minutes (train
  arrival, bandstand concert, park race, bridge lift, auction) with a HUD countdown and map
  marker. Uses the shared clock so every server lines up.

### T31 · "What's on" across servers + Join ⬜ 🔒
- **Specs** PLAYER_GATHERING §3 · **Size** M · MessagingService feed + TeleportService join.
  🔒 Needs the place published and Studio API access on (ROADMAP "before M0" checklist).

### T32 · Parties and join-friends ⬜ · 2–6 players teleport/spawn together.
### T33 · Daily tasks and letters 🟡 (3 daily tasks from Config.DAILY_POOL done; letters to do) · **Specs** PLAYER_GATHERING §4 · Filtered letters, `CanUsersDirectChatAsync` check (TECH §8).

---

## M4: the Court

### T34 · Throne claim and line of succession ⬜
- **Specs** COURT_PARLIAMENT §2, §2.1 · **Size** M · `Stations` King/Queen have `claim = "throne"`;
  build the claim at the throne in `PalaceInteriors.ThroneRoom`, succession offers (20 s each),
  abdication, accession proclamation, saved cosmetic reign count (`progress.honours`).
### T35 · Appointments, honours and grants menu ⬜ · **Specs** COURT §2 table, §5 · Seat caps, rate limits, logging.
### T36 · Throne room protocol and audience queue ⬜ · **Specs** COURT §4 · Court chat channel, floor control.
### T37 · Decrees ⬜ · **Specs** COURT §6 · Banner + bell, decree boards, Gazette column, lever decrees.
### T38 · No-confidence votes and vote-kick ⬜ · **Specs** DESIGN §10, COURT §2 · Thresholds per spec, logged.
### T39 · Event framework ⬜ · **Specs** EVENTS §1, §3, §4 · Announce → gather → steps → finish, NPC fill, scheduling.
### T40 · Changing of the Guard + balcony appearance ⬜ · **Depends** T39, T24 · Route in `Map.Routes`.

---

## M5: law and order

### T41 · Health, downed, revive, death and safe zones ⬜ · **Specs** LAW §1 · Hospital respawn replaces `Config.RESPAWN_SECONDS`.
### T42 · Weapons (server-validated hits) and firearms certificate ⬜ · **Specs** LAW §1 table · Q8.
### T43 · Crimes, wanted marks, murder bounty escalation ⬜ · **Specs** LAW §1.1, §2, §3.
### T44 · Arrest flow, booking, auto-justice ⬜ · **Specs** LAW §4 · Server-enforced legal-target rule.
### T45 · Police court and full trials ⬜ · **Specs** LAW §5 · Old Bailey interior needed (🔒 landmark/interior).
### T46 · Sentences and prison ⬜ · **Specs** LAW §6 · Remaining time saved in the profile.

---

## M6: property, wardrobe, motor cars

### T47 · (replaced) Leases and houses → see **Property, building and shops** (P01–P10, S01–S08) above.
### T48 · Wardrobe and shops ⬜ · **Specs** PROPERTY_WARDROBE §3 · Owned outfits, role uniforms, dress codes. Builds on T06. 🔒 catalog items list (§4) for real clothing.
### T49 · Motor cars, fuel, breakdowns, motor engineer ⬜ · **Specs** VEHICLES §2, §5 · Depends T13.

---

## M7: Parliament and events

### T50 · Levers module ⬜ · **Specs** COURT §7.4 · Per-server values with ranges; every system reads its lever here.
### T51 · Elections and sittings ⬜ · **Specs** COURT §7.2–7.3, §7.5.
### T52 · State Procession, Royal Ball, Motor Run, Market Day ⬜ · **Specs** EVENTS §2 · Depends T39.
### T53 · Fire!, Pea-souper, Tower Bridge lift, train arrival ⬜ · **Specs** EVENTS §2 · Bridge lift needs Tower Bridge bascules (🔒 L3 model).

---

## M8–M9 (mostly need the user)

- **T54 · UI pass** 🔒 user's reference images (ART §8); hand-made 9-slice art.
- **T55 · Touch/gamepad and phone performance pass** (30 FPS on a phone in the busiest district).
- **T56 · Robux products and gamepasses** · **Specs** ECONOMY §9a, DESIGN §11 · receipt-safe.
- **T57 · Closed test and launch prep** · PLAYER_GATHERING §6.

## Housekeeping

- **H1 · Staff tools vs "no staff"** 🔒 (OPEN_QUESTIONS Q24) · `Admin` (M0) has mod/admin levels and group ranks, but
  Q11 says no staff. Ask whether to cut it down to owner-only tools plus automatic moderation.
- **H2 · Missing docs** 🔒 · `MAP_LAYOUT.md` and `map_layout.html` are referenced by README/ROADMAP
  but not in the repo; ask the user to upload them.
- **H3 · Fresh characters in slots 2–3** 🔒 (Q22) · priced free (`Config.SLOT_NEW_PRICE = 0`) because
  the user only set the link price (£100); confirm.
