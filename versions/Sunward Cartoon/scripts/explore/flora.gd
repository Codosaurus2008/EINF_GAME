class_name Flora
extends RefCounted
## Detailed vegetation (visual upgrade, first used on Verdis): leaf / grass / frond / flower
## textures drawn in code, plants built from many textured "cards" (merged into one mesh each,
## so they draw fast), detailed jungle trees with bark, roots, branches, leafy crowns and vines,
## and instanced ground cover (MultiMesh: thousands of plants in a few draw calls).

static var _tex := {}
static var _mats := {}
static var _bark: StandardMaterial3D


# ================================================================== textures
## kind: leaf, blade, frond, flower. Base of the plant at the bottom of the picture.
static func texture(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var w := 64 if kind in ["blade", "shard"] else 128
	var h := 128 if kind in ["flower", "crust"] else 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var u := (x + 0.5) / w
			var v := (y + 0.5) / h
			var c := _pixel(kind, u, v)
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


static func _pixel(kind: String, u: float, v: float) -> Color:
	var t := 1.0 - v                    # 0 at the base, 1 at the tip
	var dx := absf(u - 0.5)
	match kind:
		"leaf":
			# lance-shaped leaf: serrated edge, midrib, angled side veins, rich greens
			var half := 0.47 * pow(sin(PI * pow(clampf(t, 0.0, 1.0), 0.8)), 0.9)
			half *= 1.0 - 0.06 * absf(sin(t * 46.0))                      # small teeth along the edge
			if t < 0.06:
				return Color(0.2, 0.3, 0.1) if dx < 0.025 else Color(0, 0, 0, 0)
			if dx > half:
				return Color(0, 0, 0, 0)
			var edge := dx / maxf(half, 0.001)
			var c := Color(0.08, 0.32, 0.1).lerp(Color(0.16, 0.55, 0.2), t * 0.7).lerp(Color(0.3, 0.62, 0.14), edge * 0.35)
			c = c.lerp(Color(0.05, 0.42, 0.24), 0.25 * absf(sin(u * 9.0 + v * 13.0)))   # emerald mottling
			c = c.darkened(edge * edge * 0.35)
			if dx < 0.016:
				c = c.lightened(0.3)                                         # midrib
			elif absf(fmod(dx * 2.4 - t * 1.0 + 4.0, 0.13) - 0.065) < 0.008:
				c = c.lightened(0.15)                                        # side veins, angled to the tip
			return c
		"blade":
			var half2 := 0.46 * pow(1.0 - t, 0.6)
			if dx > half2:
				return Color(0, 0, 0, 0)
			var c2 := Color(0.06, 0.26, 0.07).lerp(Color(0.2, 0.55, 0.15), smoothstep(0.0, 0.6, t)).lerp(Color(0.55, 0.72, 0.2), smoothstep(0.65, 1.0, t))
			return c2.lightened(0.12) if dx < 0.05 else c2.darkened(dx * 0.6)
		"frond":
			if dx < 0.03:
				return Color(0.3, 0.45, 0.15) if t > 0.02 else Color(0, 0, 0, 0)
			var reach := 0.46 * pow(sin(PI * clampf(t * 0.95 + 0.04, 0.0, 1.0)), 0.7)
			if dx > reach:
				return Color(0, 0, 0, 0)
			var seg := fmod(t * 16.0 + dx * 2.2, 1.0)
			if seg > 0.62:
				return Color(0, 0, 0, 0)
			return Color(0.2, 0.48, 0.18).lerp(Color(0.4, 0.66, 0.22), dx / 0.46).darkened(absf(seg - 0.31) * 0.6)
		"flower":
			var p := Vector2(u - 0.5, v - 0.5)
			var r := p.length()
			var a := atan2(p.y, p.x)
			if r < 0.11:
				return Color(1.0, 0.85, 0.3).darkened(r * 2.0)
			var petal := 0.44 * (0.55 + 0.45 * absf(cos(a * 3.0)))
			if r > petal:
				return Color(0, 0, 0, 0)
			return Color(1, 1, 1).darkened(r * 0.5).lerp(Color(1.0, 0.9, 0.95), 0.3)
		"crust":
			# lichen / moss patch lying on the ground: blotchy, with darker spots
			var q := Vector2(u - 0.5, v - 0.5) * 2.0
			var wob := 0.75 + 0.15 * sin(atan2(q.y, q.x) * 5.0 + 1.3) + 0.1 * sin(atan2(q.y, q.x) * 11.0)
			if q.length() > wob:
				return Color(0, 0, 0, 0)
			var spot := absf(sin(u * 37.0) * sin(v * 29.0))
			return Color(0.75, 0.78, 0.7).darkened(0.25 * spot + 0.2 * q.length())
		"shard":
			# thin crystal blade, bright edges
			var half3 := 0.45 * (1.0 - t) + 0.02
			if dx > half3:
				return Color(0, 0, 0, 0)
			var e := dx / half3
			return Color(0.85, 0.9, 1.0, 0.85).lerp(Color(1, 1, 1, 1), e * e)
	return Color(0, 0, 0, 0)


static func foliage_mat(kind: String, tint: Color, sway: float, glow := Color.BLACK) -> ShaderMaterial:
	var key := "%s|%s|%.2f|%s" % [kind, tint.to_html(), sway, glow.to_html()]
	if not _mats.has(key):
		_mats[key] = ExploreShaders.material("foliage", {"tex": texture(kind), "tint": tint, "sway": sway, "glow": glow})
	return _mats[key]


## Bark: stretched noise with a bump map
static func bark() -> StandardMaterial3D:
	if _bark == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.03
		n.fractal_octaves = 3
		var g := Gradient.new()
		g.set_color(0, Color("#2e2216"))
		g.set_color(1, Color("#7a6248"))
		var tex := NoiseTexture2D.new()
		tex.width = 256
		tex.height = 256
		tex.seamless = true
		tex.noise = n
		tex.color_ramp = g
		var nt := NoiseTexture2D.new()
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		nt.noise = n
		nt.as_normal_map = true
		nt.bump_strength = 6.0
		_bark = StandardMaterial3D.new()
		_bark.albedo_texture = tex
		_bark.normal_enabled = true
		_bark.normal_texture = nt
		_bark.roughness = 0.95
		_bark.uv1_scale = Vector3(3.0, 1.0, 1.0)
		Cartoon.toon(_bark)
	return _bark


# ================================================================== card meshes
## Collects textured quads and turns them into one mesh
class Cards:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	## A card standing at `base`, growing along `up`, `w` wide, `h` long
	func add(base: Vector3, up: Vector3, side: Vector3, w: float, h: float, col := Color.WHITE) -> void:
		var i := verts.size()
		var s := side.normalized() * w * 0.5
		var top := base + up.normalized() * h
		verts.append_array(PackedVector3Array([base - s, base + s, top + s, top - s]))
		var n := side.cross(up).normalized()
		norms.append_array(PackedVector3Array([n, n, n, n]))
		uvs.append_array(PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]))
		cols.append_array(PackedColorArray([col, col, col, col]))
		idx.append_array(PackedInt32Array([i, i + 1, i + 2, i, i + 2, i + 3]))

	func mesh(mat: Material) -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		if verts.size() > 0:
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m.surface_set_material(0, mat)
		return m


