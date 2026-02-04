class_name HoldNote extends Sprite2D

@export var body: Sprite2D
@export var end: Sprite2D

var type :StringName = &"hold"
var time :float = 0.0       ## 打击时机
var track :int = 0          ## 在哪条轨道上
var end_time :float = 0.0   ## hold的持续时间
var hited :bool = false
var holding :bool = false
