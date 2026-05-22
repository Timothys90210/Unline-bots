-- Diamond Trainers
-- Casts "exevo gran con hur" when trainer monsters are nearby and mana > 3000

local SPELL = "exevo gran con hur"
local MANA_THRESHOLD = 19000
local trainerDetected = false

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

local diamondTrainers = macro(2000, function()
    local hasTrainer = hasTrainerNearby(10)

    if not hasTrainer then
        trainerDetected = false
        return
    end

    if not trainerDetected then
        trainerDetected = true
        modules.game_textmessage.displayGameMessage("[DiamondTrainers] Trainer detected nearby, casting " .. SPELL)
    end

    local mana = player:getMana()
    if mana < MANA_THRESHOLD then return end

    g_game.talk(SPELL)
end)

addIcon("DiamondTrainers", { item = { id = 25757, count = 1 }, text = "Diamond Trainers" }, diamondTrainers)
