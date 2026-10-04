shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D height_tex : filter_linear, repeat_disable;
// RGB = layers 0..2 (alpha forced opaque for GPU data upload).
uniform sampler2D splat_1_4 : filter_linear, repeat_disable;
// RGB = layers 4..6 (alpha forced opaque for GPU data upload).
uniform sampler2D splat_5_8 : filter_linear, repeat_disable;
// R = layer 3, G = layer 7 — source alpha weights stored as RGB data.
uniform sampler2D splat_extra : filter_linear, repeat_disable;
uniform sampler2D tint_colors : filter_linear, repeat_disable;
uniform sampler2D tint_geometry : filter_linear, repeat_disable;

uniform sampler2D albedo_0 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_1 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_2 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_3 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_4 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_5 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_6 : filter_linear_mipmap, repeat_enable;
uniform sampler2D albedo_7 : filter_linear_mipmap, repeat_enable;

uniform sampler2D normal_0 : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_1 : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_2 : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_3 : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_4 : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_5 : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_6 : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_7 : filter_linear_mipmap, repeat_enable;

uniform sampler2D mask_0 : filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_1 : filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_2 : filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_3 : filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_4 : filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_5 : filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_6 : filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_7 : filter_linear_mipmap, repeat_enable;

uniform float map_width = 256.0;
uniform float map_length = 256.0;
uniform float map_height = 128.0;
uniform float water_level = 0.0;
uniform bool has_water = false;
uniform bool use_textured = false;
uniform bool use_tint = true;

uniform vec2 tile_0 = vec2(10.0);
uniform vec2 tile_1 = vec2(8.0);
uniform vec2 tile_2 = vec2(8.0);
uniform vec2 tile_3 = vec2(10.0);
uniform vec2 tile_4 = vec2(12.0);
uniform vec2 tile_5 = vec2(8.0);
uniform vec2 tile_6 = vec2(8.0);
uniform vec2 tile_7 = vec2(8.0);

uniform vec2 tile_far_0 = vec2(40.0);
uniform vec2 tile_far_1 = vec2(32.0);
uniform vec2 tile_far_2 = vec2(32.0);
uniform vec2 tile_far_3 = vec2(40.0);
uniform vec2 tile_far_4 = vec2(48.0);
uniform vec2 tile_far_5 = vec2(32.0);
uniform vec2 tile_far_6 = vec2(32.0);
uniform vec2 tile_far_7 = vec2(32.0);

uniform float tile_tri_0 = 12.0;
uniform float tile_tri_1 = 12.0;
uniform float tile_tri_2 = 12.0;
uniform float tile_tri_3 = 12.0;
uniform float tile_tri_4 = 12.0;
uniform float tile_tri_5 = 12.0;
uniform float tile_tri_6 = 12.0;
uniform float tile_tri_7 = 12.0;

uniform float tile_tri_far_0 = 36.0;
uniform float tile_tri_far_1 = 36.0;
uniform float tile_tri_far_2 = 36.0;
uniform float tile_tri_far_3 = 36.0;
uniform float tile_tri_far_4 = 36.0;
uniform float tile_tri_far_5 = 36.0;
uniform float tile_tri_far_6 = 36.0;
uniform float tile_tri_far_7 = 36.0;

// HDRP-style remaps (defaults = identity-ish).
uniform vec4 diffuse_remap_0 = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 diffuse_remap_1 = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 diffuse_remap_2 = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 diffuse_remap_3 = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 diffuse_remap_4 = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 diffuse_remap_5 = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 diffuse_remap_6 = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 diffuse_remap_7 = vec4(0.5, 0.5, 0.5, 1.0);

uniform vec4 far_color_remap_0 = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 far_color_remap_1 = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 far_color_remap_2 = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 far_color_remap_3 = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 far_color_remap_4 = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 far_color_remap_5 = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 far_color_remap_6 = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 far_color_remap_7 = vec4(1.0, 1.0, 1.0, 0.0);

uniform vec4 mask_remap_min_0 = vec4(0.0);
uniform vec4 mask_remap_min_1 = vec4(0.0);
uniform vec4 mask_remap_min_2 = vec4(0.0);
uniform vec4 mask_remap_min_3 = vec4(0.0);
uniform vec4 mask_remap_min_4 = vec4(0.0);
uniform vec4 mask_remap_min_5 = vec4(0.0);
uniform vec4 mask_remap_min_6 = vec4(0.0);
uniform vec4 mask_remap_min_7 = vec4(0.0);

