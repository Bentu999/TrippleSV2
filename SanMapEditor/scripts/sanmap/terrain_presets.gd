class_name TerrainPresets
extends RefCounted
## Named terrain material presets (stratum sets) used by official maps.

## Stable paint-slot labels — identical for every biome (paths still differ).
const LAYER_ROLE_NAMES: Array[String] = [
	"Boden A",
	"Boden B",
	"Detail",
	"Sand",
	"Fels",
	"Vegetation",
	"Erde",
	"Stein",
]


static func preset_ids() -> PackedStringArray:
	return PackedStringArray(["highlands", "forest", "tropical", "desert", "frozen", "evergreen"])


static func preset_label(id: String) -> String:
	match id:
		"highlands":
			return "Highlands"
		"forest":
			return "Forest"
		"tropical":
			return "Tropical"
		"desert":
			return "Desert"
		"frozen":
			return "Frozen / Winter"
		"evergreen":
			return "Evergreen"
		_:
			return id


static func apply(map: SanMapData, preset_id: String) -> void:
	var layers: Array = _layers_for(preset_id)
	if layers.is_empty():
		return
	_assign_layer_names(layers)
	map.stratum_layers = layers
	var sky := _sky_for(preset_id)
	if not sky.is_empty():
		map.skybox = {"path": sky}


static func layer_role_name(index: int) -> String:
	if index < 0 or index >= LAYER_ROLE_NAMES.size():
		return "Schicht %d" % (index + 1)
	return LAYER_ROLE_NAMES[index]


static func layer_display_name(map: SanMapData, index: int) -> String:
	## `index` is 0..7 internally; labels are biome-independent role names.
	var label_n := index + 1
	var role := layer_role_name(index)
	if index < 0 or index >= map.stratum_layers.size():
		return "%d · %s" % [label_n, role]
	var layer: Dictionary = map.stratum_layers[index]
	var path := str((layer.get("albedo", {}) as Dictionary).get("path", ""))
	if path.is_empty():
		return "%d · %s (leer)" % [label_n, role]
	return "%d · %s" % [label_n, role]


static func _assign_layer_names(layers: Array) -> void:
	for i in mini(layers.size(), LAYER_ROLE_NAMES.size()):
		if typeof(layers[i]) != TYPE_DICTIONARY:
			continue
		(layers[i] as Dictionary)["name"] = layer_role_name(i)


static func _sky_for(preset_id: String) -> String:
	if preset_id == "frozen":
		return "Environment/Skybox/kloppenheim_06_puresky_4k.exr"
	return "Environment/Skybox/kloofendal_48d_partly_cloudy_puresky_4k.exr"


static func _S(albedo: String, normal: String, mask: String, tile: float = 8.0) -> Dictionary:
	return {
		"albedo": {"path": albedo},
		"normal": {"path": normal},
		"mask": {"path": mask},
		"tileSize": {"x": tile, "y": tile},
		"tileSizeFar": {"x": maxf(tile * 4.0, 32.0), "y": maxf(tile * 4.0, 32.0)},
		"tileSizeTriplanar": 12.0,
		"tileSizeFarTriplanar": 36.0,
		"normalScale": 1.0,
		"normalScaleFar": 1.0,
		"normalFarNearBlend": 0.5,
		"heightFarNearBlend": 0.5,
		"diffuseRemap": {"r": 0.5, "g": 0.5, "b": 0.5, "a": 1.0},
		"farColorRemap": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.0},
		"maskRemapMin": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 0.0},
		"maskRemapMax": {"x": 1.0, "y": 1.0, "z": 1.0, "w": 1.0},
	}


static func _empty() -> Dictionary:
	return _S("", "", "", 1.0)


static func _layers_for(preset_id: String) -> Array:
	match preset_id:
		"desert":
			return _desert()
		"forest":
			return _forest()
		"tropical":
			return _tropical()
		"frozen":
			return _frozen()
		"evergreen":
			return _evergreen()
		_:
			return _highlands()


