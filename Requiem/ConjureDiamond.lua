-- Conjure Diamond
-- Casts SPELL every 5 seconds if mana > 30% and no trainer is nearby

local SPELL = "exevo gran con hur"
local TRAINER_IDS = {29243, 31608}

local function isTrainerNearby(range)
    range = range or 10
    local playerPos = player:getPosition()
    for dx = -range, range do
        for dy = -range, range do
            local tile = g_map.getTile({x = playerPos.x + dx, y = playerPos.y + dy, z = playerPos.z})
            if tile then
                for _, item in ipairs(tile:getItems()) do
                    for _, id in ipairs(TRAINER_IDS) do
                        if item:getId() == id then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local conjureDiamond = macro(5000, function()
    if isTrainerNearby() then return end

    local mana = player:getMana()
    local maxMana = player:getMaxMana()
    if maxMana <= 0 then return end

    if mana / maxMana < 0.70 then return end

    g_game.talk(SPELL)
end)

addIcon("ConjureDiamond", { item = { id = 25757, count = 1 }, text = "Conjure Diamond" }, conjureDiamond)
