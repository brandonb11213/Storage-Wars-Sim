extends SceneTree

var checks: int = 0
var failures: Array = []
var database: ItemDatabase
const TEST_PATH = "user://test_storage_save.json"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _run() -> void:
	# Set both the render size and stretch aspect; the dummy display otherwise stays 64×64.
	root.size = Vector2i(1280, 720)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	database = ItemDatabase.new()
	_test_database()
	_test_generation()
	_test_auction()
	_test_inventory_and_transactions()
	_test_progression()
	_test_saves()
	await _test_scene_loop()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _state(seed_value: int = 71) -> GameState:
	return GameState.new(seed_value)

func _manager(state: GameState) -> AuctionManager:
	return AuctionManager.new(state, StorageUnitGenerator.new(database))

func _win(manager: AuctionManager) -> void:
	manager.next_auction()
	manager.start()
	for turn in 100:
		if manager.state.auction.stage != "bidding":
			break
		if manager.state.auction.leader != "player":
			if not manager.bid():
				manager.pass_and_resolve()
				break
		manager.npc_turn()

func _test_database() -> void:
	check(database.items.size() >= 50, "at least 50 item definitions")
	check(database.by_id.size() == database.items.size(), "item IDs are unique")
	var rarities: Dictionary = {}
	for item in database.items:
		check(item.name is String and int(item.value) > 0 and item.shape is String, "valid definition " + item.id)
		rarities[int(item.rarity)] = true
	check(rarities.size() == 6, "all six rarity tiers have definitions")
	var rng = RandomNumberGenerator.new()
	rng.seed = 54231
	var found: Dictionary = {}
	for index in 12000:
		var item = database.generate(rng, 0, index + 1)
		found[int(database.describe(item).rarity)] = true
		check(int(item.value) > 0 and int(item.condition) in range(4), "generated value/condition valid")
	check(found.size() == 6, "all rarity tiers actually occur in seeded generation")

func _test_generation() -> void:
	var first = _state()
	var second = _state()
	_manager(first).next_auction()
	_manager(second).next_auction()
	check(first.auction == second.auction, "same seed and serial produce identical unit")
	var initial = first.auction.duplicate(true)
	_manager(first).next_auction()
	check(first.auction != initial, "next unit differs")
	check(first.auction.boxes.size() == 6 and first.next_item_id == 13, "six unique items assigned per unit")
	var low_rng = RandomNumberGenerator.new()
	var high_rng = RandomNumberGenerator.new()
	low_rng.seed = 901
	high_rng.seed = 901
	var low = 0
	var high = 0
	for index in 3000:
		low += int(database.describe(database.generate(low_rng, 0, index + 1)).rarity)
		high += int(database.describe(database.generate(high_rng, 3, index + 1)).rarity)
	check(high > low, "access upgrades measurably improve rarity distribution")

func _test_auction() -> void:
	var state = _state()
	var manager = _manager(state)
	check(state.cash == 500, "starting cash is $500")
	check(not manager.bid(), "bid without auction rejected")
	manager.next_auction()
	check(manager.start(), "auction starts from preview")
	check(state.auction.npcs.size() == 3, "three named NPC bidders")
	check(not manager.start(), "auction cannot start twice")
	check(not manager.next_auction(), "cannot discard an active auction")
	var opening = int(state.auction.starting_bid)
	check(manager.bid() and int(state.auction.price) == opening, "first bid uses opening price")
	check(state.cash == 500, "bids don't deduct cash before win")
	check(not manager.bid(), "cannot bid against yourself")
	manager.npc_turn()
	check(state.auction.leader != "player", "NPC responds to player bid")
	for turn in 100:
		if state.auction.stage != "bidding": break
		manager.bid()
		manager.npc_turn()
	check(state.auction.stage == "owned", "player can win against real NPC budgets")
	check(state.cash == 500 - int(state.auction.price), "winning cash deduction is exact")
	check(state.total_spent == int(state.auction.price) and state.auctions_won == 1, "win and cost tracked once")
	var paid_cash = state.cash
	manager.settle()
	check(state.cash == paid_cash and state.auctions_won == 1, "settlement is idempotent")
	check(not manager.next_auction(), "uncollected paid contents cannot be discarded")
	var losing_state = _state(9)
	var losing = _manager(losing_state)
	losing.next_auction()
	losing.start()
	losing.pass_and_resolve()
	check(losing_state.auction.stage == "lost" and losing_state.cash == 500, "passing loses without charge")
	check(losing.next_auction(), "can retry after loss")
	losing.start()
	losing_state.cash = 0
	check(not losing.bid() and losing_state.cash == 0, "unaffordable bid rejected")
	for seed_value in range(1, 41):
		var sample = _state(seed_value)
		_win(_manager(sample))
		check(sample.auction.stage == "owned" and sample.cash >= 0, "40 seeds remain winnable without negative cash")

