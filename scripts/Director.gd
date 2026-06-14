extends Node
## Neuromorphic AI Director â€” adapts arena difficulty from live player telemetry.
##
## Maintains three normalized scores (0.0â€“1.0) that approximate skill, stress,
## and confidence. These drive spawn rates, enemy speed, and wave composition
## through compute_difficulty().

enum MoodState { CALM, PRESSING, OVERCLOCKED }

# Normalized player-state estimates updated each scoring tick.
var skill_score: float = 0.5
var stress_score: float = 0.0
var confidence_score: float = 0.5
var current_mood: MoodState = MoodState.CALM

var movement_entropy: float = 0.0
var predictability_score: float = 0.5
var current_stress: float = 0.0
var stress_peak: float = 0.0
var panic_score: float = 0.0

# Cached difficulty multiplier consumed by WaveManager and enemy AI.
var current_difficulty: float = 1.0

# Rolling counters reset or decay over time.
var _kills: int = 0
var _deaths: int = 0
var _shots_fired: int = 0
var _shots_hit: int = 0
var _damage_taken: float = 0.0
var _dash_count: int = 0
var _time_since_hit: float = 0.0
var _session_time: float = 0.0
var _last_dash_time: float = -999.0
var _last_player_position: Vector2 = Vector2.ZERO
var _last_move_direction: Vector2 = Vector2.ZERO
var _movement_history: Array = []
var _direction_change_count: int = 0
var _consecutive_misses: int = 0
var _near_hit_cooldown: float = 0.0
var _near_hit_count: int = 0
var _player_health_ratio: float = 1.0
var _health_pressure_bias: float = 0.0

@export var params: GameParams

const SCORE_DECAY: float = 0.02
const STRESS_SPIKE: float = 0.15
const CONFIDENCE_GAIN: float = 0.08
const POSITION_WINDOW_SECONDS: float = 10.0
const ZONE_SIZE: float = 240.0
const NEAR_HIT_DISTANCE: float = 72.0
const NEAR_HIT_COOLDOWN: float = 0.5
const RAPID_TURN_THRESHOLD: float = 0.35
const PANIC_DASH_WINDOW: float = 2.0


func _ready() -> void:
	if params == null:
		params = load("res://data/default_params.tres") as GameParams
	_connect_events()


func _process(delta: float) -> void:
	_session_time += delta
	_time_since_hit += delta
	_near_hit_cooldown = maxf(_near_hit_cooldown - delta, 0.0)
	_update_player_motion()
	_update_near_hit_pressure()
	_sync_player_health_ratio()
	_apply_health_pressure_bias()
	update_scores({})


func _connect_events() -> void:
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_shot.connect(_on_player_shot)
	EventBus.player_dashed.connect(_on_player_dashed)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_spawned.connect(_on_player_spawned)


func _on_player_hit(damage: float, _health_remaining: float) -> void:
	_damage_taken += damage
	_time_since_hit = 0.0
	stress_score = clampf(stress_score + STRESS_SPIKE, 0.0, 1.0)
	confidence_score = clampf(confidence_score - 0.1, 0.0, 1.0)


func _on_player_died() -> void:
	_deaths += 1
	stress_score = 1.0
	confidence_score = 0.0
	panic_score = 1.0
	current_stress = 1.0
	_player_health_ratio = 0.0


func _on_player_spawned(player: Node2D) -> void:
	_sync_player_health_ratio(player)


func _on_player_shot(_origin: Vector2, _direction: Vector2, hit: bool) -> void:
	_shots_fired += 1
	if hit:
		_shots_hit += 1
		_consecutive_misses = 0
	else:
		_consecutive_misses += 1
		if _consecutive_misses >= 3:
			panic_score = clampf(panic_score + 0.08, 0.0, 1.0)
			stress_score = clampf(stress_score + 0.05, 0.0, 1.0)


