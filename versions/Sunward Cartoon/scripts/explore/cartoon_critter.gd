class_name CartoonCritter
extends RefCounted
## Sunward Cartoon: every animal as a flat 2D cartoon drawing standing in the 3D world.
## The drawing is made from the species' body plan and colours (hand-made species and the
## generated aliens alike): a thick dark ink outline, flat bold colours with a lighter belly, big
## shiny eyes, a smile. Two poses side by side (legs / wings / feet in two positions) - the animal
## switches between them while walking, hopping, flying or swimming.
## Each species is drawn once (in a small hidden viewport) and kept for the whole game.

const W := 256                       # one pose
const INK := Color(0.07, 0.05, 0.1)
static var _tex := {}                # species id -> ViewportTexture (2 poses, 512 x 256)
static var _holder: Node = null


static func texture(id: String, sp: Dictionary, tree: SceneTree) -> Texture2D:
	if _tex.has(id):
		return _tex[id]
	if _holder == null or not is_instance_valid(_holder):
		_holder = Node.new()
		_holder.name = "CartoonCritters"
		tree.root.add_child(_holder)
	var vp := SubViewport.new()
	vp.size = Vector2i(W * 2, W)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var d := Drawer.new()
	d.sp = sp
	d.size = Vector2(W * 2, W)
	vp.add_child(d)
	_holder.add_child(vp)
	var tx := vp.get_texture()
	_tex[id] = tx
	return tx


class Drawer:
	extends Control
	var sp: Dictionary

	func _draw() -> void:
		for f in 2:
			draw_set_transform(Vector2(f * W, 0))
			CartoonCritter.draw_critter(self, sp, f)
		draw_set_transform(Vector2.ZERO)


# ================================================================== drawing helpers
static func _ell(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, rot := 0.0, ink := 5.0) -> void:
	var pts := PackedVector2Array()
	var pin := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		var v := Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot)
		pts.append(c + v)
		pin.append(c + v + v.normalized() * ink)
	if ink > 0.0:
		ci.draw_colored_polygon(pin, INK)
	ci.draw_colored_polygon(pts, col)


static func _limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, INK, w + 8.0, true)
	ci.draw_circle(b, (w + 8.0) * 0.5, INK)
	ci.draw_line(a, b, col, w, true)
	ci.draw_circle(b, w * 0.5, col)


static func _eye(ci: CanvasItem, c: Vector2, r: float, glow := Color.TRANSPARENT) -> void:
	ci.draw_circle(c, r + 3.5, INK)
	if glow.a > 0.0:
		ci.draw_circle(c, r, glow)
		ci.draw_circle(c + Vector2(r * 0.15, 0), r * 0.4, glow.darkened(0.6))
	else:
		ci.draw_circle(c, r, Color.WHITE)
		ci.draw_circle(c + Vector2(r * 0.25, r * 0.05), r * 0.55, INK)
	ci.draw_circle(c + Vector2(-r * 0.2, -r * 0.3), r * 0.25, Color.WHITE)


