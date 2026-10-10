# gdlint: disable=max-file-lines
## Real-time battle mode (GID-135 / TID-546 prototype): drives
## `RealtimeCombat` from `_process`, renders its events, and gates player
## plays on the global cooldown. Inert unless `maybe_start()` enabled it —
## Settings > Battle Mode = Real-time / Real-time (slow), solo PvE only (no PvP, co-op, team,
## puzzle, scripted or resumed battles).
##
## Also owns two small onboarding/analytics pieces layered on the same clock:
## `mentor_barks` (`MentorBarks.gd`, TID-558) — built only for an eligible new
## player (`BarkRules.is_eligible`, Maiteln + still on the `CombatOnboarding`
## ramp) — and `fight_stats` (`FightStats.gd`, TID-559), built for every
## real-time fight and read via `fight_tip()` for the victory/defeat card.
##
## A child of BattleScene (`BattleScene.realtime`), created by
## `_ensure_battle_modules()`. Reach the scene as `_battle.<name>`.
extends Node

const _SwingFx = preload("res://scenes/battle/modules/SwingFx.gd")
const _BattleScene = preload("res://scenes/battle/BattleScene.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")
const CardInstance = preload("res://game_logic/battle/CardInstance.gd")
const PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _TutorialPopup = preload("res://scenes/ui/TutorialPopup.gd")
const _RealtimeVisuals = preload("res://scenes/battle/modules/RealtimeVisuals.gd")
const CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const _CombatTuningPanel = preload("res://scenes/battle/modules/CombatTuningPanel.gd")
const _BattleOnboarding = preload("res://scenes/battle/modules/BattleOnboarding.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")
const _RealtimeTechniques = preload("res://scenes/battle/modules/RealtimeTechniques.gd")
const _MentorBarks = preload("res://scenes/battle/modules/MentorBarks.gd")
const _BarkRules = preload("res://game_logic/battle/BarkRules.gd")
const FightStats = preload("res://game_logic/battle/FightStats.gd")
const _MomentumHud = preload("res://scenes/battle/modules/MomentumHud.gd")
const PlayerCaster = preload("res://game_logic/battle/PlayerCaster.gd")
const _BattleSetup = preload("res://game_logic/battle/BattleSetup.gd")
const DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")
const _SchoolFeedback = preload("res://game_logic/battle/SchoolFeedback.gd")
## Settings key holding the tuning panel's overrides (per device).
const TUNING_SETTING: String = "combat_tuning"
## Hit feel per strength: [hit-stop seconds, shake pixels] (TID-580).
const _HIT_FEEL: Array = [[0.0, 0.0], [0.045, 2.5], [0.08, 5.0], [0.12, 8.0]]

var rt: RealtimeCombat = null
## The player's casting rules (GCD, cast bar, combo, techniques — GID-176 /
## TID-713), shared with the balance simulator; null outside real time.
var caster: PlayerCaster = null
## Technique-card presentation (Kick pulse, hand panels — GID-175).
var techniques: _RealtimeTechniques = null
## Combo pips, free-cast glow (GID-139); null outside real time.
var momentum: _MomentumHud = null
## New-player ramp + first-time tips (TID-552 / TID-553); null outside real time.
var onboarding: _BattleOnboarding = null
## Maiteln's coaching barks (GID-135 / TID-558) — only built for an eligible
## new player; null otherwise (checked, never assumed present).
var mentor_barks: _MentorBarks = null
## Per-fight stats feeding the post-fight tip (GID-135 / TID-559) — built for
## every real-time fight, not just onboarding ones.
var fight_stats: FightStats = null
var _battle: _BattleScene
var _strip: HBoxContainer = null
var _visuals: _RealtimeVisuals = null
var _enemy_tier: int = 1
## Enemy rounds elapsed, for the fight traits (GID-149).
var _enemy_rounds: int = 0
## TID-580: seconds of hit-stop left (the combat clock holds; the screen doesn't).
var _hitstop_left: float = 0.0

