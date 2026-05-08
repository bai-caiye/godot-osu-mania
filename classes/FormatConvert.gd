class_name FormatConvert extends Node
## 工具脚本 用于把osu的数据格式转换成可用的

static func type(x) -> StringName:
	match int(x):
		128: return &"hold"
		_: return &"tap"


static func track(x, track_quantity :int) -> int:
	return int(float(int(x) * track_quantity) / 512.0)


static func time(v) -> float:
	return float(v) / 1000.0
