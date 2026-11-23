class_name AmbientLife
extends Node3D
## Small life around the player: insects that flutter from plant to plant and land for a
## moment, tiny crawlers that wander over the ground and scurry away from your feet, and
## motes that drift in the wind (pollen, spores, snow, embers, sparks ...).
## Everything lives only in a small bubble around the camera and is drawn with 3 MultiMeshes
## (3 draw calls), so it costs almost nothing.

## per planet: flyers, crawlers, motes, [flyer colours], [crawler colours], mote colour,
## motes glow?, motes rise (+) / sink (-)
const KITS := {
	"verdis": [14, 10, 40, [Color("#ffd23a"), Color("#ff7ab8"), Color("#8ad8ff"), Color("#ffffff")], [Color("#2a4a1a"), Color("#5a3a1a")], Color(1.0, 1.0, 0.8), false, 0.02],
	"pebble": [4, 14, 25, [Color("#c8b890")], [Color("#4a4038"), Color("#6a5a4a"), Color("#8a6a3a")], Color(0.85, 0.8, 0.7), false, -0.01],
	"glacia": [3, 6, 70, [Color("#e0f0ff")], [Color("#8ab8d8"), Color("#c8e0f0")], Color(1.0, 1.0, 1.0), false, -0.25],
	"mycelia": [10, 12, 60, [Color("#b080ff"), Color("#60ffd0")], [Color("#5a3a6a"), Color("#3a2a4a")], Color(0.6, 1.0, 0.85), true, 0.05],
	"aquora": [8, 12, 25, [Color("#ffffff"), Color("#80d0ff")], [Color("#d0603a"), Color("#e08050")], Color(0.9, 1.0, 1.0), false, 0.0],
	"ferrum": [5, 10, 55, [Color("#ff6a20")], [Color("#2a1a14"), Color("#5a2a1a")], Color(1.0, 0.45, 0.1), true, 0.3],
	"voltara": [8, 10, 45, [Color("#80c0ff"), Color("#c0a0ff")], [Color("#5a5a70"), Color("#3a3a50")], Color(0.5, 0.85, 1.0), true, 0.08],
	"solara": [8, 10, 40, [Color("#ffd27a"), Color("#ffffff")], [Color("#c89a50"), Color("#e8c890")], Color(1.0, 0.9, 0.6), true, 0.06],
}
const BUBBLE := 7.0              # radius around the camera (m)

var world: SphereWorld
var kit: Array = []
var rng := RandomNumberGenerator.new()
var flyers: Array = []           # [pos, vel, target, phase, rest, colour]
var crawlers: Array = []         # [dir on sphere, target dir, pause, colour, yaw]
var motes: Array = []            # [pos, drift]
var mm_fly: MultiMesh
var mm_crawl: MultiMesh
var mm_mote: MultiMesh
var t := 0.0


func setup(w: SphereWorld) -> void:
	world = w
	rng.seed = hash(w.pid) + 4242
	kit = KITS.get(w.pid, KITS["verdis"])
	mm_fly = _multimesh(_wing_mesh(), int(kit[0]), false, false)
	mm_crawl = _multimesh(_bug_mesh(), int(kit[1]), false, false)
	var mq := QuadMesh.new()
	mq.size = Vector2(1.0, 1.0)
	mm_mote = _multimesh(mq, int(kit[2]), true, bool(kit[6]))
	for i in int(kit[0]):
		var fc: Array = kit[3]
		flyers.append([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, rng.randf() * TAU, 0.0, fc[i % fc.size()], false])
	for i in int(kit[1]):
		var cc: Array = kit[4]
		crawlers.append([Vector3.UP, Vector3.UP, 0.0, cc[i % cc.size()], 0.0, false])
	for i in int(kit[2]):
		motes.append([Vector3.ZERO, Vector3.ZERO, false])


func _multimesh(mesh: Mesh, count: int, billboard: bool, glow: bool) -> MultiMesh:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.6
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = Particles.dot_texture()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if glow:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = m
	else:
		(mesh as ArrayMesh).surface_set_material(0, m)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16.0
	add_child(mi)
	return mm


