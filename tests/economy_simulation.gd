extends SceneTree
# Run production GDScript systems with fixed seeds, visible-clue strategies and no forced outcomes.
var database = ItemDatabase.new()
var checks: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		printerr("FAIL simulation: " + label)

func resolve(state: GameState, manager: AuctionManager, fraction: float) -> void:
	if not manager.start(): return
	var ceiling = mini(state.cash - manager.transport.quote(), int(state.auction.clue_value * fraction))
	for turn in 1000:
		if state.auction.stage != "bidding": break
		if state.auction.leader != "player":
			if manager.required_bid() > ceiling or not manager.bid():
				manager.pass_and_resolve()
				break
		manager.npc_turn()
	verify(state.auction.stage != "bidding", "auction resolves")
	verify(state.cash >= 0, "no negative cash")

func liquidation(state: GameState) -> int:
	var inventory = InventoryManager.new(state)
	var economy = EconomyManager.new(state)
	var revenue = 0
	for index in 6:
		inventory.reveal_box(index)
		if not inventory.collect_box(index):
			var sale = economy.sell(state.inventory.map(func(i): return int(i.uid)))
			revenue += int(sale.earned)
			verify(inventory.collect_box(index), "capacity recovery preserves winnings")
	var result = economy.sell(state.inventory.map(func(i): return int(i.uid)))
	revenue += int(result.earned)
	return revenue

