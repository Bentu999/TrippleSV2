extends Node3D
## Raycasts from the camera and applies the active terrain / marker tool.

@onready var camera: Camera3D = $"../OrbitCamera/Camera3D"
@onready var terrain: MeshInstance3D = $"../Terrain"
@onready var brush_ring: MeshInstance3D = $"../BrushRing"
@onready var mirror_rings_root: Node3D = $"../MirrorBrushRings"
@onready var markers_root: Node3D = $"../Markers"
@onready var props_root: Node3D = $"../Props"
@onready var playable_area: MeshInstance3D = $"../PlayableArea"
@onready var water: MeshInstance3D = $"../Water"

var _painting: bool = false
var _shaping: bool = false
var _last_hit: Vector3 = Vector3.ZERO
var _has_last_hit: bool = false
var _mirror_rings: Array[MeshInstance3D] = []
var _measure_pin: MeshInstance3D
var _measure_probe_mat: StandardMaterial3D
var _brush_default_mat: StandardMaterial3D
var _water_mat: ShaderMaterial
var _water_shader: Shader
var _water_albedo: Texture2D
var _water_normal: Texture2D
var _water_tex_loaded: bool = false
var _shape_preview: MeshInstance3D
var _pathing_overlay_mesh: MeshInstance3D
var _pathing_path_mesh: MeshInstance3D


func _ready() -> void:
	EditorState.map_changed.connect(_refresh_overlays)
	EditorState.markers_changed.connect(_rebuild_markers)
	EditorState.props_changed.connect(_rebuild_props)
	EditorState.heights_changed.connect(_on_heights_changed)
	EditorState.tool_changed.connect(_on_tool_changed)
	EditorState.measurement_changed.connect(_sync_measure_pin)
	EditorState.shape_draft_changed.connect(_rebuild_shape_preview)
	EditorState.pathing_changed.connect(_rebuild_pathing_visuals)
	_make_brush_ring()
	_make_measure_pin()
	_make_shape_preview()
	_make_pathing_visuals()
	_refresh_overlays()
	_rebuild_markers()
	_rebuild_props()
	_sync_measure_pin()


func _on_tool_changed() -> void:
	# Switching tools must always end an active stroke.
	if _painting:
		EditorState.end_stroke()
	_painting = false
	_shaping = false
	if EditorState.active_tool != EditorState.Tool.MEASURE_HEIGHT:
		EditorState.set_live_measure(Vector3.ZERO, false)
	_sync_measure_pin()
	_rebuild_shape_preview()
	_rebuild_pathing_visuals()


func _on_heights_changed(_dirty: Rect2i) -> void:
	_update_water()
	_restick_markers()
	if EditorState.measure_pinned:
		EditorState.refresh_pinned_measure_height()
		_sync_measure_pin()
	if EditorState.active_tool == EditorState.Tool.PATHING:
		EditorState.refresh_pathing_overlay()
	_rebuild_shape_preview()


