extends Control
##加载音符控制音符移动的脚本
@export_group("Option")
@export_global_file("*.osu") var chart_path: String
@export var speed: float = 1000.0  ## 整体速度
@export var offset: float = 0.0    ## 整体偏移

@export_group("Node")
@export var bg: TextureRect  ## 背景图片
@export var music: AudioStreamPlayer
@export var tracks: Tracks
@export var node2d_notes: Node2D
@export var lead_in_timer: Timer
@export var progress_bar: ColorRect

const NOTE := preload("res://scenes/game/note.tscn")

var pause :bool = false:
	set(v):
		pause = v
		get_tree().paused = pause
		set_process(!pause)

var _pool: Array = []
var _pool_initial_size: int = 20

var note_quantity: int  ## 音符总数
var notes_data: Array = []
var notes_data_index: int = 0
var active_notes: Array = []

var chart: PackedStringArray  ## 谱面文本
var beatmap_data: Dictionary  ## 谱面信息
var timing_points: Array      ## 时间点数组
var key_quantity: int         ## 有多少key
var line_y: float = 850.0     ## 判定线的高度

var speed_scale: float = 1.0  ## 变速(百分比%)
var music_time: float = 0.0   ## 当前音乐播放时间


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and !event.is_echo():
		match event.keycode:
			KEY_QUOTELEFT:
				restart(chart_path)
			KEY_ESCAPE:
				pause = !pause

## 初始化
func _ready() -> void:
	set_physics_process(false)
	set_process_input(false)
	set_process(false)
	
	load_beatmap()
	line_y = tracks.line_Y
	_prewarm_pool()
	lead_in_timer.start()
	set_process(true)
	
	await lead_in_timer.timeout
	music.play()

## 重开
func restart(_chart_path :String) -> void:
	set_process(false)
	if music.stream: music.stop()
	
	notes_data_index = 0
	for i in active_notes.size():
		pool_release(active_notes[i][&"node"])
	active_notes.clear()
	
	if chart_path != _chart_path:
		notes_data.clear()
		timing_points.clear()
		load_beatmap()
	
	lead_in_timer.start()
	pause = false
	
	await lead_in_timer.timeout
	music.play()


func load_beatmap() -> void:
	var beatmap := SongLoader.load_beatmap(chart_path)
	bg.texture = beatmap.image
	music.stream  = beatmap.music
	chart = beatmap.chart
	beatmap_data = SongLoader.load_beatmap_data(chart)
	
	note_quantity = chart.size() - chart.find("[HitObjects]") - 2
	key_quantity = beatmap_data[&"CircleSize"]
	tracks.key_quantity = key_quantity
	
	node2d_notes.global_position = Vector2(tracks.position.x - tracks.track_H * 2, 0.0)
	progress_bar.length = music.stream.get_length()
	
	load_timing_points(chart)
	load_notes_data(chart)
	precalculate_lead_times()


func _process(_delta: float) -> void:
	music_time = music.get_playback_position() - lead_in_timer.time_left
	speed_scale = get_speed_scale(music_time)
	
	spawn_notes()
	update_active_notes()
	recycle_expired_notes()


## 生成note
func spawn_notes() -> void:
	while notes_data_index < notes_data.size():
		var note_data: Dictionary = notes_data[notes_data_index]
		var lead_time: float = note_data[&"lead_time"]
		
		if note_data[&"time"] - music_time <= lead_time: 
			var note_node: Node2D = pool_acquire()
			
			note_node.type = note_data[&"type"]
			note_node.scale.x = tracks.track_H
			note_node.track = note_data[&"track_index"]
			note_node.time = note_data[&"time"] + offset
			note_node.end_time = note_data[&"end_time"] + offset if note_data[&"end_time"] > 0.0 else 0.0
			note_node.position.x = note_data[&"track_index"] * tracks.track_H
			
			var distance: float = calculate_distance(music_time, note_data[&"time"])
			note_node.position.y = line_y - distance
			
			if note_data[&"track_index"] == 1 or note_data[&"track_index"] == 2:
				note_node.self_modulate = Color(0.3, 0.65, 1.0, 1.0)
			else: 
				note_node.self_modulate = Color.WHITE
			
			active_notes.append({
				&"data": note_data,
				&"node": note_node})
			
			notes_data_index += 1
		else:
			break


## 更新note位置
func update_active_notes() -> void:
	for note_info in active_notes: 
		var note_node: Node2D = note_info[&"node"]
		var note_data: Dictionary = note_info[&"data"]
		note_node.position.y = line_y - calculate_distance(music_time, note_data[&"time"])


## from_time->to_time之间音符移动的距离
func calculate_distance(from_time: float, to_time: float) -> float:
	if from_time >= to_time: return 0.0
	
	var total_distance: float = 0.0
	var current_time: float = from_time
	
	var timing_index: int = -1
	for i in range(timing_points.size()):
		if timing_points[i][0] <= from_time: 
			timing_index = i
		else: 
			break
	
	#分段计算距离 也是定积分
	while current_time < to_time:
		var segment_sv: float = 1.0
		if timing_index >= 0 and timing_index < timing_points.size():
			segment_sv = timing_points[timing_index][1]
		
		var segment_end_time: float = to_time
		if timing_index + 1 < timing_points.size():
			segment_end_time = minf(to_time, timing_points[timing_index + 1][0])
		
		#分段时间 * speed * segment_sv
		total_distance += (segment_end_time - current_time) * speed * segment_sv
		current_time = segment_end_time
		timing_index += 1
		
	return total_distance


