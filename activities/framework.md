# Activity framework: what exists and what to add

The framework is `src/server/LondonServer/Activities/init.luau` (server) and
`src/client/LondonClient/Activities/init.luau` (client). Each activity is one child module that
returns `{ init(A), leave(player)? }` and is listed in `A.MODULES`.

## What it does today (built 2026-10-27)

| Piece | API | Notes |
|---|---|---|
| One activity at a time | `A.claim(player, id)`, `A.release`, `A.current` | claim fails with a notice if busy elsewhere |
| Rewards | `A.reward(player, { activity, hobby, xp, pence, items })` | pence capped by `Config.ACTIVITY_PAY_PER_HOUR` across all activities (saved in the profile); XP to the active character's progress; items to the account collection; toast on the client |
| Boards | `A.board(id, title, unit, cframe)`, `A.score(id, player, n, "max"\|"sum")` | "Today in this server", top `ACTIVITY_BOARD_SIZE`; `max` also saves a personal best |
| Building | `A.site(name)`, `A.part(props)`, `A.ground(x, z, fromY?)`, `A.prompt(...)`, `A.near(...)` | sites built from Config coordinates; Y by raycast |
| Character switch | module `leave(player)` | called before a switch so rewards go to the old character |
| Client | `Activities.toast(lines)` + one UI module per activity | |

## Pieces to add (build each once, the first time an activity needs it)

Each activity page lists the pieces it needs as **F1–F11**.

### F1 · Join pad and lobby
A marked pad (or prompt) with `minPlayers`, `maxPlayers`, and a countdown that starts when the
minimum is reached and shortens when full. Shows "2/4 — starting in 12 s" on a billboard and in
the joiners' HUD. Leaving the pad leaves the lobby. Activities with `minPlayers = 1` start
straight away; `npcFill = true` tops up with NPCs (F6) after a wait.
API sketch: `A.lobby(id, { pad = CFrame, min, max, wait, onStart = fn(players) })`.

### F2 · Rounds, timer and results
`A.round(players, { seconds, onTick?, onEnd })`: a shared timer shown in the HUD, scores kept by
the server, an end card (placings, pay, XP) and automatic `A.reward` + `A.score`. Rounds always
end cleanly when players leave, switch character or the server's round cap is hit.

### F3 · Teams
Split a lobby into 2 teams (balanced by count, friends together where possible), team colours on
the name tag, team scores. Needed by tug of war, sports day, regatta crews, rowing races in pairs.

### F4 · Spectators
Everyone within ~60 studs sees the live state: a billboard score line above the site, the site
board, and for big ones an optional "Watch" camera. Spectators of a finished round get a tiny
stipend once per session per activity (0–1d) so crowds form (PLAYER_GATHERING §2).

### F5 · Minigame controls kit (client)
One shared client module, `LondonClient/Activities/Kit`, used by every skill game so they feel
alike and all work on PC, gamepad and touch:
- **Meter**: press at the right moment (exists: `Shared.Meter` + the Strength UI; move it here).
- **Aim + power**: drag / stick to aim, hold-release for power (croquet, coconut shy, hoop-la,
  billiards, cricket bowling).
- **Rhythm lane**: notes fall to a line, press on the beat (bandstand, music hall, waltz, rowing).
- **Hold-steady**: keep a needle in a moving zone (kite flying, fishing reel, model boats).
- **Choice list**: pick from options against a timer (tea room orders, bouquet matching, debates).
The client only reports *inputs and timing*; the server works out the result (see F9).

### F6 · NPC participants
Uses the NPC framework (TASKS T24): an NPC can take an empty lobby slot (opponent, partner,
audience). NPCs play at a set skill level (Config), never win prizes or board places, and leave
when a player wants the slot.

### F7 · Scheduled sessions
Some activities are best as *appointments*: the bandstand concert at the half hour, the Punch &
Judy show, the market auction. Hooks into the hub appointments scheduler (TASKS T30): a start
time from the shared world clock, an announcement 2 minutes before, a HUD countdown.

### F8 · Rides
A seat (or seats) moved on a path or around a pivot, server-owned, with a ride cycle (board → ride
→ alight). Carousel, swing boats, helter-skelter, hot-air balloon, rowing boats (player-driven
variant). Riders can't be pushed off; the ride waits if someone is half-seated.

### F9 · Thrown and rolled things (server results)
Balls, rings, croquet balls, model boats: the client shows the flight at once, but the server
decides where it lands from the reported aim/power (with a little server-side randomness only
where real life has it: wind on a kite, not a dice roll for a prize). Rate limit throws.

### F10 · All-time boards, hobby rewards, collection book
TASKS T29 (OrderedDataStore boards and a "Hall of Champions"), T28 (hobby level cosmetics and
unlocks), T27 (collection book UI). Pages here list which board, which hobby, which items.

### F11 · Seasons
Season flag in Config (`"none"`, `"winter"`, `"jubilee"`...) that swaps some activities on or off
(ice skating, snowballs) and changes props (frozen lake surface).

## Rules every activity follows (ACTIVITIES §1, DESIGN §12)
- Period-appropriate, Roblox-safe: **no betting, no paid chance, no alcohol**, no weapons beyond
  the fairground's soft balls. Prizes are earned by skill or taking part, never by luck you pay for.
  Entry to pastimes is free; only consumables are sold (seed, tea, a bouquet's flowers).
- Rounds of 30 s – 5 min; join with one prompt; leave any time without penalty.
- Works solo and is better with others (scores, teams, crowds).
- Pay 1d – 1s per round from the game (never player-to-player stakes), under the shared hourly cap;
  XP to one hobby; collection entries where it makes sense. Never better money than a job.
- Touch and gamepad for everything; fits a landscape phone (~360 px tall).
- Server-authoritative: the client reports inputs, the server scores (F9). Every remote has a
  schema and a rate limit.

## Reward calibration (starting values, tune in M9)

| Round length | Pay | XP | Notes |
|---|---|---|---|
| ≤ 1 min (a throw, a feed, a dig) | 0–2d | 4–8 | many per hour; the hourly cap does the limiting |
| 1–3 min (a game of croquet, a song) | 2–4d | 10–20 | |
| 3–5 min (a race, a match, a show) | 4–12d | 20–30 | winners +50% pay, everyone gets XP |
| Hosted show with an audience | 1d per audience member, max 1s | 20–30 | audience members get 1–2 XP |

Hobby XP to level n: `100 × (n−1)^1.5` (Config `HOBBY_XP_*`). Level 10 ≈ 2,700 XP ≈ 6–10 hours of one hobby.
