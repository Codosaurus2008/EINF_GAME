class_name WorldProps
extends RefCounted
## Builds the plants, rocks and formations of the planets out of simple 3D shapes.
## make(kind, ...) returns a Node3D standing on its own origin (the ground).
## Nodes with the meta "anim" are animated by SphereWorld (floating rocks, geysers ...).
## To add a new prop: add a case in make() and use the kind in Biomes "props".

static var _mats := {}
static var _meshes := {}
static var _detail_tex: NoiseTexture2D
static var _detail_nrm: NoiseTexture2D
static var _rock_tex: NoiseTexture2D
static var _rock_nrm: NoiseTexture2D
static var _rock_meshes: Array = []
static var _rock_mats := {}
## Colours of the zone where the next prop stands (set by SphereWorld, see Biomes "palettes")
static var palette: Dictionary = {}


static func pick(key: String, fallback: Array, rng: RandomNumberGenerator) -> Color:
	var list: Array = palette.get(key, fallback)
	if list.is_empty():
		list = fallback
	return list[rng.randi() % list.size()]

## Where a prop may stand: land (dry), water (under water), shore, any
const PLACE := {"lake_log": "lake", "bank_rock": "bank", "driftwood": "shore", "kelp": "water", "coral": "water", "reef_rock": "water", "sea_fan": "water", "tube_sponge": "water", "palm": "shore", "beach_rock": "shore", "mangrove": "shore", "palm_hd": "shore"}

## Recipes for branching plants (Flora.branch_tree): every planet grows in its own way
const TREES := {
	# Pebble: slow mineral plants in thin light - stony stems with crystal tips, wiry shrubs
	"lithophyte": {"h": 1.6, "r": 0.09, "depth": 2, "forks": 3, "spread": 0.8, "up": 0.25, "roots": 3, "bark": Color("#5a524a"),
		"tip": "crystal", "tip_tint": Color("#3f7f86"), "glow": Color("#3fd6e0"), "tip_count": 3, "tip_size": 0.6, "trunk": 0.4},
	"wire_shrub": {"h": 1.2, "r": 0.04, "depth": 3, "forks": 3, "spread": 0.9, "up": 0.0, "droop": 0.05, "roots": 2, "bark": Color("#6a5040"),
		"tip": "needle", "tip_tint": Color("#8a7a5a"), "tip_count": 4, "tip_size": 0.35, "trunk": 0.3, "sway": 0.05},
	# Glacia: frost-trees with blue needles and ice-pods, rime bushes
	"frost_tree": {"h": 9.0, "r": 0.32, "depth": 3, "forks": 3, "spread": 0.55, "up": 0.2, "droop": 0.15, "roots": 5, "bark": Color("#4a5468"),
		"tip": "needle", "tip_tint": Color("#9ad8ff"), "tip_count": 12, "tip_size": 1.2, "trunk": 0.5, "sway": 0.06},
	"rime_bush": {"h": 1.8, "r": 0.07, "depth": 3, "forks": 3, "spread": 0.9, "up": 0.15, "roots": 3, "bark": Color("#6a7488"),
		"tip": "crystal", "tip_tint": Color("#dff4ff"), "glow": Color("#5fb8ff") * 0.4, "tip_count": 3, "tip_size": 0.4, "trunk": 0.25},
	# Mycelia: branching spore trees with glowing caps, curtains of hanging roots
	"spore_tree": {"h": 8.0, "r": 0.35, "depth": 3, "forks": 3, "spread": 0.75, "up": 0.3, "roots": 6, "bark": Color("#5a3a5a"),
		"tip": "cap", "tip_tint": Color("#c46fd8"), "glow": Color("#ff6fb7") * 0.7, "tip_size": 1.3, "trunk": 0.45, "bend": 0.3},
	"root_curtain": {"h": 4.5, "r": 0.18, "depth": 2, "forks": 4, "spread": 1.0, "up": 0.0, "droop": 0.9, "roots": 6, "bark": Color("#4a3a2a"),
		"tip": "blade", "tip_tint": Color("#2fa898"), "glow": Color("#4ff2ff") * 0.5, "tip_count": 6, "tip_size": 0.9, "trunk": 0.6, "sway": 0.2},
	# Aquora sea floor: fan corals and tube sponges
	"sea_fan": {"h": 2.4, "r": 0.06, "depth": 3, "forks": 3, "spread": 1.0, "up": 0.35, "roots": 0, "bark": Color("#c8506a"),
		"tip": "blade", "tip_tint": Color("#ff8aa8"), "glow": Color("#ff9ad0") * 0.4, "tip_count": 4, "tip_size": 0.5, "trunk": 0.25, "sway": 0.25},
	"tube_sponge": {"h": 1.6, "r": 0.14, "depth": 1, "forks": 5, "spread": 0.45, "up": 0.6, "roots": 0, "bark": Color("#e0a040"),
		"tip": "bulb", "tip_tint": Color("#ffd27a"), "glow": Color("#7ff5ff") * 0.6, "tip_size": 0.3, "trunk": 0.3, "shrink": 1.0},
	# Aquora: mangroves on stilt roots at the water's edge, tall palms
	"mangrove": {"h": 7.0, "r": 0.22, "depth": 3, "forks": 3, "spread": 0.8, "up": 0.1, "roots": 9, "bark": Color("#5a4a3a"),
		"tip": "leaf", "tip_tint": Color("#3a8a4a"), "tip_count": 9, "tip_size": 0.9, "trunk": 0.35},
	"palm_hd": {"h": 12.0, "r": 0.28, "depth": 1, "forks": 7, "spread": 1.2, "up": -0.05, "droop": 0.5, "roots": 4, "bark": Color("#7a6a50"),
		"tip": "frond", "tip_tint": Color("#5aa83a"), "tip_count": 10, "tip_size": 1.6, "trunk": 0.85, "lean": 0.35, "shrink": 0.35, "sway": 0.2},
	# Verdis: dense jungle undergrowth
	"jungle_shrub": {"h": 2.6, "r": 0.08, "depth": 3, "forks": 3, "spread": 0.9, "up": 0.15, "droop": 0.1, "roots": 3, "bark": Color("#4a3a22"),
		"tip": "leaf", "tip_tint": Color("#2f7a2a"), "tip_count": 7, "tip_size": 0.7, "trunk": 0.3, "sway": 0.15},
	# Verdis savanna: thorn bushes, bare dead trees, candelabra succulents; tropics: palms
	"thorn_bush": {"h": 2.2, "r": 0.06, "depth": 3, "forks": 3, "spread": 1.0, "up": 0.05, "droop": 0.05, "roots": 3, "bark": Color("#5a4a3a"),
		"tip": "frond", "tip_tint": Color("#8aa83a"), "tip_count": 3, "tip_size": 0.6, "trunk": 0.2, "sway": 0.08},
	"dead_tree": {"h": 9.0, "r": 0.3, "depth": 3, "forks": 3, "spread": 0.8, "up": 0.15, "bend": 0.3, "roots": 4, "bark": Color("#8a8078"),
		"tip": "crystal", "tip_tint": Color("#8a8078"), "tip_count": 0, "tip_size": 0.1, "trunk": 0.45},
	"candelabra": {"h": 4.5, "r": 0.16, "depth": 1, "forks": 6, "spread": 0.3, "up": 1.0, "roots": 2, "bark": Color("#4a6a2a"),
		"tip": "bulb", "tip_tint": Color("#5a8a2a"), "glow": Color("#d6ff6b") * 0.25, "tip_size": 0.35, "trunk": 0.4, "shrink": 1.0},
	"tropic_palm": {"h": 13.0, "r": 0.26, "depth": 1, "forks": 8, "spread": 1.2, "up": -0.05, "droop": 0.5, "roots": 4, "bark": Color("#6a5a40"),
		"tip": "frond", "tip_tint": Color("#3f9a2a"), "tip_count": 10, "tip_size": 1.7, "trunk": 0.85, "lean": 0.3, "shrink": 0.35, "sway": 0.2},
	# Ferrum: charred ash trees, fat heat succulents with glowing pods
	"ash_tree": {"h": 7.5, "r": 0.3, "depth": 3, "forks": 2, "spread": 0.9, "up": 0.05, "bend": 0.35, "roots": 5, "bark": Color("#1e1a18"),
		"tip": "pod", "tip_tint": Color("#3a1a0a"), "glow": Color("#ff6a1a"), "tip_size": 0.45, "trunk": 0.5},
	"succulent": {"h": 1.4, "r": 0.16, "depth": 1, "forks": 5, "spread": 0.7, "up": 0.5, "roots": 3, "bark": Color("#5a4a2a"),
		"tip": "bulb", "tip_tint": Color("#8a6a2a"), "glow": Color("#ffb347") * 0.6, "tip_size": 0.6, "trunk": 0.2, "shrink": 1.0},
	# Voltara: conducting reed clumps and rod trees that collect charge
	"storm_reed": {"h": 2.8, "r": 0.05, "depth": 1, "forks": 6, "spread": 0.35, "up": 0.6, "roots": 2, "bark": Color("#3a3858"),
		"tip": "bulb", "tip_tint": Color("#9ff3ff"), "glow": Color("#9ff3ff"), "tip_size": 0.25, "trunk": 0.15, "shrink": 1.3},
	"rod_tree": {"h": 10.0, "r": 0.25, "depth": 2, "forks": 4, "spread": 0.5, "up": 0.5, "roots": 5, "bark": Color("#2a2a40"),
		"tip": "crystal", "tip_tint": Color("#6a5ad8"), "glow": Color("#c48bff"), "tip_count": 4, "tip_size": 1.0, "trunk": 0.6},
	# Solara: glass trees that grow crystals, mirror cacti
	"crystal_tree": {"h": 7.0, "r": 0.25, "depth": 3, "forks": 3, "spread": 0.6, "up": 0.35, "roots": 4, "bark": Color("#c8a070"),
		"tip": "crystal", "tip_tint": Color("#fff4d0"), "glow": Color("#ffd27a"), "tip_count": 5, "tip_size": 0.9, "trunk": 0.45},
	"sun_cactus": {"h": 3.0, "r": 0.3, "depth": 1, "forks": 3, "spread": 0.9, "up": 0.9, "roots": 0, "bark": Color("#c87a3a"),
		"tip": "bulb", "tip_tint": Color("#fff4d0"), "glow": Color("#ffffff") * 0.5, "tip_size": 0.35, "trunk": 0.6, "shrink": 0.6},
}
## Props that must not stand too close to each other (big ones)
const BIG := ["palm_tree", "acacia", "tropic_palm", "dead_tree", "frost_tree", "spore_tree", "mangrove", "palm_hd", "ash_tree", "rod_tree", "crystal_tree", "cliff", "cave",
	"glacier", "giant_mushroom", "jungle_tree", "jungle_tree_hd", "rock_arch", "metal_spire", "rock_spire", "light_pillar", "basalt"]


