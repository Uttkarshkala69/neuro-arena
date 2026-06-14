extends Node
## Global event bus for decoupled, event-driven gameplay communication.
##
## All systems emit and listen through this singleton rather than holding
## direct references to each other. Keeps the neuromorphic Director and
## session recorder loosely coupled from combat logic.

# --- Player lifecycle ---
signal player_spawned(player: Node2D)
signal player_hit(damage: float, health_remaining: float)
signal player_died
signal player_healed(amount: float, health_remaining: float)

# --- Player actions (fed into Director metrics) ---
signal player_shot(origin: Vector2, direction: Vector2, hit: bool)
signal player_dashed(from_pos: Vector2, to_pos: Vector2)
signal player_moved(distance: float)

# --- Combat outcomes ---
signal enemy_spawned(enemy: Node2D, enemy_type: String)
signal enemy_killed(enemy_type: String, position: Vector2)
signal projectile_fired(source: String, origin: Vector2)

# --- Wave / session flow ---
signal wave_started(wave_number: int, enemy_count: int)
signal wave_completed(wave_number: int)
signal arena_cleared
signal game_over
signal run_restarted

# --- Director feedback loop ---
signal difficulty_changed(difficulty: float)
signal director_scores_updated(skill: float, stress: float, confidence: float)
signal director_mood_changed(mood: String)

# --- Generic telemetry hook for SessionRecorder ---
signal session_event(event_name: String, data: Dictionary)

# --- Enemy adaptation ---
signal enemy_adaptation_changed(enemy_type: String, mode: String)
signal enemy_behavior_mode_changed(enemy_type: String, mode: String)

# --- Boss adaptation ---
signal boss_spawned(boss: Node2D, boss_name: String, current_health: float, max_health: float)
signal boss_health_changed(boss_name: String, current_health: float, max_health: float)
signal boss_died(boss_name: String)
signal boss_phase_changed(phase: String)
signal boss_adapted(phase: String, reason: String)
signal boss_prediction_attack(target: Vector2)

# --- Presentation / feedback ---
signal ui_popup_requested(message: String)
signal screen_flash_requested(kind: String, strength: float)
signal audio_event_requested(event_name: String)
