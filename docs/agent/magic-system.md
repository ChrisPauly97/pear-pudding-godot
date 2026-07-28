# Magic System

## Key Features

- **Four top-level magic types**, two sub-branches each, declared in one table:
  `game_logic/MagicTypes.gd`
- **Light** — Ember (direct damage) and Dawn (healing, restoration)
- **Dark** — Dusk (lifesteal, drain) and Ash (disruption, necromancy)
- **Verdant** — Bloom (sustain, ramp) and Thorn (retribution, attrition) *(GID-126)*
- **Rift** — Flux (tempo, transmutation) and Fracture (removal, disruption) *(GID-126)*
- The player picks one type as their home path; it gates their two skill trees
- Cards of this system are **spell** type: they cost mana, apply a targeted or
  area effect, and do not occupy board slots

---

## MagicTypes.gd — the source of truth

Everything that needs to know what a magic type *is* reads from
`game_logic/MagicTypes.gd`. Nothing else holds a copy of the branch list.

| Table | Contents |
|---|---|
| `TYPES` | Per type: `display`, `branches` (2, in tab order), `color`, `tagline`, `cross_currency` |
| `BRANCH_COLORS` | Per-branch UI tint — skill tree tabs and connector bars |
| `RUNE_COLORS` | Per-branch pixel-art tint for the procedural spell rune (saturated; deliberately not the same values as `BRANCH_COLORS`, which must stay legible behind white label text) |
| `CURRENCY_BRANCHES` | Each type's one signature branch |
| `POINTS_PER_CARD` | Cross-magic points earned per signature-branch card played |

Accessors: `all_types()`, `is_valid_type()`, `branches_for()`, `type_for_branch()`,
`display_name()`, `tagline()`, `type_color()`, `branch_color()`,
`branch_rune_color()`, `branch_summary()`, `cross_currency()`,
`currency_for_branch()`.

`type_for_branch()` is derived by scanning `TYPES` rather than stored, so a branch
can never be listed under one type and attributed to another.
`test_magic_types.gd` asserts the tables agree in both directions.

**Adding a fifth type** means one `TYPES` entry, two `BRANCH_COLORS` entries, two
`RUNE_COLORS` entries, and its skill/card resources. No UI, battle-rule or
currency code changes.

| Type | Branches | Alignment | Spends | Signature branch |
|---|---|---|---|---|
| Light | Ember, Dawn | life | corruption | Dawn |
| Dark | Dusk, Ash | entropy | redemption | Dusk |
| Verdant | Bloom, Thorn | life | corruption | Bloom |
| Rift | Flux, Fracture | entropy | redemption | Fracture |

### Cross-magic currency

The currency a player spends is set by **their own** type, not by what they are
buying — a Light player corrupts themselves to reach into any other type. Two
currencies cover four types by alignment (the table above). This is exactly the
rule Light and Dark already followed; GID-126 named it rather than changing it.

Currency accrues from playing your type's **signature branch** cards in a won
battle: `PlayerState.branch_cards_played` → `cross_currency_earned()` →
`BattleResultUI` result dict (`corruption_earned` / `redemption_earned`) →
`SceneManager` → `SaveManager.add_corruption_points()` /
`add_redemption_points()`.

### Battlefield affinity

Each type's signature branch costs 1 less mana under one battlefield condition,
defined in `BattlefieldRules.BRANCH_AFFINITY`. Light and Dark use the **time of
day** axis; Verdant and Rift use the **biome** axis, so the two never stack on one
card. The other four branches have no affinity.

| Branch | Condition |
|---|---|
| Dawn | daytime |
| Dusk | night |
| Bloom | Forest biome |
| Fracture | Scorched biome |

Stacking order in `effective_cost()`: branch affinity first, then the Grasslands
first-card discount, floor 0.

---

## Lore

### Light Magic

Light magic draws from warmth, radiance, and living energy. Its practitioners feel it as a heat behind the eyes and a buzz in the fingertips — the body recognising something that wants to grow. Light is not passive; it expands, consumes, and ultimately cleanses. At its most benevolent it heals and sustains; at its most aggressive it reduces everything it touches to cinder. Light does not hate the dark — it simply does not permit it to remain.

