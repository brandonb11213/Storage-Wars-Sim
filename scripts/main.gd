extends Node

const INK = Color("152f3b")
const MUTED = Color("a4bcc3")
const GOLD = Color("ffc46b")
var database: ItemDatabase
var state: GameState
var auctions: AuctionManager
var inventory: InventoryManager
var economy: EconomyManager
var progression: ProgressionManager
var saves: SaveManager
var facility: StorageFacility
var ui: Control
var sidebar: PanelContainer
var sidebar_content: VBoxContainer
var menu_panel: PanelContainer
var hud: HBoxContainer
var cash_label: Label
var stats_label: Label
var status_label: Label
var tabs: HBoxContainer
var mode: String = "auction"
var active_box: int = -1
var selected: Array = []
var playing: bool = false
var npc_pending: bool = false
var session: int = 0

func _ready() -> void:
	database = ItemDatabase.new()
	saves = SaveManager.new(database)
	facility = StorageFacility.new()
	add_child(facility)
	facility.box_tapped.connect(open_box)
	facility.display_unit({}, database)
	_build_ui()
	show_menu()

func _bind_state(game_state: GameState) -> void:
	state = game_state
	auctions = AuctionManager.new(state, StorageUnitGenerator.new(database))
	inventory = InventoryManager.new(state)
	economy = EconomyManager.new(state)
	progression = ProgressionManager.new(state)
	session += 1
	npc_pending = false
	selected.clear()
	active_box = -1

func new_game(seed_value: int = 0) -> void:
	_bind_state(GameState.new(seed_value))
	auctions.next_auction()
	_enter_game()
	notify("Your garage, old pickup, and $500. Find your first treasure.")
	_save(false)

func continue_game() -> void:
	var loaded = saves.load_game()
	if loaded == null:
		notify(saves.last_message)
		show_menu()
		return
	_bind_state(loaded)
	if state.auction.is_empty():
		auctions.next_auction()
	_enter_game()
	notify(saves.last_message)
	# A saved player bid may have been waiting for the delayed NPC reply.
	if state.auction.stage == "bidding" and state.auction.leader == "player":
		_schedule_npc()

func _enter_game() -> void:
	playing = true
	mode = "auction"
	menu_panel.hide()
	hud.show()
	tabs.show()
	sidebar.show()
	facility.controller.set_process_unhandled_input(true)
	facility.display_unit(state.auction, database)
	facility.controller.focus_unit()
	refresh()

func show_menu() -> void:
	playing = false
	session += 1
	npc_pending = false
	hud.hide()
	tabs.hide()
	sidebar.hide()
	facility.controller.set_process_unhandled_input(false)
	_clear(menu_panel)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	menu_panel.add_child(content)
	_label(content, "SUNSET STORAGE  /  A RESALE STORY", 16, GOLD)
	_label(content, "STORAGE\nWARS SIM", 52, Color.WHITE)
	_label(content, "Small garage. Big discoveries.\nBuild your fortune, one crate at a time.", 21, MUTED)
	_button(content, "Continue", continue_game, not saves.has_save(), "Continue")
	_button(content, "New Game  ·  $500", _request_new_game, false, "NewGame", true)
	_label(content, "Drag to pan · pinch to zoom · tap to discover\nOffline single-player · original procedural art", 16, MUTED)
	menu_panel.show()
	_fade(menu_panel)

func _request_new_game() -> void:
	if not saves.has_save():
		new_game()
		return
	_clear(menu_panel)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	menu_panel.add_child(content)
	_label(content, "Start a fresh business?", 30)
	_label(content, "This replaces your local progress and backup.\nYour current business cannot be restored.", 20, MUTED)
	_button(content, "Start fresh", func():
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(saves.path + suffix):
				DirAccess.remove_absolute(saves.path + suffix)
		new_game(), false, "ConfirmNew", true)
	_button(content, "Keep my business", show_menu, false, "CancelNew")