func run() -> void:
	var result = {"seed_range": "1..1000", "strategies": {}, "featured_counts": [0, 0, 0, 0], "playthroughs": {}}
	var theme_counts = {}
	for strategy in [{"name": "cautious", "fraction": 0.55}, {"name": "speculative", "fraction": 1.4}]:
		var report = {"scenarios": 1000, "wins": 0, "losses": 0, "profitable_units": 0, "unprofitable_units": 0, "total_profit_on_wins": 0, "total_winning_price": 0, "total_npc_budget": 0, "low_price_wins": 0, "unaffordable_rival_units": 0}
		for seed_value in range(1, 1001):
			var state = GameState.new(seed_value)
			var manager = AuctionManager.new(state, StorageUnitGenerator.new(database))
			manager.next_auction()
			if strategy.name == "cautious":
				result.featured_counts[int(state.auction.featured)] += 1
				theme_counts[state.auction.theme] = int(theme_counts.get(state.auction.theme, 0)) + 1
			resolve(state, manager, strategy.fraction)
			var maximum = 0
			for npc in state.auction.npcs:
				report.total_npc_budget += int(npc.budget)
				maximum = maxi(maximum, int(npc.budget))
			if maximum + manager.transport.quote() > 500: report.unaffordable_rival_units += 1
			if state.auction.stage == "owned":
				report.wins += 1
				report.total_winning_price += int(state.auction.price)
				if int(state.auction.price) <= 80: report.low_price_wins += 1
				var cost = int(state.auction.price) + state.transport_spent
				var revenue = liquidation(state)
				var profit = revenue - cost
				report.total_profit_on_wins += profit
				if profit < 0: report.unprofitable_units += 1
				else: report.profitable_units += 1
			else: report.losses += 1
			report["win_rate"] = float(report.wins) / 1000
			report["average_profit_per_won_unit"] = float(report.total_profit_on_wins) / maxi(1, report.wins)
			report["loss_frequency_among_wins"] = float(report.unprofitable_units) / maxi(1, report.wins)
			report["average_winning_price"] = float(report.total_winning_price) / maxi(1, report.wins)
			result.strategies[strategy.name] = report
		verify(report.wins > 0 and report.losses > 0, "strategy has naturally occurring wins and losses")
		verify(report.unprofitable_units > 0, "overpayment losses naturally occur")
	result["theme_counts"] = theme_counts
	verify(theme_counts.size() == 8, "all eight themes occur")
	# Broad distribution checks detect configuration/generation regressions, not exact outcome targets.
	for index in 4:
		var observed = float(result.featured_counts[index]) / 1000
		verify(absf(observed - float(GameplayData.get_config().featured_probabilities[index])) < 0.05, "configured featured probability sampled")
	var progressed = 0
	var garage_unlocked = 0
	var appraisal_affordable = 0
	var zero_cash_events = 0
	var recovery_attempts = 0
	var recovery_successes = 0
	var first_upgrade_turns: Array = []
	var second_district_turns: Array = []
	for seed_value in range(1, 101):
		var state = GameState.new(seed_value * 313)
		var manager = AuctionManager.new(state, StorageUnitGenerator.new(database))
		var economy = EconomyManager.new(state)
		var progression = ProgressionManager.new(state)
		var first = 0
		for auction_number in range(1, 41):
			manager.next_auction()
			if state.cash >= progression.cost("appraisal"): appraisal_affordable += 1
			if economy.can_clearout():
				zero_cash_events += 1
				recovery_attempts += 1
				verify(economy.garage_clearout(database), "recovery item is available")
				economy.sell(state.inventory.map(func(i): return int(i.uid)))
				if state.cash >= economy.recovery_target(): recovery_successes += 1
			resolve(state, manager, 0.8)
			if state.auction.stage == "owned": liquidation(state)
			progression.claim_quests()
			for key in ["appraisal", "vehicle", "garage", "district", "shelving", "cleaning", "restoration", "selling", "demand", "operations"]:
				if state.upgrades[key] == 0 and state.cash >= progression.cost(key) + 100 and progression.purchase(key):
					if first == 0:
						first = auction_number
						first_upgrade_turns.append(first)
					if key == "district":
						second_district_turns.append(auction_number)
						state.district = 1
			progression.claim_quests()
			verify(SaveManager.new(database).validate(state.to_dict()), "playthrough remains saveable")
		if state.upgrades.district > 0: progressed += 1
		if state.upgrades.garage > 0: garage_unlocked += 1
	result.playthroughs = {"count": 100, "auctions_per_session": 40, "strategy": "bid up to 80% of visible estimate; liquidate; buy first tiers with $100 reserve", "garage_unlocked": garage_unlocked, "second_district_unlocked": progressed, "appraisal_affordable_before_auction_count": appraisal_affordable, "low_funding_events": zero_cash_events, "recovery_attempts": recovery_attempts, "recovery_successes": recovery_successes, "first_upgrade_auction_numbers": first_upgrade_turns, "second_district_auction_numbers": second_district_turns}
	var recovery_wins = 0
	# Forced initial bankruptcy is a fixture, not an auction outcome override.
	for seed_value in range(1, 101):
		var state = GameState.new(seed_value)
		var manager = AuctionManager.new(state, StorageUnitGenerator.new(database))
		manager.next_auction()
		state.cash = 0
		var economy = EconomyManager.new(state)
		verify(economy.garage_clearout(database), "zero-cash recovery")
		verify(not economy.garage_clearout(database), "recovery anti-farming")
		economy.sell(state.inventory.map(func(i): return int(i.uid)))
		verify(state.cash >= economy.recovery_target(), "one recovery job restores a useful bidding budget")
		resolve(state, manager, 100.0)
		if state.auction.stage == "owned": recovery_wins += 1
	verify(recovery_wins > 0 and recovery_wins < 100, "recovery funds competitive bids without forced wins")
	result["forced_bankruptcy_recovery_fixtures"] = 100
	result["recovery_funded_auction_wins"] = recovery_wins
	result["checks"] = checks
	result["failures"] = failed
	var file = FileAccess.open("res://test-results/economy_simulation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ", true, true))
	file.close()
	print("ECONOMY RESULT: %d checks, %d failures; 2,000 seeded auctions, 100 × 40-auction sessions, 100 recovery fixtures" % [checks, failed])
	quit(0 if failed == 0 else 1)
