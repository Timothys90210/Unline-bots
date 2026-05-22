------------------------------------------------------
local secondsToIdle = 5
local activeFPS =  75
---------------------------------------------------------

local afkFPS = 0
function botPrintMessage(message)
  modules.game_textmessage.displayGameMessage(message)
end

botPrintMessage("[Idle-Mode] made by: VivoDibra#1182")

local function isSameMousePos(p1,p2)
  return p1.x == p2.x and p1.y == p2.y
end

local function setAfk()
  modules.client_options.setOption("backgroundFrameRate", afkFPS)
  modules.game_interface.gameMapPanel:hide()
end

local function setActive()
  modules.client_options.setOption("backgroundFrameRate", activeFPS)
  modules.game_interface.gameMapPanel:show()
end

local lastMousePos = nil
local finalMousePos = nil
local idleCount = 0
local maxIdle = secondsToIdle * 4
macro(250, "Idle Mode", function()
  local currentMousePos = g_window.getMousePosition()

  if finalMousePos then
    if isSameMousePos(finalMousePos,currentMousePos) then return end
    botPrintMessage("(Idle Mode) Active!")
    setActive()
    finalMousePos = nil
  end

  if lastMousePos and isSameMousePos(lastMousePos,currentMousePos) then
    idleCount = idleCount + 1
  else
    lastMousePos = currentMousePos
    idleCount = 0
  end

  if idleCount == maxIdle then
    botPrintMessage("(Idle Mode) AFK!")
    setAfk()
    finalMousePos = currentMousePos
    idleCount = 0
  end

end)