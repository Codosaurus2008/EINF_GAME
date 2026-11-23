class_name Xeno
extends RefCounted
## Xenobiology: builds alien organisms from "genes" (Biomes.SPECIES[...]["genes"]).
## Every species gets its own body plan - how it moves (legs, radial legs, crawling, hovering,
## wings, swimming, burrowing, climbing, rooted), its body shape, eyes, feeding organ, armour,
## see-through skin with organs inside, glowing markings and skin pattern.
##
## genes:
##   loc      legs | radial | crawl | hover | wing | swim | burrow | climb | sessile
##   body     orb | long | flat | disk | teardrop | asym | segmented
##   legs     number of leg pairs (legs) or legs around the body (radial)
##   joints   2 or 3 segments per leg       posture  high | low
##   eyes     how many    eye_layout  row | ring | cluster | stalks | cross | asym
##   mouth    proboscis | tendrils | fans | mandibles | lure | ring | none
##   armor    plates | spines | crystals | shell | none
##   extras   [sail, frills, antennae, tail, fans, vents, skirt, sac]
##   clear    see-through skin     organs  number of glowing inner organs
##   pattern  0..6  (see ExploreShaders.CREATURE)   colors [base, belly, mark, glow]

static var _mats := {}
static var _glow_base := {}     # material key -> glow strength of its markings in daylight


## Material for one part of a species
static func mat(id: String, g: Dictionary, part: String) -> Material:
	var key := id + "|" + part
	if _mats.has(key):
		return _mats[key]
	var cols: Array = g.get("colors", [Color.GRAY, Color.WHITE, Color.BLACK, Color.CYAN])
	var base: Color = cols[0]
	var belly: Color = cols[1]
	var mark: Color = cols[2]
	var glow: Color = cols[3]
	var m: Material
	match part:
		"skin":
			m = ExploreShaders.material("creature_clear" if bool(g.get("clear", false)) else "creature", {
				"base": base, "belly": belly, "mark": mark, "pattern": int(g.get("pattern", 0)),
				"pattern_scale": float(g.get("pattern_scale", 5.0)), "mark_glow": float(g.get("mark_glow", 0.0)),
				"alpha": 0.45, "rough": float(g.get("rough", 0.5)), "bumps": float(g.get("bumps", 0.3))})
			_glow_base[key] = float(g.get("mark_glow", 0.0))
		"limb":
			m = ExploreShaders.material("creature", {"base": base.darkened(0.25), "belly": belly.darkened(0.2), "mark": mark,
				"pattern": 3 if int(g.get("pattern", 0)) == 1 else 0, "pattern_scale": 8.0, "rough": 0.6, "bumps": 0.2})
		"armor":
			var ac: Color = g.get("armor_color", base.lightened(0.15))
			m = ExploreShaders.material("creature", {"base": ac, "belly": ac.darkened(0.3), "mark": ac.darkened(0.45),
				"pattern": 4, "pattern_scale": 3.0, "rough": 0.35, "metal": float(g.get("armor_metal", 0.25)), "bumps": 0.6})
		"membrane":
			m = ExploreShaders.material("creature_clear", {"base": glow.lerp(base, 0.5), "belly": glow, "mark": glow,
				"pattern": 5, "pattern_scale": 4.0, "mark_glow": 0.8, "alpha": 0.35, "rough": 0.3, "bumps": 0.1})
			_glow_base[key] = 0.8
		"eye":
			m = WorldProps.std(Color("#06070a"), 0.05, 0.4)
		"iris":
			m = WorldProps.std(glow, 0.2, 0.0, glow, 2.5)
		"glow":
			m = WorldProps.std(glow, 0.3, 0.0, glow, 3.0)
		"inner":
			m = WorldProps.std(mark.lerp(base, 0.3), 0.6, 0.0, mark, 0.4)
	_mats[key] = m
	return m