func _test_inventory_and_transactions() -> void:
	var state = _state()
	var inventory = InventoryManager.new(state)
	check(inventory.reveal_box(0).is_empty(), "cannot loot unowned unit")
	_win(_manager(state))
	check(not inventory.collect_box(0), "must reveal before collecting")
	check(inventory.reveal_box(-1).is_empty(), "out-of-range box rejected")
	var item = inventory.reveal_box(0)
	check(not item.is_empty() and state.inventory.is_empty(), "reveal doesn't collect prematurely")
	check(inventory.collect_box(0), "revealed item collected")
	check(not inventory.collect_box(0), "double collect rejected")
	for index in range(1, 6):
		inventory.reveal_box(index)
		inventory.collect_box(index)
	check(state.inventory.size() == 6 and state.items_found == 6, "six items collected")
	check(state.auction.stage == "cleared", "unit clears only after every collection")
	var economy = EconomyManager.new(state)
	var before = state.cash
	var uid = int(item.uid)
	check(not economy.sell([uid, uid]).ok, "duplicate selection rejected")
	check(not economy.sell([uid, 99999]).ok, "invalid selection rejected atomically")
	check(state.cash == before and state.inventory.size() == 6, "invalid sales change nothing")
	var expected = economy.offer(item)
	var result = economy.sell([uid])
	check(result.ok and result.earned == expected, "sale matches displayed offer")
	check(state.cash == before + expected and state.inventory.size() == 5, "sale credits cash and removes sold item")
	check(not economy.sell([uid]).ok, "sold item cannot be sold twice")
	var all = state.inventory.map(func(entry): return int(entry.uid))
	check(economy.sell(all).ok and state.inventory.is_empty(), "bulk selling works")
	check(state.sales == 6 and state.experience == 98, "sales and discovery XP tracked")
	check(economy.net_profit() == state.cash - 500, "profit matches cash delta before upgrades")
	check(_manager(state).next_auction(), "repeat auction after collection and sale")
	state.cash = 0
	check(economy.garage_clearout(database), "bankruptcy recovery available when empty")
	check(not economy.garage_clearout(database), "cannot farm recovery while inventory exists")
	var upgraded = _state(42)
	upgraded.upgrades.auction_access = 3
	_manager(upgraded).next_auction()
	upgraded.cash = int(upgraded.auction.starting_bid) - 1
	check(upgraded.cash >= 35, "upgraded recovery fixture exceeds old $35 threshold")
	check(EconomyManager.new(upgraded).garage_clearout(database), "recovery works below an upgraded auction opening bid")

func _test_progression() -> void:
	var state = _state()
	var progression = ProgressionManager.new(state)
	var economy = EconomyManager.new(state)
	var item = {"value": 100}
	var offer_before = economy.offer(item)
	check(progression.purchase("appraisal") and state.cash == 425, "upgrade costs $75 and increments tier")
	check(economy.offer(item) > offer_before, "appraisal improves offers")
	check(progression.cost("appraisal") == 150, "upgrade costs scale")
	check(not progression.purchase("unknown"), "unknown upgrade rejected")
	state.cash = 0
	check(not progression.purchase("auction_access"), "unaffordable upgrade rejected")
	state.cash = 10000
	progression.purchase("appraisal")
	progression.purchase("appraisal")
	check(not progression.purchase("appraisal") and state.upgrades.appraisal == 3, "maximum tier enforced")
	state.experience = 200
	check(progression.level() == 3, "experience increases player level")
	var manager = _manager(state)
	manager.next_auction()
	manager.start()
	check(not progression.purchase("auction_access"), "upgrade spending cannot invalidate an active bid")

func _remove_save() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)

