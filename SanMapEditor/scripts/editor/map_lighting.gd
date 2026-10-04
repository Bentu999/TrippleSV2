extends Node
## Syncs WorldEnvironment sky + DirectionalLight to the active SanMap lighting block.

@onready var world_env: WorldEnvironment = $"../WorldEnvironment"
@onready var sun: DirectionalLight3D = $"../Sun"

var _sky: Sky
var _panorama_mat: PanoramaSkyMaterial
var _fallback_sky_mat: ProceduralSkyMaterial
var _cached_sky_path: String = ""
var _cached_sky_tex: Texture2D
var _cached_cookie_path: String = ""
var _cached_cookie_tex: Texture2D


func _ready() -> void:
	_ensure_sky_resources()
	EditorState.map_changed.connect(_apply_from_map)
	EditorState.materials_changed.connect(_apply_from_map)
	_apply_from_map()


func _ensure_sky_resources() -> void:
	if world_env.environment == null:
		world_env.environment = Environment.new()
	var env := world_env.environment
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.04

	_panorama_mat = PanoramaSkyMaterial.new()
	_panorama_mat.filter = true
	_fallback_sky_mat = ProceduralSkyMaterial.new()
	_fallback_sky_mat.sky_top_color = Color(0.35, 0.55, 0.78)
	_fallback_sky_mat.sky_horizon_color = Color(0.72, 0.78, 0.82)
	_fallback_sky_mat.ground_bottom_color = Color(0.18, 0.2, 0.16)
	_fallback_sky_mat.ground_horizon_color = Color(0.55, 0.58, 0.5)

	_sky = Sky.new()
	_sky.sky_material = _fallback_sky_mat
	env.sky = _sky


func _apply_from_map() -> void:
	if world_env == null or sun == null:
		return
	_ensure_sky_resources()
	var map := EditorState.map
	var env := world_env.environment

	_apply_skybox(map, env)
	_apply_exposure(map, env)
	_apply_sun(map)
	_apply_fog(map, env)


func _apply_skybox(map: SanMapData, env: Environment) -> void:
	var path := str((map.skybox as Dictionary).get("path", "")).strip_edges()
	if path.is_empty():
		path = "Environment/Skybox/kloofendal_48d_partly_cloudy_puresky_4k.exr"

	var tex: Texture2D = null
	if path == _cached_sky_path and _cached_sky_tex != null:
		tex = _cached_sky_tex
	else:
		tex = EnvironmentAssets.load_skybox_panorama(path, 2048)
		_cached_sky_path = path
		_cached_sky_tex = tex

	if tex != null:
		_panorama_mat.panorama = tex
		# Game skyboxExposure ~12–13; boost panorama a bit so Godot HDRI reads similarly.
		var energy := _sky_energy_multiplier(map)
		_panorama_mat.energy_multiplier = energy
		_sky.sky_material = _panorama_mat
	else:
		_sky.sky_material = _fallback_sky_mat
		push_warning("Skybox missing locally: %s (using procedural fallback)" % path)

	# Sanctuary skyboxRotation is degrees around Y.
	env.sky_rotation = Vector3(0.0, deg_to_rad(map.skybox_rotation), 0.0)


func _sky_energy_multiplier(map: SanMapData) -> float:
	match map.skybox_intensity_mode:
		"Lux":
			return clampf(map.skybox_lux_value / 42000.0, 0.25, 1.6)
		"Multiplier":
			return clampf(map.skybox_multiplier * 0.85, 0.2, 1.8)
		_:
			# Exposure mode: keep HDRI visible without washing terrain albedo.
			var delta := map.skybox_exposure - 12.0
			return clampf(0.72 * pow(2.0, delta * 0.28), 0.3, 1.5)


