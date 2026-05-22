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

-- here you can set manually order of scripts
-- libraries should be loaded first
local luaFiles = {
  "main",
  "items",
  "vlib",
  "new_cavebot_lib",
  "configs", -- do not change this and above
  "extras",
  "cavebot",
  "playerlist",
  "alarms",
  "Conditions",
  "Equipper",
  "HealBot",
  "new_healer",
  "AttackBot", -- last of major modules
  "ingame_editor",
  "Dropper",
  "drop_empty_bp",
  "Containers",
  "tools",
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

for i, file in ipairs(luaFiles) do
  loadScript(file)
end

setDefaultTab("_")
UI.Separator()
dofile("/vBot/autoImbue.lua")
UI.Separator()
UI.Separator()
dofile("DivineGrenade.lua")

dofile("EquipCheck.lua")
