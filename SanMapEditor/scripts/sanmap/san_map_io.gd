class_name SanMapIO
extends RefCounted
## Sanctuary map package IO matching official layout:
##   MapName/
##     MapName.sanmap
##     preview.png
##     Textures/heightmap.raw
##     Textures/stratums_1_4.tga
##     Textures/stratums_5_8.tga
##     Textures/tint_colors.tga
##     Textures/tint_geometry.tga

static func _tga_footer() -> PackedByteArray:
	return PackedByteArray([
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
		0x54, 0x52, 0x55, 0x45, 0x56, 0x49, 0x53, 0x49,
		0x4F, 0x4E, 0x2D, 0x58, 0x46, 0x49, 0x4C, 0x45,
		0x2E, 0x00
	])


static func sanitize_map_name(name: String) -> String:
	var n := name.strip_edges()
	if n.is_empty():
		n = "Untitled"
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		n = n.replace(ch, "_")
	n = n.strip_edges()
	return n if not n.is_empty() else "Untitled"


## Resolve a Save-dialog path into MapName/MapName.sanmap.
## Existing packages (already MapName/MapName.sanmap, or legacy folder with
## sibling Textures/) are kept in place so reopen+save does not nest folders.
static func ensure_package_sanmap_path(path: String, map_name: String) -> String:
	var chosen := path.replace("\\", "/")
	if chosen.is_empty():
		chosen = sanitize_map_name(map_name) + ".sanmap"

	var parent := ""
	var base_name := ""
	if chosen.ends_with(".sanmap"):
		base_name = sanitize_map_name(chosen.get_file().get_basename())
		parent = chosen.get_base_dir()
	elif DirAccess.dir_exists_absolute(chosen):
		base_name = sanitize_map_name(map_name)
		parent = chosen
	else:
		base_name = sanitize_map_name(chosen.get_file())
		parent = chosen.get_base_dir()
		if parent.is_empty() or parent == ".":
			parent = chosen

	if parent.is_empty():
		parent = "."

	# Already MapName/MapName.sanmap
	if parent.get_file() == base_name:
		return parent.path_join(base_name + ".sanmap")

	var direct_sanmap := parent.path_join(base_name + ".sanmap")
	# Re-save / open-then-save: keep existing file in place (e.g. The_Forge).
	if FileAccess.file_exists(direct_sanmap):
		return direct_sanmap

	# New package: Parent/MapName/MapName.sanmap
	var package_dir := parent.path_join(base_name)
	return package_dir.path_join(base_name + ".sanmap")


static func ensure_package_dir(sanmap_path: String) -> Error:
	var dir_path := sanmap_path.get_base_dir()
	if dir_path.is_empty() or DirAccess.dir_exists_absolute(dir_path):
		return OK
	return DirAccess.make_dir_recursive_absolute(dir_path)


static func textures_dir(sanmap_path: String) -> String:
	return sanmap_path.get_base_dir().path_join("Textures")


static func heightmap_raw_path(sanmap_path: String) -> String:
	return textures_dir(sanmap_path).path_join("heightmap.raw")


static func preview_png_path(sanmap_path: String) -> String:
	return sanmap_path.get_base_dir().path_join("preview.png")


static func save_preview_png(sanmap_path: String, image: Image) -> Error:
	if image == null:
		return ERR_INVALID_PARAMETER
	var err := ensure_package_dir(sanmap_path)
	if err != OK:
		return err
	return image.save_png(preview_png_path(sanmap_path))


static func companion_heightmap_path(sanmap_path: String) -> String:
	## Legacy name kept for callers; official package uses Textures/heightmap.raw.
	return heightmap_raw_path(sanmap_path)


static func splat_resolution_for_map(map: SanMapData) -> int:
	## Official generated maps use splat size == heightmapResolution (e.g. 257/513/1025).
	return maxi(map.heightmap_resolution, 64)


static func tint_resolution_for_map(map: SanMapData) -> int:
	## Official generated maps use tint size == map width/length (e.g. 256/512/1024).
	return maxi(maxi(map.width, map.length), 64)


## Back-compat alias used by older callers.
static func texture_resolution_for_map(map: SanMapData) -> int:
	return splat_resolution_for_map(map)