static func _smile(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_arc(c, r, 0.25, PI - 0.25, 12, INK, 4.0, true)


static func _spikes(ci: CanvasItem, from: Vector2, to: Vector2, n: int, h: float, col: Color, crystal: bool) -> void:
	for i in n:
		var k := (i + 0.5) / n
		var p := from.lerp(to, k)
		var hh := h * (0.7 + 0.3 * sin(k * PI))
		var tri := PackedVector2Array([p + Vector2(-h * 0.35, 4), p + Vector2(0, -hh), p + Vector2(h * 0.35, 4)])
		if crystal:
			tri = PackedVector2Array([p + Vector2(-h * 0.25, 2), p + Vector2(-h * 0.1, -hh), p + Vector2(h * 0.12, -hh * 0.85), p + Vector2(h * 0.25, 2)])
		var out := PackedVector2Array()
		for q: Vector2 in tri:
			out.append(p + (q - p) * 1.25 + Vector2(0, -1))
		ci.draw_colored_polygon(out, INK)
		ci.draw_colored_polygon(tri, col)


# ================================================================== the animals
## Draws the animal facing right, feet near the bottom (y ~ 232). f = pose (0 / 1).
static func draw_critter(ci: CanvasItem, sp: Dictionary, f: int) -> void:
	var col := Cartoon.vivid(Color(sp.get("color", Color.GRAY)))
	var acc := Cartoon.vivid(Color(sp.get("accent", Color.WHITE)))
	var plan := str(sp.get("plan", "walker"))
	var g: Dictionary = sp.get("genes", {})
	var eyes := 2
	if not g.is_empty():
		var cs: Array = g.get("colors", [])
		if cs.size() >= 4:
			col = Cartoon.vivid(Color(cs[0]))
			acc = Cartoon.vivid(Color(cs[3]))
		eyes = int(g.get("eyes", 2))
		plan = {"legs": "walker", "radial": "radial", "crawl": "crawler", "hover": "floater", "wing": "flyer",
			"swim": "swimmer", "burrow": "crawler", "climb": "walker", "sessile": "sessile"}.get(str(g.get("loc", "legs")), "walker")
	match str(sp.get("model", "")):
		"giant_fly":
			_giant_fly(ci, col, f)
			return
		"woolly_giant":
			_woolly(ci, col, acc, f)
			return
	var glow := acc if bool(sp.get("glow", false)) else Color.TRANSPARENT
	match plan:
		"hopper":
			_hopper(ci, sp, col, acc, f, eyes)
		"flyer", "skimmer":
			_flyer(ci, col, acc, f, eyes)
		"swimmer":
			_fish(ci, col, acc, f, eyes)
		"crawler":
			_crawler(ci, col, acc, f, eyes)
		"floater":
			_floater(ci, col, acc, f, eyes)
		"gasbag":
			_gasbag(ci, col, acc, f, eyes)
		"jelly":
			_jelly(ci, col, acc, f)
		"tripod":
			_tripod(ci, col, acc, f, eyes)
		"radial":
			_radial(ci, col, acc, f, eyes)
		"sessile":
			_sessile(ci, col, acc, f, eyes)
		_:
			_walker(ci, sp, col, acc, f, eyes, glow)


static func _eyes_row(ci: CanvasItem, c: Vector2, n: int, r: float, glow := Color.TRANSPARENT) -> void:
	if n <= 0:
		ci.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), INK, 4.0, true)
		return
	if n == 1:
		_eye(ci, c, r * 1.3, glow)
		return
	var cols := mini(n, 4)
	var rows := int(ceil(float(n) / cols))
	var rr := r * (1.0 if n <= 2 else 0.75)
	for i in n:
		var cx := i % cols
		var cy := i / cols
		var p := c + Vector2((cx - (cols - 1) * 0.5) * rr * 2.3, (cy - (rows - 1) * 0.5) * rr * 2.2)
		_eye(ci, p, rr, glow)


static func _walker(ci: CanvasItem, sp: Dictionary, col: Color, acc: Color, f: int, eyes: int, glow: Color) -> void:
	var long := bool(sp.get("long_legs", false))
	var by := 120.0 if long else 150.0
	var pairs := clampi(int(sp.get("legs", 2)), 1, 4)
	# legs behind (darker), then the body, then legs in front
	var leg_c := col.darkened(0.25)
	var foot_y := 228.0
	for side in 2:
		if side == 1:
			# the body between the far legs and the near legs
			_ell(ci, Vector2(128, by), Vector2(78, 48), col)
			_ell(ci, Vector2(124, by + 16), Vector2(56, 24), col.lightened(0.35), 0.0, 0.0)
		for i in pairs:
			var x := lerpf(-50.0, 50.0, (i + 0.5) / pairs)
			var swing := (8.0 if (i + side + f) % 2 == 0 else -8.0) * (1.0 if side == 0 else 0.7)
			var lc := leg_c.darkened(0.2) if side == 0 else leg_c
			_limb(ci, Vector2(128 + x + (side * 6), by + 20), Vector2(128 + x + swing + side * 6, foot_y), 14.0, lc)
	# back
	var back := str(sp.get("back", ""))
	if back == "spikes":
		_spikes(ci, Vector2(80, by - 40), Vector2(170, by - 40), 4, 34.0, acc, false)
	elif back == "crystals":
		_spikes(ci, Vector2(85, by - 38), Vector2(165, by - 38), 3, 40.0, acc, true)
	# tail
	ci.draw_line(Vector2(52, by - 4), Vector2(22, by - 30 + f * 6), INK, 18.0, true)
	ci.draw_line(Vector2(52, by - 4), Vector2(22, by - 30 + f * 6), col, 10.0, true)
	# head (on a neck for some)
	var hc := Vector2(200, by - 22)
	if bool(sp.get("neck", false)):
		hc = Vector2(205, by - 75)
		_limb(ci, Vector2(175, by - 15), hc + Vector2(-6, 12), 22.0, col)
	_ell(ci, hc, Vector2(38, 33), col)
	_ell(ci, hc + Vector2(14, 12), Vector2(20, 14), col.lightened(0.3), 0.0, 3.0)
	_eyes_row(ci, hc + Vector2(6, -8), eyes, 11.0, glow)
	_smile(ci, hc + Vector2(16, 8), 10.0)
	if bool(sp.get("tail", false)) or str(sp.get("ears", "")) != "":
		_ell(ci, hc + Vector2(-18, -32), Vector2(8, 18), acc, -0.3, 3.0)


