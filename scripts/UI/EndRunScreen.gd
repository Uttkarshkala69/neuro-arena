extends CanvasLayer
## Valorant-inspired competitive results screen with animated reveal.

# ─── Node refs ──────────────────────────────────────────────────────────────
@onready var outcome_label:    Label         = $Root/MainLayout/HeaderSection/OutcomeLabel
@onready var outcome_line:     ColorRect     = $Root/MainLayout/HeaderSection/OutcomeLine
@onready var director_quote:   Label         = $Root/MainLayout/HeaderSection/DirectorQuote
@onready var stats_row:        HBoxContainer = $Root/MainLayout/StatsRow
@onready var score_label:      Label         = $Root/MainLayout/StatsRow/ScoreCard/ScoreInner/ScoreVBox/ScoreValue
@onready var waves_label:      Label         = $Root/MainLayout/StatsRow/WavesCard/WavesInner/WavesVBox/WavesValue
@onready var difficulty_label: Label         = $Root/MainLayout/StatsRow/DifficultyCard/DiffInner/DiffVBox/DifficultyValue
@onready var bottom_row:       HBoxContainer = $Root/MainLayout/BottomRow
@onready var summary_label:    Label         = $Root/MainLayout/BottomRow/DirectorPanel/DirectorInner/DirectorVBox/SummaryLabel
@onready var mood_label:       Label         = $Root/MainLayout/BottomRow/MoodSection/MoodInner/MoodVBox/MoodLabel
@onready var button_row:       HBoxContainer = $Root/MainLayout/ButtonRow
@onready var restart_button:   Button        = $Root/MainLayout/ButtonRow/RestartButton
@onready var exit_button:      Button        = $Root/MainLayout/ButtonRow/ExitButton
@onready var score_card:       PanelContainer = $Root/MainLayout/StatsRow/ScoreCard
@onready var waves_card:       PanelContainer = $Root/MainLayout/StatsRow/WavesCard
@onready var diff_card:        PanelContainer = $Root/MainLayout/StatsRow/DifficultyCard
@onready var director_panel:   PanelContainer = $Root/MainLayout/BottomRow/DirectorPanel
@onready var mood_section:     PanelContainer = $Root/MainLayout/BottomRow/MoodSection
@onready var background:       ColorRect      = $Background

# Kept for compatibility – same signals, same restart flow
var _analysis:  Dictionary = {}
var _victory:   bool       = false

