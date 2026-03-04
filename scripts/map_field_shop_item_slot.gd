extends PanelContainer
## 商店商品格子，用于展示单个商品的图片、名称和价格。可点击以拿起对应种子。

signal item_clicked(plant_type: String, texture: Texture2D)

var _pending_texture: Texture2D
var _pending_name: String = ""
var _pending_price: int = 0
var _pending_plant_type: String = ""


func setup(texture: Texture2D, item_name: String, price: int, plant_type: String = "") -> void:
	"""配置商品格子的显示内容。plant_type 与 farming_system 的 PlantDB 对应（如 carrot、tomato、wheat）。"""
	_pending_texture = texture
	_pending_name = item_name
	_pending_price = price
	_pending_plant_type = plant_type
	_apply_pending()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	_apply_pending()


func _on_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _pending_plant_type != "" and _pending_texture != null:
		item_clicked.emit(_pending_plant_type, _pending_texture)


func _apply_pending() -> void:
	if _pending_texture == null:
		return
	var texture_rect := get_node_or_null("MarginContainer/VBoxContainer/texture") as TextureRect
	var label_name := get_node_or_null("MarginContainer/VBoxContainer/Label_name") as Label
	var label_cost := get_node_or_null("MarginContainer/VBoxContainer/Label_cost") as Label
	if texture_rect == null or label_name == null or label_cost == null:
		return  # 尚未进入场景树，等 _ready 时再应用
	texture_rect.texture = _pending_texture
	label_name.text = _pending_name
	label_cost.text = str(_pending_price)
