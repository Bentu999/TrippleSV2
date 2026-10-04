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
var _splat_tex_14: ImageTexture
var _splat_tex_58: ImageTexture


func _ready() -> void:
	var shader := load("res://resources/shaders/terrain_displace.gdshader") as Shader
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	material_override = _shader_mat

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
	if _materials_dirty:
		_materials_dirty = false
		_reload_materials()


func _on_map_changed() -> void:
	_rebuild_base_mesh()
	_sync_full_height_texture()
	_materials_dirty = true
	_splat_dirty = true


func _on_heights_changed(_dirty: Rect2i) -> void:
	_texture_dirty = true


func _on_splat_changed(_dirty: Rect2i) -> void:
	_splat_dirty = true


func _on_materials_changed() -> void:
	_materials_dirty = true


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
	_shader_mat.set_shader_parameter("map_width", float(EditorState.map.width))
	_shader_mat.set_shader_parameter("map_length", float(EditorState.map.length))
	_shader_mat.set_shader_parameter("map_height", float(EditorState.map.height))
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
		var tex := EnvironmentAssets.load_texture(albedo_path, 512)
		if tex != null:
			loaded += 1
		else:
			tex = _fallback_albedo_texture(i)
		_shader_mat.set_shader_parameter("albedo_%d" % i, tex)
		var tile: Dictionary = layer.get("tileSize", {"x": 8.0, "y": 8.0})
		# Editor preview: slightly coarser tiling so albedo detail stays readable from orbit.
		var tx := maxf(float(tile.get("x", 8.0)) * 2.0, 4.0)
		var ty := maxf(float(tile.get("y", 8.0)) * 2.0, 4.0)
		_shader_mat.set_shader_parameter("tile_%d" % i, Vector2(tx, ty))

	_sync_splat_textures()
	_shader_mat.set_shader_parameter("use_textured", loaded > 0)
	_push_shader_params()


func _sync_splat_textures() -> void:
	if _shader_mat == null:
		return
	EditorState.ensure_splat_images()
	var img14 := EditorState.splat_1_4
	var img58 := EditorState.splat_5_8
	# Preview uses a capped resolution for GPU upload cost on large maps.
	var max_preview := 1024
	if img14.get_width() > max_preview:
		img14 = img14.duplicate()
		img14.resize(max_preview, max_preview, Image.INTERPOLATE_BILINEAR)
	if img58.get_width() > max_preview:
		img58 = img58.duplicate()
		img58.resize(max_preview, max_preview, Image.INTERPOLATE_BILINEAR)
	if _splat_tex_14 == null:
		_splat_tex_14 = ImageTexture.create_from_image(img14)
	else:
		_splat_tex_14.set_image(img14)
	if _splat_tex_58 == null:
		_splat_tex_58 = ImageTexture.create_from_image(img58)
	else:
		_splat_tex_58.set_image(img58)
	_shader_mat.set_shader_parameter("splat_1_4", _splat_tex_14)
	_shader_mat.set_shader_parameter("splat_5_8", _splat_tex_58)


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
