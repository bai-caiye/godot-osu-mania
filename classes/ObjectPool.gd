class_name ObjectPool extends Node2D
#region 说明注释
## 对象池 预创建对象循环复用减少开销
##
## 提前创建大量节点实例 要用的时候拿出 不用的时候放回并[b]重置[/b]节点  这样做的好处是 [b]减少高频创建和销毁的性能开销[/b] 循环利用已有节点[br][br]
## 如果自动加载里有 [param PoolManager] 那么 [param ObjectPool] 将会把自己[b]注册[/b]到 [param PoolManager] 的对象池名单  这样你就可以在任何地方获取到这个 [param ObjectPool]了[br][br]
## 当对象池被释放也就是他[b]离开场景树[/b]的时候 会自己[b]注销[/b] [param PoolManager] 的对象池名单上自己的名字[br][br]
##
## [b]使用方法:[/b][br]
## 在场景里添加 [param ObjectPool] 并[b]设置好需要大量生成的节点场景[/b]并在脚本中获得 [param ObjectPool][br]
## 有很多种方法可以获取 [param ObjectPool][br][br]
##
## 你可以直接在节点树里按 [code]Alt[/code] 拖动到脚本里松手获取 ( 推荐也最简单稳定快速 )
## [codeblock]
## @export var human_pool: ObjectPool
## [/codeblock]
##
## 通过自动加载的 [param PoolManager] 获取 找的是 [member ObjectPool] 节点的 [member Node.name]
## [codeblock]
## var human_pool: ObjectPool = PoolManager.get_object_pool(&"HumanPool")
## [/codeblock]
##
## 最好把要生成节点的脚本里加上[code]reset[/code]方法用来重置关键变量
## [codeblock]
## # 要大量创建节点的脚本里
## var value :int = 100
## 
## # 使用完后value可能就不是100了 需要重置
## func reset() -> void:
##     position = Vector2.ZERO
##     value = 100
## [/codeblock]
## 将创建节点实例和释放节点的方法 [method queue_free] [b]替换[/b]成 [method acquire_node] 和 [method recycle_node]
## [codeblock]
## # 需要使用时从 human_pool 里获取一个节点
## var human :Node2D = human_pool.acquire_node()
## 
## # 进行使用
## my.value += human.value
## 
## # 使用完后把节点放回 human_pool
## human_pool.recycle_node()
## [/codeblock]
#endregion

@export_group("Settings")
@export var scene: PackedScene                              ## 要实例化的场景资源
@export_range(10, 1000) var pool_size: int = 50             ## 对象池的初始大小。启动时会预创建这么多实例。
@export_range(1000, 10000) var max_pool_size: int = 1000    ## 对象池的最大容量限制。当池内对象总数（空闲+活跃）超过此值时，新取出的对象将不再回收到池中。

@export_subgroup("More Settings")
@export var enable_limit :bool = false                      ## 启用取出限制[br][b]提示[/b]: 一帧内大量取出会卡死如果你想避免这样的情况请启用
@export var enable_decay :bool = true                       ## 如果为 [code]true[/code]，会创建定时器自动释放超出 [member pool_size] 的多余空闲节点。
@export_range(0.1, 10.0) var decay_interval :float = 1.0    ## 衰减检查的间隔时间 (秒)。每隔此时间释放一个超出初始大小的空闲节点。

var pool: Array[Node] = []                                  ## [b]对象池[/b] 存储空闲节点实例的队列

## 活跃对象字典。键为当前被取出使用的节点，值为 [code]true[/code]。
## 使用字典而非数组是为了 [method has] 判断的时间复杂度为 O(1)。
var active_nodes :Dictionary[Node, bool] = {}


