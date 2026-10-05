# BID-086: Stray GID-361 / GID-368 references inflate the "highest ID" scan

**Category:** doc-gap
**Discovered During:** GID-153 research

## Description

`tasks/goals/GID-101--mp-social-rewards/TID-369--party-bounties.md` (lines 28, 31) cites "GID-368 duel wins" and
"GID-361 soulbound". No such goals exist (highest goal folder is GID-152); they look like TID numbers mislabelled
as GIDs. A naive "highest GID" grep returns GID-368, risking a skipped ID range.

## Evidence

`grep -rn "GID-36[18]" tasks`

## Suggested Resolution

Replace with the intended TID-361 / TID-368 references.
