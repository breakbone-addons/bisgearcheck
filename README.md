# BiS Gear Check

A World of Warcraft TBC Classic addon that compares your equipped gear against Best in Slot lists, with tooltip integration, a wishlist system, and full BiS list browsing. Supports both Alliance and Horde characters with cross-character wishlist management.

**Author:** Breakbone - Dreamscythe
**Interface:** 20505 (TBC Anniversary)

## Features

### Gear Comparison
- Compares your currently equipped items against ranked BiS lists for your spec
- Auto-detects your spec from talent points
- Shows upgrade rank for each slot with items ranked higher than what you have equipped
- Collapsible slot sections with Collapse All / Expand All controls
- Displays item source and drop location (boss, zone, quest, etc.)
- Automatically refreshes when you change gear
- Faction-aware: filters out items not available to your faction

### Multi-Character Support
- **Character selector** at the top of the addon lets you switch between all characters on the account
- View and edit any character's wishlists from any other character
- Gear snapshots are saved automatically so you can see another character's equipped items on the Compare tab
- Each character's spec, data source, and filter settings are saved independently

### Wishlist
- **Multiple wishlists** per character — create, rename, delete, and switch between them
- Add upgrade items to the active wishlist from the comparison view
- Filter wishlist by dungeon/raid zone
- Auto-filter mode automatically filters by your current zone when entering a dungeon or raid
- Zones with wishlist items are highlighted green in the dropdown
- Tracks whether wishlist items are currently equipped

### BiS Lists Browser
- Browse the full BiS list for any spec across all classes
- Class-colored headers in the spec dropdown
- Switch between data sources to compare rankings

### Tooltip Integration
- Injects BiS ranking info into item tooltips (GameTooltip, ItemRefTooltip, ShoppingTooltip)
- Shows which specs rank the item and at what position
- Class-colored spec names
- Configurable via Interface Options:
  - Toggle tooltip injection on/off
  - Filter to show only your class
  - Select tooltip data source (Both, WowTBC.gg, AtlasLoot)

### Conflict Detection
- Detects when AtlasBIS Tooltips is also loaded
- Presents a dialog to choose: BiS Gear Check only, Keep Both, or AtlasBIS only
- Remembers your choice across sessions

### Minimap Button
- Left-click: Open gear comparison
- Right-click: Open wishlist
- Alt-click: Open addon settings in Interface Options
- Powered by LibDataBroker + LibDBIcon

## Slash Commands

- `/bisgear` or `/bgc` — Toggle the comparison view
- `/bisgear wishlist` or `/bgc wl` — Toggle the wishlist view

## Data Sources

BiS Gear Check supports two independent data sources:

| Source | Database | Description |
|--------|----------|-------------|
| WowTBC.gg | `Data.lua` (`BISGearCheckDB`) | BiS rankings sourced from wowtbc.gg |
| AtlasLoot | `Data_AtlasLoot.lua` (`BISGearCheckDB_AtlasLoot`) | BiS rankings from AtlasLoot data |

Item drop sources (boss names, zones, quest names) are stored in `SourceDB.lua`. Items can be tagged with a `faction` field ("Alliance" or "Horde") for faction-specific filtering; untagged items are available to both factions.

## Dependencies

No hard addon dependencies. The following libraries are bundled:

- LibStub
- CallbackHandler-1.0
- LibDataBroker-1.1
- LibDBIcon-1.0

## Installation

Copy the `BISGearCheck` folder into your WoW AddOns directory:

```
World of Warcraft/_anniversary_/Interface/AddOns/BISGearCheck/
```
