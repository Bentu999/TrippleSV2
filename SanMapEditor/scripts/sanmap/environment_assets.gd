class_name EnvironmentAssets
extends RefCounted
## Resolves Sanctuary `Environment/...` asset paths against the local `Enviroment/` folder.


static func enviroment_root() -> String:
	## Search order for Sanctuary terrain textures:
	## 1) next to the exported .exe (portable dist)
	## 2) workspace sibling of the Godot project (dev)
	## 3) fallback path name
	var candidates: PackedStringArray = []
	var exe_dir := OS.get_executable_path().get_base_dir()
	if not exe_dir.is_empty():
		candidates.append(exe_dir.path_join("Enviroment"))
		candidates.append(exe_dir.path_join("Environment"))
	var project_root := ProjectSettings.globalize_path("res://").rstrip("/\\")
	var workspace := project_root.get_base_dir()
	candidates.append(workspace.path_join("Enviroment"))
	candidates.append(workspace.path_join("Environment"))
	for candidate in candidates:
		if DirAccess.dir_exists_absolute(candidate):
			return candidate
	return exe_dir.path_join("Enviroment") if not exe_dir.is_empty() else workspace.path_join("Enviroment")


static func resolve_game_path(game_path: String) -> String:
	## `Environment/01_Highlands/...tga` -> absolute file under Enviroment/.
	var p := game_path.strip_edges().replace("\\", "/")
	if p.is_empty():
		return ""
	var rel := p
	if rel.begins_with("Environment/"):
		rel = rel.substr("Environment/".length())
	elif rel.begins_with("Enviroment/"):
		rel = rel.substr("Enviroment/".length())
	var full := enviroment_root().path_join(rel.replace("/", "\\") if OS.get_name() == "Windows" else rel)
	full = full.replace("\\", "/")
	# Prefer formats Godot Image.load can decode. DDS often exists but is unrecognized.
	var basename := full.get_basename()
	var ordered: PackedStringArray = []
	if full.ends_with(".dds"):
		ordered = PackedStringArray([basename + ".png", basename + ".tga", full])
	elif full.ends_with(".tga"):
		ordered = PackedStringArray([full, basename + ".png", basename + ".dds"])
	elif full.ends_with(".png"):
		ordered = PackedStringArray([full, basename + ".tga", basename + ".dds"])
	else:
		ordered = PackedStringArray([full])
	for candidate in ordered:
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


static func load_texture(game_or_abs_path: String, max_size: int = 1024) -> Texture2D:
	var abs_path := game_or_abs_path.strip_edges()
	if abs_path.is_empty():
		return null
	var looks_absolute := abs_path.begins_with("res://") \
		or abs_path.begins_with("/") \
		or (abs_path.length() > 2 and abs_path[1] == ":")
	if not looks_absolute:
		abs_path = resolve_game_path(abs_path)
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		return null
	var img := Image.new()
	var err := img.load(abs_path)
	if err != OK:
		push_warning("Failed to load texture: %s (%s)" % [abs_path, error_string(err)])
		return null
	if max_size > 0 and (img.get_width() > max_size or img.get_height() > max_size):
		var scale := float(max_size) / float(maxi(img.get_width(), img.get_height()))
		var w := maxi(1, int(round(float(img.get_width()) * scale)))
		var h := maxi(1, int(round(float(img.get_height()) * scale)))
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	# Shader uses mipmaps; generate them or sampling looks like noise.
	if img.get_format() != Image.FORMAT_RGBA8 and img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func load_package_texture(sanmap_path: String, file_name: String, max_size: int = 1024) -> Texture2D:
	if sanmap_path.is_empty():
		return null
	var full := sanmap_path.get_base_dir().path_join("Textures").path_join(file_name)
	if not FileAccess.file_exists(full):
		return null
	return load_texture(full, max_size)


static func load_skybox_panorama(game_or_abs_path: String, max_size: int = 2048) -> Texture2D:
	## Load HDRI/EXR skyboxes without crushing them to LDR RGBA8.
	var abs_path := game_or_abs_path.strip_edges()
	if abs_path.is_empty():
		return null
	var looks_absolute := abs_path.begins_with("res://") \
		or abs_path.begins_with("/") \
		or (abs_path.length() > 2 and abs_path[1] == ":")
	if not looks_absolute:
		abs_path = resolve_game_path(abs_path)
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		return null
	var img := Image.new()
	var err := img.load(abs_path)
	if err != OK:
		push_warning("Failed to load skybox: %s (%s)" % [abs_path, error_string(err)])
		return null
	if max_size > 0 and (img.get_width() > max_size or img.get_height() > max_size):
		var scale := float(max_size) / float(maxi(img.get_width(), img.get_height()))
		var w := maxi(1, int(round(float(img.get_width()) * scale)))
		var h := maxi(1, int(round(float(img.get_height()) * scale)))
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


static func make_base_splat_image(resolution: int, layer_index: int = 0) -> Image:
	## RGBA weights: layer 0..3 -> R,G,B,A. Default fills layer 0.
	var img := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	var c := Color(0, 0, 0, 0)
	match layer_index:
		0:
			c = Color(1, 0, 0, 0)
		1:
			c = Color(0, 1, 0, 0)
		2:
			c = Color(0, 0, 1, 0)
		_:
			c = Color(0, 0, 0, 1)
	img.fill(c)
	return img