# ================================================================== helpers
static func std(col: Color, rough := 0.9, metal := 0.0, glow := Color.BLACK, energy := 1.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s|%.2f|%.2f" % [col.to_html(), rough, metal, glow.to_html(), energy, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col, alpha)
	m.roughness = rough
	m.metallic = metal
	if glow != Color.BLACK:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	elif glow == Color.BLACK:
		# fine surface detail and small bumps on every solid surface
		_ensure_detail()
		m.albedo_texture = _detail_tex
		m.normal_enabled = true
		m.normal_texture = _detail_nrm
		m.normal_scale = 0.6
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(1.4, 1.4, 1.4)
	_mats[key] = m
	return m


static func _noise_tex(freq: float, octaves: int, lo: float, hi: float, normal: bool, bump := 4.0, cellular := true) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR if cellular else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = bump
	else:
		var g := Gradient.new()
		g.set_color(0, Color(lo, lo, lo))
		g.set_color(1, Color(hi, hi, hi))
		t.color_ramp = g
	return t


static func _ensure_detail() -> void:
	if _detail_tex == null:
		_detail_tex = _noise_tex(0.02, 3, 0.8, 1.04, false)
		_detail_nrm = _noise_tex(0.02, 3, 0.0, 1.0, true, 3.0)
		_rock_tex = _noise_tex(0.012, 5, 0.55, 1.1, false, 0.0, false)
		_rock_nrm = _noise_tex(0.03, 4, 0.0, 1.0, true, 7.0)


## Rock material: layered grain, cracks and bumps (textures mapped from all sides)
static func rock_mat(col: Color, rough := 0.95, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [col.to_html(), rough, metal]
	if _rock_mats.has(key):
		return _rock_mats[key]
	_ensure_detail()
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.albedo_texture = _rock_tex
	m.normal_enabled = true
	m.normal_texture = _rock_nrm
	m.normal_scale = 1.0
	m.roughness = rough
	m.metallic = metal
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.9, 0.9, 0.9)
	_rock_mats[key] = m
	return m


## 12 different irregular rock shapes (noise-shaped spheres with a flat bottom and layers)
static var _pebble_meshes: Array = []


## Small low-poly stone (about 60 triangles) for gravel and pebbles - thousands are drawn
static func pebble_mesh(i: int) -> Mesh:
	if _pebble_meshes.is_empty():
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 1.1
		for v in 8:
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 8
			sm.rings = 5
			var arr := sm.get_mesh_arrays()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var off := Vector3(v * 5.3, v * 2.1, v * 3.7)
			var squash := 0.45 + 0.4 * fmod(v * 0.41, 1.0)
			for k in verts.size():
				var p := verts[k]
				p *= 1.0 + n.get_noise_3dv(p + off) * 0.4
				p.y *= squash
				if p.y < -0.2:
					p.y = -0.2 + (p.y + 0.2) * 0.3
				verts[k] = p
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = null
			arr[Mesh.ARRAY_TANGENT] = null
			var tmp := ArrayMesh.new()
			tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var st := SurfaceTool.new()
			st.create_from(tmp, 0)
			st.generate_normals()
			_pebble_meshes.append(st.commit())
	return _pebble_meshes[i % _pebble_meshes.size()]


static func rock_mesh(i: int) -> Mesh:
	if _rock_meshes.is_empty():
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_octaves = 4
		n.frequency = 0.9
		for v in 12:
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = 20
			sm.rings = 12
			var arr := sm.get_mesh_arrays()
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var off := Vector3(v * 7.3, v * 3.1, v * 5.7)
			var squash := 0.55 + 0.35 * fmod(v * 0.37, 1.0)
			for k in verts.size():
				var p := verts[k]
				var d := 1.0 + n.get_noise_3dv(p * 1.2 + off) * 0.45 + n.get_noise_3dv(p * 3.5 + off) * 0.12
				p *= d
				p.y *= squash
				if p.y < -0.25:
					p.y = -0.25 + (p.y + 0.25) * 0.25          # flat underside, sits on the ground
				p.y += sin(p.y * 14.0 + p.x * 2.0) * 0.015      # rock layers
				verts[k] = p
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = null
			arr[Mesh.ARRAY_TANGENT] = null
			var tmp := ArrayMesh.new()
			tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var st := SurfaceTool.new()
			st.create_from(tmp, 0)
			st.generate_normals()
			st.generate_tangents()
			_rock_meshes.append(st.commit())
	return _rock_meshes[i % _rock_meshes.size()]


static func sphere(r: float, seg := 10, rings := 6, hemi := false) -> SphereMesh:
	var key := "s%.2f|%d|%d|%s" % [r, seg, rings, hemi]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r if hemi else r * 2.0
		m.radial_segments = seg
		m.rings = rings
		m.is_hemisphere = hemi
		_meshes[key] = m
	return _meshes[key]


static func cyl(top: float, bottom: float, h: float, seg := 8) -> CylinderMesh:
	var key := "c%.2f|%.2f|%.2f|%d" % [top, bottom, h, seg]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = seg
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func box(s: Vector3) -> BoxMesh:
	var key := "b%s" % s
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = s
		_meshes[key] = m
	return _meshes[key]


static func torus(inner: float, outer: float, seg := 24) -> TorusMesh:
	var key := "t%.2f|%.2f|%d" % [inner, outer, seg]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = seg
		m.ring_segments = 8
		_meshes[key] = m
	return _meshes[key]


static func part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


## Solid obstacle the player bumps into (layer 1)
static func solid(parent: Node3D, shape: Shape3D, pos: Vector3, rot := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	cs.rotation = rot
	body.add_child(cs)
	parent.add_child(body)


static func solid_cyl(parent: Node3D, r: float, h: float, pos: Vector3) -> void:
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	solid(parent, s, pos)


static func solid_ball(parent: Node3D, r: float, pos: Vector3) -> void:
	var s := SphereShape3D.new()
	s.radius = r
	solid(parent, s, pos)


static func solid_box(parent: Node3D, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var s := BoxShape3D.new()
	s.size = size
	solid(parent, s, pos, rot)


static func vary(c: Color, rng: RandomNumberGenerator, amount := 0.12) -> Color:
	var k := rng.randf_range(-amount, amount)
	return c.lightened(k) if k > 0.0 else c.darkened(-k)


static func tilt(rng: RandomNumberGenerator, amount: float) -> Vector3:
	return Vector3(rng.randf_range(-amount, amount), rng.randf() * TAU, rng.randf_range(-amount, amount))


## Natural rock: one to three irregular stones with layers, cracks and bumps
static func rock(rng: RandomNumberGenerator, col: Color, size: float, rough := 0.95, metal := 0.0) -> Node3D:
	var n := Node3D.new()
	var mat := rock_mat(vary(col, rng, 0.08), rough, metal)
	for i in rng.randi_range(1, 3):
		var s := size * rng.randf_range(0.5, 1.0)
		var off := Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6)) * size if i > 0 else Vector3.ZERO
		var mi := MeshInstance3D.new()
		mi.mesh = rock_mesh(rng.randi())
		mi.material_override = mat
		mi.position = off + Vector3(0, s * 0.12, 0)
		mi.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
		mi.scale = Vector3(s * rng.randf_range(0.8, 1.3), s * rng.randf_range(0.7, 1.1), s * rng.randf_range(0.8, 1.3))
		n.add_child(mi)
	if size > 1.1:
		solid_ball(n, size * 0.75, Vector3(0, size * 0.2, 0))
	return n


## Cluster of pointed crystals
static func crystals(rng: RandomNumberGenerator, col: Color, glow: Color, energy: float, size: float, count: int, pulse := 0.0, alpha := 1.0) -> Node3D:
	var n := Node3D.new()
	var mat: Material
	if pulse > 0.0:
		mat = ExploreShaders.nature(col, glow, energy, 0.0, pulse, 0.15, 0.3)
	else:
		mat = std(col, 0.1, 0.3, glow, energy, alpha)
	for i in count:
		var h := size * rng.randf_range(0.5, 1.4)
		var r := h * rng.randf_range(0.12, 0.2)
		var off := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)) * size * 0.6 if i > 0 else Vector3.ZERO
		var rot := Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45)) if i > 0 else Vector3(0, rng.randf() * TAU, 0)
		var holder := Node3D.new()
		holder.position = off
		holder.rotation = rot
		n.add_child(holder)
		part(holder, cyl(r * 0.6, r, h * 0.75, 6), mat, Vector3(0, h * 0.375 - 0.1, 0))
		part(holder, cyl(0.0, r * 0.6, h * 0.25, 6), mat, Vector3(0, h * 0.875 - 0.1, 0))
	if size > 1.2:
		solid_cyl(n, size * 0.35, size, Vector3(0, size * 0.5, 0))
	return n


