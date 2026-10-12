class_name StorageUnitGenerator
extends RefCounted

# Old theme names remain valid only for migrated auctions.
const LEGACY_THEMES = ["Weekend collector", "Garage clear-out", "Moving day", "Market trader"]
var database: ItemDatabase

func _init(item_database: ItemDatabase) -> void:
	database = item_database

func generate(state: GameState) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	var unit_seed = state.world_seed + state.auction_serial * 7919
	rng.seed = unit_seed
	var config = GameplayData.get_config()
	var theme: Dictionary = config.themes[rng.randi_range(0, 7)]
	if state.district == 1:
		theme = config.themes[[1, 3, 6, 7][rng.randi_range(0, 3)]]
	var roll = rng.randf()
	var feature = 3
	var cumulative = 0.0
	for index in 4:
		cumulative += float(config.featured_probabilities[index])
		if roll < cumulative:
			feature = index
			break
	var boxes: Array = []
	for index in 6:
		var item = database.generate(rng, int(state.upgrades.auction_access) + state.district, state.next_item_id, theme.categories)
		var visible = ""
		if index == 0 and feature > 0:
			var pool: Array = config.featured_pools[feature - 1]
			var definition: Dictionary = database.by_id[pool[rng.randi_range(0, pool.size() - 1)]]
			item = database.generate_definition(rng, definition, state.next_item_id, true)
			visible = str(definition.shape)
		elif index in [1, 4]:
			visible = str(database.by_id[item.definition].shape)
		state.next_item_id += 1
		boxes.append({"item": item, "revealed": false, "collected": false, "visible": visible})
	var starting_bid = 20 + rng.randi_range(0, 3) * 5 + int(state.upgrades.auction_access) * 10 + state.district * 20
	return {"seed": unit_seed, "theme": theme.name, "boxes": boxes, "featured": feature,
		"clue_value": int(theme.clue_value) + feature * 100, "district": state.district,
		"transport_cost": 0, "starting_bid": starting_bid, "increment": 10, "price": starting_bid - 10,
		"leader": "", "stage": "preview", "round": 0, "npcs": [], "log": []}