func _init(battle: _BattleScene) -> void:
	_battle = battle

func is_active() -> bool:
	return rt != null

## Real time applies only to plain solo PvE fights started fresh.
static func eligible(mode_setting: String, is_fresh: bool, networked: bool, puzzle: bool, scripted: bool) -> bool:
	return mode_setting.begins_with("realtime") and is_fresh and not networked and not puzzle and not scripted

func maybe_start(is_fresh: bool) -> void:
	var mode: String = SceneManager.save_manager.battle_mode()
	var networked: bool = _battle._pvp or _battle._coop_pve or _battle._team_pvp or _battle._pvp_spectating
	if not eligible(mode, is_fresh, networked, _battle._state.puzzle_mode, _battle._state.scripted_battle):
		return
	var player_level: int = SceneManager.save_manager.level
	var enemy_type: String = str(_battle.enemy_data.get("enemy_type", ""))
	var tier: int = _BattleSetup.base_tier(enemy_type)
	var saved: Variant = SceneManager.save_manager.get_setting(TUNING_SETTING, {})
	var tuning := CombatTuning.new(saved as Dictionary if saved is Dictionary else {})
	var enemy_level: int = int(_battle.enemy_data.get("enemy_level", enemy_level_for_tier(tier)))
	rt = RealtimeCombat.new(_battle._state, [player_level, enemy_level], tuning)
	# Gates, caps, opening hand and gear timers — shared with the balance sim (TID-714).
	var sm := SceneManager.save_manager
	_BattleSetup.configure_realtime(rt, player_level, enemy_type, equipped_weapon_speed(),
			offhand_damage_for_item(str(sm.equipped_offhand), sm.gear.mult(str(sm.equipped_offhand))),
			_battle._state.puzzle_mode)
	_BattleSetup.apply_deck_rules(rt, sm.learned_abilities)  # GID-185 / TID-775
	# Skill-tree card modifiers and spell crits (GID-179) — real time only.
	_BattleSetup.apply_skill_mods(_battle._state.players[RealtimeCombat.PLAYER], sm.unlocked_skills)
	caster = PlayerCaster.new(rt)
	caster.notify = _on_caster_event
	_battle._resolver.power_hook = caster.modify_power
	_enemy_tier = tier
	_apply_live_tuning()
	_build_ui()
	_visuals = _RealtimeVisuals.new(_battle)
	_visuals.build(str(_battle.enemy_data.get("enemy_type", "")), bool(_battle.enemy_data.get("is_boss", false)))
	_visuals.set_action_strip(_strip)
	onboarding = _BattleOnboarding.new(_battle, self)
	onboarding.begin(not _EnemyRegistry.is_passive(enemy_type))
	techniques = _RealtimeTechniques.new(_battle, self)
	momentum = _MomentumHud.new(_battle, self)
	momentum.build(_strip)
	fight_stats = FightStats.new()
	if _BarkRules.is_eligible(modifiers_companion(), SceneManager.save_manager.level):
		mentor_barks = _MentorBarks.new(_battle, self)
	GameBus.potion_used.connect(_on_potion_used)
	_battle._refresh_all()
	onboarding.apply()

func _on_potion_used(_potion_id: String) -> void:
	var hero := _battle._state.players[RealtimeCombat.PLAYER].hero
	if fight_stats != null: fight_stats.record_potion_used(float(hero.health) / float(maxi(1, hero.max_health)))

