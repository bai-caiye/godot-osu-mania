class_name ObjectPool extends Node2D
## 对象池 预创建对象循环复用减少开销 一定不要直接free对象 用free_object方法

@export_group("Settings")
@export var _object_scene: PackedScene                     ## 要创建的对象的场景
@export_range(10, 1000) var _pool_size: int = 10:          ## 初始对象池大小
	set(value): _pool_size = clampi(value,10 ,1000)
@export_range(100, 10000) var _max_pool_size: int = 1000:  ## 最大对象数量
	set(value): _max_pool_size = clampi(value,_pool_size ,10000)

@export_subgroup("Decay")
@export var _enable_decay :bool = true                     ## 启用衰减
@export_range(0.1, 10.0) var _decay_interval :float = 1.0: ## 衰减检查间隔
	set(value): _decay_interval = clampf(value,0.1 ,10.0)

var _idle_objects: Array[Node] = []    ## 空闲对象
var _active_objects :Array[Node] = []  ## 活跃对象
var _initializing :bool = false

## 初始化对象池并把自己注册到管理器名单
func _ready() -> void:
	if !_object_scene: assert(false, name + "对象池没有要生成的场景") ;return
	
	# 如果对象池管理器不在全局就不注册名单
	var PoolManager :Node = get_node_or_null("/root/PoolManager")
	if PoolManager: PoolManager.register_object_pool(self)
	init_pool()
	
	# 如果启用衰减回收就创建计时器用于回收
	if _enable_decay:
		var timer: Timer = Timer.new()
		timer.wait_time = _decay_interval
		timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
		add_child(timer)
		# 绑定虚方法实现回收
		timer.timeout.connect(func():
			if get_pool_size() > _pool_size and !_idle_objects.is_empty():
				var node :Node2D = _idle_objects.pop_back()
				node.queue_free())
		timer.start()

## 在节点离开树前注销名单
func _exit_tree() -> void:
	# 如果对象池管理器不在全局就不用注销名单
	var PoolManager :Node = get_node_or_null("/root/PoolManager")
	if PoolManager: PoolManager.unregister_object_pool(self)
	clear_pool()

## 初始化对象池 
func init_pool() -> void:
	if !_active_objects.is_empty(): printerr("%s对象池占用无法初始化" % name); return
	_initializing = true
	clear_pool()
	for i in range(_pool_size):
		var node: Node = _object_scene.instantiate()
		node.set_meta(&"father_pool", self)
		node.visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(node)
		_idle_objects.append(node)
	_initializing = false

## 释放池所有对象
func clear_pool() -> void:
	recycle_all_object()
	for node in _idle_objects.duplicate():
		node.queue_free()
	_idle_objects.clear()

## 获取对象池大小
func get_pool_size() -> int:
	return _idle_objects.size() + _active_objects.size()

## 获取一个对象 初始化对象属性 需要在对象的脚本手动填写acquire_init方法
func acquire_object() -> Node:
	if _initializing :printerr("%s对象池初始化中不可用" % name) ;return null
	
	var node: Node
	if _idle_objects.is_empty():
		if get_pool_size() >= _max_pool_size: printerr("%s对象池超出最大限制" % name) ;return null
		node = _object_scene.instantiate()
		node.set_meta(&"father_pool", self)
		add_child(node)
	else:
		node = _idle_objects.pop_back()
	
	node.visible = true
	node.process_mode = PROCESS_MODE_INHERIT
	if node.has_method("acquire_init"): node.acquire_init()
	
	_active_objects.append(node)
	return node

## 回收一个对象 初始化对象属性 需要在对象的脚本手动填写recycle_init方法
func recycle_object(node: Node) -> void:
	if _initializing :printerr("%s对象池初始化中不可用" % name) ;return
	# 如果回收节点无效或不属于这个对象池就返回
	if !is_instance_valid(node) or node.get_meta(&"father_pool", null) != self: return
	
	node.visible = false
	node.process_mode = PROCESS_MODE_DISABLED
	if node.has_method("recycle_init"): node.recycle_init()
	
	_active_objects.erase(node)
	_idle_objects.append(node)

## 回收全部对象
func recycle_all_object() -> void:
	for node in _active_objects.duplicate():
		node.visible = false
		node.process_mode = PROCESS_MODE_DISABLED
		if node.has_method("recycle_init"): node.recycle_init()
		_idle_objects.append(node)
	_active_objects.clear()

## 释放对象 一定不要直接free用这个
func free_object(node :Node) -> void:
	if node.get_meta(&"father_pool", null) != self: return
	node.queue_free()
	_idle_objects.erase(node)
	_active_objects.erase(node)
