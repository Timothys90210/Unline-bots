--------------------------------- Dust Tracker --------------------------------------------

-- Configuration
local CHECK_INTERVAL = 3600000 -- 1 hour in milliseconds (60 * 60 * 1000)
local lastCheckTime = -CHECK_INTERVAL -- Start negative so first check happens immediately
local DUST_THRESHOLD_PERCENT = 90 -- Trigger forge visit when dust progress reaches 90%

-- Exaltation Forge coordinates
local FORGE_POS = {x = 5258, y = 5336, z = 6}
local MAX_FORGE_DISTANCE = 7 -- Maximum distance to use the forge without walking

-- Waypoints to navigate to the forge from temple
local FORGE_WAYPOINTS = {
  {x = 503, y = 525, z = 7},
  {x = 509, y = 525, z = 7},
  {x = 513, y = 519, z = 7},
  {x = 519, y = 518, z = 7},
  {x = 525, y = 517, z = 7},
  {x = 527, y = 511, z = 7},
  {x = 528, y = 505, z = 7},
  {x = 531, y = 499, z = 7},
  {x = 531, y = 493, z = 7},
  {x = 537, y = 488, z = 7},
  {x = 538, y = 486, z = 7, forceWalk = true, useStairs = true},
  {x = 540, y = 487, z = 6, openDoor = true}, -- Open door here
  {x = 538, y = 490, z = 6, forceWalk = true} -- Final waypoint - teleport to forge
}

local TP_DELAY_AFTER_TELEPORT = 5000 -- 5 seconds delay after teleporting

-- Variables to store dust counts
local currentDusts = 0
local maxDusts = 0

-- Track if CaveBot was turned off by this script
local cavebotOffByDustTracker = false

-- Track if we need to visit the forge due to threshold
local needsForgeVisit = false

-- Track navigation state
local isNavigatingToForge = false
local currentWaypointIndex = 1
local lastPlayerPos = nil
local stuckCheckCount = 0
local MAX_STUCK_CHECKS = 6 -- If stuck for 6 checks (3 seconds), force skip

-- Fallback/Watchdog tracking
local FALLBACK_TIMEOUT = 120000 -- 2 minutes in milliseconds
local scriptStartTime = nil -- When the script sequence started
local scriptCompleted = false -- Whether click 5/5 was reached
local lastMovementTime = nil -- Last time player moved
local lastWatchdogPos = nil -- Position at last watchdog check
local watchdogScheduleId = nil -- To track watchdog schedule

-- Retry tracking for bulletproof operation
local MAX_RETRIES = 3 -- Maximum number of full script retries
local currentRetryCount = 0 -- Current retry attempt
local forgeWindowRetryCount = 0 -- Retries for forge window detection
local MAX_FORGE_WINDOW_RETRIES = 5 -- Max retries for forge window
local forgeInteractionRetryCount = 0 -- Retries for forge interaction
local MAX_FORGE_INTERACTION_RETRIES = 3 -- Max retries for forge interaction

-- Function to reset all script state for a fresh start
local function resetScriptState(fullReset)
  modules.game_textmessage.displayGameMessage("[Dust Tracker] Resetting script state for fresh start", 18)
  isNavigatingToForge = false
  currentWaypointIndex = 1
  lastPlayerPos = nil
  stuckCheckCount = 0
  scriptStartTime = nil
  scriptCompleted = false
  lastMovementTime = nil
  lastWatchdogPos = nil
  watchdogScheduleId = nil
  forgeWindowRetryCount = 0
  forgeInteractionRetryCount = 0

  -- Only reset retry count on full reset (successful completion)
  if fullReset then
    currentRetryCount = 0
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Full reset - retry count cleared", 18)
  end
end

-- Forward declarations (needed for retry logic)
local openExaltationForge
local openExaltationForgeNearby
local clickRaiseLimitButton

