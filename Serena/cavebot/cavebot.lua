local cavebotMacro = nil
local config = nil
local subfolderActive = nil  -- path of subfolder profile currently loaded (nil = root/framework mode)
local subfolderIsOn   = false

-- ── Folder navigation ────────────────────────────────────────────────────────
local botConfigName = modules.game_bot.contentsPanel.config:getCurrentOption().text
local configsRoot   = "/bot/" .. botConfigName .. "/cavebot_configs"

local function getCfgFilesInFolder(folder)
    local path = (folder == "" or not folder) and configsRoot or (configsRoot .. "/" .. folder)
    local all  = g_resources.listDirectoryFiles(path, true, false) or {}
    local result = {}
    for _, f in ipairs(all) do
        if f:match("%.cfg$") then
            local name = f:match("([^/]+)%.cfg$")
            if name then
                table.insert(result, name)
            end
        end
    end
    table.sort(result)
    return result
end

local function getSubfolders()
    local result = {}

    -- Recursively scans dirPath. Adds relPath to result only if the directory
    -- contains .cfg files directly. If it contains only subdirectories (like
    -- "tasks/"), recurses into them so their children appear in the list.
    local function scanDir(dirPath, relPath)
        local entries = g_resources.listDirectoryFiles(dirPath, true, false) or {}
        local hasCfg  = false
        local subDirs = {}

        for _, f in ipairs(entries) do
            if f:match("%.cfg$") then
                hasCfg = true
            else
                local name = f:match("([^/]+)$")
                if name and not name:match("%.%w+$") then
                    local fullPath = dirPath .. "/" .. name
                    if g_resources.directoryExists(fullPath) then
                        table.insert(subDirs, name)
                    end
                end
            end
        end

        if hasCfg and relPath ~= "" then
            table.insert(result, relPath)
        end

        for _, name in ipairs(subDirs) do
            local subRel = relPath == "" and name or (relPath .. "/" .. name)
            scanDir(dirPath .. "/" .. name, subRel)
        end
    end

    scanDir(configsRoot, "")
    table.sort(result)
    return result
end

-- All panels rendered before UI.Config() so they appear above it in the layout
local folderPanel = setupUI([[
Panel
  height: 21
  margin-bottom: 2
  Label
    id: folderIcon
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    width: 22
    text: Dir:
    font: verdana-11px-rounded
  Button
    id: folderSelect
    text-align: left
    text-offset: 4 0
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: folderIcon.right
    anchors.right: parent.right
    margin-left: 2
]])

local filePanel = setupUI([[
Panel
  height: 21
  margin-bottom: 2
  Button
    id: fileSelect
    text-align: left
    text-offset: 4 0
    anchors.fill: parent
]])

local caveOnOffPanel = setupUI([[
Panel
  height: 24
  BotSwitch
    id: caveOnOff
    anchors.fill: parent
    $on:
      text: ON
    $!on:
      text: OFF
]])

local caveAERPanel = setupUI([[
Panel
  layout:
    type: verticalBox
    fit-children: true
  Panel
    id: buttons
    height: 20
    margin-top: 2
    Button
      id: addBtn
      text: Add
      width: 45
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.left: parent.left
    Button
      id: editBtn
      text: Edit
      width: 45
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
    Button
      id: removeBtn
      text: Remove
      width: 45
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
]])


