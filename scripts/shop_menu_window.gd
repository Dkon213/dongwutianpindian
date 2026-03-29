extends Window

## 商店弹窗：按显示器比例计算物理尺寸，大/中/小三档；内部 UI 以 BASE_DESIGN_SIZE 为逻辑分辨率整体缩放。

const CONFIG_PATH: String = "user://shop_window.cfg"
const CONFIG_SECTION: String = "shop"
const KEY_SIZE_PRESET: String = "size_preset"

const BASE_DESIGN_SIZE := Vector2(752, 600)

# 各档位占当前显示器宽、高的比例（在保持 752:600 宽高比的前提下取 min 缩放，塞进该矩形内）
# 无 user://shop_window.cfg 存档时默认使用「中」= 第二项 (0.22, 0.30)
const PRESET_SCREEN_FRACTIONS: Array[Vector2] = [
	Vector2(0.18, 0.23), # 小
	Vector2(0.22, 0.30), # 中（默认档位）
	Vector2(0.30, 0.42), # 大
]

const MIN_SCALE: float = 0.35
const MAX_SCALE: float = 1.35

enum SizePreset { SMALL, MEDIUM, LARGE }

@onready var _scaled_root: Control = $shop_content_scaled_root
@onready var _size_option: OptionButton = $shop_size_toolbar/HBoxContainer/size_option

# 无存档时保持为 MEDIUM，对应 PRESET_SCREEN_FRACTIONS[1] = (0.22, 0.30)
var _preset: SizePreset = SizePreset.MEDIUM
var _syncing_option: bool = false


func _ready() -> void:
	_setup_size_option()
	_load_preset()
	_refresh_option_state()
	if _size_option:
		_size_option.item_selected.connect(_on_size_option_selected)
	_apply_size_for_screen(_get_screen_index_for_sizing())


func prepare_for_popup_at_global_pos(global_pos: Vector2) -> void:
	_apply_size_for_screen(_screen_index_at_global_pos(global_pos))


func set_size_preset(preset: SizePreset, persist: bool = true) -> void:
	_preset = preset
	if persist:
		_save_preset()
	_refresh_option_state()
	_apply_size_for_screen(_get_screen_index_for_sizing())


func _setup_size_option() -> void:
	if _size_option == null:
		return
	_size_option.clear()
	_size_option.add_item("小", SizePreset.SMALL)
	_size_option.add_item("中", SizePreset.MEDIUM)
	_size_option.add_item("大", SizePreset.LARGE)


func _on_size_option_selected(index: int) -> void:
	if _syncing_option:
		return
	set_size_preset(index as SizePreset)


func _refresh_option_state() -> void:
	if _size_option == null:
		return
	_syncing_option = true
	_size_option.select(int(_preset))
	_syncing_option = false


func _get_screen_index_for_sizing() -> int:
	if visible:
		var center := Vector2(position) + 0.5 * Vector2(size)
		return _screen_index_at_global_pos(center)
	return _get_reference_screen_index()


func _screen_index_at_global_pos(global_pos: Vector2) -> int:
	var pt := Vector2i(int(global_pos.x), int(global_pos.y))
	for i in range(DisplayServer.get_screen_count()):
		var sp: Vector2i = DisplayServer.screen_get_position(i)
		var sz: Vector2i = DisplayServer.screen_get_size(i)
		if Rect2i(sp, sz).has_point(pt):
			return i
	return _get_reference_screen_index()


func _get_reference_screen_index() -> int:
	var rw: Window = get_tree().root as Window
	if rw != null:
		return DisplayServer.window_get_current_screen(rw.get_window_id())
	return 0


func _apply_size_for_screen(screen: int) -> void:
	screen = clampi(screen, 0, DisplayServer.get_screen_count() - 1)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
	if screen_size.x < 1 or screen_size.y < 1:
		return
	# 已显示时改尺寸：固定右下角，避免变大后左上角伸出屏幕外
	var preserve_bottom_right := visible
	var bottom_right := Vector2(position) + Vector2(size)
	var frac: Vector2 = PRESET_SCREEN_FRACTIONS[int(_preset)]
	var target := Vector2(screen_size.x * frac.x, screen_size.y * frac.y)
	var s: float = minf(target.x / BASE_DESIGN_SIZE.x, target.y / BASE_DESIGN_SIZE.y)
	s = clampf(s, MIN_SCALE, MAX_SCALE)
	if _scaled_root:
		_scaled_root.scale = Vector2(s, s)
	var w: int = int(ceil(BASE_DESIGN_SIZE.x * s))
	var h: int = int(ceil(BASE_DESIGN_SIZE.y * s))
	var new_size := Vector2i(maxi(w, 1), maxi(h, 1))
	size = new_size
	if preserve_bottom_right:
		position = Vector2i(
			int(round(bottom_right.x - float(new_size.x))),
			int(round(bottom_right.y - float(new_size.y)))
		)


func _load_preset() -> void:
	var cfg := ConfigFile.new()
	# 无文件或无键：保留 _preset 初值 MEDIUM（即 (0.22, 0.30) 档位）
	if cfg.load(CONFIG_PATH) != OK:
		return
	if not cfg.has_section_key(CONFIG_SECTION, KEY_SIZE_PRESET):
		return
	var v: int = int(cfg.get_value(CONFIG_SECTION, KEY_SIZE_PRESET, SizePreset.MEDIUM))
	var max_i: int = PRESET_SCREEN_FRACTIONS.size() - 1
	_preset = clampi(v, 0, max_i) as SizePreset


func _save_preset() -> void: # 保存设置
	var cfg := ConfigFile.new() # 创建配置文件
	cfg.load(CONFIG_PATH) # 加载配置文件
	cfg.set_value(CONFIG_SECTION, KEY_SIZE_PRESET, int(_preset)) # 设置配置文件
	cfg.save(CONFIG_PATH) # 保存配置文件	
