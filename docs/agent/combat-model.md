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
| Consumables | `SaveManager.potions`; two Q / E quick slots with a shared cooldown (TID-542) |
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
3. **Hero HP carries over between fights**, with slow out-of-combat regen and a full heal in towns / beds
   (shipped in TID-543 — see `home-garden-potions.md` → Persistent Hero HP).
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
| Allies (player units) | **auto-attack** every `ally_ready` 3 s (fresh Ally waits one interval; Surge at once) at the hero's target — Ward first, else the focused minion, else the targeted enemy hero (`RealtimeCombat._tick_ally`, no retaliation, no command). Tapping an enemy just moves the shared focus |
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


## Encounters that match the world (TID-541)

First cut of the Pack / Solo / Summoner shapes, without changing GameState's win rules (every fight still has an
enemy hero):

- **Pack** (`ghoul_pack`, `undead_horde`): `EnemyRegistry` entries carry `pack` (card ids; `get_pack(type)`). The
  leader is the enemy hero; its pack **starts on the enemy board** — `BattleModifiers._place_enemy_pack(type,
  tier)` right after the enemy deck is built in `_setup_solo_battle`, tier-scaled like the deck
  (`CardDropUtil.enemy_card_stats`), `minion_attack_bonus` applied, ready to act (not summoning-sick). In the world,
  `EnemyNPC._add_pack_followers()` stands the same units around the leader (80 % height, bobbing billboards from
  `SpriteRegistry.pack_member_texture(card_id)`), children of the leader so they chase and vanish with it.
- **Solo** (ability-casting enemies): **not shipped.** An all-spell Warlord deck was tried and reverted after
  review — enemy spells never resolve: `PlayerState.play_card` just discards a spell (only auto-resolve cards
  drawn go through `pending_auto_spells`), and real time's `RealtimeCombat.choose_enemy_card` skipped spells.
  BID-078 has since fixed that (BasicAI queues played spells for the flush; real time resolves them at the player
  in `_after_enemy_play`), so an ability deck is now viable — not yet assigned to any enemy.
- **Leaderless pack** (BID-077, `undead_horde`): an entry with `"leaderless": true`
  (`EnemyRegistry.is_leaderless(type)`) has no hero to fight. `_place_enemy_pack` sets
  `HeroState.leaderless` once the pack is on the board; that stand-in hero takes no damage (`take_damage` no-ops)
  and never swings or winds up heavy blows in real time (`main_hand_damage` → 0). `GameState._resolve_leaderless()`
  (run by `is_game_over()` / `winner()`) drops it to 0 HP when its board is empty, so every existing "enemy hero
  dead" win path, reward and capture check works unchanged. The horde's deck still reinforces, so it is a race to
  clear the board. `PlayerState.hero_unreachable()` (Ward or leaderless) blocks attacking / dropping on the hero;
  spells can't target it; the hero strip reads **PACK / Clear the board** with no HP bar. Real-time auto-attacks go
  at the weakest pack unit (`RealtimeCombat._weakest_pack_member`). The flag persists through `HeroState.to_dict()`
  for resumed fights. The horde's `spell_final_blow` soulbind already means "a spell kills the last minion".
  Tests: `test_leaderless_pack.gd`, `realtime_battle_smoke` (real horde fight: pack on board, untouchable, clear wins).
- **Summoner**: everyone else keeps the current summoning deck.
- Co-op PvE, PvP, puzzles and scripted fights don't use `_setup_solo_battle`, so they're unchanged.
- Tests: `test_enemy_encounters.gd` (pack data; the Warlord keeps a summoning deck until BID-078); `battle_input_flow_smoke` checks the ghoul
  pack is on the board when the fight opens.

## Chain pulls — the next enemy follows straight on (TID-532)

