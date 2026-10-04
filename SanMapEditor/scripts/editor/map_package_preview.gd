class_name MapPackagePreview
extends RefCounted
## Builds official-style top-down `preview.png` images for .sanmap packages.


const MAX_PREVIEW_SIZE := 1024
const FALLBACK_LAYER_COLORS: Array[Color] = [
	Color(0.42, 0.48, 0.28),
	Color(0.55, 0.52, 0.38),
	Color(0.48, 0.46, 0.44),
	Color(0.62, 0.58, 0.48),
	Color(0.36, 0.40, 0.30),
	Color(0.58, 0.50, 0.36),
	Color(0.40, 0.38, 0.36),
	Color(0.70, 0.68, 0.62),
]

const SPAWN_COLORS: Array[Color] = [
	Color(0.22, 0.78, 0.28),
	Color(0.86, 0.18, 0.16),
	Color(0.92, 0.86, 0.62),
	Color(0.16, 0.28, 0.72),
	Color(0.95, 0.55, 0.16),
	Color(0.35, 0.78, 0.95),
	Color(0.72, 0.48, 0.88),
	Color(0.95, 0.95, 0.95),
	Color(0.55, 0.35, 0.18),
	Color(0.20, 0.65, 0.55),
	Color(0.85, 0.35, 0.65),
	Color(0.45, 0.45, 0.48),
]


static func preview_size_for_map(map: SanMapData) -> int:
	var dim := maxi(map.width, map.length)
	return clampi(dim, 64, MAX_PREVIEW_SIZE)


static func build(
	map: SanMapData,
	heights: PackedFloat32Array,
	splat_1_4: Image,
	splat_5_8: Image
) -> Image:
	var size := preview_size_for_map(map)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var hm_res := map.heightmap_resolution
	if hm_res < 2 or heights.size() < hm_res * hm_res:
		img.fill(Color(0.15, 0.16, 0.14, 1.0))
		return img

	ensure_splat_ready(map, splat_1_4, splat_5_8)
	var layer_albedos := _load_layer_albedos(map)
	var water_norm := 0.0
	if map.has_water and map.height > 0:
		water_norm = clampf(map.water_level / float(map.height), 0.0, 1.0)

	var splat_res := splat_1_4.get_width() if splat_1_4 != null else 0
	for py in size:
		for px in size:
			var u := float(px) / float(maxi(size - 1, 1))
			var v := float(py) / float(maxi(size - 1, 1))
			var hx := int(round(u * float(hm_res - 1)))
			var hy := int(round(v * float(hm_res - 1)))
			var h := heights[hy * hm_res + hx]
			var c: Color
			if map.has_water and h <= water_norm:
				var t := clampf(h / maxf(water_norm, 0.0001), 0.0, 1.0)
				c = Color(0.07, 0.18 + t * 0.16, 0.30 + t * 0.22, 1.0)
			else:
				c = _sample_terrain_color(
					map, splat_1_4, splat_5_8, splat_res, layer_albedos, u, v, h
				)
				var slope := _slope_shade(heights, hm_res, hx, hy)
				c = Color(c.r * slope, c.g * slope, c.b * slope, 1.0)
				# Gentle height lift so ridges read in the thumbnail.
				var lift := 0.85 + h * 0.35
				c = Color(
					clampf(c.r * lift, 0.0, 1.0),
					clampf(c.g * lift, 0.0, 1.0),
					clampf(c.b * lift, 0.0, 1.0),
					1.0
				)
			img.set_pixel(px, py, c)

	_draw_alloy_markers(img, map)
	_draw_spawn_markers(img, map)
	return img


static func ensure_splat_ready(map: SanMapData, splat_1_4: Image, splat_5_8: Image) -> void:
	if splat_1_4 == null or splat_5_8 == null:
		return
	var res := SanMapIO.splat_resolution_for_map(map)
	if splat_1_4.get_width() != res or splat_1_4.get_height() != res:
		splat_1_4.resize(res, res, Image.INTERPOLATE_BILINEAR)
	if splat_5_8.get_width() != res or splat_5_8.get_height() != res:
		splat_5_8.resize(res, res, Image.INTERPOLATE_BILINEAR)


