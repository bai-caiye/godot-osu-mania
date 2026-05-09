extends Node
## 玩家设置

@export_range(10.0, 10000.0) var speed: float = 1500   ## 整体速度
@export_range(-1.0, 1.0) var offset: float = 0.0       ## 整体偏移

## 键位映射
var key_binding :Dictionary = {
	1: {KEY_SPACE:0},
	2: {KEY_F:0, KEY_J:1},
	3: {KEY_F:0, KEY_SPACE:1, KEY_J:2},
	4: {KEY_D:0, KEY_F:1, KEY_J:2, KEY_K:3},
	5: {KEY_D:0, KEY_F:1, KEY_SPACE:3, KEY_J:4, KEY_K:5},
	6: {KEY_S:0, KEY_D:1, KEY_F:2, KEY_J:3, KEY_K:4, KEY_L:5},
	7: {KEY_S:0, KEY_D:1, KEY_F:2, KEY_SPACE:3, KEY_J:4, KEY_K:5, KEY_L:6},
	8: {KEY_A:0, KEY_S:1, KEY_D:2, KEY_F:3, KEY_J:4, KEY_K:5, KEY_L:6, KEY_SEMICOLON:7},
	10:{KEY_A:0, KEY_S:1, KEY_D:2, KEY_F:3, KEY_V:4, KEY_N:5, KEY_J:6, KEY_K:7, KEY_L:8, KEY_SEMICOLON:9},
}
