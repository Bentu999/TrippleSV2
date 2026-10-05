class_name SanMapData
extends RefCounted
## Mirrors EM.Map.SanMap (.sanmap format version 3).
## Heightmap samples live separately in EditorState (not in JSON by default).

const FORMAT_VERSION := 3
const EXTENSION := "sanmap"
const STRATUM_COUNT := 9
const MARKER_SPAWN := "Spawn"
const MARKER_ALLOYS := "Alloys"
const AREA_PLAYABLE := "PlayableArea"

var file_version: int = FORMAT_VERSION
var map_version: int = 1
var name: String = "Untitled"
var credits: String = ""
var width: int = 256
var length: int = 256
var height: int = 128

var heightmap_resolution: int = 257

var has_water: bool = false
var water_level: float = 0.0
var water_depth: float = 8.0
var water_wind_speed: float = 0.25
var water_wind_direction: float = 160.0
var water_wind_shore_waves_remap: float = 0.5
var water_shore_depth_offset: float = 8.0
var water_shore_depth_strength: float = 0.7
var water_shore_distance_offset: float = 0.0
var water_shore_distance_strength: float = 2.0
var water_shore_generator_blueprint: String = ""

var shader: String = "RTS/TerrainLit"
var height_transition: float = 0.5
var fade_distance: float = 128.0
var fade_start_distance: float = 1.0
var stratum_layers: Array = []

var background_fog_intensity: float = 0.425
var background_fog_range: float = 1024.0
var background_fog_minimum: float = 0.1
var background_sky_color_intensity: float = 0.52
var background_color_intensity: float = 1.0
var background_color: Dictionary = {"r": 1.319508, "g": 1.319508, "b": 1.319508, "a": 1.0}
var background_color_fadeout_range: float = 150000.0
var background_color_fadeout_power: float = 0.3

var height_fog_intensity: float = 1.0
var height_fog_range: Dictionary = {"x": -10.0, "y": 100.0}
var height_fog_start: float = -10.0
var height_fog_end: float = 500.0
var height_fog_power: float = 6.0

var linear_fog_intensity: float = 0.24
var linear_fog_start: float = 100.0
var linear_fog_end: float = 5000.0
var linear_fog_power: float = 1.0
var linear_fog_camera_intensity: float = 0.0
var linear_fog_camera_start: float = 500.0
var linear_fog_camera_end: float = 5000.0

