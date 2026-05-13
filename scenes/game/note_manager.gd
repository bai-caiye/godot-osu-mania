## 音符管理器：负责音符的生成、位置更新、过期回收和对象池操作
class_name NoteManager extends RefCounted

var notes_data: Array[Dictionary] = []  ## 所有音符的预处理数据
var notes_data_index: int = 0           ## 下一个待生成音符的索引
var active_notes: Array[Node2D] = []    ## 当前屏幕上活跃的音符

## 外部依赖（由 setup 注入）
var _judgment: Node
var _tracks: Node
var _tap_pool: Node
var _hold_pool: Node
var _sv: SvCalculator
var _line_y: float
var _key_quantity: int
var _miss_range: float                  ## 缓存 miss 判定窗口（避免每帧查表）
var _good_range: float                  ## 缓存 good 判定窗口
var _meh_range: float                   ## 缓存 meh 判定窗口


## 注入所有外部依赖
func setup(judgment: Node, tracks: Node, tap_pool: Node, hold_pool: Node, sv: SvCalculator, line_y: float) -> void:
	_judgment = judgment
	_tracks = tracks
	_tap_pool = tap_pool
	_hold_pool = hold_pool
	_sv = sv
	_line_y = line_y
	_miss_range = judgment.rating_range[judgment.Rating.Miss]
	_good_range = judgment.rating_range[judgment.Rating.Good]
	_meh_range  = judgment.rating_range[judgment.Rating.Meh]


## 重开时重置音符状态
func reset() -> void:
	notes_data_index = 0
	active_notes.clear()


## 刷新缓存的 miss 判定窗口（在 judgment.init() 后调用）
func refresh_miss_range() -> void:
	_miss_range = _judgment.rating_range[_judgment.Rating.Miss]
	_good_range = _judgment.rating_range[_judgment.Rating.Good]
	_meh_range  = _judgment.rating_range[_judgment.Rating.Meh]


## 从谱面文本解析所有音符数据
func load_notes_data(chart: PackedStringArray, key_quantity: int, chart_offset: float) -> void:
	_key_quantity = key_quantity
	notes_data.clear()
	var index: int = chart.find("[HitObjects]") + 1
	while index < chart.size() - 1:
		var line: String = chart[index]
		if line.is_empty():
			index += 1
			continue
		var note_data: Dictionary = {
			&"type":        FormatConvert.type(line.get_slice(",", 3)),
			&"time":        FormatConvert.time(line.get_slice(",", 2)) - chart_offset,
			&"end_time":    FormatConvert.time(line.get_slice(",", 5).get_slice(":", 0)) - chart_offset,
			&"track_index": FormatConvert.track(line.get_slice(",", 0), key_quantity),
			&"lead_time":   0.0
		}
		if note_data[&"end_time"] <= 0.0:
			note_data[&"end_time"] = 0.0
		notes_data.append(note_data)
		index += 1


## 生成到达出现时机的音符（每帧最多 key_quantity 个）
func spawn_notes(music_time: float, key_quantity: int) -> void:
	var spawned: int = 0
	while spawned < key_quantity and notes_data_index < notes_data.size():
		var note_data: Dictionary = notes_data[notes_data_index]
		if note_data[&"time"] - music_time > note_data[&"lead_time"]:
			break
		_spawn_note(note_data)
		spawned += 1
		notes_data_index += 1


## 更新所有活跃音符的位置，并将进入判定窗口的音符加入判定队列
func update_active_notes(music_time: float) -> void:
	var last_note_time: float = -1.0
	var last_note_pos: float = 0.0

	for i in active_notes.size():
		var note: Node2D = active_notes[i]

		# 同一时刻的 tap 音符共享位置，避免重复计算
		if note.time == last_note_time and note.type != &"hold":
			note.global_position.y = last_note_pos
		else:
			_update_note(note, music_time)
			last_note_time = note.time
			last_note_pos = note.global_position.y

		# 进入判定窗口时加入判定队列
		if !note.in_judgment and !note.hited and abs(note.time - music_time) <= _miss_range:
			note.in_judgment = true
			_judgment.judgment_list[note.track].append(note)


## 检测并回收过期音符
func recycle_expired_notes(music_time: float) -> void:
	for i in range(active_notes.size() - 1, -1, -1):
		var note: Node2D = active_notes[i]
		var expired := false
		match note.type:
			&"tap":  expired = _check_tap_expiry(note, music_time)
			&"hold": expired = _check_hold_expiry(note, music_time)
		if expired:
			active_notes.remove_at(i)
			_judgment.judgment_list[note.track].erase(note)
			if note.type == &"hold":
				_judgment.release_list[note.track].erase(note)
			_recycle_note(note)


# ── 内部方法 ──────────────────────────────────────────────

func _spawn_note(note_data: Dictionary) -> void:
	var note: Node2D = _acquire_note(note_data[&"type"])
	note.time = note_data[&"time"]
	note.track = note_data[&"track_index"]
	note.scale.x = _tracks.track_H / 100.0
	note.position.x = note.track * _tracks.track_H
	if note.type == &"hold":
		note.end_time = note_data[&"end_time"]
	note.modulate = _get_note_color(note.track)
	active_notes.append(note)


func _update_note(note: Node2D, music_time: float) -> void:
	var head_y: float = _line_y - _sv.calculate_distance(music_time, note.time)
	note.global_position.y = head_y
	if note.type == &"hold":
		var end_y: float = _line_y - _sv.calculate_distance(music_time, note.end_time)
		if note.hited and note.holding and note.time <= music_time:
			note.set_length(end_y, _line_y)
		else:
			note.set_length(end_y)


func _check_tap_expiry(note: Node2D, music_time: float) -> bool:
	if note.hited:
		return true
	if note.time - music_time <= -_miss_range:
		_judgment.judgment(note.time, music_time)
		return true
	return false


func _check_hold_expiry(note: Node2D, music_time: float) -> bool:
	var dt: float = note.time - music_time

	if (dt <= -_miss_range or note.hited) and not note.holding and note.modulate.a != 0.5:
		note.modulate.a = 0.5
		if dt < -_miss_range:
			_judgment.judgment(note.time, music_time)

	var edt: float = note.end_time - music_time
	if not note.released:
		if edt <= -_miss_range or (note.holding and edt <= -_good_range):
			if _judgment.release_list[note.track].has(note):
				_judgment.release_list[note.track].erase(note)
			note.released = true
			_judgment.judgment(note.end_time, music_time)

	if edt < -_meh_range and note.end.global_position.y > 1080.0:
		return true
	return false


func _get_note_color(track: int) -> Color:
	match _key_quantity:
		4: return Color("66b3ffff") if track in [1, 2] else Color.WHITE
		7:
			if track == 3: return Color("ffcc4dff")
			return Color("66b3ffff") if track in [1, 5] else Color.WHITE
	return Color.WHITE


func _acquire_note(type: StringName) -> Node2D:
	match type:
		&"tap":  return _tap_pool.acquire_node()
		&"hold": return _hold_pool.acquire_node()
		_:       return _tap_pool.acquire_node()


func _recycle_note(note: Node2D) -> void:
	match note.type:
		&"tap":
			_tap_pool.recycle_node(note)
		&"hold":
			note.head.position.y = 0.0
			_hold_pool.recycle_node(note)
