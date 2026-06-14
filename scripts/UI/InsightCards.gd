extends CanvasLayer
## End-of-run analysis panel showing Director learning and adaptive responses.

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var summary_label: Label = $Panel/Margin/VBox/Summary
@onready var skill_bar: ProgressBar = $Panel/Margin/VBox/SummaryGrid/SkillRow/SkillBar
@onready var stress_bar: ProgressBar = $Panel/Margin/VBox/SummaryGrid/StressRow/StressBar
@onready var confidence_bar: ProgressBar = $Panel/Margin/VBox/SummaryGrid/ConfidenceRow/ConfidenceBar
@onready var difficulty_label: Label = $Panel/Margin/VBox/SummaryGrid/DifficultyRow/DifficultyValue
@onready var accuracy_label: Label = $Panel/Margin/VBox/SummaryGrid/AccuracyRow/AccuracyValue
@onready var kills_label: Label = $Panel/Margin/VBox/SummaryGrid/KillsRow/KillsValue
@onready var mood_label: Label = $Panel/Margin/VBox/SummaryGrid/MoodRow/MoodValue
@onready var cards_box: VBoxContainer = $Panel/Margin/VBox/Cards
@onready var session_label: Label = $Panel/Margin/VBox/SessionLabel

var _analysis: Dictionary = {}


func set_analysis(analysis: Dictionary, session_path: String = "") -> void:
	_analysis = analysis.duplicate(true)
	_render(session_path)


func _ready() -> void:
	_render("")
	_apply_theme()


func _render(session_path: String) -> void:
	if _analysis.is_empty():
		return

	title_label.text = "Run Analysis"
	summary_label.text = "The Director studied the run, adapted to patterns, and recorded the result."
	session_label.text = "Session: %s" % (session_path if session_path != "" else String(_analysis.get("session_id", "")))

	var final_skill: float = float(_analysis.get("final_skill", 0.0))
	var final_stress: float = float(_analysis.get("final_stress", 0.0))
	var final_confidence: float = float(_analysis.get("final_confidence", 0.0))
	var highest_difficulty: float = float(_analysis.get("highest_difficulty", 1.0))
	var accuracy: float = float(_analysis.get("accuracy", 0.0))
	var kills: int = int(_analysis.get("kills", 0))
	var mood_distribution: Dictionary = _analysis.get("mood_distribution", {})

	skill_bar.value = final_skill * 100.0
	stress_bar.value = final_stress * 100.0
	confidence_bar.value = final_confidence * 100.0
	difficulty_label.text = "%.2fx" % highest_difficulty
	accuracy_label.text = "%.0f%%" % (accuracy * 100.0)
	kills_label.text = "%d" % kills
	mood_label.text = _format_moods(mood_distribution)

	for child in cards_box.get_children():
		child.queue_free()

	var cards: Array = _analysis.get("insight_cards", [])
	for card in cards:
		cards_box.add_child(_build_card(card))


func _apply_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.03, 0.05, 0.92)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.2, 0.95, 1.0, 0.22)
	$Panel.add_theme_stylebox_override("panel", panel_style)
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.8, 1.0, 1.0))
	summary_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	session_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.8))
	skill_bar.add_theme_color_override("fg_color", Color(0.2, 0.95, 1.0))
	stress_bar.add_theme_color_override("fg_color", Color(1.0, 0.4, 0.25))
	confidence_bar.add_theme_color_override("fg_color", Color(0.8, 0.3, 1.0))
	difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
	accuracy_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.8))
	kills_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	mood_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.95))


func _build_card(card: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 90)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = String(card.get("title", "Insight"))
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(title)

	var reason := Label.new()
	reason.text = String(card.get("reason", ""))
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(reason)

	var response := Label.new()
	response.text = "Director Response: %s" % String(card.get("response", ""))
	response.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(response)

	return panel


func _format_moods(moods: Dictionary) -> String:
	if moods.is_empty():
		return "No mood data"
	var parts: Array[String] = []
	for key in moods.keys():
		parts.append("%s:%d" % [String(key), int(moods[key])])
	return ", ".join(parts)
