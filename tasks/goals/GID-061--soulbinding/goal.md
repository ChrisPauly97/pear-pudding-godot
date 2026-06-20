# GID-061: Soulbinding — Every Enemy Is a Card

## Objective

Each enemy type has a signature card obtainable only by winning the battle while a per-enemy capture condition holds, turning the enemy roster into a hunt-and-collect metagame.

## Context

Battles currently reward a random card from the enemy's `drop_pool` plus coins — there is no reason to fight a specific enemy in a specific way. Soulbinding gives every enemy type a unique signature card that can only be "captured" by winning under a special condition (e.g. "land the final blow on their last minion with a spell", "win with your hero at or below N HP"). This turns the 4-type enemy roster into a collection hunt and adds skill-expression goals to otherwise-solved fights.

Design summary:
- `EnemyData` (`data/EnemyData.gd`) gains `signature_card: String` and `capture_condition: String` fields, plus an optional numeric `capture_param: int` for conditions like "win before turn N".
- Conditions are tracked during battle by a small `CaptureTracker` in `game_logic/battle/`, fed from BattleScene action sites (the declared GameBus battle signals `card_played` / `card_attacked` / `battle_ended` are currently never emitted — see TID-218 Research Notes).
- On victory with the condition satisfied, a Soulbind ritual overlay offers the signature card in addition to normal rewards.
- Captured signatures are tracked per save (`SaveManager.captured_signatures: Array[String]`) so each is a one-time capture; repeat wins show the condition status to support the hunt.
- Signature cards are exclusive: not purchasable in `ShopScene` and never present in `drop_pool` arrays.

There are exactly **4 existing enemy types** in `data/enemies/`: `undead_basic` (Undead Wanderer), `undead_horde` (Horde Shambler), `ghoul_pack` (Ghoul Pack Leader), `undead_elite` (Undead Warlord). TID-220 creates one signature card per type.

Complementary: the pending GID-045 bestiary goal tracks seen/defeated enemies in a Journal tab — captured signatures could later surface there as a third reveal tier. No dependency either way; mentioned for context only.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-218 | Capture-condition fields on EnemyData + in-battle condition tracking | agent | done | — |
| TID-219 | Soulbind victory flow, captured-signature save tracking, overlay UI | agent | done | TID-218 |
| TID-220 | Content: signature cards + conditions for the 4 existing enemy types | agent | done | TID-219 |

## Acceptance Criteria

- [ ] `EnemyData` exports `signature_card: String`, `capture_condition: String`, and `capture_param: int`; `EnemyRegistry` exposes accessors for them
- [ ] A `CaptureTracker` in `game_logic/battle/` evaluates at least 4 condition types during battle (spell final blow on last minion, win at/below N hero HP, no minion attacks on enemy hero, win before turn N) with no rendering dependency, and its verdict is queryable at game-over
- [ ] Winning while the condition holds (and the signature is not yet captured) shows a Soulbind ritual overlay offering the signature card in addition to the normal victory rewards; declining or failing the condition leaves normal rewards untouched
- [ ] `SaveManager.captured_signatures: Array[String]` persists captures with a save-version migration; a captured signature is never offered again
- [ ] On repeat wins against an enemy whose signature is uncaptured, the victory overlay shows the capture condition and whether it was met this battle
- [ ] Signature cards do not appear in `ShopScene` listings or any enemy `drop_pool`; they cannot be sold/scrapped (use existing `is_unique` handling) or crafted (`can_craft = false`)
- [ ] All 4 enemy types have an authored signature card `.tres` (with `.uid` sidecar, registered in `CardRegistry`) and an assigned condition tuned to that enemy's deck
- [ ] All tests pass headless (`godot --headless --path . -s tests/runner.gd`)
