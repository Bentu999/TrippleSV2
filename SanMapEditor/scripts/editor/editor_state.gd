extends Node
## Global editor state (autoload).


signal map_changed
## Emitted after height edits. Empty rect = full texture refresh.
signal heights_changed(dirty: Rect2i)
## Emitted after splat weight edits. Empty rect = full splat refresh.
signal splat_changed(dirty: Rect2i)
signal materials_changed
signal markers_changed
signal props_changed
signal tool_changed
signal dirty_changed
signal view_changed
signal mirror_changed
signal paint_layer_changed
signal history_changed
signal measurement_changed
signal scale_guides_changed
signal prop_settings_changed
signal shape_draft_changed
signal pathing_changed

enum Tool {
	ORBIT,
	RAISE,
	LOWER,
	SMOOTH,
	SET_HEIGHT,
	MEASURE_HEIGHT,
	PAINT_TEXTURE,
	SHAPE_LINE,
	SHAPE_CIRCLE,
	SHAPE_ARC,
	SHAPE_PLATEAU,
	SHAPE_RAMP,
	PATHING,
	MARKER_SPAWN,
	MARKER_ALLOYS,
	PLACE_PROP,
}

enum ViewMode {
	VIEW_3D,
	VIEW_2D,
	VIEW_HEIGHTMAP,
}

var map: SanMapData = SanMapData.new()
var heights: PackedFloat32Array = PackedFloat32Array()
## In-memory stratum splat weights (RGBA = layers 0-3 / 4-7).
var splat_1_4: Image
var splat_5_8: Image
## In-memory tint maps (colors + geometry/normal tint).
var tint_colors: Image
var tint_geometry: Image
var current_path: String = ""
var is_dirty: bool = false
var active_tool: Tool = Tool.RAISE
var view_mode: ViewMode = ViewMode.VIEW_3D
## Active terrain material preset id (see TerrainPresets).
var terrain_preset_id: String = "highlands"
## Active stratum layer index for PAINT_TEXTURE (0..7).
var paint_layer: int = 0

var brush_radius: float = 12.0
## Normalized height change per second at brush center (frame-rate independent).
var brush_strength: float = 0.35
## Absolute world-space target height for SET_HEIGHT brush / shape fill / ramp end.
var set_height_world: float = 16.0
## How shapes combine with Zielhöhe: SET / RAISE / LOWER (see TerrainShapes.HeightMode).
var shape_height_mode: int = TerrainShapes.HeightMode.SET
## Target slope for SHAPE_RAMP (degrees).
var ramp_angle_deg: float = 15.0
## Horizontal length of the finished ramp (metres). Direction comes from aim / rotate buttons.
var ramp_length_m: float = 32.0
## Last sampled start height under the ramp cursor (links angle ↔ length in the UI).
var ramp_ref_start_h: float = 16.0
## Horizontal aim direction for ramp preview / placement (unit XZ vector).
var ramp_aim_dir: Vector3 = Vector3(0.0, 0.0, 1.0)
## True after the user rotates / drags the ramp aim (stops camera auto-aim).
var ramp_aim_manual: bool = false
## Max walkable slope for PATHING checks (degrees).
var pathing_max_angle_deg: float = 30.0
## Live brush symmetry across map center (X and/or Z).
var mirror_x_enabled: bool = false
var mirror_z_enabled: bool = false

## Multi-click / drag draft for geometric shape tools.
var shape_draft_active: bool = false
var shape_draft_points: Array[Vector3] = []
var shape_draft_cursor: Vector3 = Vector3.ZERO
var shape_draft_has_cursor: bool = false

## Pathing overlay + optional A→B walkability result.
var pathing_overlay: Image
var pathing_path: Array[Vector3] = []
var pathing_path_ok: bool = false
var pathing_pick_a: Vector3 = Vector3.ZERO
var pathing_has_a: bool = false
var pathing_status: String = ""

## Height probe (MEASURE_HEIGHT tool).
var measure_live_valid: bool = false
var measure_live_height: float = 0.0
var measure_live_pos: Vector3 = Vector3.ZERO
var measure_pinned: bool = false
var measure_pinned_height: float = 0.0
var measure_pinned_pos: Vector3 = Vector3.ZERO

## Grid / 2 m figure / edge ticks for judging world scale in the 3D view.
var show_scale_guides: bool = true

## Active prop blueprint for PLACE_PROP tool.
var prop_blueprint: String = PropCatalog.FALLBACK_BLUEPRINTS[0]
var prop_scale: float = 1.0
var prop_random_yaw: bool = true

const MAX_HISTORY := 40
var _undo_stack: Array = []
var _redo_stack: Array = []
var _stroke_open: bool = false
var _stroke_label: String = ""
var _stroke_before_heights: Dictionary = {}
var _stroke_before_splat14: Dictionary = {}
var _stroke_before_splat58: Dictionary = {}
var _stroke_markers_before: Dictionary = {}
var _stroke_armies_before: Dictionary = {}
var _stroke_props_before: Array = []
var _stroke_meta_before: Dictionary = {}
var _stroke_touched_heights: bool = false
var _stroke_touched_splat: bool = false
var _stroke_touched_markers: bool = false
var _stroke_touched_props: bool = false
var _stroke_touched_meta: bool = false
var _history_applying: bool = false


func _ready() -> void:
	PropCatalog.all_blueprints()
	new_map(256, 256, 128, 257)


func new_map(width: int, length: int, height: int, resolution: int) -> void:
	clear_history()
	map = SanMapData.new()
	# Prefer official convention heightmapResolution = width + 1 when square.
	var hm_res := resolution
	if width == length and resolution <= 0:
		hm_res = width + 1
	map.resize(width, length, height, hm_res, true)
	TerrainPresets.apply(map, terrain_preset_id if not terrain_preset_id.is_empty() else "highlands")
	map.has_water = false
	map.water_level = _default_water_level_world()
	_alloc_flat_heights(_default_land_height_normalized())
	_alloc_default_splats()
	_alloc_default_tints()
	current_path = ""
	_set_dirty(false)
	map_changed.emit()
	heights_changed.emit(Rect2i())
	splat_changed.emit(Rect2i())
	materials_changed.emit()
	markers_changed.emit()
	props_changed.emit()


## Default water table in world metres for new maps.
func _default_water_level_world() -> float:
	var h := maxf(float(map.height), 1.0)
	return minf(16.0, h * 0.125)


## Normalized heightmap fill so the starting land sits clearly above water.
func _default_land_height_normalized() -> float:
	var h := maxf(float(map.height), 1.0)
	var water := map.water_level if map.has_water else _default_water_level_world()
	var land_world := water + maxf(4.0, h * 0.04)
	return clampf(land_world / h, 0.0, 1.0)


func _alloc_flat_heights(value: float) -> void:
	var n := map.heightmap_resolution * map.heightmap_resolution
	heights.resize(n)
	heights.fill(value)


func _alloc_default_splats() -> void:
	var res := SanMapIO.splat_resolution_for_map(map)
	var pair := SanMapIO.make_default_splat_images(res)
	splat_1_4 = pair[0]
	splat_5_8 = pair[1]


func _alloc_default_tints() -> void:
	var res := SanMapIO.tint_resolution_for_map(map)
	var pair := SanMapIO.make_default_tint_images(res)
	tint_colors = pair[0]
	tint_geometry = pair[1]


