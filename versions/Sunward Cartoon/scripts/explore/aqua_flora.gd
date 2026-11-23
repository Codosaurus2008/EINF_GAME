class_name AquaFlora
extends RefCounted
## Aquora's underwater plants: six alien species, each built from many parts (stems, branches,
## roots, blades, bulbs, tentacles, fins, webbing) with colour gradients from the base to the
## tips, glowing tips on some, and one mesh per plant (one draw call). They sway in the
## current (shader): the higher up and the thinner a part, the more it moves.
## Every species has 8 different variants per planet visit; each placed plant is also turned,
## tilted and sized differently, so no two look alike.
##   aq_fan      lattice fan: a flat, branching fan with webbing, red / orange tips
##   aq_kelp     bladder kelp tower: a tall swaying stalk with gas bulbs and hanging ribbons,
##               a holdfast of roots
##   aq_anemone  anemone bloom: a fleshy column with a crown of curling, glowing tentacles
##   aq_spiral   spiral frond: a stalk wrapped in a twisting fin ribbon
##   aq_bubble   bubble algae: clusters of glossy bubbles on short stalks
##   aq_tree     arch-root tree: arching roots, a trunk and a crown of glowing fin fans

const KINDS := ["aq_fan", "aq_kelp", "aq_anemone", "aq_spiral", "aq_bubble", "aq_tree", "aq_pillar", "aq_vent"]
const VARIANTS := 8
static var _cache := {}           # kind -> [[mesh, height], ...]
static var _mat: ShaderMaterial = null


static func make(kind: String, rng: RandomNumberGenerator) -> Node3D:
	if not _cache.has(kind):
		var list: Array = []
		var r2 := RandomNumberGenerator.new()
		r2.seed = hash(kind) + 31
		for v in VARIANTS:
			list.append(_build(kind, r2))
		_cache[kind] = list
	var opts: Array = _cache[kind]
	var pick: Array = opts[rng.randi() % opts.size()]
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = pick[0]
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a little leaning and different sizes
	mi.rotation = Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12))
	var s := rng.randf_range(0.75, 1.25)
	mi.scale = Vector3(s * rng.randf_range(0.9, 1.1), s, s * rng.randf_range(0.9, 1.1))
	n.add_child(mi)
	n.set_meta("h", float(pick[1]) * s)
	if kind == "aq_vent":
		# a stream of bubbles rising from the vent
		var b := CPUParticles3D.new()
		b.amount = 30
		b.lifetime = 4.0
		b.direction = Vector3.UP
		b.spread = 8.0
		b.initial_velocity_min = 0.4
		b.initial_velocity_max = 0.8
		b.gravity = Vector3.ZERO
		b.scale_amount_min = 0.5
		b.scale_amount_max = 1.5
		b.position = Vector3(0, float(pick[1]) * s, 0)
		b.mesh = Particles.soft_quad(0.03)
		b.material_override = Particles.material(Color(0.85, 0.97, 1.0, 0.7), true)
		b.visibility_range_end = 35.0
		n.add_child(b)
	return n


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = Shader.new()
		_mat.shader.code = SHADER
	return _mat


