setDefaultTab("Hunt")

local state = {
    MS_enabled = false,
    ED_enabled = false,
    EK_enabled = false,
    RP_enabled = false,
    Ninja_enabled = false,
    configureSpellsWindow = nil
}

-- ### SPELLDATABASE ###
local spells = {
    -- Master Sorcerer Spells
    MS = {
        { name="Flame Strike", incantation="exori flam", mana=10, level=8, cooldown=2000, range=5 },
        { name="Ice Strike", incantation="exori frigo", mana=10, level=8, cooldown=2000, range=5 },
        { name="Terra Strike", incantation="exori tera", mana=10, level=8, cooldown=2000, range=5 },
        { name="Energy Strike", incantation="exori vis", mana=10, level=8, cooldown=2000, range=5 },
        { name="Death Strike", incantation="exori mort", mana=20, level=16, cooldown=2000, range=5 },
        { name="Fire Wave", incantation="exevo flam hur", mana=25, level=18, cooldown=4000, range=5 },
        { name="Energy Beam", incantation="exevo vis lux", mana=40, level=23, cooldown=4000, range=5 },
        { name="Great Energy Beam", incantation="exevo gran vis lux", mana=110, level=29, cooldown=6000, range=5 },
        { name="Energy Wave", incantation="exevo vis hur", mana=170, level=30, cooldown=4000, range=5 },
        { name="Explosion Beam", incantation="exevo gran vis", mana=600, level=40, cooldown=4000, range=5 },
        { name="Great Fire Wave", incantation="exevo gran flam hur", mana=160, level=50, cooldown=4000, range=5 },
        { name="Strong Energy Strike", incantation="exori gran vis", mana=80, level=50, cooldown=6000, range=5 },
        { name="Rage of the Skies", incantation="exevo gran mas vis", mana=400, level=55, cooldown=6000, range=5 },
        { name="Hell's Core", incantation="exevo gran mas flam", mana=450, level=60, cooldown=6000, range=5 },
        { name="Armageddon", incantation="exevo gran mas mort", mana=2000, level=80, cooldown=20000, range=5 },
        { name="Apocalypse", incantation="exevo gran mas vis lux", mana=800, level=100, cooldown=20000, range=5 },
        { name="Shadow Drown", incantation="adana sio vis", mana=140, level=100, cooldown=6000, range=5 },
        { name="Ultimate Energy Strike", incantation="exori max vis", mana=120, level=100, cooldown=10000, range=5 },
        { name="Great Death Beam", incantation="exevo max mort", mana=140, level=300, cooldown=6000, range=5 }
    },
    -- Druid Spells
    ED = {
        { name="Terra Strike", incantation="exori tera", mana=10, level=8, cooldown=2000, range=5 },
        { name="Flame Strike", incantation="exori flam", mana=10, level=8, cooldown=2000, range=5 },
        { name="Ice Strike", incantation="exori frigo", mana=10, level=8, cooldown=2000, range=5 },
        { name="Energy Strike", incantation="exori vis", mana=10, level=8, cooldown=2000, range=5 },
        { name="Physical Strike", incantation="exori moe ico", mana=20, level=16, cooldown=2000, range=5 },
        { name="Ice Wave", incantation="exevo frigo hur", mana=25, level=18, cooldown=4000, range=5 },
        { name="Terra Wave", incantation="exevo tera hur", mana=210, level=30, cooldown=4000, range=5 },
        { name="Terra Beam", incantation="exevo gran tera", mana=600, level=40, cooldown=4000, range=5 },
        { name="Strong Ice Strike", incantation="exori gran frigo", mana=80, level=50, cooldown=6000, range=5 },
        { name="Strong Terra Strike", incantation="exori gran tera", mana=80, level=50, cooldown=6000, range=5 },
        { name="Wrath of Nature", incantation="exevo gran mas tera", mana=400, level=55, cooldown=6000, range=5 },
        { name="Strong Ice Wave", incantation="exevo gran frigo hur", mana=270, level=60, cooldown=8000, range=5 },
        { name="Eternal Winter", incantation="exevo gran mas frigo", mana=450, level=60, cooldown=6000, range=5 },
        { name="Fury of Nature", incantation="exevo gran gran tera", mana=2000, level=100, cooldown=20000, range=5 },
        { name="Ultimate Ice Strike", incantation="exori max frigo", mana=120, level=100, cooldown=10000, range=5 },
        { name="Ultimate Terra Strike", incantation="exori max tera", mana=120, level=100, cooldown=10000, range=5 },
        { name="Ice Burst", incantation="exevo ulus frigo", mana=230, level=300, cooldown=22000, range=5 }
    },
    -- Knight Spells
    EK = {
        { name="Whirlwind Throw", incantation="exori hur", mana=10, level=8, cooldown=2000, range=5 },
        { name="Brutal Strike", incantation="exori ico", mana=30, level=16, cooldown=4000, range=1 },
        { name="Challenge", incantation="exeta res", mana=30, level=20, cooldown=2000, range=1 },
        { name="Chivalrous Challenge", incantation="exeta amp res", mana=30, level=20, cooldown=7000, range=5 },
        { name="Berserk", incantation="exori", mana=115, level=30, cooldown=2000, range=1 },
        { name="Groundshaker", incantation="exori mas", mana=160, level=33, cooldown=6000, range=1 },
        { name="Stunning Whirlwind", incantation="exeta hur", mana=240, level=55, cooldown=10000, range=5 },
        { name="Front Sweep", incantation="exori min", mana=200, level=70, cooldown=4000, range=1 },
        { name="Fierce Berserk", incantation="exori gran", mana=340, level=90, cooldown=4000, range=1 },
        { name="Great Berserk", incantation="uber exori", mana=0, manaPercent=60, level=100, cooldown=5000, range=1 },
        { name="Annihilation", incantation="exori gran ico", mana=325, level=110, cooldown=15000, range=1 },
        { name="Executioners Throw", incantation="exori amp kor", mana=225, level=300, cooldown=2000, range=4 }
    },
    -- Paladin Spells
    RP = {
        { name="Ethereal Spear", incantation="exori con", mana=10, level=8, cooldown=2000, range=7 },
        { name="Divine Missile", incantation="exori san", mana=20, level=40, cooldown=2000, range=7 },
        { name="Arrow Shower", incantation="exori mas con", mana=220, level=50, cooldown=10000, range=7 },
        { name="Divine Caldera", incantation="exevo mas san", mana=100, level=50, cooldown=4000, range=5 },
        { name="Sidewinder", incantation="exevo vis", mana=0, manaPercent=20, level=60, cooldown=8000, range=7 },
        { name="Sharpshooter", incantation="utito tempo san", mana=450, level=60, cooldown=10000, range=7 },
        { name="Strong Ethereal Spear", incantation="exori gran con", mana=55, level=90, cooldown=6000, range=7 },
        { name="Arrow Repel", incantation="exori con ani", mana=200, level=100, cooldown=4000, range=1 },
        { name="Divine Empowerment", incantation="utevo grav san", mana=500, level=300, cooldown=10000, range=1 },
        { name="Divine Grenade", incantation="exevo tempo mas san", mana=160, level=300, cooldown=10000, range=7 }
    },
    -- Ninja Spells
    Ninja = {
        { name="Lightspeed Attack", incantation="exevo lux velox", mana=280, level=30, cooldown=4000, range=1 },
        { name="Rage Blow", incantation="exori cruentus", mana=200, level=35, cooldown=4000, range=1 },
        { name="Napalm Burst", incantation="ignis rumptur", mana=450, level=45, cooldown=8000, range=1 },
        { name="Repel Stars", incantation="exevo extra lumen", mana=400, level=50, cooldown=10000, range=1 },
        { name="Magnetic Stars", incantation="exevo intra lumen", mana=400, level=50, cooldown=10000, range=1 },
        { name="Heavy Rage Blow", incantation="exori mas cruentus", mana=1200, level=100, cooldown=8000, range=1 },
        { name="Restraining Knives", incantation="utevo mas chain", mana=1100, level=150, cooldown=10000, range=1 },
        -- ÄNDRAD: mana=0 för Fire Thrower och Ripped Heart
        { name="Fire Thrower", incantation="utevo ignis fiamma", mana=0, manaPercent=25, level=200, cooldown=4000, range=1 },
        { name="Ripped Heart", incantation="pectus cruentus", mana=0, manaPercent=75, level=200, cooldown=20000, range=1 }
    }
}