func splat_resolution() -> int:
	if splat_1_4 != null:
		return splat_1_4.get_width()
	return SanMapIO.splat_resolution_for_map(map)


func ensure_splat_images() -> void:
	var res := SanMapIO.splat_resolution_for_map(map)
	if splat_1_4 == null or splat_5_8 == null:
		_alloc_default_splats()
		return
	if splat_1_4.get_width() != res or splat_1_4.get_height() != res:
		splat_1_4.resize(res, res, Image.INTERPOLATE_BILINEAR)
	if splat_5_8.get_width() != res or splat_5_8.get_height() != res:
		splat_5_8.resize(res, res, Image.INTERPOLATE_BILINEAR)


func ensure_tint_images() -> void:
	var res := SanMapIO.tint_resolution_for_map(map)
	if tint_colors == null or tint_geometry == null:
		_alloc_default_tints()
		return
	if tint_colors.get_width() != res or tint_colors.get_height() != res:
		tint_colors.resize(res, res, Image.INTERPOLATE_BILINEAR)
	if tint_geometry.get_width() != res or tint_geometry.get_height() != res:
		tint_geometry.resize(res, res, Image.INTERPOLATE_BILINEAR)


func set_terrain_preset(preset_id: String) -> void:
	if preset_id.is_empty() or preset_id == terrain_preset_id:
		return
	var owned := begin_stroke("Terrain preset")
	terrain_preset_id = preset_id
	TerrainPresets.apply(map, preset_id)
	map.ensure_playable_materials()
	_stroke_touched_meta = true
	mark_dirty()
	materials_changed.emit()
	map_changed.emit()
	if owned:
		end_stroke()


func set_water_enabled(enabled: bool) -> void:
	if map.has_water == enabled:
		return
	var owned := begin_stroke("Water")
	map.has_water = enabled
	_stroke_touched_meta = true
	mark_dirty()
	map_changed.emit()
	if owned:
		end_stroke()


func set_water_level(level: float) -> void:
	if is_equal_approx(map.water_level, level):
		return
	map.water_level = level
	if _stroke_open:
		_stroke_touched_meta = true
	mark_dirty()
	map_changed.emit()


func set_playable_area(x: float, y: float, area_width: float, area_height: float) -> void:
	var before := map.get_playable_area()
	var trial := {
		"x": x,
		"y": y,
		"width": area_width,
		"height": area_height,
	}
	# Preview clamp without mutating yet.
	var max_w := float(map.width)
	var max_l := float(map.length)
	var w := clampf(float(trial["width"]), 1.0, max_w)
	var h := clampf(float(trial["height"]), 1.0, max_l)
	var nx := clampf(float(trial["x"]), 0.0, max_w - w)
	var ny := clampf(float(trial["y"]), 0.0, max_l - h)
	if (
		is_equal_approx(before["x"], nx)
		and is_equal_approx(before["y"], ny)
		and is_equal_approx(before["width"], w)
		and is_equal_approx(before["height"], h)
	):
		return
	var owned := begin_stroke("Playable area")
	map.set_playable_area(nx, ny, w, h)
	_stroke_touched_meta = true
	mark_dirty()
	map_changed.emit()
	if owned:
		end_stroke()


func reset_playable_to_full() -> void:
	var before := map.get_playable_area()
	if (
		is_equal_approx(before["x"], 0.0)
		and is_equal_approx(before["y"], 0.0)
		and is_equal_approx(before["width"], float(map.width))
		and is_equal_approx(before["height"], float(map.length))
	):
		return
	var owned := begin_stroke("Playable area full")
	map.reset_playable_to_full()
	_stroke_touched_meta = true
	mark_dirty()
	map_changed.emit()
	if owned:
		end_stroke()


func reset_playable_to_centered() -> void:
	var before := map.get_playable_area()
	var w := maxf(float(map.width) * 0.5, 1.0)
	var h := maxf(float(map.length) * 0.5, 1.0)
	var x := (float(map.width) - w) * 0.5
	var y := (float(map.length) - h) * 0.5
	if (
		is_equal_approx(before["x"], x)
		and is_equal_approx(before["y"], y)
		and is_equal_approx(before["width"], w)
		and is_equal_approx(before["height"], h)
	):
		return
	var owned := begin_stroke("Playable area centered")
	map.reset_playable_to_centered()
	_stroke_touched_meta = true
	mark_dirty()
	map_changed.emit()
	if owned:
		end_stroke()


func center_playable_area() -> void:
	var before := map.get_playable_area()
	var w: float = before["width"]
	var h: float = before["height"]
	var x := (float(map.width) - w) * 0.5
	var y := (float(map.length) - h) * 0.5
	if is_equal_approx(before["x"], x) and is_equal_approx(before["y"], y):
		return
	var owned := begin_stroke("Center playable area")
	map.center_playable_area()
	_stroke_touched_meta = true
	mark_dirty()
	map_changed.emit()
	if owned:
		end_stroke()


func set_fade_distance(value: float) -> void:
	var clamped := maxf(value, 0.0)
	if is_equal_approx(map.fade_distance, clamped):
		return
	var owned := begin_stroke("Fade distance")
	map.fade_distance = clamped
	_stroke_touched_meta = true
	mark_dirty()
	map_changed.emit()
	if owned:
		end_stroke()


func set_fade_start_distance(value: float) -> void:
	var clamped := maxf(value, 0.0)
	if is_equal_approx(map.fade_start_distance, clamped):
		return
	var owned := begin_stroke("Fade start")
	map.fade_start_distance = clamped
	_stroke_touched_meta = true
	mark_dirty()
	map_changed.emit()
	if owned:
		end_stroke()


func touch_meta_for_stroke() -> void:
	if _stroke_open:
		_stroke_touched_meta = true


func set_paint_layer(layer: int) -> void:
	var clamped := clampi(layer, 0, 7)
	if paint_layer == clamped:
		paint_layer_changed.emit()
		return
	paint_layer = clamped
	paint_layer_changed.emit()


func set_tool(tool: Tool) -> void:
	if active_tool == tool:
		tool_changed.emit()
		return
	clear_shape_draft()
	clear_pathing_pick()
	active_tool = tool
	if tool == Tool.PATHING:
		refresh_pathing_overlay()
	else:
		_clear_pathing_overlay()
	tool_changed.emit()


func is_shape_tool(tool: Tool = active_tool) -> bool:
	return tool == Tool.SHAPE_LINE \
		or tool == Tool.SHAPE_CIRCLE \
		or tool == Tool.SHAPE_ARC \
		or tool == Tool.SHAPE_PLATEAU \
		or tool == Tool.SHAPE_RAMP


func shape_points_needed(tool: Tool = active_tool) -> int:
	match tool:
		Tool.SHAPE_ARC:
			return 3
		Tool.SHAPE_LINE, Tool.SHAPE_CIRCLE, Tool.SHAPE_PLATEAU, Tool.SHAPE_RAMP:
			return 2
		_:
			return 0


func set_ramp_angle_deg(value: float) -> void:
	ramp_angle_deg = clampf(value, 0.5, 80.0)
	# Keep a finished ramp: angle + height delta define horizontal length.
	var dh := absf(set_height_world - ramp_ref_start_h)
	var tan_a := tan(deg_to_rad(ramp_angle_deg))
	if tan_a > 0.0001 and dh > 0.001:
		ramp_length_m = clampf(dh / tan_a, 2.0, 512.0)
	_notify_ramp_preview()