When an in-place fight is won (`BattleVictory._on_battle_won`, standard path) and an `EnemyNPC` that is
already **pursuing** (`is_pursuing()`: alive and ALERTED or CHASING; every EnemyNPC joins group
`EnemyNPC.GROUP` = `world_enemy`) stands within `CHAIN_RADIUS` (9 world units) of the hero, it engages at once:
`_start_chain()` lifts the 2 s post-battle `_proximity_engage_blocked` grace and calls its `engage()`, with an
"Another one!" toast. `SceneManager.hold_fight_zoom` keeps the camera pushed in across the hand-off —
`_thaw_world` skips the zoom-out while it is set, and `_freeze_world` keeps the original `battle_cam_size`
meta instead of re-recording a zoomed size — so the chain never resets the camera; the last fight's thaw
restores it. If the follow-up never starts within `CHAIN_GIVEUP_SECONDS` (1.5 s, e.g. it stood down) the held
zoom is released. Solo only (no chain in a co-op session); detached (non-real-time) battles never chain.
Covered by `tests/in_world_battle_smoke.gd` → `_check_chain_pull`.

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

## Determinism (GID-176 / TID-712)

A real-time fight replays exactly when its randomness is seeded. There are two sources:

- `RealtimeCombat.rng` (procs): randomized in `_init`; set `rt.rng.seed = n` after construction.
- The global RNG (deck `shuffle()` in `PlayerState` / `RealtimeCombat.trim_hand`, `randi()` picks in
  `SpellEffectResolver`): call `seed(n)` **before** building decks.

`SpellEffectResolver.silent = true` skips its `AudioManager` sound calls for headless batch runs. Nothing else on the
real-time fight path touches an autoload. `CardInstance` instance ids still count up across fights, so compare
template ids, not instance ids. Test: `tests/unit/test_battle_determinism.gd` (same seed → identical 60 s trace;
mutation-checked by dropping either seed).

## PlayerCaster — the player's casting rules, shared (GID-176 / TID-713)

`game_logic/battle/PlayerCaster.gd` is the single, pure home of the local player's real-time rules:

- **GCD gate:** `on_cooldown()` (outside the spell-queue window, or mid-cast).
- **Cast state machine:** `begin(card, finish, target, cast_time)` → `tick(dt)`. Queue delay, the GCD start, a
  technique's own cast time, pushback from hits since the last tick, fizzle when the unit target left the board,
  then `finish`.
- **Off-GCD:** `run_off_gcd()`.
- **Combo / free-cast payoff:** a non-technique card is wrapped by `_with_combo`, and a full combo makes it instant.
- **Techniques:** `is_off_gcd`, `technique_blocker`, `resolve_reactive` (Kick / Daze), `casting_enemy`, and builder
  hits after a technique resolves.

`BattleRealtime` owns one (`caster`) and only presents. `run_cast` / `run_off_gcd` / `is_casting` / `on_cooldown`
/ `note_player_play` forward to it, and its `notify` events (`combo`, `proc`, `interrupt`, `dazed`, `fizzled`,
`resolved`, `technique`) become toasts, hit feel, FightStats and quest progress in `_on_caster_event`.
`MomentumHud` lost `wrap_card`; `RealtimeTechniques` keeps only presentation (`control_for`, `pulse_reactive`).

The balance simulator plays through `play(card, resolver, target)` / `play_blocker(card)`. These apply the same
gates as a hand tap, the same cast path, then `PlayerState.play_card*` + `SpellEffectResolver` (Allies go to the
first free slot), without FX. Not mirrored: snow first-card discount, weather on summons, scripted-battle tutorial
steps. Tests: `tests/unit/test_player_caster.gd` (mutation-checked on pushback and the combo spend).

## BattleSetup — shared fight setup (GID-176 / TID-714)

`game_logic/battle/BattleSetup.gd` (pure statics) holds what an ordinary solo PvE fight starts with. The scene
calls each piece with values read from the save, and the balance simulator calls `build(cfg)`:

