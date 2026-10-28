# Asset list: everything to make

What needs modelling (or sourcing), with sizes in studs, triangle budgets and priority. Look:
`style.md`; pipeline and budgets: `blender.md`; kit pieces: `kit.md`. **P1** = needed for the
next phases (homes, shops, the city looking finished), **P2** = for systems after that, **P3** =
nice to have. Status: ✅ in the place, 🟡 greybox only, ⬜ not started, 🔒 the user must supply it.

## 1. Building kit (P1)
All pieces in `kit.md`. Order of work, so streets look finished soonest (templates use these
first): `wall_plain`, `wall_sash`, `wall_door`, `roof_pitch`, `chimney`, `cornice`,
`wall_shopfront`, `steps`, `railings`, `floor_boards`, then the rest. 🟡 greybox in code (Shared.Kit).

## 2. Street furniture (P1)
| id | size (w × d × h) | tris | notes |
|---|---|---|---|
| `gas_lamp` | 1.2 × 1.2 × 11 | 300 | iron post, lantern with 4 glass panes; a PointLight at the lantern (JOBS lamplighter, TASKS T04) |
| `gas_lamp_wall` | 1 × 2 × 3 | 200 | bracket lamp on a wall (lanes, mews) |
| `pillar_box` | 1.6 × 1.6 × 4.5 | 300 | red, fluted Penfold-style |
| `horse_trough` | 6 × 2 × 2.5 | 150 | granite |
| `cab_shelter` | 6 × 14 × 9 | 800 | green timber hut at cab ranks |
| `advertising_column` | 3 × 3 × 10 | 300 | round, posters (fictional brands) |
| `bench_park` | 6 × 2 × 3 | 250 | iron and slats |
| `railings_park` | 4 × 0.5 × 3.5 | 300 | park railings (green) |
| `telegraph_pole` | 1 × 1 × 20 | 200 | outer districts; wires as Beams |
| `bollard` | 1 × 1 × 3 | 60 | iron |
| `street_sign` | 3 × 0.2 × 1 | 20 | enamel plate on a wall, street name text |
| `drinking_fountain` | 3 × 3 × 5 | 400 | granite, in parks |
| `newspaper_stand` | 4 × 2 × 4 | 300 | newsboy corners (JOBS §4) |
| `market_stall` | 6 × 4 × 7 | 500 | striped awning; Covent Garden, Spitalfields (SHOPS §5) |
| `tree_plane` | 10 × 10 × 30 | 1,200 | London plane, parks and squares |
| `deckchair` | 2 × 3 × 3 | 150 | parks (green-striped canvas) |

## 3. Activity props (P1–P2, see `activities/`)
| id | for | size | tris |
|---|---|---|---|
| `seed_stand` | ducks | 4 × 2 × 5 | 300 |
| `strength_machine` | test your strength | pad 3 × 3, pole 22 tall, bell | 800 |
| `chess_table` + seats | chess | 4.4 × 4.4 × 2.8 | 400 |
| `tide_sign`, `board_notice` | mudlarking, every site | 9 × 0.4 × 6.5 | 100 |
| `croquet_set` | croquet | hoops 1 × 0.1 × 1.2, peg, mallet, balls | 300 |
| `rowing_boat` | rowing, regatta | 8 × 3 × 1.5 (4-seat 14 long) | 1,200 |
| `model_boat` | model boats | 2 × 0.6 × 2 | 300 |
| `bandstand` | concerts | octagon 24 across, 12 tall | 4,000 |
| `kite` | kites | 2 × 3 | 50 |
| `coconut_shy`, `hoopla_stall` | fairground | 10 × 6 × 8 | 1,000 each |
| `carousel` | fairground | 22 across, 14 tall | 8,000 (horses instanced) |
| `swing_boats` | fairground | 10 × 6 × 10 | 2,000 |
| `helter_skelter` | fairground | 10 × 10 × 30 | 4,000 |
| `balloon` | balloon ride | basket 6 × 6, envelope 20 across | 2,500 |
| `cricket_net` | cricket | 6 × 22 × 8 | 600 |
| `punch_judy_booth` | Punch & Judy | 4 × 3 × 9 | 800 |
| `billiards_table` | billiards | 12 × 6 × 3 | 900 |
| `fishing_rod` | fishing | 8 long | 100 |
| `camera_box` | photography | 1.5 × 2 × 1.5 on a tripod | 300 |
| `curio_*` × 100 | curiosities hunt | 0.5–3 | 50–300 each |