func set_ramp_length_m(value: float) -> void:
	ramp_length_m = clampf(value, 2.0, 512.0)
	var dh := absf(set_height_world - ramp_ref_start_h)
	if ramp_length_m > 0.001 and dh > 0.001:
		ramp_angle_deg = clampf(rad_to_deg(atan(dh / ramp_length_m)), 0.5, 80.0)
	_notify_ramp_preview()


func set_ramp_end_height(world_h: float) -> void:
	set_height_world = clampf(world_h, 0.0, float(map.height))
	var dh := absf(set_height_world - ramp_ref_start_h)
	if ramp_length_m > 0.001 and dh > 0.001:
		ramp_angle_deg = clampf(rad_to_deg(atan(dh / ramp_length_m)), 0.5, 80.0)
	elif ramp_angle_deg > 0.001 and dh > 0.001:
		var tan_a := tan(deg_to_rad(ramp_angle_deg))
		if tan_a > 0.0001:
			ramp_length_m = clampf(dh / tan_a, 2.0, 512.0)
	_notify_ramp_preview()


func update_ramp_ref_start(world_h: float) -> void:
	ramp_ref_start_h = world_h


func set_ramp_aim_dir(dir: Vector3, mark_manual: bool = false) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.001:
		return
	var next := flat.normalized()
	var dir_changed := not ramp_aim_dir.is_equal_approx(next)
	var manual_changed := mark_manual and not ramp_aim_manual
	if not dir_changed and not manual_changed:
		return
	ramp_aim_dir = next
	if mark_manual:
		ramp_aim_manual = true
	_notify_ramp_preview()


func rotate_ramp_aim_deg(yaw_deg: float) -> void:
	ramp_aim_dir = ramp_aim_dir.rotated(Vector3.UP, deg_to_rad(yaw_deg)).normalized()
	ramp_aim_manual = true
	_notify_ramp_preview()


func _notify_ramp_preview() -> void:
	if active_tool == Tool.SHAPE_RAMP:
		shape_draft_changed.emit()


func set_shape_height_mode(mode: int) -> void:
	shape_height_mode = clampi(mode, TerrainShapes.HeightMode.SET, TerrainShapes.HeightMode.LOWER)


func set_pathing_max_angle_deg(value: float) -> void:
	var v := clampf(value, 1.0, 89.0)
	if is_equal_approx(v, pathing_max_angle_deg):
		return
	pathing_max_angle_deg = v
	if active_tool == Tool.PATHING:
		refresh_pathing_overlay()
		if pathing_has_a and not pathing_path.is_empty():
			# Re-run last path if we still have endpoints.
			var goal := pathing_path[pathing_path.size() - 1]
			run_pathing_check(pathing_pick_a, goal)


func clear_shape_draft() -> void:
	if not shape_draft_active and shape_draft_points.is_empty() and not shape_draft_has_cursor:
		return
	shape_draft_active = false
	shape_draft_points.clear()
	shape_draft_has_cursor = false
	shape_draft_changed.emit()


func update_shape_cursor(world_pos: Vector3, valid: bool) -> void:
	shape_draft_has_cursor = valid
	if valid:
		shape_draft_cursor = world_pos
		# Sync ramp aim from drag direction without a second notify cycle.
		if active_tool == Tool.SHAPE_RAMP and shape_draft_active and not shape_draft_points.is_empty():
			var origin: Vector3 = shape_draft_points[0]
			var flat := Vector3(world_pos.x - origin.x, 0.0, world_pos.z - origin.z)
			if flat.length() > 0.001:
				ramp_aim_dir = flat.normalized()
				ramp_aim_manual = true
	shape_draft_changed.emit()


func begin_shape_draft(world_pos: Vector3) -> void:
	shape_draft_active = true
	shape_draft_points = [world_pos]
	shape_draft_cursor = world_pos
	shape_draft_has_cursor = true
	if active_tool == Tool.SHAPE_RAMP:
		update_ramp_ref_start(sample_world_height(world_pos))
	shape_draft_changed.emit()


func add_shape_draft_point(world_pos: Vector3) -> void:
	if not shape_draft_active:
		begin_shape_draft(world_pos)
		return
	shape_draft_points.append(world_pos)
	shape_draft_cursor = world_pos
	shape_draft_has_cursor = true
	var needed := shape_points_needed()
	if shape_draft_points.size() >= needed:
		commit_shape_draft()
	else:
		shape_draft_changed.emit()


func commit_shape_draft_with_cursor() -> void:
	if not shape_draft_active or shape_draft_points.is_empty():
		return
	if shape_draft_has_cursor:
		# Two-point drag tools: start + current cursor.
		if shape_points_needed() == 2:
			shape_draft_points = [shape_draft_points[0], shape_draft_cursor]
			commit_shape_draft()
			return
		# Arc: accumulate cursor as next click equivalent on release of first drag.
		if active_tool == Tool.SHAPE_ARC and shape_draft_points.size() == 1:
			shape_draft_points.append(shape_draft_cursor)
			shape_draft_changed.emit()
			return
	commit_shape_draft()


func commit_shape_draft() -> void:
	if not is_shape_tool() or shape_draft_points.is_empty():
		clear_shape_draft()
		return
	var pts := shape_draft_points.duplicate()
	if shape_draft_has_cursor and pts.size() < shape_points_needed():
		pts.append(shape_draft_cursor)
	if pts.size() < shape_points_needed():
		shape_draft_changed.emit()
		return

	var owned := begin_stroke(_shape_stroke_label(active_tool))
	var dirty := Rect2i()
	var hmode := shape_height_mode
	match active_tool:
		Tool.SHAPE_LINE:
			dirty = TerrainShapes.apply_line(self, pts[0], pts[1], brush_radius, set_height_world, hmode)
		Tool.SHAPE_CIRCLE:
			var radius := Vector2(pts[1].x - pts[0].x, pts[1].z - pts[0].z).length()
			dirty = TerrainShapes.apply_circle(self, pts[0], radius, set_height_world, hmode)
		Tool.SHAPE_ARC:
			dirty = TerrainShapes.apply_arc(self, pts[0], pts[1], pts[2], brush_radius, set_height_world, hmode)
		Tool.SHAPE_PLATEAU:
			dirty = TerrainShapes.apply_plateau(self, pts[0], pts[1], set_height_world, hmode)
		Tool.SHAPE_RAMP:
			# Click-to-place: if the cursor barely moved, stamp along the current aim.
			var ramp_aim: Vector3 = pts[1]
			var ramp_flat := Vector3(ramp_aim.x - pts[0].x, 0.0, ramp_aim.z - pts[0].z)
			if ramp_flat.length() < 0.001:
				ramp_aim = pts[0] + ramp_aim_dir
			dirty = TerrainShapes.apply_ramp(
				self,
				pts[0],
				ramp_aim,
				brush_radius,
				ramp_length_m,
				ramp_angle_deg,
				set_height_world
			)
	clear_shape_draft()
	if dirty.size.x > 0 and dirty.size.y > 0:
		mark_dirty()
		heights_changed.emit(dirty)
	if owned:
		end_stroke()


func _shape_stroke_label(tool: Tool) -> String:
	match tool:
		Tool.SHAPE_LINE:
			return "Line"
		Tool.SHAPE_CIRCLE:
			return "Circle"
		Tool.SHAPE_ARC:
			return "Arc"
		Tool.SHAPE_PLATEAU:
			return "Plateau"
		Tool.SHAPE_RAMP:
			return "Ramp"
		_:
			return "Shape"


