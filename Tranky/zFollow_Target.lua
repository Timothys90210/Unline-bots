setDefaultTab("Main")
UI.Separator()

local toFollowPos = {}
local lastToggleTime = 0
local disableDistance = 8     -- Friend nearby = disable cavebot
local enableDistance = 12     -- Friend far/off-screen = enable cavebot
local toggleCooldown = 2000   -- ms between toggles

-- Main follow macro
local followMacro = macro(100, "Follow Target", function()
  local friendName = storage.followFriend
  if not friendName or friendName:len() == 0 then return end

  local now = now
  local target = getCreatureByName(friendName)
  local friendVisible = false
  local friendDistance = 9999

  if target then
    local tpos = target:getPosition()
    toFollowPos[tpos.z] = tpos
    friendVisible = true
    friendDistance = getDistanceBetween(pos(), tpos)
  end

  -- Toggle Cavebot state with cooldown
  if now - lastToggleTime >= toggleCooldown then
    if friendVisible and friendDistance <= disableDistance then
      if CaveBot.isOn() then
        CaveBot.setOff()
        lastToggleTime = now
        print(string.format("[Follow] Friend is near (%d sqm), disabling CaveBot.", friendDistance))
      end
    elseif (not friendVisible) or friendDistance > enableDistance then
      if not CaveBot.isOn() then
        CaveBot.setOn()
        lastToggleTime = now
        print(string.format("[Follow] Friend is far/off-screen (%d sqm), enabling CaveBot.", friendDistance))
      end
    end
  end

  -- Walking logic
  if player:isWalking() then return end

  local p = toFollowPos[posz()]
  if not p then return end

  if autoWalk(p, 20, {ignoreNonPathable=true, precision=1, ignoreStairs=false}) then
    delay(100)
  end
end)

-- Friend name input box
addTextEdit("followfriend", storage.followFriend or "", function(widget, text)
  storage.followFriend = text
end)

-- Update stored position when friend moves
onCreaturePositionChange(function(creature, newPos, oldPos)
  if creature:getName() == storage.followFriend then
    toFollowPos[newPos.z] = newPos
  end
end)
