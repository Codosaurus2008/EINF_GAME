class_name CreatureForge
extends RefCounted
## Builds a 3D creature from its elements (1-4), an individual seed (the unit id), Umbra or not,
## and its tier. No fixed models: a creature is assembled from anatomy parts.
##
## 1. One element is the "frame": posture, body proportions and legs.
## 2. The other body parts (head, back, tail, arms) are shared out between the elements:
##    each element takes the part it is best at (CreatureLook "slot_love").
## 3. Every element also "infuses" its features all over the body: scrap plates and rivets
##    (Pebble), frost crystals and an ice shell (Glacia), little fungi and spore pores (Mycelia),
##    gills and fin frills (Aquora), thorns and leaves (Verdis), iron bands with glowing seams and
##    a furnace (Ferrum), copper coils and conductive lines with lightning (Voltara), light organs
##    and crystal facets (Solara).
## 4. Skin: base colour from the frame element, pattern / markings / glow from the second element,
##    rim light from the third. Every part keeps the material of the element that made it.
## 5. The seed varies proportions, numbers of horns / eyes / spines / toes, colours, asymmetry.

const SLOTS := ["head", "back", "tail", "arms"]
## neck direction and length, head size (relative to the chest) of each head style's people
const NECKS := {
	"pebble": [Vector3(0, 0.25, 1), 0.16, 0.78], "glacia": [Vector3(0, 0.95, 0.45), 0.42, 0.62],
	"mycelia": [Vector3(0, 0.25, 1), 0.07, 0.82], "aquora": [Vector3(0, 0.02, 1), 0.06, 0.95],
	"verdis": [Vector3(0, 0.35, 1), 0.26, 0.62], "ferrum": [Vector3(0, 0.7, 0.5), 0.1, 0.5],
	"voltara": [Vector3(0, 0.45, 1), 0.3, 0.6], "solara": [Vector3(0, 0.9, 0.35), 0.24, 0.62],
}

var m: CreatureModel
var els: Array = []
var dom := ""
var accent := ""
var third := ""
var owner := {}
var rng := RandomNumberGenerator.new()
var umbra := false
var tier := 0
var f := {}                 # frame numbers
var mats := {}
var centre := Vector3.ZERO  # body pivot (model space)
var sp_start := Vector3.ZERO
var sp_dir := Vector3.FORWARD
var sp_up := Vector3.UP
var body_mat: ShaderMaterial
var design := {}
var seed_used := 0
var ow := 0.012               # outline width


## The public entry: a finished, animated creature
static func build(elements: Array, seed_value: int, is_umbra := false, tier_value := 0) -> CreatureModel:
	var fo := CreatureForge.new()
	return fo._build(elements, seed_value, is_umbra, tier_value)


func _build(elements: Array, seed_value: int, is_umbra: bool, tier_value: int) -> CreatureModel:
	els = elements.duplicate()
	if els.is_empty():
		els = ["pebble"]
	umbra = is_umbra
	tier = tier_value
	seed_used = seed_value
	rng.seed = seed_value * 104729 + hash(str(els)) + 3
	m = CreatureModel.new()
	m.elements = els
	m.name = "Creature%d" % seed_value
	_assign()
	_frame()
	_torso()
	_legs()
	_neck_head()
	_back()
	_tail()
	_arms()
	for e: String in els:
		_infuse(e)
	if tier >= 1:
		_tier_marks()
	for e: String in els:
		_fx(e)
	m.size = maxf(float(f["hip_h"]) + float(f["chest"]) * 1.6, 0.8)
	_merge_static(m)
	return m


# ================================================================== who builds which part
func _assign() -> void:
	design = CreatureLook.design(els, seed_used)
	dom = design["dom"]
	accent = design["accent"]
	third = design["third"]
	owner = design["owner"]


func _k(e: String) -> Dictionary:
	return CreatureLook.kit(e)


# ================================================================== materials
func _skin_of(e: String, kind := "skin") -> ShaderMaterial:
	var key := e + "|" + kind
	if not mats.has(key):
		var role := "fin" if kind in ["membrane", "skin_2side"] else "armor"
		var c := CreatureLook.pal(e, role)
		if umbra:
			c = c.lerp(CreatureLook.UMBRA_SKIN, 0.55)
		var sm := CreatureLook.part(c, c.lightened(0.3), e, umbra, rng, kind, ow)
		if kind == "skin_clear" or kind == "membrane":
			sm.set_shader_parameter("alpha", 0.55 if kind == "skin_clear" else 0.6)
			sm.set_shader_parameter("mark_glow", 1.2)
		mats[key] = sm
		m.skin_mats.append(sm)
	return mats[key]


## Material of a body region of this creature (head, limb, horn ...), coloured by the element
## that owns that region
func _role(role: String) -> ShaderMaterial:
	var key := "role|" + role
	if not mats.has(key):
		var c := CreatureLook.region(design, role, umbra)
		var e: String = dom
		match role:
			"head": e = owner["head"]
			"limb": e = accent
			"horn": e = third if els.size() >= 3 else str(owner["head"])
		var sec := c.lightened(0.28)
		if role == "head":
			sec = CreatureLook.region(design, "belly", umbra)
		var sm := CreatureLook.part(c, sec, e, umbra, rng, "skin", ow)
		mats[key] = sm
		m.skin_mats.append(sm)
	return mats[key]


func _metal(e: String, which := "metal") -> ShaderMaterial:
	var key := e + "|" + which
	if not mats.has(key):
		var mm := CreatureLook.metal(_k(e), which, umbra)
		mats[key] = mm
		m.skin_mats.append(mm)
	return mats[key]


func _glow(e: String, energy := 2.2, pulse := 0.3, flicker := 0.0, glass := 0.0, col := Color(0, 0, 0, 0)) -> ShaderMaterial:
	var c: Color = col if col.a > 0.0 else Color(_k(e)["glow"])
	if umbra:
		c = CreatureLook.UMBRA_GLOW
	var key := "glow|%s|%.1f|%.1f|%.1f|%.1f" % [c.to_html(), energy, pulse, flicker, glass]
	if not mats.has(key):
		var g := CreatureLook.glow(c, energy, pulse, flicker, glass)
		mats[key] = g
		m.glow_mats.append(g)
	return mats[key]


## Plates / armour of an element
func _armor(e: String) -> ShaderMaterial:
	match e:
		"ferrum": return _metal(e)
		"pebble": return _skin_of(e)
		"glacia", "solara": return _skin_of(e, "skin_clear")
		"voltara": return _metal(e)
	return _skin_of(e)


# ================================================================== helpers
func _mesh(parent: Node3D, mesh: Mesh, mat: Material, xf := Transform3D.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	return mi


func _node(parent: Node3D, pos: Vector3, b := Basis()) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.basis = b
	parent.add_child(n)
	return n


func _v(a: float, b: float) -> float:
	return rng.randf_range(a, b)


## A point on the spine (model space), 0 = rear, 1 = front
func sp(tt: float) -> Vector3:
	var lng := float(f["len"])
	return sp_start + sp_dir * lng * tt + sp_up * (float(f["arch"]) * sin(PI * tt) + float(f["hunch"]) * tt * tt)


## Body radius along the spine
func sp_r(tt: float) -> float:
	var keys: Array = [[0.0, float(f["hip"]) * 0.5], [0.2, float(f["hip"])], [0.5, float(f["waist"])], [0.8, float(f["chest"])], [1.0, float(f["chest"]) * 0.62]]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if tt <= float(b[0]):
			var k := (tt - float(a[0])) / (float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), smoothstep(0.0, 1.0, k))
	return float(f["chest"]) * 0.62


## Model space -> body pivot space
func L(p: Vector3) -> Vector3:
	return p - centre


## Top of the body at spine position tt (model space) and the outward "up" there
func top(tt: float) -> Vector3:
	return sp(tt) + sp_up * sp_r(tt) * 0.92


# ================================================================== body
func _frame() -> void:
	var base: Dictionary = _k(dom)["frame"]
	f = base.duplicate()
	var g := 1.0
	for e: String in els:
		if e != dom:
			g *= lerpf(1.0, float(_k(e)["girth"]), 0.6)
	var ind := _v(0.9, 1.1)
	for key: String in ["chest", "waist", "hip"]:
		f[key] = float(f[key]) * g * ind * _v(0.92, 1.08)
	f["len"] = float(f["len"]) * _v(0.9, 1.12)
	f["hip_h"] = float(f["hip_h"]) * _v(0.92, 1.08)
	f["arch"] = float(f["chest"]) * _v(0.05, 0.25)
	var lumps := float(f["lumps"])
	for e: String in els:
		lumps = maxf(lumps, float(_k(e)["frame"]["lumps"]) * 0.6)
	f["lumps"] = lumps
	var tilt := deg_to_rad(float(f["tilt"]) + _v(-6.0, 6.0))
	sp_dir = Vector3(0, sin(tilt), cos(tilt))
	sp_up = Vector3(0, cos(tilt), -sin(tilt))
	var lng := float(f["len"])
	sp_start = Vector3(0, float(f["hip_h"]), -lng * cos(tilt) * 0.5)
	centre = sp(0.45)
	ow = 0.004 + float(f["chest"]) * 0.018
	body_mat = CreatureLook.part(CreatureLook.region(design, "body", umbra), CreatureLook.region(design, "belly", umbra), accent, umbra, rng, "skin", ow)
	body_mat.set_shader_parameter("belly", 0.8)
	if third != accent:
		body_mat.set_shader_parameter("rim", Color(_k(third)["glow"]).lerp(Color.WHITE, 0.2))
		body_mat.set_shader_parameter("rim_amount", 0.3)
	m.skin_mats.append(body_mat)
	m.body = _node(m, centre)
	m.body_rest = centre
	match str(_k(dom)["legs"]):
		"flipper4": m.hover = 0.05
		"talons": m.hover = 0.07
		"petals": m.hover = 0.06


func _torso() -> void:
	var path: Array = []
	var radii: Array = []
	var wide := 1.0 + float(f["square"]) * 0.2
	for i in 13:
		var tt := float(i) / 12.0
		path.append(L(sp(tt)))
		var r := sp_r(tt)
		radii.append(Vector2(r * wide, r * 0.9))
	var flat := 0.25 if float(f["tilt"]) < 40.0 else 0.0
	_mesh(m.body, CMesh.tube(path, radii, 18, float(f["square"]), float(f["lumps"]), _v(0, 50), flat), body_mat)
	# muscle masses at shoulders and hips break the outline
	for tt: float in [0.18, 0.8]:
		for sx: float in [-1.0, 1.0]:
			var p := sp(tt) + Vector3(sx * sp_r(tt) * 0.55, 0, 0) - sp_up * sp_r(tt) * 0.1
			var r2 := sp_r(tt) * 0.55
			_mesh(m.body, CMesh.tube([L(p - sp_dir * r2), L(p), L(p + sp_dir * r2)], [Vector2(r2 * 0.5, r2 * 0.5), Vector2(r2, r2 * 0.9), Vector2(r2 * 0.4, r2 * 0.4)], 12, 0.0, float(f["lumps"]) * 0.6, _v(0, 50)), body_mat)
	# vertebrae ridge along the back
	var verts := rng.randi_range(6, 10)
	for i in verts:
		var tt2 := lerpf(0.1, 0.92, float(i) / (verts - 1))
		var p2 := top(tt2)
		var rr := sp_r(tt2) * 0.16
		_mesh(m.body, CMesh.plate(rr * 1.6, rr * 2.2, rr * 0.9, 0.3, 0.3), body_mat, CMesh.along(L(p2), sp_up, Vector3.ONE))