func _apply_exposure(map: SanMapData, env: Environment) -> void:
	# HDRP exposure (~10–13) → Godot ACES tonemap exposure.
	var ev := map.exposure + map.exposure_compensation * 0.25
	var mapped := 0.95 * pow(2.0, -(ev - 11.5) * 0.22)
	env.tonemap_exposure = clampf(mapped, 0.55, 1.35)
	env.ambient_light_energy = clampf(0.32 + (12.5 - ev) * 0.03, 0.25, 0.55)


func _apply_sun(map: SanMapData) -> void:
	var dir := _sun_direction(map.sun_ra, map.sun_da)
	var center := Vector3(float(map.width) * 0.5, 0.0, float(map.length) * 0.5)
	var pos := center - dir * maxf(float(map.width), float(map.length))
	pos.y = maxf(pos.y, float(map.height) + 80.0)
	sun.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), pos)

	var tint := _dict_color(map.sun_tint, Color.WHITE)
	var kelvin := _temperature_to_color(map.sun_temperature)
	sun.light_color = (kelvin * tint).clamp()
	# Game intensities are HDRP-physical (25k–60k); scale into Godot light energy.
	sun.light_energy = clampf(map.sun_intensity / 52000.0, 0.3, 1.7)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = maxf(float(map.width), float(map.length)) * 3.0
	_apply_sun_cookie(map)

	# Mild skylight contribution when the map provides a non-zero intensity.
	if world_env.environment != null and map.skylight_intensity > 0.01:
		var sky_tint := _dict_color(map.skylight_tint, Color.WHITE)
		var sky_k := _temperature_to_color(map.skylight_temperature)
		world_env.environment.ambient_light_color = (sky_k * sky_tint).clamp()
		world_env.environment.ambient_light_sky_contribution = clampf(
			0.55 + map.skylight_intensity * 0.02, 0.4, 0.95
		)


func _apply_sun_cookie(map: SanMapData) -> void:
	var path := str((map.sun_cookie as Dictionary).get("path", "")).strip_edges()
	if path.is_empty():
		sun.light_projector = null
		return

	var tex: Texture2D = null
	if path == _cached_cookie_path and _cached_cookie_tex != null:
		tex = _cached_cookie_tex
	else:
		# Prefer PNG (Godot Image.load often rejects DDS).
		tex = EnvironmentAssets.load_texture(path.get_basename() + ".png", 1024)
		if tex == null:
			tex = EnvironmentAssets.load_texture(path, 1024)
		_cached_cookie_path = path
		_cached_cookie_tex = tex

	if tex == null:
		sun.light_projector = null
		push_warning("Sun cookie missing locally: %s" % path)
		return

	sun.light_projector = tex
	# Cookie world scale from SanMap sunCookieSize (metres across map).
	var cookie_size: Dictionary = map.sun_cookie_size
	var cx := float(cookie_size.get("x", 1024.0))
	var cy := float(cookie_size.get("y", 1024.0))
	# Directional cookies in Godot use light angular/projector UV; keep soft default.
	sun.light_size = clampf(maxf(cx, cy) / 8000.0, 0.0, 1.0)


