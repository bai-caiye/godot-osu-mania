class_name HoldNote extends Node2D

@export var head: Sprite2D
@export var body: Sprite2D
@export var end: Sprite2D

const type :StringName = &"hold"
var time :float = 0.0       ## 打击时机
var track :int = 0          ## 在哪条轨道上
var end_time :float = 0.0   ## hold的持续时间
var hited :bool = false
var holding :bool = false:
	set(v):
		if !v and holding:
			modulate.a = 0.5
		holding = v
var released :bool = false

## 设置尾头位置更改长度
func set_length(end_pos :float, head_pos :float = head.global_position.y) -> void:
	if end_pos >= head_pos:
		visible = false
		return
	head.global_position.y = head_pos
	end.global_position.y = end_pos
	body.scale.y = (head_pos - end_pos) / 100.0


func init() -> void:
	pass


func reset() -> void:
	time = 0.0
	end_time = 0.0
	modulate = Color.WHITE
	modulate.a = 1.0
	track = -1
	visible = false
	hited = false
	holding = false
	released = false
	head.position.y = 0
	end.position.y = 0
	body.scale.y = 1