# ================================================================== legs
func _legs() -> void:
	var kind := str(_k(dom)["legs"])
	var hh := float(f["hip_h"])
	var mat := _role("limb")
	match kind:
		"stout4":
			for pair: Array in [[0.82, 1.0, 0.0], [0.15, -1.0, 0.5]]:
				for sx: float in [-1.0, 1.0]:
					var tt := float(pair[0])
					var hip := sp(tt) + Vector3(sx * sp_r(tt) * 0.72, 0, 0) - sp_up * sp_r(tt) * 0.3
					var foot := Vector3(hip.x * 1.25, 0, hip.z + float(pair[1]) * 0.04)
					var l := (hip.y - 0.02) * 0.56
					_ik_leg(hip, foot, l * _v(0.95, 1.08), l * 1.0, float(pair[1]), sx, float(pair[2]) + (0.0 if sx < 0.0 else 0.5), mat, sp_r(tt) * 0.32, "paw", dom, tt > 0.5)
			m.stride = 0.16
			m.step_speed = 1.5
		"stilt2":
			for sx: float in [-1.0, 1.0]:
				var hip2 := sp(0.08) + Vector3(sx * sp_r(0.08) * 0.75, 0, 0)
				var foot2 := Vector3(hip2.x * 1.2, 0, hip2.z + 0.05)
				_ik_leg(hip2, foot2, hh * 0.56, hh * 0.62, 1.0, sx, 0.0 if sx < 0.0 else 0.5, mat, float(f["hip"]) * 0.32, "talon", dom, false)
			m.stride = 0.24
			m.step_speed = 1.3
		"pillar2":
			for sx: float in [-1.0, 1.0]:
				var hip3 := sp(0.06) + Vector3(sx * sp_r(0.06) * 0.95, 0, 0) - sp_up * 0.05
				var foot3 := Vector3(hip3.x * 1.15, 0, hip3.z + 0.08)
				_ik_leg(hip3, foot3, hip3.y * 0.55, hip3.y * 0.53, -1.0, sx, 0.0 if sx < 0.0 else 0.5, _metal(dom), float(f["hip"]) * 0.42, "stomp", dom, false)
			m.stride = 0.14
			m.step_speed = 1.1
		"insect6":
			var i := 0
			for tt: float in [0.22, 0.5, 0.78]:
				for sx: float in [-1.0, 1.0]:
					var hip4 := sp(tt) + Vector3(sx * sp_r(tt) * 0.8, 0, 0) - sp_up * sp_r(tt) * 0.2
					var out := float(f["len"]) * 0.32 + 0.12
					var foot4 := Vector3(sx * (sp_r(tt) + out), 0, hip4.z + (tt - 0.5) * 0.5)
					var ph := (0.0 if (i % 2 == 0) == (sx < 0.0) else 0.5)
					_ik_leg(hip4, foot4, out * 0.75, hip4.y * 1.05, sx, sx, ph, mat, sp_r(tt) * 0.13, "spike", dom, tt > 0.6, true)
				i += 1
			m.stride = 0.13
			m.step_speed = 2.2
		"roots":
			var n := rng.randi_range(7, 10)
			for i2 in n:
				var a := TAU * i2 / n + _v(-0.2, 0.2)
				var tt2 := 0.45 + cos(a) * 0.35
				var base := sp(tt2) + Vector3(sin(a) * sp_r(tt2) * 0.6, 0, 0) - sp_up * sp_r(tt2) * 0.6
				var out2 := Vector3(sin(a) * 0.8, -1.0, cos(a) * 0.5)
				_tendril(base, out2, base.y * 1.3, sp_r(tt2) * 0.16, 4, _skin_of(dom), "root")
			m.stride = 0.0
		"flipper4":
			for pair2: Array in [[0.78, 0.0], [0.2, 0.5]]:
				for sx: float in [-1.0, 1.0]:
					var tt3 := float(pair2[0])
					var root := sp(tt3) + Vector3(sx * sp_r(tt3) * 0.85, 0, 0) - sp_up * sp_r(tt3) * 0.3
					_flipper(root, sx, sp_r(tt3) * 1.6, float(pair2[1]))
		"talons":
			for sx: float in [-1.0, 1.0]:
				var root2 := sp(0.25) + Vector3(sx * sp_r(0.25) * 0.6, 0, 0) - sp_up * sp_r(0.25) * 0.6
				_tendril(root2, Vector3(sx * 0.15, -1, 0.25), hh * 0.5, float(f["hip"]) * 0.18, 3, _metal(dom), "talon")
		"petals":
			var ring := _node(m.body, L(sp(0.05)))
			m.spinners.append([ring, Vector3.UP, 0.25])
			var n2 := rng.randi_range(6, 9)
			for i3 in n2:
				var a2 := TAU * i3 / n2
				var dir := Vector3(sin(a2) * 0.55, -1.0, cos(a2) * 0.55).normalized()
				var pv := _node(ring, Vector3(sin(a2), 0, cos(a2)) * float(f["hip"]) * 0.6)
				var lng := hh * _v(0.45, 0.7)
				_mesh(pv, CMesh.crystal(lng, float(f["hip"]) * 0.18, 5), _skin_of(dom, "skin_clear"), CMesh.along(Vector3.ZERO, dir))
				_mesh(pv, CMesh.ball(float(f["hip"]) * 0.07, 8, 6), _glow(dom, 3.0, 0.5), Transform3D(Basis(), dir * lng * 0.95))
				m.grows.append([pv, Vector3.ONE])


## A real leg: hip joint, thigh, knee joint, shin, foot. The model moves it by IK.
## insect: the knee goes up and out (bend axis = forward)
func _ik_leg(hip: Vector3, foot: Vector3, l1: float, l2: float, ks: float, sx: float, phase: float, mat: Material,
		r: float, foot_kind: String, e: String, front: bool, insect := false) -> void:
	var hp := _node(m.body, L(hip))
	var bulge := 0.35 if foot_kind != "spike" else 0.05
	_mesh(hp, CMesh.limb(Vector3.ZERO, Vector3(0, -l1, 0), r, r * 0.7, Vector3(0, 0, -0.04 * ks), bulge, 10, 0.05), mat)
	_mesh(hp, CMesh.ball(r * 1.05, 10, 6), mat)
	var kn := _node(hp, Vector3(0, -l1, 0))
	_mesh(kn, CMesh.ball(r * 0.8, 10, 6), mat)
	_mesh(kn, CMesh.limb(Vector3.ZERO, Vector3(0, -l2, 0), r * 0.68, r * 0.42, Vector3(0, 0, 0.03 * ks), bulge * 0.6, 8, 0.03), mat)
	var fp := Vector3(0, -l2, 0)
	match foot_kind:
		"paw":
			_mesh(kn, CMesh.plate(r * 2.0, r * 2.4, r * 0.8, 0.0, 0.3), mat, Transform3D(Basis(), fp + Vector3(0, r * 0.2, r * 0.5)))
			var toes := 3 + rng.randi_range(0, 1)
			for i in toes:
				var a := lerpf(-0.5, 0.5, float(i) / (toes - 1))
				var b := fp + Vector3(sin(a) * r * 0.8, r * 0.1, r * 1.3)
				_mesh(kn, CMesh.horn(b, b + Vector3(sin(a) * r * 0.3, -r * 0.35, r * 0.6), r * 0.22, Vector3(0, r * 0.1, 0)), _metal(e, "metal2") if e == "pebble" else _role("horn"))
		"talon":
			for i2 in 3:
				var a2 := lerpf(-0.6, 0.6, float(i2) / 2.0)
				var b2 := fp + Vector3(0, r * 0.1, 0)
				_mesh(kn, CMesh.limb(b2, b2 + Vector3(sin(a2) * r * 1.5, -r * 0.1, cos(a2) * r * 2.6), r * 0.3, r * 0.15, Vector3(0, r * 0.4, 0), 0.0, 6), mat)
				var tip := b2 + Vector3(sin(a2) * r * 1.5, -r * 0.1, cos(a2) * r * 2.6)
				_mesh(kn, CMesh.crystal(r * 1.1, r * 0.18, 5), _skin_of("glacia", "skin_clear") if e == "glacia" else mat, CMesh.along(tip, Vector3(sin(a2), -0.6, cos(a2))))
			_mesh(kn, CMesh.horn(fp, fp + Vector3(0, r * 0.2, -r * 1.4), r * 0.25), mat)
		"stomp":
			_mesh(kn, CMesh.box(Vector3(r * 2.4, r * 0.6, r * 3.0)), _metal(e), Transform3D(Basis(), fp + Vector3(0, r * 0.25, r * 0.4)))
			for i3 in 3:
				var x := (i3 - 1) * r * 0.75
				_mesh(kn, CMesh.box(Vector3(r * 0.55, r * 0.5, r * 0.8)), _metal(e, "metal2"), Transform3D(Basis(), fp + Vector3(x, r * 0.2, r * 1.95)))
			# piston along the shin, gear in the knee
			var pist := _node(kn, Vector3(r * 0.9 * sx, -l2 * 0.35, -r * 0.4))
			_mesh(pist, CMesh.cyl(r * 0.22, r * 0.22, l2 * 0.5, 8), _metal(e, "metal2"))
			_mesh(kn, CMesh.cyl(r * 0.32, r * 0.32, l2 * 0.4, 8), _metal(e), Transform3D(Basis(), Vector3(r * 0.9 * sx, -l2 * 0.2, -r * 0.4)))
			m.pistons.append([pist, pist.position, Vector3.UP, l2 * 0.12, 3.0])
			var g := _node(kn, Vector3(sx * r * 0.85, 0, 0), Basis(Vector3.FORWARD, PI / 2))
			_mesh(g, CMesh.gear(r * 0.75, 10, r * 0.25), _metal(e, "metal2"))
			m.spinners.append([g, Vector3.UP, 1.2 * sx])
		"spike":
			_mesh(kn, CMesh.horn(fp, fp + Vector3(0, -r * 2.5, r * 1.0), r * 0.9), mat)
			for i4 in 2:
				var p4 := Vector3(0, -l2 * (0.3 + i4 * 0.3), 0)
				_mesh(kn, CMesh.horn(p4, p4 + Vector3(sx * r * 1.6, r * 1.2, 0), r * 0.55), _skin_of("verdis") if e == "verdis" else mat)
	var side := Vector3(0, 0, 1) if insect else Vector3(1, 0, 0)
	var leg := {"hip": hp, "knee": kn, "l1": l1, "l2": l2, "rest": foot, "side": side, "ks": ks, "phase": phase,
		"lift": clampf(hip.y * 0.18, 0.04, 0.16), "front": front}
	m.legs.append(leg)


## A chain of segments (tentacle / root / talon leg) hanging from `base` towards `dir`
func _tendril(base: Vector3, dir: Vector3, length: float, r: float, segs: int, mat: Material, kind: String) -> Array:
	var nodes: Array = []
	var rests: Array = []
	var parent: Node3D = m.body
	var seg := length / segs
	var d := dir.normalized()
	var pos := L(base)
	for i in segs:
		var b := CMesh.along(Vector3.ZERO, d).basis if i == 0 else Basis()
		var n := _node(parent, pos, b)
		var rr := r * (1.0 - float(i) / segs * 0.7)
		_mesh(n, CMesh.limb(Vector3.ZERO, Vector3(0, seg, 0), rr, rr * 0.75, Vector3(0, 0, 0.0), 0.15, 7), mat)
		nodes.append(n)
		rests.append(n.basis)
		parent = n
		pos = Vector3(0, seg, 0)
	var tip := _node(parent, Vector3(0, seg, 0))
	match kind:
		"root":
			# the tip curls onto the ground, with a small glowing pore
			_mesh(tip, CMesh.horn(Vector3.ZERO, Vector3(0, r * 2.0, r * 1.5), r * 0.5, Vector3(0, r, 0)), mat)
			_mesh(tip, CMesh.ball(r * 0.35, 8, 6), _glow("mycelia", 2.0, 0.6))
			m.chains.append({"nodes": nodes.duplicate(), "rest": rests, "amp": 0.12, "walk_amp": 0.25, "speed": 2.2, "lag": 0.7, "axis": Vector3.FORWARD, "phase": base.x * 5.0 + base.z * 3.0})
		"talon":
			for i2 in 3:
				var a := lerpf(-0.7, 0.7, float(i2) / 2.0)
				_mesh(tip, CMesh.horn(Vector3.ZERO, Vector3(sin(a) * r * 2.0, r * 2.5, r * 1.5), r * 0.6, Vector3(0, 0, r * 1.5)), _metal("voltara", "metal2"))
			m.chains.append({"nodes": nodes.duplicate(), "rest": rests, "amp": 0.1, "walk_amp": 0.2, "speed": 1.6, "lag": 0.5, "axis": Vector3.RIGHT, "phase": base.x * 4.0})
		"lure", "antenna", "hypha", "streamer":
			m.chains.append({"nodes": nodes.duplicate(), "rest": rests, "amp": 0.18, "walk_amp": 0.2, "speed": 2.0, "lag": 0.6, "axis": Vector3.FORWARD, "phase": base.x * 7.0 + base.y})
	nodes.append(tip)
	return nodes


