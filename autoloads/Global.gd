extends Node

@export_global_file("*.osu") var chart_path: String
@export var auto_play :bool = false

var full_screen :bool =false
func _unhandled_key_input(event: InputEvent) -> void:
	
	if event.keycode == KEY_F11 and event.pressed and !event.is_echo():
		full_screen = !full_screen
		DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if full_screen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, full_screen)
