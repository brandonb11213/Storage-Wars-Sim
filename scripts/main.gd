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
var mode: String = "map"
var transport: TransportManager
var nav_buttons: Dictionary = {}
var sidebar_scroll: ScrollContainer
var camera_tools: HBoxContainer
var rendered_mode: String = ""
var rendered_stage: String = ""
var bidding_controls: Dictionary = {}
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
	facility.destination_tapped.connect(change_mode)
	facility.display_unit({}, database)
	_build_ui()
	show_menu()

func _bind_state(game_state: GameState) -> void:
	state = game_state
	auctions = AuctionManager.new(state, StorageUnitGenerator.new(database))
	inventory = InventoryManager.new(state)
	economy = EconomyManager.new(state)
	progression = ProgressionManager.new(state)
	transport = TransportManager.new(state, database)
	session += 1
	npc_pending = false
	rendered_mode = ""
	rendered_stage = ""
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
	mode = "map"
	menu_panel.hide()
	hud.show()
	tabs.show()
	sidebar.show()
	facility.controller.set_process_unhandled_input(true)
	facility.display_unit(state.auction, database)
	facility.show_view("map", state, database)
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
	_label(content, "SUNSET STORAGE  /  A RESALE STORY", 14, GOLD)
	_label(content, "STORAGE WARS SIM", 36, Color.WHITE)
	_label(content, "Small garage. Big discoveries.\nBuild your fortune, one unit at a time.", 18, MUTED)
	_button(content, "Continue", continue_game, not saves.has_save(), "Continue")
	_button(content, "New Game  ·  $500", _request_new_game, false, "NewGame", true)
	_label(content, "Drag to pan · pinch to zoom · tap to discover\nOffline single-player · original procedural art", 14, MUTED)
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
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 8
	top.offset_bottom = 70
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_stylebox_override("panel", _style(Color(INK, 0.96), 12, 8))
	hud = HBoxContainer.new()
	hud.add_theme_constant_override("separation", 10)
	top.add_child(hud)
	_label(hud, "STORAGE WARS", 16, GOLD)
	cash_label = _label(hud, "$500", 24)
	stats_label = _label(hud, "", 16, MUTED)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var save_button = _button(hud, "Save", func(): _save(true), false, "Save")
	var menu_button = _button(hud, "Menu", func():
		_save(false)
		show_menu(), false, "Menu")
	save_button.custom_minimum_size.y = 44
	save_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	menu_button.custom_minimum_size.y = 44
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	# The top frame follows its HUD so it does not block the menu or camera.
	hud.visibility_changed.connect(func(): top.visible = hud.visible)
	sidebar = PanelContainer.new()
	ui.add_child(sidebar)
	sidebar.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	sidebar.offset_left = -332
	sidebar.offset_right = -12
	sidebar.offset_top = 82
	sidebar.offset_bottom = -96
	sidebar.add_theme_stylebox_override("panel", _style(Color(INK, 0.97), 14, 12))
	var scroll = ScrollContainer.new()
	sidebar_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(scroll)
	sidebar_content = VBoxContainer.new()
	sidebar_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_content.add_theme_constant_override("separation", 12)
	scroll.add_child(sidebar_content)
	var bottom = PanelContainer.new()
	ui.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_top = -84
	bottom.offset_bottom = -8
	bottom.add_theme_stylebox_override("panel", _style(Color(INK, 0.96), 12, 4))
	tabs = HBoxContainer.new()
	bottom.add_child(tabs)
	tabs.add_theme_constant_override("separation", 4)
	for tab in [["Map", "map"], ["Auctions", "auction"], ["Home", "home"], ["Inventory", "inventory"], ["Selling", "selling"], ["Upgrades", "upgrades"], ["Business", "business"]]:
		var target: String = tab[1]
		var button = _button(tabs, tab[0], func(): change_mode(target), false, target.capitalize() + "Tab")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_stylebox_override("normal", _style(Color("2b4855"), 10, 4))
		nav_buttons[target] = button
	camera_tools = HBoxContainer.new()
	ui.add_child(camera_tools)
	camera_tools.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	camera_tools.position = Vector2(12, 82)
	for tool in [["−", "ZoomOut"], ["+", "ZoomIn"], ["⌂", "Recenter"]]:
		var target: String = tool[1]
		_button(camera_tools, "Center" if tool[1] == "Recenter" else tool[0], func():
			if target == "Recenter": _show_scene()
			else: facility.controller.zoom(1 if target == "ZoomOut" else -1), false, target)
	hud.visibility_changed.connect(func(): camera_tools.visible = hud.visible)
	tabs.visibility_changed.connect(func(): bottom.visible = tabs.visible)
	status_label = Label.new()
	ui.add_child(status_label)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.offset_left = 18
	status_label.offset_top = -140
	status_label.offset_right = 600
	status_label.offset_bottom = -84
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("fff7dc"))
	status_label.add_theme_color_override("font_shadow_color", Color("1b3642"))
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.clip_text = true
	menu_panel = PanelContainer.new()
	ui.add_child(menu_panel)
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_panel.offset_left = -250
	menu_panel.offset_right = 250
	menu_panel.offset_top = -215
	menu_panel.offset_bottom = 215
	menu_panel.add_theme_stylebox_override("panel", _style(Color(INK, 0.98), 20, 20))

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
	button.custom_minimum_size = Vector2(0, 64)
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
	var claimed = progression.claim_quests()
	if not claimed.is_empty(): notify("Milestone: %s. Cash and XP awarded!" % ", ".join(claimed))
	var saved = saves.save_game(state)
	if show_message or not saved:
		notify(saves.last_message)

