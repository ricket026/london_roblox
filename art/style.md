# Visual style guide: London, 1897

How the game should look, for anyone modelling, texturing, placing props, lighting or choosing
colours. The technical side (Blender, scale, export, budgets) is `blender.md`; building-kit pieces
are `kit.md`; the list of everything to make is `assets.md`. ART.md is the original plan; this
guide is the detailed version and wins where they differ.

## 1. Pillars of the look
1. **Readable first.** A phone screen at 30 metres must tell a cab from an omnibus, a constable
   from a guardsman, a shop from a house. Strong silhouettes and big colour blocks; detail is a
   bonus that appears up close.
2. **Late Victorian, not "generic old".** 1897 London: gaslight and early electric light, horses
   *and* the first motor cars, soot-black brick beside fresh white stucco, enamel advertising.
   Avoid medieval, Tudor-beam, fantasy-steampunk and Georgian-only looks.
3. **Grime with colour.** The base city is soot greys, browns and stone; colour comes from the
   things people wear, drive and sell: liveries, shopfronts, painted doors, flower stalls,
   uniforms. Keep saturated colour for *those*, so they pop.
4. **Stylised realism.** Real proportions and materials, simplified shapes (chunky cornices,
   no hairline mouldings), no noisy micro-detail, no photo textures with baked shadows.
5. **One kit, one palette.** Everything is built from shared pieces and named colours, so the
   city feels made by one hand and the art pass can swap greybox for final meshes in one go.

## 2. The city by district
Each district has a **lot type**, **dominant materials** and **one or two accents**. Use the
palette ids in §4.

| District | Lot type | Look | Materials | Accents |
|---|---|---|---|---|
| Mayfair, Belgravia | Townhouse | grand terraces and squares, white stucco fronts, porticos with columns, black railings, area steps | stucco white/cream (`stucco_white`, `stucco_cream`), slate, iron | glossy front doors (`door_black`, `door_green`), brass |
| St James's | Club | gentlemen's clubs: Portland stone, tall sash windows, balustrades | `stone_portland`, `slate` | gilt lettering |
| Westminster, Whitehall | Terrace / Government | stone ministries, Gothic Revival near Parliament, sober terraces | `stone_portland`, `stone_bath`, `brick_stock_sooted` | royal red (`livery_royal_red`), gold |
| West End, Soho | Shop | busy shopfronts on narrow streets, theatre canopies, signs on every frontage | `brick_red`, `brick_stock`, painted shopfronts | enamel signs, striped awnings |
| Covent Garden | Shop | the market hall (iron and glass), flower and fruit stalls, St Paul's portico | `brick_red`, `iron_green`, `glass` | flowers, crates, awnings |
| Holborn & Bloomsbury | Terrace | plain brick terraces around garden squares | `brick_stock`, `brick_stock_sooted` | coloured doors, window boxes |
| Fleet Street, Strand & Temple | Office | newspaper offices, banks of tall windows, signs and clocks | `brick_red`, `stone_portland` | newspaper signs, gilt clocks |
| The City | Office | banks, the Exchange, St Paul's dome: grand stone | `stone_portland` (sooted lower floors) | gilt, flags |
| Clerkenwell & Moorfields | Workshop | workshops with big ground-floor doors and yards | `brick_stock_sooted`, timber | painted trade signs |
| Tower, Docks, Bankside, Southwark | Warehouse | tall brick warehouses with loading doors and cranes, wharves | `brick_stock_sooted`, `brick_blue`, timber, `iron_black` | ships' colours, crates |
| East End | Lodging | crowded lodging houses, narrow streets, washing lines, gaslit alleys | `brick_stock_sooted`, render | small shops, posters |
| Lambeth (south bank) | Terrace | plainer terraces; St Thomas' Hospital and Lambeth Palace | `brick_stock`, `stone_bath` | |
| Parks | – | lawns, gravel paths, plane trees, iron railings, the lake | `grass`, `gravel`, `iron_black` | flower beds, deckchairs |

