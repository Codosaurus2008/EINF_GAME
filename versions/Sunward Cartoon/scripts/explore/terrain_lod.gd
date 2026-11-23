class_name TerrainLOD
extends Node3D
## The planet's ground as 216 chunks (6 x 6 on each cube face). Chunks near the camera are built
## with fine cells (about 1 m, 0.5 m inside fresh craters), far ones coarse. Rebuilding happens a
## little every frame (nothing stalls). Each chunk has a skirt hanging down along its edges, so
## neighbours with different detail never show gaps.
## A crater rebuilds only the few chunks it touches - never the whole planet.

const PER_FACE := 6
const LEVELS := [6, 12, 24, 48, 96]       # cells along a chunk
const HEIGHTS_PER_FRAME := 500       # each height costs ~15-20 µs: about 8 ms per frame at most

var terrain: SphereTerrain
var mat: Material
var chunks: Array = []          # {f, i, j, mi, level, centre, building}
var jobs: Array = []            # [chunk index, level, n, heights, rows done]
var viewer := Vector3.ZERO
var tick := 0.0
var size_m := 50.0              # chunk edge length (m)
var primed := false


func setup(t: SphereTerrain, material: Material) -> void:
	terrain = t
	mat = material
	size_m = t.radius * PI * 0.5 / PER_FACE
	for f in 6:
		for i in PER_FACE:
			for j in PER_FACE:
				var mi := MeshInstance3D.new()
				mi.material_override = mat
				add_child(mi)
				var c := _dir(f, i, j, 0.5, 0.5)
				var ch := {"f": f, "i": i, "j": j, "mi": mi, "level": -1, "centre": c * (t.radius + t.height(c)), "dirty": false}
				chunks.append(ch)
	for f in 6:
		build_face(f)


func build_face(f: int) -> void:
	for k in PER_FACE * PER_FACE:
		_build_now(f * PER_FACE * PER_FACE + k, 0)


## Point on the unit sphere: chunk (i, j) of face f, (a, b) = 0 .. 1 inside the chunk
func _dir(f: int, i: int, j: int, a: float, b: float) -> Vector3:
	var u := -1.0 + 2.0 * (i + a) / PER_FACE
	var v := -1.0 + 2.0 * (j + b) / PER_FACE
	return terrain._cube_dir(f, u, v)


func _want(ci: int) -> int:
	var ch: Dictionary = chunks[ci]
	var c: Vector3 = ch["centre"]
	# distance to the chunk's nearest part (not its centre): the ground right next to you is
	# always fine, even at the edge of a chunk
	var d := maxf(0.0, c.distance_to(viewer) - size_m * 0.72)
	var s := size_m
	var lvl := 0
	if d < s * 0.45:
		lvl = 3
	elif d < s * 1.4:
		lvl = 2
	elif d < s * 3.8:
		lvl = 1
	# fresh craters get extra-fine cells close up
	if lvl == 3 and bool(ch.get("crater", false)) and d < s * 0.25:
		lvl = 4
	# hysteresis: keep the finer mesh a bit longer when walking away
	var cur := int(ch["level"])
	if cur > lvl:
		var lim: float = [INF, s * 3.8, s * 1.4, s * 0.45, s * 0.25][cur]
		if d < lim * 1.15:
			return cur
	return lvl


## The camera position (set every frame). The first time, the chunks around it are built at once.
func update_viewer(p: Vector3) -> void:
	viewer = p
	if not primed and p.length() > 1.0:
		primed = true
		for ci in chunks.size():
			var w := _want(ci)
			if w >= 2:
				_build_now(ci, w)


func _process(delta: float) -> void:
	if terrain == null or not primed:
		return
	tick -= delta
	if tick <= 0.0:
		tick = 0.25
		_plan()
	_work()


## Which chunks need a different level (nearest first, finer first)
func _plan() -> void:
	var want: Array = []
	for ci in chunks.size():
		var ch: Dictionary = chunks[ci]
		if bool(ch.get("queued", false)):
			continue
		var w := _want(ci)
		if w != int(ch["level"]) or bool(ch["dirty"]):
			var cc: Vector3 = ch["centre"]
			var d := cc.distance_to(viewer)
			want.append([d - (500.0 if bool(ch["dirty"]) else 0.0), ci, w])
	want.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for e: Array in want:
		if jobs.size() >= 3:
			break
		var ci2 := int(e[1])
		var ch2: Dictionary = chunks[ci2]
		ch2["queued"] = true
		ch2["dirty"] = false
		var n: int = LEVELS[int(e[2])]
		jobs.append([ci2, int(e[2]), n, PackedFloat32Array(), 0])


