class_name Rivers
extends Node3D
## Draws the rivers that SphereTerrain traced and carved: a flowing water (or lava) ribbon along
## every river, lying exactly on the carved bed's water level. The surface streams downhill,
## faster and white where it is steep (rapids), and falls as a waterfall where the land drops.
## Waterfalls throw up mist; pools at the end of a river are round and calm; where a river
## reaches the sea, it fades into it with foam.

var world: SphereWorld
var mat: ShaderMaterial
var falls: Array = []           # [position, up, strength] of waterfalls (mist, sound)
var lake_mat: ShaderMaterial
var foam_mat: ShaderMaterial


func setup(w: SphereWorld) -> void:
	world = w
	var t := w.terrain
	if t.rivers.is_empty():
		return
	var lava := t.river_liquid == "lava"
	mat = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = RIVER_SHADER
	mat.set_shader_parameter("lava", 1.0 if lava else 0.0)
	mat.set_shader_parameter("sky_col", w.biome["sky_top"])
	var look := w.water_look()
	mat.set_shader_parameter("shallow", look[0])
	mat.set_shader_parameter("deep", look[1])
	# lakes and pools: the same water, but still (no current)
	lake_mat = mat.duplicate()
	lake_mat.set_shader_parameter("still", 1.0)
	foam_mat = ShaderMaterial.new()
	foam_mat.shader = Shader.new()
	foam_mat.shader.code = FOAM_SHADER
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(w.pid) + 4242
	for rv: Dictionary in t.rivers:
		_ribbon(rv)
		if bool(rv["pool"]):
			_pool(rv)
		if not lava:
			_bed_rocks(rv, rng)
	for lk: Dictionary in t.lakes:
		_lake(lk)


