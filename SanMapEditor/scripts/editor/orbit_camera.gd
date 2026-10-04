extends Node3D
## RMB orbit / MMB pan / wheel zoom around map center.

@onready var camera: Camera3D = $Camera3D

var _yaw: float = 45.0
var _pitch: float = 35.0
var _distance: float = 220.0
var _focus: Vector3 = Vector3(128, 20, 128)
var _orbiting: bool = false
var _panning: bool = false


func _ready() -> void:
	EditorState.map_changed.connect(_on_map_changed)
	_on_map_changed()
	_apply()


func _on_map_changed() -> void:
	_focus = Vector3(
		float(EditorState.map.width) * 0.5,
		float(EditorState.map.height) * 0.2,
		float(EditorState.map.length) * 0.5
	)
	_distance = maxf(EditorState.map.width, EditorState.map.length) * 0.9
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if EditorState.is_flat_view():
		_orbiting = false
		_panning = false
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(20.0, _distance * 0.9)
			_apply()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(2000.0, _distance * 1.1)
			_apply()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _orbiting:
			_yaw -= mm.relative.x * 0.25
			_pitch = clampf(_pitch + mm.relative.y * 0.25, 5.0, 89.0)
			_apply()
		elif _panning:
			var right := camera.global_transform.basis.x
			var up := Vector3.UP
			_focus -= right * mm.relative.x * _distance * 0.0015
			_focus += up * mm.relative.y * _distance * 0.0015
			_apply()


func _apply() -> void:
	var rad_yaw := deg_to_rad(_yaw)
	var rad_pitch := deg_to_rad(_pitch)
	var offset := Vector3(
		cos(rad_pitch) * sin(rad_yaw),
		sin(rad_pitch),
		cos(rad_pitch) * cos(rad_yaw)
	) * _distance
	global_position = _focus
	camera.position = offset
	camera.look_at(_focus, Vector3.UP)
