# GID-158: Codebase Cleanup — UI Factory Adoption

## Objective

Hand-built `Button.new()` + text + size + font + connect + `add_child` blocks go through `UiUtil.make_button`.

## Context

User asked to clean up the codebase. CLAUDE.md requires the `UiUtil` factories, but ~21 plain `Button.new()`
sites wrote the boilerplate out by hand.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-666](TID-666--make-button-sweep.md) | Route straightforward hand-built buttons through `UiUtil.make_button` | agent | done | — |

## Acceptance Criteria

- [x] Clean-fit sites converted; behaviour unchanged.
- [x] Tests, battle/menu/world smoke tests, gdlint, `unsafe-hits.sh`, headless import clean.
