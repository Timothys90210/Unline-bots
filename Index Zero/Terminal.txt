-- Terminal.lua: In-client Lua REPL with terminal-style UI

Terminal = Terminal or {}

local termWindow    = nil
local lineWidgets   = {}
local logHistory    = {}
local MAX_LINES     = 300

local loadfn = loadstring or load

local C = {
    ts      = "#4A4A4A",
    cmd     = "#4EC9B0",
    ret     = "#9CDCFE",
    out     = "#D4D4D4",
    err     = "#F44747",
    syn     = "#F4B942",
    log     = "#DCDCAA",
    info    = "#C586C0",
}

g_ui.loadUIFromString([[
TerminalLine < Panel
  height: 15
  Label
    id: ts
    width: 72
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    font: verdana-11px
    text-align: left
    color: #4A4A4A
  Label
    id: msg
    anchors.left: ts.right
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    font: verdana-11px
    text-align: left
    color: #D4D4D4

TerminalWindow < MainWindow
  text: Lua Terminal
  size: 680 520
  @onEscape: self:hide()
  Panel
    id: outputBg
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: inputBg.top
    margin-top: 5
    margin-left: 5
    margin-right: 5
    margin-bottom: 3
    padding: 4
    ScrollablePanel
      id: outputScroll
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.right: outputScrollBar.left
      vertical-scrollbar: outputScrollBar
      layout:
        type: verticalBox
        spacing: 1
    VerticalScrollBar
      id: outputScrollBar
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      step: 15
      pixels-scroll: true
  Panel
    id: inputBg
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: logBg.top
    height: 30
    margin-left: 5
    margin-right: 5
    margin-bottom: 3
    padding: 4
    Label
      id: promptLabel
      text: >
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 14
      font: verdana-11px
      color: #4EC9B0
    TextEdit
      id: codeInput
      anchors.left: promptLabel.right
      anchors.right: runBtn.left
      anchors.verticalCenter: parent.verticalCenter
      height: 21
      margin-right: 4
    Button
      id: runBtn
      text: Run
      anchors.right: clearBtn.left
      anchors.verticalCenter: parent.verticalCenter
      size: 40 21
      margin-right: 4
    Button
      id: clearBtn
      text: Clear
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      size: 45 21
  Panel
    id: logBg
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: closeBtn.top
    height: 30
    margin-left: 5
    margin-right: 5
    margin-bottom: 3
    padding: 4
    Label
      id: logLabel
      text: log >
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 38
      font: verdana-11px
      color: #DCDCAA
    TextEdit
      id: logName
      anchors.left: logLabel.right
      anchors.right: saveBtn.left
      anchors.verticalCenter: parent.verticalCenter
      height: 21
      margin-right: 4
    Button
      id: saveBtn
      text: Save Log
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      size: 65 21
  Button
    id: closeBtn
    !text: tr('Close')
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 45 21
    @onClick: self:getParent():hide()
]])

termWindow = UI.createWindow("TerminalWindow")
termWindow:hide()

pcall(function() termWindow.outputBg:setBackgroundColor("#0D1117") end)
pcall(function() termWindow.inputBg:setBackgroundColor("#161B22") end)
pcall(function() termWindow.logBg:setBackgroundColor("#161B22") end)
pcall(function() termWindow.outputBg.outputScroll:setBackgroundColor("#0D1117") end)

local function scrollToBottom()
    local sb = termWindow.outputBg.outputScrollBar
    if sb then sb:setValue(sb:getMaximum()) end
end

local WRAP_AT = 90

