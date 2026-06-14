extends Node2D
## Arena root scene - bootstraps WaveManager, player, and UI on load.
## Visual redesign: cyberpunk / Valorant-inspired esports aesthetic.
## All gameplay logic is unchanged.

# ── Palette ──────────────────────────────────────────────────────────────────
const C_BG_OUTER    := Color(0.03, 0.01, 0.06)       # deep void purple
const C_BG_INNER    := Color(0.05, 0.02, 0.09)       # arena floor
const C_GRID        := Color(0.18, 0.08, 0.55, 0.30) # dim purple grid
const C_GRID_ACCENT := Color(0.40, 0.10, 1.00, 0.18) # brighter grid cross
const C_BORDER_1    := Color(0.95, 0.10, 0.60, 0.90) # hot-pink outer
const C_BORDER_2    := Color(0.20, 0.80, 1.00, 0.85) # cyan inner
const C_SCAN        := Color(0.20, 1.00, 0.90, 0.09) # scanline sweep
const C_PULSE_RING  := Color(0.20, 0.80, 1.00, 0.55) # director pulse
const C_SPAWN_RING  := Color(0.95, 0.90, 0.10, 0.80) # spawn warning yellow
const C_CORNER_DASH := Color(0.95, 0.10, 0.60, 0.70) # corner bracket pink
const C_DIFF_HEAT   := Color(1.00, 0.30, 0.05, 0.00) # difficulty heat tint

# ── Arena geometry ────────────────────────────────────────────────────────────
const ARENA_W  := 1200.0
const ARENA_H  :=  800.0
const AX       := -ARENA_W * 0.5   # -600
const AY       := -ARENA_H * 0.5   # -400
const GRID_STEP := 60              # grid cell size

# ── Spawn point world positions (must match .tscn Marker2D positions) ─────────
const SPAWN_POSITIONS: Array[Vector2] = [
	Vector2(   0, -360),   # North
	Vector2(   0,  360),   # South
	Vector2( 480,    0),   # East
	Vector2(-480,    0),   # West
]

# ── Runtime state ─────────────────────────────────────────────────────────────
var _time        := 0.0
var _diff_level  := 0       # 0-5, increased externally via escalate_difficulty()
var _diff_heat   := 0.0     # 0..1 smooth lerp target

## Director-pulse state (call trigger_director_pulse() from WaveManager)
var _pulse_active  := false
var _pulse_radius  := 0.0
var _pulse_alpha   := 0.0
var _pulse_tween   : Tween

## Per-spawn flash state
var _spawn_flash   := {}    # spawn_index -> alpha 0..1
var _spawn_tweens  := {}

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var wave_manager    : Node    = $WaveManager
@onready var spawn_points    : Node2D  = $SpawnPoints
@onready var enemies_container: Node2D = $Enemies

# ── Visual-only child nodes (added in .tscn) ──────────────────────────────────
@onready var bg_particles    : GPUParticles2D = $FX/AmbientSparks
@onready var border_lines    : Node2D         = $FX/BorderLines


# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	print("Arena Ready")
	# Seed spawn-flash dict
	for i in range(SPAWN_POSITIONS.size()):
		_spawn_flash[i] = 0.0

	# Wire up gameplay (unchanged)
	var points: Array[Node2D] = []
	for child in spawn_points.get_children():
		if child is Node2D:
			points.append(child)

	wave_manager.setup(enemies_container, points)
	GameManager.register_arena(self, wave_manager)
	GameManager.start_run()

	# Animate border lines brightness with a looping tween
	_start_border_pulse()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	# Smooth difficulty heat
	var target_heat := clampf(float(_diff_level) / 5.0, 0.0, 1.0)
	_diff_heat = lerpf(_diff_heat, target_heat, delta * 0.8)
	queue_redraw()


# ═══════════════════════════════════════════════════════════════════════════════
## Public API for WaveManager / GameManager to call
# ═══════════════════════════════════════════════════════════════════════════════

## Call this from WaveManager when a new wave starts.
## spawn_index: 0=North 1=South 2=East 3=West
func flash_spawn(spawn_index: int) -> void:
	if spawn_index < 0 or spawn_index >= SPAWN_POSITIONS.size():
		return
	# Kill any running tween for this spawn
	if _spawn_tweens.has(spawn_index) and _spawn_tweens[spawn_index]:
		_spawn_tweens[spawn_index].kill()
	_spawn_flash[spawn_index] = 1.0
	var tw := create_tween()
	tw.tween_method(func(v): _spawn_flash[spawn_index] = v, 1.0, 0.0, 1.2)
	_spawn_tweens[spawn_index] = tw


