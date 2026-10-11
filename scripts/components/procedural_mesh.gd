class_name ProceduralMesh
extends RefCounted

static func material(color: Color, emission: bool = false) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.86
	if emission:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 0.7
	return result

static func box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = position
	return node

static func cylinder(parent: Node3D, radius: float, height: float, position: Vector3, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = position
	return node

static func item_model(parent: Node3D, shape: String, color: Color) -> Node3D:
	var model = Node3D.new()
	parent.add_child(model)
	match shape:
		"vase":
			cylinder(model, 0.25, 0.7, Vector3(0, 0.35, 0), color)
			cylinder(model, 0.13, 0.25, Vector3(0, 0.8, 0), color.lightened(0.3))
		"lamp":
			cylinder(model, 0.3, 0.12, Vector3(0, 0.06, 0), color)
			cylinder(model, 0.04, 0.65, Vector3(0, 0.38, 0), Color("435969"))
			cylinder(model, 0.28, 0.28, Vector3(0, 0.8, 0), color.lightened(0.2))
		"stool":
			box(model, Vector3(0.8, 0.15, 0.6), Vector3(0, 0.65, 0), color)
			for x in [-0.28, 0.28]:
				for z in [-0.2, 0.2]:
					box(model, Vector3(0.09, 0.6, 0.09), Vector3(x, 0.3, z), Color("bc864d"))
		"books", "records":
			for index in 3:
				box(model, Vector3(0.65, 0.12, 0.48), Vector3(0, index * 0.14 + 0.06, 0), color.lightened(index * 0.13))
		"long":
			box(model, Vector3(0.3, 0.14, 1.1), Vector3(0, 0.2, 0), color)
			cylinder(model, 0.27, 0.18, Vector3(0, 0.2, 0.35), color.lightened(0.15))
		"motorcycle", "car":
			var car = shape == "car"
			box(model, Vector3(1.3 if car else 0.45, 0.45, 1.7), Vector3(0, 0.6, 0), color)
			box(model, Vector3(1.1 if car else 0.4, 0.35, 0.65), Vector3(0, 0.95, 0.1), Color("6c888b") if car else Color("36414e"))
			for z in [-0.65, 0.65]:
				for x in ([-0.65, 0.65] if car else [0]):
					var wheel = cylinder(model, 0.3, 0.18, Vector3(x, 0.3, z), Color("293746"))
					wheel.rotation.z = PI / 2
			if not car: box(model, Vector3(0.8, 0.07, 0.1), Vector3(0, 1.05, 0.6), Color("d0d6d2"))
		"arcade", "vending", "cabinet", "safe", "tool_chest":
			var height = 1.8 if shape in ["arcade", "vending", "cabinet"] else 1.0
			box(model, Vector3(0.9, height, 0.65), Vector3(0, height / 2, 0), color)
			box(model, Vector3(0.68, height * 0.5, 0.04), Vector3(0, height * 0.65, 0.35), Color("1d3649"))
			if shape == "arcade":
				box(model, Vector3(1.0, 0.15, 0.8), Vector3(0, 0.8, 0.15), Color("f1bd65"))
				cylinder(model, 0.06, 0.16, Vector3(-0.22, 0.95, 0.4), Color("ed785c"))
			elif shape == "tool_chest":
				for y in 4: box(model, Vector3(0.65, 0.04, 0.05), Vector3(0, 0.2 + y * 0.18, 0.37), Color("e6d4b5"))
			elif shape == "safe": cylinder(model, 0.18, 0.07, Vector3(0, 0.6, 0.39), Color("d9c6a3")).rotation.x = PI / 2
		"television", "gaming_pc":
			box(model, Vector3(1.1 if shape == "television" else 0.5, 0.8, 0.18 if shape == "television" else 0.55), Vector3(0, 0.6, 0), Color("223647"))
			box(model, Vector3(0.9 if shape == "television" else 0.3, 0.6, 0.04), Vector3(0, 0.6, 0.3 if shape == "gaming_pc" else 0.11), color)
			box(model, Vector3(0.6, 0.1, 0.45), Vector3(0, 0.12, 0), Color("475565"))
		"guitar", "boat_motor":
			cylinder(model, 0.35, 0.25, Vector3(0, 0.42, 0), color).rotation.x = PI / 2
			box(model, Vector3(0.15, 1, 0.15), Vector3(0, 1, 0), Color("b28257"))
		"luggage", "jewelry":
			box(model, Vector3(0.8, 0.6 if shape == "luggage" else 0.25, 0.5), Vector3(0, 0.3, 0), color)
			box(model, Vector3(0.25, 0.1, 0.1), Vector3(0, 0.65, 0), Color("e6c36c"))
		"trophy":
			cylinder(model, 0.3, 0.18, Vector3(0, 0.09, 0), Color("56493d"))
			cylinder(model, 0.07, 0.6, Vector3(0, 0.4, 0), color)
			cylinder(model, 0.3, 0.35, Vector3(0, 0.82, 0), Color("f4c76c"))
		_:
			box(model, Vector3(0.6, 0.4, 0.45), Vector3(0, 0.2, 0), color)
			box(model, Vector3(0.23, 0.15, 0.2), Vector3(0, 0.45, 0), color.lightened(0.22))
	return model

static func pickup(parent: Node3D, upgraded: bool = false) -> Node3D:
	var truck = Node3D.new()
	parent.add_child(truck)
	box(truck, Vector3(1.7, 0.6, 3.3), Vector3(0, 0.7, 0), Color("d48b55"))
	box(truck, Vector3(1.6, 0.8, 1.3), Vector3(0, 1.35, 0.7), Color("e6a666"))
	box(truck, Vector3(1.4, 0.55, 0.04), Vector3(0, 1.4, 1.37), Color("a5d4dd"))
	box(truck, Vector3(1.35, 0.08, 1.5), Vector3(0, 1.02, -0.8), Color("684b39"))
	for x in [-0.85, 0.85]:
		for z in [-1.1, 1.05]:
			cylinder(truck, 0.34, 0.2, Vector3(x, 0.43, z), Color("2b3945")).rotation.z = PI / 2
	if upgraded:
		for x in [-0.65, 0.65]:
			box(truck, Vector3(0.08, 1.2, 0.08), Vector3(x, 1.5, -1.3), Color("627985"))
		box(truck, Vector3(1.5, 0.1, 2.5), Vector3(0, 2.1, -0.3), Color("a5c8c1"))
	return truck

static func sign(parent: Node3D, text: String, position: Vector3, size: int = 38) -> void:
	var label = Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.009
	label.outline_size = 2
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)

static func destination(parent: Node3D, target: String, position: Vector3, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.set_meta("destination", target)
	parent.add_child(body)
	body.position = position
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
