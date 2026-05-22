--Hide Floors

onPlayerPositionChange(function(pos)
    if storage.limitFloor then
        local gameMapPanel = modules.game_interface.getMapPanel()
        if gameMapPanel then gameMapPanel:lockVisibleFloor(pos.z) end
    end
end)
local switch = addSwitch("limitFloor", "Camera Floor Lock",
                         function(widget)
    widget:setOn(not widget:isOn())
    storage.limitFloor = widget:isOn()
    local gameMapPanel = modules.game_interface.getMapPanel()
    if gameMapPanel then
        if storage.limitFloor then
            gameMapPanel:lockVisibleFloor(posz())
        else
            gameMapPanel:unlockVisibleFloor()
        end
    end
end)
