extends Control

@export var v_box: VBoxContainer
const BUTTON := preload("res://scenes/UI/texture_button.tscn")

var cached_buttons: Dictionary = {}

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and event.keycode == KEY_ENTER:
		visible = !visible

func _ready() -> void:
	visible = false
	update_song_list()
	SongLoader.osz_loaded.connect(update_song_list)


func update_song_list() -> void:
	var current_paths: Dictionary = {}
	
	var folder_names: PackedStringArray = DirAccess.get_directories_at(SongLoader.SONGS_PATH)
	for folder_name in folder_names:
		var folder_path: String = SongLoader.SONGS_PATH.path_join(folder_name)
		var file_names: PackedStringArray = DirAccess.get_files_at(folder_path)
	
		var image: Texture2D = Texture2D.new()
		for file_name in file_names:
			if file_name.get_extension() in ["jpg", "png", "jpeg"]:
				image = SongLoader.load_image(folder_path.path_join(file_name))
				break
	
		for file_name in file_names:
			if file_name.get_extension() != "osu":
				continue
			var chart_path: String = folder_path.path_join(file_name)
			current_paths[chart_path] = true
	
			if cached_buttons.has(chart_path): 
				continue
	
			var button: TextureButton = BUTTON.instantiate()
			button.title.text = file_name
			button.chart_path = chart_path
			button.texture_normal = image
			button.pressed.connect(emit_open_beat_map.bind(button.chart_path))
			v_box.add_child(button)
			cached_buttons[chart_path] = button
	
	for path in cached_buttons.keys():
		if not current_paths.has(path):
			cached_buttons[path].queue_free()
			cached_buttons.erase(path)

func emit_open_beat_map(_chart_path: String) -> void:
	get_tree().current_scene.restart(_chart_path)
