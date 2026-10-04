extends Control
## Top-down 2D / heightmap view with sculpting and marker placement.

var _texture_rect: TextureRect
var _img_texture: ImageTexture
var _painting: bool = false
var _shaping: bool = false
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
	EditorState.props_changed.connect(queue_redraw)
	EditorState.view_changed.connect(_on_view_changed)
	EditorState.tool_changed.connect(queue_redraw)
	EditorState.mirror_changed.connect(queue_redraw)
	EditorState.measurement_changed.connect(queue_redraw)
	EditorState.shape_draft_changed.connect(queue_redraw)
	EditorState.pathing_changed.connect(queue_redraw)
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
	if _painting:
		EditorState.end_stroke()
		_painting = false
	_shaping = false
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
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			if EditorState.shape_draft_active:
				EditorState.clear_shape_draft()
				_shaping = false
				accept_event()
			elif EditorState.pathing_has_a:
				EditorState.clear_pathing_pick()
				accept_event()
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_cursor_uv = _local_to_uv(mm.position)
		if EditorState.active_tool == EditorState.Tool.MEASURE_HEIGHT:
			if _uv_valid(_cursor_uv):
				EditorState.set_live_measure(_uv_to_world(_cursor_uv), true)
			else:
				EditorState.set_live_measure(Vector3.ZERO, false)
		if EditorState.is_shape_tool():
			if _uv_valid(_cursor_uv):
				EditorState.update_shape_cursor(_uv_to_world(_cursor_uv), true)
			else:
				EditorState.update_shape_cursor(Vector3.ZERO, false)
		queue_redraw()
		if _painting:
			_paint_at_cursor(get_process_delta_time())
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if EditorState.shape_draft_active:
				EditorState.clear_shape_draft()
				_shaping = false
				accept_event()
			elif EditorState.pathing_has_a:
				EditorState.clear_pathing_pick()
				accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_cursor_uv = _local_to_uv(mb.position)
		if not mb.pressed:
			if _painting:
				EditorState.end_stroke()
			_painting = false
			if _shaping and EditorState.active_tool != EditorState.Tool.SHAPE_ARC:
				EditorState.commit_shape_draft_with_cursor()
			_shaping = false
			accept_event()
			return
		if not _uv_valid(_cursor_uv):
			return
		var world := _uv_to_world(_cursor_uv)
		if mb.shift_pressed and (
			EditorState.active_tool == EditorState.Tool.SET_HEIGHT
			or EditorState.is_shape_tool()
		):
			var sampled := EditorState.sample_world_height(world)
			if EditorState.active_tool == EditorState.Tool.SHAPE_RAMP:
				EditorState.set_ramp_end_height(sampled)
			else:
				EditorState.set_height_world = sampled
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
			EditorState.Tool.PLACE_PROP:
				EditorState.add_prop(world)
			EditorState.Tool.MEASURE_HEIGHT:
				EditorState.pin_measure(world)
				EditorState.set_height_world = EditorState.measure_pinned_height
				var canvas2 := find_parent_canvas()
				if canvas2 != null and canvas2.has_method("sync_set_height_from_state"):
					canvas2.sync_set_height_from_state()
			EditorState.Tool.PATHING:
				EditorState.pathing_click(world)
			EditorState.Tool.ORBIT:
				pass
			_:
				if EditorState.is_shape_tool():
					if EditorState.active_tool == EditorState.Tool.SHAPE_ARC:
						if not EditorState.shape_draft_active:
							EditorState.begin_shape_draft(world)
						else:
							EditorState.add_shape_draft_point(world)
					else:
						EditorState.begin_shape_draft(world)
						_shaping = true
				else:
					EditorState.begin_stroke(_stroke_label_for_tool(EditorState.active_tool))
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
	draw_rect(area_rect, Color(0.2, 0.85, 1.0, 0.12), true)
	draw_rect(area_rect, Color(0.25, 0.95, 1.0, 0.95), false, 2.5)

	_draw_markers(SanMapData.MARKER_SPAWN, Color(0.25, 0.95, 0.4), rect)
	_draw_markers(SanMapData.MARKER_ALLOYS, Color(1.0, 0.78, 0.2), rect)
	_draw_props(rect)
	_draw_pathing(rect)
	_draw_shape_draft(rect)

	if EditorState.measure_pinned:
		_draw_measure_marker(rect, EditorState.measure_pinned_pos, EditorState.measure_pinned_height, true)

	if _uv_valid(_cursor_uv):
		var world := _uv_to_world(_cursor_uv)
		if EditorState.active_tool == EditorState.Tool.MEASURE_HEIGHT:
			_draw_measure_marker(rect, world, EditorState.sample_world_height(world), false)
		elif EditorState.active_tool == EditorState.Tool.PATHING:
			_draw_measure_marker(rect, world, EditorState.sample_world_height(world), false)
		elif EditorState.is_shape_tool():
			var radius_px := maxf((EditorState.brush_radius / float(EditorState.map.width)) * rect.size.x, 4.0)
			var center := rect.position + Vector2(_cursor_uv.x * rect.size.x, _cursor_uv.y * rect.size.y)
			draw_arc(center, radius_px, 0.0, TAU, 48, Color(1.0, 0.85, 0.25, 0.7), 1.5)
		else:
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


