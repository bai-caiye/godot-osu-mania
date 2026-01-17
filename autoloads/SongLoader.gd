extends Node
## 用于加载曲包和谱面的脚本

const SONGS_PATH :String = "user://songs/"
signal osz_loaded  ## 曲包加载结束后发送的信号


func _ready() -> void:
	if !DirAccess.dir_exists_absolute(SONGS_PATH): DirAccess.make_dir_absolute(SONGS_PATH)
	get_viewport().files_dropped.connect(load_osz)
	#OS.shell_open(OS.get_user_data_dir())


## 用于加载osu的osz文件
func load_osz(file_paths:PackedStringArray) -> void:
	var suffixs :Array[StringName] = [&"osu",&"mp3",&"ogg",&"wav",&"png",&"jpg",&"jpeg"]
	for i in file_paths.size():
		var reader :ZIPReader = ZIPReader.new()
		if reader.open(file_paths[i]) != OK: return PackedByteArray()
		
		var folder_path :String = SONGS_PATH.path_join(file_paths[i].get_file().get_basename())
		DirAccess.make_dir_absolute(folder_path)
		var file_names :PackedStringArray = reader.get_files()
		
		for file_name in file_names:
			if !suffixs.has(file_name.get_extension()) or file_name.find("/") != -1:continue
			var res :PackedByteArray = reader.read_file(file_name)
			var res_file :FileAccess = FileAccess.open(folder_path.path_join(file_name),FileAccess.WRITE)
			if res: res_file.store_buffer(res)
			res_file.close()
		reader.close()
	osz_loaded.emit()


## 获取所有曲包以及谱面
func get_songs() -> Array[Song]:
	#待写
	return []


## 根据所选谱面(chart)返回beatmap(包含音乐和图片的谱面)
func load_beatmap(chart_path :String) -> Beatmap:
	if !FileAccess.file_exists(chart_path): return Beatmap.new()
	
	var song_path :String = chart_path.get_base_dir()
	var beatmap :Beatmap = Beatmap.new()
	beatmap.chart = FileAccess.get_file_as_string(chart_path).split("\r\n")
	
	#查找谱面指定音频文件
	var audio_path :String = song_path.path_join(beatmap.chart[beatmap.chart.find("[General]")+1].get_slice(": ",1))
	match audio_path.get_extension():
		"mp3": beatmap.music = load_audio(audio_path, &"mp3")
		"ogg": beatmap.music = load_audio(audio_path, &"ogg")
		
	beatmap.image = load_image(
		song_path.path_join(
			beatmap.chart[beatmap.chart.find("[Events]")+2].get_slice(",",2).trim_prefix('"').trim_suffix('"')))
	return beatmap


## 加载曲目信息 可以传谱面或谱面文件路径
func load_beatmap_data(chart) -> Dictionary:
	if !chart is PackedStringArray:
		if FileAccess.file_exists(chart):
			chart = FileAccess.get_file_as_string(chart).split("\r\n")
		else: printerr("读取谱面数据失败参数有不正确")
	
	var beatmap_data :Dictionary = {
	&"Title":"",         #音乐名称
	&"Artist":"",        #音乐作者
	&"Creato":"",        #谱师名称
	&"PreviewTime":0.0,  #音乐预览播放位置
	&"CircleSize":1,     #轨道数量
	&"Version":"",}      #版本
	
	var index :int = chart.find("[Metadata]") + 1
	while chart[index] != "":  
		match chart[index].get_slice(":",0):
			"Title": beatmap_data[&"Title"] = chart[index].get_slice(":",1)
			"Artist": beatmap_data[&"Artist"] = chart[index].get_slice(":",1)
			"Creato": beatmap_data[&"Creato"] = chart[index].get_slice(":",1)
			"PreviewTime": beatmap_data[&"PreviewTime"] = float(chart[index].get_slice(":",1))/1000
			"Version": beatmap_data[&"Version"] = chart[index].get_slice(":",1)
			"": break
		index += 1
	beatmap_data[&"CircleSize"] = int(chart[chart.find("[Difficulty]")+2].get_slice(":",1))
	return beatmap_data


## 加载图像并返回ImageTexture
func load_image(path: String) -> ImageTexture:
	if !FileAccess.file_exists(path): printerr("路径图像文件不存在") ;return ImageTexture.new()
	var image :Image = Image.load_from_file(path)
	return ImageTexture.create_from_image(image)


## 加载音频文件返回流
func load_audio(path: String, type: StringName = &"mp3") -> AudioStream:
	if !FileAccess.file_exists(path): printerr("路径音频文件不存在"); return AudioStream.new()
	var audio
	match type:
		&"mp3": audio = AudioStreamMP3.new()
		&"wav": audio = AudioStreamWAV.new()
		&"ogg": return AudioStreamOggVorbis.load_from_file(path)
	audio.data = FileAccess.get_file_as_bytes(path)
	return audio
