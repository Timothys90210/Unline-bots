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
local FIRE_SNAKE_SAFE_DISTANCE = 6      -- sqm (Chebyshev) — trigger movement when snake within this range
local FIRE_SNAKE_MIN_CLEARANCE = 5      -- sqm — target tiles must be at least this far from snake

-- ── Logging ───────────────────────────────────────────────────────────────────
local botConfigName = modules.game_bot.contentsPanel.config:getCurrentOption().text
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

local snakeArenaBounds    = nil   -- computed once on first snake detection
local snakeInitialPhase   = true  -- true while doing the one-time run to 12 o'clock
local snakeInitialTarget  = nil
local snakeWalkTarget     = nil
local snakeWalkIssued     = false
local snakeWalkAt         = 0
local snakeActivePhase    = false
local snakeEmergencyAt    = 0     -- os.clock() of last emergency reroute; guards 500ms lock
local snakeIdleLogAt      = 0
local snakeHeadLastPos    = nil

-- Firestorm tracking
local firestormLastClearedAt   = 0      -- os.clock() when last "Firestorm cleared"
local firestormEventCount      = 0      -- total firestorm events this portal session
local firestormWalkCount       = 0      -- walk commands issued for current event

local dodgeFirestormActive = false
local dodgeSoccerActive    = false
local dodgeBombsActive     = false
local dodgeTargetPos       = nil   -- committed dodge destination; monitored every tick

local bombScanLogAt        = 0
local bombsGameActive      = false  -- latched true on first bomb detection; gates firestorm for full portal

local function log(msg)
    modules.game_textmessage.displayGameMessage("[CinderEvent] " .. msg)
end

local function resetState()
    insidePortal             = false
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
    snakeArenaBounds   = nil
    snakeInitialPhase  = true
    snakeInitialTarget = nil
    snakeWalkTarget    = nil
    snakeWalkIssued    = false
    snakeWalkAt        = 0
    snakeActivePhase   = false
    snakeEmergencyAt   = 0
    snakeIdleLogAt     = 0
    snakeHeadLastPos   = nil
    firestormLastClearedAt   = 0
    firestormEventCount      = 0
    firestormWalkCount       = 0
    dodgeFirestormActive     = false
    dodgeSoccerActive        = false
    dodgeBombsActive         = false
    dodgeTargetPos           = nil
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

-- Scans all floor tiles within 55 sqm to find arena extents.
-- Returns raw tile min/max AND a walkable inset (wall tiles sit at the edge,
-- walkable floor starts 1 tile inside). Logs full boundary info for verification.
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

