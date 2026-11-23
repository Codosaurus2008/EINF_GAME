class_name CMesh
extends RefCounted
## Mesh building blocks for the creatures. Bodies are not spheres: they are "lofted" tubes
## along a curved spine with a different cross-section at every ring (wide chest, narrow waist,
## flat belly, square armour, bumps). Limbs, necks, tails, horns, tentacles and pipes are
## tubes too. Plus crystals, curved armour plates, wing / fin membranes and gears.

static var _noise: FastNoiseLite
static var _cache := {}


static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		_noise.seed = 4242
	return _noise


## A tube through the points `path`, with radii[i] = Vector2(side, up) at every point.
## square: 0 = round, 1 = boxy. bumps: lumpy surface (noise), seed shifts the lumps.
## flat_belly: flattens the lower half (bodies). cap: close the ends.
static func tube(path: Array, radii: Array, sides := 12, square := 0.0, bumps := 0.0, lump_seed := 0.0,
		flat_belly := 0.0, cap := true) -> ArrayMesh:
	var n := path.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var e := lerpf(1.0, 0.3, clampf(square, 0.0, 1.0))
	var nz := _n()
	# frames along the path (parallel transport, so the tube does not twist)
	var tangents: Array = []
	for i in n:
		var a: Vector3 = path[maxi(i - 1, 0)]
		var b: Vector3 = path[mini(i + 1, n - 1)]
		var t := (b - a)
		tangents.append(t.normalized() if t.length() > 0.00001 else Vector3.FORWARD)
	var t0: Vector3 = tangents[0]
	var up := Vector3.UP if absf(t0.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var nrm := (up - t0 * up.dot(t0)).normalized()
	var length_v := 0.0
	for i in n:
		var t: Vector3 = tangents[i]
		nrm = (nrm - t * nrm.dot(t))
		if nrm.length() < 0.0001:
			nrm = t.cross(Vector3.RIGHT)
		nrm = nrm.normalized()
		var bin := t.cross(nrm).normalized()
		var p: Vector3 = path[i]
		if i > 0:
			length_v += p.distance_to(path[i - 1])
		var r: Vector2 = radii[i]
		for k in sides + 1:
			var ang := TAU * float(k) / sides
			var c := cos(ang)
			var s := sin(ang)
			var cx := signf(c) * pow(absf(c), e)
			var sy := signf(s) * pow(absf(s), e)
			var ry := r.y
			if sy < 0.0:
				ry *= 1.0 - flat_belly
			var lump := 1.0
			if bumps > 0.0:
				var probe := p + (bin * c + nrm * s) * maxf(r.x, r.y)
				lump = 1.0 + bumps * nz.get_noise_3d(probe.x * 6.0 + lump_seed, probe.y * 6.0, probe.z * 6.0)
			var off := (bin * cx * r.x + nrm * sy * ry) * lump
			verts.append(p + off)
			var gx := signf(c) * pow(absf(c), 2.0 - e) / maxf(r.x, 0.0001)
			var gy := signf(s) * pow(absf(s), 2.0 - e) / maxf(ry, 0.0001)
			var nn := (bin * gx + nrm * gy)
			norms.append(nn.normalized() if nn.length() > 0.00001 else nrm)
			uvs.append(Vector2(float(k) / sides, length_v))
	var row := sides + 1
	for i in n - 1:
		for k in sides:
			var a0 := i * row + k
			var b0 := a0 + row
			# Godot draws faces whose corners go clockwise (seen from outside) as the front
			idx.append_array(PackedInt32Array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0]))
	if cap:
		for end: int in [0, n - 1]:
			var centre: Vector3 = path[end]
			var t2: Vector3 = tangents[end] * (-1.0 if end == 0 else 1.0)
			var ci := verts.size()
			verts.append(centre)
			norms.append(t2)
			uvs.append(Vector2(0.5, 0.0))
			var first := verts.size()
			for k in sides + 1:
				verts.append(verts[end * row + k])
				norms.append(t2)
				uvs.append(Vector2(float(k) / sides, 0.0))
			for k in sides:
				if end == 0:
					idx.append_array(PackedInt32Array([ci, first + k + 1, first + k]))
				else:
					idx.append_array(PackedInt32Array([ci, first + k, first + k + 1]))
	return _arrays(verts, norms, uvs, idx)


