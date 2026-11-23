class_name WaveSim
extends Node
## Real water physics around you: the 2D wave equation solved on the graphics card in a
## 48 x 48 m area that follows the camera (256 x 256 cells, one step every frame).
##   new height = (2 x height - previous height + c x (neighbours - 4 x height)) x damping
## Every disturbance (splash, swimming stroke, wake, a landing capsule, falling debris, rain of
## an explosion) pushes the surface down; the rings that spread out from it interfere with each
## other and are reflected by the shore, rocks and islands (where there is no water the height
## is held at zero = a solid wall for the waves). The sea shader reads the height for real
## up-and-down movement, the light (normals) and foam on steep wave fronts.
## Heights are stored with 16-bit precision in an 8-bit picture (two channels per height):
## R, G = height now, B, A = height one step ago.
## A second pair of pictures holds the FOAM (16-bit in R, G): wakes, splashes and breaking wave
## fronts leave white foam on the water that stays where it was made, spreads a little and
## fades over several seconds - the white trail behind the capsule.

const RES := 256
const SIZE := 64.0                 # metres covered (0.25 m per cell)
const MAX_DROPS := 24

var world: SphereWorld
var vps: Array = []                # two SubViewports (ping-pong: each step reads the other)
var mats: Array = []
var cur := 0                       # the one that was written last
var centre := Vector3.ZERO         # middle of the area (on the water surface)
var t1 := Vector3.RIGHT            # axes of the area (along the sea surface)
var t2 := Vector3.FORWARD
var drops: Array = []              # pending pushes: [Vector2 cell, radius cells, strength]
var foam_drops: Array = []         # pending foam: [Vector2 cell, radius cells, amount]
var fvps: Array = []               # the foam pictures (ping-pong)
var fmats: Array = []
var fcur := 0
var shift := Vector2.ZERO          # cells the area moved since the last step
var ready_k := false
var reset_n := 2                   # steps that still clear the water (start / jump to a new place)


func setup(w: SphereWorld) -> void:
	world = w
	var sh := Shader.new()
	sh.code = SIM_SHADER
	for i in 2:
		var vp := SubViewport.new()
		vp.size = Vector2i(RES, RES)
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		var rect := ColorRect.new()
		rect.size = Vector2(RES, RES)
		var m := ShaderMaterial.new()
		m.shader = sh
		rect.material = m
		vp.add_child(rect)
		add_child(vp)
		vps.append(vp)
		mats.append(m)
	(mats[0] as ShaderMaterial).set_shader_parameter("prev", (vps[1] as SubViewport).get_texture())
	(mats[1] as ShaderMaterial).set_shader_parameter("prev", (vps[0] as SubViewport).get_texture())
	# the foam layer
	var fsh := Shader.new()
	fsh.code = FOAM_SHADER
	for i in 2:
		var vp2 := SubViewport.new()
		vp2.size = Vector2i(RES, RES)
		vp2.transparent_bg = true
		vp2.disable_3d = true
		vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp2.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		var rect2 := ColorRect.new()
		rect2.size = Vector2(RES, RES)
		var m2 := ShaderMaterial.new()
		m2.shader = fsh
		rect2.material = m2
		vp2.add_child(rect2)
		add_child(vp2)
		fvps.append(vp2)
		fmats.append(m2)
	(fmats[0] as ShaderMaterial).set_shader_parameter("prev", (fvps[1] as SubViewport).get_texture())
	(fmats[1] as ShaderMaterial).set_shader_parameter("prev", (fvps[0] as SubViewport).get_texture())
	# start flat: the first two steps clear the water
	_reset()


func _reset() -> void:
	reset_n = 2
	for m: ShaderMaterial in mats:
		m.set_shader_parameter("reset", 1.0)
	for m3: ShaderMaterial in fmats:
		m3.set_shader_parameter("reset", 1.0)


## The latest heights (for the sea shader)
func texture() -> Texture2D:
	return (vps[cur] as SubViewport).get_texture()


## The latest foam (for the sea shader)
func foam_texture() -> Texture2D:
	return (fvps[fcur] as SubViewport).get_texture()


## White foam on the water at p: amount 0..1 added this step, radius in metres
func add_foam(p: Vector3, amount: float, radius: float) -> void:
	if foam_drops.size() >= MAX_DROPS or amount <= 0.0:
		return
	var cell := _cell(p)
	if cell.x < 2.0 or cell.y < 2.0 or cell.x > RES - 2.0 or cell.y > RES - 2.0:
		return
	foam_drops.append([cell, maxf(radius / SIZE * RES, 1.0), clampf(amount, 0.0, 1.0)])


