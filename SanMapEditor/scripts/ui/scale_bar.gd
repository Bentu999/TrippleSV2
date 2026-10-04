extends Control
## Screen-space scale bar: shows how many world metres fit a fixed HUD segment.

@export var bar_width_px: float = 120.0

var _metres: float = 10.0
var _label: String = "10 m"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(bar_width_px + 24.0, 36.0)


func _process(_delta: float) -> void:
	if EditorState.is_flat_view():
		visible = false
		return
	visible = true
	_update_metres()
	queue_redraw()


func _update_metres() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var rect: Rect2 = get_viewport().get_visible_rect()
	# Sample near the bottom-center of the 3D view (away from side dock).
	var y: float = rect.size.y * 0.72
	var x0: float = rect.size.x * 0.42
	var x1: float = x0 + bar_width_px
	var p0: Vector3 = _ray_hit_ground(cam, Vector2(x0, y)) as Vector3
	var p1: Vector3 = _ray_hit_ground(cam, Vector2(x1, y)) as Vector3
	if not _hit_ok(p0) or not _hit_ok(p1):
		return
	var dist: float = p0.distance_to(p1)
	if dist < 0.01 or dist > 1.0e6:
		return
	_metres = _nice_length(dist)
	# Stretch visual bar so the label matches a round metre value.
	var px_scale := _metres / dist
	bar_width_px = clampf(120.0 * px_scale, 48.0, 220.0)
	custom_minimum_size = Vector2(bar_width_px + 28.0, 36.0)
	if _metres >= 1.0:
		_label = "%.0f m" % _metres
	else:
		_label = "%.1f m" % _metres


func _hit_ok(p: Vector3) -> bool:
	return not is_nan(p.x)


func _ray_hit_ground(cam: Camera3D, screen: Vector2) -> Vector3:
	var origin := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector3(NAN, NAN, NAN)
	# Intersect a horizontal plane at orbit focus height (approx. terrain mid).
	var plane_y := float(EditorState.map.height) * 0.15
	var t := (plane_y - origin.y) / dir.y
	if t <= 0.0:
		return Vector3(NAN, NAN, NAN)
	return origin + dir * t


func _nice_length(raw: float) -> float:
	var mag := pow(10.0, floor(log(maxf(raw, 0.01)) / log(10.0)))
	var norm := raw / mag
	var nice := 1.0
	if norm < 1.5:
		nice = 1.0
	elif norm < 3.5:
		nice = 2.0
	elif norm < 7.5:
		nice = 5.0
	else:
		nice = 10.0
	return nice * mag


func _draw() -> void:
	if not visible:
		return
	var y := size.y - 10.0
	var x0 := 8.0
	var x1 := x0 + bar_width_px
	var col := Color(0.95, 0.82, 0.4, 0.95)
	var dim := Color(0, 0, 0, 0.45)
	draw_line(Vector2(x0 + 1, y + 1), Vector2(x1 + 1, y + 1), dim, 3.0)
	draw_line(Vector2(x0, y), Vector2(x1, y), col, 2.5)
	draw_line(Vector2(x0, y - 5.0), Vector2(x0, y + 5.0), col, 2.0)
	draw_line(Vector2(x1, y - 5.0), Vector2(x1, y + 5.0), col, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(x0, y - 10.0),
		_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		col
	)