## Aquora flipper: a short limb with a ribbed fin membrane that paddles
func _flipper(root: Vector3, sx: float, lng: float, phase: float) -> void:
	var pv := _node(m.body, L(root), Basis(Vector3.FORWARD, -sx * 0.5))
	_mesh(pv, CMesh.limb(Vector3.ZERO, Vector3(sx * lng * 0.45, -lng * 0.15, 0), lng * 0.12, lng * 0.07, Vector3(0, lng * 0.05, 0)), body_mat)
	var tips: Array = []
	var rays := 5
	for i in rays:
		var a := lerpf(-0.6, 0.7, float(i) / (rays - 1))
		var tip := Vector3(sx * lng * (0.45 + 0.55 * cos(a)), -lng * 0.15 - lng * 0.1 * sin(a), -lng * 0.55 * sin(a))
		tips.append(tip)
		_mesh(pv, CMesh.limb(Vector3(sx * lng * 0.4, -lng * 0.15, 0), tip, lng * 0.025, lng * 0.008, Vector3.ZERO, 0.0, 5), _skin_of("aquora"))
	_mesh(pv, CMesh.membrane(Vector3(sx * lng * 0.35, -lng * 0.15, 0), tips, 0.15), _skin_of("aquora", "membrane"))
	m.chains.append({"nodes": [pv], "rest": [pv.basis], "amp": 0.35, "walk_amp": 0.3, "speed": 2.4, "lag": 0.0, "axis": Vector3.RIGHT, "phase": phase * TAU})


# ================================================================== neck and head
func _neck_head() -> void:
	var he := str(owner["head"])
	var nk: Array = NECKS.get(he, NECKS["solara"])
	var ndir: Vector3 = Vector3(nk[0]).normalized()
	var nlen := float(nk[1]) * _v(0.85, 1.15)
	var hs := float(f["chest"]) * float(nk[2]) * _v(0.9, 1.1)
	var base := sp(0.97)
	var end := base + ndir * (nlen + hs * 0.3)
	if nlen > 0.1:
		var path := CMesh.curve(L(base - sp_dir * 0.05), L(end), Vector3(0, nlen * 0.15, -nlen * 0.1), 7)
		_mesh(m.body, CMesh.tube(path, CMesh.taper(7, sp_r(0.97) * 0.7, hs * 0.4, 0.1), 12, 0.0, float(f["lumps"]) * 0.5, 3.0), body_mat)
	m.head = _node(m.body, L(end))
	m.head_rest = m.head.basis
	var hm := _role("head")
	match he:
		"sun": _head_halo(hs, hm)
		"pebble": _head_scrap(hs, hm)
		"glacia": _head_crest(hs, hm)
		"mycelia": _head_hood(hs, hm)
		"aquora": _head_angler(hs, hm)
		"verdis": _head_beak(hs, hm)
		"ferrum": _head_helm(hs, hm)
		"voltara": _head_sleek(hs, hm)
		"solara": _head_halo(hs, hm)


func _jaw(at: Vector3) -> Node3D:
	m.jaw = _node(m.head, at)
	m.jaw_rest = m.jaw.basis
	return m.jaw


func _eye(parent: Node3D, pos: Vector3, outward: Vector3, r: float, col: Color, slit := 0.4) -> void:
	var em := CreatureLook.eye(CreatureLook.region(design, "accent", umbra), slit)
	m.eye_mats.append(em)
	_mesh(parent, CMesh.ball(r, 14, 10), em, CMesh.along(pos, outward))
	# lid / socket ridge
	_mesh(parent, CMesh.ring(r * 0.95, r * 1.25, 18), body_mat, CMesh.along(pos - outward.normalized() * r * 0.2, outward))


func _head_scrap(hs: float, hm: Material) -> void:
	# broad, low skull of stone and gristle, a heavy jaw, mismatched eyes: one brass lens
	var skull := [Vector3(0, hs * 0.1, -hs * 0.6), Vector3(0, hs * 0.2, -hs * 0.1), Vector3(0, hs * 0.12, hs * 0.4), Vector3(0, -hs * 0.05, hs * 0.75)]
	_mesh(m.head, CMesh.tube(skull, [Vector2(hs * 0.5, hs * 0.4), Vector2(hs * 0.75, hs * 0.55), Vector2(hs * 0.62, hs * 0.42), Vector2(hs * 0.3, hs * 0.25)], 14, 0.45, 0.25, 7.0), hm)
	# brow plates (stone)
	for sx: float in [-1.0, 1.0]:
		_mesh(m.head, CMesh.plate(hs * 0.5, hs * 0.55, hs * 0.14, 0.4, 0.7), _skin_of("pebble"), Transform3D(Basis.from_euler(Vector3(-0.3, sx * 0.4, sx * 0.25)), Vector3(sx * hs * 0.32, hs * 0.5, hs * 0.2)))
	var jw := _jaw(Vector3(0, -hs * 0.12, -hs * 0.35))
	_mesh(jw, CMesh.tube([Vector3(0, 0, 0), Vector3(0, -hs * 0.15, hs * 0.5), Vector3(0, -hs * 0.1, hs * 1.0)], [Vector2(hs * 0.55, hs * 0.2), Vector2(hs * 0.6, hs * 0.22), Vector2(hs * 0.35, hs * 0.14)], 12, 0.6, 0.15, 2.0), hm)
	# scrap-metal teeth, all a bit different
	for i in rng.randi_range(4, 6):
		var x := lerpf(-hs * 0.35, hs * 0.35, float(i) / 5.0)
		_mesh(jw, CMesh.crystal(hs * _v(0.15, 0.3), hs * 0.05, 4), _metal("pebble"), CMesh.along(Vector3(x, -hs * 0.02, hs * _v(0.75, 0.95)), Vector3(0, 1, 0.3)))
	# the brass monocle lens (one side), two small organic eyes (other side)
	var s := -1.0 if rng.randf() < 0.5 else 1.0
	var lp := Vector3(s * hs * 0.38, hs * 0.3, hs * 0.5)
	_mesh(m.head, CMesh.ring(hs * 0.16, hs * 0.24, 20), _metal("pebble", "metal2"), CMesh.along(lp, Vector3(s * 0.25, 0, 1)))
	_mesh(m.head, CMesh.cyl(hs * 0.17, hs * 0.17, hs * 0.04, 16), _glow("pebble", 1.6, 0.2, 0.0, 1.0), CMesh.along(lp + Vector3(0, 0, hs * 0.02), Vector3(s * 0.25, 0, 1)))
	_mesh(m.head, CMesh.limb(lp + Vector3(s * hs * 0.2, 0, 0), Vector3(s * hs * 0.6, hs * 0.1, -hs * 0.3), hs * 0.03, hs * 0.03, Vector3(0, hs * 0.1, 0)), _metal("pebble", "metal2"))
	for i2 in 2:
		_eye(m.head, Vector3(-s * hs * (0.28 + i2 * 0.14), hs * (0.3 - i2 * 0.08), hs * 0.52), Vector3(-s * 0.4, 0.15, 1), hs * 0.09, Color(_k("pebble")["glow"]), 0.6)


func _head_crest(hs: float, hm: Material) -> void:
	# long narrow skull, swept-back crest of ice crystals, four slit eyes, a clear ice mask
	var skull := [Vector3(0, hs * 0.1, -hs * 0.7), Vector3(0, hs * 0.15, -hs * 0.1), Vector3(0, 0, hs * 0.6), Vector3(0, -hs * 0.1, hs * 1.2)]
	_mesh(m.head, CMesh.tube(skull, [Vector2(hs * 0.3, hs * 0.35), Vector2(hs * 0.42, hs * 0.45), Vector2(hs * 0.3, hs * 0.3), Vector2(hs * 0.08, hs * 0.08)], 12, 0.2, 0.05, 1.0), hm)
	var ice := _skin_of("glacia", "skin_clear")
	_mesh(m.head, CMesh.plate(hs * 0.7, hs * 1.1, hs * 0.12, 0.5, 0.4), ice, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, hs * 0.32, hs * 0.35)))
	var n := rng.randi_range(3, 6)
	for i in n:
		var a := lerpf(-0.6, 0.6, float(i) / maxf(n - 1, 1))
		var lng := hs * _v(0.8, 1.6) * (1.0 - absf(a) * 0.4)
		var pv := _node(m.head, Vector3(sin(a) * hs * 0.2, hs * 0.35, -hs * 0.3))
		_mesh(pv, CMesh.crystal(lng, hs * 0.09, 6), ice, CMesh.along(Vector3.ZERO, Vector3(sin(a) * 0.6, 0.7, -1.0)))
		m.grows.append([pv, Vector3.ONE])
	for i2 in 2:
		for sx: float in [-1.0, 1.0]:
			_eye(m.head, Vector3(sx * hs * 0.26, hs * (0.18 - i2 * 0.12), hs * (0.45 - i2 * 0.1)), Vector3(sx * 0.7, 0.1, 0.7), hs * 0.075, Color(_k("glacia")["glow"]), 0.9)
	var jw := _jaw(Vector3(0, -hs * 0.15, -hs * 0.1))
	for sx2: float in [-1.0, 1.0]:
		_mesh(jw, CMesh.horn(Vector3(sx2 * hs * 0.15, 0, hs * 0.3), Vector3(sx2 * hs * 0.05, -hs * 0.15, hs * 1.1), hs * 0.06, Vector3(sx2 * hs * 0.15, 0, 0)), ice)


func _head_hood(hs: float, hm: Material) -> void:
	# a mushroom-cap hood over the face; gills under it; a cluster of small glowing eyes;
	# feeding tendrils hanging down
	var cap := _skin_of("mycelia")
	var path := [Vector3(0, hs * 0.05, -hs * 0.5), Vector3(0, hs * 0.35, -hs * 0.1), Vector3(0, hs * 0.38, hs * 0.35), Vector3(0, hs * 0.15, hs * 0.75)]
	_mesh(m.head, CMesh.tube(path, [Vector2(hs * 0.6, hs * 0.4), Vector2(hs * 1.05, hs * 0.5), Vector2(hs * 0.95, hs * 0.42), Vector2(hs * 0.4, hs * 0.15)], 16, 0.0, 0.35, 11.0, 0.6), cap)
	_mesh(m.head, CMesh.tube([Vector3(0, -hs * 0.1, -hs * 0.3), Vector3(0, -hs * 0.05, hs * 0.3), Vector3(0, -hs * 0.12, hs * 0.6)], [Vector2(hs * 0.4, hs * 0.35), Vector2(hs * 0.42, hs * 0.32), Vector2(hs * 0.2, hs * 0.15)], 12, 0.0, 0.3, 4.0), hm)
	# gill frills under the rim
	var gill := _skin_of("mycelia", "skin_2side")
	for i in 10:
		var a := lerpf(-1.2, 1.2, float(i) / 9.0)
		_mesh(m.head, CMesh.plate(hs * 0.05, hs * 0.45, hs * 0.02, 0.0, 0.0), gill, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.3), Vector3(sin(a) * hs * 0.55, hs * 0.18, cos(a) * hs * 0.4)))
	var n := rng.randi_range(5, 8)
	for i2 in n:
		var p := Vector3(_v(-0.28, 0.28) * hs, _v(0.0, 0.18) * hs, hs * _v(0.42, 0.55))
		_eye(m.head, p, Vector3(p.x, 0.1, 1), hs * _v(0.05, 0.085), Color(_k("mycelia")["glow"]), 0.0)
	var jw := _jaw(Vector3(0, -hs * 0.25, hs * 0.4))
	for i3 in rng.randi_range(3, 5):
		var x := _v(-0.25, 0.25) * hs
		var t := _tendril(Vector3.ZERO, Vector3(0, -1, 0.2), hs * _v(0.4, 0.7), hs * 0.05, 3, hm, "hypha")
		var first: Node3D = t[0]
		first.reparent(jw, false)
		first.position = Vector3(x, 0, 0)


