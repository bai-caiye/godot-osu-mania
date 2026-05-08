extends Control

@export var sprite_2d: Sprite2D
@export var animat: AnimationPlayer

func _init() -> void:
	visible = false

func show_rating(rating:int):
	animat.stop()
	visible = false
	sprite_2d.frame = rating
	animat.play(&"hit")
