local storageKey = "textDetectionLog"
storage[storageKey] = storage[storageKey] or {}

local pattern = "You have finished on wave"

onTextMessage(function(mode, text)
    local re = regexMatch(text, pattern)
    if #re ~= 0 then
        storage[storageKey].lastSeen = os.date("%Y-%m-%d %H:%M:%S")
        print("[TextLog] Matched at " .. storage[storageKey].lastSeen)
    end
end)

-- Create the overlay labels
local staminaLabel = UI.createWidget('UILabel', rootWidget)
local expHrLabel = UI.createWidget('UILabel', rootWidget)
local nextLvlLabel = UI.createWidget('UILabel', rootWidget)
local unlinedromeLabel = UI.createWidget('UILabel', rootWidget)

staminaLabel:setFont('verdana-11px-rounded')
staminaLabel:setPhantom(true)
expHrLabel:setFont('verdana-11px-rounded')
expHrLabel:setPhantom(true)
nextLvlLabel:setFont('verdana-11px-rounded')
nextLvlLabel:setPhantom(true)
unlinedromeLabel:setFont('verdana-11px-rounded')
unlinedromeLabel:setPhantom(true)

local xpHourWidget = rootWidget:recursiveGetChildById("xpPerHourLabel")
local nextLvlWidget = rootWidget:recursiveGetChildById("nextLevelIn")

local function updateUnlinedrome()
    local detectedAt = storage[storageKey].lastSeen
    if detectedAt then
        local detected = os.time({
            year  = tonumber(detectedAt:sub(1,4)),
            month = tonumber(detectedAt:sub(6,7)),
            day   = tonumber(detectedAt:sub(9,10)),
            hour  = tonumber(detectedAt:sub(12,13)),
            min   = tonumber(detectedAt:sub(15,16)),
            sec   = tonumber(detectedAt:sub(18,19)),
        })
        local readyAt = detected + (20 * 3600)
        local remaining = readyAt - os.time()

        if remaining <= 0 then
            unlinedromeLabel:setText("Unlinedrome: Ready")
            unlinedromeLabel:setColor("green")
        else
            local h = math.floor(remaining / 3600)
            local m = math.floor((remaining % 3600) / 60)
            unlinedromeLabel:setText(string.format("Unlinedrome: %02d:%02d", h, m))
            unlinedromeLabel:setColor("yellow")
        end
    else
        unlinedromeLabel:setText("Unlinedrome: --:--")
        unlinedromeLabel:setColor("white")
    end
    unlinedromeLabel:resizeToText()

    schedule(60000, updateUnlinedrome)
end

local function updateLabels()
    local screenSize = rootWidget:getSize()
    staminaLabel:move(math.floor(screenSize.width - 498), 95)
    expHrLabel:move(math.floor(screenSize.width - 498), 109)
    nextLvlLabel:move(math.floor(screenSize.width - 498), 122)
    unlinedromeLabel:move(math.floor(screenSize.width - 498), 135)

    local stamina = player:getStamina()
    local hours = math.floor(stamina / 60)
    local minutes = stamina % 60

    if stamina >= 2400 then
        staminaLabel:setColor("green")
    elseif stamina >= 840 then
        staminaLabel:setColor("yellow")
    else
        staminaLabel:setColor("red")
    end

    staminaLabel:setText(string.format("Stamina: %02d:%02d", hours, minutes))
    staminaLabel:resizeToText()
    expHrLabel:setText(string.format("Exp/hr: %s", xpHourWidget:getText()))
    expHrLabel:resizeToText()
    nextLvlLabel:setText(string.format("Next Lvl: %s", nextLvlWidget:getText()))
    nextLvlLabel:resizeToText()

    schedule(10000, updateLabels)
end

schedule(500, updateLabels)
schedule(500, updateUnlinedrome)