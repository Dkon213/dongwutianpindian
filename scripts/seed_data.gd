# 种子类型配置数据
extends Node

# 种子类型配置字典
var SEED_TYPES = {
	"wheat": {
		"name": "小麦",
		"stages": {
			"seed": {"sprite": "res://assets/crops/wheat_seed.png"},
			"sprout": {"sprite": "res://assets/crops/wheat_sprout.png"},
			"mature": {"sprite": "res://assets/crops/wheat_mature.png"},
			"fruit": {"sprite": "res://assets/crops/wheat_fruit.png"}
		},
		"growth_chance": 0.3,  # 每次浇水的成长概率
		"min_water_per_stage": {  # 每个阶段的最小浇水次数（保底）
			"seed": 1,
			"sprout": 2,
			"mature": 2
		}
	},
	"carrot": {
		"name": "胡萝卜",
		"stages": {
			"seed": {"sprite": "res://assets/crops/carrot_seed.png"},
			"sprout": {"sprite": "res://assets/crops/carrot_sprout.png"},
			"mature": {"sprite": "res://assets/crops/carrot_mature.png"},
			"fruit": {"sprite": "res://assets/crops/carrot_fruit.png"}
		},
		"growth_chance": 0.25,
		"min_water_per_stage": {
			"seed": 1,
			"sprout": 2,
			"mature": 2
		}
	},
	"tomato": {
		"name": "番茄",
		"stages": {
			"seed": {"sprite": "res://assets/crops/tomato_seed.png"},
			"sprout": {"sprite": "res://assets/crops/tomato_sprout.png"},
			"mature": {"sprite": "res://assets/crops/tomato_mature.png"},
			"fruit": {"sprite": "res://assets/crops/tomato_fruit.png"}
		},
		"growth_chance": 0.2,
		"min_water_per_stage": {
			"seed": 1,
			"sprout": 3,
			"mature": 2
		}
	}
}

# 获取种子类型列表
static func get_seed_types() -> Array:
	return SEED_TYPES.keys()

# 获取随机种子类型
static func get_random_seed_type() -> String:
	var types = get_seed_types()
	return types[randi() % types.size()]