-- Sort all spell lists by level and then alphabetically
for _, spellList in pairs(spells) do
    table.sort(spellList, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        return a.name < b.name
    end)
end

-- ### STORAGE ###
storage.autoSpellPriorities = storage.autoSpellPriorities or {}
storage.autoSpellCounts = storage.autoSpellCounts or {}
storage.petName = storage.petName or ""

-- ### UI-BUTTONS ###
UI.Separator()

local autoSpellMSButton = macro(20, "AutoSpell MS", function() end)
autoSpellMSButton.setOn(storage.MS_enabled or false)

local autoSpellEDButton = macro(20, "AutoSpell ED", function() end)
autoSpellEDButton.setOn(storage.ED_enabled or false)

local autoSpellEKButton = macro(20, "AutoSpell EK", function() end)
autoSpellEKButton.setOn(storage.EK_enabled or false)

local autoSpellRPButton = macro(20, "AutoSpell RP", function() end)
autoSpellRPButton.setOn(storage.RP_enabled or false)

local autoSpellNinjaButton = macro(20, "AutoSpell Ninja", function() end)
autoSpellNinjaButton.setOn(storage.Ninja_enabled or false)

UI.Separator()

local configureSpellsMSButton = UI.Button("Configure MS Spells")
local configureSpellsEDButton = UI.Button("Configure ED Spells")
local configureSpellsEKButton = UI.Button("Configure EK Spells")
local configureSpellsRPButton = UI.Button("Configure RP Spells")
local configureSpellsNinjaButton = UI.Button("Configure Ninja Spells")