uniform vec4 mask_remap_max_0 = vec4(1.0);
uniform vec4 mask_remap_max_1 = vec4(1.0);
uniform vec4 mask_remap_max_2 = vec4(1.0);
uniform vec4 mask_remap_max_3 = vec4(1.0);
uniform vec4 mask_remap_max_4 = vec4(1.0);
uniform vec4 mask_remap_max_5 = vec4(1.0);
uniform vec4 mask_remap_max_6 = vec4(1.0);
uniform vec4 mask_remap_max_7 = vec4(1.0);

uniform float normal_scale_0 = 1.0;
uniform float normal_scale_1 = 1.0;
uniform float normal_scale_2 = 1.0;
uniform float normal_scale_3 = 1.0;
uniform float normal_scale_4 = 1.0;
uniform float normal_scale_5 = 1.0;
uniform float normal_scale_6 = 1.0;
uniform float normal_scale_7 = 1.0;

uniform float normal_scale_far_0 = 1.0;
uniform float normal_scale_far_1 = 1.0;
uniform float normal_scale_far_2 = 1.0;
uniform float normal_scale_far_3 = 1.0;
uniform float normal_scale_far_4 = 1.0;
uniform float normal_scale_far_5 = 1.0;
uniform float normal_scale_far_6 = 1.0;
uniform float normal_scale_far_7 = 1.0;

uniform float normal_far_near_blend_0 = 0.5;
uniform float normal_far_near_blend_1 = 0.5;
uniform float normal_far_near_blend_2 = 0.5;
uniform float normal_far_near_blend_3 = 0.5;
uniform float normal_far_near_blend_4 = 0.5;
uniform float normal_far_near_blend_5 = 0.5;
uniform float normal_far_near_blend_6 = 0.5;
uniform float normal_far_near_blend_7 = 0.5;

uniform float height_transition = 0.5;
uniform float height_far_near_blend = 0.5;

uniform float far_blend_start = 40.0;
uniform float far_blend_end = 180.0;
uniform float triplanar_sharpen = 4.0;

uniform vec3 albedo_low = vec3(0.22, 0.34, 0.20);
uniform vec3 albedo_high = vec3(0.48, 0.52, 0.36);

varying vec2 world_uv;
varying vec3 world_pos;
varying vec3 world_normal;
varying float slope_factor;
varying float view_dist;

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
		world_normal = vec3(0.0, 1.0, 0.0);
		slope_factor = 0.0;
	} else {
		world_normal = normalize(n);
		slope_factor = clamp(1.0 - world_normal.y, 0.0, 1.0);
	}
	NORMAL = world_normal;

	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	view_dist = length((VIEW_MATRIX * vec4(world_pos, 1.0)).xyz);
	COLOR = vec4(h, h, h, 1.0);
}

vec3 sample_planar(sampler2D tex, vec2 tile) {
	vec2 uv = world_pos.xz / max(tile, vec2(0.001));
	return texture(tex, uv).rgb;
}

vec3 sample_triplanar(sampler2D tex, float tile) {
	float t = max(tile, 0.001);
	vec3 blend = pow(abs(world_normal), vec3(triplanar_sharpen));
	blend /= max(blend.x + blend.y + blend.z, 1e-5);
	vec3 x_proj = texture(tex, world_pos.zy / t).rgb;
	vec3 y_proj = texture(tex, world_pos.xz / t).rgb;
	vec3 z_proj = texture(tex, world_pos.xy / t).rgb;
	return x_proj * blend.x + y_proj * blend.y + z_proj * blend.z;
}

vec3 sample_albedo_layer(sampler2D tex, vec2 tile_near, vec2 tile_far, float tile_tri, float tile_tri_far, float far_w) {
	vec3 near_c = sample_planar(tex, tile_near);
	vec3 far_c = sample_planar(tex, tile_far);
	vec3 planar = mix(near_c, far_c, far_w);
	float slope_w = smoothstep(0.35, 0.75, slope_factor);
	if (slope_w < 0.001) {
		return planar;
	}
	float tri_tile = mix(tile_tri, tile_tri_far, far_w);
	vec3 tri = sample_triplanar(tex, tri_tile);
	return mix(planar, tri, slope_w);
}

vec3 sample_normal_layer(sampler2D tex, vec2 tile_near, vec2 tile_far, float tile_tri, float tile_tri_far, float far_w) {
	vec3 near_n = sample_planar(tex, tile_near);
	vec3 far_n = sample_planar(tex, tile_far);
	vec3 planar = mix(near_n, far_n, far_w);
	float slope_w = smoothstep(0.35, 0.75, slope_factor);
	if (slope_w < 0.001) {
		return planar;
	}
	float tri_tile = mix(tile_tri, tile_tri_far, far_w);
	vec3 tri = sample_triplanar(tex, tri_tile);
	return mix(planar, tri, slope_w);
}

