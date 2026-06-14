extends CanvasLayer
## In-game HUD — health, wave info, and crosshair feedback.
## Visual style: minimalist cyberpunk esports (Valorant-inspired).

@onready var health_bar: ProgressBar = $BottomBar/HealthPanel/HealthMargin/HealthVBox/HealthBarBG/HealthBar
@onready var hp_value_label: Label = $BottomBar/HealthPanel/HealthMargin/HealthVBox/HealthTopRow/HpValueLabel
@onready var health_panel: PanelContainer = $BottomBar/HealthPanel

@onready var boss_panel: PanelContainer = $BossPanel
@onready var boss_name_label: Label = $BossPanel/BossMargin/BossVBox/BossTopRow/BossNameLabel
@onready var boss_health_bar: ProgressBar = $BossPanel/BossMargin/BossVBox/BossHealthBarBG/BossHealthBar
@onready var boss_hp_label: Label = $BossPanel/BossMargin/BossVBox/BossTopRow/BossHpLabel

@onready var wave_label: Label = $BottomBar/StatusRow/WavePanel/WaveMargin/WaveVBox/WaveLabel
@onready var kills_label: Label = $BottomBar/StatusRow/WavePanel/WaveMargin/WaveVBox/KillsLabel

@onready var director_panel: PanelContainer = $BottomBar/StatusRow/DirectorPanel
@onready var director_dot: ColorRect = $BottomBar/StatusRow/DirectorPanel/DirectorMargin/DirectorHBox/DirectorDot
@onready var mood_label: Label = $BottomBar/StatusRow/DirectorPanel/DirectorMargin/DirectorHBox/DirectorVBox/MoodLabel

@onready var popup_label: Label = $Popup
@onready var flash_rect: ColorRect = $Flash

# -- Palette: minimalist cyberpunk esports --
const COL_BG: Color = Color(0.04, 0.045, 0.06, 0.82)
const COL_ACCENT: Color = Color(0.35, 0.95, 1.0, 1.0)
const COL_TEXT: Color = Color(0.88, 0.95, 0.98, 1.0)
const COL_DIM: Color = Color(0.55, 0.65, 0.7, 1.0)
const COL_HP_FULL: Color = Color(0.35, 0.95, 0.75)
const COL_HP_MID: Color = Color(1.0, 0.78, 0.25)
const COL_HP_LOW: Color = Color(1.0, 0.25, 0.35)
const COL_BOSS_ACCENT: Color = Color(1.0, 0.25, 0.45, 1.0)

const MOOD_CALM: Color = Color(0.35, 0.95, 1.0)
const MOOD_PRESSING: Color = Color(1.0, 0.78, 0.25)
const MOOD_OVERCLOCKED: Color = Color(1.0, 0.25, 0.35)

var _kills: int = 0
var _popup_time: float = 0.0
var _popup_fade: float = 0.0
var _flash_time: float = 0.0
var _flash_strength: float = 0.0
var _last_difficulty: float = 1.0
var _popup_tween: Tween = null
var _player_target_value: float = 100.0
var _player_max_value: float = 100.0
var _boss_target_value: float = 0.0
var _boss_max_value: float = 0.0
var _boss_name: String = ""
var _boss_visible: bool = false
var _boss_present: bool = false
var _hit_pulse_tween: Tween = null
var _director_pulse_tween: Tween = null
var _current_mood: String = "Calm"


func _ready() -> void:
	_apply_panel_style(health_panel, COL_ACCENT)
	_apply_panel_style(director_panel, COL_ACCENT)
	_apply_panel_style($BottomBar/StatusRow/WavePanel, Color(0.4, 0.5, 0.6, 0.2))
	_apply_panel_style(boss_panel, COL_BOSS_ACCENT)

	_style_bar_bg($BottomBar/HealthPanel/HealthMargin/HealthVBox/HealthBarBG)
	_style_bar_bg($BossPanel/BossMargin/BossVBox/BossHealthBarBG)

	health_bar.add_theme_stylebox_override("fill", _bar_fill_style(COL_HP_FULL))
	health_bar.add_theme_stylebox_override("background", _bar_empty_style())

	boss_health_bar.add_theme_stylebox_override("fill", _bar_fill_style(COL_BOSS_ACCENT))
	boss_health_bar.add_theme_stylebox_override("background", _bar_empty_style())

	$BottomBar/HealthPanel/HealthMargin/HealthVBox/HealthTopRow/HealthTag.add_theme_color_override("font_color", COL_DIM)
	hp_value_label.add_theme_color_override("font_color", COL_TEXT)
	wave_label.add_theme_color_override("font_color", COL_TEXT)
	kills_label.add_theme_color_override("font_color", COL_DIM)
	$BottomBar/StatusRow/DirectorPanel/DirectorMargin/DirectorHBox/DirectorVBox/DirectorTag.add_theme_color_override("font_color", COL_DIM)
	mood_label.add_theme_color_override("font_color", MOOD_CALM)
	boss_name_label.add_theme_color_override("font_color", COL_TEXT)
	boss_hp_label.add_theme_color_override("font_color", COL_DIM)

	popup_label.add_theme_color_override("font_color", COL_TEXT)
	popup_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	popup_label.add_theme_constant_override("outline_size", 4)

	director_dot.color = MOOD_CALM
	_start_director_pulse()

	EventBus.player_hit.connect(_on_player_hit)
	EventBus.player_healed.connect(_on_player_healed)
	EventBus.player_spawned.connect(_on_player_spawned)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_health_changed.connect(_on_boss_health_changed)
	EventBus.boss_died.connect(_on_boss_died)
	EventBus.director_mood_changed.connect(_on_director_mood_changed)
	EventBus.difficulty_changed.connect(_on_difficulty_changed)
	EventBus.ui_popup_requested.connect(_on_ui_popup_requested)
	EventBus.screen_flash_requested.connect(_on_screen_flash_requested)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)

	mood_label.text = "CALM"
	popup_label.text = ""
	boss_panel.visible = false
	boss_name_label.text = "BOSS // --"
	boss_hp_label.text = "0 / 0"
	boss_health_bar.max_value = 1.0
	boss_health_bar.value = 0.0


