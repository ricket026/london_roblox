# Blender pipeline: from model to Studio

For the Blender agent (Blender MCP) and anyone making meshes. What to make is in `assets.md`,
how it should look in `style.md`, and building-kit sizes in `kit.md` (the contract with the code).
Earlier rules carried over from CoverFire (ART.md §10) still apply: check real game scale every
time, check for z-fighting before export, keep triangle counts low.

## 1. The round trip
1. **Brief:** pick an item from `assets.md` (id, size, budget, colour slots).
2. **Model** in Blender to this guide; **render** a front/three-quarter/top preview with the R15
   reference beside it; the user approves (or asks for changes).
3. **Export** FBX + a **manifest** (§10) into `blender/<batch>/` (TECH §1: the user's
   `London\blender\` folder; only manifests and small files go in git, §11).
4. **Import** in Studio (the user, or a Studio agent): 3D Importer with the settings in §5,
   then wire it per the manifest (kit pieces into `ReplicatedStorage.KitMeshes`, landmarks into
   the map with a backup first).
5. **Check in game:** scale beside a character, collisions walkable, no z-fighting, part/tri
   counts in budget; screenshot for the user.

## 2. Scene setup
- Blender 4.x. **1 Blender unit = 1 stud.** Scene → Units: Unit System *None* (or Metric with
  Unit Scale 1.0, reading metres as studs). Never scale the scene to "real metres".
- Make a `london_reference.blend` once and link it into every file:
  - **R15 proxy**: a 2 × 5.2 × 1 box (shoulder width × height × depth) standing at the origin;
  - **door proxy** 3 × 8, **storey planes** at Y = 0, 12, 24, 36, 48;
  - a **2-stud grid** (overlay grid scale 2) and a 4-stud bay outline;
  - one finished kit piece (`wall_sash`) once it exists, as the look reference.
- Blender is Z-up; Roblox is Y-up. Model with Blender's **Z as up** and the piece's **face toward
  −Y** (what you see in Front view, numpad 1). The exporter converts (§5).

## 3. Modelling rules
- **Simplified real shapes**: chunky cornices, deep window reveals (0.4–0.6 studs), clear
  silhouettes; no hairline mouldings or tiny bevels. One bevel segment on big edges at most.
- **Clean topology**: model in quads, triangulate on export; no n-gons on curved surfaces; no
  interior/duplicate faces; **Merge by Distance**; normals outward (Recalculate Outside) and shade
  flat or by auto-smooth at 30°; no zero-area faces; avoid long thin triangles.
- **No z-fighting**: coplanar faces of different materials must be ≥ 0.02 studs apart (window
  frames in front of glass, signs in front of fascias).
- **Kit pieces tile**: every edge that meets a neighbour sits exactly on the 2-stud grid and on a
  storey line (Y 0 / 12). Nothing outside the footprint in `kit.md`, except `front` pieces, which
  may project up to 2 studs toward the street (−Y in Blender).
- **Apply transforms** (Ctrl+A → All Transforms) before export; scale must read 1, 1, 1.
- **Doors** are a separate object (the leaf) with an empty named `Hinge` on the hinge line
  (manifest `DoorHinge`, the `Doors` module swings it).

## 4. Pivots and orientation
- **Kit pieces and furniture:** origin at the **bottom, at the footprint's min corner** (in kit
  space: x = 0, z = 0, y = 0 → in Blender X = 0, Y = 0, Z = 0 with the face toward −Y and the
  piece extending toward +X and +Y).
- **Landmarks:** origin at the ground centre of the building's footprint, front facing −Y; the
  manifest gives the world position from `map_layout_v2.json`.
- **Vehicles:** origin at ground level under the centre of the chassis, front toward −Y.
- **Props:** origin at the bottom centre.

## 5. Export and import settings
- **FBX export**: selected objects only; Apply Scalings *FBX Units Scale*; Forward **−Z**, Up
  **Y** (Blender's defaults); Apply Transform on; mesh: triangulate, smoothing *Face*; no
  cameras/lights; one FBX per asset (kit pieces may batch, one object per colour slot, §6).
- **Studio 3D Importer**: File Dimensions **Studs** (because 1 BU = 1 stud); Anchored; keep
  hierarchy; materials imported as SurfaceAppearance only where §6 says.
- **Verify once, then write it down here:** import `wall_plain` (4 × 12 × 1) and check Studio
  shows Size 4, 12, 1 and its LookVector points toward the street side (−Z). If the axes or
  units come out wrong, fix the export settings, re-check, and **replace these bullets with the
  settings that worked** so nobody has to rediscover them. Also record whatever settings were used
  for the Buckingham Palace and Parliament imports (DESIGN_NOTES mentions a "fit" step).

## 6. Materials, colour slots, UVs and textures
- **One MeshPart per colour slot.** A piece's colour slots in `kit.md` (face, trim, door...) are
  separate objects named exactly by slot (`face`, `trim`, `door`, `glass`). The game tints each by
  `Part.Color` from the palette, so players can repaint, and one mesh serves every colour.
- **Large surfaces** (brick, stucco, stone, slate, floors) use Roblox **MaterialVariants** from
  `MaterialService` (style.md §5 list) tinted by `Part.Color`. Unwrap these at **world scale:
  1 UV unit = 4 studs**, all pieces the same, so brick courses line up across neighbours. Check the
  tiling on the first imported piece and adjust the MaterialVariant's `StudsPerTile` (or the UV
  scale) once, then record the working values here.
- **Details** (window joinery, door panels, cornice mouldings, signs) use one shared **trim
  sheet** 1024 × 1024 (`T_trim_london`) with a SurfaceAppearance (ColorMap, NormalMap,
  RoughnessMap, MetalnessMap). Greyscale colour maps where the slot is tintable.
- **Texture sizes**: 1024 × 1024 maximum (Roblox scales larger ones down); 512 for props, 256 for
  small furniture. Prefer shared atlases to unique textures. No baked lighting or shadows in
  colour maps. Glass: Roblox Glass material, slight transparency, colour from the palette.
- Max **3 MeshParts (colour slots) per kit piece**, 1–2 per furniture item.

## 7. Budgets (triangles, after triangulation)
| Kind | Budget | Notes |
|---|---|---|
| Kit wall bay | 60–700 (per `kit.md`) | the city has thousands; keep the plain ones tiny |
| Roof / chimney | 20–300 | |
| Furniture | 24–800 (per `kit.md`) | |
| Street prop (lamp, pillar box, bench) | 150–600 | |
| Vehicle | 3,000–6,000 total | wheels separate objects (they spin) |
| Horse | 4,000 + rig | |
| Character outfit piece (3D) | 50–400 each | `assets.md` §6 |
| Landmark | 20,000–60,000 total, split into parts ≤ 10,000 each | split by section (wings, towers) so streaming and the per-mesh limit work |
| Whole player build | the kit budget (BUILDING §3) | |

Roblox has a per-mesh triangle limit (20,000 at the time of writing; check the docs if an import
is refused). Our budgets stay far below it on purpose: phones must hold 30 FPS (TECH §9).

## 8. Collision, rendering and streaming
- **Visual meshes don't collide**: `CanCollide = false`, `CanQuery = false`, `CanTouch = false`.
  The kit code keeps its **greybox parts as invisible colliders** (Transparency 1) under the
  meshes, so doorways stay walkable and collision is cheap. For landmarks, add a few simple
  invisible collision Parts (walls, floors, stairs as ramps) instead of precise mesh collision.
- `RenderFidelity` Automatic; `DoubleSided` off; `CastShadow` off for small trim and furniture.
- Landmarks: `Model.LevelOfDetail = StreamingMesh` so they read from across the city when
  streamed out; kit buildings: `ModelStreamingMode` Atomic.
- No lights inside meshes; the code adds PointLights where `kit.md` says (fireplace, lamps).

## 9. Rigs and special assets
- **Horses**: a custom rig (bones for legs, neck, head, tail), walk/trot/canter/idle animations;
  the user publishes animations and puts their ids in Config (ART §6–7). Ride seat attachment named
  `Saddle`; harness attachments `TraceLeft`, `TraceRight` for carriages.
- **Layered clothing** (later, ART §7): follow Roblox's layered-clothing rules (inner and outer
  cages, the R15 mannequin); until then outfits are 3D part pieces (`assets.md` §6).
- **Doors**: leaf + `Hinge` empty (§3). **Moving landmark parts** (Tower Bridge bascules, clock
  hands): separate objects with pivots on the rotation axis, named in the manifest.

## 10. Manifest (one per export batch)
`blender/<batch>/manifest.json`, read by the Studio agent when wiring things up:
```json
{
  "batch": "kit_walls_v1",
  "assets": [
    {
      "id": "wall_sash",
      "kind": "kit",
      "file": "wall_sash.fbx",
      "size": [4, 12, 1],
      "pivot": "min-corner",
      "slots": [
        { "mesh": "face", "materialVariant": "LondonStockSooted", "defaultColour": "brick_stock_sooted" },
        { "mesh": "trim", "surfaceAppearance": "T_trim_london", "defaultColour": "stone_portland" },
        { "mesh": "glass", "material": "Glass", "defaultColour": "glass" }
      ],
      "attributes": {},
      "tris": 296
    }
  ]
}
```
Kit pieces go into **`ReplicatedStorage.KitMeshes.<id>`**: a Model whose MeshParts are named by
slot, pivot at the min corner. The kit code (`Shared.Kit`) uses the mesh model when it exists and
falls back to greybox parts when it doesn't, so art can arrive one piece at a time.
Doors add `"attributes": { "DoorHinge": [x, y, z], "DoorOpenDeg": 100 }` (Doors module).

## 11. Files and git
- `.blend` files and textures stay in the user's `London\blender\` folder (large binaries; GitHub
  refuses files over 100 MB). Commit **manifests**, preview renders (small PNGs) and FBX files
  under ~10 MB to `blender/` in the repo; anything bigger goes through Git LFS or stays local.
- Name files by asset id: `wall_sash.fbx`, `wall_sash_preview.png`.

## 12. Checklist before handing over
- [ ] Size matches `kit.md` / `assets.md` to 0.01 studs; pivot as §4; transforms applied.
- [ ] Stands next to the R15 proxy at the right scale (door 8 tall, storey 12).
- [ ] Triangles within budget; ≤ 3 colour-slot meshes; textures ≤ 1024.
- [ ] No z-fighting, no inverted normals, no stray vertices, no faces outside the footprint.
- [ ] Neighbouring kit pieces line up (place two side by side and one above).
- [ ] Manifest written; preview render saved; the user has approved the look.
