extends "res://scripts/enemies/BaseEnemy.gd"
## Drone — basic chase enemy whose speed scales with Director difficulty.

func _ready() -> void:
	enemy_type = "drone"
	max_health = params.drone_health
	super._ready()


func _tick_ai(_delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var diff: float = get_difficulty_scale()
	var mood: String = get_director_mood()
	var speed_multiplier: float = lerpf(0.8, 1.5, diff / Director.params.max_difficulty)
	match mood:
		"Pressing":
			speed_multiplier *= 1.18
			_set_behavior_mode("aggressive_pursuit")
		"Overclocked":
			speed_multiplier *= 1.38
			_set_behavior_mode("overclocked_pursuit")
		_:
			_set_behavior_mode("normal_chase")
	var speed: float = params.drone_speed * speed_multiplier
	var direction: Vector2 = (_player.global_position - global_position).normalized()
	velocity = direction * speed
	_damage_player(params.drone_damage)

	if velocity.length_squared() > 0.001:
		rotation = velocity.angle()

	queue_redraw()


func _draw() -> void:
	var tint := Color(1.0, 0.25, 0.2)
	draw_circle(Vector2.ZERO, 23.0, Color(1.0, 0.2, 0.15, 0.1))
	draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.3, 0.25, 0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -14),
		Vector2(13, 10),
		Vector2(0, 6),
		Vector2(-13, 10),
	]), tint)
	draw_polyline(PackedVector2Array([
		Vector2(0, -14),
		Vector2(13, 10),
		Vector2(0, 6),
		Vector2(-13, 10),
		Vector2(0, -14),
	]), Color(1.0, 0.65, 0.55, 0.9), 1.6, true)