local function wrapText(text)
    if #text <= WRAP_AT then return {text} end
    local segments = {}
    while #text > WRAP_AT do
        segments[#segments + 1] = text:sub(1, WRAP_AT)
        text = "    " .. text:sub(WRAP_AT + 1)
    end
    if #text > 0 then segments[#segments + 1] = text end
    return segments
end

local function addLine(text, color)
    local ts = os.date("[%H:%M:%S]")

    logHistory[#logHistory + 1] = ts .. " " .. text
    while #logHistory > MAX_LINES do table.remove(logHistory, 1) end

    local scroll = termWindow.outputBg.outputScroll
    local segments = wrapText(text)

    for i, segment in ipairs(segments) do
        local row = g_ui.createWidget("TerminalLine", scroll)
        row.ts:setText(i == 1 and ts or "")
        row.msg:setText(segment)
        row.msg:setColor(color)
        lineWidgets[#lineWidgets + 1] = row
    end

    while #lineWidgets > MAX_LINES do
        lineWidgets[1]:destroy()
        table.remove(lineWidgets, 1)
    end

    schedule(30, scrollToBottom)
end

local function getConfigName()
    return modules.game_bot.contentsPanel.config:getCurrentOption().text
end

local function writeLog(name)
    name = (name and name ~= "") and name or "terminal"
    name = name:gsub('[/\\:*?"<>|]', "_")

    local logsDir = "/bot/" .. getConfigName() .. "/logs"

    if not g_resources.directoryExists(logsDir) then
        g_resources.makeDir(logsDir)
    end

    local n = 1
    local filepath
    repeat
        filepath = logsDir .. "/" .. name .. "_" .. n .. ".log"
        n = n + 1
    until not g_resources.fileExists(filepath)

    local header = "-- " .. name .. " | " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    local ok, err = pcall(function()
        g_resources.writeFileContents(filepath, header .. table.concat(logHistory, "\n"))
    end)

    if ok then
        addLine("[LOG] Saved -> " .. filepath, C.log)
    else
        addLine("[LOG ERR] " .. tostring(err), C.err)
    end
end

function Terminal.log(name)
    writeLog(name)
end

local function execute(code)
    if not code or code:match("^%s*$") then return end

    addLine("> " .. code, C.cmd)

    local captured = {}
    local origPrint = print
    print = function(...)
        local args = {...}
        local parts = {}
        for i = 1, #args do parts[i] = tostring(args[i]) end
        captured[#captured + 1] = table.concat(parts, "\t")
    end

    local fn, err = loadfn("return " .. code)
    if not fn then
        fn, err = loadfn(code)
    end

    if fn then
        local results = {pcall(fn)}
        print = origPrint

        for _, line in ipairs(captured) do
            addLine("  " .. line, C.out)
        end

        local ok = table.remove(results, 1)
        if not ok then
            addLine("  [ERR] " .. tostring(results[1]), C.err)
        else
            local parts = {}
            for _, v in ipairs(results) do
                if v ~= nil then parts[#parts + 1] = tostring(v) end
            end
            if #parts > 0 then
                addLine("  " .. table.concat(parts, "  "), C.ret)
            end
        end
    else
        print = origPrint
        addLine("  [SYNTAX] " .. tostring(err), C.syn)
    end
end

termWindow.inputBg.codeInput.onKeyPress = function(widget, keyCode, keyboardModifiers)
    if keyCode == 5 then -- KeyReturn
        local code = widget:getText()
        widget:setText("")
        execute(code)
        return true
    end
end

termWindow.inputBg.runBtn.onClick = function()
    local inp = termWindow.inputBg.codeInput
    execute(inp:getText())
    inp:setText("")
end

termWindow.inputBg.clearBtn.onClick = function()
    for _, w in ipairs(lineWidgets) do w:destroy() end
    lineWidgets = {}
    logHistory  = {}
end

termWindow.logBg.saveBtn.onClick = function()
    writeLog(termWindow.logBg.logName:getText())
end

function Terminal.open()
    termWindow:show()
    termWindow:raise()
    termWindow:focus()
    addLine("Lua Terminal ready. Type a command below.", C.info)
end

setDefaultTab("Tools")
UI.Button("Lua Terminal", function() Terminal.open() end)
