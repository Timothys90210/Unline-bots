setDefaultTab("Main")
UI.Separator()

local BUFF_SPELL = "utito tempo san"
local CAST_INTERVAL = 8.5  -- seconds between casts
local lastCastTime = 0

macro(100, "Auto Buff", function()
    local now = os.time()

    -- Only cast if enough time has passed
    if now - lastCastTime >= CAST_INTERVAL then
        local player = g_game.getLocalPlayer()
        if player and player:getMana() >= 290 then  -- adjust mana cost if needed
            say(BUFF_SPELL)
            lastCastTime = now
        end
    end
end)