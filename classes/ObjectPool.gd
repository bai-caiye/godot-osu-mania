class_name ObjectPool extends Node2D
## 对象池 预创建对象循环复用减少开销 简化阉割版

@export_group("Settings")
@export var scene: PackedScene                              ## 要实例化的场景资源
@export_range(10, 1000) var pool_size: int = 50             ## 对象池的初始大小 启动时会预创建这么多实例
@export_range(1000, 10000) var max_pool_size: int = 1000    ## 对象池的最大容量限制 当池内对象总数（空闲+活跃）超过此值时 新取出的对象将不再回收到池中
@export_subgroup("Decay")
@export var enable_decay :bool = true                       ## 如果为 [code]true[/code] 会创建定时器自动释放超出 [member pool_size] 的多余空闲节点
@export_range(0.1, 10.0) var decay_interval :float = 1.0    ## 衰减检查的间隔时间 (秒) 每隔此时间释放一个超出初始大小的空闲节点

var pool: Array[Node2D] = []                                  ## [b]对象池[/b] 存储空闲节点实例的队列

## 活跃对象字典 键为当前被取出使用的节点 值为 [code]true[/code]
## 使用字典而非数组是为了 [method has] 判断的时间复杂度为 O(1)
var active_nodes :Dictionary[Node2D, bool] = {}


# 初始化对象池并把自己注册到管理器名单
func _ready() -> void: 
	if !enable_decay: return
	
	# 创建一个计时器用来释放多余对象
	var timer: Timer = Timer.new()
	timer.wait_time = decay_interval
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	add_child(timer)
	# author baicaiye
	# 绑定虚方法实现定时释放
	timer.timeout.connect(
	func():
		if get_pool_size() > pool_size and !pool.is_empty():
			var node = pool.pop_back()
			if is_instance_valid(node): node.queue_free()
		)
	timer.start()


## 初始化对象池 [member slow_create] 是否启用慢加载
func init_pool(slow_create :bool = false) -> void:
	clear_pool()
	var tree := get_tree()
	for i in pool_size:
		pool.append(_create_node())
		if slow_create and i % 10 == 0:
			await tree.process_frame


# 创建一个节点实例 节点初始状态为禁用和隐藏
func _create_node() -> Node2D:
	var node: Node2D = scene.instantiate()
	node.visible = false
	node.process_mode = PROCESS_MODE_DISABLED
	node.set_physics_process(false)
	add_child(node)
	return node


## 清空对象池 释放所有空闲和活跃的节点
func clear_pool() -> void:
	for node in active_nodes:
		if is_instance_valid(node): node.queue_free()
	active_nodes.clear()
	for node in pool:
		if is_instance_valid(node): node.queue_free()
	pool.clear()


## 从对象池取出一个节点  如果池为空将会创建新节点返回可用的节点实例[br][br]
## 如果启用 [member enable_limit] 取出限制 那如果池为空且总节点数量 大于 [member max_pool_size] 时将会返回 [code]null[/code]
## [br][br]如果 [member mode] 是 [enum Mode.DYNAMIC] 模式就会把取出的节点添加到 [member add_to] 节点下
func acquire_node() -> Node2D:
	var node = pool.pop_back()
	if !is_instance_valid(node): node = _create_node()
	
	active_nodes[node] = true
	node.visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.set_physics_process(true)
	return node


## 回收一个节点 如果池大小 大于 [member max_pool_size]
func recycle_node(node: Node2D) -> void:
	if not active_nodes.erase(node): return
	
	if get_pool_size() > max_pool_size:
		node.queue_free(); return
	
	_recycle_reset(node)
	pool.append(node)


## 回收所有节点 会释放超出 [member pool_size] 的节点 且清除在 [member active_nodes] 的无效节点
func recycle_all_nodes() -> void:
	for node :Node2D in active_nodes.keys():
		if !is_instance_valid(node): continue
		_recycle_reset(node)
		pool.append(node)
	active_nodes.clear()
	
	while pool.size() > pool_size:
		pool.pop_back().queue_free()


# 把回收节点重置
func _recycle_reset(node :Node2D) -> void:
	node.visible = false
	node.process_mode = PROCESS_MODE_DISABLED
	node.set_physics_process(false)
	node.reset()    # 需要在node脚本里自行定义reset方法


## 释放该池节点 用于避免自行 [method queue_free] 导致无效节点遗留在列表造成计数错误
func free_node(node :Node) -> void:
	active_nodes.erase(node)
	if is_instance_valid(node): node.queue_free()


## 获取对象池的总节点数量 (在池节点 + 活跃节点)
func get_pool_size() -> int:
	return pool.size() + active_nodes.size()
# author baicaiye