### Dark Magic

Dark magic flows from cold, vacuum, and entropy. To touch it is to feel a hollow behind the sternum, a stillness that precedes collapse. Dark is not evil; it is the silence after sound, the space that lets things be defined. It equalises, absorbs, and unmakes. Where Light energy is additive, Dark is subtractive — it removes warmth, removes structure, removes the last HP that stood between a minion and the discard pile.

### Verdant Magic

Verdant magic is the oldest of the four and the least interested in the mage holding it. Where Light and Dark are argued about, Verdant simply continues: it was here before the argument and expects to outlast it. To channel it is to feel patient pressure, the slow insistence of a root splitting stone. It does not heal so much as *keep going* — a Verdant mage does not undo the wound, they grow past it. And it is not gentle. Everything that grows also competes, and everything that competes eventually develops something sharp. The same magic that closes a wound puts thorns on the vine.

### Rift Magic

Rift magic is what leaks through where the world does not quite meet itself. Practitioners describe it as arriving a half-second before you decide to use it. It has no substance of its own; it borrows — motion from one place and spends it in another, a turn from later and takes it now, structure from a thing that was relying on that structure. Rift mages are rarely accused of cruelty, because cruelty implies intent toward the thing you are unmaking, and a Rift mage is usually thinking about something else. It is the only one of the four that no temple claims, which its practitioners consider a fair trade.

---

## Sub-Branch Profiles

### Ember (Light)

**Personality:** Aggressive, impatient, spectacular. Ember mages are often impulsive — they solve problems by making them smaller, then making what remains into ash.

**Playstyle:** Direct damage to single targets and sweeping low-damage splashes. Ember spells trade efficiency for immediacy: they do not linger, do not resurrect, and do not wait.

**Colour palette:** Bright orange-gold flame, deep red embers, white-hot core.

---

### Dawn (Light — signature)

**Personality:** Patient, restorative, understated. Dawn mages let the battle come to them; they outlast rather than overpower.

**Playstyle:** Healing, stat boosts, shield effects. Dawn spells let a player recover from a bad trade and maintain board presence through attrition.

**Colour palette:** Pale gold, silver-white, soft pink dawn tones.

**Affinity:** −1 mana during the day.

---

### Dusk (Dark — signature)

**Personality:** Calculating, patient, parasitic. Dusk mages pay attention to what opponents have left; they drain rather than destroy.

**Playstyle:** Lifesteal, mana taxation, slow-burn attrition. Dusk answers board flooding with incremental drain effects.

**Colour palette:** Deep violet, midnight blue, faint cold glow.

**Affinity:** −1 mana at night.

---

### Ash (Dark)

**Personality:** Fatalistic, cyclical, unsettling. Ash mages view destruction as a precondition for return. They wait for things to die so they can bring them back.

**Playstyle:** Disruption (attack debuffs, targeted low-damage pings) and resurrection. Ash rewards a player who lets things die on purpose.

**Colour palette:** Charcoal grey, bone white, dull orange residual heat.

---

### Bloom (Verdant — signature)

**Personality:** Unhurried to the point of rudeness. Bloom mages are the ones still setting up on turn six, and the ones still standing on turn twelve.

**Playstyle:** Board-wide sustain and ramp. Bloom does not answer a threat; it makes the threat insufficient. Heals, mass health buffs, and mass Ward, backed by a skill tree that is mostly max-HP and mana.

**Colour palette:** New-growth green, wet bark, pale sap yellow.

**Affinity:** −1 mana in the Forest biome.

---

### Thorn (Verdant)

**Personality:** Defensive but not passive. Thorn mages consider "leave me alone" to be a complete threat.

**Playstyle:** Retribution and attrition — board-wide poison, board-wide attack buffs, and scattered damage. Thorn wants a wide board that hurts to attack into, and a clock the opponent cannot outrun.

