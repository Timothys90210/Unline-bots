local lastExori = 0

macro(500, "Gran Tera", function()
    local monsters = 0
    for _, spec in ipairs(getSpectators()) do
        if spec:isMonster() and distanceFromPlayer(spec:getPosition()) == 1 then
            monsters = monsters + 1
        end
    end
    if monsters >= 3 and (now - lastExori > 10) then
        say("exevo gran gran tera")
        lastExori = now
    end
end)