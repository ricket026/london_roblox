# Installing the scripts in Studio (by hand)

The code lives in `src/` on GitHub (branch **`m1-identity`** until it's merged into `main`). Each
file becomes one script in Studio. This page lists what's already in the place and, step by step,
what to add next. **Agents: update the status table and add a step for every change you make.**

## How to add a script
1. In the **Explorer**, hover over the parent (e.g. `Shared`) and click **⊕**.
2. Pick the **type** the step says: **ModuleScript** (most), **LocalScript** or **Script**.
   The type can't be changed later; if it's wrong, delete it and make it again.
3. **F2**, type the exact name (capitals matter).
4. Open it, **Ctrl+A**, then paste the code from the GitHub link (**Copy raw file** button,
   top right of the code).

Rules of thumb: `X.luau` = ModuleScript, `X.server.luau` = Script, `X.client.luau` = LocalScript.
A file called `init...` is the parent script itself; the other files in its folder go inside it.
Never paste a `.rbxmx` file or anything starting with `<roblox` into a script.

## Status in the user's place

| Step | What | Status |
|---|---|---|
| 0 | M0 foundations (Config, Net, Roles, Money, Text, Types, Profiles, Store, Admin, AdminLog, Analytics, Doors, Debug, LoadingScreen) | ✅ in the place |
| 1 | Character creator + save slots | ✅ installed and working (2026-10-27) |
| 1b | Name-tag fix | ⬜ re-paste Identity |
| 2 | Station (role) menu | ⬜ |
| 3 | World clock | ⬜ |
| 4 | Money, things and 3D outfits: wallet, bag, shop and bank counters, hand-overs (Phase 2, T06) | ⬜ |
| 5 | Activities (ducks, test your strength, mudlarking, chess) | ⬜ |
| 6 | Debug commands, day/night lighting, arriving at the terminus (T07, T03) | ⬜ |
| 7 | Homes and building: estate agents, rent/buy, plots, template houses, build mode, keys (Phase 3) | ⬜ |
| 8 | Shops, jobs and gas lamps: tills, suppliers, stalls, postman, newsboy, lamplighter, baker, carpenter, shop assistant (Phases 4–5, T04) | ⬜ |
| 9 | Appointments at the hubs every 10 minutes, today's tasks panel (T30, T33) | ⬜ |

Do the steps **in order**: each needs the ones before it (a script that waits for a missing one
just hangs; `tools/check_install.py` checks this list against the code). The links always show
the latest code, so do a step's pastes in one go.

**Players → CharacterAutoLoads must be unticked** (Properties window). Players spawn only after
picking a character.

## Step 1b: name over the head (and the newest settings)
Replace the code of ServerScriptService › LondonServer › **Identity** with
[src/server/LondonServer/Identity.luau](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Identity.luau),
and the code of ReplicatedStorage › Shared › **Config** with
[src/shared/Config.luau](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Config.luau) (it only adds settings; every later step uses them).

## Step 2: station (role) menu
- New **ModuleScript** `IdentityUI` inside StarterPlayer › StarterPlayerScripts › **LondonClient**:
  [src/client/LondonClient/IdentityUI.luau](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/IdentityUI.luau)
- In **LondonClient** (the LocalScript), under the `CharacterUI` line, add:
  ```lua
  require(script:WaitForChild("IdentityUI")).init()
  ```
Test: after picking a character, a **Station** button appears bottom-left.

## Step 3: world clock (24-minute day)
- New **ModuleScript** `WorldClock` inside ServerScriptService › **LondonServer**:
  [src/server/LondonServer/WorldClock.luau](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/WorldClock.luau)
- New **ModuleScript** `ClockHUD` inside **LondonClient**:
  [src/client/LondonClient/ClockHUD.luau](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/ClockHUD.luau)
- In **LondonServer** (the Script): after `local Characters = ...` add
  `local WorldClock = require(script:WaitForChild("WorldClock"))`, and after `Characters.init()` add
  `WorldClock.init()`.
- In **LondonClient**: add `require(script:WaitForChild("ClockHUD")).init()` under the other `require(...).init()` lines.

Test: the time ("6:45 pm · Dusk") shows at the top and the sky changes.

## Step 4: money, things and 3D outfits
New scripts first, then the replacements, then the start-up lines (a replaced script waits for
the new ones, so adding them first avoids a hang).

**New ModuleScripts**
- inside ReplicatedStorage › **Shared**: [Items](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Items.luau), [OutfitParts](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/OutfitParts.luau)
- inside ServerScriptService › **LondonServer**: [Daily](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Daily.luau), [Economy](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Economy.luau), [Inventory](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Inventory.luau),
  [World](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/World.luau), [Counters](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Counters.luau), [Exchange](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Exchange.luau), [Wardrobe](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Wardrobe.luau)
- inside StarterPlayer › StarterPlayerScripts › **LondonClient**: [EconomyUI](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/EconomyUI.luau)

**Replace the code of** (same place, same type): Shared › [Config](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Config.luau), Shared › [Types](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Types.luau),
LondonServer › [Profiles](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Profiles.luau) (save format v3; old saves upgrade themselves),
LondonServer › [Characters](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Characters.luau), LondonServer › [WorldClock](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/WorldClock.luau).

**LondonServer** (the Script):
- under `local Characters = require(script:WaitForChild("Characters"))` add
  ```lua
  local Economy = require(script:WaitForChild("Economy"))
  local Inventory = require(script:WaitForChild("Inventory"))
  local Counters = require(script:WaitForChild("Counters"))
  local Exchange = require(script:WaitForChild("Exchange"))
  local Daily = require(script:WaitForChild("Daily"))
  ```
- under `Characters.init()` add
  ```lua
  Economy.init()
  Inventory.init()
  Counters.init()
  Exchange.init()
  Daily.init()
  ```
- in the `PlayerRemoving` function, under `Characters.onPlayerRemoving(player)` add
  `Economy.onPlayerRemoving(player)`.

**LondonClient** (the LocalScript): delete the block that starts `local State = { pence = 0, bank = 0 }`
and ends with the `end)` after `script:SetAttribute("Pence", State.pence)` (the wallet moved into
EconomyUI), and under the last `require(...).init()` line add
```lua
require(script:WaitForChild("EconomyUI")).init() -- wallet, bag, counters, hand-overs (Phase 2)
```

Test (Play):
- characters wear 3D outfits: frock coat with tails and a top hat, tweed with a flat cap, dresses
  with full skirts and bonnets. Walk, jump, sit: nothing catches. Tell me what looks wrong;
- the wallet shows top right after picking a character, with "Bank 0d" under it; **B** (or Bag)
  opens the bag;
- the refreshment kiosk in St James's Park sells tea: buy two, **Hold** one, **Use** one;
- the post office in Trafalgar Square pays money in and out;
- with two players (Test › Clients and Servers), stand together, **Bag › Give**, accept.

## Step 5: activities
Shared modules (all **ModuleScripts** inside ReplicatedStorage › **Shared**):
[Collection](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Collection.luau), [Chess](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Chess.luau), [Meter](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Meter.luau).

Server: a **ModuleScript** `Activities` inside **LondonServer**, with the code of
[Activities/init.luau](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Activities/init.luau), then four **ModuleScripts** inside `Activities`:
[Chess](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Activities/Chess.luau), [Ducks](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Activities/Ducks.luau), [Mudlark](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Activities/Mudlark.luau), [Strength](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Activities/Strength.luau).

Client: a **ModuleScript** `Activities` inside **LondonClient**, with the code of
[Activities/init.luau](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/Activities/init.luau), then two **ModuleScripts** inside it:
[Chess](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/Activities/Chess.luau), [Strength](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/Activities/Strength.luau).
(The server and client `Chess`/`Strength` are different scripts; don't mix them up.)

**LondonServer**: add `local Activities = require(script:WaitForChild("Activities"))` under the
WorldClock line, `Activities.init()` under `WorldClock.init()`, and
`Activities.onPlayerRemoving(player)` in the `PlayerRemoving` function.
**LondonClient**: add `require(script:WaitForChild("Activities")).init()` above the EconomyUI line.

Test: seed stand at the St James's Park lake (west shore), strength machine in Covent Garden,
three chess tables by the bandstand, tide sign by the river stairs below the Temple.

## Step 6: debug commands, day and night, arriving at the terminus
Replace LondonServer › [Debug](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Debug.luau). (Steps 4's WorldClock and Characters already have
the lighting and the terminus spawn.)

In **LondonServer**, make sure Debug starts in Studio: the block
`if RunService:IsStudio() then require(script:WaitForChild("Debug")).init() end` sits after the
other `init()` lines.

Commands (Command Bar, set to **Server**), e.g. `game.ServerStorage.LondonDebug:Invoke("play", <userId>)`:
`("givePence", <userId>, 24000)`, `("clock", 19)` (dusk), `("weather", "fog")` (a pea-souper),
`("setRole", <userId>, "Judge")`, `("giveItem", <userId>, "tea", 3)`,
`print(game.ServerStorage.LondonDebug:Invoke("ledger", <userId>))`, `print(game.ServerStorage.LondonDebug:Invoke("totals"))`.

Test: new characters arrive on the forecourt of Charing Cross station; `("clock", 21)` makes it night (darker, a
blue haze); `("weather", "fog")` closes the view right in.

## Step 7: homes and building (estate agents, plots, build mode)
Needs **ServerStorage › MapLayoutData** (already in your place; it gives the plots their street
side and address).

**New ModuleScripts**
- inside ReplicatedStorage › **Shared**: [Palette](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Palette.luau), [Kit](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Kit.luau)
- inside ServerScriptService › **LondonServer**: [Lots](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Lots.luau), [Builds](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Builds.luau), [Property](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Property.luau)
- inside StarterPlayer › StarterPlayerScripts › **LondonClient**: [BuildUI](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/BuildUI.luau), [PropertyUI](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/PropertyUI.luau)

**Replace the code of**: LondonServer › [Doors](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Doors.luau).

**LondonServer** (the Script):
- under `local Exchange = require(script:WaitForChild("Exchange"))` add
  ```lua
  local Lots = require(script:WaitForChild("Lots"))
  local Builds = require(script:WaitForChild("Builds"))
  local Property = require(script:WaitForChild("Property"))
  ```
- under `Exchange.init()` add
  ```lua
  Lots.init()
  Builds.init()
  Property.init()
  ```
- under `Characters.onProfileLoaded(player)` add `Property.onProfileLoaded(player)`
- under `Economy.onPlayerRemoving(player)` add `Property.onPlayerRemoving(player)`
- replace the line `game:BindToClose(Profiles.closeAll)` with
  ```lua
  game:BindToClose(function()
  	Builds.closeAll()
  	Profiles.closeAll()
  end)
  ```

**LondonClient** (the LocalScript): under the `EconomyUI` line add
```lua
require(script:WaitForChild("BuildUI")).init() -- build mode (Phase 3)
require(script:WaitForChild("PropertyUI")).init() -- estate agents, your properties, keys (Phase 3)
```

Test (Play):
- every empty plot gets a plain template house (it builds in over a few seconds). If Studio
  lags badly, set `Config.LOT_TEMPLATES = false` and tell me;
- give yourself money (`("givePence", <userId>, 30000)`), then speak to an estate agent: Lincoln's
  Inn Fields (Holborn), Grosvenor Square (Mayfair), Covent Garden piazza or Spitalfields market.
  **Rent** a terrace or lodging: the message gives the address;
- walk there: your house is built on the plot (doors locked to others; **Property › Unlock**);
- standing on your plot, **Property › Build**: pick a piece, move the mouse to place it (touch: tap,
  then **Put**), **R** turns it, **Select** + **Delete**, **Paint**, **Undo**. Take out a front-wall
  window: the house becomes a draft (others see the plain house); put a wall back and **Publish**;
- **Exit** saves. Leave and rejoin: the same address and house come back.
Look closely at what can't be checked outside Studio: doors swing the right way, roofs slope
up to the ridge, chairs face forward, the build camera, and frame rate with templates.

## Step 8: shops, jobs and gas lamps
**New ModuleScripts**
- inside ReplicatedStorage › **Shared**: [Ranks](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Ranks.luau)
- inside ServerScriptService › **LondonServer**: [Lamps](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Lamps.luau), [Jobs](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Jobs.luau), [Shops](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Shops.luau)
- inside StarterPlayer › StarterPlayerScripts › **LondonClient**: [ShopUI](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/ShopUI.luau), [JobUI](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/JobUI.luau)

**Replace the code of**: Shared › [Stations](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Stations.luau) (new roles: Lamplighter's already there;
Baker, Carpenter, Shop Assistant).

Start-up lines:

**LondonServer** (the Script):
- under `local WorldClock = require(script:WaitForChild("WorldClock"))` add
  `local Lamps = require(script:WaitForChild("Lamps"))`
- under `local Property = require(script:WaitForChild("Property"))` add
  ```lua
  local Shops = require(script:WaitForChild("Shops"))
  local Jobs = require(script:WaitForChild("Jobs"))
  ```
- under `Property.init()` add `Shops.init()` and `Jobs.init()`; under `WorldClock.init()` add `Lamps.init()`
- above `Property.onPlayerRemoving(player)` add `Shops.onPlayerRemoving(player)`
- in the `game:BindToClose(function()` block, add `Shops.closeAll()` as its first line.

**LondonClient** (the LocalScript): under the `PropertyUI` line add
```lua
require(script:WaitForChild("ShopUI")).init() -- shop tills, market stalls, suppliers (Phase 4)
require(script:WaitForChild("JobUI")).init() -- job tracker (Phase 5)
```

Test (Play; two players for buying: Test › Clients and Servers):
- **gas lamps** line every street; `("clock", 18.5)` (dusk): they're dark until lit; **Station ›
  Lamplighter** gives a round of lamps to light (hold at each pole). Lamps nobody lights come on
  by themselves three in-game hours into dusk, and go out the same way after dawn;
- **Station › Postman**: a tracker top left and a marker over the nearest post office; hold the
  prompt there, then at each door. **Newsboy**: collect at the newsagent by Horse Guards, sell
  on the corners;
- **Buy** a shop at the Covent Garden estate agent; in build mode add a **Counter with Till** and a
  **Display Case** (from the Furniture Warehouse outside Smithfield Market); buy stock at a supplier
  (Spitalfields Wholesale 5 am–2 pm in-game, Docks Warehouse 7 am–7 pm); at your till **Add all**,
  **Open**; the other player buys; set a price, a trade and a sign; walk away and the till banks;
- a **market stall** south of Covent Garden market hall or in Spitalfields: rent it, stock it, open;
- **Baker**: flour from Spitalfields Wholesale, bake at the Bakehouse there; **Carpenter**: timber
  from the Docks Warehouse, make furniture at the workshop in Finsbury Circus; **Shop Assistant**:
  with a Till key, mind someone's open shop; the owner sets your wage at the till.

## Step 9: appointments at the hubs, and today's tasks
**New scripts**
- ModuleScript `Appointments` inside ServerScriptService › **LondonServer**: [Appointments](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Appointments.luau)
- ModuleScript `DailyUI` inside StarterPlayer › StarterPlayerScripts › **LondonClient**: [DailyUI](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/DailyUI.luau)

After this step the two start-up scripts can simply be **replaced entirely** with the GitHub
versions ([server](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/init.server.luau), [client](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/init.client.luau)).
Or add the lines by hand:
- **LondonServer**: under `local Daily = require(script:WaitForChild("Daily"))` add
  `local Appointments = require(script:WaitForChild("Appointments"))`, and under `Jobs.init()` add
  `Appointments.init()`.
- **LondonClient**: under the `JobUI` line add
  ```lua
  require(script:WaitForChild("DailyUI")).init() -- appointments countdown, today's tasks (Phase 6)
  ```

Test (Play): under the clock, "Next: The Changing of the Guard at the Palace · 7:40" counts down;
when it starts a red flag goes up there and the line says "Now:". Stand by the flag for half a
minute: a memento goes in your collection book. **Today** shows three tasks (they pay 2s each)
and your stipend streak (1s on the first day, up to 7s on the seventh day in a row).

