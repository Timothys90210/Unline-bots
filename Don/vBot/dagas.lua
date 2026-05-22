UI.Separator()

local armaDerecha = 35585

-- Usamos el valor almacenado en storage para equipar y desequipar la arma
function DagaDerecha()
  -- check if it is attacking
    -- checa si tiene arma
    if not getRight() or getRight():getId() ~= armaDerecha then
      -- equip arma 
      moveToSlot(armaDerecha, SlotRight)
      return
    end
end



local armaIzquierda = 35581

function DagaIzquierda()
	if not getLeft() or getLeft():getId() ~= armaIzquierda then
-- equipar arma
	moveToSlot(armaIzquierda, SlotLeft)
	return
	end

end