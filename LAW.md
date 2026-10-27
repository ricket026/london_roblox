# Law & order spec

Starting values in `Config.Law`. Goal: crime is a fun counter-role, police have real work, and
nobody can grief others with the arrest tools.

## 1. Health, weapons, downed and death (Q8: guns and death allowed, never permanent)
- Characters have 100 HP. Vehicles and falls into the river never kill (falls respawn you at the
  nearest steps).
- **Weapons** (server-validated hits, no blood):

| Weapon | Damage | Notes | Who / how |
|---|---|---|---|
| Fists / cane / truncheon / cosh | 5 / 10 / 20 / 25 | Melee | Anyone / police / underworld |
| Pocket pistol | 25 | 5 rounds, short range | Gunsmith (certificate) or the fence (illegal) |
| Service revolver | 34 | 6 rounds, slow reload | Police sergeant+, guard officers, certificate holders |
| Rifle | 50 | 5 rounds, slow, long range | Guards on duty, police armed response (Inspector call-out) |
| Shotgun | 60 close, falls off | 2 rounds | Gunsmith (certificate); Hyde Park clay shooting activity |

- **Firearms certificate:** £5 at the post office, needs ≥ 2 h playtime and no gun crime this
  session. Carrying without one is a crime. Parliament can ban firearms (COURT_PARLIAMENT §7.5).