local function updateButtonStates()
    state.MS_enabled = autoSpellMSButton:isOn()
    storage.MS_enabled = state.MS_enabled
    configureSpellsMSButton:setVisible(state.MS_enabled)

    state.ED_enabled = autoSpellEDButton:isOn()
    storage.ED_enabled = state.ED_enabled
    configureSpellsEDButton:setVisible(state.ED_enabled)

    state.EK_enabled = autoSpellEKButton:isOn()
    storage.EK_enabled = state.EK_enabled
    configureSpellsEKButton:setVisible(state.EK_enabled)

    state.RP_enabled = autoSpellRPButton:isOn()
    storage.RP_enabled = state.RP_enabled
    configureSpellsRPButton:setVisible(state.RP_enabled)

    state.Ninja_enabled = autoSpellNinjaButton:isOn()
    storage.Ninja_enabled = state.Ninja_enabled
    configureSpellsNinjaButton:setVisible(state.Ninja_enabled)
end

-- Call updateButtonStates periodically to sync state
macro(100, function()
    updateButtonStates()
end)

local function openConfigureWindow(vocationToDisplay)
    local window = state.configureSpellsWindow
    if window and not window:isDestroyed() then
        window:raise()
        window:focus()
        return
    end

    window = g_ui.createWidget('CombinedAutoSpellWindow', g_ui.getRootWidget())
    if not window then
        return print("Error: Failed to create CombinedAutoSpellWindow. Check your .otui file!")
    end
    state.configureSpellsWindow = window

    local petNameEdit = window:recursiveGetChildById('name')
    if petNameEdit then
        petNameEdit:setText(storage.petName)
    end
    
    local allPanels = {
      msSpellsPanel = window:recursiveGetChildById('msSpellsPanel'),
      edSpellsPanel = window:recursiveGetChildById('edSpellsPanel'),
      ekSpellsPanel = window:recursiveGetChildById('ekSpellsPanel'),
      rpSpellsPanel = window:recursiveGetChildById('rpSpellsPanel'),
      ninjaSpellsPanel = window:recursiveGetChildById('ninjaSpellsPanel')
    }

    for _, panel in pairs(allPanels) do
        panel:setVisible(false)
    end
    allPanels[vocationToDisplay:lower() .. "SpellsPanel"]:setVisible(true)

    for vocation, spellList in pairs(spells) do
        for _, spell in ipairs(spellList) do
            -- Notera: Lua-koden använder gsub(" ", "_") på incantation för att skapa ID:n,
            -- vilket är samma format som används i Autospell.otui.
            local spellId = spell.incantation:gsub(" ", "_")
            
            -- Använd unika ID:n för att hitta rätt UI-element
            local uniqueSpellId = vocation:lower() .. "_" .. spellId
            
            local btn = window:recursiveGetChildById(uniqueSpellId.."_toggle")
            local prioSpin = window:recursiveGetChildById(uniqueSpellId.."_priority_1")
            local countSpin = window:recursiveGetChildById(uniqueSpellId.."_priority_2")

            if btn and prioSpin and countSpin then
                storage.autoSpellPriorities[vocation] = storage.autoSpellPriorities[vocation] or {}
                storage.autoSpellCounts[vocation] = storage.autoSpellCounts[vocation] or {}

                storage.autoSpellPriorities[vocation][spell.incantation] = storage.autoSpellPriorities[vocation][spell.incantation] or 1
                storage.autoSpellCounts[vocation][spell.incantation] = storage.autoSpellCounts[vocation][spell.incantation] or 1
                
                local prio = storage.autoSpellPriorities[vocation][spell.incantation]
                local count = storage.autoSpellCounts[vocation][spell.incantation]

                prioSpin:setValue(prio)
                countSpin:setValue(count)
                
                local function updateButtonColor()
                    local currentPrio = storage.autoSpellPriorities[vocation][spell.incantation] or 0
                    btn:setOn(currentPrio > 0)
                    btn:setColor(currentPrio > 0 and "#00ff00" or "#ff0000")
                end
                updateButtonColor()

                btn.onClick = function()
                    local currentPrio = storage.autoSpellPriorities[vocation][spell.incantation] or 0
                    storage.autoSpellPriorities[vocation][spell.incantation] = (currentPrio > 0) and 0 or 1
                    updateButtonColor()
                end

                prioSpin.onValueChange = function(widget, value)
                    storage.autoSpellPriorities[vocation][spell.incantation] = value
                    updateButtonColor()
                end

                countSpin.onValueChange = function(widget, value)
                    storage.autoSpellCounts[vocation][spell.incantation] = value
                end
            end
        end
    end

    window.ok.onClick = function()
        if petNameEdit then
            storage.petName = petNameEdit:getText():trim():lower()
        end
        window:destroy()
        state.configureSpellsWindow = nil
    end
    window.cancel.onClick = function()
        window:destroy()
        state.configureSpellsWindow = nil
    end
    window.onEscape = window.cancel.onClick

    window:show()
    window:raise()
    window:focus()
