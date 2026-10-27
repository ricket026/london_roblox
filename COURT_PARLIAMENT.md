# Roles, Court & Parliament spec

Starting values in `Config.Court` / `Config.Parliament`. Permission checks all go through
`Roles.can` (TECH.md §6).

**Everything in this file is per server (Q4)**: thrones, offices, titles and laws belong to the
server they were won in and end when the holder leaves or the server closes. Only a cosmetic
"highest honour ever held" record is saved to the profile. There are no staff (Q11), so every
seat is filled and removed by game rules. Below, **"Monarch" means the King or the Queen**
(either can act). Every court and Parliament action has a **button** and **quick-phrase**
version, so it works for players who can't chat with each other (DESIGN §9).

## 1. Precedence (who outranks whom)
Used for presiding, forms of address, seating and processions. High to low:
King & Queen → Heir → other Royals → Archbishop (ceremonial) → Prime Minister →
Lord Chamberlain → Dukes → Marquesses → Earls → Viscounts → Barons → Ministers → Knights →
MPs → Household officers → Officers of the Guard → everyone else.
`Roles.precedence(player)` returns a number; ties broken by date of grant.

## 2. Restricted roles and seat limits (per server)

| Role | Seats | How you get it (all within the server) |
|---|---|---|
| **King** | 1 | Claim the empty throne (§2.1) |
| **Queen** | 1 | Claim the empty throne (§2.1). King and Queen rule **jointly** with equal powers; either can act alone |
| Royal family (Prince, Princess, royal Duke/Duchess) | 8 (Q20) | **Join the royal family** from the role menu while seats are free (≥ 1 h playtime), or be invited by the King/Queen. Ordered into a **line of succession** by join time |
| Lord Chamberlain | 1 | Appointed by the King/Queen; else the senior royal family member acts |
| Private Secretary | 1 | Appointed by the King/Queen |
| Equerry / Lady-in-waiting | 4 | Appointed by the Lord Chamberlain or the King/Queen |
| Prime Minister | 1 | The King/Queen invites the leader of the biggest group of MPs; else the senior MP |
| Chancellor, Home Secretary | 1 each | Appointed by the PM; else first MP to claim |
| Speaker | 1 | Elected by MPs at the first sitting; else the longest-serving MP present |
| MP | 12 | Stand in the server's **quick election** (§7.2) or claim a vacant seat between elections |
| Judge | 2 | Appointed by the Home Secretary / Lord Chamberlain; else claimable at ≥ 3 h playtime |
| Magistrate | 2 | Appointed by the Home Secretary; else claimable at ≥ 2 h playtime |
| Superintendent (police) | 1 | Highest-ranked police player present (job rank 5 first) |
| Guard officer | 2 | Highest-ranked guards present; or appointed |
| Peer (Duke … Baron) | caps per server: 2 / 3 / 5 / 6 / 8 | Granted by the King/Queen |
| Knight (Sir / Dame) | cap 15 per server | Granted by the King/Queen |

**Seat rules (no staff)**
- **Claiming:** a vacant claimable seat shows a "Claim" button to eligible players; first to
  press wins. 5-minute cooldown before the same player can claim another seat.
- **Leaving:** a holder who leaves the server, goes AFK for 10 min, or resigns frees the seat.
- **No confidence:** any office holder, including the King or Queen, can be removed by a vote of
  players present (60% yes and at least 6 votes; once per holder per 15 min). The removed player
  can't reclaim that seat for 30 min.
- **Rate limits:** grants and appointments max 1 per minute per granter; a granter's grants are
  undone if they're removed by no confidence within 10 min of granting.

### 2.1 The throne (Q3, Q19 default)
- When the King's or Queen's seat is empty, it's offered **in line of succession order** to the
  royal family members present (each has 20 s to accept), then opens to **any player with ≥ 2 h
  playtime** to claim.
- A new monarch triggers a short **Accession** proclamation; a **Coronation** event can be hosted
  at the cathedral (EVENTS) for a cosmetic crown flourish and a Gazette front page.
- **Abdication:** the King or Queen can abdicate at any time; the seat goes down the line.
- **Saved:** "Reigned as Queen of London, 3 times" style records on the profile (cosmetic).

## 3. Forms of address (auto-applied in tags and announcements)
Monarch: *His/Her Majesty* · Royals: *His/Her Royal Highness* · Duke: *His/Her Grace* ·
other peers: *The Rt Hon. the Earl of X* / *Lord/Lady X* · Knight: *Sir/Dame First* ·
MP: *First Last MP* · Police: *Constable/Sergeant/Inspector Last*.
The player picks pronoun-neutral or gendered forms in settings (His/Her/Their; Lord/Lady;
Sir/Dame). Default: none chosen → the neutral form (*Their Majesty*, *The Rt Hon.*).

