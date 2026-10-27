--[[
DESIGN_NOTES — Crown & Court (London RP, 1897; era was 1770 until 2026-10-24). Keep updated every milestone.
Docs on disk: C:\Users\ericc\Desktop\London (CLAUDE.md, DESIGN, TECH, ROADMAP, ART, OPEN_QUESTIONS).

STATUS
  2026-10-24  M0 Foundations built (awaiting user go-ahead for M1).
  Defaults in use for OPEN_QUESTIONS Q1-Q5 (unanswered): name "Crown & Court"; fictional
  monarch; Crown by group rank + Regent when absent; titles global / laws per-server; casual city
  with serious zones.
  Place is unpublished: Studio uses the in-memory mock store (Config.STUDIO_USE_REAL_STORE=false).
  2026-10-27  Code moved to git + Rojo (github.com/ricket026/london_roblox, src/). Edit the files,
              not the scripts in Studio, or the next Rojo sync overwrites the Studio edits.
              M1 identity started: names, roles + seats, overhead tags, world clock (not yet
              Play-tested).

MODULES
  ReplicatedStorage.Shared
    Config   every tunable, commented.
    Types    Profile (schema v1, TECH §5.1 incl. vehicles/licences, + record.mutedUntil), LogEntry.
    Roles    Roles.ACTIONS table + Roles.can(player, action, target?). M0 input = staff level
             (attribute "StaffLevel", set by the server from group rank / Config lists).
    Net      Remotes/<Domain>Event + <Domain>Fn. Net.handle(domain, action, spec, fn) with
             V.int/num/bool/str/enum/userId/player/optional validators, rate limits, Roles.can.
             Client: Net.send / Net.request / Net.listen. Server: Net.push / Net.pushAll.
    Money    integer pence; Money.format(270) = "£1 2s 6d"; split / fromLsd / isValidAmount.
    Text     sanitize + escapeRich (both sides); filterBroadcast / filterFor (server, fail closed).
  ServerScriptService.LondonServer (boot Script)
    Store    DataStore wrapper; Studio mock (JSON round trip, MOCK_LATENCY).
    Profiles session lock (UpdateAsync, token, stale takeover), migrate + reconcile, autosave,
             BindToClose, addPence, Loaded signal, pushes Profile.Wallet.
    AdminLog in-server ring + AdminLog_v1 "d_<yyyymmdd>" lists.
    Admin    kick / ban (timed or perm, Bans_v1, MessagingService) / mute (TextSource.CanSend).
             Chat: /kick /ban /unban /smute /sunmute /logs. Remotes: Admin.Kick/Ban/Unban/Mute/
             Unmute/Logs.
    Analytics onboarding funnel (Config.ONBOARDING_STEPS; M0 logs step 1 on first join),
             SessionSeconds custom event. Studio: memory only (ANALYTICS_IN_STUDIO=false).
    Debug    Studio only: ServerStorage.LondonDebug bindable (profile, givePence, setStaff,
             rejoin, lockTest, raw, setRaw, admin, net, analytics, setRole, clock).
    Identity (M1) RP name (filtered, Shared.Names rules, 7-day cooldown after the first pick) and
             per-server station role (Shared.Stations: open / claim with seats + playtime /
             appoint / throne). Attributes RPName, Role. Server BillboardGui "RPTag" on the Head.
             Remotes Identity.Get / SetName / ChooseRole; pushes State, Seats.
    WorldClock (M1) shared clock from server time (Config.DAY_MINUTES), drives Lighting.ClockTime,
             Lighting attr "Phase", WorldClock.PhaseChanged for lamplighters (M3).
  ReplicatedStorage.Shared (M1 additions)
    Stations every role, its station, claim rule, seats, playtime gate.
    Names    name rules + period name suggestions.
  StarterPlayerScripts.LondonClient  wallet state + staff notices into RBXSystem chat.
    IdentityUI (stub) name picker on first join, "Station" role menu bottom-left.
    ClockHUD   (stub) "6:45 pm · Dusk" at the top.
  ReplicatedFirst.LoadingScreen       stub title card until "ProfileLoaded".

STAFF
  Config.STAFF_USER_IDS (owner 3967616473 = level 3). Studio test players: -1 owner, -2 mod.
  Set Config.GROUP_ID once the group exists (ranks in GROUP_RANK_STAFF).

OPEN / LATER
  Console shows 3x "ContentId rbxassetid://203785492 ... Asset type does not match" with all
  London scripts disabled too: engine/baseplate noise, not ours.
  Money deltas (TECH §5.1 note) not separate yet: whole profile is saved under the session lock.
  Offline mutes not supported (target must be in the server). Consider Players:BanAsync at publish.
]]
-- 2026-10-26 LondonServer.Doors: tag "Door" + attrs DoorHinge (Vector3), DoorOpenDeg, DoorGroup, DoorLocked;
--   one prompt per group, server tween (Config.DOOR_*). Parliament leaves get these from parliament_manifest.json.
return {}
