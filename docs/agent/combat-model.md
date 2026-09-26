# Combat Model — Hero Spells, Allies, Enemy Packs (GID-135 / TID-540)

**Status:** **Option A approved** by the user (2026-09-26). TID-537, TID-541, TID-542, TID-543, TID-544 and TID-545 build on it.

## Problem

1. The user wants battle to be "mostly spells", with skill cards as your abilities, regular
   (creature) cards as companions, and consumables used from the inventory / a D3-style quick slot.
2. A world enemy is **one** sprite, but in battle it has a 20–30 card deck and summons a board of
   ghouls. What you see in the world is not what you fight.
3. Fights should feel WoW-fluid: short, readable, few dead turns.

## Where we are today (facts)

| Area | Today |
|---|---|
| Card pool | 117 cards: **85 spells**, 26 minions, 6 legendaries (`data/cards/*.tres`) — already spell-heavy |
| Structure | Hearthstone-like: two heroes (30 HP), 5 board slots each, mana +1/turn to 10, 1 draw/turn |
| Enemy | `EnemyRegistry` deck of minions (e.g. `ghoul_pack` = 5 ghoul + zombies + skeleton); `phase2_deck` for bosses |
| Skills | 32 passive + 16 active; one active = **hero power button** (`BattleConsumables`) |
| Consumables | `SaveManager.potions`; one potion per battle via picker |
| Gear | 4 slots; gear can inject cards (`WeaponData.injected_card_id`) |
| Soulbinding | Winning under a capture condition earns an enemy's signature **minion** card |
| "Companion" | Already a term: Maiteln etc., one equipped passive (`CompanionRegistry`). Avoid the name clash. |

## Options

### A. Hero & Allies (recommended)

You are the fighter; spells are your abilities; creature cards are a small band of **Allies**.

- **Deck:** spells + skill cards (learned from trainers, TID-537) + gear-injected cards, plus
  **at most 5 Ally cards** (creature/soulbound cards). Deck size rules unchanged (5–30).
- **Your turn:** play spells/skills with mana; summon an Ally into one of **3** ally slots;
  your hero **auto-attacks** once per turn with the equipped weapon (WoW auto-attack).
  Weapon damage from gear gives gear a direct, felt effect.
- **Faster start:** start at **3 mana** (ramp +1 to 10), draw 4 opening cards — fights are 3–6 turns, not 8–12.
  *(Superseded for real time: max mana is fixed per fight from level + gear — see Real-Time Combat.)*
