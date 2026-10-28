# Art: design and Blender guidelines

| File | For |
|---|---|
| [style.md](style.md) | the look: pillars, districts, architecture, **palette** (ids used in code), materials, lighting, signs, people, vehicles, UI direction, don'ts |
| [kit.md](kit.md) | the **building kit contract**: every piece's id, size, class, colour slots and budget; coordinates; height limits; templates |
| [blender.md](blender.md) | the **pipeline**: scene setup, modelling rules, pivots, export/import, colour slots and MaterialVariants, budgets, collision, rigs, manifests, files, checklist |
| [assets.md](assets.md) | **everything to make**, with sizes, budgets and priorities: kit, street furniture, activity props, vehicles, animals, 3D outfit pieces, landmarks (footprints from the map), interiors, UI art, audio |

ART.md (repo root) is the original plan; these are the working detail and win where they differ.
Code that uses them: `Shared.Palette` (palette ids), `Shared.Kit` (kit pieces; uses meshes from
`ReplicatedStorage.KitMeshes` when they exist, greybox otherwise).
