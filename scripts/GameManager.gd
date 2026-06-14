extends Node
## Top-level game orchestrator — wires arena systems and session lifecycle.
##
## Autoload singleton. Arena.tscn delegates run-state to this node while
## WaveManager handles spawn logic locally.

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY }

var state: GameState = GameState.PLAYING
var session_recorder: SessionRecorder
var game_params: GameParams
var _results_ui: CanvasLayer = null
var _end_screen: CanvasLayer = null

var _arena: Node2D = null
var _wave_manager: Node = null


func _ready() -> void:
	game_params = load("res://data/default_params.tres") as GameParams
	session_recorder = SessionRecorder.new()
	session_recorder.begin_session()
	_connect_events()


func _connect_events() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.arena_cleared.connect(_on_arena_cleared)
	EventBus.game_over.connect(_on_game_over)
	EventBus.session_event.connect(_on_session_event)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.enemy_killed.connect(_on_enemy_killed)


func register_arena(arena: Node2D, wave_manager: Node) -> void:
	_arena = arena
	_wave_manager = wave_manager


func start_run() -> void:
	_cleanup_run_ui()
	state = GameState.PLAYING
	get_tree().paused = false
	Director.reset()
	session_recorder.reset()
	session_recorder.begin_session()
	print("GameManager Start Run")
	if _wave_manager and _wave_manager.has_method("start_waves"):
		_wave_manager.start_waves()
	EventBus.run_restarted.emit()


func pause_run() -> void:
	if state == GameState.PLAYING:
		state = GameState.PAUSED
		get_tree().paused = true


func resume_run() -> void:
	if state == GameState.PAUSED:
		state = GameState.PLAYING
		get_tree().paused = false


func end_run(victory: bool = false) -> void:
	state = GameState.VICTORY if victory else GameState.GAME_OVER
	session_recorder.end_session(Director.get_snapshot(), victory)
	var session_path: String = session_recorder.save_session()
	_show_end_screen(victory, session_path)
	EventBus.audio_event_requested.emit("victory" if victory else "defeat")
	EventBus.game_over.emit()
	get_tree().paused = true


func _on_player_died() -> void:
	end_run(false)


func _on_arena_cleared() -> void:
	end_run(true)


func _on_game_over() -> void:
	pass


func _on_session_event(event_name: String, data: Dictionary) -> void:
	session_recorder.record_event(event_name, data)


func _on_wave_started(wave_number: int, enemy_count: int) -> void:
	session_recorder.record_event("wave_started", {
		"wave": wave_number,
		"enemy_count": enemy_count,
	})


func _on_wave_completed(wave_number: int) -> void:
	session_recorder.record_event("wave_completed", {"wave": wave_number})


func _on_enemy_killed(enemy_type: String, position: Vector2) -> void:
	session_recorder.record_event("enemy_killed", {
		"type": enemy_type,
		"position": {"x": position.x, "y": position.y},
	})


func _show_run_analysis(session_path: String) -> void:
	if _results_ui and is_instance_valid(_results_ui):
		_results_ui.queue_free()
	_results_ui = null

	var packed: PackedScene = load("res://scenes/UI/InsightCards.tscn")
	if packed == null:
		push_error("GameManager: could not load InsightCards UI")
		return

	var ui := packed.instantiate() as CanvasLayer
	if ui == null:
		return

	get_tree().current_scene.add_child(ui)
	var analysis: Dictionary = session_recorder.build_analysis()
	if ui.has_method("set_analysis"):
		ui.call("set_analysis", analysis, session_path)
	_results_ui = ui


func _show_end_screen(victory: bool, session_path: String) -> void:
	if _end_screen and is_instance_valid(_end_screen):
		_end_screen.queue_free()
	_end_screen = null

	var packed: PackedScene = load("res://scenes/UI/EndRunScreen.tscn")
	if packed == null:
		push_error("GameManager: could not load EndRunScreen UI")
		_show_run_analysis(session_path)
		return

	var ui := packed.instantiate() as CanvasLayer
	if ui == null:
		return

	get_tree().current_scene.add_child(ui)
	var analysis: Dictionary = session_recorder.build_analysis()
	if ui.has_method("set_run_summary"):
		ui.call("set_run_summary", analysis, victory, session_path)
	_end_screen = ui


func restart_run() -> void:
	_cleanup_run_ui()
	state = GameState.PLAYING
	get_tree().paused = false
	print("GameManager Restart Run")
	Director.reset()
	session_recorder.reset()
	session_recorder.begin_session()
	if _arena and is_instance_valid(_arena) and _arena.has_method("reset_run"):
		_arena.reset_run()
	elif _wave_manager and is_instance_valid(_wave_manager) and _wave_manager.has_method("reset_run"):
		_wave_manager.reset_run()
	if _wave_manager and is_instance_valid(_wave_manager) and _wave_manager.has_method("start_waves"):
		_wave_manager.start_waves()
	EventBus.run_restarted.emit()
	EventBus.audio_event_requested.emit("restart")


func _cleanup_run_ui() -> void:
	if _results_ui and is_instance_valid(_results_ui):
		_results_ui.queue_free()
	_results_ui = null
	if _end_screen and is_instance_valid(_end_screen):
		_end_screen.queue_free()
	_end_screen = null


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		activate_demo_mode()


func activate_demo_mode() -> void:
	Director.update_scores({
		"skill": 0.95,
		"stress": 0.05,
		"confidence": 0.95,
	})
	EventBus.ui_popup_requested.emit("Demo Mode Activated")
	EventBus.audio_event_requested.emit("demo_mode")