func _world_to_draw(rect: Rect2, world: Vector3) -> Vector2:
	var uv := Vector2(world.x / float(EditorState.map.width), world.z / float(EditorState.map.length))
	return rect.position + Vector2(uv.x * rect.size.x, uv.y * rect.size.y)


func _draw_pathing(rect: Rect2) -> void:
	if EditorState.active_tool != EditorState.Tool.PATHING:
		return
	if EditorState.pathing_overlay != null:
		# Sparse red dots for blocked slope cells (full blit would be heavy each frame).
		var img := EditorState.pathing_overlay
		var res := img.get_width()
		var step := maxi(1, int(res / 128.0))
		for y in range(0, res, step):
			for x in range(0, res, step):
				var c := img.get_pixel(x, y)
				if c.a < 0.05:
					continue
				var p := rect.position + Vector2(
					(float(x) / float(res - 1)) * rect.size.x,
					(float(y) / float(res - 1)) * rect.size.y
				)
				draw_circle(p, 2.0, Color(1.0, 0.2, 0.12, c.a))
	if EditorState.pathing_has_a:
		draw_circle(_world_to_draw(rect, EditorState.pathing_pick_a), 5.0, Color(0.3, 0.95, 1.0, 1.0))
	if EditorState.pathing_path.size() >= 2:
		var col := Color(0.25, 1.0, 0.45, 0.95) if EditorState.pathing_path_ok else Color(1.0, 0.3, 0.2, 0.95)
		for i in range(EditorState.pathing_path.size() - 1):
			draw_line(
				_world_to_draw(rect, EditorState.pathing_path[i]),
				_world_to_draw(rect, EditorState.pathing_path[i + 1]),
				col,
				2.5
			)


func _draw_shape_draft(rect: Rect2) -> void:
	if not EditorState.is_shape_tool():
		return
	# Ramp: preview without requiring a click (cursor = start).
	if EditorState.active_tool == EditorState.Tool.SHAPE_RAMP:
		var start := Vector3.ZERO
		var aim := Vector3.ZERO
		if EditorState.shape_draft_active and not EditorState.shape_draft_points.is_empty():
			start = EditorState.shape_draft_points[0]
			if EditorState.shape_draft_has_cursor:
				aim = EditorState.shape_draft_cursor
			elif EditorState.shape_draft_points.size() >= 2:
				aim = EditorState.shape_draft_points[1]
			else:
				aim = start + EditorState.ramp_aim_dir
		elif _uv_valid(_cursor_uv):
			start = _uv_to_world(_cursor_uv)
			aim = start + EditorState.ramp_aim_dir
		else:
			return
		_draw_ramp_preview_2d(rect, start, aim)
		return

	if not EditorState.shape_draft_active:
		return
	var pts: Array[Vector3] = EditorState.shape_draft_points.duplicate()
	if EditorState.shape_draft_has_cursor:
		pts.append(EditorState.shape_draft_cursor)
	if pts.size() < 2:
		return
	var col := Color(1.0, 0.85, 0.25, 0.95)
	match EditorState.active_tool:
		EditorState.Tool.SHAPE_LINE:
			draw_line(_world_to_draw(rect, pts[0]), _world_to_draw(rect, pts[1]), col, 2.0)
		EditorState.Tool.SHAPE_CIRCLE:
			var c := _world_to_draw(rect, pts[0])
			var edge := _world_to_draw(rect, pts[1])
			draw_arc(c, c.distance_to(edge), 0.0, TAU, 64, col, 2.0)
		EditorState.Tool.SHAPE_PLATEAU:
			var a := _world_to_draw(rect, pts[0])
			var b := _world_to_draw(rect, pts[1])
			draw_rect(Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(b.x - a.x), absf(b.y - a.y))), col, false, 2.0)
		EditorState.Tool.SHAPE_ARC:
			if pts.size() >= 3:
				var circle := TerrainShapes.circumcircle_xz(pts[0], pts[1], pts[2])
				if circle.is_empty():
					draw_line(_world_to_draw(rect, pts[0]), _world_to_draw(rect, pts[2]), col, 2.0)
				else:
					var center: Vector3 = circle.center
					var radius: float = circle.radius
					var a0 := atan2(pts[0].z - center.z, pts[0].x - center.x)
					var a_mid := atan2(pts[1].z - center.z, pts[1].x - center.x)
					var a2 := atan2(pts[2].z - center.z, pts[2].x - center.x)
					var sweep := TerrainShapes.arc_sweep_through(a0, a_mid, a2)
					var steps := 48
					for i in steps:
						var t0 := float(i) / float(steps)
						var t1 := float(i + 1) / float(steps)
						var q0 := Vector3(center.x + cos(a0 + sweep * t0) * radius, 0.0, center.z + sin(a0 + sweep * t0) * radius)
						var q1 := Vector3(center.x + cos(a0 + sweep * t1) * radius, 0.0, center.z + sin(a0 + sweep * t1) * radius)
						draw_line(_world_to_draw(rect, q0), _world_to_draw(rect, q1), col, 2.0)
			else:
				draw_line(_world_to_draw(rect, pts[0]), _world_to_draw(rect, pts[1]), col, 2.0)


