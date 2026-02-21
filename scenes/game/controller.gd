extends Control
##加载音符控制音符移动的脚本
@export_group("Option")
@export_global_file("*.osu") var chart_path: String
@export var auto_play :bool = false

@export_group("Node")
@export var bg: TextureRect  ## 背景图片
@export var music: AudioStreamPlayer
@export var tracks: Tracks
@export var lead_in_timer: Timer
@export var progress_bar: ColorRect
@export var tap_pool: ObjectPool
@export var hold_pool: ObjectPool

const JUDGE_WINDOW :float = 0.09

var speed: float = Global.speed            ## 整体速度
var global_offset: float = Global.offset   ## 整体偏移
var pause :bool = false:
	set(v):
		pause = v
		music.stream_paused = pause
		set_process(!pause)

var chart: PackedStringArray  ## 谱面文本
var beatmap_data: Dictionary  ## 谱面信息

var key_quantity: int = 4     ## 有多少key
var key_map :Dictionary = {}

var note_quantity: int = 0              ## 音符总数
var notes_data :Array[Dictionary] = []  ## note数据用于生成note
var notes_data_index: int = 0
var active_notes: Array[Node2D] = []    ## 活动的音符 移动note
var judgment_queue :Array[Node2D] = []  ## 判定区 用来存进入判定区间的note
var expired_notes :Array[Node2D] = []   ## 回收缓存 用于存放要在帧末回收的note

var line_y: float             ## 判定线的高度
var timing_points: Array      ## 时间点数组
var current_timing_index: int = -1
var music_time: float = 0.0   ## 当前音乐播放时间
var offset :float = 0.1      ## 默认偏移

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
	pause = true
	line_y = tracks.line_Y
	
	if chart_path.is_empty(): return
	load_beatmap(chart_path)
	start()
	
func start() -> void:
	music_time = 0.0 - lead_in_timer.wait_time
	lead_in_timer.start()
	pause = false
	
	await lead_in_timer.timeout
	music.play()
	music_time = get_music_position()

## 重开
func restart(_chart_path :String) -> void:
	pause = true
	if music.stream: music.stop()
	
	notes_data_index = 0
	current_timing_index = -1
	#回收全部note
	for i in active_notes.size():
		recycle_note(active_notes[i])
	active_notes.clear()
	
	if chart_path != _chart_path:
		if load_beatmap(_chart_path) != OK: printerr("重开失败"); return
		chart_path = _chart_path
	start()

## 获取音乐时间的精准位置
func get_music_position() -> float:
	return music.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency()

## 主要循环
func _process(delta: float) -> void:
	music_time += delta
	
	if music.playing:
		var music_t :float = get_music_position()
		var music_dt :float = music_t - music_time
		if music_dt > 0.015 or music_dt < -0.015:
			music_time = get_music_position()
	
	spawn_notes()
	update_active_notes()
	recycle_expired_notes()


## 生成note
func spawn_notes() -> void:
	var spawn :int = 0
	while spawn < key_quantity and notes_data_index < notes_data.size():
		var note_data: Dictionary = notes_data[notes_data_index]
		if note_data[&"time"] - music_time > note_data[&"lead_time"]: break
		
		var note: Node2D = acquire_note(note_data[&"type"])
		note.time = note_data[&"time"] 
		note.track = note_data[&"track_index"]
		note.scale.x = tracks.track_H / 100.0
		note.position.x = note.track * tracks.track_H
		if note.type == &"hold": note.end_time = note_data[&"end_time"]
		
		match key_quantity:
			4: note.modulate = Color("4da6ffff") if note.track == 1 or note.track == 2 else Color.WHITE
			7:
				if note.track == 3:
					note.modulate = Color("ffcc4dff")
				else:
					note.modulate = Color("4da6ffff") if note.track in [1,5] else Color.WHITE
				
		active_notes.append(note)
		spawn += 1
		notes_data_index += 1
		

## 更新note位置
func update_active_notes() -> void:
	push_timing_index()
	var last_note_time :float = 0.0
	var last_note_pos :float = 0.0
	
	for i in range(active_notes.size() - 1, -1, -1):
		var note :Node2D = active_notes[i]
		
		if note.time == last_note_time and note.type != &"hold":
			note.global_position.y = last_note_pos
		else:
			update_note(note)
			last_note_time = note.time
			last_note_pos = note.global_position.y


func update_note(note: Node2D) -> void:
	match note.type:
		&"tap":
			note.global_position.y = line_y - calculate_distance(music_time, note.time)
		&"hold":
			note.global_position.y = line_y - calculate_distance(music_time, note.time)
			if note.holding and note.time < music_time:
				note.set_length(line_y - calculate_distance(music_time, note.end_time), line_y)
			else:
				note.set_length(line_y - calculate_distance(music_time, note.end_time))
	
	
## from_time->to_time之间音符移动的距离
func calculate_distance(from_time: float, to_time: float) -> float:
	if from_time > to_time:
		return -calculate_distance(to_time, from_time)
	
	if from_time == to_time:
		return 0.0
	
	var total_distance: float = 0.0
	var current_time: float = from_time
	var timing_index: int = current_timing_index
	
	while current_time < to_time:
		var segment_sv: float = 1.0
		if timing_index >= 0 and timing_index < timing_points.size():
			segment_sv = timing_points[timing_index][1]
		
		var segment_end_time: float = to_time
		if timing_index + 1 < timing_points.size():
			segment_end_time = minf(to_time, timing_points[timing_index + 1][0])
		
		total_distance += (segment_end_time - current_time) * speed * segment_sv
		current_time = segment_end_time
		timing_index += 1
	return total_distance


