-- Define la lista de objetos y cantidades
-- local itemList = {
    -- {20, 10304},
    -- {25, 9638},
    -- {25, 9639},
    -- {10, 22728},
    -- {40, 11444},
    -- {50, 10311},
    -- {5, 9663},
    -- {25, 9685},
    -- {15, 9633},
    -- {5, 14012},
    -- {25, 10295},
    -- {15, 10307},
-- }

if type(storage.imbueItem1) ~= "table" then
  storage.imbueItem1 = {item=9685, max = 25}
end

if type(storage.imbueItem2) ~= "table" then
  storage.imbueItem2 = {item = 9633, max = 15}
end

if type(storage.imbueItem3) ~= "table" then
  storage.imbueItem3 = {item = 9663, max = 5}
end

-- // Icon image (ID) that will display
local iconImageID = 25183

-- // We add the icon to the screen
addIcon("TakeImbuis",
-- // Get get the item ID from the previous local and we make the icon movable with CNTRL + Drag
{item=iconImageID, movable=true,
-- // We add the text we want to the icon, so we know
text = "TakeImbuis"},
-- // Then we add the macro for the function
macro(500, "Move Items", function()
    local allItemsMoved = true  -- Variable para verificar si se han movido todos los objetos necesarios
    
    -- Itera sobre la lista de objetos y cantidades
    for _, itemData in ipairs({storage.imbueItem1,storage.imbueItem2,storage.imbueItem3}) do
        local quantityToMove = itemData.max
        local itemId = itemData.item
        
        local foundCount = 0
        local itemMoved = false  -- Variable para verificar si se ha movido el objeto en esta iteraciÃ³n
        
        -- Busca el objeto en los contenedores
        for _, container in pairs(g_game.getContainers()) do
            for _, item in ipairs(container:getItems()) do
                if item:getId() == itemId then
                    foundCount = foundCount + item:getCount()
                    if foundCount >= quantityToMove and not itemMoved then
                        -- Mueve la cantidad necesaria al primer contenedor abierto
                        local firstContainer = g_game.getContainers()[0]
						
						local moveQty = quantityToMove - itemAmount(itemId)
						
						print(moveQty)
						
                        if firstContainer then
							if moveQty > 0 then
						
								g_game.move(item, firstContainer:getSlotPosition(firstContainer:getItemsCount()), quantityToMove)
								itemMoved = true
							elseif moveQty < 0 then
							
								print("error")
								return true
							end
                        else
                            print("No se encontraron contenedores abiertos.")
                            allItemsMoved = false
                        end
                    elseif not itemMoved then
                        -- Mueve todos los objetos que encuentra, pero no es suficiente para completar la cantidad requerida
                        local firstContainer = g_game.getContainers()[0]
                        if firstContainer then
                            g_game.move(item, firstContainer, item:getCount())
                            itemMoved = true
                        else
                            print("No se encontraron contenedores abiertos.")
                            allItemsMoved = false
                        end
                    end
                end
            end
        end
    end
    
    -- Verificar si todos los objetos se han movido
    if allItemsMoved then
        return false
    else
        return "retry"
    end
end))