-- Watchdog function to detect stuck conditions and retrigger
local function watchdogCheck()
  -- Only run if script is active (navigating or waiting for clicks)
  if not scriptStartTime then
    return
  end

  local currentTime = now
  local elapsedTime = currentTime - scriptStartTime

  -- Check if script has completed successfully
  if scriptCompleted then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Watchdog: Script completed successfully, stopping watchdog", 18)
    resetScriptState(true) -- Full reset on success
    return
  end

  -- Check if 2 minutes have passed without completion
  if elapsedTime >= FALLBACK_TIMEOUT then
    currentRetryCount = currentRetryCount + 1
    modules.game_textmessage.displayGameMessage("[Dust Tracker] WATCHDOG ALERT: 2 minutes elapsed without completion!", 18)
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Retry attempt " .. currentRetryCount .. "/" .. MAX_RETRIES, 18)

    if currentRetryCount >= MAX_RETRIES then
      modules.game_textmessage.displayGameMessage("[Dust Tracker] MAX RETRIES REACHED! Giving up and resuming CaveBot.", 18)
      resetScriptState(true)

      -- Resume CaveBot so player doesn't stay stuck
      if cavebotOffByDustTracker and CaveBot then
        CaveBot.setOn()
        cavebotOffByDustTracker = false
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Resumed CaveBot after max retries", 18)
      end

      -- Teleport back to hunting grounds
      say("!tp 2")
      return
    end

    -- Reset state but keep retry count
    resetScriptState(false)

    -- Retrigger the script
    needsForgeVisit = true
    schedule(1000, function()
      if openExaltationForge then
        openExaltationForge()
        needsForgeVisit = false
      end
    end)
    return
  end

  -- Check if player hasn't moved for 2 minutes
  local playerPos = player:getPosition()
  if playerPos and lastWatchdogPos then
    if playerPos.x == lastWatchdogPos.x and playerPos.y == lastWatchdogPos.y and playerPos.z == lastWatchdogPos.z then
      -- Player hasn't moved since last watchdog check
      if lastMovementTime then
        local timeSinceMovement = currentTime - lastMovementTime
        if timeSinceMovement >= FALLBACK_TIMEOUT then
          currentRetryCount = currentRetryCount + 1
          modules.game_textmessage.displayGameMessage("[Dust Tracker] WATCHDOG ALERT: No movement for 2 minutes!", 18)
          modules.game_textmessage.displayGameMessage("[Dust Tracker] Retry attempt " .. currentRetryCount .. "/" .. MAX_RETRIES, 18)

          if currentRetryCount >= MAX_RETRIES then
            modules.game_textmessage.displayGameMessage("[Dust Tracker] MAX RETRIES REACHED! Giving up and resuming CaveBot.", 18)
            resetScriptState(true)

            -- Resume CaveBot so player doesn't stay stuck
            if cavebotOffByDustTracker and CaveBot then
              CaveBot.setOn()
              cavebotOffByDustTracker = false
              modules.game_textmessage.displayGameMessage("[Dust Tracker] Resumed CaveBot after max retries", 18)
            end

            -- Teleport back to hunting grounds
            say("!tp 2")
            return
          end

          -- Reset state but keep retry count
          resetScriptState(false)

          -- Retrigger the script
          needsForgeVisit = true
          schedule(1000, function()
            if openExaltationForge then
              openExaltationForge()
              needsForgeVisit = false
            end
          end)
          return
        end
      end
    else
      -- Player moved, update last movement time
      lastMovementTime = currentTime
    end
  end

  -- Update watchdog position
  if playerPos then
    lastWatchdogPos = {x = playerPos.x, y = playerPos.y, z = playerPos.z}
  end

  -- Schedule next watchdog check (every 10 seconds)
  schedule(10000, watchdogCheck)
end

-- Function to start watchdog monitoring
local function startWatchdog()
  scriptStartTime = now
  scriptCompleted = false
  lastMovementTime = now
  local playerPos = player:getPosition()
  if playerPos then
    lastWatchdogPos = {x = playerPos.x, y = playerPos.y, z = playerPos.z}
  end
  modules.game_textmessage.displayGameMessage("[Dust Tracker] Watchdog started - will retrigger if stuck for 2 minutes", 18)

  -- Start watchdog checks
  schedule(10000, watchdogCheck)
end