func clear_pathing_pick() -> void:
	pathing_has_a = false
	pathing_path.clear()
	pathing_path_ok = false
	pathing_status = ""
	pathing_changed.emit()


func _clear_pathing_overlay() -> void:
	pathing_overlay = null
	pathing_changed.emit()


func refresh_pathing_overlay() -> void:
	pathing_overlay = TerrainShapes.build_slope_overlay(self, pathing_max_angle_deg)
	pathing_changed.emit()


func pathing_click(world_pos: Vector3) -> void:
	if not pathing_has_a:
		pathing_pick_a = world_pos
		pathing_has_a = true
		pathing_path.clear()
		pathing_path_ok = false
		pathing_status = "Start gesetzt — zweiten Punkt für Ziel klicken"
		pathing_changed.emit()
		return
	run_pathing_check(pathing_pick_a, world_pos)
	pathing_has_a = false


func run_pathing_check(start: Vector3, goal: Vector3) -> void:
	pathing_pick_a = start
	pathing_path = TerrainShapes.find_walkable_path(self, start, goal, pathing_max_angle_deg)
	pathing_path_ok = not pathing_path.is_empty()
	if pathing_path_ok:
		var len_m := 0.0
		for i in range(pathing_path.size() - 1):
			len_m += pathing_path[i].distance_to(pathing_path[i + 1])
		pathing_status = "Pfad OK · %.0f m · max. %.0f°" % [len_m, pathing_max_angle_deg]
	else:
		pathing_status = "Kein begehbarer Pfad bei max. %.0f°" % pathing_max_angle_deg
	pathing_changed.emit()


func set_view_mode(mode: ViewMode) -> void:
	if view_mode == mode:
		view_changed.emit()
		return
	view_mode = mode
	view_changed.emit()


func set_show_scale_guides(enabled: bool) -> void:
	if show_scale_guides == enabled:
		scale_guides_changed.emit()
		return
	show_scale_guides = enabled
	scale_guides_changed.emit()


func is_flat_view() -> bool:
	return view_mode == ViewMode.VIEW_2D or view_mode == ViewMode.VIEW_HEIGHTMAP


func mark_dirty() -> void:
	_set_dirty(true)


func _set_dirty(value: bool) -> void:
	if is_dirty == value:
		return
	is_dirty = value
	dirty_changed.emit()


func get_height(x: int, y: int) -> float:
	var res := map.heightmap_resolution
	x = clampi(x, 0, res - 1)
	y = clampi(y, 0, res - 1)
	return heights[y * res + x]


func set_height(x: int, y: int, value: float) -> void:
	var res := map.heightmap_resolution
	if x < 0 or y < 0 or x >= res or y >= res:
		return
	var idx := y * res + x
	_record_height_before(idx)
	heights[idx] = clampf(value, 0.0, 1.0)


func world_to_height_index(world: Vector3) -> Vector2i:
	var res := map.heightmap_resolution
	var u := world.x / float(map.width)
	var v := world.z / float(map.length)
	var x := int(round(u * float(res - 1)))
	var y := int(round(v * float(res - 1)))
	return Vector2i(clampi(x, 0, res - 1), clampi(y, 0, res - 1))


func world_to_splat_index(world: Vector3) -> Vector2i:
	ensure_splat_images()
	var res := splat_resolution()
	var u := world.x / float(map.width)
	var v := world.z / float(map.length)
	var x := int(round(u * float(res - 1)))
	var y := int(round(v * float(res - 1)))
	return Vector2i(clampi(x, 0, res - 1), clampi(y, 0, res - 1))


## Splat-index partners for live brush symmetry.
func expand_splat_indices(index: Vector2i) -> Array[Vector2i]:
	var res := splat_resolution()
	var out: Array[Vector2i] = []
	var seen := {}
	var seed_pts: Array[Vector2i] = [index]
	if mirror_x_enabled:
		seed_pts.append(Vector2i(res - 1 - index.x, index.y))
	if mirror_z_enabled:
		var mirrored_z: Array[Vector2i] = []
		for p in seed_pts:
			mirrored_z.append(Vector2i(p.x, res - 1 - p.y))
		seed_pts.append_array(mirrored_z)
	for p in seed_pts:
		var key := "%d,%d" % [p.x, p.y]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(p)
	return out


func height_index_to_world(x: int, y: int) -> Vector3:
	var res := map.heightmap_resolution
	var wx := (float(x) / float(res - 1)) * float(map.width)
	var wz := (float(y) / float(res - 1)) * float(map.length)
	var wy := get_height(x, y) * float(map.height)
	return Vector3(wx, wy, wz)


func set_live_measure(world_pos: Vector3, valid: bool) -> void:
	if not valid:
		if not measure_live_valid:
			return
		measure_live_valid = false
		measurement_changed.emit()
		return
	var h := sample_world_height(world_pos)
	var pos := Vector3(world_pos.x, h, world_pos.z)
	if (
		measure_live_valid
		and is_equal_approx(measure_live_height, h)
		and measure_live_pos.distance_squared_to(pos) < 0.0001
	):
		return
	measure_live_valid = true
	measure_live_height = h
	measure_live_pos = pos
	measurement_changed.emit()


func pin_measure(world_pos: Vector3) -> void:
	var h := sample_world_height(world_pos)
	measure_pinned = true
	measure_pinned_height = h
	measure_pinned_pos = Vector3(world_pos.x, h, world_pos.z)
	measure_live_valid = true
	measure_live_height = h
	measure_live_pos = measure_pinned_pos
	measurement_changed.emit()


func clear_pinned_measure() -> void:
	if not measure_pinned and not measure_live_valid:
		return
	measure_pinned = false
	measure_live_valid = false
	measurement_changed.emit()


func refresh_pinned_measure_height() -> void:
	if not measure_pinned:
		return
	measure_pinned_height = sample_world_height(measure_pinned_pos)
	measure_pinned_pos.y = measure_pinned_height
	measurement_changed.emit()


func measure_normalized(height_world: float = -1.0) -> float:
	var h := measure_live_height if height_world < 0.0 else height_world
	var map_h := maxf(float(map.height), 0.001)
	return clampf(h / map_h, 0.0, 1.0)


func sample_world_height(world_xz: Vector3) -> float:
	var res := map.heightmap_resolution
	var fx := (world_xz.x / float(map.width)) * float(res - 1)
	var fy := (world_xz.z / float(map.length)) * float(res - 1)
	var x0 := clampi(int(floor(fx)), 0, res - 1)
	var y0 := clampi(int(floor(fy)), 0, res - 1)
	var x1 := mini(x0 + 1, res - 1)
	var y1 := mini(y0 + 1, res - 1)
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var h00 := get_height(x0, y0)
	var h10 := get_height(x1, y0)
	var h01 := get_height(x0, y1)
	var h11 := get_height(x1, y1)
	var h0 := lerpf(h00, h10, tx)
	var h1 := lerpf(h01, h11, tx)
	return lerpf(h0, h1, ty) * float(map.height)


func _brush_dirty_rect(center: Vector2i, radius_cells: int) -> Rect2i:
	var res := map.heightmap_resolution
	var x0 := maxi(center.x - radius_cells, 0)
	var y0 := maxi(center.y - radius_cells, 0)
	var x1 := mini(center.x + radius_cells, res - 1)
	var y1 := mini(center.y + radius_cells, res - 1)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func set_mirror_x(enabled: bool) -> void:
	if mirror_x_enabled == enabled:
		return
	mirror_x_enabled = enabled
	mirror_changed.emit()


