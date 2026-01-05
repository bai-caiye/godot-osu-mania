extends Control
##加载音符控制音符移动的脚本
@export_group("Option")
@export_global_dir var song_floder_path :String
@export_global_file("*.osu") var chart_path :String
@export var speed :float = 1000.0  ##整体速度
@export var offset :float = 0.0   ##整体偏移

@export_group("Node")
@export var bg: TextureRect  ##背景图片
@export var music: AudioStreamPlayer
@export var tracks: Tracks
@export var node2d_notes: MultiMeshInstance2D
@export var lead_in_timer: Timer
@export var progress_bar: ColorRect

const NOTE = preload("res://scenes/note.tscn")

var note_quantity :int  ##音符总数
var notes_cache :Array[Node]  ##将要添加到屏幕上的音符
var notes :Array[Node]  ##正在屏幕上的音符
var kill_notes_cache :Array[Node]  ##要清除掉音符列表

var chart :PackedStringArray  ##谱面文本
var chart_data :Dictionary  ##谱面数据
var timing_points :Array  ##时间点数组
var key_quantity :int  ##多少指
var line_y :float = 0.0

var speed_scale :float = 1.0  ##变速(百分比%)
var music_time :float = 0.0  


func _ready() -> void:
	set_process_input(false)
	set_physics_process(false)
	set_process(false)
	
	var beatmap = SongLoader.load_beatmap(song_floder_path, chart_path)
	bg.texture = beatmap.image
	music.stream = beatmap.music
	chart = beatmap.chart
	
	chart_data = SongLoader.load_chart_data(chart)
	if chart_data.size() == 0: return
	
	load_timing_points(chart)
	note_quantity = chart.size() - chart.find("[HitObjects]") - 2
	key_quantity = chart_data[&"CircleSize"]
	tracks.key_quantity = key_quantity
	line_y = tracks.line_Y
	node2d_notes.global_position.x = tracks.position.x - tracks.track_H * 2
	progress_bar.length = music.stream.get_length()
	
	load_notes(chart)
	lead_in_timer.start()
	
	set_physics_process(true)
	set_process(true)
	await lead_in_timer.timeout
	
	music.play()


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

func _process(delta: float) -> void:
	music_time = music.get_playback_position() - lead_in_timer.time_left
	
	speed_scale = get_speed_scale(music_time)
	
	while notes_cache.size() > 0:
		var note:  Node2D = notes_cache[0]
		var lead_time: float = calculate_lead_time(note.time)
		
		if note.time - music_time <= lead_time:
			node2d_notes. add_child(note)
			note.global_position.y = 0.0
			notes_cache.pop_front()
		else:
			break
			
	node2d_notes. position.y += speed * speed_scale * delta	
	
	if node2d_notes.get_children().size() > 0 and node2d_notes.get_child(0).time - music_time <= 0:
		kill_note()
	

func kill_note() -> void:
	node2d_notes.get_child(0).visible = false
	node2d_notes.get_child(0).free()
	if node2d_notes.get_children().size() > 0 and node2d_notes.get_child(0).time - music_time <= 0:
		kill_note()


func get_speed_scale(time :float) -> float:
	var _speed_scale = 1.0
	for timing in timing_points:
		if time > timing[0]:
			_speed_scale = timing[1]
		else: break
	return _speed_scale


func load_notes(_chart :PackedStringArray) -> void:
	var index :int = _chart.find("[HitObjects]") + 1
	while index < _chart.size() - 1:
		load_note(
			conversion_type(_chart[index].get_slice(",",3)),
			c_time(_chart[index].get_slice(",",2)),
			c_time(_chart[index].get_slice(",",5).get_slice(":",0)),
			conversion_track(_chart[index].get_slice(",",0)))
		index += 1
	

func load_note(type: int, time: float, end_time: float, track_index: int) -> void:
	var note :Node2D = NOTE.instantiate()
	note.type = type
	note.scale.x = tracks.track_H
	note.track = track_index
	note.time = time + offset
	note.end_time = end_time + offset if end_time > 0.0 else 0.0
	note.position.x += (note.track) * tracks.track_H
	if track_index == 1 or track_index == 2:
		note.self_modulate = Color(0.3, 0.65, 1.0, 1.0)
	notes_cache.append(note)


func load_timing_points(chart_file :PackedStringArray) -> void:
	var index :int = chart.find("[TimingPoints]") + 1
	while chart_file[index] != "":
		if int(chart_file[index].get_slice(",", 6)) == 0:
			timing_points.append(
			[c_time(chart_file[index].get_slice(",", 0)),
			-100.0 / float(chart_file[index].get_slice(",", 1))])
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
	return float(time) / 1000