static func _rand_dir(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()


static func _shade(rng: RandomNumberGenerator, amount := 0.18) -> Color:
	var k := 1.0 + rng.randf_range(-amount, amount)
	return Color(k, k * rng.randf_range(0.95, 1.05), k * rng.randf_range(0.9, 1.0))


## Tuft of grass blades
static func grass_mesh(rng: RandomNumberGenerator, tint: Color) -> ArrayMesh:
	var c := Cards.new()
	var greens: Array = [Color(0.55, 0.85, 0.5), Color(0.75, 1.0, 0.6), Color(0.5, 0.95, 0.7), Color(0.95, 1.05, 0.55), Color(1.15, 1.15, 0.6), Color(0.45, 0.7, 0.4)]
	for i in rng.randi_range(18, 28):
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0, sin(a))
		var h := rng.randf_range(0.25, 0.95)
		var lean := rng.randf_range(0.1, 0.55)
		var up1 := (Vector3.UP + out * lean * 0.5).normalized()
		var up2 := (Vector3.UP + out * lean * 1.6).normalized()
		var base := out * rng.randf_range(0.0, 0.18)
		var w := rng.randf_range(0.05, 0.11)
		var col: Color = greens[rng.randi() % greens.size()] * rng.randf_range(0.85, 1.1)
		# a blade in two parts, bending over towards its tip
		c.add(base, up1, out.cross(Vector3.UP), w, h * 0.55, col)
		c.add(base + up1 * h * 0.55, up2, out.cross(Vector3.UP), w * 0.75, h * 0.5, col.lightened(0.05))
	return c.mesh(foliage_mat("blade", tint, 0.14))


## Moss / leaf litter / fungal fragments lying on the ground
static func litter_mesh(rng: RandomNumberGenerator, kind: String, tint: Color) -> ArrayMesh:
	match kind:
		"twigs":
			var parts: Array = []
			for i in rng.randi_range(2, 4):
				var l := rng.randf_range(0.3, 0.8)
				var a := rng.randf() * TAU
				var dir := Vector3(cos(a), 0.05, sin(a))
				var p0 := Vector3(rng.randf_range(-0.3, 0.3), 0.02, rng.randf_range(-0.3, 0.3))
				parts.append([CMesh.limb(p0, p0 + dir * l, 0.025, 0.012, Vector3(0, 0.03, 0), 0.0, 5), Transform3D.IDENTITY])
				parts.append([CMesh.limb(p0 + dir * l * 0.5, p0 + dir * l * 0.5 + (dir + Vector3(-dir.z, 0.2, dir.x)).normalized() * l * 0.35, 0.012, 0.006, Vector3.ZERO, 0.0, 4), Transform3D.IDENTITY])
			return _groups([[parts, bark_tinted(tint)]])
		"pebbles":
			var parts2: Array = []
			for i in rng.randi_range(4, 9):
				var sz := rng.randf_range(0.04, 0.2) * (1.0 if rng.randf() < 0.8 else 2.0)
				var sink := rng.randf_range(0.2, 0.55)              # partly buried
				parts2.append([WorldProps.pebble_mesh(rng.randi()), _xf(Vector3(rng.randf_range(-0.6, 0.6), sz * (0.25 - sink * 0.4), rng.randf_range(-0.6, 0.6)),
					Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)), Vector3(sz * rng.randf_range(0.8, 1.4), sz * rng.randf_range(0.5, 0.9), sz))])
			var mats: Array = []
			for k in 3:
				mats.append(WorldProps.rock_mat(tint.lerp(Color(rng.randf(), rng.randf(), rng.randf()).lerp(tint, 0.75), 0.4).darkened(rng.randf_range(-0.1, 0.25)), 0.95))
			var groups: Array = [[[], mats[0]], [[], mats[1]], [[], mats[2]]]
			for i2 in parts2.size():
				groups[i2 % 3][0].append(parts2[i2])
			return _groups(groups)
	# moss / leaf litter: flat patches
	return _flat_cards(rng, "crust", tint, 6, Vector2(0.2, 0.55))


