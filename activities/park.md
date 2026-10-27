# The parks: St James's Park & the Mall (main hub), Green Park, Hyde Park

Map (`map_layout_v2.json`, studs; X north −/south +, Z west +/east −):
St James's Park x 24…620, z −44…−900 · lake centre (330, −470), radii 55 × 280, surface −1 ·
Blue Bridge across the lake at z −470 · park circuit path ·
bandstand marker (180, −300) · rowing marker (330, −650, on the water; jetty on the west shore
x ≈ 288) · croquet lawn marker (−380, −250, the lawn west of the park) ·
Green Park x −485…−295, z 640…−60 · Hyde Park x −1150…−320, z 690…850 with **Rotten Row**
(sand riding track, z 770, x −1140…−330).
F-numbers are framework pieces (`framework.md`).

---

## Feeding the ducks & pigeons (wave 1, built 2026-10-27)
`Activities/Ducks.luau` · any players · Outdoors · ~15 s
- **As built:** seed stand on the lake's west shore (Config `DUCKS_SITE`); buy seed (1d), 6 water
  birds swim over and 3 pigeons land at your feet, visible to everyone; species by in-game hour
  (pelicans 2–3 pm, swans at dawn, mallards otherwise). 4 Outdoors XP, collection entries, board
  "bags fed today". 15 s cooldown, 48 birds in the world at most.
- **Follow-ups:**
  - Pigeons are added to the collection on every feed, so the toast says "Found: London Pigeon"
    each time; only toast new finds for this activity.
  - Add 2 more time-of-day species for the collection page (moorhen at dusk, coot at night) and a
    rare **black swan** that appears only during the bandstand concert (rewards being at the hub
    at appointment time, not chance).
  - Several players feeding together: birds split between them; 3+ feeders at once = a "flock"
    bonus +2 XP each (better with others).
- **Done when** the follow-ups are in and two players feeding side by side both get birds.

## Croquet (wave 1)
Lawn west of St James's Park (−380, −250) · 1–4 players · Sport · 3–5 min
- **Pitch:** the gentle, slightly cut-throat lawn game of the 1890s; knock rivals' balls away.
- **How it plays:** a 6-hoop course plus a peg, laid out from Config. Players take turns (F1 lobby,
  F2 rounds). Your turn: aim + power (F5), the server rolls the ball (F9, simple friction on
  grass, bounces off hoops). Through your next hoop = another shot. Hit another ball = "roquet":
  one bonus shot, and you can send theirs away. First to the peg wins; 12-shot cap per player for
  a hard time limit.
- **Controls:** drag (touch) / stick (gamepad) / mouse to aim; hold and release for power.
- **Rewards:** 3d to all, 6d to the winner; Sport 15 XP (winner 25). Board: wins today.
- **With others:** roquets make it social; spectators see a live hoop tally (F4). Solo: play
  against the clock (fewest shots), board = best solo score.
- **Quiet server:** NPC opponent (F6) after 30 s in the lobby.
- **Server checks:** only the player whose turn it is may shoot; power/angle clamped; one shot per
  turn; ball physics on the server (or a deterministic sim) so results can't be faked.
- **Needs:** F1, F2, F4, F5 (aim+power), F6, F9. Config `CROQUET_*` (site, hoop layout, shot cap,
  pay, XP). Props: hoops, peg, mallet held on the character (simple parts).
- **Done when** 4 players finish a game with correct turn order and a winner, and solo mode
  records a best score.

## Lawn tennis (wave 2)
Next to the croquet lawn · 2 or 4 players · Sport · 2–4 min
- **How it plays:** a timing rally (F5 meter): the ball comes to you, press as it crosses your
  zone; early/late sends it wide. Rally speeds up each hit. Points to 4 (no deuce for brevity),
  best of 3 games. Doubles = 2 v 2 (F3), alternate hitters.
- **Rewards:** 3d / winner 6d; Sport 15/25 XP. Board: match wins today.
- **Quiet server:** NPC opponent (F6).
- **Needs:** F1, F2, F3, F5 (meter), F6. A net and court lines (parts).

## Rowing on the lake (wave 1)
Jetty on the lake's west shore (x ≈ 288, z ≈ −650); south half of the lake (below the Blue
Bridge) · 1–4 per boat, up to 4 boats · Sport · 2–4 min
- **Pitch:** hire a rowing boat for a turn around the lake, or race.
- **How it plays:** a boat ride you power yourself (F8 player-driven): a rhythm lane (F5) — press
  in time with the stroke; good timing = speed, misses = slow and a splash. More rowers in a boat =
  higher top speed if they stay in time together (better with others). Free row: no timer,
  explore the lake. **Race:** 3 buoys around the south half, 1 lap; up to 4 boats (F1, F2).
- **Controls:** stroke button / key on the beat; steer left/right.
- **Rewards:** free row: 1d per minute up to 4 min, Sport 5 XP/min. Race: 3d / winner 8d, 20 XP.
  Board: fastest lap today (`max` on negative time, or store seconds and sort ascending: add an
  `A.score` "min" mode).
- **Quiet server:** race against an NPC crew (F6) or the clock.
- **Server checks:** boat speed capped by crew size × timing quality reported per stroke (server
  re-checks stroke timing against the beat it sent, like the strength meter).