func _work() -> void:
	var budget := HEIGHTS_PER_FRAME
	while budget > 0 and not jobs.is_empty():
		var job: Array = jobs[0]
		var ci := int(job[0])
		var n := int(job[2])
		var hs: PackedFloat32Array = job[3]
		var g := n + 3                         # samples per row, with a border for the normals
		var row := int(job[4])
		var ch: Dictionary = chunks[ci]
		while row < g and budget > 0:
			for gi in g:
				hs.append(terrain.height(_dir(int(ch["f"]), int(ch["i"]), int(ch["j"]), (gi - 1.0) / n, (row - 1.0) / n)))
			row += 1
			budget -= g
		job[3] = hs
		job[4] = row
		if row >= g:
			jobs.pop_front()
			_commit(ci, int(job[1]), n, hs)
			ch["queued"] = false
			budget -= n * n / 3                # building the mesh costs time too


func _build_now(ci: int, level: int) -> void:
	var ch: Dictionary = chunks[ci]
	var n: int = LEVELS[level]
	var g := n + 3
	var hs := PackedFloat32Array()
	hs.resize(g * g)
	for row in g:
		for gi in g:
			hs[row * g + gi] = terrain.height(_dir(int(ch["f"]), int(ch["i"]), int(ch["j"]), (gi - 1.0) / n, (row - 1.0) / n))
	_commit(ci, level, n, hs)