func _apply_fog(map: SanMapData, env: Environment) -> void:
	## Approximate HDRP linear + height + background fog with Godot Environment fog.
	var linear_i := maxf(map.linear_fog_intensity, 0.0)
	var height_i := maxf(map.height_fog_intensity, 0.0)
	var bg_i := maxf(map.background_fog_intensity, 0.0)
	var active := linear_i > 0.02 or height_i > 0.05 or bg_i > 0.05
	env.fog_enabled = active
	if not active:
		env.volumetric_fog_enabled = false
		return

	var bg := _dict_color(map.background_color, Color(0.75, 0.78, 0.82))
	# Game backgroundColor is often HDR (>1); tone into a soft fog tint.
	var fog_col := Color(
		clampf(bg.r * 0.48, 0.4, 0.9),
		clampf(bg.g * 0.52, 0.45, 0.92),
		clampf(bg.b * 0.58, 0.5, 0.95),
		1.0
	)
	env.fog_light_color = fog_col
	env.fog_light_energy = clampf(0.45 + linear_i * 0.35 + bg_i * 0.12, 0.35, 1.1)
	env.fog_sun_scatter = clampf(map.sun_volumetrics_multiplier * 0.01, 0.0, 0.25)

	# Godot exponential fog is much denser per-unit than HDRP linear fog — keep soft.
	var atten := maxf(map.fog_attenuation_distance, 80.0)
	var span := maxf(map.linear_fog_end - map.linear_fog_start, 200.0)
	var dens := (linear_i * 0.7) / atten
	dens = dens * 0.5 + (linear_i / span) * 10.0 * 0.35
	dens *= 1.0 + clampf(height_i * 0.08, 0.0, 0.25)
	env.fog_density = clampf(dens, 0.00003, 0.012)

	env.fog_aerial_perspective = clampf(bg_i * 0.25, 0.0, 0.7)
	env.fog_sky_affect = clampf(bg_i * 0.75, 0.0, 1.0)

	env.fog_height = map.fog_base_height
	var h_span := maxf(map.fog_maximum_height - map.fog_base_height, 1.0)
	env.fog_height_density = clampf(height_i / h_span * 0.035, 0.0, 0.2)

	var use_vol := map.sun_volumetrics_multiplier > 1.0 and linear_i > 0.15
	env.volumetric_fog_enabled = use_vol
	if use_vol:
		env.volumetric_fog_density = clampf(
			0.00025 * map.sun_volumetrics_multiplier * linear_i, 0.0, 0.006
		)
		env.volumetric_fog_albedo = fog_col
		env.volumetric_fog_emission = Color(0, 0, 0, 1)
		env.volumetric_fog_anisotropy = clampf(map.fog_anisotropy, -0.9, 0.9)
		env.volumetric_fog_length = minf(map.fog_maximum_distance, 480.0)
		env.volumetric_fog_detail_spread = 0.45
		env.volumetric_fog_sky_affect = clampf(bg_i * 0.25, 0.0, 0.6)
		env.volumetric_fog_gi_inject = 0.0
	else:
		env.volumetric_fog_density = 0.0


func _sun_direction(ra_deg: float, da_deg: float) -> Vector3:
	## RA = azimuth degrees, DA = elevation degrees (from official map values).
	var elev := deg_to_rad(da_deg)
	var az := deg_to_rad(ra_deg)
	var dir := Vector3(
		cos(elev) * sin(az),
		-sin(elev),
		cos(elev) * cos(az)
	)
	if dir.length_squared() < 0.0001:
		return Vector3(0.35, -0.85, 0.4).normalized()
	return dir.normalized()


func _dict_color(value: Variant, fallback: Color) -> Color:
	if typeof(value) != TYPE_DICTIONARY:
		return fallback
	var d: Dictionary = value
	return Color(
		float(d.get("r", fallback.r)),
		float(d.get("g", fallback.g)),
		float(d.get("b", fallback.b)),
		float(d.get("a", fallback.a))
	)


func _temperature_to_color(kelvin: float) -> Color:
	## Approximate blackbody tint for preview (Tanner Helland-ish).
	var temp := clampf(kelvin, 1000.0, 15000.0) / 100.0
	var r := 1.0
	var g := 1.0
	var b := 1.0
	if temp <= 66.0:
		r = 1.0
		g = clampf(0.3900815787690196 * log(temp) - 0.6318414437886275, 0.0, 1.0)
	else:
		r = clampf(1.292936186062745 * pow(temp - 60.0, -0.1332047592), 0.0, 1.0)
		g = clampf(1.129890860895294 * pow(temp - 60.0, -0.0755148492), 0.0, 1.0)
	if temp >= 66.0:
		b = 1.0
	elif temp <= 19.0:
		b = 0.0
	else:
		b = clampf(0.543206789110196 * log(temp - 10.0) - 1.19625408914, 0.0, 1.0)
	return Color(r, g, b, 1.0)
