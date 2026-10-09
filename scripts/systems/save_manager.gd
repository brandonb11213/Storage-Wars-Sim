class_name SaveManager
extends RefCounted

const VERSION = 1
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
	if not parsed is Dictionary or parsed.get("version") != VERSION or not parsed.get("body") is String or not parsed.get("checksum") is String:
		return {}
	if parsed.body.sha256_text() != parsed.checksum:
		return {}
	if parser.parse(parsed.body) != OK:
		return {}
	var body = parser.data
	if not body is Dictionary or not validate(body):
		return {}
	# JSON has a single numeric type; normalize integral fields for exact seeded round-trips.
	for key in GameState.new(1).to_dict():
		if body[key] is float:
			body[key] = int(body[key])
	for key in body.upgrades:
		body.upgrades[key] = int(body.upgrades[key])
	for item in body.inventory:
		_normalize_item(item)
	if not body.auction.is_empty():
		for key in ["seed", "starting_bid", "increment", "price", "round"]:
			body.auction[key] = int(body.auction[key])
		for box in body.auction.boxes:
			_normalize_item(box.item)
		for npc in body.auction.npcs:
			npc.budget = int(npc.budget)
	return body

func _normalize_item(item: Dictionary) -> void:
	for key in ["uid", "condition", "value"]:
		item[key] = int(item[key])

func _integer(value, minimum: int = 0, maximum: int = 2000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

func _item(item) -> bool:
	if not item is Dictionary or item.size() != 4:
		return false
	return _integer(item.get("uid"), 1) and database.by_id.has(item.get("definition")) and _integer(item.get("condition"), 0, 3) and _integer(item.get("value"), 1, 100000)

func validate(data: Dictionary) -> bool:
	var expected = GameState.new(1).to_dict()
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
	if auction.size() != 11 or not auction.get("stage") in ["preview", "bidding", "owned", "cleared", "lost"] or not auction.get("theme") in StorageUnitGenerator.THEMES:
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
