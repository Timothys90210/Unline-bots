-- CinderEvent.lua
-- Phase 1 (outside portal): stops CaveBot on portal announcement, walks to portal tile
-- Phase 2 (inside portal):  blue flame OR fire snake tracking + dodge mechanics
-- Exit:                     "failure compensation" / "750 cinder points" → CaveBot resumes

local PORTAL_TILE_ID           = 47093
local BLUE_FLAME_ID            = 47295
local FIRE_SNAKE_ID            = 60662
local RED_GEM_ID               = 24934  -- Soccer Ball mechanic item
local BOMBS_ID                 = 46113  -- Bombs mechanic item
local PORTAL_SEARCH_TIME       = 60
local PORTAL_MAX_DURATION      = 90  -- safety: force-FAIL if inside portal > 90s without exit message
local FIRE_SNAKE_SAFE_DISTANCE      = 5  -- trigger movement when snake within this range
local FIRE_SNAKE_MIN_CLEARANCE      = 5  -- target tiles must be at least this far from snake
local FIRE_SNAKE_MAX_CLEARANCE      = 8  -- target tiles must be at most this far from snake
local FIRE_SNAKE_FALLBACK_CLEARANCE = 3  -- pass 3 (panic): when primary passes fail, accept tiles
                                         -- as close as 3 sqm. Targets the 40% of V9 fails that died
                                         -- with [NO TARGET] cascades at speed surge when snake length
                                         -- 11+ makes clearance≥5 geometrically impossible.

-- ── Logging ───────────────────────────────────────────────────────────────────
local botConfigName = modules.game_bot.contentsPanel.config:getCurrentOption().text

local FIRE_SNAKE_WALK_DELAY = 300  -- V1 thrash guard
local logsDir       = "/bot/" .. botConfigName .. "/logs"

-- Internal log entries — temp names during session, renamed to GameName_OUTCOME_N on exit
local cinderLogs = {
    blueFlame  = { name = "Blue Flame",  path = nil, buffer = "" },
    firestorm  = { name = "Fire Storm",  path = nil, buffer = "" },
    fireSnake  = { name = "Fire Snake",  path = nil, buffer = "" },
    soccerBall = { name = "Soccer Ball", path = nil, buffer = "" },
    bombs      = { name = "Bombs",       path = nil, buffer = "" },
}

local function ensureLogsDir()
    if not g_resources.directoryExists(logsDir) then
        g_resources.makeDir(logsDir)
    end
end

local function getNextLogPath(prefix)
    local i = 0
    while g_resources.fileExists(logsDir .. "/" .. prefix .. "_" .. i .. ".txt")
       or g_resources.fileExists(logsDir .. "/" .. prefix .. "_SUCCESS_" .. i .. ".txt")
       or g_resources.fileExists(logsDir .. "/" .. prefix .. "_FAIL_" .. i .. ".txt")
    do
        i = i + 1
    end
    return logsDir .. "/" .. prefix .. "_" .. i .. ".txt"
end

local function cinderLog(key, msg)
    local entry = cinderLogs[key]
    if not entry.path then
        ensureLogsDir()
        entry.path   = getNextLogPath(entry.name)
        entry.buffer = "=== " .. entry.name .. " | " .. os.date("%Y-%m-%d %H:%M:%S") .. " ===\n"
        entry.buffer = entry.buffer .. "[" .. os.date("%H:%M:%S") .. "] Portal entered\n"
    end
    entry.buffer = entry.buffer .. "[" .. os.date("%H:%M:%S") .. "] " .. msg .. "\n"
    g_resources.writeFileContents(entry.path, entry.buffer)
end

local function cinderLogActive(key, msg)
    if cinderLogs[key].path then cinderLog(key, msg) end
end

-- On exit: rename each active log to GameName_OUTCOME_N.txt
-- Wrapped in pcall per-entry so a file I/O error on one log never blocks the rest
-- of the exit sequence (resetState, CaveBot.setOn).
local function finalizeActiveLogs(outcome)
    for key, entry in pairs(cinderLogs) do
        if entry.path then
            pcall(function()
                if g_resources.fileExists(entry.path) then
                    local idx = entry.path:match("_(%d+)%.txt$")
                    if idx then
                        entry.buffer = entry.buffer .. "[" .. os.date("%H:%M:%S") .. "] === " .. outcome .. " ===\n"
                        local newPath = logsDir .. "/" .. entry.name .. "_" .. outcome .. "_" .. idx .. ".txt"
                        g_resources.writeFileContents(newPath, entry.buffer)
                        g_resources.deleteFile(entry.path)
                    end
                end
            end)
        end
    end
end

local function resetLogs()
    for _, entry in pairs(cinderLogs) do
        entry.path   = nil
        entry.buffer = ""
    end
end

-- Global flag read by MonsterIdentifier to avoid conflicting CaveBot restores
CinderPortalActive = false

-- CaveBot state logging helpers (defined in monster_identifier.lua if loaded first,
-- or defined here if CinderEvent loads first — guard prevents double-definition)
-- CaveBot diagnostic logging — disabled (no-ops while commented out)
-- To re-enable: uncomment this entire block and the logCaveBotOn/Off call sites below
--[[
if not CaveBotStateLogDefined then
    CaveBotStateLogDefined = true
    local _cbConfigName = modules.game_bot.contentsPanel.config:getCurrentOption().text
    local _cbLogsDir    = "/bot/" .. _cbConfigName .. "/logs"
    local _cbDiagDir    = _cbLogsDir .. "/cavebot diagnostic"
    CaveBotOffLogPath   = nil

    function logCaveBotOff(reason)
        pcall(function()
            if not g_resources.directoryExists(_cbLogsDir) then
                g_resources.makeDir(_cbLogsDir)
            end
            if not g_resources.directoryExists(_cbDiagDir) then
                g_resources.makeDir(_cbDiagDir)
            end
            local ts       = os.date("%H-%M-%S")
            local filePath = _cbDiagDir .. "/CAVEBOT_OFF_" .. ts .. ".txt"
            local content  = "=== CaveBot OFF | " .. os.date("%Y-%m-%d %H:%M:%S") .. " ===\n"
            content = content .. "[" .. os.date("%H:%M:%S") .. "] TURNED OFF | " .. reason .. "\n"
            g_resources.writeFileContents(filePath, content)
            CaveBotOffLogPath = filePath
        end)
    end

    function logCaveBotOn(reason)
        pcall(function()
            local path = CaveBotOffLogPath
            if path then
                local content = g_resources.fileExists(path) and
                                 g_resources.readFileContents(path) or ""
                content = content .. "[" .. os.date("%H:%M:%S") .. "] TURNED ON  | " .. reason .. "\n"
                g_resources.writeFileContents(path, content)
                CaveBotOffLogPath = nil
            end
        end)
    end

    function logCaveBotSkipped(reason)
        pcall(function()
            local path = CaveBotOffLogPath
            if path then
                local content = g_resources.fileExists(path) and
                                 g_resources.readFileContents(path) or ""
                content = content .. "[" .. os.date("%H:%M:%S") .. "] SKIPPED ON | " .. reason .. "\n"
                g_resources.writeFileContents(path, content)
            end
        end)
    end
end
--]]

-- Stub functions so call sites below don't error while logging is disabled
local function logCaveBotOff(reason) end
local function logCaveBotOn(reason) end
local function logCaveBotSkipped(reason) end

-- ── State ─────────────────────────────────────────────────────────────────────
local insidePortal      = false
local insidePortalSince = 0     -- os.clock() when entry detected; used by max-duration safety timeout
local portalTriggered   = false
local portalSearchUntil = 0
local portalRetryLogAt  = 0
local portalLastSeenPos = nil

local blueFlameArenaBounds   = nil    -- computed once for center targeting
local blueFlameConfirmedSet  = {}     -- tile positions of the last confirmed set (for remnant filtering)
local blueFlameMeteoPhase    = false  -- armed true on arrival; gates new-set detection
local blueFlameTarget        = nil    -- center flame of current set
local blueFlameWalkIssued    = false
local blueFlameWalkAt        = 0
local blueFlameArrivedLogged = false
local blueFlameRetryCount    = 0
local blueFlameSetActive     = false  -- true while a set is currently visible
local blueFlameSetNumber     = 0      -- 0-indexed; logged before increment

