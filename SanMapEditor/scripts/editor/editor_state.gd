extends Node
## Global editor state (autoload).

signal map_changed
## Emitted after height edits. Empty rect = full texture refresh.
signal heights_changed(dirty: Rect2i)
## Emitted after splat weight edits. Empty rect = full splat refresh.
signal splat_changed(dirty: Rect2i)
signal materials_changed
signal markers_changed
signal tool_changed
signal dirty_changed
signal view_changed
signal mirror_changed
signal paint_layer_changed

enum Tool {
	ORBIT,
	RAISE,
	LOWER,
	SMOOTH,
	SET_HEIGHT,
	PAINT_TEXTURE,
	MARKER_SPAWN,
	MARKER_ALLOYS,
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
## Absolute world-space target height for SET_HEIGHT brush.
var set_height_world: float = 16.0
## Live brush symmetry across map center (X and/or Z).
var mirror_x_enabled: bool = false
var mirror_z_enabled: bool = false


func _ready() -> void:
	new_map(256, 256, 128, 257)


func new_map(width: int, length: int, height: int, resolution: int) -> void:
	map = SanMapData.new()
	# Prefer official convention heightmapResolution = width + 1 when square.
	var hm_res := resolution
	if width == length and resolution <= 0:
		hm_res = width + 1
	map.resize(width, length, height, hm_res)
	TerrainPresets.apply(map, terrain_preset_id if not terrain_preset_id.is_empty() else "highlands")
	# Start flat so sculpting begins from a clean base.
	_alloc_flat_heights(0.0)
	_alloc_default_splats()
	current_path = ""
	_set_dirty(false)
	map_changed.emit()
	heights_changed.emit(Rect2i())
	splat_changed.emit(Rect2i())
	materials_changed.emit()
	markers_changed.emit()


func _alloc_flat_heights(value: float) -> void:
	var n := map.heightmap_resolution * map.heightmap_resolution
	heights.resize(n)
	heights.fill(value)


func _alloc_default_splats() -> void:
	var res := SanMapIO.splat_resolution_for_map(map)
	var pair := SanMapIO.make_default_splat_images(res)
	splat_1_4 = pair[0]
	splat_5_8 = pair[1]


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


func set_terrain_preset(preset_id: String) -> void:
	if preset_id.is_empty():
		return
	terrain_preset_id = preset_id
	TerrainPresets.apply(map, preset_id)
	map.ensure_playable_materials()
	mark_dirty()
	materials_changed.emit()
	map_changed.emit()


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
	active_tool = tool
	tool_changed.emit()


func set_view_mode(mode: ViewMode) -> void:
	if view_mode == mode:
		view_changed.emit()
		return
	view_mode = mode
	view_changed.emit()


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
	heights[y * res + x] = clampf(value, 0.0, 1.0)


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
	var radius_sq := float(radius_cells * radius_cells)
	var dt := clampf(delta, 0.0, 0.05)
	var amount := clampf(brush_strength * dt * 3.5, 0.0, 1.0)
	var layer := clampi(paint_layer, 0, 7)
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
	map._ensure_core_markers()
	var points := expand_brush_world_points(world_pos)
	for p in points:
		_add_marker_at(marker_type, p)
	if marker_type == SanMapData.MARKER_SPAWN:
		map.sync_armies_with_spawns()
	mark_dirty()
	markers_changed.emit()


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
	map.markers[marker_type]["transforms"] = {}
	if marker_type == SanMapData.MARKER_SPAWN:
		map.armies.clear()
	mark_dirty()
	markers_changed.emit()


func load_from_path(path: String) -> Error:
	var loaded := SanMapIO.load_sanmap(path)
	if loaded == null:
		return ERR_FILE_CANT_OPEN
	map = loaded
	map.ensure_playable_materials()
	var hm_path := SanMapIO.find_heightmap_path(path)
	if hm_path != "":
		heights = SanMapIO.load_heightmap_raw(hm_path, map.heightmap_resolution)
	else:
		_alloc_flat_heights(0.0)
		push_warning("No Textures/heightmap.raw found; using flat terrain.")
	var splats := SanMapIO.load_package_splat_images(path, map)
	splat_1_4 = splats[0]
	splat_5_8 = splats[1]
	terrain_preset_id = _guess_preset_id()
	current_path = path
	_set_dirty(false)
	map_changed.emit()
	heights_changed.emit(Rect2i())
	splat_changed.emit(Rect2i())
	materials_changed.emit()
	markers_changed.emit()
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
	var sanmap_path := SanMapIO.ensure_package_sanmap_path(path, map.name)
	var package_name := sanmap_path.get_file().get_basename()
	if map.name.strip_edges().is_empty() or map.name.strip_edges().to_lower() == "untitled":
		map.name = package_name
	map.ensure_playable_materials()
	ensure_splat_images()
	var err := SanMapIO.save_map_package(sanmap_path, map, heights, splat_1_4, splat_5_8)
	if err != OK:
		return err
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
