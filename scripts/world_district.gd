class_name WorldDistrict
extends Node3D
@export var suburban: bool = false
var vehicle: Node3D
var clock: float = 0

func _ready() -> void:
	ProceduralMesh.box(self, Vector3(27, 0.3, 21), Vector3(0, -0.3, 0), Color("89b887") if not suburban else Color("91afa2"))
	ProceduralMesh.box(self, Vector3(27, 0.06, 3), Vector3(0, -0.08, 1), Color("667783"))
	ProceduralMesh.box(self, Vector3(3, 0.06, 21), Vector3(0, -0.07, 0), Color("667783"))
	for x in range(-12, 13, 3):
		ProceduralMesh.box(self, Vector3(1.3, 0.025, 0.12), Vector3(x, -0.02, 1), Color("f0dda5"))
	_building(Vector3(-7, 0, -4), Vector3(5, 2.3, 4), Color("ebb06b"), "HOME BASE", "home")
	_building(Vector3(6, 0, -4), Vector3(7 if suburban else 5, 2.8, 4), Color("598caf") if suburban else Color("408e96"), "SUBURBAN STORAGE" if suburban else "SUNSET STORAGE", "suburban" if suburban else "starter")
	_building(Vector3(-7, 0, 6), Vector3(4, 2.5, 3), Color("b77789"), "CORNER PAWN", "selling")
	for x in [4, 9]:
		_building(Vector3(x, 0, 6), Vector3(3, 2.2, 3), Color("ddc59a"), "", "")
	for x in [-12, -3, 3, 12]:
		for z in [-8, 9]:
			ProceduralMesh.cylinder(self, 0.14, 1.2, Vector3(x, 0.6, z), Color("986f50"))
			ProceduralMesh.cylinder(self, 0.9, 1.5, Vector3(x, 1.7, z), Color("4c936f"))
	for x in [-3, 3, 11]:
		ProceduralMesh.cylinder(self, 0.05, 2, Vector3(x, 1, 3), Color("394d61"))
		ProceduralMesh.box(self, Vector3(0.35, 0.2, 0.35), Vector3(x, 2.1, 3), Color("ffda8a"))
	vehicle = ProceduralMesh.pickup(self)
	vehicle.scale = Vector3.ONE * 0.45
	vehicle.rotation.y = PI / 2

func _building(pos: Vector3, size: Vector3, color: Color, title: String, target: String) -> void:
	ProceduralMesh.box(self, size + Vector3(0.6, -size.y + 0.12, 0.6), pos + Vector3(0, 0.02, 0), Color("e4dac0"))
	ProceduralMesh.box(self, size, pos + Vector3(0, size.y / 2, 0), color)
	ProceduralMesh.box(self, Vector3(size.x + 0.3, 0.25, size.z + 0.3), pos + Vector3(0, size.y + 0.12, 0), color.darkened(0.3))
	ProceduralMesh.box(self, Vector3(1.5, 1.5, 0.1), pos + Vector3(0, 0.8, size.z / 2 + 0.05), Color("a5d4d6"))
	if not title.is_empty(): ProceduralMesh.sign(self, title, pos + Vector3(0, size.y + 0.9, 0), 32)
	if not target.is_empty(): ProceduralMesh.destination(self, target, pos + Vector3(0, size.y / 2, 0), size)

func _process(delta: float) -> void:
	clock += delta
	vehicle.position = Vector3(fmod(clock * 1.5, 25.0) - 12.5, 0, 1)
