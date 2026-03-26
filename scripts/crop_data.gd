extends Node

## 作物/果实统一配置中心（Autoload 单例 CropDB）
## 新增作物时：1. 在 CROP_IDS 末尾添加 ID，2. 在 CROPS 中添加该 ID 的完整配置，
## 3. 在 TileMap 中增加对应图层/图块，4. 在 fruits.tscn 的 AnimatedSprite2D 中添加同名动画。

# 作物 ID 的显示顺序（仓库格子顺序、商店商品顺序等）
const CROP_IDS: Array[String] = ["carrot", "tomato", "wheat"]

# 每种作物的完整属性（key = 作物 ID，与 plant_type / fruit_type 一致）
const CROPS: Dictionary = {
	"carrot": {
		"tile_source_id": 1,           # TileMap 植物图层 source_id
		"fruit_price": 5,              # 果实出售单价（金币）
		"barn_icon_path": "res://assets/Things/field/fruits/fruit_carrot.png",
		"seed_texture_path": "res://assets/Things/field/shop/ZHONGZ-CARROTI.png",
		"seed_name": "萝卜种子",
		"seed_price": 50,
		"grow_time": Vector2(300.0, 400.0), # 每阶段随机生长时长区间（秒）
		"water_time": 250.0,                 # 每阶段浇水解锁时长（秒）
	},
	"tomato": {
		"tile_source_id": 2,
		"fruit_price": 10,
		"barn_icon_path": "res://assets/Things/field/fruits/fruit_tomato.png",
		"seed_texture_path": "res://assets/Things/field/shop/ZHONGZ-TOMATOI.png",
		"seed_name": "番茄种子",
		"seed_price": 50,
		"grow_time": Vector2(100.0, 120.0),
		"water_time": 80.0,
	},
	"wheat": {
		"tile_source_id": 3,
		"fruit_price": 2,
		"barn_icon_path": "res://assets/Things/field/fruits/fruit_wheat.png",
		"seed_texture_path": "res://assets/Things/field/shop/ZHONGZ-WHEAT.png",
		"seed_name": "小麦种子",
		"seed_price": 50,
		"grow_time": Vector2(15.0, 30.0),
		"water_time": 8.0,
	},
}


func has_crop(crop_id: String) -> bool:
	return CROPS.has(crop_id)


func get_tile_source_id(crop_id: String) -> int:
	var data: Dictionary = CROPS.get(crop_id, {})
	return data.get("tile_source_id", 0)


func get_fruit_price(crop_id: String) -> int:
	var data: Dictionary = CROPS.get(crop_id, {})
	return data.get("fruit_price", 0)


func get_barn_icon_path(crop_id: String) -> String:
	var data: Dictionary = CROPS.get(crop_id, {})
	return data.get("barn_icon_path", "")


func get_grow_time_range(crop_id: String) -> Vector2:
	var data: Dictionary = CROPS.get(crop_id, {})
	var range_val: Vector2 = data.get("grow_time", Vector2(5.0, 5.0))
	var min_v: float = minf(range_val.x, range_val.y)
	var max_v: float = maxf(range_val.x, range_val.y)
	return Vector2(min_v, max_v)


func get_water_time(crop_id: String) -> float:
	var data: Dictionary = CROPS.get(crop_id, {})
	return maxf(0.0, float(data.get("water_time", 5.0)))


## 返回按 CROP_IDS 顺序排列的作物 ID 数组（用于仓库、遍历等）
func get_crop_ids() -> Array:
	return CROP_IDS.duplicate()


## 返回商店商品列表，每项含 texture_path, name, price, plant_type（与原有 SHOP_ITEMS 格式一致）
func get_shop_items() -> Array:
	var items: Array = []
	for crop_id in CROP_IDS:
		if not CROPS.has(crop_id):
			continue
		var data: Dictionary = CROPS[crop_id]
		items.append({
			"texture_path": data.get("seed_texture_path", ""),
			"name": data.get("seed_name", ""),
			"price": data.get("seed_price", 0),
			"plant_type": crop_id,
		})
	return items
