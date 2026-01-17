extends MeshInstance2D
class_name Note
var type :int = 0           ## note类型
var time :float = 0.0       ## 打击时机
var track :int = 0          ## 在哪条轨道上
var hitting :bool = false   ## 是否被击中
var end_time :float = 0.0   ## hold的持续时间
