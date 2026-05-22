-- ─────────────────────────────────────────────────────────────────────────────
-- CinderEvent_FireSnake_v1.lua  —  BACKUP of original fire snake mechanic
-- ─────────────────────────────────────────────────────────────────────────────
-- Preserved: 2026-05-23
-- Estimated success rate: ~50–70%
--
-- WHY KEPT: This version had a solid success rate. The character did nothing
-- until the snake was within 4 tiles, then scored boundary tiles using
-- snakeDist + edgeDist heuristic. Circular boundary movement emerged naturally
-- from repeated scoring without any explicit clockwise logic. The main known
-- failure mode was straight-line running across the map when no valid wall tile
-- was found in pass 1, causing pass 2 to pick a far/central tile.
--
-- TO RESTORE: Copy the constants, state variables, resetState entries, and the
-- snake section back into CinderEvent.lua, replacing the v2 equivalents.
-- ─────────────────────────────────────────────────────────────────────────────


-- ── Constants (replace the v2 versions at the top of CinderEvent.lua) ────────

-- local FIRE_SNAKE_SAFE_DISTANCE = 4      -- sqm — trigger movement when snake within this range
-- local FIRE_SNAKE_MIN_CLEARANCE = 5      -- sqm — target tiles must be at least this far from snake

-- Arena boundary estimates (hardcoded — only accurate for one arena layout)
-- local ARENA_X_MIN = 6019
-- local ARENA_X_MAX = 6101
-- local ARENA_Y_MIN = 5039
-- local ARENA_Y_MAX = 5119


-- ── State variables (replace the v2 snake vars in CinderEvent.lua) ───────────

-- local fireSnakeSeenThisSession = false
-- local snakeLastLogAt           = 0
-- local snakeLastLengthLogAt     = 0
-- local snakeLastWallLogAt       = 0
-- local snakeHeadLastPos         = nil


-- ── resetState() entries ──────────────────────────────────────────────────────

--     fireSnakeSeenThisSession = false
--     snakeLastLogAt           = 0
--     snakeLastLengthLogAt     = 0
--     snakeLastWallLogAt       = 0
--     snakeHeadLastPos         = nil


-- ── Snake section inside cinderMacro (replaces the v2 snake block) ───────────

--[[

        -- ── Fire Snake mechanic ──────────────────────────────────────────────
        -- Moves continuously away from the snake when within 4 tiles.
        -- Targets edge tiles ~5 sqm from the nearest snake tile.
        local snakeTiles = getFireSnakeTiles(playerPos)
        if #snakeTiles > 0 then
            local clk = os.clock()

            if not fireSnakeSeenThisSession then
                fireSnakeSeenThisSession = true
                cinderLog("fireSnake", "Fire snake first detected — " .. #snakeTiles .. " tile(s) on floor")
            end

            -- Periodic: log snake length (every 3s)
            if clk - snakeLastLengthLogAt >= 3 then
                snakeLastLengthLogAt = clk
                cinderLog("fireSnake", "Snake length: " .. #snakeTiles .. " tile(s)")
            end

            -- Periodic: log player wall proximity (every 5s)
            if clk - snakeLastWallLogAt >= 5 then
                snakeLastWallLogAt = clk
                local wallDist = math.min(
                    math.abs(playerPos.x - ARENA_X_MIN), math.abs(ARENA_X_MAX - playerPos.x),
                    math.abs(playerPos.y - ARENA_Y_MIN), math.abs(ARENA_Y_MAX - playerPos.y)
                )
                cinderLog("fireSnake", "Player at " .. playerPos.x .. "," .. playerPos.y .. " — nearest arena wall: " .. wallDist .. " sqm")
            end

            local nearest = minDistToSnake(playerPos, snakeTiles)

            -- Detect head movement (nearest snake tile changed position)
            local head = nil
            local headDist = math.huge
            for _, sp in ipairs(snakeTiles) do
                local d = getDistanceBetween(playerPos, sp)
                if d < headDist then headDist, head = d, sp end
            end
            if head and (not snakeHeadLastPos or head.x ~= snakeHeadLastPos.x or head.y ~= snakeHeadLastPos.y) then
                snakeHeadLastPos = head
                cinderLog("fireSnake", "Head moved to " .. head.x .. "," .. head.y .. " — dist " .. headDist .. " from player")
            end

            if nearest == 0 then
                cinderLog("fireSnake", "EMERGENCY: standing on fire snake tile at " .. playerPos.x .. "," .. playerPos.y)
            end

            if nearest <= FIRE_SNAKE_SAFE_DISTANCE then
                if clk - snakeLastLogAt >= 2 then
                    snakeLastLogAt = clk
                    cinderLog("fireSnake", "Snake " .. nearest .. " sqm away — seeking edge tile")
                end

                -- Two-pass search: pass 1 requires edgeDist <= 5 (hugging the wall).
                -- Pass 2 falls back to any valid tile if no wall tile was found.
                local bestTile, bestScore, bestSnakeDist, bestEdgeDist = nil, -1, 0, 0
                for pass = 1, 2 do
                    for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
                        local tilePos        = tile:getPosition()
                        local distFromPlayer = getDistanceBetween(playerPos, tilePos)
                        if distFromPlayer >= 3 and distFromPlayer <= 6 then
                            local isSnake = false
                            for _, sp in ipairs(snakeTiles) do
                                if sp.x == tilePos.x and sp.y == tilePos.y then isSnake = true; break end
                            end
                            if not isSnake and not (tile:getTopCreature() ~= nil) then
                                local snakeDist = minDistToSnake(tilePos, snakeTiles)
                                if snakeDist >= FIRE_SNAKE_MIN_CLEARANCE and snakeDist <= 8 then
                                    local edgeDist = math.min(
                                        math.abs(tilePos.x - ARENA_X_MIN), math.abs(ARENA_X_MAX - tilePos.x),
                                        math.abs(tilePos.y - ARENA_Y_MIN), math.abs(ARENA_Y_MAX - tilePos.y)
                                    )
                                    -- Pass 1: only wall tiles; pass 2: any tile
                                    if pass == 1 and edgeDist > 5 then
                                        -- skip non-wall tiles in first pass
                                    else
                                        local score = snakeDist * 2 + math.max(0, 15 - edgeDist)
                                        if score > bestScore and
                                           findPath(playerPos, tilePos, 7, { ignoreNonPathable = true })
                                        then
                                            bestScore, bestTile  = score, tilePos
                                            bestSnakeDist, bestEdgeDist = snakeDist, edgeDist
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if bestTile then break end  -- wall tile found, no need for fallback pass
                end

                if bestTile then
                    local passNote = bestEdgeDist <= 5 and "" or " [fallback — no wall tile]"
                    cinderLog("fireSnake", "Moving to " .. bestTile.x .. "," .. bestTile.y ..
                        " (score:" .. math.floor(bestScore) ..
                        " snakeDist:" .. bestSnakeDist ..
                        " edgeDist:" .. bestEdgeDist .. passNote .. ")")
                    autoWalk(bestTile, 7, { ignoreNonPathable = true })
                    delay(300)
                else
                    cinderLog("fireSnake", "WARNING: No valid edge tile found — snake dist:" .. nearest ..
                        " tiles:" .. #snakeTiles .. " player:" .. playerPos.x .. "," .. playerPos.y)
                end
            end
            return
        end

--]]
