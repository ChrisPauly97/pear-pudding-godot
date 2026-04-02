# BID-002: "Voice acting" out-of-scope conflicts with narration scroll audio

**Category:** spec-gap
**Discovered During:** GID-013 / TID-028

## Description

`docs/human/specification.md` lists "Voice acting or music" under **Out of Scope (for now)**. GID-013 deliberately adds background narration audio for story scrolls — long-form spoken-word audio that plays while the player explores. This is functionally voice acting (pre-recorded narration audio clips), in direct conflict with the spec statement.

The implementation is built to degrade gracefully when audio files are absent (silent if `.ogg` files not present), so the feature ships and works without the assets. But the spec should be updated to reflect the new intent before the audio assets are produced.

## Evidence

- `docs/human/specification.md`, section "Out of Scope (for now)": `Voice acting or music`
- GID-013 goal: "Has to be audio primarily to not take away players focus"
- TID-028 defines `audio_path` per scroll; TID-030 adds `AudioManager.play_narration()`

## Suggested Resolution

Human owner should update `docs/human/specification.md` to clarify:
- Voiced character dialogue (lip-sync, real-time conversation VO) remains out of scope
- Lore scroll narration audio (background ambient storytelling, similar to Diablo 3 lore books) is now in scope
- Music remains out of scope (or add a note if ambient audio is also planned)

No code changes needed — GID-013 proceeds with the graceful no-op design regardless.
