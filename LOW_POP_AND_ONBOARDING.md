# Quiet servers & onboarding spec

RP games die when a new player joins a server with 3 people and nothing happens. Every system
needs a fallback that works with few players, and new players need to be doing something within
a minute.

## 1. Low-population fallbacks

| System | With players | Fallback when nobody fills the role |
|---|---|---|
| Cab fares | player passengers | NPC fares at ranks and from train arrivals |
| Traffic | player drivers | NPC cabs, vans and the omnibus on main roads |
| Omnibus | player driver | NPC-driven bus (players can still ride) |
| Lamps | lamplighters | NPC lamplighter 10 min after dusk |
| Newspaper | journalists | Auto-edition from decrees, verdicts, bills and event results |
| Newsboy sales | player buyers | NPC buyers on busy corners |
| Shops | player tailors/merchants | NPC shopkeepers (normal prices) |
| Justice | magistrates/judges | Auto-justice after 2 min (LAW §4) |
| Revives | physicians | Respawn at hospital after 90 s |
| Guard | player guards | NPC sentries + NPC Changing of the Guard |
| Court | King/Queen present | Throne offered down the line of succession, then claimable (≥ 2 h playtime); while empty, the palace is open to tours |
| Events | hosts | Scheduled/automatic events still run (EVENTS §2) |

NPCs are simple (walk lanes, idle animations, a few lines of speech), capped by a server budget
that shrinks as player count grows.

## 2. Server matchmaking
- New players are sent to the **busiest server that isn't full** (Roblox default fill), with
  ~10% of slots reserved so friends can follow.
- Group events can use private servers.

## 3. First join (the first 5 minutes)
1. **Arrival:** spawn on a platform at the terminus as the train pulls in (cinematic, skippable).
2. **Name:** pick a first and last name (filtered; suggestions button with period names).
3. **Look:** pick a starter period outfit (3 options built from their avatar colours).
4. **Rules:** a short card (no random attacks, no reckless driving, respect court) → accept.
5. **First job:** choose one of three starter jobs, each with a 60-second guided task:
   - *Newsboy:* collect a bundle, sell 3 papers to NPCs.
   - *Lamplighter:* light 3 lamps (or polish them by day).
   - *Cab passenger → cabbie taster:* ride a cab to Westminster, then try the cab yard.
6. **Pay + goal:** first wages paid; HUD suggests the next goal ("Save £8 for a bicycle").
7. **Tour (optional):** an NPC guide points out the palace, Parliament, Scotland Yard, the market.

Returning players skip straight to their last role at their lodging/house or the terminus.

## 4. Goals HUD
A small "Next steps" list driven by the profile: buy a bicycle → rent a lodging → reach rank 2 →
get a licence → attend an event → be presented at court → buy a carriage → …
Completing a step pays a small bonus once. Players can hide it.

## 5. Menus needed (style decided later, from references)
HUD (wallet, clock, job tracker, wanted/police HUD, goals), role menu, wardrobe, house menu,
vehicle menu (summon, licences, condition), map (districts, cab ranks, events), court UI
(queue, floor control, grants), Parliament UI (bills, divisions, results), courtroom UI, event
host UI, newspaper reader/editor, bank, shop, quick-phrase wheel, vote (no confidence /
vote-kick), owner panel, settings (forms of address, audio,
controls). Every menu must work on touch and gamepad.
