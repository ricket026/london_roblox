# Victorian London RP — Game Design Document

Working title: **Crown & Court** (placeholder, see OPEN_QUESTIONS.md Q1)
Status: pre-production, v0.2 (2026-10-24). The era changed from 1770 to **1897**.
Detailed specs with numbers: `systems/` (start at `systems/README.md`).
Platforms: PC, phone, tablet, console (same targets as CoverFire)

---

## 1. Pitch

A Roblox roleplay game set in **London in 1897**, the Jubilee year. Players take a station in
life, from the Crown and its court down to cabbies, constables and newsboys, and live it:
attending court, earning a living, climbing ranks, enforcing (or breaking) the law, and driving
the city's horse cabs, omnibuses and its first rare motor cars.

The world is historically *flavoured*, not historically exact. It looks and sounds like late
Victorian London, but the monarch, peers and politicians are player-held and fictional (see §12).

## 2. Design pillars

0. **Players together, always.** The hardest part of a Roblox game is getting players to
   gather and keep playing. Compact map, busy hubs, something happening every ~10 minutes, and
   a ton of side activities and minigames. See `systems/PLAYER_GATHERING.md` and
   `systems/ACTIVITIES.md`; these win any conflict.
1. **Station matters.** Rank, title and job visibly change what you can do, where you can go,
   how others address you and what you ride in. Climbing is the long-term goal.
2. **Something to do when nobody's roleplaying.** Every job has a light gameplay loop (drive,
   deliver, light, patrol) so a quiet server is still worth playing, and RP grows on top of it.
3. **Ceremony is content.** Audiences, the Changing of the Guard, balls, trials, Parliament
   sittings and processions are structured events with tools behind them.
4. **Players run the city.** Appointments, laws, taxes, verdicts and decrees come from players.
   The game provides the levers and enforces the results.
5. **Old meets new.** Horses and gaslight share the street with motor cars, bicycles and
   electric light. New technology is rare, expensive and a status symbol.
6. **Semi-serious, fun first.** RP is supported, never required. Roblox chat rules stop players
   talking across age groups, so **everything social must also work without typing**: emotes,
   a quick-phrase wheel, prompts and gameplay actions (§9). If it isn't fun to *play*, it doesn't
   ship.
7. **Runs itself.** There will be no staff. Every role, office, punishment and event works
   automatically, with anti-grief rules built in (§10).
8. **Readable and fair.** No gore; death is never permanent. Works well on a phone.

## 3. Setting

- **Year:** 1897. The royal family and the nobility are **fictional families based on real
  places** (e.g. the House of Kew, the Duke of Richmond-upon-Thames, the Earl of Greenwich).
- **Look:** soot-darkened brick terraces, white stucco in Belgravia, Portland stone and Gothic
  Revival landmarks, cobbles and granite setts, gas lamps, telegraph wires, horse traffic,
  smoke and the famous fog.
- **Technology:** gas street lighting; electric light in the palace, theatres and grand
  houses; telegraph and a few telephones; steam trains and the Underground; safety bicycles;
  the first motor cars (the 1896 law lifted the "red flag" rule and set a 14 mph limit).
- **Tone:** stately up top, grimy at the bottom, gently comic in between. Period drama, not
  grimdark.

## 4. The map: one city, seven districts

One place, streamed, compact game-scale (not 1:1). Connected by streets, cab ranks and an
omnibus route (§7).

| District | Purpose | Key locations |
|---|---|---|
| **Westminster** | Seat of power | **Buckingham Palace** (forecourt, balcony, throne room, ballroom, guard room), The Mall, St James's Park, Houses of Parliament + clock tower, Whitehall, Scotland Yard |
| **Belgravia & Mayfair** | Wealth | Player townhouses with mews stables/garages, gentlemen's club, tailor & dressmaker, motor showroom |
| **The City & Fleet Street** | Money, church, press | Cathedral (coronations, jubilee service), Bank, Royal Exchange, newspaper offices + printing press |
| **West End & Covent Garden** | Trade & entertainment | Market (player stalls), theatre, music hall, tea rooms, photographer's studio, bakery |
| **The Tower & Docks** | Labour & landmark | **Tower Bridge** (opens for ships), Tower of London, wharves, warehouses, river steamers |
| **The Station** | Arrivals | Charing Cross terminus, now inside the West End hub (see `systems/MAP_LAYOUT.md`) |
| **Southwark & the East End** | Poverty & law | Lodging houses, police court, prison, coal yard, stables, motor works / blacksmith |

