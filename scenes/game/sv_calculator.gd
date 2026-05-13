## SV 计算器：负责 timing points 解析、距离计算、lead_time 预算
class_name SvCalculator extends RefCounted

var speed: float = 1500.0
var timing_points: Array = []       ## [时间, 合并速度因子] 对的数组
var current_timing_index: int = -1  ## 当前音乐时间所在的 timing 段索引


## 初始化基础流速
func setup(_speed: float) -> void:
	speed = _speed


## 重开时重置索引
func reset() -> void:
	current_timing_index = -1


## 从谱面文本解析 timing points，合并 BPM（红线）和 SV（绿线）
## 速度因子 = (当前BPM / 基准BPM) × 绿线SV倍率
func load_timing_points(chart: PackedStringArray) -> void:
	timing_points.clear()

	# 第一遍：收集所有红线（BPM）和绿线（SV）
	var red_lines: Array = []   ## [时间, BPM]
	var green_lines: Array = [] ## [时间, SV倍率]

	var index: int = chart.find("[TimingPoints]") + 1
	while index < chart.size() and chart[index] != "":
		var line := chart[index]
		var beat_length := float(line.get_slice(",", 1))
		var time := FormatConvert.time(line.get_slice(",", 0))
		if int(line.get_slice(",", 6)) == 1:
			# 红线：beatLength 单位为 ms/beat，BPM = 60000 / beatLength
			red_lines.append([time, 60000.0 / beat_length])
		else:
			# 绿线：SV 倍率
			green_lines.append([time, -100.0 / beat_length])
		index += 1

	if red_lines.is_empty():
		return

	# 基准 BPM：取时值最长（最常用）的红线 BPM
	var base_bpm := _find_base_bpm(red_lines, chart)

	# 第二遍：合并所有时间节点，计算每段的合并速度因子
	var all_times: Array = []
	for r in red_lines: all_times.append(r[0])
	for g in green_lines: all_times.append(g[0])
	all_times.sort()
	# 去重
	var unique_times: Array = []
	for t in all_times:
		if unique_times.is_empty() or t != unique_times.back():
			unique_times.append(t)

	var current_bpm: float = red_lines[0][1]
	var current_sv := 1.0
	var red_idx := 0
	var green_idx := 0

	for t in unique_times:
		# 红线变化时 SV 重置为 1.0（除非同一时刻有绿线覆盖）
		var red_changed := false
		while red_idx < red_lines.size() and red_lines[red_idx][0] <= t:
			current_bpm = red_lines[red_idx][1]
			red_changed = true
			red_idx += 1
		if red_changed:
			current_sv = 1.0

		while green_idx < green_lines.size() and green_lines[green_idx][0] <= t:
			current_sv = green_lines[green_idx][1]
			green_idx += 1
		timing_points.append([t, (current_bpm / base_bpm) * current_sv])


## 取时值最长的红线 BPM 作为基准 BPM
func _find_base_bpm(red_lines: Array, chart: PackedStringArray) -> float:
	# 找谱面总时长（最后一个 HitObject 的时间）
	var last_note_time := 0.0
	var ho_index := chart.find("[HitObjects]") + 1
	while ho_index < chart.size() and chart[ho_index] != "":
		var t := FormatConvert.time(chart[ho_index].get_slice(",", 2))
		if t > last_note_time:
			last_note_time = t
		ho_index += 1

	# 统计每个 BPM 在谱面中占用的时长
	var bpm_durations: Dictionary = {}
	for i in red_lines.size():
		var seg_start: float = red_lines[i][0]
		var seg_end: float = last_note_time if i + 1 >= red_lines.size() else red_lines[i + 1][0]
		var bpm: float = red_lines[i][1]
		var duration := maxf(seg_end - seg_start, 0.0)
		bpm_durations[bpm] = bpm_durations.get(bpm, 0.0) + duration

	# 返回占用时长最长的 BPM
	var base_bpm: float = red_lines[0][1]
	var max_duration := 0.0
	for bpm in bpm_durations:
		if bpm_durations[bpm] > max_duration:
			max_duration = bpm_durations[bpm]
			base_bpm = bpm
	return base_bpm


## 推进 current_timing_index 到当前 music_time 所在的段
func push_timing_index(music_time: float) -> void:
	if timing_points.is_empty():
		current_timing_index = -1
		return
	while current_timing_index + 1 < timing_points.size() and music_time >= timing_points[current_timing_index + 1][0]:
		current_timing_index += 1


## 计算 from_time 到 to_time 之间音符移动的像素距离（考虑 SV 分段）
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


## 反向推算音符应在 note_time 之前多久生成（使其从屏幕顶部出发恰好到达判定线）
func calculate_lead_time(note_time: float, line_y: float) -> float:
	var timing_index: int = timing_points.size() - 1
	while timing_index >= 0 and timing_points[timing_index][0] > note_time:
		timing_index -= 1
	return _calculate_lead_time_from(note_time, line_y, timing_index)


## 从已知 timing 段索引开始反向推算 lead_time（避免重复扫描）
func _calculate_lead_time_from(note_time: float, line_y: float, timing_index: int) -> float:
	var remaining_distance: float = line_y
	var current_time: float = note_time

	while remaining_distance > 0:
		if timing_index < 0:
			current_time -= remaining_distance / speed
			remaining_distance = 0
			break

		var segment_sv: float = timing_points[timing_index][1]
		var segment_start_time: float = timing_points[timing_index][0]
		var segment_speed: float = speed * segment_sv
		var max_time_in_segment: float = current_time - segment_start_time
		var distance_in_segment: float = max_time_in_segment * segment_speed

		if distance_in_segment >= remaining_distance:
			current_time -= remaining_distance / segment_speed
			remaining_distance = 0
		else:
			remaining_distance -= distance_in_segment
			current_time = segment_start_time
			timing_index -= 1

	return note_time - current_time


## 为所有音符数据预算 lead_time 字段（音符按时间升序，顺序推进索引避免重复扫描）
func precalculate_lead_times(notes_data: Array, line_y: float) -> void:
	if notes_data.is_empty() or timing_points.is_empty():
		for note_data in notes_data:
			note_data[&"lead_time"] = line_y / speed
		return

	# 音符升序，tp_idx 从头向后推进，O(N+M)
	var tp_idx := -1
	for note_data in notes_data:
		var note_time: float = note_data[&"time"]
		while tp_idx + 1 < timing_points.size() and timing_points[tp_idx + 1][0] <= note_time:
			tp_idx += 1
		note_data[&"lead_time"] = _calculate_lead_time_from(note_time, line_y, tp_idx)
