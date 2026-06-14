extends Node
## Placeholder audio event bridge. No assets yet, just structured hooks.

var _last_audio_event: String = ""


func _ready() -> void:
	EventBus.audio_event_requested.connect(_on_audio_event_requested)


func _on_audio_event_requested(event_name: String) -> void:
	_last_audio_event = event_name
	EventBus.session_event.emit("audio_event", {"name": event_name})
