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

## Cosmology — Essence, Veins and the Four Draws

*(GID-127. The unifying frame. Every claim here exists to explain a mechanic that
is already implemented — see the table at the end of this section.)*

### Essence

Essence is not a metaphor in this world and not a force. It is a substance. It
moves through the ground the way water moves through rock: slowly, along the
paths it has already worn, pooling where it can and bleeding where it cannot.
Living things hold a little of it. Old things hold more. Nothing makes it and,
so far as anyone has established, nothing uses it up — it only ever moves.

The practical consequence is that magic is a **plumbing** problem rather than a
moral one. A mage is not a source. A mage is a route.

### Veins

Essence runs in veins, and the veins are visible if you know to look: a faint
cyan pulse under the grass, brightest at the centre and fading to nothing at the
edges. Nobody laid them. They are the paths the essence wore for itself, and they
wander accordingly — they do not connect towns, they do not respect borders, and
the only reliable thing about them is that they were there before the map was.

Standing on one, you draw more easily and you move more easily. Both for the same
reason: there is more essence passing through you than through the ground either
side, and essence in motion **quickens** whatever it passes through. Old
travellers walk the veins where they can. It is not superstition; it is just
faster.

Where two veins cross, more essence arrives than the crossing can carry, and the
surplus surfaces. That pool is a **well**, and what you can carry away from it is
the only form of essence a person can hold in their hands rather than in their
body. Wells do not refill. The crossing keeps flowing, but the surplus that took
an age to gather is gone the moment somebody scoops it.

### The four draws

There is only one essence. There are four ways to pull on it, and this is the
part every temple gets wrong when it teaches that the types are four different
magics. They are four different **grips**.

Two of them push essence into things:

- **Light** floods it in fast, and things that are flooded fast either flourish
  or burn.
- **Verdant** feeds it in slowly, and things that are fed slowly simply keep
  going.

Two of them pull essence out:

- **Dark** draws it out of a thing and into the mage, which is why Dark mages are
  hard to kill and unpleasant to stand near.
- **Rift** draws it out of a thing and puts it somewhere else entirely — usually
  somewhere the mage would rather it was, occasionally somewhere nobody
  anticipated.

This is the whole of the alignment split. **Life-aligned** types put essence in;
**entropy-aligned** types take it out. Everything the game does with corruption
and redemption falls out of that one distinction.

### Why you only get one

Nobody chooses a draw. The first real pull a person makes sets the shape of the
channel, the way the first hard frost sets a crack in stone, and every pull after
that follows the crack. Children who grow up near a vein tend to make that first
pull young and without noticing. Everyone else makes it in a moment of need and
spends the rest of their life finding out which one it was.

This is why the choice is permanent, why it is made once, and why no one in the
world will tell you it can be undone. Reaching into another type is possible.
Becoming another type is not.

### Corruption and redemption

A mage who only ever pushes essence outward is running a deficit they cannot feel
and cannot stop. It does not injure them. It hollows the channel, slowly, and the
hollowing is what the temples named **corruption** — badly, since it has nothing
to do with wickedness and everything to do with erosion. A mage who only ever
draws essence in accrues the mirror of it: a surplus with nowhere to go, pressure
against the walls of a channel shaped only to take. That one got named
**redemption**, which is equally unhelpful and equally stuck.

The mechanically important part is that **the pressure is the currency**. A
life-aligned mage's accumulated hollowing is the only thing that will let them
grip essence the other way round — you cannot learn to take until you have given
enough to be empty. An entropy-aligned mage's accumulated surplus is what buys
the reverse. Mastery of your own pole is what funds the opposite one, and a mage
who never commits to either never accrues enough of anything to reach past their
own two branches.

Hence: practising your own type's signature branch earns the currency, and the
currency spends on every type that is not yours.

### The Blight

A vein can be opened. It takes effort and it is always deliberate, and the people
who did it were, without exception, trying to get essence out faster than a draw
allows.

An opened vein does not gush and does not stop. It bleeds — steadily, outward,
into ground that has no channel for it. Everything caught in the spill gets more
essence than its shape can hold: animals grow wrong and hard to kill, plants go
first to excess and then to rot, and the land itself takes on the flat purple
cast of something over-saturated. It is not a curse. It is a nutrient at a
concentration that kills.

The wound is called a **heart**, which is the one piece of temple terminology
that is actually accurate — it pushes, rhythmically, and what it pushes is
outward. Left alone the stain widens a little every day and never contracts.

Closing one means going to the heart and giving essence back, in quantity,
against the pressure. It is exhausting, it is dangerous, and it is the single
most life-aligned act available in the world — which is exactly why what you walk
away with is redemption. You gave. The surplus is yours.

### The Colossi

