setDefaultTab("Cave")
UI.Separator()

wepLabel = UI.Label("Bot Tools")
check = false

macro(100, "Bot off if no bless", function()
    if player:getBlessings() == 0 then
    if CaveBot.isOn() or TargetBot.isOn() then
            CaveBot.setOff()
            TargetBot.setOff()
            return true
        end
    end
end)

