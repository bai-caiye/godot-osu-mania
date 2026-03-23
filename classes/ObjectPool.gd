class_name ObjectPool extends Node2D
## 对象池V1 预创建对象循环复用减少开销 仅支持最大容量限制

@export_group("Settings")
@export var object_scene: PackedScene                     ## 要创建的对象的场景
@export_range(10, 1000) var pool_size: int = 10:          ## 初始对象池大小
	set(value): pool_size = clampi(value,10 ,1000)
@export_range(100, 10000) var max_pool_size: int = 1000:  ## 最大对象数量
	set(value): max_pool_size = clampi(value,pool_size ,10000)

var nodes: Array[Node2D] = []         ## 所有对象
var idle_pool: Array[Node2D] = []     ## 空闲对象池

## 初始化对象池并把自己注册到管理器名单
func _ready() -> void:
	if !object_scene: assert(false, name + "对象池没有要生成的场景") ;return
	
	# 如果对象池管理器不在全局就不注册名单
	var PoolManager :Node = get_node_or_null("/root/PoolManager")
	if PoolManager: PoolManager.register_object_pool(self)
	init_pool()

## 在节点离开树前注销名单
func _exit_tree() -> void:
	# 如果对象池管理器不在全局就不用注销名单
	var PoolManager :Node = get_node_or_null("/root/PoolManager")
	if PoolManager: PoolManager.unregister_object_pool(self)
	clear_pool()


## 初始化对象池
func init_pool() -> void:
	if idle_pool.size() != nodes.size(): printerr("%s对象池占用无法初始化" % name); return
	clear_pool()
	for i in range(pool_size):
		idle_pool.append(_create_node())
	
func _create_node() -> Node2D:
	var node: Node2D = object_scene.instantiate()
	node.visible = false
	node.process_mode = PROCESS_MODE_DISABLED
	node.set_physics_process(false)
	add_child(node)
	nodes.append(node)
	return node

func clear_pool() -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	idle_pool.clear()
	nodes.clear()

func acquire_object() -> Node2D:
	var node: Node2D
	
	if idle_pool.is_empty():
		if nodes.size() >= max_pool_size:printerr("%s对象池超出最大限制" % name);return null
		node = _create_node()
	else:
		node = idle_pool.pop_back()
		assert(is_instance_valid(node), "对象池中存在无效对象")
	
	node.visible = true
	node.process_mode = PROCESS_MODE_ALWAYS
	node.set_physics_process(true)
	
	return node

func recycle_object(node: Node2D) -> void:
	node.visible = false
	node.process_mode = PROCESS_MODE_DISABLED
	node.set_physics_process(false)
	
	if node.has_method("recycle_init"):
		node.recycle_init()

func recycle_all_object() -> void:
	for node in nodes:
		recycle_object(node)

func free_object(node: Node) -> void:
	recycle_object(node)
	nodes.erase(node)
	idle_pool.erase(node)
	
	if is_instance_valid(node):
		node.queue_free()