Interiors are inside the same place (doors move you, no teleport to another server), so a
party never gets split up. Separate places are reserved for later expansions (a country estate,
a seaside town at the end of a motor run) — see TECH.md §2.

## 5. Stations, roles and ranks

| Station | Roles (jobs) | How you get in |
|---|---|---|
| **The Crown** | **One King and one Queen per server**, plus royal family members (princes, princesses, dukes and duchesses of the blood; cap per server) | Per server: the throne is claimed when empty, with the royal family's line of succession first (COURT_PARLIAMENT §2) |
| **The Royal Household** | Lord Chamberlain, Private Secretary, equerries, ladies-in-waiting, butler, footmen, maids | Appointed by the Crown or Lord Chamberlain (staff roles open) |
| **The Guards** | Foot Guards (palace sentries, Changing of the Guard), Household Cavalry (mounted escort) | Open, with drill and promotion by officers |
| **The Peerage** | Duke, Marquess, Earl, Viscount, Baron (titles granted, persistent) | Granted by the Crown |
| **Government** | Prime Minister, Chancellor, Home Secretary, MPs, Speaker, Lords, magistrates | Elected in sittings / appointed |
| **The Law** | Police constable, sergeant, inspector (Metropolitan Police), detective (Scotland Yard) | Open, rank by experience and officers |
| **Professions** | Physician, nurse, banker, merchant, journalist, photographer, tailor/dressmaker, motor engineer | Open, rank by experience |
| **Transport** | Cabbie (hansom), omnibus driver, chauffeur, carter, river steamer pilot | Open; licences per vehicle class |
| **Labour** | Lamplighter, newsboy, telegraph messenger, postman, baker, coalman, dockworker, chimney sweep, firefighter | Open from day one |
| **Underworld** | Pickpocket, burglar, swindler, river smuggler | Open, with police counterplay |

**Rules of station**
- **Every server is its own little London** (Q4). All servers share the same world and systems,
  but who holds the throne, offices, peerages and laws depends on that server and who's playing.
  Your **personal progress** (money, job ranks, licences, houses, vehicles, outfits, collections)
  is saved and follows you everywhere.
- Open roles are always available. Restricted roles have a **seat limit per server** and are
  claimed, appointed or elected **within that server**. No group ranks and no staff needed.
- Titles are shown over the head with the RP name: *"The Rt Hon. the Earl of Kew"*.

## 6. Core systems

### 6.1 Identity
- RP first and last name chosen at first join (filtered), changeable with a cooldown.
- Titles and forms of address applied automatically (*Your Majesty*, *Your Grace*, *My Lord*,
  *Constable*).
- Outfit per role (§6.6).

### 6.2 Economy
- Currency: pounds, shillings, pence (stored as pence; shown as £1 4s 6d). Guineas for luxury
  prices (cars, gowns).
- Income: job loops pay per task; offices and household posts pay a salary per in-game day.
- Spending: rent, outfits, vehicles and their upkeep (feed, fuel, repairs), fares, fines, taxes.
- **The Chancellor** (a player office) sets the tax rate within limits; taxes fill a server
  treasury that pays official salaries, the police budget and event budgets.
- No player-to-player gambling.

### 6.3 Jobs (gameplay loops)
Each job is 1–3 minute repeatable tasks with a pay-out and XP for ranks. First wave:
- **Cabbie:** pick up fares at ranks or when hailed (players or NPC fares), drive them across
  the city, get paid by distance. The core vehicle job.
- **Lamplighter:** at dusk, light a route of gas lamps before nightfall. Makes the city glow.
- **Police constable:** walk a beat (checkpoints), answer the whistle, direct traffic at busy
  junctions, make arrests.
