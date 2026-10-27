# Activities: design specs

The detailed design for every side activity in `ACTIVITIES.md`, one section each, so an agent can
build any of them from its page. Read **`framework.md`** first: the rules every activity follows,
the reward scale, and the shared framework pieces **F1–F11** that pages refer to. Each page gives
the site (map coordinates), players, hobby, round length, how it plays, controls, rewards, how it
works with others and on a quiet server, server checks, what it needs, and "done when".

| Page | Area |
|---|---|
| [park.md](park.md) | St James's Park & the Mall (main hub), Green Park, Hyde Park |
| [covent-garden.md](covent-garden.md) | Covent Garden & the West End (hub 2) |
| [fairground.md](fairground.md) | the fairground on the Covent Garden piazza |
| [sports.md](sports.md) | races and sports |
| [indoors.md](indoors.md) | clubs, coffee houses, the ballroom |
| [exploration.md](exploration.md) | exploring and collecting |

## Build order

Build a framework piece the first time an activity needs it, then reuse it. Suggested order:

1. **Framework pieces F5 (controls kit), F1 (lobby), F2 (rounds), F9 (thrown things)**: almost
   everything needs them. Move the strength meter UI into the kit at the same time.
2. **Batch A, buildable now** (needs only the framework): coconut shy, hoop-la, croquet, fishing,
   curiosities hunt, rowing on the lake, carousel & swing boats (F8), Rotten Row promenade,
   kite flying, model boats, cricket nets, and the follow-ups for the four built activities
   (ducks, strength, mudlarking, chess + draughts).
3. **Batch B, needs sounds or animations from the user** (🔒 audio library picks, published
   animations): bandstand concert, music hall, busking, waltz & quadrille, piano, Punch & Judy.
   The code can be built first with placeholder silence; say so in the report.
4. **Batch C, needs other systems** (see TASKS): bicycle/horse races (vehicles T13–T14), regatta
   and sports day (events T39), tea room, flower selling, picnic (shops T15, NPCs T24), market
   auction (ledger T09), photography, detective mysteries (NPCs T24), allotments, ice skating
   (seasons F11), hot-air balloon (F7, F8).

Hubs come first within a batch (PLAYER_GATHERING §1): the parks and Covent Garden before the rest.

## All activities

Status: ✅ built (not yet Play-tested) · ⬜ specced, not built.

