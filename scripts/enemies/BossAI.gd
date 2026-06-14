extends "res://scripts/enemies/BaseEnemy.gd"
## Nexus Boss – adaptive neuromorphic boss driven by Director intelligence.
## Visual redesign: Valorant-inspired cyberpunk, esports-grade readability.

enum BossPhase { REACTION_AUDITOR, PATH_LIBRARIAN, PULSE_WARDEN, OVERCLOCKED }

# ── Adaptive logic state (unchanged) ──────────────────────────────────────────
var _boss_phase: BossPhase = BossPhase.REACTION_AUDITOR
var _phase_timer: float = 0.0
var _attack_timer: float = 0.0
var _burst_count: int = 0
var _movement_anchor: Vector2 = Vector2.ZERO
var _prediction_anchor: Vector2 = Vector2.ZERO
var _aura_pulse: float = 0.0
var _phase_reason: String = ""
var _last_player_position: Vector2 = Vector2.ZERO

# ── Phase name constants (unchanged) ──────────────────────────────────────────
const PHASE_REACTION_AUDITOR := "reaction_auditor"
const PHASE_PATH_LIBRARIAN    := "path_librarian"
const PHASE_PULSE_WARDEN      := "pulse_warden"
const PHASE_OVERCLOCKED       := "overclocked"

# ── Visual system state ────────────────────────────────────────────────────────
## Ring angles driven by _physics_process; two rings, opposite rotation speeds.
var _ring_angle_a: float = 0.0
var _ring_angle_b: float = 0.0
## Pulse animation: 0→1 sinusoidal breath, reset on phase entry.
var _core_pulse: float = 0.0
## Flash overlay: 1.0 = fully white, decays to 0.
var _flash_alpha: float = 0.0
## Banner timer: > 0 means banner is visible.
var _banner_timer: float = 0.0
const BANNER_DURATION := 1.8
## Per-frame animation time accumulator.
var _anim_time: float = 0.0

# ── Scene refs ─────────────────────────────────────────────────────────────────
var _phase_label: Label = null          # legacy HUD compat (hidden)
var _banner_label: Label = null         # PhaseBanner/BannerLabel
var _phase_banner: Control = null       # PhaseBanner root
var _attack_warning_layer: Node2D = null

# ── Phase colour palette (Valorant-inspired) ───────────────────────────────────
## Reaction Auditor  → Cyan    #00F5FF
## Path Librarian    → Orange  #FF8C00
## Pulse Warden      → Green   #39FF14
## Overclocked       → Red/Pur #CC00FF / #FF003C
const PHASE_COLORS := {
	BossPhase.REACTION_AUDITOR: Color(0.00, 0.96, 1.00, 1.0),   # cyan
	BossPhase.PATH_LIBRARIAN:   Color(1.00, 0.55, 0.00, 1.0),   # orange
	BossPhase.PULSE_WARDEN:     Color(0.22, 1.00, 0.08, 1.0),   # neon green
	BossPhase.OVERCLOCKED:      Color(0.80, 0.00, 1.00, 1.0),   # purple-red mix
}

# Overclocked has a secondary accent that pulses between purple and red.
const OVERCLOCK_RED  := Color(1.00, 0.00, 0.24, 1.0)
const OVERCLOCK_PURP := Color(0.80, 0.00, 1.00, 1.0)

# Ring sizes
const RING_OUTER := 54.0
const RING_MID   := 40.0
const RING_INNER := 28.0
const CORE_RADIUS := 18.0

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	enemy_type = "nexus_boss"
	max_health = params.boss_health
	super._ready()
	scale = Vector2(2.0, 2.0)
	_phase_timer  = 1.0
	_attack_timer = 0.0
	_cache_scene_refs()
	EventBus.boss_spawned.emit(self, _get_boss_display_name(), health, max_health)
	_update_phase_from_director(true)