static func _p(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, scl: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return WorldProps.part(parent, mesh, m, pos, rot, scl)


## Glowing markings shine brighter at night (night 0..1)
static func set_night(night: float) -> void:
	for key: String in _glow_base:
		var m := _mats.get(key) as ShaderMaterial
		if m:
			m.set_shader_parameter("mark_glow", float(_glow_base[key]) * (0.5 + night * 1.5))


## Builds the organism into w.bob and fills w's animation lists. Returns the body height.
static func build(w: Wildlife, id: String, g: Dictionary, s: float, rng: RandomNumberGenerator) -> void:
	var loc := str(g.get("loc", "legs"))
	var body := str(g.get("body", "orb"))
	var skin := mat(id, g, "skin")
	var limb := mat(id, g, "limb")
	var sph := WorldProps.sphere(1.0, 18, 10)
	var low := str(g.get("posture", "high")) == "low"
	# how high the body is above the ground
	var h := s * 0.25
	match loc:
		"legs": h = s * (0.35 if low else 0.75)
		"radial": h = s * (0.25 if low else 0.45)
		"crawl", "burrow": h = s * 0.18
		"hover": h = s * 0.4
		"climb": h = s * 0.2
		"sessile": h = s * 0.6
		"wing", "swim": h = 0.0
	var core := Node3D.new()
	core.position = Vector3(0, h, 0)
	core.set_meta("h0", h)
	w.bob.add_child(core)
	w.set_meta("core", core)
	# ---------------- body
	var r := s * 0.5
	var front := Vector3(0, 0, r)
	match body:
		"orb":
			_p(core, sph, skin, Vector3.ZERO, Vector3(r, r * 0.85, r))
		"long":
			_p(core, sph, skin, Vector3.ZERO, Vector3(r * 0.55, r * 0.45, r * 1.2))
			_p(core, sph, skin, Vector3(0, 0.05 * r, -r * 0.9), Vector3(r * 0.45, r * 0.4, r * 0.7))
			front = Vector3(0, 0, r * 1.15)
		"flat":
			_p(core, sph, skin, Vector3.ZERO, Vector3(r * 1.05, r * 0.32, r * 1.15))
			front = Vector3(0, 0, r * 1.1)
		"disk":
			_p(core, sph, skin, Vector3.ZERO, Vector3(r * 1.25, r * 0.3, r * 1.25))
			_p(core, sph, skin, Vector3(0, r * 0.2, 0), Vector3(r * 0.6, r * 0.35, r * 0.6))
			front = Vector3(0, r * 0.1, r * 1.1)
		"teardrop":
			_p(core, sph, skin, Vector3(0, 0, r * 0.3), Vector3(r * 0.7, r * 0.65, r * 0.75))
			_p(core, WorldProps.cyl(r * 0.6, 0.02, r * 1.6, 14), skin, Vector3(0, 0, -r * 0.65), Vector3.ONE, Vector3(-PI / 2, 0, 0))
			front = Vector3(0, 0, r * 0.95)
		"asym":
			# one big lobe and a smaller one off to the side - it grows lopsided
			_p(core, sph, skin, Vector3(r * 0.15, 0, 0), Vector3(r * 0.8, r * 0.7, r * 0.9), Vector3(0, 0, 0.2))
			_p(core, sph, skin, Vector3(-r * 0.6, r * 0.25, -r * 0.2), Vector3(r * 0.45, r * 0.5, r * 0.55), Vector3(0.3, 0, -0.4))
			_p(core, sph, skin, Vector3(r * 0.5, -r * 0.1, r * 0.55), Vector3(r * 0.3, r * 0.3, r * 0.35))
			front = Vector3(r * 0.2, r * 0.1, r * 0.85)
		"segmented":
			var n := int(g.get("segments", 5))
			for i in n:
				var sg := Node3D.new()
				var rr := r * (0.55 - absf(i - n * 0.3) * 0.05)
				sg.position = Vector3(0, 0, r * 0.6 - i * r * 0.45)
				sg.set_meta("y0", 0.0)
				core.add_child(sg)
				w.segs.append(sg)
				_p(sg, sph, skin, Vector3.ZERO, Vector3(rr * 1.1, rr * 0.8, rr))
			front = Vector3(0, 0, r * 1.0)
	# ---------------- see-through body: organs and a frame of "bones" inside
	var organs := int(g.get("organs", 0))
	for i in organs:
		var o := _p(core, sph, mat(id, g, "glow"), Vector3(rng.randf_range(-0.3, 0.3) * r, rng.randf_range(-0.2, 0.25) * r, rng.randf_range(-0.5, 0.4) * r), Vector3.ONE * r * rng.randf_range(0.12, 0.22))
		w.organs.append([o, o.scale.x, float(i) * 1.3])
	if bool(g.get("clear", false)):
		for i in 3:
			_p(core, WorldProps.cyl(r * 0.03, r * 0.03, r * 1.5, 5), mat(id, g, "inner"), Vector3((i - 1) * r * 0.25, -r * 0.1, 0), Vector3.ONE, Vector3(PI / 2, 0, 0))
		_p(core, sph, mat(id, g, "inner"), Vector3(0, -r * 0.05, -r * 0.1), Vector3(r * 0.25, r * 0.2, r * 0.4))
	# ---------------- head with eyes and feeding organ
	var head := Node3D.new()
	head.position = front
	core.add_child(head)
	w.head = head
	_eyes(w, id, g, head, s, rng)
	_mouth(w, id, g, head, s, limb, skin)
	# ---------------- armour
	match str(g.get("armor", "none")):
		"plates":
			for i in 5:
				_p(core, WorldProps.sphere(1.0, 14, 6, true), mat(id, g, "armor"), Vector3(0, r * 0.3, r * 0.5 - i * r * 0.32), Vector3(r * 0.75, r * 0.4, r * 0.3), Vector3(-0.2 + i * 0.1, 0, 0))
		"spines":
			for i in 7:
				var sx := 1.0 if i % 2 == 0 else -1.0
				_p(core, WorldProps.cyl(0.0, r * 0.07, r * 0.8, 6), mat(id, g, "armor"), Vector3(sx * r * 0.2, r * 0.55, r * 0.5 - i * r * 0.2), Vector3.ONE, Vector3(-0.4, 0, -sx * 0.35))
		"crystals":
			for i in 6:
				_p(core, WorldProps.cyl(0.0, r * 0.1, r * rng.randf_range(0.5, 1.0), 6), mat(id, g, "glow") if bool(g.get("crystal_glow", false)) else mat(id, g, "armor"),
					Vector3(rng.randf_range(-0.4, 0.4) * r, r * 0.55, rng.randf_range(-0.5, 0.4) * r), Vector3.ONE, Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)))
		"shell":
			_p(core, WorldProps.sphere(1.0, 20, 8, true), mat(id, g, "armor"), Vector3(0, r * 0.1, -r * 0.05), Vector3(r * 1.0, r * 0.75, r * 1.1))
			for i in 4:
				_p(core, WorldProps.torus(r * (0.35 + i * 0.17), r * (0.39 + i * 0.17), 20), mat(id, g, "glow") if bool(g.get("shell_glow", false)) else limb,
					Vector3(0, r * (0.75 - i * 0.16), -r * 0.05), Vector3(1.0, 1.0, 1.1))
	# ---------------- extras
	var extras: Array = g.get("extras", [])
	if "sail" in extras:
		var sail := Node3D.new()
		sail.position = Vector3(0, r * 0.5, -r * 0.1)
		core.add_child(sail)
		_p(sail, sph, mat(id, g, "membrane"), Vector3(0, r * 0.45, 0), Vector3(r * 0.03, r * 0.5, r * 0.8))
		for i in 4:
			_p(sail, WorldProps.cyl(r * 0.015, r * 0.02, r * 0.9, 4), limb, Vector3(0, r * 0.4, r * 0.45 - i * r * 0.3), Vector3.ONE, Vector3(0.15 * (i - 1.5), 0, 0))
		w.wings.append([sail, 0.0, 9.0])
	if "frills" in extras:
		var fr := Node3D.new()
		fr.position = front - Vector3(0, 0, r * 0.2)
		core.add_child(fr)
		_p(fr, WorldProps.torus(r * 0.35, r * 0.7, 24), mat(id, g, "membrane"), Vector3.ZERO, Vector3(1.0, 0.25, 1.0), Vector3(PI / 2, 0, 0))
		w.wings.append([fr, 0.0, 7.0])
	if "antennae" in extras:
		for sx: float in [-1.0, 1.0]:
			var an := Node3D.new()
			an.position = front + Vector3(sx * r * 0.2, r * 0.25, 0)
			core.add_child(an)
			_p(an, WorldProps.cyl(r * 0.01, r * 0.025, r * 1.1, 4), limb, Vector3(0, r * 0.5, r * 0.15), Vector3.ONE, Vector3(0.3, 0, -sx * 0.3))
			for k in 4:
				_p(an, sph, mat(id, g, "membrane"), Vector3(sx * r * 0.06, r * (0.5 + k * 0.15), r * (0.22 + k * 0.05)), Vector3(r * 0.12, r * 0.02, r * 0.06))
			w.ears.append(an)
	if "tail" in extras:
		var tl := Node3D.new()
		tl.position = Vector3(0, 0, -r * 1.0)
		core.add_child(tl)
		for k in 5:
			_p(tl, sph, skin, Vector3(0, -k * r * 0.03, -k * r * 0.28), Vector3.ONE * r * (0.22 - k * 0.035))
		_p(tl, sph, mat(id, g, "glow"), Vector3(0, -r * 0.16, -r * 1.45), Vector3.ONE * r * 0.09)
		w.tail = tl
	if "fans" in extras:
		for sx: float in [-1.0, 1.0]:
			var fn := Node3D.new()
			fn.position = Vector3(sx * r * 0.6, r * 0.2, front.z * 0.5)
			core.add_child(fn)
			_p(fn, sph, mat(id, g, "membrane"), Vector3(sx * r * 0.35, r * 0.15, 0), Vector3(r * 0.45, r * 0.5, r * 0.03), Vector3(0, sx * 0.4, 0))
			w.wings.append([fn, sx, 3.0])
	if "vents" in extras:
		for i in 4:
			var sx2 := 1.0 if i % 2 == 0 else -1.0
			var vo := _p(core, WorldProps.torus(r * 0.07, r * 0.12, 10), mat(id, g, "glow"), Vector3(sx2 * r * 0.55, r * 0.05, r * 0.3 - (i / 2) * r * 0.5), Vector3.ONE, Vector3(0, 0, PI / 2))
			w.organs.append([vo, 1.0, float(i)])
	if "skirt" in extras:
		var sk := Node3D.new()
		sk.position = Vector3(0, -r * 0.2, 0)
		core.add_child(sk)
		_p(sk, WorldProps.torus(r * 0.8, r * 1.35, 32), mat(id, g, "membrane"), Vector3.ZERO, Vector3(1.0, 0.18, 1.0))
		w.wings.append([sk, 0.0, 5.0])
	if "sac" in extras:
		_p(core, sph, mat(id, g, "membrane"), Vector3(0, r * 0.9, -r * 0.1), Vector3(r * 0.75, r * 0.65, r * 0.8))
	# ---------------- locomotion
	match loc:
		"legs":
			_legs(w, id, g, core, s, r, limb, low)
		"radial":
			var n := int(g.get("legs", 6))
			for i in n:
				var a := TAU * i / n
				var hip := Node3D.new()
				hip.position = Vector3(cos(a) * r * 0.9, 0, sin(a) * r * 0.9)
				hip.rotation.y = -a + PI / 2
				core.add_child(hip)
				var l := h + r * 0.3
				_p(hip, WorldProps.cyl(r * 0.05, r * 0.08, l * 1.2, 6), limb, Vector3(0, -l * 0.35, r * 0.3), Vector3.ONE, Vector3(0.9, 0, 0))
				_p(hip, sph, limb, Vector3(0, -h, r * 0.65), Vector3(r * 0.09, r * 0.05, r * 0.12))
				w.legs.append([hip, float(i) * TAU / n * 2.0])
		"wing":
			var pairs := int(g.get("wings", 1))
			for p in pairs:
				for sx: float in [-1.0, 1.0]:
					var wg := Node3D.new()
					wg.position = Vector3(sx * r * 0.4, r * 0.15, r * (0.3 - p * 0.55))
					core.add_child(wg)
					_p(wg, sph, mat(id, g, "membrane"), Vector3(sx * r * 1.1, 0, -r * 0.1), Vector3(r * 1.2, r * 0.02, r * (0.55 - p * 0.1)), Vector3(0, sx * 0.25, 0))
					_p(wg, WorldProps.cyl(r * 0.02, r * 0.035, r * 2.2, 5), limb, Vector3(sx * r * 1.0, 0, r * 0.25), Vector3.ONE, Vector3(0, 0, PI / 2))
					w.wings.append([wg, sx, float(p) * 1.1])
		"swim":
			if str(g.get("fin", "ribbon")) == "jets":
				for i in 8:
					var a2 := TAU * i / 8.0
					var td := Node3D.new()
					td.position = Vector3(cos(a2) * r * 0.5, -r * 0.2, sin(a2) * r * 0.5)
					core.add_child(td)
					var l2 := s * rng.randf_range(0.8, 1.6)
					_p(td, WorldProps.cyl(r * 0.015, r * 0.05, l2, 4), mat(id, g, "membrane"), Vector3(0, -l2 * 0.5, 0), Vector3.ONE)
					w.tendrils.append([td, a2])
			else:
				for sx: float in [-1.0, 1.0]:
					for k in 3:
						var fn2 := Node3D.new()
						fn2.position = Vector3(sx * r * 0.5, 0, r * (0.5 - k * 0.5))
						core.add_child(fn2)
						_p(fn2, sph, mat(id, g, "membrane"), Vector3(sx * r * 0.45, 0, 0), Vector3(r * 0.5, r * 0.02, r * 0.28))
						w.wings.append([fn2, sx, float(k) * 0.9])
		"crawl", "burrow":
			if w.segs.is_empty():
				# slime foot: a soft skirt that ripples underneath
				var foot := Node3D.new()
				foot.position = Vector3(0, -h * 0.8, 0)
				core.add_child(foot)
				_p(foot, sph, limb, Vector3.ZERO, Vector3(r * 0.9, r * 0.12, r * 1.3))
				w.wings.append([foot, 0.0, 6.0])
			else:
				for i in w.segs.size():
					for sx: float in [-1.0, 1.0]:
						var pv := Node3D.new()
						pv.position = Vector3(sx * r * 0.4, -r * 0.1, 0)
						(w.segs[i] as Node3D).add_child(pv)
						_p(pv, WorldProps.cyl(r * 0.03, r * 0.05, r * 0.6, 5), limb, Vector3(sx * r * 0.2, -r * 0.2, 0), Vector3.ONE, Vector3(0, 0, sx * 0.9))
						w.legs.append([pv, i * 0.9 + (0.0 if sx < 0.0 else PI)])
		"climb":
			for i in 6:
				var a3 := TAU * i / 6.0
				var hp := Node3D.new()
				hp.position = Vector3(cos(a3) * r * 0.7, -r * 0.1, sin(a3) * r * 0.7)
				hp.rotation.y = -a3 + PI / 2
				core.add_child(hp)
				_p(hp, WorldProps.cyl(r * 0.04, r * 0.06, r * 0.7, 5), limb, Vector3(0, -r * 0.1, r * 0.3), Vector3.ONE, Vector3(1.2, 0, 0))
				_p(hp, sph, mat(id, g, "glow"), Vector3(0, -r * 0.2, r * 0.62), Vector3.ONE * r * 0.07)
				w.legs.append([hp, float(i) * PI])
		"sessile":
			# rooted: a stalk that holds a crown of feeding fronds
			_p(w.bob, WorldProps.cyl(r * 0.18, r * 0.3, h, 8), limb, Vector3(0, h * 0.5, 0), Vector3.ONE)
			for i in 9:
				var a4 := TAU * i / 9.0
				var fr2 := Node3D.new()
				fr2.position = Vector3(cos(a4) * r * 0.4, r * 0.3, sin(a4) * r * 0.4)
				core.add_child(fr2)
				_p(fr2, sph, mat(id, g, "membrane"), Vector3(cos(a4) * r * 0.45, r * 0.5, sin(a4) * r * 0.45), Vector3(r * 0.15, r * 0.6, r * 0.15), Vector3(-sin(a4) * 0.6, 0, cos(a4) * 0.6))
				w.tendrils.append([fr2, a4])
		"hover":
			for i in 7:
				var a5 := TAU * i / 7.0
				var td2 := Node3D.new()
				td2.position = Vector3(cos(a5) * r * 0.6, -r * 0.2, sin(a5) * r * 0.6)
				core.add_child(td2)
				var l3 := s * rng.randf_range(0.5, 1.1)
				_p(td2, WorldProps.cyl(r * 0.015, r * 0.04, l3, 4), limb, Vector3(0, -l3 * 0.5, 0), Vector3.ONE)
				w.tendrils.append([td2, a5])


