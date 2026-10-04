extends MeshInstance3D
## Flat base mesh + GPU height displacement + Sanctuary-like stratum preview.

var _shader_mat: ShaderMaterial
var _height_image: Image
var _height_texture: ImageTexture
var _base_res: int = -1
var _base_width: int = -1
var _base_length: int = -1
var _base_height: int = -1
var _texture_dirty: bool = false
var _materials_dirty: bool = true
var _splat_dirty: bool = true
var _tint_dirty: bool = true
var _splat_tex_14: ImageTexture
var _splat_tex_58: ImageTexture
var _splat_tex_extra: ImageTexture
var _tint_colors_tex: ImageTexture
var _tint_geometry_tex: ImageTexture
var _flat_normal_tex: Texture2D
var _flat_mask_tex: Texture2D


func _ready() -> void:
	var shader := load("res://resources/shaders/terrain_displace.gdshader") as Shader
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	material_override = _shader_mat
	_flat_normal_tex = _make_flat_normal_texture()
	_flat_mask_tex = _make_flat_mask_texture()

	EditorState.map_changed.connect(_on_map_changed)
	EditorState.heights_changed.connect(_on_heights_changed)
	EditorState.splat_changed.connect(_on_splat_changed)
	EditorState.materials_changed.connect(_on_materials_changed)
	_rebuild_base_mesh()
	_sync_full_height_texture()
	_reload_materials()


func _process(_delta: float) -> void:
	if _texture_dirty:
		_texture_dirty = false
		_sync_full_height_texture()
	if _splat_dirty:
		_splat_dirty = false
		_sync_splat_textures()
	if _tint_dirty:
		_tint_dirty = false
		_sync_tint_textures()
	if _materials_dirty:
		_materials_dirty = false
		_reload_materials()


func _on_map_changed() -> void:
	_rebuild_base_mesh()
	_sync_full_height_texture()
	_materials_dirty = true
	_splat_dirty = true
	_tint_dirty = true


func _on_heights_changed(_dirty: Rect2i) -> void:
	_texture_dirty = true


func _on_splat_changed(_dirty: Rect2i) -> void:
	# Paint strokes only dirty splat weights — skip tint re-upload for snappier feedback.
	_splat_dirty = true


func _on_materials_changed() -> void:
	_materials_dirty = true
	_tint_dirty = true
	_splat_dirty = true


func _rebuild_base_mesh() -> void:
	var map := EditorState.map
	var res := map.heightmap_resolution
	if res < 2:
		return
	if res == _base_res and map.width == _base_width and map.length == _base_length and map.height == _base_height:
		_push_shader_params()
		return

	_base_res = res
	_base_width = map.width
	_base_length = map.length
	_base_height = map.height

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(res * res)
	uvs.resize(res * res)

	for y in res:
		for x in res:
			var i := y * res + x
			var u := float(x) / float(res - 1)
			var v := float(y) / float(res - 1)
			vertices[i] = Vector3(u * float(map.width), 0.0, v * float(map.length))
			uvs[i] = Vector2(u, v)

	indices.resize((res - 1) * (res - 1) * 6)
	var tri := 0
	for y in res - 1:
		for x in res - 1:
			var i00 := y * res + x
			var i10 := i00 + 1
			var i01 := i00 + res
			var i11 := i01 + 1
			indices[tri] = i00
			indices[tri + 1] = i10
			indices[tri + 2] = i11
			indices[tri + 3] = i00
			indices[tri + 4] = i11
			indices[tri + 5] = i01
			tri += 6

	var normals := PackedVector3Array()
	normals.resize(res * res)
	normals.fill(Vector3.UP)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = am
	_push_shader_params()


func _push_shader_params() -> void:
	if _shader_mat == null:
		return
	var map := EditorState.map
	_shader_mat.set_shader_parameter("map_width", float(map.width))
	_shader_mat.set_shader_parameter("map_length", float(map.length))
	_shader_mat.set_shader_parameter("map_height", float(map.height))
	_shader_mat.set_shader_parameter("water_level", map.water_level)
	_shader_mat.set_shader_parameter("has_water", map.has_water)
	_shader_mat.set_shader_parameter("height_transition", maxf(map.height_transition, 0.05))
	var extent := maxf(float(map.width), float(map.length))
	_shader_mat.set_shader_parameter("far_blend_start", extent * 0.18)
	_shader_mat.set_shader_parameter("far_blend_end", extent * 0.85)
	if _height_texture != null:
		_shader_mat.set_shader_parameter("height_tex", _height_texture)


