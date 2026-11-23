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
var near_mat: ShaderMaterial       # the water seen from above: solid colour (opaque)
var far_mat: ShaderMaterial
var near_under: ShaderMaterial     # second pass: the surface seen from below (partly see-through)
var far_under: ShaderMaterial
var patch: MeshInstance3D
var far: MeshInstance3D
var ripples := PackedVector4Array()       # x, y, z, start time
var ripple_p := PackedVector4Array()      # strength, size, -, -
var ripple_next := 0
# big waves from cannon shells hitting the sea: [position, start time], [height, speed]
const BLASTS := 4
var blasts := PackedVector4Array([Vector4(0, 0, 0, -100.0), Vector4(0, 0, 0, -100.0), Vector4(0, 0, 0, -100.0), Vector4(0, 0, 0, -100.0)])
var blast_p := PackedVector4Array([Vector4.ZERO, Vector4.ZERO, Vector4.ZERO, Vector4.ZERO])
var blast_next := 0
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
# the depth map of the whole planet is baked again once the planet is complete (at the start
# the land was not finished yet, so outside the sharp map around you the sea thought it was
# land and wasn't drawn)
var global_img: Image
var global_tex: ImageTexture
var global_row := 0             # rows re-baked (-1 = done)


func setup(w: SphereWorld) -> void:
	world = w
	water_r = w.water_radius()
	for i in RIPPLES:
		ripples.append(Vector4(0, 0, 0, -100.0))
		ripple_p.append(Vector4.ZERO)
	var depth_tex := _bake_global()
	global_tex = depth_tex
	near_img = Image.create(NEAR_TEX, NEAR_TEX, false, Image.FORMAT_L8)
	near_img.fill(Color(1, 1, 1))
	near_tex = ImageTexture.create_from_image(near_img)
	var look := w.water_look()
	var common := {"deep": look[1], "shallow": look[0], "far_col": look[2], "sky_col": w.biome["sky_top"],
		"horizon_col": w.biome["sky_horizon"], "water_r": water_r, "depth_map": depth_tex,
		"near_depth": near_tex, "near_half": NEAR_HALF}
	near_mat = ShaderMaterial.new()
	near_mat.shader = Shader.new()
	near_mat.shader.code = "shader_type spatial;\n#define NEAR\n" + WATER_BODY
	far_mat = ShaderMaterial.new()
	far_mat.shader = Shader.new()
	far_mat.shader.code = "shader_type spatial;\n" + WATER_BODY
	near_under = ShaderMaterial.new()
	near_under.shader = Shader.new()
	near_under.shader.code = "shader_type spatial;\n#define NEAR\n#define UNDER\n" + WATER_BODY
	far_under = ShaderMaterial.new()
	far_under.shader = Shader.new()
	far_under.shader.code = "shader_type spatial;\n#define UNDER\n" + WATER_BODY
	near_mat.next_pass = near_under
	far_mat.next_pass = far_under
	for k: String in common:
		near_mat.set_shader_parameter(k, common[k])
		far_mat.set_shader_parameter(k, common[k])
		near_under.set_shader_parameter(k, common[k])
		far_under.set_shader_parameter(k, common[k])
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
	global_img = img
	return ImageTexture.create_from_image(img)


## Bakes the whole-planet depth map again after loading, a little every frame (1.5 ms)
var global_col := 0
func _rebake_global() -> void:
	if global_row < 0 or global_img == null:
		return
	var wd := global_img.get_width()
	var ht := global_img.get_height()
	var t0 := Time.get_ticks_usec()
	while global_row < ht and Time.get_ticks_usec() - t0 < 1500:
		var y := global_row
		var lat := (0.5 - (y + 0.5) / ht) * PI
		var x := global_col
		var lon := ((x + 0.5) / wd - 0.5) * TAU
		var d := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
		var depth := world.water_level - world.terrain.height(d)
		global_img.set_pixel(x, y, Color(clampf((depth - DEPTH_MIN) / DEPTH_SPAN, 0.0, 1.0), 0, 0))
		global_col += 1
		if global_col >= wd:
			global_col = 0
			global_row += 1
	if global_row >= ht:
		global_row = -1
		global_tex.update(global_img)