## Legs with knees: pairs along the body, 2 or 3 segments, splayed outwards
static func _legs(w: Wildlife, id: String, g: Dictionary, core: Node3D, s: float, r: float, limb: Material, low: bool) -> void:
	var pairs := int(g.get("legs", 2))
	var joints := int(g.get("joints", 2))
	var h := core.position.y
	var different := bool(g.get("mixed_legs", false))    # front legs are grasping arms
	for i in pairs:
		var z := 0.0 if pairs == 1 else lerpf(r * 0.6, -r * 0.6, float(i) / (pairs - 1))
		var arm := different and i == 0
		for sx: float in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(sx * r * 0.45, 0, z)
			core.add_child(hip)
			var up_len := (h * 0.75 if not low else h * 1.2) * (0.7 if arm else 1.0)
			var spread := 0.8 if low else 0.45
			# upper segment goes out and up, the knee, then down to the ground
			_p(hip, WorldProps.cyl(r * 0.05, r * 0.08, up_len, 6), limb, Vector3(sx * up_len * 0.35, up_len * 0.3, 0), Vector3.ONE, Vector3(0, 0, -sx * (spread + 0.5)))
			var knee := Node3D.new()
			knee.position = Vector3(sx * up_len * 0.7, up_len * 0.55, 0)
			hip.add_child(knee)
			_p(knee, WorldProps.sphere(r * 0.07, 8, 4), limb, Vector3.ZERO, Vector3.ONE)
			var low_len := h + up_len * 0.55
			if arm:
				_p(knee, WorldProps.cyl(r * 0.02, r * 0.05, up_len, 5), limb, Vector3(0, -up_len * 0.2, up_len * 0.45), Vector3.ONE, Vector3(1.2, 0, 0))
				_p(knee, WorldProps.sphere(1.0, 8, 4), limb, Vector3(0, -up_len * 0.4, up_len * 0.9), Vector3(r * 0.06, r * 0.03, r * 0.1))
			elif joints >= 3:
				_p(knee, WorldProps.cyl(r * 0.035, r * 0.055, low_len * 0.6, 6), limb, Vector3(sx * r * 0.1, -low_len * 0.3, 0), Vector3.ONE, Vector3(0, 0, sx * 0.25))
				_p(knee, WorldProps.cyl(r * 0.02, r * 0.035, low_len * 0.5, 5), limb, Vector3(sx * r * 0.18, -low_len * 0.78, r * 0.08), Vector3.ONE, Vector3(0.25, 0, -sx * 0.1))
			else:
				_p(knee, WorldProps.cyl(r * 0.025, r * 0.05, low_len, 6), limb, Vector3(sx * r * 0.08, -low_len * 0.5, 0), Vector3.ONE, Vector3(0, 0, sx * 0.12))
			if not arm:
				var foot := Vector3(sx * r * 0.15, -low_len, 0)
				_p(knee, WorldProps.sphere(1.0, 8, 4), limb, foot, Vector3(r * 0.09, r * 0.04, r * 0.12))
				# toes with claws, spread like a hand on the ground
				var toes := 2 + int(g.get("toes", 1))
				for tq in toes:
					var ta := lerpf(-0.6, 0.6, float(tq) / maxf(toes - 1, 1))
					_p(knee, WorldProps.cyl(0.0, r * 0.022, r * 0.12, 4), limb, foot + Vector3(sin(ta) * r * 0.08, -r * 0.01, cos(ta) * r * 0.12),
						Vector3.ONE, Vector3(PI / 2 - 0.25, ta, 0))
			w.legs.append([hip, (i % 2) * PI + (0.0 if sx < 0.0 else PI)])
			w.set_meta("knees", w.get_meta("knees", []) + [knee])


