extends Node

@export var tracks: Tracks
@export var controller: Node2D
@export var combo_l: Label
@export var rating_L: Control
@export var j_pos: Control
var lights :Array[TextureRect] = []

const RatingRange :Dictionary = {
	"Perfect": 0.0165,
	"Great"  : 0.045,
	"Good"   : 0.075,
	"OK"     : 0.140,
	"Bad"    : 0.165,
	"Miss"   : 0.18}

var rating :Dictionary = {
	"Perfect":0,
	"Great":0,
	"Good":0,
	"OK":0,
	"Bad":0,
	"Miss":0
	}
	

var key_map :Dictionary
var keys :Array[bool] = [false, false, false, false,false, false, false, false,false, false]
var judgment_list :Array[Array] = []  ## 判定区 用来存进入判定区间的note
var release_list :Array[Array] = []

var max_combo :int = 0
var combo :int = 0:
	set(v):
		combo = v
		combo_l.text = str(combo)
		if combo > max_combo:
			max_combo = combo

func init() -> void:
	keys = [false, false, false, false,false, false, false, false,false, false]
	j_pos.init()
	judgment_list.clear()
	release_list.clear()
	
	for i in controller.key_quantity:
		judgment_list.append([])
		release_list.append([])
	
	rating_init()
	combo = 0
	max_combo = 0

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
		judgment_list[track].erase(note)
		judgment(note.time, time)

func released(track :int, time :float) -> void:
	var note :Node2D = release_list[track].pop_front()
	
	if note and note.type == &"hold" and note.hited:
		note.holding = false
		note.released = true
		note.modulate.a = 0.5
		judgment(note.end_time, time)
		if abs(note.end_time - time) <= RatingRange.OK:
			note.set_length(note.head.global_position.y+10)


func judgment(time :float, music_time :float) -> String:
	var t :float = abs(time - music_time)
	if t <= RatingRange.Perfect:
		rating.Perfect += 1
		combo += 1
		rating_L.show_rating(0)
		j_pos.add_line(music_time - time, 0)
		return "Perfect"
		
	elif t <= RatingRange.Great:
		rating.Great += 1
		combo += 1
		rating_L.show_rating(1)
		j_pos.add_line(music_time - time, 1)
		return "Great"
		
	elif t <= RatingRange.Good:
		rating.Good += 1
		combo += 1
		rating_L.show_rating(2)
		j_pos.add_line(music_time - time, 2)
		return "Good"
		
	elif t <= RatingRange.OK:
		rating.OK += 1
		combo += 1
		rating_L.show_rating(2)
		j_pos.add_line(music_time - time, 3)
		return "OK"
	
	elif t <= RatingRange.Bad:
		rating.Bad += 1
		combo = 0
		rating_L.show_rating(3)
		j_pos.add_line(music_time - time, 4)
		return "Bad"
	
	
	rating.Miss += 1
	combo = 0
	rating_L.show_rating(4)
	j_pos.add_line(music_time - time, 5)
	return "Miss"


func rating_init() -> void:
	rating = {
	"Perfect":0,
	"Great":0,
	"Good":0,
	"OK":0,
	"Bad":0,
	"Miss":0
	}
	
