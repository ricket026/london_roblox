# Side activities & minigames spec

> Detailed per-activity designs (sites, rules, controls, rewards, build steps) are in
> [`activities/`](activities/README.md); this page stays the overview.

The user wants **a ton** of side activities (2026-10-24). They're what players do between jobs
and RP, and the main way to keep hubs busy (PLAYER_GATHERING §2).

## 1. Rules for every activity
- Period-appropriate (1897) and Roblox-safe: **no betting, no paid chance** (no loot boxes,
  no wagers), no alcohol, no weapons beyond the fairground's soft balls.
- Short: 30 s – 5 min per round. Join with one prompt; leave any time.
- Works solo **and** better with others (scores, teams, crowds).
- Pays a little (1d–1s) + **hobby XP**, cosmetics and collection entries. Never better money than
  a job, so it stays fun, not a grind.
- Built on a shared **Activity framework**: queue/join pad, round timer, scoring, leaderboard
  board on site (daily + all-time), rewards, spectator view.
- Touch and gamepad controls for every one.

## 2. Activity list
**Wave 1** ships with the first public test; **Wave 2–3** follow as regular updates (one every 1–2
weeks keeps players returning).

### St James's Park & the Mall (main hub)
| Activity | Players | How it plays | Wave |
|---|---|---|---|
| Croquet | 1–4 | Aim + power swing through hoops, turn-based | 1 |
| Lawn tennis | 2 or 4 | Simple timing rally game (the 1890s craze) | 2 |
| Rowing on the lake | 1–4 per boat | Rhythm paddling; races against the clock or each other | 1 |
| Bandstand concert | 1–8 | Instrument rhythm game; crowd listens, players earn tips | 1 |
| Feeding the ducks & pigeons | any | Cosy: buy seed (1d), birds flock around you | 1 |
| Kite flying | any | Hold the wind meter steady; kites visible across the park | 2 |
| Model boats at the pond | 1–6 | Steer a toy sailboat across the pond, race | 2 |
| Rotten Row promenade | any | Ride or walk the row in fine clothes; "Best Dressed" vote each in-game day | 1 |
| Picnic | 2+ | Lay a blanket, share food items, sit emotes | 1 |
| Snowball fight / ice skating | any | Winter season only; skating rink on the frozen lake | Season |

### Covent Garden & the West End
| Activity | Players | How it plays | Wave |
|---|---|---|---|
| Music hall stage | 1–6 + audience | Players perform (stage tools: curtain, spotlight, props, sound cues); audience applauds → tips | 1 |
| Punch & Judy show | any | Watch, or work the puppets with emotes | 2 |
| Market auction | any | Auction an item (in-game money; it's buying, not chance) | 2 |
| Flower selling | 1 | Make bouquets (match the order) and sell to NPCs/players | 1 |
| Tea room | 2+ | Hosting minigame: serve tea and cakes in the right order | 1 |
| Busking | 1 | Play an instrument / juggle / magic emote set on a pitch; earn tips | 1 |
| Photography studio | 2+ | Pose, the photographer takes a portrait card for your collection | 2 |
| Baking contest | 2–6 | Timed recipe minigame, judged by score | 3 |

### The Fairground (Covent Garden on market days, Hampstead Heath edge for bank holidays)
| Activity | Players | How it plays | Wave |
|---|---|---|---|
| Carousel & swing boats | any | Ride (social, screenshots) | 1 |
| Test your strength | 1 | Timing meter → hit the bell | 1 |
| Coconut shy | 1 | Throw soft balls, skill aim | 1 |
| Hoop-la (ring toss) | 1 | Skill throw | 2 |
| Helter-skelter | any | Slide ride | 2 |
| Hot-air balloon ride | up to 6 | Ride over the city; see the whole map | 2 |

### Sports & races
| Activity | Players | How it plays | Wave |
|---|---|---|---|
| Bicycle race (park circuit) | 2–8 | Laps, checkpoints | 1 |
| Horse race (track at the edge of town) | 2–8 | Riders race; no betting | 2 |
| Rowing regatta on the Thames | 2–8 boats | Weekly headline event, teams of 2–4 | 2 |
| Cricket nets | 1–6 | Batting timing; bowling aim | 2 |
| Sports day: tug of war, sack race, egg-and-spoon | 4–16 | Bank holiday event minigames | 2 |
| Motor Run | motorists | EVENTS §2 | 1 |

### Clubs, coffee houses & indoors
| Activity | Players | How it plays | Wave |
|---|---|---|---|
| Chess & draughts | 2 | Real boards, no money | 1 |
| Billiards | 2 | Physics cue game at the club | 2 |
| Debating society | 2 debaters + audience | Timed speeches, audience vote, filtered motions | 2 |
| Waltz & quadrille (balls) | pairs / sets of 8 | Dance rhythm game synced to music | 1 |
| Piano in houses | 1 | Playable piano | 2 |

### Exploration & collecting
| Activity | Players | How it plays | Wave |
|---|---|---|---|
| **Mudlarking** | 1 | At low tide, search the Thames foreshore for curios (coins, pipes, buttons, rare finds) | 1 |
| Fishing on the Embankment | 1 | Timing catch; fish for the collection or to sell | 1 |
| **Curiosities hunt** | 1 | 100 hidden curios across the city (rooftops, alleys, interiors) | 1 |
| Detective mysteries | 1–4 co-op | Scripted puzzle cases: find clues, interview NPCs, name the culprit (no gore) | 3 |
| Street photography | 1 | Photograph landmarks and events for a photo album | 3 |
| Allotment gardening | 1 | Plant, water, harvest over real time; sell flowers/veg at market | 3 |

## 3. Hobby levels
Hobbies (Sport, Music, Performance, Outdoors, Collecting, Games) level 1–10 from activity XP.
Each level gives a cosmetic (hat ribbon, medal, title tag like *"Champion Oarsman"*), and some
unlock things: a better rod, a rowing club boat, a stage costume set, a private croquet set for
your townhouse garden.

## 4. Collections & trophies
- **Collection book:** curios, fish, mudlark finds, photographs, portraits, event medals.
  Completing a page gives a cosmetic and a Gazette mention.
- **Trophy cabinet** in your house shows medals and trophies from races and contests; visitors see it.
- **Leaderboards** on site boards (daily/weekly/all-time) and a "Hall of Champions" in the club.

## 5. Build order
- **With M3 (first jobs):** the Activity framework + 4 cheap ones to prove it: feeding the ducks,
  chess, test your strength, mudlarking.
- **Wave 1 total ≈ 20 activities** before the first public test (M9).
- Waves 2–3 as updates after launch.
