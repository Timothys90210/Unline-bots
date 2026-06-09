--Red boss mechanic = 108
--Blue boss mechanic = 80
--Green boss mechanic = 79

hotkey("F3", "Get items/effects Ids", function()
    local tile = getTileUnderCursor()
    if not tile then return end

    local function printIds(label, items)
        if #items > 0 then
            local ids = {}
            for _, item in ipairs(items) do
                table.insert(ids, item:getId())
            end
            warn(string.format("%s: %s", label, table.concat(ids, ", ")))
        end
    end

    printIds("Effects", tile:getEffects())
    printIds("Items", tile:getItems())
end)