# TID-562: Hero Appearance Picker (skin, hair)

**Goal:** GID-137
**Type:** agent
**Status:** pending
**Depends On:** TID-560

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`PaperDoll` already takes an `appearance` Dictionary overriding
`DEFAULT_APPEARANCE` colours (skin, hair, eyes, shirt, trousers, boots, belt).
Nothing persists or exposes it yet.

## Research Notes

- Add one `SaveManager.PERSISTED_FIELDS` entry (e.g. `hero_appearance: {}`)
  storing colour hex strings; convert to Color in a helper before PaperDoll.
- Picker UI via `UiUtil` factories on the New Game flow; live PaperDoll preview
  (`PaperDoll.idle_texture(gear, appearance)` in a nearest-filtered TextureRect).
- Hair *style* variants would be a new `hair_style` key + draw routine.