-- ── Main macro ────────────────────────────────────────────────────────────────
local cinderMacro = macro(200, function()
    if not player then return end
    local playerPos = player:getPosition()

    -- ── Phase 2: inside the portal ────────────────────────────────────────────
    if insidePortal then

        -- ── Fire Snake mechanic ──────────────────────────────────────────────
        -- Strategy: one-time run to 12 o'clock (top-center wall) on first detection,
        -- then hold until snake is within 5 tiles (Chebyshev), then move clockwise
        -- along the boundary. autoWalk committed once per target; re-picked only on
        -- arrival or emergency (≤2 tiles). Arena bounds computed dynamically.
        local snakeTiles = getFireSnakeTiles(playerPos)
        if #snakeTiles > 0 then
            local ok, err = pcall(function()

            -- ── Arena bounds (computed once on first detection) ───────────────
            if not snakeArenaBounds then
                snakeArenaBounds = computeSnakeArenaBounds(playerPos)
                local b = snakeArenaBounds
                -- 12 o'clock: top-center, 1 tile inside top wall
                snakeInitialTarget = { x = b.centerX, y = b.minY, z = playerPos.z }
                cinderLog("fireSnake", string.format(
                    "[BOUNDS] raw=(%d-%d, %d-%d) walkable=(%d-%d, %d-%d) center=%d,%d size=%dx%d",
                    b.rawMinX, b.rawMaxX, b.rawMinY, b.rawMaxY,
                    b.minX, b.maxX, b.minY, b.maxY,
                    b.centerX, b.centerY, b.width, b.height))
                cinderLog("fireSnake", string.format(
                    "[INIT TARGET] 12 o'clock → %d,%d | player=%d,%d dist=%d",
                    snakeInitialTarget.x, snakeInitialTarget.y,
                    playerPos.x, playerPos.y,
                    getDistanceBetween(playerPos, snakeInitialTarget)))
                log("Fire snake — running to 12 o'clock")
            end

            local b       = snakeArenaBounds
            local nearest = minDistToSnake(playerPos, snakeTiles)

            -- ── Head tracking ─────────────────────────────────────────────────
            local head, headDist = nil, math.huge
            for _, sp in ipairs(snakeTiles) do
                local d = getDistanceBetween(playerPos, sp)
                if d < headDist then headDist, head = d, sp end
            end
            if head and (not snakeHeadLastPos or
               head.x ~= snakeHeadLastPos.x or head.y ~= snakeHeadLastPos.y) then
                local prevX = snakeHeadLastPos and snakeHeadLastPos.x or head.x
                local prevY = snakeHeadLastPos and snakeHeadLastPos.y or head.y
                snakeHeadLastPos = head
                cinderLog("fireSnake", string.format(
                    "[HEAD] %d,%d → %d,%d | dist=%d | player=%d,%d | snakeLen=%d",
                    prevX, prevY, head.x, head.y, headDist,
                    playerPos.x, playerPos.y, #snakeTiles))
            end

            -- ── Wall context (logged throughout for boundary verification) ─────
            local dN = playerPos.y - b.minY
            local dS = b.maxY - playerPos.y
            local dW = playerPos.x - b.minX
            local dE = b.maxX - playerPos.x
            local wallDist = math.min(dN, dS, dW, dE)
            local wallName = (wallDist == dN) and "N" or
                             (wallDist == dS) and "S" or
                             (wallDist == dW) and "W" or "E"

            -- ── Clockwise tangent from arena center ────────────────────────────
            -- In Tibia coords (Y increases south), CW tangent of radius (rx,ry) is (-ry, rx)
            local rx = playerPos.x - b.centerX
            local ry = playerPos.y - b.centerY
            local radLen = math.sqrt(rx * rx + ry * ry)
            local cwX = radLen > 0 and (-ry / radLen) or 1
            local cwY = radLen > 0 and ( rx / radLen) or 0

            if nearest == 0 then
                cinderLog("fireSnake", string.format(
                    "[EMERGENCY] standing ON snake tile at %d,%d | wall=%s(%d)",
                    playerPos.x, playerPos.y, wallName, wallDist))
            end

            -- ── Adaptive scaling based on snake length ────────────────────────
            -- t=0 at len=1 (early/slow), t=1 at len=12 (max/fast)
            local snakeLen     = #snakeTiles
            local t            = math.min(snakeLen - 1, 11) / 11
            local dynTrigger   = math.floor(4 + t * 2)   -- 4 → 6 tiles
            local dynMaxDist   = math.floor(4 + t * 3)   -- 4 → 7 tiles from player
            local dynEmergency = math.floor(2 + t)       -- 2 → 3 tiles

            -- ── Phase 1: initial run to 12 o'clock ────────────────────────────
            if snakeInitialPhase then
                local distToInit = getDistanceBetween(playerPos, snakeInitialTarget)
                if distToInit == 0 or nearest <= dynTrigger then
                    snakeInitialPhase = false
                    cinderLog("fireSnake", string.format(
                        "[INIT DONE] player=%d,%d distToTarget=%d snakeDist=%d wall=%s(%d)",
                        playerPos.x, playerPos.y, distToInit, nearest, wallName, wallDist))
                else
                    if not snakeWalkIssued or os.clock() - snakeWalkAt >= 1 then
                        autoWalk(snakeInitialTarget, 20, { ignoreNonPathable = true })
                        snakeWalkIssued = true
                        snakeWalkAt     = os.clock()
                        cinderLog("fireSnake", string.format(
                            "[INIT WALK] → %d,%d | distToTarget=%d snakeDist=%d wall=%s(%d)",
                            snakeInitialTarget.x, snakeInitialTarget.y,
                            distToInit, nearest, wallName, wallDist))
                    end
                    return
                end
            end

            -- ── Phase 2: hold unless snake within dynTrigger tiles ────────────
            if nearest > dynTrigger then
                if snakeActivePhase then
                    snakeActivePhase = false
                    snakeWalkTarget  = nil
                    snakeWalkIssued  = false
                    cinderLog("fireSnake", string.format(
                        "[IDLE] Snake retreated to %d tiles — holding | player=%d,%d wall=%s(%d) len=%d trigger=%d maxDist=%d",
                        nearest, playerPos.x, playerPos.y, wallName, wallDist, snakeLen, dynTrigger, dynMaxDist))
                else
                    local clk = os.clock()
                    if clk - snakeIdleLogAt >= 2 then
                        snakeIdleLogAt = clk
                        cinderLog("fireSnake", string.format(
                            "[IDLE] snakeDist=%d player=%d,%d wall=%s(%d) len=%d trigger=%d maxDist=%d",
                            nearest, playerPos.x, playerPos.y,
                            wallName, wallDist, snakeLen, dynTrigger, dynMaxDist))
                    end
                end
                return
            end

            -- ── Phase 3: active — snake ≤ dynTrigger tiles, move clockwise ──────
            if not snakeActivePhase then
                snakeActivePhase = true
                cinderLog("fireSnake", string.format(
                    "[ACTIVE] Snake %d tiles | head=%d,%d | player=%d,%d | wall=%s(%d) | len=%d trigger=%d maxDist=%d emergency=%d",
                    nearest,
                    head and head.x or 0, head and head.y or 0,
                    playerPos.x, playerPos.y, wallName, wallDist,
                    snakeLen, dynTrigger, dynMaxDist, dynEmergency))
            end

            -- Check if current target is still valid
            if snakeWalkTarget then
                local distToTarget = getDistanceBetween(playerPos, snakeWalkTarget)
                if distToTarget == 0 then
                    cinderLog("fireSnake", string.format(
                        "[ARRIVED] %d,%d | wall=%s(%d) | snakeDist=%d | CW=(%.2f,%.2f)",
                        playerPos.x, playerPos.y, wallName, wallDist, nearest, cwX, cwY))
                    snakeWalkTarget = nil
                    snakeWalkIssued = false
                elseif nearest <= dynEmergency and os.clock() - snakeEmergencyAt >= 0.5 then
                    snakeEmergencyAt = os.clock()
                    cinderLog("fireSnake", string.format(
                        "[EMERGENCY REROUTE] snake %d tiles (threshold=%d) | was → %d,%d | player=%d,%d wall=%s(%d) len=%d",
                        nearest, dynEmergency, snakeWalkTarget.x, snakeWalkTarget.y,
                        playerPos.x, playerPos.y, wallName, wallDist, snakeLen))
                    snakeWalkTarget = nil
                    snakeWalkIssued = false
                end
            end

            -- Pick new target if needed
            if not snakeWalkTarget then
                local bestTile, bestScore = nil, -math.huge
                local bestSnakeDist, bestEdgeDist, bestCwAlign, bestPass = 0, 0, 0, 0

                for pass = 1, 2 do
                    -- Pass 1: tight to wall (edgeDist ≤ 3). Pass 2: allow up to 8.
                    local edgeLimit = (pass == 1) and 3 or 8
                    for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
                        local tp  = tile:getPosition()
                        local dpf = getDistanceBetween(playerPos, tp)
                        if dpf >= 2 and dpf <= dynMaxDist then
                            local isSnake = false
                            for _, sp in ipairs(snakeTiles) do
                                if sp.x == tp.x and sp.y == tp.y then isSnake = true; break end
                            end
                            if not isSnake and not (tile:getTopCreature() ~= nil) then
                                local snakeDist   = minDistToSnake(tp, snakeTiles)
                                local minClear    = nearest <= 2 and 3 or FIRE_SNAKE_MIN_CLEARANCE
                                if snakeDist >= minClear then
                                    local eN = tp.y - b.minY
                                    local eS = b.maxY - tp.y
                                    local eW = tp.x - b.minX
                                    local eE = b.maxX - tp.x
                                    local edgeDist = math.min(eN, eS, eW, eE)
                                    if edgeDist >= 0 and edgeDist <= edgeLimit then
                                        local cdx  = tp.x - playerPos.x
                                        local cdy  = tp.y - playerPos.y
                                        local cdLen = math.sqrt(cdx * cdx + cdy * cdy)
                                        local cwAlign = cdLen > 0
                                            and ((cdx / cdLen) * cwX + (cdy / cdLen) * cwY)
                                            or 0
                                        local score = snakeDist * 3
                                            + math.max(0, 8 - edgeDist) * 2
                                            + cwAlign * 20
                                        if score > bestScore and
                                           findPath(playerPos, tp, 10, { ignoreNonPathable = true })
                                        then
                                            bestScore    = score
                                            bestTile     = tp
                                            bestSnakeDist = snakeDist
                                            bestEdgeDist  = edgeDist
                                            bestCwAlign   = cwAlign
                                            bestPass      = pass
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if bestTile then break end
                end

                if bestTile then
                    snakeWalkTarget = bestTile
                    snakeWalkIssued = false
                    cinderLog("fireSnake", string.format(
                        "[TARGET] %d,%d | score=%.1f snakeDist=%d edgeDist=%d cwAlign=%.2f pass=%d | player=%d,%d wall=%s(%d) len=%d trigger=%d maxDist=%d",
                        bestTile.x, bestTile.y, bestScore,
                        bestSnakeDist, bestEdgeDist, bestCwAlign, bestPass,
                        playerPos.x, playerPos.y, wallName, wallDist,
                        snakeLen, dynTrigger, dynMaxDist))
                else
                    cinderLog("fireSnake", string.format(
                        "[NO TARGET] snakeDist=%d player=%d,%d wall=%s(%d) len=%d trigger=%d maxDist=%d",
                        nearest, playerPos.x, playerPos.y,
                        wallName, wallDist, snakeLen, dynTrigger, dynMaxDist))
                end
            end

            -- Issue walk (once per target, retry if stalled >1s)
            if snakeWalkTarget then
                if not snakeWalkIssued then
                    autoWalk(snakeWalkTarget, 10, { ignoreNonPathable = true })
                    snakeWalkIssued = true
                    snakeWalkAt     = os.clock()
                    cinderLog("fireSnake", string.format(
                        "[WALK] → %d,%d dist=%d snakeDist=%d wall=%s(%d)",
                        snakeWalkTarget.x, snakeWalkTarget.y,
                        getDistanceBetween(playerPos, snakeWalkTarget),
                        nearest, wallName, wallDist))
                elseif os.clock() - snakeWalkAt >= 1 then
                    local elapsed = os.clock() - snakeWalkAt
                    autoWalk(snakeWalkTarget, 10, { ignoreNonPathable = true })
                    snakeWalkAt = os.clock()
                    cinderLog("fireSnake", string.format(
                        "[WALK RETRY] → %d,%d dist=%d elapsed=%.1fs snakeDist=%d wall=%s(%d)",
                        snakeWalkTarget.x, snakeWalkTarget.y,
                        getDistanceBetween(playerPos, snakeWalkTarget),
                        elapsed, nearest, wallName, wallDist))
                end
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
                elseif os.clock() - blueFlameWalkAt >= 1 then
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

local function processPortalExit(outcome)
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

local effectIdsToDodge       = {78, 79, 80, 188}
local effectIdsSafe          = {575, 277, 404}
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
            if not isTileDangerous(tile)
               and not isTileRecentlyDangerous(tilePos)
               and not (tile:getTopCreature() ~= nil)
               and findPath(playerPos, tilePos, 15, dodgeFlags)
            then
                autoWalk(tilePos, 15, dodgeFlags)
                dodgeTargetPos = tilePos
                cinderLog(logKey, "Walking to safe tile at dist " .. distance .. " — " .. tilePos.x .. "," .. tilePos.y)
                CaveBot.delay(500)
                delay(500)
                return true
            end
        end
    end
    cinderLog(logKey, "WARNING: No safe tile found | nearby danger: " .. nearbyDanger ..
        " | blacklist: " .. blacklistSize .. " | pos: " .. playerPos.x .. "," .. playerPos.y)
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

        return  -- never enters firestorm logic
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
        return  -- still a bombs portal — never fall through to firestorm
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

    -- ── Firestorm / Soccer dodge ──────────────────────────────────────────────
    local _dodgeOk, _dodgeErr = pcall(function()
    local firestormDanger = hasDangerousEffect(playerTile) or hasDodgeAvoidItem(playerTile)
    local soccerDanger    = hasRedGem(playerTile)
    local currentDanger   = firestormDanger or soccerDanger
    local logKey          = soccerDanger and "soccerBall" or "firestorm"

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
                cinderLog(rerouteKey, "Destination " .. dodgeTargetPos.x .. "," .. dodgeTargetPos.y .. " became dangerous — re-routing")
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
                cinderLog("soccerBall", "Red gem at " .. playerPos.x .. "," .. playerPos.y .. " — dodging")
            elseif logKey == "firestorm" and not dodgeFirestormActive then
                dodgeFirestormActive  = true
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
                cinderLog("firestorm", "Firestorm cleared — safe at " .. playerPos.x .. "," .. playerPos.y)
            end
            if dodgeSoccerActive then
                dodgeSoccerActive = false
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
