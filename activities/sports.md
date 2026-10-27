# Sports & races

Races use vehicles (TASKS T13–T14) or boats (F8) and are the natural **headline events**
(PLAYER_GATHERING §2): schedule them, announce them across servers ("What's on", T31), and close
the course to other traffic while they run (VEHICLES §7 pedestrian zones open only for events).

Map: St James's Park circuit path (40,−80) → (200,−180) → (200,−780) → (420,−880) → (560,−760) →
(560,−180) → (420,−70) → back, ≈ 2,350 studs a lap · Rotten Row, Hyde Park, a straight sand track
z 770 from x −1140 to −330 (810 studs) · the Thames x 1150…1450, surface −14, Westminster Bridge
z −1192, Hungerford Railway Bridge z −1350 (deck 14, ample clearance), Blackfriars Bridge z −2000 ·
Green Park x −485…−295, z 640…−60 · Motor Run route: `Map.Routes["Motor Run"]`.

---

## Bicycle race, park circuit (wave 1)
St James's Park circuit · 2–8 riders · Sport · 2 laps ≈ 3 min (safety bicycle 28 studs/s)
- **How it plays:** a lobby at the start line by the Mall (F1, min 2, NPC fill F6 on quiet
  servers). Riders bring their own bicycle or borrow a club bicycle for the race (free, despawns
  after). Countdown, then 2 laps through 6 checkpoints; missing one sends you back to it.
  Pedestrians are kept off the path by a "race in progress" barrier while it runs.
- **Rewards:** finish 3d, podium 6d/5d/4d (+ winner's rosette); Sport 20 XP (winner 30). Board:
  fastest lap today ("min"). All-time board (F10).
- **Server checks:** checkpoints in order, lap time ≥ a floor based on top speed (anti-teleport),
  vehicle speed checks from the vehicle framework.
- **Needs:** vehicles (T13, T14: bicycle), F1, F2, F6, checkpoints, `A.score` "min" mode,
  temporary path barrier. Config `BIKE_RACE_*`.
- **Done when** 3 riders race 2 laps with placings, and a missed checkpoint is enforced.

## Horse race, Rotten Row (wave 2)
Rotten Row · 2–8 riders · Sport · out and back ≈ 60 s
- **How it plays:** riders on their own or hired horses (stable hire, VEHICLES §4). Start gate at
  the west end, turn at a post at the east end, finish back at the gate. Horse speed steps
  (walk/trot/canter) with a stamina bar: cantering drains it, trotting recovers it, so pacing is
  the skill. No betting, ever.
- **Rewards:** as the bicycle race. Board: fastest time today.
- **Needs:** riding horse (T13 class), stamina value on the horse controller, F1, F2.

## Rowing regatta on the Thames (wave 2, weekly headline event)
Westminster Bridge to Blackfriars Bridge (≈ 810 studs downstream) · 2–8 boats, crews of 2–4
(F3) · Sport · ≈ 3 min
- **How it plays:** a scheduled weekly event (F7, PLAYER_GATHERING headline slots). Crews sign up
  as teams; the rowing rhythm game from the lake (park.md) with crew timing; the river's current
  helps everyone equally. Spectators line the Victoria Embankment (x 1130…1146) and the bridges,
  and get the spectator stipend (F4). A launch with an NPC umpire follows the race.
- **Rewards:** crew finish 4d each, winners 1s each + a regatta medal (cosmetic, collection);
  Sport 30 XP. All-time board of winning crews (F10).
- **Needs:** the rowing boat from the lake (F8, larger crew variant), F1, F2, F3, F4, F7, the
  river surface as water the boats can sit on, and a way down to it (racing pontoon by
  Westminster Bridge).

## Cricket nets (wave 2)
Green Park · 1–6 · Sport · ~2 min
- **How it plays:** take turns batting or bowling in two nets. **Batting:** the ball comes in;
  press as it reaches the crease (F5 meter, earlier = pull, later = cut); timing gives runs (0–6)
  and a ball that goes out over the net on a 6. 12 balls per innings. **Bowling:** aim + power (F5)
  at a stump target; line and length score. NPC bowler / batter fills in solo.
- **Rewards:** 1d per 10 runs (max 6d), 2d for bowling a batter out; Sport 12 XP. Board: highest
  innings today.
- **Needs:** F1, F5 (meter, aim+power), F6, F9, nets and stumps.

## Sports day: tug of war, sack race, egg-and-spoon (wave 2, bank holidays)
Hyde Park lawns (x −1150…−320, z 690…850, avoiding the Row) · 4–16 · Sport · each game ~1 min
- Run as a bank-holiday event (EVENTS Market Day / decree "bank holiday", COURT §6) with an NPC
  steward calling each game; also playable any time with a lobby.
- **Tug of war:** two teams (F3) on a rope; press in rhythm with your team's caller (F5 rhythm):
  team timing pulls the rope; 3 pulls over the line wins. Clearly better with more people.
- **Sack race:** hop button timing (F5 meter) down a 60-stud lane; mistimed hops make you fall
  over (a harmless tumble, 1 s).
- **Egg-and-spoon:** walk the lane while keeping a wobbling needle centred (F5 hold-steady); drop
  the egg and you go back 10 studs.
- **Rewards:** per game 2d / winners 4d; Sport 10 XP; a sports-day ribbon for winning all three.
- **Needs:** F1, F2, F3, F5, F7.

## Motor Run (wave 1, event)
See EVENTS §2 (host or weekly schedule; route `Map.Routes["Motor Run"]`; prizes for finishing,
not winning; speed limit off and roads closed). It belongs to the event framework (TASKS T39,
T52) rather than the activity framework, but uses the same reward call and boards.