## Two wings (a flat V); flapping = squeezing them together through the instance transform
func _wing_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: float in [-1.0, 1.0]:
		st.set_color(Color.WHITE)
		st.add_vertex(Vector3(0.0, 0.0, 0.25))
		st.add_vertex(Vector3(s * 0.5, 0.15, 0.35))
		st.add_vertex(Vector3(s * 0.45, 0.1, -0.3))
		st.add_vertex(Vector3(0.0, 0.0, 0.25))
		st.add_vertex(Vector3(s * 0.45, 0.1, -0.3))
		st.add_vertex(Vector3(0.0, 0.0, -0.3))
	# body
	st.set_color(Color(0.15, 0.12, 0.1))
	st.add_vertex(Vector3(-0.05, 0.0, 0.35))
	st.add_vertex(Vector3(0.05, 0.0, 0.35))
	st.add_vertex(Vector3(0.0, 0.0, -0.45))
	st.generate_normals()
	return st.commit()


## A tiny beetle: a squashed sphere with a head
func _bug_mesh() -> ArrayMesh:
	var body := WorldProps.sphere(1.0, 8, 5, true)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(body, 0, Transform3D(Basis.from_scale(Vector3(0.35, 0.22, 0.5)), Vector3(0, 0.15, 0)))
	st.append_from(body, 0, Transform3D(Basis.from_scale(Vector3(0.18, 0.14, 0.16)), Vector3(0, 0.14, -0.55)))
	var am := st.commit()
	# white vertex colour, so the instance colour shows
	var arr := am.surface_get_arrays(0)
	var cols := PackedColorArray()
	cols.resize((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	cols.fill(Color.WHITE)
	arr[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out


func _ground(dir: Vector3) -> Vector3:
	return dir * (world.radius + world.terrain.height(dir))


func _dry(dir: Vector3) -> bool:
	var h := world.terrain.height(dir)
	return world.water_level < -900.0 or h > world.water_level + 0.05 or str(world.biome["water"]) == "lava" and h > world.water_level + 0.4


## A random spot on the ground within r of the camera's ground point
func _near_dir(centre: Vector3, r: float) -> Vector3:
	var up := centre.normalized()
	var side := up.cross(Vector3(0.3, 1.0, 0.2).normalized()).normalized()
	var ang := rng.randf() * TAU
	var dist := sqrt(rng.randf()) * r
	var off := (side.rotated(up, ang)) * dist
	return (centre + off).normalized()


func _process(delta: float) -> void:
	if world == null:
		return
	delta = minf(delta, 0.05)
	t += delta
	var cam := world.viewer
	if cam.length() < 1.0:
		return
	var up := cam.normalized()
	var alt := cam.length() - (world.radius + world.terrain.height(up))
	visible = alt < 14.0
	if not visible:
		return
	var foot := world.player_pos()
	if foot.length() < 1.0 or foot.length() > world.radius * 3.0 or foot.distance_to(cam) > 40.0:
		foot = _ground(up)
	_flyers(delta, foot)
	_crawlers(delta, foot)
	_motes(delta, cam)


func _flyers(delta: float, foot: Vector3) -> void:
	for i in flyers.size():
		var f: Array = flyers[i]
		var p: Vector3 = f[0]
		if not bool(f[6]) or p.distance_to(foot) > BUBBLE * 1.3:
			var d := _near_dir(foot, BUBBLE)
			p = _ground(d) + d * rng.randf_range(0.2, 1.2)
			f[2] = p
			f[6] = true
		var target: Vector3 = f[2]
		var vel: Vector3 = f[1]
		var gup := p.normalized()
		var rest := float(f[4])
		var flap := 1.0
		if rest > 0.0:
			# sitting on a plant / the ground: wings slowly open and close
			rest -= delta
			vel = Vector3.ZERO
			flap = 0.6 + 0.4 * sin(t * 3.0 + i)
			if p.distance_to(foot) < 0.5:
				rest = 0.0
		else:
			var to := target - p
			if to.length() < 0.15:
				# arrived: land for a moment (on the ground / a plant) or fly on to the next one
				if rng.randf() < 0.45:
					rest = rng.randf_range(1.0, 4.0)
				var d2 := _near_dir(foot, BUBBLE * 0.9)
				f[2] = _ground(d2) + d2 * (0.02 if rng.randf() < 0.5 else rng.randf_range(0.15, 1.0))
			# flutter: steer to the target with a wobble, away from the player's feet
			var wob := Vector3(sin(t * 5.0 + i * 1.7), sin(t * 7.0 + i), cos(t * 4.0 + i * 2.3)) * 0.6
			var away := Vector3.ZERO
			var pd := p.distance_to(foot)
			if pd < 0.7:
				away = (p - foot).normalized() * 2.0 + gup * 1.5
			vel = vel.lerp((to.normalized() * 0.9 + wob + away), clampf(delta * 3.0, 0.0, 1.0))
			p += vel * delta
			var gr := world.radius + world.terrain.height(gup)
			if p.length() < gr + 0.02:
				p = gup * (gr + 0.02)
			flap = absf(cos(t * 26.0 + float(f[3])))
		f[0] = p
		f[1] = vel
		f[4] = rest
		var fwd := vel - gup * vel.dot(gup)
		if fwd.length() < 0.01:
			fwd = gup.cross(Vector3.RIGHT)
		var b := Basis.looking_at(fwd.normalized(), gup)
		var s := 0.05
		mm_fly.set_instance_transform(i, Transform3D(b.scaled_local(Vector3(s * maxf(flap, 0.08), s, s)), p))
		mm_fly.set_instance_color(i, f[5])


func _crawlers(delta: float, foot: Vector3) -> void:
	for i in crawlers.size():
		var c: Array = crawlers[i]
		var d: Vector3 = c[0]
		if not bool(c[5]) or _ground(d).distance_to(foot) > BUBBLE * 1.2:
			for k in 6:
				d = _near_dir(foot, BUBBLE * 0.9)
				if _dry(d):
					break
			c[1] = d
			c[5] = true
		var pause := float(c[2])
		var p := _ground(d)
		var target: Vector3 = c[1]
		var speed := 0.12
		var pd := p.distance_to(foot)
		if pd < 0.45:
			# scurry away from the player's feet
			var away := (p - foot)
			away -= d * away.dot(d)
			target = (p + away.normalized() * 1.0).normalized()
			c[1] = target
			pause = 0.0
			speed = 0.45
		if pause > 0.0:
			pause -= delta
		else:
			var tp := _ground(target)
			var to := tp - p
			to -= d * to.dot(d)
			if to.length() < 0.05:
				pause = rng.randf_range(0.5, 3.0)
				var nd := (p + d.cross(Vector3(0.2, 1.0, 0.3)).normalized().rotated(d, rng.randf() * TAU) * rng.randf_range(0.3, 1.2)).normalized()
				if _dry(nd):
					c[1] = nd
			else:
				var step := to.normalized() * minf(speed * delta, to.length())
				var nd2 := (p + step).normalized()
				if _dry(nd2):
					d = nd2
				else:
					c[1] = d
		c[0] = d
		c[2] = pause
		var g := _ground(d)
		var fwd := (_ground(c[1]) - g)
		fwd -= d * fwd.dot(d)
		if fwd.length() < 0.001:
			fwd = d.cross(Vector3.RIGHT)
		var b := Basis.looking_at(fwd.normalized(), d)
		var s := 0.035
		# little steps: a tiny bob while walking
		var bob := 0.0 if pause > 0.0 else absf(sin(t * 30.0 + i)) * 0.003
		mm_crawl.set_instance_transform(i, Transform3D(b.scaled_local(Vector3.ONE * s), g + d * bob))
		mm_crawl.set_instance_color(i, c[3])


func _motes(delta: float, cam: Vector3) -> void:
	var col: Color = kit[5]
	var rise := float(kit[7])
	var glow := bool(kit[6])
	for i in motes.size():
		var m: Array = motes[i]
		var p: Vector3 = m[0]
		if not bool(m[2]) or p.distance_to(cam) > BUBBLE:
			var d := _near_dir(cam, BUBBLE * 0.95)
			p = _ground(d) + d * rng.randf_range(0.05, 2.5)
			m[1] = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.08
			m[2] = true
		var gup := p.normalized()
		var wind := Vector3(sin(t * 0.3), 0.0, cos(t * 0.23)) * 0.25
		var drift: Vector3 = m[1]
		p += (drift + wind + gup * rise + Vector3(sin(t * 1.3 + i), sin(t * 1.7 + i * 0.7), cos(t * 1.1 + i)) * 0.05) * delta
		var gr := world.radius + world.terrain.height(gup)
		if p.length() < gr + 0.01:
			m[2] = false
		if p.length() > gr + 4.0:
			m[2] = false
		m[0] = p
		var tw := 0.6 + 0.4 * sin(t * 4.0 + i * 1.3) if glow else 1.0
		var s := 0.025 if glow else 0.018
		mm_mote.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), p))
		mm_mote.set_instance_color(i, Color(col.r, col.g, col.b, 0.8) * Color(tw, tw, tw, 1.0))