| Activity | Page | Wave | Status | Players | Hobby | Framework | Depends on |
|---|---|---|---|---|---|---|---|
| Feeding the ducks & pigeons | park | 1 | ✅ (+ follow-ups) | any | Outdoors | – | – |
| Croquet | park | 1 | ⬜ | 1–4 | Sport | F1 F2 F4 F5 F6 F9 | – |
| Lawn tennis | park | 2 | ⬜ | 2/4 | Sport | F1 F2 F3 F5 F6 | – |
| Rowing on the lake | park | 1 | ⬜ | 1–4 per boat | Sport | F1 F2 F5 F6 F8 | – |
| Bandstand concert | park | 1 | ⬜ | 1–8 + audience | Music | F1 F2 F4 F5 F6 F7 | 🔒 music |
| Kite flying | park | 2 | ⬜ | any | Outdoors | F5 | – |
| Model boats | park | 2 | ⬜ | 1–6 | Outdoors | F1 F2 F5 F9 | – |
| Rotten Row promenade & Best Dressed | park | 1 | ⬜ | any | Performance | vote UI | – |
| Picnic | park | 1 | ⬜ | 2+ | Outdoors | – | T15 items |
| Ice skating & snowballs | park | season | ⬜ | any | Sport | F1 F3 F5 F9 F11 | – |
| Music hall stage | covent-garden | 1 | ⬜ | 1–6 + audience | Performance | F1 F4 F6 | 🔒 sound cues |
| Punch & Judy | covent-garden | 2 | ⬜ | any | Performance | F7 | – |
| Market auction | covent-garden | 2 | ⬜ | any | Collecting | F7 | T09 ledger |
| Flower selling | covent-garden | 1 | ⬜ | 1 | Performance | F5 F6 | T24 NPCs, T15 |
| Tea room | covent-garden | 1 | ⬜ | 2+ | Performance | F5 F6 | T15 |
| Busking | covent-garden | 1 | ⬜ | 1 | Music / Performance | F5 | T24, 🔒 sounds |
| Photography studio | covent-garden | 2 | ⬜ | 2+ | Performance | – | T05 poses |
| Baking contest | covent-garden | 3 | ⬜ | 2–6 | Performance | F1 F2 F5 F7 | – |
| Test your strength | fairground | 1 | ✅ (+ follow-ups) | 1 | Sport | (F1 queue) | 🔒 bell sound |
| Coconut shy | fairground | 1 | ⬜ | 1 | Sport | F5 F9 | – |
| Hoop-la | fairground | 2 | ⬜ | 1–2 | Sport | F5 F9 | – |
| Carousel & swing boats | fairground | 1 | ⬜ | any | Outdoors | F5 F8 | 🔒 organ music |
| Helter-skelter | fairground | 2 | ⬜ | any | Sport | F5 F8 | – |
| Hot-air balloon ride | fairground | 2 | ⬜ | ≤ 6 | Outdoors | F7 F8 | – |
| Bicycle race (park circuit) | sports | 1 | ⬜ | 2–8 | Sport | F1 F2 F6 | T13 T14 |
| Horse race (Rotten Row) | sports | 2 | ⬜ | 2–8 | Sport | F1 F2 | T13 |
| Rowing regatta (Thames) | sports | 2 | ⬜ | 2–8 crews | Sport | F1 F2 F3 F4 F7 F8 | T39 |
| Cricket nets | sports | 2 | ⬜ | 1–6 | Sport | F1 F5 F6 F9 | – |
| Sports day (tug of war, sack race, egg-and-spoon) | sports | 2 | ⬜ | 4–16 | Sport | F1 F2 F3 F5 F7 | T39 |
| Motor Run | sports | 1 | ⬜ | motorists | – | – | T39 T49 (event) |
| Chess (+ draughts) | indoors | 1 | ✅ chess (+ follow-ups) | 2 | Games | – | – |
| Billiards | indoors | 2 | ⬜ | 2 | Games | F1 F2 F5 | – |
| Debating society | indoors | 2 | ⬜ | 2 + audience | Performance | F1 F2 F4 | – |
| Waltz & quadrille | indoors | 1 | ⬜ | pairs / 8 | Performance | F1 F3 F5 | T05, 🔒 animations + music |
| Piano | indoors | 2 | ⬜ | 1 | Music | F5 | 🔒 note samples |
| Mudlarking | exploration | 1 | ✅ (+ follow-ups) | 1 | Collecting | – | – |
| Fishing on the Embankment | exploration | 1 | ⬜ | 1 per spot | Outdoors | F5 | – |
| Curiosities hunt | exploration | 1 | ⬜ | 1 | Collecting | – | T27 book |
| Detective mysteries | exploration | 3 | ⬜ | 1–4 | Collecting | – | T24 |
| Street photography | exploration | 3 | ⬜ | 1 | Collecting | – | T27 |
| Allotment gardening | exploration | 3 | ⬜ | 1 | Outdoors | – | T15 |

Wave 1 here has 20 activities, matching ACTIVITIES §5 (~20 before the first public test).

## New collection pages these add
Birds of the Park (exists, + moorhen, coot, black swan) · Mudlark Finds (exists, + London Bridge
stretch) · Fish of the Thames · Curiosities of London (100) · Portraits · Photographs · stamps
(balloon ascent, picnics, cases closed) · medals and rosettes (regatta, races, best dressed,
sports day).
