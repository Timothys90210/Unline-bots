-- Auto Spell Caster Script
-- Casts "exevo tempo mas san" consistently with no delays

-- Global flag to track if spell caster is enabled
local spellCasterEnabled = macro(1000, function() end)

-- Visual icon to activate/deactivate spell caster
addIcon("SpellCaster", { item = { id = 6561, count = 1 }, text = "Auto Spell" }, spellCasterEnabled)

-- Worker macro that casts the spell continuously
macro(23000, function()
    if spellCasterEnabled:isOff() then return end

    -- Cast spell with 4s delay
    say("utito tempo")
    --say("exana amp res")
end)