## 回收对象
func recycle_expired_notes() -> void:
	for i in active_notes.size():
		var note :Node2D = active_notes[i]
		var expired_time :float = music_time - JUDGE_WINDOW if !auto_play else music_time
		match note.type:
			&"tap":
				if note.time < expired_time:
					if auto_play:
						note.hited = true  # 后面替换成hit方法
					expired_notes.append(note)
					
			&"hold":
				if note.time < expired_time:
					if auto_play:  # 后面替换成hit方法
						note.hited = true
						note.holding = true
					if !note.hited: note.modulate.a = 0.5
				
				if(note.end_time < expired_time and note.holding) or (note.end.global_position.y > 1080.0):
					expired_notes.append(note)
		
	while expired_notes.size() > 0:
		var expired_note :Node2D = expired_notes.pop_back()
		active_notes.erase(expired_note)
		recycle_note(expired_note)
		

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
		if timing_index < 0:
			# 已经没有更早的 timing point，用当前段速度一次性走完
			current_time -= remaining_distance / (speed * 1.0)
			remaining_distance = 0
			break
	
		var segment_sv :float = 1.0
		var segment_start_time :float = 0.0
	
		segment_sv = timing_points[timing_index][1]
		segment_start_time = timing_points[timing_index][0]
	
		var segment_speed :float = speed * segment_sv
		var max_time_in_segment :float = current_time - segment_start_time
		var distance_in_segment :float = max_time_in_segment * segment_speed
	
		if distance_in_segment >= remaining_distance:
			current_time -= remaining_distance / segment_speed
			remaining_distance = 0
		else:
			remaining_distance -= distance_in_segment
			current_time = segment_start_time
			timing_index -= 1
	return note_time - current_time


func push_timing_index() -> void:
	if timing_points.is_empty(): current_timing_index = -1; return
	
	while current_timing_index + 1 < timing_points.size() and music_time >= timing_points[current_timing_index + 1][0]:
		current_timing_index += 1


## 加载谱面
func load_beatmap(_chart_path :String) -> Error:
	var beatmap := SongLoader.load_beatmap(_chart_path)
	if beatmap.chart.is_empty(): printerr("谱面读取错误"); return ERR_UNAVAILABLE
	
	var beatmap_temp_data = SongLoader.load_beatmap_data(beatmap.chart)
	if beatmap_temp_data.is_empty(): printerr("谱面信息读取错误"); return ERR_UNAVAILABLE
	
	bg.texture = beatmap.image
	music.stream = beatmap.music
	chart = beatmap.chart
	beatmap_data = beatmap_temp_data.duplicate(true)
	beatmap_temp_data = null
	
	key_quantity = beatmap_data[&"CircleSize"]
	key_map = Global.key_binding[key_quantity]
	tracks.key_quantity = key_quantity
	var pos :Vector2 = Vector2(tracks.position.x - tracks.track_H * key_quantity / 2, 0.0)
	tap_pool.global_position = pos
	hold_pool.global_position = pos
	progress_bar.length = music.stream.get_length()
	
	load_timing_points(chart)
	load_notes_data(chart)
	note_quantity = notes_data.size()
	precalculate_lead_times()
	return OK


## 加载timing_points
func load_timing_points(_chart: PackedStringArray) -> void:
	timing_points.clear()
	var index: int = chart.find("[TimingPoints]") + 1
	while index < _chart.size() and _chart[index] != "": 
		var uninheritedint :int = int(_chart[index].get_slice(",", 6))
		if uninheritedint == 0:
			timing_points.append([
			c_time(_chart[index].get_slice(",", 0)),
			-100.0 / float(_chart[index].get_slice(",", 1))])
		index += 1


## 加载音符数据
func load_notes_data(_chart: PackedStringArray) -> void:
	notes_data.clear()
	var index: int = _chart.find("[HitObjects]") + 1
	while index < _chart.size() - 1:
		var line: String = _chart[index]
		if line.is_empty():
			index += 1
			continue
			
		var note_data :Dictionary = {
			&"type": conversion_type(line.get_slice(",", 3)),
			&"time": c_time(line.get_slice(",", 2)) + global_offset + offset,
			&"end_time": c_time(line.get_slice(",", 5).get_slice(":", 0)) + global_offset + offset,
			&"track_index": conversion_track(line.get_slice(",", 0)),
			&"lead_time": 0.0
		}
		if note_data[&"end_time"] <= 0.0: note_data[&"end_time"] = 0.0
		notes_data.append(note_data)
		index += 1

## 取出note
func acquire_note(type :StringName) -> Node2D:
	match type:
		&"tap": return tap_pool.acquire_object()
		&"hold": return hold_pool.acquire_object()
	return null

## 放回note
func recycle_note(note :Node2D) -> void:
	note.hited = false
	match note.type:
		&"tap": tap_pool.recycle_object(note)
		&"hold":
			note.holding = false
			note.head.position.y = 0.0
			hold_pool.recycle_object(note)


func conversion_type(x) -> StringName:
	match int(x):
		128: return &"hold"
		_: return &"tap"


func conversion_track(x) -> int:
	x = int(x)
	match key_quantity: 
		4: return (x - 64) / 128
		7: return (x - 35) / 73
		_: return int(float(x * key_quantity) / 512.0)


func c_time(time) -> float:
	return float(time) / 1000.0
