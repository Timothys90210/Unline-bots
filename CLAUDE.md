# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## SESSION START

1. Read tasks/lessons.md — apply all lessons before touching anything

2. Read tasks/todo.md — understand current state

3. If neither exists, create them before starting

 

## WORKFLOW

 

### 1. Plan First

- Enter plan mode for any non-trivial task (3+ steps)

- Write plan to tasks/todo.md before implementing

- If something goes wrong, STOP and re-plan — never push through

 

### 2. Subagent Strategy

- Use subagents to keep main context clean

- One task per subagent

- Throw more compute at hard problems

 

### 3. Self-Improvement Loop

- After any correction: update tasks/lessons.md

- Format: [date] | what went wrong | rule to prevent it

- Review lessons at every session start

 

### 4. Verification Standard

- Never mark complete without proving it works

- Run tests, check logs, diff behavior

- Ask: "Would a staff engineer approve this?"

 

### 5. Demand Elegance

- For non-trivial changes: is there a more elegant solution?

- If a fix feels hacky: rebuild it properly

- Don't over-engineer simple things

 

### 6. Autonomous Bug Fixing

- When given a bug: just fix it

- Go to logs, find root cause, resolve it

- No hand-holding needed

 

## CORE PRINCIPLES

- Simplicity First — touch minimal code

- No Laziness — root causes only, no temp fixes

- Never Assume — verify paths, APIs, variables before using

- Ask Once — one question upfront if unclear, never interrupt mid-task

- Low Code Cost — scripts run on game ticks (50ms–2000ms); every macro must be cheap. Prefer integer comparisons and local table lookups over creature scans, container iteration, or pathfinding calls. Only call expensive APIs (findPath, getSpectators, g_map.getSpectatorsInRange) when necessary, gate them behind early exits, and never call them on every tick without a guard. When adding functionality, ask: what does this do every tick, and is that cost justified?

 

## TASK MANAGEMENT

1. Plan → tasks/todo.md

2. Verify → confirm before implementing

3. Track → mark complete as you go

4. Explain → high-level summary each step

5. Commit → create git commit to DEV branch after each completed task

6. Learn → tasks/lessons.md after corrections

## Project Overview

This is a **Tibia game bot automation framework** written in Lua. It runs as a client extension (likely OTClient or similar) and automates gameplay including cave hunting, combat targeting, healing, and item management. There is no build system — scripts are loaded and interpreted directly by the Tibia client.

## Architecture

### Multi-Character Structure

The repo contains 14 character profiles (e.g., `Don/`, `Grayson/`, `Serena/`, `vBot_4.8/`) plus a legacy `cavebot_1.3/`. Each character directory has its own `_Loader.lua` that defines load order for that character's modules.

### Load Order (`_Loader.lua`)

Scripts are loaded in a strict sequence:
1. UI definitions (`.otui` files via `importStyle`)
2. Core libraries: `main`, `items`, `vlib`, `new_cavebot_lib`
3. Config system
4. Major modules: `cavebot`, `targetbot`, `AttackBot`, `HealBot`, `Equipper`, `Conditions`
5. Utility modules: `Dropper`, `Containers`, `tools`, etc.

### Global Namespace

All bot state lives under the `vBot` global table (e.g., `vBot.standTime`, `vBot.isUsingPotion`). Module-level globals like `CaveBot`, `TargetBot` expose their APIs.

### Three Core Modules

**CaveBot** (`cavebot/cavebot.lua`):
- Main 20ms macro loop that processes a sequential action list
- Each action callback must return `"retry"` (re-run), `true` (advance), or `false` (skip)
- Actions registered in `CaveBot.Actions[]`; extensions in `CaveBot.Extensions[]`
- Pauses automatically when TargetBot is active

**TargetBot** (`targetbot/target.lua`):
- Handles creature tracking (`creature.lua`), attack patterns (`creature_attack.lua`), and looting (`looting.lua`)
- Integrates with CaveBot's pause system during combat

