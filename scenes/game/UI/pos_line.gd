extends ColorRect

func init() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT

func reset() -> void:
	modulate = Color.WHITE
	modulate.a = 1
	position.x = 0

func _physics_process(delta: float) -> void:
	modulate.a -= 0.10 * delta
	if modulate.a <= 0.0:
		queue_free()