**Colour palette:** Yellow-green bramble, dry stem, dark thorn tips.

---

### Flux (Rift)

**Personality:** Distracted, quick, hard to pin down in conversation or on the board.

**Playstyle:** Tempo and card flow — draw, single-target burst, and letting one minion act twice. Flux converts an information advantage into a turn advantage.

**Colour palette:** Pale cyan, refracted white, thin blue edge-glow.

---

### Fracture (Rift — signature)

**Personality:** Clinical. Fracture mages do not describe what they do as destruction; they describe it as noticing.

**Playstyle:** Removal and disruption — stripping keywords, stunning, forcing discards. Fracture answers the opponent's best card by making it stop being their best card.

**Colour palette:** Magenta seam-light, black fracture lines, dull grey shard.

**Affinity:** −1 mana in the Scorched biome.

---

## Card Roster — Verdant & Rift (GID-126)

Every card reuses a `spell_effect` that `SpellEffectResolver` already implements,
so the branches needed no new resolver arms, labels or targeting entries.

| Branch | Card | Cost | Effect |
|---|---|---|---|
| Bloom | Germinate | 2 | `heal_all` 3 |
| Bloom | Verdant Bulwark | 3 | `buff_health_all` 2 |
| Bloom | Blooming Ward | 5 | `grant_ward_all` |
| Thorn | Bramble Snare | 3 | `apply_poison_all` 1 |
| Thorn | Thorn Volley | 3 | `deal_damage_random` 3 |
| Thorn | Wild Growth | 4 | `buff_attack_all` 2 |
| Flux | Displace | 2 | `draw_card` 2 |
| Flux | Kinetic Bolt | 3 | `deal_damage_single` 4 |
| Flux | Momentum | 4 | `double_attack` |
| Fracture | Unmake | 3 | `bind_minion` |
| Fracture | Fault | 3 | `stun_single` 1 |
| Fracture | Shardfall | 4 | `enemy_discard` 2 |

These reach shops, drafts, drops and crafting through the normal
`CardRegistry.get_all_ids()` paths — no per-feature wiring.

---

## Card Stat Proposals

### Ember Branch Cards

| Card | Cost | Effect | Flavour Text |
|------|------|--------|--------------|
| Spark | 1 | Deal 1 damage to any target | "The smallest flame is still a flame." |
| Flicker | 2 | Deal 1 damage to all enemies | "Unstable, uncontainable, inevitable." |
| Ember | 3 | Deal 3 damage to one target | "What smolders longest burns deepest." |
| Scorch | 5 | Deal 5 damage to one target | "Nothing survives the full expression of the flame." |

**Target rules for Ember:**
- Spark and Ember: target any single minion or either hero
- Flicker: hits all enemy minions and enemy hero for 1 each (area sweep)
- Scorch: single target, same as Spark

---

### Ash Branch Cards

| Card | Cost | Effect | Flavour Text |
|------|------|--------|--------------|
| Ash | 1 | Reduce a minion's attack by 2 until end of turn | "What remains when fire has finished." |
| Brittle | 2 | Deal 2 damage to a minion | "Cold makes things fragile." |
| Char | 3 | Destroy a minion with 3 or less HP | "The last thing it knew was heat." |
| Alight | 4 | Resurrect the last destroyed friendly minion with 1 HP | "From ash, something stirs." |

**Target rules for Ash:**
- Ash: targets any minion (enemy or friendly)
- Brittle: targets any minion
- Char: targets any minion with current HP ≤ 3; no-op if none qualify
- Alight: no target required; reads last destroyed entry from the friendly discard pile

---

## Implementation Notes

### CardData Schema Extensions Required (TID-021)

The following fields must be added to `data/CardData.gd`:

| Field | Type | Values |
|-------|------|--------|
| `card_type` | `String` | `"minion"` (existing default) or `"spell"` |
| `magic_type` | `String` | Any key of `MagicTypes.TYPES` — `"light"`, `"dark"`, `"verdant"`, `"rift"` — or `""` (for non-magic minions) |
| `magic_branch` | `String` | Any of the eight branches, or `""` |

