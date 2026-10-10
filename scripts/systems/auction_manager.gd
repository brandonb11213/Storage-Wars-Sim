class_name AuctionManager
extends RefCounted

const NPCS = [
	{"id": "penny", "name": "Penny Price", "style": "Cautious reseller", "factor": 0.38},
	{"id": "rafi", "name": "Rafi Cruz", "style": "Bold bargain hunter", "factor": 0.48},
	{"id": "mo", "name": "Mo Bennett", "style": "Patient collector", "factor": 0.56}]
var state: GameState
var generator: StorageUnitGenerator

func _init(game_state: GameState, unit_generator: StorageUnitGenerator) -> void:
	state = game_state
	generator = unit_generator

func next_auction() -> bool:
	if not state.auction.is_empty() and state.auction.stage in ["bidding", "owned"]:
		return false
	state.auction_serial += 1
	state.auction = generator.generate(state)
	return true

func start() -> bool:
	if state.auction.is_empty() or state.auction.stage != "preview":
		return false
	var total = 0
	for box in state.auction.boxes:
		total += int(box.item.value)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(state.auction.seed) + 101
	for definition in NPCS:
		var npc: Dictionary = definition.duplicate()
		npc["budget"] = clampi(int(total * float(npc.factor) * rng.randf_range(0.8, 1.15)), int(state.auction.starting_bid), 240 + int(state.upgrades.auction_access) * 100)
		npc["active"] = true
		state.auction.npcs.append(npc)
	state.auction.stage = "bidding"
	state.auction.log.append("Auction open. Tap Bid or Pass to resolve.")
	return true

func required_bid() -> int:
	return int(state.auction.get("price", 0)) + int(state.auction.get("increment", 10))

func bid() -> bool:
	if state.auction.get("stage") != "bidding" or state.auction.leader == "player" or required_bid() > state.cash:
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
	for npc in state.auction.npcs:
		if not npc.active or npc.id == state.auction.leader:
			continue
		if int(npc.budget) < required_bid():
			npc.active = false
		else:
			candidates.append(npc)
	if candidates.is_empty():
		return settle()
	# Bold Rafi jumps early; patient Mo enters on later turns.
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
	for turn in 200:
		if state.auction.stage != "bidding":
			break
		npc_turn()
	return str(state.auction.log.back())

func settle() -> String:
	if state.auction.get("stage") != "bidding":
		return ""
	var message: String
	if state.auction.leader == "player" and int(state.auction.price) <= state.cash:
		state.cash -= int(state.auction.price)
		state.total_spent += int(state.auction.price)
		state.auctions_won += 1
		state.experience += 20
		state.auction.stage = "owned"
		message = "Sold to you for $%d! Open all six crates." % int(state.auction.price)
	else:
		state.auctions_lost += 1
		state.auction.stage = "lost"
		message = "Another bidder takes the unit. Your cash is untouched."
	state.auction.log.append(message)
	return message