**vBot** (`vBot/` directory — shared across characters via `vBot_4.8/`):
- `vlib.lua` — core utility functions
- `items.lua` — item database
- `AttackBot.lua` — spell/rune patterns (cross, bomb, area targeting)
- `HealBot.lua` — healing automation with up to 5 profiles
- `Equipper.lua` — conditional equipment swapping (70+ condition types)
- `Conditions.lua` — reusable decision logic

### Configuration System

- Per-character JSON profiles stored in `vBot_configs/profile_N/[ModuleName].json` (e.g., `AttackBot.json`, `HealBot.json`, `Supplies.json`)
- Hunting paths stored as `.cfg` files in `cavebot_configs/` — line-based format with fields like `action:`, `function:`, `delay:`, `config:`, `extensions:`
- Config loaded via `Config.setup()` at startup; persisted through `storage` table

### Event Model

- **Macros**: `macro(interval_ms, callback)` — recurring timers
- **Schedules**: `schedule(delay_ms, callback)` — one-shot delayed execution
- **Callbacks**: `onPlayerPositionChange()`, `onTextMessage()`, `onCreatureAppear()`, etc. (game engine hooks)

### UI System

`.otui` files define panels in OTClient's XML-like markup. Widgets (Panel, Button, Label, etc.) bind two-way to Lua variables. Layout is auto-managed.

## UI Widget Rules

- **Never use `TextEdit` or `SpinBox` for user-editable input inside bot panels** — they are not focusable in this context. Always use `BotTextEdit` for any field the user needs to type into.
- `setupUI([[...]])` creates a Panel in the currently active tab context. Call `setDefaultTab("TabName")` before `setupUI` to control which tab it appears in.
- `UI.Label(text)`, `UI.Separator()`, `UI.TextEdit()` etc. are tab-context-aware shorthand functions used in regular vBot scripts.
- Widget IDs within different parent panels do not conflict — `helmetRow.val1` and `armorRow.val1` are distinct even though both children are named `val1`.
- Avoid `anchors.right: parent.right` on the last element in a row if you want consistent sizing — give it an explicit `width` instead.

## Popup Window Pattern

Two approaches depending on where the script lives:

**Scripts inside `vBot/`** (loaded via `luaFiles` list in `_Loader.lua`):
- Can use a separate `.otui` file — the loader auto-imports all `.otui` files from `vBot/` at startup
- Instantiate with `UI.createWindow("WindowName")`, then `window:hide()`
- Show via `window:show()` / `window:raise()` / `window:focus()`

**Scripts in the character root directory** (loaded via `dofile` at bottom of `_Loader.lua`):
- **Must** define window styles inline using `g_ui.loadUIFromString([[...]])` — separate `.otui` files are NOT auto-loaded for these
- Same instantiation pattern after: `UI.createWindow("WindowName")` then `window:hide()`
- Reference example: `Stash.lua` (defines `StashDepositsWindow` inline)

**Window style template:**
```
MyWindow < MainWindow
  text: Window Title
  size: 400 300
  @onEscape: self:hide()
  -- children...
  Button
    id: closeButton
    !text: tr('Close')
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    size: 45 21
    @onClick: self:getParent():hide()
```

**Dynamic rows in a window** — define a row widget class in the same `loadUIFromString` block, then instantiate per row:
```lua
local row = g_ui.createWidget("MyRowClass", window.containerPanel)
row.someLabel:setText("value")
```
Use `layout: verticalBox` on the container panel so rows stack automatically.

## CaveBot Extension Pattern

- Extensions live in `cavebot/` and register via `CaveBot.Extensions.Foo = {}` + `CaveBot.Extensions.Foo.setup = function() ... end`
- `setup()` is called by `cavebot/cavebot.lua` after all extensions are loaded — do NOT put `setDefaultTab()` or `setupUI()` inside `setup()`; put that code at module top level so it runs at load time
- To have both a Tools tab UI **and** a cavebot action, split into two files: a `vBot/foo_config.lua` (loaded via `_Loader.lua` for the UI) and `cavebot/foo.lua` (for the extension). The config file loads first and populates `storage`, which the cavebot extension reads at runtime.
- Cavebot action callbacks must return `"retry"`, `true`, or `false`. State machines work well for multi-step actions.

