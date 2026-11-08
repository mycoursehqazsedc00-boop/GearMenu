# GearMenu (fork)

Quickly switch gear on a vanilla 1.12.1 client. Hover a slot, pick an item from your bags, done. Items that cannot be switched in combat are queued and equipped as soon as combat ends.

Fork of [wow-vanilla-gearmenu](https://github.com/RagedUnicorn/wow-vanilla-gearmenu) v1.2.2 by Michael Wiesendanger (MIT License). Upstream credit is kept in the TOC and in every source file header.

## Client mods

| Mod | Status | Used for |
|---|---|---|
| [ClassicAPI](https://github.com/brues-code/ClassicAPI) | optional | `PLAYER_EQUIPMENT_CHANGED` and `BAG_UPDATE_DELAYED` events to refresh the slots, and `GetCursorInfo()` to handle dropping an offhand item while a two-handed weapon is equipped |

No other client mod is used. GearMenu works on a stock 1.12.1 client; without ClassicAPI the two events never fire, the addon relies on `UNIT_INVENTORY_CHANGED`, and drag and drop behaves like the original.

## Commands

`/gm` is no longer registered, because it belongs to the game (GM ticket). Use `/gmenu` or `/gearmenu`.

| Command | Description |
|---|---|
| `/gmenu` / `/gmenu info` | List all commands |
| `/gmenu opt` | Open the options menu |
| `/gmenu show` | Show the window |
| `/gmenu hide` | Hide the window |
| `/gmenu toggle` | Show or hide the window |
| `/gmenu lock` | Lock the window |
| `/gmenu unlock` | Unlock the window so it can be moved |
| `/gmenu use <1-10>` | Use the item in a slot, for macros: `/gmenu use 1` |
| `/gmenu scale <0.5-2>` | Resize the window (saved) |
| `/gmenu sort [on/off]` | Sort the item menu by quality, then name (saved). Without argument it toggles |
| `/gmenu reset` | Move the window back to its default position |
| `/gmenu status` | Print the current settings |
| `/gmenu debug [on/off]` | Debug output, current session only |
| `/gmenu trace [on/off]` | Event tracing, current session only |
| `/gmenu reload` | Reload the UI |

## Features

- Up to 10 slots shown at once, chosen from head, neck, shoulder, cloak, chest, waist, legs, feet, wrist, hands, 2 rings, 2 trinkets, main hand, off hand and ranged
- Hover a slot to list matching items from your bags and click one to equip it
- Combat queue: items that cannot be switched in combat are queued and equipped after combat; weapons switch immediately; right click a slot to remove its queue entry
- Switching an off-hand item while wearing a two-handed weapon unequips the two-hander first
- Quick Change rules: switch to another item after an item was used, with an optional delay
- Key bindings per slot
- Drag and drop onto, between and out of slots
- Cooldown display on slots and in the menu
- Full or small (name only) tooltips
- Item quality filter for the menu
- Lockable window
- Item menu sorted by quality, then name (can be turned off)
- Slash commands for macros, scale, position reset, debug and tracing

## Compared to the original (v1.2.2)

| Area | Original | This fork |
|---|---|---|
| Slash command | `/gm` (overrides the game's GM ticket command), `/gearmenu` | `/gmenu`, `/gearmenu`; `/gm` is left alone |
| Commands | show, hide, opt, reload | Adds toggle, lock, unlock, use, scale, sort, reset, status, debug, trace |
| Item menu order | Bag order | Quality, then name (toggle with `/gmenu sort`) |
| Window | Could be dragged off screen, no scale | Clamped to the screen, saved scale, `reset` command |
| Macros | Not possible | `/gmenu use <slot>` |
| Refresh on inventory change | Full rebuild for every event | Events within 50 ms are coalesced into one refresh |
| Optional ClassicAPI events | None | `PLAYER_EQUIPMENT_CHANGED`, `BAG_UPDATE_DELAYED` |
| Drop offhand while wearing a two-hander | Not possible | Works with ClassicAPI (`GetCursorInfo`) |
| Debugging | Edit the source to change the log level | `/gmenu debug`, `/gmenu trace` at runtime |
| Item lookup by ID | Substring match: id `1234` also matched `12345` or an enchant id, which could equip or queue the wrong item | Exact match on `item:<id>:` |
| Items missing from the client cache | Menu raised an error | Item is skipped |
| Missing item category | `GetItemsByType` returned `nil` and crashed the caller | Returns an empty list |
| Equipped-item lists (Quick Change) | Undefined variable used as bag slot, entries duplicated per item type | Each equipped item listed once, no bag fields |
| Combat queue | Nil error for slots without a position, leaked globals, stale entries for items that left the bags | Guarded, locals only, stale entries dropped |
| Timers | Removed while iterating; generated one-shot timers stayed in the pool forever | Iterates a snapshot, generated timers are destroyed after firing |
| Small tooltips | Item names with parentheses or dots raised an error | Name taken from the link as is |
| Cooldown refresh | Ran on every cooldown event even with the window hidden | Only while the window is visible |
| German locale | Replaced the whole string table | Falls back to English for missing keys |

## Credits and license

Original addon by Michael Wiesendanger, MIT License. See the license header in each source file.
