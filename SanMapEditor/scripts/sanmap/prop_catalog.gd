class_name PropCatalog
extends RefCounted
## Discovers Sanctuary prop blueprints (.santp) for the placement tool.


const FALLBACK_BLUEPRINTS: PackedStringArray = [
	"Environment/01_Highlands/Props/edbm0149/edbm0149.santp",
	"Environment/01_Highlands/Props/edbm0148/edbm0148.santp",
	"Environment/01_Highlands/Props/edbm0146/edbm0146.santp",
	"Environment/01_Highlands/Props/edbm0150/edbm0150.santp",
	"Environment/01_Highlands/Props/edbm0147/edbm0147.santp",
	"Environment/01_Highlands/Props/edbm0145/edbm0145.santp",
	"Environment/01_Highlands/Props/edbm0141/edbm0141.santp",
	"Environment/01_Highlands/Props/edbm0143/edbm0143.santp",
	"Environment/01_Highlands/Props/edbm0142/edbm0142.santp",
	"Environment/01_Highlands/Props/edbm0144/edbm0144.santp",
	"Environment/01_Highlands/Props/edbm0121/edbm0121.santp",
	"Environment/01_Highlands/Props/edbm0122/edbm0122.santp",
	"Environment/01_Highlands/Props/edbm0123/edbm0123.santp",
	"Environment/01_Highlands/Props/edbm0124/edbm0124.santp",
	"Environment/01_Highlands/Props/edbm0125/edbm0125.santp",
	"Environment/01_Highlands/Props/edbs0110/edbs0110.santp",
	"Environment/01_Highlands/Props/edbs0111/edbs0111.santp",
	"Environment/01_Highlands/Props/edbs0112/edbs0112.santp",
	"Environment/01_Highlands/Props/edbs0113/edbs0113.santp",
	"Environment/01_Highlands/Props/edmm0102/edmm0102.santp",
	"Environment/01_Highlands/Props/edmm0103/edmm0103.santp",
	"Environment/01_Highlands/Props/edmm0104/edmm0104.santp",
	"Environment/01_Highlands/Props/edml0101/edml0101.santp",
	"Environment/01_Highlands/Props/edml0102/edml0102.santp",
	"Environment/01_Highlands/Props/edms0101/edms0101.santp",
	"Environment/02_Evergreen/Props/egbm0101/egbm0101.santp",
	"Environment/10_WhiteDesert/Props/wdbm0101/wdbm0101.santp",
]

static var _cache: PackedStringArray = PackedStringArray()


static func all_blueprints() -> PackedStringArray:
	if not _cache.is_empty():
		return _cache
	var found := _scan_environment_pack()
	if found.is_empty():
		found = FALLBACK_BLUEPRINTS.duplicate()
	_cache = found
	return _cache


static func refresh() -> PackedStringArray:
	_cache = PackedStringArray()
	return all_blueprints()


static func display_name(blueprint_path: String) -> String:
	var p := blueprint_path.replace("\\", "/").strip_edges()
	if p.is_empty():
		return "(none)"
	var parts := p.split("/")
	var file := p.get_file().get_basename()
	var biome := ""
	for i in parts.size():
		if parts[i] == "Props" and i > 0:
			biome = parts[i - 1]
			break
	if biome.begins_with("01_"):
		biome = biome.substr(3)
	elif biome.begins_with("02_") or biome.begins_with("04_") or biome.begins_with("09_") or biome.begins_with("10_"):
		biome = biome.substr(3)
	if biome.is_empty():
		return file
	return "%s / %s" % [biome, file]


static func color_for(blueprint_path: String) -> Color:
	var h := blueprint_path.hash()
	var hue := float(h & 0xFF) / 255.0
	var sat := 0.45 + float((h >> 8) & 0x7F) / 255.0 * 0.35
	var val := 0.72 + float((h >> 16) & 0x3F) / 255.0 * 0.2
	return Color.from_hsv(hue, sat, val)


static func proxy_size_for(blueprint_path: String) -> Vector3:
	## Approximate rock/bush sizes from Sanctuary naming prefixes.
	var id := blueprint_path.get_file().get_basename().to_lower()
	if id.contains("edml") or id.contains("egml") or id.begins_with("wdml"):
		return Vector3(4.5, 3.2, 4.5)
	if id.contains("edbm") or id.contains("egbm") or id.begins_with("wdbm"):
		return Vector3(3.2, 2.4, 3.2)
	if id.contains("edmm") or id.contains("egmm"):
		return Vector3(2.2, 1.7, 2.2)
	if id.contains("edbs") or id.contains("edms"):
		return Vector3(1.4, 1.1, 1.4)
	return Vector3(2.0, 1.6, 2.0)


static func merge_from_map(map: SanMapData) -> void:
	if map == null:
		return
	var current := all_blueprints()
	var seen: Dictionary = {}
	for p in current:
		seen[str(p)] = true
	var added := false
	for group in map.props:
		if typeof(group) != TYPE_DICTIONARY:
			continue
		var bp := str(group.get("blueprintPath", "")).strip_edges()
		if bp.is_empty() or seen.has(bp):
			continue
		seen[bp] = true
		current.append(bp)
		added = true
	if added:
		current.sort()
		_cache = current


static func _scan_environment_pack() -> PackedStringArray:
	var pack := _find_environment_sanpack()
	if pack.is_empty() or not FileAccess.file_exists(pack):
		return PackedStringArray()
	var out: PackedStringArray = PackedStringArray()
	var zf := ZIPReader.new()
	if zf.open(pack) != OK:
		return PackedStringArray()
	for entry in zf.get_files():
		var n := str(entry).replace("\\", "/")
		if not n.ends_with(".santp"):
			continue
		if "/Props/" not in n:
			continue
		# Normalize to Environment/... game path.
		var idx := n.find("Environment/")
		if idx < 0:
			idx = n.find("Enviroment/")
		var game_path := n if idx < 0 else n.substr(idx)
		game_path = game_path.replace("Enviroment/", "Environment/")
		if not out.has(game_path):
			out.append(game_path)
	zf.close()
	out.sort()
	return out


static func _find_environment_sanpack() -> String:
	var candidates: PackedStringArray = [
		"D:/SteamLibrary/steamapps/common/Sanctuary Shattered Sun Playtest/engine/Sanctuary_Data/Gamedata/Environment.sanpack",
		"C:/Program Files (x86)/Steam/steamapps/common/Sanctuary Shattered Sun Playtest/engine/Sanctuary_Data/Gamedata/Environment.sanpack",
		"C:/Program Files/Steam/steamapps/common/Sanctuary Shattered Sun Playtest/engine/Sanctuary_Data/Gamedata/Environment.sanpack",
	]
	var env_root := EnvironmentAssets.enviroment_root()
	var workspace := env_root.get_base_dir()
	candidates.append(workspace.path_join("Environment.sanpack"))
	candidates.append(workspace.path_join("Gamedata").path_join("Environment.sanpack"))
	for c in candidates:
		if FileAccess.file_exists(c):
			return c
	return ""
