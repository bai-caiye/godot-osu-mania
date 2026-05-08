extends Control

@export var pos_line_pool: ObjectPool

func add_line(dt :float, color :int) -> void:
	var node :Control = pos_line_pool.acquire_node()
	match color:
		0: node.modulate = Color(0.18, 0.891, 1.0, 1.0)
		1: node.modulate = Color(0.18, 0.891, 1.0, 1.0)
		2: node.modulate = Color(0.104, 0.87, 0.283, 1.0)
		3: node.modulate = Color(0.104, 0.87, 0.283, 1.0)
		4: node.modulate = Color(0.76, 0.564, 0.289, 1.0)
		5: node.modulate = Color(0.63, 0.076, 0.076, 1.0)
	node.modulate.a = 0.6
	node.position.x = snapped(clampf(dt, -0.18, 0.18) / 0.18, 0.001) * 125.0 

func init() -> void:
	pos_line_pool.recycle_all_nodes()
