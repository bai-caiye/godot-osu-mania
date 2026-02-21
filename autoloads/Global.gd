extends Node
## 全局设置

@export var speed :float = 1800.0  ## 整体速度
@export var offset :float = 0.0    ## 整体偏移

## 键位映射
var key_binding :Dictionary = {
	4: {KEY_D:0, KEY_F:1, KEY_J:2, KEY_K:3},
	6: {KEY_S:0, KEY_D:1, KEY_F:2, KEY_J:3, KEY_K:4, KEY_L:5},
	7: {KEY_S:0, KEY_D:1, KEY_F:2, KEY_SPACE:3, KEY_J:4, KEY_K:5, KEY_L:6},
}

var full_screen :bool =false
func _unhandled_key_input(event: InputEvent) -> void:
	if event.keycode == KEY_F11 and event.pressed and !event.is_echo():
		full_screen = !full_screen
		DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if full_screen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, full_screen)