func change_mode(target: String) -> void:
	if target in ["starter", "suburban"]:
		var district_id = 1 if target == "suburban" else 0
		if state.district != district_id: travel(district_id)
		if state.district != district_id: return
		target = "auction"
	mode = target
	sidebar_scroll.scroll_vertical = 0
	_show_scene()
	refresh()
	_fade(sidebar)

func refresh() -> void:
	if not playing:
		return
	cash_label.text = "$%s" % state.cash
	stats_label.text = "LV %d  ·  %d XP  ·  %d items" % [progression.level(), state.experience, state.inventory.size()]
	for key in nav_buttons:
		nav_buttons[key].modulate = GOLD if key == mode or (mode == "reveal" and key == "auction") else Color.WHITE
	# Bids update stable controls. Replacing a pressed/hovered button between rival
	# replies can swallow a repeated click at the same position in the web canvas.
	if mode == "auction" and state.auction.stage == "bidding" and rendered_mode == mode and rendered_stage == "bidding":
		_update_bidding_ui()
		return
	rendered_mode = mode
	rendered_stage = str(state.auction.stage)
	_clear(sidebar_content)
	match mode:
		"map": _map_ui()
		"home": _home_ui()
		"inventory", "selling": _inventory_ui()
		"upgrades": _upgrades_ui()
		"business": _business_ui()
		"reveal": _reveal_ui()
		_: _auction_ui()
	# Refresh the cursor after replacement controls receive their deferred layout.
	get_viewport().call_deferred("update_mouse_cursor_state")

