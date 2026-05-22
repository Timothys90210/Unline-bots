-- You can place this at the end of your script or inside the onTextMessage section
onTextMessage(function(mode, text)
    local msg = text:lower()
    
    -- Detect that a pet was born
    if msg:find("congratulations! you have tamed") then
        
        -- If it does NOT contain the word "shiny"
        if not msg:find("shiny") then
            -- Say the command for the first time
            say("!releasepet")
            
            -- Wait 300ms and say the second command to confirm
            schedule(300, function()
                say("!releasepet")
            end)
            
            -- Optional: print to console for your reference
            warn ("Normal pet detected. Releasing...")
        else
            -- If it's shiny, do nothing (keep it)
            say ("SHINY PET OBTAINED! It will not be released.")
        end
    end
end)