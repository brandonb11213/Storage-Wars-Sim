class_name EconomyManager
extends RefCounted

var state: GameState
func _init(game_state: GameState) -> void:
	state = game_state

func offer(item: Dictionary) -> int:
	return maxi(1, int(round(int(item.value) * (0.8 + 0.04 * int(state.upgrades.appraisal)))))

func sell(uids: Array) -> Dictionary:
	# Validate the entire selection before modifying cash or inventory.
	if uids.is_empty():
		return {"ok": false, "earned": 0}
	var unique: Dictionary = {}
	for uid in uids:
		if unique.has(int(uid)):
			return {"ok": false, "earned": 0}
		unique[int(uid)] = true
	var found: Array = []
	var earned = 0
	for item in state.inventory:
		if unique.has(int(item.uid)):
			found.append(item)
			earned += offer(item)
	if found.size() != unique.size():
		return {"ok": false, "earned": 0}
	for item in found:
		state.inventory.erase(item)
	state.cash += earned
	state.total_earned += earned
	state.sales += found.size()
	state.experience += found.size() * 8
	return {"ok": true, "earned": earned}

func net_profit() -> int:
	return state.total_earned - state.total_spent - state.upgrade_spent

func recovery_target() -> int:
	return maxi(35, int(state.auction.get("starting_bid", 35)))

func can_clearout() -> bool:
	return state.cash < recovery_target() and state.inventory.is_empty() and not state.auction.get("stage") in ["bidding", "owned"]

func garage_clearout(database: ItemDatabase) -> bool:
	# Prevent bankruptcy from permanently trapping an offline save. Only available when empty.
	if not can_clearout():
		return false
	var rng = RandomNumberGenerator.new()
	rng.seed = state.world_seed + state.next_item_id * 37
	state.inventory.append(database.generate(rng, 0, state.next_item_id))
	state.next_item_id += 1
	return true