func _build_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	canvas.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme = Theme.new()
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", Color("eef4ee"))
	theme.set_color("font_color", "Button", Color("eef4ee"))
	theme.set_color("font_disabled_color", "Button", Color("6d858e"))
	theme.set_stylebox("normal", "Button", _style(Color("2b4855"), 12, 12))
	theme.set_stylebox("hover", "Button", _style(Color("3b626e"), 12, 12))
	theme.set_stylebox("pressed", "Button", _style(Color("496f78"), 12, 12))
	theme.set_stylebox("disabled", "Button", _style(Color("203942"), 12, 12))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), 12, 0, GOLD))
	ui.theme = theme
	var top = PanelContainer.new()
	ui.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 16
	top.offset_bottom = 91
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _style(Color(INK, 0.96), 16, 14))
	hud = HBoxContainer.new()
	hud.add_theme_constant_override("separation", 20)
	top.add_child(hud)
	_label(hud, "STORAGE WARS", 23, GOLD)
	cash_label = _label(hud, "$500", 30)
	stats_label = _label(hud, "", 18, MUTED)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(hud, "Save", func(): _save(true), false, "Save")
	_button(hud, "Menu", func():
		_save(false)
		show_menu(), false, "Menu")
	# The top frame follows its HUD so it does not block the menu or camera.
	hud.visibility_changed.connect(func(): top.visible = hud.visible)
	sidebar = PanelContainer.new()
	ui.add_child(sidebar)
	sidebar.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	sidebar.offset_left = -370
	sidebar.offset_right = -18
	sidebar.offset_top = 109
	sidebar.offset_bottom = -108
	sidebar.add_theme_stylebox_override("panel", _style(Color(INK, 0.97), 18, 18))
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)
	sidebar_content = VBoxContainer.new()
	sidebar_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_content.add_theme_constant_override("separation", 12)
	scroll.add_child(sidebar_content)
	var bottom = PanelContainer.new()
	ui.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 18
	bottom.offset_right = -18
	bottom.offset_top = -91
	bottom.offset_bottom = -16
	bottom.add_theme_stylebox_override("panel", _style(Color(INK, 0.96), 16, 12))
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	bottom.add_child(tabs)
	for tab in [["Auction", "auction"], ["Inventory / Pawn", "inventory"], ["Business", "business"]]:
		var target: String = tab[1]
		_button(tabs, tab[0], func(): change_mode(target), false, target.capitalize() + "Tab")
	var filler = Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(filler)
	_button(tabs, "−", func(): facility.controller.zoom(1), false, "ZoomOut")
	_button(tabs, "+", func(): facility.controller.zoom(-1), false, "ZoomIn")
	_button(tabs, "Recenter", facility.controller.focus_unit, false, "Recenter")
	tabs.visibility_changed.connect(func(): bottom.visible = tabs.visible)
	status_label = Label.new()
	ui.add_child(status_label)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.offset_left = 32
	status_label.offset_top = -150
	status_label.offset_right = 870
	status_label.offset_bottom = -104
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("fff7dc"))
	status_label.add_theme_color_override("font_shadow_color", Color("1b3642"))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_panel = PanelContainer.new()
	ui.add_child(menu_panel)
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_panel.offset_left = -280
	menu_panel.offset_right = 280
	menu_panel.offset_top = -285
	menu_panel.offset_bottom = 285
	menu_panel.add_theme_stylebox_override("panel", _style(Color(INK, 0.98), 24, 30))

func _style(color: Color, radius: int = 12, padding: int = 12, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0 else 0)
	return style

func _label(parent: Node, text: String, size: int = 20, color: Color = Color("eef4ee")) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if parent is VBoxContainer else TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable, disabled: bool = false, node_name: String = "", primary: bool = false) -> Button:
	var button = Button.new()
	button.text = text
	if not node_name.is_empty():
		button.name = node_name
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	if primary:
		button.add_theme_stylebox_override("normal", _style(GOLD, 12, 12))
		button.add_theme_stylebox_override("hover", _style(GOLD.lightened(0.12), 12, 12))
		button.add_theme_stylebox_override("pressed", _style(GOLD.darkened(0.12), 12, 12))
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		# Keep nodes in the tree until input dispatch finishes; immediate detachment
		# invalidates Godot's current GUI/input traversal during a button callback.
		child.process_mode = Node.PROCESS_MODE_DISABLED
		if child is Control:
			child.hide()
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_retire_names(child)
		child.queue_free()