-- Function to debug and list all open windows
local function debugListWindows()
  modules.game_textmessage.displayGameMessage("[Dust Tracker] ===== Listing All Open Windows =====", 18)

  local rootWidget = g_ui.getRootWidget()
  if not rootWidget then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] ERROR: Could not get root widget", 18)
    return
  end

  -- Recursively search for windows
  local function listWindows(widget, depth, path)
    depth = depth or 0
    path = path or "root"

    if depth > 5 then return end -- Limit depth to avoid too much output

    local children = widget:getChildren()
    for i, child in ipairs(children) do
      local id = child:getId() or "no-id"
      local className = child:getClassName() or "no-class"
      local isVisible = child:isVisible() and "visible" or "hidden"

      -- Only log windows or interesting widgets
      if className:lower():find("window") or
         id:lower():find("window") or
         id:lower():find("exalt") or
         id:lower():find("forge") or
         id:lower():find("dust") then

        local indent = string.rep("  ", depth)
        modules.game_textmessage.displayGameMessage(
          "[Dust Tracker] " .. indent .. "ID: " .. id .. " | Class: " .. className .. " | " .. isVisible,
          18
        )

        -- List direct children of windows
        if depth < 3 then
          listWindows(child, depth + 1, path .. "/" .. id)
        end
      end
    end
  end

  listWindows(rootWidget, 0)
  modules.game_textmessage.displayGameMessage("[Dust Tracker] ===== End of Window List =====", 18)
end

-- Function to click the "Raise limit from" button
clickRaiseLimitButton = function(forgeThing)
  modules.game_textmessage.displayGameMessage("[Dust Tracker] Looking for 'Raise limit from' button", 18)

  local rootWidget = g_ui.getRootWidget()
  if not rootWidget then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] ERROR: Could not get root widget", 18)
    return false
  end

  -- Find forge window by searching for any visible window containing dustLimitPanel
  local forgeWindow = nil
  local dustLimitPanel = nil

  modules.game_textmessage.displayGameMessage("[Dust Tracker] Searching for forge window...", 18)

  -- First try to find dustLimitPanel directly from root
  dustLimitPanel = rootWidget:recursiveGetChildById('dustLimitPanel')
  if dustLimitPanel then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Found dustLimitPanel directly!", 18)
    -- Find parent window
    local parent = dustLimitPanel
    for i = 1, 10 do
      local p = parent:getParent()
      if p then
        parent = p
        local className = parent:getClassName() or ""
        if className:lower():find("window") then
          forgeWindow = parent
          modules.game_textmessage.displayGameMessage("[Dust Tracker] Found parent window: " .. (parent:getId() or "unknown"), 18)
          break
        end
      else
        break
      end
    end
    if not forgeWindow then
      forgeWindow = parent -- Use topmost parent as window
    end
  end

  if not dustLimitPanel then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] dustLimitPanel not found directly, searching windows...", 18)

    local function findForgeWindow(widget, depth)
      depth = depth or 0
      if depth > 15 then return nil, nil end

      local children = widget:getChildren()
      for _, child in ipairs(children) do
        -- Check if this widget has dustLimitPanel as a descendant
        local panel = child:recursiveGetChildById('dustLimitPanel')
        if panel and child:isVisible() then
          modules.game_textmessage.displayGameMessage("[Dust Tracker] Found forge window with dustLimitPanel (ID: " .. (child:getId() or "unknown") .. ")", 18)
          return child, panel
        end

        -- Recurse into children
        local foundWindow, foundPanel = findForgeWindow(child, depth + 1)
        if foundWindow then
          return foundWindow, foundPanel
        end
      end
      return nil, nil
    end

    forgeWindow, dustLimitPanel = findForgeWindow(rootWidget, 0)
  end

  if not forgeWindow and not dustLimitPanel then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] ERROR: Could not find forge window or dustLimitPanel", 18)
    -- Debug: list visible windows
    local children = rootWidget:getChildren()
    for i, child in ipairs(children) do
      if child:isVisible() then
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Visible child " .. i .. ": " .. (child:getId() or "no-id") .. " | " .. (child:getClassName() or "no-class"), 18)
      end
    end
    return false
  end

  modules.game_textmessage.displayGameMessage("[Dust Tracker] Found dustLimitPanel", 18)

  -- First, find the label with "Raise limit from" text
  local function findTextWidget(widget, depth, searchText)
    depth = depth or 0
    if depth > 5 then return nil end

    -- Check if this widget has the text we're looking for
    if widget.getText then
      local text = ""
      pcall(function()
        text = widget:getText() or ""
      end)

      if text:lower():find(searchText:lower()) then
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Found text widget: " .. text, 18)
        return widget
      end
    end

    -- Recursively search children
    local children = widget:getChildren()
    for _, child in ipairs(children) do
      local result = findTextWidget(child, depth + 1, searchText)
      if result then
        return result
      end
    end

    return nil
  end

  local raiseLimitText = findTextWidget(dustLimitPanel, 0, "raise limit from")

  if not raiseLimitText then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] ERROR: Could not find 'Raise limit from' text", 18)
    return false
  end

  -- Now find the parent of this text widget and look for a clickable sibling or parent
  local parent = raiseLimitText:getParent()

  if not parent then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] ERROR: Text widget has no parent", 18)
    return false
  end

  modules.game_textmessage.displayGameMessage("[Dust Tracker] Found parent of text widget", 18)

  -- Look for clickable widgets in the parent (siblings of the text)
  local children = parent:getChildren()
  local raiseLimitButton = nil

  for i, child in ipairs(children) do
    local childId = child:getId() or "no-id"
    local className = child:getClassName() or "no-class"

    modules.game_textmessage.displayGameMessage("[Dust Tracker] Sibling " .. i .. ": " .. childId .. " | " .. className, 18)

    -- Check if it's clickable (UIItem or has onClick)
    if child.onClick or className:find("Item") or className:find("Button") then
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Found clickable sibling", 18)

      if child.onClick then
        raiseLimitButton = child
        break
      end
    end
  end

  if not raiseLimitButton then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] ERROR: No clickable sibling found", 18)
    return false
  end

  -- Click the button 5 times with 1 second delay between each click
  modules.game_textmessage.displayGameMessage("[Dust Tracker] Clicking raise limit button 5 times...", 18)

  for i = 1, 5 do
    schedule((i - 1) * 1000, function()
      raiseLimitButton:onClick()
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Click " .. i .. "/5", 18)

      -- Mark script as completed on final click
      if i == 5 then
        scriptCompleted = true
        modules.game_textmessage.displayGameMessage("[Dust Tracker] All 5 clicks completed - script successful!", 18)
      end
    end)
  end

  -- Close the forge window after all 5 clicks are done (after 5 seconds)
  schedule(5000, function()
    -- Try to close the forge window
    if forgeWindow then
      pcall(function() forgeWindow:hide() end)
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Closed forge window after all clicks", 18)
    end

    -- Teleport back to hunting grounds
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Teleporting back to hunting grounds...", 18)
    say("!tp 2")

    -- Resume CaveBot after teleport delay
    schedule(TP_DELAY_AFTER_TELEPORT, function()
      if cavebotOffByDustTracker and CaveBot then
        CaveBot.setOn()
        cavebotOffByDustTracker = false
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Resumed CaveBot", 18)
      end
    end)
  end)

  return true
