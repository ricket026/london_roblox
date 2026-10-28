# Building spec: the period kit, build mode and decorating

Decided 2026-10-27: players **build from a period kit and decorate** on plots they rent or own
(PROPERTY.md). Curated pieces only, snapped to a grid, inside the plot and under a height limit,
so streets keep looking like 1897 and nothing inappropriate can be made without staff (Q11).
The same kit gives the whole city its houses: unused plots show kit-built templates (§6), which
is also the modular kit ART.md §3 planned for the M8 art pass.

## 1. Scale and grid (ART.md §2)
- Characters ~5 studs tall; **storey 12 studs**; doors 8 studs; window bays 4 studs wide.
- Placement grid **2 studs** (the map's cell size) for floors, roofs and garden pieces, **1 stud**
  for walls and trim (1-stud-thick walls must meet at corners), **storey levels** vertically
  (pieces sit on floor level 0, 12, 24, ...; furniture snaps to 0.5 studs on a floor).
- Rotation in 90° steps for structure; 15° steps for furniture.
- Plots have attributes from `MapGreybox`: `LotId`, `District`, `LotType`, `Frontage`, `Depth`;
  their top surface is y = 0.6. The **street side** of a plot is the side facing the nearest road
  (computed once per lot from the road data and stored as an attribute `Front`).

## 2. The kit

**Structure** (each piece one part or a small model; colour/material variants via a palette, not
separate meshes; greybox now, Blender meshes in the art pass with the same sizes and ids):

| Group | Pieces |
|---|---|
| Floors | floor tile 4×4 (boards, parquet, tiles, flagstones), stair flight (one storey), landing |
| Walls (4 wide × 12 tall bays) | plain (London stock brick yellow/red, stucco white/cream, render), sash window (2 heights), bay window, door bay (front door + fanlight + steps), shopfront (window + door + signboard), arch / carriage entrance (mews), interior wall (plaster, panelled), interior door |
| Roofs | slate pitched (per 4-stud run), mansard with dormer, flat with parapet, gable end, chimney stack (2–8 pots) |
| Trim | cornice, string course, rusticated ground floor, portico columns (Belgravia), railings + gate, front steps, area railings (basement), balcony |
| Outside | garden wall, gate, path, lawn, flower bed, tree (small), water butt, mews door (garage) |

**Decor & furniture** (inside and in gardens): beds, wardrobes, washstands; tables, chairs, sofas,
armchairs; sideboards, bookcases, shelves; fireplace + mantel (with a working fire light), gas
mantles, oil lamps, chandeliers; rugs, curtains, pictures, mirrors, clocks, plants; kitchen range,
dresser, sink; piano (playable, activities/indoors.md); **shop fittings**: counters, display cases,
shelving, till, signboard (SHOPS.md). Paint and **wallpaper** per interior wall face and **floor
finish** per tile, from a period palette (~16 colours, ~10 wallpapers).

**Where pieces come from:** basic structure and a starter furniture set are free and unlimited.
Furniture beyond the starter set is **bought** from furniture dealers (shops: wholesale stock or
made by carpenters, SHOPS.md) and lives in your **storage** until placed. Special furniture sets
are Robux items (DESIGN §11, Q6).

## 3. Rules and limits (checked by the server on every placement)
- **Inside the plot:** the piece's footprint within the lot's bounds; 2-stud setback at the back
  for townhouse gardens/mews is optional.
- **Height limit** by kind (Config `BUILD_MAX_STOREYS`): lodging 2, terrace 3, shop 3,
  townhouse 4, workshop 2, warehouse 4; plus a roof (max 8 studs) and chimneys.
- **Street front:** the bays along the plot's street side, on the ground floor, must be wall pieces
  (plain / window / door / shopfront / arch) with no gaps, and the house needs at least one door
  bay on the street side and a roof over the top storey. Until that's true the build is a
  **draft**: others see the template (§6) and the owner sees their draft. "Publish" checks the
  rules and shows the house to everyone. Streets never get holes or floating rooms.
- **Piece budget** per kind (Config `BUILD_BUDGET`, parts after merging): lodging 120, terrace
  300, shop 300, townhouse 500, workshop 250, warehouse 400. The budget meter is in build mode.
  (Performance: TECH §9 targets phones at 30 FPS; a full server of builds must stay inside the
  streaming budget, checked in T55.)
- **Text:** only the house name plate and the shop sign, both through `Shared.Text`
  (broadcast filter). No other free text, no images uploaded by players.
- **Colours:** palette only.

## 4. Build mode (owner, or key holders with *build* / *decorate*)
- Enter at your property (prompt on the door or a "Build" button when inside the plot). The
  camera switches to a build camera (orbit around the plot; touch: drag/pinch; gamepad: sticks).
- **Catalogue panel** by group with search; the budget meter; a storey selector (show one floor
  at a time, cut-away walls above).
- **Place** (ghost preview snaps to the grid, red when it breaks a rule, with the reason),
  **rotate**, **move**, **delete**, **paint** (pick a palette colour, tap a wall face / floor),
  **copy**, **undo/redo** (50 steps), **templates** (start from one of 3 starter layouts per kind).
- Exit saves. Edits replicate live so visitors see furniture appear.
- Works on touch and gamepad from the start (every action has an on-screen button).

## 5. Save format
Compact, per property, in `PropertyBuild_v1` (PROPERTY §6):
```lua
{ v = 1, kind = "terrace", w = 26, d = 43,            -- the lot size it was built for
  pieces = { { "wall_sash", x, y, z, r, c }, ... },  -- piece id, grid x/z (2-stud cells from the
                                                     -- lot's street-left corner), storey y,
                                                     -- rotation 0-3 (or 0-23 for furniture),
                                                     -- palette index
  faces = { [pieceIndex] = { wallpaper, paint } },  -- interior finishes
  published = true }
```
- Positions are **relative to the lot's street-left corner**, so a build fits any lot of the same
  kind. A lot that's slightly smaller than the one it was built for: pieces outside it go to
  storage and the owner is told (rare; lots of one kind vary by a few studs).
- Validate on load as well as on save (Config may have tightened limits since).

## 6. Templates for unused plots
- Every lot without a loaded player build shows a **template house** for its kind and district,
  chosen by `LotId` so neighbours differ: front colour, window rhythm, door position, roof type,
  chimney count. Built from the same kit at ≤ 6 parts each for unused lots (a front, a roof, a
  door, chimneys merged: there are ~4,000 lots), with full detail only near players (streaming).
- These are the city's buildings until the art pass; the art pass swaps the kit's greybox pieces
  for Blender meshes and every template and player build updates with it.

## 7. Moderation without staff
- Kit-only building, palette-only colours and filtered text keep the worst out by design.
- **"Report this building"** prompt for visitors (reason list). 3 reports from different accounts
  in one server: that server shows the template instead of the build for the rest of the session,
  the owner is told why, and it's logged for the owner panel (Admin logs). Repeat reports across
  sessions put the build back into draft (owner must publish again).
- Builds can't trap players (doors always openable from inside, no sealed rooms around spawns),
  can't block the pavement (plot bounds) and can't exceed the height limit.

## 8. Build order (TASKS)
Kit data + piece builder (P04) → templates on all lots (P05) → build mode: place/rotate/delete +
rules (P06) → save/load (P07) → decorating: furniture, paint, wallpaper, storage (P08) → report
system (P09). See ROADMAP "Phase 3".
