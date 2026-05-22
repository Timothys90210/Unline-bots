-- TierInfo.lua
-- Opens a window showing Boost Categories and Tier Values table

setDefaultTab("Tools")

g_ui.loadUIFromString([[
TierInfoRow < Panel
  height: 18
  layout:
    type: horizontalBox

  Label
    id: cat
    width: 110
    height: 18
    text-align: center
    font: verdana-11px-rounded
    color: #cccccc

  Label
    id: boost
    width: 155
    height: 18
    text-align: center
    font: verdana-11px-rounded
    color: #cccccc

  Label
    id: t1
    width: 45
    height: 18
    text-align: center
    font: verdana-11px-rounded
    color: #cccccc

  Label
    id: t2
    width: 45
    height: 18
    text-align: center
    font: verdana-11px-rounded
    color: #cccccc

  Label
    id: t3
    width: 45
    height: 18
    text-align: center
    font: verdana-11px-rounded
    color: #cccccc

TierInfoWindow < MainWindow
  text: Boost Tier Values
  size: 430 400
  padding: 15
  @onEscape: self:hide()

  Panel
    id: header
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 20
    background-color: #111111
    layout:
      type: horizontalBox

    Label
      width: 110
      height: 20
      text: Category
      text-align: center
      font: verdana-11px-rounded
      color: #ffffff

    Label
      width: 155
      height: 20
      text: Boost
      text-align: center
      font: verdana-11px-rounded
      color: #ffffff

    Label
      width: 45
      height: 20
      text: T1
      text-align: center
      font: verdana-11px-rounded
      color: #ffffff

    Label
      width: 45
      height: 20
      text: T2
      text-align: center
      font: verdana-11px-rounded
      color: #ffffff

    Label
      width: 45
      height: 20
      text: T3
      text-align: center
      font: verdana-11px-rounded
      color: #ffffff

  Panel
    id: tableContent
    anchors.top: header.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: separator.top
    margin-top: 2
    margin-bottom: 5
    layout:
      type: verticalBox

  HorizontalSeparator
    id: separator
    anchors.right: parent.right
    anchors.left: parent.left
    anchors.bottom: closeButton.top
    margin-bottom: 8

  Button
    id: closeButton
    !text: tr('Close')
    font: cipsoftFont
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 45 21
    margin-right: 5
    @onClick: self:getParent():hide()
]])

local tierData = {
  { category = "Damage",     boost = "Strike (Crit)",    t1 = 1,  t2 = 2,  t3 = 3  },
  { category = "Damage",     boost = "Vampirism (Life)", t1 = 4,  t2 = 5,  t3 = 6  },
  { category = "Damage",     boost = "Void (Mana)",      t1 = 7,  t2 = 8,  t3 = 9  },
  { category = "Protection", boost = "Death Prot",       t1 = 10, t2 = 11, t3 = 12 },
  { category = "Protection", boost = "Earth Prot",       t1 = 13, t2 = 14, t3 = 15 },
  { category = "Protection", boost = "Fire Prot",        t1 = 16, t2 = 17, t3 = 18 },
  { category = "Protection", boost = "Ice Prot",         t1 = 19, t2 = 20, t3 = 21 },
  { category = "Protection", boost = "Energy Prot",      t1 = 22, t2 = 23, t3 = 24 },
  { category = "Protection", boost = "Holy Prot",        t1 = 25, t2 = 26, t3 = 27 },
  { category = "Skills",     boost = "Magic Level",      t1 = 28, t2 = 29, t3 = 30 },
  { category = "Skills",     boost = "Club",             t1 = 31, t2 = 32, t3 = 33 },
  { category = "Skills",     boost = "Sword",            t1 = 34, t2 = 35, t3 = 36 },
  { category = "Skills",     boost = "Axe",              t1 = 37, t2 = 38, t3 = 39 },
  { category = "Skills",     boost = "Distance",         t1 = 40, t2 = 41, t3 = 42 },
  { category = "Skills",     boost = "Shield",           t1 = 43, t2 = 44, t3 = 45 },
}

local window = UI.createWindow("TierInfoWindow")
window:hide()

for i, row in ipairs(tierData) do
  local rowWidget = g_ui.createWidget("TierInfoRow", window.tableContent)
  rowWidget:setBackgroundColor((i % 2 == 0) and "#222222" or "#2a2a2a")
  rowWidget.cat:setText(row.category)
  rowWidget.boost:setText(row.boost)
  rowWidget.t1:setText(tostring(row.t1))
  rowWidget.t2:setText(tostring(row.t2))
  rowWidget.t3:setText(tostring(row.t3))
end

UI.Button("Tier Info", function()
  window:show()
  window:raise()
  window:focus()
end)