func set_mirror_z(enabled: bool) -> void:
	if mirror_z_enabled == enabled:
		return
	mirror_z_enabled = enabled
	mirror_changed.emit()


func toggle_mirror_x() -> void:
	set_mirror_x(not mirror_x_enabled)


func toggle_mirror_z() -> void:
	set_mirror_z(not mirror_z_enabled)


## Heightmap index partners for live brush symmetry (res - coord - 1).
func expand_height_indices(index: Vector2i) -> Array[Vector2i]:
	var res := map.heightmap_resolution
	var out: Array[Vector2i] = []
	var seen := {}
	var seed_pts: Array[Vector2i] = [index]
	if mirror_x_enabled:
		seed_pts.append(Vector2i(res - 1 - index.x, index.y))
	if mirror_z_enabled:
		var mirrored_z: Array[Vector2i] = []
		for p in seed_pts:
			mirrored_z.append(Vector2i(p.x, res - 1 - p.y))
		seed_pts.append_array(mirrored_z)
	for p in seed_pts:
		var key := "%d,%d" % [p.x, p.y]
		if seen.has(key):
			continue
		seen[key] = true
		out.append(p)
	return out


## World-space brush centers (primary first) for cursor ghosts / marker placement.
func expand_brush_world_points(world_pos: Vector3) -> Array[Vector3]:
	var map_w := float(map.width)
	var map_l := float(map.length)
	var seed_pts: Array[Vector3] = [world_pos]
	if mirror_x_enabled:
		seed_pts.append(Vector3(map_w - world_pos.x, world_pos.y, world_pos.z))
	if mirror_z_enabled:
		var mirrored_z: Array[Vector3] = []
		for p in seed_pts:
			mirrored_z.append(Vector3(p.x, p.y, map_l - p.z))
		seed_pts.append_array(mirrored_z)
	var out: Array[Vector3] = []
	var seen := {}
	for p in seed_pts:
		var key := "%.3f,%.3f" % [p.x, p.z]
		if seen.has(key):
			continue
		seen[key] = true
		p.y = sample_world_height(p)
		out.append(p)
	return out


func apply_brush(world_pos: Vector3, raise: bool, delta: float = 1.0 / 60.0) -> void:
	var res := map.heightmap_resolution
	var centers := expand_height_indices(world_to_height_index(world_pos))
	var radius_cells := maxi(1, int(round(brush_radius * float(res - 1) / float(map.width))))
	var dt := clampf(delta, 0.0, 0.05)
	var strength := brush_strength * dt
	if not raise:
		strength = -strength
	var radius_sq := float(radius_cells * radius_cells)
	var dirty := Rect2i()
	var has_dirty := false

	for center in centers:
		for oy in range(-radius_cells, radius_cells + 1):
			for ox in range(-radius_cells, radius_cells + 1):
				var dist_sq := float(ox * ox + oy * oy)
				if dist_sq > radius_sq:
					continue
				var dist := sqrt(dist_sq)
				var falloff := 1.0 - (dist / float(radius_cells))
				falloff *= falloff
				var x := center.x + ox
				var y := center.y + oy
				var h := get_height(x, y) + strength * falloff
				set_height(x, y, h)
		var stamp_dirty := _brush_dirty_rect(center, radius_cells)
		dirty = stamp_dirty if not has_dirty else dirty.merge(stamp_dirty)
		has_dirty = true
	mark_dirty()
	heights_changed.emit(dirty)


func apply_smooth(world_pos: Vector3, delta: float = 1.0 / 60.0) -> void:
	var res := map.heightmap_resolution
	var centers := expand_height_indices(world_to_height_index(world_pos))
	var radius_cells := maxi(1, int(round(brush_radius * float(res - 1) / float(map.width))))
	var radius_sq := float(radius_cells * radius_cells)
	var dt := clampf(delta, 0.0, 0.05)
	var amount := clampf(brush_strength * dt * 2.5, 0.0, 1.0)
	var scratch := {}
	var dirty := Rect2i()
	var has_dirty := false
	for center in centers:
		for oy in range(-radius_cells, radius_cells + 1):
			for ox in range(-radius_cells, radius_cells + 1):
				var dist_sq := float(ox * ox + oy * oy)
				if dist_sq > radius_sq:
					continue
				var x := center.x + ox
				var y := center.y + oy
				var sum := 0.0
				var count := 0
				for ny in range(-1, 2):
					for nx in range(-1, 2):
						sum += get_height(x + nx, y + ny)
						count += 1
				var avg := sum / float(count)
				var falloff := 1.0 - (sqrt(dist_sq) / float(radius_cells))
				var h := lerpf(get_height(x, y), avg, amount * falloff)
				scratch[Vector2i(x, y)] = h
		var stamp_dirty := _brush_dirty_rect(center, radius_cells)
		dirty = stamp_dirty if not has_dirty else dirty.merge(stamp_dirty)
		has_dirty = true
	for key in scratch.keys():
		set_height(key.x, key.y, scratch[key])
	mark_dirty()
	heights_changed.emit(dirty)


func apply_splat_paint(world_pos: Vector3, delta: float = 1.0 / 60.0) -> void:
	ensure_splat_images()
	var res := splat_resolution()
	var centers := expand_splat_indices(world_to_splat_index(world_pos))
	var radius_cells := maxi(1, int(round(brush_radius * float(res - 1) / float(map.width))))
	var radius_f := float(maxi(radius_cells, 1))
	var radius_sq := radius_f * radius_f
	var dt := clampf(delta, 0.0, 0.05)
	# Texture paint should feel snappy: ~full layer in ~0.15s at default strength.
	var amount := clampf(brush_strength * dt * 16.0, 0.0, 1.0)
	var layer := clampi(paint_layer, 0, 7)
	var dirty := Rect2i()
	var has_dirty := false

	for center in centers:
		for oy in range(-radius_cells, radius_cells + 1):
			for ox in range(-radius_cells, radius_cells + 1):
				var dist_sq := float(ox * ox + oy * oy)
				if dist_sq > radius_sq:
					continue
				# Gentler than height brushes: wider hot core, soft edge.
				var t := 1.0 - (sqrt(dist_sq) / radius_f)
				var falloff := pow(t, 1.2)
				var x := center.x + ox
				var y := center.y + oy
				if x < 0 or y < 0 or x >= res or y >= res:
					continue
				_paint_splat_pixel(x, y, layer, amount * falloff)
		var stamp_dirty := Rect2i(
			maxi(center.x - radius_cells, 0),
			maxi(center.y - radius_cells, 0),
			0,
			0
		)
		var x1 := mini(center.x + radius_cells, res - 1)
		var y1 := mini(center.y + radius_cells, res - 1)
		stamp_dirty.size = Vector2i(x1 - stamp_dirty.position.x + 1, y1 - stamp_dirty.position.y + 1)
		dirty = stamp_dirty if not has_dirty else dirty.merge(stamp_dirty)
		has_dirty = true
	mark_dirty()
	splat_changed.emit(dirty)