## A ring wave at p. strength 0.05 .. 2.5, size = how wide the rings are (0.15 for a hand,
## 1 for the capsule, 3 for a crash)
func add_ripple(p: Vector3, strength: float, size := 1.0) -> void:
	# the physical waves: a push on the simulated surface (it spreads, interferes, reflects)
	if sim:
		sim.disturb(p, clampf(strength * 0.07, 0.006, 0.4), clampf(size * 0.6, 0.25, 3.0))
		# splashes leave a little foam where they hit
		if strength > 0.25:
			sim.add_foam(p, clampf(strength * 0.35, 0.05, 0.8), clampf(size * 0.5, 0.25, 2.5))
	var q := p.normalized() * water_r
	ripples[ripple_next] = Vector4(q.x, q.y, q.z, world.t)
	ripple_p[ripple_next] = Vector4(strength, clampf(size, 0.08, 4.0), 0.0, 0.0)
	ripple_next = (ripple_next + 1) % RIPPLES


## Something cuts through the water at p: push (m per step) for the simulated waves - moving
## with the capsule it draws the V-shaped wake - and white foam (0..1), size in metres
func wake(p: Vector3, push: float, foam: float, size: float) -> void:
	if sim == null:
		return
	if push > 0.0:
		sim.disturb(p, push, size)
	if foam > 0.0:
		sim.add_foam(p, foam, size * 1.3)


## A shader value for the near water (both passes)
func _np(key: String, v: Variant) -> void:
	near_mat.set_shader_parameter(key, v)
	near_under.set_shader_parameter(key, v)


## A cannon shell explodes in the sea at p: it punches a hole into the water and sends out a
## big ring wave (height in metres at the start) that runs out over the sea, gets longer and
## lower as it travels, and rocks everything floating (the capsule, animals) as it passes.
func add_blast(p: Vector3, height: float) -> void:
	var q := p.normalized() * water_r
	blasts[blast_next] = Vector4(q.x, q.y, q.z, world.t)
	blast_p[blast_next] = Vector4(height, 6.5, 0.0, 0.0)
	blast_next = (blast_next + 1) % BLASTS
	if sim:
		sim.disturb(p, 0.8, 3.0)
		sim.add_foam(p, 1.0, 5.0)


## Height of the blast waves at p (the same as the shader draws)
func blast_height(p: Vector3) -> float:
	var sum := 0.0
	var q := p.normalized() * water_r
	for i in BLASTS:
		var a := blast_p[i].x
		var age := world.t - blasts[i].w
		if a <= 0.0 or age < 0.0 or age > 25.0:
			continue
		var d := q.distance_to(Vector3(blasts[i].x, blasts[i].y, blasts[i].z))
		var x := d - age * blast_p[i].y
		var l := 3.5 + age * 0.35
		var k := TAU / (l * 2.2)
		var env := exp(-(x * x) / (l * l))
		var amp := a * exp(-age * 0.11) / sqrt(1.0 + d * 0.15)
		sum += cos(x * k) * env * amp - a * 1.3 * exp(-(d * d) / 9.0) * exp(-age * 1.6)
	return sum


## The simulated wave heights and foam the near sea uses (WaveSim calls this every step)
func set_sim(tex: Texture2D, foam: Texture2D, c: Vector3, a1: Vector3, a2: Vector3, size: float) -> void:
	_np("sim_tex", tex)
	_np("foam_tex", foam)
	_np("sim_c", c)
	_np("sim_t1", a1)
	_np("sim_t2", a2)
	_np("sim_size", size)
	_np("sim_on", 1.0)


func set_param(key: String, v: Variant) -> void:
	_np(key, v)
	far_mat.set_shader_parameter(key, v)
	far_under.set_shader_parameter(key, v)
	if key == "wave":
		wave_k = float(v)
	elif key == "chop":
		chop_k = float(v)


