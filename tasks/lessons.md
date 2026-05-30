# Lessons Learned

## [2026-03-25] | Separate .otui file not loaded for root-level scripts | Use g_ui.loadUIFromString inline

**What went wrong:** Created `vBot/TierInfo.otui` as a separate file and called `UI.createWindow("TierInfoWindow")` from `TierInfo.lua` (root-level, loaded via `dofile`). Error: `attempt to index local 'widget' (a nil value)` — the style was never registered.

**Root cause:** `_Loader.lua` auto-imports `.otui` files only from the `vBot/` subdirectory glob. Root-level scripts loaded via `dofile` cannot rely on this auto-load.

**Rule:** Scripts in the root character directory (loaded via `dofile`) must define window styles inline using `g_ui.loadUIFromString([[...]])` before calling `UI.createWindow()`. Only scripts inside `vBot/` can use separate `.otui` files. See `Stash.lua` as the reference example.

---

## [2026-04-08] | `g_game.equipItemId` ignores slot — weapons always route to slot 6

**What went wrong:** Used `g_game.equipItemId(id)` to unequip a weapon from slot 5 (right/shield hand) and to re-equip items back to their original slots. Weapons were never unequipped from slot 5, and re-equipping always went to slot 6, displacing the already-equipped left-hand weapon.

**Root cause:** `g_game.equipItemId` routes items by their *natural slot type*. Weapons always go to slot 6 (left hand), shields to slot 5. A weapon sitting in slot 5 is invisible to `equipItemId` because it searches slot 6 for weapons.

**Rule:** To unequip from a specific slot, use `g_game.move(slotItem, containerPos, 1)` where `slotItem = lp:getInventoryItem(slotNum)`. To re-equip to a specific slot, save `slotItem:getPosition()` before moving, then `g_game.move(foundItem, savedPos, 1)` on re-equip. Never rely on `equipItemId` for non-natural slot placement.

---

## [2026-04-08] | Imbuement window must be closed between items

**What went wrong:** After imbuing item 1, the imbuement window stayed open. `useWith(shrine, item2)` was called but produced no new dialog — the second item was silently skipped or imbued incorrectly.

**Root cause:** The game will not open a new imbuement dialog while one is already visible. `useWith` on the second item had no effect.

**Rule:** At the end of every "imbuing" state iteration, call `closeInfoDialogs()` + `getImbuementWindow()` + `findCloseButton()` + `onClick()` before advancing `currentIndex`. Do not rely on the window closing itself.

---

## [2026-04-08] | Use index-based lookup in itemsToImbue for same-ID dual-wield

**What went wrong:** `itemsToImbue` was searched by `entry.id == currentId` with `break` on first match. When both weapons had the same item ID, the second iteration always found the first entry's slot (slot 6), not slot 5.

**Root cause:** ID-based search with break is ambiguous when the same item ID appears twice.

**Rule:** Use `itemsToImbue[currentIndex]` (index-based) to look up the current item's config and slot. This correctly handles same-ID dual-wield weapons.

---

## [2026-04-08] | Stale backpack items cause re-imbuing of the same weapon

**What went wrong:** After imbuing item 1 it was left in the backpack. For item 2 (same ID), `findItem` found the already-imbued backpack weapon instead of the still-equipped slot 5 weapon. Item 2 was never unequipped — the script imbued item 1 a second time.

**Root cause:** No way to distinguish the backpack item from the slot item when IDs match.

**Rule:** After calling `findItem(id)`, if the result is non-nil AND `lp:getInventoryItem(currentSlot)` also has the same ID, the backpack item is stale. Set `item = nil` to force the unequip-from-slot path. Do NOT re-equip items mid-process — leave them in the backpack and let `reequipAllItems` handle everything at the end.

---

## [2026-04-08] | `getContainers()` name filter can silently block all containers

**What went wrong:** Filtering containers by `cname:find("backpack") or cname:find("bag")` excluded valid containers with custom or unusual names, causing `moved = false` and silently falling back to the broken `equipItemId` path.

**Root cause:** Players use many container types (fishing boxes, quest containers, etc.) whose names don't contain "backpack" or "bag".

