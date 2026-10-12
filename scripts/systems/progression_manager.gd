class_name ProgressionManager
extends RefCounted

static var UPGRADES: Dictionary = GameplayData.get_config().upgrades
const QUESTS = ["first_auction", "rare_discovery", "sales_1000", "expanded_garage", "second_district", "cargo_upgrade", "collectible_set"]
const QUEST_NAMES = ["Win your first auction", "Discover a Rare or better item", "Earn $1,000 in cumulative sales", "Expand your garage", "Unlock Suburban Storage", "Upgrade pickup cargo", "Discover 3 different shelf classics"]
const REWARDS = [40, 60, 100, 50, 80, 40, 100]
var state: GameState

func _init(game_state: GameState) -> void:
	state = game_state

func level() -> int:
	return mini(100, 1 + state.experience / 100)

func cost(key: String) -> int:
	return int(UPGRADES[key].base_cost) * (int(state.upgrades[key]) + 1) if UPGRADES.has(key) else 0

func requirement(key: String) -> String:
	var info: Dictionary = UPGRADES[key]
	if level() < int(info.level):
		return "Requires level %d" % int(info.level)
	if not str(info.requires).is_empty() and int(state.upgrades[info.requires]) == 0:
		return "Requires " + str(UPGRADES[info.requires].name)
	return ""

func purchase(key: String) -> bool:
	if state.auction.get("stage") == "bidding" or not UPGRADES.has(key):
		return false
	if int(state.upgrades[key]) >= int(UPGRADES[key].max) or state.cash < cost(key) or not requirement(key).is_empty():
		return false
	var paid = cost(key)
	state.cash -= paid
	state.upgrade_spent += paid
	state.upgrades[key] += 1
	return true

func quest_complete(key: String) -> bool:
	match key:
		"first_auction": return state.auctions_won > 0
		"rare_discovery":
			var db = ItemDatabase.new()
			for id in state.discoveries:
				if int(db.by_id[id].rarity) >= 2: return true
		"sales_1000": return state.total_earned >= 1000
		"expanded_garage": return state.upgrades.garage > 0
		"second_district": return state.upgrades.district > 0
		"cargo_upgrade": return state.upgrades.vehicle > 0
		"collectible_set":
			var count = 0
			var db = ItemDatabase.new()
			for id in state.discoveries:
				if db.by_id[id].get("set", "") == "shelf_classics": count += 1
			return count >= 3
	return false

func claim_quests() -> Array:
	var claimed: Array = []
	for index in QUESTS.size():
		var key: String = QUESTS[index]
		if not key in state.quests and quest_complete(key):
			state.quests.append(key)
			state.cash += REWARDS[index]
			state.quest_earned += REWARDS[index]
			state.experience += 15
			claimed.append(QUEST_NAMES[index])
	return claimed
