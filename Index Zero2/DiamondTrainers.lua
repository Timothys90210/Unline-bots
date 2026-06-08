-- Diamond Trainers
-- Casts "exevo con" then (2s later) "exevo gran con hur" when trainers nearby and mana > threshold

local SPELL_ARROWS   = "exevo con"
local SPELL_DIAMOND  = "exevo gran con hur"
local MANA_THRESHOLD = 0.30  -- 30% of max mana
local trainerDetected = false
local castArrowsAt    = 0  -- timestamp after which diamond spell is allowed

local function hasTrainerNearby(range)
    if not range then range = 10 end
    for _, spec in pairs(getSpectators()) do
        if spec:isMonster() and (g_game.getClientVersion() < 960 or spec:getType() < 3) then
            local name = spec:getName():lower()
            if name:find("trainer") and distanceFromPlayer(spec:getPosition()) <= range then
                return true
            end
        end
    end
    return false
end

local diamondTrainers = macro(500, function()
    local hasTrainer = hasTrainerNearby(10)

    if not hasTrainer then
        trainerDetected = false
        castArrowsAt = 0
        return
    end

    if not trainerDetected then
        trainerDetected = true
        modules.game_textmessage.displayGameMessage("[DiamondTrainers] Trainer detected, casting " .. SPELL_ARROWS .. " then " .. SPELL_DIAMOND)
    end

    local mana = player:getMana()
    local maxMana = player:getMaxMana()
    if mana < maxMana * MANA_THRESHOLD then return end

    local now = os.time()

    if castArrowsAt == 0 then
        -- Step 1: cast conjure arrows and record when diamond spell becomes available
        g_game.talk(SPELL_ARROWS)
        castArrowsAt = now + 2
        return
    end

    if now >= castArrowsAt then
        -- Step 2: cast diamond arrows and reset so next cycle starts fresh
        g_game.talk(SPELL_DIAMOND)
        castArrowsAt = 0
    end
end)

addIcon("DiamondTrainers", { item = { id = 25757, count = 1 }, text = "Diamond Trainers" }, diamondTrainers)
