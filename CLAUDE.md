# Crown & Court: agent handbook

A Roblox roleplay game set in London, 1897 (working title *Crown & Court*). Read this first, then
`TASKS.md` for what to work on. Design: `DESIGN.md` (pillars, §2), `TECH.md` (architecture),
`ROADMAP.md` (milestones), the system specs (`JOBS.md`, `ECONOMY.md`, `LAW.md`...; index in
`README.md`), per-activity designs in `activities/`, property/building/shops in `PROPERTY.md`,
`BUILDING.md`, `SHOPS.md`, art and Blender guidelines in `art/` (style + palette, the kit
contract, the pipeline, the asset list), decisions in `OPEN_QUESTIONS.md`. Module-by-module notes: `src/replicated/DESIGN_NOTES.luau`.
**`PLAYER_GATHERING.md` wins any conflict between specs.**

## How code gets into the game (read before changing anything)

- **`src/` in git is the source of truth for every script.** The place file `london.rbxl` holds
  the map, landmarks, interiors and backups; it is a snapshot, not kept in sync with `src/`.
- **The user installs scripts by hand**: they create each script in Studio and paste the code
  from GitHub. They don't use Rojo, and Studio's "Insert from File" didn't work for them. So:
  - Touch as **few scripts** as you can per change; prefer editing one module over spreading a
    feature across many. Don't rename or move scripts without a strong reason.
  - **End every change with install instructions**: for each script, its Studio location, type
    (Script / LocalScript / ModuleScript), new or replace, and the GitHub link. For the boot
    scripts (`LondonServer`, `LondonClient`) give the exact lines to add.
  - **Update `INSTALL.md`** (status table + a new step) in the same commit.
  - Never ask them to paste generated or `.rbxmx` text into a script. Don't build installers
    or generators for them (they asked for plain copy-paste).
- Agents with Studio access (Studio MCP, TECH.md §1): any script you change in Studio must be
  mirrored into `src/` and committed, or the next paste from GitHub overwrites your work.
  Map/landmark edits go in the place; back up first (`ServerStorage._Backups_<topic>_<date>`).
- `tools/build_rbxmx.py` builds `import/*.rbxmx` (drag-in models) and `default.project.json` is
  a Rojo project; both exist for anyone who can use them, but the user's path is copy-paste.

## Branches

Work is on **`m1-identity`** (not yet merged into `main`). Branch off it, or off `main` once
merged. Open a pull request only when the user asks.

## Checking work without Studio

```
python3 tools/check_luau.py      # block/bracket balance, Module.field references, unused locals
python3 tools/luau_test.py       # runs tests/*.luau against the real src/ modules (needs `pip install lupa`)
python3 tools/chess_perft.py     # chess rules (Python port of Shared.Chess) vs standard counts
python3 tools/check_sites.py     # Config map positions vs london.rbxl + map_layout (pip install lz4 zstandard)
```
All must pass before you commit. `luau_test.py` converts src/ to plain Lua (`tools/luau2lua.py`,
same line numbers) and runs it with `tools/luau_prelude.lua` standing in for Roblox: instances,
signals, remotes, players, a DataStore, CFrame/Vector3 maths and **virtual time**
(`__advance(seconds)`). Tests can boot the real server (`__run(__find("ServerScriptService.LondonServer"))`),
add players (`__addPlayer`) and call remotes through `Net._dispatch`; see `tests/test_characters.luau`.
Client modules load with `__asClient(player, fn)` (own module copies, LocalPlayer, pushes fire
OnClientEvent); press buttons with `button.Activated:Fire()`; see `tests/test_economy_ui.luau`.
**Write tests for every new system.** None of this is a type checker or the real engine: say plainly in your report what still needs a
Play-test in Studio. Map positions can be checked against the place file's parts
(the earlier review did this; positions for activity sites are in `Config`, with Y found by
raycast at runtime).

## Code rules (TECH.md §4 plus what the code base does)

- `--!strict`, many small ModuleScripts, each starting with a header comment saying what it
  does, its remotes and its public functions. Match the surrounding style and comment density.
- Every tunable number goes in `Shared.Config` with a comment saying what it is and its unit.
- Server-authoritative. All client messages go through `Shared.Net` (`Net.handle` with a schema
  of `Net.V` validators, a rate limit, and `can =` a `Roles.ACTIONS` entry when permissioned).
  Unknown or missing fields are rejected, so client payloads must match the schema exactly.
- **A Luau line must never start with `(`**; bind a local first.
- Money: integer pence only (`Shared.Money` to format). Every change goes through
  `LondonServer.Economy` with a reason: `Economy.pay(player, pence, reason, ref)`,
  `Economy.charge(...)` (wallet then bank), `Economy.change` (fines). Not `Profiles.addPence`.