- **Enemy side = encounter** (fixes problem 2), three shapes defined in `EnemyRegistry`:
  | Shape | World | Battle | Win |
  |---|---|---|---|
  | **Pack** (ghoul_pack, undead_horde, spectres) | 2–4 sprites | those units **start on the board**; no enemy hero | clear the board |
  | **Solo** (elite, duelist, most bosses) | 1 sprite | enemy hero only; plays **ability cards** (strike, cleave, enrage, heal) from an ability deck; no summons | hero to 0 |
  | **Summoner** (necromancer, Martarquas shaman, bosses' phase 2) | 1 sprite + ritual FX | current model: hero + summoning deck | hero to 0 |
- **Telegraphs:** the enemy's next action shows as a **cast bar** on the unit that will act
  (evolves today's intent banner) — reads like WoW and lets you react.
- **Consumables:** 2 quick slots (TID-542), usable any time on your turn, **no mana cost**, shared
  **3-turn cooldown** instead of "one per battle". Same buttons usable in the world.
- **Hero power button removed:** active skills become skill cards; passives stay in the tree.
- **Soulbinding stays:** signature cards become Allies (more attractive — they're your party).
- **PvP/co-op:** duels keep hero-vs-hero with the same deck rules (Ally cap applies to both).
  Co-op PvE vs pack/boss works unchanged in shape.

Cost: medium-high. Touches GameState setup/win check, BasicAI (per-unit pack AI + ability AI),
deck validation, weapon data, save migration for decks with >5 minions (auto-move extras to collection).

### B. Keep the Hearthstone model, fix the encounters only

Only the Pack/Solo/Summoner encounter shapes + faster start + quick slot. Minions stay unlimited,
hero power stays. Cheap and low-risk, but battles don't become "mostly spells" and your hero is still passive.

### C. Full action bar (no hand)

A fixed bar of 6 abilities with cooldowns and mana, like WoW itself; cards are only collected to
fill the bar. Most WoW-like, but drops draw/hand/deckbuilding — the game's core TCG identity and
the spec positioning ("every enemy can be soulbound into your deck"). Not recommended.

## Recommendation

**Option A**, rolled out in phases so each ships on its own:

1. **Encounter shapes** (TID-541) — pack/solo/summoner; enemy side only; biggest "makes sense" win.
2. **Pace + controls** (TID-529/530/542) — 3-mana start, quick slots with cooldown, cast bars.
3. **Hero kit** (TID-537 + new work in TID-538) — weapon auto-attack, skill cards replace hero power, 3 Ally slots + deck cap with save migration.

## Battle control layout (landscape phone)

```
┌────────────────────────────────────────────┬────────┐
│  enemy units / enemy hero  (cast bars)     │ ⓘ      │
│────────────────────────────────────────────│        │
│  your 3 ally slots        [HERO ⚔ auto]    │ END    │
│                                            │ TURN   │
│ [Q potion][2 potion]   hand: spells/skills │        │
└────────────────────────────────────────────┴────────┘
```
Keyboard: `Q`/`1`–`2` quick slots, `Space` end turn, number row for hand cards (TID-530).

## Decisions (2026-09-26)

1. **Option A** — Hero & Allies.
2. **Allies are ordinary deck cards**: drawn and played like any card, never auto-deployed at battle start.
   Cap: at most 5 Ally cards per deck, 3 Ally board slots (tunable in TID-545).
3. **Hero HP carries over between fights**, with slow out-of-combat regen and a full heal in towns / beds.
   Healing must be accessible early: more low-level hero heal spells, **food** consumables (out-of-combat
   regen, WoW-style) alongside the existing persistent potions (TID-543).
4. **Terminology** (use everywhere — UI text, docs, code names for new work):
   | Term | Meaning |
   |---|---|
   | **Mentor** | Maiteln-style passive helper; one equipped at a time (today's in-game "Companion") |
   | **Ally** | A player creature card / unit on the player's board |
   | **Minion** | An enemy creature unit on the enemy board |

## Real-Time Combat (decided 2026-09-26)

The user asked for WoW-style parallel combat: "enemy attacks on its own schedule, I use my abilities
on mine". Turns are replaced by per-combatant timers. Puzzles, scripted story battles, PvP, co-op,
team duels and resumed mid-battle saves stay turn-based.

| Rule | Value (prototype) |
|---|---|
| Player global cooldown (GCD) | 1.5 s — a **minimum** between plays; it starts when a cast starts |
| Player cast time (spells) | `0.4 + 0.35 × cost units` s, max 2.5 s; 0-cost instant; summons instant (GCD only). Cast bar "Casting X (N mana)" above the hand; mana is spent when the cast completes; a unit target that dies mid-cast fizzles the spell (card kept, no mana spent) |
| Enemy GCD / cast bar | 3.5 s / 1.5 s — an orange "Enemy casts X (N mana)" bar over the enemy board |
| Mana | **×100 points** (`MANA_SCALE`, `HeroState.mana_scale`): a 3-cost card costs 300. **Fixed max for the fight** = `400 + 35 × (level − 1) + 100 × hero.bonus_mana`, cap 1000 (`max_mana_for`); start full; regen **20 points/s** (one cost unit per 5 s). Enemy level-equivalent = `1 + (tier − 1) × 3`. Turn-based fights keep `mana_scale = 1`. |
| Draw | 1 card every 6 s while hand < 7 (no fatigue from the clock) |
| Board caps | **3 Allies**, **2 enemy minions** (`PlayerState.max_units`); empty slots past the cap are hidden |
| Allies (player units) | **commanded**: ready every 3 s (fresh Ally waits one interval; Surge at once). Tap a ready Ally, then a target — normal attack path (lunge, retaliation), **off the GCD**. Per-card bar: blue charging, green + pulse when ready |
| Enemy minions | auto-attack every 4.5 s, **alternating** the player's weakest Ally and the hero (Ward Allies first); per-card orange bar; **wind-up** (grow + redden) over the last 30 %; lunge on the hit |
| Hero auto-attack | both heroes, main hand every 3.0 s for `unarmed[side] + hero.attack` (player 3; enemy 2 + (tier − 1)); off hand every 2.0 s for `offhand_damage` (TID-545). Frozen/stunned heroes don't swing |
| Arena layout | **Diagonal, full width, centred**: your token bottom-left, the enemy's top-right; each side's slots step top-left → bottom-right and **hug their own hero** — your line just right of your token (bottom-aligned), theirs just left of theirs (top-aligned) — leaving open ground between the lines (`RealtimeVisuals.arena_layout`, `ROW_GAP` = token↔line gap; unit-tested at 16:9 and 20:9: no cross-group overlap, lines attached, ≥ 1 card width apart). `DiagonalBoard.gd` places the slots. The side panel (pause, Effects, battlefield info) moves to the top-left corner and your Cooldown / Auto-attack / Target box to the bottom-right (`_place_corner_panels`); the side mana label is hidden (mana is on your token). Re-laid out on viewport resize |
| Hero tokens | boxes with the hero / enemy sprite; the scene's **hero strips are reparented into them** (HP bar, mana / hand count — still refreshed by CardViewBuilder and still the enemy-hero tap target), plus a swing bar; they **lunge** at the target on each auto-attack |
| Auto-attack target | Ward first; else your **focus** (tap an enemy minion with no Ally selected); tap the enemy hero to clear |
| Clock stops | pause menu, card inspect, first-battle tip, any `TutorialPopup` (group `modal_popup`), and during a commanded attack's lunge (`_action_busy`) |
| Card cost display | `CostLabel` line on every card face: "N mana" (points), blue / green discounted / red not yet affordable; inspect overlay and cast bars show points too |
| Speed | Settings > Battle Mode: Turn-based / Real-time / Real-time (slow, 60 %). Battle Speed = Fast runs real time at 125 %. |

### Fighting in place (TID-528)

With Battle Mode = Real-time, solo battles (`SceneManager._in_world_battle_eligible`: not networked, no
session, current scene has a `_camera`) skip the wipe: `_enter_battle_in_world` keeps the WorldScene in the
tree but frozen (`process_mode = DISABLED`), hides its CanvasLayers (HUD), pushes the orthographic camera
in (size × 0.6 over 0.35 s) and fades the battle overlay in with `in_world = true` (BattleScene skips the
backdrop and dims the Background to 45 %, so the world is the arena). Every exit re-attaches through
`SceneManager.reattach_world()`, which thaws an in-place world (layers back, camera zooms out) or re-adds a
detached one; `_restore_world` skips the wipe for an in-place world. The engaged enemy stays standing in the frozen world:
`EnemyNPC.engage()` / `BlightHeart.engage()` call `SceneManager.free_after_battle(self)`, which frees at once on
the wipe path, or on the next transition back to WORLD when fighting in place. `_exit_tree` frees the held world only
when it has **no parent** (an in-place world is freed by the tree). Test: `tests/in_world_battle_smoke.gd` (CI).

### Prototype (TID-546)

- Pure driver `game_logic/battle/RealtimeCombat.gd`: `advance(delta)` ticks resources, swings (resolved
  in place: damage, deaths → discard) and the enemy cast state machine, returning events
  (`mana`, `draw`, `swing`, `enemy_cast_start`, `enemy_cast`). `current_player_idx` is pinned to 0 so
  the existing hand/targeting input works unchanged; the enemy acts only through events.
- Scene module `scenes/battle/modules/BattleRealtime.gd` (`BattleScene.realtime`): `maybe_start()` at the
  end of `_ready` (gated by `eligible()`), `_process` drives the clock (paused with the pause menu),
  renders events (FX flash/float labels, death ghosts, intent banner as the cast bar), hides End Turn
  and adds a GCD bar + "Target:" label to the side panel. `_can_local_act()` returns false while on
  GCD; `_do_play_card` / `BattleTargeting` slot plays call `note_player_play()`. A plain tap on an enemy
  minion sets focus (`BattleInput._on_enemy_card_input`).
- Tests: `tests/unit/test_realtime_combat.gd`, `tests/realtime_battle_smoke.gd` (in CI scene smokes).

### Mana scale

`HeroState.mana_scale` (1 turn-based, 100 real time) converts card-cost **units** to mana **points**.
`mana`/`max_mana` are points; card `cost`, `bonus_mana` and effect values stay in units.
`PlayerState.effective_cost()`/`base_cost()` return points; mutate mana only via `HeroState.gain_mana(units,
allow_overflow)` / `drain_mana(units)` so every effect scales. Card `.tres` costs are still whole units — a
finer cost (e.g. 150) needs `CardData.cost` in points, planned with the full mode (TID-547). The `mana` event
fires only when a whole unit is crossed; the module updates hero/mana labels every frame.

### Known prototype gaps (follow-ups)

- Turn-keyed effects don't tick: status durations (poison/freeze/stun), once-per-turn passives, weather
  per-turn effects, gambit per-turn rules. Needs a periodic "pulse" (e.g. every 6 s) — TID-547.
- Enemy spells are skipped (the turn-based AI also plays them without an effect); enemy ability cards
  arrive with TID-541. Enemy card choice is "most expensive affordable unit".
- No input queue during GCD/cast (TID-530). No interrupts yet. Summons have no cast time.
- Mid-battle save/resume restores into turn-based mode.


## WoW timing model & tuning (TID-549)

WoW runs five independent clocks; only the GCD gates button presses:

| Clock | WoW | Ours |
|---|---|---|
| Global cooldown | 1.5 s (haste → 1.0 s floor); potions, interrupts, pet commands are off-GCD; ~0.4 s spell queue | `player_gcd` 1.5 s; Ally commands + potions off-GCD; `spell_queue` 0.4 s (cast queued until the GCD ends) |
| Cast time | 0–3 s, starts the GCD; pushback when hit; interrupts cancel | `cast_base + cast_per_cost × units` (≤ `cast_max`); `cast_pushback` × up to `pushback_max_hits`; enemy casts interrupted by a commanded Ally hit on the enemy hero |
| Swing timer | weapon speed (dagger ~1.8 s … 2H ~3.6 s), slow = bigger hits, off hand ~50 % | `WeaponData.swing_speed` (0 = `hero_swing`); damage × speed ÷ `hero_swing`; `offhand_swing` |
| Ability cooldowns | per ability, 6 s … 2 min | deck cards single-use; skill-card cooldowns → TID-550 |
| Resource regen | Classic five-second rule | regen pauses `mana_regen_delay` after any spend, then `mana_regen` pts/s |

**Tuning:** every number above (21 knobs) lives in `game_logic/battle/CombatTuning.gd` `DEFS`. `RealtimeCombat`
reads them each tick; `BattleRealtime` loads overrides from the `combat_tuning` setting. In a real-time fight,
**⚙ Tune** (top-left, or T) opens `CombatTuningPanel`: grouped − / + rows, clock paused, changes apply at once
and are saved on the device; Reset all restores defaults. Max-mana knobs apply from the next fight.