local snakeArena         = nil   -- circular arena: {centerX, centerY, radius, ...}
local snakeActiveSeen    = false -- true after first movement trigger (gates one-time [ACTIVE] log)
local snakeIdleLogAt     = 0
local snakeHeadLastPos   = nil   -- for [HEAD] log change detection only

-- Firestorm tracking
local firestormLastClearedAt   = 0      -- os.clock() when last "Firestorm cleared"
local firestormEventCount      = 0      -- total firestorm events this portal session
local firestormWalkCount       = 0      -- walk commands issued for current event

local dodgeFirestormActive = false
local dodgeSoccerActive    = false
local dodgeBombsActive     = false
local dodgeTargetPos       = nil   -- committed dodge destination; monitored every tick

-- Diagnostic state for richer firestorm/soccer logging
local dodgeStaleDestKey     = nil  -- "x,y" of current dodgeTargetPos for stale-detection
local dodgeStaleDestStartAt = 0    -- os.clock when this destKey was first observed
local dodgeStaleLogged      = false -- already logged a [STALE DEST] for current stuck period
local dodgeBlacklistLogAt   = 0    -- last time we dumped [BLACKLIST] (rate-limited 5s)

-- Pattern A: tiles already attempted within the current dodge event. Prevents
-- the selector re-picking the same destination after a HIT (FAIL_68, _73, _75
-- showed 2-4 consecutive walks to identical tiles). Cleared on event start
-- and on clear. Independent of the 5s decay blacklist.
local dodgeAttemptedThisEvent = {}

local bombScanLogAt        = 0
local bombsGameActive      = false  -- latched true on first bomb detection; gates firestorm for full portal

local function log(msg)
    modules.game_textmessage.displayGameMessage("[CinderEvent] " .. msg)
end

local function resetState()
    insidePortal             = false
    insidePortalSince        = 0
    portalTriggered          = false
    CinderPortalActive       = false
    portalSearchUntil        = 0
    portalRetryLogAt         = 0
    portalLastSeenPos        = nil
    blueFlameArenaBounds   = nil
    blueFlameConfirmedSet  = {}
    blueFlameMeteoPhase    = false
    blueFlameTarget        = nil
    blueFlameWalkIssued    = false
    blueFlameWalkAt        = 0
    blueFlameArrivedLogged = false
    blueFlameRetryCount    = 0
    blueFlameSetActive     = false
    blueFlameSetNumber     = 0
    snakeArena         = nil
    snakeActiveSeen    = false
    snakeIdleLogAt     = 0
    snakeHeadLastPos   = nil
    firestormLastClearedAt   = 0
    firestormEventCount      = 0
    firestormWalkCount       = 0
    dodgeFirestormActive     = false
    dodgeSoccerActive        = false
    dodgeBombsActive         = false
    dodgeTargetPos           = nil
    dodgeStaleDestKey        = nil
    dodgeStaleDestStartAt    = 0
    dodgeStaleLogged         = false
    dodgeBlacklistLogAt      = 0
    dodgeAttemptedThisEvent  = {}
    bombScanLogAt            = 0
    bombsGameActive          = false
    pendingSuccessScheduled  = false
    resetLogs()
end

-- ── Helpers ───────────────────────────────────────────────────────────────────
-- Full tile inspection — returns a human-readable string of everything on a tile.
-- Used to detect if flame IDs change between rounds.
local function inspectTile(pos)
    local tile = g_map.getTile(pos)
    if not tile then return "tile_not_found" end
    local parts = {}
    local ground = tile:getGround()
    if ground then table.insert(parts, "ground:" .. ground:getId()) end
    local effects = tile:getEffects()
    if #effects > 0 then
        local eIds = {}
        for _, fx in ipairs(effects) do table.insert(eIds, fx:getId()) end
        table.insert(parts, "effects:[" .. table.concat(eIds, ",") .. "]")
    end
    local items = tile:getItems()
    if #items > 0 then
        local iIds = {}
        for _, item in ipairs(items) do table.insert(iIds, item:getId()) end
        table.insert(parts, "items:[" .. table.concat(iIds, ",") .. "]")
    end
    return #parts > 0 and table.concat(parts, " | ") or "empty"
end

local function hasTileItemId(tile, id)
    local ground = tile:getGround()
    if ground and ground:getId() == id then return true end
    for _, item in ipairs(tile:getItems()) do
        if item:getId() == id then return true end
    end
    return false
end


local function getFireSnakeTiles(playerPos)
    local tiles = {}
    for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
        if hasTileItemId(tile, FIRE_SNAKE_ID) then
            table.insert(tiles, tile:getPosition())
        end
    end
    return tiles
end

local function minDistToSnake(pos, snakeTiles)
    local minDist = math.huge
    for _, sp in ipairs(snakeTiles) do
        local d = getDistanceBetween(pos, sp)
        if d < minDist then minDist = d end
    end
    return minDist
end

-- ── Circular arena detection (V7) ───────────────────────────────────────────
-- The fire snake arena is a CIRCLE (~15 tiles diameter), not a rectangle.
-- Rectangle-based bounds caused corner-pin deaths in V6 because the "corners"
-- of the bounding box are not walkable. We compute center + chebyshev radius
-- and only use these for SCORING, never for hard filtering. findPath() is the
-- authoritative walkability check.
local function computeSnakeArena(playerPos)
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    local count = 0
    for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
        local tp = tile:getPosition()
        if math.abs(tp.x - playerPos.x) <= 20 and math.abs(tp.y - playerPos.y) <= 20 then
            count = count + 1
            if tp.x < minX then minX = tp.x end
            if tp.x > maxX then maxX = tp.x end
            if tp.y < minY then minY = tp.y end
            if tp.y > maxY then maxY = tp.y end
        end
    end
    local cx = math.floor((minX + maxX) / 2)
    local cy = math.floor((minY + maxY) / 2)
    local radius = math.max(maxX - cx, cx - minX, maxY - cy, cy - minY)
    return {
        centerX = cx, centerY = cy, radius = radius,
        minX = minX, maxX = maxX, minY = minY, maxY = maxY,
        tileCount = count,
    }
end

-- Dynamic expansion: if player or snake tile falls outside detected arena,
-- expand center/radius to include it. Self-corrects underestimated bounds.
local function expandArenaIfNeeded(arena, pos)
    local d = math.max(math.abs(pos.x - arena.centerX), math.abs(pos.y - arena.centerY))
    if d > arena.radius then
        arena.radius = d
        if pos.x < arena.minX then arena.minX = pos.x end
        if pos.x > arena.maxX then arena.maxX = pos.x end
        if pos.y < arena.minY then arena.minY = pos.y end
        if pos.y > arena.maxY then arena.maxY = pos.y end
        return true
    end
    return false
end

-- Predict where the snake head will be in N ticks based on its recent velocity.
-- If we don't have history yet, returns current head.
local function predictHeadPos(head, headPrev, ticks)
    if not headPrev then return { x = head.x, y = head.y } end
    local vx = head.x - headPrev.x
    local vy = head.y - headPrev.y
    return { x = head.x + vx * ticks, y = head.y + vy * ticks }
end

-- Intercept simulation: walks the player toward `target` and the snake toward
-- the player's evolving position, tick by tick (chebyshev pursuit). Returns
-- chebyshev distance between snake and target when player arrives at target.
-- Low value = snake catches up to / occupies the target before/when player
-- gets there. This catches the "snake follows you south" case that the
-- vector-based side penalty misses (snake's chase curves toward you, not
-- along a fixed direction).
local function interceptDistance(playerPos, target, head)
    local function sign(n) return n > 0 and 1 or (n < 0 and -1 or 0) end
    local t_arrival = math.max(
        math.abs(target.x - playerPos.x),
        math.abs(target.y - playerPos.y))
    if t_arrival == 0 then
        return math.max(math.abs(head.x - target.x), math.abs(head.y - target.y))
    end
    local px, py = playerPos.x, playerPos.y
    local sx, sy = head.x, head.y
    local tx, ty = target.x, target.y
    for _ = 1, t_arrival do
        if px ~= tx then px = px + sign(tx - px) end
        if py ~= ty then py = py + sign(ty - py) end
        if sx ~= px then sx = sx + sign(px - sx) end
        if sy ~= py then sy = sy + sign(py - sy) end
    end
    return math.max(math.abs(sx - tx), math.abs(sy - ty))
end

