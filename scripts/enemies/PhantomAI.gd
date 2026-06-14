extends "res://scripts/enemies/BaseEnemy.gd"
## Phantom — alternates between visible chase and brief teleport repositioning.

enum Phase { CHASE, TELEPORT }

var _phase: Phase = Phase.CHASE
var _phase_timer: float = 0.0
var _teleport_cooldown: float = 2.5
var _blink_bias: float = 1.0


func _ready() -> void:
	enemy_type = "phantom"
	max_health = params.phantom_health
	super._ready()
	_phase_timer = 1.5


func _tick_ai(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	_phase_timer -= delta
	var diff: float = get_difficulty_scale()
	var confidence: float = float(_director_snapshot.get("confidence_score", Director.confidence_score))
	# Skilled players face faster phase cycles.
	_teleport_cooldown = lerpf(3.0, 1.2, Director.skill_score)
	_teleport_cooldown = lerpf(_teleport_cooldown, 1.0, confidence)
	_blink_bias = lerpf(1.25, 0.75, confidence)

	match _phase:
		Phase.CHASE:
			_chase(delta, diff, confidence)
			if _phase_timer <= 0.0:
				_phase = Phase.TELEPORT
				_phase_timer = lerpf(0.35, 0.18, confidence)
		Phase.TELEPORT:
			modulate.a = 0.3
			if _phase_timer <= 0.0:
				_teleport_near_player()
				_phase = Phase.CHASE
				_phase_timer = (_teleport_cooldown / maxf(diff, 0.25)) * _blink_bias
				modulate.a = 1.0
	queue_redraw()


func _chase(_delta: float, diff: float, confidence: float) -> void:
	_set_behavior_mode("blink_hunt")
	var speed: float = params.phantom_speed * lerpf(0.85, 1.35, diff / Director.params.max_difficulty)
	speed *= lerpf(0.88, 1.15, confidence)
	var direction: Vector2 = (_player.global_position - global_position).normalized()
	var chase_offset: Vector2 = Vector2.ZERO
	if confidence > 0.65:
		chase_offset = direction * lerpf(10.0, 36.0, confidence)
	velocity = (direction * speed) + chase_offset
	_damage_player(params.drone_damage)
	if velocity.length_squared() > 0.001:
		rotation = velocity.angle()


func _teleport_near_player() -> void:
	if not is_instance_valid(_player):
		return
	var confidence: float = float(_director_snapshot.get("confidence_score", Director.confidence_score))
	var range_min: float = lerpf(120.0, 60.0, confidence)
	var offset: Vector2 = Vector2(randf_range(-range_min, range_min), randf_range(-range_min, range_min))
	global_position = _player.global_position + offset


func _draw() -> void:
	var alpha := modulate.a
	draw_circle(Vector2.ZERO, 28.0, Color(0.72, 0.25, 1.0, 0.06 * alpha))
	draw_circle(Vector2.ZERO, 18.0, Color(0.75, 0.2, 1.0, 0.15 * alpha))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -15),
		Vector2(12, -2),
		Vector2(8, 15),
		Vector2(-8, 15),
		Vector2(-12, -2),
	]), Color(0.55, 0.15, 0.85, 0.9 * alpha))
	draw_line(Vector2(-8, 0), Vector2(8, 0), Color(1.0, 1.0, 1.0, 0.18 * alpha), 1.2)