## Fern: arched fronds made of two bent cards each
static func fern_mesh(rng: RandomNumberGenerator, tint: Color) -> ArrayMesh:
	var c := Cards.new()
	var n := rng.randi_range(6, 10)
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.4
		var out := Vector3(cos(a), 0, sin(a))
		var side := out.cross(Vector3.UP)
		var l := rng.randf_range(0.6, 1.1)
		var up1 := (Vector3.UP * 1.0 + out * 0.8).normalized()
		var p1 := up1 * l * 0.55
		c.add(Vector3.ZERO, up1, side, 0.42, l * 0.55, _shade(rng))
		var up2 := (Vector3.UP * 0.1 + out * 1.0).normalized()
		c.add(p1, up2, side, 0.42, l * 0.6, _shade(rng))
	return c.mesh(foliage_mat("frond", tint, 0.09))


## Small flowering plant (crossed flower cards on a short stem)
static func flower_mesh(rng: RandomNumberGenerator, petal: Color) -> ArrayMesh:
	var stem := Cards.new()
	var h := rng.randf_range(0.3, 0.6)
	for i in 3:
		var a := TAU * i / 3.0
		stem.add(Vector3.ZERO, Vector3(cos(a) * 0.3, 1, sin(a) * 0.3), Vector3(-sin(a), 0, cos(a)), 0.1, h * 0.8)
	var m := stem.mesh(foliage_mat("blade", Color(0.8, 1.0, 0.8), 0.05))
	var fl := Cards.new()
	for k in 2:
		var side := Vector3(1, 0, 0) if k == 0 else Vector3(0, 0, 1)
		fl.add(Vector3(0, h * 0.75, 0), Vector3.UP, side, 0.32, 0.32)
	fl.add(Vector3(0, h * 0.9, -0.16), Vector3(0, 0, 1), Vector3(1, 0, 0), 0.32, 0.32)
	var fm := fl.mesh(foliage_mat("flower", petal, 0.05, petal * 0.15))
	# merge the second surface into the first mesh
	var arr := fm.surface_get_arrays(0)
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(1, fm.surface_get_material(0))
	return m


## Leafy bush: leaves around a rounded volume
static func shrub_mesh(rng: RandomNumberGenerator, tint: Color) -> ArrayMesh:
	var c := Cards.new()
	var r := rng.randf_range(0.6, 1.1)
	for i in 34:
		var d := _rand_dir(rng)
		d.y = absf(d.y) * 0.8 + 0.1
		d = d.normalized()
		var p := Vector3(0, r * 0.7, 0) + d * r * rng.randf_range(0.3, 0.9)
		var up := (d + Vector3.UP * 0.5).normalized()
		c.add(p - up * 0.3, up, up.cross(_rand_dir(rng)), rng.randf_range(0.35, 0.55), rng.randf_range(0.6, 0.9), _shade(rng))
	return c.mesh(foliage_mat("leaf", tint, 0.06))


# ================================================================== instanced ground cover
## Scatters `count` copies of `mesh` on the planet within `radius` metres of `centre` (a direction).
## Each copy stands on the curved ground, turned and sized randomly. ok(dir) decides where plants grow.
static func scatter(world: SphereWorld, mesh: Mesh, centre: Vector3, radius: float, count: int, size_min: float, size_max: float,
		ok: Callable, rng: RandomNumberGenerator, view_dist: float, tint_fn := Callable()) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var xf: Array = []
	var cs: Array = []
	var c := centre.normalized()
	for i in count * 3:
		if xf.size() >= count:
			break
		var b := SphereTerrain.surface_basis(c, rng.randf() * TAU)
		var ang := sqrt(rng.randf()) * radius / world.radius
		var d := c.rotated(b.x, ang).normalized()
		if not bool(ok.call(d)):
			continue
		var s := rng.randf_range(size_min, size_max)
		var basis := SphereTerrain.surface_basis(d, rng.randf() * TAU).scaled(Vector3(s, s, s))
		xf.append(Transform3D(basis, world.ground_point(d, -0.04)))
		var shade := _shade(rng, 0.15)
		if tint_fn.is_valid():
			shade *= tint_fn.call(d)
		cs.append(shade)
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = view_dist
	return mmi


