# Property & Wardrobe spec

> **§1–2 are replaced by `PROPERTY.md`, `BUILDING.md` and `SHOPS.md`** (user decisions
> 2026-10-27: portable deeds that can be rented or bought, kit building + decorating, player
> shops). Kept below for history. §3–4 (wardrobe) still apply.

## 1. Leases, not fixed addresses
Many servers share one game, so a fixed house can't belong to one player everywhere. Instead:
- Players rent a **lease** of a tier (Lodging / Flat / Townhouse), saved in the profile.
- On joining a server, the player is assigned a free house of their tier there (the same
  address if it's free; otherwise the nearest free one). Their furniture layout, door colour and
  name plate move with them.
- This replaces `Rentals_v1` (one renter per house globally) from TECH.md §5.2.

| Tier | Per server | Rent / real week | Includes |
|---|---|---|---|
| Lodging (East End) | 20 | £1 | 1 room, bed, chest |
| Flat (West End) | 12 | £4 | 3 rooms, 2 layouts |
| Townhouse (Belgravia/Mayfair) | 8 | £15 | 4 floors, mews (vehicle storage + summon point), 3 layouts, staff quarters |

If a server is full for a tier, the player gets a "guest room" at a hotel until one frees up.
Rent auto-pays from the bank weekly; 3 days of grace, then the lease ends (belongings kept).

## 2. Inside the house
- **Doors:** locked/unlocked by the owner; **keys** given to up to 5 players (persistent).
- **Layouts:** pick from preset furniture layouts per room (no free-build in v1); paint and
  wallpaper colours; a name plate on the door (filtered).
- **Household staff:** owner hires players as butler/maid/footman. Staff get a wage (owner pays
  per in-game day, min set in Config) and household tasks (JOBS §3).
- **Hosting:** "At Home" toggle puts a marker on the map and lets anyone knock; the butler (or
  owner) admits guests.
- **Safe zone** unless the owner turns on "allow duels".

## 3. Wardrobe
- **Role uniforms** are free and forced while on duty for uniformed roles (police, guards,
  household, omnibus, firefighters).
- **Owned outfits** in a wardrobe list (slots: 10 free, more via gamepass Q6). Outfits are sets
  of accessory/clothing IDs + body colours applied with `HumanoidDescription`.
- **Shops:** tailor (men's), dressmaker (women's), hatter, outfitter (police/guard ceremonial
  extras).
- **Period clothing everywhere** (default): players can't wear their own modern Roblox outfit.
  A default period outfit is generated from the player's avatar colours on first join.
- **Dress code** checks for events: a ball needs an outfit tagged `Formal`; court needs
  `CourtDress` (tagged on items).
- **Rank details** added automatically: police numbers and chevrons, Guards' badges, peers' robes
  for ceremonies.
- **Tailor job (later):** players craft outfits from cloth bought at the docks and sell them; the
  craft makes the same catalog items but cheaper and with a "Made by" tag.

## 4. Items list (to source in M6)
Catalog/marketplace search list: top hat, bowler, flat cap, deerstalker, frock coat, morning coat,
tailcoat, waistcoat, Inverness cape, police tunic + custodian helmet, Guards' tunic + bearskin,
cavalry helmet + cuirass, bustle gown, leg-of-mutton sleeve blouse, walking skirt, ball gown,
bonnet, wide-brim hat with feathers, shawl, apron (maid), butler's suit, newsboy cap and
knickerbockers, flower-seller basket, nurse uniform, fireman's brass helmet.
Free items only, checked for scripts (CLAUDE.md).