| Piece | Called by the game from |
|---|---|
| `unlock_filter(deck, learned)` (minions / spells until learned, techniques always) | `BattleModifiers._apply_combat_unlocks` |
| `apply_gear(player, [{id, level, mult}], realtime)` | `BattleModifiers._apply_equipment_effects` (builds the item list from the save) |
| `apply_passives(player, skill_ids)` | `BattleModifiers._apply_passive_skills` |
| `enemy_tier(type, is_boss, enemy_level)` | `BattleScene._setup_solo_battle` |
| `setup_enemy(enemy, player, type, deck, tier, level, boss_hp)` (mirror trait deck, tier-scaled build + opening hand, pack, boss HP, zone HP; an empty deck keeps GameState's default) | `BattleScene._setup_solo_battle` (then `modifiers.set_trait_source`) |
| `enemy_round(state, type, tier, round_n)` (fight traits) | `BattleModifiers.apply_enemy_traits` |
| `configure_realtime(rt, level, type, weapon_speed, offhand, puzzle)` (heavy blows on, enemy-minion cap by **enemy** level, ally cap, opening-hand trim, gear timers, passive) | `BattleRealtime.maybe_start` |
| `enemy_spell_scale(rt, side)` (0..1 power of an enemy side's spells by its level) | `BattleRealtime._after_enemy_play`, `BalanceFight` |
| `apply_live_tuning(rt, base_tier)`, `enemy_level_for_tier`, `offhand_damage_for_item`, `weapon_speed_for_item` | `BattleRealtime` (its statics forward here) |

`build(cfg)` keys: `player_level`, `learned`, `deck` (default `starter_deck()` = new-game deck + Strike), `gear`,
`weapon`, `offhand`, `skills`, `enemy_type` (`undead_basic`), `enemy_level`, `is_boss`, `tuning`, `seed`. It
returns `{state, rt, tier}` in the scene's order: player deck → unlock filter → gear → passives → opening hand →
enemy → `start_turn(1)` → RealtimeCombat + `configure_realtime` + live tuning. Not covered (scene-only, BID-094):
spire / siege HP, gambits, ambush, blight, weather, battlefield biome, companions, persistent HP.

Guard: `realtime_battle_smoke` `_check_setup_matches_sim` builds the sim fight next to the real scene and compares
enemy max HP, ally / enemy-minion caps, heavy blows, base damage and both max manas (mutation-checked). Unit tests:
`tests/unit/test_battle_setup.gd`.

## Enemy strength by enemy level (GID-176 / TID-720)

Enemies act the same whatever the player has learned; only the **enemy's** level (`RealtimeCombat.side_levels`)
changes them. Knobs (CombatTuning, Enemy group):

| Knob | Default | Effect |
|---|---|---|
| `heavy_min_level` | 1 | Enemies below this never wind up heavy blows (every enemy by default; heavies soften on the same curve as spells) |
| `enemy_full_level` | 10 | Level at which heavies / spells hit at full strength |
| `enemy_low_scale` | 0.5 | Strength at level 1; `CombatTuning.level_scale(L)` lerps to 1 at `enemy_full_level` |
| `enemy_two_minions_level` | 4 | Below this an enemy fields one minion |

`heavy_damage(side)` = player max HP × `heavy_frac` × `level_scale`. Enemy spells keep their cast bars at every
level (so Kick is familiar when learned) but `SpellEffectResolver.resolve_enemy_play(..., power_scale)` scales
`spell_power` for that resolve. `CombatOnboarding` only shapes the **player's** side (hand, spells, Ally slots).

## Balance bot and single fight (GID-176 / TID-715)

- **`game_logic/battle/BalanceBot.gd`**: a simple, deterministic stand-in player. Its `decide(caster)` picks one
  card (in this order):
  1. Kick, else Daze, on an enemy cast (Daze first on a heavy blow).
  2. A heal below `policy.heal_below` (0.4).
  3. The best Ally by (atk + hp) / cost.
  4. The best spell by power per mana unit.

  Targets go to enemy Ward minions, else the weakest enemy minion, else the hero (plain damage only); friendly
  spells go to your weakest Ally. A card with no sensible target falls through to the next. Ties break by hand
  order. Slot- and ally-targeted spells are skipped. `act()` plays through `PlayerCaster.play`. The policy knobs
  (`heal_below`, `summon`, `interrupt`) are sweepable.
- **`game_logic/battle/BalanceFight.gd`**: `run(cfg, policy)` runs one seeded fight at a fixed 0.05 s tick, making
  the scene's calls minus presentation:
  1. `BattleSetup.build`.
  2. Each tick: the bot acts → `caster.tick` → `rt.advance`.
  3. `enemy_cast` → `SpellEffectResolver.resolve_enemy_play` (now shared with `BattleRealtime._after_enemy_play`).
  4. Enemy `round` → `BattleSetup.enemy_round`.

  It returns `{result, seconds, hero_hp, hero_hp_frac, plays, dealt_cards, dealt_auto, interrupts, enemy_casts,
  procs, full_mana_s}`. It runs about 30 fights/s headless.
- **Not simulated:** boss phase 2, weather, companions, gambits, potions / hero power, commanded Ally attacks, focus
  changes.
- **Tests:** `tests/unit/test_balance_bot.gd`:
  - Kick on a cast.
  - Mend only when low.
  - Strike at the hero on an empty board.
  - Every decision legal over three whole fights.
  - Same seed → identical fight result.

## Momentum — always a button to press (GID-139)

Problem (2026-09-27 playtest): with 400 mana at 20/s and a 2 s spend pause, a 3-cost card came
every ~15 s and Strike (6 s cooldown) was the only filler, so most GCDs were idle and the fight
played itself. The fix keeps real time but makes the loop **build → spend**:

- **Strike is the filler:** 0 mana, no cooldown, 2 damage — the GCD (`player_gcd`, now 1.2 s) is its
  only gate. Every damaging technique card is a *builder* (GID-175).
- **Essence siphon (lore: striking knocks essence loose and you draw it in — see magic-system.md
  Cosmology):** `RealtimeCombat.on_player_hit(dmg, builder)` grants `siphon_per_damage` mana per damage
  from your hero's swings and damaging techniques.
- **Auto-attack is always on** (`RealtimeCombat.auto_attack`; the old ⚔ Auto / F "Focus" toggle and
  `focus_regen_mult` were removed): melee swings are automatic, siphon mana, and vein regen runs ×
  `fighting_regen_mult` (0.4). The one starter ability, **Strike** (5 dmg, free), runs on a 6 s cooldown
  instead of being a GCD-spammed filler.
- **Combo charges:** each builder hit adds one (cap `combo_max` 3, pips ◆◇ on the action strip). The next
  hand card spends them all for `combo_refund` mana each; a **full** combo makes that card instant.
  Hook: `PlayerCaster.begin` → `_with_combo` (technique cards are skipped, GID-175); the combo is spent only once the card actually left the hand.
- **Essence surge procs:** builder hits roll `proc_chance` (0.15), auto hits `auto_proc_chance` (0.05);
  a proc banks `PlayerState.next_card_free` (effective_cost → 0, cleared by `play_card*`) so the next
  card is free and instant. Auto-hit procs arrive as a `{"type": "proc"}` advance event, technique procs
  from `PlayerCaster._after_technique`. The hand pulses gold (free) or blue (full combo) via
  `self_modulate`.
- All numbers are **Momentum** rows in `CombatTuning` (⚙ Tune). Tests: `test_combat_momentum.gd`.
- Next (GID-139 todo): telegraphed heavy enemy attacks (TID-579), real-time hit-stop/shake (TID-580).

## Technique cards (GID-175 / TID-706) — supersedes the fixed skill bar

Decided 2026-10-08. The spec's `## Identity` rule is that **the card is the atomic unit of the game**. The fixed
3-slot bar (TID-550) broke it, so every bar ability becomes a **technique card**: deckbuilt, drawn and played from
the hand. The sections "Skill bar — fixed abilities" and "Learning abilities & the loadout" below describe the old
model and stay only until TID-710 removes the code.

### Rules

| Rule | Decision |
|---|---|
| Card type | `card_class = "spell"` (so every spell path — targeting, cast bar, resolver — works unchanged) with a `tech_*` id; `TechniqueDefs.is_technique(id)` is the marker. Typeless (`magic_type = ""`), `can_craft = false`, `is_unique = true` (can't be traded, auctioned or stashed), never dropped, never captured |
| Cooldown → recycle | Once a technique **resolves** it goes to the **bottom of `draw_deck`**, not the discard. Deck cycling is its cooldown. A fizzled cast keeps the card in hand (as with spells) |
| Copies | **1 copy** of each technique per deck |
| Deck cost | Techniques **take deck slots**, max **3 per deck** (`TECHNIQUE_DECK_MAX`, same weight as the old 3 slots). The cap also stops a tiny all-technique deck from cycling forever |
| Cost | Card cost units, ×100 in real time like any card: **0** for Strike, Kick, Mana Tap and Daze; **1** for Mend, Guard, Ember Lance and Sweep |
| Real-time extras | `game_logic/battle/TechniqueDefs.gd`, keyed by card id: `cast` (s, overrides the spell cast formula), `off_gcd`, `rt_value`, `mana_value`, `level_req`, `learn_cost`. It replaces `SkillBar.ABILITIES` and `UnlockLadder` reads it. The `.tres` holds only the face (name, cost, `spell_effect`, `spell_power` = turn-based value) |
| GCD | Same as spells. Off-GCD techniques (Kick, Daze) skip the GCD gate but not "nothing fires mid-cast" |
| Momentum | Damaging techniques are **builders** (`on_player_hit(dmg, true)`, can proc). Techniques **don't spend** combo or `next_card_free` (same as the old skill pseudo-cards) |
| Reactive cards | Kick and Daze are held, not always ready: keeping one in a 5-card hand is the choice. A held Kick **pulses** while an enemy casts |
| Both modes | Techniques work turn-based too (values below). The once-per-battle hero power stays |
| Enemies | Enemies get no techniques; enemy casts stay as they are |
| Auto-attack | **Kept** (user, 2026-10-08): weapon-driven, passive, feeds the deck through the siphon. No manual swing and no weapon abilities. If auto-attack decides fights, lower its damage rather than weakening cards |
| Filler | Strike is a normal deck card (not guaranteed). Auto-attack covers the gaps. If playtests show dead hands, lower `draw_interval` (9 → 7 s) before anything else |
| Learning | A trainer "Learn" grants **one** technique card into the collection (shows its face). Strike is in the starter deck. On load, a learned technique missing from the collection is re-granted |
| Visual | Typeless → neutral frame; the description opens "↻ Technique —" and ends "Returns to the bottom of your deck." A dedicated badge is optional polish |
| Pools | `CardRegistry.get_all_ids()` **excludes** techniques (every drop / shop / pack / draft / craft pool is built from it); `get_technique_ids()` lists them |

### The eight techniques

| Card | Cost | Real time (`TechniqueDefs`) | Turn-based (`spell_effect` / power) | Level / coins |
|---|---|---|---|---|
| Strike | 0 | 5 dmg to target, instant | `deal_damage_single` 2 | starter |
| Mend | 1 | heal 6, 1.5 s cast | `heal_hero` 4 | 2 / 15 |
| Kick | 0 | interrupt enemy cast, off GCD | `stun_single` (a minion, 1 turn) | 3 / 25 |
| Guard | 1 | armor 6 | `armor_hero` 4 | 11 / 60 |
| Ember Lance | 1 | 9 dmg, 1 s cast | `deal_damage_single` 4 | 13 / 90 |
| Mana Tap | 0 | 2 dmg + 1 mana unit | new `mana_tap`: 1 dmg + 1 mana | 14 / 90 |
| Sweep | 1 | 3 to every enemy minion | `deal_damage_all` 1 | 16 / 120 |
| Daze | 0 | cancel enemy cast + `stun`, off GCD | `freeze_single` (a minion, 1 turn) | 18 / 150 |

Turn-based numbers start low because a 0-cost card that keeps coming back is strong at 30 HP. TID-707 tunes them,
and a test still keeps every value ≤ 9.

### Implementation (TID-707)

- `game_logic/battle/TechniqueDefs.gd`: `DEFS` (rt_value, cast, off_gcd, mana_value, level_req, learn_cost), `ORDER`,
  `DECK_MAX` 3 / `MAX_COPIES` 1, `power(id, printed, realtime)`, `cast_time`, `off_gcd`, `deck_violation(ids)`.
- `data/cards/tech_*.tres` (8, with `.uid`), preloaded in `CardRegistry`.
- `PlayerState._retire_spell()`: a played technique is `push_front`ed onto `draw_deck` (`draw_card` pops the back).
- `SpellEffectResolver.resolve_spell`: `power = TechniqueDefs.power(...)` with real time = `hero.mana_scale > 1`; new
  `mana_tap` arm (enemy hero damage + `gain_mana(mana_value)`), label in `SpellEffectLabels`.
- Real-time-only behaviour (cast override, off-GCD, Kick/Daze interrupting an enemy cast) is wired in TID-709;
  until then Kick/Daze resolve their turn-based stun/freeze in real time too.
- Tests: `tests/unit/test_technique_cards.gd`.

### Real-time integration (TID-709)

- **No bar:** `BattleSkillBar` is no longer built (`BattleRealtime.skills` is gone). The technique logic lives in
  `scenes/battle/modules/RealtimeTechniques.gd` (`BattleRealtime.techniques`, a RefCounted helper; real-time only). Number keys 1–9 play hand cards
  (`BattleShortcuts.first_hand_key()` = `KEY_1`).
- **Tap routing** (`BattleInput._realtime_technique_tap`): an untargeted technique (and Kick / Daze) casts on tap,
  with no confirm; targeted ones (Strike, Ember Lance) use the normal targeting flow.
  `PlayerCaster.technique_blocker()` refuses Kick with nothing casting ("Nothing to interrupt").
- **Cast time:** `run_cast` takes `TechniqueDefs.cast_time(id)` when the caller passes none (Mend 1.5 s, Ember Lance
  1 s, others instant).
- **Off-GCD:** `_can_local_act(ignore_gcd)` is passed `caster.is_off_gcd(card)`, and `BattleRealtime.run_off_gcd()`
  resolves at once without starting or waiting on the GCD.
- **Kick / Daze:** in real time `PlayerCaster.resolve_reactive()` replaces the resolver. Kick interrupts the
  casting enemy (target first); Daze stuns that hero and cancels its cast.
- **Momentum:** `PlayerCaster._after_technique()` runs after a cast or off-GCD resolve. Damage dealt → `rt.on_player_hit(dmg,
  true)` (siphon, combo, proc); also `note_skill_used`, plus quest `use_skill` progress with the ability id.
  `PlayerCaster.begin` only combo-wraps non-technique cards (techniques never spend combo). `PlayerState.effective_cost` / `play_card`
  never spend `next_card_free` on a technique.
- **Kick pulse:** `RealtimeTechniques.pulse_reactive()` pulses a held Kick / Daze card (`modulate`) while an enemy casts.
  `control_for(ability_id)` finds a technique's hand panel (onboarding tips use it too).
- **Onboarding:** the hand is always shown. `BattleModifiers._apply_combat_unlocks` strips minions until
  `feat_minions` and spells until `feat_spells` but always keeps techniques, so a level-1 hand is technique-only.
  Ally slots stay locked. Tips anchor to technique cards; `rt_*` tutorial texts describe cards.
- **Mentor bark** `cooldown_ready` fires when a technique comes back into the hand.
- Tests: `realtime_battle_smoke` (Strike from the hand hits + recycles to the bottom, Mend casts; the first fight's
  hand is technique-only); `test_technique_cards` (free-cast exemption).

### Learning & migration (TID-708)

- **Ids:** `learned_abilities` keeps the plain ability ids (`"mend"`) next to the `feat_*` ids, so UnlockLadder
  gates and onboarding are unchanged. `TechniqueDefs.card_for("mend")` → `"tech_mend"`, `ability_for` reverses
  it, and `known_cards(learned)` = Strike + each learned technique.
- **Ladder:** UnlockLadder skill rows read `level_req` / `learn_cost` from `TechniqueDefs.DEFS`. The how-to texts
  describe cards.
- **Learning:** `SaveManager.learn_ability(id)` → `_own_technique("tech_" + id)` (one bound instance, skips the
  bag cap) → `_add_technique_to_deck(uid)` (only if the deck is under `IsoConst.DECK_MAX` and
  `deck_violation` stays clean). The trainer panel toasts "<Name> card added to your collection."
- **Starter:** `new_game` and the cold co-op `ensure_coop_deck` deal Strike into the deck.
- **Deck builder:** `InventoryScene._on_add_by_uid` refuses a technique that breaks the rules (HUD message).
  Auto-fill never picks techniques.
- **Migration v46** (`SaveMigrations._m46_technique_cards`): the old `skill_bar` (or the default
  Strike/Mend/Kick, filtered to what the save knew) becomes `technique_deck_pending` card ids, and `skill_bar` is
  erased. On load, `SaveManager._restore_technique_cards` owns every known technique (an idempotent repair on every
  load) and deals the pending ones into the active deck.
- `skill_bar` left `PERSISTED_FIELDS` in TID-710; v46 erases it from old saves.
- Tests: `tests/unit/test_technique_learning.gd`, `test_unlock_ladder.gd`.

## Skill bar — retired (GID-175 / TID-710)

The fixed 3-slot bar (TID-550), its loadout picker (`SkillBarScene`, TID-556), `SkillBar.gd`, `BattleSkillBar.gd`,
the `skill_bar` save field and the `skill_cooldown` tuning knob are gone. The same eight abilities are technique
cards — see "Technique cards (GID-175)" above. The trainer panel (`NpcInteractions.show_trainer_panel`) teaches
them through UnlockLadder skill rows; the training dummy (TID-557, `EnemyRegistry` `passive: true`) still gives a
risk-free practice fight.

### One-glance layout (2026-09-26)

Everything you act on is in one bottom band: the action strip (combo pips) + hand, with your cast bar above the hand.
There is no bottom-right readout box any more: the GCD is a sweep on the hand
cards (`RealtimeVisuals.update_hand_sweep`, pooled overlays on the root; full shade while casting), the auto-attack bar lives on your token, and your target gets a gold ring
(`RealtimeVisuals._update_focus_ring`: focused minion, else the targeted enemy token). Enemy cast bars
(inside their tokens) are larger, and a held Kick card pulses so you can react without looking up.

## New-player onboarding (TID-552 / TID-553, ladder-based since GID-141 / TID-588)

**Ramp** — a fight contains only what the player has learned from a trainer (`UnlockLadder`, see
`docs/agent/starter-zone-and-training.md`). `game_logic/battle/CombatOnboarding.gd` reads
`SaveManager.learned_abilities`:

| Learned | Technique cards | Allies (minion cards) | Enemy minions | Spell cards |
|---|---|---|---|---|
| nothing (level 1) | Strike | locked (stripped from the battle deck) | 1 | — |
| + `mend` (L2) | Strike, Mend | locked | 1 | — |
| + `kick` (L3) | Strike, Mend, Kick | locked | 1 | — |
| + `feat_minions` (L4) | as learned | in the deck | up to 2 | removed from the battle deck |
| + `feat_spells` (L5) | as learned | in the deck | up to 2 | in the deck (full fight, `stage` −1) |

- The hand is always shown (GID-175). `BattleModifiers._apply_combat_unlocks()` strips minion cards until
  `feat_minions` and spell cards until `feat_spells`, but always keeps technique cards (not in puzzle / scripted
  battles). Only learned technique cards are owned, so they need no filter.
- Early fights stay small (below `CombatOnboarding.EARLY_LEVEL` 10): 1 enemy minion, `EARLY_ALLY_CAP` 2 Allies
  (`RealtimeCombat.set_ally_cap`), opening hand trimmed to 2 (3 later) via `RealtimeCombat.trim_hand`. Draws are
  every `draw_interval` 9 s up to `hand_cap` 5.
- Enemy minions (BID-084 / BID-085): `CombatOnboarding.enemy_minion_cap()` is 1 until `feat_minions` (then
  `MAX_ENEMY_MINIONS`); `BattleRealtime` passes it to `RealtimeCombat.set_enemy_minion_cap()`, which sets
  `max_units` on every enemy side and on adds that join later, so `can_play` rejects extra minion cards. The new
  player still sees a summon without facing a full board. Pre-placed pack units are unaffected.
- Locked Ally slots (BID-085): with no hand the hand row is hidden but your Ally slots stay, each empty one under a
  "Locked · Allies at Lv N" plate (`scenes/battle/modules/AllySlotLocks.gd`, owned by `RealtimeVisuals`, placed per
  frame; the plates swallow taps). N is `UnlockLadder.level_req(FEAT_MINIONS)`.
- Slow clock (60 %): only the very first fight (`realtime_fights == 0`, nothing learned).
- **Battle mode:** a hand-less player always fights in real time — `SaveManager.battle_mode()` (use it instead of
  reading the `battle_mode` setting) returns `"realtime"` until `feat_minions`; after that the setting decides (unset = `SaveManager.DEFAULT_BATTLE_MODE`, `"realtime_slow"`).
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
  | A technique comes back round | technique cards in hand rise since last frame (`MentorBarks._cooldown_candidates`) |
  | You land an interrupt | `PlayerCaster.resolve_reactive` reports a successful Kick card via `BattleRealtime.note_skill_used("interrupt")` — a real, mechanical interrupt
    (`RealtimeCombat.interrupt_enemy_cast`), not flavor text |
  | Low HP / empty mana | Hero state read directly each frame |
- **Post-fight tip** (`fight_stats`, `game_logic/battle/FightStats.gd`): per-fight accumulators (duration,
  skill uses — deck cards, technique cards included, enemy casts completed, interrupts landed, mana-full/-empty
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

## Telegraphed heavy blows (GID-139 / TID-579)

Enemies wind up a **Heavy Blow** every `heavy_every` (12 s; first at 60 %) for `heavy_windup` (2.2 s), landing
`heavy_frac` (25 %) of the player's max HP. It rides the existing cast bar as a pseudo card
(`RealtimeCombat.make_heavy_card()`, `card_class == HEAVY_CLASS`), so **Kick interrupts it** (the same
`interrupt_enemy_cast` / `SkillBar._casting_enemy` path), pushback applies, and **Guard / armor soaks it**
(`HeroState.take_damage`). Events: `enemy_heavy_start` (toast "Heavy Blow incoming — Kick it or Guard!", Maiteln's
"cast_bar" bark) and `enemy_heavy_hit` (red float + shake). `RealtimeCombat.heavy_enabled` is set by
`BattleRealtime` only once the player has learned **Kick** (GID-141 ladder, L3) and not in puzzles, so new players
never face a blow they can't answer. Knobs: `heavy_every`, `heavy_windup`, `heavy_frac` (CombatTuning, Enemy group).

## Hit feel (GID-139 / TID-580)

`BattleRealtime.hit_feel(strength)` = a brief hit-stop (the combat clock holds; `_hitstop_left`) plus
`BattleFx.trigger_shake`, from `_HIT_FEEL` = [seconds, pixels]: 1 = a hit (your auto-attack swing, a skill hit) 0.045 s
/ 2.5 px; 2 = a free-cast proc or a combo card 0.08 s / 5 px; 3 = a full-combo or free card 0.12 s / 8 px. Both obey
the Screen Shake setting. Callers: `BattleRealtime` (player swing events), `BattleSkillBar.press`, `MomentumHud`
(`on_proc`, combo card payoff).
