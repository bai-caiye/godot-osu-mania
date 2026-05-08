extends Control

@export var pos_line_pool: ObjectPool

var lines :Array[Node]= []

func add_line(dt :float, color :int) -> void:
	for line in lines:
		line.modulate.a -= 0.025
		line.modulate.v -= 0.05
	
	var node :Control = pos_line_pool.acquire_node()
	match color:
		0: node.modulate = Color(1.0, 0.967, 0.5, 1.0)
		1: node.modulate = Color(0.91, 0.869, 0.291, 1.0)
		2: node.modulate = Color(0.104, 0.87, 0.283, 1.0)
		3: node.modulate = Color(0.27, 0.72, 1.0, 1.0)
		4: node.modulate = Color(0.78, 0.187, 0.671, 1.0)
		5: node.modulate = Color(0.85, 0.221, 0.221, 1.0)
	node.modulate.v = 1.5
	node.position.x = snapped(clampf(dt, -0.18, 0.18) / 0.18, 0.001) * 125.0 
	lines.append(node)
	if lines.size() > 50:
		pos_line_pool.recycle_node(lines.pop_front())

func init() -> void:
	pos_line_pool.recycle_all_nodes()
	lines.clear()
