# Card Visuals (GID-151)

## Key Features

- Pixel-art **frame per magic type** (light / dark / verdant / rift + neutral) on every card face.
- Shared **card back** (gold trim, tiled lattice, Pear Pudding crest).
- Round **cost gem / attack / health badges** and a dark **text plate** for ability text.
- Tileable **branch background** behind every illustration (ember sparks, dawn rays, dusk mist, ash flakes, bloom
  flowers, thorn vines, flux waves, fracture cracks; neutral bricks).
- One builder (`scenes/ui/CardFace.gd`) used by battle cards, backpack tiles, pack opening and the inspect overlay.

## How It Works

### Art (`tools/generate_card_frames.py`)
Writes `assets/textures/cards/frame_<type>.png` (32×48, 6 px bevelled border, corner studs), `card_back.png`,
`card_crest.png`, `gem_cost.png`, `badge_atk.png`, `badge_hp.png`, `plate_text.png`, and 16×16 tileable
`bg_<branch>.png` (+ `bg_neutral.png`). Colours come from
`tools/pixel_palette.py`. Frame edges are uniform so they can stretch; the back's centre is a tileable lattice.
`game_logic/CardChrome.gd` preloads them (Android rule) and exposes accessors; `FRAME_MARGIN` / `PLATE_MARGIN`
must match the generator. `test_card_chrome` fails if a `MagicTypes` type has no frame.

### Sizing (`scenes/ui/CardFace.gd`)
- `pixel_scale(card_h)` = round(card_h / 110): the chrome is upscaled by that whole number with nearest
  filtering (`upscaled()`, cached), then 9-sliced by a `StyleBoxTexture` (`frame_style`, `back_style`,
  `plate_style`, cached per texture + scale). Content margins equal the border, so children sit inside it.
  If a texture's pixels can't be read (headless dummy renderer) the unscaled texture is used.
- `make_badge(kind, text, d, font)` — Label on a gem/badge stylebox; `set_badge_text` shrinks 3+ digit numbers
  (real-time costs are mana points ×100).
- `make_art(tex, h)` — nearest-filtered illustration rect (the project default filter is linear, which smeared 32 px art).
- `set_art_background(art, branch, card_h)` — adds / swaps an `ArtBackground` TextureRect (tiled, upscaled,
  `show_behind_parent`) inside the illustration rect. `CardArt.apply(..., card_h)` calls it for battle cards.
  `test_card_chrome` fails if a MagicTypes branch has no background.
- `apply_back(panel, card_h)` — back stylebox + centred `BackCrest`.

### Battle cards (`CardViewBuilder`)
- Panel stylebox = the frame for the face template's `magic_type` (dual-face cards follow `active_face`).
- The old per-card `StyleBoxFlat` (meta `card_style`) is now a **rim** drawn over the frame from the panel's
  `draw` signal (`_draw_rim`, hooked once in `attach_card_style`). Highlight borders still set its border; the
  "dimmed" states (unaffordable hand card, invalid ward target) set its fill to `DIM_COLOR`. Empty board slots
  (meta `is_empty_slot`) own their stylebox and skip the rim. Callers mutate the rim then `queue_redraw()`.
- Vbox rows: `IllustrationRect` (min `ART_FRAC` of card height, expands into spare height), `NameLabel`,
  `DescLabel` (on the text plate), `KeywordRow`, `StatsRow` (`CostLabel` gem · spacer · `AtkLabel` · `HpLabel`,
  badges hidden for spells; HP turns pale red when damaged), optional `StatusRow`.
- Board rows are 0.245 vh (was 0.27) so the hand row fits a 16:9 screen with the hero panels' natural height.

### Card back
`CardFace.apply_back()` dresses the battle enemy-hand panels (`BattleScene._make_card_view`, meta `is_card_back`;
that row only shows in co-op / team top-bar layouts) and the pack-opening backs (`PanelContainer`s flipped by
`PackOpenScene._flip_card`). Draw / enemy-play animations reuse it.

### Other card views
- `CardTile` (backpack): frame stylebox; hover / selected are `modulate_color` tints of the same frame; gem via `make_badge`.
- `PackOpenScene`: face is a `Panel` with the card's frame, art, name and badges.
- `CardInspectOverlay`: the panel is the card's frame; dual-face panels dim the inactive face.

### Motion (`scenes/battle/CardMotion.gd`)
Ghost copies in the battle's float layer (`_float_layer`, CanvasLayer 128) so container-laid-out panels never
move. Durations × the battle speed scale.
- **Draw deal-in** — `BattleScene._card_motion` (an instance; it remembers dealt hand ids) runs
  `deal_new_hand_cards()` after every hand refresh. Each new card's real panel is hidden, a card back flies
  from the right end of the hand row (tilted, staggered 0.07 s), turns edge-on, and the face flips out
  (`flip_out`). The opening hand deals in the same way. A refresh mid-flight simply shows the card early
  (`update_card_view` resets modulate / scale on reuse).

- **Real-time draw pile** (GID-178 / TID-725) — `scenes/battle/modules/DeckPile.gd` (built by `RealtimeVisuals`):
  a stack of card backs with the cards-left count, right of the rightmost hand card; the top back hops on each
  draw. `CardMotion.deal_from` points at it, so drawn cards and returning technique cards fly out of the pile
  (`deal_time_mult` 1.7 slows the real-time flight so a draw reads).
