extends Node3D
## Viewport scale aids: terrain-following grid, edge ticks, 2 m reference figure.

const REF_HEIGHT := 2.0

var _grid: MeshInstance3D
var _ticks: MeshInstance3D
var _labels_root: Node3D
var _ref_root: Node3D
var _height_ladder: MeshInstance3D
var _mat_minor: StandardMaterial3D
var _mat_major: StandardMaterial3D
var _mat_ref: StandardMaterial3D
var _mat_ladder: StandardMaterial3D
var _built_key: String = ""


func _ready() -> void:
	_make_materials()
	_grid = MeshInstance3D.new()
	_grid.name = "ScaleGrid"
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid)

	_ticks = MeshInstance3D.new()
	_ticks.name = "ScaleTicks"
	_ticks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ticks)

	_height_ladder = MeshInstance3D.new()
	_height_ladder.name = "HeightLadder"
	_height_ladder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_height_ladder)

	_labels_root = Node3D.new()
	_labels_root.name = "ScaleLabels"
	add_child(_labels_root)

	_ref_root = Node3D.new()
	_ref_root.name = "ScaleReference"
	add_child(_ref_root)
	_build_reference_figure()

	EditorState.map_changed.connect(_rebuild)
	EditorState.heights_changed.connect(_on_heights)
	EditorState.view_changed.connect(_update_visibility)
	EditorState.scale_guides_changed.connect(_update_visibility)
	_rebuild()


func _on_heights(_dirty: Rect2i) -> void:
	# Keep the 2 m figure stuck to terrain; full grid rebuild stays on map/toggle.
	if EditorState.show_scale_guides and not EditorState.is_flat_view() and _ref_root != null:
		_place_reference(EditorState.map)


func _make_materials() -> void:
	_mat_minor = _line_mat(Color(0.2, 0.22, 0.18, 0.55))
	_mat_major = _line_mat(Color(0.95, 0.72, 0.2, 0.9))
	_mat_ladder = _line_mat(Color(0.35, 0.85, 1.0, 0.95))
	_mat_ref = StandardMaterial3D.new()
	_mat_ref.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_ref.albedo_color = Color(0.95, 0.55, 0.2, 0.95)
	_mat_ref.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _line_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Avoid Z-fighting with terrain; guides stay readable from any angle.
	mat.no_depth_test = true
	mat.render_priority = 5
	return mat


func _update_visibility() -> void:
	var on := EditorState.show_scale_guides and not EditorState.is_flat_view()
	visible = on
	if on and _built_key != _cache_key():
		_rebuild()


func _cache_key() -> String:
	var m := EditorState.map
	return "%d_%d_%d_%s_%s" % [
		m.width, m.length, m.height,
		str(m.has_water),
		"%.1f" % m.water_level,
	]


func _rebuild() -> void:
	_built_key = _cache_key()
	_clear_labels()
	var map := EditorState.map
	var w := float(map.width)
	var l := float(map.length)
	var step := _grid_step(maxi(map.width, map.length))
	var major := step * 5.0

	_grid.mesh = _build_grid_mesh(w, l, step, major, false)
	_grid.material_override = _mat_minor
	# Second pass overlay for major lines (same mesh with only majors is clearer).
	_ticks.mesh = _build_grid_mesh(w, l, major, major, true)
	_ticks.material_override = _mat_major

	_place_edge_labels(w, l, major)
	_place_reference(map)
	_build_height_ladder(map)
	_update_visibility()


func _grid_step(map_size: int) -> float:
	if map_size <= 128:
		return 5.0
	if map_size <= 512:
		return 10.0
	if map_size <= 1024:
		return 25.0
	return 50.0


