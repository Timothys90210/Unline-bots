-- Probe.lua: Trade window investigation tools
if ProbeLoaded then return end
ProbeLoaded = true

local listening   = false
local actionLines = {}   -- output captured during current button action
local logBuffer   = {}   -- all lines written to the current log file
local configName  = modules.game_bot.contentsPanel.config:getCurrentOption().text
local logsDir     = "/bot/" .. configName .. "/logs"
local currentLogPath = nil

-- Find next non-colliding probe log path
local function nextLogPath()
    if not g_resources.directoryExists(logsDir) then
        g_resources.makeDir(logsDir)
    end
    local n = 1
    local path
    repeat
        path = logsDir .. "/probe_" .. n .. ".log"
        n = n + 1
    until not g_resources.fileExists(path)
    return path
end

-- Write the full buffer to disk (overwrite = full in-memory append)
local function flushLog()
    if currentLogPath then
        g_resources.writeFileContents(currentLogPath, table.concat(logBuffer, "\n") .. "\n")
    end
end

-- Append lines from an action into the current log file
local function commitAction(label, lines)
    logBuffer[#logBuffer + 1] = "[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. label
    for _, line in ipairs(lines) do
        logBuffer[#logBuffer + 1] = "  " .. line
    end
    logBuffer[#logBuffer + 1] = ""  -- blank line between actions
    flushLog()
end

-- Start the first log file
currentLogPath = nextLogPath()

-- Output: warns immediately + captures for log
local function out(text)
    text = tostring(text)
    warn("[PROBE] " .. text)
    actionLines[#actionLines + 1] = text
end

-- Wrap a button action: collect output then commit to log
local function run(label, fn)
    actionLines = {}
    local ok, err = pcall(fn)
    if not ok then out("ERROR: " .. tostring(err)) end
    commitAction(label, actionLines)
end

setDefaultTab("Probe")

UI.Button("Save Logs", function()
    -- Seal current file and start fresh increment
    local sealed = currentLogPath
    currentLogPath = nextLogPath()
    logBuffer = {}
    warn("[PROBE] Sealed: " .. tostring(sealed))
    warn("[PROBE] New log: " .. tostring(currentLogPath))
end)

UI.Separator()
UI.Label("-- g_game Trade Functions --")
UI.Separator()

UI.Button("Probe Trade Methods", function()
    run("probe_trade_methods", function()
        local methods = {
            "acceptTrade", "rejectTrade", "requestTrade",
            "inspectTrade", "getOffer", "getCounterOffer",
            "closeTrade", "getTradeItem", "hasTradeItem",
        }
        for _, m in ipairs(methods) do
            out(m .. " = " .. type(g_game[m]))
        end
    end)
end)

UI.Button("Probe Move Methods", function()
    run("probe_move_methods", function()
        local methods = {
            "move", "moveToInventory", "moveItemToInventory",
            "moveToFreeSlot", "pickupItem", "pickupItemToSlot",
            "dropItem", "sendMoveItem", "equipItem",
            "openContainer", "browseField", "counterTrade",
            "cancelTrade", "getTradeState", "isTrading",
            "useWith", "use", "useItem",
        }
        for _, m in ipairs(methods) do
            out(m .. " = " .. type(g_game[m]))
        end
    end)
end)

UI.Button("Accept Trade", function()
    run("accept_trade", function()
        g_game.acceptTrade()
        out("acceptTrade() sent")
    end)
end)

UI.Button("Reject Trade", function()
    run("reject_trade", function()
        g_game.rejectTrade()
        out("rejectTrade() sent")
    end)
end)

UI.Button("Inspect Trade Slot 0 (my offer)", function()
    run("inspect_trade_slot0_mine", function()
        g_game.inspectTrade(false, 0)
        out("inspectTrade(false, 0) sent")
    end)
end)

UI.Button("Inspect Trade Slot 0 (counter)", function()
    run("inspect_trade_slot0_counter", function()
        g_game.inspectTrade(true, 0)
        out("inspectTrade(true, 0) sent")
    end)
end)

UI.Button("Inspect Trade Slots 1-5", function()
    run("inspect_trade_slots_1_5", function()
        for i = 1, 5 do
            pcall(function()
                g_game.inspectTrade(false, i)
                out("inspectTrade(false, " .. i .. ") sent")
            end)
            pcall(function()
                g_game.inspectTrade(true, i)
                out("inspectTrade(true, " .. i .. ") sent")
            end)
        end
    end)
end)

UI.Button("Inject Item Into Trade Slot", function()
    run("inject_item_trade_slot", function()
        local item = getSlot(6)
        if not item then out("No item in slot 6") return end
        out("Attempting move of slot 6 item (id=" .. item:getId() .. ") to trade offer pos {x=0xFFFF,y=0,z=0}")
        pcall(function()
            g_game.move(item, {x=0xFFFF, y=0, z=0}, 1)
            out("move() sent")
        end)
    end)
end)

UI.Button("Request Trade (slot 6 item)", function()
    run("request_trade_slot6", function()
        local item = getSlot(6)
        if not item then out("No item in slot 6") return end
        local lp = g_game.getLocalPlayer()
        local specs = getSpectators()
        local target = nil
        for _, s in ipairs(specs) do
            if s:isPlayer() and s:getId() ~= lp:getId() then
                target = s
                break
            end
        end
        if not target then out("No other player visible") return end
        out("requestTrade(" .. item:getId() .. ", " .. target:getName() .. ")")
        pcall(function()
            g_game.requestTrade(item, target)
            out("requestTrade() sent")
        end)
    end)
end)

UI.Separator()
UI.Label("-- Full API Dump --")
UI.Separator()

UI.Button("Dump g_game Methods", function()
    run("dump_g_game", function()
        local count = 0
        pcall(function()
            for k, v in pairs(g_game) do
                out(k .. " = " .. type(v))
                count = count + 1
            end
        end)
        out("Total: " .. count .. " keys")
        if count == 0 then out("pairs() failed — g_game is userdata, not table") end
    end)
end)

UI.Button("Dump g_map Methods", function()
    run("dump_g_map", function()
        local count = 0
        pcall(function()
            for k, v in pairs(g_map) do
                out(k .. " = " .. type(v))
                count = count + 1
            end
        end)
        out("Total: " .. count .. " keys")
        if count == 0 then out("pairs() failed — g_map is userdata, not table") end
    end)
end)

UI.Button("Dump g_ui Methods", function()
    run("dump_g_ui", function()
        local count = 0
        pcall(function()
            for k, v in pairs(g_ui) do
                out(k .. " = " .. type(v))
                count = count + 1
            end
        end)
        out("Total: " .. count .. " keys")
        if count == 0 then out("pairs() failed — g_ui is userdata, not table") end
    end)
end)

UI.Separator()
UI.Label("-- transferCoins / moveRaw --")
UI.Separator()

UI.Button("Probe transferCoins (no args)", function()
    run("transfercoins_probe_noargs", function()
        out("type: " .. type(g_game.transferCoins))
        local ok, err = pcall(function() g_game.transferCoins() end)
        if ok then out("transferCoins() — no error") else out("error: " .. tostring(err)) end
    end)
end)

UI.Button("transferCoins(Index Two, 1)", function()
    run("transfercoins_1", function()
        local ok, err = pcall(function() g_game.transferCoins("Index Two", 1) end)
        if ok then out("transferCoins sent — check balance") else out("error: " .. tostring(err)) end
    end)
end)

UI.Button("moveRaw Trade Pos (slot 6)", function()
    run("moveraw_trade_pos", function()
        local item = getSlot(6)
        if not item then out("No item in slot 6") return end
        local ipos = item:getPosition()
        out("moveRaw item id=" .. item:getId() .. " from " .. ipos.x .. "," .. ipos.y .. "," .. ipos.z)
        -- try raw integer signature: moveRaw(fromX, fromY, fromZ, stackPos, toX, toY, toZ, count)
        local ok, err = pcall(function()
            g_game.moveRaw(ipos.x, ipos.y, ipos.z, item:getStackPos(), 0xFFFF, 0, 0, 1)
            out("moveRaw(fromX,fromY,fromZ,stackPos,toX,toY,toZ,count) sent")
        end)
        if not ok then
            out("sig1 error: " .. tostring(err))
            -- try: moveRaw(item, toX, toY, toZ, count)
            ok, err = pcall(function()
                g_game.moveRaw(item, 0xFFFF, 0, 0, 1)
                out("moveRaw(item,toX,toY,toZ,count) sent")
            end)
            if not ok then out("sig2 error: " .. tostring(err)) end
        end
    end)
end)

UI.Button("requestItemInfo (slot 6 item)", function()
    run("requestiteminfo_item", function()
        local item = getSlot(6)
        if not item then out("No item in slot 6") return end
        out("requestItemInfo on slot 6 item id=" .. item:getId())
        local ok, err = pcall(function()
            g_game.requestItemInfo(item)
            out("requestItemInfo(item) sent")
        end)
        if not ok then
            out("sig1 error: " .. tostring(err))
            ok, err = pcall(function()
                g_game.requestItemInfo(item, 0)
                out("requestItemInfo(item, 0) sent")
            end)
            if not ok then out("sig2 error: " .. tostring(err)) end
        end
    end)
end)

UI.Separator()
UI.Label("-- Event Hooks --")
UI.Separator()

UI.Button("Hook Trade Events", function()
    run("hook_trade_events", function()
        g_game.onOwnTrade = function(name, items)
            local line = "onOwnTrade: name=" .. tostring(name) .. " items=" .. tostring(#(items or {}))
            warn("[PROBE] " .. line)
            logBuffer[#logBuffer + 1] = "[" .. os.date("%H:%M:%S") .. "] " .. line
            flushLog()
        end
        g_game.onCounterTrade = function(name, items)
            local line = "onCounterTrade: name=" .. tostring(name) .. " items=" .. tostring(#(items or {}))
            warn("[PROBE] " .. line)
            logBuffer[#logBuffer + 1] = "[" .. os.date("%H:%M:%S") .. "] " .. line
            flushLog()
        end
        g_game.onCloseTrade = function()
            local line = "onCloseTrade fired"
            warn("[PROBE] " .. line)
            logBuffer[#logBuffer + 1] = "[" .. os.date("%H:%M:%S") .. "] " .. line
            flushLog()
        end
        g_game.onCoinBalance = function(type, balance)
            local line = "onCoinBalance: type=" .. tostring(type) .. " balance=" .. tostring(balance)
            warn("[PROBE] " .. line)
            logBuffer[#logBuffer + 1] = "[" .. os.date("%H:%M:%S") .. "] " .. line
            flushLog()
        end
        out("Hooked: onOwnTrade, onCounterTrade, onCloseTrade, onCoinBalance")
    end)
end)

UI.Button("Unhook Trade Events", function()
    run("unhook_trade_events", function()
        g_game.onOwnTrade    = nil
        g_game.onCounterTrade = nil
        g_game.onCloseTrade  = nil
        g_game.onCoinBalance = nil
        out("Unhooked all trade event handlers")
    end)
end)

UI.Separator()
UI.Label("-- Message Listener --")
UI.Separator()

UI.Button("Start Listening", function()
    run("start_listening", function()
        if listening then out("Already listening") return end
        listening = true
        onTextMessage(function(mode, text)
            if not listening then return end
            local low = text:lower()
            if low:find("trade") or low:find("coin") or low:find("document") or low:find("transfer") then
                local line = "MSG[" .. tostring(mode) .. "]: " .. text
                warn("[PROBE] " .. line)
                logBuffer[#logBuffer + 1] = "[" .. os.date("%H:%M:%S") .. "] " .. line
                flushLog()
            end
        end)
        out("Listening for trade/coin/document messages...")
    end)
end)

UI.Button("Stop Listening", function()
    run("stop_listening", function()
        listening = false
        out("Stopped listening")
    end)
end)

UI.Separator()
UI.Label("-- Container / Item Scan --")
UI.Separator()

UI.Button("Scan All Containers", function()
    run("scan_containers", function()
        local containers = getContainers()
        if not containers then out("No containers open") return end
        for i, c in pairs(containers) do
            local items = c:getItems()
            out("Container[" .. i .. "] " .. c:getName() .. " (" .. c:getItemsCount() .. " items)")
            for j, item in ipairs(items) do
                out("  [" .. (j-1) .. "] id=" .. item:getId() .. " count=" .. item:getCount())
            end
        end
    end)
end)

UI.Button("Scan Inventory Slots", function()
    run("scan_inventory", function()
        local lp = g_game.getLocalPlayer()
        for slot = 1, 10 do
            local item = lp:getInventoryItem(slot)
            if item then
                out("Slot " .. slot .. ": id=" .. item:getId() .. " count=" .. item:getCount())
            end
        end
    end)
end)

UI.Separator()
UI.Label("-- Rapid Command Test --")
UI.Separator()

UI.Button("Send x3 Rapid Sell", function()
    run("rapid_sell_x3", function()
        local target = "Index Two"
        local amount = 105
        say("!sellcoins " .. target .. "," .. amount)
        schedule(80,  function() say("!sellcoins " .. target .. "," .. amount) end)
        schedule(160, function() say("!sellcoins " .. target .. "," .. amount) end)
        out("Sent 3x !sellcoins " .. target .. "," .. amount .. " at 0 / 80 / 160ms")
    end)
end)