end

-- Function to check if player is in battle
local function isInBattle()
  -- Use hasSwords() function which checks for combat/swords icon
  return hasSwords()
end

-- Function to start the forge visit sequence
openExaltationForge = function()
  modules.game_textmessage.displayGameMessage("[Dust Tracker] Starting forge visit sequence", 18)

  -- Start the watchdog timer
  startWatchdog()

  -- Pause CaveBot if it's running
  if CaveBot then
    CaveBot.setOff()
    cavebotOffByDustTracker = true
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Paused CaveBot for dust check", 18)
  end

  -- Check if we're already at/near the forge (skip navigation entirely)
  local playerPos = player:getPosition()
  if playerPos then
    local distanceToForge = getDistanceBetween(playerPos, FORGE_POS)
    if distanceToForge <= MAX_FORGE_DISTANCE then
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Already near forge (distance: " .. distanceToForge .. "), opening directly!", 18)
      openExaltationForgeNearby()
      return true
    end
  end

  -- Wait until not in battle
  local function checkBattleAndTeleport()
    if isInBattle() then
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Waiting for battle to end...", 18)
      schedule(2000, checkBattleAndTeleport) -- Check again in 2 seconds
      return
    end

    -- Store position before teleport to verify it worked
    local preTeleportPos = player:getPosition()
    local teleportRetryCount = 0
    local MAX_TELEPORT_RETRIES = 3

    -- Not in battle, teleport to temple
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Battle ended, teleporting to temple...", 18)
    say("!tp 2")

    -- Function to verify teleport and start navigation
    local function verifyTeleportAndNavigate()
      local playerPos = player:getPosition()
      if not playerPos then
        modules.game_textmessage.displayGameMessage("[Dust Tracker] ERROR: Could not get player position after teleport", 18)
        teleportRetryCount = teleportRetryCount + 1
        if teleportRetryCount < MAX_TELEPORT_RETRIES then
          modules.game_textmessage.displayGameMessage("[Dust Tracker] Retrying teleport...", 18)
          say("!tp 2")
          schedule(TP_DELAY_AFTER_TELEPORT, verifyTeleportAndNavigate)
        end
        return
      end

      -- Check if position changed (teleport worked)
      local teleportWorked = true
      if preTeleportPos then
        if playerPos.x == preTeleportPos.x and playerPos.y == preTeleportPos.y and playerPos.z == preTeleportPos.z then
          teleportWorked = false
          modules.game_textmessage.displayGameMessage("[Dust Tracker] WARNING: Position unchanged after teleport!", 18)
        end
      end

      -- Check if we're near the first waypoint (expected temple area)
      local firstWaypoint = FORGE_WAYPOINTS[1]
      local distanceToFirst = getDistanceBetween(playerPos, {x = firstWaypoint.x, y = firstWaypoint.y, z = firstWaypoint.z})

      if not teleportWorked and distanceToFirst > 50 then
        teleportRetryCount = teleportRetryCount + 1
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Teleport may have failed (distance to waypoint 1: " .. distanceToFirst .. ")", 18)

        if teleportRetryCount < MAX_TELEPORT_RETRIES then
          modules.game_textmessage.displayGameMessage("[Dust Tracker] Retrying teleport (attempt " .. teleportRetryCount .. "/" .. MAX_TELEPORT_RETRIES .. ")...", 18)
          say("!tp 2")
          schedule(TP_DELAY_AFTER_TELEPORT, verifyTeleportAndNavigate)
          return
        else
          modules.game_textmessage.displayGameMessage("[Dust Tracker] Max teleport retries reached, proceeding anyway...", 18)
        end
      end

      modules.game_textmessage.displayGameMessage("[Dust Tracker] Teleport verified, starting navigation to forge...", 18)
      isNavigatingToForge = true
      currentWaypointIndex = 1
      lastPlayerPos = nil
      stuckCheckCount = 0
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Navigation flag set to TRUE, waypoint index: " .. currentWaypointIndex, 18)

      -- Immediately trigger first waypoint walk
      if firstWaypoint then
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Player position: " .. playerPos.x .. "," .. playerPos.y .. "," .. playerPos.z, 18)
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Starting walk to first waypoint: " .. firstWaypoint.x .. "," .. firstWaypoint.y .. "," .. firstWaypoint.z, 18)

        local distance = getDistanceBetween(playerPos, {x = firstWaypoint.x, y = firstWaypoint.y, z = firstWaypoint.z})
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Distance to first waypoint: " .. distance, 18)

        -- Check if we're already at the first waypoint (temple spawn point)
        if distance <= 1 then
          modules.game_textmessage.displayGameMessage("[Dust Tracker] Already at waypoint 1, skipping to waypoint 2", 18)
          currentWaypointIndex = 2

          -- Walk to second waypoint
          local secondWaypoint = FORGE_WAYPOINTS[2]
          if secondWaypoint then
            modules.game_textmessage.displayGameMessage("[Dust Tracker] Walking to waypoint 2", 18)
            autoWalk({x = secondWaypoint.x, y = secondWaypoint.y, z = secondWaypoint.z}, 20, {ignoreNonPathable = true, precision = 1})

            -- Start the navigation loop
            schedule(1000, navigateToNextWaypoint)
          end
        else
          modules.game_textmessage.displayGameMessage("[Dust Tracker] Walking to first waypoint", 18)
          autoWalk({x = firstWaypoint.x, y = firstWaypoint.y, z = firstWaypoint.z}, 20, {ignoreNonPathable = true, precision = 1})

          -- Start the navigation loop
          schedule(1000, navigateToNextWaypoint)
        end
      end
    end

    -- Wait for teleport delay, then verify and start navigation
    schedule(TP_DELAY_AFTER_TELEPORT, verifyTeleportAndNavigate)
  end

  checkBattleAndTeleport()
  return true