# ================================================================== building blocks
## Everything is collected in plain arrays: position, normal, colour, and in UV2:
## x = how freely the part sways (0 base .. 1 tip), y = how much it glows
class Acc:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	## Adds a mesh; colours go from col_a (bottom of the part) to col_b (top), sway / glow
	## from the part's base to its top
	func add(m: Mesh, xf: Transform3D, col_a: Color, col_b: Color, sway_a: float, sway_b: float, glow_a := 0.0, glow_b := 0.0) -> void:
		var arr := m.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ids = arr[Mesh.ARRAY_INDEX]
		var lo := INF
		var hi := -INF
		var ws := PackedVector3Array()
		ws.resize(vs.size())
		for i in vs.size():
			var w := xf * vs[i]
			ws[i] = w
			lo = minf(lo, w.y)
			hi = maxf(hi, w.y)
		var base := verts.size()
		var span := maxf(hi - lo, 0.0001)
		for i in vs.size():
			var k := (ws[i].y - lo) / span
			verts.append(ws[i])
			norms.append((xf.basis * ns[i]).normalized())
			cols.append(col_a.lerp(col_b, k))
			uv2.append(Vector2(lerpf(sway_a, sway_b, k), lerpf(glow_a, glow_b, k)))
		if ids == null:
			for i in vs.size():
				idx.append(base + i)
		else:
			for i: int in ids:
				idx.append(base + i)

	## Two-sided ribbon along a path (blades, fins): widths per point, `side` across
	func ribbon(path: Array, widths: Array, side: Vector3, col_a: Color, col_b: Color, sway_a: float, sway_b: float, glow_b := 0.0, curl := 0.15) -> void:
		var n := path.size()
		for face in 2:
			var base := verts.size()
			for i in n:
				var p: Vector3 = path[i]
				var nxt: Vector3 = path[mini(i + 1, n - 1)]
				var prv: Vector3 = path[maxi(i - 1, 0)]
				var tng := (nxt - prv).normalized()
				var sd := (side - tng * side.dot(tng)).normalized()
				var nrm := tng.cross(sd).normalized() * (1.0 if face == 0 else -1.0)
				var w := float(widths[i])
				var k := float(i) / (n - 1)
				for e: float in [-1.0, 0.0, 1.0]:
					# slightly cupped across (curl) so the blade has volume
					verts.append(p + sd * w * e + nrm * absf(e) * w * curl * (1.0 if face == 0 else 1.0))
					norms.append(nrm)
					cols.append(col_a.lerp(col_b, k).darkened(0.12 * absf(e) if face == 0 else 0.25))
					uv2.append(Vector2(lerpf(sway_a, sway_b, k), glow_b * k * k))
			for i in n - 1:
				for e in 2:
					var a := base + i * 3 + e
					var b := a + 1
					var c := a + 3
					var d := c + 1
					if face == 0:
						idx.append_array(PackedInt32Array([a, c, b, b, c, d]))
					else:
						idx.append_array(PackedInt32Array([a, b, c, b, d, c]))

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


static func _tube(a: Vector3, b: Vector3, r0: float, r1: float, bend: Vector3, sides := 7, count := 7) -> ArrayMesh:
	return CMesh.tube(CMesh.curve(a, b, bend, count), CMesh.taper(count, r0, r1, 0.1), sides, 0.0, 0.25, a.x * 7.0 + b.z * 3.0)


static func _ball(r: float) -> Mesh:
	return CMesh.ball(r, 10, 7)


static func _jit(rng: RandomNumberGenerator, c: Color, amount := 0.08) -> Color:
	return Color(c.r * rng.randf_range(1.0 - amount, 1.0 + amount), c.g * rng.randf_range(1.0 - amount, 1.0 + amount), c.b * rng.randf_range(1.0 - amount, 1.0 + amount))


# ================================================================== the species
static func _build(kind: String, rng: RandomNumberGenerator) -> Array:
	var acc := Acc.new()
	var h := 1.0
	match kind:
		"aq_fan":
			h = _fan(acc, rng)
		"aq_kelp":
			h = _kelp(acc, rng)
		"aq_anemone":
			h = _anemone(acc, rng)
		"aq_spiral":
			h = _spiral(acc, rng)
		"aq_bubble":
			h = _bubble(acc, rng)
		"aq_pillar":
			h = _pillar(acc, rng)
		"aq_vent":
			h = _vent(acc, rng)
		_:
			h = _tree(acc, rng)
	return [acc.mesh(), h]