static func _highlands() -> Array:
	return [
		_S("Environment/01_Highlands/Stratum/highlands_100m_grass07_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass07_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass07_mask.tga", 10.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_grass02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass02b_mask.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_moss01_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_moss01_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_moss01_mask.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_sand05_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_sand05_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_sand05_mask.tga", 10.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_rock_cliff02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_rock_cliff02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_rock_cliff02_masks.tga", 12.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_heather03_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_heather03_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_heather03_mask.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_mud02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_mud02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_mud02_mask.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_grass03_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass03_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass03_mask.tga", 8.0),
		_empty(),
	]


static func _forest() -> Array:
	return [
		_S("Environment/01_Highlands/Stratum/highlands_100m_grass02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass02_mask.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_grass02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass02_mask.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_grass07_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass07_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass07_mask.tga", 10.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_moss01_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_moss01_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_moss01_mask.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_gravel02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_gravel02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_gravel02_masks.tga", 20.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_rock_cliff02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_rock_cliff02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_rock_cliff02_masks.tga", 12.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_heather03_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_heather03_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_heather03_mask.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_groundrock_02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_groundrock_02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_groundrock_02_mask.tga", 8.0),
		_empty(),
	]


static func _tropical() -> Array:
	return [
		_S("Environment/01_Highlands/Stratum/highlands_100m_grass07_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass07_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass07_mask.tga", 10.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_grass07_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass07_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass07_mask.tga", 10.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_heather03_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_heather03_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_heather03_mask.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_grass02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass02b_mask.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_grass03_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass03_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass03_mask.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_mud02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_mud02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_mud02_mask.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_sand05_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_sand05_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_sand05_mask.tga", 10.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_rock_cliff02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_rock_cliff02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_rock_cliff02_masks.tga", 12.0),
		_empty(),
	]


static func _desert() -> Array:
	return [
		_S("Environment/10_WhiteDesert/Stratum/desert_100m_sand_01_albedo.tga",
			"Environment/10_WhiteDesert/Stratum/desert_100m_sand_01_normal.tga",
			"Environment/10_WhiteDesert/Stratum/desert_100m_sand_01_mask.tga", 12.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_sand02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_sand02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_sand02_mask_low.tga", 10.0),
		_S("Environment/10_WhiteDesert/Stratum/desert_100m_sand_02_albedo.tga",
			"Environment/10_WhiteDesert/Stratum/desert_100m_sand_02_normal.tga",
			"Environment/10_WhiteDesert/Stratum/desert_100m_sand_02_mask.tga", 12.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_sand02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_sand02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_sand02_mask.tga", 10.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_gravel02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_gravel02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_gravel02_masks.tga", 8.0),
		_S("Environment/10_WhiteDesert/Stratum/desert_100m_sandstone_01_albedo.tga",
			"Environment/10_WhiteDesert/Stratum/desert_100m_sandstone_01_normal.tga",
			"Environment/10_WhiteDesert/Stratum/desert_100m_sandstone_01_mask.tga", 12.0),
		_S("Environment/10_WhiteDesert/Stratum/desert_100m_ground_foliage_04_albedo.tga",
			"Environment/10_WhiteDesert/Stratum/desert_100m_ground_foliage_04_normal.tga",
			"Environment/10_WhiteDesert/Stratum/desert_100m_ground_foliage_04_mask.tga", 8.0),
		_S("Environment/10_WhiteDesert/Stratum/desert_100m_rock_01_albedo.tga",
			"Environment/10_WhiteDesert/Stratum/desert_100m_rock_01_normal.tga",
			"Environment/10_WhiteDesert/Stratum/desert_100m_rock_01_mask.tga", 10.0),
		_empty(),
	]


static func _frozen() -> Array:
	return [
		_S("Environment/Winter/Stratum/uewpai2fw_albedo.tga",
			"Environment/Winter/Stratum/uewpai2fw_normal.tga",
			"Environment/Winter/Stratum/uewpai2fw_masks.tga", 8.0),
		_S("Environment/Winter/Stratum/ice_alt_albedo.tga",
			"Environment/Winter/Stratum/ice_normals.tga",
			"Environment/Winter/Stratum/ice_mask.tga", 8.0),
		_S("Environment/Winter/Stratum/snow_plain_albedo.tga",
			"Environment/Winter/Stratum/uewpai2fw_normal.tga",
			"Environment/Winter/Stratum/snow_plain_mask.tga", 8.0),
		_S("Environment/Winter/Stratum/dirty_ground_albedo.tga",
			"Environment/Winter/Stratum/dirty_ground_normal.tga",
			"Environment/Winter/Stratum/dirty_ground_masks.tga", 8.0),
		_S("Environment/01_Highlands/Stratum/highlands_100m_rock_sandstone02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_rock_sandstone02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_rock_sandstone02_mask.tga", 10.0),
		_S("Environment/Winter/Stratum/vjuieadr_albedo.tga",
			"Environment/Winter/Stratum/vjuieadr_normal.tga",
			"Environment/Winter/Stratum/vjuieadr_masks.tga", 8.0),
		_S("Environment/Winter/Stratum/ice_albedo.tga",
			"Environment/Winter/Stratum/ice_normals.tga",
			"Environment/Winter/Stratum/ice_mask.tga", 8.0),
		_S("Environment/Winter/Stratum/tdloaf1r_albedo.tga",
			"Environment/Winter/Stratum/tdloaf1r_normal.tga",
			"Environment/Winter/Stratum/tdloaf1r_masks.tga", 8.0),
		_empty(),
	]


static func _evergreen() -> Array:
	return [
		_S("Environment/02_Evergreen/Stratum/grass_albedo.tga",
			"Environment/02_Evergreen/Stratum/grass_normal.tga",
			"Environment/02_Evergreen/Stratum/grass_mask.tga", 8.0),
		_S("Environment/02_Evergreen/Stratum/dirt_albedo.tga",
			"Environment/02_Evergreen/Stratum/grass_normal.tga",
			"Environment/02_Evergreen/Stratum/dirt_mask.tga", 8.0),
		_S("Environment/02_Evergreen/Stratum/rock_albedo.tga",
			"Environment/02_Evergreen/Stratum/rock_normal.tga",
			"Environment/02_Evergreen/Stratum/rock_mask.tga", 10.0),
		_S("Environment/02_Evergreen/Stratum/sand_albeo.tga",
			"Environment/02_Evergreen/Stratum/sand_normal.tga",
			"Environment/02_Evergreen/Stratum/sand_mask.tga", 10.0),
		_S("Environment/02_Evergreen/Stratum/aerial_grass_rock_15m_albedo.tga",
			"Environment/02_Evergreen/Stratum/aerial_grass_rock_15m_normal.tga",
			"Environment/02_Evergreen/Stratum/aerial_grass_rock_15m_mask.tga", 15.0),
		_S("Environment/02_Evergreen/Stratum/grass_albedo.tga",
			"Environment/02_Evergreen/Stratum/grass_normal.tga",
			"Environment/02_Evergreen/Stratum/grass_mask.tga", 8.0),
		_S("Environment/02_Evergreen/Stratum/dirt_albedo.tga",
			"Environment/02_Evergreen/Stratum/grass_normal.tga",
			"Environment/02_Evergreen/Stratum/dirt_mask.tga", 8.0),
		_S("Environment/02_Evergreen/Stratum/rock_albedo.tga",
			"Environment/02_Evergreen/Stratum/rock_normal.tga",
			"Environment/02_Evergreen/Stratum/rock_mask.tga", 10.0),
		_empty(),
	]