## 4. Throne room protocol
States (set by the Lord Chamberlain or the Monarch):
- **Closed** — guards admit only the Household and invited guests.
- **Open** — anyone admitted; normal chat.
- **In session** — the **Court** chat channel is the only one heard inside: the Monarch speaks
  freely; others only when **given the floor**. Two warnings → contempt (LAW §2).

**Audience queue:**
1. A player at the palace door requests an audience (reason ≤ 80 chars, filtered).
2. The Lord Chamberlain sees the queue, accepts/declines, reorders.
3. "Announce": the petitioner's name and title are proclaimed in the room; they walk to the mark.
4. Bow/curtsy prompt (emote); the floor is given to them for up to 3 min (extendable).
5. Monarch may grant an honour, an office, a pardon, or a decree right from the audience UI.

**Presentations at court ("The Season"):** a scheduled event where newly titled players and
debutantes are presented one by one: announced, walk, curtsy/bow, Monarch acknowledges.
Being presented unlocks invitations to balls (cosmetic flag + "Presented at Court" in profile).

## 5. Honours and grants
- Grant menu for the Monarch: titles (peerage ranks, knighthood), offices, the Royal Warrant
  (a shop/business gets a "By Appointment" sign and a 5% NPC-sale bonus), pardons (clear wanted,
  release from prison), and the Royal Household posts.
- Every grant: confirm dialog → logged → proclaimed in this server → Gazette entry.
- Grants last for the session in this server; the profile saves a cosmetic "highest honour".
- **Revocation** needs a reason and is logged. There's no staff to appeal to; abuse is handled by
  no-confidence votes and rate limits (§2).

## 6. Decrees
- The King or Queen issues a decree: title ≤ 60, text ≤ 400, filtered.
- Effects: proclaimed (big banner + bell sound) city-wide, posted on decree boards, front page of
  the next paper. Decrees are **flavour unless they match a lever** that only the Crown controls:
  declare a bank holiday (bonus pay day, once per real day), grant a pardon, summon Parliament,
  dissolve Parliament (forces a General Election), call a ball or a procession.
- Cooldown: 1 decree per 10 min.

## 7. Parliament

### 7.1 Houses
- **Commons:** up to 12 MPs. The Speaker runs sittings.
- **Lords:** all peers present. In v1 the Lords can **delay** a bill once (it returns next
  sitting) but not block it.

### 7.2 Quick election (per server)
- Held when a server has no MPs and ≥ 10 players, every ~60 real minutes, or when the King/Queen
  dissolves Parliament.
- 3-minute nomination window (≥ 1 h playtime; pick a party from a game list: Tory, Liberal,
  Labour, Independent), then a 3-minute vote at polling booths in each district or from the
  menu. One vote per player. Top 12 become MPs for the session.
- Party with most seats → its top-voted MP is invited to be Prime Minister.
- Between elections, empty MP seats can be claimed by eligible players.

### 7.3 Sittings
1. The Speaker opens a sitting (quorum 3 MPs present).
2. Bills are proposed from the **lever list** (§7.4) by the PM or any MP (MP bills need a
   seconder).
3. Debate (Speaker gives the floor, 5 min cap per bill).
4. Division: MPs vote Aye/No; majority of those voting; the Speaker breaks ties.
5. Lords may delay once (vote of peers present).
6. **Royal Assent** from the King or Queen within 3 min; refusing is allowed once per real
   day and is proclaimed. No response → assent given.
7. Passed: the lever changes for this server at once and is proclaimed; the change persists for
   the rest of the session (per-server laws, Q4 default).

### 7.4 Levers

| Lever | Range | Default | Effect |
|---|---|---|---|
| Income tax | 0–15% | 5% | Tax on pay (ECONOMY §6) |
| Purchase duty | 0–20% | 10% | Tax on vehicles and luxuries |
| Speed limit | 8–20 mph | 14 | VEHICLES §7 |
| Police budget | 0–50% bonus | 20% | Police salary bonus, paid from treasury |
| Cab fare per 100 studs | 2–5d | 3d | VEHICLES §8 |
| Lamp wages bonus | 0–100% | 0% | Lamplighter pay, from treasury |
| Motor licence fee | £1–£20 | £5 | |
| Market day | on/off per in-game week day | Saturday | Bonus sales at Covent Garden |
| Curfew in the parks | on/off | off | Parks closed at night; trespass applies |
| Motor cars in Westminster | allowed / banned | allowed | Westminster becomes horse-only |

### 7.5 Anti-abuse
- One bill per lever per sitting; levers can't move by more than half their range per bill.
- All votes logged. MPs AFK for 10 min lose their seat.
- Add a lever **"Firearms in the city"**: allowed with certificate (default) / banned in
  Westminster / banned city-wide (police and guards exempt).