func _head_angler(hs: float, hm: Material) -> void:
	# streamlined fish-like head, gill slits, big round eyes in brass porthole rings,
	# an underslung jaw with needle teeth, and a glowing lure on a stalk
	var path := [Vector3(0, 0, -hs * 0.6), Vector3(0, hs * 0.05, 0), Vector3(0, 0, hs * 0.55), Vector3(0, -hs * 0.1, hs * 0.95)]
	_mesh(m.head, CMesh.tube(path, [Vector2(hs * 0.5, hs * 0.55), Vector2(hs * 0.55, hs * 0.55), Vector2(hs * 0.4, hs * 0.38), Vector2(hs * 0.12, hs * 0.1)], 14, 0.0, 0.03, 2.0), hm)
	for sx: float in [-1.0, 1.0]:
		var ep := Vector3(sx * hs * 0.42, hs * 0.15, hs * 0.25)
		_eye(m.head, ep, Vector3(sx, 0.2, 0.4), hs * 0.15, Color(_k("aquora")["glow"]), 0.2)
		_mesh(m.head, CMesh.ring(hs * 0.15, hs * 0.22, 20), _metal("aquora"), CMesh.along(ep, Vector3(sx, 0.2, 0.4)))
		for i in 4:   # rivets on the porthole
			var a := TAU * i / 4.0
			var off := Basis.looking_at(Vector3(sx, 0.2, 0.4)) * Vector3(cos(a), sin(a), 0) * hs * 0.19
			_mesh(m.head, CMesh.ball(hs * 0.025, 6, 4), _metal("aquora", "metal2"), Transform3D(Basis(), ep + off))
	var jw := _jaw(Vector3(0, -hs * 0.3, -hs * 0.25))
	_mesh(jw, CMesh.tube([Vector3(0, 0, 0), Vector3(0, -hs * 0.05, hs * 0.6), Vector3(0, hs * 0.05, hs * 1.15)], [Vector2(hs * 0.4, hs * 0.18), Vector2(hs * 0.4, hs * 0.2), Vector2(hs * 0.18, hs * 0.08)], 12, 0.1, 0.0, 0.0), hm)
	for i2 in 8:
		var x := lerpf(-hs * 0.3, hs * 0.3, float(i2) / 7.0)
		_mesh(jw, CMesh.horn(Vector3(x, hs * 0.05, hs * (0.8 + absf(x) * -0.6)), Vector3(x, hs * 0.3, hs * (0.85 - absf(x) * 0.6)), hs * 0.025), _skin_of("glacia", "skin_clear") if umbra == false else hm)
	var lure := _tendril(Vector3.ZERO, Vector3(0, 1, 0.6), hs * 1.1, hs * 0.04, 4, hm, "lure")
	var first: Node3D = lure[0]
	first.reparent(m.head, false)
	first.position = Vector3(0, hs * 0.45, hs * 0.1)
	var tip: Node3D = lure[lure.size() - 1]
	_mesh(tip, CMesh.ball(hs * 0.12, 12, 8), _glow("aquora", 3.0, 0.6))


func _head_beak(hs: float, hm: Material) -> void:
	# narrow head, hooked beak of bark-horn, thorn horns curving back, leaf frills, two eyes
	var path := [Vector3(0, 0, -hs * 0.5), Vector3(0, hs * 0.15, 0), Vector3(0, hs * 0.05, hs * 0.5)]
	_mesh(m.head, CMesh.tube(path, [Vector2(hs * 0.4, hs * 0.45), Vector2(hs * 0.48, hs * 0.5), Vector2(hs * 0.3, hs * 0.3)], 12, 0.3, 0.1, 5.0), hm)
	var bark := _skin_of("verdis")
	_mesh(m.head, CMesh.horn(Vector3(0, hs * 0.1, hs * 0.4), Vector3(0, -hs * 0.35, hs * 1.15), hs * 0.25, Vector3(0, hs * 0.35, hs * 0.1), 8, 0.5), bark)
	var jw := _jaw(Vector3(0, -hs * 0.12, hs * 0.2))
	_mesh(jw, CMesh.horn(Vector3(0, 0, 0), Vector3(0, -hs * 0.15, hs * 0.7), hs * 0.18, Vector3(0, -hs * 0.05, 0), 8, 0.5), bark)
	var n := rng.randi_range(2, 3)
	for i in n:
		for sx: float in [-1.0, 1.0]:
			var b := Vector3(sx * hs * (0.2 + i * 0.08), hs * (0.35 - i * 0.12), -hs * (0.1 + i * 0.15))
			var pv := _node(m.head, b)
			_mesh(pv, CMesh.horn(Vector3.ZERO, Vector3(sx * hs * 0.4, hs * 0.5, -hs * (0.9 - i * 0.2)), hs * (0.13 - i * 0.03), Vector3(sx * hs * 0.2, hs * 0.2, 0)), _role("horn"))
			m.grows.append([pv, Vector3.ONE])
	var leaf := _skin_of("verdis", "skin_2side")
	for sx2: float in [-1.0, 1.0]:
		_mesh(m.head, CMesh.membrane(Vector3(sx2 * hs * 0.35, hs * 0.1, -hs * 0.2), [Vector3(sx2 * hs * 0.9, hs * 0.5, -hs * 0.5), Vector3(sx2 * hs * 1.0, hs * 0.1, -hs * 0.6), Vector3(sx2 * hs * 0.8, -hs * 0.25, -hs * 0.5)], 0.1), leaf)
	for sx3: float in [-1.0, 1.0]:
		_eye(m.head, Vector3(sx3 * hs * 0.3, hs * 0.22, hs * 0.32), Vector3(sx3 * 0.6, 0.15, 0.8), hs * 0.1, Color(_k("verdis")["glow"]), 0.8)


func _head_helm(hs: float, hm: Material) -> void:
	# small heavy head under an iron helm, a glowing visor slit, a grill jaw, bolts
	var iron := _metal("ferrum")
	_mesh(m.head, CMesh.tube([Vector3(0, 0, -hs * 0.45), Vector3(0, hs * 0.1, 0), Vector3(0, 0, hs * 0.5)], [Vector2(hs * 0.55, hs * 0.5), Vector2(hs * 0.62, hs * 0.58), Vector2(hs * 0.45, hs * 0.4)], 12, 0.6, 0.1, 9.0), hm)
	_mesh(m.head, CMesh.tube([Vector3(0, hs * 0.05, -hs * 0.5), Vector3(0, hs * 0.2, 0), Vector3(0, hs * 0.12, hs * 0.55)], [Vector2(hs * 0.62, hs * 0.55), Vector2(hs * 0.7, hs * 0.62), Vector2(hs * 0.5, hs * 0.42)], 12, 0.8, 0.0, 0.0, 0.7), iron)
	_mesh(m.head, CMesh.box(Vector3(hs * 0.8, hs * 0.1, hs * 0.08)), _glow("ferrum", 3.0, 0.4), Transform3D(Basis(), Vector3(0, hs * 0.15, hs * 0.6)))
	var jw := _jaw(Vector3(0, -hs * 0.2, hs * 0.1))
	for i in 5:
		var x := lerpf(-hs * 0.3, hs * 0.3, float(i) / 4.0)
		_mesh(jw, CMesh.box(Vector3(hs * 0.06, hs * 0.3, hs * 0.06)), _metal("ferrum", "metal2"), Transform3D(Basis(), Vector3(x, -hs * 0.05, hs * 0.45)))
	_mesh(jw, CMesh.box(Vector3(hs * 0.75, hs * 0.08, hs * 0.5)), iron, Transform3D(Basis(), Vector3(0, -hs * 0.2, hs * 0.25)))
	for sx: float in [-1.0, 1.0]:
		_mesh(m.head, CMesh.horn(Vector3(sx * hs * 0.5, hs * 0.35, -hs * 0.1), Vector3(sx * hs * 0.85, hs * 0.75, -hs * 0.4), hs * 0.12, Vector3(sx * hs * 0.1, 0, 0), 6, 0.6), _role("horn"))
		for j in 3:
			_mesh(m.head, CMesh.ball(hs * 0.05, 6, 4), _metal("ferrum", "metal2"), Transform3D(Basis(), Vector3(sx * hs * 0.66, hs * (0.1 - j * 0.15), hs * (0.1 - j * 0.1))))


func _head_sleek(hs: float, hm: Material) -> void:
	# aerodynamic pointed head, three eyes in a row (the middle one large), coil antennae
	var path := [Vector3(0, 0, -hs * 0.5), Vector3(0, hs * 0.1, hs * 0.1), Vector3(0, 0, hs * 0.7), Vector3(0, -hs * 0.08, hs * 1.4)]
	_mesh(m.head, CMesh.tube(path, [Vector2(hs * 0.4, hs * 0.4), Vector2(hs * 0.45, hs * 0.42), Vector2(hs * 0.25, hs * 0.22), Vector2(hs * 0.02, hs * 0.02)], 12, 0.0, 0.0, 0.0), hm)
	_eye(m.head, Vector3(0, hs * 0.28, hs * 0.35), Vector3(0, 0.5, 1), hs * 0.12, Color(_k("voltara")["glow"]), 0.0)
	for sx: float in [-1.0, 1.0]:
		_eye(m.head, Vector3(sx * hs * 0.3, hs * 0.15, hs * 0.3), Vector3(sx * 0.7, 0.2, 0.7), hs * 0.08, Color(_k("voltara")["glow"]), 0.8)
	var jw := _jaw(Vector3(0, -hs * 0.15, hs * 0.2))
	_mesh(jw, CMesh.horn(Vector3.ZERO, Vector3(0, -hs * 0.05, hs * 0.9), hs * 0.15, Vector3(0, -hs * 0.05, 0)), hm)
	for sx2: float in [-1.0, 1.0]:
		var ant := _tendril(Vector3.ZERO, Vector3(sx2 * 0.3, 1, -0.6), hs * 1.4, hs * 0.035, 4, _metal("voltara"), "antenna")
		var first: Node3D = ant[0]
		first.reparent(m.head, false)
		first.position = Vector3(sx2 * hs * 0.2, hs * 0.35, 0)
		# copper coil rings along the antenna
		for i in range(1, ant.size() - 1):
			var nd: Node3D = ant[i]
			_mesh(nd, CMesh.ring(hs * 0.04, hs * 0.07, 12), _metal("voltara"), Transform3D(Basis(), Vector3(0, hs * 0.1, 0)))
		var tip: Node3D = ant[ant.size() - 1]
		_mesh(tip, CMesh.ball(hs * 0.07, 10, 6), _glow("voltara", 3.5, 0.3, 0.8))
		m.arc_points.append(tip)


func _head_halo(hs: float, hm: Material) -> void:
	# a smooth faceless mask, an arc of luminous eye-points, crystal crown rays behind,
	# and a floating brass halo ring
	var path := [Vector3(0, -hs * 0.1, -hs * 0.4), Vector3(0, hs * 0.1, 0), Vector3(0, 0, hs * 0.5), Vector3(0, -hs * 0.2, hs * 0.75)]
	_mesh(m.head, CMesh.tube(path, [Vector2(hs * 0.35, hs * 0.45), Vector2(hs * 0.42, hs * 0.55), Vector2(hs * 0.32, hs * 0.42), Vector2(hs * 0.08, hs * 0.1)], 14, 0.1, 0.0, 0.0), hm)
	var n := rng.randi_range(5, 7)
	for i in n:
		var a := lerpf(-0.9, 0.9, float(i) / (n - 1))
		_mesh(m.head, CMesh.ball(hs * 0.045, 8, 6), _glow("solara", 4.0, 0.3), Transform3D(Basis(), Vector3(sin(a) * hs * 0.32, hs * (0.18 + cos(a) * 0.08), hs * 0.42 * cos(a * 0.6))))
	var cr := _skin_of("solara", "skin_clear")
	var rays := rng.randi_range(5, 9)
	for i2 in rays:
		var a2 := lerpf(-1.3, 1.3, float(i2) / (rays - 1))
		var pv := _node(m.head, Vector3(0, hs * 0.2, -hs * 0.25))
		_mesh(pv, CMesh.crystal(hs * _v(0.6, 1.0), hs * 0.06, 5), cr, CMesh.along(Vector3.ZERO, Vector3(sin(a2), cos(a2) * 0.9, -0.5)))
		m.grows.append([pv, Vector3.ONE])
	var halo := _node(m.head, Vector3(0, hs * 0.45, -hs * 0.35), Basis(Vector3.RIGHT, -0.5))
	_mesh(halo, CMesh.ring(hs * 0.6, hs * 0.68, 32), _metal("solara"))
	for i3 in 6:
		var a3 := TAU * i3 / 6.0
		_mesh(halo, CMesh.ball(hs * 0.05, 8, 6), _glow("solara", 3.0, 0.5), Transform3D(Basis(), Vector3(cos(a3), 0, sin(a3)) * hs * 0.64))
	m.spinners.append([halo, Vector3.UP, 0.6])
	_jaw(Vector3(0, -hs * 0.2, hs * 0.3))


