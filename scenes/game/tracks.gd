@tool
extends Control
class_name Tracks

@export_group("Option")
##轨道数量
@export var key_quantity :int:
	set(v):
		key_quantity = v
		for i in tracks.size():
			if i < key_quantity: tracks[i].visible = true
			else: tracks[i].visible = false
		set_line()
##轨道宽度
@export var track_H :float:
	set(v):
		track_H = v
		for track in tracks:
			track.custom_minimum_size.x = track_H
		set_line()
##轨道透明度
@export_range(0.0, 1.0) var track_A :float:
	set(v):
		track_A = v
		for track in tracks:
			track.modulate.a = track_A
##线的高度
@export var line_Y :float:
	set(v):
		line_Y = v
		set_line()
@export_group("Node")
@export var tracks :Array[ColorRect]
@export var line: ColorRect


func set_line() -> void:
	if !line: return
	line.global_position.y = line_Y
	line.scale.x = key_quantity * track_H / 280.0
	