func _retire_names(node: Node) -> void:
	# Free names immediately for replacement controls and test/accessibility lookup.
	node.name = "Retiring_%d" % node.get_instance_id()
	for child in node.get_children():
		_retire_names(child)

func _fade(control: Control) -> void:
	control.modulate.a = 0
	create_tween().tween_property(control, "modulate:a", 1.0, 0.2)

func notify(message: String) -> void:
	status_label.text = message

func _save(show_message: bool = false) -> void:
	if state == null:
		return
	var saved = saves.save_game(state)
	if show_message or not saved:
		notify(saves.last_message)

func change_mode(target: String) -> void:
	mode = target
	refresh()
	_fade(sidebar)

func refresh() -> void:
	if not playing:
		return
	cash_label.text = "$%s" % state.cash
	stats_label.text = "LV %d  ·  %d XP  ·  %d items" % [progression.level(), state.experience, state.inventory.size()]
	_clear(sidebar_content)
	match mode:
		"inventory": _inventory_ui()
		"business": _business_ui()
		"reveal": _reveal_ui()
		_: _auction_ui()

func _auction_ui() -> void:
	var auction: Dictionary = state.auction
	_label(sidebar_content, "SUNSET STORAGE / UNIT 01", 15, GOLD)
	_label(sidebar_content, auction.theme, 27)
	var stage: String = auction.stage
	match stage:
		"preview":
			_label(sidebar_content, "Six sealed crates. A collector's shelf.\nThe contents are a mystery until you win.", 19, MUTED)
			_label(sidebar_content, "Opening bid  $%d\nBid increment  $%d" % [auction.starting_bid, auction.increment], 22)
			for npc in AuctionManager.NPCS:
				_label(sidebar_content, "%s · %s" % [npc.name, npc.style], 16, MUTED)
			_button(sidebar_content, "Enter auction", enter_auction, state.cash < int(auction.starting_bid), "EnterAuction", true)
			if state.cash < int(auction.starting_bid):
				_label(sidebar_content, "Sell inventory to fund your next bid.", 18, GOLD)
		"bidding":
			_label(sidebar_content, "CURRENT BID", 16, MUTED)
			_label(sidebar_content, "$%d" % auction.price, 46, GOLD)
			var leader = "No bids yet"
			if auction.leader == "player":
				leader = "You lead"
			else:
				for npc in auction.npcs:
					if npc.id == auction.leader:
						leader = "%s leads" % npc.name
			_label(sidebar_content, leader, 22)
			for npc in auction.npcs:
				_label(sidebar_content, "%s  ·  %s" % [npc.name, "In" if npc.active else "Out"], 17, MUTED)
			_button(sidebar_content, "Bid $%d" % auctions.required_bid(), place_bid, npc_pending or auction.leader == "player" or auctions.required_bid() > state.cash, "Bid", true)
			_button(sidebar_content, "Pass / finish auction", pass_auction, npc_pending, "Pass")
			if not auction.log.is_empty():
				_label(sidebar_content, str(auction.log.back()), 16, MUTED)
		"owned":
			_label(sidebar_content, "YOU WON  ·  $%d" % auction.price, 26, GOLD)
			_label(sidebar_content, "Tap a crate in the 3D unit to reveal what's inside. Inspect it, then collect it.", 21)
			_label(sidebar_content, "%d / 6 crates remaining" % state.remaining_boxes(), 21, MUTED)
			_button(sidebar_content, "Sell your discoveries", func(): change_mode("inventory"), false, "VisitPawn")
		"cleared", "lost":
			_label(sidebar_content, "Unit cleared!" if stage == "cleared" else "Outbid this time", 30, GOLD)
			_label(sidebar_content, "Sell your finds, improve your business, and return for a new set of crates." if stage == "cleared" else "No cash was deducted. Another unit is waiting for you.", 20, MUTED)
			_button(sidebar_content, "Next auction", next_auction, false, "NextAuction", true)
			_button(sidebar_content, "Inventory / Pawn shop", func(): change_mode("inventory"), false, "VisitPawn")
	if economy.can_clearout():
		_button(sidebar_content, "Garage clear-out · free find", garage_clearout, false, "GarageClearout")
		_label(sidebar_content, "A small recovery job when cash is low. Sell the find to get back to auctions.", 16, MUTED)