func _process(delta: float) -> void:
	if EditorState.is_flat_view():
		brush_ring.visible = false
		_hide_mirror_rings()
		if _shape_preview:
			_shape_preview.visible = false
		if _painting:
			EditorState.end_stroke()
			_painting = false
		_shaping = false
		return
	if _is_pointer_over_blocking_ui():
		brush_ring.visible = false
		_hide_mirror_rings()
		if EditorState.active_tool == EditorState.Tool.MEASURE_HEIGHT:
			EditorState.set_live_measure(Vector3.ZERO, false)
		if EditorState.is_shape_tool():
			EditorState.update_shape_cursor(Vector3.ZERO, false)
		return

	var hit := _raycast_terrain()
	if hit.is_empty():
		if _painting and _has_last_hit:
			_apply_at(_last_hit, delta)
		else:
			brush_ring.visible = false
			_hide_mirror_rings()
			if EditorState.active_tool == EditorState.Tool.MEASURE_HEIGHT:
				EditorState.set_live_measure(Vector3.ZERO, false)
			if EditorState.is_shape_tool():
				EditorState.update_shape_cursor(Vector3.ZERO, false)
		return

	_last_hit = hit.position
	_has_last_hit = true
	var measuring := EditorState.active_tool == EditorState.Tool.MEASURE_HEIGHT
	var shaping := EditorState.is_shape_tool()
	var pathing := EditorState.active_tool == EditorState.Tool.PATHING
	var show_brush := _is_sculpt_tool(EditorState.active_tool) or measuring or shaping or pathing
	brush_ring.visible = show_brush
	if measuring:
		EditorState.set_live_measure(hit.position, true)
		_apply_measure_probe_style()
		_place_brush_visual(brush_ring, hit.position, 2.5, 0.8)
		_hide_mirror_rings()
	elif shaping:
		_restore_brush_style()
		var preview_r := EditorState.brush_radius
		if EditorState.active_tool == EditorState.Tool.SHAPE_CIRCLE and EditorState.shape_draft_active:
			var c0: Vector3 = EditorState.shape_draft_points[0]
			preview_r = maxf(Vector2(hit.position.x - c0.x, hit.position.z - c0.z).length(), 1.0)
		elif EditorState.active_tool == EditorState.Tool.SHAPE_PLATEAU:
			preview_r = 2.5
		_place_brush_visual(brush_ring, hit.position, preview_r, maxf(preview_r * 0.05, 0.6))
		_hide_mirror_rings()
		EditorState.update_shape_cursor(hit.position, true)
	elif pathing:
		_apply_measure_probe_style()
		_place_brush_visual(brush_ring, hit.position, 2.5, 0.8)
		_hide_mirror_rings()
	elif _is_sculpt_tool(EditorState.active_tool):
		_restore_brush_style()
		_update_brush_ghosts(hit.position, EditorState.brush_radius)
	else:
		_hide_mirror_rings()

	if _painting:
		_apply_at(hit.position, delta)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_ESCAPE:
		if EditorState.shape_draft_active:
			EditorState.clear_shape_draft()
			_shaping = false
			get_viewport().set_input_as_handled()
		elif EditorState.active_tool == EditorState.Tool.PATHING and EditorState.pathing_has_a:
			EditorState.clear_pathing_pick()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if EditorState.shape_draft_active:
				EditorState.clear_shape_draft()
				_shaping = false
				get_viewport().set_input_as_handled()
				return
			if EditorState.active_tool == EditorState.Tool.PATHING and EditorState.pathing_has_a:
				EditorState.clear_pathing_pick()
				get_viewport().set_input_as_handled()
				return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return

		# Always stop painting on release, even if release happens over UI.
		if not mb.pressed:
			if _painting:
				EditorState.end_stroke()
			_painting = false
			if _shaping:
				_finish_shape_drag()
			_shaping = false
			return

		# Flat views handle their own painting.
		if EditorState.is_flat_view():
			return

		if _is_pointer_over_blocking_ui():
			return

		var hit := _raycast_terrain()
		if hit.is_empty():
			return

		_last_hit = hit.position
		_has_last_hit = true

		if mb.shift_pressed and EditorState.active_tool == EditorState.Tool.SET_HEIGHT:
			EditorState.set_height_world = EditorState.sample_world_height(hit.position)
			var ui := get_node_or_null("../UI")
			if ui != null and ui.has_method("sync_set_height_from_state"):
				ui.sync_set_height_from_state()
			get_viewport().set_input_as_handled()
			return

		match EditorState.active_tool:
			EditorState.Tool.MARKER_SPAWN:
				EditorState.add_marker(SanMapData.MARKER_SPAWN, hit.position)
				get_viewport().set_input_as_handled()
			EditorState.Tool.MARKER_ALLOYS:
				EditorState.add_marker(SanMapData.MARKER_ALLOYS, hit.position)
				get_viewport().set_input_as_handled()
			EditorState.Tool.PLACE_PROP:
				EditorState.add_prop(hit.position)
				get_viewport().set_input_as_handled()
			EditorState.Tool.MEASURE_HEIGHT:
				EditorState.pin_measure(hit.position)
				# Measuring always copies the sampled height into the SET_HEIGHT brush target.
				EditorState.set_height_world = EditorState.measure_pinned_height
				var ui2 := get_node_or_null("../UI")
				if ui2 != null and ui2.has_method("sync_set_height_from_state"):
					ui2.sync_set_height_from_state()
				get_viewport().set_input_as_handled()
			EditorState.Tool.PATHING:
				EditorState.pathing_click(hit.position)
				get_viewport().set_input_as_handled()
			EditorState.Tool.ORBIT:
				pass
			_:
				if EditorState.is_shape_tool():
					_begin_shape_at(hit.position)
					get_viewport().set_input_as_handled()
				elif _is_sculpt_tool(EditorState.active_tool):
					EditorState.begin_stroke(_stroke_label_for_tool(EditorState.active_tool))
					_painting = true
					_apply_at(hit.position, get_process_delta_time())
					get_viewport().set_input_as_handled()


