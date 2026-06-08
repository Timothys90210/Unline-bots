-- load all otui files, order doesn't matter
local configName = modules.game_bot.contentsPanel.config:getCurrentOption().text

local configFiles = g_resources.listDirectoryFiles("/bot/" .. configName .. "/vBot", true, false)
for i, file in ipairs(configFiles) do
  local ext = file:split(".")
  if ext[#ext]:lower() == "ui" or ext[#ext]:lower() == "otui" then
    g_ui.importStyle(file)
  end
end

local function loadScript(name)
  return dofile("/vBot/" .. name .. ".lua")
end

-- libraries and core modules (do not reorder)
local coreFiles = {
  "main",
  "items",
  "vlib",
  "new_cavebot_lib",
  "configs",
  "extras",
  "cavebot",
  "playerlist",
  "alarms",
  "Conditions",
  "Equipper",
  "HealBot",
}

for i, file in ipairs(coreFiles) do
  loadScript(file)
end

-- Probe tab loads here so it appears right after HP
dofile("probe.lua")

-- remaining modules
local remainingFiles = {
  "new_healer",
  "AttackBot", -- last of major modules
  "ingame_editor",
  "Dropper",
  "Containers",
  "tools",
  "AutoMount",
  "imbuing_config",
  "eat_food",
  "equip",
  "supplies",
  "depositer_config",
  "npc_talk",
  "xeno_menu",
  "hold_target",
  "bottools",
  "Open full BPs"
}

for i, file in ipairs(remainingFiles) do
  loadScript(file)
end

setDefaultTab("_")
UI.Separator()
dofile("/vBot/autoImbue.lua")
UI.Separator()
dofile("Terminal.lua")

-- dofile("ImbuementChecker.lua")
dofile("AddCoins.lua")

dofile("EquipCheck.lua")

dofile("Stances.lua")

dofile("Waves.lua")

dofile("StowAll.lua")