- **Hover / press** — `BattleInput._set_hover_lift` → `CardMotion.set_hover`: lift ×1.25 from the bottom edge,
  −3° tilt, brighter frame via `self_modulate`. Touch lifts while a finger is down (`InputEventScreenTouch`,
  connected in `_bind_card_input` after its disconnect sweep). `update_card_view` resets rotation / self_modulate.
- **Playable glow** — `apply_card_style` calls `CardMotion.set_playable_glow(panel, on)` for hand cards the local
  player can play on their turn: a green `StyleBoxFlat` ring (meta `glow_style`) drawn just outside the card by
  `CardMotion.draw_glow` from `_draw_rim`; its alpha pulses (looping tween, meta `glow_tween`) unless Reduce
  Flashing is on. (The rim's own shadow can't be used: its transparent fill lets the shadow tint the whole card.)

- **Play arc** — `BattleScene._animate_card_travel` (awaited by `BattleTargeting` slot plays) delegates to
  `CardMotion.play_arc`: the ghost follows a quadratic curve (peak `PLAY_ARC` × distance above the midpoint,
  slight lean), swells then settles, and `BattleJuice.sparks` bursts in the branch colour (`card_color`) on landing.
- **Enemy flip-reveal** — `BattleFx.pop_new_board_cards` → `_enter_board`: a new enemy board card is hidden, a
  card back flies from the enemy hero panel to its slot, turns edge-on and the face flips out with a burst
  (`CardMotion.reveal_play`). If the enemy hero panel isn't visible it falls back to `pop_in`, which own-side
  entrances (AI/net summons) still use.

- **Dissolve** — `assets/shaders/card_dissolve.gdshader`: blocky screen-space value noise (`FRAGCOORD` / `cell_px`,
  so a whole card tree dissolves as one via `use_parent_material`), glowing `edge_color` band, `progress` 0→1.
  `CardMotion.apply_dissolve` / `dissolve(node, color, dur)`.
  - Deaths: `BattleFx.animate_death` dissolves the ghost in the card's branch colour (panel meta `card_branch`,
    set by `apply_card_style`) over `BattlePacing.DEATH_ANIM`, sinking to 92 %.
  - Spells: `BattleScene._do_play_card` (the one choke point for local, AI-free and net spell plays) captures the
    local caster's hand panel rect before `play_card`, then `CardMotion.cast_spell` lifts a face ghost to the
    screen centre (×1.3), holds, sparks, and dissolves. Fire-and-forget; never delays resolution.

### Illustrations
`tools/generate_cards.py` draws the 32×32 card art: creature portraits cropped from
`tools/generate_characters.py` sprites and one rune per spell branch — dawn, dusk, ember, ash, and (TID-639)
bloom (flower), thorn (bramble), flux (vortex), fracture (split crystal). `SpriteRegistry.card_illustration_texture`
maps them; `test_card_chrome.test_every_branch_has_a_spell_rune` keeps every MagicTypes branch covered.
Creature cards (TID-640): `generate_cards.py` `FAMILIES` crops one portrait per family from the world sprites in
`assets/textures/characters/` (tall humanoids get an 18-row bust; props/tree kept whole) → `card_<family>.png`.
`game_logic/CardArtRegistry.gd` (split out of SpriteRegistry, which delegates `card_illustration_texture`) holds
the literal preloads and `_CARD_ART`, mapping every minion / legendary card id to a family or, for spell-like
legendaries, a rune. `test_every_creature_card_has_generated_art` fails if a non-spell card would fall back to
`TextureGen`. New creature cards need a `_CARD_ART` row.
Battle faces keep everything inside the card: art min `ART_FRAC` 0.1 of the height and flexes, ability text
≤ 3 lines, keyword font 1.6 % vh; spell-like legendaries hide the attack / health badges.

### Rarity (TID-641)
Rarity (common / rare / epic / legendary, from collection instances) now reaches battle: `CardInstance.rarity`
(default common; in `to_dict` / `from_dict`), set by `PlayerState.build_deck_from_instances`. Enemy / generated
cards stay common.
- **Pip** — `CardFace.draw_rarity_pip` draws a rarity-coloured diamond (`UiUtil.rarity_color`) on the frame's top
  edge for rare and up, from the battle card's draw hook (meta `card_rarity`).
- **Foil** — `assets/shaders/card_foil.gdshader`: a screen-space light band sweeping diagonally (`TIME`), tinted by
  rarity. `CardFace.foil_material(rarity)` (shared per rarity; `FOIL_STRENGTH` epic 0.35, legendary 0.55, else
  null) is set as the panel's own `material`, so it lights the frame / rim / glow but not the contents. Used on
  battle cards (`apply_card_style`; cleared when a slot empties), backpack tiles and pack-opening faces.
- The "Card Rarity" tutorial text listed a non-existent Uncommon tier; it now names Common / Rare / Epic / Legendary.

## Integrations
- `MagicTypes` (type list), `CardRegistry` templates (`magic_type`, `illustration`, `card_class`).
- `tools/capture_battle_cards.gd` renders a battle screenshot under xvfb for eyeballing card changes.

## Asset Requirements
All chrome is original, generated art (no licences). Regenerate with `python3 tools/generate_card_frames.py`
(needs Pillow), then run the headless import so the `.png.import` files exist.
