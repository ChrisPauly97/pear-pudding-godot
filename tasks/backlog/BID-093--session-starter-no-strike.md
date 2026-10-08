# BID-093: Multiplayer session starter character has no Strike technique

**Category:** design-inconsistency
**Discovered During:** GID-175 / TID-708

## Description

Single-player `new_game` and the cold co-op `ensure_coop_deck` now deal the Strike technique card into the starter deck. `SessionState.make_starter_character` (multiplayer session characters, GID-095) builds its own starter deck and was not changed. When such a character is loaded, `SaveManager._restore_technique_cards` does not run (it runs only in the save-file load path), so a session character never gets Strike.

## Evidence

`autoloads/SaveManager.gd` (`new_game`, `ensure_coop_deck`, `load_session_character` path) vs `SessionState.make_starter_character`.

## Suggested Resolution

Add Strike to `make_starter_character`, and call the technique repair when a session character is loaded.
