-- Auto Spell Caster Script
-- Casts "exevo tempo mas san" consistently with no delays

-- Global flag to track if spell caster is enabled
local spellCasterEnabled = macro(1000, function() end)

local function hasTrainerNearby(range)
    if not range then range = 10 end
    for _, spec in pairs(getSpectators()) do
        if spec:isMonster() and (g_game.getClientVersion() < 960 or spec:getType() < 3) then
            local name = spec:getName():lower()
            local dist = distanceFromPlayer(spec:getPosition())
            if name:find("trainer") and dist and dist <= range then
                return true
            end
        end
    end
    return false
end

local function hasItemNearby(itemId, range)
    if not range then range = 10 end
    local pos = player:getPosition()
    for x = pos.x - range, pos.x + range do
        for y = pos.y - range, pos.y + range do
            local tile = g_map.getTile({x=x, y=y, z=pos.z})
            if tile then
                for _, item in ipairs(tile:getItems()) do
                    if item:getId() == itemId then return true end
                end
            end
        end
    end
    return false
end

local diamondTrainers = macro(2000, function()
    local hasTrainer = hasTrainerNearby(10)

    if not hasTrainer then
        trainerDetected = false
        return
    end

    if not trainerDetected then
        trainerDetected = true
        modules.game_textmessage.displayGameMessage("[DivineGrenade] Trainer detected nearby, turning off DivineGrenade.lua casting")
    end
end)


-- Visual icon to activate/deactivate spell caster
addIcon("SpellCaster", { item = { id = 6561, count = 1 }, text = "Auto Spell" }, spellCasterEnabled)

-- Worker macro that casts the spell continuously
macro(500, function()
    if spellCasterEnabled:isOff() then return end

    if not g_game.isAttacking() then return end

    if hasTrainerNearby(10) or hasItemNearby(29243, 10) then
        return
    end

    -- Cast spell with 4s delay
    say("exevo tempo mas san")
    --say("exana amp res")
end)