static func anim(n: Node3D, data: Dictionary) -> Node3D:
	n.set_meta("anim", data)
	return n


# ================================================================== props
static func make(kind: String, rng: RandomNumberGenerator, accent: Color) -> Node3D:
	match kind:
		# ---------------- Pebble
		"boulder":
			return rock(rng, Color("#6b625a"), rng.randf_range(0.5, 2.6))
		"pebbles":
			return rock(rng, Color("#7a7068"), rng.randf_range(0.12, 0.35))
		"debris":
			return _debris(rng)
		"mineral":
			return _columns(rng, Color("#3f7f86"), Color("#3fd6e0"), 0.6, rng.randf_range(1.2, 3.2), true)
		"floater_rock":
			var fr := rock(rng, Color("#857a70"), rng.randf_range(0.5, 1.4))
			var holder := Node3D.new()
			fr.position.y = rng.randf_range(1.6, 4.5)
			holder.add_child(fr)
			return anim(holder, {"type": "float", "node": fr, "speed": rng.randf_range(0.2, 0.6), "base": fr.position.y})
		# ---------------- Glacia
		"ice_spike":
			return crystals(rng, pick("ice", [Color("#bfe6ff")], rng), pick("glow", [Color("#5fb8ff")], rng), 0.3, rng.randf_range(1.2, 4.5), rng.randi_range(2, 5), 0.0, 0.82)
		"ice_arch":
			return _ice_arch(rng)
		"crystal_field":
			var cf := Node3D.new()
			for i in rng.randi_range(6, 12):
				var c := crystals(rng, pick("ice", [Color("#9a7ae8")], rng), pick("glow", [Color("#b07aff")], rng), 1.2, rng.randf_range(0.5, 2.2), rng.randi_range(2, 4), 0.5)
				c.position = Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
				cf.add_child(c)
			return cf
		"glow_ice":
			var gi := crystals(rng, pick("ice", [Color("#4fe0d0")], rng), pick("glow", [Color("#4ff2e0")], rng), 2.4, rng.randf_range(2.5, 5.5), rng.randi_range(3, 6), 0.35)
			return gi
		"frost_flower":
			return _frost_flower(rng)
		"frozen_fern":
			var ff := Node3D.new()
			var fm := MeshInstance3D.new()
			fm.mesh = Flora.fern_mesh(rng, Color(0.65, 0.85, 1.25))
			fm.scale = Vector3.ONE * rng.randf_range(0.8, 1.6)
			ff.add_child(fm)
			for i in 4:
				part(ff, cyl(0.0, 0.05, 0.25, 6), std(Color("#dff4ff"), 0.05, 0.2, Color("#7fd8ff"), 0.6, 0.85), Vector3(rng.randf_range(-0.4, 0.4), 0.3, rng.randf_range(-0.4, 0.4)), tilt(rng, 0.5))
			return ff
		"glacier":
			return _glacier(rng)
		"snow_rock":
			var sr := rock(rng, Color("#5f6f80"), rng.randf_range(0.6, 2.2))
			var cap_s := rng.randf_range(0.7, 1.6)
			part(sr, sphere(1.0, 10, 5, true), std(Color("#f6faff"), 0.6), Vector3(0, cap_s * 0.35, 0), Vector3.ZERO, Vector3(cap_s, cap_s * 0.35, cap_s))
			return sr
		# ---------------- Mycelia
		"giant_mushroom":
			return _mushroom(rng, rng.randf_range(4.0, 13.0))
		"tiered_cap":
			return _tiered(rng)
		"trumpet_fungus":
			return _trumpets(rng)
		"veil_fungus":
			var vf := _mushroom(rng, rng.randf_range(4.0, 8.0))
			_add_veil(vf, rng)
			return vf
		"puffball":
			return _puffballs(rng)
		"coral_fungus":
			return _coral_fungus(rng)
		"shelf_fungus":
			return _shelf(rng)
		"moss_mound":
			return _moss(rng)
		"small_mushrooms":
			var sm := Node3D.new()
			for i in rng.randi_range(3, 7):
				var m := _mushroom(rng, rng.randf_range(0.25, 0.8))
				m.position = Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
				sm.add_child(m)
			return sm
		"tube_coral":
			return _tubes(rng, [Color("#6a3f8a"), Color("#3a7f7a"), Color("#8a3f6a")][rng.randi() % 3], Color("#7dffcf"))
		"glow_bulb":
			return _bulb(rng, Color("#4a3a5a"), [Color("#7dffcf"), Color("#ff7de0"), Color("#9f8bff")][rng.randi() % 3], rng.randf_range(0.8, 2.4))
		# ---------------- Aquora
		"palm":
			return _palm(rng)
		"beach_rock":
			return rock(rng, Color("#6f6a62"), rng.randf_range(0.4, 2.0))
		"kelp":
			return _kelp(rng)
		"coral":
			return _coral(rng)
		# ---------------- Verdis
		"jungle_tree":
			return _jungle_tree(rng)
		"palm_tree", "tree_fern":
			var pr: Array = Flora.palm_tree(rng, pick("leaf", [Color(1.0, 1.1, 0.9)], rng)) if kind == "palm_tree" else Flora.tree_fern(rng, Color.WHITE)
			var pn: Node3D = pr[0]
			pn.set_meta("trunk_r", pr[1])
			return pn
		"acacia", "acacia_young":
			var ar: Array = Flora.acacia(rng, pick("leaf", [Color(1.1, 1.15, 0.85)], rng), kind == "acacia_young")
			var an: Node3D = ar[0]
			an.set_meta("trunk_r", ar[1])
			return an
		"termite_mound":
			return _termite_mound(rng)
		"lake_log", "driftwood":
			return _log(rng, kind == "lake_log")
		"mossy_rock":
			var mr := Node3D.new()
			for i in rng.randi_range(1, 3):
				var b2 := rock(rng, Color("#4a6a32").lerp(Color("#3a4a30"), rng.randf()), rng.randf_range(0.5, 1.6), 0.95)
				b2.position = Vector3(rng.randf_range(-1.0, 1.0), -0.15, rng.randf_range(-1.0, 1.0))
				mr.add_child(b2)
			return mr
		"bank_rock":
			var br := Node3D.new()
			for i in rng.randi_range(1, 3):
				var b := rock(rng, pick("rock", [Color("#4a4c48")], rng), rng.randf_range(0.35, 1.1), 0.8)
				b.position = Vector3(rng.randf_range(-0.8, 0.8), -0.1, rng.randf_range(-0.8, 0.8))
				br.add_child(b)
			return br
		"savanna_rock":
			var kop := Node3D.new()
			for i in rng.randi_range(2, 5):
				var b := rock(rng, pick("rock", [Color("#9a8a78")], rng), rng.randf_range(0.6, 2.4), 0.9)
				b.position = Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-2.0, 2.0))
				kop.add_child(b)
			return kop
		"jungle_tree_hd":
			var tr: Array = Flora.jungle_tree(rng, Color.WHITE)
			var tn: Node3D = tr[0]
			tn.set_meta("trunk_r", tr[1])
			return tn
		"fern":
			return _fern(rng, [Color("#2f7a2a"), Color("#4a9a2a"), Color("#2a6a4a")][rng.randi() % 3], rng.randf_range(0.6, 1.8))
		"vine_plant":
			return _pitcher(rng)
		"bulb_plant":
			return _bulb(rng, Color("#2f5a22"), [Color("#d6ff6b"), Color("#ff9a4a"), Color("#ff5fa8")][rng.randi() % 3], rng.randf_range(0.6, 1.6))
		"jungle_rock":
			var jr := rock(rng, Color("#4f5a48"), rng.randf_range(0.6, 2.2))
			var ms := rng.randf_range(0.6, 1.4)
			part(jr, sphere(1.0, 10, 5, true), std(Color("#3f7a2a"), 1.0), Vector3(0, ms * 0.3, 0), Vector3.ZERO, Vector3(ms, ms * 0.3, ms))
			return jr
		# ---------------- Ferrum
		"basalt":
			return _columns(rng, Color("#2a2423"), Color.BLACK, 0.0, rng.randf_range(2.0, 6.0), false)
		"metal_spire":
			return _spire(rng, Color("#3a3230"), rng.randf_range(6.0, 16.0), 0.6, Color("#ff5a1a"))
		"ore_deposit":
			var oc: Color = pick("ore", [Color("#c87533"), Color("#d4af37"), Color("#b8c4cc")], rng)
			var od := rock(rng, Color("#2e2624"), rng.randf_range(0.6, 1.4))
			var cr := crystals(rng, oc, oc.darkened(0.6), 0.4, rng.randf_range(0.6, 1.3), rng.randi_range(3, 6))
			for c in cr.get_children():
				var mi := c as Node3D
				if mi:
					for g in mi.get_children():
						var gm := g as MeshInstance3D
						if gm:
							gm.material_override = std(oc, 0.25, 0.9)
			od.add_child(cr)
			return od
		"geyser":
			return _geyser(rng)
		"dark_rock":
			return rock(rng, Color("#2c2830"), rng.randf_range(0.5, 2.4))
		# ---------------- Voltara
		"rock_arch":
			return _arch(rng)
		"rock_spire":
			return _spire(rng, Color("#3a3850"), rng.randf_range(5.0, 18.0), 0.0, Color.BLACK)
		"charged_crystal":
			var cc: Color = pick("glow", [Color("#9f7bff"), Color("#5fe8ff"), Color("#fff36b")], rng)
			return crystals(rng, cc.darkened(0.3), cc, 1.6, rng.randf_range(0.8, 2.6), rng.randi_range(3, 6), 0.8)
		# ---------------- Solara
		"sun_crystal":
			var sg := pick("glow", [Color("#ffd27a")], rng)
			return crystals(rng, sg.lerp(Color.WHITE, 0.6), sg, 1.3, rng.randf_range(1.2, 5.0), rng.randi_range(3, 7), 0.25)
		"glass_rock":
			return rock(rng, Color("#d89a40"), rng.randf_range(0.5, 2.2), 0.08, 0.6)
		"light_pillar":
			return _light_pillar(rng)
		"reef_rock":
			var rr := rock(rng, Color("#4a6a7a"), rng.randf_range(0.6, 2.0), 0.8)
			for i in rng.randi_range(2, 5):
				var cc := crystals(rng, [Color("#ff7a5a"), Color("#ffd27a"), Color("#c46fd8")][rng.randi() % 3], Color("#7ff5ff"), 0.4, rng.randf_range(0.2, 0.5), 3)
				cc.position = Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.3, 0.8), rng.randf_range(-0.6, 0.6))
				rr.add_child(cc)
			return rr
		"cliff":
			return _cliff(rng)
		"cave":
			return _cave(rng)
	if TREES.has(kind):
		var recipe: Dictionary = TREES[kind]
		var tree_c := recipe.duplicate()
		# colours follow the zone the plant grows in (if the planet has palettes)
		if palette.has("plant"):
			tree_c["tip_tint"] = pick("plant", [recipe["tip_tint"]], rng)
		if palette.has("glow") and recipe.has("glow"):
			tree_c["glow"] = pick("glow", [recipe["glow"]], rng) * 0.7
		tree_c["tip_tint"] = vary(Color(tree_c["tip_tint"]), rng, 0.08)
		var tree_res := Flora.branch_tree(rng, tree_c)
		var tree_n: Node3D = tree_res[0]
		tree_n.set_meta("trunk_r", float(tree_res[1]))
		return tree_n
	return rock(rng, Color.GRAY, 1.0)