static func _eyes(w: Wildlife, id: String, g: Dictionary, head: Node3D, s: float, rng: RandomNumberGenerator) -> void:
	var n := int(g.get("eyes", 2))
	if n <= 0:
		return
	var layout := str(g.get("eye_layout", "row"))
	var r := s * 0.5
	var er := r * float(g.get("eye_size", 0.12))
	var spots: Array = []
	match layout:
		"row":
			for i in n:
				spots.append(Vector3((i - (n - 1) * 0.5) * er * 2.4, r * 0.15, 0))
		"ring":
			for i in n:
				var a := TAU * i / n
				spots.append(Vector3(cos(a) * r * 0.35, r * 0.25 + sin(a) * r * 0.15, -r * 0.1))
		"cluster":
			for i in n:
				spots.append(Vector3(rng.randf_range(-0.25, 0.25) * r, rng.randf_range(0.05, 0.3) * r, rng.randf_range(-0.05, 0.05) * r))
		"cross":
			for i in n:
				var a2 := PI / 2 * i
				spots.append(Vector3(cos(a2) * r * 0.2 * (1 + i / 4), r * 0.2 + sin(a2) * r * 0.2, 0))
		"asym":
			for i in n:
				spots.append(Vector3(r * (0.25 - i * 0.12), r * (0.1 + i * 0.07), -i * r * 0.05))
		_:
			for i in n:
				spots.append(Vector3((i - (n - 1) * 0.5) * r * 0.3, r * 0.3, -r * 0.1))
	for i in spots.size():
		var p: Vector3 = spots[i]
		var e := Node3D.new()
		e.position = p
		head.add_child(e)
		var sz := er * (1.4 if layout == "asym" and i == 0 else 1.0)
		if layout == "stalks":
			_p(e, WorldProps.cyl(sz * 0.2, sz * 0.3, r * 0.5, 4), mat(id, g, "limb"), Vector3(0, r * 0.25, 0), Vector3.ONE)
			e.position += Vector3(0, 0, 0)
			_p(e, WorldProps.sphere(1.0, 10, 6), mat(id, g, "eye"), Vector3(0, r * 0.52, 0), Vector3.ONE * sz)
			_p(e, WorldProps.sphere(1.0, 8, 4), mat(id, g, "iris"), Vector3(0, r * 0.52, sz * 0.7), Vector3.ONE * sz * 0.45)
		else:
			_p(e, WorldProps.sphere(1.0, 10, 6), mat(id, g, "eye"), Vector3.ZERO, Vector3.ONE * sz)
			_p(e, WorldProps.sphere(1.0, 8, 4), mat(id, g, "iris"), Vector3(0, 0, sz * 0.72), Vector3(sz * 0.5, sz * 0.5, sz * 0.3))
		w.eyes.append(e)


