# TID-066: Human — Define Chapter 1 Victory Condition

**Goal:** GID-020
**Type:** human-action
**Status:** done — satisfied by GID-107/TID-394+395 (user-approved story pack written into story.md, 2026-07-02)
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Chapter 1 has no defined ending. Without a victory condition the story has no climax or sense of completion. The human must decide what triggers the ending, what is shown, and what happens after.

## What the Human Needs to Do

Open `docs/human/specification.md` and fill in the **Chapter 1 Victory Condition** section (added during goal creation). Answer:

1. **Trigger:** Which specific interaction ends Chapter 1? (Suggested: talking to King Eldar in blancogov_temple after `chapter1_entered_temple` is set)
2. **Ending presentation:** What does the player see? Options:
   - A narration scroll overlay (reuses existing narration system from GID-013)
   - A black screen with text lines fading in
   - A new dedicated ending scene
3. **Story flag set:** What flag marks completion? (Suggested: `chapter1_complete`)
4. **Post-ending flow:** What happens next? (Suggested: return to main menu; Continue button loads save for future Chapter 2 content)

Also open `docs/human/story.md` and consider adding a beat #10 to the Chapter 1 story beats table describing the ending scene text.

## When Done

Notify the agent. TID-067 can then implement the ending.

## Plan

_N/A — human action._

## Changes Made

_N/A — human action._

## Documentation Updates

_N/A — human action._