# ─── Colour tokens ──────────────────────────────────────────────────────────
const C_BG          := Color(0.027, 0.031, 0.043, 0.96)
const C_PANEL       := Color(0.055, 0.068, 0.090, 1.0)
const C_BORDER      := Color(0.25,  0.95,  1.0,   0.18)
const C_ACCENT_CYAN := Color(0.25,  0.95,  1.0,   1.0)
const C_ACCENT_ORNG := Color(1.0,   0.45,  0.3,   1.0)
const C_ACCENT_GOLD := Color(1.0,   0.70,  0.3,   1.0)
const C_VICTORY     := Color(0.25,  1.0,   0.60,  1.0)
const C_DEFEAT      := Color(1.0,   0.28,  0.28,  1.0)
const C_MUTED       := Color(0.6,   0.75,  0.8,   1.0)
const C_TEXT        := Color(0.9,   0.95,  1.0,   1.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_theme()
	restart_button.pressed.connect(_on_restart_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	# Start invisible; _render() kicks off the tween sequence
	outcome_label.modulate.a = 0.0
	stats_row.modulate.a     = 0.0
	bottom_row.modulate.a    = 0.0
	button_row.modulate.a    = 0.0
	director_quote.modulate.a = 0.0


# ─── Public API (unchanged signatures) ──────────────────────────────────────

func set_run_summary(analysis: Dictionary, victory: bool, _session_path: String = "") -> void:
	_analysis = analysis.duplicate(true)
	_victory  = victory
	_render()


# ─── Internal ────────────────────────────────────────────────────────────────

func _apply_theme() -> void:
	# Background
	background.color = C_BG

	# Stat cards
	for card in [score_card, waves_card, diff_card, director_panel, mood_section]:
		_style_panel(card)

	# Outcome accent line colour is set in _render() based on victory/defeat

	# Buttons
	_style_restart_button()
	_style_exit_button()


func _style_panel(panel: PanelContainer) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color           = C_PANEL
	s.border_width_left  = 1
	s.border_width_top   = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color       = C_BORDER
	s.corner_radius_top_left     = 2
	s.corner_radius_top_right    = 2
	s.corner_radius_bottom_left  = 2
	s.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel", s)


func _style_restart_button() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color           = C_ACCENT_CYAN
	s.corner_radius_top_left     = 2
	s.corner_radius_top_right    = 2
	s.corner_radius_bottom_left  = 2
	s.corner_radius_bottom_right = 2
	restart_button.add_theme_stylebox_override("normal",  s)
	restart_button.add_theme_stylebox_override("pressed", s)
	var sh := s.duplicate()
	sh.bg_color = Color(0.5, 1.0, 1.0, 1.0)
	restart_button.add_theme_stylebox_override("hover", sh)
	restart_button.add_theme_color_override("font_color",         Color(0.02, 0.06, 0.10))
	restart_button.add_theme_color_override("font_hover_color",   Color(0.0,  0.04, 0.08))
	restart_button.add_theme_color_override("font_pressed_color", Color(0.02, 0.06, 0.10))
	restart_button.add_theme_font_size_override("font_size", 14)


func _style_exit_button() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color           = Color(0.0, 0.0, 0.0, 0.0)
	s.border_width_left  = 1
	s.border_width_top   = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color       = Color(0.35, 0.45, 0.55, 0.7)
	s.corner_radius_top_left     = 2
	s.corner_radius_top_right    = 2
	s.corner_radius_bottom_left  = 2
	s.corner_radius_bottom_right = 2
	exit_button.add_theme_stylebox_override("normal",  s)
	var sh := s.duplicate()
	sh.border_color = C_ACCENT_CYAN
	exit_button.add_theme_stylebox_override("hover",   sh)
	exit_button.add_theme_stylebox_override("pressed", s)
	exit_button.add_theme_color_override("font_color",         Color(0.55, 0.65, 0.75))
	exit_button.add_theme_color_override("font_hover_color",   C_ACCENT_CYAN)
	exit_button.add_theme_color_override("font_pressed_color", Color(0.55, 0.65, 0.75))
	exit_button.add_theme_font_size_override("font_size", 14)


func _render() -> void:
	if _analysis.is_empty():
		return

	# Outcome
	var is_victory := _victory
	outcome_label.text = "VICTORY" if is_victory else "DEFEAT"
	outcome_label.add_theme_color_override("font_color", C_VICTORY if is_victory else C_DEFEAT)
	outcome_line.color = (C_VICTORY if is_victory else C_DEFEAT) * Color(1, 1, 1, 0.6)
	director_quote.text = _pick_director_quote()

	# Stats
	score_label.text      = "%d"   % int(_calculate_final_score())
	waves_label.text      = "%d"   % int(_analysis.get("waves_cleared", _estimate_waves_cleared()))
	difficulty_label.text = "%.2fx" % float(_analysis.get("highest_difficulty", 1.0))

	# Bottom panels
	summary_label.text = _build_summary_text()
	mood_label.text    = _format_moods(_analysis.get("mood_distribution", {}))

	# Button labels
	restart_button.text = "RESTART RUN"
	exit_button.text    = "EXIT GAME"

	# Animate in
	_play_reveal()


func _play_reveal() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_EXPO)
	tw.set_ease(Tween.EASE_OUT)

	# 1 – Title slams in
	tw.tween_property(outcome_label, "modulate:a", 1.0, 0.25).set_delay(0.05)

	# 2 – Director quote fades
	tw.tween_property(director_quote, "modulate:a", 1.0, 0.35).set_delay(0.15)

	# 3 – Stats cards rise in together
	tw.tween_property(stats_row, "modulate:a", 1.0, 0.35).set_delay(0.2)

	# 4 – Bottom panels
	tw.tween_property(bottom_row, "modulate:a", 1.0, 0.35).set_delay(0.2)

	# 5 – Buttons
	tw.tween_property(button_row, "modulate:a", 1.0, 0.3).set_delay(0.2)


# ─── Text helpers ────────────────────────────────────────────────────────────

func _build_summary_text() -> String:
	var skill:      float = float(_analysis.get("final_skill",      0.0))
	var stress:     float = float(_analysis.get("final_stress",     0.0))
	var confidence: float = float(_analysis.get("final_confidence", 0.0))
	return "Skill %.2f  ·  Stress %.2f  ·  Confidence %.2f" % [skill, stress, confidence]


func _calculate_final_score() -> float:
	var kills:      float = float(_analysis.get("kills",      0))
	var accuracy:   float = float(_analysis.get("accuracy",   0.0))
	var difficulty: float = float(_analysis.get("highest_difficulty", 1.0))
	return (kills * 100.0) + (accuracy * 250.0) + (difficulty * 150.0)


func _estimate_waves_cleared() -> int:
	return maxi(1, int(_analysis.get("kills", 0) / 3))


func _format_moods(moods: Dictionary) -> String:
	if moods.is_empty():
		return "CALM"
	var parts: Array[String] = []
	for key in moods.keys():
		parts.append("%s  %d" % [String(key).to_upper(), int(moods[key])])
	return "\n".join(parts)


func _pick_director_quote() -> String:
	if _victory:
		return "Target eliminated. Performance logged."
	var kills: int = int(_analysis.get("kills", 0))
	if kills == 0:
		return "No engagements recorded. The Director is watching."
	return "You were eliminated. Reviewing engagement data."


# ─── Button handlers (unchanged) ─────────────────────────────────────────────

func _on_restart_pressed() -> void:
	GameManager.restart_run()


func _on_exit_pressed() -> void:
	get_tree().quit()