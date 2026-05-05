extends Control

@export var pos_line_pool: ObjectPool

var lines :Array[Node]= []

func add_line(dt :float) -> void:
	for line in lines:
		line.modulate.a -= 0.025
	
	var node :Node = pos_line_pool.acquire_node()
	node.position.x = dt * (125.0 / 0.18)
	lines.append(node)
	if lines.size() > 50:
		pos_line_pool.recycle_node(lines.pop_front())

func init() -> void:
	pos_line_pool.recycle_all_nodes()
	lines.clear()
