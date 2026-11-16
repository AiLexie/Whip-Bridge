# Whip Bridge

`whip_bridge` for whip_core. QBCore and Qbox scripts run on whip without edits.

The scripts call qb-core, qbx_core, qb-inventory or ox_inventory like normal, and the bridge turns
every call into a whip_core export. whip keeps control of players, money, jobs, items and cars.

## Requirements

- whip_core. The framework this bridges to. It is not part of this repository and is not public,
  so ask for access before you install the bridge.
- oxmysql.

## Install

```
ensure oxmysql
ensure whip_core
ensure whip_bridge
ensure your-qb-scripts
```

Don't run the real qbx_core, qb-core, qb-inventory, ox_inventory, qb-target, ox_target, qb-menu,
qb-input, qb-vehiclekeys or qbx_vehiclekeys next to it. This resource provides all of those names
itself.

## Scripts that import @qbx_core files

Some Qbox scripts list a file path like `'@qbx_core/modules/lib.lua'` in their own fxmanifest.
`provide` aliases exports, not file paths, so `whip_bridge` cannot answer those imports on its own.
You have two ways to handle it.

Copy `compat/qbx_core` into your resources folder and start it before your scripts:

```
ensure whip_bridge
ensure qbx_core
ensure your-qb-scripts
```

That resource is seven forwarding files and nothing else. It declares no scripts and no exports, so
`whip_bridge` stays the one answering `exports.qbx_core` and the `qbx_core:*` events.

Or edit each script's fxmanifest and point the path at `'@whip_bridge/modules/lib.lua'`. Nothing else
in the script changes.

## Docs

[whip_bridge/README.md](whip_bridge/README.md) lists what the bridge covers, how QBCore ideas map
onto whip, which database tables it keeps, and where behaviour differs from real qb.

## License

See [LICENSE](LICENSE). You can use it and change it for free. You can't sell it or publish it
under another name. [NOTICE](NOTICE) covers the projects this bridges to and their licenses.
