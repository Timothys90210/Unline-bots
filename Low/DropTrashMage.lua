setDefaultTab("Tools")

local trashItems = {
  [814] = true,
  [830] = true,
  [8082] = true,
  [3286] = true,
  [7440] = true,
  [27284] = true,
  [23375] = true,
  [3115] = true,
  [7439] = true,
  [3367] = true,
  [3276] = true,
  [3411] = true,
  [3065] = true,
  [811] = true,
  [7443] = true
  --[52764] = true
}

macro(200, "Drop Trash", function()
  for _, container in pairs(getContainers()) do
    for i, item in ipairs(container:getItems()) do
      if trashItems[item:getId()] then
        g_game.move(item, pos(), item:getCount())
      end
    end
  end
end)
