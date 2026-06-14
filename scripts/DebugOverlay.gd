extends CanvasLayer
## Debug overlay — live neuromorphic Director telemetry for tuning and QA.

@onready var skill_label: Label = $Panel/Margin/VBox/SkillLabel
@onready var stress_label: Label = $Panel/Margin/VBox/StressLabel
@onready var confidence_label: Label = $Panel/Margin/VBox/ConfidenceLabel
@onready var difficulty_label: Label = $Panel/Margin/VBox/DifficultyLabel
@onready var mood_label: Label = $Panel/Margin/VBox/MoodLabel
@onready var predictability_label: Label = $Panel/Margin/VBox/PredictabilityLabel
@onready var stress_snapshot_label: Label = $Panel/Margin/VBox/StressSnapshotLabel
@onready var boss_phase_label: Label = $Panel/Margin/VBox/BossPhaseLabel

var _boss_phase_cache: String = "Reaction Auditor"


func _ready() -> void:
	EventBus.director_scores_updated.connect(_on_scores_updated)
	EventBus.difficulty_changed.connect(_on_difficulty_changed)
	_refresh()


func _on_scores_updated(_skill: float, _stress: float, _confidence: float) -> void:
	_refresh()


func _on_difficulty_changed(difficulty: float) -> void:
	difficulty_label.text = "Difficulty: %.2f" % difficulty


func _refresh() -> void:
	skill_label.text = "Skill:       %.2f" % Director.skill_score
	stress_label.text = "Stress:      %.2f" % Director.stress_score
	confidence_label.text = "Confidence:  %.2f" % Director.confidence_score
	difficulty_label.text = "Difficulty:  %.2f" % Director.get_current_difficulty()
	mood_label.text = "Mood:        %s" % Director.get_current_mood()
	predictability_label.text = "Predict:     %.2f" % Director.get_predictability_score()
	stress_snapshot_label.text = "Stress Peak: %.2f" % Director.get_stress_snapshot().get("stress_peak", 0.0)
	_boss_phase_cache = _get_boss_phase()
	boss_phase_label.text = "Boss Phase:  %s" % _boss_phase_cache


func _get_boss_phase() -> String:
	if not is_inside_tree():
		return _boss_phase_cache
	var bosses: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for boss in bosses:
		if boss is Node and boss.has_method("get") and boss.get("enemy_type") == "nexus_boss":
			if boss.has_method("_get_phase_name"):
				return String(boss.call("_get_phase_name", boss.get("_boss_phase")))
	return "Reaction Auditor"
