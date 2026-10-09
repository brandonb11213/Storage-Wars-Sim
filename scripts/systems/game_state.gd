class_name GameState
extends RefCounted

var cash: int = 500
var inventory: Array = []
var experience: int = 0
var upgrades: Dictionary = {"appraisal": 0, "auction_access": 0}
var auction: Dictionary = {}
var auction_serial: int = 0
var next_item_id: int = 1
var world_seed: int = 0
var auctions_won: int = 0
var auctions_lost: int = 0
var items_found: int = 0
var sales: int = 0
var total_spent: int = 0
var total_earned: int = 0
var upgrade_spent: int = 0

func _init(seed_value: int = 0) -> void:
	world_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system()) % 2000000000

func to_dict() -> Dictionary:
	return {"cash": cash, "inventory": inventory.duplicate(true), "experience": experience,
		"upgrades": upgrades.duplicate(), "auction": auction.duplicate(true),
		"auction_serial": auction_serial, "next_item_id": next_item_id, "world_seed": world_seed,
		"auctions_won": auctions_won, "auctions_lost": auctions_lost, "items_found": items_found,
		"sales": sales, "total_spent": total_spent, "total_earned": total_earned, "upgrade_spent": upgrade_spent}

static func from_dict(data: Dictionary) -> GameState:
	var state = GameState.new(int(data.world_seed))
	for key in data:
		state.set(key, data[key])
	return state

func remaining_boxes() -> int:
	var count = 0
	for box in auction.get("boxes", []):
		if not box.collected:
			count += 1
	return count
