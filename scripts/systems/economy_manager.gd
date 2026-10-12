class_name EconomyManager
extends RefCounted

var state: GameState
var database: ItemDatabase
func _init(game_state: GameState) -> void:
	state = game_state
	database = ItemDatabase.new()

func offer(item: Dictionary) -> int:
	var bonus = 0.05 * int(state.upgrades.selling)
	if state.upgrades.demand > 0 and item.has("definition") and int(database.by_id[item.definition].rarity) >= 2:
		bonus += 0.1
	return maxi(1, int(round(int(item.value) * (0.8 + 0.04 * int(state.upgrades.appraisal) + bonus))))

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
		if state.display_uid == int(item.uid): state.display_uid = 0
	state.cash += earned
	state.total_earned += earned
	state.sales += found.size()
	state.experience += found.size() * 8
	return {"ok": true, "earned": earned}

func net_profit() -> int:
	return state.total_earned - state.total_spent - state.upgrade_spent - state.transport_spent - state.preparation_spent

func recovery_target() -> int:
	return maxi(220, int(state.auction.get("starting_bid", 35)) + TransportManager.new(state, database).quote() + 120)

func can_clearout() -> bool:
	return state.cash < recovery_target() and state.inventory.is_empty() and not state.auction.get("stage") in ["bidding", "owned"]

func garage_clearout(database: ItemDatabase) -> bool:
	# Prevent bankruptcy from permanently trapping an offline save. Only available when empty.
	if not can_clearout():
		return false
	var rng = RandomNumberGenerator.new()
	rng.seed = state.world_seed + state.next_item_id * 37
	var item = database.generate_definition(rng, database.by_id.recovery_lot, state.next_item_id)
	item.value = maxi(int(item.value), ceili(recovery_target() / 0.8))
	state.inventory.append(item)
	state.recovery_jobs += 1
	state.next_item_id += 1
	return true

func prepare(uid: int, restore: bool = false) -> bool:
	if state.auction.get("stage") == "bidding": return false
	var item = InventoryManager.new(state).find_item(uid)
	if item.is_empty() or (restore and (state.upgrades.restoration == 0 or int(item.condition) != 2)) or (not restore and (state.upgrades.cleaning == 0 or int(item.condition) > 1)):
		return false
	var fee = preparation_cost(item, restore)
	if state.cash < fee: return false
	state.cash -= fee
	state.preparation_spent += fee
	item.condition = 3 if restore else 2
	item.value = int(round(int(item.value) * (1.25 if restore else 1.2)))
	return true

func preparation_cost(item: Dictionary, restore: bool = false) -> int:
	return maxi(2, ceili(int(item.value) * (0.15 if restore else 0.08)))