-- Wrong-side penalty: project player→target onto player→head direction. If
-- positive, target is on the snake's side of the player (suicidal). Returns
-- the projection length in tiles; caller multiplies by a weight.
-- Without this, two tiles with equal headDist score the same even when one
-- sits in the snake's predicted path and the other is on the safe side.
local function towardSnakeScore(tp, playerPos, head)
    local apx, apy = head.x - playerPos.x, head.y - playerPos.y
    local tpx, tpy = tp.x - playerPos.x, tp.y - playerPos.y
    local apLen = math.sqrt(apx * apx + apy * apy)
    if apLen == 0 then return 0 end
    local proj = (apx * tpx + apy * tpy) / apLen  -- tiles toward snake (signed)
    return math.max(0, proj)  -- only penalize toward-snake; behind-player is free
end

-- Tangential bonus: tiles perpendicular to the head→player vector score
-- higher than tiles radially away. On a circle, this naturally produces
-- perimeter-following behaviour instead of corner-hopping.
local function tangentialScore(tp, playerPos, head)
    local hpx, hpy = playerPos.x - head.x, playerPos.y - head.y
    local tpx, tpy = tp.x - playerPos.x, tp.y - playerPos.y
    local hpLen = math.sqrt(hpx * hpx + hpy * hpy)
    local tpLen = math.sqrt(tpx * tpx + tpy * tpy)
    if hpLen == 0 or tpLen == 0 then return 0 end
    local cosAng = (hpx * tpx + hpy * tpy) / (hpLen * tpLen)
    -- cosAng = 0 → perpendicular (best, tangential)
    -- cosAng = +1 → radial flee (decent)
    -- cosAng = -1 → toward snake (worst)
    return (1 - math.abs(cosAng))  -- 0..1
end

-- Head detection via tile novelty: snake grows from the head outward, so the
-- tile that newly appeared this tick is the head. Resolves the "nearest tile
-- to player flips between body segments" bug that previously caused phantom
-- head jumps of 3+ tiles per tick (see SUCCESS_14 — chase reset by luck).
-- Phantom guard: ignore new tiles further than 5 chebyshev from last head
-- (briefly-evicted cached tiles re-appearing far away).
local function identifyHead(snakeTiles, lastTileSet, lastHead, playerPos)
    local currentSet = {}
    for _, sp in ipairs(snakeTiles) do
        currentSet[sp.x .. "," .. sp.y] = sp
    end

    local newTiles = {}
    if lastTileSet then
        for k, sp in pairs(currentSet) do
            if not lastTileSet[k] then
                if lastHead then
                    local d = math.max(math.abs(sp.x - lastHead.x), math.abs(sp.y - lastHead.y))
                    if d <= 5 then table.insert(newTiles, sp) end
                else
                    table.insert(newTiles, sp)
                end
            end
        end
    end

    local head, source
    if #newTiles == 1 then
        head, source = newTiles[1], "novel"
    elseif #newTiles > 1 and lastHead then
        local bestD = math.huge
        for _, sp in ipairs(newTiles) do
            local d = math.max(math.abs(sp.x - lastHead.x), math.abs(sp.y - lastHead.y))
            if d < bestD then bestD, head = d, sp end
        end
        source = "multi-novel"
    elseif lastHead and currentSet[lastHead.x .. "," .. lastHead.y] then
        head, source = currentSet[lastHead.x .. "," .. lastHead.y], "stationary"
    else
        local bestD = math.huge
        for _, sp in ipairs(snakeTiles) do
            local d = math.max(math.abs(sp.x - playerPos.x), math.abs(sp.y - playerPos.y))
            if d < bestD then bestD, head = d, sp end
        end
        source = "fallback-nearest"
    end

    return head, currentSet, source
end

-- Legacy rectangular bounds (kept for BlueFlame which still uses it).
local function computeSnakeArenaBounds(playerPos)
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
        local tp = tile:getPosition()
        if math.abs(tp.x - playerPos.x) <= 55 and math.abs(tp.y - playerPos.y) <= 55 then
            if tp.x < minX then minX = tp.x end
            if tp.x > maxX then maxX = tp.x end
            if tp.y < minY then minY = tp.y end
            if tp.y > maxY then maxY = tp.y end
        end
    end
    local b = {
        rawMinX = minX, rawMaxX = maxX, rawMinY = minY, rawMaxY = maxY,
        minX = minX + 2, maxX = maxX - 2,
        minY = minY + 2, maxY = maxY - 2,
        width  = (maxX - 2) - (minX + 2),
        height = (maxY - 2) - (minY + 2),
    }
    b.centerX = math.floor((b.minX + b.maxX) / 2)
    b.centerY = math.floor((b.minY + b.maxY) / 2)
    return b
end

local function scanBlueFlames(z)
    local set, count = {}, 0
    for _, tile in ipairs(g_map.getTiles(z)) do
        if hasTileItemId(tile, BLUE_FLAME_ID) then
            local tp = tile:getPosition()
            set[tp.x .. "," .. tp.y] = { x = tp.x, y = tp.y, z = tp.z }
            count = count + 1
        end
    end
    return set, count
end



-- Sets 0-6: pure center targeting — builds good central position early.
-- Sets 7+:  blended scoring (distToPlayer*2 + distToCenter) — prioritises
--           reachable flames when late-round sets place all flames far from center.
local BLUE_FLAME_BLEND_SET = 7

local function findCenterFlame(flameSet, centerX, centerY, playerPos, setNumber)
    local bestPos, bestScore = nil, math.huge
    for _, pos in pairs(flameSet) do
        local distToCenter = math.max(math.abs(pos.x - centerX), math.abs(pos.y - centerY))
        local score
        if setNumber and playerPos and setNumber >= BLUE_FLAME_BLEND_SET then
            local distToPlayer = math.max(math.abs(pos.x - playerPos.x), math.abs(pos.y - playerPos.y))
            score = distToPlayer * 2 + distToCenter
        else
            score = distToCenter
        end
        if score < bestScore then bestScore, bestPos = score, pos end
    end
    -- Return position and its distance from center for logging
    local distFromCenter = bestPos and math.max(math.abs(bestPos.x - centerX), math.abs(bestPos.y - centerY)) or 0
    return bestPos, distFromCenter
end

local function logFlameSet(label, flameSet, size, centerX, centerY)
    local parts = {}
    for _, pos in pairs(flameSet) do
        local dist = math.max(math.abs(pos.x - centerX), math.abs(pos.y - centerY))
        table.insert(parts, pos.x .. "," .. pos.y .. "(c:" .. dist .. ")")
    end
    table.sort(parts)
    cinderLog("blueFlame", string.format("[%s] size=%d | %s", label, size, table.concat(parts, " | ")))
end

-- Forward declaration: processPortalExit is defined below but referenced
-- inside the macro (timeout safety path). Lua resolves locals at parse time.
local processPortalExit

