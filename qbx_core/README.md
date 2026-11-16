# qbx_core for whip_core

Lets QBCore and Qbox scripts run on whip_core. The scripts call qb-core, qbx_core, qb-inventory or
ox_inventory like normal, and every call gets turned into a whip_core export. whip stays in charge of
players, money, jobs, items and cars.

The resource is called `qbx_core` and also `provide`s `qb-core`, `qb-inventory`, `ox_inventory`,
`qb-target`, `ox_target`, `qb-menu`, `qb-input`, `qb-vehiclekeys` and `qbx_vehiclekeys`.

## Install

```
ensure oxmysql
ensure whip_core
ensure qbx_core
ensure your-qb-scripts
```

Don't run the real versions of any of those resources next to it. whip's setup report will flag
`qbx_core` as another framework. You can ignore that line.

## What's covered

Everything public in qb-core (2026-08), qbx_core (2026-10), qb-inventory (2026-09) and ox_inventory
(2026-11), checked against their sources:

- `QBCore.Functions` on both sides, `QBCore.Player`, player methods in both the
  `Player.Functions.X` and `Player:X` styles
- `QBCore.Shared` (items, jobs, gangs, vehicles, weapons, locations and the helper functions)
- `QBCore.Commands` and qb-core's built-in commands. `/me` is left to whip.
- qb-core and qbx_core exports, plus the `@qbx_core/modules/*` files Qbox scripts import
- qb-inventory and ox_inventory exports
- qb-target and ox_target, qb-menu, qb-input, qb-vehiclekeys and qbx_vehiclekeys
- The usual events: player loaded/unloaded, job, gang, duty, money and metadata updates,
  `OnSharedUpdate`, Qbox's `onGroupUpdate` and friends

Tested in game with qb-recyclejob, qbx_recyclejob, qb-scrapyard and qbx_scrapyard.

## How things map

| QBCore / Qbox | whip_core |
|---|---|
| `citizenid` | `tostring(charId)` |
| cash, bank, crypto | `GetPlayerCash`, `GetBalance`, metadata `crypto`. Changed through `PayPlayer` / `ChargePlayer` |
| `PlayerData.job` | the job they're clocked on at, otherwise their first job, otherwise `unemployed` |
| `job.grade.level` | role rank, 0 being the lowest whip role |
| `SetJob` and friends | `HirePlayer`, `SetPlayerRole`, `FirePlayer`, `ClockOn` |
| `AddJob`, `CreateJob` | `EnsureJob`. Grades become roles and the top grade gets level 100 |
| gangs | metadata `qb_gang`. Define them in `shared/config.lua` or with `AddGang` |
| metadata, rep, charinfo phone | `SetPlayerMetadata` |
| offline players | read by charId. Bank and metadata work, and items are queued with `GiveOnLogin` |
| stashes | whip containers keyed `qb:<name>` |
| `trunk<plate>`, `glove<plate>` | that car's boot and glovebox |
| `CreateTemporaryStash` | `CreateContainer` with `persist = false` |
| shops | whip `npc` shops at the shop's first location |
| drops | whip ground items |
| `CreateUseableItem` | `RegisterUseHandler`. The item isn't taken, the script removes it like in qb |
| `SpawnVehicle`, `qbx.spawnVehicle` | `SpawnTempVehicle`, kept until something deletes it |
| `HasPermission` | ace, or whip permissions (see `BridgeConfig.Permissions`) |
| `Notify`, `Progressbar`, `DrawText` | `Notify`, `Progress`, `ShowText` |
| target zones | one whip prompt (`AddAction`) in the middle of the zone, with reach covering it |
| target entities and models | an action on that entity, net id or model |
| target bones on cars | an action on the matching car part (hood, trunk, doors) |
| global peds, players, vehicles, objects | an `aimBox` action |
| qb-menu | a whip `Input` dialog with one choice per entry |
| qb-input | whip `Input`. Answers come back as strings like qb-input sends them |
| vehicle keys | whip's `vehicle_key` item. Street cars get adopted first |

