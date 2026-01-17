extends Control


@export var v_box: VBoxContainer

const BUTTON := preload("res://scenes/UI/texture_button.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and event.keycode == KEY_QUOTELEFT:
		visible = !visible


func _ready() -> void:
	visible = false
	update_song_list()


func update_song_list() -> void:
	var folder_names :PackedStringArray = DirAccess.get_directories_at(SongLoader.SONGS_PATH)
	for folder_name in folder_names:
		var file_names :PackedStringArray = DirAccess.get_files_at(SongLoader.SONGS_PATH.path_join(folder_name))
		var image :Texture2D = Texture2D.new()
		for file_name in file_names:
			if file_name.get_extension() in ["jpg","png","jpeg"]:
				image = SongLoader.load_image(SongLoader.SONGS_PATH.path_join(folder_name + "/" + file_name))
		
		for file_name in file_names:
			if !file_name.get_extension() == "osu": continue
			var button :TextureButton = BUTTON.instantiate()
			button.title.text = file_name
			button.chart_path = ProjectSettings.globalize_path(
				SongLoader.SONGS_PATH.path_join(folder_name + "/" + file_name))
			button.texture_normal = image
			button.pressed.connect(emit_open_beat_map.bind(button.chart_path))
			v_box.add_child(button)


func emit_open_beat_map(_chart_path :String) -> void:
	var tree := get_tree()
	tree.reload_current_scene()
	await tree.scene_changed
	tree.current_scene.chart_path = _chart_path
