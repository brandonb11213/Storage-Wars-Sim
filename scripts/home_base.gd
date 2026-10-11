class_name HomeBase
extends Node3D
var visual: Node3D

func display(state: GameState, database: ItemDatabase) -> void:
	if visual:
		visual.hide()
		for body in visual.find_children("*", "StaticBody3D", true, false): body.collision_layer = 0
		visual.queue_free()
	visual = Node3D.new()
	add_child(visual)
	var expanded = state.upgrades.garage > 0
	var width = 12 if expanded else 8
	ProceduralMesh.box(visual, Vector3(24, 0.25, 18), Vector3(0, -0.35, 0), Color("92b894"))
	ProceduralMesh.box(visual, Vector3(width, 0.25, 8), Vector3(-2, -0.15, -1), Color("ded4b6"))
	ProceduralMesh.box(visual, Vector3(width, 3.3, 0.25), Vector3(-2, 1.55, -5), Color("dbac72"))
	ProceduralMesh.box(visual, Vector3(0.25, 3.3, 8), Vector3(-2 - width / 2, 1.55, -1), Color("c89065"))
	ProceduralMesh.box(visual, Vector3(17, 0.1, 5), Vector3(0, -0.2, 5.5), Color("718a8c"))
	ProceduralMesh.sign(visual, "EXPANDED GARAGE" if expanded else "YOUR STARTER GARAGE", Vector3(-2, 4, -4))
	var truck = ProceduralMesh.pickup(visual, state.upgrades.vehicle > 0)
	truck.position = Vector3(5, 0, 4)
	ProceduralMesh.destination(visual, "upgrades", truck.position + Vector3(0, 0.8, 0), Vector3(2, 2, 4))
	for index in (2 + int(state.upgrades.shelving) + (2 if expanded else 0)):
		var x = -5.0 + index * 2.0
		for y in [0.4, 1.3, 2.2]: ProceduralMesh.box(visual, Vector3(1.6, 0.12, 0.8), Vector3(x, y, -4), Color("56818b"))
		for dx in [-0.7, 0.7]: ProceduralMesh.box(visual, Vector3(0.08, 2.4, 0.08), Vector3(x + dx, 1.2, -4), Color("425669"))
	ProceduralMesh.destination(visual, "inventory", Vector3(-2, 1.2, -4), Vector3(width, 2.5, 1.2))
	# Workbench, office desk and showcase remain physically tappable.
	for pair in [[Vector3(-5, 0, 0), "selling", "WORKBENCH"], [Vector3(1, 0, -1), "business", "OFFICE"], [Vector3(-1, 0, 2), "inventory", "DISCOVERIES"]]:
		ProceduralMesh.item_model(visual, "stool", Color("af775c")).position = pair[0]
		ProceduralMesh.sign(visual, pair[2], pair[0] + Vector3(0, 1.4, 0), 25)
		ProceduralMesh.destination(visual, pair[1], pair[0] + Vector3(0, 0.7, 0), Vector3(1.6, 1.8, 1.5))
	for index in mini(state.inventory.size(), 8):
		var item: Dictionary = state.inventory[index]
		var model = ProceduralMesh.item_model(visual, str(database.by_id[item.definition].shape), ItemDatabase.COLORS[int(database.by_id[item.definition].rarity)])
		model.position = Vector3(-5 + (index % 4) * 1.7, 0.5 + (index / 4) * 0.9, -3.9)
		model.scale = Vector3.ONE * 0.5
	if state.display_uid > 0:
		var item = InventoryManager.new(state).find_item(state.display_uid)
		if not item.is_empty():
			ProceduralMesh.item_model(visual, str(database.by_id[item.definition].shape), Color("ffcc75")).position = Vector3(-1, 0.8, 2)
	for key in ["cleaning", "restoration", "appraisal", "selling", "demand", "operations"]:
		if state.upgrades[key] > 0:
			var x = -6.0 + ["cleaning", "restoration", "appraisal", "selling", "demand", "operations"].find(key) * 1.7
			ProceduralMesh.box(visual, Vector3(1, 0.7, 0.6), Vector3(x, 0.35, 0.6), Color("6faeb0"))
			ProceduralMesh.sign(visual, key.capitalize(), Vector3(x, 1.3, 0.6), 20)
