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
  2026-10-27  Activity framework + the 4 proving activities from ACTIVITIES §5 (ducks, test your
              strength, mudlarking, chess). Not yet Play-tested. Shared.Chess passes perft
              (start d3, Kiwipete d2, pos3 d3) in a line-for-line port; promotion is queen-only.
  2026-10-27  Characters + save slots, profile schema v2 (user decisions: linked slots; money,
              Robux purchases, collection and moderation record are account-wide; first slot
              free, sharing progress into a new slot costs £100; creator = name + look presets).
              Review fixes: duck stand off the shoreline, glints raycast under Blackfriars
              Bridge, tide sign off the parapet, bigger site boards, persisted pastime pay cap.
              Not yet Play-tested.
  2026-10-27  Second review: role cooldown cleared on character switch, saved looks repaired
              against Config on load, one free rename within Config.NAME_FIX_GRACE of creation,
              skin swatch outline (UIStroke Border mode), character menu retries its first List.
  2026-10-27  Third review (+ scripted checks: block/bracket balance, Module.field references,
              client/server remote contracts, unused locals - all clean). Bell threshold 95 -> 85
              (window was ~35 ms per sweep), strength meter and chess Resign fit phone screens.

MODULES
  ReplicatedStorage.Shared
    Config   every tunable, commented.
    Types    Profile schema v2 (account: money, collection, purchases, outfits, vehicles, rental,
             record, limits; slots { "1".. } -> Slot { char, name, look }; progress { c1.. } ->
             Progress { jobs, hobbies, bests, licences, honours }), LogEntry. Profiles migrates
             v1 -> v2 (old identity becomes slot 1). Every session starts at the menu (active "").
    Looks    look presets (Config.SKIN_TONES / HAIR_STYLES / OUTFITS) validation.
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
    Characters  save slots (Config.MAX_SLOTS): Create (first free), Link (shares a Progress,
             Config.SLOT_LINK_PRICE), Select (switch cooldown), Rename (7-day cooldown), Delete
             (type the full name; Progress kept while another slot links to it). Saves at once.
             CharacterAutoLoads off: spawns with LoadCharacterWithHumanoidDescription from the
             slot's Look (own face/body, modern clothes removed) and respawns after death.
             Characters.onBeforeChange(fn) settles activities before a switch.
             Attributes RPName, CharSlot. Remotes Character.List/Create/Link/Select/Rename/Delete.
    Identity (M1) per-server station role (Shared.Stations: open / claim with seats + playtime /
             appoint / throne), reset on character switch. Attribute Role. Server BillboardGui
             "RPTag" on the Head shows RPName + role. Remotes Identity.Get / ChooseRole;
             pushes State, Seats.
    Activities  framework (claim/release one activity at a time, reward with the hourly pay cap
             Config.ACTIVITY_PAY_PER_HOUR, hobby XP + levels, collection, per-server daily
             boards + profile bests) and children Ducks, Strength, Mudlark, Chess, each built
             in workspace.Activities from Config coordinates (Y by raycast). Remotes:
             Activity.StrengthSwing / ChessMove / ChessResign.
    WorldClock (M1) shared clock from server time (Config.DAY_MINUTES), drives Lighting.ClockTime,
             Lighting attr "Phase", WorldClock.PhaseChanged for lamplighters (M3).
    Economy (Phase 2) the money ledger: every change has a reason (REASONS: faucet / sink / move),
             change/pay/charge (wallet then bank, all or nothing), deposit/withdraw, transfer
             (new accounts: Config.NEW_ACCOUNT_DAILY_TRANSFER a day), recent lines + server totals,
             big changes to AdminLog. Remotes Economy.Ledger / Bank. Use it, not Profiles.addPence.
    Inventory (Phase 2) bag (Config.BAG_SLOTS stacks) + storage (furniture, no limit) in the
             profile; stacks keep the maker of player-made items. Held item = welded part
             "HeldItem" + player attr HeldItem. Remotes Inventory.Get / Use / Hold; pushes State.
    World    ground raycast (skips markers and built folders), part, folder, near, sign.
    Counters (Phase 2) NPC counters from Config.COUNTERS (shop / bank; others via onOpen) built in
             workspace.Counters; prompt pushes Counter.Open. Remote Counter.Buy. Counters.add for
             estate agents and wholesalers (Phase 3-4).
    Exchange (Phase 2) in-person hand-overs of money and/or a stack; checked again on accept.
             Remotes Exchange.Offer / Answer / Cancel; pushes Offered, Closed.
    Lots     (Phase 3) every plot in Workspace.Map.Plots: street side from the roads in
             ServerStorage.MapLayoutData, lot frame attributes (LotOrigin/LotRight/LotIn/LotW/
             LotD), address (LotAddress), per-server claims (LotOwner), template houses in
             workspace.LotTemplates (Config.LOT_TEMPLATES). Lots.choose follows PROPERTY §4.
    Builds   (Phase 3) builds on plots: renders published builds (workspace.Properties), pushes
             drafts to the owner/builders, validates edits with Shared.Kit, PropertyBuild_v1
             store (key u_<userId>_<deedId>, only while the owner's profile is open; never over a
             build that failed to load). Remotes Build.Enter/Exit/Place/Remove/Move/Paint/
             Publish/Starter; pushes State, Changed, Notice, Closed.
    Shops    (Phase 4) property shops (deed.shop: trade, sign, prices, stock, till) and market
             stalls (counter kind "stall", per server): till prompt on counter_till pieces,
             open only while the owner is here and a seller is within SHOP_TILL_RANGE, till
             banks itself (shop_sale / npc_sale), NPC customers at the till (rng = Shops.rng).
             Remotes Shop.Menu/Buy/Open/Restock/Unstock/Price/Settings/BankTill/RentStall/
             LeaveStall; pushes Shop.Notice. Counters kind "supplier" = wholesale (Counter.Wholesale).
    Wardrobe (T06) welds an outfit's 3D pieces onto a character after Characters.spawn
             (folder "Outfit"; massless, no collisions or queries).
    Jobs     (Phase 5) the job framework: duty = holding a job's station role; tasks of steps
             ("goto" auto, "hold" via Job.Hold; need/give for makers) checked by the server;
             pay with the rank bonus (Shared.Ranks) inside Config.JOBS[job].cap per real hour
             (profile.limits.jobPaid); XP in progress.jobs. Postman, Newsboy, Baker, Carpenter.
             Jobs.register(id, start) for new jobs. Pushes Job.Task/Done/Off/Notice.
    Property (Phase 3) deeds in profile.properties: estate agents (counter kind "estate"),
             rent (bank first, grace, lapse keeps the build), buy/sell back, placing on plots,
             10-min linger, keys (enter/decorate/build/sell), lock, At Home, name plate,
             reports. Doors.canOpen hook; plot attributes LotLocked/AtHome/LotName/LotEnter so
             doors still work while the owner is away. Remotes Property.*.
  ReplicatedStorage.Shared (M1 additions)
    Stations every role, its station, claim rule, seats, playtime gate.
    Names    name rules + period name suggestions.
    Collection  collection book items (birds, mudlark finds) + weighted roll for free finds.
    Hobbies  hobby XP -> level (Config.HOBBY_XP_*).
    Chess    full chess rules (server authority, client move hints).
    Meter    timing meter curve shared by client and server.
    Ranks    (Phase 5) job rank maths (XP for rank n, rank for XP, pay multiplier).
    OutfitParts (T06) the 3D pieces of each outfit, sized and placed relative to limbs.
    Items    (Phase 2) every item: name, category, base price, stack size, use text, holdable,
             furniture kit id, player-made.
    Palette  (Phase 3) art/style.md colours by id; builds save the index (append only).
    Kit      (Phase 3) the building kit (art/kit.md is the contract, tests/test_kit.luau checks
             it): pieces, footprints, rules (Kit.check), street-front rule (Kit.publishable),
             greybox geometry (Kit.makePiece), starter houses (Kit.starter). Lot space: origin
             street-left corner, +X along the street, +Z into the plot, half-stud units.
  StarterPlayerScripts.LondonClient  boots the UI modules + staff notices into RBXSystem chat.
    CharacterUI (stub) character menu at session start / "Characters" button: slots, creator,
             share progress, rename, delete. Menu camera from Config.MENU_CAMERA.
    IdentityUI (stub) "Station" role menu bottom-left.
    ClockHUD   (stub) "6:45 pm · Dusk" at the top.
    Activities (stub) reward toasts + Strength meter + Chess board for seated players.
    ShopUI     (stub) counter kinds "playershop", "stall", "supplier" in EconomyUI's panel.
    JobUI      (stub) job tracker top left: step, distance, shift pay, Skip; marker + hold prompt.
    BuildUI    (stub) build mode: orbit camera, catalogue, ghost + reasons, undo/redo; draws
             drafts locally (hides the template here only).
    PropertyUI (stub) "Property" button: your properties, keys, name plate, Build; estate
             agent menus (EconomyUI.onCounter "estate"); "Report this house".
    EconomyUI  (stub) wallet top right, bag (B), Give, counter menus (shop, bank;
             EconomyUI.onCounter(kind, fn) for more), offer popup, toasts. The only module that
             listens to Profile.Wallet (Net.listen keeps one listener per action).
  ReplicatedFirst.LoadingScreen       stub title card until "ProfileLoaded".