var sun_ra: float = 96.2
var sun_da: float = 30.0
var sun_intensity: float = 60000.0
var sun_tint: Dictionary = {"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0}
var sun_temperature: float = 9800.0
var sun_angular_diameter: float = 0.5
var sun_volumetrics_multiplier: float = 6.7
var sun_volumetrics_shadow_dimer: float = 0.5
var sun_position: Dictionary = {"x": 512.0, "y": 10.0, "z": 256.0}
var sun_cookie: Dictionary = {"path": ""}
var sun_cookie_size: Dictionary = {"x": 1024.0, "y": 1024.0}

var skylight_intensity: float = 0.0
var skylight_tint: Dictionary = {"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0}
var skylight_temperature: float = 12000.0
var exposure: float = 11.5
var exposure_compensation: float = 0.0
var skybox_rotation: float = 232.0
var skybox_intensity_mode: String = "Exposure"
var skybox_exposure: float = 12.9
var skybox_multiplier: float = 1.0
var skybox_lux_value: float = 30000.0
var fog_attenuation_distance: float = 251.0
var fog_base_height: float = 5.41
var fog_maximum_height: float = 132.5
var fog_maximum_distance: float = 1500.0
var fog_anisotropy: float = 0.0
var skybox: Dictionary = {"path": "Environment/Skybox/kloofendal_48d_partly_cloudy_puresky_4k.exr"}

var areas: Dictionary = {}
var armies: Dictionary = {}
var chains: Dictionary = {}
var markers: Dictionary = {}
var decals: Array = []
var props: Array = []

var wind_speed: float = 0.25
var wind_direction: float = 160.0


func _init() -> void:
	_init_default_strata()
	_ensure_core_markers()
	reset_playable_to_centered()


func _init_default_strata() -> void:
	stratum_layers = _highlands_strata_template()


func _highlands_strata_template() -> Array:
	## Highlands preset matching The Forge / official maps (paths under Environment/).
	return [
		_stratum(
			"Environment/01_Highlands/Stratum/highlands_100m_grass07_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass07_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass07_mask.tga",
			10.0, 64.0, 1.0, 1.22
		),
		_stratum(
			"Environment/01_Highlands/Stratum/highlands_100m_grass02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass02b_mask.tga",
			8.0, 64.0
		),
		_stratum(
			"Environment/01_Highlands/Stratum/highlands_100m_moss01_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_moss01_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_moss01_mask.tga",
			8.0, 64.0
		),
		_stratum(
			"Environment/01_Highlands/Stratum/highlands_100m_sand05_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_sand05_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_sand05_mask.tga",
			10.0, 32.0, 0.8, 0.8, 8.0
		),
		_stratum(
			"Environment/01_Highlands/Stratum/highlands_100m_rock_cliff02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_rock_cliff02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_rock_cliff02_masks.tga",
			12.0, 52.0, 1.0, 1.0, 10.0
		),
		_stratum(
			"Environment/01_Highlands/Stratum/highlands_100m_heather03_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_heather03_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_heather03_mask.tga",
			8.0, 32.0
		),
		_stratum(
			"Environment/01_Highlands/Stratum/highlands_100m_mud02_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_mud02_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_mud02_mask.tga",
			8.0, 40.0
		),
		_stratum(
			"Environment/01_Highlands/Stratum/highlands_100m_grass03_albedo.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass03_normal.tga",
			"Environment/01_Highlands/Stratum/highlands_100m_grass03_mask.tga",
			8.0, 32.0
		),
		_stratum("", "", "", 1.0, 1.0),
	]


func _stratum(
	albedo: String,
	normal: String,
	mask: String,
	tile: float,
	tile_far: float,
	normal_scale: float = 1.0,
	normal_scale_far: float = 1.0,
	tile_tri: float = 12.0
) -> Dictionary:
	# Official maps omit "name" on stratum layers.
	return {
		"albedo": {"path": albedo},
		"normal": {"path": normal},
		"mask": {"path": mask},
		"tileSize": {"x": tile, "y": tile},
		"tileSizeFar": {"x": tile_far, "y": tile_far},
		"tileSizeTriplanar": tile_tri,
		"tileSizeFarTriplanar": 36.0,
		"normalScale": normal_scale,
		"normalScaleFar": normal_scale_far,
		"normalFarNearBlend": 0.5,
		"heightFarNearBlend": 0.5,
		"diffuseRemap": {"r": 0.5, "g": 0.5, "b": 0.5, "a": 1.0},
		"farColorRemap": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.0},
		"maskRemapMin": {"x": 0.0, "y": 0.0, "z": 0.0, "w": 0.0},
		"maskRemapMax": {"x": 1.0, "y": 1.0, "z": 1.0, "w": 1.0},
	}


func ensure_playable_materials() -> void:
	## Fill empty albedo paths with Highlands defaults so the game can render terrain.
	var defaults := _highlands_strata_template()
	if stratum_layers.is_empty():
		stratum_layers = defaults
		return
	for i in mini(stratum_layers.size(), defaults.size()):
		var layer: Dictionary = stratum_layers[i]
		var albedo_path := str((layer.get("albedo", {}) as Dictionary).get("path", ""))
		if albedo_path.strip_edges().is_empty():
			stratum_layers[i] = defaults[i]
	while stratum_layers.size() < STRATUM_COUNT:
		var idx := stratum_layers.size()
		stratum_layers.append(defaults[idx] if idx < defaults.size() else _stratum("", "", "", 1.0, 1.0))
	if skybox.get("path", "").strip_edges().is_empty():
		skybox = {"path": "Environment/Skybox/kloofendal_48d_partly_cloudy_puresky_4k.exr"}


func _ensure_core_markers() -> void:
	if not markers.has(MARKER_SPAWN):
		markers[MARKER_SPAWN] = {"resource": false, "transforms": {}}
	if not markers.has(MARKER_ALLOYS):
		markers[MARKER_ALLOYS] = {"resource": true, "transforms": {}}


func resize(new_width: int, new_length: int, new_height: int, new_resolution: int, fill_playable: bool = false) -> void:
	width = maxi(new_width, 16)
	length = maxi(new_length, 16)
	height = maxi(new_height, 16)
	heightmap_resolution = maxi(new_resolution, 17)
	if fill_playable:
		# New maps: centered half-size playable (matches The Forge defaults).
		reset_playable_to_centered()
	else:
		clamp_playable_area()


## Default playable: half map size, centered (e.g. 2048 → 1024² at 512,512).
func reset_playable_to_centered() -> void:
	var w := maxf(float(width) * 0.5, 1.0)
	var h := maxf(float(length) * 0.5, 1.0)
	areas[AREA_PLAYABLE] = {
		"x": (float(width) - w) * 0.5,
		"y": (float(length) - h) * 0.5,
		"width": w,
		"height": h,
	}


## Keep current playable size, move origin so the rect sits on map center.
func center_playable_area() -> void:
	var area := get_playable_area()
	var w: float = area["width"]
	var h: float = area["height"]
	areas[AREA_PLAYABLE] = {
		"x": (float(width) - w) * 0.5,
		"y": (float(length) - h) * 0.5,
		"width": w,
		"height": h,
	}
	clamp_playable_area()


func reset_playable_to_full() -> void:
	areas[AREA_PLAYABLE] = {
		"x": 0.0,
		"y": 0.0,
		"width": float(width),
		"height": float(length),
	}


func get_playable_area() -> Dictionary:
	var area: Dictionary = areas.get(AREA_PLAYABLE, {})
	return {
		"x": float(area.get("x", 0.0)),
		"y": float(area.get("y", 0.0)),
		"width": float(area.get("width", float(width))),
		"height": float(area.get("height", float(length))),
	}


func set_playable_area(x: float, y: float, area_width: float, area_height: float) -> void:
	areas[AREA_PLAYABLE] = {
		"x": x,
		"y": y,
		"width": area_width,
		"height": area_height,
	}
	clamp_playable_area()


func clamp_playable_area() -> void:
	## Keep PlayableArea inside map bounds; do not force it to fill the map.
	var area := get_playable_area()
	var max_w := float(width)
	var max_l := float(length)
	var w := clampf(area["width"], 1.0, max_w)
	var h := clampf(area["height"], 1.0, max_l)
	var x := clampf(area["x"], 0.0, max_w - w)
	var y := clampf(area["y"], 0.0, max_l - h)
	areas[AREA_PLAYABLE] = {
		"x": x,
		"y": y,
		"width": w,
		"height": h,
	}


## The Forge uses odd Army_N → faction 1, even → 2.
## MapUtils.cs defaults new armies to faction 0 / alloys 500 / energy 500; shipped
## multiplayer maps (Forge) use 1/2 so each side gets its own spawn.
static func faction_for_army_id(army_id: String) -> int:
	if army_id.begins_with("Army_"):
		var n := int(army_id.substr(5))
		if n > 0:
			return 1 if (n % 2) == 1 else 2
	return 1


static func _army_sort_key(army_id: String) -> int:
	if army_id.begins_with("Army_"):
		return int(army_id.substr(5))
	return 9999


func sync_armies_with_spawns() -> void:
	_ensure_core_markers()
	var spawn_bucket: Dictionary = markers.get(MARKER_SPAWN, {})
	var transforms: Dictionary = spawn_bucket.get("transforms", {})
	var ids: Array = transforms.keys()
	ids.sort_custom(func(a, b): return _army_sort_key(str(a)) < _army_sort_key(str(b)))

	# Rebuild armies from spawn markers only (drop orphans).
	var ordered_armies := {}
	for spawn_id in ids:
		var id := str(spawn_id)
		var prev: Dictionary = armies.get(id, {})
		ordered_armies[id] = {
			"faction": faction_for_army_id(id),
			# Resource defaults match MapUtils.cs; faction pattern matches The Forge.
			"alloys": float(prev.get("alloys", 500.0)),
			"energy": float(prev.get("energy", 500.0)),
			"groups": prev.get("groups", {}),
		}
	armies = ordered_armies


func _export_stratum_layers() -> Array:
	var out: Array = []
	for layer in stratum_layers:
		if typeof(layer) != TYPE_DICTIONARY:
			continue
		var src: Dictionary = layer
		var dst := {
			"albedo": src.get("albedo", {"path": ""}),
			"normal": src.get("normal", {"path": ""}),
			"mask": src.get("mask", {"path": ""}),
			"tileSize": src.get("tileSize", {"x": 1.0, "y": 1.0}),
			"tileSizeFar": src.get("tileSizeFar", {"x": 1.0, "y": 1.0}),
			"tileSizeTriplanar": float(src.get("tileSizeTriplanar", 12.0)),
			"tileSizeFarTriplanar": float(src.get("tileSizeFarTriplanar", 36.0)),
			"normalScale": float(src.get("normalScale", 1.0)),
			"normalScaleFar": float(src.get("normalScaleFar", 1.0)),
			"normalFarNearBlend": float(src.get("normalFarNearBlend", 0.5)),
			"heightFarNearBlend": float(src.get("heightFarNearBlend", 0.5)),
			"diffuseRemap": src.get("diffuseRemap", {"r": 0.5, "g": 0.5, "b": 0.5, "a": 1.0}),
			"farColorRemap": src.get("farColorRemap", {"r": 1.0, "g": 1.0, "b": 1.0, "a": 0.0}),
			"maskRemapMin": src.get("maskRemapMin", {"x": 0.0, "y": 0.0, "z": 0.0, "w": 0.0}),
			"maskRemapMax": src.get("maskRemapMax", {"x": 1.0, "y": 1.0, "z": 1.0, "w": 1.0}),
		}
		out.append(dst)
	return out


func _normalize_transform(t: Dictionary) -> Dictionary:
	var pos: Dictionary = t.get("position", {})
	var rot: Dictionary = t.get("rotation", {})
	var scl: Dictionary = t.get("scale", {})
	return {
		"position": {
			"x": float(pos.get("x", 0.0)),
			"y": float(pos.get("y", 0.0)),
			"z": float(pos.get("z", 0.0)),
		},
		"rotation": {
			"x": float(rot.get("x", 0.0)),
			"y": float(rot.get("y", 0.0)),
			"z": float(rot.get("z", 0.0)),
			"w": float(rot.get("w", 1.0)),
		},
		"scale": {
			"x": float(scl.get("x", 1.0)),
			"y": float(scl.get("y", 1.0)),
			"z": float(scl.get("z", 1.0)),
		},
	}


func _export_marker_bucket(bucket: Dictionary) -> Dictionary:
	var transforms_in: Dictionary = bucket.get("transforms", {})
	var transforms_out := {}
	for id in transforms_in.keys():
		if typeof(transforms_in[id]) == TYPE_DICTIONARY:
			transforms_out[id] = _normalize_transform(transforms_in[id])
	return {
		"resource": bool(bucket.get("resource", false)),
		"transforms": transforms_out,
	}


func _export_markers() -> Dictionary:
	# Official sample orders Alloys before Spawn.
	_ensure_core_markers()
	var out := {}
	if markers.has(MARKER_ALLOYS):
		out[MARKER_ALLOYS] = _export_marker_bucket(markers[MARKER_ALLOYS])
	if markers.has(MARKER_SPAWN):
		out[MARKER_SPAWN] = _export_marker_bucket(markers[MARKER_SPAWN])
	for key in markers.keys():
		if key == MARKER_ALLOYS or key == MARKER_SPAWN:
			continue
		out[key] = _export_marker_bucket(markers[key])
	return out


func to_dict() -> Dictionary:
	return to_export_dict()


func _export_areas() -> Dictionary:
	var out := {}
	for area_name in areas.keys():
		var a: Dictionary = areas[area_name]
		out[area_name] = {
			"x": float(a.get("x", 0.0)),
			"y": float(a.get("y", 0.0)),
			"width": float(a.get("width", float(width))),
			"height": float(a.get("height", float(length))),
		}
	return out


func to_export_dict() -> Dictionary:
	## Key order matches official Sanctuary .sanmap files (e.g. The Forge).
	return {
		"fileVersion": file_version,
		"mapVersion": map_version,
		"name": name,
		"credits": credits,
		"width": width,
		"length": length,
		"height": height,
		"heightmapResolution": heightmap_resolution,
		"hasWater": has_water,
		"waterLevel": water_level,
		"waterDepth": water_depth,
		"waterWindSpeed": water_wind_speed,
		"waterWindDirection": water_wind_direction,
		"waterWindShoreWavesRemap": water_wind_shore_waves_remap,
		"waterShoreDepthOffset": water_shore_depth_offset,
		"waterShoreDepthStrength": water_shore_depth_strength,
		"waterShoreDistanceOffset": water_shore_distance_offset,
		"waterShoreDistanceStrength": water_shore_distance_strength,
		"waterShoreGeneratorBlueprint": water_shore_generator_blueprint,
		"shader": shader,
		"heightTransition": height_transition,
		"fadeDistance": fade_distance,
		"fadeStartDistance": fade_start_distance,
		"stratumLayers": _export_stratum_layers(),
		"backgroundFogIntensity": background_fog_intensity,
		"backgroundFogRange": background_fog_range,
		"backgroundFogMinimum": background_fog_minimum,
		"backgroundSkyColorIntensity": background_sky_color_intensity,
		"backgroundColorIntensity": background_color_intensity,
		"backgroundColor": background_color,
		"backgroundColorFadeoutRange": background_color_fadeout_range,
		"backgroundColorFadeoutPower": background_color_fadeout_power,
		"heightFogIntensity": height_fog_intensity,
		"heightFogRange": height_fog_range,
		"heightFogStart": height_fog_start,
		"heightFogEnd": height_fog_end,
		"heightFogPower": height_fog_power,
		"linearFogIntensity": linear_fog_intensity,
		"linearFogStart": linear_fog_start,
		"linearFogEnd": linear_fog_end,
		"linearFogPower": linear_fog_power,
		"linearFogCameraIntensity": linear_fog_camera_intensity,
		"linearFogCameraStart": linear_fog_camera_start,
		"linearFogCameraEnd": linear_fog_camera_end,
		"sunRA": sun_ra,
		"sunDA": sun_da,
		"sunIntensity": sun_intensity,
		"sunTint": sun_tint,
		"sunTemperature": sun_temperature,
		"sunAngularDiameter": sun_angular_diameter,
		"sunVolumetricsMultiplier": sun_volumetrics_multiplier,
		"sunVolumetricsShadowDimer": sun_volumetrics_shadow_dimer,
		"sunPosition": sun_position,
		"sunCookie": sun_cookie,
		"sunCookieSize": sun_cookie_size,
		"skylightIntensity": skylight_intensity,
		"skylightTint": skylight_tint,
		"skylightTemperature": skylight_temperature,
		"exposure": exposure,
		"exposureCompensation": exposure_compensation,
		"skyboxRotation": skybox_rotation,
		"skyboxIntensityMode": skybox_intensity_mode,
		"skyboxExposure": skybox_exposure,
		"skyboxMultiplier": skybox_multiplier,
		"skyboxLuxValue": skybox_lux_value,
		"fogAttenuationDistance": fog_attenuation_distance,
		"fogBaseHeight": fog_base_height,
		"fogMaximumHeight": fog_maximum_height,
		"fogMaximumDistance": fog_maximum_distance,
		"fogAnisotropy": fog_anisotropy,
		"skybox": skybox,
		"areas": _export_areas(),
		"armies": armies,
		"chains": chains,
		"markers": _export_markers(),
		"decals": decals,
		"windSpeed": wind_speed,
		"windDirection": wind_direction,
		"props": props,
	}


static func from_dict(data: Dictionary) -> SanMapData:
	var map := SanMapData.new()
	map.file_version = int(data.get("fileVersion", FORMAT_VERSION))
	map.map_version = int(data.get("mapVersion", 1))
	map.name = str(data.get("name", "Untitled"))
	map.credits = str(data.get("credits", ""))
	map.width = int(data.get("width", 256))
	map.length = int(data.get("length", 256))
	map.height = int(data.get("height", 128))
	map.heightmap_resolution = int(data.get("heightmapResolution", map.width + 1))

	map.has_water = bool(data.get("hasWater", false))
	map.water_level = float(data.get("waterLevel", 0.0))
	map.water_depth = float(data.get("waterDepth", 8.0))
	map.water_wind_speed = float(data.get("waterWindSpeed", 0.25))
	map.water_wind_direction = float(data.get("waterWindDirection", 160.0))
	map.water_wind_shore_waves_remap = float(data.get("waterWindShoreWavesRemap", 0.5))
	map.water_shore_depth_offset = float(data.get("waterShoreDepthOffset", 8.0))
	map.water_shore_depth_strength = float(data.get("waterShoreDepthStrength", 0.7))
	map.water_shore_distance_offset = float(data.get("waterShoreDistanceOffset", 0.0))
	map.water_shore_distance_strength = float(data.get("waterShoreDistanceStrength", 2.0))
	map.water_shore_generator_blueprint = str(data.get("waterShoreGeneratorBlueprint", ""))

	map.shader = str(data.get("shader", "RTS/TerrainLit"))
	map.height_transition = float(data.get("heightTransition", 0.5))
	map.fade_distance = float(data.get("fadeDistance", 128.0))
	map.fade_start_distance = float(data.get("fadeStartDistance", 1.0))
	map.stratum_layers = data.get("stratumLayers", map.stratum_layers)

	map.background_fog_intensity = float(data.get("backgroundFogIntensity", 1.0))
	map.background_fog_range = float(data.get("backgroundFogRange", 1024.0))
	map.background_fog_minimum = float(data.get("backgroundFogMinimum", 0.1))
	map.background_sky_color_intensity = float(data.get("backgroundSkyColorIntensity", 1.0))
	map.background_color_intensity = float(data.get("backgroundColorIntensity", 0.0))
	map.background_color = data.get("backgroundColor", map.background_color)
	map.background_color_fadeout_range = float(data.get("backgroundColorFadeoutRange", 150000.0))
	map.background_color_fadeout_power = float(data.get("backgroundColorFadeoutPower", 0.3))

	map.height_fog_intensity = float(data.get("heightFogIntensity", 1.0))
	map.height_fog_range = data.get("heightFogRange", map.height_fog_range)
	map.height_fog_start = float(data.get("heightFogStart", -10.0))
	map.height_fog_end = float(data.get("heightFogEnd", 500.0))
	map.height_fog_power = float(data.get("heightFogPower", 6.0))

	map.linear_fog_intensity = float(data.get("linearFogIntensity", 0.24))
	map.linear_fog_start = float(data.get("linearFogStart", 100.0))
	map.linear_fog_end = float(data.get("linearFogEnd", 5000.0))
	map.linear_fog_power = float(data.get("linearFogPower", 1.0))
	map.linear_fog_camera_intensity = float(data.get("linearFogCameraIntensity", 0.0))
	map.linear_fog_camera_start = float(data.get("linearFogCameraStart", 500.0))
	map.linear_fog_camera_end = float(data.get("linearFogCameraEnd", 5000.0))

	map.sun_ra = float(data.get("sunRA", 0.0))
	map.sun_da = float(data.get("sunDA", 0.0))
	map.sun_intensity = float(data.get("sunIntensity", 15000.0))
	map.sun_tint = data.get("sunTint", map.sun_tint)
	map.sun_temperature = float(data.get("sunTemperature", 6300.0))
	map.sun_angular_diameter = float(data.get("sunAngularDiameter", 0.5))
	map.sun_volumetrics_multiplier = float(data.get("sunVolumetricsMultiplier", 6.7))
	map.sun_volumetrics_shadow_dimer = float(data.get("sunVolumetricsShadowDimer", 0.5))
	map.sun_position = data.get("sunPosition", map.sun_position)
	map.sun_cookie = data.get("sunCookie", map.sun_cookie)
	map.sun_cookie_size = data.get("sunCookieSize", map.sun_cookie_size)

	map.skylight_intensity = float(data.get("skylightIntensity", 0.0))
	map.skylight_tint = data.get("skylightTint", map.skylight_tint)
	map.skylight_temperature = float(data.get("skylightTemperature", 9000.0))
	map.exposure = float(data.get("exposure", 12.0))
	map.exposure_compensation = float(data.get("exposureCompensation", 2.5))
	map.skybox_rotation = float(data.get("skyboxRotation", 0.0))
	map.skybox_intensity_mode = str(data.get("skyboxIntensityMode", "Exposure"))
	map.skybox_exposure = float(data.get("skyboxExposure", 12.0))
	map.skybox_multiplier = float(data.get("skyboxMultiplier", 1.0))
	map.skybox_lux_value = float(data.get("skyboxLuxValue", 10000.0))
	map.fog_attenuation_distance = float(data.get("fogAttenuationDistance", 200.0))
	map.fog_base_height = float(data.get("fogBaseHeight", 15.0))
	map.fog_maximum_height = float(data.get("fogMaximumHeight", 100.0))
	map.fog_maximum_distance = float(data.get("fogMaximumDistance", 1500.0))
	map.fog_anisotropy = float(data.get("fogAnisotropy", 0.5))
	map.skybox = data.get("skybox", map.skybox)

	map.areas = data.get("areas", {})
	map.armies = data.get("armies", {})
	map.chains = data.get("chains", {})
	map.markers = data.get("markers", {})
	map.decals = data.get("decals", [])
	map.props = data.get("props", [])
	map.wind_speed = float(data.get("windSpeed", 0.25))
	map.wind_direction = float(data.get("windDirection", 160.0))

	map._ensure_core_markers()
	map.sync_armies_with_spawns()
	if not map.areas.has(AREA_PLAYABLE):
		map.reset_playable_to_centered()
	else:
		map.clamp_playable_area()
	if map.stratum_layers.is_empty():
		map._init_default_strata()
	return map
