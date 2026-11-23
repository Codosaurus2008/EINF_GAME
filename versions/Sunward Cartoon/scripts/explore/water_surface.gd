class_name WaterSurface
extends Node3D
## The sea of an ocean planet, built for detail where you are and low cost elsewhere:
##  - a fine, round water patch that follows the camera (dense in the middle, coarser outwards):
##    real moving waves (5 layers with different sizes / speeds, driven by the wind and weather),
##    ring waves from splashes, wakes, swimming, animals and the capsule
##  - the rest of the sea is a simple sphere with the same colours but no moving geometry
##  - the depth of the water is known everywhere (a baked depth map of the whole planet plus a
##    sharper one around you): shallow water is clear and turquoise and shows the ground,
##    deep water is dark blue; waves get lower and break near the shore, foam lines the beach
## Ring waves: up to 24 at a time (position, start time, strength, size).

const RIPPLES := 24
const NEAR_TEX := 64            # sharper depth map around the camera (texels)
const NEAR_HALF := 40.0         # ... covering 80 x 80 m
const DEPTH_MIN := -4.0         # depth maps store -4 .. +20 m in 0 .. 1
const DEPTH_SPAN := 24.0

var world: SphereWorld
var near_mat: ShaderMaterial
var far_mat: ShaderMaterial
var patch: MeshInstance3D
var far: MeshInstance3D
var ripples := PackedVector4Array()       # x, y, z, start time
var ripple_p := PackedVector4Array()      # strength, size, -, -
var ripple_next := 0
var water_r := 100.0
# sharper depth map around the camera (rebuilt a little every frame when you have moved on)
var near_img: Image
var near_tex: ImageTexture
var near_job := -1              # rows done (-1 = idle)
var near_new_c := Vector3.ZERO
var near_new_t1 := Vector3.RIGHT
var near_new_t2 := Vector3.FORWARD
var near_c := Vector3.ZERO
var near_t1_cur := Vector3.RIGHT       # axes of the depth map that is in use
var near_t2_cur := Vector3.FORWARD
var sim: WaveSim = null


func setup(w: SphereWorld) -> void:
	world = w
	water_r = w.water_radius()
	for i in RIPPLES:
		ripples.append(Vector4(0, 0, 0, -100.0))
		ripple_p.append(Vector4.ZERO)
	var depth_tex := _bake_global()
	near_img = Image.create(NEAR_TEX, NEAR_TEX, false, Image.FORMAT_L8)
	near_img.fill(Color(1, 1, 1))
	near_tex = ImageTexture.create_from_image(near_img)
	var common := {"deep": Color("#0a2f5c"), "shallow": Color("#1f8f98"), "sky_col": w.biome["sky_top"],
		"horizon_col": w.biome["sky_horizon"], "water_r": water_r, "depth_map": depth_tex,
		"near_depth": near_tex, "near_half": NEAR_HALF}
	near_mat = ShaderMaterial.new()
	near_mat.shader = Shader.new()
	near_mat.shader.code = "shader_type spatial;\n#define NEAR\n" + WATER_BODY
	far_mat = ShaderMaterial.new()
	far_mat.shader = Shader.new()
	far_mat.shader.code = "shader_type spatial;\n" + WATER_BODY
	for k: String in common:
		near_mat.set_shader_parameter(k, common[k])
		far_mat.set_shader_parameter(k, common[k])
	# the far sea: a plain sphere
	far = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = water_r
	sm.height = water_r * 2.0
	sm.radial_segments = 192
	sm.rings = 96
	far.mesh = sm
	far.material_override = far_mat
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far)
	# the near patch: a disc of rings, dense in the middle
	patch = MeshInstance3D.new()
	patch.mesh = _disc(60, 120)
	patch.material_override = near_mat
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.extra_cull_margin = 40.0
	add_child(patch)
	# real wave physics around the camera (wave equation on the graphics card)
	sim = WaveSim.new()
	sim.name = "WaveSim"
	add_child(sim)
	sim.setup(w)


