# 全局音频管理：BGM 单曲循环、音量、配置持久化
extends Node

# BGM 列表（写死）：对应 assets/BGM 下的 1.mp3, 2.mp3, 3.mp3
const BGM_PATHS: Array[String] = [
	"res://assets/BGM/1.mp3",
	"res://assets/BGM/2.mp3",
	"res://assets/BGM/3.mp3"
]

const CONFIG_PATH: String = "user://audio_settings.cfg"
const CONFIG_SECTION: String = "audio"
const KEY_BGM_INDEX: String = "bgm_index"
const KEY_BGM_VOLUME: String = "bgm_volume"
const KEY_SFX_VOLUME: String = "sfx_volume"

var _bgm_player: AudioStreamPlayer
var _current_bgm_index: int = 0
# 0.0~1.0 线性，存盘用；播放时转 dB
var _bgm_volume_linear: float = 0.8
var _sfx_volume_linear: float = 0.8


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	_bgm_player.finished.connect(_on_bgm_finished)
	_load_config()
	_apply_bgm_volume()
	# 启动时默认单曲循环播放第二首
	play_bgm(1)


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	if cfg.has_section_key(CONFIG_SECTION, KEY_BGM_INDEX):
		_current_bgm_index = clampi(cfg.get_value(CONFIG_SECTION, KEY_BGM_INDEX, 0), 0, BGM_PATHS.size() - 1)
	if cfg.has_section_key(CONFIG_SECTION, KEY_BGM_VOLUME):
		_bgm_volume_linear = clampf(cfg.get_value(CONFIG_SECTION, KEY_BGM_VOLUME, 0.8), 0.0, 1.0)
	if cfg.has_section_key(CONFIG_SECTION, KEY_SFX_VOLUME):
		_sfx_volume_linear = clampf(cfg.get_value(CONFIG_SECTION, KEY_SFX_VOLUME, 0.8), 0.0, 1.0)


func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(CONFIG_SECTION, KEY_BGM_INDEX, _current_bgm_index)
	cfg.set_value(CONFIG_SECTION, KEY_BGM_VOLUME, _bgm_volume_linear)
	cfg.set_value(CONFIG_SECTION, KEY_SFX_VOLUME, _sfx_volume_linear)
	cfg.save(CONFIG_PATH)


func _on_bgm_finished() -> void:
	# 单曲循环：播完再播当前首
	play_bgm(_current_bgm_index)


# 线性 0~1 转 dB（0 静音约 -80dB，1 约 0dB）
static func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return linear * 20.0 - 20.0  # 简单映射：1.0 -> 0dB


func _apply_bgm_volume() -> void:
	_bgm_player.volume_db = _linear_to_db(_bgm_volume_linear)


# --- 对外接口 ---

## 播放第 index 首 BGM（0-based），单曲循环
func play_bgm(index: int) -> void:
	if index < 0 or index >= BGM_PATHS.size():
		return
	_current_bgm_index = index
	var path: String = BGM_PATHS[index]
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: 无法加载 BGM: " + path)
		return
	_bgm_player.stream = stream
	_bgm_player.play()


## 当前 BGM 索引（0-based）
func get_current_bgm_index() -> int:
	return _current_bgm_index


## BGM 数量
func get_bgm_count() -> int:
	return BGM_PATHS.size()


## 设置 BGM 音量（0.0 ~ 1.0 线性），并保存配置
func set_bgm_volume_linear(linear: float) -> void:
	_bgm_volume_linear = clampf(linear, 0.0, 1.0)
	_apply_bgm_volume()
	_save_config()


## 获取 BGM 音量（0.0 ~ 1.0）
func get_bgm_volume_linear() -> float:
	return _bgm_volume_linear


## 设置音效音量（0.0 ~ 1.0），并保存配置；后续播放音效时用此音量
func set_sfx_volume_linear(linear: float) -> void:
	_sfx_volume_linear = clampf(linear, 0.0, 1.0)
	_save_config()


## 获取音效音量（0.0 ~ 1.0）
func get_sfx_volume_linear() -> float:
	return _sfx_volume_linear


## 供 UI 显示：当前 BGM 的显示名（如 "1"、"2"、"3"）
func get_current_bgm_display_name() -> String:
	return str(_current_bgm_index + 1)
