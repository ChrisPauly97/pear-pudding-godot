extends Node3D

## First-night wilderness camp on the road out of Madrian (GID-108 / TID-402).
## Interacting triggers the rabbit-hunt scripted battle (see docs/human/story.md
## "Chapter 1: Into the Wild World" beat 2), then the next-morning fire-making
## dialogue on a second interaction. Frees itself once both beats are resolved.

const _CampfireVisual = preload("res://scenes/world/entities/CampfireVisual.gd")

func _ready() -> void:
	# The story's camp is cold ("No fire tonight"): embers smoulder under a smoke
	# wisp until Maiteln's fire lesson frees the node (GID-152 / TID-649).
	_CampfireVisual.build(self, false)


## Three-stage camp interaction. Stage 1 starts the rabbit-hunt tutorial battle;
## stage 2 (next visit, after victory) delivers the fire-making lesson and frees
## this node — its narrative purpose is served. Stage 3 is a defensive fallback
## for a stale node from an earlier session where both flags are already set.
func interact() -> void:
	var sm := SceneManager.save_manager
	if not sm.get_story_flag("chapter1_camp_night"):
		GameBus.hud_message_requested.emit(
			"Rain patters on the leaves overhead. Saimtar creeps toward a rustle in the brush — a rabbit. No fire "
				+ "tonight; it'll have to be eaten raw.")
		GameBus.scripted_battle_requested.emit("rabbit_hunt")
		return
	if not sm.get_story_flag("chapter1_learned_fire"):
		GameBus.hud_message_requested.emit(
			"Maiteln kneels by the cold ashes: \"Flint here, tinder there — patience, lad.\" The first flame catches.")
		sm.set_story_flag("chapter1_learned_fire")
		queue_free()
		return
	GameBus.hud_message_requested.emit("The campfire's long since cold — the lesson is learned.")