Five of them, that anyone has found. They do not resemble each other and they are
not in the same style, which is the first clue that they were not one project.

They are what it looks like when someone tries to draw without a draw. Not a
grip — an aperture: a structure built directly over a vein, wide open, intended
to take everything at once and hold it. Every one of them worked. That is the
part that gets left out. They worked for a while, and then the thing that had
been built to hold everything at once turned out to be a thing that was holding
everything at once, and stopped.

Nobody remembers who built them or what they were called. What you find carved on
them is not their name — it is what the last people to live nearby called them,
generations after, in the local idiom, guessing. That is why no two regions agree
and why the name you learn depends entirely on where you are standing when you
learn it.

The unbuilt sites are more worrying than the ruins. A Colossus that failed is
inert. A vein that a Colossus was built over is not.

### Cantrips, or why the deck matters

A captured card is not a picture of a creature. It is the creature's pattern —
the specific shape its essence held — bound into a form you can carry.

Carry one and you have a curiosity. Carry enough of the same kind and the pattern
starts to impose itself on the route it is riding in, which is to say on you. Not
much, and not permanently, and never enough to make you the thing. Enough to
borrow the trick.

Four is roughly where it takes. Below that the pattern is noise. At four a person
carrying ghosts finds that walls have started to be negotiable, and a person
carrying skeletons finds they know, without deciding to, exactly where the ground
has been disturbed and what is under it.

Every mage discovers this by accident, usually while carrying something they
meant to sell.

### Hearth — the tradition that isn't a type

There is a fifth thing, and it is not a fifth draw.

Most people who can touch essence at all never make the hard first pull. They
make small ones, constantly, for small purposes, and the channel never sets into
a crack — it stays a hundred hairline paths that each carry almost nothing. You
cannot fight with that. You can conjure a horse with it, if you are patient. You
can take the ache out of a bad road, warm a room, put a meal together, tidy up
after a boy who does not.

Practitioners call it **hearth-work** when they call it anything. The temples do
not teach it, do not oppose it, and quietly rely on it. The four types produce
mages. Hearth-work produces the person who gets the wagon there.

It is worth being precise about the trade: a hearth-worker can do a hundred
useful things badly and no destructive thing at all. When one of them tells you
they are not much of a wizard, they are being accurate, and it does not mean what
you would assume.

> **Maiteln practises hearth-work.** This is the intended in-fiction reason he
> conjures horses, smooths roads, tidies rooms and cooks — and never duels. It
> keeps the story's only wizard consistent with a type system he does not fit,
> without adding a fifth type or any balance surface. Formal story canon needs
> human approval — see `tasks/goals/GID-127--magic-cosmology/TID-481--orphan-doc-lore-hooks.md`.

### Mechanics this frame explains

Each row is a number or behaviour already in the code that the cosmology now
accounts for. The lore was written to fit these, not the other way round.

| Implemented behaviour | Lore account |
|---|---|
| Ley lines render as cyan bands, brightest at centre, fading to nothing (`ley_intensity`) | Veins the essence wore for itself; intensity is flow density |
| +15% move speed on a ley line | Essence in motion quickens what it passes through |
| "Attuned" +1 mana on battle turn 1 | More essence passing through you than through the ground beside you |
| Mana Wells spawn only at ley **intersections** (`ley_intersection_strength`) | Surplus surfaces where a crossing carries more than it can hold |
| Mana Wells are one-time collectibles | The crossing keeps flowing; the gathered surplus does not come back |
| Essence is the crafting currency | The only form a person can carry in their hands |
| Blight Hearts spread outward, never contract (`SPREAD_RATE` 0.5/day) | An opened vein bleeds steadily; nothing closes it on its own |
| Blighted enemies gain +5 HP | Over-saturation: more essence than the shape can hold |
| Blight tints terrain purple | The colour of ground past what it can carry |
| Cleansing a heart awards **Redemption** Points | Giving essence back against the pressure is the definitive life-aligned act |
| Blight is a pure function of `(world_seed, days_elapsed, cleansed)` | The bleed is mechanical, not malicious — it just runs |
| 5 Colossi variants, one per biome, no shared style | Five separate attempts, not one project |
| Colossi are ruined | Every aperture worked, then held everything at once, then stopped |
| Colossus names are generated from location | Nobody knows the real names; each region invented its own |
| Cantrips need **4+** family cards | Below four the pattern is noise; four is where it imposes |
| Ghost cards → walk through walls; Skeleton cards → find what's buried | You borrow the pattern's trick, not its nature |
| `magic_type` is chosen once and never changes | The first pull sets the channel; the crack does not move |
| Signature-branch cards earn the currency you spend elsewhere | Committing to your pole is what builds the pressure to reach past it |
| Two currencies span four types | Only two directions exist: essence in, essence out |

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