static func neutral_tint_colors() -> Color:
	## Game uses ~127/127/127/127 as neutral tint. Alpha 0 punches terrain holes.
	return Color(127.0 / 255.0, 127.0 / 255.0, 127.0 / 255.0, 127.0 / 255.0)


static func neutral_tint_geometry() -> Color:
	## Neutral geometry/normal tint seen on official packages (BGRA ~ 255,127,127,255).
	return Color(127.0 / 255.0, 127.0 / 255.0, 1.0, 1.0)


static func load_sanmap(path: String) -> SanMapData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open sanmap: %s (%s)" % [path, FileAccess.get_open_error()])
		return null
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid sanmap JSON: %s" % path)
		return null
	return SanMapData.from_dict(parsed)


static func save_sanmap(path: String, map: SanMapData) -> Error:
	map.sync_armies_with_spawns()
	var export_dict := map.to_export_dict()
	# Use ordered writer — JSON.stringify alphabetizes Dictionary keys.
	var json := OrderedJson.stringify(export_dict, "  ")
	# Official maps use Windows CRLF.
	json = json.replace("\n", "\r\n")
	if not json.ends_with("\r\n"):
		json += "\r\n"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json)
	return OK


static func ensure_textures_dir(sanmap_path: String) -> Error:
	var dir_path := textures_dir(sanmap_path)
	if DirAccess.dir_exists_absolute(dir_path):
		return OK
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	return err


static func load_heightmap_raw(path: String, resolution: int) -> PackedFloat32Array:
	var bytes := FileAccess.get_file_as_bytes(path)
	var expected := resolution * resolution * 2
	var heights := PackedFloat32Array()
	heights.resize(resolution * resolution)
	if bytes.size() < expected:
		push_error("Heightmap too small: %s (need %d bytes, got %d)" % [path, expected, bytes.size()])
		heights.fill(0.0)
		return heights
	for i in resolution * resolution:
		var lo := int(bytes[i * 2])
		var hi := int(bytes[i * 2 + 1])
		var raw := lo | (hi << 8)
		heights[i] = float(raw) / 65535.0
	return heights


static func save_heightmap_raw(path: String, heights: PackedFloat32Array, resolution: int) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var count := resolution * resolution
	for i in count:
		var v := 0.0
		if i < heights.size():
			v = clampf(heights[i], 0.0, 1.0)
		var raw := clampi(int(round(v * 65535.0)), 0, 65535)
		file.store_8(raw & 0xFF)
		file.store_8((raw >> 8) & 0xFF)
	return OK


## Back-compat aliases.
static func load_heightmap_r16(path: String, resolution: int) -> PackedFloat32Array:
	return load_heightmap_raw(path, resolution)


static func save_heightmap_r16(path: String, heights: PackedFloat32Array, resolution: int) -> Error:
	return save_heightmap_raw(path, heights, resolution)


static func splat_path_1_4(sanmap_path: String) -> String:
	return textures_dir(sanmap_path).path_join("stratums_1_4.tga")


static func splat_path_5_8(sanmap_path: String) -> String:
	return textures_dir(sanmap_path).path_join("stratums_5_8.tga")


static func make_default_splat_images(resolution: int) -> Array:
	## Returns [splat_1_4, splat_5_8] with base weight on stratum 0.
	var img14 := EnvironmentAssets.make_base_splat_image(resolution, 0)
	var img58 := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	img58.fill(Color(0, 0, 0, 0))
	return [img14, img58]


static func make_default_tint_images(resolution: int) -> Array:
	## Returns [tint_colors, tint_geometry] with game-neutral fills.
	var colors := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	colors.fill(neutral_tint_colors())
	var geometry := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	geometry.fill(neutral_tint_geometry())
	return [colors, geometry]


static func tint_path_colors(sanmap_path: String) -> String:
	return textures_dir(sanmap_path).path_join("tint_colors.tga")


static func tint_path_geometry(sanmap_path: String) -> String:
	return textures_dir(sanmap_path).path_join("tint_geometry.tga")


