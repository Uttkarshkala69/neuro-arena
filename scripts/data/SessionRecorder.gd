class_name SessionRecorder
extends RefCounted
## Records gameplay sessions to JSON under res://data/sessions/ (user:// at runtime).
##
## Captures director snapshots, wave events, and combat telemetry for offline
## analysis of neuromorphic adaptation behaviour.

const SESSION_DIR: String = "user://sessions/"

var _session_id: String = ""
var _start_time: int = 0
var _events: Array = []
var _active: bool = false
var _final_snapshot: Dictionary = {}
var _victory: bool = false


func begin_session() -> void:
	_session_id = "session_%s" % Time.get_datetime_string_from_system().replace(":", "-")
	_start_time = Time.get_ticks_msec()
	_events.clear()
	_final_snapshot = {}
	_victory = false
	_active = true
	record_event("session_start", {"session_id": _session_id})


func record_event(event_name: String, data: Dictionary = {}) -> void:
	if not _active:
		return
	_events.append({
		"t": Time.get_ticks_msec() - _start_time,
		"event": event_name,
		"data": data.duplicate(true),
	})


func end_session(director_snapshot: Dictionary, victory: bool) -> void:
	if not _active:
		return
	_final_snapshot = director_snapshot.duplicate(true)
	_victory = victory
	record_event("session_end", {
		"victory": victory,
		"director": director_snapshot.duplicate(true),
		"duration_ms": Time.get_ticks_msec() - _start_time,
	})
	_active = false


## Persist the session log as formatted JSON.
func save_session() -> String:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("sessions"):
		dir.make_dir("sessions")

	var payload: Dictionary = {
		"session_id": _session_id,
		"started_at_ms": _start_time,
		"events": _events,
		"analysis": build_analysis(),
	}
	var json_text: String = JSON.stringify(payload, "\t")
	var file_path: String = SESSION_DIR + _session_id + ".json"

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("SessionRecorder: could not write %s" % file_path)
		return ""
	file.store_string(json_text)
	file.close()
	return file_path


