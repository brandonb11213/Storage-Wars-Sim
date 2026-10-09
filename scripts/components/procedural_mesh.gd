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
		_:
			box(model, Vector3(0.6, 0.4, 0.45), Vector3(0, 0.2, 0), color)
			box(model, Vector3(0.23, 0.15, 0.2), Vector3(0, 0.45, 0), color.lightened(0.22))
	return model
