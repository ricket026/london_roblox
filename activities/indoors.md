# Clubs, coffee houses & indoors

Map: St James's (gentlemen's clubs) x −505…−24, z −440…−975, with St James's Square
x −420…−282, z −666…−774 · palace interiors in `Workspace.PalaceInteriors` (Ballroom with a
**Piano** model, North/South Saloons, Throne Room) · coffee houses: West End and Fleet Street lots.
No club interiors exist yet: build a greybox **club room** (and a public **coffee house**) from
parts on a St James's Square lot; later replaced in the art pass. Rule (DESIGN §12): coffee, tea
and lemonade only; no gambling at any table.

---

## Chess & draughts (wave 1; chess built 2026-10-27)
`Activities/Chess.luau` + client `Activities/Chess.luau` + `Shared.Chess` · 2 · Games · 5–20 min
- **As built:** 3 outdoor tables by the bandstand; sit to play, full chess rules (server
  authority, perft-checked), 2-minute move clock, standing up resigns, table-top board for
  spectators, pays from 10 plies (win 6d / draw 3d; Games 30/20/15 XP), board "wins today".
- **Follow-ups (in order):**
  1. Verify the table-top board orientation for white in Studio (TASKS T01).
  2. **Draw offer** button (both must agree) and **rematch with colours swapped**.
  3. **Draughts** on the same tables: a toggle when both seats are empty ("Chess / Draughts"),
     English draughts rules in a new `Shared.Draughts` (forced captures, multi-jumps, kings);
     same pay and XP. Test it like chess (a move-count test in `tools/`).
  4. Indoor tables in the club room and coffee house (Config `CHESS_TABLES` already takes a list;
     add an indoor flag for the lighting).
  5. A **watch** button for spectators within 20 studs (opens the same board UI read-only).
  6. A Games-hobby **rating** shown on the tag at the table (e.g. "Club player", "Master" by
     hobby level), and an all-time wins board in the club (F10).
- **Done when** 1–3 are in and a draughts game plays to a win.

## Billiards (wave 2)
Club room · 2 · Games · ~5 min
- **Pitch:** English billiards, the game of the period: three balls (two cue balls and a red).
- **How it plays:** turn-based; aim + power (F5) with spin (top/back/side as a small dial). The
  **server simulates** the shot on the table plane (2D circles, cushions, pockets, friction: a
  small deterministic sim in a Shared module so the client can preview the line) and replays the
  result to both players and spectators. Scoring: pot red 3, pot opponent's ball 2, in-off 2/3,
  cannon 2. First to 30, or most after 8 visits each.
- **Rewards:** 3d / winner 6d; Games 20/30 XP. Board: wins today.
- **Needs:** F1 (2 seats/cues), F2, F5 (aim+power+spin), `Shared.BilliardsSim` (tested in Python
  like chess), table model.

## Debating society (wave 2)
Club room (or the coffee house) · 2 debaters + audience · Performance · ~5 min
- **Pitch:** "This house believes that the motor car will never replace the horse."
- **Chat-light (Q5):** debates must work without typing. Each debater gets a hand of **argument
  cards** (game-written lines tied to the motion, for and against: "Consider the cost of fodder,
  sir!"). Three rounds: each debater plays a card (shown as a speech bubble and read out on the
  hall board), may add a rebuttal card, and players who can chat may also speak freely. The
  audience votes after each round (buttons); the motion carries or falls on the final vote.
- **Motions** come from a game list (Config); a player-written motion is allowed only through the
  text filter (`Shared.Text`, broadcast) and a Chair (rank: Performance level 3+) approves it.
- **Rewards:** debaters 3d / winner 6d, Performance 25 XP; audience 2 XP per vote (max 10).
- **Needs:** card data in a Shared module, F1, F2, F4, vote buttons (shared vote UI from the Rotten
  Row page).

## Waltz & quadrille (wave 1)
Palace Ballroom during balls (EVENTS Royal Ball) + an **Assembly Rooms** practice floor open to
all (greybox room on a West End lot) · pairs / sets of 8 · Performance · ~2 min per dance
- **How it plays:** pick a partner (invite prompt, both accept) or join a set of 8 for the
  quadrille (F1). A rhythm lane (F5) in time with the music; good steps keep the pair's dance
  animation smooth and in step, misses make a stumble. Pairs' scores show on a ballroom board; at
  a ball the best pair is announced.
- **Rewards:** 2d per dance (practice), 4d at a ball; Performance 15 XP; the ball's best pair gets
  a cosmetic dance card / rosette.
- **Needs:** 🔒 dance animations (paired waltz, quadrille figures; the user publishes them, ART §7)
  and 🔒 waltz music; F1, F3 (sets), F5, emotes system (TASKS T05). Ball attendance needs the dress
  code check (PROPERTY_WARDROBE §3: `Formal`).

## Piano (wave 2)
The Ballroom piano (`PalaceInteriors.Ballroom.Piano`) now; house pianos in M6 · 1 · Music ·
open-ended
- **How it plays:** sit at the piano: **free play** (on-screen keys on touch; number/letter row on
  PC; gamepad maps a scale) heard by everyone nearby, or **play a piece** (rhythm lane, F5) from a
  short list of period pieces for a score.
- **Rewards:** a piece: 1–3d by score, Music 10 XP. Free play: Music 1 XP per 30 s while someone
  else is listening (max 10).
- **Needs:** 🔒 piano note samples (Roblox audio library), seat on the piano stool, F5.
