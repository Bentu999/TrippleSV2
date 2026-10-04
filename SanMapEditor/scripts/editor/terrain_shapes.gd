class_name TerrainShapes
extends RefCounted
## Pure heightmap geometry helpers for line / circle / arc / plateau / ramp / pathing.
##
## Height modes (combine shapes with Zielhöhe):
##   SET   – stamp absolute world height
##   RAISE – raise existing terrain toward Zielhöhe (never lower)
##   LOWER – lower existing terrain toward Zielhöhe (never raise)
##
## Line / arc / ramp stamp a flat corridor (driveable road cross-section),
## not a soft circular brush.


enum HeightMode {
	SET,
	RAISE,
	LOWER,
}


static func world_cell_size(map: SanMapData) -> float:
	var res := maxi(map.heightmap_resolution, 2)
	return float(map.width) / float(res - 1)


static func target_norm(map: SanMapData, world_height: float) -> float:
	return clampf(world_height / maxf(float(map.height), 0.001), 0.0, 1.0)


static func combine_height(current: float, target: float, mode: int, strength: float = 1.0) -> float:
	var s := clampf(strength, 0.0, 1.0)
	match mode:
		HeightMode.RAISE:
			if current >= target:
				return current
			return lerpf(current, target, s)
		HeightMode.LOWER:
			if current <= target:
				return current
			return lerpf(current, target, s)
		_:
			return lerpf(current, target, s)


static func apply_line(
	state: Node,
	a: Vector3,
	b: Vector3,
	width_m: float,
	world_height: float,
	height_mode: int = HeightMode.SET
) -> Rect2i:
	var target := target_norm(state.map, world_height)
	return _stamp_corridor(
		state,
		[a, b],
		width_m,
		func(_t: float, _world: Vector3) -> float: return target,
		height_mode,
		0.85
	)


static func apply_circle(
	state: Node,
	center: Vector3,
	radius_m: float,
	world_height: float,
	height_mode: int = HeightMode.SET
) -> Rect2i:
	var map: SanMapData = state.map
	var res: int = map.heightmap_resolution
	var cell := world_cell_size(map)
	var radius_cells := maxi(1, int(ceil(radius_m / maxf(cell, 0.001))))
	var c: Vector2i = state.world_to_height_index(center)
	var target := target_norm(map, world_height)
	var radius_sq := float(radius_cells * radius_cells)
	var dirty := Rect2i()
	var has_dirty := false
	for oy in range(-radius_cells, radius_cells + 1):
		for ox in range(-radius_cells, radius_cells + 1):
			var dist_sq := float(ox * ox + oy * oy)
			if dist_sq > radius_sq:
				continue
			var x := c.x + ox
			var y := c.y + oy
			if x < 0 or y < 0 or x >= res or y >= res:
				continue
			# Soft outer rim (~15% of radius); interior is flat at target height.
			var dist := sqrt(dist_sq)
			var edge := 1.0
			if radius_cells > 0:
				edge = 1.0 - clampf((dist / float(radius_cells) - 0.85) / 0.15, 0.0, 1.0)
			var cur: float = state.get_height(x, y)
			state.set_height(x, y, combine_height(cur, target, height_mode, edge))
			var cell_rect := Rect2i(x, y, 1, 1)
			dirty = cell_rect if not has_dirty else dirty.merge(cell_rect)
			has_dirty = true
	return dirty if has_dirty else Rect2i()


static func apply_arc(
	state: Node,
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	width_m: float,
	world_height: float,
	height_mode: int = HeightMode.SET
) -> Rect2i:
	var circle := circumcircle_xz(p0, p1, p2)
	if circle.is_empty():
		return apply_line(state, p0, p2, width_m, world_height, height_mode)
	var center: Vector3 = circle.center
	var radius: float = circle.radius
	var a0 := atan2(p0.z - center.z, p0.x - center.x)
	var a1 := atan2(p1.z - center.z, p1.x - center.x)
	var a2 := atan2(p2.z - center.z, p2.x - center.x)
	var sweep := arc_sweep_through(a0, a1, a2)
	var steps := clampi(int(ceil(absf(sweep) * radius / maxf(world_cell_size(state.map), 0.25))), 8, 512)
	var points: Array[Vector3] = []
	for i in steps + 1:
		var t := float(i) / float(steps)
		var ang := a0 + sweep * t
		points.append(Vector3(center.x + cos(ang) * radius, 0.0, center.z + sin(ang) * radius))
	var target := target_norm(state.map, world_height)
	return _stamp_corridor(
		state,
		points,
		width_m,
		func(_t: float, _world: Vector3) -> float: return target,
		height_mode,
		0.85
	)


