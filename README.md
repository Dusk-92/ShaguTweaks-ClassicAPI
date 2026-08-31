# 🧩 ShaguTweaks — ClassicAPI

A lightweight fork of [ShaguTweaks](https://github.com/shagu/ShaguTweaks) for **Turtle WoW-like servers**.

Focused on **stability, compatibility and performance** while keeping the original ShaguTweaks experience.

> This fork requires ClassicAPI and targets **Turtle WoW-like server/client environments**.

## 🔌 Requirements

- **[ClassicAPI](https://github.com/brues-code/ClassicAPI) — required**
- **[SuperWoW](https://github.com/balakethelock/SuperWoW) — optional / recommended**

ClassicAPI is the main API layer. SuperWoW is only used as an additional fallback for some cast/GUID information.

## 📦 Installation

1. Install **ClassicAPI**.
2. Optionally install **SuperWoW**.
3. Rename the addon folder to `ShaguTweaks`.
4. Copy it to `World of Warcraft\Interface\AddOns\ShaguTweaks`.
5. Restart the game.

Settings: **Esc → Advanced Options**.

## ✨ Main changes

- ClassicAPI-backed integration for casts, auras, items and unit data.
- Reduced per-frame work, tooltip scans and repeated UI updates.
- Event-driven target and nameplate castbars where possible.
- Safer GUID-based handling for same-name enemies.
- Better Turtle WoW-like server compatibility for custom items, spells and UI changes.
- Safer hooks and fewer destructive global overrides.
- Expanded Item Rarity Borders support for merchant, quest, mail, trade, crafting and loot frames.
- Added independent Item Rarity Glows using the shared item rarity engine.
- Expanded Movable Unit Frames to handle Player, Target, Party, Minimap, Buffs, Debuffs and Weapon Buffs through one shared Ctrl+Shift mover and alignment grid.
- Restored Real Health Numbers as an independent module, with direct values when available and a lazy Vanilla health estimator fallback for percentage-only targets.
- Unit Frame Big Health is presentation-only again and no longer forces numeric health/power text.
- Various stability fixes across legacy ShaguTweaks modules.

## 🔷 Mods using ClassicAPI directly

- Actionbar Range Color
- Auto Dismount
- Chat Tweaks
- Equip Compare
- Free Slots
- Improved Castbar
- Item Rarity Borders
- Item Rarity Glows
- Movable Unit Frames
- Real Health Numbers
- Nameplate Class Colors
- Nameplate Castbar
- No Toggle
- Sell Junk
- Skip Gossip Text
- Enemy Target Castbar
- Tooltip Details
- WorldMap Window

Other modules can also benefit indirectly from ClassicAPI through shared ShaguTweaks libraries and caches.

## ⚙️ Modules

### Action Bar

- Auto Dismount
- Auto Stance
- Actionbar Range Color
- Cooldown Numbers
- Hide Gryphons
- Improved Castbar
- No Toggle Auto-Attack
- Reduced Actionbar

### Unit Frames

- Big Health
- Class Colors
- Class Portraits
- Energy & Mana Tick
- Health Colors
- Movable Unit Frames
- Real Health Numbers
- Enemy Target Castbar
- Target Debuff Timer

### Nameplates

- Nameplate Scale
- Nameplate Class Colors
- Nameplate Castbar

### Tooltip & Items

- Equip Compare
- Free Slots
- Item Rarity Borders
- Item Rarity Glows
- Sell Junk
- Tooltip Details
- Vendor Values

### Chat & Social

- Chat Tweaks
- Chat Levels
- Chat Spam Filter
- Social Colors

### Minimap & World Map

- Clean Minimap
- Minimap Clock
- Minimap Square
- Minimap Tweaks
- Minimap Zoom
- Hide Tracking Icon
- WorldMap Class Colors
- WorldMap Coordinates
- WorldMap Window

### Loot

- Improved Roll Frames
- Loot Cursor

### Interface

- Darkened UI
- Hide Errors
- Smaller Error Frame
- XP Bar Text

### General

- Super WoW Compatibility
- Turtle WoW Compatibility
- Skip Gossip Text

## 🔧 Compatibility

- ClassicAPI integration
- Turtle WoW-like server integration
- SuperWoW integration

## 🧹 Removed / integrated modules

The following original ShaguTweaks modules are not included as standalone modules because their functionality is either integrated elsewhere or no longer required:

- **Chat Links** → integrated into **Chat Tweaks**
- **Blue Shaman Class Colors** → no longer required; supported natively by Turtle WoW-like clients
- **Movable Unit Frames Extended** → integrated into **Movable Unit Frames**

## 📜 Project identity & licensing

This is an independent community project. Compatibility with **World of Warcraft**, **Turtle WoW-like environments**, **ClassicAPI**, **SuperWoW**, or other referenced projects does not imply affiliation, endorsement, sponsorship, or ownership by their respective rights holders or maintainers.

**World of Warcraft** and **Blizzard Entertainment** names, marks, and game assets remain the property of their respective rights holders.

For detailed provenance and licensing information, see:

- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
- [PROJECT_IDENTITY.md](PROJECT_IDENTITY.md)
- [Docs/ASSET_PROVENANCE.md](Docs/ASSET_PROVENANCE.md)
- [LICENSES/](LICENSES/)

## 🙏 Credits

Original addon and modules by **Shagu**.

Additional maintenance and Turtle WoW work by **paokkerkir**.

ClassicAPI compatibility fork maintained by **Dusk-92**.

Additional code and ideas from **pfUI** and **zUI**.

Extended Movable Unit Frames support adapted from **TokensWorth/ShaguTweaks-mods**, originally released under MIT by **GryllsAddons**. See `THIRD_PARTY_NOTICES.md`.

Released under the original **MIT License**.