-- Scrollable dropdown backed by a TextList popup (replaces the unscrollable
-- core ComboBox). Exposes a ComboBox-like API so the callbacks below are
-- unchanged in spirit: addOption / clearOptions / setText / getText / onChange.
local function makeScrollCombo(button)
    local self = { button = button, options = {}, current = nil, onChange = nil, popup = nil }

    function self:getText() return self.current or "" end

    function self:setText(t)               -- updates display only, never fires onChange
        self.current = t
        self.button:setText(t or "")
    end

    function self:clearOptions()
        self.options = {}
        self.current = nil
        self.button:setText("")
    end

    function self:addOption(t)
        table.insert(self.options, t)
        if self.current == nil then self:setText(t) end  -- first option becomes current (matches ComboBox)
    end

    function self:closePopup()
        if self.popup then
            self.popup:destroy()
            self.popup = nil
        end
    end

    function self:open()
        self:closePopup()
        if #self.options == 0 then return end
        local root = g_ui.getRootWidget()
        local ok, overlay = pcall(g_ui.createWidget, "CaveScrollOverlay", root)
        if not ok or not overlay then
            return warn("[CaveBot] scroll dropdown could not be created: " .. tostring(overlay))
        end
        self.popup = overlay
        -- Click anywhere not consumed by the box (i.e. outside) closes the popup.
        overlay.onMousePress = function()
            self:closePopup()
            return true
        end

        local box = overlay.box
        local currentRow = nil
        for _, opt in ipairs(self.options) do
            local row = g_ui.createWidget("CaveScrollOption", box.list)
            row:setText(opt)
            local isCurrent = (opt == self.current)
            if isCurrent then
                currentRow = row
                row:setBackgroundColor("#1f6fb2")
            end
            -- Hover highlight driven from Lua (the $hover style state is unreliable
            -- on these rows); selected row keeps its blue when not hovered.
            row.onHoverChange = function(w, hovered)
                if hovered then
                    w:setBackgroundColor("#3b556e")
                else
                    w:setBackgroundColor(isCurrent and "#1f6fb2" or "alpha")
                end
            end
        end

        -- TextList drives selection via child focus (clicking a row focuses it),
        -- so hook onChildFocusChange rather than per-row onClick.
        local ready = false
        box.list.onChildFocusChange = function(_, newChild)
            if not ready or not newChild then return end
            local opt = newChild:getText()
            local changed = (opt ~= self.current)
            self:closePopup()
            if changed then
                self:setText(opt)
                if self.onChange then self.onChange(opt) end
            end
        end

        -- Size and position the box directly below the button (flip above if it
        -- would run off the bottom of the screen).
        local bx, by = button:getX(), button:getY()
        local bw, bh = button:getWidth(), button:getHeight()
        local rowH, maxVisible = 16, 12
        local h = math.min(#self.options, maxVisible) * rowH + 4
        box:setWidth(bw)
        box:setHeight(h)
        box:setX(bx)
        local belowY = by + bh
        if belowY + h > root:getHeight() and (by - h) >= 0 then
            box:setY(by - h)
        else
            box:setY(belowY)
        end
        overlay:raise()

        -- Highlight the current selection without triggering the change handler.
        if currentRow then currentRow:focus() end
        ready = true
    end

    button.onClick = function() self:open() end
    return self
end

local folderCombo = makeScrollCombo(folderPanel.folderSelect)
local fileCombo   = makeScrollCombo(filePanel.fileSelect)

folderCombo:addOption("/")
for _, dir in ipairs(getSubfolders()) do
    folderCombo:addOption(dir)
end
-- ─────────────────────────────────────────────────────────────────────────────

-- ui
local configWidget = UI.Config()
local ui = UI.createWidget("CaveBotPanel")

ui.list = ui.listPanel.list -- shortcut
CaveBot.actionList = ui.list

if CaveBot.Editor then
  CaveBot.Editor.setup()
end
if CaveBot.Config then
  CaveBot.Config.setup()
end
for extension, callbacks in pairs(CaveBot.Extensions) do
  if callbacks.setup then
    callbacks.setup()
  end
end

-- main loop, controlled by config
local actionRetries = 0
local prevActionResult = true
cavebotMacro = macro(20, function()
  if TargetBot and TargetBot.isActive() and not TargetBot.isCaveBotActionAllowed() then
    CaveBot.resetWalking()
    return -- target bot or looting is working, wait
  end
  
  if CaveBot.doWalking() then
    return -- executing walking3
  end
  
  local actions = ui.list:getChildCount()
  if actions == 0 then return end
  local currentAction = ui.list:getFocusedChild()
  if not currentAction then
    currentAction = ui.list:getFirstChild()
  end
  local action = CaveBot.Actions[currentAction.action]  
  local value = currentAction.value
  local retry = false
  if action then
    local status, result = pcall(function()
      CaveBot.resetWalking()
      return action.callback(value, actionRetries, prevActionResult)
    end)
    if status then
      if result == "retry" then
        actionRetries = actionRetries + 1
        retry = true
      elseif type(result) == 'boolean' then
        actionRetries = 0
        prevActionResult = result
      else
        warn("Invalid return from cavebot action (" .. currentAction.action .. "), should be \"retry\", false or true, is: " .. tostring(result))
      end
    else
      warn("warn while executing cavebot action (" .. currentAction.action .. "):\n" .. result)
    end    
  else
    warn("Invalid cavebot action: " .. currentAction.action)
  end
  
  if retry then
    return
  end
  
  if currentAction ~= ui.list:getFocusedChild() then
    -- focused child can change durring action, get it again and reset state
    currentAction = ui.list:getFocusedChild() or ui.list:getFirstChild()
    actionRetries = 0
    prevActionResult = true
  end
  local nextAction = ui.list:getChildIndex(currentAction) + 1
  if nextAction > actions then
    nextAction = 1
  end
  ui.list:focusChild(ui.list:getChildByIndex(nextAction))
end)

-- config, its callback is called immediately, data can be nil
local lastConfig = ""

local function loadCavebot(name, enabled, data)
  if enabled and CaveBot.Recorder.isOn() then
    CaveBot.Recorder.disable()
    CaveBot.setOff()
    return
  end

  local currentActionIndex = ui.list:getChildIndex(ui.list:getFocusedChild())
  ui.list:destroyChildren()
  if not data then return cavebotMacro.setOff() end

  local cavebotConfig = nil
  for k,v in ipairs(data) do
    if type(v) == "table" and #v == 2 then
      if v[1] == "config" then
        local status, result = pcall(function()
          return json.decode(v[2])
        end)
        if not status then
          warn("warn while parsing CaveBot extensions from config:\n" .. result)
        else
          cavebotConfig = result
        end
      elseif v[1] == "extensions" then
        local status, result = pcall(function()
          return json.decode(v[2])
        end)
        if not status then
          warn("warn while parsing CaveBot extensions from config:\n" .. result)
        else
          for extension, callbacks in pairs(CaveBot.Extensions) do
            if callbacks.onConfigChange then
              callbacks.onConfigChange(name, enabled, result[extension])
            end
          end
        end
      else
        CaveBot.addAction(v[1], v[2])
      end
    end
  end

  CaveBot.Config.onConfigChange(name, enabled, cavebotConfig)

  actionRetries = 0
  CaveBot.resetWalking()
  prevActionResult = true
  cavebotMacro.setOn(enabled)
  cavebotMacro.delay = nil
  if lastConfig == name then
    ui.list:focusChild(ui.list:getChildByIndex(currentActionIndex))
  end
  lastConfig = name
end

config = Config.setup("cavebot_configs", configWidget, "cfg", function(name, enabled, data)
  -- This callback fires when external code calls CaveBot.setOn()/setOff()
  -- (CinderEvent portal exit, monster_identifier disengage, etc.). The
  -- framework's setOn rewrites storage._configs.cavebot_configs.selected to
  -- match its own hidden combobox (a root-level file), so we can't rely on
  -- that key to remember the user's subfolder choice. We use our own
  -- storage.cavebotSubfolderPath key which the framework never touches.
  local subStored = storage.cavebotSubfolderPath
  if subStored and subStored ~= "" then
    local subPath = configsRoot .. "/" .. subStored .. ".cfg"
    if g_resources.fileExists(subPath) then
      subfolderActive = subStored
      subfolderIsOn   = enabled
      loadCavebot(subStored, enabled,
                  Config.parse(g_resources.readFileContents(subPath)))
      return
    end
  end
  subfolderActive = nil
  loadCavebot(name, enabled, data)
end)

-- ── Folder navigation callbacks ──────────────────────────────────────────────
-- Fully hide the framework widget — our panels replace all of its functionality.
configWidget:hide()

-- ON/OFF button
caveOnOffPanel.caveOnOff:setOn(config.isOn())
pcall(function() caveOnOffPanel.caveOnOff:setBackgroundColor("#8B0000") end)
caveOnOffPanel.caveOnOff.onClick = function(widget)
    if subfolderActive then
        if subfolderIsOn then
            subfolderIsOn = false
            cavebotMacro.setOff()
        else
            local filePath = configsRoot .. "/" .. subfolderActive .. ".cfg"
            if g_resources.fileExists(filePath) then
                local data = Config.parse(g_resources.readFileContents(filePath))
                storage._configs.cavebot_configs.selected = subfolderActive
                storage.cavebotSubfolderPath = subfolderActive
                subfolderIsOn = true
                loadCavebot(subfolderActive, true, data)
            end
        end
    else
        if config.isOn() then config.setOff() else config.setOn() end
    end
end
macro(200, function()
    if subfolderActive then
        caveOnOffPanel.caveOnOff:setOn(subfolderIsOn)
    else
        caveOnOffPanel.caveOnOff:setOn(config.isOn())
    end
end)

local function currentFullProfile()
    local file   = fileCombo:getText()
    local folder = folderCombo:getText()
    folder = folder == "/" and "" or folder
    return folder == "" and file or (folder .. "/" .. file)
end

local function populateFileCombo(folder)
    fileCombo:clearOptions()
    for _, name in ipairs(getCfgFilesInFolder(folder)) do
        fileCombo:addOption(name)
    end
end

-- Sync visual state of our combos with the profile Config.setup already loaded.
-- Callbacks are defined AFTER this block so startup population doesn't trigger them.
-- Prefer our cavebotSubfolderPath key (framework-untouchable) over the
-- framework's storage._configs key (which gets overwritten by external setOn).
local savedProfile = storage.cavebotSubfolderPath
                  or (storage._configs and storage._configs.cavebot_configs and
                      storage._configs.cavebot_configs.selected)
                  or ""

if savedProfile:find("/", 1, true) then
    local savedFolder = savedProfile:match("^([^/]+)/")
    if savedFolder then
        folderCombo:setText(savedFolder)
        populateFileCombo(savedFolder)
    else
        populateFileCombo("")
    end
else
    populateFileCombo("")
end

if savedProfile ~= "" then
    local savedFile = savedProfile:match("([^/]+)$") or savedProfile
    fileCombo:setText(savedFile)
end

folderCombo.onChange = function(sel)
    local folder = sel == "/" and "" or sel
    if sel == "/" then subfolderActive = nil end
    populateFileCombo(folder)
end

fileCombo.onChange = function(sel)
    if sel and sel ~= "" then
        local folder = folderCombo:getText()
        local fullPath = currentFullProfile()
        if folder == "/" then
            subfolderActive = nil
            storage.cavebotSubfolderPath = nil  -- clear our key when returning to root
            local wasOn = config.isOn()
            CaveBot.setCurrentProfile(fullPath)
            if not wasOn then config.setOff() end
        else
            local filePath = configsRoot .. "/" .. fullPath .. ".cfg"
            if not g_resources.fileExists(filePath) then
                warn("[CaveBot] profile not found: " .. filePath)
                return
            end
            local wasOn = subfolderActive and subfolderIsOn or config.isOn()
            local data = Config.parse(g_resources.readFileContents(filePath))
            storage._configs.cavebot_configs.selected = fullPath
            storage.cavebotSubfolderPath = fullPath  -- our key, framework-untouchable
            subfolderActive = fullPath
            subfolderIsOn = wasOn
            loadCavebot(fullPath, wasOn, data)
        end
    end
end
-- Add / Edit / Remove: delegate directly to the framework's own hidden buttons
-- so behaviour is identical to the untouched Dreadfull directory.
local frameworkBtns = {}
local function findBtns(widget)
    for _, child in ipairs(widget:getChildren()) do
        local ok, txt = pcall(function() return child:getText() end)
        if ok and txt and txt ~= "" then
            frameworkBtns[txt:lower()] = child
        end
        findBtns(child)
    end
end
findBtns(configWidget)

caveAERPanel.buttons.addBtn.onClick = function()
    if frameworkBtns["add"] then
        pcall(function() frameworkBtns["add"].onClick(frameworkBtns["add"]) end)
    end
end
caveAERPanel.buttons.editBtn.onClick = function()
    if frameworkBtns["edit"] then
        pcall(function() frameworkBtns["edit"].onClick(frameworkBtns["edit"]) end)
    end
end
caveAERPanel.buttons.removeBtn.onClick = function()
    if frameworkBtns["remove"] then
        pcall(function() frameworkBtns["remove"].onClick(frameworkBtns["remove"]) end)
    end
end
-- ─────────────────────────────────────────────────────────────────────────────

-- ui callbacks
ui.showEditor.onClick = function()
  if not CaveBot.Editor then return end
  if ui.showEditor:isOn() then
    CaveBot.Editor.hide()
    ui.showEditor:setOn(false)
  else
    CaveBot.Editor.show()
    ui.showEditor:setOn(true)
  end
end

ui.showConfig.onClick = function()
  if not CaveBot.Config then return end
  if ui.showConfig:isOn() then
    CaveBot.Config.hide()
    ui.showConfig:setOn(false)
  else
    CaveBot.Config.show()
    ui.showConfig:setOn(true)
  end
end

-- public function, you can use them in your scripts
CaveBot.isOn = function()
  return config.isOn()
end

CaveBot.isOff = function()
  return config.isOff()
end

CaveBot.setOn = function(val)
  if val == false then  
    return CaveBot.setOff(true)
  end
  config.setOn()
end

CaveBot.setOff = function(val)
  if val == false then  
    return CaveBot.setOn(true)
  end
  config.setOff()
end

CaveBot.getCurrentProfile = function()
  return storage._configs.cavebot_configs.selected
end

CaveBot.lastReachedLabel = function()
  return vBot.lastLabel
end

CaveBot.gotoNextWaypointInRange = function()
  local currentAction = ui.list:getFocusedChild()
  local index = ui.list:getChildIndex(currentAction)
  local actions = ui.list:getChildren()

  -- start searching from current index
  for i, child in ipairs(actions) do
    if i > index then
      local text = child:getText()
      if string.starts(text, "goto:") then
        local re = regexMatch(text, [[(?:goto:)([^,]+),([^,]+),([^,]+)]])
        local pos = {x = tonumber(re[1][2]), y = tonumber(re[1][3]), z = tonumber(re[1][4])}
        
        if posz() == pos.z then
          local maxDist = storage.extras.gotoMaxDistance
          if distanceFromPlayer(pos) <= maxDist then
            if findPath(player:getPosition(), pos, maxDist, { ignoreNonPathable = true }) then
              ui.list:focusChild(ui.list:getChildByIndex(i-1))
              return true
            end
          end
        end
      end
    end
  end

  -- if not found then damn go from start
  for i, child in ipairs(actions) do
    if i <= index then
      local text = child:getText()
      if string.starts(text, "goto:") then
        local re = regexMatch(text, [[(?:goto:)([^,]+),([^,]+),([^,]+)]])
        local pos = {x = tonumber(re[1][2]), y = tonumber(re[1][3]), z = tonumber(re[1][4])}

        if posz() == pos.z then
          local maxDist = storage.extras.gotoMaxDistance
          if distanceFromPlayer(pos) <= maxDist then
            if findPath(player:getPosition(), pos, maxDist, { ignoreNonPathable = true }) then
              ui.list:focusChild(ui.list:getChildByIndex(i-1))
              return true
            end
          end
        end
      end
    end
  end

  -- not found
  return false
end

local function reverseTable(t, max)
  local reversedTable = {}
  local itemCount = max or #t
  for i, v in ipairs(t) do
      reversedTable[itemCount + 1 - i] = v
  end
  return reversedTable
end

function rpairs(t)
  test()
	return function(t, i)
		i = i - 1
		if i ~= 0 then
			return i, t[i]
		end
	end, t, #t + 1
end

CaveBot.gotoFirstPreviousReachableWaypoint = function()
  local currentAction = ui.list:getFocusedChild()
  local currentIndex = ui.list:getChildIndex(currentAction)
  local index = ui.list:getChildIndex(currentAction)

  -- check up to 100 childs
  for i=0,100 do
    index = index - i
    if index <= 0 or index > currentIndex or math.abs(index-currentIndex) > 100 then
      break
    end

    local child = ui.list:getChildByIndex(index)

    if child then
      local text = child:getText()
      if string.starts(text, "goto:") then
        local re = regexMatch(text, [[(?:goto:)([^,]+),([^,]+),([^,]+)]])
        local pos = {x = tonumber(re[1][2]), y = tonumber(re[1][3]), z = tonumber(re[1][4])}

        if posz() == pos.z then
          if distanceFromPlayer(pos) <= storage.extras.gotoMaxDistance/2 then
            print("found pos, going back "..currentIndex-index.. " waypoints.")
            return ui.list:focusChild(child)
          end
        end
      end
    end
  end

  -- not found
  print("previous pos not found, proceeding")
  return false
end

CaveBot.getFirstWaypointBeforeLabel = function(label)
  label = "label:"..label
  label = label:lower()
  local actions = ui.list:getChildren()
  local index

  -- find index of label
  for i, child in pairs(actions) do
    local name = child:getText():lower()
    if name == label then
      index = i
      break
    end
  end

  -- if there's no index then label was not found
  if not index then return false end

  for i=1,#actions do
    if index - 1 < 1 then
      -- did not found any waypoint in range before label 
      return false
    end

    local child = ui.list:getChildByIndex(index-i)
    if child then
      local text = child:getText()
      if string.starts(text, "goto:") then
        local re = regexMatch(text, [[(?:goto:)([^,]+),([^,]+),([^,]+)]])
        local pos = {x = tonumber(re[1][2]), y = tonumber(re[1][3]), z = tonumber(re[1][4])}

        if posz() == pos.z then
          if distanceFromPlayer(pos) <= storage.extras.gotoMaxDistance/2 then
            return ui.list:focusChild(child)
          end
        end
      end
    end
  end
end

CaveBot.getPreviousLabel = function()
  local actions = ui.list:getChildren()
  -- check if config is empty
  if #actions == 0 then return false end

  local currentAction = ui.list:getFocusedChild()
  --check we made any progress in waypoints, if no focused or first then no point checking
  if not currentAction or currentAction == ui.list:getFirstChild() then return false end

  local index = ui.list:getChildIndex(currentAction)

  -- if not index then something went wrong and there's no selected child
  if not index then return false end

  for i=1,#actions do
    if index - i < 1 then
      -- did not found any waypoint in range before label 
      return false
    end

    local child = ui.list:getChildByIndex(index-i)
    if child then
      if child.action == "label" then
        return child.value
      end
    end
  end
end

CaveBot.getNextLabel = function()
  local actions = ui.list:getChildren()
  -- check if config is empty
  if #actions == 0 then return false end

  local currentAction = ui.list:getFocusedChild() or ui.list:getFirstChild()
  local index = ui.list:getChildIndex(currentAction)

  -- if not index then something went wrong
  if not index then return false end

  for i=1,#actions do
    if index + i > #actions then
      -- did not found any waypoint in range before label 
      return false
    end

    local child = ui.list:getChildByIndex(index+i)
    if child then
      if child.action == "label" then
        return child.value
      end
    end
  end
end

local botConfigName = modules.game_bot.contentsPanel.config:getCurrentOption().text
CaveBot.setCurrentProfile = function(name)
  if not g_resources.fileExists("/bot/"..botConfigName.."/cavebot_configs/"..name..".cfg") then
    return warn("there is no cavebot profile with that name!")
  end
  CaveBot.setOff()
  storage._configs.cavebot_configs.selected = name
  CaveBot.setOn()
end

CaveBot.delay = function(value)
  cavebotMacro.delay = math.max(cavebotMacro.delay or 0, now + value)
end

CaveBot.gotoLabel = function(label)
  label = label:lower()
  for index, child in ipairs(ui.list:getChildren()) do
    if child.action == "label" and child.value:lower() == label then    
      ui.list:focusChild(child)
      return true
    end
  end
  return false
end

CaveBot.save = function()
  local data = {}
  for index, child in ipairs(ui.list:getChildren()) do
    table.insert(data, {child.action, child.value})
  end
  
  if CaveBot.Config then
    table.insert(data, {"config", json.encode(CaveBot.Config.save())})
  end
  
  local extension_data = {}
  for extension, callbacks in pairs(CaveBot.Extensions) do
    if callbacks.onSave then
      local ext_data = callbacks.onSave()
      if type(ext_data) == "table" then
        extension_data[extension] = ext_data
      end
    end
  end
  table.insert(data, {"extensions", json.encode(extension_data, 2)})
  config.save(data)
end

CaveBotList = function()
  return ui.list
end