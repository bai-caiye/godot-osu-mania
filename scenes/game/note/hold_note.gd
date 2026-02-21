class_name HoldNote extends Node2D

@export var head: Sprite2D
@export var body: Sprite2D
@export var end: Sprite2D

var type :StringName = &"hold"
var time :float = 0.0       ## 打击时机
var track :int = 0          ## 在哪条轨道上
var end_time :float = 0.0   ## hold的持续时间
var hited :bool = false
var holding :bool = false

## 设置尾头位置更改长度
func set_length(end_pos :float, head_pos :float = head.global_position.y) -> void:
	head.global_position.y = head_pos
	end.global_position.y = end_pos
	body.scale.y = (head_pos - end_pos) / 100.0