# ================================================================== detailed jungle tree
## Curved trunk with bark, root flares, branches, leafy crowns and hanging vines.
## Returns [node, trunk radius].
static func jungle_tree(rng: RandomNumberGenerator, leaf_tint: Color) -> Array:
	var n := Node3D.new()
	var h := rng.randf_range(16.0, 28.0)
	var r0 := rng.randf_range(0.7, 1.3)
	var bk := bark()
	# trunk: bent spine of tapered segments
	var segs := 6
	var bend := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.6, 2.2)
	var pts: Array = []
	for i in segs + 1:
		var k := float(i) / segs
		pts.append(Vector3(0, h * k, 0) + bend * k * k + Vector3(sin(k * 7.0) * 0.25, 0, cos(k * 5.0) * 0.25) * k)
	for i in segs:
		var k0 := float(i) / segs
		var ra := r0 * lerpf(1.0, 0.45, k0)
		var rb := r0 * lerpf(1.0, 0.45, k0 + 1.0 / segs)
		_limb(n, pts[i], pts[i + 1], rb, ra, bk, 10)
	# root flares
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf() * 0.6
		var out := Vector3(cos(a), 0, sin(a))
		var root := _limb(n, out * r0 * 2.4 + Vector3(0, -0.2, 0), Vector3(0, 2.6, 0) + out * r0 * 0.3, r0 * 0.25, r0 * 0.08, bk, 6)
		root.scale = Vector3(0.45, 1.0, 1.0)
	# crowns and vines (all leaves in one mesh)
	var leaves := Cards.new()
	var tops: Array = [pts[segs]]
	for i in rng.randi_range(3, 5):
		var k := rng.randf_range(0.6, 0.88)
		var p0: Vector3 = pts[int(k * segs)]
		var p1: Vector3 = pts[mini(int(k * segs) + 1, segs)]
		var base := p0.lerp(p1, fmod(k * segs, 1.0))
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), rng.randf_range(0.5, 1.0), sin(a)).normalized()
		var end := base + dir * rng.randf_range(4.0, 7.0)
		_limb(n, base, end, r0 * 0.12, r0 * 0.28, bk, 7)
		tops.append(end)
	for tp: Vector3 in tops:
		var cr := rng.randf_range(3.0, 5.0)
		for j in 55:
			var d := _rand_dir(rng)
			d.y = d.y * 0.55 + 0.25
			var p := tp + d * cr * rng.randf_range(0.35, 1.0)
			var up := (d + Vector3.UP * 0.6).normalized()
			leaves.add(p - up * 0.4, up, up.cross(_rand_dir(rng)), rng.randf_range(0.9, 1.5), rng.randf_range(1.4, 2.4), _shade(rng, 0.22))
		# vines hanging from the crown
		for v in rng.randi_range(1, 3):
			var start := tp + Vector3(rng.randf_range(-cr, cr) * 0.7, -cr * 0.3, rng.randf_range(-cr, cr) * 0.7)
			var l := rng.randf_range(5.0, 12.0)
			var y := 0.6
			while y < l:
				var a2 := rng.randf() * TAU
				var side := Vector3(cos(a2), 0, sin(a2))
				leaves.add(start - Vector3(0, y, 0), (Vector3(0, -1, 0) + side * 0.8).normalized(), side.cross(Vector3.UP), 0.35, 0.55, _shade(rng))
				y += rng.randf_range(0.45, 0.8)
	var lm := MeshInstance3D.new()
	lm.mesh = leaves.mesh(foliage_mat("leaf", leaf_tint, 0.1))
	n.add_child(lm)
	# a few glowing bulbs (light at night)
	for i in rng.randi_range(0, 3):
		var tp2: Vector3 = tops[rng.randi() % tops.size()]
		WorldProps.part(n, WorldProps.sphere(0.22, 10, 5), WorldProps.std(Color("#d6ff6b"), 0.4, 0.0, Color("#b6ff4b"), 2.2),
			tp2 + Vector3(rng.randf_range(-2, 2), -2.5, rng.randf_range(-2, 2)))
	return [n, r0]


## A tapered cylinder from a to b
static func _limb(parent: Node3D, a: Vector3, b: Vector3, r_top: float, r_bottom: float, mat: Material, seg: int) -> MeshInstance3D:
	var seg_len := a.distance_to(b)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = seg_len
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.001:
		mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	return mi


# ================================================================== atmosphere pieces
## Slanted beam of sunlight through the leaves
static func light_shaft(mat: ShaderMaterial, length: float, width: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(width, length)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Patch of low mist
static func mist_patch(mat: ShaderMaterial, size: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size * 0.45)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ================================================================== ground cover for every planet
## Merges several primitive meshes (each with its own place) into one surface
static func _merge(parts: Array) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Array in parts:
		var m: Mesh = p[0]
		var xf: Transform3D = p[1]
		st.append_from(m, 0, xf)
	st.generate_tangents()
	return st.commit_to_arrays()


## A mesh made of groups: [[parts, material], ...] - one surface per group
static func _groups(groups: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for g: Array in groups:
		var parts: Array = g[0]
		if parts.is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _merge(parts))
		mesh.surface_set_material(mesh.get_surface_count() - 1, g[1])
	return mesh


static func _xf(pos: Vector3, rot: Vector3, scl: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scl), pos)


## Little cards lying flat on the ground (lichen, moss, leaves)
static func _flat_cards(rng: RandomNumberGenerator, kind: String, tint: Color, count: int, size: Vector2, glow := Color.BLACK) -> ArrayMesh:
	var c := Cards.new()
	for i in count:
		var p := Vector3(rng.randf_range(-0.8, 0.8), 0.03 + i * 0.002, rng.randf_range(-0.8, 0.8))
		var fwd := Vector3(cos(rng.randf() * TAU), 0, sin(rng.randf() * TAU)).normalized()
		var sz := rng.randf_range(size.x, size.y)
		c.add(p - fwd * sz * 0.5, fwd, fwd.cross(Vector3.UP), sz, sz, _shade(rng, 0.2))
	return c.mesh(foliage_mat(kind, tint, 0.0, glow))


