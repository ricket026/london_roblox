# Open Questions

Each open question has a **default** I'll use if you don't answer.

## Decided

| # | Decision (user) | Date |
|---|---|---|
| Era | 1897, late Victorian (replaces the 1770 plan) | 2026-10-24 |
| First landmark | Buckingham Palace | 2026-10-24 |
| Q2 | **Fictional families, based on real places** (e.g. the House of Kew; peers named after real places) | 2026-10-25 |
| Q3 | **One King and one Queen per server at a time**, plus a number of royal family members for others who want to join | 2026-10-25 |
| Q4 | **Every server shares the same concept; changes depend on the current server and who's playing**, unless a system says otherwise | 2026-10-25 |
| Q5 | **Semi-serious.** Roblox chat rules stop players talking across age groups, so RP can't rely on chat; fun gameplay comes first | 2026-10-25 |
| Q6 | **Special furniture, gamepasses, money packs** | 2026-10-25 |
| Q7 | 50 players per server | 2026-10-24 |
| Q8 | **Guns and some violence and death are allowed; no permanent death** | 2026-10-25 |
| Q11 | **No staff, probably ever.** Moderation must be automatic | 2026-10-25 |
| Q13 | **Royals and high-ranking government officials get free vehicles; everyone else pays a hefty price** | 2026-10-25 |
| Q14 | NPC traffic and fares: **yes**, if we can make it work | 2026-10-25 |
| Q16 | City size kept as drafted (~4 min end to end, hubs ~1 min apart) | 2026-10-25 |
| Q17 | Hyde Park: **playable** | 2026-10-25 |
| Q18 | South bank: **playable later**; façades in v1 | 2026-10-25 |
| Q12 | **Git: yes.** Scripts live in `src/` on GitHub (`ricket026/london_roblox`) | 2026-10-27 |
| Slots | **Character save slots with linked progress.** A new slot can share an existing character's progress (job ranks, hobbies, licences, bests): own name and look, progress counts for both | 2026-10-27 |
| Slots | **Account-wide:** money (wallet + bank), Robux purchases, collection book, moderation record | 2026-10-27 |
| Slots | **First slot free; sharing progress into a new slot costs £100** in-game | 2026-10-27 |
| Creator | **Name + look presets** (skin tone, hair, outfit) on the player's own face and body | 2026-10-27 |
| Workflow | The user installs scripts **by copy-paste**; keep the number of scripts per change small and always say which to paste (CLAUDE.md) | 2026-10-27 |

## Still open

| # | Question | Default |
|---|---|---|
| Q1 | **Game name?** Ideas: *Crown & Court*, *Jubilee*, *Gaslight London*, *The Season*, *Fog & Crown* | Crown & Court (working title) |
| Q9 | **Other roleplay settings later** (pirate port, modern city): build the framework reusable from day one? | Yes: setting data in Config/Roles, systems generic |
| Q10 | **Day length?** | 24 real minutes per in-game day |
| Q15 | **Headline event times?** Two weekly slots for time zones | Saturday 14:00 and 20:00 US Eastern |
| Q19 | **How does someone become King or Queen in a server?** | Claim the empty throne (needs ≥ 2 h playtime); the royal family's line of succession gets first refusal (COURT_PARLIAMENT §2) |
| Q20 | **How many royal family members per server?** | 8 |
| Q21 | **Money packs:** OK to let Robux money buy expensive vehicles, or should some things be earn-only? | Packs buy anything except licences and ranks; top vehicles also need a job rank |
| Q22 | **Price of a fresh (unlinked) character in slots 2–3?** Only the £100 link price was set | Free (`Config.SLOT_NEW_PRICE = 0`) |
| Q23 | **How should outfits be made?** 3D outfits built from parts (TASKS T06, discussed), catalog clothing IDs, or Blender meshes later. And are hats a separate choice? | 3D part outfits now (swappable for Blender meshes later); hats come with the outfit |
| Q24 | **Staff tools vs Q11 "no staff":** the M0 `Admin` module has moderator/admin levels and group ranks | Cut down to owner-only tools + automatic moderation |