**Rule:** For temporary item storage (imbuing, etc.), use any non-full container — remove name filters. Only apply name filters when the destination type truly matters (e.g., loot-only bags).

---

## [2026-05-22] | Game exit messages can fire multiple times — use specific amounts not generic text

**What went wrong:** `lowerText:find("cinder points")` was used to detect a successful portal exit. The game fires `"You received X cinder points."` as a mid-event participation reward for each round completed. Our code caught this early, logged SUCCESS, called `resetState()`, then the actual failure message `"You received 188 cinder points as failure compensation."` was ignored because `insidePortal` was already false.

**Root cause:** The participation reward and the final outcome message both contain "cinder points". The reward fires first.

**Rule:** Use the EXACT amount as the differentiator: `"750 cinder points"` = success, `"failure compensation"` = failure. Never use generic substring like `"cinder points"` alone for game outcome detection. Always check for the most specific string possible.

---

## [2026-05-22] | Portal search timeout must restore CaveBot

**What went wrong:** `CaveBot.setOff()` is called when the portal is announced. If the character never reaches the portal within 60 seconds, the timeout cleared `portalTriggered = false` but never called `CaveBot.setOn()`. CaveBot stayed off permanently.

**Root cause:** Timeout path only cleared the trigger flag, didn't restore what the portal announcement had changed.

**Rule:** Any code path that turns CaveBot off must have a corresponding `CaveBot.setOn()` on every exit path — including timeouts, not just successful exits.

---

## [2026-05-22] | Two scripts fighting over CaveBot state — use a global flag for coordination

**What went wrong:** MonsterIdentifier.lua and CinderEvent.lua both called `CaveBot.setOff()` and `CaveBot.setOn()`. MonsterIdentifier's 5-second restore timer would turn CaveBot ON while CinderEvent had it intentionally OFF for a portal. The state was unpredictable.

**Root cause:** No shared awareness between scripts about who "owns" the CaveBot state.

**Rule:** Expose a global flag (e.g. `CinderPortalActive = false`) that the "owner" script sets. Other scripts check the flag before restoring CaveBot. The owning script clears the flag on all exit paths. See `CinderEvent.lua` + `monster_identifier.lua` for the pattern.

---

## [2026-05-22] | Bomb mechanic item detection — floor scan not player tile scan

**What went wrong:** `hasBombs(playerTile)` checked if the player was standing ON the bomb item (46113). The player never stands on the bomb — they're hit by its explosion zone red tiles. The Bombs log was never created.

**Root cause:** Bomb mechanic danger comes from the explosion zone (red tile effects), not from the bomb item tile itself. Player would never be on the 46113 tile.

**Rule:** When a mechanic's danger is delivered to a DIFFERENT tile than the mechanic's item, detect the mechanic by scanning the FLOOR for the item, not by checking the player's tile. Use `for _, tile in ipairs(g_map.getTiles(playerPos.z)) do ... end` to check if the mechanic is active at all.

---

## [2026-05-22] | Two mechanics sharing detection code causes contamination — use early-return separation

**What went wrong:** Bombs and Firestorm both used red tile effects (78/79/80/188) as the dodge trigger. Keeping them in the same code path made it impossible to guarantee the working Firestorm logic wasn't affected by Bombs changes.

**Root cause:** Shared trigger code = shared risk. A change for one mechanic could silently break the other.

**Rule:** For mechanics that share the same trigger signal (e.g. red tile effects), use an early-return pattern: detect the game MODE first (floor scan for bombs), handle it entirely, then `return`. The other mechanic's code physically cannot run. This is safer than trying to parameterise shared logic.

---

## [2026-05-22] | Blue Flame — all flames in a set appear simultaneously and disappear simultaneously

**Fact:** All blue flames (item ID 47295) in a set spawn at exactly the same time and despawn at exactly the same time. There is no staggered appearance or disappearance within a set.

**Why this matters for detection:** Any approach that uses global flame presence (`flamesWereVisible`) to detect new sets will be fragile. The correct trigger for movement is: "a flame exists at a DIFFERENT position than where the character currently stands." If no flame exists at a different position, hold still. If one does, it is the new safe set — move to it.