func _sync_full_height_texture() -> void:
	var res := EditorState.map.heightmap_resolution
	var bytes := EditorState.heights.to_byte_array()
	_height_image = Image.create_from_data(res, res, false, Image.FORMAT_RF, bytes)
	if _height_texture == null:
		_height_texture = ImageTexture.create_from_image(_height_image)
	else:
		_height_texture.set_image(_height_image)
	_push_shader_params()


func _reload_materials() -> void:
	if _shader_mat == null:
		return
	var map := EditorState.map
	map.ensure_playable_materials()

	var loaded := 0
	for i in 8:
		var layer: Dictionary = map.stratum_layers[i] if i < map.stratum_layers.size() else {}
		var albedo_path := str((layer.get("albedo", {}) as Dictionary).get("path", ""))
		var normal_path := str((layer.get("normal", {}) as Dictionary).get("path", ""))
		var mask_path := str((layer.get("mask", {}) as Dictionary).get("path", ""))

		var albedo := EnvironmentAssets.load_texture(albedo_path, 1024)
		if albedo != null:
			loaded += 1
		else:
			albedo = _fallback_albedo_texture(i)
		_shader_mat.set_shader_parameter("albedo_%d" % i, albedo)

		var normal := EnvironmentAssets.load_texture(normal_path, 1024)
		_shader_mat.set_shader_parameter("normal_%d" % i, normal if normal != null else _flat_normal_tex)

		var mask := EnvironmentAssets.load_texture(mask_path, 1024)
		_shader_mat.set_shader_parameter("mask_%d" % i, mask if mask != null else _flat_mask_tex)

		var tile: Dictionary = layer.get("tileSize", {"x": 8.0, "y": 8.0})
		var tile_far: Dictionary = layer.get("tileSizeFar", {"x": 32.0, "y": 32.0})
		# Mild coarsening keeps orbit readable while staying closer to in-game tiling.
		var tx := maxf(float(tile.get("x", 8.0)) * 1.15, 2.0)
		var ty := maxf(float(tile.get("y", 8.0)) * 1.15, 2.0)
		var ftx := maxf(float(tile_far.get("x", tx * 4.0)), tx * 2.0)
		var fty := maxf(float(tile_far.get("y", ty * 4.0)), ty * 2.0)
		_shader_mat.set_shader_parameter("tile_%d" % i, Vector2(tx, ty))
		_shader_mat.set_shader_parameter("tile_far_%d" % i, Vector2(ftx, fty))
		_shader_mat.set_shader_parameter(
			"tile_tri_%d" % i,
			maxf(float(layer.get("tileSizeTriplanar", 12.0)), 4.0)
		)
		_shader_mat.set_shader_parameter(
			"tile_tri_far_%d" % i,
			maxf(float(layer.get("tileSizeFarTriplanar", 36.0)), 8.0)
		)
		_push_layer_look_params(i, layer)

	_sync_splat_textures()
	_sync_tint_textures()
	_shader_mat.set_shader_parameter("use_textured", loaded > 0)
	_shader_mat.set_shader_parameter("use_tint", true)
	_push_shader_params()


func _push_layer_look_params(index: int, layer: Dictionary) -> void:
	var diffuse := _dict_rgba(layer.get("diffuseRemap", {}), Color(0.5, 0.5, 0.5, 1.0))
	var far_col := _dict_rgba(layer.get("farColorRemap", {}), Color(1.0, 1.0, 1.0, 0.0))
	# maskRemap uses x/y/z/w in SanMap JSON — pack into Color for vec4 uniforms.
	var mask_min := _dict_xyzw_as_color(layer.get("maskRemapMin", {}), Color(0, 0, 0, 0))
	var mask_max := _dict_xyzw_as_color(layer.get("maskRemapMax", {}), Color(1, 1, 1, 1))
	_shader_mat.set_shader_parameter("diffuse_remap_%d" % index, diffuse)
	_shader_mat.set_shader_parameter("far_color_remap_%d" % index, far_col)
	_shader_mat.set_shader_parameter("mask_remap_min_%d" % index, mask_min)
	_shader_mat.set_shader_parameter("mask_remap_max_%d" % index, mask_max)
	_shader_mat.set_shader_parameter("normal_scale_%d" % index, float(layer.get("normalScale", 1.0)))
	_shader_mat.set_shader_parameter("normal_scale_far_%d" % index, float(layer.get("normalScaleFar", 1.0)))
	_shader_mat.set_shader_parameter(
		"normal_far_near_blend_%d" % index,
		float(layer.get("normalFarNearBlend", 0.5))
	)
	if index == 0:
		_shader_mat.set_shader_parameter(
			"height_far_near_blend",
			float(layer.get("heightFarNearBlend", 0.5))
		)


func _dict_rgba(value: Variant, fallback: Color) -> Color:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var d: Dictionary = value
	return Color(
		float(d.get("r", fallback.r)),
		float(d.get("g", fallback.g)),
		float(d.get("b", fallback.b)),
		float(d.get("a", fallback.a))
	)