## Unit disc in the XZ plane: rings get further apart towards the edge (adaptive resolution)
func _disc(rings: int, segs: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.append(Vector3.ZERO)
	norms.append(Vector3.UP)
	for r in range(1, rings + 1):
		var rr := pow(float(r) / rings, 1.8)
		for s in segs:
			var a := TAU * s / segs
			verts.append(Vector3(cos(a) * rr, 0.0, sin(a) * rr))
			norms.append(Vector3.UP)
	for s in segs:
		idx.append_array(PackedInt32Array([0, 1 + (s + 1) % segs, 1 + s]))
	for r in range(1, rings):
		var a0 := 1 + (r - 1) * segs
		var b0 := 1 + r * segs
		for s in segs:
			var s1 := (s + 1) % segs
			idx.append_array(PackedInt32Array([a0 + s, a0 + s1, b0 + s, a0 + s1, b0 + s1, b0 + s]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Water depth over the whole planet (longitude / latitude map, about 6 m per texel)
func _bake_global() -> ImageTexture:
	var wd := 192
	var ht := 96
	var img := Image.create(wd, ht, false, Image.FORMAT_L8)
	for y in ht:
		var lat := (0.5 - (y + 0.5) / ht) * PI
		for x in wd:
			var lon := ((x + 0.5) / wd - 0.5) * TAU
			var d := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var depth := world.water_level - world.terrain.height(d)
			img.set_pixel(x, y, Color(clampf((depth - DEPTH_MIN) / DEPTH_SPAN, 0.0, 1.0), 0, 0))
	return ImageTexture.create_from_image(img)


## A ring wave at p. strength 0.05 .. 2.5, size = how wide the rings are (0.15 for a hand,
## 1 for the capsule, 3 for a crash)
func add_ripple(p: Vector3, strength: float, size := 1.0) -> void:
	# the physical waves: a push on the simulated surface (it spreads, interferes, reflects)
	if sim:
		sim.disturb(p, clampf(strength * 0.07, 0.006, 0.4), clampf(size * 0.6, 0.25, 3.0))
	var q := p.normalized() * water_r
	ripples[ripple_next] = Vector4(q.x, q.y, q.z, world.t)
	ripple_p[ripple_next] = Vector4(strength, clampf(size, 0.08, 4.0), 0.0, 0.0)
	ripple_next = (ripple_next + 1) % RIPPLES


## The simulated wave heights the near sea uses (WaveSim calls this every step)
func set_sim(tex: Texture2D, c: Vector3, a1: Vector3, a2: Vector3, size: float) -> void:
	near_mat.set_shader_parameter("sim_tex", tex)
	near_mat.set_shader_parameter("sim_c", c)
	near_mat.set_shader_parameter("sim_t1", a1)
	near_mat.set_shader_parameter("sim_t2", a2)
	near_mat.set_shader_parameter("sim_size", size)
	near_mat.set_shader_parameter("sim_on", 1.0)


func set_param(key: String, v: Variant) -> void:
	near_mat.set_shader_parameter(key, v)
	far_mat.set_shader_parameter(key, v)
	if key == "wave":
		wave_k = float(v)
	elif key == "chop":
		chop_k = float(v)


# ================================================================== the same waves on the CPU
## Exactly the wave layers the shader draws (same lengths, directions, heights, speeds), so the
## capsule, swimmers, animals and floating things ride the waves you see.
var wave_k := 0.3
var chop_k := 0.0
const WIND := Vector3(1.0, 0.0, 0.3)
const LENS := [21.0, 11.0, 5.3, 2.4, 1.1]
const ANGS := [0.0, 0.55, -0.7, 1.2, -1.5]
const HS := [0.32, 0.2, 0.11, 0.05, 0.022]


## Height of the water surface above the calm sea level at p (metres; + = crest)
func wave_height(p: Vector3) -> float:
	var up := p.normalized()
	var w := up * water_r
	var depth := world.water_level - world.terrain.height(up)
	var shoal := clampf(depth / 3.0, 0.0, 1.0)
	var amp := (0.1 + wave_k * 1.1) * lerpf(0.25, 1.0, shoal)
	var wd := (WIND.normalized() - up * WIND.normalized().dot(up)).normalized()
	var sd := up.cross(wd)
	var h := 0.0
	var now := world.t
	for i in 5:
		var dir: Vector3 = wd * cos(float(ANGS[i])) + sd * sin(float(ANGS[i]))
		var k := TAU / float(LENS[i])
		var c := sqrt(9.8 / k)
		var ph := w.dot(dir) * k - now * c * k + i * 1.7
		var a := float(HS[i]) * amp * (1.0 if i < 3 else (0.6 + chop_k))
		var sn := sin(ph)
		h += a * (sn + 0.25 * sn * sn)
	return h


## Point on the moving water surface above / below p
func surface_point(p: Vector3) -> Vector3:
	return p.normalized() * (water_r + wave_height(p))


func _process(delta: float) -> void:
	if world == null:
		return
	var cam := world.viewer
	if cam.length() < 1.0:
		return
	var up := cam.normalized()
	var alt := absf(cam.length() - water_r)
	# the fine patch lies under the camera; higher up it covers more
	var pr := clampf(45.0 + alt * 1.6, 45.0, 260.0)
	var c := up * water_r
	patch.global_transform = Transform3D(SphereTerrain.surface_basis(up, 0.0).scaled(Vector3(pr, 1.0, pr)), c)
	set_param("now", world.t)
	set_param("patch_c", c)
	set_param("patch_r", pr)
	near_mat.set_shader_parameter("ripples", ripples)
	near_mat.set_shader_parameter("ripple_p", ripple_p)
	# the wind sets the waves' direction
	var wind_v := Vector3(1.0, 0.0, 0.3).normalized()
	near_mat.set_shader_parameter("wind_dir", wind_v)
	_near_depth(up)


## Re-bakes the sharp depth map when the camera has moved on (3 rows per frame)
func _near_depth(up: Vector3) -> void:
	if near_job < 0:
		if near_c == Vector3.ZERO or (up * water_r).distance_to(near_c) > NEAR_HALF * 0.35:
			near_new_c = up * water_r
			var b := SphereTerrain.surface_basis(up, 0.0)
			near_new_t1 = b.x
			near_new_t2 = b.z
			near_job = 0
		return
	for r in 3:
		var y := near_job
		if y >= NEAR_TEX:
			break
		for x in NEAR_TEX:
			var lp := near_new_c + near_new_t1 * ((x + 0.5) / NEAR_TEX - 0.5) * NEAR_HALF * 2.0 \
				+ near_new_t2 * ((y + 0.5) / NEAR_TEX - 0.5) * NEAR_HALF * 2.0
			var depth := world.water_level - world.terrain.height(lp.normalized())
			near_img.set_pixel(x, y, Color(clampf((depth - DEPTH_MIN) / DEPTH_SPAN, 0.0, 1.0), 0, 0))
		near_job += 1
	if near_job >= NEAR_TEX:
		near_job = -1
		near_c = near_new_c
		near_tex.update(near_img)
		set_param("near_c", near_new_c)
		set_param("near_t1", near_new_t1)
		set_param("near_t2", near_new_t2)
		near_t1_cur = near_new_t1
		near_t2_cur = near_new_t2
		set_param("near_on", 1.0)


## After a crater under water: the depth maps follow
func refresh_depth() -> void:
	near_c = Vector3.ZERO


const WATER_BODY := """
render_mode blend_mix, cull_disabled, depth_draw_always, world_vertex_coords, shadows_disabled, diffuse_toon, specular_toon;
uniform vec4 deep : source_color = vec4(0.03, 0.19, 0.31, 1.0);
uniform vec4 shallow : source_color = vec4(0.21, 0.79, 0.78, 1.0);
uniform vec4 sky_col : source_color = vec4(0.4, 0.6, 0.9, 1.0);
uniform vec4 horizon_col : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float wave = 0.3;
uniform float chop = 0.0;
uniform float rain = 0.0;
uniform float clarity = 0.7;
uniform float day = 1.0;
uniform float now = 0.0;
uniform float water_r = 100.0;
uniform vec3 wind_dir = vec3(1.0, 0.0, 0.3);
uniform vec3 patch_c = vec3(0.0);
uniform float patch_r = 50.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform sampler2D depth_map : filter_linear, repeat_enable;
uniform sampler2D near_depth : filter_linear, repeat_disable;
uniform vec3 near_c = vec3(0.0);
uniform vec3 near_t1 = vec3(1.0, 0.0, 0.0);
uniform vec3 near_t2 = vec3(0.0, 0.0, 1.0);
uniform float near_half = 40.0;
uniform float near_on = 0.0;
uniform vec4 ripples[24];
uniform vec4 ripple_p[24];
uniform sampler2D sim_tex : filter_nearest, repeat_disable;
uniform vec3 sim_c = vec3(0.0);
uniform vec3 sim_t1 = vec3(1.0, 0.0, 0.0);
uniform vec3 sim_t2 = vec3(0.0, 0.0, 1.0);
uniform float sim_size = 48.0;
uniform float sim_on = 0.0;

// the simulated (physical) wave height at p, smoothly read from the 16-bit packed picture
float sim_unpack(vec2 c) {
	float v = floor(c.x * 255.0 + 0.5) * 256.0 + floor(c.y * 255.0 + 0.5);
	return (v / 65535.0 - 0.5) * 2.0;
}
float sim_h(vec3 p) {
	if (sim_on < 0.5) { return 0.0; }
	vec3 q = p - sim_c;
	vec2 uv = vec2(dot(q, sim_t1), dot(q, sim_t2)) / sim_size + 0.5;
	float edge = min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y));
	if (edge <= 0.0) { return 0.0; }
	vec2 ts = vec2(textureSize(sim_tex, 0));
	vec2 f = uv * ts - 0.5;
	vec2 i = floor(f);
	vec2 fr = f - i;
	ivec2 i0 = ivec2(clamp(i, vec2(0.0), ts - 1.0));
	ivec2 i1 = ivec2(clamp(i + 1.0, vec2(0.0), ts - 1.0));
	float a = sim_unpack(texelFetch(sim_tex, i0, 0).rg);
	float b = sim_unpack(texelFetch(sim_tex, ivec2(i1.x, i0.y), 0).rg);
	float c = sim_unpack(texelFetch(sim_tex, ivec2(i0.x, i1.y), 0).rg);
	float d = sim_unpack(texelFetch(sim_tex, i1, 0).rg);
	return mix(mix(a, b, fr.x), mix(c, d, fr.x), fr.y) * smoothstep(0.0, 0.08, edge);
}
varying vec3 wp;
varying float wh;

float depth_at(vec3 p) {
	vec3 d = normalize(p);
	vec2 uv = vec2(atan(d.z, d.x) / 6.2831853 + 0.5, 0.5 - asin(clamp(d.y, -1.0, 1.0)) / 3.14159265);
	float dg = texture(depth_map, uv).r * 24.0 - 4.0;
	if (near_on > 0.5) {
		vec3 q = p - near_c;
		vec2 lc = vec2(dot(q, near_t1), dot(q, near_t2)) / (near_half * 2.0) + 0.5;
		float edge = min(min(lc.x, lc.y), min(1.0 - lc.x, 1.0 - lc.y));
		if (edge > 0.0) {
			float dn = texture(near_depth, lc).r * 24.0 - 4.0;
			dg = mix(dg, dn, smoothstep(0.0, 0.08, edge));
		}
	}
	return dg;
}

// 5 layers of waves: long swell to small chop; returns height, adds the slope to grad
float waves(vec3 p, vec3 up, float amp, out vec3 grad) {
	vec3 wd = normalize(wind_dir - up * dot(wind_dir, up));
	vec3 sd = cross(up, wd);
	float h = 0.0;
	grad = vec3(0.0);
	float lens[5] = {21.0, 11.0, 5.3, 2.4, 1.1};
	float angs[5] = {0.0, 0.55, -0.7, 1.2, -1.5};
	float hs[5] = {0.32, 0.2, 0.11, 0.05, 0.022};
	for (int i = 0; i < 5; i++) {
		vec3 dir = wd * cos(angs[i]) + sd * sin(angs[i]);
		float k = 6.2831853 / lens[i];
		float c = sqrt(9.8 / k);
		float ph = dot(p, dir) * k - now * c * k + float(i) * 1.7;
		float a = hs[i] * amp * (i < 3 ? 1.0 : (0.6 + chop));
		// sharper crests (like real waves): lifted sine
		float s = sin(ph);
		h += a * (s + 0.25 * s * s);
		grad += dir * a * k * cos(ph) * (1.0 + 0.5 * s);
	}
	return h;
}

// ring waves from splashes / wakes; adds their slope to grad, returns height
float rings(vec3 p, inout vec3 grad, out float foam) {
	float sum = 0.0;
	foam = 0.0;
	for (int i = 0; i < 24; i++) {
		vec4 rp = ripple_p[i];
		float age = now - ripples[i].w;
		if (rp.x <= 0.0 || age < 0.0 || age > 7.0) { continue; }
		vec3 dv = p - ripples[i].xyz;
		float d = length(dv);
		float sz = rp.y;
		float front = age * 1.6 * sqrt(sz);
		float k = d - front;
		if (abs(k) > sz * 2.5) { continue; }
		float fade = rp.x * exp(-age * 0.7) / (1.0 + d * 0.5 / sz);
		float w = 7.0 / sz;
		float env = exp(-abs(k) * 2.2 / sz);
		sum += sin(k * w) * env * fade * sz * 0.12;
		grad += (dv / max(d, 0.001)) * cos(k * w) * w * env * fade * sz * 0.12;
		foam += env * fade * smoothstep(0.6, 0.0, age);
	}
	return sum;
}

void vertex() {
	vec3 w = normalize(VERTEX) * water_r;
	vec3 up = normalize(w);
	float wdepth = depth_at(w);
	// waves are lower in shallow water and stop at the beach
	float shoal = clamp(wdepth / 3.0, 0.0, 1.0);
	float amp = (0.1 + wave * 1.1) * mix(0.25, 1.0, shoal);
#ifdef NEAR
	float near_k = 1.0 - smoothstep(patch_r * 0.55, patch_r * 0.95, distance(w, patch_c));
	vec3 g;
	float h = waves(w, up, amp, g) * near_k;
	float rf;
	vec3 g2 = vec3(0.0);
	h += rings(w, g2, rf) * near_k * (1.0 - sim_on * 0.7);
	h += sim_h(w);
	VERTEX = w + up * h;
	wh = h;
#else
	VERTEX = w;
	wh = 0.0;
#endif
	NORMAL = up;
	wp = w;
}

void fragment() {
	vec3 up = normalize(wp);
	float depth = depth_at(wp);
#ifndef NEAR
	// the fine patch covers the middle
	if (distance(wp, patch_c) < patch_r - 0.4) { discard; }
#endif
	float cam_d = length(VERTEX);
	float shoal = clamp(depth / 3.0, 0.0, 1.0);
	float amp = (0.1 + wave * 1.1) * mix(0.25, 1.0, shoal);
	vec3 g;
	float h = waves(wp, up, amp, g);
	float rf = 0.0;
#ifdef NEAR
	h += rings(wp, g, rf);
	// the physical waves: their slope bends the light, steep fronts and crests foam
	float s0 = sim_h(wp);
	float sx = sim_h(wp + sim_t1 * 0.18) - sim_h(wp - sim_t1 * 0.18);
	float sz = sim_h(wp + sim_t2 * 0.18) - sim_h(wp - sim_t2 * 0.18);
	g += (sim_t1 * sx + sim_t2 * sz) / 0.36;
	rf = rf * (1.0 - sim_on * 0.6) + clamp(length(vec2(sx, sz)) * 6.0 - 0.25, 0.0, 1.0) + clamp(abs(s0) * 4.0 - 0.3, 0.0, 0.6);
	h += s0;
#endif
	// thousands of small wind ripples on top: 8 short wave trains (12 cm .. 1 m) in different
	// directions plus a drifting noise; they catch the light (glints) and give the water its
	// texture. They fade out with distance (no flicker far away).
	float tk = 1.0 - smoothstep(18.0, 90.0, cam_d);
	vec3 wdir = normalize(wind_dir - up * dot(wind_dir, up));
	vec3 sdir = cross(up, wdir);
	vec3 tiny = vec3(0.0);
	float wind_k = 0.55 + wave * 0.8 + chop * 0.8;
	for (int i = 0; i < 8; i++) {
		float fi = float(i);
		float ang = (fract(sin(fi * 12.9898) * 43758.5453) - 0.5) * 2.4;
		vec3 dir = wdir * cos(ang) + sdir * sin(ang);
		float lam = 0.12 + fi * 0.12;
		float k = 6.2831853 / lam;
		float ph = dot(wp, dir) * k - now * sqrt(9.8 * k) * 0.6 + fi * 2.3;
		tiny += dir * cos(ph) * (0.18 / (1.0 + fi * 0.35));
	}
	vec2 nq = vec2(dot(wp, wdir), dot(wp, sdir));
	vec2 nn = vec2(sin(nq.x * 3.1 + now * 0.9 + sin(nq.y * 2.3)), cos(nq.y * 2.7 - now * 0.7 + sin(nq.x * 1.9)));
	tiny += (wdir * nn.x + sdir * nn.y) * 0.08;
	tiny *= tk * wind_k;
	// the surface is smoother in some patches, rougher in others (wind gusts)
	float gust = 0.5 + 0.5 * sin(nq.x * 0.21 + now * 0.4 + sin(nq.y * 0.17 - now * 0.3) * 2.0);
	// rain drops: small expanding rings
	vec2 rc = vec2(wp.x + wp.y * 0.5, wp.z - wp.y * 0.5) * 5.0;
	vec2 cell = floor(rc);
	float phase = fract(now * 1.3 + fract(sin(dot(cell, vec2(12.9, 78.2))) * 437.5));
	float rdist = length(fract(rc) - 0.5);
	float drop = rain * (1.0 - smoothstep(0.0, 0.05, abs(rdist - phase * 0.45))) * (1.0 - phase) * tk;
	vec3 slope = g - up * dot(g, up);
	vec3 n = normalize(up - slope * 0.9 + tiny * (0.6 + 0.6 * gust) + vec3(drop * 0.4, 0.0, drop * 0.4));
	vec3 nv = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	NORMAL = nv;
	float f = pow(1.0 - clamp(dot(nv, VIEW), 0.0, 1.0), 4.0);
	// colour by depth: clear turquoise in the shallows, dark blue in the deep
	float dk = 1.0 - exp(-max(depth, 0.0) * 0.22);
	vec3 water = mix(shallow.rgb, deep.rgb, dk);
	// light shining through the wave crests
	water = mix(water, shallow.rgb * 1.15, clamp(h * 1.2, 0.0, 0.35) * (1.0 - dk * 0.5));
	// foam: on the beach, in lines of breaking waves, on splashes and rough crests
	float shore = 1.0 - smoothstep(0.05, 0.45, depth);
	float breaker = smoothstep(0.75, 1.0, sin(depth * 3.2 + now * 1.7 + sin(wp.x * 0.3 + wp.z * 0.2) * 1.5)) * (1.0 - smoothstep(0.3, 2.2, depth)) * step(0.0, depth);
	float grain = fract(sin(dot(floor(wp.xz * 9.0 + wp.y * 3.0), vec2(12.9898, 78.233))) * 43758.5453);
	float foam = shore * (0.55 + 0.45 * grain) + breaker * (0.4 + 0.5 * grain) + rf * 0.8
		+ clamp((h - 0.25 * amp) * chop * 2.5, 0.0, 1.0) + drop * 0.5;
	foam = clamp(foam, 0.0, 0.92);
	// cartoon: the water in three clear colour steps by depth, foam as crisp white shapes
	float band = floor((1.0 - exp(-max(depth, 0.0) * 0.25)) * 3.0) / 3.0;
	water = mix(vec3(0.1, 0.9, 0.85), vec3(0.0, 0.28, 0.75), band);
	water = mix(water, water * 1.25, clamp(h * 1.5, 0.0, 0.5));
	foam = step(0.45, foam);
	water = mix(water, vec3(1.0), foam);
	// reflection of the sky: towards the horizon colour at grazing angles
	vec3 rv = reflect(-VIEW, nv);
	vec3 up_v = normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz);
	vec3 refl = mix(horizon_col.rgb, sky_col.rgb, smoothstep(0.0, 0.5, dot(rv, up_v)));
	// reflections: sky (Schlick fresnel - always some), and the sun glittering on the ripples
	float fr = 0.03 + 0.97 * pow(1.0 - clamp(dot(nv, VIEW), 0.0, 1.0), 5.0);
	vec3 sv = normalize((VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz);
	// cartoon sparkles: hard white stars of light instead of soft glints
	float glint = step(0.997, max(dot(rv, sv), 0.0)) * 3.0 + step(0.98, max(dot(rv, sv), 0.0)) * 0.35;
	ALBEDO = water * (0.55 + 0.45 * day);
	EMISSION = refl * fr * (0.08 + 0.75 * day) + water * 0.06 * day + vec3(1.0, 0.97, 0.9) * glint * day * (1.0 - foam);
	// a real liquid surface: mostly opaque, a little see-through only in the shallows
	float clear = mix(0.78, 0.97, smoothstep(0.0, 4.0, depth));
	ALPHA = clamp(max(max(clear, fr), foam), 0.0, 1.0) * mix(0.55, 1.0, smoothstep(0.0, 0.35, depth)) * smoothstep(-0.25, 0.05, depth);
	ROUGHNESS = 0.025 + (1.0 - gust) * 0.05 + chop * 0.06 + foam * 0.5 + drop * 0.2;
	METALLIC = 0.05;
	SPECULAR = 0.9;
	if (!FRONT_FACING) {
		// seen from under the water: a bright rippling window straight up, darker at an angle
		vec3 nb = -nv;
		float straight = clamp(dot(nb, VIEW), 0.0, 1.0);
		float window = smoothstep(0.55, 0.85, straight);
		float caust = 0.5 + 0.5 * sin(wp.x * 2.3 + now * 1.6 + sin(wp.z * 1.7 + now)) * sin(wp.z * 2.1 - now * 1.3);
		vec3 under = mix(deep.rgb * 0.35, mix(shallow.rgb, sky_col.rgb, 0.5) * (0.6 + 0.4 * caust), window);
		NORMAL = nb;
		ALBEDO = under * 0.4;
		EMISSION = under * (0.15 + 0.85 * day) * (0.5 + window) + vec3(1.0) * rf * 0.3;
		ALPHA = 0.92;
		SPECULAR = 0.2;
	}
}
"""
