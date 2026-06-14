extends CharacterBody2D
## Top-down player controller — movement, shooting, dash, and event emission.

@export var params: GameParams

@onready var muzzle: Marker2D = $Muzzle
@onready var shoot_timer: Timer = $ShootCooldown
@onready var dash_timer: Timer = $DashCooldown
@onready var glow_layer: Node = get_node_or_null("GlowLayer")
@onready var energy_ring: Node = get_node_or_null("EnergyRing")
@onready var direction_indicator: Line2D = get_node_or_null("DirectionIndicator") as Line2D

var health: float = 100.0
var current_health: float = 100.0
var max_health: float = 100.0
var _dash_remaining: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var _aim_direction: Vector2 = Vector2.RIGHT
var _spawn_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	if params == null:
		params = load("res://data/default_params.tres") as GameParams
	max_health = params.player_max_health
	current_health = max_health
	health = current_health
	_spawn_position = global_position
	shoot_timer.wait_time = params.player_shoot_cooldown
	dash_timer.wait_time = params.player_dash_cooldown
	_last_position = global_position
	_setup_visuals()
	EventBus.player_spawned.emit(self)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_aim()
	_handle_shooting()
	_handle_dash(delta)
	_emit_movement_event()
	move_and_slide()


func _draw() -> void:
	var glow := Color(0.2, 0.95, 1.0, 0.16)
	draw_circle(Vector2.ZERO, 30.0, glow)
	draw_circle(Vector2.ZERO, 20.0, Color(0.1, 0.9, 1.0, 0.24))
	draw_circle(Vector2.ZERO, 12.0, Color(0.05, 0.18, 0.25, 1.0))
	draw_arc(Vector2.ZERO, 18.0 + sin(Time.get_ticks_msec() / 180.0) * 2.0, 0.0, TAU, 48, Color(0.25, 1.0, 0.95, 0.9), 1.6)
	draw_line(Vector2.ZERO, _aim_direction * 24.0, Color(0.65, 1.0, 1.0, 0.95), 2.5)
	draw_line(Vector2.ZERO, _aim_direction.rotated(0.18) * 12.0, Color(0.65, 1.0, 1.0, 0.4), 1.2)
	draw_line(Vector2.ZERO, _aim_direction.rotated(-0.18) * 12.0, Color(0.65, 1.0, 1.0, 0.4), 1.2)


func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed: float = params.player_dash_speed if _dash_remaining > 0.0 else params.player_speed
	if _dash_remaining > 0.0:
		_dash_remaining -= delta
	velocity = input_dir * speed


func _handle_aim() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	_aim_direction = (mouse_pos - global_position).normalized()
	if _aim_direction.length_squared() > 0.001:
		rotation = _aim_direction.angle()
	queue_redraw()


func _handle_shooting() -> void:
	if Input.is_action_pressed("shoot") and shoot_timer.is_stopped():
		_fire_projectile()


func _handle_dash(delta: float) -> void:
	if Input.is_action_just_pressed("dash") and dash_timer.is_stopped() and velocity.length() > 0.0:
		var from_pos: Vector2 = global_position
		_dash_remaining = params.player_dash_duration
		dash_timer.start()
		# Immediate burst in current move direction.
		var dash_dir: Vector2 = velocity.normalized()
		global_position += dash_dir * params.player_dash_speed * params.player_dash_duration * 0.5
		EventBus.player_dashed.emit(from_pos, global_position)
		EventBus.session_event.emit("player_dash", {"from": from_pos, "to": global_position})


func _fire_projectile() -> void:
	shoot_timer.start()
	var origin: Vector2 = muzzle.global_position if muzzle else global_position
	var direction: Vector2 = _aim_direction

	var bullet := _create_projectile()
	bullet.global_position = origin
	bullet.rotation = direction.angle()
	get_tree().current_scene.add_child(bullet)

	if bullet.has_method("launch"):
		bullet.launch(direction, params.projectile_speed, params.projectile_damage, params.projectile_lifetime)

	EventBus.player_shot.emit(origin, direction, false)
	EventBus.projectile_fired.emit("player", origin)
	EventBus.audio_event_requested.emit("shoot")
	EventBus.session_event.emit("player_shot", {"origin": origin, "direction": direction})


func _create_projectile() -> Area2D:
	var bullet := Area2D.new()
	bullet.name = "PlayerBullet"
	bullet.collision_layer = 4  # layer 3: projectiles
	bullet.collision_mask = 2   # layer 2: enemies
	bullet.monitoring = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	bullet.add_child(shape)

	bullet.set_script(load("res://scripts/Projectile.gd"))
	return bullet


func _emit_movement_event() -> void:
	var dist: float = global_position.distance_to(_last_position)
	if dist > 1.0:
		EventBus.player_moved.emit(dist)
	_last_position = global_position


func take_damage(amount: float) -> void:
	current_health = maxf(current_health - amount, 0.0)
	health = current_health
	EventBus.player_hit.emit(amount, current_health)
	EventBus.screen_flash_requested.emit("hit", clampf(amount / maxf(params.player_max_health, 1.0), 0.2, 1.0))
	EventBus.audio_event_requested.emit("hit")
	EventBus.session_event.emit("player_hit", {"damage": amount, "health": current_health})
	if current_health <= 0.0:
		die()


func reset_for_run() -> void:
	max_health = params.player_max_health
	current_health = max_health
	health = current_health
	_dash_remaining = 0.0
	_last_position = _spawn_position
	_aim_direction = Vector2.RIGHT
	global_position = _spawn_position
	rotation = 0.0
	velocity = Vector2.ZERO
	shoot_timer.stop()
	dash_timer.stop()
	_setup_visuals()
	EventBus.player_spawned.emit(self)
	queue_redraw()


func _setup_visuals() -> void:
	if energy_ring and energy_ring is Line2D:
		var ring := energy_ring as Line2D
		ring.width = 2.0
		ring.default_color = Color(0.2, 0.95, 1.0, 0.85)
		ring.clear_points()
		for i in range(24):
			var angle := TAU * float(i) / 24.0
			ring.add_point(Vector2(cos(angle), sin(angle)) * 20.0)
		ring.closed = true
	if direction_indicator:
		direction_indicator.width = 2.0
		direction_indicator.default_color = Color(0.7, 1.0, 1.0, 0.9)
		direction_indicator.points = PackedVector2Array([Vector2.ZERO, _aim_direction * 28.0])


func die() -> void:
	EventBus.player_died.emit()
	queue_free()


func heal(amount: float) -> void:
	max_health = params.player_max_health
	current_health = minf(current_health + amount, max_health)
	health = current_health
	EventBus.player_healed.emit(amount, current_health)