func _build_ui() -> void:
	var vh: float = _battle._vh
	_battle._end_turn_btn.visible = false
	_battle._turn_label.visible = false  # no turns in real time
	# One bottom action strip beside the hand (skill bar); RealtimeVisuals places it.
	# The GCD shows as a sweep on the skills + dimmed hand, the swing bar is on
	# your token and the target gets a ring, so there is no separate readout box.
	_strip = _UiUtil.make_hbox(int(vh * 0.008), _battle)
	_strip.name = "RealtimeActionStrip"
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Combat tuning panel (TID-549): top-left with pause / Effects; T on desktop.
	var tune_parent: Control = _battle.get_node("SidePanel") as Control
	_UiUtil.make_button("⚙ Tune", Vector2(vh * 0.14, vh * 0.055), int(_battle._font(0.022)), open_tuning,
			tune_parent)

## Enemy level-equivalent for mana until zone levels land (TID-536): tier 1 → 1, each tier +3.
static func enemy_level_for_tier(tier: int) -> int:
	return _BattleSetup.enemy_level_for_tier(tier)

## The clock stops while the player is reading something: pause menu, card
## inspect (long-press), the first-battle tip, or any tutorial popup.
func is_blocked() -> bool:
	if _battle._pause_ui.is_paused():
		return true
	if is_instance_valid(_battle._inspect_overlay) or is_instance_valid(_battle._tutorial_overlay):
		return true
	return not get_tree().get_nodes_in_group(_TutorialPopup.MODAL_GROUP).is_empty()

## True while the local player is on global cooldown or mid-cast (blocks plays).
func on_cooldown() -> bool:
	# Inside the spell queue window the next play is accepted (see run_cast).
	return rt != null and caster.on_cooldown()

## The equipped main-hand weapon's swing speed (0 = unarmed).
static func equipped_weapon_speed() -> float:
	return _BattleSetup.weapon_speed_for_item(SceneManager.save_manager.equipped_weapon)

## Off-hand swing damage for the given equipped offhand item id (TID-545), or
## 0 for no item / an offhand item that isn't an attack type (armor/mana
## offhand gear has no real-time swing). Pure so tests can drive it without an
## autoload. The turn-based equivalent bonus (BattleModifiers) is skipped once
## real time is active, so the two never double up.
static func offhand_damage_for_item(item_id: String, mult: float = 1.0) -> int:
	return _BattleSetup.offhand_damage_for_item(item_id, mult)

## Opens the combat tuning panel over the battle (the clock pauses while it's open).
func open_tuning() -> void:
	if rt == null or not get_tree().get_nodes_in_group(_TutorialPopup.MODAL_GROUP).is_empty():
		return
	var layer := CanvasLayer.new()
	layer.layer = 160
	_battle.add_child(layer)
	var panel := _CombatTuningPanel.new()
	panel.setup(rt.tune, save_tuning)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(panel)
	panel.closed.connect(layer.queue_free)

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if rt == null or k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_T:
		open_tuning()
		get_viewport().set_input_as_handled()

## Saves the tuning panel's overrides and applies them from the next tick.
func save_tuning() -> void:
	if rt != null:
		SceneManager.save_manager.set_setting(TUNING_SETTING, rt.tune.overrides())
		_apply_live_tuning()

## Knobs RealtimeCombat caches rather than reads each tick (base damage).
func _apply_live_tuning() -> void:
	_BattleSetup.apply_live_tuning(rt, _enemy_tier)

## A commanded Ally attack on the enemy hero interrupts its cast (WoW pet kick).
func on_ally_hit_enemy_hero(side: int = RealtimeCombat.ENEMY) -> void:
	if rt == null:
		return
	var cut: CardInstance = rt.interrupt_enemy_cast(side)
	if cut != null:
		_visuals.toast("Interrupted %s!" % cut.name)

## Called after any successful local card play. A cast's GCD already started
## when the cast began, so its resolution doesn't restart it.
func note_player_play(player_idx: int) -> void:
	if rt == null or player_idx != RealtimeCombat.PLAYER:
		return
	caster.note_play()
	if fight_stats != null: fight_stats.record_skill_use()