static func _load_layer_albedos(map: SanMapData) -> Array:
	var out: Array = []
	out.resize(8)
	for i in 8:
		out[i] = null
		if i >= map.stratum_layers.size():
			continue
		var layer: Dictionary = map.stratum_layers[i]
		var path := str((layer.get("albedo", {}) as Dictionary).get("path", ""))
		if path.is_empty():
			continue
		var tex := EnvironmentAssets.load_texture(path, 128)
		if tex != null:
			out[i] = tex.get_image()
	return out


static func _sample_terrain_color(
	map: SanMapData,
	splat_1_4: Image,
	splat_5_8: Image,
	splat_res: int,
	layer_albedos: Array,
	u: float,
	v: float,
	h: float
) -> Color:
	var weights := PackedFloat32Array([1, 0, 0, 0, 0, 0, 0, 0])
	if splat_1_4 != null and splat_5_8 != null and splat_res > 1:
		var sx := clampi(int(round(u * float(splat_res - 1))), 0, splat_res - 1)
		var sy := clampi(int(round(v * float(splat_res - 1))), 0, splat_res - 1)
		var c14 := splat_1_4.get_pixel(sx, sy)
		var c58 := splat_5_8.get_pixel(sx, sy)
		weights = PackedFloat32Array([c14.r, c14.g, c14.b, c14.a, c58.r, c58.g, c58.b, c58.a])

	var color := Color(0, 0, 0, 1)
	var wsum := 0.0
	for i in 8:
		var w: float = weights[i]
		if w <= 0.0001:
			continue
		var sample := _layer_color(map, layer_albedos, i, u, v)
		color.r += sample.r * w
		color.g += sample.g * w
		color.b += sample.b * w
		wsum += w
	if wsum < 0.0001:
		return FALLBACK_LAYER_COLORS[0].lerp(Color(0.55, 0.55, 0.52), h)
	color.r /= wsum
	color.g /= wsum
	color.b /= wsum
	return color


static func _layer_color(map: SanMapData, layer_albedos: Array, index: int, u: float, v: float) -> Color:
	var img: Image = layer_albedos[index] if index < layer_albedos.size() else null
	if img != null and img.get_width() > 0 and img.get_height() > 0:
		var tile := 8.0
		if index < map.stratum_layers.size():
			var layer: Dictionary = map.stratum_layers[index]
			var ts: Dictionary = layer.get("tileSize", {})
			tile = maxf(float(ts.get("x", 8.0)), 1.0)
		var world_x := u * float(map.width)
		var world_z := v * float(map.length)
		var tu := fposmod(world_x / tile, 1.0)
		var tv := fposmod(world_z / tile, 1.0)
		var px := clampi(int(tu * float(img.get_width() - 1)), 0, img.get_width() - 1)
		var py := clampi(int(tv * float(img.get_height() - 1)), 0, img.get_height() - 1)
		return img.get_pixel(px, py)
	return FALLBACK_LAYER_COLORS[clampi(index, 0, FALLBACK_LAYER_COLORS.size() - 1)]


static func _slope_shade(heights: PackedFloat32Array, res: int, x: int, y: int) -> float:
	var x0 := maxi(x - 1, 0)
	var x1 := mini(x + 1, res - 1)
	var y0 := maxi(y - 1, 0)
	var y1 := mini(y + 1, res - 1)
	var dx := heights[y * res + x1] - heights[y * res + x0]
	var dy := heights[y1 * res + x] - heights[y0 * res + x]
	var slope := sqrt(dx * dx + dy * dy) * float(res) * 0.35
	# Soft directional light from top-left.
	var light := clampf(0.72 + (-dx + dy) * float(res) * 0.18 - slope * 0.25, 0.35, 1.15)
	return light


static func _draw_spawn_markers(img: Image, map: SanMapData) -> void:
	var bucket: Dictionary = map.markers.get(SanMapData.MARKER_SPAWN, {})
	var transforms: Dictionary = bucket.get("transforms", {})
	var size := img.get_width()
	var radius := maxi(int(round(float(size) * 0.018)), 6)
	var ids: Array = transforms.keys()
	ids.sort_custom(func(a, b): return _spawn_sort_key(str(a)) < _spawn_sort_key(str(b)))
	var index := 0
	for id in ids:
		var t: Dictionary = transforms[id]
		var pos: Dictionary = t.get("position", {})
		var u := float(pos.get("x", 0.0)) / float(maxi(map.width, 1))
		var v := float(pos.get("z", 0.0)) / float(maxi(map.length, 1))
		var cx := clampi(int(round(u * float(size - 1))), 0, size - 1)
		var cy := clampi(int(round(v * float(size - 1))), 0, size - 1)
		var color := SPAWN_COLORS[index % SPAWN_COLORS.size()]
		_fill_circle(img, cx, cy, radius + 1, Color(0, 0, 0, 0.75))
		_fill_circle(img, cx, cy, radius, color)
		_stroke_circle(img, cx, cy, radius, Color(1, 1, 1, 0.9))
		_draw_number(img, cx, cy, index + 1, Color(1, 1, 1, 1))
		index += 1