## Upright blades / shards fanning out
static func _blades(rng: RandomNumberGenerator, kind: String, tint: Color, count: int, h: Vector2, w: float, lean: float, sway: float, glow := Color.BLACK) -> ArrayMesh:
	var c := Cards.new()
	for i in count:
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0, sin(a))
		var up := (Vector3.UP + out * rng.randf_range(0.0, lean)).normalized()
		c.add(out * rng.randf_range(0.0, 0.15), up, out.cross(Vector3.UP), w * rng.randf_range(0.7, 1.3), rng.randf_range(h.x, h.y), _shade(rng))
	return c.mesh(foliage_mat(kind, tint, sway, glow))


## Small stones (real rock shapes) lying together
static func _gravel(rng: RandomNumberGenerator, col: Color, count: int, size: Vector2, rough := 0.95, metal := 0.0, glow := Color.BLACK) -> ArrayMesh:
	var parts: Array = []
	for i in count:
		var s := rng.randf_range(size.x, size.y)
		parts.append([WorldProps.pebble_mesh(rng.randi()), _xf(Vector3(rng.randf_range(-0.7, 0.7), s * 0.1, rng.randf_range(-0.7, 0.7)),
			Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * rng.randf_range(0.6, 1.0), s))])
	var mat: Material = WorldProps.rock_mat(col, rough, metal)
	if glow != Color.BLACK:
		var gm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		gm.emission_enabled = true
		gm.emission = glow
		gm.emission_energy_multiplier = 1.2
		mat = gm
	return _groups([[parts, mat]])


## Planet-specific ground cover. Returns [mesh, where ("land", "shore", "water"), size range]
## Adds the (first) surface of `other` as a new surface of m (keeps its material)
static func _add_surface(m: ArrayMesh, other: Mesh) -> ArrayMesh:
	for i in other.get_surface_count():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, other.surface_get_arrays(i))
		m.surface_set_material(m.get_surface_count() - 1, other.surface_get_material(i))
	return m


## Small glowing / coloured balls on short stems (spore puffs, sprout bulbs)
static func _bulbs(rng: RandomNumberGenerator, count: int, h: Vector2, r: float, col: Color, glow: Color) -> ArrayMesh:
	var stems: Array = []
	var balls: Array = []
	for i in count:
		var hh := rng.randf_range(h.x, h.y)
		var p := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
		var lean := Vector3(rng.randf_range(-0.2, 0.2), 1.0, rng.randf_range(-0.2, 0.2)).normalized()
		stems.append([WorldProps.cyl(0.012, 0.02, hh, 5), Transform3D(CMesh.along(Vector3.ZERO, lean).basis, p + lean * hh * 0.5)])
		var rr := r * rng.randf_range(0.7, 1.3)
		balls.append([WorldProps.sphere(1.0, 8, 5), _xf(p + lean * hh, Vector3.ZERO, Vector3(rr, rr, rr))])
	return _groups([[stems, WorldProps.std(col.darkened(0.3).lerp(Color("#d8ccc0"), 0.5), 0.8)], [balls, ExploreShaders.nature(col, glow, 1.6, 0.04, 0.5, 0.4)]])


