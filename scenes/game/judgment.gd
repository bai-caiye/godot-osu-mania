extends Node
## 判定脚本

@export_group("Node")
@export var tracks: Tracks
@export var controller: Node2D
@export var combo_l: Label
@export var rating_L: Control
@export var j_pos: Control
var lights :Array[TextureRect] = []

## 评分名称
enum Rating{
	Perfect,
	Great,
	Good,
	OK,
	Meh,
	Miss,
}
## 判定区间
var rating_range :Dictionary[Rating, float] = {
	Rating.Perfect: 0.0165,
	Rating.Great  : 0.0415,
	Rating.Good   : 0.0745,
	Rating.OK     : 0.1045,
	Rating.Meh    : 0.1285,
	Rating.Miss   : 0.1655
}
## 本场评分
var rating :Dictionary[Rating, int] = {
	Rating.Perfect: 0,
	Rating.Great  : 0,
	Rating.Good   : 0,
	Rating.OK     : 0,
	Rating.Meh    : 0,
	Rating.Miss   : 0
}

var key_map :Dictionary
var keys :Array[bool] = [false, false, false, false,false, false, false, false,false, false]
var deviations :Array[float] = []
var judgment_list :Array[Array] = []  ## 判定区 用来存进入判定区间的note
var release_list :Array[Array] = []   ## 释放区

var max_combo :int = 0
var combo :int = 0:
	set(v):
		combo = v
		combo_l.text = str(combo)
		if combo > max_combo:
			max_combo = combo


func init() -> void:
	keys = [false, false, false, false,false, false, false, false,false, false]
	deviations.clear()
	judgment_list.clear()
	release_list.clear()
	
	for i in controller.key_quantity:
		judgment_list.append([])
		release_list.append([])
	
	j_pos.init()
	rating_init()
	combo = 0
	max_combo = 0


func rating_init() -> void:
	rating = {
	Rating.Perfect: 0,
	Rating.Great  : 0,
	Rating.Good   : 0,
	Rating.OK     : 0,
	Rating.Meh    : 0,
	Rating.Miss   : 0
	}


func _ready() -> void:
	lights = tracks.lights


func _unhandled_key_input(event: InputEvent) -> void:
	if controller.auto_play: return
	
	if event.pressed and !event.is_echo():
		if event.keycode in key_map:
			keys[key_map[event.keycode]] = true
			hit(key_map[event.keycode], controller.music_time)
		
	if event.is_released():
		if event.keycode in key_map:
			keys[key_map[event.keycode]] = false
			if release_list[key_map[event.keycode]].is_empty():
				return
			released(key_map[event.keycode], controller.music_time)


func _physics_process(delta: float) -> void:
	for i in controller.key_quantity:
		lights[i].modulate.a = lerp(lights[i].modulate.a, float(keys[i]), delta * 10)


func hit(track :int, time :float) -> void:
	if judgment_list[track].is_empty(): return
	var note :Node2D = judgment_list[track].front()
	if note and !note.hited:
		note.hited = true
		if note.type == &"hold":
			note.holding = true
			release_list[track].append(note)
		judgment(note.time, time)
		judgment_list[track].erase(note)


func released(track :int, time :float) -> void:
	var note :Node2D = release_list[track].pop_front()
	if note and note.type == &"hold" and note.hited:
		note.holding = false
		note.released = true
		note.modulate.a = 0.5
		judgment(note.end_time, time)
		if abs(note.end_time - time) <= rating_range[Rating.OK]:
			note.set_length(note.head.global_position.y+10)


func judgment(time :float, music_time :float) -> void:
	var dt :float = abs(music_time - time)
	if dt <= rating_range[Rating.Perfect]:
		rating[Rating.Perfect] += 1
		combo += 1
		rating_L.show_rating(0)
		j_pos.add_line(music_time - time, 0)
		return
		
	elif dt <= rating_range[Rating.Great]:
		rating[Rating.Great] += 1
		combo += 1
		rating_L.show_rating(1)
		j_pos.add_line(music_time - time, 1)
		return
		
	elif dt <= rating_range[Rating.Good]:
		rating[Rating.Good] += 1
		combo += 1
		rating_L.show_rating(2)
		j_pos.add_line(music_time - time, 2)
		return
		
	elif dt <= rating_range[Rating.OK]:
		rating[Rating.OK] += 1
		combo += 1
		rating_L.show_rating(2)
		j_pos.add_line(music_time - time, 3)
		return
	
	elif dt <= rating_range[Rating.Meh]:
		rating[Rating.Meh] += 1
		combo = 0
		rating_L.show_rating(3)
		j_pos.add_line(music_time - time, 4)
		return
	
	rating[Rating.Miss] += 1
	combo = 0
	rating_L.show_rating(4)
	j_pos.add_line(music_time - time, 5)