# ================================================================== back
func _back() -> void:
	var e := str(owner["back"])
	match e:
		"pebble": _back_scrap()
		"glacia": _back_spines()
		"mycelia": _back_grove()
		"aquora": _back_fin()
		"verdis": _back_thorns()
		"ferrum": _back_chimneys()
		"voltara": _back_wings(e == dom)
		"solara", "sun": _back_orrery()


func _back_scrap() -> void:
	# welded junk: bent exhaust pipes with brass caps, a turning gear, a tank with a gauge,
	# bolted plates - never symmetric
	var s := 1.0 if rng.randf() < 0.5 else -1.0
	var p0 := top(0.55)
	var r := sp_r(0.55)
	for i in rng.randi_range(1, 2):
		var a := p0 + Vector3(s * r * (0.3 + i * 0.25), 0, -r * 0.2 * i)
		var b := a + sp_up * r * _v(0.8, 1.3) + Vector3(s * r * 0.2, 0, -r * 0.5)
		_mesh(m.body, CMesh.limb(L(a), L(b), r * 0.1, r * 0.08, Vector3(0, 0, r * 0.3), 0.0, 8), _metal("pebble"))
		_mesh(m.body, CMesh.cyl(r * 0.12, r * 0.1, r * 0.15, 10), _metal("pebble", "metal2"), CMesh.along(L(b), b - a))
		var puff := _node(m.body, L(b))
		puff.set_meta("fx_point", "pebble")
	var g := _node(m.body, L(top(0.35) + Vector3(-s * r * 0.35, 0, 0)), CMesh.along(Vector3.ZERO, Vector3(-s, 0.4, 0)).basis)
	_mesh(g, CMesh.gear(r * 0.4, 9, r * 0.08), _metal("pebble", "metal2"))
	m.spinners.append([g, Vector3.UP, 0.9])
	var tank := top(0.75) + Vector3(-s * r * 0.4, -r * 0.1, 0)
	_mesh(m.body, CMesh.cyl(r * 0.18, r * 0.18, r * 0.6, 12), _metal("pebble"), CMesh.along(L(tank), sp_dir))
	_mesh(m.body, CMesh.cyl(r * 0.1, r * 0.1, r * 0.03, 14), _glow("pebble", 1.2, 0.1, 0.0, 1.0), CMesh.along(L(tank + Vector3(-s * r * 0.18, 0, 0)), Vector3(-s, 0, 0)))
	for i2 in rng.randi_range(2, 3):
		var tt := _v(0.25, 0.8)
		var pp := top(tt) + Vector3(_v(-0.4, 0.4) * sp_r(tt), -sp_r(tt) * 0.05, 0)
		_mesh(m.body, CMesh.plate(sp_r(tt) * _v(0.5, 0.8), sp_r(tt) * _v(0.5, 0.9), sp_r(tt) * 0.06, 0.2, 0.9), _metal("pebble"), CMesh.along(L(pp), sp_up + Vector3(_v(-0.3, 0.3), 0, 0)))


func _back_spines() -> void:
	var ice := _skin_of("glacia", "skin_clear")
	var n := rng.randi_range(5, 9)
	for i in n:
		var tt := lerpf(0.12, 0.9, float(i) / (n - 1))
		var p := top(tt)
		var lng := sp_r(tt) * _v(0.9, 1.8) * (0.6 + sin(float(i) / (n - 1) * PI) * 0.6)
		var pv := _node(m.body, L(p))
		var lean := sp_up - sp_dir * 0.6 + Vector3(_v(-0.2, 0.2), 0, 0)
		_mesh(pv, CMesh.crystal(lng, sp_r(tt) * 0.13, 6), ice, CMesh.along(Vector3.ZERO, lean))
		# smaller side crystals
		for sx: float in [-1.0, 1.0]:
			if rng.randf() < 0.6:
				_mesh(pv, CMesh.crystal(lng * 0.45, sp_r(tt) * 0.07, 5), ice, CMesh.along(Vector3(sx * sp_r(tt) * 0.15, 0, 0), lean + Vector3(sx * 0.7, 0, 0)))
		m.grows.append([pv, Vector3.ONE])
	# cryo tubes with glowing coolant along the flanks
	for sx2: float in [-1.0, 1.0]:
		var path: Array = []
		var rad: Array = []
		for j in 6:
			var tt2 := lerpf(0.2, 0.85, float(j) / 5.0)
			path.append(L(sp(tt2) + Vector3(sx2 * sp_r(tt2) * 0.92, 0, 0) + sp_up * sp_r(tt2) * 0.25))
			rad.append(Vector2(sp_r(0.5) * 0.06, sp_r(0.5) * 0.06))
		_mesh(m.body, CMesh.tube(path, rad, 8), _glow("glacia", 1.6, 0.6, 0.0, 1.0))
		for j2 in 3:
			var tt3 := lerpf(0.3, 0.75, float(j2) / 2.0)
			_mesh(m.body, CMesh.ring(sp_r(0.5) * 0.06, sp_r(0.5) * 0.1, 12), _metal("glacia"), CMesh.along(L(sp(tt3) + Vector3(sx2 * sp_r(tt3) * 0.92, 0, 0) + sp_up * sp_r(tt3) * 0.25), sp_dir))


func _back_grove() -> void:
	# a little forest of mushrooms grows on the back, gills glowing underneath;
	# a brass spore censer breathes spores
	var cap := _skin_of("mycelia")
	var gill := _glow("mycelia", 1.4, 0.5)
	var n := rng.randi_range(3, 6)
	for i in n:
		var tt := _v(0.15, 0.85)
		var p := top(tt) + Vector3(_v(-0.5, 0.5) * sp_r(tt), 0, 0)
		var h := sp_r(tt) * _v(0.5, 1.4)
		var cr := h * _v(0.35, 0.6)
		var pv := _node(m.body, L(p))
		var lean := (sp_up + Vector3(_v(-0.4, 0.4), 0, _v(-0.3, 0.3))).normalized()
		_mesh(pv, CMesh.limb(Vector3.ZERO, lean * h, cr * 0.22, cr * 0.16, Vector3(_v(-0.05, 0.05), 0, 0), 0.2, 8), _skin_of("mycelia", "skin_2side"))
		var tip := lean * h
		_mesh(pv, CMesh.tube([tip - lean * cr * 0.1, tip + lean * cr * 0.3, tip + lean * cr * 0.45], [Vector2(cr, cr), Vector2(cr * 0.75, cr * 0.75), Vector2(cr * 0.1, cr * 0.1)], 14, 0.0, 0.1, float(i)), cap)
		_mesh(pv, CMesh.cyl(cr * 0.95, cr * 0.2, cr * 0.08, 14), gill, CMesh.along(tip - lean * cr * 0.12, lean))
		m.grows.append([pv, Vector3.ONE])
	var c := top(0.5) + Vector3(sp_r(0.5) * 0.45, 0, 0)
	var cen := _node(m.body, L(c), CMesh.along(Vector3.ZERO, sp_up).basis)
	_mesh(cen, CMesh.cyl(sp_r(0.5) * 0.12, sp_r(0.5) * 0.16, sp_r(0.5) * 0.35, 10), _metal("mycelia"), Transform3D(Basis(), Vector3(0, sp_r(0.5) * 0.17, 0)))
	_mesh(cen, CMesh.ring(sp_r(0.5) * 0.12, sp_r(0.5) * 0.17, 14), _glow("mycelia", 2.2, 0.8), Transform3D(Basis(), Vector3(0, sp_r(0.5) * 0.3, 0)))
	cen.set_meta("fx_point", "mycelia")


func _back_fin() -> void:
	# a tall translucent dorsal fin on rays, and a brass air tank strapped on
	var tips: Array = []
	var rays := rng.randi_range(5, 8)
	var hgt := sp_r(0.5) * _v(1.3, 2.0)
	for i in rays:
		var tt := lerpf(0.2, 0.85, float(i) / (rays - 1))
		var b := top(tt)
		var tip := b + sp_up * hgt * sin(float(i + 1) / (rays + 1) * PI) - sp_dir * hgt * 0.4
		tips.append(L(tip))
		_mesh(m.body, CMesh.limb(L(b), L(tip), sp_r(tt) * 0.04, sp_r(tt) * 0.015, Vector3.ZERO, 0.0, 5), _skin_of("aquora"))
	var root := L(top(0.5) - sp_up * sp_r(0.5) * 0.1)
	var all: Array = [L(top(0.15))]
	all.append_array(tips)
	all.append(L(top(0.92)))
	_mesh(m.body, CMesh.membrane(root, all, 0.12), _skin_of("aquora", "membrane"))
	for sx: float in [-1.0, 1.0]:
		var c := sp(0.45) + Vector3(sx * sp_r(0.45) * 0.75, 0, 0) + sp_up * sp_r(0.45) * 0.5
		_mesh(m.body, CMesh.cyl(sp_r(0.45) * 0.15, sp_r(0.45) * 0.15, sp_r(0.45) * 0.9, 12), _metal("aquora"), CMesh.along(L(c), sp_dir))
		_mesh(m.body, CMesh.ring(sp_r(0.45) * 0.15, sp_r(0.45) * 0.19, 14), _metal("aquora", "metal2"), CMesh.along(L(c), sp_dir))
	var bub := _node(m.body, L(top(0.5)))
	bub.set_meta("fx_point", "aquora")


func _back_thorns() -> void:
	var bark := _skin_of("verdis")
	var n := rng.randi_range(6, 10)
	for i in n:
		var tt := lerpf(0.1, 0.92, float(i) / (n - 1))
		var p := top(tt)
		var pv := _node(m.body, L(p))
		var lng := sp_r(tt) * _v(0.6, 1.2)
		_mesh(pv, CMesh.horn(Vector3.ZERO, (sp_up * 0.8 - sp_dir * 0.6) * lng, sp_r(tt) * 0.16, sp_up * lng * 0.1), _role("horn"))
		m.grows.append([pv, Vector3.ONE])
		# overlapping bark plates on both sides
		for sx: float in [-1.0, 1.0]:
			var q := sp(tt) + Vector3(sx * sp_r(tt) * 0.65, 0, 0) + sp_up * sp_r(tt) * 0.55
			_mesh(m.body, CMesh.plate(sp_r(tt) * 0.6, sp_r(tt) * 0.8, sp_r(tt) * 0.12, 0.4, 0.5), bark, CMesh.along(L(q), sp_up + Vector3(sx * 0.9, 0, 0)))
	var leaf := _skin_of("verdis", "skin_2side")
	for i2 in rng.randi_range(2, 4):
		var tt2 := _v(0.2, 0.8)
		var b2 := top(tt2) + Vector3(_v(-0.3, 0.3) * sp_r(tt2), 0, 0)
		var pv2 := _node(m.body, L(b2))
		var d := (sp_up + Vector3(_v(-0.6, 0.6), 0, _v(-0.5, 0.2))).normalized()
		_mesh(pv2, CMesh.membrane(Vector3.ZERO, [d * sp_r(tt2) * 0.6 + Vector3(sp_r(tt2) * 0.2, 0, 0), d * sp_r(tt2) * 0.9, d * sp_r(tt2) * 0.6 - Vector3(sp_r(tt2) * 0.2, 0, 0)], 0.0), leaf)
		m.chains.append({"nodes": [pv2], "rest": [pv2.basis], "amp": 0.15, "speed": 1.4, "lag": 0.0, "axis": Vector3.FORWARD, "phase": float(i2)})


