# Technical Architecture

v0.2 (2026-10-24, era now 1897). Lessons carried over from CoverFire are marked **(CF)**.

## 1. Tooling

- **Roblox Studio** through the Studio MCP tools, the same as CoverFire. Code lives in the
  place file; scripts are authored with `multi_edit` / `execute_luau`.
- **Blender** through the Blender MCP for buildings, props and furniture. FBX files and
  manifests go in `London\blender\`. The user imports them by hand (File > Import 3D).
- **Never touch the CoverFire place ("Overlord Command") from this project.** Call
  `list_roblox_studios` first and make sure the active Studio is the London place.
- Backups before risky edits: `ServerStorage._Backups_<topic>_<date>` with `*_pre<Change>`
  copies **(CF)**.

## 2. Places

| Place | When | Notes |
|---|---|---|
| **London** (main) | v1 | The whole city, interiors included. StreamingEnabled. |
| Country estate / state visit | later | Separate places joined by TeleportService, used for events only. |

One main place is deliberate: RP needs everyone in one server, and teleporting into an interior
would split groups. (CoverFire used one place per map because each map needs its own Terrain;
that doesn't apply here.) If more places come later, shared code becomes Packages the same
way as CoverFire **(CF)**.

## 3. Folder layout in the place

```
ReplicatedStorage
  Shared/            Config, Roles, Titles, Districts, Net, Money, Text, Types   (ModuleScripts)
  Assets/            Outfits, Tools, UI art, Props
  DESIGN_NOTES       milestone status + module summaries (keep updated)  (CF)
ReplicatedFirst
  LoadingScreen
ServerScriptService
  LondonServer/      Boot script + modules:
    Profiles         DataStore, session lock, migration, Studio mock store
    Identity         RP names, titles, address forms, overhead tags
    Roles            station/role select, seat limits, presiding rules
    Economy          wallet, wages, tax, treasury, ledger
    Jobs/            one module per job (Lamplighter, Baker, Watch, Coachman, Crier...)
    Property         rentals, door locks, keys, layouts
    Wardrobe         outfits, ownership, role restrictions
    Law              crimes, wanted, whistle, arrest, prison, trials, sentences, downed state
    Vehicles/        spawning, ownership, seats, licences, speed limit, fares, upkeep,
                     no-vehicle-kill rule, zone blocking; one module per class (Cab, Omnibus,
                     Carriage, Motor, Bicycle, Horse)
    Court            audiences, protocol, presentations, appointments, honours, decrees
    Parliament       sittings, bills, votes, royal assent, server settings
    Events           event framework + ChangingGuard, Procession, Ball, MotorRun, Fire...
    Activities/      activity framework (join pad, rounds, scoring, boards) + one module per
                     activity; hobby XP; collections
    WhatsOn          cross-server event feed (MessagingService) + Join (TeleportService), parties
    Npc              ambient crowds, NPC traffic/fares, role fallbacks, population budget
    Analytics        AnalyticsService funnels and custom events
    Chat             TextChatService channels and speaking permissions
    Admin            owner-only tools (ban, money, profile reset, logs) + automatic moderation:
                     vote-kick, no-confidence votes, murder/bounty escalation, session bans
    Combat           weapons (server-validated hits), downed/death/respawn, certificates
    Guard            anti-exploit checks (speed, teleport, remote spam)
    WorldClock       day/night, weather, curfew
StarterPlayerScripts
  LondonClient/      UIKit, HUD, RoleMenu, Wardrobe, CourtUI, LawUI, ParliamentUI,
                     EventUI, Map, Emotes, Prompts, Gamepad, Touch
Workspace
  Map/
    Districts/<District>/{Buildings, Interiors, Street, Props}
    Spawns/, CabRanks/, BusStops/, Mews/, Lamps/, JobSites/, Roads/ (lanes for NPC traffic)
  Vehicles/          live vehicles (server-owned until a driver sits)