func _ribbon(rv: Dictionary) -> void:
	var t := world.terrain
	var r := t.radius
	var pts: Array = rv["pts"]
	var surfs: Array = rv["surf"]
	var ws: Array = rv["w"]
	var n := pts.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var along := 0.0
	var end_k := 1.0
	var lst: Vector3 = pts[n - 1]
	var last := lst * (r + float(surfs[n - 1]))
	for i in n:
		var d: Vector3 = pts[i]
		var sf := float(surfs[i])
		var c := d * (r + sf + 0.02)
		var prv: Vector3 = pts[maxi(i - 1, 0)]
		var nxt: Vector3 = pts[mini(i + 1, n - 1)]
		var tang := (nxt - prv)
		tang -= d * tang.dot(d)
		var side := d.cross(tang.normalized()).normalized()
		var w := float(ws[i]) + 0.25
		# how steep the water runs here (rapids / waterfall)
		var drop := 0.0
		if i > 0:
			drop = (float(surfs[i - 1]) - sf) / 2.0
			if drop > 0.35:
				falls.append([c, d, drop])
		if i > 0:
			var pd: Vector3 = pts[i - 1]
			along += (pd * (r + float(surfs[i - 1]))).distance_to(c)
		# fades into the sea at the mouth
		if world.water_level > -900.0:
			end_k = clampf((sf - world.water_level + 0.5) / 1.0, 0.0, 1.0)
		var steep := clampf(drop * 2.5, 0.0, 1.0)
		# depth of the water in the middle of the bed (see SphereTerrain._river_carve)
		var mid_depth := 0.16 + float(ws[i]) * 0.05
		for s: float in [-1.0, -0.4, 0.4, 1.0]:
			# a slight curve across: the middle is a little higher (flowing water bulges)
			var lift := (1.0 - absf(s)) * 0.02
			verts.append(c + side * w * s + d * lift)
			norms.append(d)
			uvs.append(Vector2((s + 1.0) * 0.5, along))
			var dv := mid_depth * (0.84 if absf(s) < 0.5 else 0.0)
			cols.append(Color(steep, end_k, clampf(w / 3.0, 0.0, 1.0), clampf(dv / 4.0, 0.0, 1.0)))
	for i in n - 1:
		for s in 3:
			var a := i * 4 + s
			var b := a + 1
			var c2 := a + 4
			var dd := c2 + 1
			idx.append_array(PackedInt32Array([a, c2, b, b, c2, dd]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# mist over the waterfalls
	for f: Array in falls:
		if float(f[2]) < 0.35:
			continue
		var p := CPUParticles3D.new()
		p.amount = 24
		p.lifetime = 2.5
		p.local_coords = false
		p.direction = Vector3.UP
		p.spread = 50.0
		p.initial_velocity_min = 0.2
		p.initial_velocity_max = 0.6
		p.gravity = Vector3.ZERO
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.4
		p.mesh = Particles.soft_quad(0.6)
		p.material_override = Particles.material(Color.WHITE, world.terrain.river_liquid == "lava")
		var g := Gradient.new()
		var mc := Color(1.0, 0.5, 0.15, 0.5) if world.terrain.river_liquid == "lava" else Color(0.95, 0.98, 1.0, 0.35)
		g.set_color(0, mc)
		g.set_color(1, Color(mc, 0.0))
		p.color_ramp = g
		p.visibility_range_end = 70.0
		add_child(p)
		p.position = f[0]
		p.basis = SphereTerrain.surface_basis(f[1], 0.0)
	falls.clear()


func _pool(rv: Dictionary) -> void:
	var t := world.terrain
	var pts: Array = rv["pts"]
	var surfs: Array = rv["surf"]
	var ce: Vector3 = pts[pts.size() - 1]
	var pr := float(rv["pool_r"]) + 0.6
	var sf := float(surfs[surfs.size() - 1])
	var basis := SphereTerrain.surface_basis(ce, 0.0)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var segs := 28
	verts.append(ce * (t.radius + sf + 0.02))
	norms.append(ce)
	uvs.append(Vector2(0.5, 0.5))
	cols.append(Color(0.0, 1.0, clampf(pr / 30.0, 0.0, 1.0), 0.35 / 4.0))
	for s in segs:
		var a := TAU * s / segs
		var off := (basis.x * cos(a) + basis.z * sin(a)) * pr
		var d := (ce * t.radius + off).normalized()
		verts.append(d * (t.radius + sf + 0.02))
		norms.append(d)
		uvs.append(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
		cols.append(Color(0.0, 1.0, clampf(pr / 30.0, 0.0, 1.0), 0.0))
	for s in segs:
		idx.append_array(PackedInt32Array([0, 1 + s, 1 + (s + 1) % segs]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = lake_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## A lake: a disc of rings lying on the water level; every vertex knows how deep the water is
## there (clear near the shore, dark in the middle)
func _lake(lk: Dictionary) -> void:
	var t := world.terrain
	var ce: Vector3 = lk["c"]
	var lr := float(lk["r"]) + 1.2
	var sf := float(lk["surf"])
	var basis := SphereTerrain.surface_basis(ce, 0.0)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var rings := 10
	var segs := 56
	verts.append(ce * (t.radius + sf + 0.02))
	norms.append(ce)
	uvs.append(Vector2(0.5, 0.5))
	cols.append(Color(0.0, 1.0, clampf(lr / 30.0, 0.0, 1.0), clampf((sf - t.height(ce)) / 4.0, 0.0, 1.0)))
	for ri in range(1, rings + 1):
		var rr := lr * float(ri) / rings
		for sg in segs:
			var a := TAU * sg / segs
			var off := (basis.x * cos(a) + basis.z * sin(a)) * rr
			var d := (ce * t.radius + off).normalized()
			verts.append(d * (t.radius + sf + 0.02))
			norms.append(d)
			uvs.append(Vector2(0.5 + cos(a) * 0.5 * rr / lr, 0.5 + sin(a) * 0.5 * rr / lr))
			cols.append(Color(0.0, 1.0, clampf(lr / 30.0, 0.0, 1.0), clampf((sf - t.height(d)) / 4.0, 0.0, 1.0)))
	for sg in segs:
		idx.append_array(PackedInt32Array([0, 1 + sg, 1 + (sg + 1) % segs]))
	for ri in range(1, rings):
		var a0 := 1 + (ri - 1) * segs
		var b0 := 1 + ri * segs
		for sg in segs:
			var s1 := (sg + 1) % segs
			idx.append_array(PackedInt32Array([a0 + sg, b0 + sg, a0 + s1, a0 + s1, b0 + sg, b0 + s1]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = lake_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Stones in the beds of streams and rivers: rounded, wet, some sticking out of the water with
## white water swirling around them (like a mountain stream)
func _bed_rocks(rv: Dictionary, rng: RandomNumberGenerator) -> void:
	var t := world.terrain
	var pts: Array = rv["pts"]
	var surfs: Array = rv["surf"]
	var ws: Array = rv["w"]
	var holder := Node3D.new()
	add_child(holder)
	var fv := PackedVector3Array()
	var fn := PackedVector3Array()
	var fu := PackedVector2Array()
	var fi := PackedInt32Array()
	var stream := bool(rv.get("stream", false))
	var i := 2
	while i < pts.size() - 2:
		i += rng.randi_range(2, 5) if stream else rng.randi_range(4, 9)
		if i >= pts.size() - 1:
			break
		var d: Vector3 = pts[i]
		var nxt: Vector3 = pts[i + 1]
		var tang := nxt - d
		tang = (tang - d * tang.dot(d)).normalized()
		var side := d.cross(tang)
		var w := float(ws[i])
		var off := rng.randf_range(-0.8, 0.8) * w
		var dd := (d * t.radius + side * off).normalized()
		var sz := rng.randf_range(0.18, 0.45) * (1.0 if stream else 1.4)
		var col := Color("#6a6a64").lerp(Color("#8a8478"), rng.randf())
		var rock := WorldProps.rock(rng, col, sz, 0.55)
		holder.add_child(rock)
		var bed := t.height(dd)
		rock.position = dd * (t.radius + bed + sz * 0.25)
		rock.basis = SphereTerrain.surface_basis(dd, rng.randf() * TAU)
		var sf := float(surfs[i])
		world.obstacles.append([rock.position, sz * 0.7, 1])
		# sticks out of the water: a ring of white water around it, trailing downstream
		if bed + sz * 0.9 > sf - 0.02:
			var c := dd * (t.radius + sf + 0.035)
			var fr := sz * 1.5
			var base := fv.size()
			for q in 4:
				var cx := -1.0 if q == 0 or q == 3 else 1.0
				var cy := -1.0 if q < 2 else 1.0
				# longer downstream (the wake behind the stone)
				var along := cy * fr * (2.2 if cy > 0.0 else 1.0)
				fv.append(c + side * cx * fr + tang * along)
				fn.append(dd)
				fu.append(Vector2((cx + 1.0) * 0.5, (cy + 1.0) * 0.5))
			fi.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	CMesh.merge_deep(holder)
	for c2 in holder.get_children():
		var gi := c2 as GeometryInstance3D
		if gi:
			gi.visibility_range_end = 90.0
	if fv.size() > 0:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = fv
		arr[Mesh.ARRAY_NORMAL] = fn
		arr[Mesh.ARRAY_TEX_UV] = fu
		arr[Mesh.ARRAY_INDEX] = fi
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = foam_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 70.0
		add_child(mi)


## White water around stones: a foaming ring that swirls, with a trail downstream
const FOAM_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	// UV: x across, y along the flow (0 = upstream edge, 1 = end of the wake)
	vec2 q = vec2((UV.x - 0.5) * 2.0, UV.y * 3.2 - 1.0);
	float r = length(vec2(q.x, min(q.y, 0.0) * 1.0 + max(q.y, 0.0) * 0.35));
	float ring = smoothstep(1.0, 0.55, r) * smoothstep(0.25, 0.5, length(q));
	float n = vnoise(vec2(UV.x * 9.0, UV.y * 6.0 - TIME * 2.2)) * 0.6 + vnoise(vec2(UV.x * 17.0 + 3.0, UV.y * 13.0 - TIME * 3.1)) * 0.5;
	float foam = ring * smoothstep(0.35, 0.75, n + ring * 0.35 - max(q.y, 0.0) * 0.12);
	ALBEDO = vec3(0.95, 0.97, 1.0);
	EMISSION = vec3(0.25);
	ROUGHNESS = 0.6;
	ALPHA = clamp(foam, 0.0, 0.9);
}
"""


const RIVER_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always;
uniform float lava = 0.0;
uniform float still = 0.0;
uniform vec4 sky_col : source_color = vec4(0.5, 0.7, 1.0, 1.0);
uniform vec4 shallow : source_color = vec4(0.25, 0.6, 0.55, 1.0);
uniform vec4 deep : source_color = vec4(0.05, 0.2, 0.25, 1.0);
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	float steep = COLOR.r;
	float end_k = COLOR.g;
	float w = COLOR.b * 3.0;
	float depth = COLOR.a * 4.0;
	float speed = (0.6 + steep * 3.5) * (1.0 - still);
	// the surface streams downhill: two layers of moving ripples (lakes: slow wind ripples)
	vec2 uv = still > 0.5 ? (UV - 0.5) * COLOR.b * 30.0 + vec2(TIME * 0.05, TIME * 0.03) : vec2(UV.x * w * 2.0, UV.y);
	vec2 a = vec2(uv.x * 2.2, uv.y * 1.3 - TIME * speed);
	vec2 b = vec2(uv.x * 3.7 + 1.3, uv.y * 2.1 - TIME * speed * 1.4);
	float n1 = vnoise(a * 2.0);
	float n2 = vnoise(b * 3.0);
	vec3 up = normalize(wp);
	vec3 t1 = normalize(cross(up, vec3(0.0, 1.0, 0.1)));
	vec3 t2 = cross(up, t1);
	vec3 n = normalize(up + (t1 * (n1 - 0.5) + t2 * (n2 - 0.5)) * (0.25 + steep * 0.5));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float edge = still > 0.5 ? 1.0 : 1.0 - abs(UV.x - 0.5) * 2.0;
	// white water on rapids and falls, a little foam along the banks
	float foam = smoothstep(0.55, 0.9, n1 * 0.6 + n2 * 0.6 + steep * 0.7 - 0.2) * (0.2 + steep)
		+ (1.0 - smoothstep(0.0, 0.18, edge)) * 0.35 * n2 + (1.0 - end_k) * 0.3 * n1;
	foam = clamp(foam, 0.0, 1.0);
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	if (lava > 0.5) {
		// glowing lava: dark crust drifting on bright molten rock
		float crust = smoothstep(0.45, 0.7, vnoise(a * 1.4) * 0.7 + vnoise(b * 0.9) * 0.5);
		vec3 hot = mix(vec3(1.0, 0.55, 0.1), vec3(1.0, 0.85, 0.35), n2);
		ALBEDO = mix(hot * 0.3, vec3(0.08, 0.04, 0.03), crust);
		EMISSION = hot * (1.0 - crust) * (2.2 + steep * 1.5);
		ROUGHNESS = mix(0.4, 0.95, crust);
		ALPHA = 1.0;
	} else {
		// clear water: you see the stones in a stream and the sandy shallows of a lake; the
		// deeper the water (and the flatter you look), the more of its own colour it shows
		float dk = 1.0 - exp(-depth * 0.55);
		vec3 water = mix(shallow.rgb, deep.rgb, dk);
		water = mix(water, vec3(0.94, 0.97, 1.0), foam);
		vec3 upv = normalize((VIEW_MATRIX * vec4(normalize(wp), 0.0)).xyz);
		float path = depth / max(abs(dot(upv, VIEW)), 0.2) + depth;
		float body = 1.0 - exp(-path * 0.6);
		ALBEDO = water;
		EMISSION = sky_col.rgb * f * 0.45;
		ROUGHNESS = 0.03 + foam * 0.5;
		SPECULAR = 0.8;
		ALPHA = clamp(max(max(body * 0.95, f * 0.75), foam) + 0.06, 0.0, 0.97) * smoothstep(0.0, 0.12, edge + 0.02) * (0.4 + 0.6 * end_k + foam);
	}
}
"""