func _cache_scene_refs() -> void:
	_phase_label          = get_node_or_null("PhaseLabel") as Label
	_phase_banner         = get_node_or_null("PhaseBanner") as Control
	_banner_label         = get_node_or_null("PhaseBanner/BannerLabel") as Label
	_attack_warning_layer = get_node_or_null("AttackWarningLayer") as Node2D
	if _phase_banner:
		_phase_banner.visible = false


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_phase_from_director(false)
	_update_visuals(delta)


# ─────────────────────────────────────────────────────────────────────────────
# Core AI (unchanged logic)
# ─────────────────────────────────────────────────────────────────────────────

func _tick_ai(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	_attack_timer -= delta
	_phase_timer  -= delta

	var diff: float        = get_difficulty_scale()
	var mood: String       = get_director_mood()
	var predictability: float = get_predictability_score()
	var confidence: float  = float(_director_snapshot.get("confidence_score", Director.confidence_score))
	var stress_snapshot: Dictionary = get_stress_snapshot()
	var current_stress: float = float(stress_snapshot.get("current_stress", Director.current_stress))

	if _phase_timer <= 0.0:
		_update_phase_from_director(false)

	match _boss_phase:
		BossPhase.REACTION_AUDITOR:
			_reaction_auditor(delta, diff, confidence, mood)
		BossPhase.PATH_LIBRARIAN:
			_path_librarian(delta, diff, predictability)
		BossPhase.PULSE_WARDEN:
			_pulse_warden(delta, diff, current_stress)
		BossPhase.OVERCLOCKED:
			_overclocked(delta, diff, confidence, predictability)

	_damage_player(params.boss_damage)


func _update_phase_from_director(force_emit: bool) -> void:
	var skill: float        = Director.skill_score
	var stress: float       = float(_director_snapshot.get("current_stress", Director.current_stress))
	var confidence: float   = float(_director_snapshot.get("confidence_score", Director.confidence_score))
	var predictability: float = get_predictability_score()
	var target_phase: BossPhase = _boss_phase
	var reason: String      = _phase_reason

	if confidence >= 0.78 and stress <= 0.28:
		target_phase = BossPhase.OVERCLOCKED
		reason       = "Player dominating"
		_phase_timer = 2.0
	elif stress >= 0.7:
		target_phase = BossPhase.PULSE_WARDEN
		reason       = "Player overloaded"
		_phase_timer = 2.5
	elif predictability >= 0.6:
		target_phase = BossPhase.PATH_LIBRARIAN
		reason       = "Player follows habits"
		_phase_timer = 2.25
	elif skill >= 0.62:
		target_phase = BossPhase.REACTION_AUDITOR
		reason       = "Player reacts quickly"
		_phase_timer = 2.0
	else:
		target_phase = BossPhase.REACTION_AUDITOR
		reason       = "Player reacts quickly"
		_phase_timer = 1.75

	if force_emit or target_phase != _boss_phase or reason != _phase_reason:
		_boss_phase   = target_phase
		_phase_reason = reason
		_apply_phase_enter(target_phase)
		EventBus.boss_phase_changed.emit(_get_phase_name(target_phase))
		EventBus.boss_adapted.emit(_get_phase_name(target_phase), reason)
		EventBus.ui_popup_requested.emit("%s" % reason)
		EventBus.screen_flash_requested.emit("boss_phase", 0.5 if target_phase != BossPhase.PULSE_WARDEN else 0.35)
		EventBus.audio_event_requested.emit("boss_phase_change")
		EventBus.session_event.emit("boss_adapted", {
			"phase":  _get_phase_name(target_phase),
			"reason": reason,
		})
		queue_redraw()


func _apply_phase_enter(phase: BossPhase) -> void:
	# ── Visual: flash + banner ─────────────────────────────────────────────
	_flash_alpha  = 1.0          # white flash, decays in _update_visuals
	_core_pulse   = 0.0          # restart breath animation
	_banner_timer = BANNER_DURATION
	_show_phase_banner(phase)

	# ── Original gameplay state (unchanged) ───────────────────────────────
	match phase:
		BossPhase.REACTION_AUDITOR:
			_burst_count  = 0
			_attack_timer = 0.0
			_aura_pulse   = 0.15
		BossPhase.PATH_LIBRARIAN:
			_burst_count  = 3
			_attack_timer = 0.0
			_movement_anchor   = _player.global_position if is_instance_valid(_player) else global_position
			_prediction_anchor = _movement_anchor
			_aura_pulse        = 0.25
		BossPhase.PULSE_WARDEN:
			_burst_count  = 0
			_attack_timer = 0.0
			_aura_pulse   = 0.1
		BossPhase.OVERCLOCKED:
			_burst_count  = 0
			_attack_timer = 0.0
			_aura_pulse   = 0.55
			EventBus.audio_event_requested.emit("boss_overclocked")


func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if health > 0.0:
		EventBus.boss_health_changed.emit(_get_boss_display_name(), health, max_health)

# ─────────────────────────────────────────────────────────────────────────────
# Phase behaviours (logic unchanged, aura colours updated to new palette)
# ─────────────────────────────────────────────────────────────────────────────

func _reaction_auditor(_delta: float, diff: float, confidence: float, mood: String) -> void:
	_set_behavior_mode("reaction_auditor")
	var speed: float     = params.boss_speed * lerpf(0.8, 1.35, diff / Director.params.max_difficulty)
	var telegraph: float = lerpf(1.0, 0.35, Director.skill_score)
	_phase_timer = minf(_phase_timer, telegraph)
	var direction: Vector2 = (_player.global_position - global_position).normalized()
	velocity = direction * speed
	if _attack_timer <= 0.0:
		_fire_precision_attack(confidence)
		_attack_timer = lerpf(1.2, 0.55, Director.skill_score)
	_apply_aura_from_phase(PHASE_COLORS[BossPhase.REACTION_AUDITOR])
	_apply_precision_look(mood)


func _path_librarian(_delta: float, diff: float, predictability: float) -> void:
	_set_behavior_mode("path_librarian")
	var speed: float = params.boss_speed * lerpf(0.7, 1.15, diff / Director.params.max_difficulty)
	var player_velocity: Vector2 = Vector2.ZERO
	if _last_player_position != Vector2.ZERO:
		player_velocity = (_player.global_position - _last_player_position).normalized()
	_last_player_position = _player.global_position
	if player_velocity == Vector2.ZERO:
		player_velocity = (_player.global_position - global_position).normalized()
	_prediction_anchor = _player.global_position + player_velocity * lerpf(120.0, 240.0, predictability)
	velocity = (_prediction_anchor - global_position).normalized() * speed
	if _attack_timer <= 0.0:
		_fire_prediction_attack(_prediction_anchor, predictability)
		_spawn_intercept_attack(_prediction_anchor, predictability)
		_attack_timer = lerpf(1.35, 0.7, predictability)
	_apply_aura_from_phase(PHASE_COLORS[BossPhase.PATH_LIBRARIAN])


func _pulse_warden(_delta: float, diff: float, current_stress: float) -> void:
	_set_behavior_mode("pulse_warden")
	var speed: float = params.boss_speed * lerpf(0.55, 0.85, diff / Director.params.max_difficulty)
	var retreat_point: Vector2 = _player.global_position + (_player.global_position - global_position).normalized() * lerpf(180.0, 260.0, current_stress)
	velocity = (retreat_point - global_position).normalized() * speed
	if _attack_timer <= 0.0:
		_attack_timer = lerpf(1.8, 1.1, current_stress)
		_phase_timer  = maxf(_phase_timer, 1.4)
	_apply_aura_from_phase(PHASE_COLORS[BossPhase.PULSE_WARDEN])


func _overclocked(_delta: float, diff: float, confidence: float, predictability: float) -> void:
	_set_behavior_mode("overclocked")
	var speed: float = params.boss_speed * lerpf(1.35, 2.1, diff / Director.params.max_difficulty)
	var direction: Vector2 = (_player.global_position - global_position).normalized()
	var pulse_phase: float = sin(Time.get_ticks_msec() / 90.0)
	velocity = direction * speed + direction.orthogonal() * pulse_phase * 120.0
	_aura_pulse = 0.75 + abs(pulse_phase) * 0.25
	if _attack_timer <= 0.0:
		_fire_precision_attack(confidence)
		_fire_prediction_attack(_player.global_position + direction * lerpf(50.0, 120.0, predictability), predictability)
		_spawn_multi_pattern_attack(confidence, predictability)
		_attack_timer = lerpf(0.65, 0.35, confidence)

# ─────────────────────────────────────────────────────────────────────────────
# Attack methods (gameplay unchanged, telegraph visuals added)
# ─────────────────────────────────────────────────────────────────────────────

func _fire_precision_attack(confidence: float) -> void:
	if not is_instance_valid(_player):
		return
	var origin:    Vector2 = global_position
	var direction: Vector2 = (_player.global_position - origin).normalized()
	var speed:     float   = lerpf(820.0, 1120.0, confidence)
	_show_attack_telegraph(origin, direction, lerpf(0.22, 0.1, confidence), PHASE_COLORS[BossPhase.REACTION_AUDITOR])
	_spawn_projectile(origin, direction, speed, lerpf(20.0, 30.0, confidence), lerpf(1.6, 2.2, confidence), "precision")
	_reduce_telegraph(confidence)


func _fire_prediction_attack(target: Vector2, predictability: float) -> void:
	if not is_instance_valid(_player):
		return
	var origin:    Vector2 = global_position
	var direction: Vector2 = (target - origin).normalized()
	var speed:     float   = lerpf(720.0, 980.0, predictability)
	_show_attack_telegraph(origin, direction, lerpf(0.28, 0.14, predictability), PHASE_COLORS[BossPhase.PATH_LIBRARIAN])
	_spawn_projectile(origin, direction, speed, lerpf(18.0, 26.0, predictability), 1.8, "prediction")
	EventBus.boss_prediction_attack.emit(target)
	EventBus.session_event.emit("boss_prediction_attack", {
		"target": {"x": target.x, "y": target.y},
	})


func _spawn_intercept_attack(target: Vector2, predictability: float) -> void:
	if _attack_timer > 0.0:
		return
	var offset_dir:      Vector2 = (target - global_position).normalized().orthogonal()
	var intercept_target: Vector2 = target + offset_dir * lerpf(60.0, 120.0, predictability)
	var direction:       Vector2 = (intercept_target - global_position).normalized()
	_spawn_projectile(global_position, direction, lerpf(760.0, 960.0, predictability), 16.0, 2.0, "intercept")


func _spawn_multi_pattern_attack(confidence: float, predictability: float) -> void:
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	_show_attack_telegraph(global_position, dir, 0.1, PHASE_COLORS[BossPhase.OVERCLOCKED])
	_spawn_projectile(global_position, dir,                lerpf(920.0, 1180.0, confidence), 24.0, 1.7, "burst_center")
	_spawn_projectile(global_position, dir.rotated( 0.18), lerpf(860.0, 1100.0, confidence), 20.0, 1.7, "burst_left")
	_spawn_projectile(global_position, dir.rotated(-0.18), lerpf(860.0, 1100.0, confidence), 20.0, 1.7, "burst_right")
	if predictability > 0.65:
		_spawn_intercept_attack(_player.global_position, predictability)


func _spawn_projectile(origin: Vector2, direction: Vector2, speed: float, damage: float, lifetime: float, source_tag: String) -> void:
	var bullet := Area2D.new()
	bullet.name = "BossProjectile_%s" % source_tag
	bullet.set_meta("source", "boss")
	bullet.collision_layer = 4
	bullet.collision_mask  = 1
	bullet.monitoring      = true
	var shape  := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape   = circle
	bullet.add_child(shape)
	bullet.set_script(load("res://scripts/Projectile.gd"))
	bullet.global_position = origin
	if bullet.has_method("launch"):
		bullet.launch(direction, speed, damage, lifetime)
	get_tree().current_scene.add_child(bullet)

# ─────────────────────────────────────────────────────────────────────────────
# Visual helpers
# ─────────────────────────────────────────────────────────────────────────────

func _reduce_telegraph(confidence: float) -> void:
	_phase_timer = minf(_phase_timer, lerpf(0.85, 0.3, confidence))


func _apply_precision_look(mood: String) -> void:
	match mood:
		"Pressing":
			_aura_pulse = maxf(_aura_pulse, 0.3)
		"Overclocked":
			_aura_pulse = maxf(_aura_pulse, 0.55)


func _apply_aura_from_phase(col: Color) -> void:
	## Tints the root modulate toward phase colour; aura_pulse brightens it.
	var tinted := col.lerp(Color.WHITE, clampf(_aura_pulse, 0.0, 1.0) * 0.18)
	modulate = tinted


## Show a thin directional line indicator in the attack warning layer.
## Decays automatically by calling queue_free on a 1-shot timer child.
func _show_attack_telegraph(origin: Vector2, direction: Vector2, duration: float, col: Color) -> void:
	if not is_instance_valid(_attack_warning_layer):
		return
	# We draw a temporary Line2D in world space to telegraph the attack direction.
	var line := Line2D.new()
	line.default_color = Color(col.r, col.g, col.b, 0.55)
	line.width         = 2.0
	# Line is in local coords of AttackWarningLayer (which has no offset).
	var local_origin := _attack_warning_layer.to_local(origin)
	line.add_point(local_origin)
	line.add_point(local_origin + direction * 280.0)
	_attack_warning_layer.add_child(line)
	# Self-removing timer.
	var t := get_tree().create_timer(duration)
	t.timeout.connect(line.queue_free)


func _show_phase_banner(phase: BossPhase) -> void:
	if not is_instance_valid(_phase_banner) or not is_instance_valid(_banner_label):
		return
	var col: Color   = _get_phase_color()
	var name_str: String = _get_phase_name(phase).to_upper()
	_banner_label.text     = name_str
	_banner_label.modulate = col
	# Tint background with a very faint phase colour.
	var bg := _phase_banner.get_node_or_null("BannerBackground") as ColorRect
	if bg:
		bg.color = Color(col.r * 0.06, col.g * 0.06, col.b * 0.06, 0.90)
	_phase_banner.visible = true


func _update_visuals(delta: float) -> void:
	_anim_time  += delta
	_aura_pulse  = maxf(_aura_pulse - delta * 0.7, 0.0)
	_flash_alpha = maxf(_flash_alpha - delta * 3.5, 0.0)   # fast decay
	_core_pulse  = sin(_anim_time * 2.8) * 0.5 + 0.5      # 0..1 breath

	# Ring rotation – outer slow CW, inner fast CCW.
	_ring_angle_a += delta * 0.55
	_ring_angle_b -= delta * 1.1

	# Banner timer.
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and is_instance_valid(_phase_banner):
			_phase_banner.visible = false

	# Legacy label (hidden, but kept for any HUD that reads .text).
	if _phase_label:
		_phase_label.text = _get_phase_name(_boss_phase).to_upper()

	queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
# Draw  (all boss visuals rendered here for zero-node overhead)
# ─────────────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var phase_col: Color = _get_phase_color()

	# ── Overclocked: dual-colour accent that pulses between red and purple ──
	var draw_col: Color = phase_col
	if _boss_phase == BossPhase.OVERCLOCKED:
		var t: float = sin(_anim_time * 4.2) * 0.5 + 0.5
		draw_col = OVERCLOCK_PURP.lerp(OVERCLOCK_RED, t)

	# ── 1. Outer diffuse aura (large, very transparent) ────────────────────
	var aura_r: float = RING_OUTER + 24.0 + _core_pulse * 8.0
	draw_circle(Vector2.ZERO, aura_r, Color(draw_col.r, draw_col.g, draw_col.b, 0.04))
	draw_circle(Vector2.ZERO, aura_r * 0.78, Color(draw_col.r, draw_col.g, draw_col.b, 0.08))

	# ── 2. Phase aura pulse ring (brightens on transition) ─────────────────
	if _aura_pulse > 0.01:
		var pulse_r: float = RING_OUTER * (1.0 + _aura_pulse * 0.4)
		draw_arc(Vector2.ZERO, pulse_r, 0.0, TAU, 64,
				Color(draw_col.r, draw_col.g, draw_col.b, _aura_pulse * 0.7), 2.5)

	# ── 3. Outer rotating ring (dashed arc, slow CW) ───────────────────────
	var seg_count: int  = 8
	var seg_arc: float  = TAU / seg_count
	var gap_frac: float = 0.28
	for i in seg_count:
		var start: float = _ring_angle_a + i * seg_arc
		var end:   float = start + seg_arc * (1.0 - gap_frac)
		draw_arc(Vector2.ZERO, RING_OUTER, start, end, 16,
				Color(draw_col.r, draw_col.g, draw_col.b, 0.80), 2.0)

	# ── 4. Mid rotating ring (solid arc, fast CCW) ─────────────────────────
	var mid_seg: int    = 6
	var mid_arc: float  = TAU / mid_seg
	for i in mid_seg:
		var start: float = _ring_angle_b + i * mid_arc
		var end:   float = start + mid_arc * 0.72
		draw_arc(Vector2.ZERO, RING_MID, start, end, 12,
				Color(1.0, 1.0, 1.0, 0.30), 1.5)

	# ── 5. Inner tick ring (tiny dashes, static offset) ────────────────────
	var tick_count: int = 12
	for i in tick_count:
		var angle: float = (TAU / tick_count) * i + _ring_angle_a * 0.3
		var inner_pt: Vector2 = Vector2(cos(angle), sin(angle)) * (RING_INNER - 3.0)
		var outer_pt: Vector2 = Vector2(cos(angle), sin(angle)) * (RING_INNER + 3.0)
		draw_line(inner_pt, outer_pt, Color(draw_col.r, draw_col.g, draw_col.b, 0.55), 1.2)

	# ── 6. Core dark fill ──────────────────────────────────────────────────
	draw_circle(Vector2.ZERO, CORE_RADIUS, Color(0.03, 0.03, 0.05, 1.0))

	# ── 7. Core glow – inner bright disc that breathes ─────────────────────
	var glow_r: float = CORE_RADIUS * 0.55 + _core_pulse * (CORE_RADIUS * 0.25)
	draw_circle(Vector2.ZERO, glow_r, Color(draw_col.r, draw_col.g, draw_col.b, 0.85 + _core_pulse * 0.15))
	# Bright specular highlight.
	draw_circle(Vector2(-3.0, -3.0), 4.0, Color(1.0, 1.0, 1.0, 0.45))

	# ── 8. Core border ring (crisp, solid) ─────────────────────────────────
	draw_arc(Vector2.ZERO, CORE_RADIUS, 0.0, TAU, 64, draw_col, 1.8)

	# ── 9. Flash overlay (full-disc white, fast decay after phase change) ──
	if _flash_alpha > 0.01:
		draw_circle(Vector2.ZERO, RING_OUTER + 30.0,
				Color(1.0, 1.0, 1.0, _flash_alpha * 0.55))

# ─────────────────────────────────────────────────────────────────────────────
# Utility
# ─────────────────────────────────────────────────────────────────────────────

func _get_phase_color() -> Color:
	return PHASE_COLORS.get(_boss_phase, PHASE_COLORS[BossPhase.REACTION_AUDITOR])


func _get_phase_name(phase: BossPhase) -> String:
	match phase:
		BossPhase.REACTION_AUDITOR: return "Reaction Auditor"
		BossPhase.PATH_LIBRARIAN:   return "Path Librarian"
		BossPhase.PULSE_WARDEN:     return "Pulse Warden"
		BossPhase.OVERCLOCKED:      return "Overclocked"
	return "Reaction Auditor"


func _get_boss_display_name() -> String:
	return "Nexus Boss"


func _die() -> void:
	EventBus.boss_died.emit(_get_boss_display_name())
	super._die()