## Load a previously saved session file (for replay / analysis tools).
static func load_session(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("SessionRecorder: could not read %s" % file_path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	return {}


func build_analysis() -> Dictionary:
	var metrics := _extract_metrics()
	var cards: Array = _build_insight_cards(metrics)
	return {
		"session_id": _session_id,
		"victory": _victory,
		"final_skill": float(_final_snapshot.get("skill_score", 0.0)),
		"final_stress": float(_final_snapshot.get("current_stress", _final_snapshot.get("stress_score", 0.0))),
		"final_confidence": float(_final_snapshot.get("confidence_score", 0.0)),
		"highest_difficulty": float(metrics.get("highest_difficulty", 1.0)),
		"accuracy": float(metrics.get("accuracy", 0.0)),
		"kills": int(metrics.get("kills", 0)),
		"waves_cleared": int(metrics.get("waves_cleared", 0)),
		"mood_distribution": metrics.get("mood_distribution", {}),
		"insight_cards": cards,
	}


func _extract_metrics() -> Dictionary:
	var shots_fired: int = 0
	var shots_hit: int = 0
	var kills: int = 0
	var waves_cleared: int = 0
	var highest_difficulty: float = 0.0
	var mood_counts: Dictionary = {}
	var adaptation_events: Dictionary = {
		"boss_phase": [],
		"enemy_mode": [],
		"prediction": 0,
	}
	var movement_samples: int = 0

	for event in _events:
		if not (event is Dictionary):
			continue
		var name: String = String(event.get("event", ""))
		var data: Dictionary = event.get("data", {})
		if name == "player_shot":
			shots_fired += 1
			if bool(data.get("hit", false)):
				shots_hit += 1
		elif name == "enemy_killed":
			kills += 1
		elif name == "wave_completed":
			waves_cleared += 1
		elif name == "director_tick":
			highest_difficulty = maxf(highest_difficulty, float(data.get("current_difficulty", 0.0)))
			var mood: String = String(data.get("current_mood", "Unknown"))
			mood_counts[mood] = int(mood_counts.get(mood, 0)) + 1
		elif name == "boss_adapted":
			adaptation_events["boss_phase"].append(String(data.get("phase", "")))
		elif name == "boss_prediction_attack":
			adaptation_events["prediction"] += 1
		elif name == "enemy_behavior_mode_changed":
			adaptation_events["enemy_mode"].append(String(data.get("mode", "")))
		elif name == "player_moved":
			movement_samples += 1

	if highest_difficulty <= 0.0:
		highest_difficulty = float(_final_snapshot.get("current_difficulty", 1.0))

	return {
		"shots_fired": shots_fired,
		"shots_hit": shots_hit,
		"accuracy": 0.0 if shots_fired <= 0 else float(shots_hit) / float(shots_fired),
		"kills": kills,
		"waves_cleared": waves_cleared,
		"highest_difficulty": highest_difficulty,
		"mood_distribution": mood_counts,
		"adaptation_events": adaptation_events,
		"movement_samples": movement_samples,
	}


func _build_insight_cards(metrics: Dictionary) -> Array:
	var cards: Array = []
	var accuracy: float = float(metrics.get("accuracy", 0.0))
	var highest_difficulty: float = float(metrics.get("highest_difficulty", 1.0))
	var mood_distribution: Dictionary = metrics.get("mood_distribution", {})
	var adaptation_events: Dictionary = metrics.get("adaptation_events", {})
	var boss_phases: Array = adaptation_events.get("boss_phase", [])
	var enemy_modes: Array = adaptation_events.get("enemy_mode", [])
	var prediction_attacks: int = int(adaptation_events.get("prediction", 0))
	var final_skill: float = float(_final_snapshot.get("skill_score", 0.0))
	var final_stress: float = float(_final_snapshot.get("current_stress", _final_snapshot.get("stress_score", 0.0)))
	var final_confidence: float = float(_final_snapshot.get("confidence_score", 0.0))
	var stress_peak: float = float(_final_snapshot.get("stress_peak", 0.0))
	var predictability: float = float(_final_snapshot.get("predictability_score", 0.0))
	var waves_cleared: int = int(metrics.get("waves_cleared", 0))

	if accuracy >= 0.65:
		cards.append({
			"title": "Reaction Specialist",
			"reason": "Accuracy reached %.0f%%." % [accuracy * 100.0],
			"response": "Director raised challenge tempo to test reaction speed.",
		})

	if predictability >= 0.6 or enemy_modes.has("intercept_cutoff") or prediction_attacks > 0:
		cards.append({
			"title": "Predictable Pathfinder",
			"reason": "Repeated movement routes were detected.",
			"response": "Director and boss responded with intercept pressure.",
		})

	if final_confidence >= 0.75 or mood_distribution.get("Overclocked", 0) > 0:
		cards.append({
			"title": "High Confidence Player",
			"reason": "Confidence remained above 0.75.",
			"response": "Overclocked pressure was activated during the run.",
		})

	if stress_peak >= 0.7 or final_stress >= 0.65 or mood_distribution.get("Pressing", 0) > 0:
		cards.append({
			"title": "Stress Spike",
			"reason": "Stress exceeded the adaptive threshold.",
			"response": "Boss pressure shifted into recovery-friendly behavior.",
		})

	if highest_difficulty >= 1.4 and float(_final_snapshot.get("current_difficulty", 1.0)) >= 1.2:
		cards.append({
			"title": "Adaptive Survivor",
			"reason": "Difficulty increased from 1.0x to %.1fx." % highest_difficulty,
			"response": "The Director escalated the run as the player survived longer.",
		})

	if waves_cleared >= 4 and cards.size() < 5:
		cards.append({
			"title": "Endurance Pattern",
			"reason": "%d waves were cleared before the run ended." % waves_cleared,
			"response": "The Director sustained adaptation across a longer session.",
		})

	if cards.is_empty():
		cards.append({
			"title": "Baseline Observation",
			"reason": "The Director gathered a readable run profile.",
			"response": "Adaptive systems recorded the session for future tuning.",
		})

	return cards


func reset() -> void:
	_session_id = ""
	_start_time = 0
	_events.clear()
	_active = false
	_final_snapshot = {}
	_victory = false
