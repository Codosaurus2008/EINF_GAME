class_name CreatureArt2D
extends RefCounted
## The 2D version of the creature designs (for comparison with the 3D one): drawn with
## shapes in side view, with outlines, cel shading (shadow side, lit side, highlight), the
## same colour regions, the same body parts per element and the same hybrid rules as the 3D
## creatures (CreatureLook.design). Animated: breathing, walking legs, swaying tail and
## antennae, flapping wings, attack lunge.

static var _cache := {}

# drawing state for the current creature
var ci: CanvasItem
var g := Vector2.ZERO          # ground point under the creature (screen)
var k := 1.0                   # pixels per unit
var fc := 1.0                  # facing
var t := 0.0
var pose := "idle"
var d := {}                    # design + numbers
var lw := 1.5                  # outline width


static func draw(canvas: CanvasItem, u: Dictionary, c: Vector2, r: float, tm: float, facing: float, pose_name: String) -> void:
	var a := CreatureArt2D.new()
	a.ci = canvas
	a.g = c + Vector2(0, r * 0.95)
	a.fc = facing
	a.t = tm + float(u.get("id", 0)) * 0.37
	a.pose = pose_name if pose_name != "" else "idle"
	a.d = _design(u)
	a.k = r * float(a.d["scale"])
	a.lw = clampf(r * 0.07, 1.2, 4.0)
	a._draw_all()


