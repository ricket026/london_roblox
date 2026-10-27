# Exploration & collecting

These are the solo-friendly activities that fill quiet moments and the **collection book**
(ACTIVITIES §4, TASKS T27). Random finds are fine here because they're **free** (no paid chance);
anything bought (seeds, bait) must give a known result.

Map: Thames foreshore x 1150…1186, z −1700…−2560 (top −10), river stairs at z −1720 and −2400 ·
Victoria Embankment promenade x 1130…1146, z −1192…−2735 · fishing marker (1138, −1700) ·
Scotland Yard x 880…1065, z −1230…−1300 · Spitalfields Market x −500…−380, z −2960…−3080 ·
East End x −1150…700, z −2730…−3320.

---

## Mudlarking (wave 1, built 2026-10-27)
`Activities/Mudlark.luau` · 1 (shared glints) · Collecting · ~10 s per find
- **As built:** foreshore below the Temple (x 1154…1182, z −1745…−2100, glints raycast from below
  Blackfriars Bridge deck). At low tide (in-game 0–6 and 12–18) 10 glints; hold 2 s to dig; a find
  from 9 weighted items (clay pipe … Roman coin) sold on the spot (1d–1s) and added to the
  collection; Collecting 6 XP; board "finds today". Tide sign by the stairs says when the water
  goes out.
- **Follow-ups:**
  - Make the tide visible: raise the river surface over the foreshore at high tide (tween a water
    part, or Terrain water) so it reads as a real tide; players caught by the tide are lifted to
    the stairs (no drowning, LAW §1).
  - Second foreshore stretch by London Bridge (z −2400…−2560) with its own find table (more
    shipping finds: a ship's nail, a sailor's button, a clay marble).
  - A rare find announces in the server ("A Roman coin on the foreshore!") to draw players.

## Fishing on the Embankment (wave 1)
Victoria Embankment, from the fishing marker (1138, −1700) along the wall · 1 per spot, 8 spots ·
Outdoors · ~30–60 s per catch
- **How it plays:** borrow a rod at the spot (free; better rods unlock at Outdoors level 3/6,
  ACTIVITIES §3). Cast (meter, F5); wait 5–20 s for a bite (bobber dips, a sound); then reel with
  hold-steady (F5): keep the line tension in the zone while the fish pulls; snap or slack = lost.
  Fish depend on **time of day and tide** (shared clock), so regulars learn when to come.
- **Catches** (new collection page "Fish of the Thames", values are what the fishmonger pays):
  roach 1d, dace 1d, flounder 2d, smelt 2d, perch 2d, eel 3d, barbel 4d (dawn), and the rare
  "Thames salmon" 1s (a legend of the period: only at dawn on a high tide). Junk: an old boot, a
  bottle with a message (opens a short period letter; collection item).
- **Rewards:** sell to the fishmonger stall on the Embankment or keep for the book; Outdoors 5 XP
  per catch. Board: biggest catch today (weight in lb, rolled within each species' range).
- **Server checks:** the bite time and fish are chosen by the server when you cast; the reel
  result is checked against the tension curve the server sent (like the strength meter).
- **Needs:** F5 (meter + hold-steady), new `Collection` source "Fishing", rod held item, a
  fishmonger NPC/stall (T24). Config `FISHING_*` (spots, bite times, species table by hour/tide).
- **Done when** a player catches and sells fish, the species follow the clock and tide, and the
  collection page fills.

## Curiosities hunt (wave 1)
The whole city · 1 · Collecting · open-ended
- **Pitch:** 100 hidden curios: a carved gargoyle head on a roof, a lost umbrella in an alley, a
  cat on a windowsill, a clockwork bird in the palace gallery...
- **How it plays:** each curio is a small prop with a prompt ("Examine"). Found once per account
  (collection is account-wide), they stay visible for others. A "Curiosities of London" page lists
  1–100 with a riddle-style hint per number ("Where the Admiral keeps watch, look to his feet"
  → Nelson's Column). Every 10 found: a cosmetic (a magnifying glass, then a cane topper...) and a
  Gazette mention.
- **Placement:** curios are **data** (a list of id, name, position, hint) in a Shared module; the
  server builds them at start like the activity sites. Spread them by district (roughly 5 per
  district, more in hubs) and at every landmark; put some on rooftops reachable by stairs, some
  in interiors. An agent can propose positions from the map data (landmark edges, plot roofs,
  alleys between plots), then the user or a Studio agent nudges them in place.
- **Rewards:** 2d per curio, Collecting 10 XP; milestones as above.
- **Needs:** curio data module, prompts, collection page with hints (T27). Config `CURIO_*`.
- **Done when** 100 curios exist, each is found once per account, and the page shows hints.

## Detective mysteries (wave 3)
Scotland Yard (case office) + the city · 1–4 co-op · Collecting · 10–20 min per case
- **How it plays:** take a case file at Scotland Yard: a short scripted mystery (a stolen
  necklace at the Savoy, a forged banknote at the Bank). Clues are props placed for that case
  (footprints, a torn glove, a ledger page); NPC witnesses answer from a choice list. Name the
  culprit and the evidence; right answer closes the case. Co-op players share the case file.
  No gore, no murders (DESIGN §12).
- **Rewards:** 1s per case, Collecting 40 XP, a "Case closed" stamp. 5 cases at launch; more as
  updates.
- **Needs:** case data format (clues, NPC lines, solution), NPCs (T24), case UI. Pairs well with
  the police detective role (LAW §7).

## Street photography (wave 3)
The whole city · 1 · Collecting · open-ended
- **How it plays:** buy a box camera (shop, £1). Aim at a landmark or an event and press: the
  server checks the landmark is in frame (in front of the camera, within a distance band) and
  records a **photo card** (landmark, time of day, weather, and who was in shot). An album page
  per landmark; event photos (procession, bridge lift, a fire) are rare cards.
- **Rewards:** 1d per new card, Collecting 8 XP.
- **Needs:** camera tool, landmark list with photo points, album pages (T27).

## Allotment gardening (wave 3)
Allotments in the East End (a lot near Spitalfields) · 1 · Outdoors · real time (a crop takes
1–4 real hours)
- **How it plays:** rent an allotment bed for the session's server (like houses, PROPERTY §1; the
  crops are saved to your account and move with you). Plant seeds (bought, 1d a packet), water
  (a can at the tap) once per growth stage; crops grow in real time. Harvest and sell flowers and
  vegetables at Spitalfields or Covent Garden (feeds flower selling).
- **Rewards:** produce sells for 2–4× the seed cost; Outdoors 5 XP per harvest.
- **Needs:** bed assignment per server, crop state in the profile (`os.time` growth), shops (T15).
