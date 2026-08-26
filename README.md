# 🧩 ShaguTweaks

> **A small World of Warcraft (1.12.1) AddOn for those who don't want to use any AddOns at all.**

This is a **fork of [shagu/ShaguTweaks](https://github.com/shagu/ShaguTweaks)**, patched for **OctoWoW / Turtle WoW**, with several new custom mods added and existing ones tweaked.

The goal stays the same: stay non-intrusive to the default UI, while giving you the choice to enable extra quality-of-life features if you want them. Every setting can be toggled in-game via **"Advanced Options"** on the Main Menu (*Esc*).

---

## 🔌 Requirements

- **[ClassicAPI](https://github.com/brues-code/ClassicAPI) — required.** This fork uses ClassicAPI for structured spell, cast, nameplate, bag, merchant and player-state data where it is more reliable than legacy tooltip/combat-log parsing. ShaguTweaks declares `!!!ClassicAPI` as a dependency and will not load without it.
- **[SuperWoW](https://github.com/balakethelock/SuperWoW) — optional / recommended.** It remains supported as an additional compatibility source, especially for GUID-based cast information, but ClassicAPI is the primary API layer.

Use the latest ClassicAPI version and follow its upstream installation instructions.

---

## 📦 Installation

**Vanilla (1.12)**
1. Install/update **ClassicAPI** first
2. Download the latest ShaguTweaks version
3. Unpack the zip
4. Rename the folder to `ShaguTweaks`
5. Copy it into `Wow-Directory\Interface\AddOns`
6. Restart WoW

---

## 🆕 Custom mods (added on top of the original)

- **Energy & Mana Tick** — Adds an energy & mana tick to the player frame.
- **Clean Minimap** — Hides minimap addon buttons automatically when the cursor leaves the minimap area.
- **Minimap Zoom** — Increases the minimap size and shifts buff icons left to prevent overlap.
- **XP Bar Text** — Always shows current XP and rested bonus percentage directly on the experience bar — fixed for OctoWoW.
- **Free Slots Count** — Shows free slot counts on the backpack button: class bag slots (top right), reagent bag slots (bottom left), and total free slots (bottom right).
- **Loot Cursor** — Positions the loot window directly under your cursor so you can loot without moving your mouse.
- **No Toggle** — Keeps Auto Attack, Auto Shot, and Shoot active when re-pressed, preventing accidental cancellation.
- **Range Color** — Action buttons will be colored red when out of range.
- **Hide Tracking Icon** — Hides the tracking icon from the minimap.
- **Improved Roll Frames** — Smaller roll frames with roll tracking.
- **Improved Castbar** — Adds a spell icon and remaining cast time to the cast bar.
- **Chat Spam Filter** — Hides repeated messages in say/yell/channel chat (70s cooldown per unique message). Also suppresses BigWigs cast spam and #showtooltip errors.
- **Smaller Error Frame** — Resizes the error frame to 1 line instead of 3.
- **Skip Gossip Text** — Skip gossip text when interacting with NPCs unless holding shift.
---

## ⚙️ Original Features

- **Auto Dismount** — Automatically dismounts whenever a spell is cast.
- **Auto Stance** — Automatically switches to the required warrior/druid stance on spell cast.
- **Blue Shaman Class Colors** — Changes shaman class color to blue, as in +.
- **Chat Hyperlinks** — Copy website URLs from chat, turns CLINKs into real items, handles quest/player links.
- **Chat Tweaks** — Mouse wheel scroll, sticky chat channels, repeat message on arrow up.
- **Cooldown Numbers** — Shows remaining cooldown duration as text.
- **Darkened UI** — Darker overall interface colors.
- **Equip Compare** — Shows currently equipped items on tooltips while holding Shift.
- **Unit Frame Health Colors** — Health text color changes based on value.
- **Hide Errors** — Hides and ignores Lua errors from broken addons.
- **Hide Gryphons** — Hides the gryphons next to the action bar.
- **Item Rarity Borders** — Item rarity shown as border color on bags/bank/character/inspect frames.
- **MiniMap Clock** — Small 24h clock on the minimap.
- **MiniMap Square** — Square minimap instead of round.
- **MiniMap Tweaks** — Hides unnecessary minimap buttons, mouse wheel zoom.
- **Movable Unit Frames** — Move player/target frames with Shift+Ctrl.
- **Nameplate Castbar** — Castbar on nameplates using ClassicAPI cast state first, with legacy/SuperWoW fallbacks.
- **Nameplate Class Colors** — Nameplate health bar colored by class.
- **Nameplate Scale** — Nameplates honor UI-Scale setting.
- **Reduced Actionbar Size** — Smaller action bar, removes bag panel/microbar.
- **Sell Junk** — "Sell Junk" button at merchants, sells all grey items.
- **Social Colors** — Class colors in Who, Guild, Friends and Chat.
- **Enemy Castbars** — Enemy castbar on target frame using ClassicAPI timing first, with compatibility fallbacks.
- **Debuff Timer** — Debuff durations shown on target frame.
- **Tooltip Details** — Health, class color, guild name/rank, current target on tooltips.
- **Unit Frame Big Health** — Bigger healthbars for player/target.
- **Unit Frame Class Colors** — Class colors on player/target/party frames.
- **Unit Frame Class Portraits** — Replaces portraits with class icons.
- **Vendor Values** — Shows sell value on item tooltips.
- **WorldMap Class Colors** — Class-colored circles on world/battlefield map.
- **WorldMap Coordinates** — Coordinates at the bottom of the World Map.
- **WorldMap Window** — Movable, scalable world map window.

---

## 🙏 Credits

Original addon by **shagu**. Code also borrows from **pfUI** and **zUI**.
This fork adapts, patches and extends ShaguTweaks for **OctoWoW / Turtle WoW**.
