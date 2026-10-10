class_name InventoryManager
extends RefCounted

var state: GameState
func _init(game_state: GameState) -> void:
	state = game_state

func reveal_box(index: int) -> Dictionary:
	if state.auction.get("stage") != "owned" or index < 0 or index >= state.auction.boxes.size():
		return {}
	var box: Dictionary = state.auction.boxes[index]
	if box.collected:
		return {}
	box.revealed = true
	return box.item.duplicate()

func collect_box(index: int) -> bool:
	if state.auction.get("stage") != "owned" or index < 0 or index >= state.auction.boxes.size():
		return false
	var box: Dictionary = state.auction.boxes[index]
	if not box.revealed or box.collected:
		return false
	state.inventory.append(box.item.duplicate())
	box.collected = true
	state.items_found += 1
	state.experience += 5
	if state.remaining_boxes() == 0:
		state.auction.stage = "cleared"
	return true

func find_item(uid: int) -> Dictionary:
	for item in state.inventory:
		if int(item.uid) == uid:
			return item
	return {}