func _begin_shape_at(world_pos: Vector3) -> void:
	# Arc uses discrete clicks (3 points). Other shapes use press-drag-release.
	if EditorState.active_tool == EditorState.Tool.SHAPE_ARC:
		if not EditorState.shape_draft_active:
			EditorState.begin_shape_draft(world_pos)
		else:
			EditorState.add_shape_draft_point(world_pos)
		return
	EditorState.begin_shape_draft(world_pos)
	_shaping = true


func _finish_shape_drag() -> void:
	if not EditorState.is_shape_tool():
		return
	if EditorState.active_tool == EditorState.Tool.SHAPE_ARC:
		return
	if EditorState.shape_draft_active:
		EditorState.commit_shape_draft_with_cursor()


func _is_sculpt_tool(tool: EditorState.Tool) -> bool:
	return tool == EditorState.Tool.RAISE \
		or tool == EditorState.Tool.LOWER \
		or tool == EditorState.Tool.SMOOTH \
		or tool == EditorState.Tool.SET_HEIGHT \
		or tool == EditorState.Tool.PAINT_TEXTURE


func _stroke_label_for_tool(tool: EditorState.Tool) -> String:
	match tool:
		EditorState.Tool.RAISE:
			return "Raise"
		EditorState.Tool.LOWER:
			return "Lower"
		EditorState.Tool.SMOOTH:
			return "Smooth"
		EditorState.Tool.SET_HEIGHT:
			return "Set height"
		EditorState.Tool.PAINT_TEXTURE:
			return "Paint texture"
		_:
			return "Edit"


func _is_pointer_over_blocking_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	# Walk up; IGNORE parents don't block, STOP/PASS controls do.
	var node: Control = hovered
	while node != null:
		if node.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true
		if node.mouse_filter == Control.MOUSE_FILTER_PASS:
			# PASS still receives mouse; treat as UI chrome.
			return true
		node = node.get_parent() as Control
	return false


func _apply_at(pos: Vector3, delta: float) -> void:
	match EditorState.active_tool:
		EditorState.Tool.RAISE:
			EditorState.apply_brush(pos, true, delta)
		EditorState.Tool.LOWER:
			EditorState.apply_brush(pos, false, delta)
		EditorState.Tool.SMOOTH:
			EditorState.apply_smooth(pos, delta)
		EditorState.Tool.SET_HEIGHT:
			EditorState.apply_set_height(pos, delta)
		EditorState.Tool.PAINT_TEXTURE:
			EditorState.apply_splat_paint(pos, delta)


func _raycast_terrain() -> Dictionary:
	if camera == null or terrain.mesh == null:
		return {}
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)

	var map_w := float(EditorState.map.width)
	var map_l := float(EditorState.map.length)
	var max_h := float(EditorState.map.height) + 50.0
	var step := maxf(map_w, map_l) / 512.0
	step = clampf(step, 0.25, 2.0)

	var pos := from
	var prev := from
	for _i in 1600:
		prev = pos
		pos += dir * step
		if pos.y < -80.0:
			return {}
		if pos.x < -20.0 or pos.z < -20.0 or pos.x > map_w + 20.0 or pos.z > map_l + 20.0:
			if pos.y > max_h:
				return {}
			continue
		var ground := EditorState.sample_world_height(pos)
		var prev_ground := EditorState.sample_world_height(prev)
		var crossed := prev.y >= prev_ground and pos.y <= ground
		var underground := pos.y <= ground
		if crossed or underground:
			var a := prev
			var b := pos
			for _j in 10:
				var m := (a + b) * 0.5
				if m.y > EditorState.sample_world_height(m):
					a = m
				else:
					b = m
			var hit_pos := b
			hit_pos.x = clampf(hit_pos.x, 0.0, map_w)
			hit_pos.z = clampf(hit_pos.z, 0.0, map_l)
			hit_pos.y = EditorState.sample_world_height(hit_pos)
			return {"position": hit_pos}
	return {}


