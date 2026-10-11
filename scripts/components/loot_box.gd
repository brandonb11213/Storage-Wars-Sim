class_name LootBox
extends Node3D

var index: int = 0
var lid: Node3D
var body: MeshInstance3D
var revealed: bool = false
var collected: bool = false
var item_model: Node3D
var preview: Node3D
var glow: MeshInstance3D

func _ready() -> void:
	body = ProceduralMesh.box(self, Vector3(1.2, 0.9, 1), Vector3(0, 0.45, 0), Color("cb9855"))
	for x in [-0.47, 0.47]:
		ProceduralMesh.box(self, Vector3(0.09, 0.93, 1.03), Vector3(x, 0.46, 0), Color("8c613d"))
	lid = Node3D.new()
	add_child(lid)
	lid.position = Vector3(0, 0.9, -0.5)
	ProceduralMesh.box(lid, Vector3(1.25, 0.1, 1.07), Vector3(0, 0, 0.5), Color("e7b66e"))
	ProceduralMesh.box(lid, Vector3(0.18, 0.12, 1.08), Vector3(0, 0.02, 0.5), Color("ffe1a1"))
	var target = StaticBody3D.new()
	target.set_meta("box_index", index)
	add_child(target)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.3, 1.2, 1.1)
	collision.shape = shape
	target.add_child(collision)
	collision.position.y = 0.55
	var label = Label3D.new()
	label.text = "%02d" % (index + 1)
	label.font_size = 42
	label.pixel_size = 0.007
	label.outline_size = 0
	label.position = Vector3(0, 0.5, 0.51)
	label.modulate = Color("523e2c")
	add_child(label)

func reveal(definition: Dictionary, animate: bool = true) -> void:
	if revealed:
		return
	revealed = true
	if preview: preview.hide()
	var color: Color = ItemDatabase.COLORS[int(definition.rarity)]
	item_model = ProceduralMesh.item_model(self, definition.shape, color)
	item_model.position.y = 0.55
	var ring = TorusMesh.new()
	ring.inner_radius = 0.52
	ring.outer_radius = 0.62
	ring.rings = 16
	ring.ring_segments = 8
	glow = MeshInstance3D.new()
	glow.mesh = ring
	glow.material_override = ProceduralMesh.material(color, true)
	glow.position.y = 0.025
	add_child(glow)
	if animate:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(lid, "rotation:x", -1.9, (0.45 if int(definition.rarity) >= 2 else 0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(item_model, "position:y", 1.25, (0.5 if int(definition.rarity) >= 2 else 0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if int(definition.rarity) >= 2:
			tween.tween_property(item_model, "rotation:y", TAU, 0.8)
	else:
		lid.rotation.x = -1.9
		item_model.position.y = 1.25

func mark_collected(animate: bool = true) -> void:
	collected = true
	if item_model:
		item_model.visible = false
	if glow:
		glow.visible = false
	if animate:
		create_tween().tween_property(self, "scale", Vector3(0.7, 0.4, 0.7), 0.3).set_trans(Tween.TRANS_QUAD)
	else:
		scale = Vector3(0.7, 0.4, 0.7)
	body.material_override = ProceduralMesh.material(Color("788d87"))

func show_preview(shape: String) -> void:
	if shape.is_empty() or revealed: return
	preview = ProceduralMesh.item_model(self, shape, Color("79aeb6"))
	preview.position.y = 0.95
	preview.scale = Vector3.ONE * 0.65
