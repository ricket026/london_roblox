# Vehicles spec

Starting values; all in `Config.Vehicles`. Speeds in studs/s. Displayed speed in mph =
studs/s ÷ 2.4 (so the default 14 mph limit ≈ 34 studs/s). Walking is 16 studs/s.

## 1. Classes

| Kind | Seats | Top speed | Accel | Turn | Reverse | Owned / hired | Licence |
|---|---|---|---|---|---|---|---|
| Penny-farthing | 1 | 24 | low | wide | no | owned | – |
| Safety bicycle | 1 | 28 | med | tight | no | owned | – |
| Riding horse | 1 (+1 pillion) | walk 12 / trot 22 / canter 32 | med | tight | slow | owned / stable hire | – |
| Hansom cab | driver + 2 | 30 | med | med | slow | cab yard hire / owned | Cab |
| Four-wheeler | driver + 4 | 26 | low | wide | slow | cab yard hire / owned | Cab |
| Horse omnibus | driver + 10 | 22 | low | very wide | slow | company (job) | Omnibus |
| Brougham | driver + 2 | 28 | med | med | slow | owned | – |
| Landau | driver + 4 | 26 | low | wide | slow | owned | – |
| State landau | driver + 4 | 18 | low | wide | no | Crown, events | – |
| Delivery van / dray | driver + 1 | 22 | low | wide | slow | job | – |
| Police van | driver + 1 + 2 cells | 26 | med | med | slow | police | – |
| Steam fire engine | driver + 3 | 26 | low | wide | slow | fire brigade | – |
| Motor carriage | 2 | 40 | med | med | yes | owned | Motor |
| Motor tourer | 4 | 44 | med | wide | yes | owned | Motor |

Motor cars are the only vehicles whose top speed is above the default limit, so speeding is
mostly a motorist crime (by design).

## 2. Driving model
- One shared chassis controller (server-validated, driver-owned physics), tuned per kind by
  the table above. Horse-drawn vehicles get a **horse feel**: speed steps (walk/trot/canter) rather
  than a smooth throttle, a short "pull away" delay, and refusal to reverse more than a few studs.
- Motor cars: **crank start** (hold to crank, 1–3 s random; fails 20% in cold/fog), smooth
  throttle, chance to stall if you brake hard at low speed (5%).
- Bicycles: lean into turns, dismount automatically when hit or when speed hits 0 on a slope.
- Horses as models are animated client-side from the vehicle's speed (walk/trot/canter cycles).

## 3. Controls

| Action | PC | Gamepad | Touch |
|---|---|---|---|
| Throttle / speed step up | W | RT | right-side pedal button |
| Brake / step down | S | LT | left pedal button |
| Steer | A / D | left stick | left thumbstick |
| Horn / bell / whistle | H | Y | button |
| Enter / exit | E (ProximityPrompt) | X | prompt tap |
| Crank (motor) | hold E | hold X | hold button |
| Fare meter on/off (cab) | F | B | button |

## 4a. State & official vehicles (Q13)
- **Free while you hold the role:** the King, Queen and royal family summon from the **Royal
  Mews** (behind the palace): state landau, royal brougham, royal motor tourer, riding horses.
  Ministers (PM, Chancellor, Home Secretary), the Speaker, judges and the Superintendent summon
  from the **government garage** (Whitehall): ministerial brougham, official motor car.
- No licence fee, fuel or repair costs; they despawn when you lose the role or leave.
- Royal/official liveries make them recognisable. They count toward `MAX_LIVE_VEHICLES` but not
  toward the private motor cap.
- Everyone else pays a **hefty price** for private vehicles (ECONOMY §3).

## 4. Ownership, spawning, storage
- Owned vehicles live in the profile (`vehicles[]`). Summon at your **mews** (townhouse),
  a **stable/garage** (public, 6d fee) or a cab yard (cabs only).
- One summoned vehicle per player at a time. Server cap: `MAX_LIVE_VEHICLES` = 40 total,
  `MAX_LIVE_MOTORS` = 6 (Q13).
- Idle despawn: no driver for 5 min and nobody within 60 studs → returned to storage.
- Only the owner (and key holders) can drive; anyone allowed by the driver can ride.
- Cab yard hire: 5s per shift, the cab returns when you go off duty or leave.

## 5. Upkeep and condition
- **Condition** 0–100 saved per owned vehicle. Collisions above 20 studs/s cost 2–10.
  Below 40 condition: top speed −20%; at 0: broken down, must be towed (cab yard / engineer).
- **Horses**: need feed once per in-game day (6d, auto-charged when stabled; if unpaid the horse
  is "tired": max speed = trot). No horse death.
- **Motors**: fuel tank lasts ~20 min of driving; refill at a chemist or motor works (1s).
  Breakdown roll 1% per minute of driving when condition < 60. A **motor engineer** player
  repairs faster and cheaper than the NPC works.

## 6. Licences
- Cab, Omnibus and Motor licences, saved in the profile.
- Earned by a short **driving test** at Scotland Yard's Public Carriage Office: a timed course
  with no collisions and no speeding (NPC examiner; a police sergeant can run it in person).
- Revoked by a court sentence or by 3 speeding convictions in a session (restored after 24 h real).

## 7. Rules of the road
- **Speed limit** (Parliament lever, 8–20 mph, default 14). Police see a speedometer reading on a
  vehicle they're looking at within 80 studs ("Speed trap" tool) and can signal "Stop".
- **No vehicle killing.** A vehicle hitting a character never deals damage. The character is
  shoved aside (ragdoll 1 s, no damage) and the driver gets a `reckless` strike. 3 strikes in
  10 min → wanted for reckless driving; 6 → vehicle confiscated for the session (logged).
- Vehicle-to-vehicle hits: condition loss only.
- **Pedestrian zones** (invisible collision for vehicles only, open during events): palace
  forecourt, market, station platforms, park paths, cathedral steps.
- Drive on the **left** (it's London). NPC traffic follows lanes.

## 8. Fares (cabs and omnibus)
- **Cab:** driver turns the meter on with passengers aboard. Fare = 6d flag + 3d per 100 studs,
  paid automatically on exit (passenger can refuse at an RP cost: the driver may call police for
  "bilking"). Players can also hail with a whistle emote; NPC fares spawn at ranks (low pop, §9).
- **Omnibus:** fixed route through the districts with ~8 stops. 1d per stop ridden, max 6d,
  paid on boarding. The driver earns per passenger-stop plus a per-lap wage.

## 9. NPC traffic and fares (Q14)
- When fewer than N players are driving in the area, light NPC traffic runs on main-road lanes:
  hansoms, vans, the omnibus. NPC vehicles yield, stop for players and never block a road for
  more than 5 s (they despawn if stuck).
- NPC fares wait at cab ranks so the cabbie job works on a quiet server.
- NPC count scales down as players rise (budget in Config).

## 10. Security
- Server checks every driven vehicle each second: speed ≤ kind max × 1.15, no teleports
  (> 3× top speed per second), seats legit. Violations → vehicle returned + Guard flag.
- Seat occupancy and ownership checked server-side on every enter request.
- Flinging guard: vehicles have capped mass ratio vs characters; collisions with characters
  are handled by the no-kill shove, not raw physics.
