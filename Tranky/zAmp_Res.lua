setDefaultTab("Main")
UI.Separator()

macro(1000, "Exana Amp Res", function()
    local distantCreatures = 0

    for _, spec in ipairs(getSpectators()) do
        if spec:isMonster() then
            local distance = distanceFromPlayer(spec:getPosition())

            if distance > 3 then
                distantCreatures = distantCreatures + 1
            end
        end
    end

    if distantCreatures > 3 then
        cast("exana amp res")
    end
end)