func _back_chimneys() -> void:
	# two smokestacks breathing embers and smoke, heavy iron plates with glowing seams,
	# a furnace grate glowing through the chest
	var iron := _metal("ferrum")
	var r := sp_r(0.5)
	for sx: float in [-1.0, 1.0]:
		var b := top(0.42) + Vector3(sx * r * 0.45, 0, 0)
		var h := r * _v(1.0, 1.5)
		var up := (sp_up * 0.85 - sp_dir * 0.4 + Vector3(sx * 0.15, 0, 0)).normalized()
		_mesh(m.body, CMesh.cyl(r * 0.15, r * 0.19, h, 12), iron, CMesh.along(L(b + up * h * 0.5), up))
		for j in 3:
			_mesh(m.body, CMesh.ring(r * 0.17, r * 0.22, 14), _metal("ferrum", "metal2"), CMesh.along(L(b + up * h * (0.2 + j * 0.3)), up))
		_mesh(m.body, CMesh.ring(r * 0.11, r * 0.15, 14), _glow("ferrum", 3.0, 0.6), CMesh.along(L(b + up * h), up))
		var top_n := _node(m.body, L(b + up * h))
		top_n.set_meta("fx_point", "ferrum")
	for i in 4:
		var tt := lerpf(0.2, 0.85, float(i) / 3.0)
		for sx2: float in [-1.0, 1.0]:
			var q := sp(tt) + Vector3(sx2 * sp_r(tt) * 0.62, 0, 0) + sp_up * sp_r(tt) * 0.55
			_mesh(m.body, CMesh.plate(sp_r(tt) * 0.7, sp_r(tt) * 0.55, sp_r(tt) * 0.12, 0.3, 0.85), iron, CMesh.along(L(q), sp_up + Vector3(sx2, 0, 0)))
	_furnace()


func _furnace() -> void:
	var r := sp_r(0.75)
	var front := sp(0.72) - sp_up * r * 0.1
	var out := (sp_dir * 0.35 - sp_up * 0.0 + Vector3(0, 0, 0.6)).normalized()
	var pos := front + out * r * 0.85
	_mesh(m.body, CMesh.cyl(r * 0.35, r * 0.35, r * 0.06, 16), _glow("ferrum", 3.5, 0.5), CMesh.along(L(pos), out))
	for i in 4:
		var x := (i - 1.5) * r * 0.16
		_mesh(m.body, CMesh.box(Vector3(r * 0.04, r * 0.65, r * 0.06)), _metal("ferrum"), CMesh.along(L(pos + out * r * 0.03), out) * Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(x, 0, 0)))
	_mesh(m.body, CMesh.ring(r * 0.34, r * 0.42, 18), _metal("ferrum", "metal2"), CMesh.along(L(pos), out))


func _back_wings(big: bool) -> void:
	# membrane wings on copper ribs; the ribs carry current, the membrane glows in lines
	var sc := (1.0 if big else 0.7) * _v(0.9, 1.15)
	var span := (float(f["len"]) * 0.9 + 0.4) * sc
	var mem := _skin_of("voltara", "membrane")
	mem.set_shader_parameter("pattern", 9)
	mem.set_shader_parameter("mark_glow", 2.2)
	for sx: float in [-1.0, 1.0]:
		var root := top(0.72) + Vector3(sx * sp_r(0.72) * 0.4, 0, 0)
		var pv := _node(m.body, L(root))
		var tips: Array = []
		var ribs := 4
		for i in ribs:
			var a := lerpf(0.25, -0.75, float(i) / (ribs - 1))
			var tip := Vector3(sx * span * cos(a) * (1.0 - i * 0.08), span * 0.35 * sin(a + 0.3) + span * 0.1, -span * 0.35 * (i + 0.5) / ribs - span * 0.1)
			tips.append(tip)
			_mesh(pv, CMesh.limb(Vector3.ZERO, tip, span * 0.025, span * 0.006, Vector3(0, span * 0.06, 0), 0.0, 6), _metal("voltara"))
			if i == 0:
				var claw := _node(pv, tip)
				_mesh(claw, CMesh.horn(Vector3.ZERO, Vector3(sx * span * 0.08, span * 0.04, span * 0.04), span * 0.02), _metal("voltara", "metal2"))
				m.arc_points.append(claw)
		tips.append(Vector3(sx * span * 0.15, -span * 0.05, -span * 0.45))
		_mesh(pv, CMesh.membrane(Vector3(sx * span * 0.02, 0, -span * 0.02), tips, 0.22), mem)
		m.wings.append({"pivot": pv, "rest": pv.basis, "side": -sx, "amp": 0.35 if big else 0.25, "speed": 5.5 if big else 3.5})


func _back_orrery() -> void:
	# above the back floats a small glowing core, circled by brass rings like an orrery,
	# with crystal fins on the shoulders
	var c := top(0.55) + sp_up * sp_r(0.55) * 1.1
	var core := _node(m.body, L(c))
	_mesh(core, CMesh.ball(sp_r(0.55) * 0.28, 16, 10), _glow("solara", 4.0, 0.4))
	for i in 3:
		var ring := _node(core, Vector3.ZERO, Basis.from_euler(Vector3(_v(0, PI), _v(0, PI), 0)))
		var rr := sp_r(0.55) * (0.5 + i * 0.18)
		_mesh(ring, CMesh.ring(rr, rr + sp_r(0.55) * 0.04, 30), _metal("solara"))
		_mesh(ring, CMesh.ball(sp_r(0.55) * 0.06, 8, 6), _skin_of("solara", "skin_clear"), Transform3D(Basis(), Vector3(rr + sp_r(0.55) * 0.02, 0, 0)))
		m.spinners.append([ring, Vector3.UP, _v(0.6, 1.4) * (1.0 if i % 2 == 0 else -1.0)])
	_mesh(m.body, CMesh.limb(L(top(0.55)), L(c), sp_r(0.55) * 0.04, sp_r(0.55) * 0.02), _metal("solara", "metal2"))
	var cr := _skin_of("solara", "skin_clear")
	for sx: float in [-1.0, 1.0]:
		for j in 3:
			var p := top(0.75) + Vector3(sx * sp_r(0.75) * 0.6, -j * sp_r(0.75) * 0.15, -j * sp_r(0.75) * 0.2)
			var pv := _node(m.body, L(p))
			_mesh(pv, CMesh.crystal(sp_r(0.75) * (1.1 - j * 0.25), sp_r(0.75) * 0.08, 5), cr, CMesh.along(Vector3.ZERO, Vector3(sx * 0.9, 0.6, -0.5)))
			m.grows.append([pv, Vector3.ONE])
	core.set_meta("fx_point", "solara")


# ================================================================== tail
func _tail() -> void:
	var e := str(owner["tail"])
	var base := sp(0.02)
	var r := sp_r(0.08) * 0.55
	var dir := (-sp_dir * 0.85 - sp_up * 0.25).normalized()
	var lng := float(f["len"]) * _v(0.7, 1.1)
	match e:
		"mycelia":
			for i in rng.randi_range(3, 5):
				var d := (dir + Vector3(_v(-0.5, 0.5), _v(-0.3, 0.2), 0)).normalized()
				var ch := _tendril(base, d, lng * _v(0.5, 0.8), r * 0.25, 4, _skin_of("mycelia"), "hypha")
				var tip: Node3D = ch[ch.size() - 1]
				_mesh(tip, CMesh.ball(r * 0.15, 8, 6), _glow("mycelia", 2.5, 0.7))
			return
		"solara", "sun":
			for i2 in 3:
				var d2 := (dir + Vector3((i2 - 1) * 0.35, 0.1, 0)).normalized()
				var ch2 := _tendril(base, d2, lng * 0.9, r * 0.15, 5, _glow("solara", 1.8, 0.5), "streamer")
				for nd: Node3D in ch2:
					for c in nd.get_children():
						if c is MeshInstance3D:
							(c as MeshInstance3D).scale = Vector3(2.4, 1.0, 0.25)
			return
	var segs := 7
	var seg := lng / segs
	var parent: Node3D = m.body
	var nodes: Array = []
	var rests: Array = []
	var pos := L(base)
	var mat: Material = body_mat
	if e != dom:
		var tc := CreatureLook.pal(e, "body")
		mat = CreatureLook.part(tc.lerp(CreatureLook.UMBRA_SKIN, 0.55) if umbra else tc, CreatureLook.pal(e, "belly"), e, umbra, rng, "skin", ow)
		m.skin_mats.append(mat)
	if e == "ferrum":
		mat = _metal("ferrum")
	for i3 in segs:
		var b := CMesh.along(Vector3.ZERO, dir).basis if i3 == 0 else Basis()
		var n := _node(parent, pos, b)
		var k := float(i3) / segs
		var rr := r * (1.0 - k * 0.75)
		if e == "aquora":
			rr = r * (1.1 - k * 0.6)
		_mesh(n, CMesh.limb(Vector3.ZERO, Vector3(0, seg * 1.08, 0), rr, rr * 0.88, Vector3.ZERO, 0.1, 10, 0.05), mat)
		match e:
			"glacia":
				for sx: float in [-1.0, 1.0]:
					_mesh(n, CMesh.crystal(rr * 2.2, rr * 0.25, 5), _skin_of("glacia", "skin_clear"), CMesh.along(Vector3(sx * rr * 0.7, seg * 0.5, 0), Vector3(sx, 0.6, 0.3)))
			"verdis":
				_mesh(n, CMesh.horn(Vector3(0, seg * 0.5, rr * 0.8), Vector3(0, seg * 0.2, rr * 2.0), rr * 0.25), _skin_of("verdis"))
			"ferrum":
				_mesh(n, CMesh.ring(rr * 0.9, rr * 1.15, 14), _metal("ferrum", "metal2"), Transform3D(Basis(), Vector3(0, seg * 0.1, 0)))
				_mesh(n, CMesh.cyl(rr * 0.8, rr * 0.8, seg * 0.12, 12), _glow("ferrum", 2.5, 0.5), Transform3D(Basis(), Vector3(0, seg * 1.0, 0)))
			"voltara":
				_mesh(n, CMesh.ring(rr * 0.8, rr * 1.15, 12), _metal("voltara"), Transform3D(Basis(), Vector3(0, seg * 0.5, 0)))
			"pebble":
				if i3 % 2 == 0:
					_mesh(n, CMesh.plate(rr * 2.0, seg * 0.9, rr * 0.3, 0.3, 0.8), _skin_of("pebble"), Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, seg * 0.5, rr * 0.75)))
		nodes.append(n)
		rests.append(n.basis)
		parent = n
		pos = Vector3(0, seg, 0)
	var tip2 := _node(parent, Vector3(0, seg, 0))
	match e:
		"pebble":
			_mesh(tip2, CMesh.tube([Vector3(0, -r * 0.3, 0), Vector3(0, r * 0.4, 0), Vector3(0, r * 1.0, 0)], [Vector2(r * 0.4, r * 0.4), Vector2(r * 0.9, r * 0.8), Vector2(r * 0.3, r * 0.3)], 10, 0.3, 0.4, 3.0), _skin_of("pebble"))
			for i4 in 4:
				var a := TAU * i4 / 4.0
				_mesh(tip2, CMesh.horn(Vector3(cos(a) * r * 0.6, r * 0.4, sin(a) * r * 0.6), Vector3(cos(a) * r * 1.2, r * 0.5, sin(a) * r * 1.2), r * 0.18), _metal("pebble"))
		"glacia":
			_mesh(tip2, CMesh.crystal(r * 3.0, r * 0.35, 6), _skin_of("glacia", "skin_clear"))
		"aquora":
			_mesh(tip2, CMesh.membrane(Vector3.ZERO, [Vector3(-r * 2.5, r * 1.2, 0), Vector3(-r * 1.0, r * 0.6, 0), Vector3(0, r * 0.4, 0), Vector3(r * 1.0, r * 0.6, 0), Vector3(r * 2.5, r * 1.2, 0)], 0.3), _skin_of("aquora", "membrane"))
		"verdis":
			for i5 in 4:
				var a2 := TAU * i5 / 4.0
				_mesh(tip2, CMesh.limb(Vector3.ZERO, Vector3(cos(a2) * r * 0.8, r * 1.2, sin(a2) * r * 0.8), r * 0.12, r * 0.03, Vector3(0, 0, r * 0.3)), _skin_of("verdis"))
		"ferrum":
			_mesh(tip2, CMesh.horn(Vector3.ZERO, Vector3(0, r * 1.2, r * 0.6), r * 0.5, Vector3(0, 0, r * 0.4), 6, 0.6), _metal("ferrum", "metal2"))
		"voltara":
			for sx2: float in [-1.0, 1.0]:
				var prong := _node(tip2, Vector3.ZERO)
				_mesh(prong, CMesh.horn(Vector3.ZERO, Vector3(sx2 * r * 0.8, r * 1.6, 0), r * 0.18, Vector3(sx2 * r * 0.2, 0, 0)), _metal("voltara"))
				var pt := _node(prong, Vector3(sx2 * r * 0.8, r * 1.6, 0))
				_mesh(pt, CMesh.ball(r * 0.12, 8, 6), _glow("voltara", 3.0, 0.3, 0.8))
				m.arc_points.append(pt)
	m.chains.append({"nodes": nodes, "rest": rests, "amp": 0.12, "walk_amp": 0.15, "speed": 1.6, "lag": 0.5, "axis": Vector3.FORWARD, "droop": 0.0})


