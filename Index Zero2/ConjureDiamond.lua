-- Conjure Diamond
-- Casts SPELL every 5 seconds if mana > 30%

local SPELL = "exevo gran con hur"

local conjureDiamond = macro(5000, function()
    -- Yield the shared spell-group cooldown when movement matters: this conjure
    -- (exevo gran con hur) shares cooldown with utani mas hur, which is the
    -- paralyse-cure / haste spell. Skipping it while paralysed lets the cure fire
    -- immediately; skipping it inside a cinder portal keeps the haste free for
    -- portal movement. (Index One/Two/Zero, 2026-06-06.)
    if isParalyzed() then return end
    if CinderPortalActive then return end

    local mana = player:getMana()
    local maxMana = player:getMaxMana()
    if maxMana <= 0 then return end

    if mana / maxMana < 0.30 then return end

    g_game.talk(SPELL)
end)

addIcon("ConjureDiamond", { item = { id = 25757, count = 1 }, text = "Conjure Diamond" }, conjureDiamond)
