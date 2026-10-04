shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform sampler2D splat_1_4 : filter_linear, repeat_disable;
uniform sampler2D splat_5_8 : filter_linear, repeat_disable;
uniform sampler2D albedo_0 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_1 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_2 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_3 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_4 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_5 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_6 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_7 : filter_linear_mipmap, repeat_enable;

uniform float map_width = 256.0;
uniform float map_length = 256.0;
uniform float map_height = 128.0;
uniform bool use_textured = false;
uniform vec2 tile_0 = vec2(10.0);
uniform vec2 tile_1 = vec2(8.0);
uniform vec2 tile_2 = vec2(8.0);
uniform vec2 tile_3 = vec2(10.0);
uniform vec2 tile_4 = vec2(12.0);
uniform vec2 tile_5 = vec2(8.0);
uniform vec2 tile_6 = vec2(8.0);
uniform vec2 tile_7 = vec2(8.0);
uniform vec3 albedo_low = vec3(0.22, 0.34, 0.20);
uniform vec3 albedo_high = vec3(0.48, 0.52, 0.36);

varying vec2 world_uv;
varying float slope_factor;

void vertex() {
	ivec2 ts = textureSize(height_tex, 0);
	vec2 texel = 1.0 / max(vec2(ts), vec2(1.0));

	float h = texture(height_tex, UV).r;
	VERTEX.y = h * map_height;
	world_uv = UV;

	float h_l = texture(height_tex, UV + vec2(-texel.x, 0.0)).r;
	float h_r = texture(height_tex, UV + vec2(texel.x, 0.0)).r;
	float h_d = texture(height_tex, UV + vec2(0.0, -texel.y)).r;
	float h_u = texture(height_tex, UV + vec2(0.0, texel.y)).r;

	float step_x = map_width * texel.x;
	float step_z = map_length * texel.y;
	vec3 tangent = vec3(2.0 * step_x, (h_r - h_l) * map_height, 0.0);
	vec3 bitangent = vec3(0.0, (h_u - h_d) * map_height, 2.0 * step_z);
	vec3 n = cross(bitangent, tangent);
	if (length(n) < 1e-5) {
		NORMAL = vec3(0.0, 1.0, 0.0);
		slope_factor = 0.0;
	} else {
		NORMAL = normalize(n);
		slope_factor = clamp(1.0 - NORMAL.y, 0.0, 1.0);
	}

	COLOR = vec4(h, h, h, 1.0);
}

vec3 sample_layer(sampler2D tex, vec2 tile) {
	vec2 world_xz = vec2(world_uv.x * map_width, world_uv.y * map_length);
	vec2 uv = world_xz / max(tile, vec2(0.001));
	return texture(tex, uv).rgb;
}

void fragment() {
	float h = COLOR.r;
	vec3 albedo;
	float roughness;
	if (!use_textured) {
		albedo = mix(albedo_low, albedo_high, clamp(h * 1.35, 0.0, 1.0));
		roughness = 0.92;
	} else {
		vec4 w14 = texture(splat_1_4, world_uv);
		vec4 w58 = texture(splat_5_8, world_uv);
		float w0 = w14.r;
		float w1 = w14.g;
		float w2 = w14.b;
		float w3 = w14.a;
		float w4 = w58.r;
		float w5 = w58.g;
		float w6 = w58.b;
		float w7 = w58.a;
		float sum = w0 + w1 + w2 + w3 + w4 + w5 + w6 + w7;
		if (sum < 0.001) {
			w0 = 1.0;
			sum = 1.0;
		}
		vec3 color = sample_layer(albedo_0, tile_0) * w0;
		color += sample_layer(albedo_1, tile_1) * w1;
		color += sample_layer(albedo_2, tile_2) * w2;
		color += sample_layer(albedo_3, tile_3) * w3;
		color += sample_layer(albedo_4, tile_4) * w4;
		color += sample_layer(albedo_5, tile_5) * w5;
		color += sample_layer(albedo_6, tile_6) * w6;
		color += sample_layer(albedo_7, tile_7) * w7;
		albedo = color / sum;
		// Macro shading similar to in-game: shade slopes / low areas slightly.
		float valley = smoothstep(0.35, 0.0, h);
		albedo *= mix(1.0, 0.78, valley * 0.55 + slope_factor * 0.65);
		roughness = mix(0.78, 0.94, slope_factor);
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
}