`to_template_dict()` must include all three new fields so `CardInstance` and UI code can read them.

### Spell Effect Design Patterns

Spells do not go on the board. When played:
1. `GameState.play_card()` checks `card_data.card_type == "spell"`
2. Spell requires a target (or auto-targets for area effects like Flicker and Alight)
3. Effect is applied immediately; card goes to discard
4. No `CardInstance` is created on the board; no board slot is consumed

**Effect types needed:**

| Pattern | Used by | Notes |
|---------|---------|-------|
| `deal_damage(target, amount)` | Spark, Flicker, Ember, Scorch, Brittle | Target = minion or hero |
| `deal_damage_all_enemies(amount)` | Flicker | Iterates all enemy board slots + hero |
| `apply_attack_debuff(target_minion, amount, duration)` | Ash | duration = "end_of_turn"; cleared in turn-start cleanup |
| `destroy_if_hp_leq(target_minion, threshold)` | Char | Conditional destroy |
| `resurrect_last_friendly_discarded()` | Alight | Scans friendly discard pile for last minion; spawns it with 1 HP if slot available |

These patterns are defined here for TID-022 and TID-023 to reference when writing the `.tres` assets and wiring spell effects into `GameState`.

### UI / Visual Treatment

- Spell cards should render without an attack/health line (show only cost and effect text)
- Branch colour tinting: Ember = orange-gold, Ash = charcoal, Dawn = pale gold, Dusk = dark violet
- No board slot needed — drag-to-play should allow dropping onto valid targets instead of empty board slots

---

## Integrations with Other Features

| System | Direction | Details |
|--------|-----------|---------|
| **CardData** | Schema | New fields `card_type`, `magic_type`, `magic_branch` added in TID-021 |
| **CardRegistry** | Data source | Loads new `.tres` spell cards alongside existing minion cards |
| **GameState** | Spell execution | `play_card()` must branch on `card_type == "spell"` to apply effects rather than placing on board |
| **BattleScene UI** | Display | Spell cards render without attack/health; drop targets are enemy board slots and heroes |
| **SaveManager / Deck** | Player deck | Spell card IDs stored in `player_deck` like minions |
| **MagicTypes** | Source of truth | Types, branches, colours, signature branches, currency mapping (GID-126) |
| **SkillTreeScene** | Path choice + trees | Builds the choose-your-path modal and all three tabs from `MagicTypes` |
| **BattlefieldRules** | Cost rules | `BRANCH_AFFINITY` drives the −1 mana discount per signature branch |
| **PlayerState** | Currency accrual | `branch_cards_played` → `cross_currency_earned()` at battle end |
| **TextureGen** | Card art | Spell rune tinted from `MagicTypes.RUNE_COLORS` |

---

## Asset Requirements

| Asset | Path | Notes |
|-------|------|-------|
| MagicTypes registry | `game_logic/MagicTypes.gd` | Static tables; preload, not an autoload |
| Ember spell cards (×4) | `data/cards/spell_*.tres` + `.uid` | Spark, Flicker, Ember, Scorch |
| Ash spell cards (×4) | `data/cards/spell_*.tres` + `.uid` | Ash, Brittle, Char, Alight |
| Verdant spell cards (×6) | `data/cards/bloom_*.tres`, `thorn_*.tres` + `.uid` | See the Card Roster table above |
| Rift spell cards (×6) | `data/cards/flux_*.tres`, `fracture_*.tres` + `.uid` | See the Card Roster table above |
| Verdant / Rift skills (×24) | `data/skills/{bloom,thorn,flux,fracture}_*.tres` + `.uid` | 6 per branch; preloaded in `SkillRegistry` |
| Branch rune PNGs (×4) | `assets/textures/cards/rune_{bloom,thorn,flux,fracture}.png` | **Outstanding.** Procedural fallback covers them today — see `docs/agent/art-sprites.md` |
| CardData schema | `data/CardData.gd` | Extended with `card_type`, `magic_type`, `magic_branch` |
