extends "res://scripts/enemies/BaseEnemy.gd"
## Stalker — flanking chase; pauses briefly when player dashes (reads stress via difficulty).

var _pause_timer: float = 0.0
var _last_player_position: Vector2 = Vector2.ZERO
var _last_player_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	enemy_type = "stalker"
	max_health = params.stalker_health
	super._ready()
	EventBus.player_dashed.connect(_on_player_dashed)


func _on_player_dashed(_from_pos: Vector2, _to_pos: Vector2) -> void:
	# Higher difficulty (skilled player) → shorter pause.
	_pause_timer = lerpf(0.6, 0.15, Director.skill_score)


func _tick_ai(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	if _pause_timer > 0.0:
		_pause_timer -= delta
		velocity = Vector2.ZERO
		return

	var diff: float = get_difficulty_scale()
	var to_player: Vector2 = _player.global_position - global_position
	var predictability: float = get_predictability_score()
	var speed: float = params.stalker_speed * lerpf(0.9, 1.4, diff / Director.params.max_difficulty)
	var target: Vector2
	var current_position: Vector2 = _player.global_position

	if predictability > 0.6:
		_set_behavior_mode("intercept_cutoff")
		var player_velocity: Vector2 = Vector2.ZERO
		if _last_player_position != Vector2.ZERO:
			player_velocity = (current_position - _last_player_position) / maxf(delta, 0.001)
		_last_player_direction = player_velocity.normalized() if player_velocity.length_squared() > 1.0 else _last_player_direction
		var lead_distance: float = lerpf(80.0, 180.0, predictability)
		target = current_position + _last_player_direction * lead_distance
		if _last_player_direction == Vector2.ZERO:
			target = current_position + to_player.normalized() * 90.0
	else:
		_set_behavior_mode("flank_pressure")
		var flank: Vector2 = to_player.normalized().rotated(PI * 0.5 * sign(to_player.x))
		target = current_position + flank * 60.0

	_last_player_position = current_position

	var direction: Vector2 = (target - global_position).normalized()

	velocity = direction * speed
	_damage_player(params.drone_damage)

	if velocity.length_squared() > 0.001:
		rotation = velocity.angle()


func _draw() -> void:
	var tint := Color(1.0, 0.55, 0.15)
	draw_circle(Vector2.ZERO, 26.0, Color(1.0, 0.45, 0.05, 0.1))
	draw_circle(Vector2.ZERO, 17.0, Color(1.0, 0.55, 0.1, 0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -16),
		Vector2(15, 0),
		Vector2(0, 16),
		Vector2(-15, 0),
	]), tint)
	draw_polyline(PackedVector2Array([
		Vector2(0, -16),
		Vector2(15, 0),
		Vector2(0, 16),
		Vector2(-15, 0),
		Vector2(0, -16),
	]), Color(1.0, 0.85, 0.6, 0.9), 1.6, true)
