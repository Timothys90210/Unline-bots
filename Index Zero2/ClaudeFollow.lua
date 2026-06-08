if ClaudeFollowLoaded then return end
ClaudeFollowLoaded = true

setDefaultTab("BOSS")
addLabel("Label", "Follow Name")
addTextEdit("TxtEdit", storage.fName or "name", function(widget, text)
  storage.fName = text
end)
--------------------------
local targetPos = nil
local walkDelay = 0

macro(20, "Claude Follow", function()
  local leader = getCreatureByName(storage.fName)
  if not leader then return end

  local leaderPos = leader:getPosition()
  local playerPos = player:getPosition()

  -- Check if player is on the same tile as leader
  if leaderPos.x == playerPos.x and leaderPos.y == playerPos.y and leaderPos.z == playerPos.z then
    targetPos = nil
    walkDelay = 0
    return
  end

  -- Calculate if leader moved
  local leaderMoved = not targetPos or targetPos.x ~= leaderPos.x or targetPos.y ~= leaderPos.y or targetPos.z ~= leaderPos.z

  if leaderMoved then
    targetPos = {x = leaderPos.x, y = leaderPos.y, z = leaderPos.z}
    walkDelay = 0
  end

  -- Only walk if delay counter is 0
  if walkDelay > 0 then
    walkDelay = walkDelay - 1
    return
  end

  -- Calculate direction to leader
  local dx = leaderPos.x - playerPos.x
  local dy = leaderPos.y - playerPos.y
  local dz = leaderPos.z - playerPos.z

  -- Check if we need floor change
  if dz ~= 0 then
    player:autoWalk(leaderPos)
    walkDelay = 5
    return
  end

  -- Calculate which direction to move
  local dir = nil

  -- Determine direction based on distance
  if dx > 0 and dy > 0 then
    dir = SouthEast
  elseif dx > 0 and dy < 0 then
    dir = NorthEast
  elseif dx < 0 and dy > 0 then
    dir = SouthWest
  elseif dx < 0 and dy < 0 then
    dir = NorthWest
  elseif dx > 0 then
    dir = East
  elseif dx < 0 then
    dir = West
  elseif dy > 0 then
    dir = South
  elseif dy < 0 then
    dir = North
  end

  if dir then
    g_game.walk(dir)
    walkDelay = 5  -- Wait 5 cycles (100ms) before next walk
  end
end)