func enter_auction() -> void:
	if auctions.start():
		_save()
		notify("Penny, Rafi, and Mo are ready. Bid or pass.")
		refresh()

func place_bid() -> void:
	if not npc_pending and auctions.bid():
		notify("Your bid is in. The rivals are thinking…")
		_save()
		_schedule_npc()

func _schedule_npc() -> void:
	npc_pending = true
	refresh()
	var expected_session = session
	await get_tree().create_timer(0.65).timeout
	if expected_session != session or not playing:
		return
	npc_pending = false
	var result = auctions.npc_turn()
	notify(result)
	if state.auction.stage == "owned":
		facility.controller.focus_unit()
	_save()
	refresh()

func pass_auction() -> void:
	if npc_pending:
		return
	notify(auctions.pass_and_resolve())
	_save()
	refresh()

func next_auction() -> void:
	if auctions.next_auction():
		mode = "auction"
		active_box = -1
		facility.display_unit(state.auction, database)
		facility.controller.focus_unit()
		notify("New unit, new possibilities. Preview the crates and enter when ready.")
		_save()
		refresh()

func open_box(index: int) -> void:
	if not playing:
		return
	var item = inventory.reveal_box(index)
	if item.is_empty():
		notify("Win the unit first." if state.auction.stage != "owned" else "That crate has already been collected.")
		return
	active_box = index
	mode = "reveal"
	facility.boxes[index].reveal(database.describe(item))
	notify("A new discovery! Inspect its condition and value, then collect it.")
	_save()
	refresh()
	_fade(sidebar)

func _reveal_ui() -> void:
	if active_box < 0:
		mode = "auction"
		_auction_ui()
		return
	var item: Dictionary = state.auction.boxes[active_box].item
	var definition = database.describe(item)
	var rarity = int(definition.rarity)
	_label(sidebar_content, "%s DISCOVERY" % ItemDatabase.RARITIES[rarity].to_upper(), 18, ItemDatabase.COLORS[rarity])
	_label(sidebar_content, definition.name, 32)
	_label(sidebar_content, "%s · %s condition" % [definition.category, ItemDatabase.CONDITIONS[int(item.condition)]], 20, MUTED)
	_label(sidebar_content, "Estimated market value\n$%d" % database.estimate(item, int(state.upgrades.appraisal)), 27, GOLD)
	_label(sidebar_content, "Pawn offer  $%d" % economy.offer(item), 22)
	_label(sidebar_content, "Estimates aren't guaranteed sale prices. Appraisal upgrades sharpen your eye and improve offers.", 18, MUTED)
	_button(sidebar_content, "Collect to inventory", collect_active_box, false, "Collect", true)
	_button(sidebar_content, "Back to unit", func(): change_mode("auction"), false, "BackToUnit")

func collect_active_box() -> void:
	if inventory.collect_box(active_box):
		facility.boxes[active_box].mark_collected()
		mode = "auction"
		notify("Collected! +5 XP. %d crates left." % state.remaining_boxes())
		active_box = -1
		_save()
		refresh()

