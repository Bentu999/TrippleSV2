extends Control
## Top-down 2D / heightmap view with sculpting and marker placement.

var _texture_rect: TextureRect
var _img_texture: ImageTexture
var _painting: bool = false
var _cursor_uv: Vector2 = Vector2(-1, -1)
var _dirty: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_texture_rect = TextureRect.new()
	_texture_rect.name = "MapImage"
	_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_texture_rect)

	EditorState.map_changed.connect(_queue_refresh)
	EditorState.heights_changed.connect(_on_heights_changed)
	EditorState.markers_changed.connect(queue_redraw)
	EditorState.view_changed.connect(_on_view_changed)
	EditorState.tool_changed.connect(queue_redraw)
	EditorState.mirror_changed.connect(queue_redraw)
	_on_view_changed()
	_refresh_now()


func _on_heights_changed(_dirty_rect: Rect2i) -> void:
	_queue_refresh()


func _queue_refresh() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if visible and _dirty:
		_dirty = false
		_refresh_now()
	if visible and _painting:
		_paint_at_cursor(get_process_delta_time())


func _on_view_changed() -> void:
	visible = EditorState.is_flat_view()
	mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	_queue_refresh()
	queue_redraw()


func _refresh_now() -> void:
	if not EditorState.is_flat_view():
		return
	var heightmap_only := EditorState.view_mode == EditorState.ViewMode.VIEW_HEIGHTMAP
	var img := EditorState.build_preview_image(heightmap_only)
	if _img_texture == null:
		_img_texture = ImageTexture.create_from_image(img)
	else:
		_img_texture.set_image(img)
	_texture_rect.texture = _img_texture
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_cursor_uv = _local_to_uv(mm.position)
		queue_redraw()
		if _painting:
			_paint_at_cursor(get_process_delta_time())
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_cursor_uv = _local_to_uv(mb.position)
		if not mb.pressed:
			_painting = false
			accept_event()
			return
		if not _uv_valid(_cursor_uv):
			return
		var world := _uv_to_world(_cursor_uv)
		if mb.shift_pressed and EditorState.active_tool == EditorState.Tool.SET_HEIGHT:
			EditorState.set_height_world = EditorState.sample_world_height(world)
			var canvas := find_parent_canvas()
			if canvas != null and canvas.has_method("sync_set_height_from_state"):
				canvas.sync_set_height_from_state()
			accept_event()
			return
		match EditorState.active_tool:
			EditorState.Tool.MARKER_SPAWN:
				EditorState.add_marker(SanMapData.MARKER_SPAWN, world)
			EditorState.Tool.MARKER_ALLOYS:
				EditorState.add_marker(SanMapData.MARKER_ALLOYS, world)
			EditorState.Tool.ORBIT:
				pass
			_:
				_painting = true
				_paint_at_cursor(get_process_delta_time())
		accept_event()


func find_parent_canvas() -> Node:
	var n: Node = self
	while n != null:
		if n is CanvasLayer and n.has_method("sync_set_height_from_state"):
			return n
		n = n.get_parent()
	return null


func _paint_at_cursor(delta: float) -> void:
	if not _uv_valid(_cursor_uv):
		return
	var world := _uv_to_world(_cursor_uv)
	match EditorState.active_tool:
		EditorState.Tool.RAISE:
			EditorState.apply_brush(world, true, delta)
		EditorState.Tool.LOWER:
			EditorState.apply_brush(world, false, delta)
		EditorState.Tool.SMOOTH:
			EditorState.apply_smooth(world, delta)
		EditorState.Tool.SET_HEIGHT:
			EditorState.apply_set_height(world, delta)
		EditorState.Tool.PAINT_TEXTURE:
			EditorState.apply_splat_paint(world, delta)


