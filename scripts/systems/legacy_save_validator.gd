class_name LegacySaveValidator
extends RefCounted
var database: ItemDatabase
func _init(db: ItemDatabase) -> void:
	database = db

func _integer(value, minimum: int = 0, maximum: int = 2000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

func _item(item) -> bool:
	if not item is Dictionary or item.size() != 4:
		return false
	return _integer(item.get("uid"), 1) and database.by_id.has(item.get("definition")) and _integer(item.get("condition"), 0, 3) and _integer(item.get("value"), 1, 100000)

func validate(data: Dictionary) -> bool:
	var expected = {"cash": 0, "inventory": [], "experience": 0, "upgrades": {}, "auction": {}, "auction_serial": 0, "next_item_id": 0, "world_seed": 0, "auctions_won": 0, "auctions_lost": 0, "items_found": 0, "sales": 0, "total_spent": 0, "total_earned": 0, "upgrade_spent": 0}
	if data.size() != expected.size():
		return false
	for key in expected:
		if not data.has(key):
			return false
		if expected[key] is int and not _integer(data[key]):
			return false
	if data.next_item_id < 1 or not data.inventory is Array or data.inventory.size() > 10000 or not data.upgrades is Dictionary:
		return false
	if data.upgrades.size() != 2:
		return false
	for key in ["appraisal", "auction_access"]:
		if not _integer(data.upgrades.get(key), 0, 3):
			return false
	var ids: Dictionary = {}
	for item in data.inventory:
		if not _item(item) or ids.has(int(item.uid)) or item.uid >= data.next_item_id:
			return false
		ids[int(item.uid)] = true
	if not data.auction is Dictionary:
		return false
	if data.auction.is_empty():
		return true
	var auction: Dictionary = data.auction
	if auction.size() != 11 or not auction.get("stage") in ["preview", "bidding", "owned", "cleared", "lost"] or not auction.get("theme") in StorageUnitGenerator.LEGACY_THEMES:
		return false
	if not _integer(auction.get("seed"), 0, 100000000000000) or not _integer(auction.get("starting_bid"), 1, 1000) or not _integer(auction.get("increment"), 1, 100) or not _integer(auction.get("price"), 0, 100000) or not _integer(auction.get("round"), 0, 10000):
		return false
	if not auction.get("leader") in ["", "player", "penny", "rafi", "mo"] or not auction.get("boxes") is Array or auction.boxes.size() != 6 or not auction.get("log") is Array or auction.log.size() > 1000 or not auction.get("npcs") is Array:
		return false
	for line in auction.log:
		if not line is String or line.length() > 300:
			return false
	var box_ids: Dictionary = {}
	var uncollected = 0
	for box in auction.boxes:
		if not box is Dictionary or box.size() != 3 or not _item(box.get("item")) or not box.get("revealed") is bool or not box.get("collected") is bool:
			return false
		var item: Dictionary = box.item
		if item.uid >= data.next_item_id or box_ids.has(int(item.uid)) or (not box.collected and ids.has(int(item.uid))):
			return false
		box_ids[int(item.uid)] = true
		if box.collected and not box.revealed:
			return false
		if auction.stage in ["preview", "bidding", "lost"] and (box.collected or box.revealed):
			return false
		if not box.collected:
			uncollected += 1
	if auction.stage == "cleared" and uncollected != 0:
		return false
	if auction.stage in ["owned", "cleared"] and auction.leader != "player":
		return false
	if auction.stage == "preview":
		return auction.npcs.is_empty() and auction.leader == ""
	if auction.npcs.size() != 3:
		return false
	var npc_ids: Dictionary = {}
	for npc in auction.npcs:
		if not npc is Dictionary or not npc.get("id") in ["penny", "rafi", "mo"] or npc_ids.has(npc.id) or not npc.get("name") is String or not npc.get("style") is String or not npc.get("active") is bool or not _integer(npc.get("budget"), 0, 1000):
			return false
		if not (npc.get("factor") is float or npc.get("factor") is int) or float(npc.factor) < 0 or float(npc.factor) > 1:
			return false
		npc_ids[npc.id] = true
	return true