**Rule:** Never use global flame presence transitions (`false → true` or `true → false`) to detect new flame sets. Use positional comparison only: `flame.x ~= blueFlameTarget.x or flame.y ~= blueFlameTarget.y`. Sets cannot overlap — when a flame appears at a different position while the character is on their committed tile, it is always a new set.

---

## [2026-05-22] | autoWalk re-issued every 200ms causes oscillation

**What went wrong:** Blue flame `autoWalk` was called on every macro tick (every 200ms). The repeated walk commands interrupted in-progress movement, causing the character to overshoot the tile, then try to walk back, creating back-and-forth oscillation around the target.

**Root cause:** `autoWalk` sends a pathfinding packet to the server. Sending a new packet before the character completes the previous step interrupts it.

**Rule:** Issue `autoWalk` ONCE when committing to a target. Use a `walkIssued` flag and only retry after 1+ second if the character hasn't arrived. Never re-issue on every tick.

---

## [2026-05-30] | Persist macro toggle state by polling, not onToggle

**What went wrong:** `Stances.lua` saved its toggle state via `macroObj.onToggle = function(w) cfg.x = w:isOn() end` and restored with `setOn(cfg.x)` at load. After turning the bot off/on the stance toggles reset to OFF.

**Root cause:** `onToggle` does not fire reliably in this client build, so `cfg.x` was never set to `true`; on reload `setOn(false)` then forced the button off — clobbering even vBot's own native `_macros` persistence (which stores macro on/off by title in `storage/profile_N.json`).

**Rule:** To persist a macro toggle's on/off state, mirror the proven `Autospell.lua` pattern: **poll** `macroObj:isOn()` into `storage` on a recurring tick (e.g. inside the worker macro), and restore with `macroObj.setOn(storage.value)` at load. Do not rely on `onToggle`. Keep the `setOn(...)` value in sync via polling so it never clobbers the restored state. (vBot also natively persists macro on/off by title in `_macros`; never call `setOn` with a stale value that overrides it.)

---

## [2026-05-30] | Root-level dofile scripts must guard against double-load or UI duplicates

**What went wrong:** `Stances.lua` (loaded via `dofile` at the bottom of `_Loader.lua`) created its Hunt-tab buttons/panels twice — the user saw two complete copies of the panel, one configured + one with fresh defaults.

**Root cause:** vBot re-runs the loaders in the **same persistent Lua state** (globals and `storage` survive a soft reload, and old tab UI is NOT destroyed). The loader can therefore execute a root script more than once, building its `setupUI`/`macro` UI each time. The orphaned (first) panel kept its build-time captions, so configuring the live panel only updated one copy — hence one configured, one default.

**Rule:** Every root-level script loaded via `dofile` must start with a load guard, exactly like `EquipCheck.lua`:
```lua
if MyScriptLoaded then return end
MyScriptLoaded = true
```
Use a unique global name per script. Note: because the Lua state persists, adding the guard does NOT remove panels already duplicated in a running session — the user must fully restart the client/bot (fresh Lua state) once to clear existing duplicates; the guard prevents recurrence thereafter.

---

## [2026-05-08] | Widget key events in this OTClient build — correct signatures and key codes

**What went wrong:** Multiple failed attempts at catching Enter key on a TextEdit: `onKeyPress(keyCode)` wrong signature, `onKeyDown(keyCode)` not firing, `g_keyboard.isKeyPressed` (global doesn't exist), `onTextChange` with `multiLine` (Enter didn't insert `\n`).

**Root cause:** Two separate issues:
1. The Enter keyCode is `5` in this client's enum — not `KeyReturn`, not `13`. Using the named constant or standard ASCII value silently fails.
2. Widget-level key callbacks take `(widget, keyCode, keyboardModifiers)` — widget is always the first argument.

**Rule:** For widget key handling use `widget.onKeyPress = function(widget, keyCode, keyboardModifiers)`. Enter key is `keyCode == 5`. Reference: `vBot_4.8/vBot/playerlist.lua` line 288. Never use `g_keyboard` (doesn't exist), never assume `KeyReturn` constant is defined.