# ================================================================== arms
func _arms() -> void:
	var e := str(owner["arms"])
	var kind := str(_k(e)["arms"])
	if kind == "":
		return
	var r := sp_r(0.85)
	for sx: float in [-1.0, 1.0]:
		var sh := sp(0.86) + Vector3(sx * r * 0.85, 0, 0) - sp_up * r * 0.1
		var s := _node(m.body, L(sh), Basis(Vector3.RIGHT, -0.45) * Basis(Vector3.FORWARD, sx * 0.25))
		var big := kind == "scrap_claw" and sx > 0.0
		var ul := r * (1.4 if big else 0.95)
		var ar := r * (0.22 if big else 0.13)
		var mat: Material = _role("limb")
		if kind == "piston" or big:
			mat = _metal(e)
		_mesh(s, CMesh.limb(Vector3.ZERO, Vector3(0, -ul, 0), ar, ar * 0.75, Vector3.ZERO, 0.3, 8), mat)
		_mesh(s, CMesh.ball(ar * 1.15, 10, 6), mat)
		var el := _node(s, Vector3(0, -ul, 0), Basis(Vector3.RIGHT, -1.1))
		_mesh(el, CMesh.ball(ar * 0.85, 10, 6), mat)
		var fl := ul * 0.95
		_mesh(el, CMesh.limb(Vector3.ZERO, Vector3(0, -fl, 0), ar * 0.75, ar * 0.55, Vector3.ZERO, 0.2, 8), mat)
		var hp := Vector3(0, -fl, 0)
		match kind:
			"scrap_claw":
				if big:
					# a heavy mechanical pincer driven by a piston
					var p := _node(el, Vector3(ar * 1.1, -fl * 0.5, 0))
					_mesh(p, CMesh.cyl(ar * 0.25, ar * 0.25, fl * 0.5, 8), _metal(e, "metal2"))
					_mesh(el, CMesh.cyl(ar * 0.35, ar * 0.35, fl * 0.4, 8), _metal(e), Transform3D(Basis(), Vector3(ar * 1.1, -fl * 0.3, 0)))
					m.pistons.append([p, p.position, Vector3.DOWN, fl * 0.12, 2.5])
					for sy: float in [-1.0, 1.0]:
						_mesh(el, CMesh.horn(hp, hp + Vector3(sy * ar * 1.4, -ar * 3.0, ar * 0.8), ar * 0.5, Vector3(sy * ar * 0.9, 0, 0), 6, 0.6), _metal(e))
					var g := _node(el, Vector3(0, 0, ar * 0.9), Basis(Vector3.RIGHT, PI / 2))
					_mesh(g, CMesh.gear(ar * 0.9, 9, ar * 0.25), _metal(e, "metal2"))
					m.spinners.append([g, Vector3.UP, 1.5])
				else:
					for i in 3:
						var a := lerpf(-0.5, 0.5, float(i) / 2.0)
						_mesh(el, CMesh.horn(hp, hp + Vector3(sin(a) * ar * 1.5, -ar * 2.2, ar * 0.6), ar * 0.3), mat)
			"ice_scythe":
				_mesh(el, CMesh.crystal(fl * 1.4, ar * 0.5, 4), _skin_of("glacia", "skin_clear"), CMesh.along(hp, Vector3(0, -0.4, 1)) * Transform3D(Basis().scaled(Vector3(0.35, 1, 1.8)), Vector3.ZERO))
			"mantis":
				_mesh(el, CMesh.horn(hp, hp + Vector3(0, ar * 2.5, ar * 2.0), ar * 0.6, Vector3(0, -ar, ar), 6, 0.5), _skin_of("verdis"))
				for i2 in 4:
					var q := Vector3(0, -fl * (0.2 + i2 * 0.2), ar * 0.5)
					_mesh(el, CMesh.horn(q, q + Vector3(0, ar * 0.4, ar * 1.0), ar * 0.25), _skin_of("verdis"))
			"piston":
				var p2 := _node(el, Vector3(0, -fl * 0.5, -ar * 1.0))
				_mesh(p2, CMesh.cyl(ar * 0.22, ar * 0.22, fl * 0.55, 8), _metal(e, "metal2"))
				_mesh(el, CMesh.cyl(ar * 0.32, ar * 0.32, fl * 0.4, 8), _metal(e), Transform3D(Basis(), Vector3(0, -fl * 0.3, -ar * 1.0)))
				m.pistons.append([p2, p2.position, Vector3.DOWN, fl * 0.15, 3.0])
				_mesh(el, CMesh.tube([hp, hp + Vector3(0, -ar * 0.8, 0), hp + Vector3(0, -ar * 1.6, 0)], [Vector2(ar * 1.1, ar * 1.1), Vector2(ar * 1.3, ar * 1.3), Vector2(ar * 1.0, ar * 1.0)], 10, 0.8), _metal(e))
				_mesh(el, CMesh.cyl(ar * 0.6, ar * 0.6, ar * 0.1, 12), _glow("ferrum", 2.5, 0.5), Transform3D(Basis(), hp + Vector3(0, -ar * 1.7, 0)))
		m.arms.append({"shoulder": s, "elbow": el, "rest_s": s.basis, "rest_e": el.basis, "side": sx})


# ================================================================== infusions (every element)
func _infuse(e: String) -> void:
	var r := sp_r(0.5)
	match e:
		"pebble":
			# bolted scrap plates on one flank, rivets, a brass gauge
			var s := -1.0 if rng.randf() < 0.5 else 1.0
			for i in rng.randi_range(2, 3):
				var tt := _v(0.25, 0.8)
				var p := sp(tt) + Vector3(s * sp_r(tt) * 0.88, _v(-0.2, 0.3) * sp_r(tt), 0)
				var pl := _mesh(m.body, CMesh.plate(sp_r(tt) * _v(0.5, 0.8), sp_r(tt) * _v(0.5, 0.8), sp_r(tt) * 0.05, 0.1, 0.95), _metal("pebble"), CMesh.along(L(p), Vector3(s, 0.1, 0)))
				for j in 4:
					var off := Vector3((j % 2 - 0.5) * sp_r(tt) * 0.5, sp_r(tt) * 0.04, (j / 2 - 0.5) * sp_r(tt) * 0.5)
					_mesh(pl, CMesh.ball(sp_r(tt) * 0.035, 6, 4), _metal("pebble", "metal2"), Transform3D(Basis(), off))
			var gp := sp(0.7) + Vector3(-s * sp_r(0.7) * 0.8, sp_r(0.7) * 0.35, 0)
			_mesh(m.body, CMesh.cyl(r * 0.12, r * 0.12, r * 0.06, 14), _metal("pebble", "metal2"), CMesh.along(L(gp), Vector3(-s, 0.4, 0)))
			_mesh(m.body, CMesh.cyl(r * 0.09, r * 0.09, r * 0.065, 14), _glow("pebble", 1.0, 0.1, 0.0, 1.0, Color("#f0e0b0")), CMesh.along(L(gp), Vector3(-s, 0.4, 0)))
		"glacia":
			# frost crystal clusters on shoulders and hips, a clear ice shell over the back
			var ice := _skin_of("glacia", "skin_clear")
			for tt2: float in [0.2, 0.8]:
				for sx: float in [-1.0, 1.0]:
					if rng.randf() < 0.7:
						var pv := _node(m.body, L(sp(tt2) + Vector3(sx * sp_r(tt2) * 0.75, sp_r(tt2) * 0.4, 0)))
						for j2 in rng.randi_range(2, 4):
							_mesh(pv, CMesh.crystal(sp_r(tt2) * _v(0.3, 0.6), sp_r(tt2) * 0.06, 6), ice, CMesh.along(Vector3.ZERO, Vector3(sx * _v(0.3, 1.0), _v(0.4, 1.0), _v(-0.5, 0.5))))
						m.grows.append([pv, Vector3.ONE])
			if owner["back"] != "glacia":
				var path: Array = []
				var rad: Array = []
				for j3 in 6:
					var tt3 := lerpf(0.3, 0.75, float(j3) / 5.0)
					path.append(L(sp(tt3) + sp_up * sp_r(tt3) * 0.35))
					rad.append(Vector2(sp_r(tt3) * 0.95, sp_r(tt3) * 0.75))
				_mesh(m.body, CMesh.tube(path, rad, 14, 0.3, 0.05, 2.0), ice)
		"mycelia":
			# little fungi sprouting at the joints, glowing pores
			var spots: Array = []
			for l: Dictionary in m.legs:
				spots.append(l["knee"])
			for a: Dictionary in m.arms:
				spots.append(a["elbow"])
			if spots.is_empty():
				spots.append(m.body)
			for i2 in rng.randi_range(3, 6):
				var host: Node3D = spots[rng.randi() % spots.size()]
				var rr := r * _v(0.12, 0.22)
				var p2 := Vector3(_v(-1, 1), _v(-0.5, 1), _v(-1, 1)) * r * 0.25 if host != m.body else L(top(_v(0.2, 0.9)))
				var pv2 := _node(host, p2)
				_mesh(pv2, CMesh.cyl(rr * 0.15, rr * 0.2, rr * 0.8, 6), _skin_of("mycelia", "skin_2side"), Transform3D(Basis(), Vector3(0, rr * 0.4, 0)))
				_mesh(pv2, CMesh.tube([Vector3(0, rr * 0.7, 0), Vector3(0, rr * 1.0, 0), Vector3(0, rr * 1.15, 0)], [Vector2(rr * 0.8, rr * 0.8), Vector2(rr * 0.6, rr * 0.6), Vector2(rr * 0.05, rr * 0.05)], 10), _skin_of("mycelia"))
				_mesh(pv2, CMesh.cyl(rr * 0.75, rr * 0.2, rr * 0.05, 10), _glow("mycelia", 1.6, 0.6), Transform3D(Basis(), Vector3(0, rr * 0.68, 0)))
				m.grows.append([pv2, Vector3.ONE])
			for i3 in rng.randi_range(4, 8):
				var tt4 := _v(0.15, 0.9)
				var a2 := _v(-1.2, 1.2)
				var pp := sp(tt4) + (sp_up * cos(a2) + Vector3(sin(a2), 0, 0)) * sp_r(tt4) * 0.97
				_mesh(m.body, CMesh.ball(sp_r(tt4) * 0.05, 8, 6), _glow("mycelia", 2.0, 0.8), Transform3D(Basis(), L(pp)))
		"aquora":
			# gill slits behind the head, fin frills on legs and arms
			for sx: float in [-1.0, 1.0]:
				for j in 3:
					var tt5 := 0.86 - j * 0.05
					var gp2 := sp(tt5) + Vector3(sx * sp_r(tt5) * 0.93, sp_r(tt5) * 0.15, 0)
					_mesh(m.body, CMesh.box(Vector3(sp_r(tt5) * 0.04, sp_r(tt5) * 0.45, sp_r(tt5) * 0.05)), _glow("aquora", 1.4, 0.7, 0.0, 0.0, Color(_k("aquora")["glow"]).darkened(0.3)), Transform3D(Basis(Vector3.FORWARD, sx * 0.2), L(gp2)))
			var fin := _skin_of("aquora", "membrane")
			var hosts: Array = []
			for l2: Dictionary in m.legs:
				hosts.append([l2["knee"], float(l2["l2"])])
			for a3: Dictionary in m.arms:
				hosts.append([a3["elbow"], r])
			for h: Array in hosts:
				var nd: Node3D = h[0]
				var ln := float(h[1])
				_mesh(nd, CMesh.membrane(Vector3(0, -ln * 0.15, -r * 0.05), [Vector3(0, -ln * 0.2, -r * 0.45), Vector3(0, -ln * 0.45, -r * 0.4), Vector3(0, -ln * 0.65, -r * 0.2)], 0.2), fin)
			if m.legs.is_empty() and m.arms.is_empty():
				for sx2: float in [-1.0, 1.0]:
					var root := sp(0.6) + Vector3(sx2 * sp_r(0.6) * 0.9, 0, 0)
					_mesh(m.body, CMesh.membrane(L(root), [L(root + Vector3(sx2 * r * 0.6, r * 0.3, -r * 0.2)), L(root + Vector3(sx2 * r * 0.8, -r * 0.1, -r * 0.5)), L(root + Vector3(sx2 * r * 0.5, -r * 0.4, -r * 0.7))], 0.2), fin)
			for mm: ShaderMaterial in [body_mat]:
				mm.set_shader_parameter("sheen", maxf(float(mm.get_shader_parameter("sheen")), 0.4))
		"verdis":
			# thorns along the spine and on the limbs, a few leaf tufts
			var bark := _skin_of("verdis")
			if owner["back"] != "verdis":
				for i4 in rng.randi_range(4, 7):
					var tt6 := lerpf(0.15, 0.9, float(i4) / 6.0)
					var sx3 := -1.0 if i4 % 2 == 0 else 1.0
					var b2 := top(tt6) + Vector3(sx3 * sp_r(tt6) * 0.4, 0, 0)
					var pv3 := _node(m.body, L(b2))
					_mesh(pv3, CMesh.horn(Vector3.ZERO, (sp_up + Vector3(sx3 * 0.5, 0, 0) - sp_dir * 0.4) * sp_r(tt6) * 0.6, sp_r(tt6) * 0.08), bark)
					m.grows.append([pv3, Vector3.ONE])
			for l3: Dictionary in m.legs:
				var kn: Node3D = l3["knee"]
				_mesh(kn, CMesh.horn(Vector3(0, -float(l3["l2"]) * 0.3, -r * 0.1), Vector3(0, -float(l3["l2"]) * 0.15, -r * 0.5), r * 0.07), bark)
		"ferrum":
			# iron bands with glowing seams around the limbs and the neck, and a furnace
			var hosts2: Array = []
			for l4: Dictionary in m.legs:
				hosts2.append([l4["hip"], float(l4["l1"]) * 0.5])
			for a4: Dictionary in m.arms:
				hosts2.append([a4["shoulder"], r * 0.5])
			for h2: Array in hosts2:
				var nd2: Node3D = h2[0]
				_mesh(nd2, CMesh.ring(r * 0.17, r * 0.24, 16), _metal("ferrum"), Transform3D(Basis(), Vector3(0, -float(h2[1]), 0)))
				_mesh(nd2, CMesh.ring(r * 0.15, r * 0.19, 16), _glow("ferrum", 2.5, 0.5), Transform3D(Basis(), Vector3(0, -float(h2[1]) - r * 0.06, 0)))
			if owner["back"] != "ferrum":
				_furnace()
			# heat cracks on the body glow (if the skin pattern is not already molten)
			if int(body_mat.get_shader_parameter("pattern")) != 3:
				var plate_p := sp(0.4) + sp_up * sp_r(0.4) * 0.7
				_mesh(m.body, CMesh.plate(sp_r(0.4) * 1.1, sp_r(0.4) * 1.2, sp_r(0.4) * 0.1, 0.4, 0.8), _metal("ferrum"), CMesh.along(L(plate_p), sp_up))
				_mesh(m.body, CMesh.box(Vector3(sp_r(0.4) * 0.9, sp_r(0.4) * 0.05, sp_r(0.4) * 0.03)), _glow("ferrum", 3.0, 0.5), CMesh.along(L(plate_p + sp_up * sp_r(0.4) * 0.06), sp_up))
		"voltara":
			# copper coils around the limbs, a conductive line along the spine; lightning jumps
			var hosts3: Array = []
			for l5: Dictionary in m.legs:
				hosts3.append([l5["knee"], float(l5["l2"]) * 0.4])
			for a5: Dictionary in m.arms:
				hosts3.append([a5["elbow"], r * 0.3])
			for h3: Array in hosts3:
				var nd3: Node3D = h3[0]
				for j4 in 3:
					_mesh(nd3, CMesh.ring(r * 0.1, r * 0.14, 12), _metal("voltara"), Transform3D(Basis(), Vector3(0, -float(h3[1]) - j4 * r * 0.06, 0)))
				var ap := _node(nd3, Vector3(0, -float(h3[1]), 0))
				m.arc_points.append(ap)
			var path2: Array = []
			var rad2: Array = []
			for j5 in 8:
				var tt7 := lerpf(0.1, 0.95, float(j5) / 7.0)
				path2.append(L(top(tt7) + sp_up * sp_r(tt7) * 0.06))
				rad2.append(Vector2(r * 0.03, r * 0.03))
			_mesh(m.body, CMesh.tube(path2, rad2, 6), _glow("voltara", 2.6, 0.4, 0.6))
			for tt8: float in [0.2, 0.9]:
				var ap2 := _node(m.body, L(top(tt8)))
				m.arc_points.append(ap2)
		"solara":
			# light organs along both flanks, crystal facets on the shoulders
			for sx4: float in [-1.0, 1.0]:
				var n := rng.randi_range(4, 6)
				for j6 in n:
					var tt9 := lerpf(0.2, 0.85, float(j6) / (n - 1))
					var p3 := sp(tt9) + Vector3(sx4 * sp_r(tt9) * 0.95, sp_r(tt9) * 0.1, 0)
					_mesh(m.body, CMesh.ball(sp_r(tt9) * 0.07, 10, 6), _glow("solara", 3.2, 0.5), Transform3D(Basis(), L(p3)))
			if owner["back"] != "solara" and owner["head"] != "solara":
				for sx5: float in [-1.0, 1.0]:
					var pv4 := _node(m.body, L(sp(0.8) + Vector3(sx5 * sp_r(0.8) * 0.7, sp_r(0.8) * 0.5, 0)))
					_mesh(pv4, CMesh.crystal(sp_r(0.8) * 0.6, sp_r(0.8) * 0.09, 5), _skin_of("solara", "skin_clear"), CMesh.along(Vector3.ZERO, Vector3(sx5, 1.0, -0.4)))
					m.grows.append([pv4, Vector3.ONE])