vec4 sample_mask_layer(sampler2D tex, vec2 tile_near, vec2 tile_far, float far_w) {
	vec2 uv_n = world_pos.xz / max(tile_near, vec2(0.001));
	vec2 uv_f = world_pos.xz / max(tile_far, vec2(0.001));
	return mix(texture(tex, uv_n), texture(tex, uv_f), far_w);
}

vec3 unpack_normal(vec3 packed_n) {
	return normalize(packed_n * 2.0 - 1.0);
}

vec3 apply_diffuse_remap(vec3 albedo, vec4 remap) {
	// HDRP-ish: mid-gray remap.rgb (0.5) ≈ identity via *2; alpha scales influence.
	vec3 remapped = albedo * remap.rgb * 2.0;
	return mix(albedo, remapped, clamp(remap.a, 0.0, 1.0));
}

vec3 apply_far_color(vec3 albedo, vec4 far_remap, float far_w) {
	float w = far_w * clamp(far_remap.a, 0.0, 1.0);
	return mix(albedo, albedo * far_remap.rgb, w);
}

vec4 apply_mask_remap(vec4 mask, vec4 remap_min, vec4 remap_max) {
	vec4 span = max(remap_max - remap_min, vec4(1e-4));
	return clamp((mask - remap_min) / span, vec4(0.0), vec4(1.0));
}

float layer_height_proxy(vec4 mask_remapped, vec3 albedo) {
	// Prefer remapped detail (B); fall back toward albedo luminance.
	float detail_h = mask_remapped.b;
	float luma = dot(albedo, vec3(0.299, 0.587, 0.114));
	return mix(luma, detail_h, 0.65);
}

void height_blend_weights(
	inout float w0, inout float w1, inout float w2, inout float w3,
	inout float w4, inout float w5, inout float w6, inout float w7,
	float h0, float h1, float h2, float h3, float h4, float h5, float h6, float h7,
	float transition
) {
	float t = max(transition, 0.02);
	float hh0 = w0 * h0;
	float hh1 = w1 * h1;
	float hh2 = w2 * h2;
	float hh3 = w3 * h3;
	float hh4 = w4 * h4;
	float hh5 = w5 * h5;
	float hh6 = w6 * h6;
	float hh7 = w7 * h7;
	float max_h = max(max(max(hh0, hh1), max(hh2, hh3)), max(max(hh4, hh5), max(hh6, hh7)));
	w0 = max(hh0 - max_h + t, 0.0);
	w1 = max(hh1 - max_h + t, 0.0);
	w2 = max(hh2 - max_h + t, 0.0);
	w3 = max(hh3 - max_h + t, 0.0);
	w4 = max(hh4 - max_h + t, 0.0);
	w5 = max(hh5 - max_h + t, 0.0);
	w6 = max(hh6 - max_h + t, 0.0);
	w7 = max(hh7 - max_h + t, 0.0);
	float sum = w0 + w1 + w2 + w3 + w4 + w5 + w6 + w7;
	if (sum < 1e-5) {
		w0 = 1.0;
		return;
	}
	float inv = 1.0 / sum;
	w0 *= inv;
	w1 *= inv;
	w2 *= inv;
	w3 *= inv;
	w4 *= inv;
	w5 *= inv;
	w6 *= inv;
	w7 *= inv;
}

