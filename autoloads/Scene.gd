extends CanvasLayer
## 全局场景管理 用于加载场景和切换播放过场动画
# 不要加其他东西 要加东西去全局脚本

@export_group("Node")
@export var animation: AnimationPlayer

enum Transition{None, Fade}

func change_scene(path :String, transition :Transition = Transition.None, play_sleep: float = 1.0) -> void:
	var transition_name :StringName = Transition.find_key(transition)
	var tree := get_tree() 
	
	if transition_name != &"None":
		animation.speed_scale = play_sleep
		animation.play(transition_name+&"-In")
		await animation.animation_finished
	
	tree.paused = true
	
	# 使用线程加载场景资源
	ResourceLoader.load_threaded_request(path)
	var progress :Array = []
	while ResourceLoader.load_threaded_get_status(path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await tree.process_frame
	
	var scene :Resource = ResourceLoader.load_threaded_get(path)
	
	tree.change_scene_to_packed(scene)
	await tree.scene_changed
	
	tree.paused = false
	
	if transition_name != &"None":
		animation.play(transition_name+&"-Out")
