extends Node
## 对象池管理器[br][br]
## 用于管理和获取所有对象池的全局单例节点。[br]
## 提供创建、注册、获取对象池的统一接口。[br][br]
## [b]注意：[/b] 需要在项目设置的自动加载中注册为全局单例（建议命名为 [code]PoolManager[/code]）


## 对象池名单[br][br]
## 存储所有已注册的对象池实例，格式为 [code]{池名: ObjectPool实例}[/code]
var pool_name_list :Dictionary[StringName, ObjectPool] = {}


## 创建pool实例并初始化
func _init_pool_instance(
	pool_name: StringName,
	scene: PackedScene,
	pool_size: int,
	max_pool_size: int,
	enable_limit: bool,
	enable_decay: bool,
	decay_interval: float
	) -> ObjectPool:
	
	assert(!pool_name_list.has(pool_name), "%s同名对象池已存在" % pool_name)
	var object_pool: ObjectPool = ObjectPool.new()
	object_pool.name = pool_name
	object_pool.scene = scene
	object_pool.pool_size = pool_size
	object_pool.max_pool_size = max_pool_size
	object_pool.enable_limit = enable_limit
	object_pool.enable_decay = enable_decay
	object_pool.decay_interval = decay_interval
	return object_pool


## 创建对象池并添加到全局[br][br]
## [param pool_name] 对象池的唯一标识名称[br]
## [param scene] 要池化的场景资源[br]
## 参数更具体用处请看 [ObjectPool] 的文档
## [b]注意：[/b] 同名对象池已存在时会触发断言错误
func create_pool_add_global(
		pool_name :StringName, 
		scene :PackedScene, 
		pool_size :int = 10, 
		max_pool_size :int = 1000,
		enable_limit :bool = false,
		enable_decay :bool = false,
		decay_interval :float = 1.0,
	) -> ObjectPool:
	
	assert(!pool_name_list.has(pool_name), "%s同名对象池已存在" % pool_name)
	var object_pool :ObjectPool = _init_pool_instance(
		pool_name, 
		scene, 
		pool_size, 
		max_pool_size,
		enable_limit,
		enable_decay,
		decay_interval,
	)
	add_child(object_pool)
	return object_pool


## 创建对象池并添加到当前场景树 会随着场景切换释放[br][br]
## [param pool_name] 对象池的唯一标识名称[br]
## [param scene] 要池化的场景资源[br]
## 参数更具体用处请看 [ObjectPool] 的文档
## [b]注意：[/b] 同名对象池已存在时会触发断言错误
func create_pool_add_tree(
		pool_name :StringName, 
		scene :PackedScene, 
		pool_size :int = 10, 
		max_pool_size :int = 1000,
		enable_limit :bool = false,
		enable_decay :bool = false,
		decay_interval :float = 1.0,
	) -> ObjectPool:
	assert(!pool_name_list.has(pool_name), "%s同名对象池已存在" % pool_name)
	
	var object_pool :ObjectPool = _init_pool_instance(
		pool_name, 
		scene, 
		pool_size, 
		max_pool_size,
		enable_limit,
		enable_decay,
		decay_interval,
	)
	get_tree().current_scene.add_child(object_pool)
	return object_pool


## 将对象池注册到管理器名单[br][br]
## [param object_pool] 要注册的对象池实例[br][br]
## [b]注意：[/b] 通常由 [ObjectPool] 自身在 [method ObjectPool._ready] 中自动调用，无需手动注册
func register_pool_list(object_pool :ObjectPool) -> void:
	assert(!pool_name_list.has(object_pool.name), "%s同名对象池已存在" % object_pool.name)
	pool_name_list[object_pool.name] = object_pool


## 从管理器名单中注销对象池[br][br]
## [param object_pool] 要注销的对象池实例[br][br]
## [b]注意：[/b] 通常由 [ObjectPool] 自身在 [method ObjectPool._exit_tree] 中自动调用，无需手动注销
func unregister_pool_list(object_pool :ObjectPool) -> void:
	pool_name_list.erase(object_pool.name)


## 通过名称获取对象池实例[br][br]
## 返回找到的对象池实例，如果不存在则返回 [code]null[/code]。[br][br]
## [param pool_name] 对象池的名称
func get_object_pool(pool_name: StringName) -> ObjectPool:
	return pool_name_list.get(pool_name)


## 获取所有已注册对象池的名称列表[br][br]
## 返回包含所有对象池名称的数组
func get_pool_names() -> Array:
	return pool_name_list.keys()
