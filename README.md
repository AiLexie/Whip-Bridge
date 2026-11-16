# Whip Bridge

`whip_bridge` for whip_core. QBCore and Qbox scripts run on whip without edits.

The scripts call qb-core, qbx_core, qb-inventory or ox_inventory like normal, and the bridge turns
every call into a whip_core export. whip keeps control of players, money, jobs, items and cars.

## Requirements

- whip_core
- oxmysql

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

A Qbox script that lists `'@qbx_core/modules/lib.lua'` in its fxmanifest needs that path changed to
`'@whip_bridge/modules/lib.lua'`. `exports.qbx_core` and the `qbx_core:*` events need no change.

## Docs

[whip_bridge/README.md](whip_bridge/README.md) lists what the bridge covers, how QBCore ideas map
onto whip, which database tables it keeps, and where behaviour differs from real qb.

## License

See [LICENSE](LICENSE). You can use it and change it for free. You can't sell it or publish it
under another name.
