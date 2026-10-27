# The fairground (Covent Garden piazza)

The market building fills the middle of the piazza (x −190…−90, z −1340…−1460), leaving four
strips: **north** z −1296…−1340 (44 studs deep, between St Paul's and the market), **south**
z −1460…−1500 (40), **west** x −222…−190 (32), **east** x −90…−58 (32). Plan every ride to fit a
strip (a carousel is ~22 studs across) and keep a 10-stud walkway clear on every side.

**Sideshows** (test your strength, coconut shy, hoop-la) stand all the time. **Rides** (carousel,
swing boats, helter-skelter) set up on **market days and bank holidays** (EVENTS Market Day, Config
`FAIR_DAYS`) so the fair is an occasion; until the Market Day lever exists (TASKS T50), they stand
every in-game Saturday. All games are **free to play** and won by skill (no paid chance, framework
rules); prizes are cosmetic.

---

## Test your strength (wave 1, built 2026-10-27)
`Activities/Strength.luau` + client `Activities/Strength.luau` · 1 at a time · Sport · ~15 s
- **As built:** north strip at (−140, −1318). 3 swings on a timing meter (`Shared.Meter`); the puck
  flies up the 22-stud pole for everyone; score ≥ 85 rings the bell (~90–125 ms window per sweep).
  2d per bell, Sport 4 XP + 1 per 10 points of the best swing, board "best swing today".
  One swinger at a time; 25 s timeout; must stay within 14 studs.
- **Follow-ups:**
  - 🔒 a bell sound (`Config.STRENGTH_BELL_SOUND`, user picks from the audio library).
  - A **queue**: others waiting press the prompt and are told their place ("You're next"),
    instead of "Someone's swinging" (F1 with max 1).
  - Crowd moment: when the bell rings, nearby players see a short cheer bubble; 3 bells in a row
    gives a cosmetic "Strongman" ribbon for the day.
  - Move the meter UI into the shared Kit (F5) when the Kit exists.

## Coconut shy (wave 1)
West strip · 1 player at a time (2 stalls side by side) · Sport · ~30 s
- **How it plays:** 5 soft balls per go; 5 coconuts on posts 15 studs away. Aim + power (F5); the
  server flies the ball (F9) and decides hits from position (no hidden "glued coconut" trickery,
  it's skill only). A clean hit knocks the coconut off; glancing hits wobble it.
- **Rewards:** 1d per coconut, a coconut (cosmetic held item) for 3+; Sport 6 XP. Board: most
  coconuts in a go today.
- **Needs:** F5 (aim+power), F9, ball/coconut props. Config `COCONUT_*`.

## Hoop-la (wave 2)
East strip · 1–2 at a time · Sport · ~30 s
- **How it plays:** 5 rings to toss over prize blocks at 3 distances (F5 aim+power, F9). Ring over
  a block = points by distance; far blocks are worth more.
- **Rewards:** 1–3d by score; a small cosmetic prize for a perfect 5; Sport 6 XP.
- **Needs:** as the coconut shy.

## Carousel & swing boats (wave 1, on fair days)
Carousel in the north strip (east end), swing boats in the south strip · any players · none (a
social ride; tiny Outdoors XP) · ~60 s ride
- **Carousel:** 12 horses on poles (F8 ride around a pivot, horses bob up and down), steam-organ
  music. Board → 60 s ride → alight. Riders face outwards so friends can screenshot each other.
- **Swing boats:** 3 paired boats; 2 riders each pull in turn (press on the swing, F5 meter) to
  swing higher together (better with others). Height is shown; best pair height today on a board.
- **Rewards:** Outdoors 2 XP per ride (max 10 per fair day), no pay (it's a ride).
- **Needs:** F8 (rides), F5 for the swing boats, 🔒 steam-organ music.

## Helter-skelter (wave 2, on fair days)
South strip (west end) · any players · Sport · ~20 s
- **How it plays:** climb the tower stairs, sit on a mat, slide down the spiral (F8 path ride);
  a lean-in-the-turns meter (F5) gives a faster time. Times on a board.
- **Rewards:** 1d per slide (max 6 per fair day), Sport 2 XP. Board: fastest slide today ("min").
- **Needs:** tower model (greybox spiral), F8, F5.

## Hot-air balloon ride (wave 2)
Launch field in **Green Park** (x −485…−295, z 640…−60; the piazza is too small) · up to 6 ·
Outdoors · ~3 min
- **How it plays:** a scheduled ascent every ~10 minutes (F7). Riders board the basket; it rises
  to ~250 studs and drifts a fixed loop over the palace, the Mall, Parliament and the river so
  riders see the whole map, then lands. A "spotting" game while aloft: name 5 landmarks as the
  guide calls them (tap the right one on screen) for a collection stamp.
- **Rewards:** Outdoors 10 XP, a "Balloon Ascent" collection stamp, +1d per landmark spotted.
- **Needs:** F7, F8 (balloon on a path; streaming must keep the riders' surroundings loaded —
  check `StreamingEnabled` radius), landmark list from `map_layout_v2.json`.
