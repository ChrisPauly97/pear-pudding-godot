# TID-184: Story Objective Markers (Chapter 1 Derived)

**Goal:** GID-049
**Type:** agent
**Status:** pending
**Depends On:** TID-182

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Derive the current story objective from Chapter 1 flags (no new flags) and show it as a distinct marker on the compass ribbon, minimap, and map overlay. The objective updates as the story progresses and disappears when Chapter 1 is complete.

## Research Notes

- **Chapter 1 story flags (in progression order):** From **docs/agent/story-implementation.md** (lines 37–45) and **docs/human/story.md** (NPC dialogue section):
  1. `story_intro_complete` — Set when player speaks to Maiteln in `madrian` map. Objective: reach Maiteln at (45, 36) in madrian.
  2. `chapter1_left_madrian` — Set when player exits madrian map. Objective: leave madrian (reach any door).
  3. `chapter1_warned_farsyth` — Set when player speaks to Lord Farsyth in `farsyth_mansion`. Objective: reach Lord Farsyth at (49, 20) in farsyth_mansion.
  4. `chapter1_received_letter` — Set when Isfig encounter triggers (wilderness event between maykalene and blancogov). Objective: encounter Isfig on the road (NPC spawn location varies; see story beats in docs/human/story.md line 101–102 — "scripted encounter" at open world position, no fixed tile).
  5. `chapter1_reached_blancogov` — Set when player enters `blancogov` map. Objective: reach blancogov map entrance / gate guard at (49, 9).
  6. `chapter1_temple_council` — Set when player speaks to King Eldar in `blancogov_temple`. Objective: reach King Eldar at (42, 15) in blancogov_temple.
  7. `chapter1_complete` — Set by King Eldar dialogue (proposed in docs/human/story.md line 120–123, TODO section — assume the flag is set when the player interacts with the King). No objective after this; chapter is done.

- **Objective tracker function:** Create a new **game_logic/ObjectiveTracker.gd** with a static function:
  ```gdscript
  static func current_objective(flags: Dictionary) -> Dictionary:
      # Returns {label: String, map: String, tx: int, tz: int} or {} if no active objective
      if flags.get("chapter1_complete", false):
          return {}  # Chapter 1 done
      if flags.get("chapter1_temple_council", false):
          return {}  # All flags set, wait for completion (or return empty)
      if not flags.get("chapter1_received_letter", false):
          # Isfig encounter has not happened yet
          if flags.get("chapter1_reached_blancogov", false):
              # Player is past maykalene but before blancogov_temple
              return {label: "Encounter Isfig", map: "main", tx: -1, tz: -1}  # Wildcard: open-world
          if flags.get("chapter1_warned_farsyth", false):
              # Player must leave maykalene and encounter Isfig
              return {label: "Encounter Isfig", map: "main", tx: -1, tz: -1}  # Wildcard
          if flags.get("chapter1_left_madrian", false):
              # Player must reach Farsyth in farsyth_mansion (accessed from maykalene)
              return {label: "Find Lord Farsyth", map: "farsyth_mansion", tx: 49, tz: 20}
          if flags.get("story_intro_complete", false):
              # Player must leave madrian
              return {label: "Leave Madrian", map: "madrian", tx: 50, tz: 50}  # Door or map boundary
          # No flags set yet
          return {label: "Speak to Maiteln", map: "madrian", tx: 45, tz: 36}
      
      # chapter1_received_letter is true
      if flags.get("chapter1_reached_blancogov", false):
          if flags.get("chapter1_temple_council", false):
              return {}
          return {label: "Enter the Temple", map: "blancogov_temple", tx: 42, tz: 15}
      
      # Reached letter but not blancogov yet
      return {label: "Reach Blancogov", map: "blancogov", tx: 49, tz: 9}
  ```
  **Note:** For `chapter1_received_letter` state, the Isfig encounter is a scripted open-world encounter (no fixed tile on any named map). Set `tx = -1, tz = -1` as a wildcard; the compass will clamp this to the ribbon edge. Alternatively, hardcode Isfig's spawn tile from the script that triggers it — but the roadside encounter location is not yet fixed in the code, so `{tx: -1, tz: -1}` is safer for v1.

- **NPC position lookup (alternative to hardcoding):** Map entity positions are defined in **assets/maps/*.txt** files and parsed by **game_logic/world/WorldMap.gd**. To look up an NPC position at runtime, call `world_map.get_tile_at_npc_id(npc_id)` (or similar method if it exists). Check `WorldMap.gd` to see if such a method exists; if not, hardcode the positions as in the function above (simpler for v1, and matches the story bible which lists all NPC positions).

- **Signal-driven updates:** When a story flag changes, `GameBus.story_flag_set(flag_name)` is emitted (see **autoloads/GameBus.gd**, line 24). In CompassRibbon (TID-182), connect to this signal:
  ```gdscript
  GameBus.story_flag_set.connect(_on_story_flag_changed)
  func _on_story_flag_changed(flag_name: String) -> void:
      _update_objective_marker()
  ```
  Call `ObjectiveTracker.current_objective(SaveManager.story_flags)` to compute the new objective and update the registered marker.

- **Marker registration:** In WorldScene after creating the CompassRibbon, register the objective:
  ```gdscript
  var obj = ObjectiveTracker.current_objective(SaveManager.story_flags)
  if not obj.is_empty():
      var pos_func = func() -> Vector3:
          var o = ObjectiveTracker.current_objective(SaveManager.story_flags)
          if o.is_empty() or o.map != SaveManager.current_map:
              return null  # Off-map or no objective
          return Vector3(o.tx * IsoConst.TILE_SIZE, 0.0, o.tz * IsoConst.TILE_SIZE)
      _compass.add_marker("objective", Color(1.0, 0.8, 0.0), pos_func)  # Gold/yellow
  ```

- **MapViewOverlay display (optional):** When opening MapViewOverlay, show a small text label near the close hint: `"Objective: [label]"` if an objective exists, otherwise nothing. Font size `vh * 0.020`, positioned above the close hint. This gives quick context without the map overlay.

- **Minimap marker (optional v1+):** Similar to compass, the minimap can show the objective dot. Apply the same bearing-to-dot logic as the compass, using the same yellow/gold color.

- **Headless tests:** In `tests/unit/test_objective_tracker.gd`:
  - **Flag state exhaustion:** For each possible flag state (no flags, story_intro_complete, chapter1_left_madrian, etc.), call `current_objective(flags)` and verify:
    - Non-empty objective returned (unless chapter1_complete) with correct label, map, and coords.
    - Objective points to a real map/NPC from the story bible (spot-check a few).
  - **Off-map wildcard:** When objective.tx == -1, verify the compass clamps it to the ribbon edge (tested in TID-182 off-map tests, but also confirm integration here).
  - **Completion:** When `chapter1_complete = true`, objective is empty regardless of other flags.

- **Update docs/agent/story-implementation.md:** Add a subsection "Objective Tracking" explaining how ObjectiveTracker derives the current objective and which flag sets which objective. Include the objective table with flag → label → map → coords for reference.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