## Call this from WaveManager on elite / boss spawn.
func trigger_director_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_active = true
	_pulse_radius = 0.0
	_pulse_alpha  = 0.8
	_pulse_tween  = create_tween()
	_pulse_tween.tween_method(_set_pulse, 0.0, 1.0, 0.9)


## Call this when difficulty wave index increases (0-5).
func escalate_difficulty(level: int) -> void:
	_diff_level = clampi(level, 0, 5)


# ── reset_run (gameplay, unchanged) ───────────────────────────────────────────
func reset_run() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node and enemy.get_parent() == enemies_container:
			enemy.queue_free()

	for projectile: Node in get_tree().get_nodes_in_group("projectiles"):
		if projectile is Node and projectile.get_parent() == self:
			projectile.queue_free()

	var player: Node = $Player
	if player and player.has_method("reset_for_run"):
		player.reset_for_run()

	if wave_manager and wave_manager.has_method("reset_run"):
		wave_manager.reset_run()

	_diff_level = 0
	_diff_heat  = 0.0
	queue_redraw()


# ═══════════════════════════════════════════════════════════════════════════════
## Draw  (all visuals; no gameplay)
# ═══════════════════════════════════════════════════════════════════════════════
func _draw() -> void:
	_draw_background()
	_draw_grid()
	_draw_scanline()
	_draw_diagonal_accents()
	_draw_center_crosshair()
	_draw_corners()
	_draw_borders()
	_draw_spawn_indicators()
	_draw_director_pulse()
	_draw_difficulty_heat()


# ── Layer 0: Background ────────────────────────────────────────────────────────
func _draw_background() -> void:
	# Outer void
	draw_rect(Rect2(AX - 20, AY - 20, ARENA_W + 40, ARENA_H + 40), C_BG_OUTER)
	# Inner floor with subtle radial-ish gradient via stacked rects
	draw_rect(Rect2(AX, AY, ARENA_W, ARENA_H), C_BG_INNER)
	# Faint vignette edges
	var vign := Color(0.0, 0.0, 0.0, 0.45)
	draw_rect(Rect2(AX,        AY,        ARENA_W, 40), vign)  # top
	draw_rect(Rect2(AX,        AY + ARENA_H - 40, ARENA_W, 40), vign)  # bottom
	draw_rect(Rect2(AX,        AY,        40, ARENA_H), vign)  # left
	draw_rect(Rect2(AX + ARENA_W - 40, AY, 40, ARENA_H), vign)  # right


# ── Layer 1: Neon Grid Floor ──────────────────────────────────────────────────
func _draw_grid() -> void:
	var t := _time
	# Every 5th line is a brighter accent line
	var x := AX
	var col_i := 0
	while x <= -AX + 1:
		var is_accent := (col_i % 5 == 0)
		var pulse := 0.06 * sin(t * 1.4 + x * 0.015)
		var c: Color = C_GRID_ACCENT if is_accent else C_GRID
		c.a = (C_GRID_ACCENT.a if is_accent else C_GRID.a) + pulse
		draw_line(Vector2(x, AY), Vector2(x, -AY), c, 1.0 if not is_accent else 1.5)
		x += GRID_STEP
		col_i += 1

	var y := AY
	var row_i := 0
	while y <= -AY + 1:
		var is_accent := (row_i % 5 == 0)
		var pulse := 0.06 * sin(t * 1.1 + y * 0.015)
		var c: Color = C_GRID_ACCENT if is_accent else C_GRID
		c.a = (C_GRID_ACCENT.a if is_accent else C_GRID.a) + pulse
		draw_line(Vector2(AX, y), Vector2(-AX, y), c, 1.0 if not is_accent else 1.5)
		y += GRID_STEP
		row_i += 1


# ── Layer 2: Scanline sweep ───────────────────────────────────────────────────
func _draw_scanline() -> void:
	var sweep_y := AY + fmod(_time * 55.0, ARENA_H)
	# Thick soft scanline
	for i in 5:
		var offset := float(i) - 2.0
		var a := C_SCAN.a * (1.0 - absf(offset) / 3.5)
		draw_line(
			Vector2(AX, sweep_y + offset * 2.0),
			Vector2(-AX, sweep_y + offset * 2.0),
			Color(C_SCAN.r, C_SCAN.g, C_SCAN.b, a), 1.5
		)


