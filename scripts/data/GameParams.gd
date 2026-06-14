class_name GameParams
extends Resource
## Tunable game parameters shared across Director, Player, and WaveManager.
## Edit via data/default_params.tres in the inspector.

# --- Player ---
@export_group("Player")
@export var player_speed: float = 280.0
@export var player_dash_speed: float = 720.0
@export var player_dash_duration: float = 0.18
@export var player_dash_cooldown: float = 0.9
@export var player_max_health: float = 100.0
@export var player_shoot_cooldown: float = 0.12
@export var projectile_speed: float = 900.0
@export var projectile_damage: float = 25.0
@export var projectile_lifetime: float = 1.5

# --- Director difficulty mapping ---
@export_group("Director")
@export var base_difficulty: float = 1.0
@export var min_difficulty: float = 0.5
@export var max_difficulty: float = 3.0
@export var skill_weight: float = 0.6
@export var stress_weight: float = 0.4
@export var confidence_weight: float = 0.3

# --- Waves ---
@export_group("Waves")
@export var max_waves: int = 8
@export var base_enemies_per_wave: int = 3
@export var enemies_per_wave_scaling: float = 1.2
@export var max_enemies_per_wave: int = 24
@export var spawn_stagger: float = 0.35
@export var wave_cooldown: float = 3.0

# --- Enemy base stats (scaled by Director at runtime) ---
@export_group("Enemies")
@export var drone_speed: float = 120.0
@export var drone_health: float = 40.0
@export var drone_damage: float = 10.0
@export var stalker_speed: float = 160.0
@export var stalker_health: float = 60.0
@export var phantom_speed: float = 140.0
@export var phantom_health: float = 50.0
@export var boss_speed: float = 90.0
@export var boss_health: float = 500.0
@export var boss_damage: float = 20.0
