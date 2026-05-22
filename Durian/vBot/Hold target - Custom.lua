setDefaultTab("Boss")
UI.Separator()

local targetID = nil
local markedCreature = nil
local HOLD_COLOR = "#3EFF00"

local function clearMark()
  if markedCreature then
    markedCreature:setMarked("")
    markedCreature = nil
  end
end

-- escape when attacking will reset hold target
onKeyPress(function(keys)
  if keys == "Escape" and targetID then
    clearMark()
    targetID = nil
  end
end)

macro(100, "Highlight and Hold Target", function()
  if target() and target():getPosition().z == posz() and not target():isNpc() then
    local t = target()
    if t:getId() ~= targetID then
      clearMark()
      targetID = t:getId()
    end
    markedCreature = t
    t:setMarked(HOLD_COLOR)
  elseif not target() then
    if not targetID then
      clearMark()
      return
    end

    local found = false
    for _, spec in ipairs(getSpectators()) do
      if spec:getPosition().z == posz() and spec:getId() == targetID then
        found = true
        attack(spec)
        markedCreature = spec
        spec:setMarked(HOLD_COLOR)
      end
    end

    -- creature is gone, clean up
    if not found then
      clearMark()
      targetID = nil
    end
  end
end)
