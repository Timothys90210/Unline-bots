local autoUtamoVita = macro(250, "Auto Utamo Vita", function()
    if hppercent() < 55 and not hasManaShield() then
        say("utamo vita")
    elseif hppercent() > 90 and hasManaShield() then

        say("utamo vita")
    end
end)

addIcon("AutoUtamoVita", {item=3321, text="Utamo"}, function(icon, isOn)
    if isOn then
        autoUtamoVita.setOn(true)
    else
        autoUtamoVita.setOn(false)
        -- Solo lanza utamo vita si no tienes el buff activo
        if not hasManaShield() then
            say("utamo vita")
        end
    end
end)