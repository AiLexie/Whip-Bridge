fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbx_core'
author 'Lexie'
description 'Path shim for whip_bridge: answers @qbx_core/... file imports'
version '0.4.0'
repository 'https://github.com/AiLexie/Whip-Bridge'

-- Only for servers running Qbox scripts that import '@qbx_core/...' in their own fxmanifest.
-- `provide` aliases exports, not file paths, so whip_bridge alone can't answer those imports.
-- This resource declares no scripts and no exports: it is files and nothing else, so whip_bridge
-- stays the one answering exports.qbx_core and the qbx_core:* events.
dependency 'whip_bridge'

files {
    'modules/lib.lua',
    'modules/playerdata.lua',
    'modules/utils.lua',
    'modules/logger.lua',
    'shared/locale.lua',
    'shared/config.lua',
    'shared/convert.lua',
}
