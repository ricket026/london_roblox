# Roadmap

> **Status 2026-10-27.** Work is split into agent-sized tasks in `TASKS.md` (T-numbers below);
> how to work on the code is in `CLAUDE.md`, and what's installed in the user's place is in
> `INSTALL.md`. Scripts now live in git (`src/`, Q12 answered yes). New since the original plan:
> **character save slots** (built ahead of M1 at the user's request) and the **activity
> framework + 4 activities** (pulled forward from M3, the user's priority).

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
- [ ] T47–T49 (T06 3D outfits is the base for the wardrobe).

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