static func load_package_tint_images(sanmap_path: String, map: SanMapData) -> Array:
	var res := tint_resolution_for_map(map)
	var defaults := make_default_tint_images(res)
	if sanmap_path.is_empty():
		return defaults
	var colors := load_rgba_tga_image(tint_path_colors(sanmap_path))
	var geometry := load_rgba_tga_image(tint_path_geometry(sanmap_path))
	if colors == null:
		colors = defaults[0]
	elif colors.get_width() != res or colors.get_height() != res:
		colors.resize(res, res, Image.INTERPOLATE_BILINEAR)
	if geometry == null:
		geometry = defaults[1]
	elif geometry.get_width() != res or geometry.get_height() != res:
		geometry.resize(res, res, Image.INTERPOLATE_BILINEAR)
	return [colors, geometry]


static func load_rgba_tga_image(path: String) -> Image:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_warning("Failed to load TGA: %s (%s)" % [path, error_string(err)])
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


static func load_package_splat_images(sanmap_path: String, map: SanMapData) -> Array:
	var res := splat_resolution_for_map(map)
	var defaults := make_default_splat_images(res)
	if sanmap_path.is_empty():
		return defaults
	var img14 := load_rgba_tga_image(splat_path_1_4(sanmap_path))
	var img58 := load_rgba_tga_image(splat_path_5_8(sanmap_path))
	if img14 == null:
		img14 = defaults[0]
	elif img14.get_width() != res or img14.get_height() != res:
		img14.resize(res, res, Image.INTERPOLATE_BILINEAR)
	if img58 == null:
		img58 = defaults[1]
	elif img58.get_width() != res or img58.get_height() != res:
		img58.resize(res, res, Image.INTERPOLATE_BILINEAR)
	return [img14, img58]


static func _tga_needs_rewrite(path: String, expected_res: int, require_nonzero_alpha: bool) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var img := load_rgba_tga_image(path)
	if img == null:
		return true
	if img.get_width() != expected_res or img.get_height() != expected_res:
		return true
	if not require_nonzero_alpha:
		return false
	# All-zero alpha = terrain holes everywhere in the game.
	var w := img.get_width()
	var h := img.get_height()
	# Spot-check corners + center; rewrite if they look like our old broken defaults.
	var samples := [
		img.get_pixel(0, 0),
		img.get_pixel(w - 1, 0),
		img.get_pixel(0, h - 1),
		img.get_pixel(w - 1, h - 1),
		img.get_pixel(w >> 1, h >> 1),
	]
	for c in samples:
		if c.a > 0.001:
			return false
	return true


static func save_package_textures(
	sanmap_path: String,
	map: SanMapData,
	splat_1_4: Image = null,
	splat_5_8: Image = null,
	tint_colors: Image = null,
	tint_geometry: Image = null
) -> Error:
	var err := ensure_textures_dir(sanmap_path)
	if err != OK:
		return err
	var splat_res := splat_resolution_for_map(map)
	var tint_res := tint_resolution_for_map(map)
	var tex_dir := textures_dir(sanmap_path)

	var full_14 := tex_dir.path_join("stratums_1_4.tga")
	if splat_1_4 != null:
		var img14 := splat_1_4
		if img14.get_width() != splat_res or img14.get_height() != splat_res:
			img14 = img14.duplicate()
			img14.resize(splat_res, splat_res, Image.INTERPOLATE_BILINEAR)
		err = write_image_rgba_tga(full_14, img14)
		if err != OK:
			return err
	elif not FileAccess.file_exists(full_14) or _tga_needs_rewrite(full_14, splat_res, false):
		# Base weight on stratum 0 (R channel in BGRA TGA layout used by the game).
		err = write_rgba_tga(full_14, splat_res, Color(1, 0, 0, 0))
		if err != OK:
			return err

	var full_58 := tex_dir.path_join("stratums_5_8.tga")
	if splat_5_8 != null:
		var img58 := splat_5_8
		if img58.get_width() != splat_res or img58.get_height() != splat_res:
			img58 = img58.duplicate()
			img58.resize(splat_res, splat_res, Image.INTERPOLATE_BILINEAR)
		err = write_image_rgba_tga(full_58, img58)
		if err != OK:
			return err
	elif not FileAccess.file_exists(full_58) or _tga_needs_rewrite(full_58, splat_res, false):
		err = write_rgba_tga(full_58, splat_res, Color(0, 0, 0, 0))
		if err != OK:
			return err

	var full_tint := tex_dir.path_join("tint_colors.tga")
	if tint_colors != null:
		var img_tc := tint_colors
		if img_tc.get_width() != tint_res or img_tc.get_height() != tint_res:
			img_tc = img_tc.duplicate()
			img_tc.resize(tint_res, tint_res, Image.INTERPOLATE_BILINEAR)
		err = write_image_rgba_tga(full_tint, img_tc)
		if err != OK:
			return err
	elif _tga_needs_rewrite(full_tint, tint_res, true):
		err = write_rgba_tga(full_tint, tint_res, neutral_tint_colors())
		if err != OK:
			return err

	var full_geo := tex_dir.path_join("tint_geometry.tga")
	if tint_geometry != null:
		var img_tg := tint_geometry
		if img_tg.get_width() != tint_res or img_tg.get_height() != tint_res:
			img_tg = img_tg.duplicate()
			img_tg.resize(tint_res, tint_res, Image.INTERPOLATE_BILINEAR)
		err = write_image_rgba_tga(full_geo, img_tg)
		if err != OK:
			return err
	elif _tga_needs_rewrite(full_geo, tint_res, true):
		err = write_rgba_tga(full_geo, tint_res, neutral_tint_geometry())
		if err != OK:
			return err
	return OK


