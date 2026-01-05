extends ColorRect

@export var music: AudioStreamPlayer
var length :float = 0.0

func _physics_process(_delta: float) -> void:
	if music.stream != null:
		size.x = music.get_playback_position() / length * 1920.0
