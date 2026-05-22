-- Conjure Diamond
-- Casts SPELL every 5 seconds if mana > 30%

local SPELL = "exevo gran con hur"

local conjureDiamond = macro(5000, function()
    local mana = player:getMana()
    local maxMana = player:getMaxMana()
    if maxMana <= 0 then return end

    if mana / maxMana < 0.30 then return end

    g_game.talk(SPELL)
end)

addIcon("ConjureDiamond", { item = { id = 25757, count = 1 }, text = "Conjure Diamond" }, conjureDiamond)