## 4. Vehicles (P2, VEHICLES.md; liveries style.md §9)
Width ≤ 7 so two pass on a 24-stud main road. Wheels separate (they spin).
| id | size (l × w × h) | tris | seats |
|---|---|---|---|
| `bicycle` | 6 × 1.5 × 4 | 1,500 | 1 |
| `penny_farthing` | 6 × 1.5 × 6 | 1,500 | 1 |
| `hansom_cab` | 10 × 6 × 9 (+ horse) | 4,000 | driver + 2 |
| `four_wheeler` | 12 × 6.5 × 8 (+ horse) | 4,500 | driver + 4 |
| `omnibus` | 18 × 7 × 12 (+ 2 horses) | 6,000 | driver + 10 (top deck open) |
| `brougham`, `landau`, `state_landau` | 12 × 6.5 × 8 | 4,500 each | 2–4 |
| `delivery_van`, `dray` | 12 × 6.5 × 8 | 4,000 | 1 + 1 |
| `police_van` | 12 × 6.5 × 9 | 4,000 | 1 + 1 + cells |
| `fire_engine_steam` | 14 × 6.5 × 9 | 6,000 | 1 + 3 |
| `motor_carriage` | 10 × 5 × 7 | 5,000 | 2 |
| `motor_tourer` | 13 × 5.5 × 7 | 6,000 | 4 |
| `steam_launch`, `river_steamer` (P3) | 20–40 long | 6,000–12,000 | |

## 5. Animals (P2)
| id | notes | tris |
|---|---|---|
| `horse` | rigged; walk/trot/canter/idle (🔒 animations published by the user) | 4,000 |
| `duck`, `swan`, `pelican`, `pigeon`, `moorhen`, `coot` | simple shapes, bob/paddle animation by code | 100–300 |
| `cat`, `dog` (P3) | curiosities, ambience | 600 |

## 6. Character outfit pieces, 3D (P1 for TASKS T06)
Attached to the R15 body by welds; sized from the character's limbs at spawn (so they fit any
avatar). Size given for a standard R15 (UpperTorso 2 × 1.6 × 1). Colours from the outfit preset.
| id | attach to | size (approx.) | used by |
|---|---|---|---|
| `top_hat` | Head | 1.3 × 1.3 × 1.6 | frock coat |
| `bowler` | Head | 1.4 × 1.4 × 0.9 | tweed suit |
| `flat_cap` | Head | 1.4 × 1.6 × 0.5 | working clothes |
| `bonnet` | Head | 1.6 × 1.6 × 1.3 | day dress |
| `small_hat` | Head | 1.4 × 1.4 × 0.6 | walking costume |
| `mob_cap` | Head | 1.4 × 1.4 × 0.6 | plain dress & apron |
| `coat_tails` | LowerTorso | 2.2 × 0.4 × 2.6 (back) | frock coat |
| `jacket_hem` | LowerTorso | 2.2 × 1.2 × 0.8 | tweed suit, walking costume |
| `waistcoat_front` | UpperTorso | 1.6 × 0.15 × 1.4 | frock coat, tweed, working |
| `cravat` / `neckerchief` | UpperTorso | 0.6 × 0.3 × 0.6 | frock coat / working |
| `bodice_front` | UpperTorso | 1.8 × 0.2 × 1.5 | day dress, walking costume |
| `bell_skirt` | LowerTorso | 3.2 × 2.6 × 3.4 (to the ground; hides the legs) | day dress, plain dress |
| `a_line_skirt` | LowerTorso | 2.8 × 2.2 × 3.4 | walking costume |
| `apron_front` | LowerTorso | 1.8 × 0.2 × 2.8 | plain dress & apron, shopkeepers |
| `shawl` | UpperTorso | 2.4 × 1.4 × 1 | P2 |
| uniforms (P2): `police_helmet`, `police_tunic_front`, `guards_bearskin`, `guards_tunic_front`, `guard_belt` | | | role uniforms (PROPERTY_WARDROBE §3) |

