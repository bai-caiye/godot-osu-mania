extends Node
## 全局声音管理器 由于播放音效和背景音乐

@export var bgm :AudioStreamPlayer
@export var sfx :Node

## 播放音乐
func play_bgm(stream: AudioStream) -> void:
	if bgm.stream != stream:
		bgm.stream = stream
		bgm.play()

## 播放音效
func play_sfx(sound_name: String) -> void:
	var player = sfx.get_node(sound_name) as AudioStreamPlayer
	if not player:
		push_error("没有[%s]这个音效" % sound_name)
		return
	player.play()