func _make_brush_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	torus.rings = 16
	torus.ring_segments = 48

	_brush_default_mat = _make_brush_material(Color(1.0, 0.82, 0.12, 1.0))
	_measure_probe_mat = _make_brush_material(Color(0.35, 0.95, 1.0, 1.0))
	_setup_brush_instance(brush_ring, torus, Color(1.0, 0.82, 0.12, 1.0), false)
	brush_ring.material_override = _brush_default_mat

	for child in mirror_rings_root.get_children():
		child.queue_free()
	_mirror_rings.clear()
	for i in 3:
		var ghost := MeshInstance3D.new()
		ghost.name = "MirrorBrushRing_%d" % i
		_setup_brush_instance(ghost, torus, Color(0.15, 0.95, 1.0, 1.0), true)
		ghost.visible = false
		mirror_rings_root.add_child(ghost)
		_mirror_rings.append(ghost)


func _setup_brush_instance(host: MeshInstance3D, torus: TorusMesh, color: Color, is_mirror: bool) -> void:
	host.mesh = torus
	host.material_override = _make_brush_material(color)
	for child in host.get_children():
		child.queue_free()
	var pip := MeshInstance3D.new()
	pip.name = "Pip"
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	pip.mesh = sphere
	pip.material_override = _make_brush_material(color)
	pip.position = Vector3(0, 0.2, 0)
	host.add_child(pip)
	if is_mirror:
		var beacon := MeshInstance3D.new()
		beacon.name = "Beacon"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 1.0
		beacon.mesh = cyl
		beacon.material_override = _make_brush_material(color)
		beacon.position = Vector3(0, 0.7, 0)
		host.add_child(beacon)
	else:
		var radius_lbl := Label3D.new()
		radius_lbl.name = "RadiusLabel"
		radius_lbl.text = "r 12 m"
		radius_lbl.font_size = 48
		radius_lbl.modulate = Color(1.0, 0.9, 0.35, 1.0)
		radius_lbl.outline_size = 10
		radius_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		radius_lbl.no_depth_test = true
		radius_lbl.pixel_size = 0.035
		radius_lbl.position = Vector3(0, 1.4, 0)
		host.add_child(radius_lbl)


func _make_brush_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.no_depth_test = true
	mat.render_priority = 20
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _apply_measure_probe_style() -> void:
	if _measure_probe_mat != null:
		brush_ring.material_override = _measure_probe_mat


func _restore_brush_style() -> void:
	if _brush_default_mat != null:
		brush_ring.material_override = _brush_default_mat


func _make_measure_pin() -> void:
	_measure_pin = MeshInstance3D.new()
	_measure_pin.name = "MeasurePin"
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	_measure_pin.mesh = sphere
	_measure_pin.material_override = _make_brush_material(Color(1.0, 0.45, 0.15, 1.0))
	var stem := MeshInstance3D.new()
	stem.name = "Stem"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = 8.0
	stem.mesh = cyl
	stem.material_override = _make_brush_material(Color(1.0, 0.55, 0.2, 1.0))
	stem.position = Vector3(0, 4.0, 0)
	_measure_pin.add_child(stem)
	_measure_pin.visible = false
	add_child(_measure_pin)


func _sync_measure_pin() -> void:
	if _measure_pin == null:
		return
	if not EditorState.measure_pinned:
		_measure_pin.visible = false
		return
	var p := EditorState.measure_pinned_pos
	p.y = EditorState.sample_world_height(p) + 0.4
	_measure_pin.global_position = p
	_measure_pin.visible = not EditorState.is_flat_view()


func _update_brush_ghosts(world_pos: Vector3, radius: float) -> void:
	var points := EditorState.expand_brush_world_points(world_pos)
	var r := maxf(radius, 1.0)
	var lift := maxf(r * 0.05, 0.6)
	_place_brush_visual(brush_ring, points[0], r, lift)
	for i in _mirror_rings.size():
		var ring := _mirror_rings[i]
		var pi := i + 1
		if pi < points.size() and ring.is_inside_tree():
			ring.visible = true
			_place_brush_visual(ring, points[pi], r, lift)
		else:
			ring.visible = false