```

## 4. Coding rules (carried over from CoverFire)

- Server-authoritative. Validate every remote with `Net` validators (types, ranges, rate limits,
  role permission, distance to the target).
- Many small ModuleScripts, `--!strict`, no `wait()` / deprecated APIs.
- Every tunable number goes in `Shared.Config` with a comment.
- A Luau line must never start with `(` or `;(` after a statement; bind a local first **(CF)**.
- Global ZIndexBehavior: children of a raised panel draw under it unless raised too **(CF)**.
- Client BillboardGuis in workspace models may not render; project to a ScreenGui instead
  **(CF)**. (Overhead name tags: test early, fall back to projection if needed.)
- Free assets only, inspected for scripts before use.

## 5. Data

### 5.1 Player profile (DataStore `Profile_v1`, key `u_<userId>`)

Schema v3 (2026-10-28): one profile per account holding character save slots. Exact types in
`Shared.Types`; older profiles migrate on load (v1: the old identity becomes slot 1; v2: the
unused `rental` field goes, and inventory, properties and the transfer limits are added).

```lua
{
  v = 3,                    -- schema version, migrate on load
  -- account-wide (shared by every character)
  pence = 0, bank = 0,      -- wallet and bank, integer pence
  collection = {},          -- curio id -> times found
  purchases = {},           -- Robux gamepass / product id -> count
  outfits = { owned = {}, equipped = {} },
  vehicles = { { id = "", kind = "hansom", livery = "", condition = 100 } },
  record = { arrests = 0, warnings = {}, mutedUntil = 0 },  -- moderation follows the player
  limits = { activityWindow = 0, activityPaid = 0,         -- hourly pastime pay cap
             transferDay = "", transferred = 0 },           -- new-account hand-over cap (UTC day)
  inventory = { bag = { { i = "tea", n = 2, by = nil, byName = nil } }, storage = {} },
  properties = {},          -- deeds (PROPERTY §6, Phase 3)
  nextDeed = 1,
  settings = {}, firstJoin = 0, playtime = 0,
  -- characters (Config.MAX_SLOTS; string keys because DataStore JSON can't hold sparse arrays)
  slots = { ["1"] = { char = "c1", name = { first, last, changedAt }, look = { skin, hair, outfit }, createdAt } },
  active = "",              -- slot being played; every session starts at the character menu
  progress = { c1 = { jobs = {}, hobbies = {}, bests = {}, licences = {}, honours = {} } },
  nextChar = 2,
}
```

- **Linked slots** point at the same `progress` entry: their own name and look, shared job
  ranks, hobbies, licences and bests. Linking costs `Config.SLOT_LINK_PRICE` (£100); the first
  slot is free. A progress entry is deleted only when no slot points at it.
- Titles and offices are per server (Q4) and are not saved; `honours` keeps the cosmetic record.

- Session lock through `UpdateAsync` with a lock token and timeout; save on leave, on
  BindToClose, and every N minutes. Money changes save as deltas **(CF)**.
- Developer Product receipts: save before granting; a failed save returns NotProcessedYet **(CF)**.
- Studio uses an in-memory mock store unless API access is on **(CF)**.

### 5.2 Global stores
Thrones, offices, titles, laws and elections are **per server, in memory** (Q4, 2026-10-25), so
there are no global title/office/law/ballot registries. Profile additions: `honours` (cosmetic
"highest honour held", reign counts), `weaponsBanUntil`, `certificates.firearms`.

| Store | Key | Holds |
|---|---|---|
| `Bans_v1` | userId | reason, by (owner or automatic), until |
| ~~`Titles_v1` / `Offices_v1` / `Laws_v1` / `Ballots_v1`~~ | – | dropped: per-server now |
| ~~`Rentals_v1`~~ | – | superseded: leases live in the profile, houses assigned per server (systems/PROPERTY_WARDROBE.md §1) |

MessagingService is still used for the cross-server "What's on" feed and owner bans.

### 5.3 Logs
DataStore append for grants, kills/murders, money transfers over a threshold, Robux product
grants, arrests, verdicts, vote-kicks, no-confidence votes and owner actions. Readable from the
owner panel. A webhook to Discord is optional later (needs a proxy; Roblox blocks discord.com
directly).

## 6. Permissions model

`Roles.can(player, action, target?)` is the single permission check. Inputs:
1. **Owner** (the game creator's userId only) for owner tools. No group ranks, no staff (Q11).
2. Current role in this server, its rank and seat (King, Queen, royal family, offices).
3. Persistent job ranks, licences and certificates from the profile.
4. Server state: presiding/acting rules, no-confidence removals, session bans (weapons,
   vehicles, banishment).

Every remote handler and UI menu asks `Roles.can`. Actions are listed in `Shared.Roles` so the
permission table can be read in one place.

## 7. Networking

- One `RemoteEvent` and one `RemoteFunction` per domain (Court, Law, Economy...) through
  `Shared.Net`, each message `{ t = "Action", ... }` validated against a schema.
- Server pushes state as small deltas (wallet, role, wanted, event step).
- ProximityPrompts for world interactions (doors, lamps, ovens, stalls), validated on the server
  by distance and role.

## 8. Text and safety

- All player text (RP names, decrees, Gazette, bills, house names) goes through
  `TextService:FilterStringAsync` with the right context (broadcast vs. private).
- RP names also checked against a blocklist of real royals/politicians and reserved titles.
- Private player-to-player text (letters, calling cards) is only allowed when
  `TextChatService:CanUsersDirectChatAsync` says those two users may chat (Roblox age-group
  rules, Q5). Broadcast text uses the broadcast filter.
- Quick-phrase wheel lines are game-authored strings sent by id, not player text.
- Rate limits on every text action.

## 9. Performance targets

- Server: 50 players (user decision), heartbeat ≥ 55 FPS.
- Client: phones at 30+ FPS. StreamingEnabled, interiors stream in when you're near.
- Building budget: modular Victorian kit with shared textures (atlas), LODs on large landmarks,
  RenderFidelity Automatic, CollisionFidelity Box where possible.
- No per-frame server loops over all players for jobs; event-driven with timers.
- Vehicles: network ownership to the driver, server checks speed against the limit and class
  max (anti-exploit), despawn idle vehicles, cap live vehicles per server (Config). Horses
  animated client-side from the vehicle's speed.

## 10. Testing

- Every milestone ends with a Play test: `get_console_output` shows 0 errors, screenshots,
  report of what works / what doesn't / numbers tuned, then wait for the go-ahead **(CF)**.
- Multi-client tests (2–3 players) for court, law and trade before calling a milestone done.
- A debug bindable for tests (grant role/title, set time, give money, start event) — Studio only.
- Don't debug-spawn things in view during visual tests; they read as bugs **(CF)**.