## Adding a script

Drop it in and `ensure` it. You don't edit the script or the bridge. Same as on Qbox, the script's items
and jobs need to exist:

1. Add its items to whip's item list (`Config.Items` in `whip_core/config.lua`), the way you'd add them to
   `ox_inventory/data/items.lua`. Pictures go in `whip_core/html/img/items/<item>.png`. An ox-style
   `client = { event = '...' }` on an item works: the bridge fires that event when it's used.
2. Create its jobs in `/whip`, or list them in `BridgeConfig.Jobs` and the bridge creates them.
3. If anything uses `IsWearingGloves`, fill `BridgeConfig.NoGloves` with your bare-hand arm drawables.

If you miss an item, `BridgeConfig.AutoCreateItems` catches it: the first time a script gives it, the bridge
makes a plain version (name from the key, 0.1 kg) and prints a warning telling you to add it properly.

## Database tables

Plenty of qb scripts query `players`, `player_vehicles` or `player_groups` directly, so the bridge keeps
real tables with those names. They get refilled from whip's data (through the `qbx_v_*` views) on start,
every `BridgeConfig.SqlSyncSeconds` and after every write. `hash` is filled with `qb_joaat(model)`.

Writes work too. Triggers copy each `INSERT`, `UPDATE` or `DELETE` into `qbx_bridge_queue`, the bridge
applies it through whip within a second, then rewrites the row with whatever whip ended up doing.

| A script writes | whip does |
|---|---|
| `players.money` | `PayPlayer` / `ChargePlayer`. Offline players only get bank changes |
| `players.job`, `players.gang` | `HirePlayer`, `SetPlayerRole`, gang metadata |
| `players.metadata`, `charinfo` phone etc. | `SetPlayerMetadata`. Name, birthdate and gender are refused |
| `INSERT INTO player_vehicles` | `CreateOwnedVehicle`. The owner has to be online, otherwise the row is dropped and logged |
| `player_vehicles` plate, garage, state, mods, fuel, owner | `SetVehiclePlate`, `SetVehicleGarage`, `DespawnVehicle`, `RetrieveVehicle`, `SetVehicleAppearance`, fuel, `TransferVehicle` |
| `DELETE FROM player_vehicles` | `DeleteVehicle` |
| `player_groups` (Qbox) | hire, change grade, fire |
| `INSERT` / `DELETE` on `players` | ignored, characters belong to whip |

whip's `bans` table has different columns, so a qb `INSERT INTO bans` will fail. If you already have
real `players` or `player_vehicles` tables from an old qb database, the bridge leaves them alone.

## Differences from real qb

- `OpenShop` can't open a shop UI from code. It tells the player to go to the counter instead.
- Logging in and creating or deleting characters happens on whip's character screen. `Login`,
  `CreatePlayer` and `DeleteCharacter` return false.
- Inventory hooks only fire for changes that go through the bridge, not for whip's own drag and drop.
- A stash registered without coords can be opened by server code, but a client can't ask to open it.
- Cash is an item in whip, so money given to an offline player goes to their bank.
- qb callbacks and events are plain net events like in real qb. whip's SecureEvent doesn't cover them.
- There's no target eye. Prompts show up on their own when you're close, so `IsTargetActive` is always false.
- Box and poly zones become a single prompt in the middle of the zone.
- A script's `canInteract` runs across resources every time whip checks it. Lots of them on global
  types will cost more than under qb-target.
- `closeMenu` can't close a menu that's already open, but picking something after it does nothing.
- Clients can only claim keys for a car within 10 m that's a street car, a temp car or their own.
- `addNoLockVehicles` is stored, but whip's lock rules decide what actually locks.

qb-garages, qb-phone, qb-banking, qb-doorlock and the rest aren't bridged. whip has its own garages,
banking and doors, so only run the qb ones if you take whip's out.