func _paint_splat_pixel(x: int, y: int, layer: int, paint: float) -> void:
	if paint <= 0.0001:
		return
	_record_splat_before(x, y)
	var c14 := splat_1_4.get_pixel(x, y)
	var c58 := splat_5_8.get_pixel(x, y)
	var w := PackedFloat32Array([c14.r, c14.g, c14.b, c14.a, c58.r, c58.g, c58.b, c58.a])
	# Pull toward selected layer and reduce others so weights stay normalized.
	for i in 8:
		if i == layer:
			w[i] = lerpf(w[i], 1.0, paint)
		else:
			w[i] = lerpf(w[i], 0.0, paint)
	var sum := 0.0
	for i in 8:
		sum += w[i]
	if sum < 0.0001:
		w[layer] = 1.0
		sum = 1.0
	for i in 8:
		w[i] /= sum
	splat_1_4.set_pixel(x, y, Color(w[0], w[1], w[2], w[3]))
	splat_5_8.set_pixel(x, y, Color(w[4], w[5], w[6], w[7]))


func apply_set_height(world_pos: Vector3, delta: float = 1.0 / 60.0) -> void:
	var res := map.heightmap_resolution
	var centers := expand_height_indices(world_to_height_index(world_pos))
	var radius_cells := maxi(1, int(round(brush_radius * float(res - 1) / float(map.width))))
	var radius_sq := float(radius_cells * radius_cells)
	var dt := clampf(delta, 0.0, 0.05)
	# Strong pull toward absolute height so the brush feels like "set to X".
	var amount := clampf(brush_strength * dt * 4.0, 0.0, 1.0)
	var map_h := maxf(float(map.height), 0.001)
	var target_norm := clampf(set_height_world / map_h, 0.0, 1.0)
	var dirty := Rect2i()
	var has_dirty := false
	for center in centers:
		for oy in range(-radius_cells, radius_cells + 1):
			for ox in range(-radius_cells, radius_cells + 1):
				var dist_sq := float(ox * ox + oy * oy)
				if dist_sq > radius_sq:
					continue
				var falloff := 1.0 - (sqrt(dist_sq) / float(radius_cells))
				falloff *= falloff
				var x := center.x + ox
				var y := center.y + oy
				var h := lerpf(get_height(x, y), target_norm, amount * falloff)
				set_height(x, y, h)
		var stamp_dirty := _brush_dirty_rect(center, radius_cells)
		dirty = stamp_dirty if not has_dirty else dirty.merge(stamp_dirty)
		has_dirty = true
	mark_dirty()
	heights_changed.emit(dirty)


func add_marker(marker_type: String, world_pos: Vector3) -> void:
	var owned := begin_stroke("Marker")
	map._ensure_core_markers()
	_stroke_touched_markers = true
	var points := expand_brush_world_points(world_pos)
	for p in points:
		_add_marker_at(marker_type, p)
	if marker_type == SanMapData.MARKER_SPAWN:
		map.sync_armies_with_spawns()
	mark_dirty()
	markers_changed.emit()
	if owned:
		end_stroke()


func _add_marker_at(marker_type: String, world_pos: Vector3) -> void:
	var bucket: Dictionary = map.markers[marker_type]
	var transforms: Dictionary = bucket.get("transforms", {})
	var id := _next_marker_id(marker_type, transforms)
	var y := sample_world_height(world_pos)
	var rotation := {"x": 0.0, "y": 0.0, "z": 0.0, "w": 1.0}
	# Official alloy markers use a 90° X rotation quaternion.
	if marker_type == SanMapData.MARKER_ALLOYS:
		rotation = {"x": 0.7071068, "y": 0.0, "z": 0.0, "w": 0.7071068}
	transforms[id] = {
		"position": {"x": world_pos.x, "y": y, "z": world_pos.z},
		"rotation": rotation,
		"scale": {"x": 1.0, "y": 1.0, "z": 1.0},
	}
	bucket["transforms"] = transforms
	map.markers[marker_type] = bucket


func _next_marker_id(marker_type: String, transforms: Dictionary) -> String:
	if marker_type == SanMapData.MARKER_SPAWN:
		var idx := 1
		while transforms.has("Army_%d" % idx) or map.armies.has("Army_%d" % idx):
			idx += 1
		return "Army_%d" % idx
	if marker_type == SanMapData.MARKER_ALLOYS:
		if not transforms.has("AlloyMarker"):
			return "AlloyMarker"
		var idx := 2
		while transforms.has("AlloyMarker_%d" % idx):
			idx += 1
		return "AlloyMarker_%d" % idx
	return "%s_%d" % [marker_type, Time.get_ticks_msec()]


func clear_markers(marker_type: String) -> void:
	if not map.markers.has(marker_type):
		return
	var transforms: Dictionary = map.markers[marker_type].get("transforms", {})
	if transforms.is_empty():
		return
	var owned := begin_stroke("Clear markers")
	_stroke_touched_markers = true
	map.markers[marker_type]["transforms"] = {}
	if marker_type == SanMapData.MARKER_SPAWN:
		map.armies.clear()
	mark_dirty()
	markers_changed.emit()
	if owned:
		end_stroke()


func set_prop_blueprint(path: String) -> void:
	var p := path.strip_edges().replace("\\", "/")
	if p.is_empty() or p == prop_blueprint:
		return
	prop_blueprint = p
	prop_settings_changed.emit()


func set_prop_scale(value: float) -> void:
	var v := clampf(value, 0.1, 8.0)
	if is_equal_approx(v, prop_scale):
		return
	prop_scale = v
	prop_settings_changed.emit()


func set_prop_random_yaw(enabled: bool) -> void:
	if prop_random_yaw == enabled:
		return
	prop_random_yaw = enabled
	prop_settings_changed.emit()


func prop_instance_count() -> int:
	var total := 0
	for group in map.props:
		if typeof(group) != TYPE_DICTIONARY:
			continue
		total += (group.get("transforms", []) as Array).size()
	return total


func add_prop(world_pos: Vector3) -> void:
	if prop_blueprint.strip_edges().is_empty():
		return
	var owned := begin_stroke("Place prop")
	_stroke_touched_props = true
	var points := expand_brush_world_points(world_pos)
	for p in points:
		_add_prop_at(prop_blueprint, p, prop_scale, prop_random_yaw)
	mark_dirty()
	props_changed.emit()
	if owned:
		end_stroke()


func _add_prop_at(blueprint_path: String, world_pos: Vector3, scale: float, random_yaw: bool) -> void:
	var group := _find_or_create_prop_group(blueprint_path)
	var transforms: Array = group.get("transforms", [])
	var y := sample_world_height(world_pos)
	var yaw := randf() * TAU if random_yaw else 0.0
	var q := Quaternion(Vector3.UP, yaw)
	transforms.append({
		"position": {"x": world_pos.x, "y": y, "z": world_pos.z},
		"rotation": {"x": q.x, "y": q.y, "z": q.z, "w": q.w},
		"scale": {"x": scale, "y": scale, "z": scale},
	})
	group["transforms"] = transforms


func _find_or_create_prop_group(blueprint_path: String) -> Dictionary:
	for group in map.props:
		if typeof(group) != TYPE_DICTIONARY:
			continue
		if str(group.get("blueprintPath", "")) == blueprint_path:
			return group
	var created := {
		"blueprintPath": blueprint_path,
		"transforms": [],
	}
	map.props.append(created)
	return created


func clear_props() -> void:
	if map.props.is_empty():
		return
	var owned := begin_stroke("Clear props")
	_stroke_touched_props = true
	map.props = []
	mark_dirty()
	props_changed.emit()
	if owned:
		end_stroke()