func _place_brush_visual(ring: MeshInstance3D, world_pos: Vector3, radius: float, lift: float) -> void:
	ring.global_position = world_pos + Vector3.UP * lift
	ring.scale = Vector3(radius, maxf(radius * 0.3, 1.0), radius)
	# Counter-scale helpers so pip/beacon stay readable at any brush radius.
	var sx := 1.0 / maxf(ring.scale.x, 0.001)
	var sy := 1.0 / maxf(ring.scale.y, 0.001)
	var sz := 1.0 / maxf(ring.scale.z, 0.001)
	for child in ring.get_children():
		if child is Node3D:
			var n := child as Node3D
			if n.name == "Pip":
				n.scale = Vector3(sx, sy, sz) * 3.0
			elif n.name == "Beacon":
				n.scale = Vector3(sx * 2.0, sy * 14.0, sz * 2.0)
			elif n.name == "RadiusLabel":
				n.scale = Vector3(sx, sy, sz)
				if n is Label3D:
					(n as Label3D).text = "r %.0f m" % radius


func _hide_mirror_rings() -> void:
	for ring in _mirror_rings:
		if is_instance_valid(ring):
			ring.visible = false


func _refresh_overlays() -> void:
	_update_playable_area()
	_update_water()
	_rebuild_markers()


func _update_playable_area() -> void:
	var area: Dictionary = EditorState.map.areas.get(SanMapData.AREA_PLAYABLE, {})
	var x := float(area.get("x", 0.0))
	var y := float(area.get("y", 0.0))
	var w := float(area.get("width", EditorState.map.width))
	var h := float(area.get("height", EditorState.map.length))
	var box := BoxMesh.new()
	box.size = Vector3(w, 0.4, h)
	playable_area.mesh = box
	playable_area.position = Vector3(x + w * 0.5, 0.2, y + h * 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.7, 1.0, 0.12)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	playable_area.material_override = mat


func _update_water() -> void:
	var map := EditorState.map
	water.visible = map.has_water
	if not map.has_water:
		return

	var plane := PlaneMesh.new()
	# Slight oversize so water covers map edges / shore fade.
	plane.size = Vector2(float(map.width) * 1.02, float(map.length) * 1.02)
	plane.subdivide_width = 32
	plane.subdivide_depth = 32
	water.mesh = plane
	water.position = Vector3(float(map.width) * 0.5, map.water_level, float(map.length) * 0.5)

	_ensure_water_material()
	var depth := maxf(map.water_depth, 0.25)
	var shallow := Color(0.22, 0.48, 0.52, clampf(0.35 + depth * 0.04, 0.35, 0.7))
	var deep := Color(0.04, 0.14, 0.26, clampf(0.55 + depth * 0.05, 0.55, 0.9))
	_water_mat.set_shader_parameter("shallow_color", shallow)
	_water_mat.set_shader_parameter("deep_color", deep)
	_water_mat.set_shader_parameter("water_depth", depth)
	_water_mat.set_shader_parameter("wind_speed", map.water_wind_speed)
	_water_mat.set_shader_parameter("wind_direction_deg", map.water_wind_direction)
	# Tile so large maps don't look like a single stretched stamp.
	var tile := clampf(28.0 / maxf(float(map.width), 64.0), 0.012, 0.08)
	_water_mat.set_shader_parameter("tile_scale", tile)
	_water_mat.set_shader_parameter("normal_strength", clampf(0.55 + map.water_wind_speed * 1.2, 0.4, 1.4))
	water.material_override = _water_mat


func _ensure_water_material() -> void:
	if _water_mat != null:
		return
	if _water_shader == null:
		_water_shader = load("res://resources/shaders/water_surface.gdshader") as Shader
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = _water_shader
	if not _water_tex_loaded:
		_water_tex_loaded = true
		# Prefer PNG (Godot Image.load does not decode many DDS formats).
		_water_albedo = EnvironmentAssets.load_texture("Environment/Water/Water_001_COLOR.png", 1024)
		if _water_albedo == null:
			_water_albedo = EnvironmentAssets.load_texture("Environment/Water/Water_001_COLOR.dds", 1024)
		_water_normal = EnvironmentAssets.load_texture("Environment/Water/Water_001_NORM.png", 1024)
		if _water_normal == null:
			_water_normal = EnvironmentAssets.load_texture("Environment/Water/Water_001_NORM.dds", 1024)
	_water_mat.set_shader_parameter("has_albedo", _water_albedo != null)
	_water_mat.set_shader_parameter("has_normal", _water_normal != null)
	if _water_albedo != null:
		_water_mat.set_shader_parameter("albedo_tex", _water_albedo)
	if _water_normal != null:
		_water_mat.set_shader_parameter("normal_tex", _water_normal)


func _rebuild_markers() -> void:
	for child in markers_root.get_children():
		child.free()
	_spawn_marker_group(SanMapData.MARKER_SPAWN, Color(0.25, 0.95, 0.4))
	_spawn_marker_group(SanMapData.MARKER_ALLOYS, Color(1.0, 0.78, 0.2))


