class_name StorageFacility
extends Node3D

signal box_tapped(index: int)
const BOX_SCENE = preload("res://scenes/components/loot_box.tscn")
var controller: TouchCameraController
var boxes: Array = []
var crate_root: Node3D

func _ready() -> void:
	var environment_node = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a3c6cc")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5e5e4")
	environment.ambient_light_energy = 0.3
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = environment
	add_child(environment_node)
	var sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-55, -30, 0)
	sunlight.light_color = Color("ffecd2")
	sunlight.light_energy = 0.8
	sunlight.shadow_enabled = true
	add_child(sunlight)
	controller = TouchCameraController.new()
	add_child(controller)
	controller.tapped.connect(_pick)
	_build_facility()
	crate_root = Node3D.new()
	add_child(crate_root)

func _build_facility() -> void:
	ProceduralMesh.box(self, Vector3(200, 0.2, 200), Vector3(0, -0.55, 0), Color("9ab8a2"))
	ProceduralMesh.box(self, Vector3(21, 0.4, 18), Vector3(0, -0.25, 0), Color("5d7375"))
	ProceduralMesh.box(self, Vector3(9.5, 0.3, 7.5), Vector3(-2, 0, -1.5), Color("d4c6a5"))
	# Cutaway front and right walls keep the playable unit visible from the isometric view.
	ProceduralMesh.box(self, Vector3(9.5, 3.4, 0.2), Vector3(-2, 1.85, -5.2), Color("387b85"))
	ProceduralMesh.box(self, Vector3(0.2, 2.9, 7.5), Vector3(-6.7, 1.6, -1.5), Color("498e95"))
	for x in [-6.6, 2.6]:
		ProceduralMesh.box(self, Vector3(0.2, 3.5, 0.2), Vector3(x, 1.9, 2.2), Color("ffc576"))
	ProceduralMesh.box(self, Vector3(9.5, 0.28, 0.3), Vector3(-2, 3.5, 2.2), Color("eeb263"))
	# Rolled-up storage door, striped closed doors, and roof on the adjacent bays.
	ProceduralMesh.box(self, Vector3(9.3, 0.6, 0.6), Vector3(-2, 3.1, 2.1), Color("df8f51"))
	for x in [4.2, 7.6]:
		ProceduralMesh.box(self, Vector3(3.1, 3.4, 6.9), Vector3(x, 1.85, -1.5), Color("347885"))
		ProceduralMesh.box(self, Vector3(2.7, 2.7, 0.12), Vector3(x, 1.6, 2.0), Color("df9255"))
		for y in range(5):
			ProceduralMesh.box(self, Vector3(2.65, 0.035, 0.06), Vector3(x, 0.65 + y * 0.45, 2.08), Color("b67249"))
		ProceduralMesh.box(self, Vector3(3.3, 0.2, 7.1), Vector3(x, 3.65, -1.5), Color("234c5b"))
		_label("%02d" % (2 if x < 5 else 3), Vector3(x, 3.2, 2.15), 42, Color("fff0d2"))
	_label("SUNSET STORAGE", Vector3(-2, 4.25, -5.05), 66, Color("fff0d2"))
	_label("01 / YOUR NEXT FIND", Vector3(-2, 3.9, 2.15), 35, Color("2c4d52"))
	# Reusable shelf and a little desk behind the treasure crates.
	for x in [-5.7, -2.7]:
		for z in [-4.7, -3.9]:
			ProceduralMesh.box(self, Vector3(0.09, 2.3, 0.09), Vector3(x, 1.3, z), Color("354d5a"))
	for y in [0.4, 1.35, 2.2]:
		ProceduralMesh.box(self, Vector3(3.2, 0.12, 1), Vector3(-4.2, y, -4.3), Color("d0a372"))
	for x in [-5.2, -4.2, -3.2]:
		ProceduralMesh.box(self, Vector3(0.6, 0.55, 0.65), Vector3(x, 1.67, -4.25), Color("a8beb3"))
	ProceduralMesh.item_model(self, "stool", Color("edb071")).position = Vector3(0.6, 0.16, -3.8)
	# Painted lane, pickup, palm-like low-poly landscaping, fence, traffic cones.
	for x in range(-8, 9, 3):
		ProceduralMesh.box(self, Vector3(1.5, 0.02, 0.12), Vector3(x, 0, 5.1), Color("eee0b1"))
	var truck = Node3D.new()
	add_child(truck)
	truck.position = Vector3(-6, 0, 5.9)
	ProceduralMesh.box(truck, Vector3(1.7, 0.6, 3.3), Vector3(0, 0.7, 0), Color("d48b55"))
	ProceduralMesh.box(truck, Vector3(1.6, 0.8, 1.3), Vector3(0, 1.35, 0.7), Color("e6a666"))
	ProceduralMesh.box(truck, Vector3(1.4, 0.55, 0.04), Vector3(0, 1.4, 1.37), Color("a5d4dd"))
	ProceduralMesh.box(truck, Vector3(1.35, 0.08, 1.5), Vector3(0, 1.02, -0.8), Color("684b39"))
	for x in [-0.85, 0.85]:
		for z in [-1.1, 1.05]:
			var wheel = ProceduralMesh.cylinder(truck, 0.34, 0.2, Vector3(x, 0.43, z), Color("2b3945"))
			wheel.rotation.z = PI / 2
	for x in [-9, 9.5]:
		ProceduralMesh.cylinder(self, 0.3, 0.6, Vector3(x, 0.3, 4.2), Color("d9955d"))
		ProceduralMesh.cylinder(self, 0.15, 2.8, Vector3(x, 1.6, 4.2), Color("986741"))
		for angle in 5:
			var leaf = ProceduralMesh.box(self, Vector3(0.6, 0.18, 2.1), Vector3(x, 3, 4.2), Color("54877a"))
			leaf.rotation.y = angle * TAU / 5
	for x in [-8, 8]:
		ProceduralMesh.cylinder(self, 0.18, 0.65, Vector3(x, 0.35, 3.3), Color("ffa26c"))
		ProceduralMesh.box(self, Vector3(0.48, 0.06, 0.48), Vector3(x, 0.05, 3.3), Color("263f4d"))
	for x in range(-10, 11, 2):
		ProceduralMesh.box(self, Vector3(0.09, 1.2, 0.09), Vector3(x, 0.6, -7.8), Color("d2c7ab"))
	ProceduralMesh.box(self, Vector3(20, 0.08, 0.08), Vector3(0, 1.1, -7.8), Color("d2c7ab"))