## Reported right after a technique card resolves (GID-175; TID-559 stats,
## TID-558 barks). `effect` "interrupt" is a real, successful Kick.
func note_skill_used(effect: String) -> void:
	if fight_stats != null:
		fight_stats.record_skill_use()
	if effect == "interrupt":
		if fight_stats != null:
			fight_stats.record_interrupt()
		if mentor_barks != null:
			mentor_barks.queue("interrupt")

## Real time: starts a visible cast for `card` (`PlayerCaster.begin`) and runs
## `finish` when it completes. Returns false in turn-based mode (rt == null) or
## while already casting, when the caller should resolve immediately. Instant
## plays still queue behind the GCD (TID-555); a unit `target` that dies
## mid-cast fizzles the spell. `cast_time` >= 0 overrides the card's own time.
func run_cast(card: CardInstance, finish: Callable, target: CardInstance = null, cast_time: float = -1.0) -> bool:
	if rt == null or not caster.begin(card, finish, target, cast_time):
		return false
	_battle._refresh_all()
	return true

## Off-GCD play (Kick, Daze — GID-175): resolves now.
func run_off_gcd(card: CardInstance, finish: Callable) -> void:
	if rt != null:
		caster.run_off_gcd(card, finish)

func is_casting() -> bool:
	return caster != null and caster.is_casting()

## Feedback from `PlayerCaster` (pure rules) → toasts, hit feel, stats, quests.
func _on_caster_event(kind: String, data: Dictionary) -> void:
	match kind:
		"combo":
			var n: int = int(data.get("n", 0))
			var free: bool = bool(data.get("free", false))
			if free:
				toast("Essence surge — cast for free!")
			else:
				toast("Combo ×%d — +%d mana" % [n, n * rt.tune.get_i("combo_refund")])
			# TID-580: the payoff lands heavier the more it was built up.
			hit_feel(3 if free or n >= rt.tune.get_i("combo_max") else 2)
		"proc":
			momentum.on_proc()
		"interrupt":
			toast("Interrupted %s!" % str(data.get("name", "")))
			note_skill_used("interrupt")
		"dazed":
			toast("Dazed!")
		"fizzled":
			toast("Target lost — spell fizzled")
			_battle._refresh_all()
		"returned":
			_battle._refresh_all()
		"crit":
			var cc := data.get("card") as CardInstance
			var extra: String = " — next cast instant" if bool(data.get("instant", false)) else ""
			toast("Critical %s!%s" % [cc.name, extra])
			hit_feel(2)
		"resolved":
			if fight_stats != null: fight_stats.record_card_damage(int(data.get("dealt", 0)))  # TID-559 tip
		"technique":
			var card := data.get("card") as CardInstance
			if card.template_id != "tech_kick":
				note_skill_used(str(data.get("effect", "")))
			SceneManager.save_manager.quests.progress_event("use_skill", TechniqueDefs.ability_for(card.template_id))

func _cast_info() -> Dictionary:
	var cs: Dictionary = caster.cast_state()
	if cs.is_empty():
		return {}
	var card := cs["card"] as CardInstance
	var cost: int = _battle._state.players[RealtimeCombat.PLAYER].effective_cost(card)
	# An instant play is shown as "queued" until it resolves on the next tick.
	if bool(cs["queued"]):
		return {"name": card.name + " (queued)", "fraction": 0.0, "cost": cost}
	return {"name": card.name, "fraction": float(cs["fraction"]), "cost": cost}

## The battle companion (Maiteln…), "" until learned (UnlockLadder feat_companion).
func modifiers_companion() -> String:
	return _battle.modifiers._active_companion()

## GID-139 / TID-580: hit feel — a brief hit-stop and a shake, scaled by how big
## the moment is (1 = a hit, 2 = a proc / combo card, 3 = a full-combo or free
## card). Both follow the Screen Shake setting.
func hit_feel(strength: int) -> void:
	if not bool(SceneManager.save_manager.get_setting("screen_shake", true)):
		return
	var f: Array = _HIT_FEEL[clampi(strength, 0, _HIT_FEEL.size() - 1)]
	_hitstop_left = maxf(_hitstop_left, float(f[0]))
	if float(f[1]) > 0.0:
		_battle._fx.trigger_shake(float(f[1]), 0.12 + 0.04 * float(strength))

