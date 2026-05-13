## 判定系统：快速判定、combo 管理、评分统计
extends Node

@export_group("Node")
@export var tracks: Tracks
@export var controller: Node2D
@export var combo_l: Label
@export var rating_L: Control
@export var j_pos: Control
var lights: Array[TextureRect] = []

enum Rating {
	Perfect,
	Great,
	Good,
	OK,
	Meh,
	Miss,
}

## 判定窗口（秒），按 Rating 顺序排列
var rating_range: Array[float] = [0.0165, 0.042, 0.0745, 0.1045, 0.1285, 0.1655]

## Rating 索引到精灵帧的映射（OK 和 Good 共享帧 2）
var rating_to_frame: Array[int] = [0, 1, 2, 2, 3, 4]

## 本场评分计数，按 Rating 顺序排列
var rating: Array[int] = [0, 0, 0, 0, 0, 0]

var key_map: Dictionary
var keys: Array[bool] = []
var deviations: Array[float] = []
var judgment_list: Array[Array] = []
var release_list: Array[Array] = []

var max_combo: int = 0
var combo: int = 0:
	set(v):
		combo = v
		combo_l.text = str(combo)
		if combo > max_combo:
			max_combo = combo


func init() -> void:
	var key_qty = controller.key_quantity
	keys.resize(key_qty)
	keys.fill(false)
	deviations.clear()
	judgment_list.clear()
	release_list.clear()

	for i in key_qty:
		judgment_list.append([])
		release_list.append([])

	j_pos.init()
	rating.fill(0)
	combo = 0
	max_combo = 0


func _ready() -> void:
	lights = tracks.lights


func _unhandled_key_input(event: InputEvent) -> void:
	if controller.auto_play: return

	var keycode = event.keycode
	if keycode not in key_map:
		return

	var track = key_map[keycode]
	if event.pressed and !event.is_echo():
		keys[track] = true
		hit(track, controller.music_time)
	elif event.is_released():
		keys[track] = false
		if !release_list[track].is_empty():
			released(track, controller.music_time)


func _physics_process(delta: float) -> void:
	for i in controller.key_quantity:
		lights[i].modulate.a = lerp(lights[i].modulate.a, float(keys[i]), delta * 10)


func hit(track: int, time: float) -> void:
	if judgment_list[track].is_empty():
		return
	var note: Node2D = judgment_list[track].pop_front()
	if note and !note.hited:
		note.hited = true
		if note.type == &"hold":
			note.holding = true
			release_list[track].append(note)
		judgment(note.time, time)


func released(track: int, time: float) -> void:
	var note: Node2D = release_list[track].pop_front()
	if note and note.type == &"hold" and note.hited:
		note.holding = false
		note.released = true
		note.modulate.a = 0.5
		judgment(note.end_time, time)
		if abs(note.end_time - time) <= rating_range[Rating.OK]:
			note.set_length(note.head.global_position.y + 10)


func judgment(time: float, music_time: float) -> void:
	deviations.append(music_time - time)
	var dt: float = abs(music_time - time)

	var rating_idx: int = Rating.Miss
	for i in rating_range.size():
		if dt <= rating_range[i]:
			rating_idx = i
			break

	rating[rating_idx] += 1
	if rating_idx < Rating.Meh:
		combo += 1
	else:
		combo = 0

	var frame = rating_to_frame[rating_idx]
	rating_L.show_rating(frame)
	j_pos.add_line(music_time - time, rating_idx)
