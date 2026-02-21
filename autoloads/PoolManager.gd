extends Node
## 用于管理和获取所有对象池的全局节点

## 对象池名单 储存所有对象池指针用于获取地址 {池名 : ObjectPool实例}
var object_pools :Dictionary[StringName, ObjectPool] = {}

## 注册对象池名单
func register_object_pool(object_pool :ObjectPool) -> void:
	if object_pools.has(object_pool.name):
		push_warning("同名对象池已存在") ;return
	object_pools[object_pool.name] = object_pool

## 注销对象池名单
func unregister_object_pool(object_pool :ObjectPool) -> void:
	object_pools.erase(object_pool.name)

## 以名称获取对象池地址
func get_object_pool(pool_name: StringName) -> ObjectPool:
	return object_pools.get(pool_name)

## 创建对象池并添加到子级和object_pools
func create_object_pool(pool_name :StringName, pool_size :int, scene :PackedScene) -> ObjectPool:
	var object_pool :ObjectPool = ObjectPool.new()
	object_pool.name = pool_name
	object_pool.pool_size = pool_size
	object_pool.object_scene = scene
	get_tree().current_scene.add_child(object_pool)
	return object_pool
	