- **Newsboy / Journalist:** journalists write the paper (filtered text) at Fleet Street, the
  press prints it, newsboys sell copies on corners. Royal decrees go on the front page.
- **Omnibus driver:** run the fixed route; players ride for a fare.
- Later: telegraph messenger (timed deliveries), postman, baker, coalman, dockworker, chimney
  sweep, firefighter, motor engineer (repairs), photographer (takes in-game portraits),
  physician (revives the downed), butler/maid in noble houses.

### 6.4 Property, building and shops (revised 2026-10-27: `PROPERTY.md`, `BUILDING.md`, `SHOPS.md`)
- **Rent or buy** homes (lodging, terrace house, townhouse with a **mews**) and businesses (shop,
  market stall, later workshop and warehouse) with in-game money. A property is a **portable
  deed**: it appears on a free plot of its kind in whichever server you join, at your usual address
  when it's free.
- Players **build their house from a period kit** (brick and stucco fronts, sash windows, roofs)
  and **decorate** it, inside the plot and height limits; the street front must stay a proper
  house front. Unused plots show template houses, so the city is never empty.
- Owners lock doors, give keys, hire household staff and shop assistants.
- **Shopkeepers** stock wholesale goods from the docks and markets and goods made by other
  players (bread, outfits, furniture), set prices, and sell to players and NPC customers.

### 6.5 Law & order
- **Crimes:** pickpocketing, burglary, swindling, smuggling, assault, trespass in the palace,
  reckless driving / speeding, cab without a licence, contempt of the Crown. Crimes give a
  temporary "wanted" mark visible to the police.
- **Arrest:** constable blows the whistle (nearby police alerted), handcuffs, escorts or calls
  the police van, jails at the station.
- **Trial:** minor cases at the police court (one magistrate, fast); serious ones as a full
  trial with judge, counsel and jury of players.
- **Sentences:** fine, prison time (real minutes, with a light prison-work loop), licence
  revoked, or banishment from the city for the session. **No executions.**
- **Combat (Q8):** guns and some violence are allowed. Period firearms (service revolvers,
  Guards' and police rifles, criminals' pocket pistols, hunting shotguns) plus melee (truncheons,
  coshes, canes). Guns need a **firearms certificate** for legal carry. At 0 HP you're **downed**;
  if nobody revives you in time, you **die and respawn** at hospital. **No permanent death**: you
  keep your character and progress, but drop some carried cash. No blood or gore.
- **Anti-grief without staff:** safe zones (palace interior, cathedral, Parliament, hospital,
  spawn), spawn protection, killing outside a crime/duel/arrest makes you *wanted* with a
  bounty that grows per kill, repeat random killers lose their weapons for the session, and
  victims get a "Report killer" button that adds evidence for the police. LAW.md §1–2.