## OTClient Inventory Slot Numbers

Confirmed slot numbers for this client:
| Slot | Number |
|------|--------|
| Head (Helmet) | 1 |
| Armor | 4 |
| Right hand (Shield) | 5 |
| Left hand (Weapon) | 6 |
| Ammo (Doll) | 10 |

Note: slot 9 is the **ring/finger** slot, NOT the doll/ammo slot. Slot 5 is right hand (shield), slot 6 is left hand (weapon) — opposite of what standard OTClient documentation implies.

## Imbuing System

- `g_game.applyImbuement(x, y)` — x = imbuement slot number (1, 2, or 3 within the item), y = imbuement type ID
- `g_game.clearImbuement(x)` — clears imbuement slot x
- Always clear all slots before applying new ones
- The imbuement window **cannot be closed** while info/confirmation dialogs are open — always dismiss `UIMessageBox` widgets first, then find and click the window's close button
- `modules.game_imbuing.hide()` does NOT reliably close the window — use `getImbuementWindow()` + `findCloseButton()` + `button:onClick()` instead, with Escape as fallback
- Items must be **unequipped** (in backpack) before `useWith(shrine, item)` will open the imbuement dialog for them. **Do NOT use `g_game.equipItemId` for this** — it routes by item type's natural slot and will not find a weapon in slot 5. Use `g_game.move(lp:getInventoryItem(slot), containerPos, 1)` to move from a specific slot.
- The imbuement window stays open after imbuing. **Always close it** (closeInfoDialogs + getImbuementWindow + findCloseButton + onClick) before calling `useWith` for the next item — the game will not open a new dialog while one is visible.
- **Re-equipping to a specific slot:** Save `slotItem:getPosition()` before moving the item out. On re-equip use `g_game.move(found, savedPos, 1)` — this bypasses `equipItemId`'s natural-slot routing and places the item in the exact original slot. Critical for dual-wield weapons (both slot 5 and slot 6).
- **Multi-item imbuing with same item ID (dual-wield same weapon type):** Use index-based lookup (`itemsToImbue[currentIndex]`) not ID-based search. After imbuing, leave items in the backpack — do not mid-process re-equip. Detect stale backpack items: if `findItem(id)` succeeds AND `lp:getInventoryItem(currentSlot)` also has that ID, the backpack item is leftover from a previous imbue; force-nil it to trigger the slot unequip path.

## Deploying Changes Across Characters

All active character directories share the same script structure. When updating a shared file:
1. Edit the master copy (currently `Index One/`)
2. `cp` to all other character directories: Requiem, Grayson, Low, Serena, Testing, Index Zero, Index One, Index Two
3. For new vBot scripts, also add the filename to each character's `_Loader.lua` under the `luaFiles` list (after `"tools"` is a safe position)
4. Use `sed -i 's/"tools",/"tools",\n  "new_file",/'` to batch-update all `_Loader.lua` files

## Key Files

| File | Purpose |
|------|---------|
| `vBot_4.8/_Loader.lua` | Load order definition for vBot 4.8 |
| `vBot_4.8/vBot/vlib.lua` | Core utility/helper functions |
| `vBot_4.8/vBot/items.lua` | Item ID database |
| `vBot_4.8/cavebot/cavebot.lua` | CaveBot main loop |
| `vBot_4.8/cavebot/actions.lua` | Base action implementations |
| `vBot_4.8/targetbot/target.lua` | Combat targeting logic |
| `vBot_4.8/vBot/AttackBot.lua` | Spell/rune automation |
| `vBot_4.8/vBot/HealBot.lua` | Healing profiles |
| `vBot_4.8/vBot/Equipper.lua` | Gear swapping conditions |