static func _hopper(ci: CanvasItem, sp: Dictionary, col: Color, acc: Color, f: int, eyes: int) -> void:
	var up := 0.0 if f == 0 else -22.0
	var c := Vector2(128, 150 + up)
	# big feet
	_ell(ci, Vector2(110, 222 + up * 0.3), Vector2(30, 12), col.darkened(0.25))
	_ell(ci, Vector2(150, 222 + up * 0.3), Vector2(30, 12), col.darkened(0.15))
	_ell(ci, c, Vector2(66 - up * 0.3, 62 + up * 0.4), col)
	_ell(ci, c + Vector2(6, 18), Vector2(40, 30), col.lightened(0.35), 0.0, 0.0)
	# ears
	var long := str(sp.get("ears", "")) == "long"
	for sx: float in [-1.0, 1.0]:
		_ell(ci, c + Vector2(sx * 22 - 6, -70 if long else -55), Vector2(12, 40 if long else 22), acc, sx * 0.2, 4.0)
	_eyes_row(ci, c + Vector2(18, -10), eyes, 14.0)
	_smile(ci, c + Vector2(24, 14), 12.0)


static func _flyer(ci: CanvasItem, col: Color, acc: Color, f: int, eyes: int) -> void:
	var c := Vector2(128, 140)
	var wing_up := f == 0
	var wc := Color(acc, 0.85)
	_ell(ci, c + Vector2(-10, -50 if wing_up else 10), Vector2(70, 34 if wing_up else 26), wc, -0.5 if wing_up else 0.4)
	_ell(ci, c, Vector2(56, 34), col)
	_ell(ci, c + Vector2(-4, 12), Vector2(38, 14), col.lightened(0.35), 0.0, 0.0)
	_ell(ci, c + Vector2(10, -40 if wing_up else 18), Vector2(64, 30 if wing_up else 24), Color(acc.lightened(0.2), 0.9), -0.3 if wing_up else 0.5)
	_eyes_row(ci, c + Vector2(36, -6), eyes, 10.0)
	ci.draw_line(c + Vector2(44, -24), c + Vector2(60, -56), INK, 4.0, true)
	ci.draw_circle(c + Vector2(60, -56), 6, acc)


static func _fish(ci: CanvasItem, col: Color, acc: Color, f: int, eyes: int) -> void:
	var c := Vector2(128, 130)
	var tw := 16.0 if f == 0 else -16.0
	var tail := PackedVector2Array([c + Vector2(-60, 0), c + Vector2(-110, -40 + tw), c + Vector2(-100, 0), c + Vector2(-110, 40 + tw)])
	var tail_o := PackedVector2Array()
	for q: Vector2 in tail:
		tail_o.append(c + (q - c) * 1.08)
	ci.draw_colored_polygon(tail_o, INK)
	ci.draw_colored_polygon(tail, acc)
	_ell(ci, c, Vector2(80, 44), col)
	_ell(ci, c + Vector2(6, 16), Vector2(56, 18), col.lightened(0.35), 0.0, 0.0)
	_ell(ci, c + Vector2(-6, -40), Vector2(28, 12), acc, -0.4, 4.0)
	_eyes_row(ci, c + Vector2(44, -8), eyes, 11.0)
	_smile(ci, c + Vector2(58, 8), 8.0)


static func _crawler(ci: CanvasItem, col: Color, acc: Color, f: int, eyes: int) -> void:
	for i in 6:
		var k := float(i) / 5.0
		var p := Vector2(lerpf(50, 200, k), 200 - sin(k * PI + f * 0.8) * 10.0)
		var r := lerpf(22, 30, k)
		_limb(ci, p + Vector2(0, 10), p + Vector2((6 if (i + f) % 2 == 0 else -6), 30), 6.0, col.darkened(0.3))
		_ell(ci, p, Vector2(r, r * 0.9), col if i % 2 == 0 else col.lightened(0.15))
	_spikes(ci, Vector2(60, 182), Vector2(185, 175), 5, 18.0, acc, false)
	_eyes_row(ci, Vector2(208, 192), eyes, 9.0)


