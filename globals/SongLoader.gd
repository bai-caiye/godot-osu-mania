extends Node

const SONGS_PATH :String = "user://songs/"

func _ready() -> void:
	if !DirAccess.dir_exists_absolute(SONGS_PATH): DirAccess.make_dir_absolute(SONGS_PATH)
	get_viewport().files_dropped.connect(load_osz)
	#OS.shell_open(OS.get_user_data_dir())

##用于加载osu的osz文件
func load_osz(file_paths:PackedStringArray) -> void:
	var suffixs :Array[StringName] = [&"osu",&"mp3",&"ogg",&"wav",&"png",&"jpg",&"jpeg"]
	for i in len(file_paths):
		var reader := ZIPReader.new()
		var err := reader.open(file_paths[i])
		
		if err != OK:return PackedByteArray()
		
		var folder_name :String = file_paths[i].get_file().split(".")[0]
		var folder_path :String = SONGS_PATH + folder_name + "/"
		
		DirAccess.make_dir_absolute(folder_path)
		var file_names :PackedStringArray = reader.get_files()
		
		for file_name in file_names:
			if !suffixs.has(file_name.split(".")[-1]) or file_name.find("/") != -1:continue
			var res := reader.read_file(file_name)
			var res_file := FileAccess.open(folder_path+file_name,FileAccess.WRITE)
			if res: res_file.store_buffer(res)
			res_file.close()
		reader.close()
	get_tree().reload_current_scene()

##加载曲目文件返回beatmap
func load_beatmap(beatmap_floder_path :String, chart_path :String) -> Beatmap:
	if !DirAccess.dir_exists_absolute(beatmap_floder_path): return Beatmap.new()
	
	var beatmap_files :PackedStringArray = DirAccess.get_files_at(beatmap_floder_path)
	var beatmap :Beatmap = Beatmap.new()
	
	var file = FileAccess.open(chart_path,FileAccess.READ)
	if !file: return Beatmap.new()
	beatmap.chart = file.get_as_text().split("\r\n")
	file.close()
	#查找谱面指定音频文件
	var audio_path :String = beatmap_floder_path+"/"+beatmap.chart[beatmap.chart.find("[General]")+1].get_slice(": ",1)
	match audio_path.split(".")[-1]:
		&"mp3": beatmap.music = load_audio(audio_path, &"mp3")
		&"wav": beatmap.music = load_audio(audio_path, &"wav")
		&"ogg": beatmap.music = load_audio(audio_path, &"ogg")
	
	for file_name in beatmap_files:
		if ![&"png",&"jpg",&"jpeg"].has(file_name.split(".")[-1]): continue
		var image :Image = Image.load_from_file(beatmap_floder_path + "/" + file_name)
		beatmap.image = ImageTexture.create_from_image(image)
		break
	return beatmap

##加载谱面数据
func load_chart_data(chart: PackedStringArray) -> Dictionary:
	if chart.size() == 0: return {}
	var chart_data = {
	&"Title":"",         #音乐名称
	&"Artist":"",        #音乐作者
	&"Creato":"",        #谱师名称
	&"PreviewTime":0.0,  #音乐预览播放位置
	&"CircleSize":1,     #轨道数量
	&"Version":"",}      #版本
	
	var index :int = chart.find("[Metadata]") + 1
	while chart[index] != "": 
		match chart[index].get_slice(":",0):
			&"Title": chart_data[&"Title"] = chart[index].get_slice(":",1)
			&"Artist": chart_data[&"Artist"] = chart[index].get_slice(":",1)
			&"Creato": chart_data[&"Creato"] = chart[index].get_slice(":",1)
			&"PreviewTime": chart_data[&"PreviewTime"] = float(chart[index].get_slice(":",1))/1000
			&"Version": chart_data[&"Version"] = chart[index].get_slice(":",1)
			&"": break
		index += 1
	
	index = chart.find("[Difficulty]") + 1
	while chart[index] != "": 
		if chart[index].get_slice(":",0) == &"CircleSize":
			chart_data[&"CircleSize"] = int(chart[index].get_slice(":",1))
			break
		index += 1
	
	index = chart.find("[General]") + 1
	while chart[index] != "": 
		if chart[index].get_slice(":",0) == &"PreviewTime":
			chart_data[&"PreviewTime"] = float(chart[index].get_slice(":",1)) / 1000
			break
		index += 1
	return chart_data

##加载音频文件返回流
func load_audio(path: String, type: StringName = &"mp3") -> AudioStream:
	var file = FileAccess.open(path, FileAccess.READ)
	var audio
	match type:
		&"mp3": audio = AudioStreamMP3.new()
		&"wav": audio = AudioStreamWAV.new()
		&"ogg": return AudioStreamOggVorbis.load_from_file(path)
	audio.data = file.get_buffer(file.get_length())
	file.close()
	return audio
