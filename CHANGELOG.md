# Changelog

Versioning: **MAJOR.MINOR.PATCH**
- **MAJOR** — Breaking changes (saved variable resets, incompatible data format changes)
- **MINOR** — New features or significant improvements
- **PATCH** — Bug fixes, data corrections, small tweaks

## v3.0.0

### Breaking Changes
- Renamed addon from BISGearCheck to BiSGearCheck. Addon folder, TOC file, SavedVariables, and all Lua identifiers updated. Existing users must rename their addon folder and saved variable files.

### Changes
- Refactored Core.lua and UI.lua into smaller, focused files: Character.lua, Wishlist.lua, Comparison.lua, UIControls.lua, UIWishlistControls.lua, UIRenderComparison.lua, UIRenderLists.lua.
- Added GitHub Actions workflows for manual release and pre-release builds.
- Fixed dropdown indentation inconsistency across all dropdown menus.
- Added Limitations section to README.
- TOC version is now maintained manually instead of using @project-version@ token.
- GitHub repository permissions locked down (branch protection, Actions visibility, fork workflow restrictions).

## v2.1.0

### New Features
- **Faction Support**: Detects player faction and filters BiS lists to show only faction-appropriate items. Items in SourceDB can be tagged with a `faction` field ("Alliance" or "Horde"); untagged items are available to both.
- **Multi-Character Management**: Characters on the same WoW account can view and edit each other's wishlists. A character selector dropdown at the top of the addon window lets you switch between characters.
- **Gear Snapshots**: Each character's equipped gear is saved when they log in or change equipment, allowing other characters to see their gear on the Compare tab.
- **Per-Character Settings**: Spec selection, data source, and wishlist auto-filter are now saved per-character instead of account-wide.

### Changes
- SavedVariables restructured: `BiSGearCheckSaved` is account-wide (character registry, wishlists, tooltip settings), `BiSGearCheckChar` is per-character (spec, data source, filters).
- Automatic migration from pre-2.1.0 saved data format.
- Added `.pkgmeta` and GitHub Actions workflow for CurseForge packaging.

## v2.0.0

- Initial release with Compare, Wishlists, and BiS Lists tabs.
- WowTBC.gg and AtlasLoot data sources.
- Tooltip integration with BiS rankings.
- Zone-based wishlist filtering with auto-detect.
- Multiple named wishlists with create/rename/delete.
- Minimap button via LibDBIcon.
