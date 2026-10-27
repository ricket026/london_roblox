# Property spec: homes, shops and plots

Decided by the user 2026-10-27 (OPEN_QUESTIONS "Property"): **portable deeds**, **rent or buy**,
**kit building + decor** on your own plot (BUILDING.md), **shops** selling wholesale stock and
player-made goods (SHOPS.md). This replaces PROPERTY_WARDROBE.md §1–2 (leases only, preset
layouts, no free-build). Wardrobe (§3–4 there) is unchanged.

## 1. The idea in one paragraph
You don't own *an address*, you own *a property of a kind in a district* ("a Mayfair townhouse",
"a Soho shop"). It's saved to your **account** with everything you've built and put in it. Every
server is its own little London (Q4), so when you join a server your property appears on a free
plot of that kind, at **your usual address when it's free**, otherwise the nearest free plot in
the same district. The street never has gaps: plots nobody is using show a plain template house.

## 2. Property kinds

From the plots in the place (`Workspace.Map.Plots`, ~4,000 flat lots with a district lot type,
`map_layout_v2.json` districts). Sizes are frontage × depth in studs.

| Kind | Lot type / districts | Lots | Size | Rent / real week | Buy | Notes |
|---|---|---|---|---|---|---|
| **Lodging room** | Lodging · East End | 929 | 22 × 35 | £1 | £30 | 1–2 rooms; the first home |
| **Terrace house** | Terrace · Holborn & Bloomsbury, Westminster, Lambeth | 1,007 | 26 × 43 | £4 | £120 | 2–3 storeys |
| **Townhouse** | Townhouse · Mayfair, Belgravia | 828 | 29 × 43 | £15 | £400 | with a **mews** (vehicle storage + summon point, VEHICLES §4) and staff quarters |
| **Shop** | Shop · Covent Garden, Soho | 164 | 25 × 37 | £3 | £200 | ground-floor shop, rooms above (SHOPS.md) |
| **Market stall** | stalls in Covent Garden Market / Spitalfields | ~30 | 6 × 4 | 6d per in-game day | – | the cheap first shop (EVENTS Market Day) |
| **Workshop** (later) | Workshop · Clerkenwell | 245 | 30 × 46 | £4 | £180 | where makers work: tailor, carpenter, baker (JOBS §3) |
| **Warehouse** (later) | Warehouse · Docks, Bankside, Southwark, Tower | 223 | 44 × 58 | £8 | £350 | a wholesale business; stores stock for several shops |

Prices are starting values for `Config.Property` (tuned in M9 with ECONOMY). Buying costs about
30 weeks' rent, so renting is the normal start and buying is a long-term goal (ECONOMY §3 target:
a townhouse ≈ 160 hours of labour). Offices, clubs and government lots aren't ownable (they're
the city's: newspapers, gentlemen's clubs, ministries).

**How many per account:** up to **2 homes and 2 businesses** (shops, stalls, workshops,
warehouses), each rented or bought at the normal price (Config `PROPERTY_SLOTS`). Linked or not,
all your characters share the account's properties (money is account-wide, OPEN_QUESTIONS
2026-10-27); any of them can live in the house or run the shop.

## 3. Getting a property
- **Estate agent** offices (one in Mayfair, one in Holborn, one in the East End, one in Covent
  Garden): browse kinds and districts, see free plots in this server on a map, **rent** or **buy**.
- **Rent:** the first week up front; then auto-paid from the **bank** every real week. 3 days'
  grace if the bank can't pay (warning letters), then the tenancy ends. **Nothing you built is
  lost**: the deed becomes "lapsed", the plot frees up, and renting again (same kind) restores it.
- **Buy:** one payment; no rent. You can **sell back to the estate agent** for 50% (a money sink),
  or later list it for another player to buy (v2, needs a trade flow).
- **Upgrade:** moving from a lodging to a terrace keeps your furniture in storage (the "removals"
  list) to place in the new house.
- Money goes through the Economy ledger (TASKS T09): reasons `rent`, `property_buy`,
  `property_sell`.

## 4. Plots in a server
- **Assignment** when the owner joins (or pays): (1) their saved lot id if it's free in this
  server; (2) else the nearest free lot of the same kind in the same district; (3) else any free
  lot of that kind; (4) else a **hotel room** (homes) or a **market stall** (shops) until one
  frees up. Lots carry attributes from `MapGreybox` (`LotId`, `District`, `LotType`,
  `Frontage`, `Depth`); the deed remembers the part's name (`Lot_<LotId>`), the same in every
  server because the map is the same.
- **Loading:** the owner's build (BUILDING.md) is built on the lot while they're in the server and
  for **10 minutes after they leave** (so guests don't see a house vanish mid-visit), then the lot
  returns to the template. Two owners never share a lot.
- **Templates:** every unused lot shows a low-part template house for its district (BUILDING §6),
  varied by lot id so streets don't repeat.
- **Address:** "No. 14, Berkeley Square": the street is the nearest named road (`Map.Roads._Names`
  / map data), numbers run along the street by lot order. Shown on the door plate, the map and
  letters (PLAYER_GATHERING §4).

## 5. Inside your property
- **Doors** use the existing `Doors` module (tag `Door`, `DoorLocked` attribute). Owner
  locks/unlocks; up to **5 key holders** (persistent, by userId) can open and, if allowed, build.
- **Permissions** per key holder: *enter*, *decorate* (furniture and decor), *build* (structure),
  *sell* (shops: run the till). Owner always has all.
- **"At Home"** toggle: a map marker, and anyone may knock; the owner (or a butler) admits them.
- **Household staff** and **shop assistants**: hire players with a wage paid per in-game day
  from the owner's bank (JOBS §3, SHOPS §6).
- **Safe zone** inside unless the owner allows duels (LAW §1).
- **Burglary** (LAW §3) targets valuables in homes; **shoplifting** (SHOPS §8) targets shops.

## 6. Data

Profile (account-wide) gets `properties: { [deedId]: Deed }`; the build itself is large, so it
lives in its own store.

```lua
Deed = {
  id = "p3", kind = "townhouse", district = "Mayfair",
  tenure = "rent" | "own", paidUntil = 0, lapsed = false,
  lotId = "Lot_1234",            -- usual address; assignment prefers it
  name = "Kew House",            -- optional, filtered
  doorColour = 2, keys = { [userId] = { enter=true, decorate=true, build=false, sell=false } },
  atHome = false,
  shop = nil | ShopSettings,     -- SHOPS.md §2
  buildVersion = 7,              -- bumps on each saved edit
}
```
- `PropertyBuild_v1` DataStore, key `u_<userId>_<deedId>`: the build (BUILDING §5 format), written
  only by the server holding the owner's profile lock (same lock token), saved when leaving build
  mode, every autosave if changed, and on leave. Under 1 MB per property (budget check on save).
- Schema bump: profile v3 adds `properties = {}` and `storage = {}` (removals); migration fills
  defaults. Old `rental` (unused) is dropped.

## 7. Server checks
- Only the owner (or a key holder with the right permission) may edit or sell; every edit request
  is validated against the plot bounds, height limit and piece budget (BUILDING §3).
- Rent/buy prices come from Config, never from the client. Assignment is server-side.
- Rate limits on edits (e.g. 10 placements per second), saves debounced.

## 8. What players see (UI stubs until the UI pass)
Estate agent menu (kinds, districts, free plots map, rent/buy), property menu (keys, lock, at
home, name plate, door colour, sell back), build mode (BUILDING §4), shop menu (SHOPS §9).
