# BID-044: Co-op siege boss engage may race the normal solo-battle signal handler

**Category:** code-smell (suspected correctness bug)
**Discovered During:** GID-106 / TID-391 research

## Summary

`EnemyNPC.engage()` unconditionally emits `GameBus.enemy_engaged`, with no
awareness of co-op joint-battle routing. Two listeners are connected to that
signal:

- `SceneManager._on_enemy_engaged` (`autoloads/SceneManager.gd:416`) — connected
  once at autoload boot, always first in connection order. Starts a normal
  **solo** `BattleScene` whenever `_state == State.WORLD`, with no id/coop-aware
  guard of any kind.
- `WorldScene._on_enemy_engaged_coop` (`scenes/world/WorldScene.gd:1317`) —
  connected later, per-map. For the co-op Town Siege boss
  (`eid.begins_with("siege_boss_")`), it routes to
  `_coop_engage_siege_boss` → `_coop_start_siege_boss_battle` →
  `SceneManager.enter_coop_pve_battle(...)`.

Since Godot signal emission calls listeners in connection order, and
`SceneManager`'s connection always precedes `WorldScene`'s, `_on_enemy_engaged`
runs first on every `enemy_engaged` emission. It sets `_state = State.BATTLE`
synchronously (outside `TransitionManager.transition`'s callable) with no
awareness of a pending joint-battle route. `SceneManager.enter_coop_pve_battle`
itself guards on `_state == State.WORLD` — so if the solo handler runs first and
flips the state, the joint-battle call from `_coop_start_siege_boss_battle`
would silently no-op on the **host**, while clients (who never went through the
solo path themselves) would still correctly enter the joint battle via the
`notify_coop_pve_start` RPC. Net effect if this reasoning holds: the host would
see/fight a normal solo duel against the siege boss while clients see a joint
co-op battle — a visible desync.

## Why not fixed here

Out of scope for TID-391 (this task only introduces the analogous co-op Spire
boss route, and closes the equivalent risk for its own new code with a targeted
guard in `_on_enemy_engaged`: skip the solo path when
`NetworkManager.is_active() and SceneManager.is_coop_spire_active() and
enemy_data.id == "spire_enemy"`). The siege feature (GID-103) is a separate,
already-shipped, already-flagged-as-"unverified in-sandbox" feature; changing
its behavior without being able to run the headless test suite is riskier than
leaving a documented gap.

## Suggested fix

Generalize the guard added for Spire in `_on_enemy_engaged`: check for a
co-op-joint-routed enemy id (siege boss id prefix, Spire's `"spire_enemy"`, and
any future joint-battle enemy) before starting a solo battle, or — more
robustly — have `EnemyNPC.engage()` itself consult a single
`WorldScene`/`SceneManager` predicate ("is this engage going to be routed as a
joint co-op battle?") before ever emitting `GameBus.enemy_engaged`, so the
solo-vs-joint decision is made once, at the source, instead of via signal
connection order between two independent listeners.

## Verification needed

Requires a real headless Godot run (or manual multi-peer log trace) to confirm
whether this is a live bug or whether some other mechanism (not found during
this research pass) already prevents it.
