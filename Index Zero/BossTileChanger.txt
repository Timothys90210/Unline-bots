setDefaultTab("BOSS")
local fastTiles = macro(10000, "Fast Tiles", function() end)
--Fast Tiles
local sandStone = 415
local iceTile = 7151
local blackMarble = 410
--[ConfigTileID]----------
local tileId = blackMarble
--------------------------
onAddThing(function(tile, thing)
  if fastTiles:isOff() or 
  not tile:isWalkable(true) or 
  tile:isHouseTile() then return end
  if thing:isFullGround() then
    thing:setId(tileId)
  end
end)