setDefaultTab("BOSS")
-- Amulet (SSA)
local amulet = {
    amuletEquip   = 3081,  -- SSA
    hpEquip       = 50,    -- equip threshold
    amuletUnequip = 61241, -- Cinder necklace
    hpUnequip     = 95     -- unequip threshold
}

local lastAmuletSwap = 0

macro(200, "SSA: Equip", function()
    if now - lastAmuletSwap < 500 then return end

    local neck = getNeck()
    local currentId = neck and neck:getId() or 0
    local hp = hppercent()

    if hp <= amulet.hpEquip and currentId ~= amulet.amuletEquip then
        g_game.equipItemId(amulet.amuletEquip)
        lastAmuletSwap = now
    elseif hp >= amulet.hpUnequip and currentId ~= amulet.amuletUnequip then
        g_game.equipItemId(amulet.amuletUnequip)
        lastAmuletSwap = now
    end
end)

-- Ring (Might Ring)
local ring = {
    mightRingEquip   = 3048,  -- Might Ring
    energyRingEquip = 3051, -- Energy Ring
    hpMightEquip       = 75,    -- equip threshold
    hpEnergyEquip       = 60,    -- equip threshold
    ringUnequip = 52478, -- Other ring
    hpUnequip     = 95     -- unequip threshold
}

local lastRingSwap = 0

macro(200, "Might: Equip", function()
    if now - lastRingSwap < 500 then return end

    local finger = getFinger()
    local currentId = finger and finger:getId() or 0
    local hp = hppercent()

    if hp <= ring.hpMightEquip and currentId ~= ring.mightRingEquip then
        g_game.equipItemId(ring.mightRingEquip)
        lastRingSwap = now
    elseif hp >= ring.hpUnequip and currentId ~= ring.ringUnequip then
        g_game.equipItemId(ring.ringUnequip)
        lastRingSwap = now
    end
end)

macro(200, "Energy: Equip", function()
    if now - lastRingSwap < 500 then return end

    local finger = getFinger()
    local currentId = finger and finger:getId() or 0
    local hp = hppercent()

    if hp <= ring.hpEnergyEquip and currentId ~= ring.energyRingEquip then
        g_game.equipItemId(ring.energyRingEquip)
        lastRingSwap = now
    elseif hp >= ring.hpUnequip and currentId ~= ring.ringUnequip then
        g_game.equipItemId(ring.ringUnequip)
        lastRingSwap = now
    end
end)