## Higher tiers: brass medallion and extra glowing marks (stronger creatures look it)
func _tier_marks() -> void:
	var p := sp(0.8) + Vector3(0, 0, sp_r(0.8) * 0.4) - sp_up * sp_r(0.8) * 0.2
	var out := Vector3(0, -0.2, 1).normalized()
	_mesh(m.body, CMesh.ring(sp_r(0.8) * 0.15, sp_r(0.8) * 0.22, 18), _metal(dom, "metal2"), CMesh.along(L(p + out * sp_r(0.8) * 0.6), out))
	_mesh(m.body, CMesh.cyl(sp_r(0.8) * 0.15, sp_r(0.8) * 0.15, 0.01, 16), _glow(dom, 2.5 + tier, 0.4), CMesh.along(L(p + out * sp_r(0.8) * 0.6), out))
	body_mat.set_shader_parameter("mark_glow", float(body_mat.get_shader_parameter("mark_glow")) + 0.6 * tier)


# ================================================================== elemental effects
func _fx(e: String) -> void:
	var host: Node3D = m.body
	for n: Node in m.body.find_children("*", "Node3D", true, false):
		if n.has_meta("fx_point") and str(n.get_meta("fx_point")) == e:
			host = n
			break
	var p := CPUParticles3D.new()
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(f["chest"]) * 1.2
	p.direction = Vector3.UP
	p.spread = 60.0
	p.gravity = Vector3.ZERO
	var col: Color = _k(e)["glow"]
	var add := true
	var sz := 0.035
	match e:
		"glacia":
			p.amount = 30
			p.lifetime = 2.5
			p.initial_velocity_min = 0.02
			p.initial_velocity_max = 0.12
			p.gravity = Vector3(0, -0.08, 0)
			col = Color(0.85, 0.95, 1.0, 0.9)
			sz = 0.025
		"mycelia":
			p.amount = 26
			p.lifetime = 3.5
			p.initial_velocity_min = 0.08
			p.initial_velocity_max = 0.25
			p.emission_sphere_radius = 0.06 if host != m.body else float(f["chest"])
			p.gravity = Vector3(0, 0.03, 0)
			sz = 0.03
		"aquora":
			p.amount = 24
			p.lifetime = 2.2
			p.emission_sphere_radius = float(f["chest"]) * 1.3
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.15
			p.tangential_accel_min = 0.4
			p.tangential_accel_max = 0.8
			col = Color(0.75, 0.95, 1.0, 0.7)
			sz = 0.03
		"ferrum":
			p.amount = 28
			p.lifetime = 1.6
			p.emission_sphere_radius = 0.05 if host != m.body else float(f["chest"])
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 0.7
			p.spread = 20.0
			sz = 0.025
			var smoke := CPUParticles3D.new()
			smoke.local_coords = false
			smoke.amount = 14
			smoke.lifetime = 2.5
			smoke.direction = Vector3.UP
			smoke.spread = 15.0
			smoke.initial_velocity_min = 0.2
			smoke.initial_velocity_max = 0.4
			smoke.scale_amount_min = 1.0
			smoke.scale_amount_max = 2.5
			smoke.mesh = Particles.soft_quad(0.18)
			smoke.material_override = Particles.material(Color(0.2, 0.18, 0.17, 0.45), false)
			host.add_child(smoke)
			m.fx["ferrum_smoke"] = smoke
		"voltara":
			p.amount = 16
			p.lifetime = 0.5
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.6
			p.spread = 180.0
			sz = 0.02
			var arcm := MeshInstance3D.new()
			arcm.mesh = ImmediateMesh.new()
			var am := StandardMaterial3D.new()
			am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			am.albedo_color = Color(_k("voltara")["glow"]).lerp(Color.WHITE, 0.5) if not umbra else CreatureLook.UMBRA_GLOW
			arcm.material_override = am
			m.add_child(arcm)
			m.arc_mesh = arcm
		"solara":
			p.amount = 24
			p.lifetime = 3.0
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.15
			p.gravity = Vector3(0, 0.04, 0)
			col = Color(1.0, 0.95, 0.8, 0.9)
			sz = 0.03
		"pebble":
			p.amount = 10
			p.lifetime = 2.0
			p.emission_sphere_radius = 0.04 if host != m.body else float(f["chest"])
			p.initial_velocity_min = 0.15
			p.initial_velocity_max = 0.3
			p.spread = 15.0
			p.scale_amount_min = 1.0
			p.scale_amount_max = 3.0
			col = Color(0.85, 0.85, 0.85, 0.35)
			add = false
			sz = 0.06
		"verdis":
			p.amount = 10
			p.lifetime = 4.0
			p.initial_velocity_min = 0.03
			p.initial_velocity_max = 0.1
			p.gravity = Vector3(0, -0.05, 0)
			col = Color(0.85, 1.0, 0.4, 0.8)
			sz = 0.025
	if umbra:
		col = Color(CreatureLook.UMBRA_GLOW, col.a)
	p.mesh = Particles.soft_quad(sz)
	p.material_override = Particles.material(col, add)
	host.add_child(p)
	m.fx[e] = p


# ================================================================== fewer draw calls
## Merges the parts that hang on the same joint and share a material into one mesh
## (a creature has hundreds of parts but only a few dozen meshes are drawn).
func _merge_static(root: Node3D) -> void:
	var groups := {}
	for c in root.get_children():
		if c is MeshInstance3D and c.get_child_count() == 0 and not ((c as MeshInstance3D).mesh is ImmediateMesh):
			var mi := c as MeshInstance3D
			var key := mi.material_override.get_instance_id() if mi.material_override else 0
			if not groups.has(key):
				groups[key] = []
			groups[key].append(mi)
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		for mi: MeshInstance3D in list:
			var xf := mi.transform
			var nb := xf.basis.inverse().transposed()
			for si in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(si)
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
		var first: MeshInstance3D = list[0]
		var merged := MeshInstance3D.new()
		merged.mesh = am
		merged.material_override = first.material_override
		root.add_child(merged)
		for mi2: MeshInstance3D in list:
			root.remove_child(mi2)
			mi2.free()
	for c2 in root.get_children():
		if c2 is Node3D and not (c2 is MeshInstance3D):
			_merge_static(c2)
