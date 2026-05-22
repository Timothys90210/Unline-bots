-- ── Imbuing Config UI (Tools tab) ───────────────────────────────────────────
setDefaultTab("Tools")

if type(storage.imbuingConfig) ~= "table" or type(storage.imbuingConfig.helmet) ~= "table" then
  storage.imbuingConfig = {
    helmet      = {0, 0},
    armor       = {0, 0, 0},
    weapon      = {0, 0, 0},
    weaponright = {0, 0, 0},
    shield      = {0, 0, 0},
    doll        = {0, 0, 0},
  }
end
-- Upgrade: add weaponright if missing from older saves
if type(storage.imbuingConfig.weaponright) ~= "table" then
  storage.imbuingConfig.weaponright = {0, 0, 0}
end
local config = storage.imbuingConfig

local imbuingUi = setupUI([[
Panel
  height: 140

  Label
    id: title
    text: Imbuing Config
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 16
    text-align: center
    font: verdana-11px-rounded

  Panel
    id: headerRow
    anchors.top: title.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 14

    UIWidget
      width: 72
      anchors.left: parent.left

    Label
      id: hdr1
      text: Slot 1
      width: 36
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center
      font: verdana-11px-rounded

    Label
      id: hdr2
      text: Slot 2
      width: 36
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center
      font: verdana-11px-rounded

    Label
      id: hdr3
      text: Slot 3
      width: 36
      anchors.left: prev.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center
      font: verdana-11px-rounded

  Panel
    id: helmetRow
    anchors.top: headerRow.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 18

    UIWidget
      id: lbl
      text: Helmet
      width: 72
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      font: verdana-11px-rounded
      text-align: left

    BotTextEdit
      id: val1
      width: 36
      height: 16
      anchors.left: lbl.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

    BotTextEdit
      id: val2
      width: 36
      height: 16
      anchors.left: val1.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

  Panel
    id: armorRow
    anchors.top: helmetRow.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 18

    UIWidget
      id: lbl
      text: Armor
      width: 72
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      font: verdana-11px-rounded
      text-align: left

    BotTextEdit
      id: val1
      width: 36
      height: 16
      anchors.left: lbl.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

    BotTextEdit
      id: val2
      width: 36
      height: 16
      anchors.left: val1.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

    BotTextEdit
      id: val3
      width: 36
      height: 16
      anchors.left: val2.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

  Panel
    id: weaponRow
    anchors.top: armorRow.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 18

    UIWidget
      id: lbl
      text: Weapon
      width: 72
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      font: verdana-11px-rounded
      text-align: left

    BotTextEdit
      id: val1
      width: 36
      height: 16
      anchors.left: lbl.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

    BotTextEdit
      id: val2
      width: 36
      height: 16
      anchors.left: val1.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

    BotTextEdit
      id: val3
      width: 36
      height: 16
      anchors.left: val2.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

  Panel
    id: weaponrightRow
    anchors.top: weaponRow.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 18

    UIWidget
      id: lbl
      text: Weapon Right
      width: 72
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      font: verdana-11px-rounded
      text-align: left

    BotTextEdit
      id: val1
      width: 36
      height: 16
      anchors.left: lbl.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

    BotTextEdit
      id: val2
      width: 36
      height: 16
      anchors.left: val1.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

    BotTextEdit
      id: val3
      width: 36
      height: 16
      anchors.left: val2.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

  Panel
    id: shieldRow
    anchors.top: weaponrightRow.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 18

    UIWidget
      id: lbl
      text: Shield/Right
      width: 72
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      font: verdana-11px-rounded
      text-align: left

    BotTextEdit
      id: val1
      width: 36
      height: 16
      anchors.left: lbl.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

    BotTextEdit
      id: val2
      width: 36
      height: 16
      anchors.left: val1.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

    BotTextEdit
      id: val3
      width: 36
      height: 16
      anchors.left: val2.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center

  Panel
    id: dollRow
    anchors.top: shieldRow.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 18

    UIWidget
      id: lbl
      text: Doll
      width: 72
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      font: verdana-11px-rounded
      text-align: left

    BotTextEdit
      id: val1
      width: 36
      height: 16
      anchors.left: lbl.right
      anchors.verticalCenter: parent.verticalCenter
      margin-left: 2
      text-align: center
]])

local rowBindings = {
  {key="helmet", row=imbuingUi.helmetRow, slots=2},
  {key="armor",  row=imbuingUi.armorRow,  slots=3},
  {key="weapon",      row=imbuingUi.weaponRow,      slots=3},
  {key="weaponright", row=imbuingUi.weaponrightRow, slots=3},
  {key="shield",      row=imbuingUi.shieldRow,      slots=3},
  {key="doll",   row=imbuingUi.dollRow,   slots=1},
}

for _, entry in ipairs(rowBindings) do
  local vals = config[entry.key]
  for i = 1, entry.slots do
    local field = entry.row["val" .. i]
    field:setText(vals[i] > 0 and tostring(vals[i]) or "")
    local slot = i
    field.onTextChange = function(widget, text)
      vals[slot] = tonumber(text) or 0
    end
  end
end