-- ── Main macro ────────────────────────────────────────────────────────────────
local cinderMacro = macro(200, function()
    if not player then return end
    local playerPos = player:getPosition()

    -- ── Phase 2: inside the portal ────────────────────────────────────────────
    if insidePortal then

        -- ── Safety: force-exit if portal exit messages never fire (game/text bug)
        if insidePortalSince > 0 and os.clock() - insidePortalSince > PORTAL_MAX_DURATION then
            cinderLogActive("fireSnake", string.format(
                "[TIMEOUT] inside portal %ds with no exit message — forcing FAIL",
                math.floor(os.clock() - insidePortalSince)))
            log(string.format("Portal timeout (%ds) — forcing FAIL recovery.",
                math.floor(os.clock() - insidePortalSince)))
            processPortalExit("FAIL")
            return
        end

        -- ── Fire Snake mechanic (V9 — V1 logic, circular bounds, rich logging) ──
        -- V1 scoring restored: `snakeDist*2 + edgeBonus` over candidates with
        -- snakeDist [5,8] and dpf [3,6]. Two-pass wall fallback (pass 1 prefers
        -- tiles ≤5 from wall, pass 2 any). V1 had 50-70% success with this.
        -- Updates: circular arena bounds (V1 used wrong rectangular bounds that
        -- accidentally disabled the edge filter); overshooting guard via plain
        -- autoWalk/findPath (no ignoreNonPathable). Rich logging tags from V7+.
        local snakeTiles = getFireSnakeTiles(playerPos)
        if #snakeTiles > 0 then
            local ok, err = pcall(function()

            if not snakeArena then
                snakeArena = computeSnakeArena(playerPos)
                local a = snakeArena
                cinderLog("fireSnake", string.format(
                    "[ARENA] center=%d,%d radius=%d bbox=(%d-%d, %d-%d) tiles=%d",
                    a.centerX, a.centerY, a.radius,
                    a.minX, a.maxX, a.minY, a.maxY, a.tileCount))
            end

            local a        = snakeArena
            local snakeLen = #snakeTiles
            local nearest  = minDistToSnake(playerPos, snakeTiles)

            -- Head = nearest snake tile (informational only — used for logging).
            local head, headDist = nil, math.huge
            for _, sp in ipairs(snakeTiles) do
                local d = getDistanceBetween(playerPos, sp)
                if d < headDist then headDist, head = d, sp end
            end
            if head and (not snakeHeadLastPos or
               head.x ~= snakeHeadLastPos.x or head.y ~= snakeHeadLastPos.y) then
                cinderLog("fireSnake", string.format(
                    "[HEAD] %d,%d → %d,%d dist=%d player=%d,%d len=%d",
                    snakeHeadLastPos and snakeHeadLastPos.x or head.x,
                    snakeHeadLastPos and snakeHeadLastPos.y or head.y,
                    head.x, head.y, headDist,
                    playerPos.x, playerPos.y, snakeLen))
                snakeHeadLastPos = { x = head.x, y = head.y }
            end

            if nearest == 0 then
                cinderLog("fireSnake", string.format(
                    "[ON SNAKE] standing on snake tile | player=%d,%d",
                    playerPos.x, playerPos.y))
            end

            local trigger = FIRE_SNAKE_SAFE_DISTANCE
            if nearest > trigger then
                local clk = os.clock()
                if clk - snakeIdleLogAt >= 2 then
                    snakeIdleLogAt = clk
                    cinderLog("fireSnake", string.format(
                        "[IDLE] snakeDist=%d trigger=%d | player=%d,%d len=%d",
                        nearest, trigger, playerPos.x, playerPos.y, snakeLen))
                end
                return
            end

            if not snakeActiveSeen then
                snakeActiveSeen = true
                cinderLog("fireSnake", string.format(
                    "[ACTIVE] head=%d,%d dist=%d | player=%d,%d | len=%d trigger=%d",
                    head and head.x or 0, head and head.y or 0, headDist,
                    playerPos.x, playerPos.y, snakeLen, trigger))
                log("Fire snake — active")
            end

            -- V9.1 three-pass search (2026-05-28):
            --   Pass 1 (wall):     edgeDist ≤ 5, snakeDist ≥ FIRE_SNAKE_MIN_CLEARANCE (5)
            --   Pass 2 (any):      any tile,     snakeDist ≥ FIRE_SNAKE_MIN_CLEARANCE (5)
            --   Pass 3 (panic):    any tile,     snakeDist ≥ FIRE_SNAKE_FALLBACK_CLEARANCE (3)
            -- Score: snakeDist*2 (safety primary) + max(0,15-edgeDist) (wall bonus).
            -- Pass 3 only fires when passes 1+2 found nothing — addresses the 40% of
            -- V9 fails that died with [NO TARGET] cascades at speed surge (snake length
            -- 11+ makes clearance≥5 impossible). Strict superset of V9 — cannot regress
            -- when snake is short enough that pass 1 or 2 finds a tile.
            local bestTile, bestScore = nil, -1
            local bestSnakeDist, bestEdgeDist, bestPass = 0, 0, ""
            for pass = 1, 3 do
                local passClearance = (pass == 3) and FIRE_SNAKE_FALLBACK_CLEARANCE
                                                  or  FIRE_SNAKE_MIN_CLEARANCE
                for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
                    local tp  = tile:getPosition()
                    local dpf = getDistanceBetween(playerPos, tp)
                    if dpf >= 3 and dpf <= 6 then
                        local isSnake = false
                        for _, sp in ipairs(snakeTiles) do
                            if sp.x == tp.x and sp.y == tp.y then isSnake = true; break end
                        end
                        if not isSnake and not (tile:getTopCreature() ~= nil) then
                            local snakeDist = minDistToSnake(tp, snakeTiles)
                            if snakeDist >= passClearance
                               and snakeDist <= FIRE_SNAKE_MAX_CLEARANCE then
                                local distFromCenter = math.max(
                                    math.abs(tp.x - a.centerX),
                                    math.abs(tp.y - a.centerY))
                                local edgeDist = math.max(0, a.radius - distFromCenter)
                                if pass >= 2 or edgeDist <= 5 then
                                    local score = snakeDist * 2 + math.max(0, 15 - edgeDist)
                                    if score > bestScore
                                       and findPath(playerPos, tp, 7, {}) then
                                        bestScore     = score
                                        bestTile      = tp
                                        bestSnakeDist = snakeDist
                                        bestEdgeDist  = edgeDist
                                        bestPass      = (pass == 1) and "wall"
                                                     or (pass == 2) and "any"
                                                     or "panic"
                                    end
                                end
                            end
                        end
                    end
                end
                if bestTile then break end
            end

            if bestTile then
                cinderLog("fireSnake", string.format(
                    "[TARGET] %d,%d | score=%d snakeDist=%d edgeDist=%d pass=%s | player=%d,%d nearest=%d len=%d",
                    bestTile.x, bestTile.y, bestScore,
                    bestSnakeDist, bestEdgeDist, bestPass,
                    playerPos.x, playerPos.y, nearest, snakeLen))
                autoWalk(bestTile, 7, {})
                cinderLog("fireSnake", string.format(
                    "[WALK] → %d,%d dpf=%d",
                    bestTile.x, bestTile.y,
                    getDistanceBetween(playerPos, bestTile)))
                delay(FIRE_SNAKE_WALK_DELAY)  -- V1 thrash guard
            else
                cinderLog("fireSnake", string.format(
                    "[NO TARGET] snakeDist=%d player=%d,%d head=%d,%d len=%d",
                    nearest, playerPos.x, playerPos.y,
                    head and head.x or 0, head and head.y or 0, snakeLen))
            end

            end)  -- pcall
            if not ok then
                cinderLog("fireSnake", "[ERROR] " .. tostring(err))
                log("FireSnake ERROR: " .. tostring(err))
            end
            return
        end

        -- ── Blue flame mechanic ──────────────────────────────────────────────
        local _blueOk, _blueErr = pcall(function()
        -- Detection: meteor-gate approach.
        -- A new set is ONLY confirmed on the first non-empty scan after a confirmed
        -- empty scan (meteor phase). Flame count fluctuations during an active set
        -- (caused by client visibility changes as the player moves) are ignored.
        -- Once a target is committed, it is never changed until the next new set.

        -- Compute arena bounds once for center targeting
        if not blueFlameArenaBounds then
            local anyFlame = false
            for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
                if hasTileItemId(tile, BLUE_FLAME_ID) then anyFlame = true; break end
            end
            if anyFlame then
                blueFlameArenaBounds = computeSnakeArenaBounds(playerPos)
                local b = blueFlameArenaBounds
                cinderLog("blueFlame", string.format(
                    "[BOUNDS] walkable=(%d-%d, %d-%d) center=%d,%d size=%dx%d",
                    b.minX, b.maxX, b.minY, b.maxY, b.centerX, b.centerY, b.width, b.height))
            end
        end

        local b = blueFlameArenaBounds
        if not b then return end

        local scanSet, scanSize = scanBlueFlames(playerPos.z)

        -- ── Arm meteor phase when own flame disappears ────────────────────────
        -- Do NOT arm on arrival (set still active for 2s after arriving).
        -- Only arm when the character's committed flame tile is gone from the scan.
        if blueFlameSetActive and blueFlameArrivedLogged and blueFlameTarget
           and not blueFlameMeteoPhase then
            local ownKey = blueFlameTarget.x .. "," .. blueFlameTarget.y
            if not scanSet[ownKey] then
                blueFlameMeteoPhase = true
                cinderLog("blueFlame", string.format(
                    "[METEOR ARM] own flame %d,%d gone from scan (size=%d) | player=%d,%d",
                    blueFlameTarget.x, blueFlameTarget.y, scanSize,
                    playerPos.x, playerPos.y))
            end
        end

        -- ── Meteor phase ──────────────────────────────────────────────────────
        -- After arriving at a flame, meteorphase=true. We then watch for the
        -- next genuine set by filtering out old-set remnants from the scan.
        -- scanSize==0 is still valid but not required — new tiles with zero overlap
        -- with blueFlameConfirmedSet confirm the new set even without a zero-scan frame.
        if blueFlameMeteoPhase then
            if scanSize == 0 then
                -- Visual confirmation of empty scan — hold, still in meteor phase
                cinderLog("blueFlame", string.format(
                    "[METEOR] Set #%d empty scan — holding at %d,%d",
                    blueFlameSetNumber - 1, playerPos.x, playerPos.y))
                return
            end
            -- Flames visible: filter out confirmed-set remnants
            local newTiles, newCount = {}, 0
            for key, pos in pairs(scanSet) do
                if not blueFlameConfirmedSet[key] then
                    newTiles[key] = pos
                    newCount = newCount + 1
                end
            end
            if newCount == 0 then
                -- Only old-set remnants visible — cache hasn't cleared, hold
                cinderLog("blueFlame", string.format(
                    "[HOLDING] only old-set remnants visible (size=%d) — waiting | player=%d,%d",
                    scanSize, playerPos.x, playerPos.y))
                return
            end
            -- Genuine new tiles — confirm new set from non-remnant tiles only
            blueFlameMeteoPhase    = false
            blueFlameSetActive     = true
            blueFlameConfirmedSet  = scanSet  -- full scan so all currently-visible tiles are excluded next tick
            blueFlameTarget        = nil
            blueFlameWalkIssued    = false
            blueFlameArrivedLogged = false
            blueFlameRetryCount    = 0
            local blendActive = blueFlameSetNumber >= BLUE_FLAME_BLEND_SET
            cinderLog("blueFlame", string.format(
                "[NEW SET #%d] size=%d (filtered from scan=%d) | player=%d,%d | targeting=%s",
                blueFlameSetNumber, newCount, scanSize, playerPos.x, playerPos.y,
                blendActive and "BLEND" or "CENTER"))
            logFlameSet("SET_" .. blueFlameSetNumber, newTiles, newCount, b.centerX, b.centerY)
            local target, distFromCenter = findCenterFlame(newTiles, b.centerX, b.centerY, playerPos, blueFlameSetNumber)
            blueFlameTarget = target
            blueFlameWalkAt = os.clock()
            cinderLog("blueFlame", string.format(
                "[TARGET] center flame=%d,%d distFromCenter=%d | player=%d,%d",
                target.x, target.y, distFromCenter, playerPos.x, playerPos.y))
            log("Flame set #" .. blueFlameSetNumber .. " — " .. target.x .. "," .. target.y)
            blueFlameSetNumber = blueFlameSetNumber + 1
            -- Fall through to walk management
        elseif scanSize == 0 then
            -- Normal empty scan outside meteor phase (set expired before arrival)
            if blueFlameSetActive then
                blueFlameSetActive = false
                cinderLog("blueFlame", string.format(
                    "[METEOR] Set #%d expired — holding at %d,%d | arrived=%s",
                    blueFlameSetNumber - 1, playerPos.x, playerPos.y, tostring(blueFlameArrivedLogged)))
            end
            return
        elseif not blueFlameSetActive then
            -- First non-empty scan at game start or after a clean meteor
            blueFlameSetActive     = true
            blueFlameConfirmedSet  = scanSet
            blueFlameTarget        = nil
            blueFlameWalkIssued    = false
            blueFlameArrivedLogged = false
            blueFlameRetryCount    = 0
            local blendActive = blueFlameSetNumber >= BLUE_FLAME_BLEND_SET
            cinderLog("blueFlame", string.format(
                "[NEW SET #%d] size=%d | player=%d,%d | targeting=%s",
                blueFlameSetNumber, scanSize, playerPos.x, playerPos.y,
                blendActive and "BLEND" or "CENTER"))
            logFlameSet("SET_" .. blueFlameSetNumber, scanSet, scanSize, b.centerX, b.centerY)
            local target, distFromCenter = findCenterFlame(scanSet, b.centerX, b.centerY, playerPos, blueFlameSetNumber)
            blueFlameTarget = target
            blueFlameWalkAt = os.clock()
            cinderLog("blueFlame", string.format(
                "[TARGET] center flame=%d,%d distFromCenter=%d | player=%d,%d",
                target.x, target.y, distFromCenter, playerPos.x, playerPos.y))
            log("Flame set #" .. blueFlameSetNumber .. " — " .. target.x .. "," .. target.y)
            blueFlameSetNumber = blueFlameSetNumber + 1
        end
        -- blueFlameSetActive true + not in meteor phase: same set still active, hold

        -- ── Walk management ───────────────────────────────────────────────────
        -- Once arrived, hold — never re-walk. Retries after arrival cause autoWalk
        -- overshoot that moves the character off the flame tile before set expires.
        if blueFlameTarget then
            local dist = getDistanceBetween(playerPos, blueFlameTarget)
            if dist == 0 then
                if not blueFlameArrivedLogged then
                    blueFlameArrivedLogged = true
                    -- blueFlameMeteoPhase armed only when own flame disappears from scan (see above)
                    cinderLog("blueFlame", string.format(
                        "[ARRIVED] %d,%d | walkElapsed=%.1fs | retries=%d",
                        playerPos.x, playerPos.y,
                        os.clock() - blueFlameWalkAt, blueFlameRetryCount))
                end
            elseif not blueFlameArrivedLogged then
                -- Only walk if not yet arrived — holds position after arrival
                if not blueFlameWalkIssued then
                    autoWalk(blueFlameTarget, 15, { ignoreNonPathable = true })
                    blueFlameWalkIssued = true
                    blueFlameWalkAt     = os.clock()
                    cinderLog("blueFlame", string.format(
                        "[WALK] → %d,%d dist=%d | player=%d,%d",
                        blueFlameTarget.x, blueFlameTarget.y, dist,
                        playerPos.x, playerPos.y))
                elseif os.clock() - blueFlameWalkAt >= 1 and dist > 2 then
                    local elapsed = os.clock() - blueFlameWalkAt
                    blueFlameRetryCount = blueFlameRetryCount + 1
                    autoWalk(blueFlameTarget, 15, { ignoreNonPathable = true })
                    blueFlameWalkAt = os.clock()
                    cinderLog("blueFlame", string.format(
                        "[WALK RETRY %d] → %d,%d dist=%d elapsed=%.1fs | player=%d,%d",
                        blueFlameRetryCount, blueFlameTarget.x, blueFlameTarget.y,
                        dist, elapsed, playerPos.x, playerPos.y))
                end
            end
        end
        end)  -- pcall
        if not _blueOk then
            cinderLog("blueFlame", "[ERROR] " .. tostring(_blueErr))
            log("BlueFlame ERROR: " .. tostring(_blueErr))
        end
        return
    end

    -- ── Phase 1: walk to portal tile ──────────────────────────────────────────
    if portalTriggered and os.clock() > portalSearchUntil then
        portalTriggered    = false
        CinderPortalActive = false
        CaveBot.setOn()
        logCaveBotOn("Cinder portal search timed out — 60s elapsed without entering")
        log("Portal search timed out — CaveBot restored.")
    end

    for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
        local pos = tile:getPosition()
        if getDistanceBetween(playerPos, pos) <= 8 then
            if hasTileItemId(tile, PORTAL_TILE_ID) then
                portalLastSeenPos = pos
                if findPath(playerPos, pos, 15, { ignoreNonPathable = true, precision = 1 }) then
                    if portalTriggered and os.clock() >= portalRetryLogAt then
                        log("Walking to portal... retrying")
                        portalRetryLogAt = os.clock() + 3
                    end
                    autoWalk(pos, 15, { ignoreNonPathable = true, precision = 1 })
                    delay(1000)
                    return
                end
            end
        end
    end
end)