func clear_props_of_type(blueprint_path: String) -> void:
	var bp := blueprint_path.strip_edges()
	if bp.is_empty():
		return
	var kept: Array = []
	var removed := false
	for group in map.props:
		if typeof(group) != TYPE_DICTIONARY:
			continue
		if str(group.get("blueprintPath", "")) == bp:
			removed = true
			continue
		kept.append(group)
	if not removed:
		return
	var owned := begin_stroke("Clear prop type")
	_stroke_touched_props = true
	map.props = kept
	mark_dirty()
	props_changed.emit()
	if owned:
		end_stroke()


func load_from_path(path: String) -> Error:
	var loaded := SanMapIO.load_sanmap(path)
	if loaded == null:
		return ERR_FILE_CANT_OPEN
	clear_history()
	map = loaded
	map.ensure_playable_materials()
	var hm_path := SanMapIO.find_heightmap_path(path)
	if hm_path != "":
		heights = SanMapIO.load_heightmap_raw(hm_path, map.heightmap_resolution)
		# MapUtils: heightmap stays texture-space; convert world marker Z → editor Z if needed.
		SanMapIO.apply_coordinate_space_for_editor(heights, map)
	else:
		_alloc_flat_heights(0.0)
		push_warning("No Textures/heightmap.raw found; using flat terrain.")
	var splats := SanMapIO.load_package_splat_images(path, map)
	splat_1_4 = splats[0]
	splat_5_8 = splats[1]
	var tints := SanMapIO.load_package_tint_images(path, map)
	tint_colors = tints[0]
	tint_geometry = tints[1]
	terrain_preset_id = _guess_preset_id()
	PropCatalog.merge_from_map(map)
	current_path = path
	_set_dirty(false)
	map_changed.emit()
	heights_changed.emit(Rect2i())
	splat_changed.emit(Rect2i())
	materials_changed.emit()
	markers_changed.emit()
	props_changed.emit()
	return OK


func _guess_preset_id() -> String:
	if map.stratum_layers.is_empty():
		return "highlands"
	var first: Dictionary = map.stratum_layers[0]
	var path := str((first.get("albedo", {}) as Dictionary).get("path", "")).to_lower()
	if path.contains("whitedesert") or path.contains("desert_"):
		return "desert"
	if path.contains("/winter/") or path.contains("uewpai") or path.contains("ice_"):
		return "frozen"
	if path.contains("evergreen"):
		return "evergreen"
	if path.contains("grass02") and map.stratum_layers.size() > 4:
		var l4: Dictionary = map.stratum_layers[4] if map.stratum_layers.size() > 4 else {}
		var p4 := str((l4.get("albedo", {}) as Dictionary).get("path", "")).to_lower()
		if p4.contains("gravel"):
			return "forest"
	if path.contains("grass07") and map.stratum_layers.size() > 2:
		var l2: Dictionary = map.stratum_layers[2] if map.stratum_layers.size() > 2 else {}
		var p2 := str((l2.get("albedo", {}) as Dictionary).get("path", "")).to_lower()
		if p2.contains("heather"):
			return "tropical"
	return "highlands"


func save_to_path(path: String) -> Error:
	if _stroke_open:
		end_stroke()
	var sanmap_path := SanMapIO.ensure_package_sanmap_path(path, map.name)
	var package_name := sanmap_path.get_file().get_basename()
	if map.name.strip_edges().is_empty() or map.name.strip_edges().to_lower() == "untitled":
		map.name = package_name
	map.ensure_playable_materials()
	ensure_splat_images()
	ensure_tint_images()
	var err := SanMapIO.save_map_package(
		sanmap_path, map, heights, splat_1_4, splat_5_8, tint_colors, tint_geometry
	)
	if err != OK:
		return err
	err = SanMapIO.save_preview_png(sanmap_path, build_package_preview_image())
	if err != OK:
		push_warning("Map saved, but preview.png failed: %s" % error_string(err))
	current_path = sanmap_path
	_set_dirty(false)
	map_changed.emit()
	return OK


func build_preview_image(heightmap_only: bool) -> Image:
	var res := map.heightmap_resolution
	var img := Image.create(res, res, false, Image.FORMAT_RGBA8)
	var water_norm := 0.0
	if map.has_water and map.height > 0:
		water_norm = clampf(map.water_level / float(map.height), 0.0, 1.0)
	for y in res:
		for x in res:
			var h := get_height(x, y)
			var c: Color
			if heightmap_only:
				c = Color(h, h, h, 1.0)
			else:
				if map.has_water and h <= water_norm:
					var t := clampf(h / maxf(water_norm, 0.0001), 0.0, 1.0)
					c = Color(0.08, 0.22 + t * 0.2, 0.38 + t * 0.25, 1.0)
				else:
					c = Color(
						0.18 + h * 0.35,
						0.34 + h * 0.4,
						0.16 + h * 0.12,
						1.0
					)
			img.set_pixel(x, y, c)
	return img


func build_package_preview_image() -> Image:
	ensure_splat_images()
	return MapPackagePreview.build(map, heights, splat_1_4, splat_5_8)


## Start a grouped undoable edit. Returns true if this call opened the stroke.
func begin_stroke(label: String = "Edit") -> bool:
	if _history_applying:
		return false
	if _stroke_open:
		return false
	_stroke_open = true
	_stroke_label = label
	_stroke_before_heights.clear()
	_stroke_before_splat14.clear()
	_stroke_before_splat58.clear()
	_stroke_markers_before = map.markers.duplicate(true)
	_stroke_armies_before = map.armies.duplicate(true)
	_stroke_props_before = map.props.duplicate(true)
	_stroke_meta_before = _capture_meta_snapshot()
	_stroke_touched_heights = false
	_stroke_touched_splat = false
	_stroke_touched_markers = false
	_stroke_touched_props = false
	_stroke_touched_meta = false
	return true


func end_stroke() -> void:
	if not _stroke_open or _history_applying:
		_stroke_open = false
		return
	_stroke_open = false
	if not (
		_stroke_touched_heights
		or _stroke_touched_splat
		or _stroke_touched_markers
		or _stroke_touched_props
		or _stroke_touched_meta
	):
		return

	var entry := {
		"label": _stroke_label,
		"heights": _pack_height_delta(true),
		"splat": _pack_splat_delta(true),
		"markers_before": _stroke_markers_before if _stroke_touched_markers else {},
		"markers_after": map.markers.duplicate(true) if _stroke_touched_markers else {},
		"armies_before": _stroke_armies_before if _stroke_touched_markers else {},
		"armies_after": map.armies.duplicate(true) if _stroke_touched_markers else {},
		"props_before": _stroke_props_before.duplicate(true) if _stroke_touched_props else [],
		"props_after": map.props.duplicate(true) if _stroke_touched_props else [],
		"meta_before": _stroke_meta_before if _stroke_touched_meta else {},
		"meta_after": _capture_meta_snapshot() if _stroke_touched_meta else {},
		"touched_markers": _stroke_touched_markers,
		"touched_props": _stroke_touched_props,
		"touched_meta": _stroke_touched_meta,
	}
	_undo_stack.append(entry)
	while _undo_stack.size() > MAX_HISTORY:
		_undo_stack.pop_front()
	_redo_stack.clear()
	history_changed.emit()


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo() -> bool:
	if _stroke_open:
		end_stroke()
	if _undo_stack.is_empty():
		return false
	var entry: Dictionary = _undo_stack.pop_back()
	_apply_history_entry(entry, true)
	_redo_stack.append(entry)
	history_changed.emit()
	return true