## 预算lead_time
func precalculate_lead_times() -> void:
	for note_data in notes_data:
		note_data[&"lead_time"] = calculate_lead_time(note_data[&"time"])


## 计算lead_time
func calculate_lead_time(note_time: float) -> float:
	var remaining_distance: float = line_y
	var current_time: float = note_time

	var timing_index: int = timing_points.size() - 1
	while timing_index >= 0 and timing_points[timing_index][0] > note_time:
		timing_index -= 1 #找到当前时间对应的timing point索引

	while remaining_distance > 0: 
		var segment_sv: float = 1.0 #绿线，读流速
		var segment_start_time: float = 0.0 #时间段的起始点

		if timing_index >= 0:
			segment_sv = timing_points[timing_index][1]
			segment_start_time = timing_points[timing_index][0]

		var segment_speed: float = speed * segment_sv #全局流速*时间段流速缩放
		var max_time_in_segment: float = current_time - segment_start_time #这一段最多能走的时间
		var distance_in_segment: float = max_time_in_segment * segment_speed #最多能走的距离

		if distance_in_segment >= remaining_distance: 
			#这一变速段能走完，往前调生成时间
			current_time -= remaining_distance / segment_speed
			remaining_distance = 0
		else: 
			#这一段不够，继续往前
			remaining_distance -= distance_in_segment
			current_time = segment_start_time #调整为这一个timingpoint的开始时间，往前继续积分
			timing_index -= 1
	return note_time - current_time


## 获取speed_scale
func get_speed_scale(time: float) -> float:
	var _speed_scale: float = 1.0
	for timing in timing_points:
		if time > timing[0]: 
			_speed_scale = timing[1]
		else: 
			break
	return _speed_scale


## 给对象池添加御用对象
func _prewarm_pool() -> void:
	for i in _pool_initial_size:
		var note: Node2D = NOTE.instantiate()
		note.visible = false
		note.set_process(false)
		node2d_notes.add_child(note)
		_pool.append(note)


## 从对象池取一个对象
func pool_acquire() -> Node2D:
	var note: Node2D
	if _pool.size() > 0:
		note = _pool.pop_back()
	else:
		note = NOTE.instantiate()
		node2d_notes.add_child(note)
		#print("no enough notes, instantiating prefab")
	note.visible = true
	return note


## 批量回收对象
func recycle_expired_notes() -> void:
	var i: int = 0
	while i < active_notes.size():
		var note_data: Dictionary = active_notes[i][&"data"]
		
		if note_data[&"time"] - music_time < 0:
			var note_node: Node2D = active_notes[i][&"node"]
			pool_release(note_node)
			active_notes.remove_at(i)
		else:
			i += 1

## 回收对象
func pool_release(note: Node2D) -> void:
	note.visible = false
	note.position = Vector2.ZERO
	note.self_modulate = Color.WHITE
	_pool.append(note)


## 回收第 index 个对象
func _recycle_at(index: int) -> void:
	pool_release(active_notes[index][&"node"])
	active_notes.remove_at(index)


## 加载音符数据
func load_notes_data(_chart: PackedStringArray) -> void:
	var index: int = _chart.find("[HitObjects]") + 1
	while index < _chart.size() - 1:
		var line: String = _chart[index]
		if line.is_empty():
			index += 1
			continue
			
		var note_data :Dictionary = {
			&"type": conversion_type(line.get_slice(",", 3)),
			&"time": c_time(line.get_slice(",", 2)) + offset,
			&"end_time": c_time(line.get_slice(",", 5).get_slice(":", 0)) + offset,
			&"track_index": conversion_track(line.get_slice(",", 0)),
			&"lead_time": 0.0
		}
		if note_data[&"end_time"] <= 0.0:
			note_data[&"end_time"] = 0.0
		notes_data.append(note_data)
		index += 1


## 加载timing_points
func load_timing_points(_chart: PackedStringArray) -> void:
	var index: int = chart.find("[TimingPoints]") + 1
	while index < _chart.size() and _chart[index] != "": 
		if int(_chart[index].get_slice(",", 6)) == 0:
			timing_points.append([
			c_time(_chart[index].get_slice(",", 0)),
			-100.0 / float(_chart[index].get_slice(",", 1))])
		index += 1


func conversion_type(x) -> int:
	match int(x):
		1: return 0
		5: return 0
		128: return 1
		_: return 0

func conversion_track(x) -> int:
	x = int(x)
	match key_quantity: 
		4: return (x - 64) / 128
		7: return (x - 35) / 73
		_: return int((float(x) / 512.0) * key_quantity)


func c_time(time) -> float:
	return float(time) / 1000.0
