-- Our writes set @qbx_sync so the triggers skip them.
-- A real table with the same name that we didn't create (an old qb database) is left alone and logged.
local B = Bridge
local SQL = {}
B.sql = SQL
local MARK = 'qbx_core bridge'

SQL.joaat = [[
CREATE OR REPLACE FUNCTION qb_joaat(s VARCHAR(255)) RETURNS BIGINT DETERMINISTIC
BEGIN
    DECLARE h BIGINT UNSIGNED DEFAULT 0;
    DECLARE i INT DEFAULT 1;
    SET s = LOWER(s);
    WHILE i <= CHAR_LENGTH(s) DO
        SET h = (h + ASCII(SUBSTRING(s, i, 1))) & 4294967295;
        SET h = (h + ((h << 10) & 4294967295)) & 4294967295;
        SET h = h ^ (h >> 6);
        SET i = i + 1;
    END WHILE;
    SET h = (h + ((h << 3) & 4294967295)) & 4294967295;
    SET h = h ^ (h >> 11);
    SET h = (h + ((h << 15) & 4294967295)) & 4294967295;
    RETURN IF(h >= 2147483648, CAST(h AS SIGNED) - 4294967296, CAST(h AS SIGNED));
END]]

-- A JSON true/false from a condition (a bare 0/1 would read as truthy in Lua).
local function jbool(cond) return ("JSON_EXTRACT(IF(%s, 'true', 'false'), '$')"):format(cond) end
local GRADE = '(SELECT COUNT(*) FROM job_roles r2 WHERE r2.jobId = r.jobId AND r2.level < r.level)'
local BANK = [[(SELECT ba.%s FROM bank_accounts ba WHERE ba.ownerCharId = c.charId AND ba.type = 'personal'
    AND ba.closedAt IS NULL ORDER BY ba.isDefault DESC, ba.accountId LIMIT 1)]]