## Hero token for `side` (onboarding spotlights), or null.
func token(side: int) -> Control:
	return _visuals.token(side) if _visuals != null else null

## Shows your Ally slots as locked until `level` (minions not learned yet).
func lock_ally_slots(level: int) -> void:
	if _visuals != null:
		_visuals.lock_ally_slots(level)

func unit_panel(card: CardInstance, side: int) -> Control:
	return _visuals.unit_panel(card, side) if _visuals != null else null

## False while onboarding hides the hand (the turn-based card tips don't apply yet).
func shows_card_tips() -> bool:
	return onboarding == null or onboarding.shows_hand()

func toast(text: String) -> void:
	if _visuals != null: _visuals.toast(text)

## Your hero token lunges at a unit (or enemy `side`'s token when `target` is null).
func lunge_at(target: CardInstance, side: int) -> void:
	if _visuals != null:
		_visuals.lunge_token(RealtimeCombat.PLAYER, _visuals.target_pos(target, side))

## Tap on an enemy minion with no Ally selected: focus it for the hero's auto-attack;
## tapping it again, or tapping the enemy hero (null), goes back to the hero.
func set_focus(target: CardInstance) -> void:
	if rt == null:
		return
	rt.focus_target = null if (target == null or rt.focus_target == target) else target

## Tap on an enemy hero with no Ally selected: your auto-attack goes at that
## enemy (`pidx` -1 = the first enemy).
func set_focus_enemy(pidx: int) -> void:
	if rt == null:
		return
	rt.focus_target = null
	rt.focus_enemy = pidx if pidx > RealtimeCombat.PLAYER else RealtimeCombat.ENEMY

## Screen position of enemy `pidx`'s hero (its token in real time).
func hero_screen_pos(pidx: int) -> Vector2:
	if rt == null or _visuals == null:
		return _battle._fx.pos_of_hero(true)
	return _visuals.token_center(pidx)

# ---------------------------------------------------------------------------
# Adds (TID-551): a second enemy joins the running fight
# ---------------------------------------------------------------------------

## True when another enemy can join this fight (real time, not over, room left).
func can_join() -> bool:
	return rt != null and not _battle._state.is_game_over() \
			and rt.enemy_sides().size() < RealtimeCombat.MAX_ENEMIES

## A world enemy engaged mid-fight: build its hero + deck like the first enemy
## (tier-scaled deck, boss HP), add it to the fight and give it a token and a
## row. Returns false when it can't join.
func join_enemy(enemy_data: Dictionary) -> bool:
	if not can_join():
		return false
	var etype: String = str(enemy_data.get("enemy_type", "undead_basic"))
	var is_boss: bool = bool(enemy_data.get("is_boss", false))
	var tier: int = 4 if is_boss else _BattleSetup.base_tier(etype)
	var ps := PlayerState.new(_battle._state.players.size(), true)
	var deck: Array[String] = []
	deck.assign(enemy_data.get("enemy_deck", _EnemyRegistry.get_deck(etype)))
	ps.build_deck(deck, tier)
	ps.draw_opening_hand(3)
	var bhp: int = int(enemy_data.get("boss_hp", 0))
	if is_boss and bhp > 0:
		ps.hero.health = bhp
		ps.hero.max_health = bhp
	_BattleSetup.scale_enemy_hp(ps, _EnemyRegistry.rt_hp_mult(etype))  # BID-095 per-type tuning
	var side: int = rt.add_enemy(ps, enemy_level_for_tier(tier))
	if side < 0:
		return false
	rt.unarmed[side] = rt.tune.get_i("enemy_unarmed") + maxi(0, tier - 1)
	_visuals.add_enemy_view(side, etype, is_boss, card_input_hero(side))
	_visuals.toast("%s joins the fight!" % etype.capitalize())
	onboarding.on_add(side)
	AudioManager.play_sfx("enemy_engage")
	_battle._refresh_all()
	return true