STAFF
  Config.STAFF_USER_IDS (owner 3967616473 = level 3). Studio test players: -1 owner, -2 mod.
  Set Config.GROUP_ID once the group exists (ranks in GROUP_RANK_STAFF).

OPEN / LATER
  Console shows 3x "ContentId rbxassetid://203785492 ... Asset type does not match" with all
  London scripts disabled too: engine/baseplate noise, not ours.
  Money deltas (TECH §5.1 note) not separate yet: whole profile is saved under the session lock.
  Kit changes from the 2026-10-27 spec: walls and trim snap to 1 stud (corners meet), a 2-stud
  `wall_half`, chimneys may stand in roofs; recorded in art/kit.md and BUILDING §1.
  Rent keeps falling due while a player is away (Q25); At Home just unlocks (Q26).
  Counters stand where tools/check_sites.py says the ground is clear (no lot, carriageway or
  landmark); it reads parts only, so check terrain slopes and facing in Studio.
  Offline mutes not supported (target must be in the server). Consider Players:BanAsync at publish.
]]
-- 2026-10-26 LondonServer.Doors: tag "Door" + attrs DoorHinge (Vector3), DoorOpenDeg, DoorGroup, DoorLocked;
--   one prompt per group, server tween (Config.DOOR_*). Parliament leaves get these from parliament_manifest.json.
return {}