func _auction_ui() -> void:
	var auction: Dictionary = state.auction
	_label(sidebar_content, "%s / UNIT %02d" % ["SUBURBAN" if state.auction.get("district", 0) == 1 else "SUNSET STORAGE", state.auction_serial], 15, GOLD)
	_label(sidebar_content, auction.theme, 27)
	var stage: String = auction.stage
	match stage:
		"preview":
			_label(sidebar_content, "Look at the visible objects. Covered and boxed contents stay unknown until you win.", 19, MUTED)
			_label(sidebar_content, "Opening bid  $%d\nBid increment  $%d" % [auction.starting_bid, auction.increment], 22)
			var clues = []
			for box in auction.boxes:
				if not str(box.get("visible", "")).is_empty(): clues.append(str(box.visible).replace("_", " "))
			_label(sidebar_content, "Visible: %s\nCondition and resale value unknown." % ", ".join(clues), 18, MUTED)
			_label(sidebar_content, "Pickup %d cargo/trip · %d trips\nTransport $%d reserved with bid.\nHome storage %d/%d" % [transport.capacity(), transport.trips(), transport.quote(), transport.stored_cargo(), transport.storage_capacity()], 18, GOLD)
			_button(sidebar_content, "Enter auction", enter_auction, state.cash < int(auction.starting_bid) + transport.quote(), "EnterAuction", true)
			if state.cash < int(auction.starting_bid) + transport.quote():
				_label(sidebar_content, "Sell inventory to fund your next bid.", 18, GOLD)
		"bidding":
			_label(sidebar_content, "CURRENT BID", 16, MUTED)
			bidding_controls["price"] = _label(sidebar_content, "$%d" % auction.price, 46, GOLD)
			var leader = "No bids yet"
			if auction.leader == "player":
				leader = "You lead"
			else:
				for npc in auction.npcs:
					if npc.id == auction.leader:
						leader = "%s leads" % npc.name
			bidding_controls["leader"] = _label(sidebar_content, leader, 22)
			bidding_controls["npcs"] = []
			for npc in auction.npcs:
				bidding_controls.npcs.append(_label(sidebar_content, "%s  ·  %s" % [npc.name, "In" if npc.active else "Out"], 17, MUTED))
			bidding_controls["bid"] = _button(sidebar_content, "Bid $%d" % auctions.required_bid(), place_bid, auctions.required_bid() + transport.quote() > state.cash, "Bid", true)
			bidding_controls["pass"] = _button(sidebar_content, "Pass / finish auction", pass_auction, npc_pending, "Pass")
			bidding_controls["log"] = _label(sidebar_content, str(auction.log.back()) if not auction.log.is_empty() else "", 16, MUTED)
		"owned":
			_label(sidebar_content, "Transport paid: $%d · %d pickup trips" % [auction.transport_cost, transport.trips()], 17, MUTED)
			_label(sidebar_content, "YOU WON  ·  $%d" % auction.price, 26, GOLD)
			_label(sidebar_content, "Tap a crate in the 3D unit to reveal what's inside. Inspect it, then collect it.", 21)
			_label(sidebar_content, "%d / 6 crates remaining" % state.remaining_boxes(), 21, MUTED)
			for index in 6:
				if not auction.boxes[index].collected:
					var target = index
					_button(sidebar_content, "Inspect discovery %d" % (index + 1), func(): open_box(target), false, "Inspect%d" % index)
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
		notify("Three rivals are ready. Set a budget; walking away costs nothing.")
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
		_show_scene()
		notify("New unit, new possibilities. Preview the crates and enter when ready.")
		_save()
		refresh()

func open_box(index: int) -> void:
	if not playing or mode not in ["auction", "reveal"]:
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
	_label(sidebar_content, "Pawn offer  $%d · Cargo %d" % [economy.offer(item), database.cargo_size(item)], 22)
	_label(sidebar_content, str(definition.description), 17, MUTED)
	if state.auction.get("featured", 0) > 0 and active_box == 0:
		_label(sidebar_content, "FEATURED TREASURE IDENTIFIED", 16, GOLD)
	_label(sidebar_content, "Estimates aren't guaranteed sale prices. Appraisal upgrades sharpen your eye and improve offers.", 18, MUTED)
	var full = transport.stored_cargo() + database.cargo_size(item) > transport.storage_capacity()
	if full: _label(sidebar_content, "Storage full. Sell stored items or add shelving, then return here.", 18, GOLD)
	_button(sidebar_content, "Collect to inventory", collect_active_box, full, "Collect", true)
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
	_label(sidebar_content, "Prepare and sell" if mode == "selling" else "Your inventory", 29)
	_label(sidebar_content, "%d discoveries · storage %d/%d cargo" % [state.inventory.size(), transport.stored_cargo(), transport.storage_capacity()], 18, MUTED)
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
		if uid in selected:
			_label(sidebar_content, str(description.description), 16, MUTED)
			_button(sidebar_content, "Display at home", func():
				state.display_uid = uid
				_save()
				change_mode("home"), false, "Display%d" % uid)
			if mode == "selling":
				var restore = int(item.condition) == 2
				var available = state.upgrades.restoration > 0 if restore else state.upgrades.cleaning > 0
				var fee = economy.preparation_cost(item, restore)
				_button(sidebar_content, ("Restore" if restore else "Clean") + " · $%d" % fee, func():
					if economy.prepare(uid, restore):
						_save()
						refresh(), not available or int(item.condition) == 3 or state.cash < fee or state.auction.stage == "bidding", "Prepare%d" % uid)

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
		_show_scene()
		refresh()