func card_input_hero(side: int) -> Callable:
	return _battle.card_input._on_enemy_hero_input.bind(side)

## Redraws the joined enemies' rows and hero strips (BattleScene._refresh_all
## only knows the first enemy's views).
func refresh_extra_views() -> void:
	if _visuals == null:
		return
	for side: Variant in _visuals.add_rows.keys():
		var i: int = int(side)
		var p: PlayerState = _battle._state.players[i]
		_battle._view.refresh_board_zone(_visuals.add_rows[side] as Node, p.board, "enemy_board")
		_battle._view.refresh_hero(_visuals.add_hero_views[side] as PanelContainer, p.hero, true, p.hand.size())

## The hero strip for enemy `side` (the scene's for the first enemy).
func hero_view_for(side: int) -> Control:
	if _visuals != null and _visuals.add_hero_views.has(side):
		return _visuals.add_hero_views[side] as Control
	return _battle._enemy_hero_view

func _process(delta: float) -> void:
	# Also hold the clock during a commanded Ally attack's lunge (`_action_busy`):
	# a swing landing mid-resolution could remove its attacker or target.
	if rt == null or _battle._state.is_game_over() or is_blocked() or _battle._action_busy:
		return
	if _hitstop_left > 0.0:
		_hitstop_left -= delta
		return
	var dt: float = delta * _speed_factor()
	techniques.pulse_reactive()
	_battle.consumables.tick_quick(dt)
	momentum.update()
	onboarding.update(dt)
	caster.tick(dt)
	if _battle._state.is_game_over():
		return
	var snap: Array[Dictionary] = _battle._fx.snapshot()
	var events: Array[Dictionary] = rt.advance(dt)
	if fight_stats != null:
		fight_stats.record_frame(dt, rt, events)
	if mentor_barks != null:
		mentor_barks.on_frame(dt, events)
	# Global cooldown: a sweep drains down the hand cards (full shade while casting).
	var gcd_frac: float = 0.0 if caster.is_casting() else rt.gcd_fraction(RealtimeCombat.PLAYER)
	_visuals.update_hand_sweep(gcd_frac)
	# Mana ticks every frame in points; the labels are cheap to update, the full
	# board refresh only runs on events (a whole cost unit, swings, casts).
	_battle._view.refresh_hero(_battle._player_hero_view, _battle._state.players[RealtimeCombat.PLAYER].hero, false)
	_battle._update_status()
	_visuals.update(rt, _cast_info())
	if events.is_empty():
		return
	var swings: Array[Dictionary] = []
	for ev: Dictionary in events:
		match str(ev.get("type", "")):
			"swing":
				swings.append(ev)
			"enemy_cast":
				_after_enemy_play(ev["card"] as CardInstance, int(ev.get("side", RealtimeCombat.ENEMY)))
			"round":
				_on_round(int(ev.get("side", -1)))
			"proc":
				momentum.on_proc()
			"enemy_down":
				if rt.enemy_sides().size() > 1 and not _battle._state.is_game_over():
					_visuals.toast("An enemy falls — keep fighting!")
			"enemy_heavy_start":
				_visuals.toast("Heavy Blow incoming — Kick it or Guard!")
			"enemy_heavy_hit":
				var heavy_dmg: int = int(ev.get("damage", 0))
				var heavy_outcome: String = str(ev.get("outcome", ""))
				_battle._fx.spawn_float_label(hero_screen_pos(RealtimeCombat.PLAYER),
						_SchoolFeedback.damage_text(-heavy_dmg, heavy_outcome),
						_SchoolFeedback.school_color(DamageSchools.PHYSICAL))
				_battle._fx.trigger_shake(10.0, 0.25)
	if not swings.is_empty():
		AudioManager.play_sfx("attack")
		_battle._fx.trigger_fx(snap)
		# Death ghosts are built synchronously from the old panels, so the
		# board can rebuild straight away without awaiting the tween.
		_battle._animate_deaths_from_snapshot(snap)
	_battle._refresh_all()
	for ev: Dictionary in swings:
		_animate_swing(ev)
		if int(ev.get("side", -1)) == RealtimeCombat.PLAYER:
			hit_feel(1)
	_battle._check_game_over()