## Lattice fan: branches split again and again in one (slightly curved) plane, with webbing
static func _fan(acc: Acc, rng: RandomNumberGenerator) -> float:
	var height := rng.randf_range(0.8, 1.6)
	var base_c := _jit(rng, Color("#5a1630"))
	var tip_c := _jit(rng, [Color("#ff6a3a"), Color("#ff9a4a"), Color("#e8407a")][rng.randi() % 3])
	var tips: Array = []
	var stack: Array = [[Vector3.ZERO, Vector3.UP, height * 0.35, 0.035, 0]]
	while not stack.is_empty():
		var b: Array = stack.pop_back()
		var p: Vector3 = b[0]
		var dir: Vector3 = b[1]
		var l := float(b[2])
		var r := float(b[3])
		var depth := int(b[4])
		var e := p + dir * l
		var bend := Vector3(0, 0, rng.randf_range(-0.05, 0.05)) * l
		var y0 := p.y / height
		var y1 := e.y / height
		acc.add(_tube(p, e, r, r * 0.7, bend, 6, 5), Transform3D.IDENTITY, base_c.lerp(tip_c, y0), base_c.lerp(tip_c, y1), y0, y1)
		if depth >= 4 or l < 0.08:
			tips.append(e)
			continue
		for s: float in [-1.0, 1.0]:
			var nd := dir.rotated(Vector3(0, 0, 1), s * rng.randf_range(0.3, 0.55)).normalized()
			stack.append([e, nd, l * rng.randf_range(0.62, 0.8), r * 0.7, depth + 1])
	# webbing between the outer tips (a translucent sheet that gives the fan its volume)
	tips.sort_custom(func(a: Vector3, b: Vector3) -> bool: return atan2(a.x, a.y) < atan2(b.x, b.y))
	if tips.size() > 3:
		var web := CMesh.membrane(Vector3(0, height * 0.3, 0), tips, 0.35)
		acc.add(web, Transform3D.IDENTITY, base_c.lerp(tip_c, 0.4).darkened(0.1), tip_c.lerp(Color.WHITE, 0.1), 0.3, 1.0, 0.0, 0.25)
	# glowing polyps on the tips
	for tp: Vector3 in tips:
		acc.add(_ball(0.012), Transform3D(Basis(), tp), tip_c, tip_c.lerp(Color(1, 0.9, 0.6), 0.5), 1.0, 1.0, 0.6, 0.9)
	# small roots
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf() * 0.5
		acc.add(_tube(Vector3(0, 0.02, 0), Vector3(cos(a) * 0.12, -0.03, sin(a) * 0.12), 0.02, 0.006, Vector3(0, 0.03, 0), 5, 4),
			Transform3D.IDENTITY, base_c.darkened(0.3), base_c, 0.0, 0.0)
	return height