- **Needs:** F1, F2, F5 (rhythm), F6, F8 (boat), new `A.score` mode "min". Config `ROWING_*`.
- **Done when** a 2-rower crew beats a 1-rower boat when both row in time, and a race finishes
  with placings.

## Bandstand concert (wave 1)
Bandstand (180, −300) · 1–8 players + audience · Music · ~2 min per song
- **Pitch:** play in the park band; the crowd listens and tips.
- **How it plays:** scheduled at the half hour (F7) and on demand when 2+ musicians are waiting.
  Each player picks an instrument (cornet, euphonium, drum, clarinet; cosmetic). A rhythm lane
  (F5) per instrument plays a short period piece (march, waltz). Hits add to a shared band score;
  the music plays for everyone nearby, with missed notes muted for that player's part.
- **Rewards:** 2d + 1d per 2 audience members (max 1s) by band score; Music 20 XP. Audience
  within 40 studs for the whole song: 2 Music XP and 1d once per concert (F4 stipend).
  Board: best band score today.
- **Quiet server:** an NPC band plays the scheduled concert (F6, F7) so the hub has music; players
  can join any free part.
- **Needs:** F1, F2, F4, F5 (rhythm), F6, F7. 🔒 Music: tracks from the Roblox audio library, one
  stem per instrument if possible (user picks; Config `BAND_SONGS`).
- **Done when** 3 players finish a song with a shared score and listeners get their stipend.

## Kite flying (wave 2)
Green Park · any players · Outdoors · open-ended, scored per 60 s
- **How it plays:** buy or bring a kite (cosmetic colours), hold-steady minigame (F5): keep the
  wind needle in the zone; the kite climbs while you do and dips when you don't. Wind gusts come
  from a shared server wind value, so everyone's kites lean the same way (it looks right from
  afar). Height every 60 s is your score.
- **Rewards:** 1d per minute (max 5), Outdoors 4 XP/min. Board: highest kite today.
- **Needs:** F5 (hold-steady), a kite model on a string (Beam + part). Config `KITE_*`.

## Model boats at the pond (wave 2)
The lake's north half (above the Blue Bridge) · 1–6 players · Outdoors · ~2 min
- **How it plays:** steer a toy sailboat (small boat part, F9 server-moved) across to the far
  shore through 3 gates; wind from the shared wind value pushes it; tilt the sail (hold-steady)
  to use it. Race mode with a lobby (F1).
- **Rewards:** 2d / winner 5d; Outdoors 12/20 XP. Board: fastest crossing today ("min").
- **Needs:** F1, F2, F5, F9.

## Rotten Row promenade & "Best Dressed" (wave 1)
Rotten Row, Hyde Park (z 770, x −1140…−330) · any players · Performance · open-ended + a vote
each in-game day
- **Pitch:** the fashionable ride and walk; see and be seen.
- **How it plays:** walking, riding or driving the length of the Row (start and end gates) counts a
  "turn". At the end of each in-game day (~24 min) everyone who made a turn that day can vote
  once for the best-dressed player who also made a turn (a voting UI listing names with their
  outfits; you can't vote for yourself or your linked characters). Top 3 announced in the Gazette
  column and on a board by the Row.
- **Rewards:** a turn: 1d + Performance 4 XP (max 3 turns per in-game day). Winner: 1s + a
  cosmetic rosette for the next day; top 3: Performance 20 XP.
- **Server checks:** turns must take ≥ 20 s and pass both gates; votes limited to one per account
  per day, not for the voter's own characters; at least 3 voters for a result.
- **Needs:** gates (two trigger zones), a vote UI (reusable later for no-confidence votes,
  TASKS T38), daily reset from the world clock. Config `PROMENADE_*`.
- **Done when** 3 players make turns and a vote picks a winner at in-game midnight.

## Picnic (wave 1)
Any lawn in St James's or Green Park · 2+ players · Outdoors · open-ended
- **Pitch:** a blanket, a hamper, friends.
- **How it plays:** one player lays a blanket (prompt anywhere on grass, max 1 per player, gone
  after 10 min or when they leave). Others nearby can "join the picnic" (sit emote on the
  blanket). The host shares food items (tea, buns, sandwiches; bought from park kiosks or
  vendors for 1–3d); passing one is a give prompt. Everyone on the blanket for 2 minutes gets XP.
- **Rewards:** Outdoors 6 XP per 2 min on a blanket with 2+ people (max 30 per picnic). No pay
  (it's leisure); a "Picnic in the Park" collection stamp for 5 picnics.
- **Needs:** blanket prop, sit-on-blanket seats, consumable items (shared item system: TASKS T15
  shops), give prompt. Config `PICNIC_*`.

## Ice skating & snowball fights (season: winter)
The lake frozen (F11) / park lawns · any players · Sport · open-ended
- **Ice skating:** when the season is winter the lake surface becomes ice (walkable, low friction:
  a custom physical material); skate rental hut on the shore (free). A figure-skating "trick"
  meter (F5) on the ice. 1d per trick (max 6/min), Sport 3 XP per trick.
- **Snowballs:** snow on lawns; pick up a snowball (prompt), throw (F5 aim, F9). Hits give a
  harmless "splat" and a point. No damage (LAW §1 safe from it). Optional team snowball fight
  with a lobby (F1, F3). 2d / winners 4d per fight, Sport 10 XP.
- **Needs:** F11, F1, F3, F5, F9, a winter look for the park.
