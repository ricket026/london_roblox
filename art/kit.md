# The building kit: piece specification

Every piece players build with (BUILDING.md) and that templates use for unused plots. **This
table is the contract** between code (`src/shared/Kit.luau`, greybox from parts now) and art
(Blender meshes later, `blender.md`): same ids, same sizes, same pivot. A test
(`tests/test_kit.luau`) checks the code matches this table; change both together.

## Coordinates
- **Lot space:** origin at the plot's **street-left corner** on its top surface; **+X along the
  street** (to your right when you face the house from the street), **+Z into the plot** (away from
  the street), **+Y up**. The server turns lot space into world space from the plot's CFrame and
  its `Front` side.
- **Units:** positions are stored in **half-studs** (0.5). Structure snaps to **2-stud cells**
  (multiples of 4 half-studs); furniture snaps to half-studs. **Storeys** are 12 studs; `y` is
  the storey index (0 = ground).
- **Rotation:** `r` = 0–3, quarter turns clockwise seen from above, about the piece's footprint
  centre. At `r = 0` a wall's **face** looks toward −Z (the street).
- **Footprint:** `w × d` studs at `r = 0`; the piece occupies `[x, x + w] × [z, z + d]` (swapped
  w/d at r = 1 or 3). Height `h` studs from the storey base (floor-standing furniture starts on
  top of the floor, +0.4).
- **Pivot for meshes:** bottom, at the footprint's min corner at r = 0 (blender.md §4).