static func _mouth(w: Wildlife, id: String, g: Dictionary, head: Node3D, s: float, limb: Material, skin: Material) -> void:
	var r := s * 0.5
	var mouth := Node3D.new()
	mouth.position = Vector3(0, -r * 0.15, r * 0.05)
	head.add_child(mouth)
	w.set_meta("mouth", mouth)
	match str(g.get("mouth", "none")):
		"proboscis":
			_p(mouth, WorldProps.cyl(r * 0.015, r * 0.06, r * 1.0, 6), limb, Vector3(0, -r * 0.25, r * 0.4), Vector3.ONE, Vector3(1.0, 0, 0))
		"tendrils":
			for i in 6:
				var a := TAU * i / 6.0
				var td := Node3D.new()
				td.position = Vector3(cos(a) * r * 0.12, sin(a) * r * 0.12, 0)
				mouth.add_child(td)
				_p(td, WorldProps.cyl(r * 0.01, r * 0.03, r * 0.5, 4), limb, Vector3(0, -r * 0.2, r * 0.1), Vector3.ONE, Vector3(0.6, 0, 0))
				w.tendrils.append([td, a])
		"fans":
			for sx: float in [-1.0, 1.0]:
				var fn := Node3D.new()
				fn.position = Vector3(sx * r * 0.15, 0, r * 0.05)
				mouth.add_child(fn)
				_p(fn, WorldProps.sphere(1.0, 12, 4), mat(id, g, "membrane"), Vector3(sx * r * 0.15, -r * 0.1, r * 0.15), Vector3(r * 0.25, r * 0.3, r * 0.02), Vector3(0, sx * 0.5, 0))
				w.wings.append([fn, sx, 2.0])
		"mandibles":
			for sx: float in [-1.0, 1.0]:
				var md := Node3D.new()
				md.position = Vector3(sx * r * 0.12, 0, r * 0.05)
				mouth.add_child(md)
				_p(md, WorldProps.cyl(r * 0.01, r * 0.04, r * 0.45, 5), mat(id, g, "armor"), Vector3(-sx * r * 0.05, 0, r * 0.2), Vector3.ONE, Vector3(PI / 2, 0, sx * 0.5))
				w.wings.append([md, sx, 4.0])
		"lure":
			_p(mouth, WorldProps.cyl(r * 0.01, r * 0.02, r * 0.8, 4), limb, Vector3(0, r * 0.55, r * 0.25), Vector3.ONE, Vector3(0.7, 0, 0))
			var bulb := _p(mouth, WorldProps.sphere(1.0, 10, 5), mat(id, g, "glow"), Vector3(0, r * 0.8, r * 0.6), Vector3.ONE * r * 0.1)
			w.organs.append([bulb, r * 0.1, 0.0])
		"ring":
			_p(mouth, WorldProps.torus(r * 0.08, r * 0.16, 16), mat(id, g, "glow"), Vector3(0, 0, r * 0.08), Vector3.ONE, Vector3(PI / 2, 0, 0))