static func cover(kind: String, rng: RandomNumberGenerator, tint: Color) -> Array:
	match kind:
		"tall_grass": return [grass_mesh(rng, tint), "land", Vector2(1.0, 1.0)]
		"broad_grass": return [_blades(rng, "leaf", tint, 7, Vector2(0.3, 0.7), 0.16, 0.5, 0.12), "land", Vector2(1.0, 1.0)]
		"bush", "wind_bush": return [shrub_mesh(rng, tint), "land", Vector2(1.0, 1.0)]
		"stones": return [_gravel(rng, tint, 2, Vector2(0.3, 0.55)), "any", Vector2(1.0, 1.0)]
		"wet_stones": return [_gravel(rng, tint, 4, Vector2(0.15, 0.4), 0.18), "shore", Vector2(1.0, 1.0)]
		"metal_nodules": return [_gravel(rng, tint, 5, Vector2(0.05, 0.16), 0.3, 0.8), "any", Vector2(1.0, 1.0)]
		"hardy_sprout":
			var hs := _blades(rng, "blade", tint, 5, Vector2(0.15, 0.35), 0.06, 0.4, 0.05)
			return [_add_surface(hs, _bulbs(rng, 2, Vector2(0.15, 0.3), 0.04, Color("#ffcf8a"), Color("#ffb347") * 0.4)), "land", Vector2(1.0, 1.0)]
		"frost_fern": return [_blades(rng, "shard", tint, 8, Vector2(0.3, 0.7), 0.12, 0.6, 0.03, Color(0.45, 0.35, 0.95) * 0.35), "land", Vector2(1.0, 1.0)]
		"snow_patch": return [_flat_cards(rng, "crust", Color(1.25, 1.3, 1.4), 6, Vector2(0.35, 0.8)), "land", Vector2(1.0, 1.0)]
		"salt_crust": return [_flat_cards(rng, "crust", Color(1.3, 1.25, 1.15), 6, Vector2(0.3, 0.7)), "land", Vector2(1.0, 1.0)]
		"lava_crack": return [_flat_cards(rng, "crust", Color(0.25, 0.1, 0.06), 5, Vector2(0.3, 0.7), Color(1.0, 0.35, 0.05) * 0.9), "land", Vector2(1.0, 1.0)]
		"ember_plant": return [_blades(rng, "blade", Color(0.45, 0.16, 0.1), 7, Vector2(0.2, 0.5), 0.08, 0.5, 0.05, Color(1.0, 0.4, 0.1) * 0.5), "land", Vector2(1.0, 1.0)]
		"seagrass": return [_blades(rng, "blade", tint, 12, Vector2(0.4, 1.2), 0.06, 0.25, 0.35), "water", Vector2(1.0, 1.0)]
		"spore_puffs": return [_bulbs(rng, rng.randi_range(4, 8), Vector2(0.1, 0.35), 0.05, tint, tint * 0.9), "land", Vector2(1.0, 1.0)]
		"bell_mushrooms":
			var st2: Array = []
			var cp2: Array = []
			for i in rng.randi_range(3, 6):
				var hh3 := rng.randf_range(0.2, 0.6)
				var p3 := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
				st2.append([WorldProps.cyl(0.02, 0.035, hh3, 6), _xf(p3 + Vector3(0, hh3 * 0.5, 0), Vector3.ZERO, Vector3.ONE)])
				var cr3 := hh3 * rng.randf_range(0.25, 0.4)
				cp2.append([WorldProps.sphere(1.0, 10, 6, true), _xf(p3 + Vector3(0, hh3 - cr3 * 0.3, 0), Vector3.ZERO, Vector3(cr3, cr3 * 1.5, cr3))])
			return [_groups([[st2, WorldProps.std(Color("#e8dcc8"), 0.8)], [cp2, ExploreShaders.nature(tint, tint * 0.5, 0.8, 0.0, 0.3, 0.45)]]), "land", Vector2(1.0, 1.0)]
		"sun_dish": return [flower_mesh(rng, Color("#ffd24a")), "land", Vector2(1.0, 1.0)]
		"flowers": return [flower_mesh(rng, tint), "land", Vector2(1.0, 1.0)]
		"grass": return [grass_mesh(rng, tint), "land", Vector2(0.8, 1.5)]
		"pebbles": return [litter_mesh(rng, "pebbles", tint), "any", Vector2(0.8, 1.6)]
		"twigs": return [litter_mesh(rng, "twigs", tint), "land", Vector2(0.8, 1.4)]
		"moss": return [_flat_cards(rng, "crust", tint, 7, Vector2(0.25, 0.6)), "land", Vector2(0.8, 1.6)]
		"leaf_litter": return [_flat_cards(rng, "leaf", tint, 8, Vector2(0.12, 0.25)), "land", Vector2(0.8, 1.4)]
		"fern": return [fern_mesh(rng, tint), "land", Vector2(0.8, 1.8)]
		"shrub": return [shrub_mesh(rng, tint), "land", Vector2(0.8, 1.6)]
		"flower": return [flower_mesh(rng, [Color("#ff6fb7"), Color("#ffd27a"), Color("#9f8bff")][rng.randi() % 3]), "land", Vector2(0.8, 1.3)]
		"gravel": return [_gravel(rng, tint, 6, Vector2(0.06, 0.22)), "land", Vector2(0.7, 1.6)]
		"lichen": return [_flat_cards(rng, "crust", tint, 5, Vector2(0.25, 0.6)), "land", Vector2(0.8, 1.6)]
		"scrap":
			var parts: Array = []
			for i in 5:
				parts.append([WorldProps.box(Vector3(rng.randf_range(0.08, 0.35), 0.03, rng.randf_range(0.05, 0.2))),
					_xf(Vector3(rng.randf_range(-0.6, 0.6), 0.02, rng.randf_range(-0.6, 0.6)), Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)), Vector3.ONE)])
			return [_groups([[parts, WorldProps.std(Color("#8a6a4a"), 0.45, 0.85)]]), "land", Vector2(0.7, 1.4)]
		"frost_grass": return [_blades(rng, "blade", Color(0.8, 0.95, 1.1), 9, Vector2(0.25, 0.6), 0.1, 0.4, 0.06), "land", Vector2(0.8, 1.4)]
		"snow_clump":
			var sp: Array = []
			for i in 4:
				var s2 := rng.randf_range(0.2, 0.5)
				sp.append([WorldProps.pebble_mesh(rng.randi()), _xf(Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5)), Vector3(0, rng.randf() * TAU, 0), Vector3(s2, s2 * 0.45, s2))])
			return [_groups([[sp, WorldProps.std(Color("#f4f9ff"), 0.6)]]), "land", Vector2(0.8, 1.6)]
		"ice_shard", "spark_crystal":
			var parts2: Array = []
			for i in rng.randi_range(3, 6):
				var hh := rng.randf_range(0.2, 0.7)
				parts2.append([WorldProps.cyl(0.0, hh * 0.18, hh, 6), _xf(Vector3(rng.randf_range(-0.4, 0.4), hh * 0.4, rng.randf_range(-0.4, 0.4)),
					Vector3(rng.randf_range(-0.5, 0.5), rng.randf(), rng.randf_range(-0.5, 0.5)), Vector3.ONE)])
			var cm: Material = WorldProps.std(Color("#bfe6ff"), 0.05, 0.2, Color("#4f9fff"), 0.5, 0.85)
			if kind == "spark_crystal":
				cm = ExploreShaders.nature(Color("#4a3f8a"), [Color("#9ff3ff"), Color("#fff36b"), Color("#c48bff")][rng.randi() % 3], 1.8, 0.0, 0.9, 0.15, 0.3)
			return [_groups([[parts2, cm]]), "land", Vector2(0.7, 1.5)]
		"mini_mushroom":
			var stems: Array = []
			var caps: Array = []
			var glow: Color = [Color("#7dffcf"), Color("#ff7de0"), Color("#9fd0ff")][rng.randi() % 3]
			for i in rng.randi_range(4, 8):
				var hh2 := rng.randf_range(0.08, 0.35)
				var p := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
				stems.append([WorldProps.cyl(0.02, 0.03, hh2, 6), _xf(p + Vector3(0, hh2 * 0.5, 0), Vector3.ZERO, Vector3.ONE)])
				var cr := hh2 * rng.randf_range(0.4, 0.7)
				caps.append([WorldProps.sphere(1.0, 10, 5, true), _xf(p + Vector3(0, hh2, 0), Vector3.ZERO, Vector3(cr, cr * 0.6, cr))])
			return [_groups([[stems, WorldProps.std(Color("#d8ccc0"), 0.8)], [caps, ExploreShaders.nature(tint, glow, 1.4, 0.0, 0.5, 0.5)]]), "land", Vector2(0.8, 1.6)]
		"fungal_thread": return [_blades(rng, "blade", tint, 7, Vector2(0.3, 0.8), 0.05, 0.7, 0.08, tint * 0.8), "land", Vector2(0.8, 1.5)]
		"beach_grass": return [_blades(rng, "blade", Color(1.15, 1.05, 0.7), 10, Vector2(0.4, 0.9), 0.08, 0.6, 0.14), "shore", Vector2(0.8, 1.4)]
		"seaweed": return [_blades(rng, "blade", Color(0.7, 0.85, 0.5), 6, Vector2(1.2, 3.0), 0.25, 0.2, 0.25), "water", Vector2(0.8, 1.5)]
		"shells":
			var sh: Array = []
			for i in 5:
				var s3 := rng.randf_range(0.04, 0.1)
				sh.append([WorldProps.sphere(1.0, 10, 5, true), _xf(Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6)), Vector3(0, rng.randf() * TAU, 0), Vector3(s3, s3 * 0.5, s3 * 1.3))])
			return [_groups([[sh, WorldProps.std(Color("#f0d8e0"), 0.3, 0.2)]]), "shore", Vector2(0.8, 1.5)]
		"heat_plant": return [_blades(rng, "shard", Color(0.35, 0.22, 0.18), 8, Vector2(0.3, 0.7), 0.12, 0.5, 0.03, Color(1.0, 0.4, 0.1) * 0.6), "land", Vector2(0.8, 1.5)]
		"cinders": return [_gravel(rng, Color("#2a2220"), 6, Vector2(0.05, 0.18), 0.9, 0.0, Color(1.0, 0.35, 0.08)), "land", Vector2(0.7, 1.5)]
		"storm_grass": return [_blades(rng, "blade", Color(0.6, 0.55, 1.0), 9, Vector2(0.3, 0.75), 0.09, 0.5, 0.2, Color(0.4, 0.8, 1.0) * 0.35), "land", Vector2(0.8, 1.4)]
		"crystal_grass": return [_blades(rng, "shard", Color(1.2, 1.0, 0.6), 7, Vector2(0.25, 0.7), 0.1, 0.35, 0.02, Color(1.0, 0.8, 0.4) * 0.5), "land", Vector2(0.8, 1.5)]
		"glass_pebble": return [_gravel(rng, Color("#d89a40"), 6, Vector2(0.05, 0.16), 0.08, 0.6), "land", Vector2(0.7, 1.4)]
	return [grass_mesh(rng, tint), "land", Vector2(0.8, 1.4)]