# ── Layer 3: Diagonal accent streaks ─────────────────────────────────────────
func _draw_diagonal_accents() -> void:
	var t := _time
	# Two slow drifting diagonals — purely decorative
	var diag_c := Color(0.55, 0.05, 1.0, 0.07)
	var offset1 := fmod(t * 18.0, ARENA_W + ARENA_H)
	var offset2 := fmod(t * 12.0 + 500.0, ARENA_W + ARENA_H)
	_draw_clipped_diagonal(offset1, diag_c, 200.0)
	_draw_clipped_diagonal(offset2, Color(0.05, 0.80, 1.0, 0.06), 140.0)


func _draw_clipped_diagonal(offset: float, color: Color, half_thick: float) -> void:
	# Draw a wide diagonal streak (like a lens flare slash)
	var s := Vector2(AX + offset - half_thick, AY)
	var e := Vector2(AX + offset + half_thick, -AY)
	for i in 8:
		var t_norm := float(i) / 7.0
		var shift := lerpf(-half_thick, half_thick, t_norm)
		var a := color.a * (1.0 - absf(t_norm - 0.5) * 2.0)
		draw_line(
			Vector2(s.x + shift, s.y),
			Vector2(e.x + shift, e.y),
			Color(color.r, color.g, color.b, a), 1.0
		)


# ── Layer 4: Center crosshair ─────────────────────────────────────────────────
func _draw_center_crosshair() -> void:
	var len  := 22.0
	var gap  := 8.0
	var col  := Color(0.20, 0.80, 1.00, 0.65)
	var col2 := Color(0.95, 0.10, 0.60, 0.50)
	# Horizontal
	draw_line(Vector2(-len, 0), Vector2(-gap, 0), col, 1.5)
	draw_line(Vector2( gap, 0), Vector2( len, 0), col, 1.5)
	# Vertical
	draw_line(Vector2(0, -len), Vector2(0, -gap), col, 1.5)
	draw_line(Vector2(0,  gap), Vector2(0,  len), col, 1.5)
	# Centre dot
	draw_circle(Vector2.ZERO, 2.5, col2)
	draw_circle(Vector2.ZERO, 1.2, col)


# ── Layer 5: Corner brackets ──────────────────────────────────────────────────
func _draw_corners() -> void:
	var arm  := 28.0
	var inset := 8.0
	var col  := C_CORNER_DASH
	var corners: Array[Vector2] = [
		Vector2(AX,  AY),   # TL
		Vector2(-AX, AY),   # TR
		Vector2(AX, -AY),   # BL
		Vector2(-AX,-AY),   # BR
	]
	var dirs: Array[Array] = [
		[Vector2.RIGHT, Vector2.DOWN],
		[Vector2.LEFT,  Vector2.DOWN],
		[Vector2.RIGHT, Vector2.UP],
		[Vector2.LEFT,  Vector2.UP],
	]
	for idx in corners.size():
		var c: Vector2 = corners[idx]
		var dx  : Vector2 = dirs[idx][0]
		var dy  : Vector2 = dirs[idx][1]
		var origin := c + dx * inset + dy * inset
		# Horizontal arm
		draw_line(origin, origin + dx * arm, col, 2.5)
		# Vertical arm
		draw_line(origin, origin + dy * arm, col, 2.5)
		# Tiny corner dot
		draw_circle(origin, 2.0, col)


# ── Layer 6: Arena borders ────────────────────────────────────────────────────
func _draw_borders() -> void:
	var t := _time
	# Outer border — hot-pink, animated alpha
	var a1 := 0.75 + 0.18 * sin(t * 2.3)
	draw_rect(
		Rect2(AX, AY, ARENA_W, ARENA_H),
		Color(C_BORDER_1.r, C_BORDER_1.g, C_BORDER_1.b, a1),
		false, 2.5
	)
	# Inner border — cyan, offset 5 px, slower pulse
	var a2 := 0.55 + 0.22 * sin(t * 1.5 + 1.0)
	draw_rect(
		Rect2(AX + 5, AY + 5, ARENA_W - 10, ARENA_H - 10),
		Color(C_BORDER_2.r, C_BORDER_2.g, C_BORDER_2.b, a2),
		false, 1.0
	)
	# Tertiary faint glow line
	draw_rect(
		Rect2(AX + 9, AY + 9, ARENA_W - 18, ARENA_H - 18),
		Color(C_BORDER_1.r, C_BORDER_1.g, C_BORDER_1.b, 0.10),
		false, 1.0
	)