# ================================================================== the same waves on the CPU
## Exactly the waves the shader draws (same lengths, directions, heights, speeds, the same
## sideways Gerstner movement), so the capsule, swimmers, animals and floating things ride the
## waves you see.
## Gerstner waves: every bit of water moves in a circle as a wave passes (forward on the crest,
## back in the trough). That bunches the water up at the crests (sharp, narrow) and spreads it
## out in the troughs (wide, flat) - the shape of real sea waves. 10 wave trains from a long
## swell (62 m) down to small chop (1.1 m), spread around the wind direction; each runs at the
## speed of real deep-water waves (longer = faster: c = sqrt(g / k)).
var wave_k := 0.3
var chop_k := 0.0
const WIND := Vector3(1.0, 0.0, 0.3)
const LENS := [62.0, 39.0, 25.0, 16.0, 10.3, 6.6, 4.2, 2.7, 1.75, 1.12]
const ANGS := [0.05, 0.42, -0.36, 0.8, -0.7, 1.15, -1.05, 0.3, -1.45, 1.6]
const HS := [0.5, 0.4, 0.3, 0.2, 0.13, 0.085, 0.055, 0.034, 0.02, 0.012]


## The small wave trains (6.6 m .. 1.1 m) are made by the wind right here: there is always a
## light breeze, so they never go flat - even in calm weather the sea is covered in little waves
## (more in rain and storms). Their height doesn't shrink with the big swell.
func _wind_k(i: int) -> float:
	var base := 1.6 if i < 7 else 2.4
	return (base + chop_k * 1.2) / maxf(0.1 + wave_k * 1.1, 0.25) * 0.55


## How much the crests are pinched together (0 = round sine waves .. 1 = crests just breaking)
func steepness() -> float:
	return clampf(0.5 + wave_k * 0.35 + chop_k * 0.15, 0.0, 0.92)


## All wave trains at the calm-water point w: Vector4(sideways movement xyz, height)
func _gerstner(w: Vector3, up: Vector3, amp: float, open_sea: float, steep: float) -> Vector4:
	var wd := (WIND.normalized() - up * WIND.normalized().dot(up)).normalized()
	var sd := up.cross(wd)
	var h := 0.0
	var disp := Vector3.ZERO
	var now := world.t
	for i in 10:
		var dir: Vector3 = wd * cos(float(ANGS[i])) + sd * sin(float(ANGS[i]))
		var k := TAU / float(LENS[i])
		var om := sqrt(9.8 * k)
		var ph := w.dot(dir) * k - now * om + i * 1.93
		var a := float(HS[i]) * amp * (open_sea if i < 2 else 1.0) * (1.0 if i < 5 else _wind_k(i))
		var q := minf(steep / (k * maxf(a, 0.0001) * 10.0), 1.0)
		h += a * sin(ph)
		disp += dir * (q * a * cos(ph))
	return Vector4(disp.x, disp.y, disp.z, h)


## Height of the water surface above the calm sea level at p (metres; + = crest)
func wave_height(p: Vector3) -> float:
	var up := p.normalized()
	var w := up * water_r
	var depth := world.water_level - world.terrain.height(up)
	var shoal := clampf(depth / 3.0, 0.0, 1.0)
	var amp := (0.1 + wave_k * 1.1) * lerpf(0.25, 1.0, shoal)
	var open_sea := clampf(depth / 12.0, 0.0, 1.0)
	var steep := steepness() * shoal
	# the water at p came from a little further back (the waves move it in circles): find that
	# calm-water point in two steps, its wave height is the height at p
	var w0 := w
	for _it in 2:
		var g := _gerstner(w0, up, amp, open_sea, steep)
		var d := Vector3(g.x, g.y, g.z)
		d -= up * d.dot(up)
		w0 = w - d
	return _gerstner(w0, up, amp, open_sea, steep).w + blast_height(p)


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
	# (scaled along the patch's OWN axes: Basis.scaled() scales along the world axes, which squashed
	# the round patch into a narrow strip everywhere except at the poles - and the far sea leaves
	# a round hole for the patch, so outside the strip there was no water at all)
	patch.global_transform = Transform3D(SphereTerrain.surface_basis(up, 0.0) * Basis.from_scale(Vector3(pr, 1.0, pr)), c)
	set_param("now", world.t)
	_rebake_global()
	set_param("patch_c", c)
	set_param("patch_r", pr)
	_np("ripples", ripples)
	_np("ripple_p", ripple_p)
	_np("blasts", blasts)
	_np("blast_p", blast_p)
	# the wind sets the waves' direction
	var wind_v := Vector3(1.0, 0.0, 0.3).normalized()
	_np("wind_dir", wind_v)
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
	global_row = 0
	global_col = 0