# ================================================================== generated species
## Each planet's evolution: which ways of moving are common there, its colours, name sounds
## and how its life is adapted. Xeno.generate() builds new species from these rules.
const POOLS := {
	"pebble": {"loc": {"radial": 2, "legs": 3, "crawl": 2, "hover": 2, "burrow": 1, "sessile": 1},
		"armor": ["crystals", "plates", "shell", "none"], "clear": 0.2,
		"base": ["#6e6258", "#5a4a40", "#7a6a5a", "#4a4f50", "#8a5a3a"], "glow": ["#3fe0d0", "#ffb347", "#8fe8ff", "#ff7a3a"],
		"syl": ["kra", "tor", "grit", "ul", "zan", "rek", "mo", "vas", "dur"],
		"adapt": "In the weak gravity it needs very little strength and almost no food."},
	"glacia": {"loc": {"legs": 3, "hover": 2, "burrow": 1, "wing": 2, "crawl": 1, "sessile": 1, "radial": 1},
		"armor": ["shell", "crystals", "plates", "none"], "clear": 0.45,
		"base": ["#cfe6ff", "#7a9ad8", "#e8eef8", "#8a7ad0", "#4f8fb0"], "glow": ["#ff9a3a", "#5fd8ff", "#b07aff", "#4ff2e0"],
		"syl": ["ny", "vra", "kel", "iss", "oth", "ri", "sk", "yl", "frey"],
		"adapt": "Heat organs inside keep it alive in the deadly cold."},
	"mycelia": {"loc": {"radial": 2, "hover": 2, "crawl": 2, "legs": 2, "sessile": 2, "burrow": 1, "climb": 1},
		"armor": ["spines", "shell", "none", "crystals"], "clear": 0.5,
		"base": ["#c46fd8", "#2fa898", "#e08a2a", "#5a2a6a", "#e0407a", "#3a4ab0"], "glow": ["#4ff2ff", "#ff6fb7", "#ffc84a", "#7dffcf", "#9f8bff"],
		"syl": ["spo", "mu", "lo", "fae", "ri", "thi", "gul", "on", "myc"],
		"adapt": "Fungal spores live in its skin and help it digest."},
	"aquora": {"loc": {"swim": 4, "legs": 2, "crawl": 1, "climb": 1, "wing": 1, "hover": 1},
		"armor": ["shell", "none", "plates", "spines"], "clear": 0.4,
		"base": ["#2f6fae", "#3fa8a0", "#e2553f", "#f0d0c0", "#1a4a6a", "#6fd8ff"], "glow": ["#7ff5ff", "#e0aaff", "#ffd27a", "#4ff2c0"],
		"syl": ["ta", "lu", "ne", "mar", "ish", "oa", "ree", "quo", "sel"],
		"adapt": "It talks to others of its kind with flashes of light."},
	"verdis": {"loc": {"climb": 2, "wing": 2, "legs": 3, "crawl": 1, "sessile": 1, "radial": 1},
		"armor": ["none", "spines", "plates", "shell"], "clear": 0.15,
		"base": ["#3e8a3a", "#7a5a2a", "#2a4a1a", "#a04a2a", "#5a3a6a"], "glow": ["#d6ff6b", "#ffb13b", "#ff5fa8", "#3bd6ff"],
		"syl": ["vex", "ka", "ru", "li", "tha", "zo", "an", "ber", "qui"],
		"adapt": "Its colours hide it perfectly in the layers of the jungle."},
	"ferrum": {"loc": {"radial": 2, "legs": 2, "burrow": 2, "crawl": 2, "wing": 1, "sessile": 1},
		"armor": ["plates", "crystals", "shell", "spines"], "clear": 0.1,
		"base": ["#2a2220", "#3a302c", "#4a3a34", "#1a1614", "#5a4a40"], "glow": ["#ff6a1a", "#ffb347", "#ff4a1a", "#e0d040"],
		"syl": ["fer", "kh", "rag", "sul", "or", "dra", "mek", "ash", "tor"],
		"adapt": "Its body is lined with minerals that do not burn."},
	"voltara": {"loc": {"hover": 2, "wing": 2, "radial": 2, "legs": 2, "crawl": 1, "sessile": 1},
		"armor": ["spines", "crystals", "shell", "none"], "clear": 0.35,
		"base": ["#3a3850", "#4c4870", "#2a2a50", "#6a5ad8", "#1a2648"], "glow": ["#fff36b", "#9ff3ff", "#c48bff", "#5fe8ff"],
		"syl": ["vol", "zi", "tra", "ek", "on", "qua", "ri", "zz", "ark"],
		"adapt": "Insulating skin protects it from the lightning."},
	"solara": {"loc": {"radial": 2, "legs": 2, "hover": 2, "wing": 1, "burrow": 1, "sessile": 1},
		"armor": ["shell", "crystals", "none", "plates"], "clear": 0.35,
		"base": ["#f0e6d0", "#d89a40", "#c87a3a", "#fff4d0", "#e8c890"], "glow": ["#ffffff", "#ffd27a", "#ff9a3a", "#5ff0d8"],
		"syl": ["sol", "ae", "ri", "lux", "an", "pha", "ir", "el", "hel"],
		"adapt": "A mirror-like surface throws back the burning light."},
}