end

-- Helper function to open forge when already nearby
openExaltationForgeNearby = function()
  modules.game_textmessage.displayGameMessage("[Dust Tracker] Attempting to open forge (interaction attempt " .. (forgeInteractionRetryCount + 1) .. "/" .. MAX_FORGE_INTERACTION_RETRIES .. ")", 18)

  -- Get the forge tile
  local forgeTile = g_map.getTile(FORGE_POS)
  if not forgeTile then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] ERROR: Forge tile not found at position", 18)
    forgeInteractionRetryCount = forgeInteractionRetryCount + 1
    if forgeInteractionRetryCount < MAX_FORGE_INTERACTION_RETRIES then
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Retrying forge interaction in 2 seconds...", 18)
      schedule(2000, openExaltationForgeNearby)
    else
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Max forge interaction retries reached!", 18)
    end
    return false
  end

  -- Get the top thing on the forge tile (the forge itself)
  local forgeThing = forgeTile:getTopUseThing()
  if not forgeThing then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] ERROR: No forge object found at position", 18)
    forgeInteractionRetryCount = forgeInteractionRetryCount + 1
    if forgeInteractionRetryCount < MAX_FORGE_INTERACTION_RETRIES then
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Retrying forge interaction in 2 seconds...", 18)
      schedule(2000, openExaltationForgeNearby)
    else
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Max forge interaction retries reached!", 18)
    end
    return false
  end

  modules.game_textmessage.displayGameMessage("[Dust Tracker] Forge ID: " .. forgeThing:getId(), 18)
  modules.game_textmessage.displayGameMessage("[Dust Tracker] Using forge on player position", 18)

  -- Use the forge on the player's position
  g_game.useWith(forgeThing, player)

  modules.game_textmessage.displayGameMessage("[Dust Tracker] Exaltation Forge use command sent", 18)

  -- Wait for window to open, then click the Raise Limit button with retry logic
  schedule(1500, function()
    local success = clickRaiseLimitButton(forgeThing)
    if not success then
      forgeWindowRetryCount = forgeWindowRetryCount + 1
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Window interaction failed (attempt " .. forgeWindowRetryCount .. "/" .. MAX_FORGE_WINDOW_RETRIES .. ")", 18)

      if forgeWindowRetryCount < MAX_FORGE_WINDOW_RETRIES then
        -- Try clicking the forge again and retry window interaction
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Retrying: re-opening forge and trying again in 2 seconds...", 18)
        g_game.useWith(forgeThing, player)
        schedule(2000, function()
          local retrySuccess = clickRaiseLimitButton(forgeThing)
          if not retrySuccess then
            forgeWindowRetryCount = forgeWindowRetryCount + 1
            if forgeWindowRetryCount < MAX_FORGE_WINDOW_RETRIES then
              modules.game_textmessage.displayGameMessage("[Dust Tracker] Still failing, scheduling another retry...", 18)
              schedule(2000, function()
                g_game.useWith(forgeThing, player)
                schedule(1500, function()
                  clickRaiseLimitButton(forgeThing)
                end)
              end)
            else
              modules.game_textmessage.displayGameMessage("[Dust Tracker] Max window retries reached, watchdog will handle restart", 18)
            end
          end
        end)
      else
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Max window retries reached, watchdog will handle restart", 18)
      end
    end
  end)

  return true
