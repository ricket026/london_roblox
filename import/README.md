# Putting the scripts into Studio (no Rojo)

These five files hold every script from `src/`, already named, typed and nested. They're built by
`tools/build_rbxmx.py`; ask for them to be rebuilt whenever the code changes.

| File | Insert into |
|---|---|
| `ReplicatedStorage.rbxmx` | **ReplicatedStorage** (adds `Shared` + `DESIGN_NOTES`) |
| `ServerScriptService.rbxmx` | **ServerScriptService** (adds `LondonServer`) |
| `ServerStorage.rbxmx` | **ServerStorage** (adds `MapGreybox` + `MapLayoutData`) |
| `StarterPlayerScripts.rbxmx` | **StarterPlayer → StarterPlayerScripts** (adds `LondonClient`) |
| `ReplicatedFirst.rbxmx` | **ReplicatedFirst** (adds `LoadingScreen`) |

## Steps

1. **Back up first:** File → Save to File As… → `london_backup.rbxl`.
2. **Download the five files:** open each one on GitHub (this `import/` folder on the
   `m1-identity` branch) and click the **Download raw file** button (↓ at the top right of the file).
3. **Delete the old scripts** in the Explorer (only these seven; leave everything else, including
   the map, palace, Parliament and the `_Backups_...` folders):
   - ReplicatedStorage → `Shared` and `DESIGN_NOTES`
   - ServerScriptService → `LondonServer`
   - ServerStorage → `MapGreybox` and `MapLayoutData`
   - StarterPlayer → StarterPlayerScripts → `LondonClient`
   - ReplicatedFirst → `LoadingScreen`
4. **Insert each file:** right-click the location from the table → **Insert from File…** → pick
   the file. (If something lands in Workspace instead, drag it to the right place.)
5. **Check** the Explorer matches the tree below, then **File → Save**.
6. **Test:** press Play. You should get the character menu. Paste anything red from the Output
   window back to Claude.

```
ReplicatedFirst
  LoadingScreen                 (LocalScript)
ReplicatedStorage
  DESIGN_NOTES                  (ModuleScript)
  Shared                        (Folder)
    Chess, Collection, Config, Hobbies, Looks, Meter, Money, Names, Net, Roles,
    Stations, Text, Types       (ModuleScripts)
ServerScriptService
  LondonServer                  (Script)
    Activities                  (ModuleScript)
      Chess, Ducks, Mudlark, Strength
    Admin, AdminLog, Analytics, Characters, Debug, Doors, Identity, Profiles,
    Store, WorldClock           (ModuleScripts)
ServerStorage
  MapGreybox, MapLayoutData     (ModuleScripts)
StarterPlayer
  StarterPlayerScripts
    LondonClient                (LocalScript)
      Activities                (ModuleScript)
        Chess, Strength
      CharacterUI, ClockHUD, IdentityUI   (ModuleScripts)
```

## Handy test commands

In Studio's command bar while playing (switch it to **Server** first):

- `game.ServerStorage.LondonDebug:Invoke("play", -1)` skips the character menu with a test character
- `game.ServerStorage.LondonDebug:Invoke("givePence", -1, 24000)` gives £100 (to try sharing progress)
- `game.ServerStorage.LondonDebug:Invoke("clock", 2)` low tide for mudlarking; `14.5` for pelicans

(`-1` is the first test player in Clients & Servers mode; in a plain Play session use your own
user id.)