func _business_ui() -> void:
	_label(sidebar_content, "FROM GARAGE TO EMPIRE", 15, GOLD)
	_label(sidebar_content, "Your business", 30)
	_label(sidebar_content, "Old pickup · Owner operated\nBusiness level %d" % progression.level(), 19, MUTED)
	_label(sidebar_content, "FINANCIAL DASHBOARD", 16, GOLD)
	_label(sidebar_content, "Sales revenue  $%d\nAuction costs  $%d\nUpgrade costs  $%d\nCash profit / loss  $%d" % [state.total_earned, state.total_spent, state.upgrade_spent, economy.net_profit()], 20)
	_label(sidebar_content, "%d auctions won · %d lost\n%d items found · %d sold" % [state.auctions_won, state.auctions_lost, state.items_found, state.sales], 18, MUTED)
	_label(sidebar_content, "Transport $%d · Preparation $%d\nQuest rewards $%d\nBusiness value $%d" % [state.transport_spent, state.preparation_spent, state.quest_earned, state.cash + state.inventory.reduce(func(total, item): return total + economy.offer(item), 0) + state.upgrade_spent], 19, MUTED)
	_label(sidebar_content, "MILESTONES & ACHIEVEMENTS", 16, GOLD)
	for index in ProgressionManager.QUESTS.size():
		_label(sidebar_content, "%s %s · $%d" % ["✓" if ProgressionManager.QUESTS[index] in state.quests else "○", ProgressionManager.QUEST_NAMES[index], ProgressionManager.REWARDS[index]], 18)
	_button(sidebar_content, "Open upgrades", func(): change_mode("upgrades"), false, "OpenUpgrades")

func _upgrades_ui() -> void:
	_label(sidebar_content, "BUILD YOUR BUSINESS", 15, GOLD)
	_label(sidebar_content, "Upgrades", 30)
	if state.auction.stage == "bidding":
		_label(sidebar_content, "Finish the auction before spending on upgrades.", 18, GOLD)
	for key in ProgressionManager.UPGRADES:
		var info: Dictionary = ProgressionManager.UPGRADES[key]
		var tier = int(state.upgrades[key])
		_label(sidebar_content, "%s  %d / %d" % [info.name, tier, info.max], 23)
		_label(sidebar_content, info.description, 17, MUTED)
		var target: String = key
		var requirement = progression.requirement(key)
		if not requirement.is_empty(): _label(sidebar_content, requirement, 17, GOLD)
		_button(sidebar_content, "Maxed out" if tier >= int(info.max) else "Upgrade  ·  $%d" % progression.cost(key), func(): buy_upgrade(target), state.auction.stage == "bidding" or tier >= int(info.max) or state.cash < progression.cost(key) or not requirement.is_empty(), "Upgrade_" + key, true)

func buy_upgrade(key: String) -> void:
	if progression.purchase(key):
		notify("%s upgraded!" % ProgressionManager.UPGRADES[key].name)
		_save()
		_show_scene()
		refresh()
		_fade(sidebar)

func garage_clearout() -> void:
	if economy.garage_clearout(database):
		mode = "inventory"
		notify("Found a spare item in your garage. Sell it to fund another auction.")
		_save()
		refresh()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST] and state != null:
		_save()

func _show_scene() -> void:
	var target = "map" if mode == "map" else "home" if mode in ["home", "upgrades", "business", "inventory", "selling"] else "auction"
	facility.show_view(target, state, database)