end

-- Recursive navigation function
function navigateToNextWaypoint()
  modules.game_textmessage.displayGameMessage("[Dust Tracker] navigateToNextWaypoint() called", 18)

  if not isNavigatingToForge then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Navigation stopped (flag is false)", 18)
    return
  end

  local playerPos = player:getPosition()
  if not playerPos then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] No player position, retrying...", 18)
    schedule(500, navigateToNextWaypoint)
    return
  end

  modules.game_textmessage.displayGameMessage("[Dust Tracker] Player at: " .. playerPos.x .. "," .. playerPos.y .. "," .. playerPos.z, 18)

  -- Check if player is stuck (same position as last check)
  if lastPlayerPos and lastPlayerPos.x == playerPos.x and lastPlayerPos.y == playerPos.y and lastPlayerPos.z == playerPos.z then
    stuckCheckCount = stuckCheckCount + 1
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Player hasn't moved - stuck count: " .. stuckCheckCount .. "/" .. MAX_STUCK_CHECKS, 18)

    if stuckCheckCount >= MAX_STUCK_CHECKS then
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Player stuck! Force skipping to next waypoint", 18)
      currentWaypointIndex = currentWaypointIndex + 1
      stuckCheckCount = 0
      lastPlayerPos = nil

      -- Get next waypoint and try walking there
      local nextWaypoint = FORGE_WAYPOINTS[currentWaypointIndex]
      if nextWaypoint then
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Force walking to waypoint " .. currentWaypointIndex .. ": " .. nextWaypoint.x .. "," .. nextWaypoint.y .. "," .. nextWaypoint.z, 18)
        autoWalk({x = nextWaypoint.x, y = nextWaypoint.y, z = nextWaypoint.z}, 20, {ignoreNonPathable = false})
      end

      schedule(1000, navigateToNextWaypoint)
      return
    end
  else
    -- Player moved, reset stuck counter
    stuckCheckCount = 0
    lastPlayerPos = {x = playerPos.x, y = playerPos.y, z = playerPos.z}
  end

  -- Get current waypoint
  local waypoint = FORGE_WAYPOINTS[currentWaypointIndex]
  if not waypoint then
    -- Reached the end of waypoints
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Navigation complete! Opening forge...", 18)
    isNavigatingToForge = false
    openExaltationForgeNearby()
    return
  end

  modules.game_textmessage.displayGameMessage("[Dust Tracker] Current target: Waypoint " .. currentWaypointIndex, 18)

  -- Check if we've reached the current waypoint
  local distance = getDistanceBetween(playerPos, {x = waypoint.x, y = waypoint.y, z = waypoint.z})
  modules.game_textmessage.displayGameMessage("[Dust Tracker] Distance to waypoint " .. currentWaypointIndex .. ": " .. distance, 18)

  -- Check if this is the final waypoint at 538,490,6 (teleport to forge)
  if waypoint.x == 538 and waypoint.y == 490 and waypoint.z == 6 then
    -- Check if we either reached it (distance <= 1) OR we're suddenly far away (teleported)
    if distance <= 1 or distance > 100 then
      modules.game_textmessage.displayGameMessage("[Dust Tracker] At/passed teleport waypoint (538,490,6) - waiting 1.5 seconds then opening forge", 18)

      -- Stop navigation
      isNavigatingToForge = false

      -- Wait 1.5 seconds then open the forge
      schedule(1500, function()
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Opening exaltation forge after teleport...", 18)
        openExaltationForgeNearby()
      end)
      return
    end
  end

  if distance <= 1 then
    -- Reached waypoint, move to next
    modules.game_textmessage.displayGameMessage("[Dust Tracker] ✓ Waypoint " .. currentWaypointIndex .. "/" .. #FORGE_WAYPOINTS .. " reached", 18)

    -- Check if current waypoint has stairs to use
    if waypoint.useStairs then
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Using stairs at current position", 18)
      local currentTile = g_map.getTile(playerPos)
      if currentTile then
        local stairThing = currentTile:getTopUseThing()
        if stairThing then
          modules.game_textmessage.displayGameMessage("[Dust Tracker] Found stairs (ID: " .. stairThing:getId() .. "), using...", 18)
          g_game.use(stairThing)
        end
      end
      -- Wait for floor change before continuing
      schedule(1000, navigateToNextWaypoint)
      currentWaypointIndex = currentWaypointIndex + 1
      return
    end

    currentWaypointIndex = currentWaypointIndex + 1

    -- Get next waypoint
    local nextWaypoint = FORGE_WAYPOINTS[currentWaypointIndex]
    if nextWaypoint then
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Walking to waypoint " .. currentWaypointIndex .. ": " .. nextWaypoint.x .. "," .. nextWaypoint.y .. "," .. nextWaypoint.z, 18)

      if nextWaypoint.forceWalk or (nextWaypoint.z ~= playerPos.z) then
        autoWalk({x = nextWaypoint.x, y = nextWaypoint.y, z = nextWaypoint.z}, 20, {ignoreNonPathable = false})
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Using forceWalk (ignoreNonPathable=false)", 18)
      else
        autoWalk({x = nextWaypoint.x, y = nextWaypoint.y, z = nextWaypoint.z}, 20, {ignoreNonPathable = true, precision = 1})
        modules.game_textmessage.displayGameMessage("[Dust Tracker] Using normal walk (ignoreNonPathable=true)", 18)
      end
    end

    -- Continue navigation
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Scheduling next check in 1000ms", 18)
    schedule(1000, navigateToNextWaypoint)
  else
    -- Still walking, check again
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Still walking (distance: " .. distance .. "), checking again in 500ms", 18)
    schedule(500, navigateToNextWaypoint)
  end
end

-- Main tracking macro (with icon)
local dustTracker = macro(1000, "Dust Tracker", function()
  local currentTime = now
  local timeSinceLastCheck = currentTime - lastCheckTime

  -- Check if it's time to request dust count
  if timeSinceLastCheck >= CHECK_INTERVAL then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Timer triggered! Time since last: " .. timeSinceLastCheck .. "ms", 18)

    -- Update lastCheckTime FIRST to prevent multiple triggers
    lastCheckTime = currentTime

    -- Check if we need to visit the forge (threshold reached)
    if needsForgeVisit and not isNavigatingToForge then
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Visiting forge to raise dust limit...", 18)

      -- Start the forge visit sequence
      openExaltationForge()

      -- Reset the flag after initiating visit
      needsForgeVisit = false
    end

    -- Always say !dusts to check current count (only if not navigating)
    if not isNavigatingToForge then
      say("!dusts")
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Requested dust count", 18)
    end
  end
end)

-- Add visual icon to activate/deactivate dust tracker
addIcon("DustTracker", { item = { id = 45864, count = 1 }, text = "Dust Tracker" }, dustTracker)

-- Listen for the server response about dust count
onTextMessage(function(mode, text)
  if dustTracker:isOff() then return end

  -- Check for the dust count message in default chat
  -- Pattern: "You currently have X/Y exalted dusts."
  local lowerText = text:lower()

  if lowerText:find("you currently have") and lowerText:find("exalted dusts") then
    -- Extract the numbers using pattern matching
    -- Pattern matches: "X/Y" where X and Y are numbers
    local current, max = text:match("(%d+)/(%d+)")

    if current and max then
      -- Convert strings to numbers
      currentDusts = tonumber(current)
      maxDusts = tonumber(max)

      -- Display in server log (mode 18)
      modules.game_textmessage.displayGameMessage(
        "[Dust Tracker] Current Dusts: " .. currentDusts .. " / Max Dusts: " .. maxDusts,
        18
      )

      -- Calculate the percentage
      local percentage = math.floor((currentDusts / maxDusts) * 100)
      modules.game_textmessage.displayGameMessage(
        "[Dust Tracker] Progress: " .. percentage .. "%",
        18
      )

      -- Check if we've reached the threshold
      if percentage >= DUST_THRESHOLD_PERCENT then
        modules.game_textmessage.displayGameMessage(
          "[Dust Tracker] Threshold reached! (" .. percentage .. "% >= " .. DUST_THRESHOLD_PERCENT .. "%) - Will visit forge next check",
          18
        )
        needsForgeVisit = true
      end
    else
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Failed to parse dust count from: " .. text, 18)
    end
  end
end)

-- Helper function to manually trigger dust check (optional)
onKeyPress(function(keys)
  -- Press Ctrl+D to manually check dusts
  if dustTracker:isOn() and keys == "Ctrl+D" then
    -- Open the exaltation forge first
    openExaltationForge()

    -- Wait a moment for the forge to open
    schedule(1000, function()
      say("!dusts")
      modules.game_textmessage.displayGameMessage("[Dust Tracker] Manual dust check requested", 18)
    end)
  end

  -- Press Ctrl+Shift+D to debug windows (even when tracker is off)
  if keys == "Ctrl+Shift+D" then
    modules.game_textmessage.displayGameMessage("[Dust Tracker] Manual window debug requested", 18)
    debugListWindows()
  end
end)
