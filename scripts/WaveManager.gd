extends Node
## Spawns enemy waves scaled by the neuromorphic Director's difficulty.

@export var spawn_points: Array[NodePath] = []
@export var params: GameParams

var current_wave: int = 0
var _enemies_alive: int = 0
var _wave_active: bool = false
var _spawn_parent: Node2D = null
var _run_generation: int = 0

const ENEMY_SCENES: Dictionary = {
	"drone": "res://scenes/enemies/Drone.tscn",
	"stalker": "res://scenes/enemies/Stalker.tscn",
	"phantom": "res://scenes/enemies/Phantom.tscn",
	"nexus_boss": "res://scenes/enemies/NexusBoss.tscn",
}


func _ready() -> void:
	if params == null:
		params = load("res://data/default_params.tres") as GameParams
	EventBus.enemy_killed.connect(_on_enemy_killed)


func setup(spawn_parent: Node2D, points: Array[Node2D]) -> void:
	_spawn_parent = spawn_parent
	spawn_points.clear()
	for point in points:
		spawn_points.append(point.get_path())


func start_waves() -> void:
	_run_generation += 1
	current_wave = 0
	print("WaveManager Start Waves")
	_start_next_wave()


func reset_run() -> void:
	_run_generation += 1
	current_wave = 0
	_enemies_alive = 0
	_wave_active = false


func _start_next_wave() -> void:
	current_wave += 1
	if current_wave > params.max_waves:
		EventBus.arena_cleared.emit()
		return

	var composition: Array = _build_wave_composition(current_wave)
	_enemies_alive = composition.size()
	_wave_active = true
	EventBus.wave_started.emit(current_wave, _enemies_alive)

	for entry in composition:
		_spawn_enemy(entry["type"], entry.get("delay", 0.0))


func _build_wave_composition(wave: int) -> Array:
	var diff: float = Director.get_current_difficulty()
	var count: int = int(params.base_enemies_per_wave + wave * params.enemies_per_wave_scaling * diff)
	count = clampi(count, 1, params.max_enemies_per_wave)

	var composition: Array = []
	for i in count:
		var enemy_type: String = "drone"
		if wave >= 3 and i % 4 == 0:
			enemy_type = "stalker"
		if wave >= 5 and i % 6 == 0:
			enemy_type = "phantom"
		if wave == params.max_waves and i == count - 1:
			enemy_type = "nexus_boss"
		composition.append({"type": enemy_type, "delay": float(i) * params.spawn_stagger})

	return composition


func _spawn_enemy(enemy_type: String, delay: float) -> void:
	var generation := _run_generation
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		if generation != _run_generation:
			return
		if not is_instance_valid(_spawn_parent):
			return
		var scene_path: String = ENEMY_SCENES.get(enemy_type, ENEMY_SCENES["drone"])
		var packed: PackedScene = load(scene_path)
		if packed == null:
			push_error("WaveManager: failed to load %s" % scene_path)
			return
		var enemy: Node2D = packed.instantiate()
		enemy.global_position = _pick_spawn_position()
		print("Spawn Enemy: %s" % enemy_type)
		_spawn_parent.add_child(enemy)
		EventBus.enemy_spawned.emit(enemy, enemy_type)
	)


func _pick_spawn_position() -> Vector2:
	if spawn_points.is_empty():
		return Vector2(randf_range(-400, 400), randf_range(-300, 300))

	var path: NodePath = spawn_points[randi() % spawn_points.size()]
	var marker: Node2D = get_node_or_null(path) as Node2D
	if marker:
		return marker.global_position
	return Vector2.ZERO


func _on_enemy_killed(_enemy_type: String, _position: Vector2) -> void:
	if not _wave_active:
		return
	_enemies_alive -= 1
	if _enemies_alive <= 0:
		_wave_active = false
		EventBus.wave_completed.emit(current_wave)
		var timer := get_tree().create_timer(params.wave_cooldown)
		timer.timeout.connect(_start_next_wave)
