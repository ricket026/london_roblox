# Player gathering & retention spec

**The hardest part of a Roblox game is getting players to gather and keep playing** (user,
2026-10-24). This file overrides other specs where they conflict: if a feature spreads players
out or leaves them alone, it gets changed.

## 1. Concentrate players
- **Server size: 50 players** (user decision). Because 50 is a lot to fill, the fill-first
  rule below and the hubs matter even more: never let players spread thin across servers.
- **Fill servers before opening new ones:** busiest non-full server first, ~10% slots reserved
  for friends (LOW_POP §2).
- **Clustered hubs:** the hubs sit within ~1 min walk of each other. End to end the city is
  ~4 min on foot and ~2 min by cab (user-approved size, MAP_LAYOUT §3). Outer districts are
  thin; most space goes to the centre.
- **Three hubs** where everything passes through:
  1. **The Mall & St James's Park** (palace front, bandstand, lake, park games) — the main hub.
  2. **Covent Garden** (market, music hall, tea rooms, fairground on market days).
  3. **The Terminus** (spawn, cab rank, train arrivals).
  Spawns, cab ranks, the omnibus route, job routes and newsboy corners all run through hubs.
- **Ambient crowd:** NPC pedestrians in hubs scale down as players arrive, so a hub never looks
  dead but players always outnumber NPCs once a server has ~10.

## 2. Give people a reason to be in the same place at the same time
- **Clock-time "appointments":** something happens at a hub every ~10 real minutes: train arrival,
  Changing of the Guard, a bandstand concert, a park race, a bridge lift, market auction.
  A countdown on the HUD and the map shows what's next and where.
- **Weekly headline events at fixed real-world times** (two slots to cover time zones, e.g.
  Saturday 14:00 and 20:00 US Eastern): procession, ball, regatta, Motor Run, election night.
  Shown on an in-game calendar board, the group page and Discord.
- **Co-op beats solo:** many activities need 2+ players or pay more with more (conductor + driver,
  bucket chains, tug of war, team sports, trials with juries).

## 3. Help players find each other
- **"What's on" panel:** lists events in **every** server of the game (MessagingService feed)
  with a **Join** button (TeleportService to that server). Big events pull players together
  instead of being split across 10 half-empty servers.
- **Server list** showing: players, Monarch present, current event.
- **Join friends** button and **parties** (2–6 players who teleport and spawn together).
- **Cab to event:** from the "What's on" panel, a free NPC cab ride to an event in this server.

## 4. Reasons to come back tomorrow
- **Daily:** login stipend streak (ECONOMY §4), 3 daily tasks (any jobs/activities), a rotating
  "Today in London" special (double pay for one job, a special activity).
- **Weekly:** headline event, election, weekly goals with a cosmetic reward.
- **Long term:** job ranks, titles, house, vehicles, collections (ACTIVITIES §4), hobby levels.
- **Async social:** **letters** to friends (filtered, delivered to their house; read on next
  join), calling cards left at houses, the newspaper mentioning players by name.
- **Seasons** (~6 weeks): a theme (Jubilee summer, Christmas market, frost fair), limited
  cosmetics earned by playing, a seasonal activity.

## 5. Community outside the game
- Roblox group (optional): announcements and shouts for headline events; no in-game ranks.
- Discord (optional, the user runs it): event calendar, applications for restricted roles.
- In-game **Gazette** and the "What's on" panel reflect the same calendar.

## 6. Launch strategy (don't launch to an empty city)
1. **Closed tests** with a seed group (friends, group members) until a scheduled event fills a server.
2. **Launch weekend** built around a headline event (the Jubilee procession) at a fixed time.
3. Roblox ads/sponsored with the event time; a few small creators invited to the launch event.
4. **Steady updates** (new activity or event every 1–2 weeks) — each update is a reason to return.

## 7. Measure it
`AnalyticsService` custom events + funnels from M0:
- Onboarding funnel (each first-join step), D1 / D7 / D30 retention, session length.
- Average players per server, % of time servers have < 5 players.
- Event attendance and "Join" button use; activity plays per session.
The owner panel shows a daily summary. Every milestone report includes these once live.