### 6.6 Wardrobe
- Each role has a uniform; owned outfits can be worn when the role allows.
- Sources: catalog/marketplace Victorian clothing first (top hats, bowlers, frock coats, bustle
  and leg-of-mutton gowns, police helmets, Guards' bearskins), custom clothing later (ART.md §6).

### 6.7 The Court
- **Throne room protocol:** the Lord Chamberlain runs a queue for audiences; petitioners are
  announced; bow/curtsy prompts; only the Crown and those called may speak in the "Court" channel.
- **Presentations at court:** new players of rank are formally presented (The Season).
- **Appointments & honours:** the Crown grants titles, knighthoods and offices from a menu.
  Grants last for the session in that server. A player's **"highest honour ever held"** is saved
  as a cosmetic record (e.g. "Former Earl of Kew"), but carries no powers elsewhere.
- **Decrees:** proclaimed city-wide, posted on boards and printed in the paper.
- **The balcony:** the Crown can appear on the palace balcony; players in the forecourt cheer.

### 6.8 Parliament
- Sittings are called by the Speaker. Bills come from a list of **real levers**: tax rate,
  speed limit, police budget, cab fares, lamp wages, motor licence fee, market day, bank
  holiday (bonus pay day).
- MPs vote; the Lords can delay; the Crown gives Royal Assent. Passed bills change **that
  server's** settings for the session.

### 6.9 Events
Structured events with a host tool (start, invite, roles, steps):
- **Changing of the Guard** at the palace: drill, band, guard handover. Runs on a schedule.
- **Jubilee / State Procession:** state landau with cavalry escort from the palace to the
  cathedral; crowds line the route.
- **State Opening of Parliament.**
- **Royal Ball** at the palace ballroom: dance emotes, orchestra, dress code check.
- **Motor Run:** a London-to-the-edge-of-town run for motorists (inspired by 1896's
  Emancipation Run); finish line, prizes.
- **Market Day / Bank Holiday Fair.**
- **Fire!** A building catches fire; the horse-drawn steam fire engine and a bucket chain put
  it out before it spreads. Damage is cosmetic and repaired after.
- **Pea-souper:** a thick-fog weather event; visibility drops, police double patrols,
  pickpockets thrive.
- **Tower Bridge lift:** the bridge opens for a passing ship; traffic waits.
- **Trials, Parliament sittings, knighting ceremonies, elections.**

### 6.10 Day/night and weather
A full day is ~24 real minutes (tunable). Night brings the lamplighters, more police and
thicker fog. Rain, snow, and the pea-souper event.

## 7. Vehicles

Vehicles are a headline feature. Old and new share the road.

| Class | Vehicles | Who | Notes |
|---|---|---|---|
| **Horse** | Riding horse | Cavalry, police (mounted), the wealthy | Owned or hired from stables |
| **Cab** | Hansom cab (2 passengers), four-wheeler "growler" (4) | Cabbie job | Fares by distance; hail or use ranks |
| **Bus** | Horse omnibus (~10, top deck open) | Omnibus driver | Fixed route with stops; NPC driver fallback |
| **Private carriage** | Brougham, landau | Peers, rich players | Bought; driven by a coachman player or the owner |
| **State & official** | State landau, royal motor car, ministerial brougham | Royal family, King & Queen, ministers, senior officers | **Free while you hold the role** (Q13), from the Royal Mews or government garage |
| **Trade** | Delivery van (bread, coal, post), dray | Jobs | Used in job loops |
| **Emergency** | Steam fire engine (horse-drawn), police van | Firefighter, police | Respond to events |
| **Cycle** | Safety bicycle, penny-farthing | Anyone | Cheap, fast, the first purchase |
| **Motor car** | Early motor carriage (2-seat), larger tourer (4-seat) | The rich, chauffeurs | A hefty price for everyone without an official role, top speed ~ the 14 mph law (scaled); fuel from the chemist; breakdowns fixed by a motor engineer |
| **River** | Steam launch, river steamer | Pilots, smugglers | Later milestone |
| **Rail** | Train arriving at the terminus | Scenery + arrivals | Spawn point flavour; a rideable train is later |

**Rules**
- Fictional makers only (no real brands).
- **Licences** per class (cab, omnibus, motor) bought or earned; driving without one is a crime.
- Speed limit set by Parliament; police can stop and fine speeders.
- **NPC traffic and NPC fares** (Q14): yes, a headline feature if it can be made to work well.
- **No vehicle killing:** a vehicle that hits a pedestrian knocks them aside harmlessly; repeated
  reckless driving is a crime and a moderation flag. Vehicles are blocked from pedestrian-only
  zones (palace forecourt, market, station platforms) except in events.
- Owned vehicles are stored in your mews/stable and spawn there or at a cab rank.
- Horses need feed and rest (light upkeep); motor cars need fuel and repairs.

## 8. Player journey

- **First 5 minutes:** pick a name, pick a station (Labour/Transport roles open), a short guided
  task (sell five papers / light three lamps / one cab fare), shown around. Earn first wages.
- **First hour:** try two jobs, rent a lodging, buy a bicycle, see the Changing of the Guard.
- **First week:** rank up in a job or the police, earn a cab licence, rent a townhouse, attend a
  ball or a procession.
- **Long term:** a motor car, your rank in every job, a grand townhouse, collections, and taking
  the throne or an office whenever you're in a server with a vacancy.

## 9. Social & communication

- TextChatService channels: **General**, **Court** (throne room, controlled speaking),
  **Proclamations** (Crown/press), **Whisper** (proximity), **Police telegraph**.
- **Chat-light roleplay** (Q5): Roblox doesn't let players chat across age groups, so every
  interaction also works without typing:
  - A **quick-phrase wheel** of game-written period lines shown as speech bubbles ("Good day!",
    "Your Majesty.", "Stop, thief!", "Cab, sir?", "Three cheers for the King!"). These lines are
    game content, not player chat, so everyone sees them.
  - **Etiquette emotes** (bow, curtsy, doff hat, salute, wave, applaud, cheer) and contextual
    prompts (offer a fare, request an audience, challenge to a duel, hand over money).
  - Court, Parliament, trials and events run on **buttons and votes**, with chat as a bonus.
  - Player-written text (letters, newspaper, decrees) is filtered, and private text respects
    Roblox's who-can-message-whom rules.
- Overhead RP name + title. Roblox names visible in the player list.
- Optional proximity voice where Roblox allows.

## 10. Moderation & community

**There is no staff (Q11).** The game moderates itself:
- First-join rules card (no random killing, no reckless driving, respect protocol at court).
- **Automatic penalties:** random killing → wanted + bounty → weapons removed for the session
  after repeats → banished to the East End spawn after more. Reckless driving → licence points
  → vehicle confiscated for the session.
- **Role abuse:** a King/Queen or office holder can be removed by a **vote of no confidence**
  (players present vote; needs 60% and at least 6 votes). Abusive grants are rate-limited.
- **Vote-kick** from the server for a griefer (needs 60% of the server and at least 8 votes; one
  per player per 10 min; the kicked player can't rejoin that server for 30 min). Logged.
- **Roblox's own tools** handle chat moderation and abuse reports.
- **Owner tools** (only your account): ban, unban, grant money, reset a profile, view logs.
- Everything important is logged (grants, kills, arrests, verdicts, purchases, large
  transfers, vote-kicks) for you to review if needed.

## 11. Monetisation (Q6)

- **Special furniture:** premium furniture sets and rooms for your house (Robux only).
- **Gamepasses:** e.g. extra wardrobe slots, premium outfits, vehicle liveries, a private
  carriage summon anywhere, a bigger house tier discount, a radio/gramophone. Final list at M9.
- **Money packs:** Developer Products that add £ to your bank. Saved before granting
  (receipt-safe, TECH.md §5.1).
- **Private servers.**
- Never sold: the throne, offices, titles, licences, job ranks, or guns' combat stats. See Q21
  for whether money packs can buy everything else.

## 12. Content limits (Roblox policy and our own)

- **Fictional royal and noble families based on real places;** no real persons.
- **Violence:** guns and death are allowed (Q8), but no blood, gore, executions or torture.
  The Roblox maturity questionnaire must be answered honestly for realistic guns and death;
  expect a higher age label than a melee-only game.
- **No Jack the Ripper or serial-killer content, no opium dens.**
- **Alcohol:** no pubs serving drink; tea rooms, coffee houses and chop-houses instead. The
  music hall serves tea and lemonade.
- **No gambling** (no betting on races, no card games for money).
- **Poverty and workhouses:** present as setting, never as cruelty or a punishment mechanic.
  Child workers aren't framed as children; jobs are open to any avatar.
- **Romance:** royal marriages are *titles and alliances*, presentations at court are formal
  etiquette, not dating. Check current Roblox maturity rules before shipping anything near this.
- **Religion:** ceremonial roles only; no doctrine.
- **Empire:** no colonial conquest content.

## 13. What this is NOT (v1)

- Not a free-build sandbox: building is from a curated period kit on your own plot only
  (BUILDING.md).
- Not a shooter: guns exist for police, guards, crime and duels, but fighting isn't the main
  loop. Not a racing game either.
- Not 1:1 historically accurate London.
- Not multiple servers sharing one live city.
