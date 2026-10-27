# Covent Garden & the West End (hub 2)

Map: Covent Garden piazza x −222…−58, z −1300…−1500 · Covent Garden Market building x −190…−90,
z −1340…−1460 · St Paul's, Covent Garden (the actors' church, portico on the piazza) z −1268…−1296 ·
fairground marker (−140, −1320) · music hall marker (190, −1470) · Royal Opera House x −380…−280,
z −1505…−1545 · West End district x −505…−165, z −975…−1185 · Leicester Sq garden
x −470…−305, z −1028…−1144 · Trafalgar Sq x −145…125, z −995…−1145.
There are no building interiors yet: where one is needed, build a greybox room from parts on the
nearest lot (`Map.Plots`) until the art pass (M8).

---

## Music hall stage (wave 1)
Music hall (190, −1470) · 1–6 performers + audience · Performance · a show is 2–5 min
- **Pitch:** the great Victorian night out: comic songs, magic, a strongman, and a crowd.
- **How it plays:** a stage with stage tools for performers: curtain open/close, spotlight
  (follow a performer), 3 backdrops, prop chest (cane, top hat, juggling clubs, magic hat),
  sound cues (drum roll, cymbal, piano vamp, laugh, applause). A performer books the next slot at
  the stage door (queue, F1 with min 1). During a slot (3 min, extendable once): their act is
  whatever they do with emotes, quick phrases (TASKS T05), props and cues. The audience presses
  **Applaud / Cheer / Encore** (rate-limited); the "applause meter" is the score.
- **Rewards:** performer: 1d per audience member who applauded, max 1s, Performance 20 XP, +10 XP
  for an encore. Audience: 1 Performance XP per act watched (max 10 per visit). Board: loudest act
  today. Tea and lemonade at the bar (no alcohol, DESIGN §12).
- **Quiet server:** an NPC pianist plays between acts; NPC audience fills seats (F6) but NPC
  applause pays nothing (only real players pay out).
- **Server checks:** one applause per audience member per act counts for pay; performers can't
  applaud themselves; alt-account farming limited by the hourly cap and "same account pair" rule
  (ECONOMY §9 pattern).
- **Needs:** greybox hall (stage, 40 seats, bar), stage tool UI for the performer, audience
  buttons, F1, F4, F6. 🔒 Sound cues from the audio library. Config `MUSICHALL_*`.
- **Done when** a performer runs a slot with curtain, spotlight and cues, and two audience members'
  applause pays them.

## Punch & Judy (wave 2)
Booth under St Paul's portico on the piazza · any players · Performance · ~3 min
- **How it plays:** scheduled show (F7) every ~15 min by an NPC puppeteer; a player can take over
  as the puppeteer: two puppet buttons per hand (wave, bonk, chase, bow) and the swazzle voice as
  quick phrases ("That's the way to do it!"). Kids-show slapstick only. Audience boos/cheers.
- **Rewards:** as the music hall but smaller (max 6d); Performance 15 XP.
- **Needs:** booth + 4 puppet props, F7, puppet control UI.

## Market auction (wave 2)
Covent Garden Market · any players · Collecting · ~3 min per lot
- **Pitch:** buying, not chance: in-game money only, every bid is a purchase.
- **How it plays:** scheduled auction (F7). Lots are curios and cosmetics from a weekly list
  (Config) plus items players consign (sell your duplicate collection finds). An NPC auctioneer
  calls lots; players bid with a button (+1d / +6d / +1s steps); 10-second "going once, twice"
  timer resets on each bid. Highest bid buys; money goes through the Economy ledger (TASKS T09);
  consigners get the price minus a 10% house cut (a money sink).
- **Rewards:** the item; bidders get 2 Collecting XP per lot they bid on (max 10).
- **Server checks:** bidder must hold the money when the hammer falls (escrow on bid); no
  bidding on your own consignment or between linked characters of one account.
- **Needs:** Economy ledger (T09), item ownership (collection/inventory), F7, auction UI.
- **Rule:** no lucky-dip or mystery lots, ever (no paid chance).