## Bladder kelp: tall stalk, gas bulbs, long hanging ribbons, holdfast
static func _kelp(acc: Acc, rng: RandomNumberGenerator) -> float:
	var height := rng.randf_range(2.2, 4.8)
	var stem_a := _jit(rng, Color("#3a3014"))
	var stem_b := _jit(rng, Color("#7a6a20"))
	var blade_a := _jit(rng, Color("#4a5a14"))
	var blade_b := _jit(rng, Color("#b0a030"))
	var pts: Array = []
	var cnt := 14
	var wob := rng.randf() * TAU
	for i in cnt:
		var k := float(i) / (cnt - 1)
		pts.append(Vector3(sin(k * 3.0 + wob) * 0.15 * k, k * height, cos(k * 2.3 + wob) * 0.12 * k))
	var rads: Array = []
	for i in cnt:
		var k2 := float(i) / (cnt - 1)
		rads.append(Vector2(lerpf(0.035, 0.014, k2), lerpf(0.035, 0.014, k2)))
	acc.add(CMesh.tube(pts, rads, 7, 0.0, 0.2, wob), Transform3D.IDENTITY, stem_a, stem_b, 0.0, 1.0)
	# bulbs with a ribbon each
	var y := 0.35
	while y < height - 0.1:
		var k3 := y / height
		var i3 := int(k3 * (cnt - 1))
		var pa: Vector3 = pts[i3]
		var pb: Vector3 = pts[mini(i3 + 1, cnt - 1)]
		var c := pa.lerp(pb, fmod(k3 * (cnt - 1), 1.0))
		var ang := rng.randf() * TAU
		var out := Vector3(cos(ang), 0, sin(ang))
		var bulb := c + out * 0.05
		acc.add(_ball(rng.randf_range(0.025, 0.045)), Transform3D(Basis(), bulb), Color("#9a8a30"), Color("#d8c860"), k3, k3, 0.0, 0.15)
		# the ribbon: rises a little, then hangs and waves
		var bl := rng.randf_range(0.45, 0.9)
		var path: Array = []
		var widths: Array = []
		for j in 8:
			var t := float(j) / 7.0
			path.append(bulb + out * (0.04 + t * bl * 0.6) + Vector3(0, sin(t * PI) * 0.12 - t * 0.15, 0) + out.cross(Vector3.UP) * sin(t * 5.0) * 0.04)
			widths.append(lerpf(0.02, 0.07, sin(t * PI * 0.8 + 0.2)))
		acc.ribbon(path, widths, out.cross(Vector3.UP), blade_a, blade_b, k3, minf(1.0, k3 + 0.3), 0.0, 0.25)
		y += rng.randf_range(0.35, 0.6)
	# holdfast: a tangle of roots
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.4
		var l := rng.randf_range(0.12, 0.25)
		acc.add(_tube(Vector3(0, 0.05, 0), Vector3(cos(a) * l, -0.04, sin(a) * l), 0.018, 0.006, Vector3(0, 0.05, 0), 5, 5),
			Transform3D.IDENTITY, stem_a.darkened(0.3), stem_a, 0.0, 0.0)
	return height


## Anemone bloom: a fleshy column, a crown of curling tentacles with glowing tips
static func _anemone(acc: Acc, rng: RandomNumberGenerator) -> float:
	var col_h := rng.randf_range(0.12, 0.3)
	var r := rng.randf_range(0.07, 0.12)
	var body_a := _jit(rng, [Color("#12485a"), Color("#3a1a5a"), Color("#5a2a14")][rng.randi() % 3])
	var tip := _jit(rng, [Color("#ff7ad8"), Color("#7affe0"), Color("#ffd86a")][rng.randi() % 3])
	acc.add(_tube(Vector3.ZERO, Vector3(0, col_h, 0), r * 0.85, r, Vector3(0.01, 0, 0), 12, 5), Transform3D.IDENTITY, body_a.darkened(0.2), body_a.lerp(tip, 0.25), 0.0, 0.15)
	# the oral disc
	acc.add(_ball(r * 0.95), Transform3D(Basis().scaled(Vector3(1.0, 0.25, 1.0)), Vector3(0, col_h, 0)), body_a.lerp(tip, 0.3), body_a.lerp(tip, 0.4), 0.15, 0.15, 0.1, 0.1)
	var count := rng.randi_range(26, 44)
	for i in count:
		var a := TAU * i / count + rng.randf() * 0.15
		var ring := 0.55 + 0.45 * float(i % 3) / 2.0
		var start := Vector3(cos(a) * r * ring, col_h, sin(a) * r * ring)
		var l := rng.randf_range(0.14, 0.32)
		var out := Vector3(cos(a), 0, sin(a))
		var end := start + out * l * 0.7 + Vector3(0, l * 0.6, 0)
		var bend := out * l * 0.25 + Vector3(0, l * 0.25, 0)
		acc.add(_tube(start, end, 0.009, 0.003, bend, 5, 6), Transform3D.IDENTITY, body_a.lerp(tip, 0.3), tip, 0.2, 1.0, 0.0, 0.9)
	return col_h + 0.3


