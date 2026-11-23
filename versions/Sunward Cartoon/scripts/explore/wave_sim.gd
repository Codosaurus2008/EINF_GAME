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

const RES := 256
const SIZE := 48.0                 # metres covered
const MAX_DROPS := 16

var world: SphereWorld
var vps: Array = []                # two SubViewports (ping-pong: each step reads the other)
var mats: Array = []
var cur := 0                       # the one that was written last
var centre := Vector3.ZERO         # middle of the area (on the water surface)
var t1 := Vector3.RIGHT            # axes of the area (along the sea surface)
var t2 := Vector3.FORWARD
var drops: Array = []              # pending pushes: [Vector2 cell, radius cells, strength]
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
	# start flat: the first two steps clear the water
	_reset()


func _reset() -> void:
	reset_n = 2
	for m: ShaderMaterial in mats:
		m.set_shader_parameter("reset", 1.0)


## The latest heights (for the sea shader)
func texture() -> Texture2D:
	return (vps[cur] as SubViewport).get_texture()


## A push on the water at p: strength in metres (0.02 a hand .. 0.6 a crash), radius in metres
func disturb(p: Vector3, strength: float, radius: float) -> void:
	if drops.size() >= MAX_DROPS:
		return
	var q := p.normalized() * world.water_radius() - centre
	var cell := Vector2(q.dot(t1), q.dot(t2)) / SIZE * RES + Vector2(RES, RES) * 0.5
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
	drops.clear()
	shift = Vector2.ZERO
	cur = nxt
	# the sea shader follows the area
	sea.set_sim(texture(), centre, t1, t2, SIZE)


const SIM_SHADER := """
shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D prev : filter_nearest, repeat_disable;
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform vec4 drops[16];
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
		// the wave equation (c = 0.12: waves of a few metres per second), a little damping
		float hn = (2.0 * h - hp + 0.12 * (n - 4.0 * h)) * 0.994;
		// pushes (splashes, strokes, wakes)
		for (int i = 0; i < 16; i++) {
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