static func apply_plateau(
	state: Node,
	a: Vector3,
	b: Vector3,
	world_height: float,
	height_mode: int = HeightMode.SET
) -> Rect2i:
	var map: SanMapData = state.map
	var res: int = map.heightmap_resolution
	var ia: Vector2i = state.world_to_height_index(a)
	var ib: Vector2i = state.world_to_height_index(b)
	var x0 := mini(ia.x, ib.x)
	var y0 := mini(ia.y, ib.y)
	var x1 := maxi(ia.x, ib.x)
	var y1 := maxi(ia.y, ib.y)
	var target := target_norm(map, world_height)
	var dirty := Rect2i()
	var has_dirty := false
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if x < 0 or y < 0 or x >= res or y >= res:
				continue
			var cur: float = state.get_height(x, y)
			state.set_height(x, y, combine_height(cur, target, height_mode, 1.0))
			var cell_rect := Rect2i(x, y, 1, 1)
			dirty = cell_rect if not has_dirty else dirty.merge(cell_rect)
			has_dirty = true
	return dirty if has_dirty else Rect2i()


## Finished ramp: start at terrain under A, run exactly `length_m` in direction
## A→B, linearly from start height to `end_world_height`. `angle_deg` is the
## design slope (UI-linked with length/height); stamp uses length + end height.
## Cross-section is a flat driveable corridor (width_m = Pinselradius).
static func apply_ramp(
	state: Node,
	a: Vector3,
	b: Vector3,
	width_m: float,
	length_m: float,
	_angle_deg: float,
	end_world_height: float
) -> Rect2i:
	var start_h: float = state.sample_world_height(a)
	var end_h := end_world_height
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if flat.length() < 0.001:
		return Rect2i()
	var dir := flat.normalized()
	var ramp_len := maxf(length_m, 0.5)
	var end_pos := a + dir * ramp_len
	var map_h := maxf(float(state.map.height), 0.001)
	var height_fn := func(t: float, _world: Vector3) -> float:
		var world_h := lerpf(start_h, end_h, clampf(t, 0.0, 1.0))
		return clampf(world_h / map_h, 0.0, 1.0)
	return _stamp_corridor(state, [a, end_pos], width_m, height_fn, HeightMode.SET, 1.0)


static func slope_angle_deg_at(state: Node, x: int, y: int) -> float:
	var map: SanMapData = state.map
	var res: int = map.heightmap_resolution
	if x <= 0 or y <= 0 or x >= res - 1 or y >= res - 1:
		return 0.0
	var cell := world_cell_size(map)
	var map_h := float(map.height)
	var hx0: float = state.get_height(x - 1, y)
	var hx1: float = state.get_height(x + 1, y)
	var hy0: float = state.get_height(x, y - 1)
	var hy1: float = state.get_height(x, y + 1)
	var dhx := ((hx1 - hx0) * map_h) / (2.0 * cell)
	var dhy := ((hy1 - hy0) * map_h) / (2.0 * cell)
	return rad_to_deg(atan(sqrt(dhx * dhx + dhy * dhy)))