static func _design(u: Dictionary) -> Dictionary:
	var species: Array = u["species"]
	var umbra := bool(u.get("umbra", false))
	var key := "%s|%s|%s" % [str(u.get("id", 0)), ",".join(species), str(umbra)]
	if _cache.has(key):
		return _cache[key]
	var de := CreatureLook.design(species, int(u.get("id", 0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(u.get("id", 0)) * 104729 + hash(str(species)) + 3
	var dom: String = de["dom"]
	var fr: Dictionary = CreatureLook.kit(dom)["frame"]
	var out := de.duplicate()
	out["umbra"] = umbra
	out["rng_seed"] = rng.randi()
	out["len"] = float(fr["len"]) * rng.randf_range(0.9, 1.1)
	out["hip_h"] = float(fr["hip_h"]) * rng.randf_range(0.92, 1.08)
	var girth := 1.0
	for e: String in species:
		if e != dom:
			girth *= lerpf(1.0, float(CreatureLook.kit(e)["girth"]), 0.6)
	for key2: String in ["chest", "waist", "hip"]:
		out[key2] = float(fr[key2]) * girth * rng.randf_range(0.92, 1.08)
	out["tilt"] = deg_to_rad(float(fr["tilt"]) + rng.randf_range(-5, 5))
	out["hunch"] = float(fr["hunch"])
	out["legs"] = str(CreatureLook.kit(dom)["legs"])
	out["n_spines"] = rng.randi_range(5, 8)
	out["n_eyes"] = rng.randi_range(4, 7)
	out["asym"] = -1.0 if rng.randf() < 0.5 else 1.0
	for role: String in ["body", "belly", "head", "limb", "armor", "horn", "fin", "accent"]:
		out["c_" + role] = CreatureLook.region(de, role, umbra)
	var hgt := float(out["hip_h"]) + float(out["chest"]) * 1.6 + 0.3
	var wid := float(out["len"]) + float(out["chest"]) * 2.0 + 0.6
	out["scale"] = 1.9 / maxf(hgt, wid * 0.62)
	_cache[key] = out
	return out


# ================================================================== helpers
func P(x: float, y: float) -> Vector2:
	return g + Vector2(x * fc, -y) * k


func _col(e: String, role: String) -> Color:
	var c := CreatureLook.pal(e, role)
	if bool(d["umbra"]):
		c = c.lerp(CreatureLook.UMBRA_SKIN, 0.55)
	return c


func _glowc(e: String) -> Color:
	return CreatureLook.UMBRA_GLOW if bool(d["umbra"]) else Color(CreatureLook.kit(e)["glow"])


## A filled shape with cel shading: shadow colour underneath, lit colour shifted up,
## a small highlight, and a dark outline
func shape(pts: PackedVector2Array, col: Color, shade := true) -> void:
	if pts.size() < 3:
		return
	var outl := col.darkened(0.78)
	ci.draw_colored_polygon(pts, col.darkened(0.32) if shade else col)
	if shade:
		var cen := Vector2.ZERO
		for p in pts:
			cen += p
		cen /= pts.size()
		var lit := PackedVector2Array()
		for p in pts:
			lit.append(cen + (p - cen) * 0.86 + Vector2(-0.5, -1.0) * k * 0.035)
		ci.draw_colored_polygon(lit, col)
		var hi := PackedVector2Array()
		for p in pts:
			hi.append(cen + (p - cen) * 0.4 + Vector2(-0.6, -1.0) * k * 0.09)
		ci.draw_colored_polygon(hi, col.lightened(0.25))
	var ring := pts.duplicate()
	ring.append(pts[0])
	ci.draw_polyline(ring, outl, lw, true)


func ellipse(c: Vector2, rx: float, ry: float, rot := 0.0, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


## A limb segment from a to b (screen), tapering from ra to rb pixels, rounded ends
func seg(a: Vector2, b: Vector2, ra: float, rb: float, col: Color) -> void:
	var dir := (b - a)
	if dir.length() < 0.5:
		return
	var n := dir.normalized().orthogonal()
	var pts := PackedVector2Array([a + n * ra, b + n * rb, b - n * rb, a - n * ra])
	ci.draw_circle(a, ra + lw * 0.5, col.darkened(0.78))
	ci.draw_circle(b, rb + lw * 0.5, col.darkened(0.78))
	ci.draw_colored_polygon(pts, col.darkened(0.25))
	var lit := PackedVector2Array([a + n * ra * 0.9, b + n * rb * 0.9, b - n * rb * 0.1, a - n * ra * 0.1])
	ci.draw_colored_polygon(lit, col)
	ci.draw_circle(a, ra, col.darkened(0.1))
	ci.draw_circle(b, rb, col.darkened(0.1))
	ci.draw_line(a + n * ra, b + n * rb, col.darkened(0.78), lw, true)
	ci.draw_line(a - n * ra, b - n * rb, col.darkened(0.78), lw, true)


func spike(base: Vector2, tip: Vector2, w: float, col: Color) -> void:
	var n := (tip - base).normalized().orthogonal() * w
	shape(PackedVector2Array([base + n, tip, base - n]), col, false)


func glow_dot(p: Vector2, rad: float, col: Color) -> void:
	Art.glow(ci, p, rad * 3.0, col, 0.35)
	ci.draw_circle(p, rad, col.lightened(0.4))


## Body geometry (unit space): spine point, its "up" and its radius at 0..1 (rear .. front)
func sp(tt: float) -> Vector2:
	var tilt := float(d["tilt"])
	var lng := float(d["len"])
	var start := Vector2(-lng * cos(tilt) * 0.5, float(d["hip_h"]))
	var up := Vector2(-sin(tilt), cos(tilt))
	return start + Vector2(cos(tilt), sin(tilt)) * lng * tt + up * (float(d["chest"]) * 0.15 * sin(PI * tt) + float(d["hunch"]) * tt * tt)


func sp_up() -> Vector2:
	var tilt := float(d["tilt"])
	return Vector2(-sin(tilt), cos(tilt))


func sp_r(tt: float) -> float:
	var keys: Array = [[0.0, float(d["hip"]) * 0.5], [0.2, float(d["hip"])], [0.5, float(d["waist"])], [0.8, float(d["chest"])], [1.0, float(d["chest"]) * 0.62]]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if tt <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), smoothstep(0.0, 1.0, (tt - float(a[0])) / (float(b[0]) - float(a[0]))))
	return float(d["chest"]) * 0.62


func U(v: Vector2) -> Vector2:
	return P(v.x, v.y)


# ================================================================== the creature
func _draw_all() -> void:
	var breath := sin(t * 1.8) * 0.012
	var lunge := 0.0
	if pose == "attack":
		lunge = 0.12
	var walk := pose in ["walk", "run"]
	var bob := breath + (absf(sin(t * 7.0)) * 0.02 if walk else 0.0)
	var hover := 0.0
	if str(d["legs"]) in ["flipper4", "talons", "petals"]:
		hover = sin(t * 1.4) * 0.05
	# move the whole body (legs re-solve to the ground)
	var shift := Vector2(lunge, bob + hover)
	_back_wings(shift, true)
	_legs(shift, true)
	_tail(shift)
	_body(shift)
	_back(shift)
	_infusions(shift)
	_legs(shift, false)
	_arms(shift)
	_head(shift)
	_back_wings(shift, false)


func _body(sh: Vector2) -> void:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var up := sp_up()
	var n := 14
	for i in n + 1:
		var tt := float(i) / n
		var s := sp(tt) + sh
		var r := sp_r(tt)
		top.append(U(s + up * r))
		bot.append(U(s - up * r * 0.85))
	var pts := PackedVector2Array()
	pts.append_array(top)
	# rounded front
	var f := sp(1.0) + sh
	for j in range(1, 5):
		var a := PI * 0.5 - PI * j / 5.0
		pts.append(U(f + (up * sin(a) + Vector2(cos(a), 0)) * sp_r(1.0)))
	for i2 in range(n, -1, -1):
		pts.append(bot[i2])
	var b0 := sp(0.0) + sh
	for j2 in range(1, 5):
		var a2 := -PI * 0.5 - PI * j2 / 5.0
		pts.append(U(b0 + (up * sin(a2) + Vector2(cos(a2), 0)) * sp_r(0.0)))
	var body_c: Color = d["c_body"]
	shape(pts, body_c)
	# belly band
	var belly := PackedVector2Array()
	for i3 in range(2, n - 1):
		var tt2 := float(i3) / n
		belly.append(U(sp(tt2) + sh - up * sp_r(tt2) * 0.25))
	for i4 in range(n - 2, 1, -1):
		var tt3 := float(i4) / n
		belly.append(U(sp(tt3) + sh - up * sp_r(tt3) * 0.78))
	ci.draw_colored_polygon(belly, d["c_belly"])
	# pattern marks from the accent element
	var acc: String = d["accent"]
	var mk := CreatureLook.pal(acc, "dark").lerp(body_c, 0.3)
	var pat := int(CreatureLook.kit(acc)["pattern"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d["rng_seed"])
	for i5 in 6:
		var tt4 := rng.randf_range(0.15, 0.85)
		var p := U(sp(tt4) + sh + up * sp_r(tt4) * rng.randf_range(0.2, 0.7))
		match pat:
			1, 3, 9:
				glow_dot(p, k * 0.03, _glowc(acc))
			2, 6:
				ci.draw_line(p, p + Vector2(0, k * 0.12), mk, lw * 1.4, true)
			_:
				ci.draw_circle(p, k * rng.randf_range(0.025, 0.05), mk)
	# the outline again on top (belly and marks stay inside)
	var ring := pts.duplicate()
	ring.append(pts[0])
	ci.draw_polyline(ring, body_c.darkened(0.78), lw, true)


# ---------------------------------------------------------------- legs
func _legs(sh: Vector2, far: bool) -> void:
	var kind := str(d["legs"])
	var col: Color = d["c_limb"]
	if far:
		col = col.darkened(0.3)
	var walk := pose in ["walk", "run"]
	var sp_speed := 7.0 if pose == "run" else 4.5
	match kind:
		"stout4", "pillar2", "stilt2", "insect6":
			var mounts: Array = []
			match kind:
				"stout4": mounts = [[0.82, 0.0], [0.15, 0.5]]
				"pillar2", "stilt2": mounts = [[0.06, 0.0]]
				"insect6": mounts = [[0.22, 0.0], [0.5, 0.5], [0.78, 0.0]]
			for mnt: Array in mounts:
				var tt := float(mnt[0])
				var ph := float(mnt[1]) + (0.5 if far else 0.0)
				var hip := sp(tt) + sh - sp_up() * sp_r(tt) * 0.35
				var foot := Vector2(sp(tt).x + (0.08 if kind == "insect6" and tt > 0.5 else 0.0), 0.0)
				if kind == "insect6":
					foot.x += (tt - 0.5) * 0.6
				if walk:
					var u := fposmod(t * sp_speed / TAU + ph, 1.0)
					var s := 0.16
					if u < 0.6:
						foot.x += lerpf(s, -s, u / 0.6)
					else:
						var w := (u - 0.6) / 0.4
						foot.x += lerpf(-s, s, w)
						foot.y += 0.1 * sin(w * PI)
				var l := hip.y * (0.62 if kind != "insect6" else 0.75)
				var knee := _knee(hip, foot, l, l * (1.0 if kind != "insect6" else 0.9), -1.0 if kind in ["stilt2"] else (1.0 if kind != "insect6" else 1.0), kind == "insect6")
				var thick := sp_r(tt) * (0.34 if kind == "stout4" else (0.4 if kind == "pillar2" else (0.18 if kind == "stilt2" else 0.1)))
				var mat: Color = col
				if kind == "pillar2":
					mat = _col("ferrum", "armor").lightened(0.2) if not far else _col("ferrum", "armor")
				seg(U(hip), U(knee), thick * k, thick * k * 0.75, mat)
				seg(U(knee), U(foot + Vector2(0, 0.02)), thick * k * 0.7, thick * k * 0.45, mat)
				var fp := U(foot)
				match kind:
					"stout4":
						for i in 3:
							spike(fp + Vector2((i - 1) * thick * k * 0.5 * fc, 0), fp + Vector2(((i - 1) * 0.4 + 0.9) * thick * k * fc, thick * k * 0.15), thick * k * 0.18, d["c_horn"])
					"stilt2":
						for i2 in 3:
							spike(fp, fp + Vector2(((i2 - 1) * 0.6 + 1.2) * k * 0.12 * fc, 0), k * 0.015, d["c_horn"])
					"pillar2":
						shape(PackedVector2Array([fp + Vector2(-thick * k * 0.9, 0), fp + Vector2(-thick * k * 0.7, -thick * k * 0.5), fp + Vector2(thick * k * 1.3 * fc, -thick * k * 0.5), fp + Vector2(thick * k * 1.5 * fc, 0)]), mat)
						ci.draw_circle(U(knee), thick * k * 0.55, _col("ferrum", "horn"))
		"roots":
			var n := 5
			for i3 in n:
				if (i3 % 2 == 0) != far:
					continue
				var tt2 := lerpf(0.15, 0.85, float(i3) / (n - 1))
				var a := sp(tt2) + sh - sp_up() * sp_r(tt2) * 0.6
				var prev := U(a)
				for j in 4:
					var kk := float(j + 1) / 4.0
					var p := Vector2(a.x + sin(t * 2.2 + i3 + j) * 0.05 * kk + (tt2 - 0.5) * 0.2 * kk, a.y * (1.0 - kk))
					var q := U(p)
					seg(prev, q, k * sp_r(tt2) * 0.14 * (1.1 - kk * 0.5), k * sp_r(tt2) * 0.14 * (1.0 - kk * 0.6), col)
					prev = q
				glow_dot(prev, k * 0.02, _glowc("mycelia"))
		"flipper4":
			for tt3: float in [0.2, 0.78]:
				var root := sp(tt3) + sh - sp_up() * sp_r(tt3) * 0.3
				var a2 := sin(t * 2.4 + tt3 * 3.0 + (PI if far else 0.0)) * 0.4
				var tip := root + Vector2(-0.25, -0.3).rotated(a2) * sp_r(tt3) * 2.0
				var fin: Color = d["c_fin"]
				if far:
					fin = fin.darkened(0.3)
				shape(PackedVector2Array([U(root), U(tip + Vector2(0.12, 0)), U(tip - Vector2(0.15, 0.05)), U(root - Vector2(0.15, 0))]), fin, false)
				ci.draw_line(U(root), U(tip), Color(fin).darkened(0.5), lw * 0.8, true)
		"talons":
			for tt4: float in [0.25]:
				var root2 := sp(tt4) + sh - sp_up() * sp_r(tt4) * 0.6
				var a3 := sin(t * 1.6 + (1.0 if far else 0.0)) * 0.15
				var kn := root2 + Vector2(0.05 + (0.06 if far else 0.0), -float(d["hip_h"]) * 0.28).rotated(a3)
				var ft := kn + Vector2(0.08, -float(d["hip_h"]) * 0.22).rotated(a3 * 1.5)
				seg(U(root2), U(kn), k * 0.04, k * 0.03, col)
				seg(U(kn), U(ft), k * 0.03, k * 0.02, col)
				for i4 in 3:
					spike(U(ft), U(ft + Vector2(0.06 + i4 * 0.02, -0.04 * (i4 - 1))), k * 0.012, d["c_horn"])
		"petals":
			if far:
				return
			for i5 in 5:
				var a4 := lerpf(-0.9, 0.9, float(i5) / 4.0) + sin(t * 0.8 + i5) * 0.05
				var b := sp(0.05) + sh
				var tip2 := b + Vector2(sin(a4) * 0.35, -float(d["hip_h"]) * 0.75)
				spike(U(b), U(tip2), k * 0.05, _col("solara", "armor"))
				glow_dot(U(tip2), k * 0.025, _glowc("solara"))


## The knee of a two-part leg from hip to foot (unit space), bending forward or back
func _knee(hip: Vector2, foot: Vector2, l1: float, l2: float, bend: float, up := false) -> Vector2:
	var v := foot - hip
	var dl := clampf(v.length(), 0.01, (l1 + l2) * 0.999)
	var a := acos(clampf((l1 * l1 + dl * dl - l2 * l2) / (2.0 * l1 * dl), -1.0, 1.0))
	var dir := v.normalized().rotated(a * bend * (-1.0 if up else 1.0))
	if up:
		dir = v.normalized().rotated(-a)
		if dir.y < v.normalized().y:
			dir = v.normalized().rotated(a)
	return hip + dir * l1


# ---------------------------------------------------------------- tail
func _tail(sh: Vector2) -> void:
	var e: String = d["owner"]["tail"]
	var base := sp(0.02) + sh
	var dir := -Vector2(cos(float(d["tilt"])), sin(float(d["tilt"]))) * 0.85 - sp_up() * 0.25
	var lng := float(d["len"]) * 0.8
	var r := sp_r(0.08) * 0.55
	var col: Color = d["c_body"] if e == str(d["dom"]) else _col(e, "body")
	match e:
		"mycelia", "solara":
			for i in 3:
				var prev := U(base)
				var dd := dir.rotated((i - 1) * 0.35)
				for j in 5:
					var kk := float(j + 1) / 5.0
					var p := base + dd * lng * kk + Vector2(0, sin(t * 2.0 - j * 0.7 + i) * 0.06 * kk)
					var q := U(p)
					if e == "solara":
						ci.draw_line(prev, q, Color(_glowc("solara"), 0.9 - kk * 0.5), k * 0.05 * (1.0 - kk * 0.6), true)
					else:
						seg(prev, q, k * r * 0.25 * (1.0 - kk * 0.5), k * r * 0.2 * (1.0 - kk * 0.6), _col("mycelia", "limb"))
					prev = q
				glow_dot(prev, k * 0.025, _glowc(e))
			return
	var pts: Array = []
	for j2 in 8:
		var kk2 := float(j2) / 7.0
		pts.append(base + dir * lng * kk2 + Vector2(0, sin(t * 1.6 - j2 * 0.5) * 0.05 * kk2))
	for j3 in 7:
		var a: Vector2 = pts[j3]
		var b: Vector2 = pts[j3 + 1]
		var ra := r * (1.0 - float(j3) / 7.0 * 0.75)
		var rb := r * (1.0 - float(j3 + 1) / 7.0 * 0.75)
		var c := col if e != "ferrum" else _col("ferrum", "armor").lightened(0.15)
		seg(U(a), U(b), ra * k, rb * k, c)
		if e == "ferrum":
			ci.draw_circle(U(b), rb * k * 0.6, _glowc("ferrum"))
		if e == "voltara" and j3 % 2 == 1:
			ci.draw_arc(U(a), ra * k * 1.1, 0, TAU, 12, _col("voltara", "armor"), lw, true)
	var tip: Vector2 = pts[7]
	var p6: Vector2 = pts[6]
	var tdir: Vector2 = (tip - p6).normalized()
	match e:
		"pebble":
			shape(ellipse(U(tip), r * k * 0.9, r * k * 0.75), _col("pebble", "armor"))
			for i2 in 3:
				spike(U(tip), U(tip + tdir.rotated((i2 - 1) * 0.9) * r * 1.6), k * r * 0.2, _col("pebble", "horn"))
		"glacia":
			spike(U(tip - tdir * 0.02), U(tip + tdir * r * 3.0), k * r * 0.45, _col("glacia", "armor"))
		"aquora":
			var n := tdir.orthogonal()
			shape(PackedVector2Array([U(tip), U(tip + tdir * r * 1.4 + n * r * 2.0), U(tip + tdir * r * 0.7), U(tip + tdir * r * 1.4 - n * r * 2.0)]), d["c_fin"], false)
		"verdis":
			for i3 in 3:
				spike(U(tip), U(tip + tdir.rotated((i3 - 1) * 0.6) * r * 1.5), k * r * 0.1, _col("verdis", "limb"))
		"ferrum":
			spike(U(tip), U(tip + tdir * r * 1.5), k * r * 0.4, _col("ferrum", "horn"))
		"voltara":
			for s2: float in [-1.0, 1.0]:
				var pt := tip + tdir.rotated(s2 * 0.5) * r * 1.6
				spike(U(tip), U(pt), k * r * 0.15, _col("voltara", "armor"))
				glow_dot(U(pt), k * 0.02, _glowc("voltara"))


# ---------------------------------------------------------------- back
func _back(sh: Vector2) -> void:
	var e: String = d["owner"]["back"]
	var up := sp_up()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d["rng_seed"]) + 5
	match e:
		"pebble":
			var b := sp(0.55) + sh + up * sp_r(0.55) * 0.9
			var b2 := b + up * sp_r(0.55) * 1.0 - Vector2(0.12, 0)
			seg(U(b), U(b2), k * 0.035, k * 0.03, _col("pebble", "armor"))
			shape(ellipse(U(b2), k * 0.04, k * 0.03), _col("pebble", "horn"))
			ci.draw_circle(U(b2 + up * 0.06 + Vector2(-0.03, 0)), k * (0.03 + 0.01 * sin(t * 3.0)), Color(0.85, 0.85, 0.85, 0.4))
			var gp := U(sp(0.35) + sh + up * sp_r(0.35) * 0.8)
			_gear(gp, k * 0.1, t * 1.2, _col("pebble", "horn").darkened(0.15))
			shape(ellipse(U(sp(0.7) + sh + up * sp_r(0.7) * 0.75), k * 0.12, k * 0.07, -0.2), _col("pebble", "armor"))
		"glacia":
			var n := int(d["n_spines"])
			for i in n:
				var tt := lerpf(0.12, 0.9, float(i) / (n - 1))
				var p := sp(tt) + sh + up * sp_r(tt) * 0.8
				var h := sp_r(tt) * (0.9 + sin(float(i) / (n - 1) * PI) * 0.9)
				var tip := p + (up - Vector2(cos(float(d["tilt"])), sin(float(d["tilt"]))) * 0.5).normalized() * h
				spike(U(p), U(tip), k * sp_r(tt) * 0.16, _col("glacia", "armor"))
				ci.draw_line(U(p), U(p.lerp(tip, 0.7)), Color(1, 1, 1, 0.6), lw * 0.7, true)
		"mycelia":
			for i2 in rng.randi_range(3, 5):
				var tt2 := rng.randf_range(0.15, 0.85)
				var p2 := sp(tt2) + sh + up * sp_r(tt2) * 0.85
				var h2 := sp_r(tt2) * rng.randf_range(0.6, 1.3)
				var top2 := p2 + up * h2 + Vector2(rng.randf_range(-0.05, 0.05), 0)
				seg(U(p2), U(top2), k * h2 * 0.1, k * h2 * 0.08, _col("mycelia", "belly"))
				var cr := h2 * 0.5
				var cap := PackedVector2Array()
				for j in 9:
					var a := PI * j / 8.0
					cap.append(U(top2 + Vector2(cos(a) * cr, sin(a) * cr * 0.7)))
				shape(cap, _col("mycelia", "armor"))
				ci.draw_line(U(top2 - Vector2(cr, 0)), U(top2 + Vector2(cr, 0)), _glowc("mycelia"), lw * 1.2, true)
				for j2 in 3:
					ci.draw_circle(U(top2 + Vector2((j2 - 1) * cr * 0.5, cr * 0.35)), k * cr * 0.1, Color(1, 1, 1, 0.8))
		"aquora":
			var tips := PackedVector2Array()
			var base := PackedVector2Array()
			for i3 in 6:
				var tt3 := lerpf(0.2, 0.85, float(i3) / 5.0)
				var p3 := sp(tt3) + sh + up * sp_r(tt3) * 0.85
				base.append(U(p3))
				tips.append(U(p3 + up * sp_r(0.5) * 1.6 * sin(float(i3 + 1) / 7.0 * PI) - Vector2(0.2, 0)))
			var fin := PackedVector2Array()
			fin.append_array(tips)
			for i4 in range(5, -1, -1):
				fin.append(base[i4])
			ci.draw_colored_polygon(fin, Color(_col("aquora", "fin"), 0.8))
			for i5 in 6:
				ci.draw_line(base[i5], tips[i5], _col("aquora", "fin").darkened(0.5), lw * 0.8, true)
			var r2 := tips.duplicate()
			ci.draw_polyline(r2, _col("aquora", "fin").darkened(0.6), lw, true)
		"verdis":
			for i6 in int(d["n_spines"]):
				var tt4 := lerpf(0.1, 0.92, float(i6) / (int(d["n_spines"]) - 1))
				var p4 := sp(tt4) + sh + up * sp_r(tt4) * 0.85
				spike(U(p4), U(p4 + (up * 0.8 - Vector2(cos(float(d["tilt"])), 0) * 0.6) * sp_r(tt4) * 0.9), k * sp_r(tt4) * 0.14, _col("verdis", "horn"))
			for i7 in 2:
				var p5 := sp(0.3 + i7 * 0.35) + sh + up * sp_r(0.4) * 0.9
				var lf := ellipse(U(p5 + up * 0.12), k * 0.06, k * 0.13, 0.4 * fc + sin(t * 1.4 + i7) * 0.15)
				shape(lf, _col("verdis", "fin"))
		"ferrum":
			for s: float in [0.0, 1.0]:
				var b3 := sp(0.42) + sh + up * sp_r(0.42) * 0.7 + Vector2(-0.08 * s, 0)
				var tp := b3 + (up * 0.85 - Vector2(cos(float(d["tilt"])), sin(float(d["tilt"]))) * 0.4) * sp_r(0.5) * 1.3
				var col := _col("ferrum", "armor").lightened(0.15) if s == 0.0 else _col("ferrum", "armor")
				seg(U(b3), U(tp), k * sp_r(0.5) * 0.17, k * sp_r(0.5) * 0.19, col)
				glow_dot(U(tp), k * 0.03, _glowc("ferrum"))
				for j3 in 3:
					var sm := tp + up * (0.08 + j3 * 0.09 + fmod(t * 0.2, 0.09)) + Vector2(-0.04 * j3, 0)
					ci.draw_circle(U(sm), k * (0.04 + j3 * 0.02), Color(0.25, 0.22, 0.2, 0.45 - j3 * 0.12))
		"orrery", "solara":
			var c := sp(0.55) + sh + up * sp_r(0.55) * 2.0
			glow_dot(U(c), k * sp_r(0.55) * 0.25, _glowc("solara"))
			for j4 in 3:
				var rr := sp_r(0.55) * (0.5 + j4 * 0.2)
				var pts := ellipse(U(c), k * rr, k * rr * 0.3, t * (0.5 + j4 * 0.3) * (1.0 if j4 % 2 == 0 else -1.0), 24)
				pts.append(pts[0])
				ci.draw_polyline(pts, _col("solara", "horn"), lw * 1.2, true)


func _back_wings(sh: Vector2, far: bool) -> void:
	if str(d["owner"]["back"]) != "voltara":
		return
	var big := str(d["dom"]) == "voltara"
	var span := (float(d["len"]) * 0.8 + 0.3) * (1.0 if big else 0.7)
	var root := sp(0.72) + sh + sp_up() * sp_r(0.72) * 0.6
	var flap := sin(t * (5.5 if big else 3.5)) * 0.35 + (0.25 if far else 0.0)
	var mem := _col("voltara", "fin")
	if far:
		mem = mem.darkened(0.35)
	var ribs: Array = []
	for i in 4:
		var a := lerpf(0.9, 2.3, float(i) / 3.0) + flap
		ribs.append(root + Vector2(cos(a) * -1.0, sin(a)) * span * (1.0 - i * 0.12))
	var pts := PackedVector2Array([U(root)])
	for rp: Vector2 in ribs:
		pts.append(U(rp))
	pts.append(U(root + Vector2(-span * 0.35, -span * 0.05)))
	ci.draw_colored_polygon(pts, Color(mem, 0.85))
	for rp2: Vector2 in ribs:
		ci.draw_line(U(root), U(rp2), _col("voltara", "armor"), lw * 1.2, true)
	var ring := pts.duplicate()
	ring.append(pts[0])
	ci.draw_polyline(ring, mem.darkened(0.7), lw, true)
	if not far:
		for i2 in 3:
			var a2: Vector2 = ribs[i2]
			var b2: Vector2 = ribs[i2 + 1]
			ci.draw_line(U(a2.lerp(root, 0.4)), U(b2.lerp(root, 0.3)), _glowc("voltara"), lw * 0.8, true)


func _gear(c: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0 + rot
		var rr := r * (1.0 if i % 2 == 0 else 0.78)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	shape(pts, col, false)
	ci.draw_circle(c, r * 0.3, col.darkened(0.5))


# ---------------------------------------------------------------- arms
func _arms(sh: Vector2) -> void:
	var e: String = d["owner"]["arms"]
	var kind := str(CreatureLook.kit(e)["arms"])
	if kind == "":
		return
	var sw := sin(t * 1.4) * 0.1
	if pose == "attack":
		sw = -0.9
	var shoulder := sp(0.86) + sh - sp_up() * sp_r(0.86) * 0.1
	var ul := sp_r(0.86) * (1.3 if kind == "scrap_claw" else 0.95)
	var elbow := shoulder + Vector2(0.15, -ul).rotated(-sw * 0.5)
	var hand := elbow + Vector2(ul * 0.9, -ul * 0.1).rotated(-sw)
	var col: Color = d["c_limb"]
	if kind in ["piston", "scrap_claw"]:
		col = _col(e, "armor").lightened(0.1)
	var ar := sp_r(0.86) * (0.2 if kind in ["scrap_claw", "piston"] else 0.12)
	seg(U(shoulder), U(elbow), ar * k, ar * k * 0.8, col)
	seg(U(elbow), U(hand), ar * k * 0.8, ar * k * 0.6, col)
	var hd := (hand - elbow).normalized()
	match kind:
		"scrap_claw":
			spike(U(hand), U(hand + hd.rotated(0.5) * ar * 3.0), ar * k * 0.5, _col(e, "horn"))
			spike(U(hand), U(hand + hd.rotated(-0.5) * ar * 3.0), ar * k * 0.5, _col(e, "horn"))
			_gear(U(elbow), ar * k * 0.9, t * 2.0, _col("pebble", "horn").darkened(0.2))
		"ice_scythe":
			spike(U(hand - hd * 0.03), U(hand + hd.rotated(0.4) * ul * 1.3), ar * k * 0.9, _col("glacia", "armor"))
		"mantis":
			spike(U(hand), U(hand + hd.rotated(-2.2) * ul * 0.8), ar * k * 0.6, _col("verdis", "horn"))
		"piston":
			shape(ellipse(U(hand + hd * ar), ar * k * 1.3, ar * k * 1.1), _col("ferrum", "armor"))
			glow_dot(U(hand + hd * ar * 1.6), k * 0.025, _glowc("ferrum"))


# ---------------------------------------------------------------- head
func _head(sh: Vector2) -> void:
	var he: String = d["owner"]["head"]
	var nk: Array = CreatureForge.NECKS.get(he, CreatureForge.NECKS["solara"])
	var ndir := Vector2(Vector3(nk[0]).z, Vector3(nk[0]).y).normalized()
	var nlen := float(nk[1])
	var hs := float(d["chest"]) * float(nk[2])
	var base := sp(0.96) + sh
	var hc := base + ndir * (nlen + hs * 0.3) + Vector2(0, sin(t * 1.7) * 0.01)
	if pose == "attack":
		hc += Vector2(0.06, -0.02)
	if nlen > 0.1:
		seg(U(base), U(hc), k * sp_r(0.97) * 0.6, k * hs * 0.38, d["c_body"])
	var hcol: Color = d["c_head"]
	var eye: Color = d["c_accent"]
	var jaw_open := 0.25 if pose == "attack" else 0.03
	match he:
		"pebble":
			shape(ellipse(U(hc + Vector2(0.03, 0)), k * hs * 0.75, k * hs * 0.5, -0.1 * fc), hcol)
			shape(PackedVector2Array([U(hc + Vector2(-hs * 0.4, -hs * 0.2)), U(hc + Vector2(hs * 0.9, -hs * 0.25 - jaw_open * hs)), U(hc + Vector2(hs * 0.85, -hs * 0.55 - jaw_open * hs)), U(hc + Vector2(-hs * 0.3, -hs * 0.5))]), hcol.darkened(0.15))
			for i in 4:
				spike(U(hc + Vector2(hs * (0.3 + i * 0.15), -hs * 0.28 - jaw_open * hs)), U(hc + Vector2(hs * (0.32 + i * 0.15), -hs * 0.1)), k * hs * 0.04, _col("pebble", "horn"))
			var lp := U(hc + Vector2(hs * 0.35, hs * 0.18))
			ci.draw_circle(lp, k * hs * 0.24, _col("pebble", "horn").darkened(0.2))
			ci.draw_circle(lp, k * hs * 0.17, eye)
			Art.glow(ci, lp, k * hs * 0.5, eye, 0.3)
			ci.draw_arc(lp, k * hs * 0.24, 0, TAU, 16, Color.BLACK, lw, true)
			_eye_at(U(hc + Vector2(hs * 0.05, hs * 0.25)), k * hs * 0.09, eye)
			shape(PackedVector2Array([U(hc + Vector2(-hs * 0.2, hs * 0.35)), U(hc + Vector2(hs * 0.6, hs * 0.48)), U(hc + Vector2(hs * 0.5, hs * 0.3))]), _col("pebble", "armor"), false)
		"glacia":
			shape(ellipse(U(hc + Vector2(hs * 0.2, 0)), k * hs * 0.85, k * hs * 0.32, -0.15 * fc), hcol)
			for i2 in 4:
				var a := lerpf(0.5, 1.4, float(i2) / 3.0)
				spike(U(hc + Vector2(-hs * 0.2, hs * 0.15)), U(hc + Vector2(-cos(a) * hs * 1.5, sin(a) * hs * 1.2)), k * hs * 0.08, _col("glacia", "armor"))
			for i3 in 3:
				_eye_at(U(hc + Vector2(hs * (0.3 + i3 * 0.16), hs * 0.08)), k * hs * 0.06, eye)
			spike(U(hc + Vector2(hs * 0.6, -hs * 0.15)), U(hc + Vector2(hs * 1.2, -hs * 0.3 - jaw_open * hs)), k * hs * 0.05, _col("glacia", "horn"))
		"mycelia":
			shape(ellipse(U(hc + Vector2(hs * 0.15, -hs * 0.1)), k * hs * 0.5, k * hs * 0.38), hcol)
			var cap := PackedVector2Array()
			for j in 11:
				var a2 := PI * j / 10.0
				cap.append(U(hc + Vector2(cos(a2) * hs * 1.0, sin(a2) * hs * 0.65 + hs * 0.05)))
			shape(cap, _col("mycelia", "armor"))
			for j2 in 4:
				ci.draw_circle(U(hc + Vector2((j2 - 1.5) * hs * 0.4, hs * 0.35)), k * hs * 0.07, Color(1, 0.95, 0.85))
			ci.draw_line(U(hc + Vector2(-hs, hs * 0.05)), U(hc + Vector2(hs, hs * 0.05)), _glowc("mycelia"), lw * 1.5, true)
			for j3 in int(d["n_eyes"]):
				_eye_at(U(hc + Vector2(hs * (0.2 + 0.08 * (j3 % 3)), -hs * (0.02 + 0.08 * (j3 / 3)))), k * hs * 0.05, eye)
			for j4 in 3:
				var tp := hc + Vector2(hs * (0.15 + j4 * 0.12), -hs * 0.4)
				ci.draw_line(U(tp), U(tp + Vector2(sin(t * 2.0 + j4) * 0.03, -hs * 0.5)), _col("mycelia", "limb"), lw * 1.3, true)
		"aquora":
			shape(ellipse(U(hc + Vector2(hs * 0.2, 0)), k * hs * 0.8, k * hs * 0.5, -0.1 * fc), hcol)
			shape(PackedVector2Array([U(hc + Vector2(-hs * 0.1, -hs * 0.25)), U(hc + Vector2(hs * 1.0, -hs * 0.15 - jaw_open * hs)), U(hc + Vector2(hs * 0.8, -hs * 0.45 - jaw_open * hs))]), hcol.darkened(0.15))
			for i4 in 3:
				ci.draw_line(U(hc + Vector2(-hs * (0.15 + i4 * 0.1), hs * 0.2)), U(hc + Vector2(-hs * (0.2 + i4 * 0.1), -hs * 0.2)), Color(_glowc("aquora"), 0.7), lw, true)
			var ep := U(hc + Vector2(hs * 0.35, hs * 0.15))
			ci.draw_circle(ep, k * hs * 0.2, _col("aquora", "horn").darkened(0.3))
			_eye_at(ep, k * hs * 0.15, eye)
			var stalk0 := hc + Vector2(hs * 0.1, hs * 0.45)
			var stalk1 := stalk0 + Vector2(hs * 0.6 + sin(t * 1.8) * 0.03, hs * 0.5)
			var stalk2 := stalk1 + Vector2(hs * 0.4, -hs * 0.2)
			ci.draw_polyline(PackedVector2Array([U(stalk0), U(stalk1), U(stalk2)]), hcol.darkened(0.3), lw * 1.3, true)
			glow_dot(U(stalk2), k * hs * 0.1, _glowc("aquora"))
		"verdis":
			shape(ellipse(U(hc), k * hs * 0.55, k * hs * 0.45), hcol)
			shape(PackedVector2Array([U(hc + Vector2(hs * 0.35, hs * 0.2)), U(hc + Vector2(hs * 1.15, -hs * 0.1)), U(hc + Vector2(hs * 0.9, -hs * 0.35)), U(hc + Vector2(hs * 0.35, -hs * 0.15))]), _col("verdis", "armor"))
			for i5 in 3:
				spike(U(hc + Vector2(-hs * (0.1 + i5 * 0.15), hs * 0.3)), U(hc + Vector2(-hs * (0.7 + i5 * 0.2), hs * (0.9 - i5 * 0.15))), k * hs * 0.07, d["c_horn"])
			shape(ellipse(U(hc + Vector2(-hs * 0.3, hs * 0.05)), k * hs * 0.35, k * hs * 0.14, 0.5 * fc + sin(t * 1.5) * 0.1), _col("verdis", "fin"))
			_eye_at(U(hc + Vector2(hs * 0.2, hs * 0.12)), k * hs * 0.11, eye)
		"ferrum":
			shape(PackedVector2Array([U(hc + Vector2(-hs * 0.5, -hs * 0.4)), U(hc + Vector2(-hs * 0.5, hs * 0.4)), U(hc + Vector2(hs * 0.55, hs * 0.45)), U(hc + Vector2(hs * 0.65, -hs * 0.4))]), _col("ferrum", "armor").lightened(0.2))
			ci.draw_line(U(hc + Vector2(hs * 0.0, hs * 0.1)), U(hc + Vector2(hs * 0.62, hs * 0.1)), _glowc("ferrum"), k * hs * 0.12, true)
			Art.glow(ci, U(hc + Vector2(hs * 0.4, hs * 0.1)), k * hs * 0.5, _glowc("ferrum"), 0.3)
			for i6 in 4:
				ci.draw_line(U(hc + Vector2(hs * (0.1 + i6 * 0.13), -hs * 0.15)), U(hc + Vector2(hs * (0.1 + i6 * 0.13), -hs * 0.38)), _col("ferrum", "horn"), lw, true)
			spike(U(hc + Vector2(-hs * 0.3, hs * 0.4)), U(hc + Vector2(-hs * 0.7, hs * 0.9)), k * hs * 0.1, d["c_horn"])
		"voltara":
			shape(PackedVector2Array([U(hc + Vector2(-hs * 0.4, hs * 0.3)), U(hc + Vector2(hs * 1.3, -hs * 0.05)), U(hc + Vector2(-hs * 0.3, -hs * 0.35))]), hcol)
			_eye_at(U(hc + Vector2(hs * 0.15, hs * 0.08)), k * hs * 0.1, eye)
			_eye_at(U(hc + Vector2(hs * 0.38, hs * 0.04)), k * hs * 0.06, eye)
			for s2: float in [0.0, 1.0]:
				var a0 := hc + Vector2(-hs * 0.2 - s2 * 0.04, hs * 0.25)
				var a1 := a0 + Vector2(-hs * 0.5 + sin(t * 2.2 + s2) * 0.03, hs * 1.0)
				ci.draw_line(U(a0), U(a1), _col("voltara", "armor"), lw * 1.3, true)
				glow_dot(U(a1), k * hs * 0.08, _glowc("voltara"))
		"solara":
			shape(ellipse(U(hc + Vector2(hs * 0.15, 0)), k * hs * 0.5, k * hs * 0.55), hcol)
			for i7 in 5:
				var a3 := lerpf(-0.8, 0.8, float(i7) / 4.0)
				glow_dot(U(hc + Vector2(hs * (0.35 + cos(a3) * 0.1), hs * sin(a3) * 0.3)), k * hs * 0.04, eye)
			for i8 in 6:
				var a4 := lerpf(0.4, 2.6, float(i8) / 5.0)
				spike(U(hc + Vector2(-hs * 0.1, hs * 0.1)), U(hc + Vector2(cos(a4) * hs * -1.3, sin(a4) * hs * 1.3)), k * hs * 0.05, _col("solara", "armor"))
			var halo := ellipse(U(hc + Vector2(-hs * 0.1, hs * 0.75)), k * hs * 0.6, k * hs * 0.18, 0.0, 22)
			halo.append(halo[0])
			ci.draw_polyline(halo, _col("solara", "horn"), lw * 1.6, true)


func _eye_at(p: Vector2, r: float, col: Color) -> void:
	var blink := fposmod(t, 4.0) < 0.12
	ci.draw_circle(p, r + lw * 0.5, Color(0.05, 0.03, 0.06))
	if blink:
		ci.draw_line(p - Vector2(r, 0), p + Vector2(r, 0), col, lw, true)
		return
	ci.draw_circle(p, r, col)
	Art.glow(ci, p, r * 2.5, col, 0.25)
	ci.draw_circle(p + Vector2(r * 0.25 * fc, 0), r * 0.45, Color(0.04, 0.02, 0.05))
	ci.draw_circle(p + Vector2(-r * 0.3, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.9))


# ---------------------------------------------------------------- small features of every element
func _infusions(sh: Vector2) -> void:
	var up := sp_up()
	for e: String in d["els"]:
		match e:
			"pebble":
				var p := sp(0.45) + sh + up * sp_r(0.45) * 0.1
				var pts := ellipse(U(p), k * sp_r(0.45) * 0.45, k * sp_r(0.45) * 0.32, 0.2)
				shape(pts, _col("pebble", "armor"))
				for i in 4:
					ci.draw_circle(pts[i * 4 + 1].lerp(U(p), 0.25), k * 0.012, _col("pebble", "horn"))
			"glacia":
				var p2 := sp(0.8) + sh + up * sp_r(0.8) * 0.7
				for i2 in 3:
					spike(U(p2), U(p2 + up.rotated((i2 - 1) * 0.5) * sp_r(0.8) * 0.6), k * 0.025, _col("glacia", "armor"))
			"mycelia":
				for i3 in 2:
					var p3 := sp(0.25 + i3 * 0.4) + sh - up * sp_r(0.3) * 0.3
					ci.draw_line(U(p3), U(p3 + up * 0.07), _col("mycelia", "belly"), lw * 1.2, true)
					shape(ellipse(U(p3 + up * 0.08), k * 0.045, k * 0.025), _col("mycelia", "armor"), false)
			"aquora":
				for i4 in 3:
					var p4 := sp(0.88 - i4 * 0.05) + sh
					ci.draw_line(U(p4 + up * sp_r(0.85) * 0.4), U(p4 - up * sp_r(0.85) * 0.1), _col("aquora", "dark"), lw * 1.2, true)
			"verdis":
				for i5 in 4:
					var p5 := sp(0.2 + i5 * 0.2) + sh + up * sp_r(0.4) * 0.85
					spike(U(p5), U(p5 + up * 0.08 - Vector2(0.04, 0)), k * 0.018, _col("verdis", "horn"))
			"ferrum":
				var p6 := sp(0.72) + sh
				ci.draw_line(U(p6 + up * sp_r(0.72) * 0.6), U(p6 - up * sp_r(0.72) * 0.5), _col("ferrum", "armor"), k * 0.06, true)
				ci.draw_line(U(p6 + up * sp_r(0.72) * 0.55), U(p6 - up * sp_r(0.72) * 0.45), _glowc("ferrum"), k * 0.02, true)
			"voltara":
				var a := U(sp(0.2) + sh + up * sp_r(0.2) * 0.9)
				var b := U(sp(0.9) + sh + up * sp_r(0.9) * 0.9)
				if fposmod(t * 3.0, 1.0) < 0.35:
					var pts2 := PackedVector2Array()
					for j in 7:
						pts2.append(a.lerp(b, j / 6.0) + Vector2(0, (randf() - 0.5) * k * 0.08))
					ci.draw_polyline(pts2, _glowc("voltara").lightened(0.4), lw, true)
			"solara":
				for i6 in 4:
					glow_dot(U(sp(0.25 + i6 * 0.18) + sh), k * 0.022, _glowc("solara"))