- At 0 HP → **downed** (lies down, quick-phrases only, can't move or act) for 60 s. Revive by a
  physician/nurse (hold 3 s) or any player with smelling salts (hold 6 s, 50% HP).
- If nobody revives you, or you're shot again while downed (3 more hits), you **die**: respawn
  at the nearest hospital after 10 s. **Death costs:** 5s hospital fee and **10% of carried
  cash** (max £5) dropped where you fell (anyone can pick it up for 60 s). Nothing else is lost:
  no permanent death, no lost items, vehicles or ranks.
- **Spawn protection:** 15 s of no damage after respawning (ends early if you draw a weapon).
- **Safe zones** (no damage, weapons put away): palace interiors, cathedral, Parliament,
  hospitals, the terminus concourse, rented-house interiors unless the owner allows it.
- **Duels:** both players accept a challenge (pistols or swords at dawn in Hyde Park is a nice
  touch); fight to downed; no crime; no betting.

### 1.1 Random killing without staff
- Killing someone outside a duel, a lawful arrest, a self-defence window (they hit you first in
  the last 20 s) or a crime they were committing = **Murder**: wanted 15 min + a **bounty**
  (£2, doubling with each further kill, cap £32) payable to any police officer who arrests or
  downs the killer.
- **3 murders in 20 min:** weapons removed for the session and a "Dangerous" marker visible to
  everyone. **5:** sent to the East End spawn with no weapons for the session; repeats across
  sessions trigger an automatic 24 h weapons ban saved to the profile.
- Victims get a "Report killer" button (adds evidence; the killer's name appears on wanted
  posters in the police HUD).

## 2. Crimes

| Crime | Detected how | Class | Wanted (real min) | Default sentence |
|---|---|---|---|---|
| Pickpocketing | victim notices (delayed 5–20 s) or a witness within 30 studs | Summary | 5 | Fine 10s or 3 min prison |
| Assault | damage to a non-consenting player outside a duel | Summary | 5 | Fine £1 or 4 min |
| Assaulting police | damage to on-duty police | Indictable | 10 | 8 min |
| Murder | kill outside the allowed cases (§1.1) | Indictable | 15 + bounty | 12 min, weapons confiscated for the session |
| Armed robbery | gun drawn on a victim + money taken ("Your money or your life!" prompt) | Indictable | 10 | 8 min |
| Carrying without a certificate | police search / gun drawn in sight of police | Summary | 5 | Fine £2, gun confiscated |
| Firing in the street | gunshot with no target hit, outside ranges | Summary | 3 | Fine 10s |
| Burglary | lock picked or valuables taken from a rented house | Indictable | 10 | 8 min + items returned |
| Swindling | player report upheld by police/magistrate | Summary | 5 | Fine = amount ×2 |
| Reckless driving | 3 vehicle strikes in 10 min (VEHICLES §7) | Summary | 5 | Fine 10s, licence points |
| Speeding | police speed trap | Summary | 3 | Fine 5s per mph over |
| Driving unlicensed | police check | Summary | 3 | Fine £1, vehicle impounded |
| Bilking (not paying a fare) | driver report | Summary | 3 | Fine = fare ×3 |
| Trespass | entering restricted palace/Parliament areas | Summary | 3 | Removed + fine 5s |
| Contempt of the Crown | speaking out of turn when warned in court (2 warnings) | Summary | 3 | Removed from court |
| Resisting arrest | leaving while cuffed / escaping the van | Indictable | 10 | +4 min |
| Smuggling (later) | contraband found at customs | Indictable | 10 | 8 min + goods seized |

- **Wanted mark:** visible to police only (a small icon over the head + a list on their HUD).
  Expires after the time above if not arrested. Repeat crimes stack time (cap 20 min).
- Police may only cuff players who are **wanted**, **downed by them in a lawful arrest**, or
  witnessed committing a crime in the last 30 s. This rule is enforced by the server.

## 3. Crime mechanics
- **Pickpocket:** stand behind the target within 4 studs, hold action 2 s (cancelled if the target
  turns to face you). Success 60% (+5% per rank). Takes 5% of wallet (max £2). Bank money is safe.
  Fail: the victim is alerted at once.
- **Burglary:** at a locked rented house, lock-pick minigame (3 pins, ~10 s). Inside, up to 3
  valuables (props) can be carried to a **fence** NPC in the East End for 10s–£2 each. The owner
  gets an alert; stolen items are restored to the house after the burglar is arrested or after
  30 min.
- **Swindling:** pure RP (fake sales, scams) handled by reports.

## 4. Arrest flow
1. **Whistle** (police tool): alerts police within 200 studs and marks the position on their HUD.
2. **"Stop, in the name of the law!"** prompt on a target: the target can **surrender** (hands up,
   cuff instantly, sentence −25%) or run.
3. **Cuff:** hold 1.5 s within 6 studs (surrendered, downed or slowed target).
4. **Escort:** the cuffed player follows the officer (drag). Can be put in the police van.
5. **Booking** at a police station desk: the server lists the charges from the crime log.
   - Summary charges only → the prisoner chooses: **pay the fine** now, or **go before the
     magistrate**.
   - Any indictable charge → held for **trial**.
6. **Auto-justice:** if no magistrate/judge is on duty within 2 min of booking, the server
   applies the default sentence from §2. Quiet servers still work.

## 5. Courts
**Police court** (summary): one magistrate (player), the officer states the charge, the accused
answers, magistrate picks guilty/not guilty and a sentence within the allowed range. ~3 min.

**Full trial** (indictable), at the Old Bailey interior:
1. Judge opens the session (court UI). Roles: judge, prosecutor (police inspector or player
   barrister), defence (player barrister or self), up to 6 jurors (volunteers from the gallery,
   ≥ 2 h playtime, not police, not friends-listed with the accused), witnesses.
2. Steps: charges read → prosecution → defence → witnesses → closing → jury vote (secret,
   majority; ties = not guilty) → judge sentences within range.
3. Speaking control: the judge grants the floor (same tool as the throne room).
4. Time limit 15 min; then the judge must call the verdict. If the judge leaves, auto-justice.

## 6. Sentences
- **Fine:** taken from wallet then bank; can create debt up to £5.
- **Prison:** real minutes in a cell block. Optional **prison work** loop (sort mail sacks) cuts
  time by 10 s per task. Logging out keeps the remaining time for next join.
- **Licence revoked** (cab/omnibus/motor) for 24 h real.
- **Banishment:** removed from the city districts for the session (respawn only in the East End,
  can't enter Westminster). Used by judges for repeat indictable crimes.
- **No executions, no corporal punishment.**
- Sentence ranges: magistrate up to £5 / 6 min; judge up to £20 / 15 min / banishment.

## 7. Detectives (Scotland Yard, Inspector rank+)
- Burglaries and swindles open a **case** with clues (footprints decal near the scene, the stolen
  item's last known location, witness statements written by players).
- Closing a case with an arrest pays a 10s bonus. Kept light in v1.

## 8. Anti-abuse
- Every cuff, booking, verdict and sentence is logged with positions and chat around it.
- **False arrest:** the server only allows cuffing legal targets (§2), so false arrests are
  mostly impossible. An arrested player can still file a complaint; an Inspector (or the
  magistrate) reviews it. 3 upheld complaints → the officer is suspended from the police for the
  session.
- Police can't arrest each other while both on duty; a no-confidence vote removes a bad
  Superintendent (COURT_PARLIAMENT §2).
- Judges/magistrates can't preside over their own friends or their own arrests.
- Prisoners and the downed can't be damaged.
