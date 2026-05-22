local filterDamage = macro(100, "Filter Damage Messages", function() end)

-- Store original console addText function
local console = modules.game_console
local originalAddText = console.addText

-- Override the addText function with a wrapper that checks state each time
console.addText = function(text, style, tab, ...)
  -- If filter is OFF, use original function directly
  if not filterDamage.isOn() then
    return originalAddText(text, style, tab, ...)
  end

  -- Filter is ON - apply filtering logic

  -- Block messages starting with "You gained", "You lose", or "You were"
  if text then
    if text:find("^You gained") or text:find("^You lose") or text:find("^You were") then
      -- Don't call the original function - effectively blocks the message
      return
    end
  end

  -- When text contains damage keywords, color it
  if text then
    if text:find("loses") or text:find("hitpoints") or text:find("damage") then
      -- Create a new style table to avoid modifying the original
      local newStyle = style or {}
      local modifiedStyle = {}
      for k, v in pairs(newStyle) do
        modifiedStyle[k] = v
      end
      modifiedStyle.color = '#00FFFF'
      -- Call with modified style
      return originalAddText(text, modifiedStyle, tab, ...)
    end
  end

  -- Otherwise, call the original function to display the message
  return originalAddText(text, style, tab, ...)
end

modules.game_textmessage.displayGameMessage("[Damage Filter] Loaded successfully - use button to toggle", 19)