static func _floater(ci: CanvasItem, col: Color, acc: Color, f: int, eyes: int) -> void:
	var c := Vector2(128, 110 + f * 8)
	ci.draw_circle(c, 82, Color(acc, 0.18))
	_ell(ci, c, Vector2(58, 58), col)
	_ell(ci, c + Vector2(-14, -18), Vector2(18, 12), col.lightened(0.5), 0.0, 0.0)
	_eyes_row(ci, c + Vector2(8, -2), eyes, 12.0)
	_smile(ci, c + Vector2(10, 18), 10.0)
	for i in 4:
		var x := lerpf(-30, 30, i / 3.0)
		ci.draw_line(c + Vector2(x, 52), c + Vector2(x + (10 if (i + f) % 2 == 0 else -10), 110), INK, 9.0, true)
		ci.draw_line(c + Vector2(x, 52), c + Vector2(x + (10 if (i + f) % 2 == 0 else -10), 110), acc, 4.0, true)


static func _gasbag(ci: CanvasItem, col: Color, acc: Color, f: int, eyes: int) -> void:
	var c := Vector2(128, 95)
	for i in 6:
		var x := lerpf(-45, 45, i / 5.0)
		var wob := (8.0 if (i + f) % 2 == 0 else -8.0)
		ci.draw_polyline(PackedVector2Array([c + Vector2(x, 60), c + Vector2(x + wob, 120), c + Vector2(x - wob, 170), c + Vector2(x, 225)]), INK, 7.0, true)
		ci.draw_polyline(PackedVector2Array([c + Vector2(x, 60), c + Vector2(x + wob, 120), c + Vector2(x - wob, 170), c + Vector2(x, 225)]), acc, 3.0, true)
	_ell(ci, c, Vector2(92, 74), col)
	for i in 3:
		_ell(ci, c + Vector2(-50 + i * 50, 0), Vector2(12, 60), col.lightened(0.18), 0.0, 0.0)
	_eyes_row(ci, c + Vector2(30, 0), eyes, 13.0)
	_smile(ci, c + Vector2(36, 26), 12.0)


static func _jelly(ci: CanvasItem, col: Color, acc: Color, f: int) -> void:
	var c := Vector2(128, 100)
	for i in 7:
		var x := lerpf(-50, 50, i / 6.0)
		var w := (12.0 if (i + f) % 2 == 0 else -12.0)
		ci.draw_polyline(PackedVector2Array([c + Vector2(x, 20), c + Vector2(x + w, 80), c + Vector2(x - w, 140), c + Vector2(x, 200)]), Color(acc, 0.9), 5.0, true)
	var dome := PackedVector2Array()
	for i in 20:
		var a := PI + PI * i / 19.0
		dome.append(c + Vector2(cos(a) * 70, sin(a) * 60))
	dome.append(c + Vector2(70, 22))
	dome.append(c + Vector2(-70, 22))
	ci.draw_colored_polygon(dome, Color(col, 0.85))
	ci.draw_polyline(dome, INK, 4.0, true)
	_eyes_row(ci, c + Vector2(0, -12), 2, 10.0)


static func _tripod(ci: CanvasItem, col: Color, acc: Color, f: int, eyes: int) -> void:
	var c := Vector2(128, 70)
	for i in 3:
		var x: float = [-50.0, 0.0, 50.0][i]
		var sw := (10.0 if (i + f) % 2 == 0 else -10.0)
		_limb(ci, c + Vector2(x * 0.5, 30), c + Vector2(x + sw, 160), 10.0, col.darkened(0.2))
	_ell(ci, c, Vector2(62, 42), col)
	_spikes(ci, c + Vector2(-40, -36), c + Vector2(40, -36), 5, 26.0, acc, true)
	_eyes_row(ci, c + Vector2(20, -4), eyes, 11.0)
	_smile(ci, c + Vector2(26, 16), 9.0)


static func _radial(ci: CanvasItem, col: Color, acc: Color, f: int, eyes: int) -> void:
	var c := Vector2(128, 170)
	for i in 8:
		var a := PI + PI * (i + 0.5) / 8.0 + (0.08 if f == 1 else 0.0)
		_limb(ci, c, c + Vector2(cos(a) * 95, -sin(a) * 30 + 50), 9.0, col.darkened(0.25))
	_ell(ci, c, Vector2(70, 38), col)
	_ell(ci, c + Vector2(0, -16), Vector2(40, 14), col.lightened(0.35), 0.0, 0.0)
	_eyes_row(ci, c + Vector2(0, -12), maxi(eyes, 3), 10.0)