## Builds the chunk's mesh from its height grid (index = row * (n + 3) + column, border included)
func _commit(ci: int, level: int, n: int, hs: PackedFloat32Array) -> void:
	var ch: Dictionary = chunks[ci]
	var f := int(ch["f"])
	var ii := int(ch["i"])
	var jj := int(ch["j"])
	var g := n + 3
	var r := terrain.radius
	var pos := PackedVector3Array()
	pos.resize(g * g)
	for row in g:
		for gi in g:
			var d := _dir(f, ii, jj, (gi - 1.0) / n, (row - 1.0) / n)
			pos[row * g + gi] = d * (r + hs[row * g + gi])
	var n1 := n + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n1 * n1)
	norms.resize(n1 * n1)
	cols.resize(n1 * n1)
	for row in n1:
		for gi in n1:
			var k := (row + 1) * g + gi + 1
			var p := pos[k]
			var px := pos[k + 1] - pos[k - 1]
			var pz := pos[k + g] - pos[k - g]
			var nrm := px.cross(pz).normalized()
			var d := p.normalized()
			if nrm.dot(d) < 0.0:
				nrm = -nrm
			var o := row * n1 + gi
			verts[o] = p
			norms[o] = nrm
			cols[o] = terrain.vertex_color(d, hs[k], 1.0 - nrm.dot(d))
	var idx := PackedInt32Array()
	for row in n:
		for gi in n:
			var a := row * n1 + gi
			var b := a + 1
			var c := a + n1
			var dd := c + 1
			idx.append_array(PackedInt32Array([a, c, b, b, c, dd]))
	# skirts: a strip hanging down along every edge, hides cracks between different detail levels
	var skirt := size_m / n * 0.9 + 0.4
	var edges: Array = []
	var e0: Array = []
	var e1: Array = []
	var e2: Array = []
	var e3: Array = []
	for q in n1:
		e0.append(q)                         # first row
		e1.append(n * n1 + q)                # last row
		e2.append(q * n1)                    # first column
		e3.append(q * n1 + n)                # last column
	edges = [e0, e1, e2, e3]
	for e: Array in edges:
		var base := verts.size()
		for q in n1:
			var vi := int(e[q])
			var p2 := verts[vi]
			verts.append(p2 - p2.normalized() * skirt)
			norms.append(norms[vi])
			cols.append(cols[vi].darkened(0.2))
		for q in n:
			var a2 := int(e[q])
			var b2 := int(e[q + 1])
			var c2 := base + q
			var d2 := base + q + 1
			# both windings: the skirt is visible from either side
			idx.append_array(PackedInt32Array([a2, b2, c2, b2, d2, c2, a2, c2, b2, b2, c2, d2]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi: MeshInstance3D = ch["mi"]
	mi.mesh = mesh
	# far, coarse chunks don't need to cast shadows
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level >= 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ch["level"] = level
	ch["hs"] = hs
	ch["n"] = n
	var c3 := _dir(f, ii, jj, 0.5, 0.5)
	ch["centre"] = c3 * (r + terrain.height(c3))


## After a crater: rebuild only the chunks it touches (first in line)
func refresh(dir: Vector3, reach: float) -> void:
	var nearest := -1
	var best := INF
	for ci in chunks.size():
		var ch: Dictionary = chunks[ci]
		# any chunk whose area may include the crater: rebuilt first, finer close up
		var c: Vector3 = ch["centre"]
		var ang := c.normalized().angle_to(dir.normalized()) * terrain.radius
		if ang < size_m * 0.75 + reach:
			ch["crater"] = true
			ch["dirty"] = true
			if ang < best:
				best = ang
				nearest = ci
	# the chunk with the impact: a quick medium-detail rebuild at once (~10 ms), so the hole is
	# there right away; the fine version follows over the next frames
	if nearest >= 0 and not bool(chunks[nearest].get("queued", false)):
		_build_now(nearest, 2)
	tick = 0.0


# ================================================================== the drawn surface
## Height of the ground exactly as it is drawn right now (the same triangles as the mesh, at
## the chunk's current detail level). Walking uses this, so you never sink into the visible
## ground or float above it, whatever detail the chunk has. -INF if not known.
func surface_height(dir: Vector3) -> float:
	var fuv := cube_uv(dir)
	var f := int(fuv.x)
	var a := (fuv.y + 1.0) * 0.5 * PER_FACE
	var b := (fuv.z + 1.0) * 0.5 * PER_FACE
	var i := clampi(int(a), 0, PER_FACE - 1)
	var j := clampi(int(b), 0, PER_FACE - 1)
	var ch: Dictionary = chunks[(f * PER_FACE + i) * PER_FACE + j]
	if not ch.has("hs"):
		return -INF
	var hs: PackedFloat32Array = ch["hs"]
	var n := int(ch["n"])
	var g := n + 3
	var x := clampf((a - i) * n, 0.0, n - 0.0001)
	var y := clampf((b - j) * n, 0.0, n - 0.0001)
	var gi := int(x)
	var row := int(y)
	var fu := x - gi
	var fv := y - row
	var k := (row + 1) * g + gi + 1
	var ha := hs[k]
	var hb := hs[k + 1]
	var hc := hs[k + g]
	var hd := hs[k + g + 1]
	# the mesh splits every cell into the triangles (a, c, b) and (b, c, d)
	if fu + fv <= 1.0:
		return ha + fu * (hb - ha) + fv * (hc - ha)
	return hd + (1.0 - fu) * (hc - hd) + (1.0 - fv) * (hb - hd)


## Cube face and face coordinates (u, v in -1 .. 1) of a direction: the exact inverse of
## SphereTerrain._cube_dir (first guess per face, then a few Newton steps)
func cube_uv(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	var ax := absf(d.x)
	var ay := absf(d.y)
	var az := absf(d.z)
	var f := 0
	var u := 0.0
	var v := 0.0
	if ax >= ay and ax >= az:
		if d.x > 0.0:
			f = 0
			u = -d.z / d.x
			v = d.y / d.x
		else:
			f = 1
			u = d.z / -d.x
			v = d.y / -d.x
	elif ay >= az:
		if d.y > 0.0:
			f = 2
			u = d.x / d.y
			v = -d.z / d.y
		else:
			f = 3
			u = d.x / -d.y
			v = d.z / -d.y
	elif d.z > 0.0:
		f = 4
		u = d.x / d.z
		v = d.y / d.z
	else:
		f = 5
		u = d.x / d.z
		v = -d.y / d.z
	var e := 0.0001
	for it in 4:
		var f0 := terrain._cube_dir(f, u, v)
		var du := (terrain._cube_dir(f, u + e, v) - f0) / e
		var dv := (terrain._cube_dir(f, u, v + e) - f0) / e
		var r := d - f0
		var a11 := du.dot(du)
		var a12 := du.dot(dv)
		var a22 := dv.dot(dv)
		var b1 := du.dot(r)
		var b2 := dv.dot(r)
		var det := a11 * a22 - a12 * a12
		if absf(det) < 1e-12:
			break
		u = clampf(u + (a22 * b1 - a12 * b2) / det, -1.0, 1.0)
		v = clampf(v + (a11 * b2 - a12 * b1) / det, -1.0, 1.0)
	return Vector3(f, u, v)


## Triangles drawn by the near chunks (for the F3 meter)
func level_counts() -> Array:
	var counts := [0, 0, 0, 0, 0]
	for ch: Dictionary in chunks:
		var l := int(ch["level"])
		if l >= 0:
			counts[l] += 1
	return counts