# 初始化对象池并把自己注册到管理器名单
func _ready() -> void: 
	assert(scene, name + "对象池没有要生成的场景")
	assert(max_pool_size > pool_size, "池最大容量不能小于初始大小")
	
	# 如果对象池管理器不在全局就不注册名单
	var PoolManager :Node = get_node_or_null("/root/PoolManager")
	if PoolManager: PoolManager.register_pool_list(self)
	init_pool(true)
	
	if !enable_decay: return
	
	# 创建一个计时器用来释放多余对象
	var timer: Timer = Timer.new()
	timer.wait_time = decay_interval
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	add_child(timer)
	
	# 绑定虚方法实现定时释放
	timer.timeout.connect(
	func():
		if get_pool_size() > pool_size and !pool.is_empty():
			var node :Node = pool.pop_back()
			node.queue_free()
		)
	timer.start()


# 在节点离开场景树前注销名单并清空对象池
func _exit_tree() -> void:
	# 如果对象池管理器不在全局就不用注销名单
	var PoolManager :Node = get_node_or_null("/root/PoolManager")
	if PoolManager: PoolManager.unregister_pool_list(self)
	clear_pool()


## 初始化对象池
func init_pool(slow_create :bool = false) -> void:
	clear_pool()
	var tree := get_tree()
	for i in pool_size:
		pool.append(_create_node())
		if slow_create and i % 10 == 0:
			await tree.process_frame


## 创建一个节点实例 节点初始状态为禁用和隐藏
func _create_node() -> Node:
	var node: Node = scene.instantiate()
	node.set_meta(&"parent_pool", self.name)     # 这个主要是给PoolCreator用的 如果不用的话可注释掉 性能会更好
	node.visible = false
	node.process_mode = PROCESS_MODE_DISABLED
	node.set_physics_process(false)
	add_child(node)
	return node


## 清空对象池  释放所有空闲和活跃的节点
func clear_pool() -> void:
	for node in active_nodes:
		node.queue_free()
	active_nodes.clear()
	for node in pool:
		node.queue_free()
	pool.clear()


## 从对象池取出一个节点  
## 如果池为空将会创建新节点返回可用的节点实例[br][br]
## 如果启用 [member enable_limit] 取出限制 那如果池为空且总节点数量 大于 [member max_pool_size] 时将会返回 [code]null[/code]
func acquire_node() -> Node:
	if enable_limit and get_pool_size() >= max_pool_size: return null
	
	var node: Node = pool.pop_back()
	if !is_instance_valid(node):
		node = _create_node()
	
	if node.has_method("init"):
		node.init()    # 需要在node脚本里自行定义init方法
	else:
		node.position = Vector2.ZERO
		node.rotation = 0.0
	
	active_nodes[node] = true
	node.visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.set_physics_process(true)
	return node


## 回收一个节点 如果池大小 大于 [member max_pool_size] 将会直接把节点释放
func recycle_node(node: Node) -> void:
	assert(node not in pool, "不能回收已经在pool里的节点")
	if not active_nodes.erase(node): return      ## erase失败 = 不在活跃列表，直接返回
	
	if get_pool_size() > max_pool_size:
		node.queue_free(); return
	
	_recycle_init(node)
	pool.append(node)


## 回收所有节点 会释放超出 [member pool_size] 的节点
func recycle_all_nodes() -> void:
	var nodes :Array[Node] = active_nodes.keys()
	for node :Node in nodes:
		_recycle_init(node)
		pool.append(node)
	active_nodes.clear()
	
	while pool.size() > pool_size:
		pool.pop_back().queue_free()


## 把回收节点重置
func _recycle_init(node :Node) -> void:
	node.visible = false
	node.process_mode = PROCESS_MODE_DISABLED
	node.set_physics_process(false)
	
	if node.has_method("reset"):
		node.reset()    # 需要在node脚本里自行定义reset方法
	else:
		node.position = Vector2.ZERO
		node.rotation = 0.0


## 获取对象池的总节点数量 (在池节点 + 活跃节点)
func get_pool_size() -> int:
	return pool.size() + active_nodes.size()