func _dict_xyzw_as_color(value: Variant, fallback: Color) -> Color:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var d: Dictionary = value
	return Color(
		float(d.get("x", fallback.r)),
		float(d.get("y", fallback.g)),
		float(d.get("z", fallback.b)),
		float(d.get("w", fallback.a))
	)


func _sync_splat_textures() -> void:
	if _shader_mat == null:
		return
	EditorState.ensure_splat_images()
	var src14 := _preview_image(EditorState.splat_1_4, 1024)
	var src58 := _preview_image(EditorState.splat_5_8, 1024)
	var packed := _pack_splat_gpu_images(src14, src58)
	_splat_tex_14 = _update_tex(_splat_tex_14, packed[0])
	_splat_tex_58 = _update_tex(_splat_tex_58, packed[1])
	_splat_tex_extra = _update_tex(_splat_tex_extra, packed[2])
	_shader_mat.set_shader_parameter("splat_1_4", _splat_tex_14)
	_shader_mat.set_shader_parameter("splat_5_8", _splat_tex_58)
	_shader_mat.set_shader_parameter("splat_extra", _splat_tex_extra)


## Pack CPU splat images for GPU: move alpha weights (layers 3 & 7) into RGB
## so backends cannot treat stratum weights as transparency.
func _pack_splat_gpu_images(src14: Image, src58: Image) -> Array:
	var img14 := src14
	if img14.get_format() != Image.FORMAT_RGBA8:
		img14 = img14.duplicate()
		img14.convert(Image.FORMAT_RGBA8)
	var img58 := src58
	if img58.get_format() != Image.FORMAT_RGBA8:
		img58 = img58.duplicate()
		img58.convert(Image.FORMAT_RGBA8)
	var w := img14.get_width()
	var h := img14.get_height()
	var d14 := img14.get_data()
	var d58 := img58.get_data()
	# Work on copies so we never mutate EditorState splat images in-place.
	d14 = d14.duplicate()
	d58 = d58.duplicate()
	var dex := PackedByteArray()
	dex.resize(w * h * 4)
	var n := w * h
	for i in n:
		var o := i * 4
		dex[o] = d14[o + 3] # layer 3 (was splat_1_4.a)
		dex[o + 1] = d58[o + 3] # layer 7 (was splat_5_8.a)
		dex[o + 2] = 0
		dex[o + 3] = 255
		d14[o + 3] = 255 # force opaque
		d58[o + 3] = 255
	var out14 := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d14)
	var out58 := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d58)
	var extra := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, dex)
	return [out14, out58, extra]


func _sync_tint_textures() -> void:
	if _shader_mat == null:
		return
	EditorState.ensure_tint_images()
	var img_tc := _preview_image(EditorState.tint_colors, 1024)
	var img_tg := _preview_image(EditorState.tint_geometry, 1024)
	_tint_colors_tex = _update_tex(_tint_colors_tex, img_tc)
	_tint_geometry_tex = _update_tex(_tint_geometry_tex, img_tg)
	_shader_mat.set_shader_parameter("tint_colors", _tint_colors_tex)
	_shader_mat.set_shader_parameter("tint_geometry", _tint_geometry_tex)


func _preview_image(src: Image, max_size: int) -> Image:
	if src == null:
		return Image.create(4, 4, false, Image.FORMAT_RGBA8)
	if src.get_width() <= max_size and src.get_height() <= max_size:
		return src
	var img := src.duplicate()
	img.resize(max_size, max_size, Image.INTERPOLATE_BILINEAR)
	return img


func _update_tex(existing: ImageTexture, img: Image) -> ImageTexture:
	if existing == null:
		return ImageTexture.create_from_image(img)
	existing.set_image(img)
	return existing


func _make_flat_normal_texture() -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 1.0, 1.0))
	return ImageTexture.create_from_image(img)


func _make_flat_mask_texture() -> Texture2D:
	## HDRP-style: R=metallic, G=AO, B=detail, A=smoothness.
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 1.0, 0.0, 0.2))
	return ImageTexture.create_from_image(img)


func _fallback_albedo_texture(index: int) -> Texture2D:
	var colors := [
		Color(0.30, 0.42, 0.22),
		Color(0.36, 0.40, 0.24),
		Color(0.28, 0.38, 0.26),
		Color(0.55, 0.48, 0.30),
		Color(0.45, 0.40, 0.36),
		Color(0.32, 0.30, 0.20),
		Color(0.38, 0.30, 0.22),
		Color(0.34, 0.44, 0.26),
	]
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(colors[clampi(index, 0, colors.size() - 1)])
	return ImageTexture.create_from_image(img)
