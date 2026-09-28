# TID-577: Combo Charges Spent by Cards

**Goal:** GID-139
**Type:** agent
**Status:** done
**Depends On:** TID-576

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Plan

Damaging skill-bar hits add a charge (cap `combo_max`). `BattleRealtime.run_cast`
routes hand cards through `MomentumHud.wrap_card`: a full combo makes the cast
instant; once the card leaves the hand `RealtimeCombat.spend_combo()` refunds
`combo_refund` mana per charge. Pips (◆◇) under the Auto toggle.

## Changes Made

See TID-576 (same commit).