static func _arrays(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Points along a curve from a to b, bending towards `bend` (a quadratic curve)
static func curve(a: Vector3, b: Vector3, bend: Vector3, count := 6) -> Array:
	var out: Array = []
	var m := (a + b) * 0.5 + bend
	for i in count:
		var t := float(i) / (count - 1)
		out.append(a.lerp(m, t).lerp(m.lerp(b, t), t))
	return out


## Radii that go from r0 to r1 (with an optional bulge in the middle, like a muscle)
static func taper(count: int, r0: float, r1: float, bulge := 0.0, flat := 1.0) -> Array:
	var out: Array = []
	for i in count:
		var t := float(i) / (count - 1)
		var r := lerpf(r0, r1, t) * (1.0 + bulge * sin(t * PI))
		out.append(Vector2(r, r * flat))
	return out


## A limb / tail / tentacle / pipe from a to b
static func limb(a: Vector3, b: Vector3, r0: float, r1: float, bend := Vector3.ZERO, bulge := 0.2, sides := 8, bumps := 0.0) -> ArrayMesh:
	var pts := curve(a, b, bend, 6)
	return tube(pts, taper(6, r0, r1, bulge), sides, 0.0, bumps, a.x * 3.1 + b.z)


## A horn / spine / claw: curved and pointed
static func horn(a: Vector3, b: Vector3, r: float, bend := Vector3.ZERO, sides := 7, square := 0.0) -> ArrayMesh:
	var pts := curve(a, b, bend, 7)
	var rad: Array = []
	for i in 7:
		var t := float(i) / 6.0
		var rr := r * (1.0 - t) * (1.0 - t * 0.2) + 0.002
		rad.append(Vector2(rr, rr))
	return tube(pts, rad, sides, square, 0.0, 0.0, 0.0, true)


## A crystal: a prism with a pointed tip (5-6 sides)
static func crystal(length: float, r: float, sides := 6) -> ArrayMesh:
	var key := "c%d|%.3f|%.3f" % [sides, length, r]
	if _cache.has(key):
		return _cache[key]
	var pts: Array = [Vector3.ZERO, Vector3(0, length * 0.15, 0), Vector3(0, length * 0.72, 0), Vector3(0, length, 0)]
	var rad: Array = [Vector2(r * 0.7, r * 0.7), Vector2(r, r), Vector2(r * 0.95, r * 0.95), Vector2(0.001, 0.001)]
	var m := tube(pts, rad, sides, 0.0, 0.0, 0.0, 0.0, true)
	_cache[key] = m
	return m


## A curved armour plate (a lens-shaped slab, `w` wide, `l` long, `th` thick), lying along +z
static func plate(w: float, l: float, th: float, curl := 0.25, square := 0.6) -> ArrayMesh:
	var key := "p|%.3f|%.3f|%.3f|%.2f|%.2f" % [w, l, th, curl, square]
	if _cache.has(key):
		return _cache[key]
	var pts: Array = []
	var rad: Array = []
	for i in 5:
		var t := float(i) / 4.0
		pts.append(Vector3(0, -curl * l * pow(2.0 * t - 1.0, 2.0) * 0.3, (t - 0.5) * l))
		var k := sin(t * PI) * 0.85 + 0.15
		rad.append(Vector2(w * 0.5 * k, th * 0.5 * k))
	var m := tube(pts, rad, 10, square, 0.0, 0.0, 0.0, true)
	_cache[key] = m
	return m


## A membrane (wing / fin / frill) between a root point and a row of tips: scalloped edge
## between the tips. Double-sided material needed.
static func membrane(root: Vector3, tips: Array, scallop := 0.25) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in tips.size() - 1:
		var a: Vector3 = tips[i]
		var b: Vector3 = tips[i + 1]
		var mid := (a + b) * 0.5
		var s := mid.lerp(root, scallop)
		for tri: Array in [[root, a, s], [root, s, b]]:
			var p0: Vector3 = tri[0]
			var p1: Vector3 = tri[1]
			var p2: Vector3 = tri[2]
			var fn := (p1 - p0).cross(p2 - p0).normalized()
			var base := verts.size()
			verts.append_array(PackedVector3Array([p0, p1, p2]))
			norms.append_array(PackedVector3Array([fn, fn, fn]))
			uvs.append_array(PackedVector2Array([Vector2(0, 0), Vector2(float(i) / tips.size(), 1), Vector2(float(i + 1) / tips.size(), 0.8)]))
			idx.append_array(PackedInt32Array([base, base + 1, base + 2]))
	return _arrays(verts, norms, uvs, idx)


## A gear wheel (teeth around a disc, with a hub), lying flat in the xz plane
static func gear(r: float, teeth := 10, th := 0.04) -> ArrayMesh:
	var key := "g|%.3f|%d|%.3f" % [r, teeth, th]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var disc := CylinderMesh.new()
	disc.top_radius = r * 0.82
	disc.bottom_radius = r * 0.82
	disc.height = th
	disc.radial_segments = maxi(teeth * 2, 12)
	disc.rings = 1
	st.append_from(disc, 0, Transform3D.IDENTITY)
	var hub := CylinderMesh.new()
	hub.top_radius = r * 0.25
	hub.bottom_radius = r * 0.25
	hub.height = th * 1.8
	hub.radial_segments = 10
	hub.rings = 1
	st.append_from(hub, 0, Transform3D.IDENTITY)
	var tooth := BoxMesh.new()
	tooth.size = Vector3(r * 0.22, th, r * 0.3)
	for i in teeth:
		var a := TAU * i / teeth
		st.append_from(tooth, 0, Transform3D(Basis(Vector3.UP, a), Vector3(sin(a), 0, cos(a)) * r * 0.9))
	# spokes cut-outs look: 4 darker bars are done by the material; keep it simple
	var m := st.commit()
	_cache[key] = m
	return m


## Simple shapes (cached)
static func ball(r: float, seg := 12, rings := 8) -> SphereMesh:
	var key := "b|%.3f|%d" % [r, seg]
	if not _cache.has(key):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = seg
		s.rings = rings
		_cache[key] = s
	return _cache[key]


static func cyl(top: float, bottom: float, h: float, seg := 10) -> CylinderMesh:
	var key := "y|%.3f|%.3f|%.3f|%d" % [top, bottom, h, seg]
	if not _cache.has(key):
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = h
		c.radial_segments = seg
		c.rings = 1
		_cache[key] = c
	return _cache[key]


static func ring(inner: float, outer: float, seg := 28) -> TorusMesh:
	var key := "t|%.3f|%.3f" % [inner, outer]
	if not _cache.has(key):
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = seg
		t.ring_segments = 8
		_cache[key] = t
	return _cache[key]


static func box(s: Vector3) -> BoxMesh:
	var key := "x|%s" % s
	if not _cache.has(key):
		var b := BoxMesh.new()
		b.size = s
		_cache[key] = b
	return _cache[key]


## Transform helper: put something at `pos`, its +Y pointing along `dir`, scaled
static func along(pos: Vector3, dir: Vector3, scale := Vector3.ONE, roll := 0.0) -> Transform3D:
	var y := dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	var b := Basis(x, y, z)
	if roll != 0.0:
		b = b * Basis(Vector3.UP, roll)
	return Transform3D(Basis(b.x * scale.x, b.y * scale.y, b.z * scale.z), pos)


## Merges every static mesh part below `root` (through plain Node3D groups) into one mesh per
## material: a rock cluster or a plant made of 30 parts is then drawn with 1-3 draw calls.
## Only parts with their own material (material_override) and one surface are merged; animated
## pivots should not be passed in.
static func merge_deep(root: Node3D) -> void:
	var groups := {}
	_collect(root, Transform3D.IDENTITY, groups)
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		var mat: Material = null
		for e: Array in list:
			var mi: MeshInstance3D = e[0]
			var xf: Transform3D = e[1]
			mat = mi.material_override
			var nb := xf.basis.inverse().transposed()
			var arr := mi.mesh.surface_get_arrays(0)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nn: Variant = arr[Mesh.ARRAY_NORMAL]
			var uu: Variant = arr[Mesh.ARRAY_TEX_UV]
			var ii: Variant = arr[Mesh.ARRAY_INDEX]
			var base := verts.size()
			for k in v.size():
				verts.append(xf * v[k])
			if nn is PackedVector3Array and (nn as PackedVector3Array).size() == v.size():
				var np: PackedVector3Array = nn
				for k2 in np.size():
					norms.append((nb * np[k2]).normalized())
			else:
				for k3 in v.size():
					norms.append(Vector3.UP)
			if uu is PackedVector2Array and (uu as PackedVector2Array).size() == v.size():
				uvs.append_array(uu)
			else:
				uvs.resize(uvs.size() + v.size())
			if ii is PackedInt32Array and (ii as PackedInt32Array).size() > 0:
				var ip: PackedInt32Array = ii
				for k4 in ip.size():
					idx.append(ip[k4] + base)
			else:
				for k5 in v.size():
					idx.append(base + k5)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var merged := MeshInstance3D.new()
		merged.mesh = am
		merged.material_override = mat
		root.add_child(merged)
		for e2: Array in list:
			var old: MeshInstance3D = e2[0]
			old.get_parent().remove_child(old)
			old.free()


static func _collect(n: Node, xf: Transform3D, groups: Dictionary) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var cx := xf * mi.transform
			if mi.get_child_count() > 0:
				_collect(mi, cx, groups)
				continue
			if mi.material_override == null or mi.mesh == null or mi.mesh is ImmediateMesh or mi.mesh.get_surface_count() != 1:
				continue
			var key := mi.material_override.get_instance_id()
			if not groups.has(key):
				groups[key] = []
			groups[key].append([mi, cx])
		elif c.get_class() == "Node3D":
			_collect(c, xf * (c as Node3D).transform, groups)
