# BID-109: Early skill builds hinge on one recycle node; branch-card nodes do little

**Category:** balance
**Discovered During:** GID-187 / TID-779

## Description

Within a magic type, the branch whose early rows hold a `mod_recycle` node ("Techniques return to your hand
faster": Dawn Clarity, Thorn Wild Sap, Dusk Void Tempo, Flux Leyward Focus, Fracture Fault Line) beats the other
branch by a wide margin at low skill points, because faster Strike / Kick / Guard / Mend is the core of every kit.
Branch-card modifiers (Ember, Bloom: "+20 % to Ember cards") touch only a few cards and barely register.

Probe (typical light player, level 14 vs duelist adept 16, 16 fights): no skills 0, `dawn_clarity` alone 13,
the four Ember nodes 1. TID-779 halved the recycle values (10 → 5, Void Tempo 15 → 8) and made the profile deck
carry two cards of its build's main branch (`BalanceProfiles.branch_deck`). Builds pooled over the magic types now
differ by 6 pp on average (gate 15) but by 33 pp in the level-14 cell (gate 40); per type, Rift and Dark still lean
on their recycle node.

## Suggested Resolution

A design pass on the early rows: give each branch an early node that touches the core kit (or move the recycle
nodes deeper), and make branch-card modifiers stronger where the branch has few cards. Re-check with the
`rewards` section's `builds` rows and a per-type probe.
