class_name StorageUnitGenerator
extends RefCounted

const THEMES = ["Weekend collector", "Garage clear-out", "Moving day", "Market trader"]
var database: ItemDatabase

func _init(item_database: ItemDatabase) -> void:
	database = item_database

func generate(state: GameState) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = state.world_seed + state.auction_serial * 7919
	var boxes: Array = []
	for index in 6:
		var item = database.generate(rng, int(state.upgrades.auction_access), state.next_item_id)
		state.next_item_id += 1
		boxes.append({"item": item, "revealed": false, "collected": false})
	var starting_bid = 20 + rng.randi_range(0, 3) * 5 + int(state.upgrades.auction_access) * 10
	return {"seed": rng.seed, "theme": THEMES[rng.randi_range(0, THEMES.size() - 1)],
		"boxes": boxes, "starting_bid": starting_bid, "increment": 10, "price": starting_bid - 10,
		"leader": "", "stage": "preview", "round": 0, "npcs": [], "log": []}