func _draw_ramp_preview_2d(rect: Rect2, start: Vector3, aim: Vector3) -> void:
	var col := Color(1.0, 0.85, 0.25, 0.95)
	var dir := Vector3(aim.x - start.x, 0.0, aim.z - start.z)
	if dir.length() < 0.001:
		dir = Vector3(0, 0, 1)
	else:
		dir = dir.normalized()
	var end_pt := start + dir * EditorState.ramp_length_m
	var half := maxf(EditorState.brush_radius * 0.5, 0.5)
	var side := Vector3(-dir.z, 0.0, dir.x) * half
	var a := _world_to_draw(rect, start)
	var b := _world_to_draw(rect, end_pt)
	var a_l := _world_to_draw(rect, start + side)
	var a_r := _world_to_draw(rect, start - side)
	var b_l := _world_to_draw(rect, end_pt + side)
	var b_r := _world_to_draw(rect, end_pt - side)
	draw_line(a_l, b_l, col, 2.0)
	draw_line(a_r, b_r, col, 2.0)
	draw_line(a_l, a_r, col, 2.0)
	draw_line(b_l, b_r, col, 2.0)
	draw_line(a, b, col, 2.0)
	var start_h := EditorState.sample_world_height(start)
	var end_h := EditorState.set_height_world
	var map_h := maxf(float(EditorState.map.height), 1.0)
	var rise_px := clampf(absf(end_h - start_h) / map_h, 0.0, 1.0) * minf(rect.size.x, rect.size.y) * 0.12
	var ab := b - a
	if ab.length() > 1.0:
		var n2 := Vector2(-ab.y, ab.x).normalized()
		var tip := b + n2 * rise_px * signf(end_h - start_h)
		draw_colored_polygon(PackedVector2Array([a, b, tip]), Color(1.0, 0.75, 0.2, 0.28))
		draw_line(a, b, Color(1.0, 0.55, 0.15, 0.95), 1.5)
		draw_line(b, tip, Color(1.0, 0.55, 0.15, 0.95), 1.5)
		draw_line(tip, a, Color(1.0, 0.55, 0.15, 0.95), 2.0)


func _draw_measure_marker(rect: Rect2, world: Vector3, height: float, pinned: bool) -> void:
	var uv := Vector2(world.x / float(EditorState.map.width), world.z / float(EditorState.map.length))
	var center := rect.position + Vector2(uv.x * rect.size.x, uv.y * rect.size.y)
	var color := Color(1.0, 0.45, 0.15, 1.0) if pinned else Color(0.35, 0.95, 1.0, 1.0)
	var arm := 10.0 if pinned else 8.0
	draw_line(center + Vector2(-arm, 0), center + Vector2(arm, 0), color, 2.0)
	draw_line(center + Vector2(0, -arm), center + Vector2(0, arm), color, 2.0)
	draw_arc(center, 6.0 if pinned else 5.0, 0.0, TAU, 24, color, 2.0)
	var norm := EditorState.measure_normalized(height)
	var label := "%.1f  (%.0f%%)" % [height, norm * 100.0]
	var font := ThemeDB.fallback_font
	var font_size := 14
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos := center + Vector2(10, -10)
	draw_rect(Rect2(text_pos + Vector2(-4, -text_size.y + 2), text_size + Vector2(8, 4)), Color(0.05, 0.07, 0.08, 0.78), true)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.95))


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


func _draw_props(rect: Rect2) -> void:
	## Cap draw count so official maps with tens of thousands of props stay interactive.
	const MAX_DRAW := 4000
	var drawn := 0
	var map_w := float(EditorState.map.width)
	var map_l := float(EditorState.map.length)
	if map_w <= 0.0 or map_l <= 0.0:
		return
	for group in EditorState.map.props:
		if typeof(group) != TYPE_DICTIONARY:
			continue
		var color := PropCatalog.color_for(str(group.get("blueprintPath", "")))
		var transforms: Array = group.get("transforms", [])
		for t in transforms:
			if drawn >= MAX_DRAW:
				return
			if typeof(t) != TYPE_DICTIONARY:
				continue
			var pos: Dictionary = t.get("position", {})
			var u := float(pos.get("x", 0.0)) / map_w
			var v := float(pos.get("z", 0.0)) / map_l
			var p := rect.position + Vector2(u * rect.size.x, v * rect.size.y)
			draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), color, true)
			drawn += 1


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
