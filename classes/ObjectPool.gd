class_name ObjectPool extends MultiMeshInstance2D
## 对象池

@export var pool_size :int = 10       ## 对象池的大小
@export var object_scene :PackedScene   ## 要实例化的对象的场景

var pool :Array[Node]

## 初始化对象池并把自己注册到管理器名单
func _ready() -> void:
	PoolManager.register_object_pool(self)
	for i in pool_size:
		var node: Node2D = object_scene.instantiate()
		_set_objec_state(node, false)
		pool.append(node)
		add_child(node)

## 在节点释放注销
func _exit_tree() -> void:
	PoolManager.register_object_pool(self)

## 获取一个对象
func acquire_objec(spawn_position := Vector2(0, 0) , spawn_rotation :float = 0.0) -> Node2D:
	#获取第一个对象如果是被占用的就新增一个对象
	var node :Node2D = pool.front()
	if node.visible:
		node = object_scene.instantiate()
		add_child(node)
	pool.append(node)
	
	node.position = spawn_position
	node.rotation = spawn_rotation
	_set_objec_state(node, true)
	return node

## 回收一个对象
func recycle_object(node :Node2D) -> void:
	_set_objec_state(node, false)
	node.position = Vector2.ZERO
	node.rotation = 0.0
	node.modulate = Color.WHITE
	node.self_modulate = Color.WHITE

## 回收全部对象
func clear_pool() -> void:
	for node in pool:
		recycle_object(node)

## 设置对象是非启用
func _set_objec_state(node :Node2D, switch :bool) -> void:
	node.visible = switch
	node.set_process(switch)