-- ── POS trail (complete tile-by-tile capture for fire snake analysis) ────────
-- Uses position-change callback so every single tile walked is logged, not
-- just per-200ms-tick samples. Gated on cinderLogActive so it only records
-- once the fire snake log file is already open (avoids creating a fire snake
-- log entry for portals where no snake ever appears).
onPlayerPositionChange(function(newPos, oldPos)
    if not insidePortal then return end
    cinderLogActive("fireSnake", string.format("[POS] %d,%d", newPos.x, newPos.y))
end)

-- ── Portal entry detection ────────────────────────────────────────────────────
onPlayerPositionChange(function(newPos, oldPos)
    if not cinderMacro.isOn() then return end
    if portalTriggered and portalLastSeenPos then
        -- Detect portal entry via teleport: a single position step > 5 tiles is
        -- impossible by walking (always 1 tile/step). Portal entry causes a large jump.
        -- Old approach (distance from portalLastSeenPos > 15) fired on accumulated
        -- walking distance, causing false positives when pathing around obstacles.
        if getDistanceBetween(newPos, oldPos) > 5 then
            insidePortal       = true
            insidePortalSince  = os.clock()
            portalTriggered    = false
            portalLastSeenPos  = nil
            CinderPortalActive = true
            log("Portal entered — all mechanics now active.")
        end
    end
end)