end

configureSpellsMSButton.onClick = function() openConfigureWindow("MS") end
configureSpellsEDButton.onClick = function() openConfigureWindow("ED") end
configureSpellsEKButton.onClick = function() openConfigureWindow("EK") end
configureSpellsRPButton.onClick = function() openConfigureWindow("RP") end
configureSpellsNinjaButton.onClick = function() openConfigureWindow("Ninja") end

-- ### HELPER FUNCTIONS ###
local function countMonsters(range)
    local player = g_game.getLocalPlayer()
    if not player then return 0 end
    local count = 0
    local ignoreName = storage.petName or ""
    if ignoreName == "" then ignoreName = "------" end
    local creatures = g_map.getSpectatorsInRange(player:getPosition(), false, range, range)
    if not creatures then return 0 end
    for _, c in ipairs(creatures) do
        if c:isMonster() and c:getName():lower() ~= ignoreName then
            count = count + 1
        end
    end
    return count
end

-- REVIDERAD FUNKTION: hanterar nu stavningar med manaPercent
local function canCast(spell, playerLevel, playerMana, playerMaxMana, vocation) -- Lagt till playerMaxMana
    local priorities = storage.autoSpellPriorities[vocation]
    if not priorities then return false end

    local priority = priorities[spell.incantation] or 0
    if priority == 0 then return false end
    if playerLevel < spell.level then return false end

    local requiredMana = spell.mana or 0
    
    -- Beräkna X (mana i poäng) från manaPercent om det är definierat
    if spell.manaPercent and playerMaxMana and playerMaxMana > 0 then
        -- math.floor säkerställer att vi avrundar nedåt för att undvika överdriven precision
        local percentCost = math.floor(playerMaxMana * (spell.manaPercent / 100))
        requiredMana = requiredMana + percentCost
    end
    
    -- Kontrollera den totala råa mana-kostnaden (fast + procentuell) mot nuvarande mana
    if playerMana < requiredMana then return false end 

    if (os.clock()*1000 - (spell.lastCast or 0)) < spell.cooldown then return false end
    if countMonsters(spell.range or 7) < (storage.autoSpellCounts[vocation][spell.incantation] or 1) then return false end
    return true
end

local function castSpell(spell)
    say(spell.incantation)
    spell.lastCast = os.clock()*1000
end

-- ### MACRO ###
macro(500, function()
    local player = g_game.getLocalPlayer()
    if not player then return end

    local playerLevel = player:getLevel()
    local playerMana = player:getMana()
    -- NY: Hämta Max Mana för korrekt procentuell beräkning
    local playerMaxMana = player:getMaxMana() -- OBS: Antar att denna funktion finns tillgänglig

    -- Check enabled vocations in a fixed order
    local vocations = {"MS", "ED", "EK", "RP", "Ninja"}
    
    for _, vocationKey in ipairs(vocations) do
        if state[vocationKey .. "_enabled"] then
            local castable = {}
            for _, spell in ipairs(spells[vocationKey]) do
                -- Uppdaterat anrop för att inkludera playerMaxMana
                if canCast(spell, playerLevel, playerMana, playerMaxMana, vocationKey) then
                    table.insert(castable, spell)
                end
            end
        
            if #castable > 0 then
                table.sort(castable, function(a,b)
                    local pa = storage.autoSpellPriorities[vocationKey][a.incantation] or 0
                    local pb = storage.autoSpellPriorities[vocationKey][b.incantation] or 0
                    if pa ~= pb then return pa > pb end
                    return a.level > b.level
                end)
                castSpell(castable[1])
                break -- Stop after casting a spell from one vocation
            end
        end
    end
end)