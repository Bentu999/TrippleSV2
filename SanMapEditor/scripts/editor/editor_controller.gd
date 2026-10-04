extends Node3D
## Raycasts from the camera and applies the active terrain / marker tool.

@onready var camera: Camera3D = $"../OrbitCamera/Camera3D"
@onready var terrain: MeshInstance3D = $"../Terrain"
@onready var brush_ring: MeshInstance3D = $"../BrushRing"
@onready var mirror_rings_root: Node3D = $"../MirrorBrushRings"
@onready var markers_root: Node3D = $"../Markers"
@onready var playable_area: MeshInstance3D = $"../PlayableArea"
@onready var water: MeshInstance3D = $"../Water"

var _painting: bool = false
var _last_hit: Vector3 = Vector3.ZERO
var _has_last_hit: bool = false
var _mirror_rings: Array[MeshInstance3D] = []


func _ready() -> void:
	EditorState.map_changed.connect(_refresh_overlays)
	EditorState.markers_changed.connect(_rebuild_markers)
	EditorState.heights_changed.connect(_on_heights_changed)
	EditorState.tool_changed.connect(_on_tool_changed)
	_make_brush_ring()
	_refresh_overlays()
	_rebuild_markers()


func _on_tool_changed() -> void:
	# Switching tools must always end an active stroke.
	_painting = false


func _on_heights_changed(_dirty: Rect2i) -> void:
	_update_water()
	_restick_markers()


func _process(delta: float) -> void:
	if EditorState.is_flat_view():
		brush_ring.visible = false
		_hide_mirror_rings()
		_painting = false
		return
	if _is_pointer_over_blocking_ui():
		brush_ring.visible = false
		_hide_mirror_rings()
		return

	var hit := _raycast_terrain()
	if hit.is_empty():
		if _painting and _has_last_hit:
			_apply_at(_last_hit, delta)
		else:
			brush_ring.visible = false
			_hide_mirror_rings()
		return

	_last_hit = hit.position
	_has_last_hit = true
	var show_brush := _is_sculpt_tool(EditorState.active_tool)
	brush_ring.visible = show_brush
	var s := EditorState.brush_radius
	if show_brush:
		_update_brush_ghosts(hit.position, s)
	else:
		_hide_mirror_rings()

	if _painting:
		_apply_at(hit.position, delta)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	# Always stop painting on release, even if release happens over UI.
	if not mb.pressed:
		_painting = false
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
		EditorState.Tool.ORBIT:
			pass
		_:
			if _is_sculpt_tool(EditorState.active_tool):
				_painting = true
				_apply_at(hit.position, get_process_delta_time())
				get_viewport().set_input_as_handled()


func _is_sculpt_tool(tool: EditorState.Tool) -> bool:
	return tool == EditorState.Tool.RAISE \
		or tool == EditorState.Tool.LOWER \
		or tool == EditorState.Tool.SMOOTH \
		or tool == EditorState.Tool.SET_HEIGHT \
		or tool == EditorState.Tool.PAINT_TEXTURE


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

	_setup_brush_instance(brush_ring, torus, Color(1.0, 0.82, 0.12, 1.0), false)

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


func _make_brush_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.no_depth_test = true
	mat.render_priority = 20
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


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
	plane.size = Vector2(float(map.width), float(map.length))
	water.mesh = plane
	water.position = Vector3(float(map.width) * 0.5, map.water_level, float(map.length) * 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.35, 0.55, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	mat.metallic = 0.2
	water.material_override = mat


func _rebuild_markers() -> void:
	for child in markers_root.get_children():
		child.free()
	_spawn_marker_group(SanMapData.MARKER_SPAWN, Color(0.25, 0.95, 0.4))
	_spawn_marker_group(SanMapData.MARKER_ALLOYS, Color(1.0, 0.78, 0.2))


func _restick_markers() -> void:
	for child in markers_root.get_children():
		if child is Node3D:
			var n := child as Node3D
			var p := n.global_position
			p.y = EditorState.sample_world_height(p) + n.get_meta("hover", 8.0)
			n.global_position = p


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
