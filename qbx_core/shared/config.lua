BridgeConfig = {}

-- Prefer whip's item list (whip_core/config.lua, Config.Items); these are bridge-only items in qb format (weight in grams).
BridgeConfig.Items = {
    -- sandwich = { label = 'Sandwich', weight = 200, unique = false, useable = true, description = 'A tasty sandwich' },
}

-- Unknown items a script gives are auto-made (guessed label, 0.1 kg) with a warning; false makes those gives fail.
BridgeConfig.AutoCreateItems = true

-- whip has no gangs; they live in character metadata. List the ones SetGang can give.
BridgeConfig.Gangs = {
    none = { label = 'No Gang', grades = { ['0'] = { name = 'Unaffiliated' } } },
    -- ballas = { label = 'Ballas', grades = { ['0'] = { name = 'Recruit' }, ['1'] = { name = 'Boss', isboss = true } } },
}

-- Mirrors qb's tables (players, player_vehicles, player_groups) from whip and applies scripts' writes through whip. An existing real table is left alone.
BridgeConfig.SqlViews = true
-- How often the tables are refreshed from whip (they also refresh right after a script writes).
BridgeConfig.SqlSyncSeconds = 10

-- qb jobs to create in whip on start (qb format). Top grade is level 100; isboss grades can hire and fire.
BridgeConfig.Jobs = {
    -- police = { label = 'LSPD', grades = { ['0'] = { name = 'Cadet' }, ['1'] = { name = 'Officer' }, ['2'] = { name = 'Chief', isboss = true } } },
}

-- Extra QBCore.Shared.Vehicles entries (or prices/brands over whip's catalog), in qb's shape, keyed by model.
BridgeConfig.Vehicles = {
    -- adder = { name = 'Adder', brand = 'Truffade', price = 280000, category = 'super', shop = 'pdm' },
}

-- Returned by QBCore.Shared.Locations and exports.qbx_core:GetLocations().
BridgeConfig.Locations = {}

-- Enables qb-core's own chat commands (/tp, /car, /dv, /givemoney, /setjob, /setgang, /ooc...). /me stays whip's.
BridgeConfig.Commands = true

-- Arms (component 3) drawables that count as bare hands; these depend on your clothing packs.
BridgeConfig.NoGloves = { male = {}, female = {} }

-- Bag (component 5) drawables that count as a duffel bag, for qbx.isWearingDuffelbag.
BridgeConfig.DuffelBags = {}

-- qb permission = whip permission (HasPermission). 'user' is everyone; others are also checked as aces.
BridgeConfig.Permissions = {
    admin = 'admin',
    god = 'admin',
}
