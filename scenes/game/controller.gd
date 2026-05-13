## 游戏主控制器：负责游戏流程（加载、开始、暂停、重开）和主循环协调
extends Node2D

@export_group("Option")
@export_global_file("*.osu") var chart_path: String
@export var auto_play: bool = false
@export_range(10.0, 10000.0) var speed: float = 1500  ## 基础流速（px/s）
@export_range(-1.0, 1.0) var offset: float = 0.0      ## 全局时间偏移（补偿音频延迟）

@export_group("Node")
@export var bg: TextureRect
@export var music: AudioStreamPlayer
@export var tracks: Tracks
@export var lead_in_timer: Timer
@export var progress_bar: ColorRect
@export var tap_pool: ObjectPool
@export var hold_pool: ObjectPool
@export var judgment: Node

var pause: bool = false:
	set(v):
		pause = v
		music.stream_paused = pause
		lead_in_timer.paused = pause
		set_process(!pause)
		judgment.set_process_unhandled_key_input(!pause)

var key_quantity: int = 4
var music_time: float = 0.0   ## 当前音乐播放时间（秒）
var chart_offset: float = 0.0

var sv := SvCalculator.new()
var notes := NoteManager.new()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and !event.is_echo():
		match event.keycode:
			KEY_QUOTELEFT: restart(chart_path)
			KEY_ESCAPE:    pause = !pause


func _ready() -> void:
	pause = true
	sv.setup(speed)
	notes.setup(judgment, tracks, tap_pool, hold_pool, sv, tracks.line_Y)
	if load_beatmap(chart_path): return
	start()


## 主循环：同步音频时间，驱动音符生命周期
func _process(delta: float) -> void:
	music_time += delta
	_sync_music_time()
	if auto_play: _auto_playing()
	sv.push_timing_index(music_time)
	notes.spawn_notes(music_time, key_quantity)
	notes.update_active_notes(music_time)
	notes.recycle_expired_notes(music_time)


## 加载谱面：解析文件、初始化各子系统
func load_beatmap(_chart_path: String) -> Error:
	var beatmap := SongLoader.load_beatmap(_chart_path)
	if beatmap.chart.is_empty(): printerr("谱面读取错误"); return ERR_UNAVAILABLE

	var beatmap_data = SongLoader.load_beatmap_data(beatmap.chart)
	if beatmap_data.is_empty(): printerr("谱面信息读取错误"); return ERR_UNAVAILABLE

	if !is_instance_valid(beatmap.music): return ERR_UNAVAILABLE

	bg.texture = beatmap.image
	music.stream = beatmap.music
	key_quantity = beatmap_data[&"CircleSize"]
	tracks.key_quantity = key_quantity
	judgment.key_map = Setting.key_binding[key_quantity]
	judgment.init()

	var pool_x := Vector2(tracks.position.x - tracks.track_H * key_quantity / 2.0, 0.0)
	tap_pool.global_position = pool_x
	hold_pool.global_position = pool_x
	progress_bar.length = music.stream.get_length()

	sv.load_timing_points(beatmap.chart)
	notes.load_notes_data(beatmap.chart, key_quantity, chart_offset)
	sv.precalculate_lead_times(notes.notes_data, tracks.line_Y)
	return OK


## 开始游戏：lead-in 倒计时后播放音乐
func start() -> void:
	music_time = -lead_in_timer.wait_time + offset
	lead_in_timer.start()
	pause = false
	music.stop()
	await lead_in_timer.timeout
	if pause: return
	music.play(0.0)
	music_time = _get_music_position()


## 重开：重置所有状态后重新开始
func restart(_chart_path: String) -> void:
	pause = true
	music.stop()
	sv.reset()
	notes.reset()
	tap_pool.recycle_all_nodes()
	hold_pool.recycle_all_nodes()
	judgment.init()
	notes.refresh_miss_range()
	if chart_path != _chart_path:
		if load_beatmap(_chart_path) != OK: printerr("重开失败"); return
		chart_path = _chart_path
	start()


# ── 内部方法 ──────────────────────────────────────────────

## 每帧与实际音频位置对比，大偏差（>100ms）才强制同步，小偏差由 delta 自然推进
func _sync_music_time() -> void:
	if !music.playing: return
	var real_time := _get_music_position()
	if abs(real_time - music_time) > 0.1:
		music_time = real_time


## 获取考虑系统延迟的精确音频播放位置
func _get_music_position() -> float:
	return music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency() + offset


## Auto Play：在 0ms 偏差处自动击打所有音符（用于测试）
func _auto_playing() -> void:
	for track in judgment.judgment_list.size():
		if judgment.judgment_list[track].is_empty(): continue
		var note: Node2D = judgment.judgment_list[track].front()
		if note and !note.hited and note.time - music_time <= 0.0:
			judgment.hit(track, note.time)

	for track in judgment.release_list.size():
		if judgment.release_list[track].is_empty(): continue
		var note: Node2D = judgment.release_list[track].front()
		if note and !note.released and note.end_time - music_time <= 0.0:
			judgment.released(track, note.end_time)
