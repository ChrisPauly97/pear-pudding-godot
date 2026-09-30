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

## Integrations
- `MagicTypes` (type list), `CardRegistry` templates (`magic_type`, `illustration`, `card_class`).
- `tools/capture_battle_cards.gd` renders a battle screenshot under xvfb for eyeballing card changes.

## Asset Requirements
All chrome is original, generated art (no licences). Regenerate with `python3 tools/generate_card_frames.py`
(needs Pillow), then run the headless import so the `.png.import` files exist.
