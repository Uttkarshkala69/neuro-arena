extends Area2D
## Simple projectile used by the player (spawned at runtime).

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 25.0
var _lifetime: float = 1.5
var _source: String = "player"
var _launch_pending: bool = false
var _launch_direction: Vector2 = Vector2.RIGHT
var _launch_speed: float = 0.0
var _launch_damage: float = 25.0
var _launch_lifetime: float = 1.5
var _trail_points: Array[Vector2] = []
var _trail_color: Color = Color(1.0, 0.95, 0.4)


func _ready() -> void:
	add_to_group("projectiles")
	if has_meta("source"):
		_source = String(get_meta("source"))
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if _launch_pending:
		_begin_launch()
	queue_redraw()


func launch(direction: Vector2, speed: float, damage: float, lifetime: float) -> void:
	_launch_pending = true
	_launch_direction = direction
	_launch_speed = speed
	_launch_damage = damage
	_launch_lifetime = lifetime
	_trail_color = _get_source_color()
	if is_inside_tree():
		_begin_launch()


func _begin_launch() -> void:
	_launch_pending = false
	_velocity = _launch_direction.normalized() * _launch_speed
	_damage = _launch_damage
	_lifetime = _launch_lifetime
	var timer := get_tree().create_timer(_lifetime)
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_trail_points.push_front(Vector2.ZERO)
	if _trail_points.size() > 10:
		_trail_points.pop_back()
	queue_redraw()


func _draw() -> void:
	for i in range(_trail_points.size() - 1, -1, -1):
		var t := float(i) / maxf(float(_trail_points.size()), 1.0)
		draw_circle(_trail_points[i], lerpf(2.0, 5.0, 1.0 - t), Color(_trail_color.r, _trail_color.g, _trail_color.b, 0.08 + (1.0 - t) * 0.25))
	draw_circle(Vector2.ZERO, 7.0, Color(_trail_color.r, _trail_color.g, _trail_color.b, 0.18))
	draw_circle(Vector2.ZERO, 3.5, _trail_color)
	draw_line(Vector2.ZERO, -_velocity.normalized() * 9.0, Color(1.0, 1.0, 1.0, 0.3), 1.2)


func _get_source_color() -> Color:
	match _source:
		"boss":
			return Color(0.9, 0.3, 1.0)
		"enemy":
			return Color(1.0, 0.45, 0.25)
		_:
			return Color(0.4, 1.0, 0.95)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(_damage)
		EventBus.player_shot.emit(global_position, _velocity.normalized(), true)
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() and area.get_parent().is_in_group("enemies"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(_damage)
			EventBus.player_shot.emit(global_position, _velocity.normalized(), true)
			queue_free()