func _test_saves() -> void:
	_remove_save()
	var saves = SaveManager.new(database, TEST_PATH)
	check(saves.load_game() == null, "missing save handled safely")
	var state = _state()
	_win(_manager(state))
	var inventory = InventoryManager.new(state)
	inventory.reveal_box(0)
	inventory.collect_box(0)
	inventory.reveal_box(1)
	ProgressionManager.new(state).purchase("appraisal")
	check(saves.save_game(state), "save with partial unit and upgrade succeeds")
	var loaded = saves.load_game()
	check(loaded != null and loaded.to_dict() == state.to_dict(), "cash/items/XP/upgrades/auction/seed round-trip")
	var old_cash = state.cash
	state.cash += 1
	check(saves.save_game(state), "repeat save succeeds and preserves backup")
	var file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{corrupt")
	file.close()
	loaded = saves.load_game()
	check(loaded != null and loaded.cash == old_cash and "Recovered" in saves.last_message, "corrupt newest save recovers validated backup")
	DirAccess.remove_absolute(TEST_PATH + ".bak")
	check(saves.load_game() == null and not saves.has_save(), "corrupt save without backup doesn't crash or enable Continue")
	var payload = state.to_dict()
	payload.cash = -100
	check(not saves.validate(payload), "negative cash rejected")
	payload = state.to_dict()
	payload.inventory.append(payload.inventory[0].duplicate())
	check(not saves.validate(payload), "duplicate inventory UIDs rejected")
	payload = state.to_dict()
	payload.upgrades.appraisal = 99
	check(not saves.validate(payload), "invalid upgrade tier rejected")
	payload = state.to_dict()
	payload.auction.boxes[2].item.definition = "not_an_item"
	check(not saves.validate(payload), "unknown saved item rejected")
	payload = state.to_dict()
	payload.auction.boxes[2].item = {"bad": true}
	check(not saves.validate(payload), "malformed nested save rejected safely")
	payload = state.to_dict()
	payload["injected_property"] = true
	check(not saves.validate(payload), "unexpected state fields rejected")
	_remove_save()

func _press(game: Node, node_name: String) -> void:
	var button = game.ui.find_child(node_name, true, false)
	check(button is Button and not button.disabled, "integrated button available: " + node_name)
	if button is Button and not button.disabled:
		button.pressed.emit()
	await process_frame

func _test_scene_loop() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# Isolate test saves from player progress.
	game.saves = SaveManager.new(database, TEST_PATH)
	game.new_game(71)
	await create_timer(0.7).timeout
	check(game.state.cash == 500 and game.facility.boxes.size() == 6, "scene starts with $500 and six 3D crates")
	await _press(game, "EnterAuction")
	for turn in 100:
		if game.state.auction.stage != "bidding": break
		await _press(game, "Bid")
		await create_timer(0.7).timeout
	check(game.state.auction.stage == "owned", "integrated UI auction wins")
	await physics_frame
	var ray_targets: Array = []
	for index in 6:
		await physics_frame
		var crate: Node3D = game.facility.boxes[index]
		var screen_position: Vector2 = game.facility.controller.camera.unproject_position(crate.global_position + Vector3(0, 0.5, 0))
		ray_targets.append([screen_position.x, screen_position.y])
		var picked: int = game.facility.pick_index(screen_position)
		check(picked == index, "camera ray picks actual crate %d (got %d)" % [index, picked])
		game.facility.controller.tapped.emit(screen_position)
		await process_frame
		check(game.mode == "reveal" and crate.revealed, "tap shows reveal and animates crate")
		await _press(game, "Collect")
		await create_timer(0.35).timeout
	check(game.state.auction.stage == "cleared" and game.state.inventory.size() == 6, "integrated looting finishes")
	var target_file = FileAccess.open("res://test-results/ray_targets.json", FileAccess.WRITE)
	target_file.store_string(JSON.stringify(ray_targets))
	target_file.close()
	await _press(game, "InventoryTab")
	await _press(game, "SelectAll")
	var before = game.state.cash
	await _press(game, "SellSelected")
	check(game.state.cash > before and game.state.inventory.is_empty(), "pawn UI credits cash and removes items")
	await _press(game, "BusinessTab")
	await _press(game, "Upgrade_appraisal")
	check(game.state.upgrades.appraisal == 1, "business UI buys upgrade")
	await _press(game, "Save")
	var saved = game.state.to_dict()
	await _press(game, "Menu")
	await _press(game, "Continue")
	check(game.state.to_dict() == saved, "Continue restores actual integrated progress")
	await _press(game, "NextAuction")
	check(game.state.auction_serial == 2 and game.state.auction.stage == "preview", "integrated loop starts second auction")
	# Arrange the upgraded low-funds edge case, then exercise real recovery/selling controls.
	game.state.upgrades.auction_access = 3
	game.next_auction()
	game.state.cash = int(game.state.auction.starting_bid) - 1
	game.refresh()
	await _press(game, "GarageClearout")
	check(game.state.inventory.size() == 1 and game.mode == "inventory", "recovery UI supplies a sellable item at upgraded bid thresholds")
	await _press(game, "SelectAll")
	await _press(game, "SellSelected")
	check(game.state.cash >= int(game.state.auction.starting_bid), "recovery sale restores auction affordability")
	await _press(game, "AuctionTab")
	await _press(game, "EnterAuction")
	check(game.state.auction.stage == "bidding", "player can re-enter upgraded auction after recovery")
	var old_size: float = game.facility.controller.camera.size
	game.facility.controller.zoom(-2)
	check(game.facility.controller.camera.size < old_size, "camera zoom responds")
	game.facility.controller.pan(Vector2(40, 20))
	check(game.facility.controller.position != Vector3(-1.1, 0, 0), "camera pan responds")
	game.queue_free()
	await process_frame
	_remove_save()
