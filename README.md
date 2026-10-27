# Crown & Court (London, 1897)

**Start here:** [CLAUDE.md](CLAUDE.md) (how to work on this project) · [TASKS.md](TASKS.md)
(what to build next) · [INSTALL.md](INSTALL.md) (putting scripts into Studio by hand) ·
[ROADMAP.md](ROADMAP.md) · [DESIGN.md](DESIGN.md) · [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md)

## Working with the code (Rojo)

The game's scripts live in `src/` and sync into Studio with [Rojo](https://rojo.space).
The map, palace, Parliament, interiors and backups stay in the place file; Rojo only manages
the scripts listed in `default.project.json`.

| Folder | Becomes in Studio |
|---|---|
| `src/shared/` | `ReplicatedStorage.Shared` |
| `src/replicated/DESIGN_NOTES.luau` | `ReplicatedStorage.DESIGN_NOTES` |
| `src/server/LondonServer/` | `ServerScriptService.LondonServer` (+ its modules) |
| `src/serverstorage/` | `ServerStorage.MapGreybox`, `ServerStorage.MapLayoutData` |
| `src/client/LondonClient/` | `StarterPlayer.StarterPlayerScripts.LondonClient` |
| `src/first/LoadingScreen.client.luau` | `ReplicatedFirst.LoadingScreen` |

One-time setup on your PC:
1. Install Rojo (e.g. with [Rokit](https://github.com/rojo-rbx/rokit): `rokit add rojo-rbx/rojo`)
   and the Rojo plugin in Studio (Plugins tab → Manage Plugins, or `rojo plugin install`).
2. `git clone https://github.com/ricket026/london_roblox` (or `git pull` in your copy).

Every session:
1. `git pull`, then `rojo serve` in the repo folder.
2. Open your London place in Studio → Rojo plugin → **Connect**. The scripts update live.
3. Press Play to test. Edit scripts in the files, not in Studio (a sync overwrites Studio edits).
4. Save the place as usual; publish when you're happy.

`.luau` = ModuleScript, `.server.luau` = Script, `.client.luau` = LocalScript, and a folder with
`init.*.luau` is a script with child modules.

**Without Rojo:** `import/` has five drag-in model files with every script, one per Studio
location; see `import/README.md`. Rebuild them after code changes with `python3 tools/build_rbxmx.py`.

# System specs

Detailed specs behind DESIGN.md. Numbers are starting values for `Shared.Config`, tuned in M9.
If two files conflict, **PLAYER_GATHERING.md wins** (getting players together is the priority).

| File | Covers | Milestone |
|---|---|---|
| [PLAYER_GATHERING.md](PLAYER_GATHERING.md) | Server size, hubs, clock-time events, cross-server "What's on", retention, launch, analytics | All |
| [ACTIVITIES.md](ACTIVITIES.md) | ~40 side activities & minigames, hobby levels, collections | M3 → updates |
| [MAP_LAYOUT.md](MAP_LAYOUT.md) + [map_layout.html](map_layout.html) | City frame, districts, road hierarchy, routes, spots, heights, edges, greybox plan (the HTML's JSON = exact coordinates) | M1 |
| [LOW_POP_AND_ONBOARDING.md](LOW_POP_AND_ONBOARDING.md) | NPC fallbacks for quiet servers, first-join flow, goals HUD, menu list | M1–M3 |
| [ECONOMY.md](ECONOMY.md) | £sd, income targets, prices, faucets/sinks, tax, bank, ledger | M2 |
| [VEHICLES.md](VEHICLES.md) | Vehicle classes & stats, driving, controls, upkeep, licences, road rules, fares, NPC traffic | M2, M6 |
| [JOBS.md](JOBS.md) | Job framework, ranks/XP, first-wave and later jobs, job sites | M3 |
| [LAW.md](LAW.md) | Health/downed, crimes, arrest flow, courts, sentences, anti-abuse | M5 |
| [COURT_PARLIAMENT.md](COURT_PARLIAMENT.md) | Precedence, seat limits, address, throne room, honours, decrees, elections, bills & levers | M4, M7 |
| [EVENTS.md](EVENTS.md) | Event framework and every event | M4, M7 |
| [PROPERTY.md](PROPERTY.md) | Homes and shops: portable deeds, rent or buy, plots per server, keys | Phase 3 |
| [BUILDING.md](BUILDING.md) | The period building kit, build mode, decorating, limits, templates for every plot | Phase 3 |
| [SHOPS.md](SHOPS.md) | Items and inventory, shopkeeping, wholesale, player-made goods, NPC customers | Phases 2, 4 |
| [PROPERTY_WARDROBE.md](PROPERTY_WARDROBE.md) | Outfits, dress codes, items to source (§1–2 property replaced by the three above) | M6 |