SQL.views = {
    qbx_v_player_vehicles = [[
CREATE OR REPLACE SQL SECURITY INVOKER VIEW qbx_v_player_vehicles AS
SELECT u.license AS license, CAST(v.ownerCharId AS CHAR) AS citizenid, v.model AS vehicle,
    CAST(qb_joaat(v.model) AS CHAR) AS hash, COALESCE(v.properties, '{}') AS mods, v.plate AS plate,
    v.garage AS garage, CAST(COALESCE(JSON_VALUE(v.vehStats, '$.fuel'), 100) AS DECIMAL(10,2)) AS fuel,
    CAST(COALESCE(JSON_VALUE(v.vehStats, '$.engine'), 1000) AS DECIMAL(10,2)) AS engine,
    CAST(COALESCE(JSON_VALUE(v.vehStats, '$.body'), 1000) AS DECIMAL(10,2)) AS body,
    CASE v.state WHEN 'out' THEN 0 WHEN 'garaged' THEN 1 ELSE 2 END AS state,
    v.vehicleId AS whip_vehicle_id
FROM vehicles v
LEFT JOIN characters c ON c.charId = v.ownerCharId
LEFT JOIN users u ON u.userId = c.userId
WHERE v.ownerCharId IS NOT NULL]],

    qbx_v_players = ([[
CREATE OR REPLACE SQL SECURITY INVOKER VIEW qbx_v_players AS
SELECT c.charId AS id, CAST(c.charId AS CHAR) AS citizenid, 1 AS cid, c.userId AS userId, u.license AS license,
    u.name AS name,
    JSON_OBJECT(
        'cash', COALESCE((SELECT SUM(ci.amount) FROM character_inventory ci WHERE ci.charId = c.charId AND ci.item = 'cash'), 0),
        'bank', COALESCE(%s, 0),
        'crypto', CAST(COALESCE(JSON_VALUE(c.metadata, '$.crypto'), 0) AS DECIMAL(20,2))
    ) AS money,
    JSON_OBJECT(
        'firstname', c.firstName, 'lastname', c.lastName, 'birthdate', DATE_FORMAT(c.dateOfBirth, '%%Y-%%m-%%d'),
        'gender', IF(c.gender = 'female', 1, 0),
        'nationality', COALESCE(JSON_VALUE(c.metadata, '$.nationality'), ''),
        'phone', COALESCE((SELECT p.phoneNumber FROM phone_numbers p WHERE p.charId = c.charId AND p.retiredAt IS NULL
            ORDER BY p.createdAt LIMIT 1), ''),
        'account', COALESCE(%s, '')
    ) AS charinfo,
    COALESCE((
        SELECT JSON_OBJECT('name', j.`key`, 'label', j.name, 'payment', 0, 'type', 'none', 'onduty', %s,
            'isboss', %s, 'grade', JSON_OBJECT('name', r.name, 'level', %s))
        FROM job_employees je JOIN jobs j ON j.jobId = je.jobId JOIN job_roles r ON r.roleId = je.roleId
        WHERE je.charId = c.charId ORDER BY je.jobId LIMIT 1
    ), JSON_OBJECT('name', 'unemployed', 'label', 'Civilian', 'payment', 0, 'type', 'none', 'onduty', %s,
        'isboss', %s, 'grade', JSON_OBJECT('name', 'Freelancer', 'level', 0))) AS job,
    COALESCE(JSON_QUERY(c.metadata, '$.qb_gang'), JSON_OBJECT('name', 'none', 'label', 'No Gang', 'isboss', %s,
        'grade', JSON_OBJECT('name', 'none', 'level', 0))) AS gang,
    JSON_OBJECT('x', c.x, 'y', c.y, 'z', c.z, 'w', c.heading) AS position,
    COALESCE(c.metadata, '{}') AS metadata,
    COALESCE((SELECT JSON_ARRAYAGG(JSON_OBJECT('name', ci.item, 'amount', ci.amount, 'slot', ci.slot, 'type', 'item',
            'info', COALESCE(JSON_QUERY(ci.metadata, '$'), JSON_OBJECT())))
        FROM character_inventory ci WHERE ci.charId = c.charId AND ci.container = 'player'), '[]') AS inventory,
    (SELECT p.phoneNumber FROM phone_numbers p WHERE p.charId = c.charId AND p.retiredAt IS NULL
        ORDER BY p.createdAt LIMIT 1) AS phone_number,
    c.lastPlayed AS last_updated, c.lastPlayed AS last_logged_out
FROM characters c
LEFT JOIN users u ON u.userId = c.userId
WHERE c.deleted IS NULL]]):format(BANK:format('balance'), BANK:format('accountNumber'),
        jbool('FALSE'), jbool('r.level >= 100'), GRADE, jbool('FALSE'), jbool('FALSE'), jbool('FALSE')),

    qbx_v_player_groups = ([[
CREATE OR REPLACE SQL SECURITY INVOKER VIEW qbx_v_player_groups AS
SELECT CAST(je.charId AS CHAR) AS citizenid, j.`key` AS `group`, 'job' AS `type`, %s AS grade
FROM job_employees je JOIN jobs j ON j.jobId = je.jobId JOIN job_roles r ON r.roleId = je.roleId
UNION ALL
SELECT CAST(c.charId AS CHAR), JSON_VALUE(c.metadata, '$.qb_gang.name'), 'gang',
    CAST(COALESCE(JSON_VALUE(c.metadata, '$.qb_gang.grade.level'), 0) AS UNSIGNED)
FROM characters c
WHERE c.deleted IS NULL AND JSON_VALUE(c.metadata, '$.qb_gang.name') IS NOT NULL]]):format(GRADE),
}

