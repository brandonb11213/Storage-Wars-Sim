class_name AuctionManager
extends RefCounted

const NPCS = [
	{"id": "penny", "name": "Penny Price", "style": "Conservative Reseller", "factor": 0.48, "risk": 0.12, "cash": 280, "preferences": ["Furniture", "Home"]},
	{"id": "rafi", "name": "Rafi Cruz", "style": "Aggressive Collector", "factor": 0.72, "risk": 0.38, "cash": 650, "preferences": ["Collectibles", "Electronics"]},
	{"id": "mo", "name": "Mo Bennett", "style": "Professional Dealer", "factor": 0.56, "risk": 0.18, "cash": 520, "preferences": ["Tools", "Electronics"]},
	{"id": "bea", "name": "Bea Brooks", "style": "Bargain Hunter", "factor": 0.34, "risk": 0.1, "cash": 150, "preferences": ["Kitchen", "Books"]},
	{"id": "viv", "name": "Viv Sterling", "style": "Wealthy Enthusiast", "factor": 0.82, "risk": 0.5, "cash": 1400, "preferences": ["Vehicles", "Music"]},
	{"id": "gus", "name": "Gus Wild", "style": "Risk-Taking Gambler", "factor": 0.62, "risk": 0.65, "cash": 450, "preferences": ["Vehicles", "Collectibles"]}]
var state: GameState
var generator: StorageUnitGenerator
var transport: TransportManager

func _init(game_state: GameState, unit_generator: StorageUnitGenerator) -> void:
	state = game_state
	generator = unit_generator
	transport = TransportManager.new(state, generator.database)

func next_auction() -> bool:
	if state.auction.get("stage") in ["bidding", "owned"]:
		return false
	state.auction_serial += 1
	state.auction = generator.generate(state)
	return true

func start() -> bool:
	if state.auction.get("stage") != "preview" or state.cash < int(state.auction.starting_bid) + transport.quote():
		return false
	var rng = RandomNumberGenerator.new()
	rng.seed = int(state.auction.seed) + 101
	var available = NPCS.duplicate(true)
	state.auction.npcs.clear()
	for index in 3:
		var choice = rng.randi_range(0, available.size() - 1)
		var npc: Dictionary = available.pop_at(choice)
		# Only public clues enter appraisal. Hidden contents and actual condition/value are never read.
		var interest = 1.0
		for box in state.auction.boxes:
			if box.get("visible", "") in ["motorcycle", "car"] and "Vehicles" in npc.preferences:
				interest += 0.25
			elif box.get("visible", "") in ["arcade", "gaming_pc", "television"] and "Electronics" in npc.preferences:
				interest += 0.2
		var estimate = int(float(state.auction.clue_value) * rng.randf_range(0.55, 1.6) * interest)
		npc["estimated_value"] = estimate
		npc["cash"] = int(float(npc.cash) * rng.randf_range(0.65, 1.0))
		npc["budget"] = mini(int(npc.cash), int(estimate * (float(npc.factor) + rng.randf_range(-0.1, float(npc.risk)))))
		npc["active"] = true
		state.auction.npcs.append(npc)
	state.auction.stage = "bidding"
	state.auction.log.append("Auction open. Visible clues are guesses, not guaranteed profit.")
	return true

func required_bid() -> int:
	return int(state.auction.get("price", 0)) + int(state.auction.get("increment", 10))

func bid() -> bool:
	if state.auction.get("stage") != "bidding" or state.auction.leader == "player" or required_bid() + transport.quote() > state.cash:
		return false
	state.auction.price = required_bid()
	state.auction.leader = "player"
	state.auction.log.append("You bid $%d." % int(state.auction.price))
	return true

func npc_turn() -> String:
	if state.auction.get("stage") != "bidding":
		return ""
	state.auction.round += 1
	var candidates: Array = []
	var rng = RandomNumberGenerator.new()
	rng.seed = int(state.auction.seed) + int(state.auction.round) * 103
	for npc in state.auction.npcs:
		if not npc.active or npc.id == state.auction.leader:
			continue
		# Conservative bidders may walk away near their limit, while gamblers stay longer.
		if int(npc.budget) < required_bid() or (required_bid() > int(npc.budget) * 0.8 and rng.randf() < 0.16 * (1.0 - float(npc.get("risk", 0.2)))):
			npc.active = false
		else:
			candidates.append(npc)
	if candidates.is_empty():
		return settle()
	candidates.sort_custom(func(a, b): return float(a.factor) < float(b.factor))
	var npc: Dictionary = candidates[int(state.auction.round) % candidates.size()]
	state.auction.price = required_bid()
	state.auction.leader = npc.id
	var message = "%s bids $%d." % [npc.name, int(state.auction.price)]
	state.auction.log.append(message)
	return message

func pass_and_resolve() -> String:
	if state.auction.get("stage") != "bidding":
		return ""
	for turn in 1000:
		if state.auction.stage != "bidding":
			break
		npc_turn()
	return str(state.auction.log.back())

func settle() -> String:
	if state.auction.get("stage") != "bidding":
		return ""
	var message: String
	var fee = transport.quote()
	if state.auction.leader == "player" and int(state.auction.price) + fee <= state.cash:
		state.cash -= int(state.auction.price) + fee
		state.total_spent += int(state.auction.price)
		state.transport_spent += fee
		state.auction.transport_cost = fee
		state.auctions_won += 1
		state.experience += 20
		state.auction.stage = "owned"
		message = "Sold for $%d + $%d transport (%d pickup trips). Inspect your discoveries." % [state.auction.price, fee, transport.trips()]
	else:
		state.auctions_lost += 1
		state.auction.stage = "lost"
		message = "Another bidder takes the unit. Your cash is untouched."
	state.auction.log.append(message)
	return message
