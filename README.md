# Godot-OsuMania
基于 **Godot4.6** + **GDScript **复刻的 **Osu!Mania** 模式

项目使用 GPL-3.0 协议——任何修改与衍生版本必须继续开源

```markdown
**License:** GPL-3.0
```

## 🚀 功能特性

- **超简单的谱面导入**: 只需要把从https://osu.ppy.sh/beatmapsets?m=3 下载的.osz 直接把拖入窗口即可 会自动保存到用户文件夹

- **谱面支持**：支持解析mania格式的 `.osu` 标准谱面格式 v14和 v128 基本适配

- **动态 SV 系统**：完美实现变速（Scroll Velocity）逻辑，音符移动距离基于时间点和倍率动态计算，而非简单的线性移动。

- **高精度音频同步**：

  - 结合 `AudioServer.get_time_since_last_mix()` 和延迟补偿（Latency）。
  - 内置 `music_time` 每一帧与音频播放位置进行差值校验与对齐。

- **对象池优化**：利用 `ObjectPool` 实现 Tap 和 Hold 音符的循环利用，降低大规模 Note 场景下的内存抖动与卡顿

- **预计算**：内置 `lead_time` 预计算逻辑，确保在不同 SV 环境下音符都能在正确的时机出现在屏幕上方

- **多 Key 支持**：支持1~10轨道数，内置 4K/7K 默认配色逻辑

  

## ⌨️ 快捷键

- **`~` (反引号)**：快速重启当前关卡

- **`Esc`**：暂停/恢复游戏

- **`Enter`** 打开导入谱面列表 (测试快捷键后面可能会删除)

  

## ⚙️ 配置参数

- **ChartPath**: 谱面文件路径

- **Speed**：基础流速（默认 1500）决定了 Note 的整体飞行快慢

- **Offset**：全局偏移调整（单位：秒）用于适配不同设备的音频延迟

- **Auto Play**：开启后，判定系统将自动在 `0ms` 偏移处完美击打 Note

  

## 🔜 待办事项

- [ ] 接入更完善的结算系统（Combo, Accuracy, Rank）
- [ ] 实现谱面选择界面
- [ ] 优化note渲染

------

**参考链接**：[Godot Osu!Mania 游戏开发实践](https://zread.ai/bai-caiye/godot-osu-mania)

以上内容由 AI 生成

如果你觉得这个核心逻辑对你有帮助，欢迎点个 Star！🌟