## Spiral frond: a stalk with a fin ribbon twisting around it, little side fins
static func _spiral(acc: Acc, rng: RandomNumberGenerator) -> float:
	var height := rng.randf_range(0.9, 2.0)
	var a_c := _jit(rng, Color("#0f4a3a"))
	var b_c := _jit(rng, Color("#3ad0a0"))
	acc.add(_tube(Vector3.ZERO, Vector3(0, height, 0), 0.02, 0.008, Vector3(rng.randf_range(-0.1, 0.1), 0, 0.05), 6, 8), Transform3D.IDENTITY, a_c.darkened(0.2), b_c, 0.0, 1.0)
	var turns := rng.randf_range(2.0, 3.5)
	var path: Array = []
	var widths: Array = []
	var cnt := 40
	for i in cnt:
		var k := float(i) / (cnt - 1)
		var ang := k * turns * TAU
		var rad := lerpf(0.14, 0.03, k)
		path.append(Vector3(cos(ang) * rad * 0.5, k * height, sin(ang) * rad * 0.5))
		widths.append(rad * 0.5)
	acc.ribbon(path, widths, Vector3(1, 0, 0), a_c, b_c, 0.05, 1.0, 0.35, 0.3)
	# side fins
	for i in rng.randi_range(4, 7):
		var y := rng.randf_range(0.2, 0.85) * height
		var ang2 := rng.randf() * TAU
		var o := Vector3(cos(ang2), 0, sin(ang2))
		var tips: Array = []
		for j in 4:
			var t := float(j) / 3.0
			tips.append(Vector3(0, y, 0) + o * 0.16 + Vector3(0, (t - 0.5) * 0.14, 0) + o.cross(Vector3.UP) * (t - 0.5) * 0.08)
		acc.add(CMesh.membrane(Vector3(0, y, 0), tips, 0.2), Transform3D.IDENTITY, a_c, b_c.lerp(Color.WHITE, 0.15), y / height, y / height + 0.2, 0.0, 0.3)
	return height


## Bubble algae: glossy bubbles of all sizes on short stalks
static func _bubble(acc: Acc, rng: RandomNumberGenerator) -> float:
	var col := _jit(rng, [Color("#2a8a4a"), Color("#3a9a7a"), Color("#6aa03a")][rng.randi() % 3])
	var top := 0.0
	for i in rng.randi_range(12, 26):
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.18
		var r := rng.randf_range(0.02, 0.06) * (1.3 - d * 2.0)
		var base := Vector3(cos(a) * d, 0, sin(a) * d)
		var sh := rng.randf_range(0.02, 0.12)
		var c := base + Vector3(rng.randf_range(-0.03, 0.03), sh + r, rng.randf_range(-0.03, 0.03))
		acc.add(_tube(base, c - Vector3(0, r * 0.8, 0), 0.008, 0.005, Vector3.ZERO, 4, 3), Transform3D.IDENTITY, col.darkened(0.4), col.darkened(0.1), 0.0, 0.4)
		acc.add(_ball(r), Transform3D(Basis(), c), col.darkened(0.15), col.lerp(Color(0.7, 1.0, 0.8), 0.35), 0.4, 0.6, 0.0, 0.12)
		top = maxf(top, c.y + r)
	return top