func _rebuild_props() -> void:
	if props_root == null:
		return
	for child in props_root.get_children():
		child.free()
	for group in EditorState.map.props:
		if typeof(group) != TYPE_DICTIONARY:
			continue
		var blueprint := str(group.get("blueprintPath", ""))
		var transforms: Array = group.get("transforms", [])
		if transforms.is_empty():
			continue
		var mmi := MultiMeshInstance3D.new()
		mmi.name = blueprint.get_file().get_basename()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var box := BoxMesh.new()
		box.size = PropCatalog.proxy_size_for(blueprint)
		mm.mesh = box
		mm.instance_count = transforms.size()
		var proxy_half_y := PropCatalog.proxy_size_for(blueprint).y * 0.5
		for i in transforms.size():
			if typeof(transforms[i]) != TYPE_DICTIONARY:
				continue
			mm.set_instance_transform(i, _prop_transform_from_dict(transforms[i], proxy_half_y))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.albedo_color = PropCatalog.color_for(blueprint)
		mat.roughness = 0.85
		mmi.material_override = mat
		mmi.multimesh = mm
		props_root.add_child(mmi)


func _prop_transform_from_dict(t: Dictionary, proxy_half_y: float) -> Transform3D:
	var pos: Dictionary = t.get("position", {})
	var rot: Dictionary = t.get("rotation", {})
	var scl: Dictionary = t.get("scale", {})
	var p := Vector3(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)), float(pos.get("z", 0.0)))
	var q := Quaternion(
		float(rot.get("x", 0.0)),
		float(rot.get("y", 0.0)),
		float(rot.get("z", 0.0)),
		float(rot.get("w", 1.0))
	)
	if not q.is_normalized():
		q = q.normalized()
	var s := Vector3(
		float(scl.get("x", 1.0)),
		float(scl.get("y", 1.0)),
		float(scl.get("z", 1.0))
	)
	var xform_basis := Basis(q).scaled(s)
	# Lift proxy mesh so the base sits on terrain instead of centering through it.
	p.y += proxy_half_y * s.y
	return Transform3D(xform_basis, p)


func _restick_markers() -> void:
	for child in markers_root.get_children():
		if child is Node3D:
			var n := child as Node3D
			var p := n.global_position
			p.y = EditorState.sample_world_height(p) + n.get_meta("hover", 8.0)
			n.global_position = p


func _make_shape_preview() -> void:
	_shape_preview = MeshInstance3D.new()
	_shape_preview.name = "ShapePreview"
	_shape_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shape_preview.material_override = mat
	add_child(_shape_preview)


func _make_pathing_visuals() -> void:
	_pathing_overlay_mesh = MeshInstance3D.new()
	_pathing_overlay_mesh.name = "PathingOverlay"
	_pathing_overlay_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pathing_overlay_mesh)

	_pathing_path_mesh = MeshInstance3D.new()
	_pathing_path_mesh.name = "PathingPath"
	_pathing_path_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var path_mat := StandardMaterial3D.new()
	path_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	path_mat.albedo_color = Color(0.2, 1.0, 0.45, 1.0)
	path_mat.no_depth_test = true
	path_mat.render_priority = 30
	path_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pathing_path_mesh.material_override = path_mat
	add_child(_pathing_path_mesh)