## Lunge the attacker (hero token or enemy unit) at its target.
func _animate_swing(ev: Dictionary) -> void:
	var side: int = int(ev.get("side", 0))
	var target: CardInstance = ev.get("target") as CardInstance
	var target_side: int = int(ev.get("target_side", RealtimeCombat.PLAYER if side != RealtimeCombat.PLAYER
			else RealtimeCombat.ENEMY))
	var to: Vector2 = _visuals.target_pos(target, target_side)
	# GID-178 / TID-726: every swing lands with a slash + sparks as the lunge arrives.
	var crit: bool = bool(ev.get("crit", false))
	_SwingFx.impact(_battle._float_layer, to, _battle._vh, side == RealtimeCombat.PLAYER, 0.12, crit)
	if crit:  # TID-728: crits call themselves out and land heavier
		_battle._fx.spawn_float_label(to + Vector2(0.0, -_battle._vh * 0.06), "CRIT!",
				_SwingFx.PLAYER_HIT if side == RealtimeCombat.PLAYER else _SwingFx.ENEMY_HIT)
		hit_feel(2)
	var attacker: CardInstance = ev.get("attacker") as CardInstance
	if attacker == null:
		_visuals.lunge_token(side, to)
		return
	var panel: Control = _visuals.unit_panel(attacker, side)
	if panel != null:
		_battle._fx.animate_attack(panel, to, 1.0)

## Mirrors the post-action steps of BattleScene._execute_ai_actions.
## GID-149: fight traits tick on each enemy round.
func _on_round(side: int) -> void:
	if side == RealtimeCombat.ENEMY:
		_enemy_rounds += 1
		_battle.modifiers.apply_enemy_traits(_enemy_rounds)

func _after_enemy_play(card: CardInstance, ai_idx: int = RealtimeCombat.ENEMY) -> void:
	var snap := _battle._fx.snapshot()
	# Shared with the balance sim; a low-level enemy's spells hit softer (TID-720).
	_battle._resolver.resolve_enemy_play(card, ai_idx, RealtimeCombat.PLAYER, _BattleSetup.enemy_spell_scale(rt, ai_idx))
	if card.card_class != "spell":
		_battle.modifiers._apply_weather_to_summoned(card, ai_idx)
		GameBus.card_played.emit(card.template_id, "board", _battle._state.players[ai_idx].board.slots.find(card))
	else:
		_battle._fx.trigger_fx(snap)
		_battle._refresh_all()
		_battle._check_game_over()
		GameBus.card_played.emit(card.template_id, "spell", -1)

## Clock rate: "realtime_slow" (tactical) runs at 60 %, and the Fast battle-speed
## setting runs real time 25 % quicker. Plain inverse of `_speed_scale` would be 2.2×.
func _speed_factor() -> float:
	var mode: String = SceneManager.save_manager.battle_mode()
	if mode == "realtime_slow" or (onboarding != null and onboarding.slow_clock()):
		return 0.6
	return 1.25 if _battle._speed_scale < 1.0 else 1.0

## The one coaching line for this fight's result card, or "" — see
## `FightStats.pick_tip`. `SaveManager.realtime_fights` is already counted by
## `BattleOnboarding.begin()`; this only reads stats, no side effects.
func fight_tip() -> String:
	return FightStats.pick_tip(fight_stats.to_dict()) if fight_stats != null else ""