static func build_slope_overlay(state: Node, max_angle_deg: float) -> Image:
	var res: int = state.map.heightmap_resolution
	var img := Image.create(res, res, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var limit := clampf(max_angle_deg, 1.0, 89.0)
	for y in range(1, res - 1):
		for x in range(1, res - 1):
			var ang := slope_angle_deg_at(state, x, y)
			if ang <= limit:
				continue
			var t := clampf((ang - limit) / maxf(90.0 - limit, 1.0), 0.15, 1.0)
			img.set_pixel(x, y, Color(1.0, 0.15, 0.1, 0.25 + t * 0.55))
	return img


static func edge_slope_deg(state: Node, ax: int, ay: int, bx: int, by: int) -> float:
	var cell := world_cell_size(state.map)
	var map_h := float(state.map.height)
	var ha: float = state.get_height(ax, ay) * map_h
	var hb: float = state.get_height(bx, by) * map_h
	var dx := float(bx - ax) * cell
	var dy := float(by - ay) * cell
	var dist := sqrt(dx * dx + dy * dy)
	if dist < 0.0001:
		return 0.0
	return rad_to_deg(atan(absf(hb - ha) / dist))


static func find_walkable_path(state: Node, start: Vector3, goal: Vector3, max_angle_deg: float) -> Array[Vector3]:
	var res: int = state.map.heightmap_resolution
	var s: Vector2i = state.world_to_height_index(start)
	var g: Vector2i = state.world_to_height_index(goal)
	var limit := clampf(max_angle_deg, 1.0, 89.0)
	if s == g:
		return [start, goal]

	var open: Array[Vector2i] = [s]
	var came_from := {}
	var g_score := {}
	var f_score := {}
	var key0 := _key(s)
	came_from[key0] = Vector2i(-1, -1)
	g_score[key0] = 0.0
	f_score[key0] = _heuristic(s, g)

	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	var found := false
	var guard := 0
	var max_expand := res * res
	while not open.is_empty() and guard < max_expand:
		guard += 1
		var best_i := 0
		var best_f := INF
		for i in open.size():
			var fk := float(f_score.get(_key(open[i]), INF))
			if fk < best_f:
				best_f = fk
				best_i = i
		var current: Vector2i = open[best_i]
		open.remove_at(best_i)
		if current == g:
			found = true
			break
		var ck := _key(current)
		for d in dirs:
			var n := current + d
			if n.x < 0 or n.y < 0 or n.x >= res or n.y >= res:
				continue
			var slope := edge_slope_deg(state, current.x, current.y, n.x, n.y)
			if slope > limit:
				continue
			var step := 1.41421356 if d.x != 0 and d.y != 0 else 1.0
			var nk := _key(n)
			var tentative := float(g_score[ck]) + step
			if tentative >= float(g_score.get(nk, INF)):
				continue
			came_from[nk] = current
			g_score[nk] = tentative
			f_score[nk] = tentative + _heuristic(n, g)
			var already := false
			for o in open:
				if o == n:
					already = true
					break
			if not already:
				open.append(n)

	if not found:
		return []

	var cells: Array[Vector2i] = []
	var cur := g
	while cur.x >= 0:
		cells.append(cur)
		var prev: Vector2i = came_from.get(_key(cur), Vector2i(-1, -1))
		if prev.x < 0:
			break
		cur = prev
	cells.reverse()

	var out: Array[Vector3] = []
	var map_w := float(state.map.width)
	var map_l := float(state.map.length)
	for cell in cells:
		var u := float(cell.x) / float(res - 1)
		var v := float(cell.y) / float(res - 1)
		var p := Vector3(u * map_w, 0.0, v * map_l)
		p.y = state.sample_world_height(p)
		out.append(p)
	return out


static func circumcircle_xz(a: Vector3, b: Vector3, c: Vector3) -> Dictionary:
	var ax := a.x
	var ay := a.z
	var bx := b.x
	var by := b.z
	var cx := c.x
	var cy := c.z
	var d := 2.0 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
	if absf(d) < 0.0001:
		return {}
	var a2 := ax * ax + ay * ay
	var b2 := bx * bx + by * by
	var c2 := cx * cx + cy * cy
	var ux := (a2 * (by - cy) + b2 * (cy - ay) + c2 * (ay - by)) / d
	var uy := (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d
	var center := Vector3(ux, 0.0, uy)
	var radius := Vector2(ax - ux, ay - uy).length()
	if radius < 0.001:
		return {}
	return {"center": center, "radius": radius}


static func ramp_preview_length(start_h: float, end_h: float, angle_deg: float) -> float:
	var angle := clampf(angle_deg, 0.5, 80.0)
	return absf(end_h - start_h) / maxf(tan(deg_to_rad(angle)), 0.0001)


## Stamp a flat road corridor along a polyline.
## Cells within half_w * flat_ratio get full strength (driveable deck).
## Outer shoulder soft-blends to surrounding terrain when flat_ratio < 1.
static func _stamp_corridor(
	state: Node,
	points: Array,
	width_m: float,
	height_fn: Callable,
	height_mode: int = HeightMode.SET,
	flat_ratio: float = 0.85
) -> Rect2i:
	if points.size() < 2:
		return Rect2i()
	var map: SanMapData = state.map
	var res: int = map.heightmap_resolution
	var cell := world_cell_size(map)
	var half_w := maxf(width_m * 0.5, cell * 0.5)
	var flat_half := half_w * clampf(flat_ratio, 0.5, 1.0)
	var map_w := float(map.width)
	var map_l := float(map.length)

	var total_len := 0.0
	var seg_lens: Array[float] = []
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for i in range(points.size()):
		var p: Vector3 = points[i]
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)
		if i < points.size() - 1:
			var p1: Vector3 = points[i + 1]
			var L := Vector2(p1.x - p.x, p1.z - p.z).length()
			seg_lens.append(L)
			total_len += L
	if total_len < 0.0001:
		return Rect2i()

	min_x -= half_w
	max_x += half_w
	min_z -= half_w
	max_z += half_w
	var ix0 := clampi(int(floor(min_x / map_w * float(res - 1))), 0, res - 1)
	var ix1 := clampi(int(ceil(max_x / map_w * float(res - 1))), 0, res - 1)
	var iy0 := clampi(int(floor(min_z / map_l * float(res - 1))), 0, res - 1)
	var iy1 := clampi(int(ceil(max_z / map_l * float(res - 1))), 0, res - 1)

	var dirty := Rect2i()
	var has_dirty := false
	for y in range(iy0, iy1 + 1):
		for x in range(ix0, ix1 + 1):
			var wx := float(x) / float(res - 1) * map_w
			var wz := float(y) / float(res - 1) * map_l
			var closest := _closest_on_polyline(wx, wz, points, seg_lens, total_len)
			var perp: float = closest.dist
			if perp > half_w:
				continue
			var target_h := float(height_fn.call(closest.t, Vector3(wx, 0.0, wz)))
			var strength := 1.0
			if perp > flat_half and half_w > flat_half:
				strength = 1.0 - clampf((perp - flat_half) / (half_w - flat_half), 0.0, 1.0)
			if strength <= 0.001:
				continue
			var cur: float = state.get_height(x, y)
			state.set_height(x, y, combine_height(cur, target_h, height_mode, strength))
			var cell_rect := Rect2i(x, y, 1, 1)
			dirty = cell_rect if not has_dirty else dirty.merge(cell_rect)
			has_dirty = true
	return dirty if has_dirty else Rect2i()


static func _closest_on_polyline(
	wx: float,
	wz: float,
	points: Array,
	seg_lens: Array,
	total_len: float
) -> Dictionary:
	var best_dist := INF
	var best_t := 0.0
	var walked := 0.0
	for i in range(points.size() - 1):
		var p0: Vector3 = points[i]
		var p1: Vector3 = points[i + 1]
		var seg: float = seg_lens[i]
		var dx := p1.x - p0.x
		var dz := p1.z - p0.z
		var len_sq := dx * dx + dz * dz
		var u := 0.0
		if len_sq > 0.0000001:
			u = clampf(((wx - p0.x) * dx + (wz - p0.z) * dz) / len_sq, 0.0, 1.0)
		var cx := p0.x + dx * u
		var cz := p0.z + dz * u
		var dist := Vector2(wx - cx, wz - cz).length()
		if dist < best_dist:
			best_dist = dist
			best_t = (walked + seg * u) / total_len
		walked += seg
	return {"dist": best_dist, "t": best_t}


static func arc_sweep_through(a0: float, a_mid: float, a2: float) -> float:
	## Return signed sweep from a0 to a2 that passes through a_mid.
	var to_mid := _delta_angle(a0, a_mid)
	var to_end := _delta_angle(a0, a2)
	if signf(to_mid) == signf(to_end) or is_zero_approx(to_mid):
		if absf(to_end) < absf(to_mid):
			if to_end >= 0.0:
				to_end -= TAU
			else:
				to_end += TAU
		return to_end
	if to_end >= 0.0:
		to_end -= TAU
	else:
		to_end += TAU
	return to_end


static func _delta_angle(from: float, to: float) -> float:
	return fposmod(to - from + PI, TAU) - PI


static func _key(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]


static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx := float(a.x - b.x)
	var dy := float(a.y - b.y)
	return sqrt(dx * dx + dy * dy)