func _rebuild_shape_preview() -> void:
	if _shape_preview == null:
		return
	if EditorState.is_flat_view() or not EditorState.is_shape_tool() or not EditorState.shape_draft_active:
		_shape_preview.visible = false
		return
	var pts: Array[Vector3] = EditorState.shape_draft_points.duplicate()
	if EditorState.shape_draft_has_cursor:
		pts.append(EditorState.shape_draft_cursor)
	if pts.size() < 2:
		_shape_preview.visible = false
		return

	var im := ImmediateMesh.new()
	var mat := _shape_preview.material_override as StandardMaterial3D
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	match EditorState.active_tool:
		EditorState.Tool.SHAPE_LINE, EditorState.Tool.SHAPE_RAMP:
			_im_line(im, pts[0], pts[1])
			_im_width_guides(im, pts[0], pts[1], EditorState.brush_radius)
			if EditorState.active_tool == EditorState.Tool.SHAPE_RAMP:
				var start_h := EditorState.sample_world_height(pts[0])
				var need := TerrainShapes.ramp_preview_length(start_h, EditorState.set_height_world, EditorState.ramp_angle_deg)
				var dir := Vector3(pts[1].x - pts[0].x, 0.0, pts[1].z - pts[0].z)
				if dir.length() > 0.001:
					dir = dir.normalized()
					var mark := pts[0] + dir * need
					mark.y = EditorState.sample_world_height(mark) + 0.4
					_im_cross(im, mark, 1.5)
		EditorState.Tool.SHAPE_CIRCLE:
			_im_circle(im, pts[0], Vector2(pts[1].x - pts[0].x, pts[1].z - pts[0].z).length())
		EditorState.Tool.SHAPE_PLATEAU:
			_im_rect(im, pts[0], pts[1])
		EditorState.Tool.SHAPE_ARC:
			if pts.size() >= 3:
				_im_arc_through(im, pts[0], pts[1], pts[2])
			else:
				_im_line(im, pts[0], pts[1])
				_im_circle(im, pts[0], Vector2(pts[1].x - pts[0].x, pts[1].z - pts[0].z).length())

	im.surface_end()
	_shape_preview.mesh = im
	_shape_preview.visible = true


func _rebuild_pathing_visuals() -> void:
	if _pathing_overlay_mesh == null:
		return
	var show_pathing := EditorState.active_tool == EditorState.Tool.PATHING and not EditorState.is_flat_view()
	_pathing_overlay_mesh.visible = show_pathing and EditorState.pathing_overlay != null
	_pathing_path_mesh.visible = show_pathing and not EditorState.pathing_path.is_empty()
	if not show_pathing:
		return

	if EditorState.pathing_overlay != null:
		var img := EditorState.pathing_overlay
		var res := img.get_width()
		var step := maxi(1, int(ceil(float(res) / 96.0)))
		var map_w := float(EditorState.map.width)
		var map_l := float(EditorState.map.length)
		var im_ov := ImmediateMesh.new()
		var ov_mat := StandardMaterial3D.new()
		ov_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ov_mat.albedo_color = Color(1.0, 0.2, 0.12, 0.85)
		ov_mat.no_depth_test = true
		ov_mat.render_priority = 18
		ov_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_pathing_overlay_mesh.material_override = ov_mat
		im_ov.surface_begin(Mesh.PRIMITIVE_TRIANGLES, ov_mat)
		var half := maxf(map_w / float(res) * float(step) * 0.35, 0.4)
		for y in range(1, res - 1, step):
			for x in range(1, res - 1, step):
				if img.get_pixel(x, y).a < 0.05:
					continue
				var u := float(x) / float(res - 1)
				var v := float(y) / float(res - 1)
				var p := Vector3(u * map_w, 0.0, v * map_l)
				p.y = EditorState.sample_world_height(p) + 0.35
				# Small quad billboard-ish marker on the surface.
				im_ov.surface_add_vertex(p + Vector3(-half, 0, -half))
				im_ov.surface_add_vertex(p + Vector3(half, 0, -half))
				im_ov.surface_add_vertex(p + Vector3(half, 0, half))
				im_ov.surface_add_vertex(p + Vector3(-half, 0, -half))
				im_ov.surface_add_vertex(p + Vector3(half, 0, half))
				im_ov.surface_add_vertex(p + Vector3(-half, 0, half))
		im_ov.surface_end()
		_pathing_overlay_mesh.mesh = im_ov
		_pathing_overlay_mesh.position = Vector3.ZERO

	if not EditorState.pathing_path.is_empty():
		var im := ImmediateMesh.new()
		var path_mat := _pathing_path_mesh.material_override as StandardMaterial3D
		if EditorState.pathing_path_ok:
			path_mat.albedo_color = Color(0.2, 1.0, 0.45, 1.0)
		else:
			path_mat.albedo_color = Color(1.0, 0.3, 0.2, 1.0)
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, path_mat)
		for p in EditorState.pathing_path:
			var lifted := p
			lifted.y = EditorState.sample_world_height(p) + 0.5
			im.surface_add_vertex(lifted)
		im.surface_end()
		_pathing_path_mesh.mesh = im


