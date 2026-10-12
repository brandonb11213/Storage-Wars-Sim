class_name ItemDatabase
extends RefCounted

const RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]
const COLORS = [Color("b5cbd4"), Color("78d79a"), Color("69b8ff"), Color("c097ff"), Color("ffc969"), Color("ff83bc")]
const CONDITIONS = ["Worn", "Fair", "Good", "Pristine"]
const CONDITION_FACTORS = [0.5, 0.7, 0.9, 1.15]
static var catalogue: Array = []
var items: Array = []
var by_id: Dictionary = {}

func _init() -> void:
	if catalogue.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
		if parsed is Array: catalogue = parsed
	items = catalogue
	for item in items: by_id[item.id] = item

func generate(rng: RandomNumberGenerator, access: int, unique_id: int, categories: Array = []) -> Dictionary:
	var roll = rng.randf()
	var thresholds = [0.58 - access * 0.04, 0.84 - access * 0.03, 0.95 - access * 0.02, 0.99 - access * 0.005, 0.999]
	var rarity = 5
	for index in thresholds.size():
		if roll < thresholds[index]:
			rarity = index
			break
	var pool = items.filter(func(item): return int(item.rarity) == rarity and not item.get("recovery_only", false))
	var themed = pool.filter(func(item): return item.category in categories)
	if not themed.is_empty() and rng.randf() < 0.75:
		pool = themed
	var definition: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	return generate_definition(rng, definition, unique_id)

func generate_definition(rng: RandomNumberGenerator, definition: Dictionary, unique_id: int, featured: bool = false) -> Dictionary:
	var condition = rng.randi_range(0, 3)
	var value = maxi(1, int(round(float(definition.value) * CONDITION_FACTORS[condition] * rng.randf_range(0.15 if featured else 0.65, 1.15))))
	return {"uid": unique_id, "definition": definition.id, "condition": condition, "value": value}

func describe(item: Dictionary) -> Dictionary:
	var result: Dictionary = by_id[item.definition].duplicate()
	result.merge(item, true)
	return result

func estimate(item: Dictionary, appraisal: int) -> int:
	# Estimates approach the real value as the player learns appraisal; offers remain explicit.
	var uncertainty = 0.18 / float(appraisal + 1)
	var factor = 1.0 + uncertainty * (-1.0 if int(item.uid) % 2 == 0 else 1.0)
	return maxi(1, int(round(int(item.value) * factor)))

func cargo_size(item: Dictionary) -> int:
	return int(by_id[item.definition].get("size", 1))