## Flower selling (wave 1)
Flower stall at the market + any busy corner · 1 player · Performance (salesmanship) · ~1 min
per bouquet
- **Pitch:** the flower sellers of Covent Garden market.
- **How it plays:** take a basket at the stall (free). Customers (NPCs at hubs, or players who
  press "Buy a posy") ask for a bouquet: e.g. "violets and a rose, tied with blue". A choice-list
  minigame (F5): pick the right flowers and ribbon in 15 s. Right bouquet = sale; wrong = they walk
  off. Players can buy a real bouquet item for 2d (cosmetic, can be given to another player).
- **Rewards:** 1d per NPC sale (+1d tip for a perfect, fast one); 2d from a player purchase goes
  to the seller. Performance 5 XP per sale. Board: bouquets sold today.
- **Quiet server:** NPC customers at the piazza, the terminus and Trafalgar Square (F6).
- **Needs:** F5 (choice list), NPC customers (T24), bouquet item (shops T15). Config `FLOWERS_*`.

## Tea room (wave 1)
A tea room on the piazza's south side · 2+ (host + guests) · Performance (hosting) · ~3 min
- **How it plays:** one player puts on an apron and becomes the host (job-like but a pastime);
  guests sit at tables and order from a menu card (tea, coffee, lemonade, buns, cakes, sandwiches;
  1–3d each, real purchases). The host gets order tickets and plays a serving minigame: pick the
  items from the counter in the right order (F5 choice list) and carry them to the table before
  the order's timer runs out. NPC guests fill tables on quiet servers.
- **Rewards:** host: the guests' payment (players) or 1d per NPC order, +1d per perfect service,
  Performance 6 XP per order. Guests: the item (consumable cosmetic: holding a teacup, sip emote).
- **Needs:** greybox tea room, menu/order UI, F5, NPC guests (F6), consumables (T15).

## Busking (wave 1)
Pitches: piazza, Trafalgar Square, the terminus concourse, Leicester Square · 1 player · Music or
Performance · open-ended
- **How it plays:** stand on a pitch (marked cobbles, one busker each) and pick an act: fiddle,
  barrel organ, juggling, magic tricks. Music acts use the rhythm lane (F5) on a short loop;
  juggling uses the meter; magic is a 3-step choice list. Passers-by (players walking past within
  20 studs) and NPCs drop coins when you're doing well; players can also tip directly (hand-over
  transfer, T11).
- **Rewards:** NPC/game tips: 1d per 30 s of good performance while 1+ players or NPCs are
  watching (max 6d per 5 min); player tips on top. Music/Performance 3 XP per 30 s.
- **Needs:** pitches (Config), F5, NPC passers-by (T24). 🔒 Instrument sounds.

## Photography studio (wave 2)
West End, a studio on a lot near Leicester Square · 2+ · Performance · ~2 min
- **How it plays:** the photographer (player, or NPC) arranges sitters on a set (3 backdrops,
  chairs, props), picks a pose for each, then "exposes" (everyone holds still for 3 s: moving
  ruins it). The server saves a **portrait card**: names, outfits, pose, backdrop and date as data
  (not a real screenshot); the card is shown in a UI and kept in the sitters' collection book.
- **Rewards:** sitters pay 3d (to the player photographer, or the game if NPC); a portrait card;
  Performance 10 XP. Photographer 5 XP per sitting.
- **Needs:** set + props, pose emotes (T05), portrait card renderer (ViewportFrame of the sitters'
  saved looks), collection entry type "portrait".

## Baking contest (wave 3)
Covent Garden Market hall · 2–6 · Performance · ~4 min
- **How it plays:** a recipe card (3–5 steps: sift, mix, knead, oven timing); each step is a short
  minigame (meter, hold-steady, choice). An NPC judge scores the result; best score wins.
  Run as a scheduled event on market days (F7, EVENTS Market Day).
- **Rewards:** 3d / winner 1s; Performance 25 XP; a rosette cosmetic for the winner.
- **Needs:** F1, F2, F5 (several), F7.