static func _draw_alloy_markers(img: Image, map: SanMapData) -> void:
	var bucket: Dictionary = map.markers.get(SanMapData.MARKER_ALLOYS, {})
	var transforms: Dictionary = bucket.get("transforms", {})
	var size := img.get_width()
	var radius := maxi(int(round(float(size) * 0.010)), 3)
	for id in transforms.keys():
		var t: Dictionary = transforms[id]
		var pos: Dictionary = t.get("position", {})
		var u := float(pos.get("x", 0.0)) / float(maxi(map.width, 1))
		var v := float(pos.get("z", 0.0)) / float(maxi(map.length, 1))
		var cx := clampi(int(round(u * float(size - 1))), 0, size - 1)
		var cy := clampi(int(round(v * float(size - 1))), 0, size - 1)
		_fill_diamond(img, cx, cy, radius + 1, Color(0, 0, 0, 0.7))
		_fill_diamond(img, cx, cy, radius, Color(1.0, 0.85, 0.2, 1.0))


static func _spawn_sort_key(id: String) -> int:
	if id.begins_with("Army_"):
		return int(id.substr(5))
	return 9999


static func _fill_circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var r2 := radius * radius
	var w := img.get_width()
	var h := img.get_height()
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, _blend(img.get_pixel(x, y), color))


static func _stroke_circle(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var steps := maxi(radius * 8, 24)
	for i in steps:
		var a := TAU * float(i) / float(steps)
		var x := clampi(cx + int(round(cos(a) * float(radius))), 0, w - 1)
		var y := clampi(cy + int(round(sin(a) * float(radius))), 0, h - 1)
		img.set_pixel(x, y, color)


static func _fill_diamond(img: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if x < 0 or y < 0 or x >= w or y >= h:
				continue
			if absi(x - cx) + absi(y - cy) <= radius:
				img.set_pixel(x, y, _blend(img.get_pixel(x, y), color))


static func _draw_number(img: Image, cx: int, cy: int, number: int, color: Color) -> void:
	## Tiny 3x5 bitmap digits centered on the spawn badge.
	var glyphs := {
		1: ["010", "110", "010", "010", "111"],
		2: ["111", "001", "111", "100", "111"],
		3: ["111", "001", "111", "001", "111"],
		4: ["101", "101", "111", "001", "001"],
		5: ["111", "100", "111", "001", "111"],
		6: ["111", "100", "111", "101", "111"],
		7: ["111", "001", "010", "010", "010"],
		8: ["111", "101", "111", "101", "111"],
		9: ["111", "101", "111", "001", "111"],
		0: ["111", "101", "101", "101", "111"],
	}
	var text := str(number)
	var scale := 1 if img.get_width() < 700 else 2
	var glyph_w := 3 * scale
	var glyph_h := 5 * scale
	var gap := scale
	var total_w := text.length() * glyph_w + maxi(text.length() - 1, 0) * gap
	var ox := cx - total_w / 2
	var oy := cy - glyph_h / 2
	for ci in text.length():
		var ch := int(text.substr(ci, 1))
		var rows: Array = glyphs.get(ch, glyphs[0])
		for row_i in rows.size():
			var row: String = rows[row_i]
			for col_i in row.length():
				if row[col_i] != "1":
					continue
				for sy in scale:
					for sx in scale:
						var x := ox + ci * (glyph_w + gap) + col_i * scale + sx
						var y := oy + row_i * scale + sy
						if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
							continue
						img.set_pixel(x, y, color)


static func _blend(dst: Color, src: Color) -> Color:
	var a := src.a
	return Color(
		lerpf(dst.r, src.r, a),
		lerpf(dst.g, src.g, a),
		lerpf(dst.b, src.b, a),
		1.0
	)
