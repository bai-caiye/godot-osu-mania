class_name ObjectPool extends Node2D
## 对象池V1 预创建对象循环复用 支持最大容量限制

@export_range(1, 80) var pool_size: int = 10              ## 初始对象池大小
@export_range(100, 1000) var max_pool_size: int = 1000    ## 最大对象数量
@export var object_scene: PackedScene                     ## 要创建的对象的场景

var pool: Array[Node2D] = []           ## 空闲对象池
var total_objects :int = 0             ## 当前对象总数(含使用中)

## 初始化对象池并把自己注册到管理器名单
func _ready() -> void:
	if !object_scene: assert(false, name + " 对象池没有要创建的对象") ;return
	if pool_size < 0: assert(false, name + " 对象池大小不能小于 0") ;return
	if max_pool_size < pool_size: assert(false, name + " 最大容量不能小于初始容量") ;return
	
	if is_instance_valid(PoolManager):
		PoolManager.register_object_pool(self)
	init_pool()

## 在节点离开树前注销名单
func _exit_tree() -> void:
	if is_instance_valid(PoolManager):
		PoolManager.unregister_object_pool(self)


## 初始化对象池
func init_pool() -> void:
	clear_pool()
	pool.resize(pool_size)
	for i in range(pool_size):
		var node: Node2D = object_scene.instantiate()
		node.visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(node)
		pool[i] = node
	total_objects = pool_size

## 清空对象池(释放所有对象)
func clear_pool() -> void:
	pool.clear()
	for child in get_children():
		child.queue_free()
	total_objects = 0


## 获取一个对象
func acquire_object() -> Node2D:
	var node: Node2D
	if pool.is_empty():
		if total_objects < max_pool_size:
			node = object_scene.instantiate()
			add_child(node)
			total_objects += 1
		else: return null
	else:
		node = pool.pop_back()
	
	node.visible = true
	node.process_mode = PROCESS_MODE_INHERIT
	return node

## 回收一个对象
func recycle_object(node: Node2D) -> void:
	if !is_instance_valid(node): return
	
	node.visible = false
	node.process_mode = PROCESS_MODE_DISABLED
	node.position = Vector2.ZERO
	node.scale = Vector2.ONE
	node.modulate = Color.WHITE
	
	pool.push_back(node)


## 回收全部对象
func recycle_objects() -> void:
	for node in get_children():
		if node is Node2D and not pool.has(node):
			recycle_object(node)
		