## 7. Landmarks (P1–P3; footprints from `map_layout_v2.json`)
Game-scale versions of the real buildings at these footprints (w along X, d along Z, height h,
centre). Buckingham Palace ✅ and the Houses of Parliament ✅ are in the place (ROADMAP landmark
track L1–L2, with interiors for the palace). Next by the roadmap: **Tower Bridge** (L3, moving
bascules for the bridge-lift event) and the **Charing Cross terminus** (L4, the spawn).
| Landmark | Footprint w × d | h | Centre (x, z) |
|---|---|---|---|
| St James's Palace | 205 × 140 | 30 | (-132, -530) |
| Wellington Barracks | 76 × 222 | 30 | (700, -251) |
| Horse Guards | 170 × 36 | 35 | (245, -1018) |
| Westminster Abbey | 150 × 130 | 60 | (860, -825) |
| Tate Gallery | 130 × 210 | 35 | (1075, -225) |
| National Gallery | 85 × 126 | 40 | (-232, -1093) |
| Nelson's Column | 16 × 16 | 170 | (-20, -1070) |
| Charing Cross Terminus | 530 × 240 | 50 | (555, -1350) |
| Scotland Yard | 185 × 70 | 45 | (972, -1265) |
| Savoy Hotel | 200 × 100 | 50 | (370, -1550) |
| Somerset House | 250 × 120 | 40 | (395, -1700) |
| Royal Courts of Justice | 145 × 125 | 50 | (132, -1728) |
| St Paul's, Covent Garden | 120 × 28 | 30 | (-140, -1282) |
| Covent Garden Market | 100 × 120 | 22 | (-140, -1400) |
| Royal Opera House | 100 × 40 | 40 | (-330, -1525) |
| Bow Street Police Court | 80 × 44 | 30 | (-320, -1598) |
| Theatre Royal, Drury Lane | 100 × 75 | 40 | (-280, -1702) |
| British Museum | 140 × 160 | 40 | (-1030, -1380) |
| St Paul's Cathedral | 340 × 190 | 60 | (240, -2235) |
| St Paul's Dome | 120 × 120 | 150 | (240, -2240) |
| Newgate Prison | 126 × 55 | 35 | (-137, -2058) |
| Old Bailey | 240 × 54 | 40 | (80, -2057) |
| Smithfield Market | 164 × 100 | 25 | (-602, -2078) |
| Bank of England | 180 × 200 | 40 | (-110, -2540) |
| Royal Exchange | 78 × 52 | 45 | (55, -2674) |
| Mansion House | 125 × 80 | 40 | (162, -2520) |
| The Monument | 16 × 16 | 200 | (930, -2560) |
| Liverpool Street Station | 240 × 92 | 45 | (-680, -2668) |
| Tower of London | 290 × 225 | 50 | (935, -2862) |
| Royal Mint | 120 × 120 | 35 | (620, -3090) |
| Leman Street Police Station | 100 × 60 | 30 | (330, -3130) |
| St Thomas' Hospital | 170 × 530 | 40 | (1555, -885) |
| Lambeth Palace | 124 × 105 | 35 | (1568, -452) |
| Southwark Cathedral | 96 × 90 | 45 | (1552, -2525) |
| Victoria Station | 140 × 300 | 40 | (1070, 270) |
| Buckingham Palace | 488 × 475 | – | (0, 294) |
| Houses of Parliament | 170 × 414 | – | (1063, -955) |

Priority beyond L3–L4: the hubs first (PLAYER_GATHERING): Covent Garden Market hall and St Paul's
Covent Garden, Nelson's Column and the National Gallery (Trafalgar Square), Horse Guards and
St James's Palace (the Mall), then St Paul's Cathedral, the Bank and Royal Exchange, Scotland Yard,
the Old Bailey, the Tower of London, Westminster Abbey. Each landmark: ≤ 60,000 tris split into
sections ≤ 10,000, `LevelOfDetail = StreamingMesh`, simple invisible collision (blender.md §8).

## 8. Interiors (P2)
Kit-built where possible (houses, shops, the tea room, clubs). One-off interiors: Old Bailey
courtroom and the Bow Street police court (LAW §5), cells, the Commons chamber, the music hall
stage and auditorium, a bank hall with counters, a post office, Scotland Yard's case office, a
hospital ward (LAW §1 respawn), an estate agent's office (PROPERTY §3).

## 9. UI art (🔒 needs the user's references, ART §8)
9-slice panel sets for the chosen style, buttons, one icon sheet: money (£ s d), the six hobbies,
station groups, item categories (SHOPS §1), property kinds, map markers (cab rank, bus stop, shop,
event, home), wanted/police, court, parliament.

## 10. Audio (🔒 picks from the Roblox audio library; ids go in Config)
Strength-machine bell, steam organ (carousel), brass band pieces (bandstand, Changing of the
Guard), waltz and quadrille music, piano notes, hooves on setts, cab wheels, omnibus bell, police
whistle, Big Ben chimes and quarters, church bells, river horns, train whistle and steam, crowd
murmur and applause, market cries, rain, wind, fire crackle, ducks and pigeons, door open/close,
till bell (shops).
