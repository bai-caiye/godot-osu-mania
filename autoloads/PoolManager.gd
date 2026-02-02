extends Node
## 用于管理和获取所有对象池的全局节点


## 对象池名单 储存所有对象池指针用于获取
var object_pools :Dictionary[StringName, Node2D]

## 注册对象池名单
func register_object_pool(object_pool :Node2D) -> void:
	object_pools[object_pool.name] = object_pool

## 注销对象池名单
func unregister_object_pool(object_pool :Node2D) -> void:
	object_pools[object_pool.name] = object_pool

## 以名称获取对象池
func get_object_pool(pool_name :StringName) -> Node2D:
	if !object_pools.has(pool_name):
		return null
	return object_pools[pool_name]

## 创建对象池并添加到子级和object_pools
