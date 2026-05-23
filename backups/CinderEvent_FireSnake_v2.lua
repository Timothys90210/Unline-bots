-- ─────────────────────────────────────────────────────────────────────────────
-- CinderEvent_FireSnake_v2.lua  —  BACKUP of fire snake mechanic (V2)
-- ─────────────────────────────────────────────────────────────────────────────
-- Preserved: 2026-05-23
-- Git commit: aac281f  "[WIP] Bombs, Flames working well - Fire snake needs tweaking"
-- NOTE: Two post-commit patches applied before this version was superseded by V4:
--   1. South wall fix: minClear = nearest <= dynTrigger and 3 or FIRE_SNAKE_MIN_CLEARANCE
--      (git has the older: nearest <= 2 and 3)
--   2. Retry overshoot fix: elseif ... and getDistanceBetween(playerPos, snakeWalkTarget) > 2
--      (git has the older: no dist guard)
-- Both patches are reflected in the code block below.
--
-- WHAT THIS VERSION IS:
-- Full V2 structure rewrite over V1. Introduced explicit clockwise motion via
-- CW tangent scoring, dynamic arena bounds, phase system (initial/idle/active),
-- adaptive scaling by snake length, emergency reroute, committed walk target,
-- pcall protection, and rich logging.
--
-- KNOWN WEAKNESSES (why V4 replaced it):
-- 1. cwAlign*20 dominates scoring — a CW tile with snakeDist=3 can outscore a
--    safer tile with snakeDist=8 if it's aligned clockwise. Safety overridden.
-- 2. Initial target hardcoded to 12 o'clock (centerX, minY) — sends character
--    north regardless of where the snake spawns. Dangerous if snake enters from
--    the north side.
-- 3. Failure Mode 2: snake entering from east causes CW tangent to initially
--    point east (toward snake) before curving south.
-- 4. edgeLimit pass1=3 was too tight — no snakeDist upper bound meant the
--    scoring could prefer far-wall tiles requiring arena crossing.
-- 5. No dist>2 retry guard (added in v3 patch before v4 replaced both).
--
-- TO RESTORE: Replace the fire snake section in CinderEvent.lua with this block.
-- Also restore constants/state vars if they differ (they were the same as v4).
-- ─────────────────────────────────────────────────────────────────────────────


--[[

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
                                local minClear    = nearest <= dynTrigger and 3 or FIRE_SNAKE_MIN_CLEARANCE
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
                elseif os.clock() - snakeWalkAt >= 1 and getDistanceBetween(playerPos, snakeWalkTarget) > 2 then
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

--]]