- Player-visible text in British English. Player-written text goes through `Shared.Text`
  filtering (fail closed). Names through `Shared.Names` rules.
- UI is a deliberate **plain stub** (Garamond on dark panels) until the user supplies reference
  art (ART.md §8). Don't style it further. Every UI must fit a landscape phone (~360 px tall)
  and work with touch and gamepad.
- Never guess catalog/asset IDs. Leave `0` / `{}` in Config and ask the user for real ones.
- Free assets only, checked for scripts. No gambling or paid chance, no alcohol, no gore
  (DESIGN.md §12). Fictional families and brands only.

## Architecture in one screen

Boot: `ServerScriptService.LondonServer` (Script) requires and `init()`s its child modules, then
wires `PlayerAdded`/`PlayerRemoving`. `StarterPlayerScripts.LondonClient` (LocalScript) does the
same for UI modules. `ReplicatedStorage.Shared` holds modules both sides use.

| Module | Job |
|---|---|
| Shared: Config, Net, Roles, Money, Text, Types | foundations (M0) |
| Shared: Stations, Names, Looks, Hobbies, Collection, Chess, Meter | role table, name rules, look presets, hobby levels, collection items, chess rules, timing meter |
| Shared: Items | every item: price, stack, use, holdable, furniture, player-made |
| Shared: Kit, Palette | building kit pieces + rules + greybox geometry (art/kit.md is the contract), named colours |
| Server: Profiles + Store | profile schema v3, session lock, autosave, mock store in Studio |
| Server: Characters | save slots, creator, linked slots, spawning from a HumanoidDescription, respawn |
| Server: Identity | per-server roles with seats, overhead name tags |
| Server: WorldClock | shared 24-min day, `Phase` attribute, `PhaseChanged` |
| Server: Activities (+ Ducks, Strength, Mudlark, Chess) | activity framework and the first four activities |
| Server: Economy, Inventory, Counters, Exchange, World | money ledger + bank, bag/storage + held item, NPC counters, hand-overs, map helpers |
| Server: Lots, Builds, Property | plots (street side, address, claims, templates), player builds (edits, render, save), deeds (rent/buy, keys, doors) |
| Server: Shops | property shops and market stalls: till, stock, prices, wages, NPC customers (suppliers are a Counters kind) |
| Server: Jobs (+ Shared.Ranks) | job framework (duty by role, server-checked steps, pay caps, ranks) and Postman, Newsboy, Baker, Carpenter |
| Server: Admin, AdminLog, Analytics, Doors, Debug | M0 (Debug = Studio-only test bindable) |
| Client: CharacterUI, IdentityUI, ClockHUD, Activities (+ Chess, Strength), EconomyUI, BuildUI, PropertyUI, ShopUI, JobUI | menus and HUD stubs |

Data (`Shared.Types`): one profile per account. **Account-wide**: money, collection, Robux
purchases, outfits/vehicles/rental, moderation record. **Per character slot**: name and look.
**Progress** (job ranks, hobbies, licences, bests, honours) is shared by *linked* slots. Use
`Profiles.progress(player)` for the active character's progress (nil at the character menu).

Extension points:
- New activity: a module under `Activities/` returning `{ init(A), leave(player)? }`; add its name
  to `A.MODULES`. Use `A.claim/release`, `A.reward`, `A.score`, `A.board`, `A.ground`, `A.part`.
- Something that must settle before a character switch: `Characters.onBeforeChange(fn)`.
- New NPC counter: `Counters.add{ id, kind, name, x, z, yaw }` (server) and, for a new kind,
  `Counters.onOpen(kind, fn)` + `EconomyUI.onCounter(kind, fn)` (client).
- New job: a station role in `Shared.Stations`, numbers in `Config.JOBS`, and
  `Jobs.register(roleId, function(player) return task end)` (steps "goto"/"hold", optional need/give).
- New building piece: add a row to art/kit.md and the same entry to `Shared.Kit` (test_kit fails
  until both match); new colours go at the END of `Shared.Palette` (saved by index).
- Net domains in use: `Profile`, `Admin`, `Identity`, `Character`, `Activity`, `Economy`,
  `Inventory`, `Counter`, `Exchange`, `Property`, `Build`, `Shop`, `Job`. `Net.listen` keeps one listener per action.

## Working with the user

- They review by asking for repeated "once over" checks: re-read everything you wrote, trace the
  flows, and report real findings with what you verified and what you couldn't.
- They decide design questions; ask (with options) when a spec doesn't settle something, and
  record the answer in `OPEN_QUESTIONS.md`.
- Keep reports short and concrete: what changed, which scripts to paste, what to test.