static func write_rgba_tga(path: String, resolution: int, fill: Color) -> Error:
	var img := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return write_image_rgba_tga(path, img)


static func write_image_rgba_tga(path: String, image: Image) -> Error:
	if image == null:
		return ERR_INVALID_PARAMETER
	var img := image
	if img.get_format() != Image.FORMAT_RGBA8:
		img = image.duplicate()
		img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	# Match official generated maps: uncompressed BGRA32, top-left origin, no footer.
	# Descriptor 0x28 = 8 alpha bits + top-left origin bit.
	file.store_8(0) # id length
	file.store_8(0) # no color map
	file.store_8(2) # uncompressed true-color
	file.store_16(0) # color map origin
	file.store_16(0) # color map length
	file.store_8(0) # color map depth
	file.store_16(0) # x origin
	file.store_16(0) # y origin
	file.store_16(w)
	file.store_16(h)
	file.store_8(32) # bpp
	file.store_8(0x28) # alpha bits + top-left
	for y in h:
		var row := PackedByteArray()
		row.resize(w * 4)
		for x in w:
			var c := img.get_pixel(x, y)
			var o := x * 4
			row[o] = clampi(int(round(c.b * 255.0)), 0, 255)
			row[o + 1] = clampi(int(round(c.g * 255.0)), 0, 255)
			row[o + 2] = clampi(int(round(c.r * 255.0)), 0, 255)
			row[o + 3] = clampi(int(round(c.a * 255.0)), 0, 255)
		file.store_buffer(row)
	return OK


static func write_empty_rgba_tga(path: String, resolution: int, _with_footer: bool = false) -> Error:
	return write_rgba_tga(path, resolution, Color(0, 0, 0, 0))


static func find_heightmap_path(sanmap_path: String) -> String:
	var candidates := [
		heightmap_raw_path(sanmap_path),
		sanmap_path.get_basename() + ".r16",
		sanmap_path.get_basename() + ".raw",
		sanmap_path.get_base_dir().path_join("heightmap.raw"),
	]
	for c in candidates:
		if FileAccess.file_exists(c):
			return c
	return ""


static func load_heightmap_for_sanmap(sanmap_path: String, resolution: int) -> PackedFloat32Array:
	var path := find_heightmap_path(sanmap_path)
	if path == "":
		var heights := PackedFloat32Array()
		heights.resize(resolution * resolution)
		heights.fill(0.0)
		return heights
	return load_heightmap_raw(path, resolution)


static func save_map_package(
	sanmap_path: String,
	map: SanMapData,
	heights: PackedFloat32Array,
	splat_1_4: Image = null,
	splat_5_8: Image = null,
	tint_colors: Image = null,
	tint_geometry: Image = null
) -> Error:
	map.ensure_playable_materials()
	var err := ensure_package_dir(sanmap_path)
	if err != OK:
		return err
	err = ensure_textures_dir(sanmap_path)
	if err != OK:
		return err
	err = save_sanmap(sanmap_path, map)
	if err != OK:
		return err
	err = save_heightmap_raw(heightmap_raw_path(sanmap_path), heights, map.heightmap_resolution)
	if err != OK:
		return err
	err = save_package_textures(sanmap_path, map, splat_1_4, splat_5_8, tint_colors, tint_geometry)
	return err
