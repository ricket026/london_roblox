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
| 4 | Activities (ducks, test your strength, mudlarking, chess) | ⬜ |
| 5 | Debug commands for testing | ⬜ |

**Players → CharacterAutoLoads must be unticked** (Properties window). Players spawn only after
picking a character.

## Step 1b: name over the head
Replace the code of ServerScriptService › LondonServer › **Identity** with
[src/server/LondonServer/Identity.luau](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Identity.luau).

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

## Step 4: activities
Needs step 3. Shared modules (all **ModuleScripts** inside ReplicatedStorage › **Shared**):
[Collection](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Collection.luau),
[Chess](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Chess.luau),
[Meter](https://github.com/ricket026/london_roblox/blob/m1-identity/src/shared/Meter.luau).

Server: a **ModuleScript** `Activities` inside **LondonServer**, with the code of
[Activities/init.luau](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Activities/init.luau),
then four **ModuleScripts** inside `Activities`:
[Chess](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Activities/Chess.luau),
[Ducks](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Activities/Ducks.luau),
[Mudlark](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Activities/Mudlark.luau),
[Strength](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Activities/Strength.luau).

Client: a **ModuleScript** `Activities` inside **LondonClient**, with the code of
[Activities/init.luau](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/Activities/init.luau),
then two **ModuleScripts** inside it:
[Chess](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/Activities/Chess.luau),
[Strength](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/Activities/Strength.luau).
(The server and client `Chess`/`Strength` are different scripts; don't mix them up.)

Startup scripts: with steps 1–4 in, replace the code of **LondonServer** (the Script) and
**LondonClient** (the LocalScript) entirely with the GitHub versions:
[server](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/init.server.luau),
[client](https://github.com/ricket026/london_roblox/blob/m1-identity/src/client/LondonClient/init.client.luau).
From then on they match GitHub, and later steps only say which lines changed.

Test: seed stand at the St James's Park lake (west shore), strength machine in Covent Garden,
three chess tables by the bandstand, tide sign by the river stairs below the Temple.

## Step 5: debug commands (Studio only)
Replace LondonServer › **Debug** with
[src/server/LondonServer/Debug.luau](https://github.com/ricket026/london_roblox/blob/m1-identity/src/server/LondonServer/Debug.luau).
Commands (Command Bar, set to **Server**):
`game.ServerStorage.LondonDebug:Invoke("play", <userId>)`, `("givePence", <userId>, 24000)`,
`("clock", 14.5)`, `("setRole", <userId>, "Judge")`.