## Classes and how they may overlap
| Class | Examples | May overlap |
|---|---|---|
| `wall` | wall bays, interior walls | floors (they sit on the floor edge) |
| `floor` | floor tiles, stairs | walls |
| `roof` | roofs, chimneys | nothing |
| `trim` | cornice, portico, steps, railings, balcony | walls (they're fixed to them) |
| `outside` | garden walls, lawn, paths, trees | nothing; ground storey only (`y = 0`) |
| `furniture` | beds, tables, shop fittings | rugs; must stand on a floor |
| `rug` | rugs | furniture; must lie on a floor |

Pieces of the same class never overlap (box test, 0.01-stud tolerance). `front` pieces may stick
out up to 2 studs **in front of** the street edge (into the area/pavement line); nothing else may
leave the plot.

## Pieces

Sizes in studs. **Colour slots**: the palette ids (`art/style.md` §4) a player can repaint, with
the default. **Tris**: budget for the final Blender mesh (greybox uses a handful of parts).

### Walls (bays 4 studs wide, one storey tall, 1 stud thick)
| id | class | w | d | h | front | colour slots (default) | tris | what it is |
|---|---|---|---|---|---|---|---|---|
| `wall_plain` | wall | 4 | 1 | 12 | no | face (`brick_stock_sooted`) | 60 | solid wall bay |
| `wall_sash` | wall | 4 | 1 | 12 | no | face, trim (`stone_portland`) | 300 | sash window 2 × 6, sill and lintel |
| `wall_sash_tall` | wall | 4 | 1 | 12 | no | face, trim | 320 | taller window 2 × 8 (first floor of grand houses) |
| `wall_bay` | wall | 4 | 1 | 12 | yes | face, trim | 600 | canted bay window projecting 1.5 to the street |
| `wall_door` | wall | 4 | 1 | 12 | no | face, door (`door_black`), trim | 420 | front door 3 × 8 with a fanlight; a `Door` leaf (Doors module) |
| `wall_shopfront` | wall | 4 | 1 | 12 | no | face, frame (`shop_maroon`), trim | 700 | plate-glass window, door, fascia sign board |
| `wall_arch` | wall | 4 | 1 | 12 | no | face, door (`timber_dark`) | 380 | carriage arch 4 × 9 with a mews door (townhouses) |
| `wall_interior` | wall | 4 | 0.5 | 12 | no | face (`white_wash`) | 24 | plaster partition (interior) |
| `wall_interior_door` | wall | 4 | 0.5 | 12 | no | face, door (`timber_dark`) | 200 | partition with a panelled door |

### Floors and stairs
| id | class | w | d | h | front | colour slots | tris | what it is |
|---|---|---|---|---|---|---|---|---|
| `floor_boards` | floor | 4 | 4 | 0.4 | no | finish (`timber_light`) | 12 | floorboards |
| `floor_parquet` | floor | 4 | 4 | 0.4 | no | finish (`timber_light`) | 12 | parquet |
| `floor_tiles` | floor | 4 | 4 | 0.4 | no | finish (`stone_portland`) | 12 | encaustic tiles (halls, shops) |
| `floor_flags` | floor | 4 | 4 | 0.4 | no | finish (`flagstone`) | 12 | flagstones (kitchens, yards) |
| `stairs` | floor | 4 | 8 | 12.4 | no | finish (`timber_dark`) | 400 | one flight, up one storey; nothing may be placed in the stairwell above |

### Roofs and chimneys
| id | class | w | d | h | front | colour slots | tris | what it is |
|---|---|---|---|---|---|---|---|---|
| `roof_flat` | roof | 4 | 4 | 1 | no | finish (`lead`) | 20 | flat lead roof with a low parapet edge |
| `roof_pitch` | roof | 4 | 8 | 6 | no | finish (`slate`) | 40 | slope rising from the street side to a ridge at the back; two back to back make a ridge roof |
| `roof_mansard` | roof | 4 | 4 | 8 | no | finish (`slate`) | 60 | steep mansard slope |
| `roof_mansard_dormer` | roof | 4 | 4 | 8 | no | finish, trim (`stucco_white`) | 300 | mansard with a dormer window |
| `chimney` | roof | 2 | 2 | 6 | no | face (`brick_stock_sooted`), pots (`chimney_pot`) | 150 | chimney stack with 4 pots |

### Trim
| id | class | w | d | h | front | colour slots | tris | what it is |
|---|---|---|---|---|---|---|---|---|
| `cornice` | trim | 4 | 1 | 1.5 | yes | face (`stone_portland`) | 80 | moulded cornice at the top of a wall bay |
| `string_course` | trim | 4 | 1 | 0.6 | yes | face (`stone_portland`) | 30 | band between storeys |
| `portico` | trim | 4 | 2 | 10 | yes | face (`stucco_white`) | 900 | two columns and an entablature over a door bay (Belgravia) |
| `steps` | trim | 4 | 2 | 1.5 | yes | face (`stone_portland`) | 60 | 3 front steps |
| `railings` | trim | 4 | 0.5 | 3 | yes | face (`iron_black`) | 400 | iron railings with spear finials |
| `balcony` | trim | 4 | 1.5 | 3.5 | yes | face (`iron_black`) | 500 | iron balcony (storey 1+) |

### Outside
| id | class | w | d | h | front | colour slots | tris | what it is |
|---|---|---|---|---|---|---|---|---|
| `garden_wall` | outside | 4 | 1 | 4 | no | face (`brick_stock_sooted`) | 40 | yard / garden wall |
| `garden_gate` | outside | 4 | 1 | 4 | no | face (`timber_dark`) | 120 | gate in a garden wall |
| `lawn` | outside | 4 | 4 | 0.3 | no | finish (`grass`) | 12 | grass |
| `path` | outside | 4 | 4 | 0.3 | no | finish (`gravel`) | 12 | gravel or flag path |
| `flower_bed` | outside | 4 | 2 | 1 | no | finish (`foliage`) | 200 | bed with flowers |
| `tree_small` | outside | 2 | 2 | 10 | no | finish (`foliage`) | 400 | small tree (lime, plane) |

### Furniture (half-stud grid, stands on a floor)
| id | class | w | d | h | front | colour slots | tris | what it is |
|---|---|---|---|---|---|---|---|---|
| `bed_single` | furniture | 3 | 6 | 2.5 | no | wood (`timber_dark`), cloth (`stucco_cream`) | 400 | iron or wood single bed |
| `bed_double` | furniture | 5 | 6 | 3 | no | wood, cloth | 600 | double bed with headboard |
| `wardrobe` | furniture | 4 | 2 | 7 | no | wood | 300 | wardrobe |
| `washstand` | furniture | 3 | 1.5 | 3 | no | wood | 300 | washstand with jug and basin |
| `table_dining` | furniture | 4 | 6 | 3 | no | wood | 300 | dining table |
| `table_small` | furniture | 2.5 | 2.5 | 3 | no | wood | 200 | side / tea table |
| `chair` | furniture | 1.5 | 1.5 | 3.5 | no | wood, cloth | 250 | dining chair (a seat) |
| `armchair` | furniture | 2.5 | 2.5 | 3.5 | no | cloth (`door_oxblood`) | 500 | button-back armchair (a seat) |
| `sofa` | furniture | 6 | 2.5 | 3.5 | no | cloth | 700 | chesterfield (2 seats) |
| `sideboard` | furniture | 5 | 1.5 | 3.5 | no | wood | 300 | sideboard |
| `bookcase` | furniture | 4 | 1.5 | 7 | no | wood | 500 | bookcase with books |
| `desk` | furniture | 4 | 2.5 | 3 | no | wood | 300 | writing desk |
| `fireplace` | furniture | 4 | 1.5 | 4.5 | no | face (`stone_portland`) | 400 | fireplace and mantel; flickering light |
| `standard_lamp` | furniture | 1 | 1 | 5 | no | metal (`gilt`) | 200 | oil standard lamp; light |
| `chandelier` | furniture | 3 | 3 | 3 | no | metal (`gilt`) | 800 | hangs from the ceiling of its storey; light |
| `clock_long` | furniture | 1.5 | 1 | 7 | no | wood | 300 | longcase clock |
| `plant_pot` | furniture | 1.5 | 1.5 | 3 | no | finish (`foliage`) | 300 | aspidistra in a pot |
| `piano_upright` | furniture | 5 | 2 | 4.5 | no | wood | 600 | upright piano (playable, activities/indoors.md) |
| `kitchen_range` | furniture | 4 | 2 | 4 | no | metal (`iron_black`) | 500 | cast-iron range |
| `dresser` | furniture | 4 | 1.5 | 7 | no | wood | 500 | kitchen dresser with plates |
| `sink` | furniture | 3 | 2 | 3 | no | face (`stone_portland`) | 200 | stone sink |
| `rug` | rug | 6 | 4 | 0.1 | no | cloth (`door_oxblood`) | 8 | rug (other furniture may stand on it) |
| `counter` | furniture | 4 | 2 | 3.5 | no | wood, top (`timber_light`) | 250 | shop counter |
| `counter_till` | furniture | 4 | 2 | 4.5 | no | wood, top | 450 | shop counter with a till (SHOPS §2) |
| `display_case` | furniture | 4 | 2 | 3.5 | no | wood | 400 | glass-topped display case (stock shows in it) |
| `shelving` | furniture | 4 | 1.5 | 8 | no | wood | 300 | shop shelving (stock shows on it) |
| `barrel` | furniture | 2 | 2 | 3 | no | wood | 200 | barrel |
| `crate` | furniture | 2 | 2 | 2 | no | wood | 24 | crate |
| `flower_stand` | furniture | 4 | 2 | 3 | no | wood | 600 | tiered flower stand (florists) |

**Starter set** (free and unlimited, BUILDING §2): every structure, trim and outside piece, plus
`bed_single`, `chair`, `table_small`, `washstand`, `rug`, `counter`, `shelving`, `crate`.
Everything else is bought (furniture dealers, carpenters) and kept in storage.

## Height limits and budgets (BUILDING §3)
| Kind | Max storeys | Piece budget |
|---|---|---|
| lodging | 2 | 120 |
| terrace | 3 | 300 |
| shop | 3 | 300 |
| townhouse | 4 | 500 |
| workshop | 2 | 250 |
| warehouse | 4 | 400 |

Roofs and chimneys may sit on the storey above the top one (`y = max storeys`).

## Templates for unused plots (BUILDING §6)
≤ 8 parts each: facade block (frontage × 1 × storeys·12), body block behind it, one glass band per
storey, a roof (wedges or a slab), a door, one chimney. Storeys by kind (lodging 2, terrace 3,
townhouse 4, shop 3 with a shopfront band, workshop 2, warehouse 4). Colour and roof style picked
from the district's palette by `LotId` (deterministic), so neighbours differ but never change.
