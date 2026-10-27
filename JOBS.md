# Jobs spec

Starting values in `Config.Jobs`. Pay targets come from ECONOMY.md §2.

## 1. Common framework
- **On/off duty:** join a job at its depot (or the role menu), wear its uniform, get its tools.
  One job at a time. Switching has a 2 min cooldown.
- **Task:** a server-defined unit of work with a start, checkpoints and a completion check
  (position, timer, item). Pay + XP on completion.
- **Ranks 1–5** per job. XP to reach rank n = `150 × n^1.6` cumulative (r2 ≈ 455, r3 ≈ 870,
  r4 ≈ 1380, r5 ≈ 1970). Tasks give 10–30 XP. Rank 5 ≈ 8–10 h in one job.
- **Rank gives:** +10% pay per rank, new tools or routes, a uniform detail (chevrons, badge), and
  at rank 3+ the right to train rank 1–2 players for bonus XP.
- **Tracker HUD:** current task, next checkpoint (waypoint), pay so far this shift.
- **Anti-AFK:** tasks need movement and input; hourly pay cap per job (ECONOMY §9).

## 2. First-wave jobs

### Cabbie (Transport)
Needs: cab licence; hired cab (5s/shift) or own cab.
Loop: wait at a rank or drive around → player hails / NPC fare appears → pick up → waypoint to
destination → meter fare paid on drop-off.
Pay: fare (§VEHICLES 8) + 2d tip from NPC fares for no collisions. XP 15 per fare.
Ranks: r2 four-wheeler, r3 own-cab discount, r4 "Knowledge" badge (shows best route), r5 cab yard
foreman (can lend cabs to r1–2 cabbies).

### Omnibus driver (Transport)
Needs: omnibus licence. Company bus, no hire fee.
Loop: drive the fixed route, stop at each stop for ≥ 4 s, passengers board/alight.
Pay: 1s per stop reached on time (± 30 s window) + 1d per passenger-stop. XP 20 per lap.
Conductor role (second player, collects fares, rings the bell) gets half the passenger pay.

### Lamplighter (Labour)
Loop: at dusk (in-game 18:00–20:00) collect a route of 10–14 gas lamps; walk to each and hold
the pole action 1.5 s. Dawn (05:00–07:00): put them out the same way. Daytime: lamp repair tasks
(lamps broken by events/vandals).
Pay: 2d per lamp at dusk/dawn (≈ 2s per route), repairs 6d each. XP 12 per route.
Effect: lit lamps really light the street (PointLight on). Unlit streets stay dark until someone
lights them (NPC lamplighter fallback 10 min after dusk on low pop).

### Police constable (Law)
Loop: walk an assigned **beat** (5 checkpoints, ~3 min); answer whistles and reports; direct
traffic at a junction (stand in the box, wave vehicles through: the traffic minigame); stops,
arrests (LAW.md).
Pay: salary 4s per in-game day on duty and active + 2s per successful arrest (conviction or
paid fine) + 6d per beat completed. Police budget lever raises salary up to +50%.
Ranks: Constable 1–2, Sergeant 3 (driving tests, van), Inspector 4 (opens detective cases,
assigns beats), Superintendent 5 (seat-limited, 1 per server).

### Newsboy & Journalist (Labour / Professions)
**Journalist:** write an article at Fleet Street (headline ≤ 60 chars, body ≤ 600, filtered).
Editor (rank 3+) approves articles into the next edition. Every 2 in-game days an edition prints.
Pay per published article 2s, + 1d per copy sold.
**Newsboy:** pick up a bundle of 10 papers at the press, sell to players (they pay 1d and can read
it in a UI) or to NPCs on busy corners (walk up, hold action). Pay 1d per copy + 4d per bundle.
Royal decrees, court verdicts and passed bills are auto-added as a "Court & Parliament" column.

## 3. Second-wave jobs (outline)

New with player shops (`SHOPS.md` §7): **shopkeeper**, **shop assistant** (a starter job),
**carpenter** (makes furniture for the building kit) and **delivery runner**.
| Job | Loop | Notes |
|---|---|---|
| Telegraph messenger | Timed deliveries between offices on a bicycle | Bonus for speed |
| Postman | Route of 10 houses, post into letterboxes | Morning/afternoon rounds |
| Baker | Flour from the docks → oven timer → deliver to shops/houses | Van at r3 |
| Coalman | Coal yard → deliver sacks to houses with a dray | Heavy carry slows you |
| Dockworker | Unload ship cargo with crane/hand cart to warehouses | Events: ship arrivals |
| Chimney sweep | Climb-in minigame at houses that request it | Soot cosmetic |
| Firefighter | Respond to fires (EVENTS), steam engine, hoses | Salary on duty |
| Physician / Nurse | Revive downed players, hospital rounds | Fee per revive 1s |
| Motor engineer | Repair cars, tow, refuel | Paid by owners or NPC jobs |
| Photographer | Take portraits (camera tool → in-game photo card) | Players pay; nice for weddings of state, events |
| Butler / Maid / Footman | Household tasks in a hired house (polish, serve, announce guests) | Paid by the house owner (or NPC wage at palace) |
| Tailor / Dressmaker | Craft outfits from cloth for other players | Player-to-player shop |
| Guard (Foot Guards) | Sentry posts, drill, Changing of the Guard | Salary; see EVENTS |

## 4. Job sites to place in the map (M1 greybox)
Cab yard + 6 ranks; omnibus depot + 8 stops; gas lamps on every street (tagged `Lamp`, with a
`Route` attribute); police stations (Scotland Yard + 1 East End) with traffic boxes at 3
junctions; Fleet Street press + 8 newsboy corners; Public Carriage Office test course.