func _im_line(im: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	var a2 := a
	var b2 := b
	a2.y = EditorState.sample_world_height(a) + 0.35
	b2.y = EditorState.sample_world_height(b) + 0.35
	im.surface_add_vertex(a2)
	im.surface_add_vertex(b2)


func _im_cross(im: ImmediateMesh, p: Vector3, arm: float) -> void:
	im.surface_add_vertex(p + Vector3(-arm, 0, 0))
	im.surface_add_vertex(p + Vector3(arm, 0, 0))
	im.surface_add_vertex(p + Vector3(0, 0, -arm))
	im.surface_add_vertex(p + Vector3(0, 0, arm))


func _im_width_guides(im: ImmediateMesh, a: Vector3, b: Vector3, width: float) -> void:
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if flat.length() < 0.001:
		return
	var dir := flat.normalized()
	var side := Vector3(-dir.z, 0.0, dir.x) * (width * 0.5)
	_im_line(im, a + side, b + side)
	_im_line(im, a - side, b - side)


func _im_circle(im: ImmediateMesh, center: Vector3, radius: float) -> void:
	var r := maxf(radius, 0.25)
	var steps := 64
	var cy := EditorState.sample_world_height(center) + 0.35
	for i in steps:
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		var p0 := Vector3(center.x + cos(a0) * r, cy, center.z + sin(a0) * r)
		var p1 := Vector3(center.x + cos(a1) * r, cy, center.z + sin(a1) * r)
		p0.y = EditorState.sample_world_height(p0) + 0.35
		p1.y = EditorState.sample_world_height(p1) + 0.35
		im.surface_add_vertex(p0)
		im.surface_add_vertex(p1)


func _im_rect(im: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	var x0 := minf(a.x, b.x)
	var x1 := maxf(a.x, b.x)
	var z0 := minf(a.z, b.z)
	var z1 := maxf(a.z, b.z)
	var corners := [
		Vector3(x0, 0, z0), Vector3(x1, 0, z0),
		Vector3(x1, 0, z1), Vector3(x0, 0, z1),
	]
	for i in 4:
		_im_line(im, corners[i], corners[(i + 1) % 4])


func _im_arc_through(im: ImmediateMesh, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	var circle := TerrainShapes.circumcircle_xz(p0, p1, p2)
	if circle.is_empty():
		_im_line(im, p0, p2)
		return
	var center: Vector3 = circle.center
	var radius: float = circle.radius
	var a0 := atan2(p0.z - center.z, p0.x - center.x)
	var a_mid := atan2(p1.z - center.z, p1.x - center.x)
	var a2 := atan2(p2.z - center.z, p2.x - center.x)
	var sweep := TerrainShapes.arc_sweep_through(a0, a_mid, a2)
	var steps := clampi(int(ceil(absf(sweep) * radius / 1.0)), 12, 128)
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var ang0 := a0 + sweep * t0
		var ang1 := a0 + sweep * t1
		var q0 := Vector3(center.x + cos(ang0) * radius, 0.0, center.z + sin(ang0) * radius)
		var q1 := Vector3(center.x + cos(ang1) * radius, 0.0, center.z + sin(ang1) * radius)
		_im_line(im, q0, q1)


func _spawn_marker_group(marker_type: String, color: Color) -> void:
	var bucket: Dictionary = EditorState.map.markers.get(marker_type, {})
	var transforms: Dictionary = bucket.get("transforms", {})
	var map_scale := maxf(float(EditorState.map.width), float(EditorState.map.length))
	var stem_h := clampf(map_scale * 0.06, 10.0, 28.0)
	var head_r := clampf(map_scale * 0.018, 3.5, 8.0)

	for id in transforms.keys():
		var t: Dictionary = transforms[id]
		var pos: Dictionary = t.get("position", {})
		var root := Node3D.new()
		root.name = str(id)
		root.set_meta("hover", stem_h * 0.55)

		var stem := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = head_r * 0.18
		cyl.bottom_radius = head_r * 0.22
		cyl.height = stem_h
		stem.mesh = cyl
		stem.position = Vector3(0.0, stem_h * 0.5, 0.0)

		var head := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = head_r
		sphere.height = head_r * 2.0
		head.mesh = sphere
		head.position = Vector3(0.0, stem_h + head_r * 0.2, 0.0)

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
		stem.material_override = mat
		head.material_override = mat

		root.add_child(stem)
		root.add_child(head)

		var p := Vector3(float(pos.get("x", 0.0)), 0.0, float(pos.get("z", 0.0)))
		p.y = EditorState.sample_world_height(p)
		root.position = p
		markers_root.add_child(root)
