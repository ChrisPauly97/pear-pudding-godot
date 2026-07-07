# BID-045: BasicAI Doc Claims Sort-by-Cost/Lowest-HP Behavior the Code Doesn't Implement

**Category:** doc-gap
**Discovered During:** GID-112 research (ad-hoc review of `ai/BasicAI.gd`)

## Description

`docs/agent/battle-system.md`, "BasicAI Logic" section, describes:

```
1. Collect playable cards (cost ≤ current mana), sort by cost ascending
2. For each card: play it into the first empty slot, subtract mana; repeat until no affordable cards or no empty slots
3. For each non-sick minion with attacks_this_turn == 0:
   a. If enemy has minions → attack the weakest (lowest HP) minion
   b. Otherwise → attack enemy hero directly
```

The actual implementation in `ai/BasicAI.gd::decide_turn()` does not sort by
cost, and does not pick the lowest-HP target. It builds one Callable per card
in `ai.hand.duplicate()` (raw hand order, no `.sort()` call anywhere in the
file) and, for attacks, takes `targets[0]` from
`state.opponent().board.get_cards()` (raw board-slot order), only filtering
down to Ward-keyword minions first if any exist. There is no cost-ascending
sort and no HP comparison anywhere in the file. The doc describes intended /
assumed behavior that either was never implemented or regressed silently at
some point — either way, the doc and code have been out of sync since at least
whenever this section was last written.

## Evidence

- `ai/BasicAI.gd:16-24` (play-card loop): iterates `hand_snapshot` in place,
  no sort.
- `ai/BasicAI.gd:28-59` (attack loop): `targets[0]` is the first entry of
  `all_targets`/`ward_targets`, both built by appending in board-slot order —
  never compared by `.health`.
- `docs/agent/battle-system.md`, "BasicAI Logic" section (~lines 166-174),
  claims both behaviors that the code doesn't have.

## Suggested Resolution

GID-112 (TID-415/416, in progress) rewrites this logic anyway to add persona
support and a lethal check — when that work lands, correct the doc to describe
whatever the new `basic` persona actually does (which per TID-416's plan is
meant to preserve today's real behavior, i.e. raw order, not sorted). If
GID-112 is deprioritized or descoped before touching this, resolve
independently by either (a) fixing the doc to say "hand/board order, no
sorting" or (b) actually implementing the sort the doc describes — pick
whichever behavior is intended, since right now neither the doc nor a decision
is authoritative.