func redo() -> bool:
	if _stroke_open:
		end_stroke()
	if _redo_stack.is_empty():
		return false
	var entry: Dictionary = _redo_stack.pop_back()
	_apply_history_entry(entry, false)
	_undo_stack.append(entry)
	history_changed.emit()
	return true


func clear_history() -> void:
	_stroke_open = false
	_undo_stack.clear()
	_redo_stack.clear()
	_stroke_before_heights.clear()
	_stroke_before_splat14.clear()
	_stroke_before_splat58.clear()
	history_changed.emit()


func _record_height_before(idx: int) -> void:
	if not _stroke_open or _history_applying:
		return
	if _stroke_before_heights.has(idx):
		return
	_stroke_before_heights[idx] = heights[idx]
	_stroke_touched_heights = true


func _record_splat_before(x: int, y: int) -> void:
	if not _stroke_open or _history_applying:
		return
	var key := "%d,%d" % [x, y]
	if _stroke_before_splat14.has(key):
		return
	_stroke_before_splat14[key] = splat_1_4.get_pixel(x, y)
	_stroke_before_splat58[key] = splat_5_8.get_pixel(x, y)
	_stroke_touched_splat = true


func _capture_meta_snapshot() -> Dictionary:
	return {
		"has_water": map.has_water,
		"water_level": map.water_level,
		"terrain_preset_id": terrain_preset_id,
		"stratum_layers": map.stratum_layers.duplicate(true),
		"skybox": map.skybox.duplicate(true),
		"playable_area": map.get_playable_area(),
		"fade_distance": map.fade_distance,
		"fade_start_distance": map.fade_start_distance,
	}


func _pack_height_delta(capture_after: bool) -> Dictionary:
	if not _stroke_touched_heights or _stroke_before_heights.is_empty():
		return {}
	var indices := PackedInt32Array()
	var before := PackedFloat32Array()
	var after := PackedFloat32Array()
	for idx in _stroke_before_heights.keys():
		var i := int(idx)
		indices.append(i)
		before.append(float(_stroke_before_heights[idx]))
		if capture_after and i >= 0 and i < heights.size():
			after.append(heights[i])
		else:
			after.append(float(_stroke_before_heights[idx]))
	return {"indices": indices, "before": before, "after": after}


func _pack_splat_delta(capture_after: bool) -> Dictionary:
	if not _stroke_touched_splat or _stroke_before_splat14.is_empty():
		return {}
	var xs := PackedInt32Array()
	var ys := PackedInt32Array()
	var before14: Array = []
	var after14: Array = []
	var before58: Array = []
	var after58: Array = []
	for key in _stroke_before_splat14.keys():
		var parts := str(key).split(",")
		var x := int(parts[0])
		var y := int(parts[1])
		xs.append(x)
		ys.append(y)
		before14.append(_stroke_before_splat14[key])
		before58.append(_stroke_before_splat58[key])
		if capture_after:
			after14.append(splat_1_4.get_pixel(x, y))
			after58.append(splat_5_8.get_pixel(x, y))
		else:
			after14.append(_stroke_before_splat14[key])
			after58.append(_stroke_before_splat58[key])
	return {
		"x": xs,
		"y": ys,
		"before14": before14,
		"after14": after14,
		"before58": before58,
		"after58": after58,
	}


func _apply_history_entry(entry: Dictionary, to_before: bool) -> void:
	_history_applying = true
	var heights_delta: Dictionary = entry.get("heights", {})
	var splat_delta: Dictionary = entry.get("splat", {})
	var height_dirty := Rect2i()
	var has_height_dirty := false
	if not heights_delta.is_empty():
		var indices: PackedInt32Array = heights_delta.get("indices", PackedInt32Array())
		var values: PackedFloat32Array = (
			heights_delta.get("before", PackedFloat32Array())
			if to_before
			else heights_delta.get("after", PackedFloat32Array())
		)
		var res := map.heightmap_resolution
		for i in indices.size():
			var idx := indices[i]
			if idx < 0 or idx >= heights.size() or i >= values.size():
				continue
			heights[idx] = values[i]
			var x := idx % res
			var y := int(idx / float(res))
			var cell := Rect2i(x, y, 1, 1)
			height_dirty = cell if not has_height_dirty else height_dirty.merge(cell)
			has_height_dirty = true

	var splat_dirty := Rect2i()
	var has_splat_dirty := false
	if not splat_delta.is_empty():
		ensure_splat_images()
		var xs: PackedInt32Array = splat_delta.get("x", PackedInt32Array())
		var ys: PackedInt32Array = splat_delta.get("y", PackedInt32Array())
		var c14: Array = splat_delta.get("before14", []) if to_before else splat_delta.get("after14", [])
		var c58: Array = splat_delta.get("before58", []) if to_before else splat_delta.get("after58", [])
		for i in xs.size():
			var x := xs[i]
			var y := ys[i]
			if i < c14.size():
				splat_1_4.set_pixel(x, y, c14[i])
			if i < c58.size():
				splat_5_8.set_pixel(x, y, c58[i])
			var cell := Rect2i(x, y, 1, 1)
			splat_dirty = cell if not has_splat_dirty else splat_dirty.merge(cell)
			has_splat_dirty = true

	if bool(entry.get("touched_markers", false)):
		map.markers = (
			(entry.get("markers_before", {}) as Dictionary).duplicate(true)
			if to_before
			else (entry.get("markers_after", {}) as Dictionary).duplicate(true)
		)
		map.armies = (
			(entry.get("armies_before", {}) as Dictionary).duplicate(true)
			if to_before
			else (entry.get("armies_after", {}) as Dictionary).duplicate(true)
		)
		markers_changed.emit()

	if bool(entry.get("touched_props", false)):
		map.props = (
			(entry.get("props_before", []) as Array).duplicate(true)
			if to_before
			else (entry.get("props_after", []) as Array).duplicate(true)
		)
		props_changed.emit()

	if bool(entry.get("touched_meta", false)):
		var meta: Dictionary = (
			entry.get("meta_before", {}) if to_before else entry.get("meta_after", {})
		)
		map.has_water = bool(meta.get("has_water", map.has_water))
		map.water_level = float(meta.get("water_level", map.water_level))
		terrain_preset_id = str(meta.get("terrain_preset_id", terrain_preset_id))
		map.stratum_layers = (meta.get("stratum_layers", map.stratum_layers) as Array).duplicate(true)
		map.skybox = (meta.get("skybox", map.skybox) as Dictionary).duplicate(true)
		if meta.has("playable_area"):
			var pa: Dictionary = meta["playable_area"]
			map.set_playable_area(
				float(pa.get("x", 0.0)),
				float(pa.get("y", 0.0)),
				float(pa.get("width", float(map.width))),
				float(pa.get("height", float(map.length)))
			)
		map.fade_distance = float(meta.get("fade_distance", map.fade_distance))
		map.fade_start_distance = float(meta.get("fade_start_distance", map.fade_start_distance))
		map.ensure_playable_materials()
		materials_changed.emit()
		map_changed.emit()

	if has_height_dirty:
		heights_changed.emit(height_dirty)
	if has_splat_dirty:
		splat_changed.emit(splat_dirty)
	mark_dirty()
	_history_applying = false