func _on_player_dashed(_from_pos: Vector2, _to_pos: Vector2) -> void:
	_dash_count += 1
	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	if now_sec - _last_dash_time < PANIC_DASH_WINDOW:
		panic_score = clampf(panic_score + 0.08, 0.0, 1.0)
		stress_score = clampf(stress_score + 0.05, 0.0, 1.0)
	if _time_since_hit < 2.0:
		panic_score = clampf(panic_score + 0.05, 0.0, 1.0)
		stress_score = clampf(stress_score + 0.03, 0.0, 1.0)
	_last_dash_time = now_sec


func _on_enemy_killed(_enemy_type: String, _position: Vector2) -> void:
	_kills += 1
	confidence_score = clampf(confidence_score + CONFIDENCE_GAIN, 0.0, 1.0)
	stress_score = clampf(stress_score - 0.05, 0.0, 1.0)


func _sync_player_health_ratio(player: Node2D = null) -> void:
	if player == null:
		player = _get_player_node()
	if player == null:
		return
	var current_health: float = float(player.get("current_health"))
	var max_health: float = float(player.get("max_health"))
	if max_health <= 0.0:
		max_health = 1.0
	_player_health_ratio = clampf(current_health / max_health, 0.0, 1.0)


func _apply_health_pressure_bias() -> void:
	if _player_health_ratio >= 0.8:
		_health_pressure_bias = lerpf(_health_pressure_bias, 0.08, 0.04)
		stress_score = clampf(stress_score + 0.01, 0.0, 1.0)
		confidence_score = clampf(confidence_score - 0.005, 0.0, 1.0)
	elif _player_health_ratio <= 0.25:
		_health_pressure_bias = lerpf(_health_pressure_bias, -0.08, 0.04)
		stress_score = clampf(stress_score - 0.01, 0.0, 1.0)
		confidence_score = clampf(confidence_score + 0.008, 0.0, 1.0)
	else:
		_health_pressure_bias = lerpf(_health_pressure_bias, 0.0, 0.03)


## Recompute skill, stress, and confidence from accumulated metrics.
## Pass an optional metrics Dictionary to inject one-off overrides.
func update_scores(metrics: Dictionary = {}) -> void:
	if _shots_fired > 0:
		var accuracy: float = float(_shots_hit) / float(_shots_fired)
		skill_score = lerpf(skill_score, accuracy, 0.08)
	else:
		skill_score = lerpf(skill_score, 0.5, SCORE_DECAY)

	# Sustained survival without damage raises confidence.
	if _time_since_hit > 5.0:
		confidence_score = clampf(confidence_score + 0.001, 0.0, 1.0)

	# Damage intake relative to session length approximates stress load.
	var damage_rate: float = 0.0
	if _session_time > 0.0:
		damage_rate = clampf(_damage_taken / _session_time / 20.0, 0.0, 1.0)

	current_stress = clampf(
		(damage_rate * 0.45) +
		(stress_score * 0.25) +
		(panic_score * 0.2) +
		(clampf(float(_direction_change_count) * 0.02, 0.0, 0.25)) +
		(clampf(float(_consecutive_misses) * 0.03, 0.0, 0.25)) +
		(clampf(float(_near_hit_count) * 0.04, 0.0, 0.25)),
		0.0,
		1.0
	)
	current_stress = clampf(lerpf(current_stress, stress_score, 0.15), 0.0, 1.0)
	stress_score = clampf(lerpf(stress_score, current_stress, 0.12), 0.0, 1.0)
	stress_peak = maxf(stress_peak, current_stress)
	panic_score = clampf(lerpf(panic_score, current_stress, 0.04) - 0.005, 0.0, 1.0)
	_direction_change_count = maxi(_direction_change_count - 1, 0)
	_near_hit_count = maxi(_near_hit_count - 1, 0)

	# Allow external systems to push overrides (e.g. scripted events).
	if metrics.has("skill"):
		skill_score = clampf(metrics["skill"], 0.0, 1.0)
	if metrics.has("stress"):
		stress_score = clampf(metrics["stress"], 0.0, 1.0)
	if metrics.has("confidence"):
		confidence_score = clampf(metrics["confidence"], 0.0, 1.0)

	_update_mood_state()
	compute_difficulty()
	EventBus.director_scores_updated.emit(skill_score, stress_score, confidence_score)
	EventBus.session_event.emit("director_tick", get_snapshot())


