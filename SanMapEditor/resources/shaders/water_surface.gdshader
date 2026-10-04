shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_albedo = false;
uniform bool has_normal = false;

uniform vec4 shallow_color : source_color = vec4(0.18, 0.42, 0.48, 0.55);
uniform vec4 deep_color : source_color = vec4(0.05, 0.16, 0.28, 0.82);
uniform float water_depth = 8.0;
uniform float wind_speed = 0.25;
uniform float wind_direction_deg = 160.0;
uniform float tile_scale = 0.035;
uniform float normal_strength = 0.85;
uniform float roughness_val = 0.08;
uniform float metallic_val = 0.15;
uniform float fresnel_power = 3.5;


void fragment() {
	vec2 wind_dir = vec2(
		sin(radians(wind_direction_deg)),
		cos(radians(wind_direction_deg))
	);
	float speed = max(wind_speed, 0.02) * 0.12;
	vec2 uv_a = UV * (1.0 / max(tile_scale, 0.001)) + wind_dir * TIME * speed;
	vec2 uv_b = UV * (1.0 / max(tile_scale, 0.001)) * 0.63 - wind_dir * TIME * speed * 0.65;

	vec3 base_col = mix(shallow_color.rgb, deep_color.rgb, clamp(water_depth / 12.0, 0.0, 1.0));
	float alpha = mix(shallow_color.a, deep_color.a, clamp(water_depth / 10.0, 0.0, 1.0));

	if (has_albedo) {
		vec3 tex_a = texture(albedo_tex, uv_a).rgb;
		vec3 tex_b = texture(albedo_tex, uv_b).rgb;
		base_col = mix(base_col, (tex_a + tex_b) * 0.5 * base_col * 1.6, 0.55);
	}

	vec3 n = vec3(0.0, 0.0, 1.0);
	if (has_normal) {
		vec3 n1 = texture(normal_tex, uv_a).xyz * 2.0 - 1.0;
		vec3 n2 = texture(normal_tex, uv_b).xyz * 2.0 - 1.0;
		n = normalize(vec3((n1.xy + n2.xy) * normal_strength, 1.0));
	} else {
		// Procedural ripple when textures are missing.
		float r1 = sin(uv_a.x * 18.0 + TIME * speed * 40.0) * cos(uv_a.y * 14.0 - TIME * speed * 28.0);
		float r2 = sin(uv_b.x * 11.0 - TIME * speed * 22.0) * cos(uv_b.y * 16.0 + TIME * speed * 18.0);
		n = normalize(vec3((r1 + r2 * 0.6) * 0.18 * normal_strength, (r2 - r1 * 0.4) * 0.18 * normal_strength, 1.0));
	}

	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = normal_strength;

	float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), fresnel_power);
	ALBEDO = mix(base_col, deep_color.rgb, fresnel * 0.35);
	ALPHA = clamp(alpha + fresnel * 0.25, 0.25, 0.92);
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;
	SPECULAR = 0.6;
}