## Arch-root tree: arching roots meet in a trunk, crowned with fans of glowing fins
static func _tree(acc: Acc, rng: RandomNumberGenerator) -> float:
	var height := rng.randf_range(1.4, 2.8)
	var bark_a := _jit(rng, Color("#101a3a"))
	var bark_b := _jit(rng, Color("#2a3a7a"))
	var glow := _jit(rng, [Color("#5af0ff"), Color("#9a7aff"), Color("#5affa0")][rng.randi() % 3])
	var hub := Vector3(0, height * 0.32, 0)
	var roots := rng.randi_range(3, 5)
	for i in roots:
		var a := TAU * i / roots + rng.randf() * 0.4
		var foot := Vector3(cos(a), 0, sin(a)) * height * rng.randf_range(0.3, 0.45)
		acc.add(_tube(foot + Vector3(0, -0.05, 0), hub, 0.035, 0.05, Vector3(cos(a), 1.2, sin(a)) * height * 0.12, 7, 8), Transform3D.IDENTITY, bark_a, bark_b, 0.0, 0.1)
	acc.add(_tube(hub, Vector3(0, height * 0.75, 0), 0.06, 0.035, Vector3(0.05, 0, 0), 8, 6), Transform3D.IDENTITY, bark_b, bark_b.lerp(glow, 0.2), 0.1, 0.4)
	# crown of fin fans
	var fans := rng.randi_range(6, 10)
	for i in fans:
		var a2 := TAU * i / fans + rng.randf() * 0.3
		var o := Vector3(cos(a2), rng.randf_range(0.4, 0.9), sin(a2)).normalized()
		var root := Vector3(0, height * 0.72, 0)
		var stalk_end := root + o * height * 0.2
		acc.add(_tube(root, stalk_end, 0.02, 0.01, Vector3(0, 0.03, 0), 5, 4), Transform3D.IDENTITY, bark_b, bark_b.lerp(glow, 0.3), 0.4, 0.6)
		var tips: Array = []
		var side := o.cross(Vector3.UP).normalized()
		for j in 6:
			var t := float(j) / 5.0
			tips.append(stalk_end + o * height * 0.16 * (0.8 + 0.4 * sin(t * PI)) + side * (t - 0.5) * height * 0.22 + Vector3(0, sin(t * PI) * 0.05, 0))
		acc.add(CMesh.membrane(stalk_end, tips, 0.25), Transform3D.IDENTITY, bark_b.lerp(glow, 0.2), glow, 0.6, 1.0, 0.1, 0.7)
	return height


## Seabed rock pillar: stacked, lumpy rock with sponges, small fans and anemones growing on it
static func _pillar(acc: Acc, rng: RandomNumberGenerator) -> float:
	var height := rng.randf_range(1.2, 3.2)
	var rock_a := _jit(rng, Color("#2a3438"), 0.12)
	var rock_b := _jit(rng, Color("#5a6a68"), 0.12)
	var pts: Array = []
	var rads: Array = []
	var cnt := 9
	for i in cnt:
		var k := float(i) / (cnt - 1)
		pts.append(Vector3(sin(k * 4.0 + rng.randf()) * 0.12, k * height, cos(k * 3.0) * 0.1))
		var rr := lerpf(0.45, 0.18, k) * rng.randf_range(0.8, 1.2)
		rads.append(Vector2(rr, rr * rng.randf_range(0.8, 1.0)))
	acc.add(CMesh.tube(pts, rads, 10, 0.2, 0.9, rng.randf() * 10.0), Transform3D.IDENTITY, rock_a, rock_b, 0.0, 0.0)
	# a fallen block at the foot
	acc.add(CMesh.tube(CMesh.curve(Vector3(0.3, 0.05, 0.2), Vector3(0.75, 0.1, 0.45), Vector3(0, 0.08, 0), 4), CMesh.taper(4, 0.18, 0.12), 8, 0.3, 0.9, 3.0),
		Transform3D.IDENTITY, rock_a, rock_b.darkened(0.2), 0.0, 0.0)
	# life growing on the rock
	for i in rng.randi_range(8, 14):
		var k2 := rng.randf_range(0.1, 0.95)
		var i2 := int(k2 * (cnt - 1))
		var c: Vector3 = pts[i2]
		var ang := rng.randf() * TAU
		var rr2: Vector2 = rads[i2]
		var on := c + Vector3(cos(ang), 0, sin(ang)) * rr2.x * 0.95
		var col := _jit(rng, [Color("#e86a3a"), Color("#c83a8a"), Color("#e8c83a"), Color("#3ac8a8")][rng.randi() % 4])
		match rng.randi() % 3:
			0:
				acc.add(_ball(rng.randf_range(0.03, 0.07)), Transform3D(Basis().scaled(Vector3(1.0, 0.6, 1.0)), on), col.darkened(0.3), col, 0.0, 0.1)
			1:
				acc.add(_tube(on, on + Vector3(cos(ang), 0.8, sin(ang)) * 0.15, 0.025, 0.018, Vector3(0, 0.02, 0), 6, 4), Transform3D.IDENTITY, col.darkened(0.4), col, 0.1, 0.4)
			_:
				for j in 6:
					var a3 := TAU * j / 6.0
					acc.add(_tube(on, on + Vector3(cos(a3) * 0.06, 0.08, sin(a3) * 0.06) + Vector3(cos(ang), 0, sin(ang)) * 0.04, 0.006, 0.002, Vector3(0, 0.02, 0), 4, 4),
						Transform3D.IDENTITY, col.darkened(0.2), col.lightened(0.2), 0.3, 1.0, 0.0, 0.6)
	return height