func _build_grid_mesh(w: float, l: float, step: float, major: float, majors_only: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var sample := maxf(step, 4.0)

	var x := 0.0
	while x <= w + 0.001:
		var is_major := _is_multiple(x, major) or is_equal_approx(x, 0.0) or is_equal_approx(x, w)
		if majors_only and not is_major:
			x += step
			continue
		if not majors_only and is_major and major != step:
			x += step
			continue
		_polyline_along_z(st, x, l, sample)
		x += step

	var z := 0.0
	while z <= l + 0.001:
		var is_major := _is_multiple(z, major) or is_equal_approx(z, 0.0) or is_equal_approx(z, l)
		if majors_only and not is_major:
			z += step
			continue
		if not majors_only and is_major and major != step:
			z += step
			continue
		_polyline_along_x(st, z, w, sample)
		z += step

	return st.commit()


func _polyline_along_z(st: SurfaceTool, x: float, length: float, sample: float) -> void:
	var z := 0.0
	var prev := _surface_point(x, z)
	z += sample
	while z <= length + 0.001:
		var cur := _surface_point(x, minf(z, length))
		st.add_vertex(prev)
		st.add_vertex(cur)
		prev = cur
		z += sample


func _polyline_along_x(st: SurfaceTool, z: float, width: float, sample: float) -> void:
	var x := 0.0
	var prev := _surface_point(x, z)
	x += sample
	while x <= width + 0.001:
		var cur := _surface_point(minf(x, width), z)
		st.add_vertex(prev)
		st.add_vertex(cur)
		prev = cur
		x += sample


func _surface_point(x: float, z: float) -> Vector3:
	var p := Vector3(x, 0.0, z)
	p.y = EditorState.sample_world_height(p) + 0.6
	return p


func _is_multiple(value: float, step: float) -> bool:
	if step <= 0.0:
		return false
	var q := value / step
	return absf(q - roundf(q)) < 0.001


func _clear_labels() -> void:
	for child in _labels_root.get_children():
		child.queue_free()


func _place_edge_labels(w: float, l: float, major: float) -> void:
	var t := 0.0
	while t <= w + 0.001:
		_add_label("%.0f m" % t, _surface_point(t, 0.0) + Vector3(0, 1.2, -2.5), true)
		t += major
	t = major
	while t <= l + 0.001:
		_add_label("%.0f m" % t, _surface_point(0.0, t) + Vector3(-2.5, 1.2, 0), true)
		t += major
	_add_label("%.0f × %.0f m" % [w, l], _surface_point(w * 0.5, 0.0) + Vector3(0, 2.5, -6.0), false)


func _add_label(text: String, pos: Vector3, small: bool) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 28 if small else 36
	lbl.modulate = Color(0.95, 0.85, 0.45, 0.95)
	lbl.outline_modulate = Color(0, 0, 0, 0.7)
	lbl.outline_size = 8
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.045
	lbl.position = pos
	_labels_root.add_child(lbl)


func _build_reference_figure() -> void:
	# Capsule ≈ person height (2 m total). Fixed world size — never scales with map.
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = REF_HEIGHT
	body.mesh = cap
	body.material_override = _mat_ref
	body.position = Vector3(0, REF_HEIGHT * 0.5, 0)
	_ref_root.add_child(body)

	var lbl := Label3D.new()
	lbl.name = "RefLabel"
	lbl.text = "2 m"
	lbl.font_size = 40
	lbl.modulate = Color(1.0, 0.7, 0.3, 1.0)
	lbl.outline_size = 10
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.04
	lbl.position = Vector3(0, REF_HEIGHT + 0.8, 0)
	_ref_root.add_child(lbl)


func _place_reference(map: SanMapData) -> void:
	var area: Dictionary = map.areas.get(SanMapData.AREA_PLAYABLE, {})
	var ax := float(area.get("x", 0.0))
	var az := float(area.get("y", 0.0))
	# Slightly inside the playable corner so it sits on terrain.
	var pos := Vector3(ax + 4.0, 0.0, az + 4.0)
	pos.x = clampf(pos.x, 1.0, float(map.width) - 1.0)
	pos.z = clampf(pos.z, 1.0, float(map.length) - 1.0)
	pos.y = EditorState.sample_world_height(pos)
	_ref_root.global_position = pos


func _build_height_ladder(map: SanMapData) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var base := Vector3(2.0, 0.0, 2.0)
	base.y = 0.0
	var top_y := float(map.height)
	st.add_vertex(base)
	st.add_vertex(Vector3(base.x, top_y, base.z))

	var marks: Array[float] = [0.0, top_y * 0.25, top_y * 0.5, top_y * 0.75, top_y]
	if map.has_water:
		marks.append(map.water_level)
	marks.sort()
	var last := -99999.0
	for i in marks.size():
		var y: float = marks[i]
		if absf(y - last) < 0.5:
			continue
		last = y
		st.add_vertex(Vector3(base.x - 1.2, y, base.z))
		st.add_vertex(Vector3(base.x + 1.2, y, base.z))
		var tag := "%.0f m" % y
		if map.has_water and is_equal_approx(y, map.water_level):
			tag = "Wasser %.0f m" % y
		_add_label(tag, Vector3(base.x + 3.5, y, base.z), true)

	_height_ladder.mesh = st.commit()
	_height_ladder.material_override = _mat_ladder