func _draw() -> void:
	if not visible:
		return
	var rect := _image_draw_rect()
	# Playable area
	var area: Dictionary = EditorState.map.areas.get(SanMapData.AREA_PLAYABLE, {})
	var ax := float(area.get("x", 0.0)) / float(EditorState.map.width)
	var ay := float(area.get("y", 0.0)) / float(EditorState.map.length)
	var aw := float(area.get("width", EditorState.map.width)) / float(EditorState.map.width)
	var ah := float(area.get("height", EditorState.map.length)) / float(EditorState.map.length)
	var area_rect := Rect2(
		rect.position + Vector2(ax * rect.size.x, ay * rect.size.y),
		Vector2(aw * rect.size.x, ah * rect.size.y)
	)
	draw_rect(area_rect, Color(0.25, 0.7, 1.0, 0.12), false, 2.0)

	_draw_markers(SanMapData.MARKER_SPAWN, Color(0.25, 0.95, 0.4), rect)
	_draw_markers(SanMapData.MARKER_ALLOYS, Color(1.0, 0.78, 0.2), rect)

	if _uv_valid(_cursor_uv):
		var world := _uv_to_world(_cursor_uv)
		var radius_px := maxf((EditorState.brush_radius / float(EditorState.map.width)) * rect.size.x, 4.0)
		var points := EditorState.expand_brush_world_points(world)
		for i in points.size():
			var p: Vector3 = points[i]
			var uv := Vector2(p.x / float(EditorState.map.width), p.z / float(EditorState.map.length))
			var center := rect.position + Vector2(uv.x * rect.size.x, uv.y * rect.size.y)
			if i == 0:
				draw_arc(center, radius_px, 0.0, TAU, 64, Color(1.0, 0.85, 0.25, 0.95), 2.5)
			else:
				# Mirrored brush ghosts — cyan, dashed look via double ring.
				draw_arc(center, radius_px, 0.0, TAU, 64, Color(0.35, 0.9, 1.0, 0.9), 2.5)
				draw_arc(center, maxf(radius_px - 3.0, 2.0), 0.0, TAU, 64, Color(0.35, 0.9, 1.0, 0.45), 1.5)
				draw_circle(center, 3.0, Color(0.35, 0.9, 1.0, 0.85))


func _draw_markers(marker_type: String, color: Color, rect: Rect2) -> void:
	var bucket: Dictionary = EditorState.map.markers.get(marker_type, {})
	var transforms: Dictionary = bucket.get("transforms", {})
	for id in transforms.keys():
		var t: Dictionary = transforms[id]
		var pos: Dictionary = t.get("position", {})
		var u := float(pos.get("x", 0.0)) / float(EditorState.map.width)
		var v := float(pos.get("z", 0.0)) / float(EditorState.map.length)
		var p := rect.position + Vector2(u * rect.size.x, v * rect.size.y)
		draw_circle(p, 5.0, color)
		draw_arc(p, 5.0, 0.0, TAU, 24, Color(0, 0, 0, 0.65), 1.5)


func _image_draw_rect() -> Rect2:
	# Match TextureRect STRETCH_KEEP_ASPECT_CENTERED (local coords).
	var bounds := size
	var local_full := Rect2(Vector2.ZERO, bounds)
	var tex := _texture_rect.texture
	if tex == null:
		return local_full
	var tex_size := Vector2(tex.get_width(), tex.get_height())
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return local_full
	var fit := minf(bounds.x / tex_size.x, bounds.y / tex_size.y)
	var draw_size := tex_size * fit
	var origin := (bounds - draw_size) * 0.5
	return Rect2(origin, draw_size)


func _local_to_uv(local_pos: Vector2) -> Vector2:
	var rect := _image_draw_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Vector2(-1, -1)
	var uv := (local_pos - rect.position) / rect.size
	return uv


func _uv_valid(uv: Vector2) -> bool:
	return uv.x >= 0.0 and uv.y >= 0.0 and uv.x <= 1.0 and uv.y <= 1.0


func _uv_to_world(uv: Vector2) -> Vector3:
	var x := uv.x * float(EditorState.map.width)
	var z := uv.y * float(EditorState.map.length)
	return Vector3(x, EditorState.sample_world_height(Vector3(x, 0.0, z)), z)