# ================================================================== branching plants
static var _barks := {}


## Bark in any colour (same grain texture, tinted)
static func bark_tinted(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if not _barks.has(key):
		var m: StandardMaterial3D = bark().duplicate()
		m.albedo_color = col * 2.2
		_barks[key] = m
	return _barks[key]


## Transform that stretches a 1 m tall cylinder (centred) from a to b
static func _seg_xf(a: Vector3, b: Vector3) -> Transform3D:
	var dir := b - a
	var l := dir.length()
	var y := dir / maxf(l, 0.0001)
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y * l, z), (a + b) * 0.5)


## A whole plant from a recipe: a trunk that forks again and again into thinner, shorter
## branches (each bends a little towards the light or droops), roots spreading into the
## ground, and something growing at the tips (leaves, fronds, crystals, caps, bulbs).
## Everything is merged into a few meshes (fast). Returns [node, trunk radius].
## c: h, r, depth, forks, spread, up, droop, shrink, bend, roots, bark, tip, tip_tint,
##    tip_count, tip_size, glow, sway
static func branch_tree(rng: RandomNumberGenerator, c: Dictionary) -> Array:
	var n := Node3D.new()
	var wood: Array = []
	var cards := Cards.new()
	var solids: Array = []
	var tips: Array = []
	var h := float(c.get("h", 6.0)) * rng.randf_range(0.75, 1.25)
	var r0 := float(c.get("r", 0.25)) * rng.randf_range(0.8, 1.2)
	var depth := int(c.get("depth", 3))
	var unit := CylinderMesh.new()
	unit.top_radius = 1.0
	unit.bottom_radius = 1.0
	unit.height = 1.0
	unit.radial_segments = 7
	unit.rings = 1
	unit.cap_top = false
	unit.cap_bottom = false
	# grow: [start, direction, length, radius, level]
	var todo: Array = [[Vector3.ZERO, (Vector3.UP + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * float(c.get("lean", 0.08))).normalized(), h * float(c.get("trunk", 0.55)), r0, 0]]
	var guard := 0
	while not todo.is_empty() and guard < 400:
		guard += 1
		var b: Array = todo.pop_back()
		var start: Vector3 = b[0]
		var dir: Vector3 = b[1]
		var l: float = b[2]
		var r: float = b[3]
		var lvl: int = b[4]
		# a branch is 3 bending pieces, thinner towards the end
		var p := start
		var d := dir
		var pieces := 3
		for i in pieces:
			var nd := (d + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.3), rng.randf_range(-1, 1)) * float(c.get("bend", 0.18))
				+ Vector3.UP * float(c.get("up", 0.1)) - Vector3.UP * float(c.get("droop", 0.0)) * (lvl + 1) * 0.3).normalized()
			var q := p + nd * l / pieces
			var ra := r * lerpf(1.0, 0.65, float(i) / pieces)
			var rb := r * lerpf(1.0, 0.65, float(i + 1) / pieces)
			var xf := _seg_xf(p, q)
			# taper: scale x/z of the unit cylinder by the average radius
			var rr := (ra + rb) * 0.5
			xf.basis.x *= rr
			xf.basis.z *= rr
			wood.append([unit, xf])
			p = q
			d = nd
		if lvl >= depth:
			tips.append([p, d, r])
			continue
		var forks := int(c.get("forks", 3)) + rng.randi_range(-1, 1)
		var spread := float(c.get("spread", 0.7))
		for k in maxi(forks, 2):
			var side := d.cross(Vector3(rng.randfn(), rng.randfn(), rng.randfn())).normalized()
			var nd2 := (d * (1.0 - spread * 0.5) + side * spread).normalized()
			var from := start.lerp(p, rng.randf_range(0.55, 1.0)) if k > 0 else p
			todo.append([from, nd2, l * float(c.get("shrink", 0.68)) * rng.randf_range(0.8, 1.15), r * 0.62, lvl + 1])
	# roots: thick at the trunk, spreading and diving into the ground
	for i in int(c.get("roots", 4)):
		var a := TAU * i / float(c.get("roots", 4)) + rng.randf() * 0.7
		var out := Vector3(cos(a), 0, sin(a))
		var a0 := Vector3(0, r0 * 1.6, 0)
		var a1 := out * r0 * 2.2 + Vector3(0, r0 * 0.3, 0)
		var a2 := out * r0 * rng.randf_range(3.5, 5.0) + Vector3(0, -r0 * 0.6, 0)
		for seg: Array in [[a0, a1, r0 * 0.45], [a1, a2, r0 * 0.25]]:
			var xf2 := _seg_xf(seg[0], seg[1])
			xf2.basis.x *= float(seg[2])
			xf2.basis.z *= float(seg[2])
			wood.append([unit, xf2])
	var groups: Array = [[wood, bark_tinted(Color(c.get("bark", Color("#5a4632"))))]]
	# what grows at the tips
	var tip := str(c.get("tip", "leaf"))
	var tint: Color = c.get("tip_tint", Color("#3c8a2c"))
	var glow: Color = c.get("glow", Color.BLACK)
	var count := int(c.get("tip_count", 10))
	var tsize := float(c.get("tip_size", 1.0))
	for t: Array in tips:
		var tp: Vector3 = t[0]
		var td: Vector3 = t[1]
		match tip:
			"leaf", "frond", "blade", "needle":
				var kind := "leaf" if tip == "needle" else tip
				for j in count:
					var dd := (td * 0.6 + _rand_dir(rng)).normalized()
					if tip == "frond":
						dd = (dd + Vector3.DOWN * 0.4).normalized()
					var w := rng.randf_range(0.5, 0.9) * tsize * (0.35 if tip == "needle" else 1.0)
					cards.add(tp + _rand_dir(rng) * 0.25 * tsize, dd, dd.cross(_rand_dir(rng)), w, rng.randf_range(0.8, 1.4) * tsize, _shade(rng, 0.25))
			"crystal":
				for j in count:
					var cl := rng.randf_range(0.2, 0.6) * tsize
					var cd := (td + _rand_dir(rng) * 0.6).normalized()
					var xf3 := _seg_xf(tp, tp + cd * cl)
					xf3.basis.x *= cl * 0.12
					xf3.basis.z *= cl * 0.12
					solids.append([WorldProps.cyl(0.0, 1.0, 1.0, 5), xf3])
			"cap", "bulb", "pod":
				var s := rng.randf_range(0.25, 0.5) * tsize
				var flat := 0.45 if tip == "cap" else (1.0 if tip == "bulb" else 1.6)
				var xf4 := Transform3D(Basis.looking_at(td, Vector3.UP if absf(td.y) < 0.95 else Vector3.RIGHT).scaled(Vector3(s, s, s * flat)), tp)
				if tip == "cap":
					xf4 = Transform3D(Basis().scaled(Vector3(s * 1.8, s * 0.7, s * 1.8)), tp + Vector3(0, s * 0.2, 0))
				solids.append([WorldProps.sphere(1.0, 10, 6, tip == "cap"), xf4])
	if not solids.is_empty():
		var sm: Material
		if tip == "crystal":
			sm = ExploreShaders.nature(tint, glow, 1.6, 0.0, 0.6, 0.12, 0.3)
		else:
			sm = ExploreShaders.nature(tint, glow, 1.3, float(c.get("sway", 0.05)), 0.4, 0.6)
		groups.append([solids, sm])
	var mi := MeshInstance3D.new()
	mi.mesh = _groups(groups)
	n.add_child(mi)
	if cards.verts.size() > 0:
		var lm := MeshInstance3D.new()
		var kind2 := "leaf" if tip == "needle" else tip
		lm.mesh = cards.mesh(foliage_mat(kind2, tint, float(c.get("sway", 0.12)), glow))
		n.add_child(lm)
	return [n, r0]