# ── Layer 7: Spawn indicators ─────────────────────────────────────────────────
func _draw_spawn_indicators() -> void:
	var t: float = _time
	for i in SPAWN_POSITIONS.size():
		var pos: Vector2 = SPAWN_POSITIONS[i]
		var idle: float = 0.30 + 0.12 * sin(t * 2.0 + float(i) * 1.57)
		var flash_a : float = _spawn_flash.get(i, 0.0)
		var alpha: float = maxf(idle, flash_a)

		# Outer ring
		draw_arc(pos, 24.0, 0, TAU, 32, Color(C_SPAWN_RING.r, C_SPAWN_RING.g, C_SPAWN_RING.b, alpha * 0.6), 1.5)
		# Inner filled disc
		draw_circle(pos, 6.0, Color(C_SPAWN_RING.r, C_SPAWN_RING.g, C_SPAWN_RING.b, alpha * 0.9))

		# Dashed direction tick toward arena centre
		var to_centre: Vector2 = (Vector2.ZERO - pos).normalized()
		draw_line(pos + to_centre * 28.0, pos + to_centre * 44.0,
			Color(C_SPAWN_RING.r, C_SPAWN_RING.g, C_SPAWN_RING.b, alpha * 0.7), 1.5)

		# Label text (cardinal)
		var labels: Array[String] = ["N", "S", "E", "W"]
		var label_pos: Vector2 = pos + to_centre * 56.0
		draw_string(
			ThemeDB.fallback_font,
			label_pos - Vector2(5, 6),
			labels[i],
			HORIZONTAL_ALIGNMENT_CENTER, -1, 11,
			Color(C_SPAWN_RING.r, C_SPAWN_RING.g, C_SPAWN_RING.b, alpha * 0.55)
		)


# ── Layer 8: Director pulse ───────────────────────────────────────────────────
func _draw_director_pulse() -> void:
	if not _pulse_active:
		return
	var max_radius := 680.0
	var r := _pulse_radius * max_radius
	var a := _pulse_alpha * (1.0 - _pulse_radius)
	if a > 0.01:
		draw_arc(Vector2.ZERO, r,       0, TAU, 64, Color(C_PULSE_RING.r, C_PULSE_RING.g, C_PULSE_RING.b, a),       2.5)
		draw_arc(Vector2.ZERO, r - 8.0, 0, TAU, 64, Color(C_PULSE_RING.r, C_PULSE_RING.g, C_PULSE_RING.b, a * 0.4), 1.0)


# ── Layer 9: Difficulty heat overlay ─────────────────────────────────────────
func _draw_difficulty_heat() -> void:
	if _diff_heat < 0.01:
		return
	# Hot red vignette corners that intensifies as waves progress
	var edge_a := _diff_heat * 0.38
	var col := Color(C_DIFF_HEAT.r, C_DIFF_HEAT.g, C_DIFF_HEAT.b, edge_a)
	# Four corner triangles
	var cx := AX;  var cy := AY
	var fade := 200.0 * _diff_heat
	draw_rect(Rect2(cx,              cy,             fade, fade), col)
	draw_rect(Rect2(-AX - fade,      cy,             fade, fade), col)
	draw_rect(Rect2(cx,             -AY - fade,      fade, fade), col)
	draw_rect(Rect2(-AX - fade,     -AY - fade,      fade, fade), col)

	# Pulsing border tint when near max difficulty
	if _diff_heat > 0.7:
		var pulse_a := (_diff_heat - 0.7) / 0.3 * (0.25 + 0.15 * sin(_time * 6.0))
		draw_rect(Rect2(AX, AY, ARENA_W, ARENA_H),
			Color(1.0, 0.10, 0.05, pulse_a), false, 3.5)


# ═══════════════════════════════════════════════════════════════════════════════
## Internal helpers
# ═══════════════════════════════════════════════════════════════════════════════

func _set_pulse(v: float) -> void:
	_pulse_radius = v
	_pulse_alpha  = 0.8 * (1.0 - v)
	if v >= 1.0:
		_pulse_active = false
	queue_redraw()


func _start_border_pulse() -> void:
	# Tween modulate of the Line2D border nodes for an independent glow cycle
	if not has_node("FX/BorderLines"):
		return
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(border_lines, "modulate:a", 0.6, 1.2)
	tw.tween_property(border_lines, "modulate:a", 1.0, 1.2)