func _label(text: String, position_value: Vector3, size: int, color: Color) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.008
	label.outline_size = 0
	label.position = position_value
	label.modulate = color
	add_child(label)

func display_unit(auction: Dictionary, database: ItemDatabase) -> void:
	for node in boxes:
		node.hide()
		node.process_mode = Node.PROCESS_MODE_DISABLED
		for child in node.get_children():
			if child is CollisionObject3D:
				child.collision_layer = 0
		node.queue_free()
	boxes.clear()
	var data: Array = auction.get("boxes", [])
	for index in 6:
		var crate: LootBox = BOX_SCENE.instantiate()
		crate.index = index
		crate_root.add_child(crate)
		crate.position = Vector3(-4.5 + (index % 3) * 2.3, 0.16, -1.5 + (index / 3) * 2.5)
		boxes.append(crate)
		if data.size() == 6 and data[index].revealed:
			crate.reveal(database.describe(data[index].item), false)
			if data[index].collected:
				crate.mark_collected(false)

func pick_index(screen_position: Vector2) -> int:
	var camera = controller.camera
	var origin = camera.project_ray_origin(screen_position)
	var query = PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_position) * 100)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1
	return int(hit.collider.get_meta("box_index", -1))

func _pick(screen_position: Vector2) -> void:
	var index = pick_index(screen_position)
	if index >= 0:
		box_tapped.emit(index)
