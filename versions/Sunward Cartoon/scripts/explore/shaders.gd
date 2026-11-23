class_name ExploreShaders
extends RefCounted
## Small shaders for the planet environments (all work with the Compatibility renderer).

static var _cache := {}

const NOISE_FUNCS := """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
"""

## Ocean: moving waves, fresnel, a bit see-through
const WATER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always;
uniform vec4 deep : source_color = vec4(0.05, 0.25, 0.45, 1.0);
uniform vec4 shallow : source_color = vec4(0.2, 0.7, 0.8, 1.0);
uniform float wave = 0.35;
uniform float clarity = 0.72;
varying float h;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float a = w.x * 0.35 + TIME * 1.3;
	float b = w.z * 0.27 + w.x * 0.1 + TIME * 1.1;
	float c = (w.x + w.z) * 0.8 + TIME * 2.3;
	h = sin(a) * 0.5 + sin(b) * 0.5 + sin(c) * 0.15;
	VERTEX.y += h * wave;
	float dx = cos(a) * 0.175 + cos(b) * 0.05 + cos(c) * 0.12;
	float dz = cos(b) * 0.135 + cos(c) * 0.12;
	NORMAL = normalize(vec3(-dx * wave, 1.0, -dz * wave));
}
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep.rgb, shallow.rgb, clamp(h * 0.5 + 0.5, 0.0, 1.0) * 0.5);
	ALPHA = mix(clarity, 1.0, f);
	ROUGHNESS = 0.06;
	METALLIC = 0.15;
	SPECULAR = 0.9;
}
"""

## Lava: glowing, slowly flowing, with dark crust
const LAVA := """
shader_type spatial;
render_mode unshaded;
uniform vec4 hot : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 crust : source_color = vec4(0.18, 0.05, 0.02, 1.0);
varying vec3 wp;
""" + NOISE_FUNCS + """
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wp.x * 0.4 + TIME) * 0.04;
}
void fragment() {
	vec2 p = wp.xz * 0.12;
	float n = fbm(p + vec2(TIME * 0.04, TIME * 0.025)) * 0.65 + noise(p * 3.1 - vec2(TIME * 0.09, 0.0)) * 0.35;
	float c = smoothstep(0.5, 0.72, n);
	float glow = 1.6 + 0.4 * sin(TIME * 1.7 + wp.x * 0.2);
	ALBEDO = mix(hot.rgb * glow, crust.rgb, c);
}
"""

## Plants, mushrooms, crystals: optional swaying in the wind and pulsing glow
const NATURE := """
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 1.0;
uniform float pulse = 0.0;
uniform float sway = 0.0;
uniform float roughness = 0.8;
uniform float metallic = 0.0;
global uniform float sw_wind;
global uniform float sw_wet;
global uniform float sw_snow;
varying float phase;
varying float top;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	top = dot(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz), normalize(o));
	phase = o.x * 0.37 + o.z * 0.23;
	float k = sway * (1.0 + VERTEX.y * 0.15) * (0.5 + sw_wind);
	VERTEX.x += sin(TIME * 1.6 + phase) * k;
	VERTEX.z += cos(TIME * 1.25 + phase * 1.3) * k * 0.6;
}
// naturalistic greens: a green colour is pulled towards a palette of deep forest, leaf,
// emerald and olive greens (picked per plant, keeping its light / dark detail); colours that
// are not green (fungi, ice, crystals, flowers) are left alone
vec3 rich_green(vec3 c, vec3 org) {
	float g_k = clamp((c.g - max(c.r, c.b)) * 5.0, 0.0, 1.0);
	if (g_k <= 0.0) { return c; }
	float pick = fract(sin(dot(floor(org * 1.7), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	vec3 forest = vec3(0.055, 0.18, 0.065);
	vec3 leafg = vec3(0.13, 0.32, 0.08);
	vec3 emerald = vec3(0.04, 0.29, 0.15);
	vec3 olive = vec3(0.24, 0.29, 0.07);
	vec3 pal = pick < 0.3 ? forest : (pick < 0.6 ? leafg : (pick < 0.82 ? emerald : olive));
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 target = pal * (0.45 + lum * 1.35);
	return mix(c, target, g_k * 0.8);
}
// cartoon: much stronger colours (saturation up, a little brighter)
vec3 vivid(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return clamp(mix(vec3(l), c, 1.6) * 1.1 + 0.015, 0.0, 4.0);
}
void fragment() {
	float sn = smoothstep(0.35, 0.8, top) * sw_snow;
	ALBEDO = vivid(mix(rich_green(albedo.rgb, MODEL_MATRIX[3].xyz) * (1.0 - sw_wet * 0.25), vec3(0.93, 0.96, 1.0), sn));
	ROUGHNESS = mix(roughness * (1.0 - sw_wet * 0.6), 0.85, sn);
	METALLIC = metallic;
	float p = 1.0 + pulse * sin(TIME * 2.2 + phase * 3.0);
	EMISSION = emission.rgb * emission_energy * p;
}
"""

## Drifting cloud layer high in the sky (flash = lightning)
const CLOUDS := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 color : source_color = vec4(0.2, 0.2, 0.3, 0.9);
uniform float speed = 0.012;
uniform float cover = 0.42;
uniform float flash = 0.0;
varying vec3 wp;
""" + NOISE_FUNCS + """
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wp.xz * 0.006 + vec2(TIME * speed, TIME * speed * 0.6);
	float n = fbm(p);
	float a = smoothstep(cover, cover + 0.28, n);
	float edge = 1.0 - smoothstep(500.0, 1100.0, length(wp.xz));
	ALBEDO = color.rgb * (0.7 + 0.6 * n) + vec3(0.75, 0.75, 1.0) * flash * a;
	ALPHA = a * edge * color.a;
}
"""

## Holographic parts of constructions and the beam of the landing pod
const HOLO := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 color : source_color = vec4(0.2, 0.85, 1.0, 0.6);
uniform float stripes = 30.0;
uniform float fade_top = 1.0;
void fragment() {
	float s = 0.65 + 0.35 * sin(UV.y * stripes - TIME * 4.0);
	ALBEDO = color.rgb * s;
	ALPHA = color.a * s * mix(1.0, UV.y, fade_top);
}
"""

## Heat haze over the whole screen (Ferrum, Solara)
const HAZE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.003;
void fragment() {
	vec2 uv = SCREEN_UV;
	float k = smoothstep(0.25, 0.75, uv.y);
	vec2 off = vec2(sin(uv.y * 85.0 + TIME * 4.0), cos(uv.x * 60.0 + TIME * 3.3)) * strength * k;
	COLOR = texture(screen_tex, uv + off);
}
"""

const NOISE3 := """
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}
float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise3(p); p *= 2.03; a *= 0.5; }
	return v;
}
"""

## Ocean around a round planet. Waves get bigger with wind and storms (wave, chop), rain makes
## small rings, and up to 8 "ripples" (splashes, the capsule's wake, leaping animals) send rings
## outwards that fade away. ripples[i] = (position, start time), ripple_str[i] = strength.
## Sky reflection follows the time of day (day), sun glints come from the real sun light.
const WATER_SPHERE := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always;
uniform vec4 deep : source_color = vec4(0.05, 0.25, 0.45, 1.0);
uniform vec4 shallow : source_color = vec4(0.2, 0.7, 0.8, 1.0);
uniform vec4 sky_col : source_color = vec4(0.4, 0.6, 0.9, 1.0);
uniform vec4 horizon_col : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float wave = 0.3;
uniform float chop = 0.0;
uniform float rain = 0.0;
uniform float clarity = 0.7;
uniform float day = 1.0;
uniform float now = 0.0;
uniform vec4 ripples[8];
uniform float ripple_str[8];
varying float h;
varying vec3 wp;
float rings(vec3 p) {
	float sum = 0.0;
	for (int i = 0; i < 8; i++) {
		float age = now - ripples[i].w;
		if (ripple_str[i] <= 0.0 || age < 0.0 || age > 7.0) { continue; }
		float d = distance(p, ripples[i].xyz);
		float front = age * 5.5;
		float k = d - front;
		sum += sin(k * 1.7) * exp(-abs(k) * 0.55) * ripple_str[i] * exp(-age * 0.55) / (1.0 + d * 0.12);
	}
	return sum;
}
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = now;
	h = sin(w.x * 0.35 + t * 1.3) * 0.5 + sin(w.z * 0.27 + w.y * 0.2 + t * 1.1) * 0.5 + sin((w.x + w.y + w.z) * 0.6 + t * 2.0) * 0.15;
	h += chop * (sin(w.x * 0.9 - t * 2.7 + w.y * 0.4) * 0.6 + sin(w.z * 1.3 + t * 3.1) * 0.4);
	float r = rings(w);
	VERTEX += NORMAL * (h * wave + r * 0.45);
	h += r;
	wp = w;
}
void fragment() {
	vec3 up = normalize(wp);
	float t = now;
	vec3 rip = vec3(sin(wp.x * 1.7 + t * 2.1) + sin(wp.z * 2.3 - t * 1.7),
		sin(wp.y * 1.9 + t * 1.5) + sin(wp.x * 0.9 + wp.z * 1.1 + t * 1.2),
		cos(wp.x * 2.1 - t * 1.9) + sin(wp.y * 1.3 + t * 2.4));
	// rain drops: small expanding rings in a grid of cells
	vec2 rc = vec2(wp.x + wp.y * 0.5, wp.z - wp.y * 0.5) * 1.6;
	vec2 cell = floor(rc);
	float phase = fract(t * 1.3 + fract(sin(dot(cell, vec2(12.9, 78.2))) * 437.5));
	float dist = length(fract(rc) - 0.5);
	float drop = rain * (1.0 - smoothstep(0.0, 0.05, abs(dist - phase * 0.45))) * (1.0 - phase);
	float r = rings(wp);
	vec3 n = normalize(up + rip * (0.03 + chop * 0.04) + vec3(drop * 0.5, 0.0, drop * 0.5) + vec3(r * 0.25, r * 0.15, -r * 0.2));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 water = mix(deep.rgb, shallow.rgb, clamp(h * 0.5 + 0.5, 0.0, 1.0) * 0.45);
	float foam = clamp(abs(r) * 1.4 - 0.25, 0.0, 1.0) + clamp((h - 0.9) * chop * 1.5, 0.0, 1.0) + drop * 0.6;
	water = mix(water, vec3(0.92, 0.96, 1.0), clamp(foam, 0.0, 0.9));
	vec3 refl = mix(sky_col.rgb, horizon_col.rgb, f);
	ALBEDO = water;
	EMISSION = refl * f * (0.05 + 0.6 * day);
	ALPHA = mix(clarity, 1.0, max(f, foam));
	ROUGHNESS = 0.03 + chop * 0.08 + foam * 0.5;
	METALLIC = 0.1;
	SPECULAR = 1.0;
	if (!FRONT_FACING) {
		// seen from under the water: a bright, rippling window straight up, darker at an angle
		// (total reflection), with moving light patterns
		vec3 nb = -NORMAL;
		float straight = clamp(dot(nb, VIEW), 0.0, 1.0);
		float window = smoothstep(0.55, 0.85, straight);
		float caust = 0.5 + 0.5 * sin(wp.x * 2.3 + t * 1.6 + sin(wp.z * 1.7 + t)) * sin(wp.z * 2.1 - t * 1.3);
		vec3 under = mix(deep.rgb * 0.35, mix(shallow.rgb, sky_col.rgb, 0.5) * (0.6 + 0.4 * caust), window);
		NORMAL = nb;
		ALBEDO = under * 0.4;
		EMISSION = under * (0.15 + 0.85 * day) * (0.5 + window);
		ALPHA = 0.92;
		SPECULAR = 0.2;
	}
}
"""

## Lava around a round planet
const LAVA_SPHERE := """
shader_type spatial;
render_mode unshaded;
uniform vec4 hot : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 crust : source_color = vec4(0.18, 0.05, 0.02, 1.0);
varying vec3 wp;
""" + NOISE3 + """
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 p = wp * 0.12;
	float n = fbm3(p + vec3(TIME * 0.04, TIME * 0.025, 0.0)) * 0.65 + noise3(p * 3.1 - vec3(TIME * 0.09, 0.0, 0.0)) * 0.35;
	float c = smoothstep(0.5, 0.72, n);
	float glow = 1.6 + 0.4 * sin(TIME * 1.7 + wp.x * 0.2);
	ALBEDO = mix(hot.rgb * glow, crust.rgb, c);
}
"""

## Cloud shell around a round planet (lit by the sun, flash = lightning)
const CLOUD_SHELL := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float cover = 0.5;
uniform float speed = 0.01;
uniform float flash = 0.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
varying vec3 wp;
""" + NOISE3 + """
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 d = normalize(wp);
	float n = fbm3(d * 6.0 + vec3(TIME * speed, 0.0, TIME * speed * 0.7));
	float a = smoothstep(cover, cover + 0.25, n);
	float light = clamp(dot(d, sun_dir) * 1.3 + 0.35, 0.08, 1.0);
	ALBEDO = color.rgb * (0.7 + 0.6 * n) * light + vec3(0.75, 0.75, 1.0) * flash * a;
	ALPHA = a * color.a;
}
"""

## Atmosphere: a glowing shell. Seen from the ground it is the sky (dark on the night side),
## seen from above it is a thin glowing rim around the planet.
const ATMOSPHERE := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, fog_disabled;
uniform vec4 sky_color : source_color = vec4(0.3, 0.5, 0.9, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float planet_r = 100.0;
uniform float atmo_r = 140.0;
uniform float density = 1.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
vec2 hit(vec3 o, vec3 d, float r) {
	float b = dot(o, d);
	float c = dot(o, o) - r * r;
	float h = b * b - c;
	if (h < 0.0) { return vec2(-1.0, -1.0); }
	h = sqrt(h);
	return vec2(-b - h, -b + h);
}
void fragment() {
	vec3 o = CAMERA_POSITION_WORLD;
	vec3 d = normalize(wp - o);
	vec2 a = hit(o, d, atmo_r);
	if (a.y < 0.0) { discard; }
	float t0 = max(a.x, 0.0);
	float t1 = a.y;
	vec2 p = hit(o, d, planet_r);
	if (p.x > 0.0) { t1 = min(t1, p.x); }
	float len = max(t1 - t0, 0.0);
	float thick = atmo_r - planet_r;
	vec3 m = o + d * (t0 + t1) * 0.5;
	float hgt = clamp((length(m) - planet_r) / thick, 0.0, 1.0);
	float light = clamp(dot(normalize(m), sun_dir) * 1.5 + 0.3, 0.0, 1.0);
	float amount = 1.0 - exp(-len / thick * density * (1.7 - hgt));
	vec3 col = mix(horizon_color.rgb, sky_color.rgb, clamp(hgt * 1.4 + (1.0 - amount) * 0.4, 0.0, 1.0));
	float glow = pow(max(dot(d, sun_dir), 0.0), 10.0);
	col += horizon_color.rgb * glow * 0.7;
	ALBEDO = col * (0.15 + 0.85 * light);
	ALPHA = clamp(amount * (0.1 + 0.9 * light), 0.0, 0.96);
}
"""

## Ground of the round planets: vertex colours + several layers of fine detail, rock on steep
## slopes, small bumps, wet sand and foam at the shore, and its own ambient light that depends on
## the time of day at each place (so the night side is really dark).
const TERRAIN := """
shader_type spatial;
render_mode ambient_light_disabled, cull_disabled, diffuse_toon, specular_toon;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform vec4 rock_color : source_color = vec4(0.4, 0.38, 0.36, 1.0);
uniform float rock_mix = 0.6;
uniform float planet_r = 100.0;
uniform float water_h = -999.0;
uniform float shore = 0.0;
uniform float bump = 0.35;
uniform float roughness = 0.9;
uniform float glint = 0.0;        // tiny sparkling grains (crystal, salt, ice, mica, metal)
uniform float ice = 0.0;          // glossy, slightly see-through looking ice on flat ground
uniform float wet_sheen = 0.0;    // damp, slick ground (fungus forest, shore)
uniform float rock_spec = 0.5;    // how reflective bare rock is (soil is always matte)
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec4 amb_color : source_color = vec4(0.6, 0.6, 0.7, 1.0);
uniform float amb_day = 0.6;
uniform float amb_night = 0.07;
global uniform float sw_wet;
global uniform float sw_snow;
varying vec3 wp;
varying vec3 wn;
vec3 tri_w(vec3 n) { vec3 b = pow(abs(n), vec3(4.0)); return b / (b.x + b.y + b.z); }
float tri(vec3 p, vec3 b, float s) {
	return texture(detail, p.yz * s).r * b.x + texture(detail, p.xz * s).r * b.y + texture(detail, p.xy * s).r * b.z;
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
// cartoon: much stronger colours (saturation up, a little brighter)
vec3 vivid(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return clamp(mix(vec3(l), c, 1.6) * 1.1 + 0.015, 0.0, 4.0);
}
void fragment() {
	vec3 up = normalize(wp);
	vec3 b = tri_w(wn);
	float slope = 1.0 - clamp(dot(wn, up), 0.0, 1.0);
	float d1 = tri(wp, b, 0.11);
	float d2 = tri(wp, b, 0.017);
	float d3 = tri(wp, b, 0.6);
	vec3 col = COLOR.rgb * (0.72 + 0.42 * d1) * (0.82 + 0.32 * d2) * (0.9 + 0.16 * d3);
	float h = length(wp) - planet_r;
	// rock layers (strata), cracks and erosion streaks on steep ground
	float strata = 0.82 + 0.18 * sin(h * 5.0 + d2 * 6.0) + 0.1 * sin(h * 13.0 + d1 * 4.0);
	float crack = smoothstep(0.12, 0.02, abs(d1 - 0.5)) * 0.35;
	vec3 rock = rock_color.rgb * (0.6 + 0.6 * d1) * (0.85 + 0.25 * d3) * strata * (1.0 - crack);
	// rock: on steep ground, and where the ground itself is bare rock (outcrops, craters: the
	// vertex colour's alpha is 0 there)
	float bare = 1.0 - COLOR.a;
	col = mix(col, rock, max(smoothstep(0.22, 0.5, slope) * rock_mix, bare * 0.55));
	// gravel and loose stones around the rock: granular speckle
	float grit_k = smoothstep(0.02, 0.25, bare) * (1.0 - smoothstep(0.6, 0.95, bare)) + smoothstep(0.1, 0.25, slope) * (1.0 - smoothstep(0.35, 0.5, slope)) * 0.6;
	float grit = step(0.55, fract(sin(dot(floor(wp * 9.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453));
	col *= 1.0 - grit_k * (grit * 0.28 - 0.08);
	// small stones and darker patches on flat ground
	col *= 1.0 - smoothstep(0.62, 0.7, d3) * 0.25 * (1.0 - slope);
	float wet = 0.0;
	if (shore > 0.5) {
		wet = 1.0 - smoothstep(0.0, 1.4, h - water_h);
		col *= 1.0 - 0.35 * wet;
		float line = water_h + 0.2 + sin(TIME * 1.2 + wp.x * 0.15 + wp.z * 0.1) * 0.18;
		float foam = (1.0 - smoothstep(0.0, 0.3, abs(h - line))) * step(0.45, d3);
		col = mix(col, vec3(0.92, 0.96, 1.0), foam * 0.85);
	}
	// rain: darker, shiny ground and puddles in the low flat spots
	float flat_k = 1.0 - smoothstep(0.05, 0.2, slope);
	float puddle = (1.0 - smoothstep(0.3, 0.38, d2)) * flat_k * smoothstep(0.3, 0.8, sw_wet);
	float rainwet = sw_wet * (0.6 + 0.4 * flat_k);
	col *= 1.0 - 0.3 * rainwet;
	col = mix(col, col * 0.5 + vec3(0.04, 0.05, 0.06), puddle);
	// snow settles on flat ground first, steep rock stays bare
	float sn = (1.0 - smoothstep(0.0, 0.25, slope - sw_snow * 0.25)) * smoothstep(0.0, 0.35, sw_snow + d3 * 0.3 - 0.15) * sw_snow;
	col = mix(col, vec3(0.92, 0.95, 1.0) * (0.92 + 0.1 * d3), clamp(sn * 1.4, 0.0, 1.0));
	// close to the camera: fine grit, tiny cracks and speckles (fades out with distance)
	float cam_d = length(VERTEX);
	float near_k = 1.0 - smoothstep(4.0, 22.0, cam_d);
	float d4 = tri(wp, b, 2.6);
	float d5 = tri(wp + vec3(3.1), b, 6.5);
	float micro_crack = (1.0 - smoothstep(0.02, 0.06, abs(d4 - 0.5))) * smoothstep(0.3, 0.7, d2);
	col *= 1.0 - near_k * (micro_crack * 0.35 + (d5 - 0.5) * 0.25);
	col = mix(col, col * vec3(1.1, 1.06, 1.0), near_k * smoothstep(0.75, 0.9, d5) * 0.6);
	// under the sea: colours fade to blue-green with depth, and light ripples (caustics) play
	// over the sea floor
	float uw = (shore > 0.5) ? clamp(water_h - h, 0.0, 30.0) : 0.0;
	float caustic = 0.0;
	if (uw > 0.0) {
		col = mix(col, col * vec3(0.32, 0.62, 0.7), clamp(uw / 9.0, 0.0, 0.8));
		vec2 cq = wp.xz * 1.3 + wp.y * 0.4;
		float c1 = sin(cq.x * 2.1 + TIME * 1.3 + sin(cq.y * 1.7 + TIME * 0.9) * 1.6);
		float c2 = sin(cq.y * 2.3 - TIME * 1.1 + sin(cq.x * 1.9 - TIME * 0.7) * 1.6);
		caustic = pow(clamp(1.0 - abs(c1 + c2) * 0.5, 0.0, 1.0), 6.0) * exp(-uw * 0.18) * smoothstep(0.0, 0.3, uw);
	}
	// cartoon: vivid colours in a few clear tones, a dark ink line where the ground turns away
	col = vivid(col);
	col = floor(col * 7.0 + 0.5) / 7.0 * 0.35 + col * 0.65;
	float ink = smoothstep(0.2, 0.06, abs(dot(normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz), VIEW)));
	col *= 1.0 - ink * 0.55;
	ALBEDO = col;
	// roughness: soil very rough, bare rock a little smoother, varied by the noise; wet = shiny
	float rock_k = max(smoothstep(0.22, 0.5, slope), 1.0 - COLOR.a);
	float rgh = mix(roughness, roughness * 0.82, rock_k) * (0.88 + 0.24 * d1);
	// tiny grains that catch the light (only up close, so the ground never looks plastic)
	float d6 = tri(wp + vec3(5.3), b, 11.0);
	float spark = smoothstep(0.86, 0.95, d6) * glint * (0.4 + 0.6 * near_k);
	// ice: the flat parts become glossy and a little blue-green in their depth
	float ice_k = ice * (1.0 - rock_k * 0.7) * smoothstep(0.35, 0.65, d1 + 0.2);
	rgh = mix(rgh, 0.12 + d2 * 0.12, ice_k);
	rgh -= wet_sheen * (0.25 + 0.2 * (1.0 - d3)) * (1.0 - rock_k * 0.5);
	ROUGHNESS = clamp(rgh - wet * 0.55 - rainwet * 0.5 - puddle * 0.4 - spark * 0.75, 0.03, 1.0);
	SPECULAR = clamp(mix(0.22, rock_spec, rock_k) + spark * 0.6 + ice_k * 0.35 + wet * 0.3, 0.0, 1.0);
	METALLIC = spark * 0.35;
	float fres = pow(1.0 - clamp(dot(normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz), VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(col, col * vec3(0.8, 0.95, 1.08), ice_k * 0.5);
	// small bumps (cheap: tilt the normal with the detail noise), stronger fine grit up close
	vec3 g = vec3(tri(wp + vec3(0.37), b, 0.11) - 0.5, tri(wp + vec3(0.71), b, 0.6) - 0.5, tri(wp + vec3(0.13), b, 0.11) - 0.5);
	vec3 gf = vec3(d4 - 0.5, d5 - 0.5, tri(wp + vec3(1.7), b, 2.6) - 0.5);
	// rock and gravel are bumpier than soil
	float bmp = bump * (1.0 + rock_k * 0.8);
	vec3 nw = normalize(wn + g * bmp + gf * bmp * 0.9 * near_k);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float dayk = smoothstep(-0.18, 0.3, dot(up, sun_dir));
	EMISSION = col * amb_color.rgb * mix(amb_night, amb_day, dayk) + vec3(0.55, 0.85, 0.9) * caustic * 0.6 * dayk
		+ vec3(0.35, 0.6, 0.75) * ice_k * fres * 0.35 * dayk;
}
"""

## Leaves, grass, fronds (textured cards): cut out by the texture, moving in the wind,
## darker near the stem, colour variation per plant (vertex / instance colour).
const FOLIAGE := """
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float sway = 0.08;
uniform float base_dark = 0.45;
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
global uniform float sw_wind;
global uniform float sw_wet;
global uniform float sw_snow;
global uniform vec3 sw_player;
global uniform vec3 sw_capsule;
varying float gust_v;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float a = TIME * (1.2 + sw_wind * 1.6) + dot(w, vec3(0.31, 0.27, 0.23));
	float k = sway * (1.0 - UV.y) * (0.4 + sw_wind * 1.2);
	VERTEX += vec3(sin(a), sin(a * 1.3 + 1.0) * 0.4, cos(a * 0.8)) * k;
	// gusts: bands of stronger wind roll across the fields - the plants bow in waves
	float gust = 0.5 + 0.5 * sin(dot(w, vec3(0.11, 0.04, 0.08)) - TIME * (1.1 + sw_wind * 1.4) + sin(dot(w, vec3(0.03, 0.0, -0.05)) + TIME * 0.2) * 2.0);
	gust = gust * gust * gust * gust;
	gust_v = gust;
	VERTEX += vec3(1.0, -0.25, 0.35) * gust * (1.0 - UV.y) * sway * (2.0 + sw_wind * 4.0);
	// pushed aside when you walk through
	vec3 away = w - sw_player;
	float d = length(away);
	if (d < 0.9) {
		vec3 push = normalize(away) * (0.9 - d) * 0.5 * (1.0 - UV.y);
		VERTEX += (inverse(MODEL_MATRIX) * vec4(push, 0.0)).xyz;
	}
	// pressed flat under the parked capsule (so the capsule is never hidden in grass)
	vec3 cv = w - sw_capsule;
	float cd = length(cv);
	if (cd < 1.1) {
		vec3 cu = normalize(sw_capsule);
		vec3 flat_v = cv - cu * dot(cv, cu);
		vec3 press = (normalize(flat_v + cu * 0.001) * 0.35 - cu * 0.6) * (1.1 - cd) * (1.0 - UV.y);
		VERTEX += (inverse(MODEL_MATRIX) * vec4(press, 0.0)).xyz;
	}
}
// naturalistic greens: a green colour is pulled towards a palette of deep forest, leaf,
// emerald and olive greens (picked per plant, keeping its light / dark detail); colours that
// are not green (fungi, ice, crystals, flowers) are left alone
vec3 rich_green(vec3 c, vec3 org) {
	float g_k = clamp((c.g - max(c.r, c.b)) * 5.0, 0.0, 1.0);
	if (g_k <= 0.0) { return c; }
	float pick = fract(sin(dot(floor(org * 1.7), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	vec3 forest = vec3(0.055, 0.18, 0.065);
	vec3 leafg = vec3(0.13, 0.32, 0.08);
	vec3 emerald = vec3(0.04, 0.29, 0.15);
	vec3 olive = vec3(0.24, 0.29, 0.07);
	vec3 pal = pick < 0.3 ? forest : (pick < 0.6 ? leafg : (pick < 0.82 ? emerald : olive));
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 target = pal * (0.45 + lum * 1.35);
	return mix(c, target, g_k * 0.8);
}
// cartoon: much stronger colours (saturation up, a little brighter)
vec3 vivid(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return clamp(mix(vec3(l), c, 1.6) * 1.1 + 0.015, 0.0, 4.0);
}
void fragment() {
	vec4 c = texture(tex, UV);
	vec3 leaf = c.rgb * tint.rgb * COLOR.rgb * mix(base_dark, 1.0, 1.0 - UV.y) * (1.0 - sw_wet * 0.2);
	leaf = rich_green(leaf, MODEL_MATRIX[3].xyz);
	// bent by a gust, the blades turn their lighter undersides up: a silvery wave runs through
	leaf *= 1.0 + gust_v * 0.22 * (1.0 - UV.y);
	leaf = vivid(leaf);
	// fresh highlights at the tips, darker inside the plant
	leaf *= mix(0.82, 1.12, 1.0 - UV.y);
	ALBEDO = mix(leaf, vec3(0.92, 0.95, 1.0), sw_snow * 0.55 * (1.0 - UV.y * 0.5));
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.65 - sw_wet * 0.45;
	SPECULAR = 0.35 + sw_wet * 0.3;
	EMISSION = glow.rgb * c.a;
}
"""

## Soft light shafts under the trees (strength follows the daylight)
const SHAFT := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.95, 0.7, 1.0);
uniform float strength = 0.15;
void fragment() {
	float x = 1.0 - abs(UV.x - 0.5) * 2.0;
	float fade = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.6, UV.y);
	float flicker = 0.85 + 0.15 * sin(TIME * 0.7 + UV.x * 3.0);
	ALBEDO = color.rgb;
	ALPHA = strength * x * x * fade * flicker;
}
"""

## Low mist: big soft camera-facing patches near the ground (brightness follows the daylight)
const MIST := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D tex : filter_linear;
uniform vec4 color : source_color = vec4(0.8, 0.9, 0.8, 0.18);
uniform float light = 1.0;
varying float fade;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	fade = smoothstep(2.0, 9.0, -vp.z) * (1.0 - smoothstep(60.0, 110.0, -vp.z));
}
void fragment() {
	float a = texture(tex, UV).a;
	ALBEDO = color.rgb * (0.12 + 0.88 * light);
	ALPHA = a * color.a * fade * (0.5 + 0.5 * sin(TIME * 0.3 + UV.x * 2.0));
}
"""

## Alien skin: colour from back to belly, patterns (1 stripes, 2 spots, 3 rings, 4 mottled,
## 5 veins, 6 eye-spots), markings that can glow (brighter at night through `glow`), small bumps,
## a rim of light. CREATURE_CLEAR is the same, but see-through (organs inside stay visible).
const CREATURE_BODY := """
uniform vec4 base : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 belly : source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform vec4 mark : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform int pattern = 0;
uniform float pattern_scale = 5.0;
uniform float mark_glow = 0.0;
uniform float alpha = 1.0;
uniform float rough = 0.55;
uniform float metal = 0.0;
uniform float rim_amount = 0.35;
uniform float bumps = 0.3;
varying vec3 lp;
varying vec3 ln;
""" + NOISE3 + """
void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}
float pat(vec3 p) {
	float n = noise3(p * 2.3);
	if (pattern == 1) { return step(0.55, fract(p.z * pattern_scale + n * 0.8)); }
	if (pattern == 2) { return step(0.72, noise3(p * pattern_scale)); }
	if (pattern == 3) { return step(0.6, fract(length(p.xz) * pattern_scale + n * 0.3)); }
	if (pattern == 4) { return smoothstep(0.45, 0.65, fbm3(p * pattern_scale * 0.5)); }
	if (pattern == 5) { return 1.0 - smoothstep(0.0, 0.06, abs(noise3(p * pattern_scale) - 0.5)); }
	if (pattern == 6) { float d = length(fract(p.xz * pattern_scale * 0.5) - 0.5); return step(d, 0.18) - step(d, 0.08) * 0.5; }
	return 0.0;
}
void fragment() {
	float b = smoothstep(-0.7, 0.7, ln.y);
	vec3 col = mix(belly.rgb, base.rgb, b) * (0.85 + 0.3 * noise3(lp * 7.0));
	float m = pat(lp);
	col = mix(col, mark.rgb, m * 0.9);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	vec3 g = vec3(noise3(lp * 18.0) - 0.5, noise3(lp * 18.0 + 3.1) - 0.5, noise3(lp * 18.0 + 7.3) - 0.5);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(g * bumps, 0.0)).xyz);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = mark.rgb * m * mark_glow + mix(base.rgb, mark.rgb, 0.5) * rim * rim_amount * 0.4;
	ALPHA_PLACEHOLDER
}
"""
const CREATURE := "shader_type spatial;\nrender_mode cull_back;\n" + CREATURE_BODY
const CREATURE_CLEAR := "shader_type spatial;\nrender_mode blend_mix, cull_back, depth_draw_always;\n" + CREATURE_BODY

## Aurora: glowing curtains of light high in the sky (strength follows the night)
const AURORA := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 col_a : source_color = vec4(0.2, 1.0, 0.6, 1.0);
uniform vec4 col_b : source_color = vec4(0.7, 0.3, 1.0, 1.0);
uniform float strength = 1.0;
""" + NOISE_FUNCS + """
void fragment() {
	float x = UV.x * 9.0;
	float wave = noise(vec2(x * 0.7 + TIME * 0.05, TIME * 0.03)) * 0.8 + noise(vec2(x * 2.3 - TIME * 0.11, 3.0)) * 0.4;
	float band = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(0.35, 1.0, UV.y));
	float rays = 0.5 + 0.5 * sin(x * 14.0 + wave * 6.0 + TIME * 0.4);
	vec3 c = mix(col_a.rgb, col_b.rgb, smoothstep(0.3, 0.9, UV.y) + wave * 0.3);
	ALBEDO = c * band * (0.5 + rays * 0.8) * wave * strength * 1.4;
}
"""


static var _globals_ready := false


## Wind strength shared by all plants and the water (set by the weather)
static func ensure_globals() -> void:
	if _globals_ready:
		return
	_globals_ready = true
	RenderingServer.global_shader_parameter_add("sw_wind", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.5)
	RenderingServer.global_shader_parameter_add("sw_wet", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	RenderingServer.global_shader_parameter_add("sw_snow", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	RenderingServer.global_shader_parameter_add("sw_player", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0, -9999, 0))
	RenderingServer.global_shader_parameter_add("sw_capsule", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0, -9999, 0))


static func set_wind(w: float) -> void:
	ensure_globals()
	RenderingServer.global_shader_parameter_set("sw_wind", w)


## Where the player is: plants bend away from you
static func set_player(p: Vector3) -> void:
	ensure_globals()
	RenderingServer.global_shader_parameter_set("sw_player", p)


static func set_capsule(p: Vector3) -> void:
	ensure_globals()
	RenderingServer.global_shader_parameter_set("sw_capsule", p)


## Rain makes ground and plants wet (darker, shiny, puddles); snow settles on top surfaces
static func set_surface(wet: float, snow: float) -> void:
	ensure_globals()
	RenderingServer.global_shader_parameter_set("sw_wet", wet)
	RenderingServer.global_shader_parameter_set("sw_snow", snow)


static func shader(code_name: String) -> Shader:
	ensure_globals()
	if not _cache.has(code_name):
		var s := Shader.new()
		match code_name:
			"water": s.code = WATER
			"lava": s.code = LAVA
			"nature": s.code = NATURE
			"clouds": s.code = CLOUDS
			"holo": s.code = HOLO
			"haze": s.code = HAZE
			"water_sphere": s.code = WATER_SPHERE
			"lava_sphere": s.code = LAVA_SPHERE
			"cloud_shell": s.code = CLOUD_SHELL
			"atmosphere": s.code = ATMOSPHERE
			"terrain": s.code = TERRAIN
			"foliage": s.code = FOLIAGE
			"shaft": s.code = SHAFT
			"mist": s.code = MIST
			"creature": s.code = CREATURE.replace("ALPHA_PLACEHOLDER", "")
			"creature_clear": s.code = CREATURE_CLEAR.replace("ALPHA_PLACEHOLDER", "ALPHA = clamp(alpha + rim * 0.4, 0.0, 1.0);")
			"aurora": s.code = AURORA
		_cache[code_name] = s
	return _cache[code_name]


static func material(code_name: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(code_name)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


## Lit material for plants etc. sway = wind movement, pulse = glow breathing
static func nature(col: Color, glow := Color.BLACK, energy := 1.0, sway := 0.0, pulse := 0.0, rough := 0.8, metal := 0.0) -> ShaderMaterial:
	return material("nature", {"albedo": col, "emission": glow, "emission_energy": energy, "sway": sway,
		"pulse": pulse, "roughness": rough, "metallic": metal})
