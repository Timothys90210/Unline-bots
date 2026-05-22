setDefaultTab("BOSS")
UI.Separator()

local ring = {
    mightRingEquip   = 3048,  -- Might Ring
    energyRingEquip = 3051, -- Energy Ring
    hpMightEquip       = 75,    -- equip threshold
    hpEnergyEquip       = 60,    -- equip threshold
    ringUnequip = 3048, -- Other ring
    hpUnequip     = 95     -- unequip threshold
}

local lastRingSwap = 0

macro(200, "KEEP: Might/Energy", function()
    if now - lastRingSwap < 500 then return end

    local finger = getFinger()
    local currentId = finger and finger:getId() or 0
    local hp = hppercent()

    if hp <= ring.hpEnergyEquip and currentId ~= ring.energyRingEquip then
        g_game.equipItemId(ring.energyRingEquip)
        lastRingSwap = now
    elseif hp <= ring.hpMightEquip and currentId ~= ring.mightRingEquip then
        g_game.equipItemId(ring.mightRingEquip)
        lastRingSwap = now
    elseif hp >= ring.hpUnequip and currentId ~= ring.ringUnequip then
        g_game.equipItemId(ring.ringUnequip)
        lastRingSwap = now
    end
end)

local stoneSkinID = 3081
local lastAmuletEquip = 0

macro(200, "KEEP: Stone skin amulet", function()
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