-- ── Portal announced ──────────────────────────────────────────────────────────
onTextMessage(function(mode, text)
    if not cinderMacro.isOn() then return end
    if text:lower():find("portal has appeared") then
        portalTriggered   = true
        portalSearchUntil = os.clock() + PORTAL_SEARCH_TIME
        portalRetryLogAt  = 0
        CinderPortalActive = true
        if CaveBot.isOn() then
            CaveBot.setOff()
            logCaveBotOff("Cinder portal announced — walking to portal tile")
            log("Portal appeared — CaveBot stopped. Walking to portal.")
        else
            log("Portal appeared — walking to portal.")
        end
    end
end)

-- ── Portal exited — rename logs to GameName_OUTCOME_N and resume botting ──────
-- Success:  "You received 750 cinder points."               (exact amount = 750)
-- Failure:  "You received 188 cinder points as failure compensation."
-- Other "cinder points" amounts are mid-event participation rewards and must be ignored.
local pendingSuccessScheduled = false

processPortalExit = function(outcome)
    if not insidePortal then return end
    local result = outcome == "SUCCESS"
        and "SUCCESS — 750 cinder points"
        or  "FAILURE — received failure compensation"
    cinderLogActive("blueFlame",  "Portal exited: " .. result)
    cinderLogActive("firestorm",  "Portal exited: " .. result)
    cinderLogActive("fireSnake",  "Portal exited: " .. result)
    cinderLogActive("soccerBall", "Portal exited: " .. result)
    cinderLogActive("bombs",      "Portal exited: " .. result)
    finalizeActiveLogs(outcome)
    resetState()
    CaveBot.setOn()
    logCaveBotOn("Cinder portal exited: " .. outcome)
    log("Portal exited — CaveBot resumed.")
end

onTextMessage(function(mode, text)
    if not insidePortal then return end
    local lowerText = text:lower()

    if lowerText:find("failure compensation") then
        pendingSuccessScheduled = false
        processPortalExit("FAIL")
    elseif lowerText:find("750 cinder points") then
        processPortalExit("SUCCESS")
    end
end)

-- ── Dodge mechanics (active inside portal, overlaps with both event modes) ────
-- hasDangerousEffect / dodgeAvoidItem → logs to "Fire Storm" (Firestorm mechanic)
-- hasRedGem  (24934)                  → logs to "Soccer Ball"
-- hasBombs   (46113)                  → logs to "Bombs"

-- 329, 790 added 2026-05-27: discovered in community Event.lua. Likely explain
-- the [HIT]=0 death pattern — un-detected effects damaging player without
-- triggering hasDangerousEffect(). 60662 and 46113 stay separate (they're snake
-- and bombs IDs handled by their own mechanics).
local effectIdsToDodge       = {78, 79, 80, 188, 329, 790}
-- 47295 (BLUE_FLAME_ID) added 2026-05-27: blue flame tiles are walkable, so
-- standing on one clears any blacklist entry from a previous dangerous effect
-- that has since faded.
local effectIdsSafe          = {575, 277, 404, 47295}
local dodgeAvoidItemId       = 1949
local dodgeMaxDistance       = 7
local dodgeReentryDelay      = 5
local dodgeRecentlyDangerous = {}
local dodgeFlags             = { ignoreNonPathable = true }

local function hasDangerousEffect(tile)
    for _, fx in ipairs(tile:getEffects()) do
        for _, id in ipairs(effectIdsToDodge) do
            if fx:getId() == id then return true end
        end
    end
    return false
end

local function hasDodgeSafeEffect(tile)
    for _, fx in ipairs(tile:getEffects()) do
        for _, id in ipairs(effectIdsSafe) do
            if fx:getId() == id then return true end
        end
    end
    return false
end

local function hasDodgeAvoidItem(tile)
    for i = 0, tile:getThingCount() - 1 do
        local thing = tile:getThing(i)
        if thing and thing:getId() == dodgeAvoidItemId then return true end
    end
    return false
end

local function hasRedGem(tile)
    for i = 0, tile:getThingCount() - 1 do
        local thing = tile:getThing(i)
        if thing and thing:getId() == RED_GEM_ID then return true end
    end
    return false
end

local function hasBombs(tile)
    for i = 0, tile:getThingCount() - 1 do
        local thing = tile:getThing(i)
        if thing and thing:getId() == BOMBS_ID then return true end
    end
    return false
end

local function dodgePosKey(pos)
    return pos.x .. "," .. pos.y .. "," .. pos.z
end

local function isTileRecentlyDangerous(pos)
    local ts = dodgeRecentlyDangerous[dodgePosKey(pos)]
    return ts and (os.clock() - ts < dodgeReentryDelay)
end

-- Unified danger check — defined here so cleanupOldDangerousTiles can use it
local function isTileDangerous(tile)
    return hasDangerousEffect(tile) or hasDodgeAvoidItem(tile) or hasRedGem(tile) or hasBombs(tile)
end

-- getDangerKey only covers the two red-tile games — bombs has its own separate path
local function getDangerKey(tile)
    if hasRedGem(tile) then return "soccerBall" end
    return "firestorm"
end

local function cleanupOldDangerousTiles()
    local clk = os.clock()
    for key, ts in pairs(dodgeRecentlyDangerous) do
        if clk - ts >= dodgeReentryDelay then dodgeRecentlyDangerous[key] = nil end
    end
end

local function cleanupBySafeEffect()
    for _, tile in ipairs(g_map.getTiles(player:getPosition().z)) do
        if hasDodgeSafeEffect(tile) then
            dodgeRecentlyDangerous[dodgePosKey(tile:getPosition())] = nil
        end
    end
end

local function findAndWalkToSafeTile(playerPos, logKey)
    local blacklistSize = 0
    for _ in pairs(dodgeRecentlyDangerous) do blacklistSize = blacklistSize + 1 end

    -- Count nearby dangerous tiles for saturation context
    local nearbyDanger = 0
    for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
        local tp = tile:getPosition()
        if getDistanceBetween(playerPos, tp) <= 3 and isTileDangerous(tile) then
            nearbyDanger = nearbyDanger + 1
        end
    end

    firestormWalkCount = firestormWalkCount + 1
    if logKey == "firestorm" then
        cinderLog("firestorm", "Dodge attempt #" .. firestormWalkCount ..
            " | nearby danger: " .. nearbyDanger .. " tiles | blacklist: " .. blacklistSize .. " tiles")
    end

    -- Track rejected candidates for [CANDIDATES] diagnostic on failure.
    -- Each entry: "x,y(d<dist>:<reason>)" — capped at 12 to keep the log line readable.
    local rejected = {}
    local function trackReject(d, tp, reason)
        if #rejected < 12 then
            table.insert(rejected, string.format("%d,%d(d%d:%s)", tp.x, tp.y, d, reason))
        end
    end

    -- Helper: attempt one full scan with an optional blacklist bypass.
    -- Returns true if a walk was issued.
    local function scanForSafe(ignoreBlacklist)
        for distance = 1, dodgeMaxDistance do
            local candidates = {}
            for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
                local tilePos = tile:getPosition()
                if tilePos and getDistanceBetween(playerPos, tilePos) == distance then
                    table.insert(candidates, tile)
                end
            end
            for _, tile in ipairs(candidates) do
                local tilePos = tile:getPosition()
                if isTileDangerous(tile) then
                    if not ignoreBlacklist then trackReject(distance, tilePos, "danger") end
                elseif (not ignoreBlacklist) and isTileRecentlyDangerous(tilePos) then
                    trackReject(distance, tilePos, "blist")
                elseif dodgeAttemptedThisEvent[dodgePosKey(tilePos)] then
                    -- Pattern A: never re-pick a tile already attempted this event,
                    -- even under PANIC. A tile that just hit us cannot help us now.
                    trackReject(distance, tilePos, "tried")
                elseif tile:getTopCreature() ~= nil then
                    if not ignoreBlacklist then trackReject(distance, tilePos, "creat") end
                elseif not findPath(playerPos, tilePos, 15, dodgeFlags) then
                    if not ignoreBlacklist then trackReject(distance, tilePos, "nopth") end
                else
                    autoWalk(tilePos, 15, dodgeFlags)
                    dodgeTargetPos = tilePos
                    dodgeAttemptedThisEvent[dodgePosKey(tilePos)] = true
                    cinderLog(logKey, "Walking to safe tile at dist " .. distance .. " — " ..
                        tilePos.x .. "," .. tilePos.y ..
                        (ignoreBlacklist and " [PANIC: blacklist ignored]" or ""))
                    CaveBot.delay(500)
                    delay(500)
                    return true
                end
            end
        end
        return false
    end

    -- Primary scan: respect blacklist
    if scanForSafe(false) then return true end

    -- Panic fallback: ignore blacklist (any non-currently-dangerous tile beats standing still)
    cinderLog(logKey, string.format(
        "[NO SAFE] nearby_danger=%d blacklist=%d max_dist=%d pos=%d,%d — entering PANIC (ignore blacklist)",
        nearbyDanger, blacklistSize, dodgeMaxDistance, playerPos.x, playerPos.y))
    if #rejected > 0 then
        cinderLog(logKey, "[CANDIDATES] rejected: " .. table.concat(rejected, " | "))
    end
    if scanForSafe(true) then return true end

    cinderLog(logKey, string.format(
        "[PANIC FAILED] no candidate even with blacklist ignored | pos=%d,%d — standing still",
        playerPos.x, playerPos.y))
    return false