static func _sessile(ci: CanvasItem, col: Color, acc: Color, f: int, eyes: int) -> void:
	var sway := 6.0 if f == 0 else -6.0
	_limb(ci, Vector2(128, 230), Vector2(128 + sway, 120), 20.0, col.darkened(0.2))
	_ell(ci, Vector2(128 + sway, 100), Vector2(54, 40), col)
	for i in 6:
		var a := PI + PI * i / 5.0
		_limb(ci, Vector2(128 + sway, 86), Vector2(128 + sway + cos(a) * 60, 86 + sin(a) * 40 - 10), 7.0, acc)
	_eyes_row(ci, Vector2(128 + sway, 100), eyes, 10.0)


## Cinder Fly: four wings, four yellow eyes, a glowing yellow spine
static func _giant_fly(ci: CanvasItem, col: Color, f: int) -> void:
	var c := Vector2(128, 130)
	var y := Color("#ffd23a")
	var wing := Color(0.9, 0.95, 0.85, 0.75)
	var up := f == 0
	for k in 2:
		_ell(ci, c + Vector2(-10 + k * 26, -58 if up else 4), Vector2(64, 22), wing, (-0.6 if up else 0.5) + k * 0.2, 4.0)
	# abdomen and thorax
	_ell(ci, c + Vector2(-46, 10), Vector2(62, 36), col.darkened(0.15), 0.15)
	for i in 3:
		ci.draw_line(c + Vector2(-80 + i * 22, -14), c + Vector2(-76 + i * 22, 38), col.lightened(0.15), 5.0, true)
	_ell(ci, c + Vector2(16, -2), Vector2(38, 32), col)
	# glowing spine plates
	for i in 6:
		var p := c + Vector2(-90 + i * 22, -30 + absf(i - 3.0) * 3.0)
		ci.draw_circle(p, 13, Color(y, 0.3))
		_ell(ci, p, Vector2(7, 11), y, 0.0, 3.0)
	# legs
	for i in 3:
		_limb(ci, c + Vector2(-10 + i * 16, 26), c + Vector2(-24 + i * 20 + (6 if (i + f) % 2 == 0 else -6), 96), 5.0, col.darkened(0.3))
	# head with four big yellow eyes
	_ell(ci, c + Vector2(58, -6), Vector2(30, 28), col.darkened(0.25))
	for ey in 2:
		for ex in 2:
			_eye(ci, c + Vector2(52 + ex * 20, -18 + ey * 20), 9.5, y)
	for k in 2:
		_ell(ci, c + Vector2(6 + k * 22, -54 if up else 8), Vector2(60, 20), Color(wing, 0.85), (-0.4 if up else 0.6) + k * 0.15, 4.0)


## Drift Hulk: a shaggy mountain of fur with ice tusks
static func _woolly(ci: CanvasItem, col: Color, acc: Color, f: int) -> void:
	var c := Vector2(122, 120)
	for i in 4:
		var x: float = [-60.0, -25.0, 25.0, 60.0][i]
		var sw := (6.0 if (i + f) % 2 == 0 else -6.0)
		_limb(ci, c + Vector2(x, 50), c + Vector2(x + sw, 106), 26.0, col.darkened(0.3))
	_ell(ci, c, Vector2(100, 76), col)
	for i in 14:
		var a := PI * 0.1 + PI * 0.8 * i / 13.0
		_ell(ci, c + Vector2(cos(a) * 88, sin(a) * 56 + 10), Vector2(16, 26), col.darkened(0.08 + 0.08 * (i % 2)), 0.0, 3.0)
	for i in 6:
		_ell(ci, c + Vector2(-60 + i * 22, -58 + absf(i - 2.5) * 5), Vector2(18, 16), col.lightened(0.15), 0.0, 3.0)
	# head, trunk, tusks
	var h := c + Vector2(92, 6)
	_ell(ci, h, Vector2(40, 38), col)
	_limb(ci, h + Vector2(18, 20), h + Vector2(26 + f * 4, 74), 14.0, col.darkened(0.15))
	ci.draw_polyline(PackedVector2Array([h + Vector2(6, 26), h + Vector2(36, 48), h + Vector2(54, 36)]), INK, 14.0, true)
	ci.draw_polyline(PackedVector2Array([h + Vector2(6, 26), h + Vector2(36, 48), h + Vector2(54, 36)]), Color("#e8fbff"), 8.0, true)
	_eye(ci, h + Vector2(12, -10), 7.0, acc)
	_eye(ci, h + Vector2(28, -12), 6.0, acc)
