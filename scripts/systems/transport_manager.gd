class_name TransportManager
extends RefCounted
var state: GameState
var database: ItemDatabase

func _init(game_state: GameState, item_database: ItemDatabase) -> void:
	state = game_state
	database = item_database

func capacity() -> int:
	return 6 + 6 * int(state.upgrades.vehicle)

func storage_capacity() -> int:
	return 24 + 18 * int(state.upgrades.garage) + 12 * int(state.upgrades.shelving)

func stored_cargo() -> int:
	var total = 0
	for item in state.inventory:
		total += database.cargo_size(item)
	return total

func unit_cargo() -> int:
	var total = 0
	for box in state.auction.get("boxes", []):
		total += database.cargo_size(box.item)
	return total

func trips() -> int:
	return ceili(float(unit_cargo()) / capacity())

func quote() -> int:
	return trips() * (6 + int(state.auction.get("district", 0)) * 2 - 2 * int(state.upgrades.operations))
