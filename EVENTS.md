# Events spec

Starting values in `Config.Events`.

## 1. Framework
An event is data + a small module:
```lua
{
  id = "ChangingGuard",
  trigger = "schedule" | "random" | "host" | "decree",
  hostRoles = { "GuardOfficer", "LordChamberlain" },  -- who may start/run it (host events)
  minPlayers = 0,                                       -- online in server
  location = "Palace.Forecourt",
  roles = { Officer = 1, Guardsman = {min=0,max=8}, Band = {min=0,max=6} },  -- sign-up slots
  steps = { "Muster", "March", "Handover", "Return" },   -- the host advances or timers do
  npcFallback = true,                                   -- NPCs fill empty roles
  rewards = { participant = 1s, xp = 20 },
  closesZones = { "Mall" },                             -- vehicle/pedestrian blocks while running
}
```
- **Announce** (banner + map marker + optional sign-up) → **Gather** (countdown) → **Steps** →
  **Finish** (rewards, Gazette entry).
- Only one major event at a time per server; minor events (fire, fog, bridge lift) can overlap.
- Host UI: start, sign-up list, assign roles, advance step, end. There's no staff, so every
  event can also run automatically (timers advance the steps; NPCs fill roles) and the owner
  account can start any event.

## 2. Events

| Event | Trigger | Where | Steps (short) | NPC fallback |
|---|---|---|---|---|
| **Changing of the Guard** | Schedule: every 2 in-game days (~48 min) | Palace forecourt | Muster → band plays → new guard marches up The Mall → handover salute → old guard leaves | Yes, full NPC guard & band; players can join any slot |
| **Balcony appearance** | Host: Monarch | Palace balcony | Announce → crowd gathers → appearance (wave emote) → crowd cheer rewards | No |
| **State Procession** | Host / decree | Palace → Mall → Whitehall → cathedral | Muster cavalry → landau boards → route with closed roads → service at cathedral → return | Cavalry escort NPCs |
| **State Opening of Parliament** | Host: Monarch, after an election | Palace → Parliament | Procession → Monarch's speech (filtered text) → first sitting | Partial |
| **Royal Ball** | Host / decree | Palace ballroom | Invitations (Presented players + guests) → arrivals announced → dances (waltz, quadrille emote sets, synced music) → supper → close | Orchestra NPC |
| **Presentation at Court** | Host: Lord Chamberlain | Throne room | See COURT_PARLIAMENT §4 | No |
| **Motor Run** | Host (any motorist r3+) / weekly schedule | Mall → city → finish at the edge of the map | Sign-up → line-up → staggered start → checkpoints (speed limit off, roads closed) → finish; prizes for finishing, not winning | No |
| **Market Day** | Lever (Parliament) | Covent Garden | Stalls open to players (rent 6d), NPC shoppers ×2, sales +20% | NPC stalls |
| **Fire!** | Random every 40–80 min if ≥ 8 players | A random building (tagged `Flammable`) | Smoke → flames spread room to room every 30 s → firefighters/bucket chain put out zones → fire out; building "charred" for 10 min then restored | NPC brigade after 4 min if no players respond |
| **Pea-souper** | Weather roll, ~1 per 3 in-game days | City-wide | Fog thickens over 2 min → lasts 6–10 min → clears; pickpocket success +15%, police patrol bonus pay | – |
| **Tower Bridge lift** | Random every ~20 min | Tower Bridge | Bells → road gates close → bascules rise → ship passes → lower → gates open | Always automatic |
| **Train arrival** | Schedule every ~10 min | Terminus | Whistle → train arrives → NPC passengers (cab fares!) → departs | Automatic |
| **General Election** | Every 7 real days | Polling station in each district | See COURT_PARLIAMENT §7.2 | – |
| **Trial** | From LAW | Old Bailey | See LAW §5 | Auto-justice |
| **Jubilee** | Scheduled on special dates (owner sets them in Config) | Whole city | Decorations, procession, fireworks, double pay | – |

## 3. Rewards
- Participation pay (1s–5s) + XP to the player's current job, plus a cosmetic **medal/ribbon**
  for big ones (Jubilee, first procession, fire brigade hero).
- Spectators near the event get a small stipend (1d–3d) once per event, so crowds form.

## 4. Scheduling rules
- Major events need ≥ 10 min between them.
- Scheduled events skip if a host event is running and resume after.
- The schedule is shown on a "Court Circular" board + HUD clock tooltip.
