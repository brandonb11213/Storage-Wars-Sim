class_name ProgressionManager
extends RefCounted

const UPGRADES = {
	"appraisal": {"name": "Appraisal desk", "description": "Sharper estimates and +4% pawn offers per tier.", "base_cost": 75, "max": 3},
	"auction_access": {"name": "Auction pass", "description": "Better rare-item odds; higher opening bids.", "base_cost": 120, "max": 3}}
var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

func level() -> int:
	return mini(100, 1 + state.experience / 100)

func cost(key: String) -> int:
	return int(UPGRADES[key].base_cost) * (int(state.upgrades[key]) + 1)

func purchase(key: String) -> bool:
	if state.auction.get("stage") == "bidding":
		return false
	if not UPGRADES.has(key) or int(state.upgrades[key]) >= int(UPGRADES[key].max) or state.cash < cost(key):
		return false
	var paid = cost(key)
	state.cash -= paid
	state.upgrade_spent += paid
	state.upgrades[key] += 1
	return true