SQL.tables = {
    players = ([[
CREATE TABLE IF NOT EXISTS players (
    id INT NOT NULL AUTO_INCREMENT,
    citizenid VARCHAR(50) NOT NULL,
    cid INT DEFAULT NULL,
    userId INT DEFAULT NULL,
    license VARCHAR(255) DEFAULT NULL,
    name VARCHAR(255) DEFAULT NULL,
    money LONGTEXT DEFAULT NULL,
    charinfo LONGTEXT DEFAULT NULL,
    job LONGTEXT DEFAULT NULL,
    gang LONGTEXT DEFAULT NULL,
    position LONGTEXT DEFAULT NULL,
    metadata LONGTEXT DEFAULT NULL,
    inventory LONGTEXT DEFAULT NULL,
    phone_number VARCHAR(20) DEFAULT NULL,
    last_updated TIMESTAMP NULL DEFAULT NULL,
    last_logged_out TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY citizenid (citizenid),
    KEY license (license)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='%s']]):format(MARK),

    player_vehicles = ([[
CREATE TABLE IF NOT EXISTS player_vehicles (
    id INT NOT NULL AUTO_INCREMENT,
    license VARCHAR(50) DEFAULT NULL,
    citizenid VARCHAR(50) DEFAULT NULL,
    vehicle VARCHAR(50) DEFAULT NULL,
    hash VARCHAR(50) DEFAULT NULL,
    mods LONGTEXT DEFAULT NULL,
    plate VARCHAR(15) NOT NULL DEFAULT '',
    fakeplate VARCHAR(50) DEFAULT NULL,
    garage VARCHAR(50) DEFAULT NULL,
    fuel DECIMAL(10,2) DEFAULT 100,
    engine DECIMAL(10,2) DEFAULT 1000,
    body DECIMAL(10,2) DEFAULT 1000,
    state INT DEFAULT 1,
    depotprice INT NOT NULL DEFAULT 0,
    drivingdistance INT DEFAULT NULL,
    status TEXT DEFAULT NULL,
    balance INT NOT NULL DEFAULT 0,
    paymentamount INT NOT NULL DEFAULT 0,
    paymentsleft INT NOT NULL DEFAULT 0,
    financetime INT NOT NULL DEFAULT 0,
    whip_vehicle_id INT DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY whip_vehicle_id (whip_vehicle_id),
    KEY plate (plate),
    KEY citizenid (citizenid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='%s']]):format(MARK),

    player_groups = ([[
CREATE TABLE IF NOT EXISTS player_groups (
    citizenid VARCHAR(50) NOT NULL,
    `group` VARCHAR(50) NOT NULL,
    `type` VARCHAR(50) NOT NULL,
    grade TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (citizenid, `type`, `group`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='%s']]):format(MARK),
}

SQL.queue = [[
CREATE TABLE IF NOT EXISTS qbx_bridge_queue (
    id BIGINT NOT NULL AUTO_INCREMENT,
    tbl VARCHAR(32) NOT NULL,
    op VARCHAR(8) NOT NULL,
    old_row LONGTEXT DEFAULT NULL,
    new_row LONGTEXT DEFAULT NULL,
    created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

SQL.columns = {
    players = { 'id', 'citizenid', 'money', 'charinfo', 'job', 'gang', 'metadata', 'position' },
    player_vehicles = { 'id', 'citizenid', 'vehicle', 'plate', 'garage', 'state', 'mods', 'fuel', 'whip_vehicle_id' },
    player_groups = { 'citizenid', 'group', 'type', 'grade' },
}

local function rowJson(prefix, cols)
    local parts = {}
    for _, c in ipairs(cols) do parts[#parts + 1] = ("'%s', %s.`%s`"):format(c, prefix, c) end
    return 'JSON_OBJECT(' .. table.concat(parts, ', ') .. ')'
end

function SQL.triggers(tbl)
    local cols = SQL.columns[tbl]
    local out = {}
    for _, op in ipairs({ 'INSERT', 'UPDATE', 'DELETE' }) do
        local old = op == 'INSERT' and 'NULL' or rowJson('OLD', cols)
        local new = op == 'DELETE' and 'NULL' or rowJson('NEW', cols)
        local name = ('qbx_%s_%s'):format(tbl, op:lower())
        out[#out + 1] = ('DROP TRIGGER IF EXISTS %s'):format(name)
        out[#out + 1] = ([[
CREATE TRIGGER %s AFTER %s ON %s FOR EACH ROW
BEGIN
    IF @qbx_sync IS NULL THEN
        INSERT INTO qbx_bridge_queue (tbl, op, old_row, new_row) VALUES ('%s', '%s', %s, %s);
    END IF;
END]]):format(name, op, tbl, tbl, op, old, new)
    end
    return out
end

local PLAYER_COLS = 'id, citizenid, cid, userId, license, name, money, charinfo, job, gang, position, metadata, inventory, phone_number, last_updated, last_logged_out'
local VEH_COLS = 'license, citizenid, vehicle, hash, mods, plate, garage, fuel, engine, body, state, whip_vehicle_id'

local function updateList(cols, skip)
    local parts = {}
    for c in cols:gmatch('[%w_]+') do
        if not skip[c] then parts[#parts + 1] = ('`%s` = VALUES(`%s`)'):format(c, c) end
    end
    return table.concat(parts, ', ')
end

-- Every statement of one fill, run on one connection with @qbx_sync set so the triggers stay quiet.
function SQL.fillStatements()
    return {
        'SET @qbx_sync = 1',
        ('INSERT INTO players (%s) SELECT %s FROM qbx_v_players ON DUPLICATE KEY UPDATE %s')
            :format(PLAYER_COLS, PLAYER_COLS, updateList(PLAYER_COLS, { id = true, citizenid = true })),
        'DELETE FROM players WHERE citizenid NOT IN (SELECT citizenid FROM qbx_v_players)',
        ('INSERT INTO player_vehicles (%s) SELECT %s FROM qbx_v_player_vehicles ON DUPLICATE KEY UPDATE %s')
            :format(VEH_COLS, VEH_COLS, updateList(VEH_COLS, { whip_vehicle_id = true })),
        'DELETE FROM player_vehicles WHERE whip_vehicle_id IS NOT NULL AND whip_vehicle_id NOT IN (SELECT whip_vehicle_id FROM qbx_v_player_vehicles)',
        'DELETE FROM player_groups',
        'INSERT IGNORE INTO player_groups (citizenid, `group`, `type`, grade) SELECT citizenid, `group`, `type`, grade FROM qbx_v_player_groups',
        'SET @qbx_sync = NULL',
    }
end

local ready = false
local filling = false

function SQL.fill()
    if not ready or filling then return end
    filling = true
    local ok, err = pcall(MySQL.transaction.await, SQL.fillStatements())
    filling = false
    if not ok or err == false then print('^3[qbx_core] filling qb tables: ' .. tostring(err) .. '^0') end
end

function SQL.quiet(query, values)
    return pcall(MySQL.transaction.await, { 'SET @qbx_sync = 1', { query = query, values = values or {} }, 'SET @qbx_sync = NULL' })
end

local function tableKind(name)
    return MySQL.scalar.await('SELECT TABLE_TYPE FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })
end
local function tableComment(name)
    return MySQL.scalar.await('SELECT TABLE_COMMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })
end

local function run(label, query)
    local ok, err = pcall(MySQL.query.await, query)
    if not ok then print(('^1[qbx_core] %s: %s^0'):format(label, tostring(err))) end
    return ok
end

SQL.managed = {}

function SQL.install()
    if not BridgeConfig.SqlViews then return end
    run('qb_joaat', SQL.joaat)
    for name, ddl in pairs(SQL.views) do run(name, ddl) end
    run('qbx_bridge_queue', SQL.queue)
    for name, ddl in pairs(SQL.tables) do
        local kind = tableKind(name)
        if kind == 'VIEW' then
            run('drop old view ' .. name, ('DROP VIEW %s'):format(name))
            kind = nil
        end
        if kind == 'BASE TABLE' and tableComment(name) ~= MARK then
            print(('^3[qbx_core] a real table `%s` the bridge did not make is in this database: left alone, so qb scripts read it, not whip^0'):format(name))
        else
            if run(name, ddl) then
                local ok = true
                for _, q in ipairs(SQL.triggers(name)) do ok = run('trigger on ' .. name, q) and ok end
                SQL.managed[name] = ok
            end
        end
    end
    ready = true
    SQL.fill()
end

CreateThread(function()
    while true do
        Wait((BridgeConfig.SqlSyncSeconds or 10) * 1000)
        if ready then SQL.fill() end
    end
end)

function SQL.isReady() return ready end