end

-- Cross pattern offsets: bomb tile + 3 tiles in each cardinal direction (13 tiles total)
local BOMB_CROSS = { {0,0},{1,0},{2,0},{3,0},{-1,0},{-2,0},{-3,0},{0,1},{0,2},{0,3},{0,-1},{0,-2},{0,-3} }

local function getBombPositions(z)
    local bombs = {}
    for _, tile in ipairs(g_map.getTiles(z)) do
        if hasTileItemId(tile, BOMBS_ID) then
            table.insert(bombs, tile:getPosition())
        end
    end
    return bombs
end

local function computeBombDangerZone(bombs)
    local zone = {}
    for _, bpos in ipairs(bombs) do
        for _, d in ipairs(BOMB_CROSS) do
            zone[(bpos.x + d[1]) .. "," .. (bpos.y + d[2])] = true
        end
    end
    return zone
end

local function isInBombDanger(pos, zone)
    return zone[pos.x .. "," .. pos.y] == true
end

local function findBombSafeTile(playerPos, dangerZone)
    for dist = 1, 12 do
        for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
            local tp = tile:getPosition()
            if getDistanceBetween(playerPos, tp) == dist
               and not isInBombDanger(tp, dangerZone)
               and not hasDangerousEffect(tile)
               and not (tile:getTopCreature() ~= nil)
               and findPath(playerPos, tp, 15, { ignoreNonPathable = true })
            then
                return tp
            end
        end
    end
    return nil
end

