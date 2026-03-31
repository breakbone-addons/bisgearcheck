# BiSGearCheck Memory

## User Preferences
- "Ship it" means: update version string, commit, tag, push, AND create both CurseForge (via tag push) and GitHub releases (via `gh release create`).
- Changelog entries should be concise, user-facing. No implementation details.
- Never use m dashes. Ever. Universally.
- Never add Co-Authored-By trailers to commits.

## Current State
- Latest release: v3.5.1
- Main branch is the release branch
- Feature branches: feature/phase-data (P2-P5 data, not shipping yet), feature/cross-account-sync (WIP, symlink approach failed)

## Known Issues
- Cross-account sync: WoW overwrites symlinks when writing SavedVariables. Need external merge script approach.
- BigWigsMods packager not auto-creating GitHub releases despite GITHUB_TOKEN being set. Manual `gh release create` needed.
