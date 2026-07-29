# GID-127: Verdant & Rift Magic Types

## Objective

Grow the magic system from two top-level types to four. **Verdant** (branches
Bloom / Thorn) and **Rift** (branches Flux / Fracture) join Light and Dark at
full parity: skill trees, spell cards, battlefield synergy, card art, and the
cross-magic currency economy.

## Context

Requested by the user (2026-07-28): *"can we add two more magic types, light dark
already exist, perhaps corruption and catalyst? or idk something similar to
catalyst or growth or something"*.

Naming and scope were confirmed with the user before any files were created:

- **Verdant** — life, growth, endurance, retribution. Branches **Bloom** (sustain
  and ramp) and **Thorn** (retribution and attrition).
- **Rift** — entropy, transmutation, unmaking. Branches **Flux** (tempo and draw)
  and **Fracture** (removal and disruption).
- "Corruption" was rejected as a *type* name because `corruption_points` is
  already a currency — two unrelated meanings for one word.
- Scope: full parity (skills + cards + battle rules), not skills-only.

### Why this is not a data-only change

The existing system is hard-coded binary in five separate places:

| Location | Binary assumption |
|---|---|
| `SkillTreeScene.MAGIC_BRANCHES` | Two-entry dictionary, `light` / `dark` |
| `SkillTreeScene._opposing_magic()` | `"dark" if mt == "light" else "light"` |
| `SkillTreeScene._cross_currency()` | `"corruption" if mt == "light" else "redemption"` |
| `SkillTreeScene._build_magic_choice()` | Two hard-coded HBox columns |
| `BattlefieldRules.effective_cost()` | `if/elif` on the literal branches `dusk` / `dawn` |
| `PlayerState` | `dawn_cards_played` / `dusk_cards_played` int pair |

Each of these has to become table-driven before a third and fourth type can
exist. That generalization — not the new content — is the risky part of the
goal, so it lands first and alone (TID-477).

### Design decisions

**Single source of truth.** `game_logic/MagicTypes.gd` owns the type → branch
mapping, display names, colors, taglines, and cross-currency assignment. Every
other file reads from it. This follows the same rule CLAUDE.md states for
`IsoConst`: one table, no copies.

**Cross-magic currency with four types.** The currency a player spends is
determined by *their own* magic type (this is the pre-existing rule — a Light
player spends corruption points to reach into Dark). Two currencies cover four
types by alignment:

| Type | Alignment | Spends |
|---|---|---|
| Light | life | corruption |
| Verdant | life | corruption |
| Dark | entropy | redemption |
| Rift | entropy | redemption |

This preserves existing Light/Dark behaviour exactly.

**Signature branches.** Each type has exactly one branch that (a) accrues that
type's cross-magic currency when its cards are played, and (b) gets a −1 mana
battlefield affinity. Light/Dark already worked this way (Dawn, Dusk) without it
being named; the new types follow the same shape (Bloom, Fracture). Light and
Dark branches key their affinity off time of day; Verdant and Rift key theirs off
biome, so the two axes do not collide.

**Cross-magic tab.** Was "the opposing type's cross-purchasable skills". Now "every
non-home type's cross-purchasable skills" — 6 entries for any starting choice.

## Tasks

| Task | Title | Status |
|------|-------|--------|
| [TID-477](TID-477--magic-types-registry.md) | MagicTypes registry + generalized skill tree UI | done |
| [TID-478](TID-478--verdant-rift-skills.md) | 24 Bloom / Thorn / Flux / Fracture skill resources | done |
| [TID-479](TID-479--verdant-rift-cards.md) | 12 Verdant & Rift spell cards + branch rune colors | done |
| [TID-480](TID-480--battlefield-affinity-currency.md) | Branch affinity table + cross-magic currency accrual | done |
| [TID-481](TID-481--docs-and-tests.md) | Agent docs + regression tests | done |

## Acceptance Criteria

- [x] A new player is offered four paths, not two, and the choice persists.
- [x] Choosing Verdant or Rift shows that type's two branch trees with working
      prerequisite chains, connector bars, and skill-point unlocks.
- [x] The Cross-Magic tab lists cross-purchasable skills from all three
      non-home types, priced in the correct currency.
- [x] Existing Light/Dark saves behave identically — same branches, same
      currency, same day/night cost discounts.
- [x] Verdant and Rift spell cards appear in shops, drafts, drops and crafting
      through the normal registry paths, and render a branch-coloured rune.
- [x] Bloom cards cost 1 less in Forest; Fracture cards cost 1 less in Scorched.
- [x] Playing Bloom cards accrues corruption points; Fracture cards accrue
      redemption points — the same rule Dawn and Dusk already followed.
- [x] Headless import clean; full suite green.
