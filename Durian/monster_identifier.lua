--------------------------------- Monster Identifier --------------------------------------------
-- CaveBot state logging — shared with CinderEvent.lua (defined once via guard)
-- CaveBot diagnostic logging — disabled (no-ops while commented out)
-- To re-enable: uncomment this entire block and remove the stubs below
--[[
if not CaveBotStateLogDefined then
    CaveBotStateLogDefined = true
    local _cbConfigName = modules.game_bot.contentsPanel.config:getCurrentOption().text
    local _cbLogsDir    = "/bot/" .. _cbConfigName .. "/logs"
    local _cbDiagDir    = _cbLogsDir .. "/cavebot diagnostic"
    CaveBotOffLogPath   = nil  -- global: path of the currently open OFF episode

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

-- Stubs so call sites don't error while logging is disabled
if not CaveBotStateLogDefined then
    CaveBotStateLogDefined = true
    function logCaveBotOff(reason) end
    function logCaveBotOn(reason) end
    function logCaveBotSkipped(reason) end
end

-- Priority: Champion (emblem 3) > Elite (emblem 2) > Veteran (emblem 1) > Normal (0)
-- When emblem >= 1 creature found:
--   - Turns off CaveBot and TargetBot
--   - Attacks and holds that creature (re-attacks if temporarily lost)
--   - Marks with green outline (Hold Target style)
--   - Sets chase mode so player follows the creature
-- Restores all state when creature is gone
-- On kill: scans for orb effects and walks to collect them

local HOLD_COLOR = "#3EFF00"
local HOLD_ACTIVE_COLOR = "#FF1493"
local engagedId = nil
local markedCreature = nil
local savedCaveBotOn = false
local savedTargetBotOn = false
local cavebotRestoreAt = nil

-- Orb collection state
local orbFxIds       = {231, 544, 551, 552, 553}
local extraEffectIds = {
    18, 19, 20, 22, 23, 24, 25, 29, 30, 31, 89, 101, 154, 212, 214, 215, 216,
    499, 500, 501, 502, 503, 504, 505, 506,
    507, 508, 509, 510, 511, 512, 513, 514, 515,
    516, 517, 518, 519, 520, 521, 522, 523, 524,
    525, 526, 527, 528, 529, 530, 531, 532, 533, 534,
    535, 536, 537, 538, 539, 540, 541, 542
}
local initialOrbIds  = {210, 514, 515, 516, 517, 518}
local ORB_SCAN_WINDOW = 45
local orbScanAt = nil
local orbPauseEndTime = 0
local cavebotOffByOrb = false
local ORB_PAUSE_TIME = 4

local function hasEffect(tile, effectList)
    for _, fx in ipairs(tile:getEffects()) do
        for _, id in ipairs(effectList) do
            if fx:getId() == id then return true end
        end
    end
    return false
end

local function resumeBotsAfterOrb()
    if cavebotOffByOrb then
        CaveBot.setOn()
        logCaveBotOn("Orb event complete — orb collected or captured")
        cavebotOffByOrb = false
    end
    orbPauseEndTime = 0
end

local function clearMark()
    if markedCreature then
        pcall(function() markedCreature:setMarked("") end)
        markedCreature = nil
    end
end

local function markCreature(creature, color)
    color = color or HOLD_COLOR
    if creature == markedCreature then
        pcall(function() creature:setMarked(color) end)
        return
    end
    clearMark()
    markedCreature = creature
    pcall(function() creature:setMarked(color) end)
end

local function getMonsterPriority(creature)
    local ok, emblem = pcall(function() return creature:getEmblem() end)
    if not ok or not emblem then return 0 end
    return emblem
end

local function findBestSpecialMonster()
    local pos = player:getPosition()
    local specs = g_map.getSpectatorsInRange(pos, false, 10, 10)
    local best, bestPriority = nil, 0
    for _, creature in ipairs(specs) do
        pcall(function()
            if creature:isMonster() and not creature:isDead() then
                local cpos = creature:getPosition()
                if cpos and cpos.z == pos.z then
                    local p = getMonsterPriority(creature)
                    if p > bestPriority then
                        best, bestPriority = creature, p
                    end
                end
            end
        end)
    end
    return best, bestPriority
end

local function findCreatureById(id)
    for _, spec in ipairs(getSpectators()) do
        local ok, specId = pcall(function() return spec:getId() end)
        if ok and specId == id and spec:getPosition().z == posz() then
            return spec
        end
    end
    return nil
end

local function log(msg)
    modules.game_textmessage.displayGameMessage("[MonsterID] " .. msg)
end

local function engage(creature)
    savedCaveBotOn = CaveBot.isOn()
    savedTargetBotOn = TargetBot.isOn()
    engagedId = creature:getId()

    if savedCaveBotOn then CaveBot.setOff() end
    if savedTargetBotOn then TargetBot.setOff() end

    g_game.setChaseMode(1)
    g_game.attack(creature)
    markCreature(creature)

    local ok, name = pcall(function() return creature:getName() end)
    local emblem = getMonsterPriority(creature)
    local typeName = emblem == 3 and "Champion" or emblem == 2 and "Elite" or "Veteran"
    log("Engaging " .. typeName .. ": " .. (ok and name or "unknown"))
    if savedCaveBotOn then
        logCaveBotOff("Exalted " .. typeName .. " engaged: " .. (ok and name or "unknown"))
    end
end

local function disengage()
    engagedId = nil
    clearMark()
    g_game.setChaseMode(0)
    orbScanAt = os.clock()
    if savedTargetBotOn then TargetBot.setOn() end
    if savedCaveBotOn then
        cavebotRestoreAt = now + 5000
        log("Creature gone. Resuming TargetBot. CaveBot resumes in 5s.")
    else
        log("Creature gone. Resuming TargetBot.")
    end
end

-- Single macro — icon and button both control this
Orbes = macro(200, "Monster Identifier", function()
    if not player then return end
    local clk = os.clock()

    -- Resume CaveBot after orb spawn pause
    if orbPauseEndTime > 0 and clk >= orbPauseEndTime then
        resumeBotsAfterOrb()
    end

    -- Pending CaveBot restore after kill delay.
    -- Skip if CinderEvent has the portal active — it owns the CaveBot state until exit.
    if cavebotRestoreAt and now >= cavebotRestoreAt then
        cavebotRestoreAt = nil
        if not CinderPortalActive then
            CaveBot.setOn()
            logCaveBotOn("Exalted monster gone — 5s restore timer fired")
        else
            logCaveBotSkipped("5s restore timer fired but CinderPortalActive=true — CinderEvent owns CaveBot")
        end
    end

    if engagedId then
        local current = g_game.getAttackingCreature()
        if current then
            markCreature(current)
        else
            local found = findCreatureById(engagedId)
            if found then
                log("Re-attacking held target.")
                g_game.attack(found)
                markCreature(found, HOLD_ACTIVE_COLOR)
            else
                disengage()
            end
        end
    else
        local best, priority = findBestSpecialMonster()
        if best and priority > 0 then
            engage(best)
        end
    end

    -- Orb tile scan — only active after an exalted kill
    if not orbScanAt or (clk - orbScanAt) > ORB_SCAN_WINDOW then return end

    local playerPos = player:getPosition()
    for _, tile in ipairs(g_map.getTiles(playerPos.z)) do
        local pos = tile:getPosition()
        if getDistanceBetween(playerPos, pos) <= 8 then
            if hasEffect(tile, orbFxIds) and hasEffect(tile, extraEffectIds) then
                if findPath(playerPos, pos, 15, { ignoreNonPathable = true, precision = 1 }) then
                    autoWalk(pos, 15, { ignoreNonPathable = true, precision = 1 })
                    delay(2000)
                    return
                end
            elseif hasEffect(tile, initialOrbIds) then
                if findPath(playerPos, pos, 15, { ignoreNonPathable = true, precision = 1 }) then
                    autoWalk(pos, 15, { ignoreNonPathable = true, precision = 1 })
                    delay(2000)
                    return
                end
            end
        end
    end
end)

-- Icon linked to the same macro — clicking icon and clicking button are identical
addIcon("MonsterIdentifier", { item = { id = 3000, count = 1 }, text = "Monster Identifier" }, Orbes)

-- Pause CaveBot when orb spawn message fires
onTextMessage(function(mode, text)
    if text:lower():find("an orb has spawned, step on it to capture it.") then
        if CaveBot.isOn() then
            CaveBot.setOff()
            logCaveBotOff("Orb spawned — pausing for orb collection")
            cavebotOffByOrb = true
        end
        orbPauseEndTime = os.clock() + ORB_PAUSE_TIME
    end
end)

-- Stop scanning and resume on capture
onTextMessage(function(mode, text)
    local lowerText = text:lower()
    if lowerText:find("you have captured") or lowerText:find("you have absorbed an orb") then
        orbScanAt = nil
        if orbPauseEndTime > 0 then
            schedule(1000, function() resumeBotsAfterOrb() end)
        end
    end
end)