## Seabed vent: a crusted chimney (bubbles rise from it), mineral-coloured rings
static func _vent(acc: Acc, rng: RandomNumberGenerator) -> float:
	var height := rng.randf_range(0.4, 0.9)
	var rock := _jit(rng, Color("#3a3028"), 0.1)
	var crust := _jit(rng, Color("#c89a4a"), 0.15)
	acc.add(_tube(Vector3.ZERO, Vector3(0, height, 0), 0.22, 0.09, Vector3(rng.randf_range(-0.05, 0.05), 0, 0.03), 10, 7), Transform3D.IDENTITY, rock, crust, 0.0, 0.0)
	for i in 4:
		var y := height * (0.2 + i * 0.2)
		acc.add(CMesh.ring(0.1 + 0.08 * (1.0 - y / height), 0.14 + 0.09 * (1.0 - y / height), 14), Transform3D(Basis(), Vector3(0, y, 0)),
			crust.darkened(0.2), crust.lightened(0.15), 0.0, 0.0)
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf()
		acc.add(_tube(Vector3(0, 0.02, 0), Vector3(cos(a) * 0.4, -0.02, sin(a) * 0.4), 0.1, 0.03, Vector3(0, 0.05, 0), 6, 4), Transform3D.IDENTITY, rock.darkened(0.2), rock, 0.0, 0.0)
	acc.add(_ball(0.06), Transform3D(Basis(), Vector3(0, height, 0)), Color("#ffb060"), Color("#ffd890"), 0.0, 0.0, 0.8, 0.8)
	return height


const SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_toon;
varying float glow;
void vertex() {
	// sways in the current: the tips (UV2.x = 1) the most, slow and fluid
	vec3 org = MODEL_MATRIX[3].xyz;
	float ph = dot(org, vec3(0.37, 0.21, 0.29));
	float k = UV2.x * UV2.x;
	vec3 cur = vec3(sin(TIME * 0.7 + ph + VERTEX.y * 1.3), 0.0, cos(TIME * 0.55 + ph * 1.3 + VERTEX.y * 0.9));
	cur += vec3(sin(TIME * 1.9 + ph * 2.0 + VERTEX.y * 4.0), 0.0, cos(TIME * 1.6 + VERTEX.y * 3.0)) * 0.25;
	VERTEX += cur * k * (0.04 + VERTEX.y * 0.06);
	glow = UV2.y;
}
void fragment() {
	vec3 c = COLOR.rgb;
	// fine surface detail: streaks and spots along the parts
	float n = fract(sin(dot(floor(UV2 * 37.0 + c.xy * 11.0), vec2(12.9898, 78.233))) * 43758.5453);
	c *= 0.9 + 0.2 * n;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = clamp(mix(vec3(l), c, 1.7) * 1.15, 0.0, 4.0);
	ALBEDO = c;
	ROUGHNESS = 0.45 - glow * 0.2;
	SPECULAR = 0.55;
	// light glowing through thin, bright parts (tips, fins) - and real glow on some
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	EMISSION = c * (glow * 1.6 + rim * 0.25);
}
"""
