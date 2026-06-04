local autoMount = macro(5000, "Auto-Mount", function()
    if isInPz() then return end
    if not player:isMounted() then player:mount() end
end)

addIcon("AutoMount", { item = { id = 2998, count = 1 }, text = "Auto Mount" }, autoMount)

onPlayerPositionChange(function()
    if autoMount:isOff() then return end
    if isInPz() then return end
    if player:isMounted() then return end
    player:mount()
end)
