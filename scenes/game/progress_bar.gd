extends ColorRect

@export var music: AudioStreamPlayer
var length :float = 0.0:
	set(v):
		if music.stream == null: return
		length = v
		set_physics_process(true)

func _physics_process(_delta: float) -> void:
	scale.x = music.get_playback_position() / length
	if scale.x >= 1.0: set_physics_process(false)
