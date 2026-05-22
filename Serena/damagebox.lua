local filterDamage = macro(100, "Filter Damage Messages", function() end)

-- Store original console addText function
local console = modules.game_console
local originalAddText = console.addText

-- Override the addText function to filter messages
console.addText = function(text, style, tab, ...)
  -- When filter is ON, block messages starting with "You gained", "You lose", or "You were"
  if filterDamage.isOn() and text then
    if text:find("^You gained") or text:find("^You lose") or text:find("^You were") then
      -- Don't call the original function - effectively blocks the message
      return
    end
  end

  -- When filter is ON and text contains damage keywords, color it
  if filterDamage.isOn() and text then
    if text:find("loses") or text:find("hitpoints") or text:find("damage") then
      -- Change color to bright cyan/blue for damage messages
      style = style or {}
      style.color = '#00FFFF'
    end
  end

  -- Otherwise, call the original function to display the message
  return originalAddText(text, style, tab, ...)
end

modules.game_textmessage.displayGameMessage("[Damage Filter] Loaded successfully - use button to toggle", 19)