const WATER_BODY := """
#ifdef UNDER
render_mode blend_mix, cull_disabled, depth_draw_never, world_vertex_coords, shadows_disabled, unshaded;
#else
render_mode cull_disabled, depth_draw_opaque, world_vertex_coords, shadows_disabled, unshaded, fog_disabled;
#endif
// (unshaded: the water shows exactly the colours below - the scene's lighting made it dark;
// the sun's glitter, the sky reflection and the light through the waves are added by hand)
uniform vec4 deep : source_color = vec4(0.03, 0.19, 0.31, 1.0);
uniform vec4 shallow : source_color = vec4(0.21, 0.79, 0.78, 1.0);
uniform vec4 sky_col : source_color = vec4(0.4, 0.6, 0.9, 1.0);
uniform vec4 horizon_col : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform vec4 far_col : source_color = vec4(0.16, 0.42, 0.6, 1.0);
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
uniform vec4 blasts[4];
uniform vec4 blast_p[4];
uniform sampler2D sim_tex : filter_nearest, repeat_disable;
uniform sampler2D foam_tex : filter_nearest, repeat_disable;
uniform vec3 sim_c = vec3(0.0);
uniform vec3 sim_t1 = vec3(1.0, 0.0, 0.0);
uniform vec3 sim_t2 = vec3(0.0, 0.0, 1.0);
uniform float sim_size = 64.0;
uniform float sim_on = 0.0;

// ---- the simulated (physical) waves and foam around the camera, 16-bit packed pictures
float unpack16(vec2 c) {
	return (floor(c.x * 255.0 + 0.5) * 256.0 + floor(c.y * 255.0 + 0.5)) / 65535.0;
}
// smooth reading (4 texels by hand: packed values can't be filtered by the graphics card)
// which: 0 = height (metres), 1 = foam (0..1)
float sim_read(vec3 p, int which) {
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
	float a; float b; float c; float d;
	if (which == 0) {
		a = unpack16(texelFetch(sim_tex, i0, 0).rg);
		b = unpack16(texelFetch(sim_tex, ivec2(i1.x, i0.y), 0).rg);
		c = unpack16(texelFetch(sim_tex, ivec2(i0.x, i1.y), 0).rg);
		d = unpack16(texelFetch(sim_tex, i1, 0).rg);
		a = (a - 0.5) * 2.0; b = (b - 0.5) * 2.0; c = (c - 0.5) * 2.0; d = (d - 0.5) * 2.0;
	} else {
		a = unpack16(texelFetch(foam_tex, i0, 0).rg);
		b = unpack16(texelFetch(foam_tex, ivec2(i1.x, i0.y), 0).rg);
		c = unpack16(texelFetch(foam_tex, ivec2(i0.x, i1.y), 0).rg);
		d = unpack16(texelFetch(foam_tex, i1, 0).rg);
	}
	return mix(mix(a, b, fr.x), mix(c, d, fr.x), fr.y) * smoothstep(0.0, 0.08, edge);
}
float sim_h(vec3 p) { return sim_read(p, 0); }
float sim_foam(vec3 p) { return sim_read(p, 1); }

varying vec3 wp;      // calm-water point (the waves are computed from it)
varying vec3 wpd;     // where that water is now (moved sideways by the waves)

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

// (see WaterSurface._wind_k: the small waves made by the light wind never go flat)
float wind_k_s(int i) {
	float base = i < 7 ? 1.6 : 2.4;
	return (base + chop * 1.2) / max(0.1 + wave * 1.1, 0.25) * 0.55;
}

float steep_k() { return clamp(0.5 + wave * 0.35 + chop * 0.15, 0.0, 0.92); }

// 10 Gerstner wave trains (the same as WaterSurface.wave_height on the CPU): every bit of water
// moves in a circle, so crests are sharp and narrow and troughs wide and flat. Returns the
// height; disp = sideways movement, slope = the tilt of the surface, pinch = how much the water
// is bunched together (small on sharp crests: foam and light there).
float gerstner(vec3 p, vec3 up, float amp, float open_sea, float steep, out vec3 disp, out vec3 slope, out float pinch) {
	vec3 wd = normalize(wind_dir - up * dot(wind_dir, up));
	vec3 sd = cross(up, wd);
	float lens[10] = float[10](62.0, 39.0, 25.0, 16.0, 10.3, 6.6, 4.2, 2.7, 1.75, 1.12);
	float angs[10] = float[10](0.05, 0.42, -0.36, 0.8, -0.7, 1.15, -1.05, 0.3, -1.45, 1.6);
	float hs[10] = float[10](0.5, 0.4, 0.3, 0.2, 0.13, 0.085, 0.055, 0.034, 0.02, 0.012);
	float h = 0.0;
	disp = vec3(0.0);
	slope = vec3(0.0);
	pinch = 1.0;
	for (int i = 0; i < 10; i++) {
		vec3 dir = wd * cos(angs[i]) + sd * sin(angs[i]);
		float k = 6.2831853 / lens[i];
		float om = sqrt(9.8 * k);
		float ph = dot(p, dir) * k - now * om + float(i) * 1.93;
		float a = hs[i] * amp * (i < 2 ? open_sea : 1.0) * (i < 5 ? 1.0 : wind_k_s(i));
		float q = min(steep / (k * max(a, 0.0001) * 10.0), 1.0);
		float s = sin(ph);
		float c = cos(ph);
		h += a * s;
		disp += dir * (q * a * c);
		slope += dir * (k * a * c);
		pinch -= q * k * a * s;
	}
	return h;
}

float tk_foam(float d) { return 1.0 - smoothstep(60.0, 220.0, d) * 0.6; }

// ring waves from splashes; adds their slope to grad, returns height
// big ring waves from cannon shells hitting the sea (the same as WaterSurface.blast_height):
// a hole punched into the water that fills up, and a big wave running out that grows longer
// and lower; foam on its crest and where the shell hit
float blast_waves(vec3 p, inout vec3 grad, inout float foam) {
	float sum = 0.0;
	for (int i = 0; i < 4; i++) {
		float a = blast_p[i].x;
		float age = now - blasts[i].w;
		if (a <= 0.0 || age < 0.0 || age > 25.0) { continue; }
		vec3 dv = p - blasts[i].xyz;
		float d = length(dv);
		float x = d - age * blast_p[i].y;
		float l = 3.5 + age * 0.35;
		float k = 6.2831853 / (l * 2.2);
		float env = exp(-(x * x) / (l * l));
		float amp = a * exp(-age * 0.11) / sqrt(1.0 + d * 0.15);
		float hole_k = a * 1.3 * exp(-age * 1.6);
		float hole = exp(-(d * d) / 9.0);
		sum += cos(x * k) * env * amp - hole_k * hole;
		float dh = (-sin(x * k) * k * env - cos(x * k) * env * 2.0 * x / (l * l)) * amp + hole_k * hole * 2.0 * d / 9.0;
		grad += (dv / max(d, 0.001)) * dh;
		foam += env * smoothstep(0.4, 1.0, cos(x * k)) * clamp(amp * 0.8, 0.0, 1.0) + hole * exp(-age * 0.7);
	}
	return sum;
}

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
		float fade = rp.x * exp(-age * 0.42) / (1.0 + d * 0.5 / sz);
		float w = 7.0 / sz;
		float env = exp(-abs(k) * 2.2 / sz);
		sum += sin(k * w) * env * fade * sz * 0.12;
		grad += (dv / max(d, 0.001)) * cos(k * w) * w * env * fade * sz * 0.12;
		foam += env * fade * smoothstep(0.6, 0.0, age);
	}
	return sum;
}

// small value noise (for breaking the foam up into lacy patches and streaks)
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 w = normalize(VERTEX) * water_r;
	vec3 up = normalize(w);
	wp = w;
#ifdef NEAR
	float wdepth = depth_at(w);
	// waves are lower (and rounder) in shallow water and stop at the beach
	float shoal = clamp(wdepth / 3.0, 0.0, 1.0);
	float amp = (0.1 + wave * 1.1) * mix(0.25, 1.0, shoal);
	float open_sea = clamp(wdepth / 12.0, 0.0, 1.0);
	float near_k = 1.0 - smoothstep(patch_r * 0.55, patch_r * 0.95, distance(w, patch_c));
	vec3 disp;
	vec3 sl;
	float pinch;
	float h = gerstner(w, up, amp, open_sea, steep_k() * shoal, disp, sl, pinch) * near_k;
	vec3 hd = (disp - up * dot(disp, up)) * near_k;
	float rf;
	vec3 g2 = vec3(0.0);
	h += rings(w, g2, rf) * near_k * (1.0 - sim_on * 0.7);
	float bf = 0.0;
	h += blast_waves(w, g2, bf) * near_k;
	h += sim_h(w);
	VERTEX = w + hd + up * h;
	wpd = w + hd;
#else
	VERTEX = w;
	wpd = w;
#endif
	NORMAL = up;
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
	float open_sea = clamp(depth / 12.0, 0.0, 1.0);
	vec3 disp_f;
	vec3 g;
	float pinch;
	float h = gerstner(wp, up, amp, open_sea, steep_k() * shoal, disp_f, g, pinch);
	pinch = max(pinch, 0.04);
	float rf = 0.0;
	float trail = 0.0;
#ifdef NEAR
	// (the drawn rings are only a light touch now: the simulated water makes the real, uneven
	// rings that run into each other, so splashes don't look like stamped circles)
	vec3 gr = vec3(0.0);
	h += rings(wpd, gr, rf) * (1.0 - sim_on * 0.75);
	float bfoam = 0.0;
	h += blast_waves(wpd, g, bfoam);
	g += gr * (1.0 - sim_on * 0.75);
	rf *= 0.5 + 0.5 * vnoise(vec2(dot(wpd, sim_t1), dot(wpd, sim_t2)) * 3.0);
	// the physical waves: their slope bends the light (the V of the wake shows), steep fronts foam
	float s0 = sim_h(wpd);
	float sx = sim_h(wpd + sim_t1 * 0.2) - sim_h(wpd - sim_t1 * 0.2);
	float sz = sim_h(wpd + sim_t2 * 0.2) - sim_h(wpd - sim_t2 * 0.2);
	g += (sim_t1 * sx + sim_t2 * sz) / 0.4;
	rf = rf * (1.0 - sim_on * 0.6) + clamp(length(vec2(sx, sz)) * 5.0 - 0.3, 0.0, 0.7);
	rf += clamp(bfoam, 0.0, 1.0);
	h += s0;
	// foam trails: wakes, landings and splashes leave white foam that drifts apart and fades
	trail = sim_foam(wpd);
#endif
	// thousands of small wind ripples on top: 8 short wave trains (12 cm .. 1 m) in different
	// directions plus a drifting noise; they catch the sun (the glitter) and give the water its
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
	tiny *= tk * wind_k;                // (the light wind's ripples on top of the small waves)
	// the surface is smoother in some patches, rougher in others (wind gusts)
	float gust = 0.5 + 0.5 * sin(nq.x * 0.21 + now * 0.4 + sin(nq.y * 0.17 - now * 0.3) * 2.0);
	// rain drops: small expanding rings
	vec2 rc = vec2(wp.x + wp.y * 0.5, wp.z - wp.y * 0.5) * 5.0;
	vec2 cell = floor(rc);
	float phase = fract(now * 1.3 + fract(sin(dot(cell, vec2(12.9, 78.2))) * 437.5));
	float rdist = length(fract(rc) - 0.5);
	float drop = rain * (1.0 - smoothstep(0.0, 0.05, abs(rdist - phase * 0.45))) * (1.0 - phase) * tk;
	// the Gerstner normal: tilted by the slope, steeper where the crests are pinched
	vec3 slope = g - up * dot(g, up);
	vec3 n = normalize(up * pinch - slope + tiny * (0.6 + 0.6 * gust) + vec3(drop * 0.4, 0.0, drop * 0.4));
	vec3 nv = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	NORMAL = nv;
	// colour by depth: clear turquoise in the shallows, deep blue in the deep
	// (the turquoise reaches out a long way before the water turns full blue)
	float dk = 1.0 - exp(-max(depth, 0.0) * 0.12);
	// ONE colour everywhere: the turquoise of the planet's water. (It used to change with the
	// depth and the distance, and the depth maps made bands / strips of different colour.)
	vec3 water = shallow.rgb;
	// deeper water a little more blue (gently, like the darker patches in a lagoon)
	water = mix(water, deep.rgb, smoothstep(0.15, 1.0, dk) * 0.3);
	dk *= 0.0;
	// the thin tops of the waves let light through: they glow turquoise
	float crest_h = clamp(h / max(amp * 1.2, 0.05), -1.0, 1.0);
	water = mix(water, shallow.rgb * 1.1, clamp(crest_h * 0.45, 0.0, 0.4) * (1.0 - dk * 0.4));
	// a little darker in the troughs
	water *= 1.0 - clamp(-crest_h, 0.0, 1.0) * 0.04;
	// ---- foam
	// (beach foam and breaking waves only near you, where the depth is known exactly - far
	// away the coarse depth map drew stripes of foam)
	float near_depth_k = 1.0 - smoothstep(30.0, 45.0, cam_d);
	float shore = (1.0 - smoothstep(0.05, 0.45, depth)) * near_depth_k;
	float breaker = smoothstep(0.75, 1.0, sin(depth * 3.2 + now * 1.7 + sin(wp.x * 0.3 + wp.z * 0.2) * 1.5)) * (1.0 - smoothstep(0.3, 2.2, depth)) * step(0.0, depth) * near_depth_k;
	float grain = fract(sin(dot(floor(wp.xz * 9.0 + wp.y * 3.0), vec2(12.9898, 78.233))) * 43758.5453);
	// whitecaps: where the Gerstner crests are pinched the water breaks; the wind tears the foam
	// into streaks (more in a storm)
	vec2 sq = vec2(dot(wp, wdir) * 0.6, dot(wp, sdir) * 2.2);
	float streak = 0.5 + 0.5 * sin(sq.x * 1.7 + sin(sq.y * 0.9) * 2.0 + now * 0.5) * sin(sq.y * 1.3 + now * 0.3);
	float crest = smoothstep(0.42, 0.08, pinch) * clamp(wave * 1.6 + chop * 1.2 - 0.15, 0.0, 1.0);
	float caps = crest * (0.35 + 0.65 * streak) * (0.55 + 0.45 * grain) * tk_foam(cam_d);
	// the foam trails are lacy at their thin edges and solid white where they are thick
	vec2 fq = vec2(dot(wpd, wdir), dot(wpd, sdir));
	float lace = vnoise(fq * 2.6 + vec2(now * 0.05, 0.0)) * 0.6 + vnoise(fq * 7.5 - vec2(0.0, now * 0.08)) * 0.4;
	// solid white foam with a crisp ragged edge (like the white wake behind a jet ski)
	float trail_w = smoothstep(0.26, 0.31, trail * (0.7 + 0.6 * lace));
	float foam = shore * (0.55 + 0.45 * grain) + breaker * (0.4 + 0.5 * grain) + rf * 0.8
		+ drop * 0.5 + caps + trail_w * 0.7;
	foam = clamp(foam, 0.0, 1.0);
	// light under the foam: bubbly turquoise water just around it
	water = mix(water, shallow.rgb * 1.15, clamp(trail * 1.2, 0.0, 0.3) * (1.0 - foam));
	water = mix(water, vec3(0.94, 0.97, 1.0), foam);
	// ---- reflections
	vec3 rv = reflect(-VIEW, nv);
	vec3 up_v = normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz);
	vec3 refl = mix(horizon_col.rgb, sky_col.rgb, smoothstep(0.0, 0.5, dot(rv, up_v)));
	// Schlick fresnel: the sky shows at grazing angles, you look into the water from above
	float fr = 0.03 + 0.97 * pow(1.0 - clamp(dot(nv, VIEW), 0.0, 1.0), 5.0);
	vec3 sv = normalize((VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz);
	// the sun glitters on the small ripples: a sharp sparkle and a wider sheen
	float rs = max(dot(rv, sv), 0.0);
	float glint = pow(rs, 900.0) * 9.0 + pow(rs, 120.0) * 0.6 + pow(rs, 18.0) * 0.06;
	// looking towards the sun through a wave: light shines through its top (turquoise glow)
	float back = pow(clamp(dot(-VIEW, sv), 0.0, 1.0), 4.0) * clamp(crest_h + 0.2, 0.0, 1.0);
	vec3 sss = shallow.rgb * back * 0.55 * (1.0 - foam);
	// from far away (and from high up) the sea is one even colour: blue or grey by planet
	// (no change of colour with distance any more)
	// the final colour: the bright water, the sky mirrored at grazing angles (a little lighter
	// than the sky itself), light through the wave tops and the sun's glitter; darker at night
	vec3 col = water * mix(0.22, 1.0, day);
	// the waves are lit by the sun: faces turned to the sun lighter, faces turned away darker
	// (this gives the water its moving texture)
	float lit = dot(n, normalize(sun_dir));
	col *= mix(0.8, 1.1, clamp(lit * 0.5 + 0.5, 0.0, 1.0)) * (1.0 - foam) + foam;
	// (only a light touch of sky: at a flat angle the mirrored sky used to cover the whole sea
	// further away, so the turquoise was only seen in a strip close by)
	col = mix(col, mix(refl, water, 0.5) * mix(0.15, 1.0, day), min(fr, 0.6) * 0.3 * (1.0 - foam));
	// (the scene's haze washed the sea out to a pale grey-blue a short way off: the water has its
	// own, much lighter haze, only towards the horizon)
	// (no haze: the water keeps its colour all the way to the horizon)
	col += sss * day + vec3(1.0, 0.97, 0.9) * glint * day * (1.0 - foam) * (0.6 + 0.4 * gust);
#ifndef UNDER
	// seen from above: solid coloured water (drawn opaque - nothing shows through); the
	// water ends exactly at the beach
	// (above or below is decided by where the camera is, not by which side of the triangles
	// faces it - the triangles' winding must not decide what you see)
	bool above = dot(CAMERA_POSITION_WORLD - (wpd + up * h), up) > 0.0;
	// (no cut-off by the depth map: land above the water simply covers it)
	if (!above) { discard; }
	ALBEDO = col;
#else
	// second pass: only the surface seen from below
	bool above_u = dot(CAMERA_POSITION_WORLD - (wpd + up * h), up) > 0.0;
	if (above_u) { discard; }
	{
		// seen from under the water: a bright rippling window straight up, darker at an angle
		vec3 nb = -nv;
		float straight = clamp(dot(nb, VIEW), 0.0, 1.0);
		float window = smoothstep(0.55, 0.85, straight);
		float caust = 0.5 + 0.5 * sin(wp.x * 2.3 + now * 1.6 + sin(wp.z * 1.7 + now)) * sin(wp.z * 2.1 - now * 1.3);
		vec3 under = mix(deep.rgb * 0.35, mix(shallow.rgb, sky_col.rgb, 0.5) * (0.6 + 0.4 * caust), window);
		NORMAL = nb;
		ALBEDO = under * (0.15 + 0.85 * day) * (0.5 + window) + vec3(1.0) * (rf + trail_w) * 0.3;
		// seen from below: partly see-through (you can make out the sky and the capsule above)
		ALPHA = 0.6;
	}
#endif
}
"""
