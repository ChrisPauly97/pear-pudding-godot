# Magic System

## Key Features

- Two top-level magic axes: **Light** and **Dark**, each with two sub-branches
- **Ember** (Light) — direct-damage spells; aggressive burn cards available in this release
- **Dawn** (Light) — healing and restoration; lore-defined, no cards in this release
- **Dusk** (Dark) — lifesteal and drain; lore-defined, no cards in this release
- **Ash** (Dark) — disruption and necromancy; resurrection and debuff cards available in this release
- Cards of this system are **spell** type: they cost mana, apply a targeted or area effect, and do not occupy board slots

---

## Lore

### Light Magic

Light magic draws from warmth, radiance, and living energy. Its practitioners feel it as a heat behind the eyes and a buzz in the fingertips — the body recognising something that wants to grow. Light is not passive; it expands, consumes, and ultimately cleanses. At its most benevolent it heals and sustains; at its most aggressive it reduces everything it touches to cinder. Light does not hate the dark — it simply does not permit it to remain.

### Dark Magic

Dark magic flows from cold, vacuum, and entropy. To touch it is to feel a hollow behind the sternum, a stillness that precedes collapse. Dark is not evil; it is the silence after sound, the space that lets things be defined. It equalises, absorbs, and unmakes. Where Light energy is additive, Dark is subtractive — it removes warmth, removes structure, removes the last HP that stood between a minion and the discard pile.

---

## Sub-Branch Profiles

### Ember (Light sub-branch)

**Personality:** Aggressive, impatient, spectacular. Ember mages are often impulsive — they solve problems by making them smaller, then making what remains into ash.

**Playstyle:** Direct damage to single targets and sweeping low-damage splashes. Ember spells trade efficiency for immediacy: they do not linger, do not resurrect, and do not wait. A hand full of Ember spells is a clock ticking down for the opponent.

**Colour palette:** Bright orange-gold flame, deep red embers, white-hot core.

**Cards in this release:** Spark, Flicker, Ember, Scorch.

---

### Dawn (Light sub-branch)

**Personality:** Patient, restorative, understated. Dawn mages let the battle come to them; they outlast rather than overpower.

**Playstyle:** Healing, stat boosts, shield effects. Dawn spells let a player recover from a bad trade and maintain board presence through attrition. No cards are implemented in this release; the branch is defined so lore and UI colour treatment are consistent.

**Colour palette:** Pale gold, silver-white, soft pink dawn tones.

**Cards in this release:** None (lore only).

---

### Dusk (Dark sub-branch)

**Personality:** Calculating, patient, parasitic. Dusk mages pay attention to what opponents have left; they drain rather than destroy.

**Playstyle:** Lifesteal, mana taxation, slow-burn attrition. Dusk answers board flooding with incremental drain effects. No cards are implemented in this release; the branch is defined so lore and UI colour treatment are consistent.

**Colour palette:** Deep violet, midnight blue, faint cold glow.

**Cards in this release:** None (lore only).

---

### Ash (Dark sub-branch)

**Personality:** Fatalistic, cyclical, unsettling. Ash mages view destruction as a precondition for return. They are patient in a different way from Dusk — they wait for things to die so they can bring them back.

**Playstyle:** Disruption (attack debuffs, targeted low-damage pings), and a single resurrection spell. Ash rewards a player who lets things die on purpose. Alight is the payoff for board decisions made several turns earlier.

**Colour palette:** Charcoal grey, bone white, dull orange residual heat.

**Cards in this release:** Ash, Brittle, Char, Alight.

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
| `magic_type` | `String` | `"light"`, `"dark"`, or `""` (for non-magic minions) |
| `magic_branch` | `String` | `"ember"`, `"dawn"`, `"dusk"`, `"ash"`, or `""` |

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

---

## Asset Requirements

| Asset | Path | Notes |
|-------|------|-------|
| Ember spell cards (×4) | `data/cards/spell_*.tres` + `.uid` | Spark, Flicker, Ember, Scorch |
| Ash spell cards (×4) | `data/cards/spell_*.tres` + `.uid` | Ash, Brittle, Char, Alight |
| CardData schema | `data/CardData.gd` | Extended with `card_type`, `magic_type`, `magic_branch` |