## Map neuromorphic scores to a difficulty multiplier for spawn/AI systems.
func compute_difficulty() -> float:
	var p: GameParams = params
	var base: float = p.base_difficulty
	var target: float = base
	target += skill_score * p.skill_weight
	target += confidence_score * p.confidence_weight
	target -= current_stress * p.stress_weight
	target += _health_pressure_bias

	match current_mood:
		MoodState.CALM:
			target = lerpf(target, p.base_difficulty, 0.1)
		MoodState.PRESSING:
			target += 0.15
		MoodState.OVERCLOCKED:
			target += 0.35

	target = clampf(target, p.min_difficulty, p.max_difficulty)
	current_difficulty = lerpf(current_difficulty, target, 0.08)
	current_difficulty = clampf(current_difficulty, p.min_difficulty, p.max_difficulty)
	EventBus.difficulty_changed.emit(current_difficulty)
	return current_difficulty


## Snapshot for SessionRecorder and debug UI.
func get_snapshot() -> Dictionary:
	return {
		"skill_score": skill_score,
		"stress_score": stress_score,
		"confidence_score": confidence_score,
		"current_stress": current_stress,
		"stress_peak": stress_peak,
		"panic_score": panic_score,
		"movement_entropy": movement_entropy,
		"predictability_score": predictability_score,
		"current_mood": get_current_mood(),
		"current_difficulty": current_difficulty,
		"kills": _kills,
		"deaths": _deaths,
		"shots_fired": _shots_fired,
		"shots_hit": _shots_hit,
		"damage_taken": _damage_taken,
		"dash_count": _dash_count,
		"session_time": _session_time,
	}


## Reset director state for a new run.
func reset() -> void:
	skill_score = 0.5
	stress_score = 0.0
	confidence_score = 0.5
	current_mood = MoodState.CALM
	movement_entropy = 0.0
	predictability_score = 0.5
	current_stress = 0.0
	stress_peak = 0.0
	panic_score = 0.0
	current_difficulty = 1.0
	_kills = 0
	_deaths = 0
	_shots_fired = 0
	_shots_hit = 0
	_damage_taken = 0.0
	_dash_count = 0
	_time_since_hit = 0.0
	_session_time = 0.0
	_last_dash_time = -999.0
	_last_player_position = Vector2.ZERO
	_last_move_direction = Vector2.ZERO
	_movement_history.clear()
	_direction_change_count = 0
	_consecutive_misses = 0
	_near_hit_cooldown = 0.0
	_near_hit_count = 0
	_player_health_ratio = 1.0
	_health_pressure_bias = 0.0


func get_current_difficulty() -> float:
	return current_difficulty


func get_current_mood() -> String:
	match current_mood:
		MoodState.CALM:
			return "Calm"
		MoodState.PRESSING:
			return "Pressing"
		MoodState.OVERCLOCKED:
			return "Overclocked"
	return "Calm"


func get_predictability_score() -> float:
	return predictability_score


func get_stress_snapshot() -> Dictionary:
	return {
		"current_stress": current_stress,
		"stress_peak": stress_peak,
		"panic_score": panic_score,
		"stress_score": stress_score,
	}


func _get_player_node() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D