local cinderDodge = macro(200, function()
    if not player then return end
    if not insidePortal then return end

    local playerPos  = player:getPosition()

    if blueFlameTarget ~= nil then return end
    if #getFireSnakeTiles(playerPos) > 0 then return end

    local playerTile = player:getTile()
    cleanupOldDangerousTiles()
    cleanupBySafeEffect()

    -- ── Bombs mechanic (predictive + reactive hybrid) ────────────────────────────
    local bombsHandled = false  -- set true inside pcall when firestorm must be skipped
    local _bombOk, _bombErr = pcall(function()
    local bombs        = getBombPositions(playerPos.z)
    local reactiveDanger = hasDangerousEffect(playerTile)

    if #bombs > 0 then
        bombsGameActive = true  -- latch: gates firestorm for rest of this portal even if scan gaps occur
        if cinderLogs["bombs"].path == nil then
            cinderLog("bombs", string.format("[ACTIVE] Bombs game — %d bomb(s) detected", #bombs))
            dodgeTargetPos = nil
        end

        local dangerZone = computeBombDangerZone(bombs)
        local zoneSize   = 0
        for _ in pairs(dangerZone) do zoneSize = zoneSize + 1 end

        -- ── Periodic scan: full bomb positions + both danger checks ───────────
        local clk = os.clock()
        if clk - bombScanLogAt >= 3 then
            bombScanLogAt = clk
            local posList = {}
            for _, bp in ipairs(bombs) do
                table.insert(posList, bp.x .. "," .. bp.y)
            end
            local fxIds = {}
            for _, fx in ipairs(playerTile:getEffects()) do
                table.insert(fxIds, tostring(fx:getId()))
            end
            cinderLog("bombs", string.format(
                "[SCAN] bombs=%d zone=%d player=%d,%d predictive=%s reactive=%s effects=[%s] | %s",
                #bombs, zoneSize, playerPos.x, playerPos.y,
                tostring(isInBombDanger(playerPos, dangerZone)),
                tostring(reactiveDanger),
                #fxIds > 0 and table.concat(fxIds, ",") or "none",
                #posList > 0 and table.concat(posList, " | ") or "none"))
        end

        -- ── Check if walk target is still safe (both layers) ─────────────────
        if dodgeTargetPos then
            if getDistanceBetween(playerPos, dodgeTargetPos) == 0 then
                dodgeTargetPos = nil
                if dodgeBombsActive then
                    dodgeBombsActive = false
                    cinderLog("bombs", string.format("[SAFE] %d,%d | bombs=%d zone=%d",
                        playerPos.x, playerPos.y, #bombs, zoneSize))
                end
            elseif isInBombDanger(dodgeTargetPos, dangerZone) then
                cinderLog("bombs", string.format("[REROUTE] target %d,%d entered predictive zone — bombs=%d zone=%d",
                    dodgeTargetPos.x, dodgeTargetPos.y, #bombs, zoneSize))
                dodgeTargetPos = nil
            end
        end

        -- ── Danger detection: log which layer triggered ───────────────────────
        local predictiveDanger = isInBombDanger(playerPos, dangerZone)
        local currentDanger    = predictiveDanger or reactiveDanger

        if currentDanger and not dodgeBombsActive then
            dodgeBombsActive = true
            if reactiveDanger and not predictiveDanger then
                -- Reactive caught something predictive missed — log effects and
                -- all bomb positions so we can diagnose radius/chain issues
                local fxIds = {}
                for _, fx in ipairs(playerTile:getEffects()) do
                    table.insert(fxIds, tostring(fx:getId()))
                end
                local posList = {}
                for _, bp in ipairs(bombs) do
                    table.insert(posList, bp.x .. "," .. bp.y)
                end
                cinderLog("bombs", string.format(
                    "[IN DANGER - REACTIVE] effects=[%s] player=%d,%d bombs=%d zone=%d | bomb positions: %s",
                    table.concat(fxIds, ","), playerPos.x, playerPos.y, #bombs, zoneSize,
                    #posList > 0 and table.concat(posList, " | ") or "none"))
            elseif predictiveDanger then
                -- Predictive triggered — log which specific bombs cover the player
                local coveringBombs = {}
                for _, bp in ipairs(bombs) do
                    for _, d in ipairs(BOMB_CROSS) do
                        if (bp.x + d[1]) == playerPos.x and (bp.y + d[2]) == playerPos.y then
                            table.insert(coveringBombs, bp.x .. "," .. bp.y)
                            break
                        end
                    end
                end
                cinderLog("bombs", string.format(
                    "[IN DANGER - PREDICTIVE] player=%d,%d bombs=%d zone=%d | covering bombs: %s",
                    playerPos.x, playerPos.y, #bombs, zoneSize,
                    #coveringBombs > 0 and table.concat(coveringBombs, " | ") or "unknown"))
            end
        end

        if currentDanger and not dodgeTargetPos then
            -- findBombSafeTile already excludes both predictive zones and active effects
            local safe = findBombSafeTile(playerPos, dangerZone)
            if safe then
                autoWalk(safe, 15, { ignoreNonPathable = true })
                dodgeTargetPos = safe
                local layer = (reactiveDanger and not predictiveDanger) and "REACTIVE" or "PREDICTIVE"
                cinderLog("bombs", string.format("[WALK-%s] to %d,%d dist=%d bombs=%d zone=%d",
                    layer, safe.x, safe.y,
                    getDistanceBetween(playerPos, safe), #bombs, zoneSize))
            else
                cinderLog("bombs", string.format(
                    "[WARNING] No safe tile found — bombs=%d zone=%d player=%d,%d predictive=%s reactive=%s",
                    #bombs, zoneSize, playerPos.x, playerPos.y,
                    tostring(predictiveDanger), tostring(reactiveDanger)))
            end
        end

        bombsHandled = true; return  -- never enters firestorm logic
    end

    -- Bombs cleared (scan returned 0) — but if this is a bombs portal, keep gating firestorm.
    -- A single-tick scan gap must not drop us into firestorm mid-game.
    if bombsGameActive then
        if dodgeBombsActive then
            dodgeBombsActive = false
            dodgeTargetPos   = nil
            cinderLog("bombs", string.format("[BOMBS CLEAR] No bombs on floor — safe at %d,%d",
                playerPos.x, playerPos.y))
        end
        bombsHandled = true; return  -- still a bombs portal — never fall through to firestorm
    end

    if dodgeBombsActive then
        dodgeBombsActive = false
        dodgeTargetPos   = nil
        cinderLog("bombs", string.format("[BOMBS CLEAR] No bombs on floor — safe at %d,%d",
            playerPos.x, playerPos.y))
    end

    end)  -- bombs pcall
    if not _bombOk then
        cinderLog("bombs", "[ERROR] " .. tostring(_bombErr))
        log("Bombs ERROR: " .. tostring(_bombErr))
    end
    if bombsHandled then return end

    -- ── Firestorm / Soccer dodge ──────────────────────────────────────────────
    local _dodgeOk, _dodgeErr = pcall(function()
    local firestormDanger = hasDangerousEffect(playerTile) or hasDodgeAvoidItem(playerTile)
    local soccerDanger    = hasRedGem(playerTile)
    local currentDanger   = firestormDanger or soccerDanger
    local logKey          = soccerDanger and "soccerBall" or "firestorm"

    -- [HIT] — if we're already in an active dodge event AND still on a danger tile,
    -- something went wrong (walked onto danger / dest became dangerous mid-walk).
    -- Suppress on the initial event tick (dodgeFirestormActive only just turned true).
    if currentDanger and dodgeFirestormActive then
        cinderLog(logKey, string.format(
            "[HIT] still on danger mid-dodge | pos=%d,%d firestormDanger=%s soccerDanger=%s targetPos=%s",
            playerPos.x, playerPos.y,
            tostring(firestormDanger), tostring(soccerDanger),
            dodgeTargetPos and (dodgeTargetPos.x .. "," .. dodgeTargetPos.y) or "nil"))
    end

    -- [STALE DEST] — dodgeTargetPos unchanged for >1.5s suggests the walk command
    -- didn't reach (autoWalk stalled, pathing failed silently, or character is wedged).
    if dodgeTargetPos then
        local key = dodgeTargetPos.x .. "," .. dodgeTargetPos.y
        if key == dodgeStaleDestKey then
            if not dodgeStaleLogged and os.clock() - dodgeStaleDestStartAt > 1.5 then
                dodgeStaleLogged = true
                cinderLog(logKey, string.format(
                    "[STALE DEST] target=%d,%d unchanged for %.1fs | player=%d,%d",
                    dodgeTargetPos.x, dodgeTargetPos.y,
                    os.clock() - dodgeStaleDestStartAt,
                    playerPos.x, playerPos.y))
            end
        else
            dodgeStaleDestKey     = key
            dodgeStaleDestStartAt = os.clock()
            dodgeStaleLogged      = false
        end
    else
        dodgeStaleDestKey = nil
        dodgeStaleLogged  = false
    end

    -- [BLACKLIST] periodic dump — only during active firestorm games (not blue-flame/soccer)
    if firestormEventCount > 0 and os.clock() - dodgeBlacklistLogAt >= 5 then
        dodgeBlacklistLogAt = os.clock()
        local count, oldestAge = 0, 0
        local now_ = os.clock()
        for _, ts in pairs(dodgeRecentlyDangerous) do
            count = count + 1
            local age = now_ - ts
            if age > oldestAge then oldestAge = age end
        end
        cinderLog("firestorm", string.format(
            "[BLACKLIST] count=%d oldest_age=%.1fs (decay at %ds)",
            count, oldestAge, dodgeReentryDelay))
    end

    local needReroute = false
    local rerouteKey  = "firestorm"
    if dodgeTargetPos then
        if getDistanceBetween(playerPos, dodgeTargetPos) == 0 then
            dodgeTargetPos = nil
        else
            local destTile = g_map.getTile(dodgeTargetPos)
            if destTile and (hasDangerousEffect(destTile) or hasDodgeAvoidItem(destTile) or hasRedGem(destTile)) then
                rerouteKey = getDangerKey(destTile)
                dodgeRecentlyDangerous[dodgePosKey(dodgeTargetPos)] = os.clock()
                local distWalked = getDistanceBetween(playerPos, dodgeTargetPos)
                cinderLog(rerouteKey, string.format(
                    "Destination %d,%d became dangerous — re-routing | %d tiles still to walk",
                    dodgeTargetPos.x, dodgeTargetPos.y, distWalked))
                dodgeTargetPos = nil
                needReroute    = true
                if not currentDanger then logKey = rerouteKey end
            end
        end
    end

    if currentDanger or needReroute then
        if currentDanger then
            dodgeRecentlyDangerous[dodgePosKey(playerPos)] = os.clock()
            if logKey == "soccerBall" and not dodgeSoccerActive then
                dodgeSoccerActive = true
                dodgeAttemptedThisEvent = {}  -- Pattern A: fresh event, clear attempted-tile set
                cinderLog("soccerBall", "Red gem at " .. playerPos.x .. "," .. playerPos.y .. " — dodging")
            elseif logKey == "firestorm" and not dodgeFirestormActive then
                dodgeFirestormActive  = true
                dodgeAttemptedThisEvent = {}  -- Pattern A: fresh event, clear attempted-tile set
                firestormEventCount   = firestormEventCount + 1
                firestormWalkCount    = 0
                local interval = firestormLastClearedAt > 0
                    and string.format("%.1f", os.clock() - firestormLastClearedAt) .. "s since last clear"
                    or  "first event"
                -- Collect the specific effect IDs on this tile for diagnosis
                local effectIds = {}
                for _, fx in ipairs(playerTile:getEffects()) do
                    table.insert(effectIds, fx:getId())
                end
                cinderLog("firestorm", "Event #" .. firestormEventCount ..
                    " | " .. interval ..
                    " | effect IDs: [" .. table.concat(effectIds, ",") .. "]" ..
                    " | at " .. playerPos.x .. "," .. playerPos.y)
            end
        end
        findAndWalkToSafeTile(playerPos, logKey)
    else
        if not dodgeTargetPos then
            if dodgeFirestormActive then
                dodgeFirestormActive = false
                firestormLastClearedAt = os.clock()
                dodgeAttemptedThisEvent = {}  -- Pattern A: defensive clear on dodge-event end
                cinderLog("firestorm", "Firestorm cleared — safe at " .. playerPos.x .. "," .. playerPos.y)
            end
            if dodgeSoccerActive then
                dodgeSoccerActive = false
                dodgeAttemptedThisEvent = {}  -- Pattern A: defensive clear on dodge-event end
                cinderLog("soccerBall", "Red gem cleared — safe at " .. playerPos.x .. "," .. playerPos.y)
            end
            if dodgeBombsActive then
                dodgeBombsActive = false
                cinderLog("bombs", "Bomb cleared — safe at " .. playerPos.x .. "," .. playerPos.y)
            end
        end
    end
    end)  -- dodge pcall
    if not _dodgeOk then
        cinderLog("firestorm", "[ERROR] " .. tostring(_dodgeErr))
        log("Dodge ERROR: " .. tostring(_dodgeErr))
    end
end)

-- ── Single icon controls all features ────────────────────────────────────────
local cinderIcon = addIcon("CinderEvent", { item = { id = 47093, count = 1 }, text = "Cinder Event" }, function(icon, isOn)
    cinderMacro.setOn(isOn)
    cinderDodge.setOn(isOn)
    if not isOn then
        if CinderPortalActive then
            -- Portal was active when icon was turned off — CaveBot was off, restore it
            CaveBot.setOn()
            logCaveBotOn("CinderEvent icon turned off by user while portal was active — restoring CaveBot")
        end
        resetState()
    end
end)
cinderIcon.text:setFont("verdana-11px-rounded")
