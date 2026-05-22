setDefaultTab("Main")
UI.Separator()

local amulet = 3048
macro(100, "Might Ring", function() 
    if getFinger() == null or getFinger():getId() ~= amulet then
            g_game.equipItemId(amulet)
            delay(200)
    end
end)

local amuletID = 3081
SSA = macro(100, "Stone skin amulet", function()
    if getNeck() == nil or getNeck():getId() ~= amuletID then
      g_game.equipItemId(amuletID)
      delay(200)
    end
end)