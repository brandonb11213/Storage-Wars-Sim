class_name SaveManager
extends RefCounted

const VERSION = 2
const DEFAULT_PATH = "user://storage_wars_save.json"
var path: String
var last_message: String = ""
var database: ItemDatabase

func _init(item_database: ItemDatabase, save_path: String = DEFAULT_PATH) -> void:
	database = item_database
	path = save_path

func save_game(state: GameState) -> bool:
	var payload = state.to_dict()
	if not validate(payload):
		last_message = "Save rejected: invalid game state."
		return false
	var body = JSON.stringify(payload, "", true, true)
	var envelope = {"version": VERSION, "body": body, "checksum": body.sha256_text()}
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_message = "Cannot write save: error %d." % FileAccess.get_open_error()
		return false
	file.store_string(JSON.stringify(envelope))
	file.close()
	# Only preserve a validated old save. Never replace a good backup with corrupt data.
	if not _read(path).is_empty():
		var backup_error = DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			last_message = "Could not preserve previous save: error %d." % backup_error
			return false
	var rename_error = DirAccess.rename_absolute(path + ".tmp", path)
	if rename_error != OK:
		last_message = "Save replacement failed: error %d." % rename_error
		return false
	# Closing the temporary file may schedule sync before its final rename.
	# Request persistence again after the complete atomic replacement on web.
	if OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()
	last_message = "Progress saved locally."
	return true

func load_game() -> GameState:
	var payload = _read(path)
	if not payload.is_empty():
		last_message = "Local save loaded."
		return GameState.from_dict(payload)
	payload = _read(path + ".bak")
	if not payload.is_empty():
		last_message = "Recovered the previous save; newest file was unavailable or corrupt."
		return GameState.from_dict(payload)
	last_message = "No valid save found. Start a new game."
	return null

func has_save() -> bool:
	return not _read(path).is_empty() or not _read(path + ".bak").is_empty()

func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	# Limit parsing before allocating arbitrary inventory/auction data.
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > 4000000:
		return {}
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary or (parsed.get("version") != 1 and parsed.get("version") != VERSION) or not parsed.get("body") is String or not parsed.get("checksum") is String:
		return {}
	if parsed.body.sha256_text() != parsed.checksum:
		return {}
	if parser.parse(parsed.body) != OK:
		return {}
	var body = parser.data
	if not body is Dictionary:
		return {}
	if parsed.version == 1:
		if not LegacySaveValidator.new(database).validate(body): return {}
		body = _migrate_v1(body)
	if not validate(body):
		return {}
	return _normalize(body)

func _normalize(value):
	if value is Dictionary:
		for key in value: value[key] = _normalize(value[key])
	elif value is Array:
		for index in value.size(): value[index] = _normalize(value[index])
	elif value is float and value == floor(value):
		return int(value)
	return value

func _migrate_v1(old: Dictionary) -> Dictionary:
	var data = GameState.new(1).to_dict()
	data.merge(old, true)
	var tiers = GameState.new(1).upgrades
	tiers.merge(old.upgrades, true)
	data.upgrades = tiers
	if not data.auction.is_empty():
		data.auction.merge({"featured": 0, "clue_value": 180, "district": 0, "transport_cost": 0})
		for box in data.auction.boxes: box["visible"] = ""
		for npc in data.auction.npcs:
			npc.merge({"cash": int(npc.budget), "risk": 0.2, "estimated_value": int(npc.budget) * 2, "preferences": []})
	for item in data.inventory:
		data.discoveries[item.definition] = int(data.discoveries.get(item.definition, 0)) + 1
	return data

