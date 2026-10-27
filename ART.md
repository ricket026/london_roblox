# Art & Assets Plan

Era: **1897** (late Victorian). See DESIGN.md §3.

## 1. Direction
Late Victorian London: soot-darkened yellow and red London stock brick, white stucco terraces
in Belgravia, Portland stone and Gothic Revival landmarks, slate roofs, forests of chimney pots,
black iron railings, granite setts and cobbles, gas lamps, painted shop signs and enamel
adverts (fictional brands), telegraph wires overhead.
Palette: soot greys and browns lifted by livery colours (royal red and gold, Guards' scarlet,
police navy, bus and cab liveries in green, red and yellow).
Readable from a phone at a distance: strong silhouettes, no noisy micro-detail.

## 2. Scale
Game scale, like CoverFire: Roblox characters are ~5 studs tall, so doors ~8 studs, storeys
~12 studs. Streets narrower than real ones so the city feels dense, but **wide enough for two
carriages to pass** (vehicles need it). Check every Blender model's scale against an R15 dummy
before export. Vehicles follow the CoverFire vehicle rules (game-scale sizing, see §6).

## 3. Modular building kit (Blender)
Built once, used everywhere, one shared texture atlas:
- Wall bays: stock brick, stucco, brick with sash window (2 heights), bay window, shopfront
  with signboard, pub-style frontage reused as tea room, door bay, corner.
- Doors: panelled front door with fanlight and steps, shop door, mews stable/garage door.
- Roofs: slate pitched, mansard with dormers, parapet, chimney stacks (2–8 pots).
- Trim: stone cornice, string courses, rusticated ground floor, porticos (Belgravia).
- Street: railings + gates, gas lamp (lit/unlit), pillar box, cab rank shelter, horse trough,
  bollards, telegraph pole, market stall, crates, barrels, sandwich-board, advertising column.
- Colour and dirt variants through materials, not separate meshes.

## 4. Landmarks (one-off models)
In build order:
1. **Buckingham Palace** — the mid-Victorian east front (pale stone, central balcony, wings
   around a forecourt), railings and gates, sentry boxes, the Mall approach. Throne room and
   ballroom interiors.
2. **Houses of Parliament + clock tower** — Gothic Revival; Commons chamber interior.
3. **Tower Bridge** — with lifting bascules (an event), plus the Tower of London as backdrop.
4. **Railway terminus** — iron-and-glass train shed, platforms, a train.
5. Cathedral (dome), Bank and Royal Exchange, Scotland Yard, police court + prison, theatre /
   music hall, Fleet Street offices, docks with cranes and steamers.

## 5. Interiors
Palace throne room, ballroom, Commons chamber, police court, cells, townhouse (3 layouts),
tea room, newspaper press room, motor showroom, stables/mews, tailor.

## 6. Vehicles
Reuse CoverFire's vehicle pipeline lessons (game-scale sizing, damage states where needed,
shared atlases, one bake per call). Fictional makers and liveries only.
- First wave: hansom cab, horse omnibus, bicycle, early 2-seat motor carriage, police van.
- Second wave: four-wheeler, brougham, landau, state landau, delivery vans, steam fire engine,
  tourer motor car.
- Later: river steamer and launch, rideable train.
- **Horses** are the hard part: they need a rigged model and walk/trot/canter animations. Plan:
  a marketplace rigged horse if a good free one exists; otherwise a Blender rig and the user
  publishes the animations (same as CoverFire).

## 7. Characters & clothing
- **Clothing is the weakest area for me.** Plan: catalog/marketplace Victorian items first
  (top hats, bowlers, frock and morning coats, bustle and leg-of-mutton gowns, police helmets,
  Guards' bearskins and tunics), applied per role through HumanoidDescription.
- Later: commission or create custom layered clothing; I can build the system that applies it.
- Animations (bow, curtsy, waltz, salute, guard drill, lamp-lighting, cab whip): marketplace packs
  or an animator; the user publishes animations themselves.

## 8. UI
Don't guess a style (CoverFire lesson). Ideas to pick from once references are in: newspaper
broadsheet type, playbill posters, enamel-sign plaques, brass-and-mahogany for court menus,
telegram forms for messages. Built from hand-made 9-slice images and an icon sheet, not
code-drawn shapes. Alignment on a fixed grid; check in screenshots.

## 9. Audio
Ambience per district (hooves and wheels on setts, market cries, river horns, church bells,
the clock tower chime, train whistles), a military band for the Guard, a waltz orchestra for
balls, music-hall piano. Roblox audio library only (free, licensed).

## 10. Rules carried over from CoverFire's Blender work
- Check realistic game scale every time.
- Check for flickering/z-fighting textures before export.
- Keep triangle counts low while keeping quality.
- Follow the colour sheet once one exists (`references\colours\`).
