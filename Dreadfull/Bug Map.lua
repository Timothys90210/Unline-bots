local function checkPos(x, y)
  xyz = g_game.getLocalPlayer():getPosition()
  xyz.x = xyz.x + x
  xyz.y = xyz.y + y
  tile = g_map.getTile(xyz)
  if tile then
    autoWalk(tile:getPosition(), 20, {ignoreNonPathable=true, precision=3})
  end
end

consoleModule = modules.game_console
macro(1, 'Bug Map', function() 
  if modules.corelib.g_keyboard.isKeyPressed('up') then
    checkPos(0, -5)
  elseif modules.corelib.g_keyboard.isKeyPressed('right') then
    checkPos(5, 0)
  elseif modules.corelib.g_keyboard.isKeyPressed('down') then
    checkPos(0, 5)
  elseif modules.corelib.g_keyboard.isKeyPressed('left') then
    checkPos(-5, 0)
  end
end)