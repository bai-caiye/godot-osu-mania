extends Node
## 全局设置

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

var full_screen :bool =false
func _unhandled_key_input(event: InputEvent) -> void:
	
	if event.keycode == KEY_F11 and event.pressed and !event.is_echo():
		full_screen = !full_screen
		DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if full_screen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, full_screen)
