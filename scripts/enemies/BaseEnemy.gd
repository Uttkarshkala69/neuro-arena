extends CharacterBody2D
## Base enemy behaviour shared by all archetypes.
## Subclasses override _tick_ai() for unique movement patterns.

@export var params: GameParams
@export var enemy_type: String = "drone"
@export var max_health: float = 40.0

var health: float = 40.0
var _player: Node2D = null
var _director_snapshot: Dictionary = {}
var _current_adaptation_mode: String = "Calm"
var _director_mood_cached: String = "Calm"
var _director_refresh_timer: float = 0.0
var _visual_pulse: float = 0.0

const DIRECTOR_REFRESH_INTERVAL: float = 0.25


func _enter_tree() -> void:
	_ensure_params()


func _ready() -> void:
	add_to_group("enemies")
	_ensure_params()
	health = max_health
	_find_player()
	_cache_director_snapshot()
	EventBus.director_scores_updated.connect(_on_director_updated)
	EventBus.director_mood_changed.connect(_on_director_mood_changed)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_find_player()
	_director_refresh_timer -= delta
	if _director_refresh_timer <= 0.0:
		_cache_director_snapshot()
		_director_refresh_timer = DIRECTOR_REFRESH_INTERVAL
	adaptation_update(delta)
	_tick_ai(delta)
	move_and_slide()


func _tick_ai(_delta: float) -> void:
	pass


func _find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0] as Node2D


func _ensure_params() -> void:
	if params == null:
		params = load("res://data/default_params.tres") as GameParams
	if params != null and max_health <= 0.0:
		max_health = params.drone_health


func get_player() -> Node2D:
	return _player


func get_difficulty_scale() -> float:
	if _director_snapshot.is_empty():
		_cache_director_snapshot()
	return float(_director_snapshot.get("current_difficulty", Director.get_current_difficulty()))


func get_director_mood() -> String:
	if _director_snapshot.is_empty():
		_cache_director_snapshot()
	return String(_director_snapshot.get("current_mood", Director.get_current_mood()))


func get_predictability_score() -> float:
	if _director_snapshot.is_empty():
		_cache_director_snapshot()
	return float(_director_snapshot.get("predictability_score", Director.get_predictability_score()))


func get_stress_snapshot() -> Dictionary:
	if _director_snapshot.is_empty():
		_cache_director_snapshot()
	return _director_snapshot.get("stress_snapshot", Director.get_stress_snapshot())


func adaptation_update(delta: float) -> void:
	var mood: String = get_director_mood()
	_visual_pulse = maxf(_visual_pulse - delta * 3.0, 0.0)
	if mood != _director_mood_cached:
		_director_mood_cached = mood
		_apply_mood_feedback(mood)
		EventBus.enemy_adaptation_changed.emit(enemy_type, mood)
	match mood:
		"Pressing":
			modulate = Color(1.0, 0.88, 0.72, 1.0)
		"Overclocked":
			modulate = Color(1.0, 0.62, 0.55, 1.0)
		_:
			modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _visual_pulse > 0.0:
		modulate = modulate.lerp(Color.WHITE, clampf(_visual_pulse, 0.0, 1.0) * 0.25)
	queue_redraw()


func _cache_director_snapshot() -> void:
	var previous_mood: String = String(_director_snapshot.get("current_mood", _director_mood_cached))
	_director_snapshot = {
		"current_difficulty": Director.get_current_difficulty(),
		"current_mood": Director.get_current_mood(),
		"predictability_score": Director.get_predictability_score(),
		"confidence_score": Director.confidence_score,
		"stress_snapshot": Director.get_stress_snapshot(),
	}
	var mood: String = String(_director_snapshot.get("current_mood", "Calm"))
	if mood != previous_mood:
		_director_mood_cached = mood
		EventBus.director_mood_changed.emit(mood)


func _on_director_updated(_skill: float, _stress: float, _confidence: float) -> void:
	_cache_director_snapshot()


func _on_director_mood_changed(mood: String) -> void:
	_director_snapshot["current_mood"] = mood


func _apply_mood_feedback(mood: String) -> void:
	match mood:
		"Pressing":
			_visual_pulse = 0.25
		"Overclocked":
			_visual_pulse = 0.6
		_:
			_visual_pulse = 0.0


func _set_behavior_mode(mode: String) -> void:
	if mode == _current_adaptation_mode:
		return
	_current_adaptation_mode = mode
	EventBus.enemy_behavior_mode_changed.emit(enemy_type, mode)


func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		_die()


func _die() -> void:
	EventBus.enemy_killed.emit(enemy_type, global_position)
	EventBus.screen_flash_requested.emit("enemy_death", 0.35)
	EventBus.audio_event_requested.emit("enemy_death")
	queue_free()


func _damage_player(contact_damage: float) -> void:
	if _player and _player.has_method("take_damage"):
		var dist: float = global_position.distance_to(_player.global_position)
		if dist < 24.0:
			_player.take_damage(contact_damage * get_physics_process_delta_time() * 10.0)


func _draw() -> void:
	var tint := _get_enemy_tint()
	if _visual_pulse > 0.0:
		tint = tint.lerp(Color.WHITE, clampf(_visual_pulse, 0.0, 1.0) * 0.2)
	draw_circle(Vector2.ZERO, 24.0, Color(tint.r, tint.g, tint.b, 0.08))
	draw_circle(Vector2.ZERO, 16.0, Color(tint.r, tint.g, tint.b, 0.18))
	draw_circle(Vector2.ZERO, 10.0, tint)
	draw_arc(Vector2.ZERO, 15.0 + sin(Time.get_ticks_msec() / 140.0) * 1.0, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.12), 1.1)


func _get_enemy_tint() -> Color:
	match get_director_mood():
		"Pressing":
			return Color(1.0, 0.55, 0.2)
		"Overclocked":
			return Color(1.0, 0.3, 0.2)
	return Color(0.9, 0.25, 0.3)