**Street level everywhere:** granite kerbs, granite setts or cobbles on main roads (wood blocks in
the West End's grand streets), flagstone pavements, gas lamps, pillar boxes, horse troughs,
cab shelters, advertising columns, iron railings, telegraph wires on poles in the outer districts.
Main roads are wide enough for two carriages; lanes and mews are narrower.

## 3. Architecture vocabulary (what pieces look like)
- **Storeys** are 12 studs; ground floors of grand houses are taller-looking via a rusticated
  base (horizontal grooves) rather than extra height.
- **Windows**: tall vertical sash windows, 4 studs wide, with a stone sill and lintel; 2 storeys of
  a terrace have the same window rhythm; top floor smaller windows; dormers in mansard roofs.
- **Doors**: panelled front door with a semicircular **fanlight**, 2–3 steps up, often with a
  portico (columns) in Belgravia; shop doors are part of the shopfront, recessed.
- **Shopfronts**: big plate-glass window on a stall riser, pilasters each side, a **fascia**
  (signboard) above with the shop's name, often a canvas awning; living rooms above.
- **Roofs**: grey Welsh slate, pitched behind a parapet in terraces; mansard roofs with dormers on
  grand houses; forests of **chimney stacks** with clay pots (2–8 per stack) on party walls.
- **Trim**: stone cornice under the parapet, string course between floors, quoins on corners of
  stone buildings, iron balconies on first floors in Mayfair.
- **Landmarks** keep their real silhouettes (Buckingham Palace east front of 1850, the Houses of
  Parliament and clock tower, Tower Bridge with its bascules, St Paul's dome) at game scale; see
  `assets.md`.

## 4. Palette (named colours)
Used by the building kit, props and liveries. Values are sRGB 0–255. In code: `Shared.Palette`
(same ids). Add colours here first, then in code; don't eyeball new ones in Studio.

| id | RGB | Use |
|---|---|---|
| `brick_stock` | 196, 170, 120 | London stock brick, clean (yellow) |
| `brick_stock_sooted` | 120, 104, 82 | stock brick, sooted (most of the city) |
| `brick_red` | 150, 72, 54 | red brick (West End, Fleet Street) |
| `brick_blue` | 64, 66, 76 | blue engineering brick (docks, railway) |
| `stucco_white` | 236, 232, 222 | Belgravia/Mayfair fronts |
| `stucco_cream` | 224, 212, 186 | stucco, warmer |
| `stone_portland` | 214, 208, 194 | Portland stone (clubs, ministries, the City) |
| `stone_bath` | 206, 186, 146 | Bath stone, warmer |
| `stone_sooted` | 120, 116, 108 | lower storeys of stone buildings, soot |
| `render_grey` | 168, 164, 156 | plain render (East End) |
| `slate` | 74, 78, 86 | roofs |
| `lead` | 110, 114, 118 | flat roofs, bays |
| `chimney_pot` | 172, 98, 70 | clay pots |
| `iron_black` | 28, 28, 30 | railings, lamps, gates |
| `iron_green` | 52, 82, 66 | Covent Garden market ironwork, park railings |
| `timber_dark` | 76, 54, 38 | doors, beams, crates |
| `timber_light` | 156, 120, 80 | floors, furniture |
| `glass` | 150, 170, 180 | windows (Glass material, low transparency) |
| `door_black` | 22, 22, 24 | front doors |
| `door_green` | 30, 64, 46 | Brunswick green doors |
| `door_oxblood` | 96, 28, 28 | front doors |
| `door_navy` | 28, 38, 64 | front doors |
| `door_ochre` | 180, 132, 52 | shop doors |
| `shop_cream` | 232, 220, 190 | shopfront paint |
| `shop_maroon` | 104, 34, 40 | shopfront paint |
| `shop_teal` | 40, 92, 96 | shopfront paint |
| `gilt` | 196, 160, 72 | lettering, frames, royal trim |
| `livery_royal_red` | 170, 24, 30 | royal carriages, Guards' tunics |
| `livery_police_navy` | 24, 30, 52 | police uniforms, police van |
| `livery_cab_green` | 44, 70, 52 | hansom cabs |
| `livery_omnibus_red` | 150, 40, 36 | omnibus (one company) |
| `livery_omnibus_yellow` | 196, 160, 60 | omnibus (another company) |
| `canvas_stripe_red` | 170, 54, 48 | awnings |
| `canvas_stripe_green` | 52, 104, 70 | awnings |
| `grass` | 82, 112, 60 | lawns |
| `foliage` | 60, 88, 48 | trees, hedges |
| `gravel` | 178, 166, 140 | park paths, Rotten Row (sand) |
| `setts` | 102, 102, 106 | granite setts, kerbs |
| `flagstone` | 150, 146, 138 | pavements |
| `water_thames` | 76, 84, 78 | the river |
| `water_lake` | 86, 104, 96 | park lake |

**Wallpapers and paints (interiors, BUILDING §2):** 10 period wallpapers (William Morris-style
leaf, damask red, damask green, stripe cream, stripe blue, flock gold, plain ochre, plain sage,
plain duck-egg, panelled oak) and the paint colours above plus `white_wash` (240, 236, 226).

## 5. Materials
- Use Roblox built-in materials for greybox and for large plain surfaces: Brick, Concrete
  (stucco/render), Slate, Cobblestone (setts), Wood/WoodPlanks, Metal (iron), Glass, Grass,
  Ground, Fabric, Marble (palace interiors).
- **MaterialVariants** (custom materials in `MaterialService`) for the art pass: `LondonStock`,
  `LondonStockSooted`, `RedBrick`, `Stucco`, `PortlandStone`, `WelshSlate`, `GraniteSetts`,
  `Flagstone`, `OakFloor`, `Parquet`. One set, used everywhere; colour variants come from
  `Part.Color` tint, not separate textures (blender.md §6).
- Shiny is rare: brass, polished doors, glass, wet cobbles in rain. Everything else is matte.

## 6. Lighting and atmosphere
Driven by `WorldClock` (24-minute day) and the weather (TASKS T07). Starting values:

| Phase | Lighting | Atmosphere | Notes |
|---|---|---|---|
| Day | Brightness 2, warm-white sun, OutdoorAmbient (128, 124, 118) | Density 0.32, Haze 1.6, Color (199, 190, 175) | a hazy, sooty London sky, never clean blue |
| Dusk | sun low and orange, ambient dropping | Density 0.38, Glare 0.4 | lamplighters start; windows begin to glow |
| Night | Brightness 0.5, cool ambient (52, 56, 72) | Density 0.45, Color (70, 74, 90) | gas lamps make warm pools (PointLight range 22, colour (255, 196, 120)); lit windows |
| Dawn | pale, cool | Density 0.40 | |
| Pea-souper (event) | dim | Density 0.75–0.85, Color (170, 160, 110) yellow-brown | visibility ~60 studs |
| Rain | Brightness −20% | Density +0.05 | wet look via darker colours, puddle decals |

**Lights:** gas lamps warm orange, few and pooled; electric light (palace, theatres, the Savoy) is
whiter and brighter, a status signal. Interior lights: fireplace flicker, oil lamps.
Keep the number of real-time lights low (assets.md budgets); window glow uses Neon panes, not lights.

## 7. Signs, lettering and brands
- **Fictional brands only** (DESIGN §12): "Pemberton's Pale Soap", "Thackeray & Sons, Purveyors of
  Fine Teas", "The Daily Courier". No real companies, even historical ones.
- Lettering: serif or slab-serif capitals for fascias, gilt on dark or dark on cream; enamel
  signs in bright flat colours with a white border; posters on hoardings. Player shop signs use
  the same fascia style (SHOPS §2) with filtered text.
- In-game typography in the world (fascias, boards): Garamond-like serif for now (`Enum.Font.
  Garamond`), until the UI pass picks fonts from references.

## 8. People and clothing
- **Silhouette by station** so roles read at a glance: top hats and frock coats (gentry),
  bowlers (clerks), flat caps and waistcoats (labour), custodian helmets (police), bearskins and
  scarlet (Guards), bonnets and bustled or A-line skirts (women's day dress), aprons (servants,
  shopkeepers), crowns and robes (the Crown, events only).
- Players keep their own face and body; clothing is period only (PROPERTY_WARDROBE §3). The 3D
  part outfits (TASKS T06) are built from simple shapes in the palette colours (`assets.md` §6).
- No real people, no real royal likenesses.

## 9. Vehicles and animals
- Vehicles in fictional liveries (palette `livery_*`), black running gear, big spoked wheels.
  Hansom cab: two wheels, driver high behind. Omnibus: double deck, knifeboard seating on top,
  advertising boards along the top deck. Motor carriage: tall, spindly, brass lamps; rare and
  showy. Police van: navy, closed.
- Horses are the hardest asset (ART §6): a rigged horse with walk/trot/canter; until it exists,
  a simple blocky horse model animated by bobbing.
- Birds (ducks, swans, pigeons) and park animals are small and stylised (activities/park.md).

## 10. UI direction (until the user's references arrive)
Keep the stub UI plain (CLAUDE.md). Candidate directions for the UI pass, all period-correct:
newspaper broadsheet columns, playbill posters, enamel-sign plaques, brass and mahogany for court
menus, telegram forms for messages, calling cards for invitations. The pass chooses one from the
user's references and builds it from hand-made 9-slice images and one icon sheet (ART §8).

## 11. Don'ts
No modern items (tarmac lines, plastic, neon signs, electric street lights outside the West End's
few arc lamps), no fantasy/steampunk gadgets, no real brands or people, no gore, no alcohol
signage (pubs become tea rooms and coffee houses), no Union Jack overload (flags on ministries
and the palace, bunting for events), no Jack the Ripper imagery.