func _cell(p: Vector3) -> Vector2:
	var q := p.normalized() * world.water_radius() - centre
	return Vector2(q.dot(t1), q.dot(t2)) / SIZE * RES + Vector2(RES, RES) * 0.5


## A push on the water at p: strength in metres (0.02 a hand .. 0.6 a crash), radius in metres
func disturb(p: Vector3, strength: float, radius: float) -> void:
	if drops.size() >= MAX_DROPS or strength <= 0.0:
		return
	var cell := _cell(p)
	if cell.x < 2.0 or cell.y < 2.0 or cell.x > RES - 2.0 or cell.y > RES - 2.0:
		return
	drops.append([cell, maxf(radius / SIZE * RES, 1.2), clampf(strength, 0.0, 0.8)])


func _process(_delta: float) -> void:
	if world == null or world.water == null:
		return
	var cam := world.viewer
	if cam.length() < 1.0:
		return
	var up := cam.normalized()
	var on_sea := up * world.water_radius()
	# first time / far away: put the area here
	if not ready_k or on_sea.distance_to(centre) > SIZE * 0.9:
		centre = on_sea
		var b := SphereTerrain.surface_basis(up, 0.0)
		t1 = b.x
		t2 = b.z
		ready_k = true
		_reset()
	elif on_sea.distance_to(centre) > SIZE * 0.18:
		# follow the camera in whole cells (the waves keep their place in the world)
		var q := on_sea - centre
		var cells := Vector2(roundf(q.dot(t1) / SIZE * RES), roundf(q.dot(t2) / SIZE * RES))
		shift = cells
		centre += (t1 * cells.x + t2 * cells.y) * (SIZE / RES)
		centre = centre.normalized() * world.water_radius()
		# keep the axes along the (slightly curved) surface
		var u2 := centre.normalized()
		t1 = (t1 - u2 * t1.dot(u2)).normalized()
		t2 = t1.cross(u2).normalized()
	# one step: write into the other picture
	if reset_n > 0:
		reset_n -= 1
	elif reset_n == 0:
		reset_n = -1
		for m: ShaderMaterial in mats:
			m.set_shader_parameter("reset", 0.0)
		for m3: ShaderMaterial in fmats:
			m3.set_shader_parameter("reset", 0.0)
	var nxt := 1 - cur
	var m2: ShaderMaterial = mats[nxt]
	var dv := PackedVector4Array()
	for i in MAX_DROPS:
		if i < drops.size():
			var d: Array = drops[i]
			var c: Vector2 = d[0]
			dv.append(Vector4(c.x / RES, c.y / RES, float(d[1]) / RES, float(d[2])))
		else:
			dv.append(Vector4(0, 0, 0, 0))
	m2.set_shader_parameter("drops", dv)
	m2.set_shader_parameter("shift", shift / RES)
	# the shore: where the ground is above the water there is no water (waves bounce off)
	var sea: WaterSurface = world.water
	m2.set_shader_parameter("depth_map", sea.near_tex)
	m2.set_shader_parameter("near_c", sea.near_c)
	m2.set_shader_parameter("near_t1", sea.near_t1_cur)
	m2.set_shader_parameter("near_t2", sea.near_t2_cur)
	m2.set_shader_parameter("near_half", WaterSurface.NEAR_HALF)
	m2.set_shader_parameter("near_on", 1.0 if sea.near_c != Vector3.ZERO else 0.0)
	m2.set_shader_parameter("sim_c", centre)
	m2.set_shader_parameter("sim_t1", t1)
	m2.set_shader_parameter("sim_t2", t2)
	m2.set_shader_parameter("sim_size", SIZE)
	(vps[nxt] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	# the foam: same area, same shift; it reads the wave heights for breaking fronts
	var fnxt := 1 - fcur
	var fm: ShaderMaterial = fmats[fnxt]
	var fv := PackedVector4Array()
	for i in MAX_DROPS:
		if i < foam_drops.size():
			var fd: Array = foam_drops[i]
			var fc: Vector2 = fd[0]
			fv.append(Vector4(fc.x / RES, fc.y / RES, float(fd[1]) / RES, float(fd[2])))
		else:
			fv.append(Vector4(0, 0, 0, 0))
	fm.set_shader_parameter("drops", fv)
	fm.set_shader_parameter("shift", shift / RES)
	fm.set_shader_parameter("height", (vps[cur] as SubViewport).get_texture())
	fm.set_shader_parameter("cell_m", SIZE / RES)
	fm.set_shader_parameter("depth_map", sea.near_tex)
	fm.set_shader_parameter("near_c", sea.near_c)
	fm.set_shader_parameter("near_t1", sea.near_t1_cur)
	fm.set_shader_parameter("near_t2", sea.near_t2_cur)
	fm.set_shader_parameter("near_half", WaterSurface.NEAR_HALF)
	fm.set_shader_parameter("near_on", 1.0 if sea.near_c != Vector3.ZERO else 0.0)
	fm.set_shader_parameter("sim_c", centre)
	fm.set_shader_parameter("sim_t1", t1)
	fm.set_shader_parameter("sim_t2", t2)
	fm.set_shader_parameter("sim_size", SIZE)
	(fvps[fnxt] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	fcur = fnxt
	foam_drops.clear()
	drops.clear()
	shift = Vector2.ZERO
	cur = nxt
	# the sea shader follows the area
	sea.set_sim(texture(), foam_texture(), centre, t1, t2, SIZE)


const SIM_SHADER := """
shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D prev : filter_nearest, repeat_disable;
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform vec4 drops[24];
uniform vec2 shift = vec2(0.0);
uniform float reset = 0.0;
uniform vec3 near_c = vec3(0.0);
uniform vec3 near_t1 = vec3(1.0, 0.0, 0.0);
uniform vec3 near_t2 = vec3(0.0, 0.0, 1.0);
uniform float near_half = 40.0;
uniform float near_on = 0.0;
uniform vec3 sim_c = vec3(0.0);
uniform vec3 sim_t1 = vec3(1.0, 0.0, 0.0);
uniform vec3 sim_t2 = vec3(0.0, 0.0, 1.0);
uniform float sim_size = 48.0;
const float RANGE = 2.0;   // heights -1 .. +1 m

vec2 pack(float h) {
	float v = clamp(h / RANGE + 0.5, 0.0, 1.0) * 65535.0;
	float hi = floor(v / 256.0);
	float lo = v - hi * 256.0;
	return vec2(hi, lo) / 255.0;
}
float unpack(vec2 c) {
	float v = floor(c.x * 255.0 + 0.5) * 256.0 + floor(c.y * 255.0 + 0.5);
	return (v / 65535.0 - 0.5) * RANGE;
}
vec4 cell(vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return vec4(pack(0.0), pack(0.0)); }
	return texture(prev, uv);
}
void fragment() {
	if (reset > 0.5) {
		COLOR = vec4(pack(0.0), pack(0.0));
	} else {
		vec2 px = 1.0 / vec2(textureSize(prev, 0));
		vec2 uv = UV + shift;
		vec4 c = cell(uv);
		float h = unpack(c.rg);
		float hp = unpack(c.ba);
		float n = unpack(cell(uv + vec2(px.x, 0.0)).rg) + unpack(cell(uv - vec2(px.x, 0.0)).rg)
			+ unpack(cell(uv + vec2(0.0, px.y)).rg) + unpack(cell(uv - vec2(0.0, px.y)).rg);
		// the wave equation (c = 0.22: ring waves run at about 5-6 m/s, so a capsule surfing
		// faster than that draws a V-shaped wake like a boat), a little damping
		float hn = (2.0 * h - hp + 0.22 * (n - 4.0 * h)) * 0.9982;
		// pushes (splashes, strokes, wakes)
		for (int i = 0; i < 24; i++) {
			vec4 d = drops[i];
			if (d.w <= 0.0) { continue; }
			float r = length(UV - d.xy) / max(d.z, 0.0001);
			hn -= d.w * exp(-r * r * 2.0);
		}
		// no water here (shore, rocks): hold still - waves are reflected
		if (near_on > 0.5) {
			vec3 w = sim_c + sim_t1 * (UV.x - 0.5) * sim_size + sim_t2 * (UV.y - 0.5) * sim_size;
			vec3 q = w - near_c;
			vec2 lc = vec2(dot(q, near_t1), dot(q, near_t2)) / (near_half * 2.0) + 0.5;
			if (lc.x > 0.0 && lc.y > 0.0 && lc.x < 1.0 && lc.y < 1.0) {
				float depth = texture(depth_map, lc).r * 24.0 - 4.0;
				if (depth < 0.05) { hn = 0.0; h = 0.0; }
				else if (depth < 0.6) { hn *= 0.92; }
			}
		}
		// the edges of the area absorb the waves (no reflection from the edge)
		float edge = min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y));
		hn *= smoothstep(0.0, 0.06, edge);
		COLOR = vec4(pack(hn), pack(h));
	}
}
"""


const FOAM_SHADER := """
shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D prev : filter_nearest, repeat_disable;
uniform sampler2D height : filter_nearest, repeat_disable;
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform vec4 drops[24];
uniform vec2 shift = vec2(0.0);
uniform float reset = 0.0;
uniform float cell_m = 0.25;
uniform vec3 near_c = vec3(0.0);
uniform vec3 near_t1 = vec3(1.0, 0.0, 0.0);
uniform vec3 near_t2 = vec3(0.0, 0.0, 1.0);
uniform float near_half = 40.0;
uniform float near_on = 0.0;
uniform vec3 sim_c = vec3(0.0);
uniform vec3 sim_t1 = vec3(1.0, 0.0, 0.0);
uniform vec3 sim_t2 = vec3(0.0, 0.0, 1.0);
uniform float sim_size = 64.0;

vec2 pack(float v) {
	float x = clamp(v, 0.0, 1.0) * 65535.0;
	float hi = floor(x / 256.0);
	float lo = x - hi * 256.0;
	return vec2(hi, lo) / 255.0;
}
float unpack(vec2 c) {
	return (floor(c.x * 255.0 + 0.5) * 256.0 + floor(c.y * 255.0 + 0.5)) / 65535.0;
}
float hunpack(vec2 c) {
	float v = floor(c.x * 255.0 + 0.5) * 256.0 + floor(c.y * 255.0 + 0.5);
	return (v / 65535.0 - 0.5) * 2.0;
}
float foam_at(vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return 0.0; }
	return unpack(texture(prev, uv).rg);
}
void fragment() {
	if (reset > 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 px = 1.0 / vec2(textureSize(prev, 0));
		vec2 uv = UV + shift;
		float f = foam_at(uv);
		float nb = (foam_at(uv + vec2(px.x, 0.0)) + foam_at(uv - vec2(px.x, 0.0))
			+ foam_at(uv + vec2(0.0, px.y)) + foam_at(uv - vec2(0.0, px.y))) * 0.25;
		// spreads out a little and fades over several seconds
		f = max(mix(f, nb, 0.07) * 0.992 - 0.0015, 0.0);   // (gone after about 3 s)
		// new foam: wakes, splashes
		for (int i = 0; i < 24; i++) {
			vec4 d = drops[i];
			if (d.w <= 0.0) { continue; }
			float r = length(UV - d.xy) / max(d.z, 0.0001);
			f += d.w * exp(-r * r * 2.0) * 0.35;
		}
		// steep fronts of the simulated waves break into foam
		vec2 hp = 1.0 / vec2(textureSize(height, 0));
		float h0 = hunpack(texture(height, UV).rg);
		float hx = hunpack(texture(height, UV + vec2(hp.x, 0.0)).rg);
		float hy = hunpack(texture(height, UV + vec2(0.0, hp.y)).rg);
		float sl = length(vec2(hx - h0, hy - h0)) / cell_m;
		f += clamp(sl * 1.6 - 0.35, 0.0, 1.0) * 0.06;
		// no foam on land
		if (near_on > 0.5) {
			vec3 w = sim_c + sim_t1 * (UV.x - 0.5) * sim_size + sim_t2 * (UV.y - 0.5) * sim_size;
			vec3 q = w - near_c;
			vec2 lc = vec2(dot(q, near_t1), dot(q, near_t2)) / (near_half * 2.0) + 0.5;
			if (lc.x > 0.0 && lc.y > 0.0 && lc.x < 1.0 && lc.y < 1.0) {
				float depth = texture(depth_map, lc).r * 24.0 - 4.0;
				if (depth < 0.02) { f = 0.0; }
			}
		}
		float edge = min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y));
		f *= smoothstep(0.0, 0.03, edge);
		COLOR = vec4(pack(f), 0.0, 1.0);
	}
}
"""
