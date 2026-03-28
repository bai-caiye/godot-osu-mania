class_name ObjectPool extends Node2D
## 对象池 预创建对象循环复用减少开销

@export_group("Settings")
@export var object_scene: PackedScene                     ## 要创建的对象的场景
@export_range(10, 1000) var pool_size: int = 10:          ## 初始对象池大小
	set(value):
		pool_size = clampi(value,10 ,1000)

@export_range(100, 10000) var max_pool_size: int = 1000:  ## 最大对象数量
	set(value):
		max_pool_size =clampi(value,pool_size ,10000)

var nodes: Array[Node2D] = []         ## 所有对象
var idle_pool: Array[Node2D] = []     ## 空闲对象

## 初始化对象池并把自己注册到管理器名单
func _ready() -> void:
	assert(object_scene, name + "对象池没有要生成的场景")
	
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
	recycle_all_nodes()
	clear_pool()
	for i in range(pool_size):
		idle_pool.append(_create_node())
	

## 创建一个对象
func _create_node() -> Node2D:
	var node: Node2D = object_scene.instantiate()
	node.set_meta(&"father_pool", self)
	node.visible = false
	node.process_mode = PROCESS_MODE_DISABLED
	node.set_physics_process(false)
	add_child(node)
	nodes.append(node)
	return node


## 清空对象池 释放所有节点
func clear_pool() -> void:
	idle_pool.clear()
	
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	nodes.clear()


## 取出一个节点
func acquire_node() -> Node2D:
	var node: Node2D
	if idle_pool.is_empty():
		if nodes.size() >= max_pool_size:
			printerr("%s对象池超出最大限制" % name)
			return null
		node = _create_node()
	else:
		node = idle_pool.pop_back()
	
	node.visible = true
	node.process_mode = PROCESS_MODE_ALWAYS
	node.set_physics_process(true)
	
	return node


## 回收一个节点
func recycle_node(node: Node2D) -> void:
	node.visible = false
	node.process_mode = PROCESS_MODE_DISABLED
	node.set_physics_process(false)
	
	node.recycle_init()
	idle_pool.append(node)


## 回收所有节点
func recycle_all_nodes() -> void:
	for node in nodes:
		node.visible = false
		node.process_mode = PROCESS_MODE_DISABLED
		node.set_physics_process(false)
		node.recycle_init()
		idle_pool.append(node)


## 释放节点
func free_node(node: Node2D) -> void:
	nodes.erase(node)
	idle_pool.erase(node)
	node.queue_free()


## 获取池所有节点数量
func get_pool_size() -> int:
	return nodes.size()
