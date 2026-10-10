class_name TouchCameraController
extends Node3D

signal tapped(screen_position: Vector2)
var camera: Camera3D
var touches: Dictionary = {}
var origin: Vector2
var last_position: Vector2
var dragging: bool = false
var moved: bool = false
var pinch_distance: float = 0
var transition: Tween

func _ready() -> void:
	position = Vector3(-1, 0, -1)
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.5
	camera.position = Vector3(14, 17, 20)
	camera.look_at(global_position)
	camera.current = true
	camera.far = 120

func focus_unit() -> void:
	if transition and transition.is_running():
		transition.kill()
	transition = create_tween().set_parallel(true)
	transition.tween_property(self, "position", Vector3(-1.1, 0, 0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	transition.tween_property(camera, "size", 14.5, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func reset_view() -> void:
	if transition and transition.is_running():
		transition.kill()
	position = Vector3(-1, 0, -1)
	camera.size = 17.5

func zoom(amount: float) -> void:
	if transition and transition.is_running():
		transition.kill()
	camera.size = clampf(camera.size + amount, 9.0, 25.0)

func pan(delta: Vector2) -> void:
	if transition and transition.is_running():
		transition.kill()
	var right = camera.global_basis.x
	var forward = camera.global_basis.z
	right.y = 0
	forward.y = 0
	var ratio = camera.size / get_viewport().get_visible_rect().size.y
	position += (-right.normalized() * delta.x - forward.normalized() * delta.y) * ratio
	position.x = clampf(position.x, -7, 7)
	position.z = clampf(position.z, -7, 7)

func _unhandled_input(event: InputEvent) -> void:
	# GUI buttons need mouse emulation; the world uses raw touches to avoid duplicate taps.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom(1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				moved = false
				origin = event.position
				last_position = event.position
			else:
				if dragging and not moved:
					tapped.emit(event.position)
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		if event.position.distance_to(origin) > 8:
			moved = true
		if moved:
			pan(event.position - last_position)
		last_position = event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1:
				origin = event.position
				moved = false
			else:
				moved = true
				pinch_distance = _distance()
		else:
			if touches.has(event.index) and touches.size() == 1 and not moved:
				tapped.emit(event.position)
			touches.erase(event.index)
	elif event is InputEventScreenDrag and touches.has(event.index):
		var old: Vector2 = touches[event.index]
		touches[event.index] = event.position
		if touches.size() >= 2:
			var distance = _distance()
			if pinch_distance > 0 and distance > 0:
				zoom(camera.size * (pinch_distance / distance - 1))
			pinch_distance = distance
			moved = true
		else:
			if event.position.distance_to(origin) > 12:
				moved = true
			if moved:
				pan(event.position - old)

func _distance() -> float:
	var points = touches.values()
	return points[0].distance_to(points[1]) if points.size() >= 2 else 0.0

func _input(event: InputEvent) -> void:
	# Clean up a drag released over UI; GUI handling can otherwise swallow that release.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		call_deferred("_finish_mouse")
	elif event is InputEventScreenTouch and not event.pressed:
		call_deferred("_finish_touch", event.index)

func _finish_mouse() -> void:
	dragging = false

func _finish_touch(index: int) -> void:
	touches.erase(index)