func _update_player_motion() -> void:
	var player: Node2D = _get_player_node()
	if player == null:
		return

	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var position: Vector2 = player.global_position
	_movement_history.append({"t": now_sec, "pos": position})

	if _last_player_position != Vector2.ZERO:
		var delta_pos: Vector2 = position - _last_player_position
		if delta_pos.length() > 1.0:
			var direction: Vector2 = delta_pos.normalized()
			if _last_move_direction != Vector2.ZERO and direction.dot(_last_move_direction) < 0.15 and delta_pos.length() > 16.0:
				_direction_change_count += 1
				if now_sec - _last_dash_time < RAPID_TURN_THRESHOLD:
					panic_score = clampf(panic_score + 0.03, 0.0, 1.0)
			_last_move_direction = direction

	_last_player_position = position

	while not _movement_history.is_empty() and now_sec - float(_movement_history[0]["t"]) > POSITION_WINDOW_SECONDS:
		_movement_history.pop_front()

	if _movement_history.is_empty():
		movement_entropy = 0.0
		predictability_score = 0.5
		return

	var zone_counts: Dictionary = {}
	for sample in _movement_history:
		var pos: Vector2 = sample["pos"]
		var zone_key: Vector2i = Vector2i(floori(pos.x / ZONE_SIZE), floori(pos.y / ZONE_SIZE))
		zone_counts[zone_key] = int(zone_counts.get(zone_key, 0)) + 1

	var total: float = float(_movement_history.size())
	var entropy_sum: float = 0.0
	for count in zone_counts.values():
		var p: float = float(count) / total
		entropy_sum -= p * log(p)

	var max_entropy: float = log(maxf(1.0, float(zone_counts.size())))
	movement_entropy = 0.0 if max_entropy <= 0.0 else clampf(entropy_sum / max_entropy, 0.0, 1.0)

	var loop_hits: int = 0
	if _movement_history.size() >= 6:
		for i in range(3, _movement_history.size()):
			var current_zone: Vector2i = Vector2i(floori(float(_movement_history[i]["pos"].x) / ZONE_SIZE), floori(float(_movement_history[i]["pos"].y) / ZONE_SIZE))
			for j in range(max(0, i - 6), i - 1):
				var previous_zone: Vector2i = Vector2i(floori(float(_movement_history[j]["pos"].x) / ZONE_SIZE), floori(float(_movement_history[j]["pos"].y) / ZONE_SIZE))
				if current_zone == previous_zone:
					loop_hits += 1
					break

	var loop_factor: float = clampf(float(loop_hits) / maxf(1.0, float(_movement_history.size()) * 0.3), 0.0, 1.0)
	predictability_score = clampf((1.0 - movement_entropy) * 0.65 + loop_factor * 0.2 + clampf(float(_direction_change_count) * 0.02, 0.0, 0.15), 0.0, 1.0)


func _update_near_hit_pressure() -> void:
	var player: Node2D = _get_player_node()
	if player == null:
		return

	var closest_distance: float = 99999.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node2D:
			var distance: float = (enemy as Node2D).global_position.distance_to(player.global_position)
			closest_distance = minf(closest_distance, distance)

	if closest_distance <= NEAR_HIT_DISTANCE and _near_hit_cooldown <= 0.0:
		_near_hit_count += 1
		current_stress = clampf(current_stress + 0.08, 0.0, 1.0)
		panic_score = clampf(panic_score + 0.05, 0.0, 1.0)
		_near_hit_cooldown = NEAR_HIT_COOLDOWN


func _update_mood_state() -> void:
	var difficulty_norm: float = 0.0
	if params.max_difficulty > params.min_difficulty:
		difficulty_norm = inverse_lerp(params.min_difficulty, params.max_difficulty, current_difficulty)

	var pressure: float = clampf((current_stress * 0.55) + (difficulty_norm * 0.25) - (confidence_score * 0.2), 0.0, 1.0)
	if pressure < 0.34 and confidence_score > 0.55 and stress_peak < 0.65:
		current_mood = MoodState.CALM
	elif pressure < 0.72 and skill_score > 0.45:
		current_mood = MoodState.PRESSING
	else:
		current_mood = MoodState.OVERCLOCKED