func _integer(value, minimum: int = 0, maximum: int = 2000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

func _number(value, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

func _item(item) -> bool:
	if not item is Dictionary or item.size() != 4: return false
	return _integer(item.get("uid"), 1) and item.get("definition") is String and database.by_id.has(item.definition) and _integer(item.get("condition"), 0, 3) and _integer(item.get("value"), 1, 100000)

func validate(data: Dictionary) -> bool:
	var expected = GameState.new(1).to_dict()
	if data.size() != expected.size(): return false
	for key in expected:
		if not data.has(key): return false
		if expected[key] is int and not _integer(data[key]): return false
	if data.next_item_id < 1 or not data.inventory is Array or data.inventory.size() > 10000 or not data.upgrades is Dictionary: return false
	var upgrades = GameplayData.get_config().upgrades
	if data.upgrades.size() != upgrades.size(): return false
	for key in upgrades:
		if not _integer(data.upgrades.get(key), 0, int(upgrades[key].max)): return false
	if not _integer(data.district, 0, 1) or (data.district == 1 and data.upgrades.district == 0): return false
	if not data.quests is Array or data.quests.size() > ProgressionManager.QUESTS.size() or not data.discoveries is Dictionary or data.discoveries.size() > database.items.size(): return false
	var quests_seen = {}
	for quest in data.quests:
		if not quest is String or not quest in ProgressionManager.QUESTS or quests_seen.has(quest): return false
		quests_seen[quest] = true
	for key in data.discoveries:
		if not key is String or not database.by_id.has(key) or not _integer(data.discoveries[key], 1): return false
	var ids: Dictionary = {}
	for item in data.inventory:
		if not _item(item): return false
		if ids.has(int(item.uid)) or item.uid >= data.next_item_id: return false
		ids[int(item.uid)] = true
	if data.display_uid != 0 and not ids.has(int(data.display_uid)): return false
	if not data.auction is Dictionary: return false
	if data.auction.is_empty(): return true
	var auction: Dictionary = data.auction
	var themes: Array = GameplayData.get_config().themes.map(func(t): return t.name)
	themes.append_array(StorageUnitGenerator.LEGACY_THEMES)
	if auction.size() != 15 or not auction.get("stage") in ["preview", "bidding", "owned", "cleared", "lost"] or not auction.get("theme") in themes: return false
	for key in ["seed", "starting_bid", "increment", "price", "round", "featured", "clue_value", "district", "transport_cost"]:
		if not _integer(auction.get(key), 0, 100000000000000 if key == "seed" else 100000): return false
	if auction.starting_bid < 1 or auction.starting_bid > 1000 or auction.increment < 1 or auction.increment > 100 or auction.round > 10000 or auction.featured > 3 or auction.district > 1: return false
	var npc_ids: Array = AuctionManager.NPCS.map(func(n): return n.id)
	if not auction.get("leader") in npc_ids + ["", "player"] or not auction.get("boxes") is Array or auction.boxes.size() != 6 or not auction.get("log") is Array or auction.log.size() > 1000 or not auction.get("npcs") is Array: return false
	for line in auction.log:
		if not line is String or line.length() > 300: return false
	var box_ids: Dictionary = {}
	var uncollected = 0
	var shapes: Array = database.items.map(func(i): return i.shape)
	for box in auction.boxes:
		if not box is Dictionary or box.size() != 4 or not _item(box.get("item")) or not box.get("revealed") is bool or not box.get("collected") is bool or not box.get("visible") in shapes + [""]: return false
		var item: Dictionary = box.item
		if item.uid >= data.next_item_id or box_ids.has(int(item.uid)) or (not box.collected and ids.has(int(item.uid))): return false
		box_ids[int(item.uid)] = true
		if box.collected and not box.revealed: return false
		if auction.stage in ["preview", "bidding", "lost"] and (box.collected or box.revealed): return false
		if not box.collected: uncollected += 1
	if auction.stage == "cleared" and uncollected != 0: return false
	if auction.stage in ["owned", "cleared"] and auction.leader != "player": return false
	if auction.stage == "preview": return auction.npcs.is_empty() and auction.leader == ""
	if auction.npcs.size() != 3: return false
	var seen = {}
	for npc in auction.npcs:
		if not npc is Dictionary: return false
		if not npc.get("id") in npc_ids or seen.has(npc.id) or not npc.get("name") is String or npc.name.length() > 80 or not npc.get("style") is String or npc.style.length() > 80 or not npc.get("active") is bool: return false
		for key in ["budget", "cash", "estimated_value"]:
			if not _integer(npc.get(key), 0, 10000): return false
		if npc.budget > npc.cash or not _number(npc.get("factor"), 0, 1) or not _number(npc.get("risk"), 0, 1) or not npc.get("preferences") is Array or npc.preferences.size() > 10: return false
		for preference in npc.preferences:
			if not preference is String or preference.length() > 80: return false
		seen[npc.id] = true
	return true
