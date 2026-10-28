# Roadmap

> **Status 2026-10-27.** Work is split into agent-sized tasks in `TASKS.md` (T-numbers below);
> how to work on the code is in `CLAUDE.md`, and what's installed in the user's place is in
> `INSTALL.md`. Scripts now live in git (`src/`, Q12 answered yes). New since the original plan:
> **character save slots** (built ahead of M1 at the user's request) and the **activity
> framework + 4 activities** (pulled forward from M3, the user's priority).

## The plan, step by step (2026-10-27)

The order to build things in. Each step is a task in `TASKS.md`; a phase is done when its
"done when" line is true in a Play-test. **Property and shops come next** (user, 2026-10-27), so
they move ahead of vehicles and jobs; the economy core goes first because both need it.

**Phase 1 · Finish what's built (now)**
1. Install steps 1b–5 in the user's place and fix what the Play-test finds (T01).
2. Merge `m1-identity` into `main` when the user says (T02).
3. Spawn at the terminus (T03), a quick win while installing.
*Done when* the character creator, roles, clock and four activities run with no errors.

**Phase 2 · Economy core** (everything with money or goods needs it) · *code written 2026-10-28,
INSTALL step 4, awaiting a Play-test*
1. Economy ledger `Economy.change` (T09), then wallet HUD (T10).
2. Items and inventory: `Shared.Items`, bag and storage (P01).
3. Generic counter menu for buying from NPC sellers (T15), reused by estate agents, suppliers and
   shops.
4. Bank deposits/withdrawals and hand-over transfers (T11).
*Done when* a player buys an item at a counter, carries it, gives it to another player, and every
penny shows in the ledger.

**Phase 3 · Homes and building** (PROPERTY.md, BUILDING.md) · *code written 2026-10-28 (wallpaper,
knocking/visiting still to do), INSTALL step 7, awaiting a Play-test*
1. Profile v3 with deeds and storage (P02).
2. The kit: piece data and a builder that makes pieces from it (P04).
3. Templates on every unused plot, so the whole city gets houses (P05).
4. Estate agents: rent or buy, plot assignment per server, addresses (P03).
5. Build mode: place / rotate / move / delete, the rules and the budget (P06), then save and load
   on any lot of the kind (P07).
6. Decorating: furniture, paint, wallpaper, storage, furniture bought from dealers (P08).
7. Keys, locks, "At Home", visiting (P10), then "report this building" (P09).
*Done when* a player rents a terrace house, builds and furnishes it, leaves, joins another server
and finds it on a plot in the same district, and a friend with a key can visit.

**Phase 4 · Shops and trade** (SHOPS.md) · *code written 2026-10-28 (walking NPCs, wages and
selling made goods wait for T24/T17/S07), INSTALL step 8, awaiting a Play-test*
1. Shop settings, the till, opening and selling to players (S01).
2. Wholesale suppliers and deliveries (S02).
3. Basic NPC customers that walk in and buy (S03, the first slice of the NPC framework T24).
4. Market stalls as the cheap first shop (S04).
5. Staff and the shop-assistant job (S05), selling player-made goods to shops (S06).
*Done when* a player opens a Soho shop, stocks it from the docks, sells to a player and to NPCs,
and earns about £2 an hour of being open.

**Phase 5 · Jobs** (JOBS.md, SHOPS §7) · *framework, postman, newsboy, baker, carpenter and shop
assistant written 2026-10-28, INSTALL step 8, awaiting a Play-test*
Job framework (T17), then jobs that feed shops first: baker and carpenter (S07), then
lamplighter, constable, newsboy, cabbie and omnibus (T18–T23, cabbie and omnibus after Phase 7),
first-join flow and goals (T25).

**Phase 6 · Getting players together** (PLAYER_GATHERING.md)
Hub appointments (T30), "What's on" across servers (T31, needs the place published), parties
(T32), daily tasks and letters (T33).

**Phase 7 · Vehicles**: framework, bicycle, hansom, omnibus, licences, shops for them, the
townhouse mews (T13–T15, T21, T19–T20).

**Phase 8 · The Court** (T34–T40) · **Phase 9 · Law** (T41–T46, + shoplifting S08 and burglary)
· **Phase 10 · Parliament and events** (T50–T53) · **Phase 11 · Art, UI, all platforms, launch**
(T54–T57 and the landmark track below; the art pass swaps the kit's greybox pieces for Blender
meshes).

**Lanes for working in parallel** (so several agents don't edit the same scripts):
- *Lane A, critical path:* Phases 2 → 3 → 4 → 5 in order.
- *Lane B, activities:* `activities/` batch A from now on (each activity is its own module).
- *Lane C, Studio/Blender agent:* the map (plot `Front` attributes, curiosities placement),
  landmark track, Blender versions of the kit pieces.

## Milestone definitions (what each delivers; order above)

Era: 1897. Each milestone ends with a Play test (0 console errors), screenshots, a short report,
and the user's go-ahead before the next one.

Two tracks:
- **Systems track (M0–M9):** code first in greybox, so systems can be tested without waiting
  for art.
- **Landmark track (L1–L4):** Blender models built alongside it, starting with Buckingham
  Palace (the user's choice). Each landmark: renders → user approves → FBX export → the user
  imports → placed in the map.

## Before M0 — things only the user can do

- [x] Make a new place in Studio (Place1, 2026-10-24).
- [ ] Answer OPEN_QUESTIONS.md (at least Q1–Q5; the rest have defaults).
- [ ] File > Publish to Roblox as a **new experience** (not inside Overlord Command). Save a
      local copy as `London\london.rbxl`.
- [ ] Game Settings > Security: turn on **Enable Studio Access to API Services** (DataStores).
- [ ] Optional: a Roblox **group** for community and event announcements only (no ranks are
      needed in-game since 2026-10-25: roles are per server, no staff).
- [ ] Drop reference images into `London\references\` (see references\README.md). The UI ones
      matter most, because of the earlier "looks AI-generated" problem.

## Systems track

Detailed specs for every milestone are in `systems/`. Player gathering and side activities
are the top priority (`systems/PLAYER_GATHERING.md`).

### M0 — Foundations
Shared (Config, Net, Roles, Money, Text), Profiles with session lock + mock store, boot
scripts, debug bindable, LoadingScreen stub, Admin basics (kick/ban/mute, logs), Analytics
module with the onboarding funnel.
**Done when:** a player joins, a profile loads/saves across rejoin, staff can kick/ban, 0 errors.
- [x] Built + Play-tested 2026-10-24 in Place1 (mock store). Details: `ReplicatedStorage.DESIGN_NOTES`.

### M1 — Greybox city + identity
Blockout of the city from `systems/MAP_LAYOUT.md` + `map_layout.html` (bounds X −1150…1900,
Z 850…−3320; hubs ~1 min apart) with the three hubs (palace front & the Mall, Trafalgar/Covent
Garden, Charing Cross terminus), roads wide enough for two carriages,
spawns, district signs, day/night clock, gas lamps. First-join name picker (filtered),
station/role select with seat limits, overhead name + title.
**Done when:** two clients pick names and roles and see each other's tags; walk every district.
- [x] Greybox city (map, plots, roads, kerbs, water, bridges, markers): built in the place by
      `MapGreybox` from `map_layout_v2.json`.
- [x] Character creator + save slots (name, look presets, linked slots, profile v2): **Play-tested
      by the user, works**; name-tag fix waiting to be pasted (INSTALL 1b).
- [x] Station roles with seat limits, overhead tags, world clock + HUD: built, not Play-tested.
- [ ] Spawn at the terminus (T03), gas lamps (T04), quick phrases + emotes (T05), 3D outfits (T06),
      lighting/fog (T07), forms of address (T08). The first-join flow moves to T25 (needs jobs).

### M2 — Economy + vehicles core
Wallet (£ s d), wages, ledger, tax hook. Vehicle framework: spawn, seats, driver ownership,
speed check, no-vehicle-kill rule, zone blocking, mews storage. First vehicles in greybox:
bicycle, hansom cab, horse omnibus.
**Done when:** a player buys a bicycle that persists; a second player rides in a cab and an
omnibus; hitting a pedestrian never hurts them.
- [ ] Ledger T09, wallet HUD T10, bank T11, tax T12, vehicles T13–T14, shops T15, stipend T16.

### M3 — First jobs
Cabbie (fares by distance, ranks, hailing), lamplighter, police constable (beat + whistle),
newsboy/journalist (filtered paper, printing, selling), omnibus driver. Job XP and ranks,
licences. HUD wallet + job tracker. First-join flow + goals HUD. NPC fallbacks for these jobs.
Activity framework + 4 starter activities (ducks, chess, test your strength, mudlarking).
**Done when:** each job runs start-to-pay; a cab licence is required and enforced; a new player
is earning within 60 s; each starter activity plays a full round.
- [x] Activity framework + the 4 starter activities (ducks, test your strength, mudlarking, chess):
      built, not Play-tested.
- [ ] Job framework T17, jobs T18–T23, NPCs T24, first-join flow + goals T25, more activities T26–T29.

### M3b — Gathering
Hub "appointments" every ~10 min with HUD countdown, cross-server "What's on" + Join, parties,
join friends, daily tasks + stipend, letters.
**Done when:** a player in server A sees and joins an event in server B; something starts in a
hub every ~10 min.
- [ ] T30–T33. Cross-server parts need the place published (see "Before M0").

### M4 — The Court
Palace throne room, audience queue, protocol and Court chat channel, bow/curtsy, presentations,
appointments & honours menu, persistent title registry + MessagingService sync, decrees,
balcony appearance, Changing of the Guard (scheduled).
**Done when:** a Crown player grants a title and an office; it shows in another server; a
decree is proclaimed city-wide; the guard changes on schedule.
- [ ] T34–T40. Note Q4 (2026-10-25) made titles per server, so "shows in another server" now means the cosmetic honour record only.

### M5 — Law & order
Crimes + wanted marks, whistle alerts, cuffs, police van, cells, police court + full trial,
sentences (fine, prison, licence revoked, banishment), downed state + revive, safe zones,
speeding stops.
**Done when:** a full pickpocket → arrest → trial → sentence loop works across 3 clients; a
speeder is stopped and fined.
- [ ] T41–T46.

### M6 — Property, wardrobe, motor cars
Rentals with mews, door locks, keys, household staff jobs, furniture layouts. Wardrobe with
role-locked outfits and tailor shop. Motor cars (showroom, fuel, breakdowns, motor engineer job,
motor licence), private carriages.
**Done when:** rent a townhouse, store a car in its mews, lock the door, wear a bought outfit;
all persist.
- [ ] Property moved earlier (Phases 3–4 above: P01–P10, S01–S08). Wardrobe T48 (T06 3D outfits is
      its base) and motor cars T49 remain here.

### M7 — Parliament + events
Sittings, bills on real levers (incl. speed limit and cab fares), votes, Lords delay, royal
assent. Event framework + State Procession, Royal Ball, Motor Run, Fire, Pea-souper, Tower
Bridge lift, Market Day.
**Done when:** a bill changes the speed limit live; a procession and a fire run start-to-finish.
- [ ] T50–T53.

### M8 — Art pass + UI + all platforms
Modular Victorian kit replaces every greybox building; interiors; vehicles' final models and
horses; lighting, fog, ambience. UI rebuilt from the user's references with hand-made art.
Touch and gamepad passes for every menu and for driving.
**Done when:** a phone holds 30 FPS in the busiest district; every menu and vehicle works on
phone, gamepad and PC; the user signs off the look.

### M8b — Activities wave 1
The rest of the ~20 wave-1 activities from `systems/ACTIVITIES.md` §2, hobby levels, collection
book, trophy cabinet, site leaderboards.

### M9 — Closed test + launch prep
Launch strategy from PLAYER_GATHERING §6 (seed group, launch-weekend headline event).
Group-only test servers, moderation tuning, balance (wages, prices, vehicle costs, tax limits),
rules board, thumbnails/icon, monetisation items (if Q6 says yes).

## Landmark track

- **L1 — Buckingham Palace:** exterior (east front, balcony, forecourt, railings, gates,
  sentry boxes), then throne room + ballroom interiors. **Starting first.**
- **L2 — Houses of Parliament + clock tower:** exterior, Commons chamber.
- **L3 — Tower Bridge** with lifting bascules + Tower of London backdrop.
- **L4 — Railway terminus** with train shed and a train.
Then the cathedral, Bank/Exchange, Scotland Yard, theatre, docks.

## Later
River steamers and smuggling, rideable train and Underground, telephones, more jobs (dockworker,
chimney sweep, photographer, firefighter), a seaside town place at the end of the Motor Run,
a country estate place, seasonal events (Christmas market, frost).