func _map_ui() -> void:
	_label(sidebar_content, "YOUR GROWING TOWN", 15, GOLD)
	_label(sidebar_content, str(GameplayData.get_config().districts[state.district].name), 28)
	_label(sidebar_content, "Tap buildings to visit. Drag to pan, pinch to zoom. Start at Sunset Storage, then bring discoveries home.", 19, MUTED)
	_button(sidebar_content, "Visit storage auctions", func(): change_mode("auction"), false, "VisitAuctions", true)
	_button(sidebar_content, "Visit home base", func(): change_mode("home"), false, "VisitHome")
	_button(sidebar_content, "Visit pawn shop", func(): change_mode("selling"), false, "VisitShop")
	_label(sidebar_content, "EXPANSION", 16, GOLD)
	_button(sidebar_content, "Return to Neighborhood" if state.district == 1 else "Visit Suburban Storage" if state.upgrades.district > 0 else "Suburban Storage · locked", func():
		if state.upgrades.district == 0: change_mode("upgrades")
		else: travel(0 if state.district == 1 else 1), false, "TravelDistrict")
	if state.upgrades.district == 0:
		_label(sidebar_content, "Unlock: level 3, Expanded Garage and $250 permit. Higher opening bids; specialized unit themes.", 18, MUTED)
	for index in range(2, GameplayData.get_config().districts.size()):
		_label(sidebar_content, "LOCKED · " + str(GameplayData.get_config().districts[index].name), 16, MUTED)
	_label(sidebar_content, "More districts coming soon.", 16, MUTED)

func _home_ui() -> void:
	_label(sidebar_content, "YOUR BUSINESS HAS A HOME", 15, GOLD)
	_label(sidebar_content, "Expanded Garage" if state.upgrades.garage > 0 else "Starter Garage", 29)
	_label(sidebar_content, "Storage %d/%d cargo\nOld pickup %d cargo/trip\nWorkbench · office · discovery display" % [transport.stored_cargo(), transport.storage_capacity(), transport.capacity()], 20, MUTED)
	_label(sidebar_content, "Tap shelves, workbench, office or pickup. Your stored items and purchased equipment appear here.", 18)
	_button(sidebar_content, "Inspect stored items", func(): change_mode("inventory"), false, "HomeInventory", true)
	_button(sidebar_content, "Prepare / sell items", func(): change_mode("selling"), false, "HomeSelling")
	_button(sidebar_content, "Expand / buy equipment", func(): change_mode("upgrades"), false, "HomeUpgrades")
	_button(sidebar_content, "View finances & milestones", func(): change_mode("business"), false, "HomeBusiness")
	if economy.can_clearout():
		_button(sidebar_content, "Garage clear-out · free find", garage_clearout, false, "GarageClearout")
	_label(sidebar_content, "NEXT GOAL", 16, GOLD)
	for index in ProgressionManager.QUESTS.size():
		if not ProgressionManager.QUESTS[index] in state.quests:
			_label(sidebar_content, ProgressionManager.QUEST_NAMES[index], 20)
			break

func travel(district_id: int) -> void:
	if district_id not in [0, 1] or (district_id == 1 and state.upgrades.district == 0): return
	if state.auction.stage in ["bidding", "owned"]:
		notify("Finish the current unit before traveling to another district.")
		return
	state.district = district_id
	auctions.next_auction()
	facility.display_unit(state.auction, database)
	_save()
	_show_scene()
	refresh()
	notify("Welcome to " + str(GameplayData.get_config().districts[district_id].name))

func _update_bidding_ui() -> void:
	var auction: Dictionary = state.auction
	bidding_controls.price.text = "$%d" % auction.price
	var leader = "You lead" if auction.leader == "player" else "No bids yet"
	for index in auction.npcs.size():
		var npc: Dictionary = auction.npcs[index]
		if npc.id == auction.leader: leader = "%s leads" % npc.name
		bidding_controls.npcs[index].text = "%s  ·  %s" % [npc.name, "In" if npc.active else "Out"]
	bidding_controls.leader.text = leader
	bidding_controls.bid.text = "Rivals thinking…" if npc_pending else "Bid $%d" % auctions.required_bid()
	bidding_controls.bid.modulate = Color(0.65, 0.7, 0.75) if npc_pending else Color.WHITE
	bidding_controls.bid.disabled = auctions.required_bid() + transport.quote() > state.cash
	bidding_controls["pass"].disabled = npc_pending
	bidding_controls.log.text = str(auction.log.back()) if not auction.log.is_empty() else ""