const NOUNS := {"legs": ["Strider", "Stalker", "Walker", "Grazer"], "radial": ["Wheel", "Star", "Disc", "Crown"],
	"crawl": ["Creeper", "Crawler", "Slider"], "hover": ["Drifter", "Bloom", "Float"], "wing": ["Glider", "Wing", "Kite"],
	"swim": ["Ribbon", "Pulser", "Finner"], "burrow": ["Delver", "Borer"], "climb": ["Clinger", "Climber"],
	"sessile": ["Polyp", "Anemone", "Fan"]}


static func _weighted(d: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in d:
		total += int(d[k])
	var r := rng.randi_range(1, total)
	for k in d:
		r -= int(d[k])
		if r <= 0:
			return str(k)
	return str(d.keys()[0])


static func _one(list: Array, rng: RandomNumberGenerator) -> Variant:
	return list[rng.randi() % list.size()]


## A new species for a planet, built by the planet's rules of evolution (same every time)
static func generate(planet_id: String, index: int) -> Dictionary:
	var pool: Dictionary = POOLS.get(planet_id, POOLS["pebble"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(planet_id) + index * 7919 + 13
	var loc := _weighted(pool["loc"], rng)
	if loc == "swim" and planet_id != "aquora":
		loc = "hover"
	# size class
	var roll := rng.randf()
	var size := rng.randf_range(0.6, 1.2)
	var tiny := false
	if roll < 0.18 and loc in ["crawl", "wing", "radial", "legs"]:
		size = rng.randf_range(0.15, 0.3)
		tiny = true
	elif roll < 0.5:
		size = rng.randf_range(0.3, 0.6)
	elif roll > 0.85 and loc != "wing":
		size = rng.randf_range(1.4, 2.4)
	var bodies := ["orb", "long", "flat", "disk", "teardrop", "asym", "segmented"]
	var body: String = _one(bodies, rng)
	if loc == "radial":
		body = _one(["disk", "orb", "flat"], rng)
	if loc in ["crawl", "burrow"] and rng.randf() < 0.6:
		body = "segmented"
	var base := Color(str(_one(pool["base"], rng)))
	var glow := Color(str(_one(pool["glow"], rng)))
	var mark := Color(str(_one(pool["glow"], rng))).lerp(base, 0.3) if rng.randf() < 0.5 else base.darkened(0.45)
	var clear := rng.randf() < float(pool["clear"]) and loc in ["hover", "swim", "wing", "radial", "crawl"]
	var g := {
		"loc": loc, "body": body, "legs": rng.randi_range(2, 3) if loc == "legs" else rng.randi_range(5, 9),
		"joints": rng.randi_range(2, 3), "posture": _one(["high", "low"], rng),
		"eyes": _one([0, 1, 2, 2, 3, 4, 5, 6, 8], rng), "eye_layout": _one(["row", "ring", "cluster", "stalks", "cross", "asym"], rng),
		"eye_size": rng.randf_range(0.06, 0.16),
		"mouth": _one(["proboscis", "tendrils", "fans", "mandibles", "lure", "ring", "none"], rng),
		"armor": _one(pool["armor"], rng), "clear": clear, "organs": rng.randi_range(0, 4) if clear else rng.randi_range(0, 2),
		"segments": rng.randi_range(4, 8), "mixed_legs": loc == "legs" and rng.randf() < 0.3,
		"wings": rng.randi_range(1, 3), "fin": _one(["ribbon", "jets"], rng),
		"pattern": rng.randi_range(0, 6), "pattern_scale": rng.randf_range(2.5, 8.0), "mark_glow": rng.randf_range(0.0, 0.8),
		"crystal_glow": rng.randf() < 0.5, "shell_glow": rng.randf() < 0.4,
		"colors": [base, base.lightened(0.3).lerp(glow, 0.1), mark, glow],
		"toes": rng.randi_range(0, 2), "bumps": rng.randf_range(0.1, 0.9), "rough": rng.randf_range(0.25, 0.85), "armor_metal": rng.randf_range(0.0, 0.6),
		"armor_color": base.lerp(Color(str(_one(pool["base"], rng))), 0.6).darkened(rng.randf_range(0.0, 0.3)),
	}
	var extras: Array = []
	for e: String in ["sail", "frills", "antennae", "tail", "fans", "vents", "skirt", "sac"]:
		if rng.randf() < 0.2:
			extras.append(e)
	if loc == "hover" and not ("sac" in extras):
		extras.append("sac")
	g["extras"] = extras
	# name
	var syl: Array = pool["syl"]
	var nm := ""
	for i in rng.randi_range(2, 3):
		nm += str(_one(syl, rng))
	nm = nm.capitalize().replace(" ", "")
	var noun: String = _one(NOUNS.get(loc, ["Creature"]), rng)
	var sp_name := "%s %s" % [nm, noun]
	# description and traits from its biology
	var body_txt: String = {"orb": "a round body", "long": "a long, low body", "flat": "a flat body", "disk": "a disc-shaped body",
		"teardrop": "a teardrop-shaped body", "asym": "a lopsided body that grows more on one side",
		"segmented": "a body of %d segments" % int(g["segments"])}[body]
	var move_txt: String = {"legs": "walks on %d legs with %d joints each" % [int(g["legs"]) * 2, int(g["joints"])],
		"radial": "walks on %d legs in a circle and has no front or back" % int(g["legs"]),
		"crawl": "glides along on a muscular foot", "hover": "floats with a sac of light gas",
		"wing": "flies with %d pair%s of membrane wings" % [int(g["wings"]), "s" if int(g["wings"]) > 1 else ""],
		"swim": "swims with rippling fins" if g["fin"] == "ribbon" else "swims by squeezing water out of its bell",
		"burrow": "digs through the ground and comes up to feed", "climb": "climbs trees and rock spires with suction feet",
		"sessile": "stays rooted to one spot"}[loc]
	var feed_txt: String = {"proboscis": "probes for food with a long mouth tube", "tendrils": "catches food with a ring of tendrils",
		"fans": "filters food out of the air with two fans", "mandibles": "cuts its food with two mandibles",
		"lure": "lures small prey with a glowing bulb", "ring": "grinds its food with a ring-shaped mouth",
		"none": "takes in nutrients through its skin"}[str(g["mouth"])]
	var eyes := int(g["eyes"])
	var eye_txt := "It has no eyes and feels its way" if eyes == 0 else "%d eye%s in a %s" % [eyes, "s" if eyes > 1 else "",
		{"row": "row", "ring": "ring", "cluster": "cluster", "stalks": "row on stalks", "cross": "cross", "asym": "lopsided row"}[str(g["eye_layout"])]]
	var armor_txt: String = {"plates": "Armour plates cover its back.", "spines": "Spines protect its back.", "crystals": "Mineral crystals grow out of its back.",
		"shell": "It carries a hard shell.", "none": ""}[str(g["armor"])]
	var night := rng.randf() < 0.2
	var predator := size > 0.6 and str(g["mouth"]) in ["mandibles", "lure", "ring"] and rng.randf() < 0.4 and loc != "sessile"
	var rare := rng.randf() < 0.12
	var desc := "It has %s and %s. It %s. %s %s" % [body_txt, move_txt, feed_txt, armor_txt, pool["adapt"]]
	var traits: Array = [move_txt.capitalize().substr(0, 1) + move_txt.substr(1), eye_txt]
	if clear:
		traits.append("See-through skin shows %d glowing organs" % int(g["organs"]))
	elif armor_txt != "":
		traits.append(armor_txt.trim_suffix("."))
	if night:
		traits.append("Only active at night")
	if predator:
		traits.append("Predator")
	if rare:
		traits.append("Rare")
	var sp := {"name": sp_name, "plan": "xeno", "size": size, "speed": rng.randf_range(0.5, 2.4) if loc != "sessile" else 0.0,
		"curious": rng.randf() < 0.5, "color": base, "accent": glow, "glow": true, "genes": g, "desc": desc, "traits": traits,
		"night": night, "predator": predator, "rare": rare, "signals": int(g["organs"]) > 0 and rng.randf() < 0.6,
		"weight": 1 if rare else (6 if tiny else (1 if size > 1.3 else 3))}
	# where it lives: a colour zone of the planet and maybe a height / plant preference
	var tconf: Dictionary = Biomes.get_biome(planet_id)["terrain"]
	var zlist: Array = tconf.get("zones", [0])
	var zc := zlist.size()
	sp["home_zone"] = index % maxi(zc, 1)
	if loc != "swim":
		sp["zone"] = str(_one(["any", "any", "high", "low", "forest"], rng))
	var zone_txt := {"any": "", "high": " It prefers high ground.", "low": " It keeps to the lowlands.", "forest": " It lives among the plants."}
	sp["desc"] = str(sp["desc"]) + str(zone_txt.get(str(sp.get("zone", "any")), ""))
	if tiny:
		sp["swarm"] = rng.randi_range(4, 8)
	if loc == "hover":
		sp["hover"] = rng.randf_range(1.0, 3.0)
	if loc == "swim":
		sp["depth"] = rng.randf_range(0.4, 2.0)
		sp["leaps"] = rng.randf() < 0.4
	if predator:
		sp["carry_note"] = "It is a hunter - better not."
	return sp
