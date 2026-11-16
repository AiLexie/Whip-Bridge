fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbx_core'
description 'QBCore / Qbox bridge for whip_core: qb and qbx scripts run on whip'
version '0.3.0'

-- Don't run the real resources with these names alongside it.
provide 'qb-core'
provide 'qb-inventory'
provide 'ox_inventory'
provide 'qb-target'
provide 'ox_target'
provide 'qb-menu'
provide 'qb-input'
provide 'qb-vehiclekeys'
provide 'qbx_vehiclekeys'

dependency 'whip_core'

shared_scripts {
    -- Must stay first: only exports registered after it are answered under the provided names.
    'shared/alias.lua',
    '@whip_core/lib/satellite.lua',
    'shared/config.lua',
    'shared/convert.lua',
    'shared/locale.lua',
}

-- In this order: core makes QBCore and Bridge, start declares everything once the rest is defined.
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core.lua',
    'server/offline.lua',
    'server/inventory.lua',
    'server/vehicles.lua',
    'server/functions.lua',
    'server/commands.lua',
    'server/exports.lua',
    'server/keys.lua',
    'server/sql.lua',
    'server/sql_apply.lua',
    'server/start.lua',
}

client_scripts {
    'client/main.lua',
    'client/inventory.lua',
    'client/target.lua',
    'client/menu.lua',
    'client/keys.lua',
}

files {
    'modules/lib.lua',
    'modules/playerdata.lua',
    'modules/utils.lua',
    'modules/logger.lua',
    'shared/locale.lua',
    'shared/config.lua',
    'shared/convert.lua',
    'html/img/items/*.png',
    'html/img/items/*.webp',
}
