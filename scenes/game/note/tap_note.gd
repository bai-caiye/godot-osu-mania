class_name TapNote extends Sprite2D

const type :StringName = &"tap"
var time :float = 0.0       ## 打击时机
var track :int = 0          ## 在哪条轨道上
var hited :bool = false

func _recycle_init() -> void:
	visible = false
	hited = false