# ---------------------------------------------------------------------------
# Styling helpers
# ---------------------------------------------------------------------------

func _apply_panel_style(panel: PanelContainer, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COL_BG
	style.set_corner_radius_all(4)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)


func _style_bar_bg(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)


func _bar_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style


func _bar_empty_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.15, 1.0)
	style.set_corner_radius_all(2)
	return style


func _start_director_pulse() -> void:
	if _director_pulse_tween and _director_pulse_tween.is_valid():
		_director_pulse_tween.kill()
	_director_pulse_tween = create_tween()
	_director_pulse_tween.set_loops()
	_director_pulse_tween.tween_property(director_dot, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE)
	_director_pulse_tween.tween_property(director_dot, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------------------
# Gameplay signal handlers (logic unchanged)
# ---------------------------------------------------------------------------

func _on_player_spawned(player: Node2D) -> void:
	if player.has_method("take_damage"):
		var params: GameParams = player.params
		if params:
			_player_max_value = params.player_max_health
			_player_target_value = params.player_max_health
			health_bar.max_value = params.player_max_health
			health_bar.value = params.player_max_health


func _on_player_hit(_damage: float, health_remaining: float) -> void:
	_player_target_value = health_remaining
	_pulse_health_panel()


func _on_player_healed(_amount: float, health_remaining: float) -> void:
	_player_target_value = health_remaining


func _on_wave_started(wave_number: int, enemy_count: int) -> void:
	wave_label.text = "WAVE %d  //  %d ENEMIES" % [wave_number, enemy_count]


func _on_enemy_killed(_enemy_type: String, _position: Vector2) -> void:
	_kills += 1
	kills_label.text = "KILLS  %d" % _kills


func _on_player_died() -> void:
	wave_label.text = "GAME OVER"
	_player_target_value = 0.0


func _on_boss_spawned(_boss: Node2D, boss_name: String, current_health: float, max_health: float) -> void:
	_boss_present = true
	_boss_visible = true
	_boss_name = boss_name
	_boss_max_value = max_health
	_boss_target_value = current_health
	boss_name_label.text = "BOSS // %s" % boss_name.to_upper()
	boss_health_bar.max_value = max_health
	boss_health_bar.value = current_health
	boss_hp_label.text = "%d / %d" % [int(ceil(current_health)), int(ceil(max_health))]
	_show_boss_panel()


func _on_boss_health_changed(boss_name: String, current_health: float, max_health: float) -> void:
	_boss_present = true
	_boss_visible = true
	_boss_name = boss_name
	_boss_max_value = max_health
	_boss_target_value = current_health
	boss_name_label.text = "BOSS // %s" % boss_name.to_upper()
	boss_health_bar.max_value = max_health
	boss_hp_label.text = "%d / %d" % [int(ceil(current_health)), int(ceil(max_health))]
	if not boss_panel.visible:
		_show_boss_panel()


func _on_boss_died(_boss_name: String) -> void:
	_boss_present = false
	_boss_visible = false
	_boss_target_value = 0.0
	_hide_boss_panel()


func _show_boss_panel() -> void:
	boss_panel.visible = true
	boss_panel.modulate.a = 0.0
	boss_panel.scale = Vector2(0.96, 0.96)
	boss_panel.pivot_offset = boss_panel.size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(boss_panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(boss_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_boss_panel() -> void:
	var tw := create_tween()
	tw.tween_property(boss_panel, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): boss_panel.visible = false)


func _pulse_health_panel() -> void:
	if _hit_pulse_tween and _hit_pulse_tween.is_valid():
		_hit_pulse_tween.kill()
	_hit_pulse_tween = create_tween()
	_hit_pulse_tween.tween_property(health_panel, "modulate", Color(1.4, 1.0, 1.0, 1.0), 0.06)
	_hit_pulse_tween.tween_property(health_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)


# ---------------------------------------------------------------------------
# Frame update
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_mood_live()
	_animate_health_bars(delta)
	_update_popup(delta)
	_update_flash(delta)


func _animate_health_bars(delta: float) -> void:
	health_bar.value = lerpf(health_bar.value, _player_target_value, clampf(delta * 10.0, 0.0, 1.0))
	var hp_ratio: float = health_bar.value / maxf(_player_max_value, 1.0)
	(health_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = _get_health_color(hp_ratio)
	hp_value_label.text = "%d / %d" % [int(ceil(health_bar.value)), int(ceil(_player_max_value))]
	if hp_ratio <= 0.3:
		hp_value_label.add_theme_color_override("font_color", COL_HP_LOW)
	else:
		hp_value_label.add_theme_color_override("font_color", COL_TEXT)

	if _boss_visible:
		boss_health_bar.value = lerpf(boss_health_bar.value, _boss_target_value, clampf(delta * 8.0, 0.0, 1.0))
		boss_hp_label.text = "%d / %d" % [int(ceil(boss_health_bar.value)), int(ceil(_boss_max_value))]


func _get_health_color(ratio: float) -> Color:
	var t: float = clampf(ratio, 0.0, 1.0)
	if t > 0.5:
		return COL_HP_MID.lerp(COL_HP_FULL, clampf((t - 0.5) * 2.0, 0.0, 1.0))
	return COL_HP_LOW.lerp(COL_HP_MID, clampf(t * 2.0, 0.0, 1.0))


func _update_mood_live() -> void:
	var mood: String = Director.get_current_mood()
	if mood != _current_mood:
		_apply_mood(mood)


func _on_director_mood_changed(mood: String) -> void:
	_apply_mood(mood)


func _apply_mood(mood: String) -> void:
	_current_mood = mood
	mood_label.text = mood.to_upper()
	var col: Color
	match mood:
		"Pressing":
			col = MOOD_PRESSING
		"Overclocked":
			col = MOOD_OVERCLOCKED
		_:
			col = MOOD_CALM
	mood_label.add_theme_color_override("font_color", col)
	director_dot.color = col
	var style: StyleBoxFlat = director_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = Color(col.r, col.g, col.b, 0.6)


# ---------------------------------------------------------------------------
# Popups / flashes
# ---------------------------------------------------------------------------

func _on_ui_popup_requested(message: String) -> void:
	popup_label.text = message.to_upper()
	popup_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	popup_label.scale = Vector2(0.95, 0.95)
	if _popup_tween and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_tween = create_tween()
	_popup_tween.set_trans(Tween.TRANS_QUAD)
	_popup_tween.set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(popup_label, "scale", Vector2.ONE, 0.18)
	_popup_time = 0.0
	_popup_fade = 1.0


func _on_screen_flash_requested(kind: String, strength: float) -> void:
	_flash_time = 0.0
	_flash_strength = clampf(strength, 0.1, 1.0)
	match kind:
		"hit":
			flash_rect.color = Color(1.0, 0.25, 0.35, 0.0)
		"enemy_death":
			flash_rect.color = Color(0.35, 0.95, 1.0, 0.0)
		"boss_phase":
			flash_rect.color = Color(1.0, 0.78, 0.25, 0.0)
		_:
			flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)


func _on_boss_phase_changed(phase: String) -> void:
	if phase == "Overclocked":
		_on_ui_popup_requested("Overclocked Mode Activated")
	else:
		_on_ui_popup_requested("%s Activated" % phase)


func _on_difficulty_changed(difficulty: float) -> void:
	if difficulty > _last_difficulty + 0.02:
		_on_ui_popup_requested("Director Pressure Increased")
	elif difficulty < _last_difficulty - 0.02:
		_on_ui_popup_requested("Director Easing Pressure")
	_last_difficulty = difficulty


func _update_popup(delta: float) -> void:
	if _popup_fade <= 0.0:
		return
	_popup_time += delta
	var alpha: float = clampf(1.0 - _popup_time / 2.0, 0.0, 1.0)
	popup_label.modulate.a = alpha
	if alpha <= 0.0:
		_popup_fade = 0.0
		popup_label.text = ""


func _update_flash(delta: float) -> void:
	if _flash_strength <= 0.0:
		return
	_flash_time += delta
	var alpha: float = clampf((_flash_strength * 0.35) * (1.0 - _flash_time / 0.45), 0.0, 0.35)
	flash_rect.color.a = alpha
	if _flash_time >= 0.45:
		_flash_strength = 0.0
		flash_rect.color.a = 0.0