void fragment() {
	float h = COLOR.r;
	vec3 albedo;
	float roughness = 0.85;
	float metallic = 0.0;
	float ao = 1.0;
	float specular = 0.22;
	vec3 n_world = normalize(world_normal);

	if (!use_textured) {
		albedo = mix(albedo_low, albedo_high, clamp(h * 1.35, 0.0, 1.0));
		roughness = 0.92;
	} else {
		vec4 w14 = texture(splat_1_4, world_uv);
		vec4 w58 = texture(splat_5_8, world_uv);
		vec4 wex = texture(splat_extra, world_uv);
		float w0 = w14.r;
		float w1 = w14.g;
		float w2 = w14.b;
		float w3 = wex.r;
		float w4 = w58.r;
		float w5 = w58.g;
		float w6 = w58.b;
		float w7 = wex.g;
		float sum = w0 + w1 + w2 + w3 + w4 + w5 + w6 + w7;
		if (sum < 0.001) {
			w0 = 1.0;
			sum = 1.0;
		} else {
			float inv = 1.0 / sum;
			w0 *= inv;
			w1 *= inv;
			w2 *= inv;
			w3 *= inv;
			w4 *= inv;
			w5 *= inv;
			w6 *= inv;
			w7 *= inv;
		}

		float far_w = smoothstep(far_blend_start, far_blend_end, view_dist);

		vec3 a0 = sample_albedo_layer(albedo_0, tile_0, tile_far_0, tile_tri_0, tile_tri_far_0, far_w);
		vec3 a1 = sample_albedo_layer(albedo_1, tile_1, tile_far_1, tile_tri_1, tile_tri_far_1, far_w);
		vec3 a2 = sample_albedo_layer(albedo_2, tile_2, tile_far_2, tile_tri_2, tile_tri_far_2, far_w);
		vec3 a3 = sample_albedo_layer(albedo_3, tile_3, tile_far_3, tile_tri_3, tile_tri_far_3, far_w);
		vec3 a4 = sample_albedo_layer(albedo_4, tile_4, tile_far_4, tile_tri_4, tile_tri_far_4, far_w);
		vec3 a5 = sample_albedo_layer(albedo_5, tile_5, tile_far_5, tile_tri_5, tile_tri_far_5, far_w);
		vec3 a6 = sample_albedo_layer(albedo_6, tile_6, tile_far_6, tile_tri_6, tile_tri_far_6, far_w);
		vec3 a7 = sample_albedo_layer(albedo_7, tile_7, tile_far_7, tile_tri_7, tile_tri_far_7, far_w);

		vec4 m0 = apply_mask_remap(sample_mask_layer(mask_0, tile_0, tile_far_0, far_w), mask_remap_min_0, mask_remap_max_0);
		vec4 m1 = apply_mask_remap(sample_mask_layer(mask_1, tile_1, tile_far_1, far_w), mask_remap_min_1, mask_remap_max_1);
		vec4 m2 = apply_mask_remap(sample_mask_layer(mask_2, tile_2, tile_far_2, far_w), mask_remap_min_2, mask_remap_max_2);
		vec4 m3 = apply_mask_remap(sample_mask_layer(mask_3, tile_3, tile_far_3, far_w), mask_remap_min_3, mask_remap_max_3);
		vec4 m4 = apply_mask_remap(sample_mask_layer(mask_4, tile_4, tile_far_4, far_w), mask_remap_min_4, mask_remap_max_4);
		vec4 m5 = apply_mask_remap(sample_mask_layer(mask_5, tile_5, tile_far_5, far_w), mask_remap_min_5, mask_remap_max_5);
		vec4 m6 = apply_mask_remap(sample_mask_layer(mask_6, tile_6, tile_far_6, far_w), mask_remap_min_6, mask_remap_max_6);
		vec4 m7 = apply_mask_remap(sample_mask_layer(mask_7, tile_7, tile_far_7, far_w), mask_remap_min_7, mask_remap_max_7);

		float blend_t = mix(height_transition, height_transition * (0.35 + height_far_near_blend), far_w);
		height_blend_weights(
			w0, w1, w2, w3, w4, w5, w6, w7,
			layer_height_proxy(m0, a0), layer_height_proxy(m1, a1),
			layer_height_proxy(m2, a2), layer_height_proxy(m3, a3),
			layer_height_proxy(m4, a4), layer_height_proxy(m5, a5),
			layer_height_proxy(m6, a6), layer_height_proxy(m7, a7),
			blend_t
		);

		a0 = apply_far_color(apply_diffuse_remap(a0, diffuse_remap_0), far_color_remap_0, far_w);
		a1 = apply_far_color(apply_diffuse_remap(a1, diffuse_remap_1), far_color_remap_1, far_w);
		a2 = apply_far_color(apply_diffuse_remap(a2, diffuse_remap_2), far_color_remap_2, far_w);
		a3 = apply_far_color(apply_diffuse_remap(a3, diffuse_remap_3), far_color_remap_3, far_w);
		a4 = apply_far_color(apply_diffuse_remap(a4, diffuse_remap_4), far_color_remap_4, far_w);
		a5 = apply_far_color(apply_diffuse_remap(a5, diffuse_remap_5), far_color_remap_5, far_w);
		a6 = apply_far_color(apply_diffuse_remap(a6, diffuse_remap_6), far_color_remap_6, far_w);
		a7 = apply_far_color(apply_diffuse_remap(a7, diffuse_remap_7), far_color_remap_7, far_w);

		albedo = a0 * w0 + a1 * w1 + a2 * w2 + a3 * w3 + a4 * w4 + a5 * w5 + a6 * w6 + a7 * w7;

		float ns0 = mix(normal_scale_0, normal_scale_far_0, far_w * normal_far_near_blend_0);
		float ns1 = mix(normal_scale_1, normal_scale_far_1, far_w * normal_far_near_blend_1);
		float ns2 = mix(normal_scale_2, normal_scale_far_2, far_w * normal_far_near_blend_2);
		float ns3 = mix(normal_scale_3, normal_scale_far_3, far_w * normal_far_near_blend_3);
		float ns4 = mix(normal_scale_4, normal_scale_far_4, far_w * normal_far_near_blend_4);
		float ns5 = mix(normal_scale_5, normal_scale_far_5, far_w * normal_far_near_blend_5);
		float ns6 = mix(normal_scale_6, normal_scale_far_6, far_w * normal_far_near_blend_6);
		float ns7 = mix(normal_scale_7, normal_scale_far_7, far_w * normal_far_near_blend_7);
		float n_strength = ns0 * w0 + ns1 * w1 + ns2 * w2 + ns3 * w3 + ns4 * w4 + ns5 * w5 + ns6 * w6 + ns7 * w7;
		n_strength = clamp(n_strength, 0.0, 2.0);

		vec3 n_accum = vec3(0.0);
		n_accum += unpack_normal(sample_normal_layer(normal_0, tile_0, tile_far_0, tile_tri_0, tile_tri_far_0, far_w)) * w0;
		n_accum += unpack_normal(sample_normal_layer(normal_1, tile_1, tile_far_1, tile_tri_1, tile_tri_far_1, far_w)) * w1;
		n_accum += unpack_normal(sample_normal_layer(normal_2, tile_2, tile_far_2, tile_tri_2, tile_tri_far_2, far_w)) * w2;
		n_accum += unpack_normal(sample_normal_layer(normal_3, tile_3, tile_far_3, tile_tri_3, tile_tri_far_3, far_w)) * w3;
		n_accum += unpack_normal(sample_normal_layer(normal_4, tile_4, tile_far_4, tile_tri_4, tile_tri_far_4, far_w)) * w4;
		n_accum += unpack_normal(sample_normal_layer(normal_5, tile_5, tile_far_5, tile_tri_5, tile_tri_far_5, far_w)) * w5;
		n_accum += unpack_normal(sample_normal_layer(normal_6, tile_6, tile_far_6, tile_tri_6, tile_tri_far_6, far_w)) * w6;
		n_accum += unpack_normal(sample_normal_layer(normal_7, tile_7, tile_far_7, tile_tri_7, tile_tri_far_7, far_w)) * w7;

		vec3 detail_n = normalize(n_accum);
		vec3 blend_n = normalize(mix(vec3(0.0, 1.0, 0.0), detail_n.xzy, clamp(n_strength, 0.0, 1.0)));
		n_world = normalize(mix(n_world, normalize(n_world + blend_n * 0.7), clamp(n_strength, 0.0, 1.25)));

		// Sanctuary / HDRP Lit mask: R=metallic, G=AO, B=detail, A=smoothness.
		// Editor preview ignores mask smoothness/metallic — rock masks (esp. layer 7)
		// still mirror the skybox if A drives roughness/specular under HDR IBL.
		// B stays used only for height blend via layer_height_proxy.
		vec4 m = m0 * w0 + m1 * w1 + m2 * w2 + m3 * w3 + m4 * w4 + m5 * w5 + m6 * w6 + m7 * w7;
		ao = clamp(m.g, 0.45, 1.0);
		metallic = 0.0;
		roughness = 0.92;
		specular = 0.08;

		if (use_tint) {
			vec4 tint = texture(tint_colors, world_uv);
			if (tint.a < 0.02) {
				discard;
			}
			albedo *= clamp(tint.rgb * 2.0, vec3(0.15), vec3(2.5));
			vec3 geo = texture(tint_geometry, world_uv).rgb;
			vec3 geo_n = unpack_normal(geo);
			n_world = normalize(mix(n_world, normalize(n_world + geo_n.xzy * 0.35), 0.35));
		}

		float valley = smoothstep(0.35, 0.0, h);
		albedo *= mix(1.0, 0.82, valley * 0.45 + slope_factor * 0.35);
		albedo *= ao;

		// Wetness near / under water level (world Y) — darken albedo only, keep matte.
		if (has_water) {
			float world_y = h * map_height;
			float wet = 1.0 - smoothstep(water_level - 1.5, water_level + 2.5, world_y);
			albedo *= mix(1.0, 0.72, wet);
		}
	}

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
}