## A fallen, water-worn tree trunk with a few broken-off branches (lying on a lake floor or a beach)
static func _log(rng: RandomNumberGenerator, sunken: bool) -> Node3D:
	var n := Node3D.new()
	var bk := Flora.bark_tinted(Color("#5a4e40") if sunken else Color("#9a8f80"))
	var l := rng.randf_range(1.6, 3.2)
	var r := rng.randf_range(0.11, 0.2)
	var a := Vector3(-l * 0.5, r * 0.7, 0)
	var b := Vector3(l * 0.5, r * 0.6, rng.randf_range(-0.3, 0.3))
	Flora._limb(n, a, b, r * 0.7, r, bk, 9)
	# the root end: a few thick stubs
	for i in 3:
		var ang := TAU * i / 3.0 + rng.randf() * 0.5
		Flora._limb(n, a, a + Vector3(-0.15, sin(ang) * 0.35, cos(ang) * 0.35), r * 0.25, r * 0.55, bk, 6)
	# broken branches
	for i in rng.randi_range(2, 4):
		var t := rng.randf_range(0.25, 0.85)
		var p := a.lerp(b, t)
		var dir := Vector3(rng.randf_range(0.1, 0.6), rng.randf_range(0.3, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		Flora._limb(n, p, p + dir * rng.randf_range(0.3, 0.7), r * 0.18, r * 0.4, bk, 6)
	n.set_meta("trunk_r", r)
	return n


## A termite mound: a lumpy reddish clay tower with a few chimneys
static func _termite_mound(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var col := vary(Color("#a8643a"), rng, 0.1)
	var mat := rock_mat(col, 0.98)
	var h := rng.randf_range(4.0, 9.0)
	var w := h * rng.randf_range(0.28, 0.4)
	part(n, sphere(1.0, 12, 8), mat, Vector3(0, w * 0.35, 0), Vector3.ZERO, Vector3(w, w * 0.6, w * 0.9))
	part(n, cyl(w * 0.18, w * 0.75, h * 0.8, 9), mat, Vector3(0, h * 0.42, 0), tilt(rng, 0.08))
	for i in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var ch := h * rng.randf_range(0.35, 0.65)
		part(n, cyl(w * 0.06, w * 0.3, ch, 7), mat, Vector3(cos(a) * w * 0.45, ch * 0.5, sin(a) * w * 0.45), Vector3(sin(a) * 0.2, 0, -cos(a) * 0.2))
	part(n, sphere(1.0, 8, 6), mat, Vector3(0, h * 0.84, 0), Vector3.ZERO, Vector3.ONE * w * 0.2)
	n.set_meta("trunk_r", w * 0.8)
	return n


## A cliff wall: big leaning slabs of layered rock in a curved row
static func _cliff(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var col := pick("rock", [Color("#6b625a")], rng)
	var count := rng.randi_range(4, 7)
	var bend := rng.randf_range(-0.25, 0.25)
	for i in count:
		var k := float(i) - count * 0.5
		var h := rng.randf_range(5.0, 11.0) * (1.0 - absf(k) / count * 0.6)
		var r := rock(rng, col, 1.0, 0.95)
		r.position = Vector3(k * 2.6, h * 0.35, k * k * bend)
		r.scale = Vector3(rng.randf_range(2.2, 3.2), h, rng.randf_range(2.0, 3.2))
		r.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.12, 0.12))
		n.add_child(r)
	# fallen blocks at the foot of the cliff
	for i in rng.randi_range(3, 6):
		var b := rock(rng, col.darkened(0.1), rng.randf_range(0.4, 1.3))
		b.position = Vector3(rng.randf_range(-count * 1.4, count * 1.4), 0, rng.randf_range(2.5, 5.0))
		n.add_child(b)
	n.set_meta("trunk_r", count * 1.2)
	return n


## A cave mouth: a hollow rock dome with a dark opening you can look into
static func _cave(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var col := pick("rock", [Color("#5a524a")], rng)
	var w := rng.randf_range(3.5, 5.5)
	# arch of rocks around the opening, and a big mound behind it
	for i in 9:
		var a := PI * i / 8.0
		var r := rock(rng, col, rng.randf_range(1.2, 2.0))
		r.position = Vector3(cos(a) * w, sin(a) * w * 0.8, 0)
		n.add_child(r)
	var mound := rock(rng, col.darkened(0.08), 1.0)
	mound.position = Vector3(0, w * 0.3, -w * 1.2)
	mound.scale = Vector3(w * 1.6, w * 1.1, w * 1.6)
	n.add_child(mound)
	# the darkness inside (and something glowing deep in it)
	part(n, sphere(1.0, 14, 8, true), std(Color(0.02, 0.02, 0.025), 1.0), Vector3(0, 0.0, -w * 0.4), Vector3(PI / 2, 0, 0), Vector3(w * 0.85, w * 1.0, w * 0.7))
	var gl := pick("glow", [Color("#7dffcf"), Color("#ffb347")], rng)
	for i in rng.randi_range(2, 5):
		part(n, sphere(0.12, 8, 4), std(gl, 0.4, 0.0, gl, 2.5), Vector3(rng.randf_range(-w * 0.4, w * 0.4), rng.randf_range(0.2, w * 0.5), -w * rng.randf_range(0.5, 0.9)))
	n.set_meta("trunk_r", w * 1.1)
	return n


# ================================================================== builders
static func _debris(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var metal: Color = [Color("#7a7f88"), Color("#8a5a3a"), Color("#b08a4a")][rng.randi() % 3]
	var mat := std(metal, 0.45, 0.85)
	match rng.randi() % 3:
		0:   # girder
			var l := rng.randf_range(2.0, 5.0)
			part(n, box(Vector3(l, 0.25, 0.4)), mat, Vector3(0, 0.15, 0), Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(0.1, 0.5)))
			solid_box(n, Vector3(l, 0.5, 0.5), Vector3(0, 0.2, 0))
		1:   # pipe with brass rings
			var p := Node3D.new()
			p.rotation = Vector3(PI / 2 - 0.25, rng.randf() * TAU, 0)
			p.position.y = 0.3
			n.add_child(p)
			part(p, cyl(0.35, 0.35, 2.6, 12), mat, Vector3.ZERO)
			for k in 2:
				part(p, torus(0.33, 0.45), std(Color("#c79a4a"), 0.3, 1.0), Vector3(0, -0.9 + k * 1.8, 0))
			solid_ball(n, 0.6, Vector3(0, 0.3, 0))
		2:   # hull plate with rivets
			var plate := Node3D.new()
			plate.rotation = tilt(rng, 0.6)
			plate.position.y = 0.2
			n.add_child(plate)
			part(plate, box(Vector3(1.8, 0.08, 1.2)), mat, Vector3.ZERO)
			for k in 5:
				part(plate, sphere(0.05, 6, 3), std(Color("#c79a4a"), 0.3, 1.0), Vector3(-0.8 + k * 0.4, 0.05, 0.5))
	return n


static func _columns(rng: RandomNumberGenerator, col: Color, glow: Color, energy: float, h: float, shiny: bool) -> Node3D:
	var n := Node3D.new()
	var mat := std(vary(col, rng, 0.08), 0.3 if shiny else 0.9, 0.5 if shiny else 0.0, glow, energy)
	var count := rng.randi_range(4, 9)
	for i in count:
		var a := TAU * i / count + rng.randf() * 0.4
		var d := 0.0 if i == 0 else rng.randf_range(0.4, 1.1)
		var hh := h * (1.0 if i == 0 else rng.randf_range(0.35, 0.85))
		var r := rng.randf_range(0.28, 0.45)
		part(n, cyl(r, r, hh, 6), mat, Vector3(cos(a) * d, hh * 0.5 - 0.2, sin(a) * d), Vector3(rng.randf_range(-0.08, 0.08), rng.randf(), 0))
	solid_cyl(n, 1.1, h, Vector3(0, h * 0.5, 0))
	return n


static func _glacier(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var ice := std(Color("#9fd2f5"), 0.08, 0.15, Color("#3f8fd0"), 0.15, 0.9)
	var snow := std(Color("#f8fbff"), 0.7)
	var s := Vector3(rng.randf_range(10, 22), rng.randf_range(5, 11), rng.randf_range(6, 11))
	var rot := Vector3(rng.randf_range(-0.1, 0.1), rng.randf() * TAU, rng.randf_range(-0.12, 0.12))
	part(n, box(s), ice, Vector3(0, s.y * 0.4, 0), rot)
	part(n, box(Vector3(s.x * 1.02, 0.6, s.z * 1.02)), snow, Vector3(0, s.y * 0.9, 0), rot)
	# broken pieces at the foot
	for i in 4:
		var p := Vector3(rng.randf_range(-0.6, 0.6) * s.x, 0.3, rng.randf_range(0.55, 0.8) * s.z * (1 if rng.randf() < 0.5 else -1)).rotated(Vector3.UP, rot.y)
		part(n, box(Vector3.ONE * rng.randf_range(0.8, 2.0)), ice, p, tilt(rng, 0.6))
	solid_box(n, s, Vector3(0, s.y * 0.4, 0), rot)
	return n


static func _mushroom(rng: RandomNumberGenerator, h: float) -> Node3D:
	var n := Node3D.new()
	var cap_col: Color = vary(pick("caps", [Color("#7a3fa0"), Color("#b0407a"), Color("#2f8a80"), Color("#5a3fb0")], rng), rng, 0.1)
	var glow: Color = pick("glow", [Color("#7dffcf"), Color("#ff7de0"), Color("#9fd0ff")], rng)
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
	var stem_r := maxf(0.06, h * 0.07)
	var holder := Node3D.new()
	holder.rotation = lean
	n.add_child(holder)
	part(holder, cyl(stem_r * 0.8, stem_r * 1.3, h, 10), std(Color("#d8ccc0").darkened(0.15), 0.8), Vector3(0, h * 0.5, 0))
	var cr := h * rng.randf_range(0.35, 0.55)
	part(holder, sphere(1.0, 16, 8, true), ExploreShaders.nature(cap_col, cap_col.lightened(0.2), 0.15, 0.0, 0.0, 0.6),
		Vector3(0, h - cr * 0.08, 0), Vector3.ZERO, Vector3(cr, cr * 0.55, cr))
	part(holder, cyl(cr * 0.95, cr * 0.5, cr * 0.08, 16), ExploreShaders.nature(cap_col.darkened(0.5), glow, 1.6, 0.0, 0.5),
		Vector3(0, h - cr * 0.1, 0))
	for i in rng.randi_range(3, 8):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.2, 0.8)
		var p := Vector3(cos(a) * d * cr, 0.0, sin(a) * d * cr)
		p.y = h - cr * 0.08 + cr * 0.55 * sqrt(maxf(0.0, 1.0 - d * d)) - 0.02
		part(holder, sphere(cr * 0.09, 8, 4), std(glow.lightened(0.3), 0.5, 0.0, glow, 1.4), p)
	if h > 2.0:
		solid_cyl(n, stem_r * 1.4, h, Vector3(0, h * 0.5, 0))
	return n


static func _tubes(rng: RandomNumberGenerator, col: Color, glow: Color) -> Node3D:
	var n := Node3D.new()
	for i in rng.randi_range(3, 7):
		var h := rng.randf_range(0.8, 3.2)
		var r := rng.randf_range(0.12, 0.3)
		var p := Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.7, 0.7))
		var t := Node3D.new()
		t.position = p
		t.rotation = Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		n.add_child(t)
		part(t, cyl(r, r * 0.8, h, 10), ExploreShaders.nature(vary(col, rng), Color.BLACK, 1.0, 0.03, 0.0, 0.7), Vector3(0, h * 0.5, 0))
		part(t, torus(r * 0.75, r * 1.05, 12), ExploreShaders.nature(glow, glow, 1.5, 0.03, 0.6), Vector3(0, h, 0))
	return n


static func _bulb(rng: RandomNumberGenerator, stalk: Color, glow: Color, h: float) -> Node3D:
	var n := Node3D.new()
	var sway := 0.05
	part(n, cyl(0.03, 0.06, h, 6), ExploreShaders.nature(stalk, Color.BLACK, 1.0, sway), Vector3(0, h * 0.5, 0))
	part(n, sphere(0.16 * h / 1.5 + 0.08, 12, 6), ExploreShaders.nature(glow, glow, 2.0, sway, 0.6, 0.3), Vector3(0, h, 0))
	for i in 2:
		part(n, sphere(0.25, 8, 4), ExploreShaders.nature(stalk.lightened(0.15), Color.BLACK, 1.0, sway * 0.5),
			Vector3((i * 2 - 1) * 0.15, h * 0.3, 0), Vector3(0, 0, (i * 2 - 1) * 0.8), Vector3(1.0, 0.15, 0.45))
	return n


static func _palm(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var h := rng.randf_range(5.0, 9.0)
	var lean := rng.randf_range(0.1, 0.35)
	var dir := rng.randf() * TAU
	var bark := std(Color("#8a6a48"), 0.9)
	var segs := 6
	var top := Vector3.ZERO
	for i in segs:
		var t0 := float(i) / segs
		var p := Vector3(sin(dir), 0, cos(dir)) * lean * h * t0 * t0 + Vector3(0, h * t0, 0)
		part(n, cyl(0.17, 0.22, h / segs + 0.1, 8), bark, p + Vector3(0, h / segs * 0.5, 0), Vector3(cos(dir) * lean * t0 * 1.6, 0, -sin(dir) * lean * t0 * 1.6))
		top = p + Vector3(0, h / segs, 0)
	var leaf := ExploreShaders.nature(Color("#3f8a3a"), Color.BLACK, 1.0, 0.12, 0.0, 0.7)
	for i in 8:
		var a := TAU * i / 8.0 + rng.randf() * 0.3
		var holder := Node3D.new()
		holder.position = top
		holder.rotation = Vector3(0, a, 0)
		n.add_child(holder)
		part(holder, box(Vector3(0.5, 0.04, 3.2)), leaf, Vector3(0, -0.4, 1.4), Vector3(0.45, 0, 0))
	part(n, sphere(0.35, 8, 5), std(Color("#5a4028")), top + Vector3(0, -0.2, 0))
	solid_cyl(n, 0.3, h, Vector3(0, h * 0.5, 0))
	return n


static func _kelp(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var mat := ExploreShaders.nature(Color("#4a6a2a"), Color("#1a3a10"), 0.4, 0.15, 0.0, 0.8)
	for i in rng.randi_range(2, 5):
		var h := rng.randf_range(2.0, 6.0)
		part(n, box(Vector3(0.25, h, 0.04)), mat, Vector3(rng.randf_range(-0.5, 0.5), h * 0.5, rng.randf_range(-0.5, 0.5)), Vector3(0, rng.randf() * TAU, 0))
	return n


static func _coral(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var col: Color = [Color("#ff6f7d"), Color("#ffb34a"), Color("#c46fff"), Color("#4af0d0")][rng.randi() % 4]
	var mat := ExploreShaders.nature(col, col, 0.35, 0.02, 0.4, 0.6)
	for i in rng.randi_range(4, 9):
		var h := rng.randf_range(0.3, 1.2)
		var t := Node3D.new()
		t.position = Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
		t.rotation = Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		n.add_child(t)
		part(t, cyl(0.06, 0.1, h, 6), mat, Vector3(0, h * 0.5, 0))
		part(t, sphere(0.12, 8, 4), mat, Vector3(0, h, 0))
	return n


static func _jungle_tree(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var h := rng.randf_range(15.0, 28.0)
	var r := rng.randf_range(0.8, 1.6)
	var bark := std(Color("#5a4632"), 0.95)
	part(n, cyl(r * 0.55, r, h, 12), bark, Vector3(0, h * 0.5, 0))
	for i in 5:   # buttress roots
		var a := TAU * i / 5.0 + rng.randf() * 0.4
		part(n, cyl(0.15, r * 0.55, 3.2, 6), bark, Vector3(cos(a) * r * 1.1, 1.0, sin(a) * r * 1.1), Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5))
	var greens: Array = [Color("#2d6a24"), Color("#3c8a2c"), Color("#25582a")]
	for i in rng.randi_range(4, 7):
		var cr := rng.randf_range(3.5, 7.0)
		var p := Vector3(rng.randf_range(-4, 4), h + rng.randf_range(-3.0, 1.5), rng.randf_range(-4, 4))
		var g: Color = greens[rng.randi() % greens.size()]
		part(n, sphere(1.0, 12, 7), ExploreShaders.nature(g, Color.BLACK, 1.0, 0.08, 0.0, 0.85), p, Vector3.ZERO, Vector3(cr, cr * 0.6, cr))
	var vine := ExploreShaders.nature(Color("#3f6a2a"), Color.BLACK, 1.0, 0.25, 0.0, 0.8)
	for i in rng.randi_range(3, 7):
		var l := rng.randf_range(5.0, 13.0)
		var a := rng.randf() * TAU
		var d := rng.randf_range(2.0, 5.0)
		part(n, cyl(0.05, 0.05, l, 5), vine, Vector3(cos(a) * d, h - 2.0 - l * 0.5, sin(a) * d))
	solid_cyl(n, r, h, Vector3(0, h * 0.5, 0))
	return n


static func _fern(rng: RandomNumberGenerator, col: Color, size: float) -> Node3D:
	var n := Node3D.new()
	var mat := ExploreShaders.nature(col, Color.BLACK, 1.0, 0.07, 0.0, 0.8)
	var count := rng.randi_range(5, 9)
	for i in count:
		var holder := Node3D.new()
		holder.rotation = Vector3(0, TAU * i / count + rng.randf() * 0.3, 0)
		n.add_child(holder)
		part(holder, sphere(1.0, 8, 4), mat, Vector3(0, size * 0.35, size * 0.55), Vector3(-0.6, 0, 0), Vector3(size * 0.18, size * 0.04, size * 0.6))
	return n


static func _pitcher(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var h := rng.randf_range(0.8, 1.8)
	part(n, cyl(0.35, 0.15, h, 12), ExploreShaders.nature(Color("#7a2a4a"), Color.BLACK, 1.0, 0.03, 0.0, 0.6), Vector3(0, h * 0.5, 0))
	part(n, cyl(0.3, 0.3, 0.05, 12), ExploreShaders.nature(Color("#d6ff6b"), Color("#b6ff4b"), 1.2, 0.03, 0.4), Vector3(0, h - 0.1, 0))
	part(n, torus(0.3, 0.42, 16), ExploreShaders.nature(Color("#a03a6a"), Color.BLACK, 1.0, 0.03), Vector3(0, h, 0))
	n.add_child(_fern(rng, Color("#2f6a2a"), 0.8))
	return n


static func _spire(rng: RandomNumberGenerator, col: Color, h: float, metal: float, crack: Color) -> Node3D:
	var n := Node3D.new()
	var mat := std(vary(col, rng, 0.08), 0.6 if metal > 0.0 else 0.95, metal)
	var parts := rng.randi_range(3, 5)
	var y := 0.0
	var r := rng.randf_range(1.0, 2.0)
	for i in parts:
		var ph := h / parts * rng.randf_range(0.9, 1.3)
		part(n, cyl(r * 0.7, r, ph, 7), mat, Vector3(rng.randf_range(-0.2, 0.2), y + ph * 0.5, rng.randf_range(-0.2, 0.2)), Vector3(rng.randf_range(-0.08, 0.08), rng.randf(), rng.randf_range(-0.08, 0.08)))
		if crack != Color.BLACK and i < parts - 1:
			part(n, torus(r * 0.72, r * 0.8, 14), std(crack, 0.5, 0.0, crack, 2.2), Vector3(0, y + ph, 0))
		y += ph * 0.92
		r *= 0.72
	part(n, cyl(0.0, r, h * 0.15, 7), mat, Vector3(0, y + h * 0.07, 0))
	solid_cyl(n, maxf(0.6, r * 2.5), y, Vector3(0, y * 0.5, 0))
	return n


static func _geyser(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	part(n, cyl(0.6, 1.8, 1.2, 10), std(Color("#4a3a30"), 0.9), Vector3(0, 0.4, 0))
	part(n, cyl(0.55, 0.55, 0.05, 10), std(Color("#ff7a2a"), 0.5, 0.0, Color("#ff5a10"), 3.0), Vector3(0, 1.0, 0))
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 2.6
	p.emitting = false
	p.local_coords = false
	p.position = Vector3(0, 1.0, 0)
	p.direction = Vector3.UP
	p.spread = 9.0
	p.initial_velocity_min = 7.0
	p.initial_velocity_max = 11.0
	p.gravity = Vector3(0, -3.0, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curve
	p.mesh = Particles.soft_quad(0.9)
	p.material_override = Particles.material(Color(1, 1, 1, 0.35), false)
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.7, 0.5))
	g.set_color(1, Color(0.6, 0.55, 0.5, 0.0))
	p.color_ramp = g
	n.add_child(p)
	solid_cyl(n, 1.4, 1.2, Vector3(0, 0.5, 0))
	return anim(n, {"type": "geyser", "particles": p, "period": rng.randf_range(7.0, 13.0), "phase": rng.randf() * 10.0})


static func _arch(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var mat := std(Color("#3f3c56"), 0.95)
	var w := rng.randf_range(6.0, 12.0)
	var h := rng.randf_range(7.0, 13.0)
	for s: float in [-1.0, 1.0]:
		part(n, cyl(1.0, 1.6, h, 8), mat, Vector3(s * w * 0.5, h * 0.5, 0), Vector3(0, 0, -s * 0.08))
		solid_cyl(n, 1.4, h, Vector3(s * w * 0.5, h * 0.5, 0))
	part(n, box(Vector3(w + 2.5, 1.8, 2.2)), mat, Vector3(0, h + 0.3, 0), Vector3(0, 0, rng.randf_range(-0.06, 0.06)))
	n.rotation.y = rng.randf() * TAU
	return n


static func _light_pillar(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var h := rng.randf_range(6.0, 12.0)
	part(n, cyl(0.4, 0.8, h, 6), std(Color("#fff6dc"), 0.05, 0.2, Color("#ffd27a"), 1.8, 0.85), Vector3(0, h * 0.5, 0))
	part(n, cyl(0.6, 0.6, 40.0, 12), ExploreShaders.material("holo", {"color": Color(1.0, 0.9, 0.6, 0.25), "stripes": 6.0}), Vector3(0, h + 20.0, 0))
	solid_cyl(n, 0.8, h, Vector3(0, h * 0.5, 0))
	return n


# ---------------------------------------------------------------- Mycelia fungi
static func _cap_colors(rng: RandomNumberGenerator) -> Array:
	return [vary(pick("caps", [Color("#7a3fa0"), Color("#2f8a80")], rng), rng, 0.1), pick("glow", [Color("#7dffcf"), Color("#ff7de0")], rng)]


## Several caps stacked on one stem like a pagoda
static func _tiered(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var cc := _cap_colors(rng)
	var h := rng.randf_range(5.0, 11.0)
	part(n, cyl(0.25, 0.5, h, 10), std(Color("#d8ccc0").darkened(0.2), 0.8), Vector3(0, h * 0.5, 0))
	var tiers := rng.randi_range(3, 4)
	for i in tiers:
		var y := h * (0.45 + 0.55 * float(i) / (tiers - 1))
		var r := h * 0.32 * (1.0 - float(i) / tiers * 0.6)
		var cap: Color = Color(cc[0]).lerp(cc[1], float(i) / tiers * 0.4)
		part(n, sphere(1.0, 16, 6, true), ExploreShaders.nature(cap, cap, 0.12, 0.0, 0.0, 0.55), Vector3(0, y, 0), Vector3.ZERO, Vector3(r, r * 0.3, r))
		part(n, torus(r * 0.95, r * 1.02, 24), ExploreShaders.nature(cc[1], cc[1], 2.0, 0.0, 0.6), Vector3(0, y + 0.02, 0))
	solid_cyl(n, 0.6, h, Vector3(0, h * 0.5, 0))
	return n


## Trumpet-shaped fungi in a cluster, glowing inside
static func _trumpets(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var cc := _cap_colors(rng)
	for i in rng.randi_range(2, 5):
		var h := rng.randf_range(1.5, 5.0)
		var t := Node3D.new()
		t.position = Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
		t.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		n.add_child(t)
		part(t, cyl(h * 0.28, h * 0.05, h, 14), ExploreShaders.nature(vary(cc[0], rng), Color(cc[0]).lightened(0.2), 0.15, 0.03, 0.0, 0.5), Vector3(0, h * 0.5, 0))
		part(t, cyl(h * 0.26, h * 0.26, 0.04, 14), ExploreShaders.nature(cc[1], cc[1], 2.2, 0.03, 0.7), Vector3(0, h * 0.97, 0))
	solid_cyl(n, 1.0, 3.0, Vector3(0, 1.5, 0))
	return n


## Glowing threads hanging from the rim of a cap
static func _add_veil(n: Node3D, rng: RandomNumberGenerator) -> void:
	var holder := n.get_child(0) as Node3D
	if holder == null:
		return
	var top := 0.0
	var r := 1.5
	for c in holder.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.scale.x > r:
			r = mi.scale.x
			top = mi.position.y
	if top < 0.2:
		return                       # (no cap found: no veil - a zero-length thread breaks the mesh)
	var glow := pick("glow", [Color("#4ff2ff")], rng)
	var mat := ExploreShaders.nature(glow, glow, 1.6, 0.06, 0.5)
	for i in 22:
		var a := TAU * i / 22.0
		var l := rng.randf_range(top * 0.3, top * 0.8)
		part(holder, cyl(0.015, 0.02, l, 4), mat, Vector3(cos(a) * r * 0.92, top - l * 0.5, sin(a) * r * 0.92))


static func _puffballs(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var cc := _cap_colors(rng)
	for i in rng.randi_range(2, 5):
		var r := rng.randf_range(0.3, 1.2)
		var p := Vector3(rng.randf_range(-1.0, 1.0), r * 0.85, rng.randf_range(-1.0, 1.0))
		part(n, sphere(1.0, 16, 10), ExploreShaders.nature(Color(cc[0]).lightened(0.25), cc[1], 0.25, 0.0, 0.3, 0.7), p, Vector3.ZERO, Vector3(r, r * 0.9, r))
		for k in 6:
			var d := Vector3(rng.randfn(), absf(rng.randfn()), rng.randfn()).normalized()
			part(n, sphere(r * 0.08, 6, 3), std(cc[1], 0.4, 0.0, cc[1], 2.0), p + d * r * 0.95)
	return n


## Branching coral-like fungus with glowing tips
static func _coral_fungus(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var cc := _cap_colors(rng)
	var body := ExploreShaders.nature(vary(cc[0], rng).lightened(0.1), Color.BLACK, 1.0, 0.02, 0.0, 0.6)
	var tip := std(cc[1], 0.4, 0.0, cc[1], 2.5)
	for i in rng.randi_range(4, 7):
		var h := rng.randf_range(0.8, 2.0)
		var b := Node3D.new()
		b.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
		n.add_child(b)
		part(b, cyl(0.05, 0.12, h, 6), body, Vector3(0, h * 0.5, 0))
		for k in 3:
			var c := Node3D.new()
			c.position = Vector3(0, h * rng.randf_range(0.5, 0.95), 0)
			c.rotation = Vector3(rng.randf_range(-0.9, 0.9), rng.randf() * TAU, 0)
			b.add_child(c)
			var l := h * rng.randf_range(0.3, 0.6)
			part(c, cyl(0.02, 0.05, l, 5), body, Vector3(0, l * 0.5, 0))
			part(c, sphere(0.06, 6, 3), tip, Vector3(0, l, 0))
	return n


## Bracket fungi growing out of the side of a rock
static func _shelf(rng: RandomNumberGenerator) -> Node3D:
	var n := rock(rng, Color("#3a2e3a"), rng.randf_range(0.9, 1.6))
	var cc := _cap_colors(rng)
	for i in rng.randi_range(4, 8):
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.3, 1.2)
		var r := rng.randf_range(0.3, 0.7)
		part(n, sphere(1.0, 14, 5, true), ExploreShaders.nature(vary(cc[0], rng), cc[1], 0.3, 0.0, 0.4, 0.6),
			Vector3(cos(a) * 0.9, y, sin(a) * 0.9), Vector3(0, -a, 0), Vector3(r, r * 0.25, r * 0.7))
	return n


## Soft mound of moss with tiny lights
static func _moss(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var cc := _cap_colors(rng)
	var mc: Color = Color(cc[0]).darkened(0.35)
	for i in rng.randi_range(2, 4):
		var r := rng.randf_range(0.6, 1.6)
		part(n, sphere(1.0, 14, 6, true), rock_mat(mc, 1.0), Vector3(rng.randf_range(-0.8, 0.8), -0.05, rng.randf_range(-0.8, 0.8)), Vector3.ZERO, Vector3(r, r * 0.4, r))
	for i in 10:
		part(n, sphere(0.04, 5, 3), std(cc[1], 0.4, 0.0, cc[1], 2.5), Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.1, 0.5), rng.randf_range(-1.2, 1.2)))
	return n


# ---------------------------------------------------------------- Glacia ice
## An arch of coloured ice - a small ice cave you can walk through
static func _ice_arch(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var ic := pick("ice", [Color("#3f7fe0")], rng)
	var mat := std(ic, 0.05, 0.25, pick("glow", [Color("#3f8fff")], rng), 0.35, 0.85)
	var w := rng.randf_range(6.0, 10.0)
	var h := rng.randf_range(4.0, 7.0)
	for sx: float in [-1.0, 1.0]:
		part(n, cyl(1.0, 1.8, h, 7), mat, Vector3(sx * w * 0.5, h * 0.5, 0), Vector3(0, rng.randf(), -sx * 0.12))
		solid_cyl(n, 1.5, h, Vector3(sx * w * 0.5, h * 0.5, 0))
	for i in 7:
		var a := PI * i / 6.0
		part(n, sphere(1.0, 10, 6), mat, Vector3(-cos(a) * w * 0.5, h + sin(a) * h * 0.35, 0), Vector3(0, 0, a), Vector3(1.6, 1.0, 1.8))
	# icicles
	for i in 8:
		part(n, cyl(0.12, 0.0, rng.randf_range(0.6, 1.6), 6), mat, Vector3(rng.randf_range(-w * 0.35, w * 0.35), h - 0.4, rng.randf_range(-0.8, 0.8)), Vector3(PI, 0, 0))
	return n


## A flower of thin ice petals
static func _frost_flower(rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var ic := pick("ice", [Color("#c0a0ff")], rng)
	var gl := pick("glow", [Color("#b07aff")], rng)
	var h := rng.randf_range(0.3, 0.8)
	part(n, cyl(0.02, 0.03, h, 5), std(Color("#dff4ff"), 0.1, 0.2), Vector3(0, h * 0.5, 0))
	for i in 7:
		var a := TAU * i / 7.0
		var p := Node3D.new()
		p.position = Vector3(0, h, 0)
		p.rotation = Vector3(0, a, 0)
		n.add_child(p)
		part(p, cyl(0.0, 0.05, 0.35, 4), std(ic, 0.05, 0.2, gl, 0.8, 0.8), Vector3(0, 0.1, 0.15), Vector3(1.0, 0, 0))
	part(n, sphere(0.05, 8, 4), std(gl, 0.3, 0.0, gl, 3.0), Vector3(0, h + 0.03, 0))
	return n