func _inventory_ui() -> void:
	selected = selected.filter(func(uid): return not inventory.find_item(int(uid)).is_empty())
	_label(sidebar_content, "THE CORNER PAWN SHOP", 15, GOLD)
	_label(sidebar_content, "Your inventory", 29)
	_label(sidebar_content, "%d discoveries ready to sell" % state.inventory.size(), 18, MUTED)
	var total = 0
	for uid in selected:
		total += economy.offer(inventory.find_item(int(uid)))
	_button(sidebar_content, "Sell selected  ·  $%d" % total, sell_selected, selected.is_empty(), "SellSelected", true)
	_button(sidebar_content, "Clear selection" if selected.size() == state.inventory.size() and not selected.is_empty() else "Select all", select_all, state.inventory.is_empty(), "SelectAll")
	for item in state.inventory:
		var description = database.describe(item)
		var uid = int(item.uid)
		var row = Button.new()
		row.name = "Item%d" % uid
		row.text = "%s %s\n%s · %s\nEst. $%d  /  Offer $%d" % ["✓" if uid in selected else "○", description.name, ItemDatabase.RARITIES[int(description.rarity)], ItemDatabase.CONDITIONS[int(item.condition)], database.estimate(item, int(state.upgrades.appraisal)), economy.offer(item)]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 18)
		row.add_theme_color_override("font_color", ItemDatabase.COLORS[int(description.rarity)])
		row.custom_minimum_size.y = 104
		row.pressed.connect(func():
			if uid in selected:
				selected.erase(uid)
			else:
				selected.append(uid)
			refresh())
		sidebar_content.add_child(row)
	if state.inventory.is_empty():
		_label(sidebar_content, "The shelves are waiting. Win a storage unit and collect your discoveries.", 20, MUTED)
	_button(sidebar_content, "Back to auctions", func(): change_mode("auction"), false, "BackToAuctions")

func select_all() -> void:
	if selected.size() == state.inventory.size():
		selected.clear()
	else:
		selected = state.inventory.map(func(item): return int(item.uid))
	refresh()

func sell_selected() -> void:
	var result = economy.sell(selected)
	if result.ok:
		selected.clear()
		notify("Sold for $%d. Cash received, inventory updated, XP earned." % result.earned)
		_save()
		refresh()

func _business_ui() -> void:
	_label(sidebar_content, "FROM GARAGE TO EMPIRE", 15, GOLD)
	_label(sidebar_content, "Your business", 30)
	_label(sidebar_content, "Small garage · Old pickup\nSolo owner · Level %d" % progression.level(), 19, MUTED)
	_label(sidebar_content, "FINANCIAL DASHBOARD", 16, GOLD)
	_label(sidebar_content, "Sales revenue  $%d\nAuction costs  $%d\nUpgrade costs  $%d\nCash profit / loss  $%d" % [state.total_earned, state.total_spent, state.upgrade_spent, economy.net_profit()], 20)
	_label(sidebar_content, "%d auctions won · %d lost\n%d items found · %d sold" % [state.auctions_won, state.auctions_lost, state.items_found, state.sales], 18, MUTED)
	if state.auction.stage == "bidding":
		_label(sidebar_content, "Finish the auction before spending on upgrades.", 18, GOLD)
	for key in ProgressionManager.UPGRADES:
		var info: Dictionary = ProgressionManager.UPGRADES[key]
		var tier = int(state.upgrades[key])
		_label(sidebar_content, "%s  %d / %d" % [info.name, tier, info.max], 23)
		_label(sidebar_content, info.description, 17, MUTED)
		var target: String = key
		_button(sidebar_content, "Maxed out" if tier >= int(info.max) else "Upgrade  ·  $%d" % progression.cost(key), func(): buy_upgrade(target), state.auction.stage == "bidding" or tier >= int(info.max) or state.cash < progression.cost(key), "Upgrade_" + key, true)

func buy_upgrade(key: String) -> void:
	if progression.purchase(key):
		notify("%s upgraded!" % ProgressionManager.UPGRADES[key].name)
		_save()
		refresh()

func garage_clearout() -> void:
	if economy.garage_clearout(database):
		mode = "inventory"
		notify("Found a spare item in your garage. Sell it to fund another auction.")
		_save()
		refresh()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST] and state != null:
		_save()
