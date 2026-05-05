class_name TapNote extends Sprite2D

const type :StringName = &"tap"
var time :float = 0.0       ## 打击时机
var track :int = 0          ## 在哪条轨道上
var hited :bool = false

func init() -> void:
	pass

func reset() -> void:
	time = 0.0
	modulate = Color.WHITE
	visible = false
	hited = false
