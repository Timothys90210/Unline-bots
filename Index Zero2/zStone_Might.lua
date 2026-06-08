if zStoneMightLoaded then return end
zStoneMightLoaded = true

setDefaultTab("BOSS")
UI.Separator()

local mightRingID = 3048
local lastRingEquip = 0

macro(200, "Might Ring", function()
    local currentRing = getFinger()

    -- Check if the correct ring is already equipped
    if currentRing and currentRing:getId() == mightRingID then
        return -- Already equipped, do nothing
    end

    -- Prevent rapid re-equipping
    if os.time() - lastRingEquip < 2 then
        return
    end

    -- Equip the ring
    g_game.equipItemId(mightRingID)
    lastRingEquip = os.time()
end)

local stoneSkinID = 3081
local lastAmuletEquip = 0

SSA = macro(200, "Stone skin amulet", function()
    local currentAmulet = getNeck()

    -- Check if the correct amulet is already equipped
    if currentAmulet and currentAmulet:getId() == stoneSkinID then
        return -- Already equipped, do nothing
    end

    -- Prevent rapid re-equipping
    if os.time() - lastAmuletEquip < 2 then
        return
    end

    -- Equip the amulet
    g_game.equipItemId(stoneSkinID)
    lastAmuletEquip = os.time()
end)