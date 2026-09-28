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
| Hero auto-attack | both heroes, main hand every `swing_speed(side)` s (weapon's `WeaponData.swing_speed`, else `tune.hero_swing`) for `unarmed[side] + hero.attack`, scaled by speed ÷ unarmed speed; off hand every `tune.offhand_swing` s for `offhand_damage[side]` — set from the equipped **off-hand slot** item (GID-135 / TID-545, `inventory-and-deck.md` Equipment System) via `BattleRealtime.offhand_damage_for_item()`. Enemy heroes swing only with `hero.attack > 0`. Frozen/stunned heroes don't swing. Turn-based mode has no off-hand swing timer, so an off-hand attack item instead adds a smaller always-on `hero.attack` bonus there (`UpgradeDefs.offhand_turnbased_bonus`) |
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

### In-world rewards (TID-531)

A **routine** in-world win — not a boss, and no soulbind hunt to show (the enemy either has no
signature card or it's already captured) — skips the blocking `BattleResultUI.show_victory()` card
entirely. `BattleScene._show_standard_victory()` calls `_emit_routine_victory_toast()` instead of
building the overlay: it fires the same `GameBus.battle_won` payload the "Collect" button would,
immediately, so `BattleVictory._on_battle_won()` grants the rewards without waiting for a tap.
Boss wins (`show_victory_boss`), soulbind-hunt wins (`show_soulbind` / the hint-text `show_victory`
branch), and any win **not** fought in place (`in_world == false`, still on the classic wipe path)
are unchanged — they keep the full card.

The payload carries `"in_world_toast": true`. `BattleVictory._on_battle_won()` checks it right
where it computes the gambit-adjusted `coins_won` and `xp_amount`, and — because
`_restore_world(after)` runs `after` **inside** the reattach/transition callback, never on the next
line (see the CLAUDE.md spire-draft learning) — passes `_show_reward_toasts.bind(coins_won,
xp_amount, reward_card)` as that callback instead of calling `_restore_world()` bare.
`_show_reward_toasts()` reads `get_tree().current_scene` (the just-reattached/thawed `WorldScene`)
and `world.get_player()` for the anchor position, builds up to three lines ("+N Coins", "+N XP",
the card's name) and hands them to a `scenes/world/RewardToastFx.gd` instance (`Node3D`, one
`Label3D` per line, no `class_name` — preloaded) added as the world's child at the player's
position: it rises `RISE_DISTANCE` over `DURATION` seconds while each label fades out, then frees
itself with a `get_tree().create_timer` — no scene file, no state, gone once the animation ends.

A win with joined enemies (TID-551 adds) still grants their coins/XP/bestiary progress via
`_reward_joined_enemies()` as before; the toast only shows the primary enemy's numbers — showing
every add's reward too is left for a follow-up if it turns out to matter in practice.

Level-ups need no special handling here: `SaveManager.add_xp()` already emits
`GameBus.level_up`, which `SceneManager._on_level_up()` already turns into its own toast
(`_toast.show_text("Level Up!", …)`) — that fires independently of which result path granted the
XP, so a level-up during a routine in-world win gets its own toast for free, on top of (not instead
of) the reward toast. Test: `tests/in_world_battle_smoke.gd`'s `_check_routine_win_toast` (CI) —
engages a signature-bearing enemy with the signature pre-marked captured (forcing the plain
routine-win branch), kills it, asserts no `Continue`/`Collect` button ever appears, and that a
`RewardToastFx` child lands on the world once it's back in `WORLD` state.

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

### Round pulse (TID-547)

Turn-keyed rules (status durations, first-card discount, summoning sickness/attack-count reset, the
desert-biome scorch tick) don't fit either continuous clock, so `RealtimeCombat` runs them on a third,
per-side timer: `tune.round_seconds` (6 s default, tunable from the Tune panel). Each side's pulse fires
independently (mirrors the per-side GCD/mana/draw shape, and grows with adds — TID-551) and runs
`_run_round_upkeep(side)`, which mirrors — in the same order the turn-based path runs them —
`CardInstance.start_turn()`, `BattleFx.process_start_of_turn_statuses()` (poison/freeze),
`PlayerState.start_turn()`'s `grasslands_card_played` reset, and `BattleModifiers._apply_desert_scorch()`.
Turn-based fights are unaffected — those originals are unedited and still run only from
`GameState.end_turn()`/`BattleScene._on_turn_ended()`. One deliberate difference: a card poisoned to 0 HP
is removed from the board immediately (real time has no later turn boundary to lazily clean it up on,
unlike the turn-based version, which is left as-is). Desert scorch applies to each side's own leftmost
minion on that side's own pulse, rather than both boards on every turn-end (the turn-based version's
quirk of scorching both boards twice per full round). Gambits have no periodic per-turn rule to replicate
(only turn-1 one-offs, already handled at battle setup).

### Known prototype gaps (follow-ups)

- Enemy spells are skipped (the turn-based AI also plays them without an effect); enemy ability cards
  arrive with TID-541. Enemy card choice is "most expensive affordable unit".
- One-tap targeting and a fuller input queue (spell-queued *targeted* plays, not just instant ones —
  TID-555 covers the instant/skill-bar case) are still TID-530.
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


## Adds — a second enemy joins (TID-551)

An enemy that engages while a real-time in-world fight is running **joins it** instead of being refused
(`SceneManager.accepts_engage()` → `_battle_accepts_add()` → `BattleRealtime.can_join()`; at most
`RealtimeCombat.MAX_ENEMIES` = 2 enemy heroes). `join_enemy()` builds its hero like the first enemy (tier-scaled
deck, boss HP, 3-card hand) and `RealtimeCombat.add_enemy()` turns the state into a **team battle** (teams
`[0, 1, 1]`), so GameState's win rules end the fight only when every enemy hero is down; a fallen enemy's
minions flee and its token greys out.

- **Each enemy runs its own clocks** — GCD, cast bar (inside its token), pushback, minion swings, hero swing.
- **Targeting:** tap an enemy's hero strip to point your auto-attack at it (`focus_enemy`); hero-targeted spells
  and Ally attacks go at the tapped enemy (`_on_target_chosen_hero(pidx)`, `_execute_attack(…, defender)`);
  minion targets resolve against their owner (`SpellEffectResolver._explicit_opponent`). Untargeted board-wide
  AoE spells (`deal_damage_all`, `apply_poison_all`, `freeze_all`, `debuff_attack`, `destroy_low_hp`) hit
  **every** living enemy side (`GameState.enemy_sides(caster_pid)`, TID-554) — previously only the lowest-HP
  one, same bug `opponent()` has for a co-op boss's AoE against the whole party.
- **Layout:** the add's token stacks under the first enemy's on the right, its row attached to its left.
- **Victory:** `BattleVictory._reward_joined_enemies` marks each joined enemy defeated and pays its coins/XP,
  bestiary and bounty progress. Turn-based fights still refuse a second engage.

## Momentum — always a button to press (GID-139)

Problem (2026-09-27 playtest): with 400 mana at 20/s and a 2 s spend pause, a 3-cost card came
every ~15 s and Strike (6 s cooldown) was the only filler, so most GCDs were idle and the fight
played itself. The fix keeps real time but makes the loop **build → spend**:

- **Strike is the filler:** 0 mana, no cooldown, 2 damage — the GCD (`player_gcd`, now 1.2 s) is its
  only gate. Every damaging skill-bar ability is a *builder*.
- **Essence siphon (lore: striking knocks essence loose and you draw it in — see magic-system.md
  Cosmology):** `RealtimeCombat.on_player_hit(dmg, builder)` grants `siphon_per_damage` mana per damage
  from your hero's swings and damaging skills.
- **Auto-attack toggle** (`RealtimeCombat.auto_attack`, ⚔ Auto button / F, `MomentumHud`): on = swings
  siphon but vein regen × `fighting_regen_mult` (0.4); off ("Focus") = no swings, regen ×
  `focus_regen_mult` (2.0) — bank mana for a burst. Re-enabling restarts the swing timer.
- **Combo charges:** each builder hit adds one (cap `combo_max` 3, pips ◆◇ under the toggle). The next
  hand card spends them all for `combo_refund` mana each; a **full** combo makes that card instant.
  Hook: `BattleRealtime.run_cast` → `MomentumHud.wrap_card` (skill pseudo-cards, marked by the
  `cost_points` meta, are skipped); the combo is spent only once the card actually left the hand.
- **Essence surge procs:** builder hits roll `proc_chance` (0.15), auto hits `auto_proc_chance` (0.05);
  a proc banks `PlayerState.next_card_free` (effective_cost → 0, cleared by `play_card*`) so the next
  card is free and instant. Auto-hit procs arrive as a `{"type": "proc"}` advance event, skill procs
  as `out.proc` from `SkillBar.apply`. The hand pulses gold (free) or blue (full combo) via
  `self_modulate`.
- All numbers are **Momentum** rows in `CombatTuning` (⚙ Tune). Tests: `test_combat_momentum.gd`.
- Next (GID-139 todo): telegraphed heavy enemy attacks (TID-579), real-time hit-stop/shake (TID-580).

## Skill bar — fixed abilities (TID-550)

Decided 2026-09-26: a **small** fixed bar, not a full WoW action bar, so the deck stays the main
engine (draw, hand management, deckbuilding). Bar skills are weaker but always there on their own
cooldowns; deck spells are stronger and single-use. Think Hearthstone's hero power stretched to three
buttons.

- **Logic:** `game_logic/battle/SkillBar.gd` — `ABILITIES` table (cost in mana points, cooldown,
  cast time, effect, `off_gcd`), `SLOTS = 3`, per-slot cooldowns, `blocker()` (reason it can't be
  used), `apply()` (spends mana, applies the effect). Defaults: **Strike** (2 dmg to the focused
  minion / targeted enemy hero, instant, free, no cooldown — the GID-139 filler), **Mend** (heal 6, 1.5 s cast, 20 s), **Kick**
  (interrupt an enemy cast, off the GCD, 12 s).
- **UI:** `scenes/battle/modules/BattleSkillBar.gd` (`BattleRealtime.skills`) — buttons in the bottom
  action strip just left of the hand, with a draining shade (own cooldown or the GCD, whichever is
  longer); Kick pulses while an enemy is casting; keys 1–3. Cast-time abilities go through
  `BattleRealtime.run_cast(card, finish, null, cast_time)` so they share the GCD, spell queue, cast bar
  and pushback. Instants start the GCD unless `off_gcd`; nothing fires mid-cast. Mana is spent and the
  cooldown starts when the ability resolves.
- **Slots:** `SaveManager.skill_bar` (ability ids; empty = `DEFAULT_BAR`). Trainers (TID-537) fill it.
- **Tuning:** `skill_cooldown` multiplier knob (Skill bar group).
- Real time only; turn-based keeps the once-per-battle hero power.

### Learning abilities & the loadout (TID-537, TID-556)

`ABILITIES` also holds **5 trainer-taught abilities** beyond the always-known
Strike/Mend/Kick (`SkillBar.ALWAYS_KNOWN`), each weaker than a typical deck
spell (value ≤ 9, enforced by `test_skill_bar.gd`):

| Ability | Effect | Level / coins |
|---|---|---|
| Guard | Shield: absorbs the next 6 damage (`hero.apply_status("armor", …)`) | 3 / 40 |
| Ember Lance | A slower, heavier strike (9 dmg, 1 s cast) | 5 / 60 |
| Mana Tap | Light hit (2 dmg) that restores 1 mana unit | 4 / 50 |
| Sweep | Hits every enemy minion for 3 | 6 / 70 |
| Daze | A weak stun — cancels an in-flight enemy cast and applies `"stun"` | 7 / 80 |

- **Learning:** `SkillBar.can_learn(id, level, coins, learned)` gates on level,
  coins and "not already learned"; `SaveManager.learn_ability(id, cost)`
  performs the purchase into `SaveManager.learned_abilities: Array[String]`
  (the always-known trio never appear in this list). `SkillBar.new(bar,
  learned)` filters a saved bar id through both `ABILITIES` and `learned` (or
  `ALWAYS_KNOWN`) — an id that was never learned can't surface in a fight even
  if it ends up in `skill_bar` (a stale/tampered save).
- **Trainer NPC:** `npc_type = "trainer"` (`NpcInteractions.show_trainer_panel`)
  — no per-NPC data needed, since every trainer offers the same learnable set.
  Lists each ability with level/cost/description and a Learn button (disabled
  until eligible; replaced with "Known" once learned). Placed in Madrian next
  to the stable. See `docs/agent/enemies-and-npcs.md`.
- **Loadout picker (TID-556):** a dedicated screen for choosing which 3
  learned abilities occupy the bar, reachable from the trainer panel and from
  the deck/inventory screen; writes via `SaveManager.set_skill_bar(bar)`. See
  `docs/agent/ui-and-scene-management.md` ("SkillBarScene — loadout picker").
- **Training dummy (TID-557):** a practice fight against an `EnemyRegistry`
  enemy with `passive: true` (never casts or swings —
  `RealtimeCombat.set_passive()`), huge HP, no rewards and no defeat record.
  Exercises the bar risk-free. See `docs/agent/enemies-and-npcs.md`.

### One-glance layout (2026-09-26)

Everything you act on is in one bottom band: skill strip + hand, with your cast bar above the hand.
There is no bottom-right readout box any more: the GCD is a sweep on the skill buttons and on the hand
cards (`RealtimeVisuals.update_hand_sweep`, pooled overlays on the root; full shade while casting), the auto-attack bar lives on your token, and your target gets a gold ring
(`RealtimeVisuals._update_focus_ring`: focused minion, else the targeted enemy token). Enemy cast bars
(inside their tokens) are larger, and a ready Kick pulses so you can react without looking up.

## New-player onboarding (TID-552 / TID-553, ladder-based since GID-141 / TID-588)

**Ramp** — a fight contains only what the player has learned from a trainer (`UnlockLadder`, see
`docs/agent/starter-zone-and-training.md`). `game_logic/battle/CombatOnboarding.gd` reads
`SaveManager.learned_abilities`:

| Learned | Bar | Hand / Allies | Spell cards |
|---|---|---|---|
| nothing (level 1) | Strike | hidden | — |
| + `mend` (L2) | Strike, Mend | hidden | — |
| + `kick` (L3) | Strike, Mend, Kick | hidden | — |
| + `feat_minions` (L4) | as learned | shown | removed from the battle deck |
| + `feat_spells` (L5) | as learned | shown | in the deck (full fight, `stage` −1) |

- The bar needs no filter: `SkillBar` only holds learned ids.
- Spells: `BattleModifiers._apply_combat_unlocks()` strips `card_class == "spell"` cards from the draw deck
  (not in puzzle / scripted battles).
- Slow clock (60 %): only the very first fight (`realtime_fights == 0`, nothing learned).
- **Battle mode:** a hand-less player always fights in real time — `SaveManager.battle_mode()` (use it instead of
  reading the `battle_mode` setting) returns `"realtime"` until `feat_minions`; after that the setting decides.
- Companion: `BattleModifiers._active_companion()` is `""` until `feat_companion` is learned.
- Migrated saves (v44) have all four unlocks → the full fight.

`scenes/battle/modules/BattleOnboarding.gd` (`BattleRealtime.onboarding`) applies it; the turn-based card tips
(`tutorial_battle_tip`, tap_and_hold / tap_to_cast) wait until the hand is shown (`realtime.shows_card_tips()`).

**Tips** — `BattleOnboarding.tip(id, target)` emits `GameBus.tutorial_popup_requested` (once ever via the
`seen_tutorial_<id>` story flag; the popup pauses the clock) and spotlights `target` with a pulsing gold ring for
3.5 s after the popup closes. Texts in `TutorialRegistry` (`rt_*`):

| Tip | When | Spotlight |
|---|---|---|
| `rt_intro` | first real-time fight | Strike |
| `rt_skill_mend` / `rt_skill_kick` | first fight with it on the bar | that skill |
| `rt_cards` | first fight with the hand | hand |
| `rt_low_hp` | HP ≤ 40 % with Mend on the bar | Mend |
| `rt_enemy_cast` | an enemy casts with Kick on the bar | Kick |
| `rt_out_of_mana` | mana below the cheapest skill | your token |
| `rt_ally` | your first unit on the board | that unit |
| `rt_add` | a second enemy joins | its token |

Smoke tests that aren't about onboarding set `realtime_fights = 99` and mark the `rt_*` tips seen.

## Mentor coaching barks & post-fight tip (TID-558 / TID-559)

Two small pieces ride the same clock, both owned by `BattleRealtime` (`scenes/battle/modules/BattleRealtime.gd`)
and distinct from the one-shot `TutorialRegistry` popups above:

- **Mentor barks** (`mentor_barks`, `scenes/battle/modules/MentorBarks.gd`): short, non-blocking Maiteln
  speech bubbles (portrait + fading label, top-center — clear of the top-left `SidePanel`, the top-right enemy
  hero token, and the bottom action strip / hand / onboarding spotlight). Built only when
  `BarkRules.is_eligible(companion, player_level)` is true: Maiteln learned + equipped as companion
  (`BattleRealtime.modifiers_companion()`) **and** the player is still new (level ≤ `BarkRules.COACH_MAX_LEVEL`
  = 12 — GID-141 moved the gate from the fight-count ramp, because Maiteln joins at level 6, after it). Pure rules (rate limit 8 s, 2 uses per line per fight,
  priority order, line text) live in `game_logic/battle/BarkRules.gd`; the module turns real moments into
  candidates each frame:
  | Moment | Source |
  |---|---|
  | Enemy starts a cast | `RealtimeCombat` "enemy_cast_start" event |
  | An ally is ready | `RealtimeCombat` "ally_ready" event |
  | A skill comes off cooldown | `BattleSkillBar`'s `SkillBar.ready(slot)` false → true transition |
  | You land an interrupt | `BattleSkillBar._resolve` reports a successful `Kick` (`SkillBar.ABILITIES.kick`,
    effect `"interrupt"`) via `BattleRealtime.note_skill_used("interrupt")` — a real, mechanical interrupt
    (`RealtimeCombat.interrupt_enemy_cast`), not flavor text |
  | Low HP / empty mana | Hero state read directly each frame |
- **Post-fight tip** (`fight_stats`, `game_logic/battle/FightStats.gd`): per-fight accumulators (duration,
  skill uses — deck cards **and** skill-bar presses, enemy casts completed, interrupts landed, mana-full/-empty
  time, potions used while low, best-effort auto-attack damage) fed from `FightStats.record_frame` (called from
  `BattleRealtime._process` with `rt` and the frame's events) plus `note_skill_used` and `GameBus.potion_used`.
  `BattleRealtime.fight_tip()` reads the pure `FightStats.pick_tip(data)` rule; it does **not** touch
  `SaveManager.realtime_fights` (already counted once by `BattleOnboarding.begin()`). The win overlay
  (`BattleScene._show_standard_victory` → `BattleResultUI.show_victory` / `show_soulbind` / `show_victory_boss`,
  each with an optional `tip_text` param, default `""`) renders it directly; the loss overlay has no payload on
  `GameBus.battle_lost` and is built later by a different autoload, so the tip is handed off through
  `SceneManager.set_pending_realtime_tip` / `get_and_clear_pending_realtime_tip`, read by
  `BattleDefeat._show_defeat_overlay`. Neither task touches `BattleVictory.gd` (edited concurrently elsewhere).

Gap: `FightStats.card_damage` has no feed yet (spell effects don't report damage back to the driver), so the
"auto-attack neglected" tip rule is inert until something feeds it.
