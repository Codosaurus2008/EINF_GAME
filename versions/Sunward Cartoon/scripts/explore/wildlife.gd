class_name Wildlife
extends Interactable
## A native animal on a round planet: built from simple shapes (body plan from Biomes.SPECIES),
## wanders around its habitat, idles, reacts to the player's capsule (curious ones come and look,
## shy ones keep away). "Up" is always away from the planet centre.
## Later: feeding, helping, quests - add them in interact() / the ExploreScreen window.

var species_id := ""
var sp: Dictionary
var world: SphereWorld
var plan := "walker"
var size := 1.0
## final animal size: species size number x 0.3 (was 0.125 - they were hardly visible);
## most are 15-70 cm, giants 1-2 m (the explorer is 60 cm)
const SCALE := 0.3
var speed := 1.0
var home := Vector3.ZERO
var target := Vector3.ZERO
var state := "idle"
var timer := 0.0
var t := 0.0
var heading := Vector3.FORWARD      # where it faces, along the ground
var moving := 0.0               # 0..1, smoothed, drives the walk animation
var rng := RandomNumberGenerator.new()

var body: Node3D                # turns with the animal
var bob: Node3D                 # moves up/down (breathing, hopping)
var legs: Array = []            # [pivot, phase offset]
var wings: Array = []
var tendrils: Array = []
var ears: Array = []
var tail: Node3D
var head: Node3D
var hop := 0.0                  # hop progress 0..1
var fly_angle := 0.0
var fly_radius := 8.0
var lod_skip := 0
var lod_dt := 0.0
var swim_depth := 0.5           # sea animals: current depth under the surface
var swim_goal := 0.5
var leap := -1.0                # swimmer jump progress (-1 = swimming)
var want_feed := false          # walking to a plant / the water to eat or drink
var idle_mode := ""             # while standing: look (around), graze (eat), rest
var held := false               # carried by the player (position set by the ExploreScreen)
var segs: Array = []            # crawler body segments
var organs: Array = []          # glowing inner parts that pulse
var eyes: Array = []            # blink and look around
var genes: Dictionary = {}      # xenobiology body plan (Xeno)
var loc := ""                   # how a "xeno" species moves
var leader: Wildlife = null     # swarm animals follow their leader
var swarm_off := Vector3.ZERO
var submerged := 0.0            # burrowers: 0 = out, 1 = under the ground
var burrow_t := 0.0
var climb_c := Vector3.ZERO     # climbers: foot of the tree / spire they climb
var climb_r := 0.0
var climb_h := 0.0
var climb_a := 0.0
var climb_goal := 2.0
var custom_basis := false
var check_t := 0.0
var blink_t := 2.0
var feed_goal := false
# personality: every animal of a species reacts a little differently
var bold := 0.5                 # 0 very shy (runs early) .. 1 bold (comes close, investigates)
var partner: Wildlife = null    # a member of its own kind it is going to / greeting
var heard_t := -100.0           # last noise it reacted to (world time)

static var _skins := {}


func setup(id: String, w: SphereWorld, pos: Vector3, seed_value: int) -> void:
	species_id = id
	sp = Biomes.species(id)
	world = w
	plan = sp["plan"]
	size = float(sp["size"]) * SCALE
	speed = float(sp["speed"]) * 0.6
	title = sp["name"]
	key = "animal:" + id
	reach = 1.2
	rng.seed = seed_value
	bold = clampf(rng.randfn(0.5, 0.22) + (0.15 if bool(sp.get("curious", false)) else 0.0) + (0.2 if bool(sp.get("predator", false)) else 0.0), 0.0, 1.0)
	home = pos
	position = pos
	target = pos
	basis = SphereTerrain.surface_basis(pos.normalized(), rng.randf() * TAU)
	heading = basis.z
	fly_angle = rng.randf() * TAU
	fly_radius = rng.randf_range(2.0, 4.5) * (1.0 + float(sp["size"]) * 0.3)
	timer = rng.randf_range(0.0, 3.0)
	_build()


func prompt() -> String:
	return "Observe " + title


func interact(screen: Node) -> void:
	screen.call("open_animal", self)


# ================================================================== looks
func _mat(c: Color, glow := false, energy := 1.2) -> StandardMaterial3D:
	if glow:
		return WorldProps.std(c, 0.6, 0.0, c, energy)
	return skin(c)


## Skin with fine scales / fur pattern and small bumps (instead of plain colour)
static func skin(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _skins.has(key):
		return _skins[key]
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.08
	n.fractal_octaves = 2
	var g := Gradient.new()
	g.set_color(0, Color(0.62, 0.62, 0.62))
	g.set_color(1, Color(1.08, 1.08, 1.08))
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	tex.noise = n
	tex.color_ramp = g
	var nt := NoiseTexture2D.new()
	nt.width = 128
	nt.height = 128
	nt.seamless = true
	nt.noise = n
	nt.as_normal_map = true
	nt.bump_strength = 4.0
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = nt
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	m.roughness = 0.7
	m.rim_enabled = true
	m.rim = 0.25
	_skins[key] = Cartoon.toon(m)
	return m


func _build() -> void:
	body = Node3D.new()
	add_child(body)
	bob = Node3D.new()
	body.add_child(bob)
	var col: Color = sp["color"]
	var acc: Color = sp["accent"]
	var glow := bool(sp.get("glow", false))
	var s := size
	if Cartoon.ON:
		_cartoon_sprite.call_deferred(s)
	if sp.has("model"):
		match str(sp["model"]):
			"giant_fly":
				_build_giant_fly(col, acc, s)
			"woolly_giant":
				_build_woolly_giant(col, acc, s)
		add_hitbox(maxf(0.5, s * 0.9), Vector3(0, s * 0.6, 0))
		return
	match plan:
		"walker":
			_build_walker(col, acc, glow, s)
		"hopper":
			_build_hopper(col, acc, glow, s)
		"floater":
			_build_floater(col, acc, s)
		"flyer":
			_build_flyer(col, acc, glow, s)
		"swimmer":
			_build_swimmer(col, acc, s)
		"crawler":
			_build_crawler(col, acc, glow, s)
		"gasbag":
			_build_gasbag(col, acc, s)
		"tripod":
			_build_tripod(col, acc, glow, s)
		"skimmer":
			_build_skimmer(col, acc, glow, s)
		"jelly":
			_build_jelly(col, acc, s)
		"xeno":
			genes = sp.get("genes", {})
			loc = str(genes.get("loc", "legs"))
			Xeno.build(self, species_id, genes, s, rng)
	add_hitbox(maxf(0.5, s * 0.9), Vector3(0, s * 0.6, 0))


## Ferrum's giant fly: as big as the explorer, a heavy segmented abdomen, a glowing yellow spine
## of plates from head to tail, four big yellow eyes, four veined wings, six dangling legs
func _build_giant_fly(col: Color, acc: Color, s: float) -> void:
	var shell := WorldProps.std(col, 0.35, 0.55)
	var dark := WorldProps.std(col.darkened(0.55), 0.5, 0.3)
	var glow_m := WorldProps.std(Color("#ffd23a"), 0.3, 0.0, Color("#ffcf20"), 3.2)
	# thorax and abdomen (segments, slightly drooping)
	WorldProps.part(bob, WorldProps.sphere(1.0, 16, 10), shell, Vector3(0, 0, s * 0.1), Vector3.ZERO, Vector3(s * 0.26, s * 0.24, s * 0.3))
	for i in 5:
		var k := float(i) / 4.0
		var r := lerpf(0.28, 0.12, k) * s
		WorldProps.part(bob, WorldProps.sphere(1.0, 14, 8), shell if i % 2 == 0 else dark, Vector3(0, -k * s * 0.12, -s * 0.2 - k * s * 0.55), Vector3(0.15 * k, 0, 0), Vector3(r, r * 0.92, r * 0.9))
	# the glowing spine: plates along the back
	for i in 8:
		var k2 := float(i) / 7.0
		var y := lerpf(s * 0.24, s * 0.1, k2) - k2 * k2 * s * 0.08
		var z := lerpf(s * 0.3, -s * 0.72, k2)
		WorldProps.part(bob, WorldProps.box(Vector3(s * 0.05, s * 0.09 * (1.0 - k2 * 0.5), s * 0.07)), glow_m, Vector3(0, y, z), Vector3(-0.3, 0, 0))
	# head with four big yellow eyes (two over two)
	head = Node3D.new()
	head.position = Vector3(0, s * 0.03, s * 0.42)
	bob.add_child(head)
	WorldProps.part(head, WorldProps.sphere(1.0, 14, 8), dark, Vector3.ZERO, Vector3.ZERO, Vector3(s * 0.17, s * 0.15, s * 0.15))
	var eye_m := WorldProps.std(Color("#ffe14a"), 0.15, 0.0, Color("#ffd400"), 2.4)
	for ey: float in [-1.0, 1.0]:
		for ex: float in [-1.0, 1.0]:
			WorldProps.part(head, WorldProps.sphere(s * 0.065, 12, 8), eye_m, Vector3(ex * s * 0.09, s * 0.03 + ey * s * 0.065, s * 0.1))
	WorldProps.part(head, WorldProps.cyl(s * 0.015, s * 0.03, s * 0.14, 6), dark, Vector3(0, -s * 0.09, s * 0.1), Vector3(0.9, 0, 0))
	# four wings (two pairs), see-through with dark veins
	var wing_m := WorldProps.std(Color(0.85, 0.9, 0.8, 0.35), 0.15, 0.0, Color(0.4, 0.35, 0.1), 0.3, 0.35)
	for pair in 2:
		for sx: float in [-1.0, 1.0]:
			var pv := Node3D.new()
			pv.position = Vector3(sx * s * 0.12, s * 0.2, s * (0.12 - pair * 0.16))
			bob.add_child(pv)
			WorldProps.part(pv, WorldProps.sphere(1.0, 12, 4), wing_m, Vector3(sx * s * 0.45, 0, -s * 0.12), Vector3(0, sx * (0.25 + pair * 0.25), 0), Vector3(s * 0.48, s * 0.012, s * 0.17))
			WorldProps.part(pv, WorldProps.cyl(s * 0.006, s * 0.006, s * 0.85, 4), dark, Vector3(sx * s * 0.42, s * 0.01, -s * 0.12), Vector3(0, sx * (0.25 + pair * 0.25), PI / 2))
			wings.append([pv, sx])
	# six thin legs hanging below
	for i in 3:
		for sx: float in [-1.0, 1.0]:
			var lp := Node3D.new()
			lp.position = Vector3(sx * s * 0.12, -s * 0.15, s * (0.2 - i * 0.14))
			bob.add_child(lp)
			WorldProps.part(lp, WorldProps.cyl(s * 0.012, s * 0.018, s * 0.32, 5), dark, Vector3(sx * s * 0.05, -s * 0.15, 0), Vector3(0.3, 0, sx * 0.35))
			legs.append([lp, i * 1.3 + (0.0 if sx < 0.0 else 0.6)])


## Glacia's woolly giant: a huge shaggy walker made of hanging clumps of fur, four pillar legs,
## a drooping snout, curved ice tusks, small glowing eyes deep in the fur
func _build_woolly_giant(col: Color, acc: Color, s: float) -> void:
	var fur := skin(col)
	var fur_d := skin(col.darkened(0.2))
	var leg_len := s * 0.45
	var by := leg_len + s * 0.35
	# the body: a big core with many fur clumps hanging from it
	WorldProps.part(bob, WorldProps.sphere(1.0, 18, 12), fur, Vector3(0, by, 0), Vector3.ZERO, Vector3(s * 0.5, s * 0.45, s * 0.7))
	for i in 34:
		var a := rng.randf() * TAU
		var z := rng.randf_range(-0.6, 0.6) * s
		var y := by + rng.randf_range(-0.2, 0.35) * s
		var r := rng.randf_range(0.13, 0.22) * s
		var p := Vector3(cos(a) * s * 0.45, y - by + sin(a) * s * 0.25, z)
		if p.y < -s * 0.1:
			p.y = -s * 0.1
		WorldProps.part(bob, WorldProps.sphere(1.0, 10, 6), fur if i % 3 else fur_d, Vector3(p.x, by + p.y, p.z), Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3)), Vector3(r, r * 1.6, r))
	# a fringe hanging low
	for i in 18:
		var a2 := TAU * i / 18.0
		var fp := Vector3(cos(a2) * s * 0.48, by - s * 0.32, sin(a2) * s * 0.66)
		WorldProps.part(bob, WorldProps.sphere(1.0, 8, 6), fur_d, fp, Vector3.ZERO, Vector3(s * 0.09, s * 0.2, s * 0.09))
	# four pillar legs
	var leg_m := skin(col.darkened(0.35))
	for i in 2:
		for sx: float in [-1.0, 1.0]:
			var pv := Node3D.new()
			pv.position = Vector3(sx * s * 0.3, by - s * 0.2, (s * 0.38 if i == 0 else -s * 0.38))
			bob.add_child(pv)
			WorldProps.part(pv, WorldProps.cyl(s * 0.12, s * 0.15, leg_len + s * 0.2, 10), leg_m, Vector3(0, -(leg_len + s * 0.2) * 0.5, 0))
			WorldProps.part(pv, WorldProps.cyl(s * 0.16, s * 0.17, s * 0.06, 10), WorldProps.std(Color("#3a3a44"), 0.7), Vector3(0, -(leg_len + s * 0.22), 0))
			legs.append([pv, i * PI + (0.0 if sx < 0.0 else PI)])
	# head: shaggy, snout, tusks, eyes
	head = Node3D.new()
	head.position = Vector3(0, by + s * 0.12, s * 0.72)
	bob.add_child(head)
	WorldProps.part(head, WorldProps.sphere(1.0, 14, 8), fur, Vector3.ZERO, Vector3.ZERO, Vector3(s * 0.3, s * 0.28, s * 0.26))
	WorldProps.part(head, WorldProps.cyl(s * 0.04, s * 0.09, s * 0.5, 8), fur_d, Vector3(0, -s * 0.22, s * 0.18), Vector3(0.35, 0, 0))
	var ice := WorldProps.std(Color("#cfefff"), 0.08, 0.0, Color("#7fd0ff"), 0.6, 0.85)
	for sx: float in [-1.0, 1.0]:
		var pts: Array = CMesh.curve(Vector3(sx * s * 0.12, -s * 0.1, s * 0.12), Vector3(sx * s * 0.2, s * 0.08, s * 0.55), Vector3(sx * s * 0.05, -s * 0.2, 0.0), 6)
		var tusk := MeshInstance3D.new()
		tusk.mesh = CMesh.tube(pts, CMesh.taper(6, s * 0.035, s * 0.008), 7)
		tusk.material_override = ice
		head.add_child(tusk)
	_eyes(head, Vector3(0, s * 0.08, s * 0.2), s * 0.11, s * 0.035, true, Color("#7fd8ff"))


## "" if the player may pick it up, otherwise the reason why not
func carry_reason() -> String:
	if sp.has("carry_note"):
		return str(sp["carry_note"])
	if plan == "jelly":
		return "Its stinging threads burn - better not touch it."
	if (plan == "swimmer" or loc == "swim") and size > 0.6 * SCALE:
		return "Too big and strong - it slips out of your hands."
	if plan in ["flyer", "skimmer"] or loc == "wing":
		return "It flutters away whenever you reach for it."
	if loc == "sessile":
		return "It is rooted to the ground."
	if loc == "burrow" and submerged > 0.5:
		return "It is hiding under the ground."
	if size > 0.85 * SCALE:
		return "Far too big and heavy to carry."
	return ""


## Lives in the water (needs the sea)?
func aquatic() -> bool:
	return plan in ["swimmer", "jelly"] or loc == "swim"


func set_held(on: bool) -> void:
	held = on
	if on:
		state = "held"
	else:
		state = "idle"
		timer = 1.5
		moving = 0.0
		scale = Vector3.ONE
		target = position


func _eyes(parent: Node3D, pos: Vector3, gap: float, r: float, glow: bool, acc: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		WorldProps.part(parent, WorldProps.sphere(r, 8, 4), _mat(acc if glow else Color("#101010"), glow, 2.0), pos + Vector3(sx * gap, 0, 0))
		if not glow:
			WorldProps.part(parent, WorldProps.sphere(r * 0.35, 6, 3), _mat(Color.WHITE, true, 1.0), pos + Vector3(sx * gap + r * 0.3, r * 0.4, r * 0.6))


func _build_walker(col: Color, acc: Color, glow: bool, s: float) -> void:
	var leg_len := s * (1.0 if bool(sp.get("long_legs", false)) else 0.5)
	var by := leg_len + s * 0.2
	var bm := _mat(col)
	WorldProps.part(bob, WorldProps.sphere(1.0, 14, 8), bm, Vector3(0, by, 0), Vector3.ZERO, Vector3(s * 0.55, s * 0.38, s * 0.85))
	# legs in pairs along the body
	var pairs := int(sp.get("legs", 2))
	var leg_m := _mat(col.darkened(0.3))
	for i in pairs:
		var z := 0.0 if pairs == 1 else lerpf(s * 0.45, -s * 0.45, float(i) / (pairs - 1))
		for sx: float in [-1.0, 1.0]:
			var pv := Node3D.new()
			pv.position = Vector3(sx * s * 0.4, by - s * 0.1, z)
			bob.add_child(pv)
			var lr := s * 0.07
			WorldProps.part(pv, WorldProps.cyl(lr, lr * 0.8, leg_len + s * 0.1, 6), leg_m, Vector3(sx * s * 0.08, -(leg_len + s * 0.1) * 0.5, 0), Vector3(0, 0, sx * 0.25))
			legs.append([pv, (i % 2) * PI + (0.0 if sx < 0.0 else PI)])
	# head (on a neck for grazers)
	head = Node3D.new()
	bob.add_child(head)
	if bool(sp.get("neck", false)):
		WorldProps.part(bob, WorldProps.cyl(s * 0.09, s * 0.14, s * 0.9, 8), bm, Vector3(0, by + s * 0.45, s * 0.7), Vector3(-0.6, 0, 0))
		head.position = Vector3(0, by + s * 0.85, s * 1.0)
	else:
		head.position = Vector3(0, by + s * 0.12, s * 0.85)
	WorldProps.part(head, WorldProps.sphere(1.0, 12, 6), bm, Vector3.ZERO, Vector3.ZERO, Vector3(s * 0.26, s * 0.22, s * 0.3))
	_eyes(head, Vector3(0, s * 0.07, s * 0.22), s * 0.12, s * 0.055, glow, acc)
	if bool(sp.get("sideways", false)):      # crab claws
		for sx: float in [-1.0, 1.0]:
			WorldProps.part(head, WorldProps.sphere(1.0, 10, 5), _mat(col.lightened(0.1)), Vector3(sx * s * 0.35, -s * 0.05, s * 0.25), Vector3.ZERO, Vector3(s * 0.16, s * 0.12, s * 0.22))
	if bool(sp.get("tail", false)):
		tail = Node3D.new()
		tail.position = Vector3(0, by, -s * 0.8)
		bob.add_child(tail)
		WorldProps.part(tail, WorldProps.cyl(s * 0.02, s * 0.1, s * 1.2, 6), bm, Vector3(0, 0.1, -s * 0.55), Vector3(-1.3, 0, 0))
	# what grows on the back
	var back := str(sp.get("back", ""))
	var top := Vector3(0, by + s * 0.3, 0)
	match back:
		"crystals":
			for i in 4:
				WorldProps.part(bob, WorldProps.cyl(0.0, s * 0.08, s * 0.35, 6), _mat(acc, true, 1.8),
					top + Vector3(rng.randf_range(-0.2, 0.2) * s, s * 0.1, (i - 1.5) * s * 0.25), Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)))
		"spikes":
			for i in 5:
				WorldProps.part(bob, WorldProps.cyl(0.0, s * 0.06, s * 0.5, 6), WorldProps.std(acc, 0.1, 0.2, Color("#7fd0ff"), 0.6, 0.85),
					top + Vector3(0, s * 0.15, (i - 2) * s * 0.22), Vector3(-0.3 + i * 0.15, 0, 0))
		"mushroom":
			WorldProps.part(bob, WorldProps.cyl(s * 0.08, s * 0.1, s * 0.3, 8), _mat(Color("#e8dccc")), top + Vector3(0, s * 0.1, 0))
			WorldProps.part(bob, WorldProps.sphere(1.0, 14, 6, true), _mat(acc, true, 0.5), top + Vector3(0, s * 0.25, 0), Vector3.ZERO, Vector3(s * 0.5, s * 0.3, s * 0.5))
		"shell":
			WorldProps.part(bob, WorldProps.sphere(1.0, 14, 6, true), _mat(col.lightened(0.15)), Vector3(0, by - s * 0.02, 0), Vector3.ZERO, Vector3(s * 0.62, s * 0.4, s * 0.8))
			for i in 3:
				WorldProps.part(bob, WorldProps.torus(s * 0.25 + i * s * 0.12, s * 0.28 + i * s * 0.12, 16), _mat(acc), Vector3(0, by + s * 0.3 - i * s * 0.1, 0), Vector3.ZERO, Vector3(1.0, 1.0, 1.25))
		"leaves":
			for i in 5:
				WorldProps.part(bob, WorldProps.sphere(1.0, 8, 4), _mat(acc.darkened(0.3)), top + Vector3(0, 0, (i - 2) * s * 0.25), Vector3(0, 0, (i % 2 * 2 - 1) * 0.6), Vector3(s * 0.4, s * 0.03, s * 0.14))
		"cracks":
			for i in 3:
				WorldProps.part(bob, WorldProps.torus(s * 0.5, s * 0.56, 16), _mat(acc, true, 3.0), Vector3(0, by, (i - 1) * s * 0.35), Vector3(PI / 2, 0, 0), Vector3(1.0, 1.0, 0.7))
		"rod":
			WorldProps.part(head, WorldProps.cyl(s * 0.025, s * 0.03, s * 0.7, 6), WorldProps.std(Color("#b0b8c8"), 0.3, 0.9), Vector3(0, s * 0.45, 0))
			WorldProps.part(head, WorldProps.sphere(s * 0.08, 8, 4), _mat(acc, true, 3.0), Vector3(0, s * 0.82, 0))
		"fur":
			# thick insulating coat: many soft tufts over the body
			var fm := _mat(col.lightened(0.08))
			for i in 26:
				var a := rng.randf() * TAU
				var z := rng.randf_range(-0.75, 0.75)
				var p := Vector3(cos(a) * s * 0.5, by + sin(a) * s * 0.32 + s * 0.06, z * s * 0.8)
				if p.y < by - s * 0.15:
					continue
				WorldProps.part(bob, WorldProps.sphere(1.0, 8, 5), fm, p, Vector3.ZERO, Vector3.ONE * s * rng.randf_range(0.14, 0.22))
		"plates":
			# overlapping mineral plates with hot glowing seams
			var pm := WorldProps.std(col.lightened(0.1), 0.45, 0.4)
			for i in 5:
				var z2 := (i - 2) * s * 0.3
				WorldProps.part(bob, WorldProps.sphere(1.0, 12, 5, true), pm, Vector3(0, by + s * 0.12, z2), Vector3(-0.15 + i * 0.07, 0, 0), Vector3(s * 0.55, s * 0.32, s * 0.24))
				WorldProps.part(bob, WorldProps.torus(s * 0.42, s * 0.46, 14), WorldProps.std(acc, 0.4, 0.0, acc, 2.5), Vector3(0, by + s * 0.05, z2 + s * 0.12), Vector3(PI / 2, 0, 0), Vector3(1.0, 1.0, 0.6))
		"antlers":
			for sx: float in [-1.0, 1.0]:
				var a := Node3D.new()
				a.position = Vector3(sx * s * 0.12, s * 0.15, 0)
				a.rotation = Vector3(-0.3, 0, -sx * 0.5)
				head.add_child(a)
				var cm := WorldProps.std(acc, 0.05, 0.2, Color("#ffe6a0"), 1.6, 0.85)
				WorldProps.part(a, WorldProps.cyl(0.0, s * 0.05, s * 0.8, 6), cm, Vector3(0, s * 0.4, 0))
				WorldProps.part(a, WorldProps.cyl(0.0, s * 0.035, s * 0.45, 6), cm, Vector3(sx * s * 0.12, s * 0.45, 0), Vector3(0, 0, -sx * 0.7))


func _build_hopper(col: Color, acc: Color, glow: bool, s: float) -> void:
	var bm := _mat(col)
	WorldProps.part(bob, WorldProps.sphere(1.0, 16, 8), bm, Vector3(0, s * 0.5, 0), Vector3.ZERO, Vector3(s * 0.5, s * 0.46, s * 0.52))
	head = Node3D.new()
	head.position = Vector3(0, s * 0.62, s * 0.3)
	bob.add_child(head)
	_eyes(head, Vector3(0, 0, s * 0.18), s * 0.15, s * 0.07, glow, acc)
	for sx: float in [-1.0, 1.0]:
		var e := Node3D.new()
		e.position = Vector3(sx * s * 0.2, s * 0.85, 0)
		bob.add_child(e)
		if str(sp.get("ears", "")) == "antennae":
			WorldProps.part(e, WorldProps.cyl(s * 0.015, s * 0.02, s * 0.7, 5), _mat(col.darkened(0.2)), Vector3(0, s * 0.35, 0), Vector3(0, 0, -sx * 0.3))
			WorldProps.part(e, WorldProps.sphere(s * 0.07, 8, 4), _mat(acc, true, 2.5), Vector3(-sx * s * 0.1, s * 0.7, 0))
		else:
			WorldProps.part(e, WorldProps.sphere(1.0, 10, 5), _mat(col), Vector3(0, s * 0.3, 0), Vector3(0, 0, -sx * 0.25), Vector3(s * 0.09, s * 0.35, s * 0.05))
			WorldProps.part(e, WorldProps.sphere(1.0, 8, 4), _mat(acc), Vector3(0, s * 0.3, s * 0.02), Vector3(0, 0, -sx * 0.25), Vector3(s * 0.05, s * 0.26, s * 0.04))
		ears.append(e)
		WorldProps.part(bob, WorldProps.sphere(1.0, 8, 4), _mat(col.darkened(0.15)), Vector3(sx * s * 0.22, s * 0.08, s * 0.12), Vector3.ZERO, Vector3(s * 0.12, s * 0.08, s * 0.2))


func _build_floater(col: Color, acc: Color, s: float) -> void:
	var dome := ExploreShaders.nature(col, col, 1.4, 0.0, 0.5, 0.3)
	WorldProps.part(bob, WorldProps.sphere(1.0, 16, 8, true), dome, Vector3.ZERO, Vector3.ZERO, Vector3(s * 0.55, s * 0.5, s * 0.55))
	WorldProps.part(bob, WorldProps.sphere(s * 0.22, 10, 5), WorldProps.std(acc, 0.3, 0.0, acc, 2.5), Vector3(0, s * 0.18, 0))
	for i in 7:
		var a := TAU * i / 7.0
		var pv := Node3D.new()
		pv.position = Vector3(cos(a) * s * 0.38, 0, sin(a) * s * 0.38)
		bob.add_child(pv)
		var l := s * rng.randf_range(0.6, 1.1)
		WorldProps.part(pv, WorldProps.cyl(s * 0.015, s * 0.035, l, 5), WorldProps.std(col, 0.4, 0.0, col, 1.2, 0.8), Vector3(0, -l * 0.5, 0))
		tendrils.append([pv, a])
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 0.9
	light.omni_range = 5.0
	light.position = Vector3(0, s * 0.1, 0)
	bob.add_child(light)


func _build_flyer(col: Color, acc: Color, glow: bool, s: float) -> void:
	var bm := _mat(col)
	WorldProps.part(bob, WorldProps.sphere(1.0, 10, 6), bm, Vector3.ZERO, Vector3.ZERO, Vector3(s * 0.16, s * 0.14, s * 0.45))
	head = Node3D.new()
	head.position = Vector3(0, s * 0.04, s * 0.4)
	bob.add_child(head)
	WorldProps.part(head, WorldProps.sphere(s * 0.12, 8, 4), bm, Vector3.ZERO)
	_eyes(head, Vector3(0, s * 0.04, s * 0.08), s * 0.06, s * 0.035, glow, acc)
	var wm := WorldProps.std(acc, 0.5, 0.0, acc if glow else Color.BLACK, 1.5, 0.9)
	for sx: float in [-1.0, 1.0]:
		var pv := Node3D.new()
		pv.position = Vector3(sx * s * 0.12, s * 0.05, 0)
		bob.add_child(pv)
		WorldProps.part(pv, WorldProps.sphere(1.0, 10, 4), wm, Vector3(sx * s * 0.5, 0, 0), Vector3.ZERO, Vector3(s * 0.5, s * 0.02, s * 0.32))
		wings.append([pv, sx])
	WorldProps.part(bob, WorldProps.sphere(1.0, 8, 4), wm, Vector3(0, 0, -s * 0.5), Vector3.ZERO, Vector3(s * 0.2, s * 0.02, s * 0.25))


func _build_swimmer(col: Color, acc: Color, s: float) -> void:
	var bm := WorldProps.std(col, 0.3, 0.1)
	WorldProps.part(bob, WorldProps.sphere(1.0, 14, 6), bm, Vector3.ZERO, Vector3.ZERO, Vector3(s * 0.35, s * 0.1, s * 0.55))
	for sx: float in [-1.0, 1.0]:
		var pv := Node3D.new()
		pv.position = Vector3(sx * s * 0.25, 0, 0)
		bob.add_child(pv)
		WorldProps.part(pv, WorldProps.sphere(1.0, 10, 4), bm, Vector3(sx * s * 0.45, 0, -s * 0.05), Vector3(0, sx * 0.4, 0), Vector3(s * 0.55, s * 0.04, s * 0.3))
		WorldProps.part(pv, WorldProps.sphere(s * 0.05, 6, 3), WorldProps.std(acc, 0.3, 0.0, acc, 2.5), Vector3(sx * s * 0.7, s * 0.03, -s * 0.05))
		wings.append([pv, sx])
	WorldProps.part(bob, WorldProps.cyl(s * 0.005, s * 0.03, s * 1.0, 5), bm, Vector3(0, 0, -s * 0.9), Vector3(PI / 2, 0, 0))
	_eyes(bob, Vector3(0, s * 0.06, s * 0.45), s * 0.12, s * 0.04, true, acc)


# ---------------------------------------------------------------- new alien body plans
## Many-legged crawler: a chain of plated segments, a pair of short legs on each, feelers
func _build_crawler(col: Color, acc: Color, glow: bool, s: float) -> void:
	var count := int(sp.get("segments", 7))
	var bm := _mat(col)
	var plate := _mat(col.lightened(0.12))
	for i in count:
		var sg := Node3D.new()
		var r := s * (0.2 - absf(i - count * 0.3) * 0.012)
		sg.position = Vector3(0, s * 0.22, s * 0.45 - i * s * 0.2)
		sg.set_meta("y0", sg.position.y)
		bob.add_child(sg)
		segs.append(sg)
		WorldProps.part(sg, WorldProps.sphere(1.0, 12, 6), bm, Vector3.ZERO, Vector3.ZERO, Vector3(r * 1.2, r * 0.8, r * 1.1))
		WorldProps.part(sg, WorldProps.sphere(1.0, 12, 6, true), plate, Vector3(0, r * 0.25, 0), Vector3.ZERO, Vector3(r * 1.3, r * 0.7, r * 1.0))
		if glow and i % 2 == 1:
			var o := WorldProps.part(sg, WorldProps.sphere(1.0, 8, 4), WorldProps.std(acc, 0.4, 0.0, acc, 2.5), Vector3(0, r * 0.75, 0), Vector3.ZERO, Vector3.ONE * r * 0.25)
			organs.append([o, r * 0.25, float(i)])
		for sx: float in [-1.0, 1.0]:
			var pv := Node3D.new()
			pv.position = Vector3(sx * r * 0.9, 0, 0)
			sg.add_child(pv)
			WorldProps.part(pv, WorldProps.cyl(r * 0.08, r * 0.12, r * 1.6, 5), _mat(col.darkened(0.35)), Vector3(sx * r * 0.5, -r * 0.5, 0), Vector3(0, 0, sx * 0.9))
			legs.append([pv, i * 0.9 + (0.0 if sx < 0.0 else PI)])
	head = segs[0]
	_eyes(head, Vector3(0, s * 0.06, s * 0.2), s * 0.07, s * 0.035, glow, acc)
	for sx: float in [-1.0, 1.0]:
		WorldProps.part(head, WorldProps.cyl(s * 0.008, s * 0.015, s * 0.6, 4), bm, Vector3(sx * s * 0.08, s * 0.15, s * 0.42), Vector3(1.0, 0, -sx * 0.4))


## Floating organism: a see-through gas sac with glowing organs, fin membranes and long tendrils
func _build_gasbag(col: Color, acc: Color, s: float) -> void:
	var sac := WorldProps.std(col, 0.15, 0.0, col.darkened(0.4), 0.6, 0.55)
	WorldProps.part(bob, WorldProps.sphere(1.0, 20, 12), sac, Vector3(0, s * 0.3, 0), Vector3.ZERO, Vector3(s * 0.7, s * 0.6, s * 0.8))
	for i in 3:
		var o := WorldProps.part(bob, WorldProps.sphere(1.0, 10, 5), WorldProps.std(acc, 0.3, 0.0, acc, 3.0),
			Vector3(rng.randf_range(-0.2, 0.2) * s, s * (0.15 + i * 0.12), rng.randf_range(-0.2, 0.2) * s), Vector3.ZERO, Vector3.ONE * s * 0.13)
		organs.append([o, s * 0.13, float(i) * 1.7])
	# ridge of membrane fins
	for sx: float in [-1.0, 1.0]:
		var pv := Node3D.new()
		pv.position = Vector3(sx * s * 0.55, s * 0.25, 0)
		bob.add_child(pv)
		WorldProps.part(pv, WorldProps.sphere(1.0, 12, 4), WorldProps.std(acc.lerp(col, 0.5), 0.3, 0.0, acc, 0.4, 0.6), Vector3(sx * s * 0.35, 0, 0), Vector3.ZERO, Vector3(s * 0.45, s * 0.02, s * 0.5))
		wings.append([pv, sx])
	for i in 9:
		var a := TAU * i / 9.0
		var pv := Node3D.new()
		pv.position = Vector3(cos(a) * s * 0.35, -s * 0.15, sin(a) * s * 0.35)
		bob.add_child(pv)
		var l := s * rng.randf_range(1.0, 2.2)
		WorldProps.part(pv, WorldProps.cyl(s * 0.01, s * 0.03, l, 4), WorldProps.std(col.darkened(0.2), 0.4, 0.0, acc, 0.5, 0.8), Vector3(0, -l * 0.5, 0))
		WorldProps.part(pv, WorldProps.sphere(s * 0.035, 6, 3), WorldProps.std(acc, 0.3, 0.0, acc, 3.0), Vector3(0, -l, 0))
		tendrils.append([pv, a])
	var light := OmniLight3D.new()
	light.light_color = acc
	light.light_energy = 0.7
	light.omni_range = 5.0
	bob.add_child(light)


## Tall walker on three long jointed legs, body high above the ground, sensor stalk on top
func _build_tripod(col: Color, acc: Color, glow: bool, s: float) -> void:
	var leg_len := s * 1.6
	var bm := _mat(col)
	WorldProps.part(bob, WorldProps.sphere(1.0, 16, 8), bm, Vector3(0, leg_len, 0), Vector3.ZERO, Vector3(s * 0.45, s * 0.3, s * 0.45))
	WorldProps.part(bob, WorldProps.sphere(1.0, 16, 8, true), _mat(col.lightened(0.15)), Vector3(0, leg_len + s * 0.05, 0), Vector3.ZERO, Vector3(s * 0.5, s * 0.25, s * 0.5))
	for i in 3:
		var a := TAU * i / 3.0
		var pv := Node3D.new()
		pv.position = Vector3(cos(a) * s * 0.3, leg_len, sin(a) * s * 0.3)
		pv.rotation.y = -a
		bob.add_child(pv)
		var lm := _mat(col.darkened(0.25))
		WorldProps.part(pv, WorldProps.cyl(s * 0.04, s * 0.06, leg_len * 0.6, 6), lm, Vector3(s * 0.25, -leg_len * 0.2, 0), Vector3(0, 0, 0.9))
		WorldProps.part(pv, WorldProps.sphere(s * 0.07, 8, 4), _mat(acc) if not glow else WorldProps.std(acc, 0.4, 0.0, acc, 1.5), Vector3(s * 0.5, -leg_len * 0.38, 0))
		WorldProps.part(pv, WorldProps.cyl(s * 0.02, s * 0.04, leg_len * 0.75, 6), lm, Vector3(s * 0.55, -leg_len * 0.72, 0), Vector3(0, 0, -0.15))
		legs.append([pv, i * TAU / 3.0])
	head = Node3D.new()
	head.position = Vector3(0, leg_len + s * 0.3, 0)
	bob.add_child(head)
	WorldProps.part(head, WorldProps.cyl(s * 0.03, s * 0.04, s * 0.5, 6), bm, Vector3(0, s * 0.25, 0))
	WorldProps.part(head, WorldProps.sphere(1.0, 12, 6), bm, Vector3(0, s * 0.55, s * 0.05), Vector3.ZERO, Vector3(s * 0.16, s * 0.12, s * 0.2))
	_eyes(head, Vector3(0, s * 0.58, s * 0.2), s * 0.07, s * 0.04, glow, acc)
	if bool(sp.get("crown", false)):
		WorldProps.part(head, WorldProps.sphere(1.0, 14, 6, true), WorldProps.std(acc, 0.5, 0.0, acc, 0.8), Vector3(0, s * 0.68, 0), Vector3.ZERO, Vector3(s * 0.35, s * 0.15, s * 0.35))


## Flyer with two pairs of wings and a long tail filament
func _build_skimmer(col: Color, acc: Color, glow: bool, s: float) -> void:
	var bm := _mat(col)
	WorldProps.part(bob, WorldProps.sphere(1.0, 12, 6), bm, Vector3.ZERO, Vector3.ZERO, Vector3(s * 0.1, s * 0.09, s * 0.5))
	head = Node3D.new()
	head.position = Vector3(0, 0, s * 0.45)
	bob.add_child(head)
	WorldProps.part(head, WorldProps.sphere(s * 0.09, 8, 4), bm, Vector3.ZERO)
	_eyes(head, Vector3(0, s * 0.03, s * 0.05), s * 0.05, s * 0.03, true, acc)
	var wm := WorldProps.std(acc, 0.2, 0.0, acc if glow else Color.BLACK, 1.2, 0.55)
	for pair in 2:
		for sx: float in [-1.0, 1.0]:
			var pv := Node3D.new()
			pv.position = Vector3(sx * s * 0.08, s * 0.03, s * (0.15 - pair * 0.3))
			bob.add_child(pv)
			WorldProps.part(pv, WorldProps.sphere(1.0, 10, 4), wm, Vector3(sx * s * 0.42, 0, 0), Vector3(0, sx * (0.2 + pair * 0.2), 0), Vector3(s * 0.45, s * 0.015, s * 0.16))
			wings.append([pv, sx, pair * PI * 0.6])
	tail = Node3D.new()
	tail.position = Vector3(0, 0, -s * 0.5)
	bob.add_child(tail)
	WorldProps.part(tail, WorldProps.cyl(s * 0.004, s * 0.02, s * 1.2, 4), bm, Vector3(0, 0, -s * 0.6), Vector3(PI / 2, 0, 0))
	WorldProps.part(tail, WorldProps.sphere(s * 0.05, 6, 3), WorldProps.std(acc, 0.3, 0.0, acc, 2.5), Vector3(0, 0, -s * 1.2))


## Glowing sea organism: a pulsing bell with frilly tentacles
func _build_jelly(col: Color, acc: Color, s: float) -> void:
	WorldProps.part(bob, WorldProps.sphere(1.0, 18, 8, true), WorldProps.std(col, 0.1, 0.0, col, 1.2, 0.6), Vector3.ZERO, Vector3.ZERO, Vector3(s * 0.6, s * 0.45, s * 0.6))
	var o := WorldProps.part(bob, WorldProps.sphere(1.0, 10, 5), WorldProps.std(acc, 0.3, 0.0, acc, 3.5), Vector3(0, s * 0.15, 0), Vector3.ZERO, Vector3.ONE * s * 0.18)
	organs.append([o, s * 0.18, 0.0])
	for i in 10:
		var a := TAU * i / 10.0
		var pv := Node3D.new()
		pv.position = Vector3(cos(a) * s * 0.45, 0, sin(a) * s * 0.45)
		bob.add_child(pv)
		var l := s * rng.randf_range(0.9, 1.8)
		WorldProps.part(pv, WorldProps.cyl(s * 0.008, s * 0.025, l, 4), WorldProps.std(acc, 0.3, 0.0, acc, 1.5, 0.75), Vector3(0, -l * 0.5, 0))
		tendrils.append([pv, a])


# ================================================================== behaviour
var wet_t := 0.0
var was_wet := false


## Water reacts to animals near you: rings and a small wake where they swim at the surface or
## wade through shallow water / rivers, a splash when they run into the water
func _water_fx(delta: float, how: String) -> void:
	wet_t -= delta
	var u := position.normalized()
	var h := world.terrain.height(u)
	var surf := -INF
	if world.water != null and h < world.water_level:
		surf = world.water_level
	var rs := world.terrain.river_surface(u)
	if rs > h:
		surf = maxf(surf, rs)
	var wet := surf > -INF and position.length() < world.radius + surf + 0.25 * SCALE * 8.0 and how != "flyer"
	var body := clampf(size * SCALE, 0.05, 1.0)
	if wet and not was_wet and moving > 0.3:
		world.splash(position, body * 0.8)
	was_wet = wet
	if wet and moving > 0.25 and wet_t <= 0.0:
		wet_t = 0.35
		var at_surface := position.length() > world.radius + surf - 0.6
		if at_surface:
			if surf == world.water_level:
				world.add_ripple(position, 0.08 + body * 0.4, 0.15 + body)
			else:
				Effects.splash(world, u * (world.radius + surf), u, body * 0.3)


func _process(delta: float) -> void:
	t += delta
	if held:
		# wriggles, looks around, flaps - the ExploreScreen holds it in front of the camera
		moving = 0.6 + 0.4 * sin(t * 3.0)
		_animate(delta)
		return
	var pp := world.player_pos()
	# far away: hidden and paused (faster)
	var dist2 := position.distance_squared_to(pp)
	# small animals disappear sooner than big ones (you can't see a mouse at 60 m anyway)
	var vis_r := clampf(28.0 + size * 70.0, 28.0, 85.0)
	var far := dist2 > vis_r * vis_r
	visible = not far
	if far:
		return
	# medium distance: think and move only every third frame (with the time saved up)
	# further away: think and move less often (every 3rd frame from 18 m, every 6th from 38 m)
	if SphereWorld.optimize and dist2 > 18.0 * 18.0:
		lod_skip += 1
		lod_dt += delta
		if lod_skip % (6 if dist2 > 38.0 * 38.0 else 3) != 0:
			_cartoon_update()
			return
		delta = lod_dt
	lod_dt = 0.0
	custom_basis = false
	_ecosystem(delta, pp)
	var how := plan
	if plan == "xeno":
		how = {"legs": "walker", "radial": "walker", "crawl": "walker", "hover": "floater", "wing": "flyer",
			"swim": "swimmer", "burrow": "burrow", "climb": "climb", "sessile": "sessile"}.get(loc, "walker")
	if _resting():
		how = "rest"
	if how in ["swimmer", "jelly"] and world.terrain.height(position.normalized()) > world.water_level - 0.5:
		how = "stranded"
	match how:
		"stranded":
			_stranded(delta)
		"walker", "hopper", "crawler", "tripod":
			_ground(delta, pp)
		"floater", "gasbag":
			_float(delta, pp)
		"flyer", "skimmer":
			_fly(delta, pp)
		"swimmer", "jelly":
			_swim(delta)
		"burrow":
			_burrow(delta, pp)
		"climb":
			_climb(delta, pp)
		"sessile":
			_sessile(delta, pp)
		"rest":
			moving = move_toward(moving, 0.0, delta * 2.0)
			idle_mode = "rest"
	if dist2 < 30.0 * 30.0:
		_water_fx(delta, how)
	if custom_basis:
		_animate(delta)
		return
	# stand upright on the curved ground and face the heading
	var u := position.normalized()
	var h := heading - u * heading.dot(u)
	if h.length() > 0.01:
		heading = h.normalized()
	var want := Basis(u.cross(heading).normalized(), u, heading).orthonormalized()
	var cur := basis.orthonormalized()
	if cur.determinant() < 0.0:
		basis = want                              # (a mirrored basis can't be blended)
	else:
		basis = cur.slerp(want, minf(1.0, delta * 5.0))
	if bool(sp.get("sideways", false)):
		body.rotation.y = PI / 2
	_animate(delta)


## Turn smoothly towards a direction along the ground
func _face(dir: Vector3, delta: float) -> void:
	var u := position.normalized()
	var d := dir - u * dir.dot(u)
	if d.length() > 0.01:
		heading = heading.lerp(d.normalized(), minf(1.0, delta * 4.0)).normalized()


## A point about `dist` metres from p along the ground
func _near(p: Vector3, dist: float) -> Vector3:
	var u := p.normalized()
	var b := SphereTerrain.surface_basis(u, rng.randf() * TAU)
	return world.ground_point(u.rotated(b.x, dist / world.radius))


func _walkable(p: Vector3) -> bool:
	var h := world.terrain.height(p.normalized())
	if world.water_level > -900.0 and str(world.biome["water"]) == "ocean":
		if bool(sp.get("sideways", false)):      # crabs stay on the beach
			return h > world.water_level - 0.3 and h < world.water_level + 2.5
		return h > world.water_level + 0.3
	if world.water_level > -900.0 and str(world.biome["water"]) == "lava" and h < world.water_level + 0.2:
		return false
	return world.terrain.slope(p) < 0.4


func _pick_target(radius: float) -> void:
	# often walk to something to eat or drink nearby: a plant, a mineral crust, the shore
	want_feed = false
	if rng.randf() < 0.4:
		var f := world.feed_near(home, radius + 6.0)
		if f != Vector3.ZERO and _walkable(f):
			target = f + (position - f).normalized() * size * 0.6
			state = "move"
			want_feed = true
			return
	for i in 12:
		var p := _near(home, rng.randf_range(1.0, radius))
		if _walkable(p):
			target = p
			state = "move"
			return
	target = home
	state = "move"


func _ground(delta: float, pp: Vector3) -> void:
	var to_player := pp - position
	var d := to_player.length()
	var fast := 1.0
	if d < 9.0:
		if bool(sp.get("curious", false)) or bold > 0.82:
			# stop and look at the visitor
			if state == "move" and d < 5.0:
				state = "idle"
				timer = 1.5
			if state == "idle":
				_face(to_player, delta)
				timer = maxf(timer, 0.6)
		elif d < lerpf(9.0, 4.0, bold) and state != "flee" and (world.player_speed() > lerpf(2.2, 4.5, bold) or d < lerpf(3.5, 1.5, bold)):
			var away := position - to_player.normalized() * 9.0
			var p := world.ground_point(away)
			if _walkable(p):
				target = p
				state = "flee"
	if state == "flee":
		fast = 2.2
	var lift := 0.0
	match state:
		"idle":
			moving = move_toward(moving, 0.0, delta * 3.0)
			if hop > 0.0:      # finish the jump before resting
				hop += delta * 1.6
				if hop >= 1.0:
					hop = 0.0
			timer -= delta
			if timer <= 0.0:
				_pick_target(12.0)
		"move", "flee":
			var u := position.normalized()
			var dir := target - position
			dir -= u * dir.dot(u)
			if dir.length() < 0.4:
				state = "idle"
				timer = rng.randf_range(2.0, 5.0)
				if want_feed:
					# arrived at food or water: eat / drink for a while
					idle_mode = "graze"
					timer = rng.randf_range(5.0, 10.0)
					want_feed = false
				elif partner != null and is_instance_valid(partner):
					# met one of its own kind: they face each other for a moment
					idle_mode = "greet"
					timer = rng.randf_range(2.0, 4.5)
					_face(partner.position - position, 1.0)
					partner.state = "idle"
					partner.idle_mode = "greet"
					partner.timer = timer
					partner._face(position - partner.position, 1.0)
					partner = null
			else:
				var nxt := world.ground_point(position + dir.normalized() * speed * fast * delta)
				if not _walkable(nxt):
					state = "idle"
					timer = rng.randf_range(0.5, 1.5)
				else:
					if plan == "hopper":
						hop += delta * (1.6 if world.gravity > 5.0 else 0.8) * fast
						if hop >= 1.0:
							hop = 0.0
						if hop > 0.05:
							position = nxt
					else:
						position = nxt
					moving = move_toward(moving, 1.0, delta * 3.0)
					_face(dir, delta)
	position = world.ground_point(position, lift)


func _float(delta: float, pp: Vector3) -> void:
	var to_player := pp - position
	if to_player.length() < 10.0 and bool(sp.get("curious", false)):
		# drift towards the visitor and circle in front of it
		var b := SphereTerrain.surface_basis(pp.normalized(), 0.0)
		target = pp + (b.x * sin(t * 0.4) + b.z * cos(t * 0.4)) * 3.5
		state = "move"
	match state:
		"idle":
			timer -= delta
			if timer <= 0.0:
				_pick_target(14.0)
		"move":
			var u := position.normalized()
			var dir := target - position
			dir -= u * dir.dot(u)
			if dir.length() < 0.5:
				state = "idle"
				timer = rng.randf_range(2.0, 6.0)
			else:
				position += dir.normalized() * speed * delta
				_face(dir, delta)
	var lift := float(sp.get("hover", 1.6)) * SCALE + size + sin(t * 1.3) * 0.2
	var r := maxf(world.floor_radius(position), world.radius) + lift
	position = position.normalized() * r


func _fly(delta: float, pp: Vector3) -> void:
	var centre := home
	if (pp - home).length() < 18.0 and bool(sp.get("curious", false)):
		centre = home.lerp(pp, 0.35)
	fly_angle += speed / fly_radius * delta
	var b := SphereTerrain.surface_basis(centre.normalized(), 0.0)
	var p := centre + (b.x * cos(fly_angle) + b.z * sin(fly_angle) * 0.7) * fly_radius
	var alt := float(sp.get("fly_alt", 0.8)) + sin(t * 0.7) * 0.25 + size
	p = p.normalized() * (world.floor_radius(p) + alt)
	var dir := p - position
	position = p
	if dir.length() > 0.001:
		_face(dir, delta * 3.0)
	moving = 1.0


func _swim(delta: float) -> void:
	var wr := world.radius + world.water_level
	match state:
		"idle":
			timer -= delta
			if timer <= 0.0:
				for i in 12:
					var p := _near(home, rng.randf_range(4.0, 25.0))
					if world.terrain.height(p.normalized()) < world.water_level - 1.6:
						target = p
						state = "move"
						# a new depth too: some cruise near the surface, others near the seabed
						var floor_depth := world.water_level - world.terrain.height(p.normalized())
						var base := float(sp.get("depth", 0.45)) * SCALE * 2.0
						swim_goal = clampf(base + rng.randf_range(0.0, floor_depth * 0.8), 0.3, maxf(0.4, floor_depth - 0.5))
						break
				timer = 1.0
		"move":
			var u := position.normalized()
			var dir := target - position
			dir -= u * dir.dot(u)
			if dir.length() < 1.0:
				state = "idle"
				timer = rng.randf_range(1.0, 3.0)
			else:
				var nxt := position + dir.normalized() * speed * delta
				if world.terrain.height(nxt.normalized()) > world.water_level - 1.0:
					state = "idle"
				else:
					position = nxt
					_face(dir, delta)
	# sometimes leaps out of the water (with a splash going out and coming back in)
	# a swimmer close to you darts away (also under water)
	var pp := world.player_pos()
	if position.distance_to(pp) < 3.0 and state != "flee":
		target = position + (position - pp).normalized() * 8.0
		state = "move"
		swim_goal = clampf(swim_goal + rng.randf_range(-1.5, 1.5), 0.3, 12.0)
	swim_depth = lerpf(swim_depth, swim_goal, minf(1.0, delta * 0.5))
	var floor_now := world.water_level - world.terrain.height(position.normalized())
	var depth := clampf(swim_depth, 0.25, maxf(0.3, floor_now - 0.4))
	if leap < 0.0 and state == "move" and swim_depth < 1.0 and bool(sp.get("leaps", true)) and rng.randf() < delta * 0.08:
		leap = 0.0
		world.splash(position, clampf(size * SCALE * 2.5, 0.06, 1.2))
	# near the surface they ride the waves too
	var r := wr - depth + sin(t * 1.1) * 0.08 + world.wave_at(position) * clampf(1.0 - depth, 0.0, 1.0)
	if leap >= 0.0:
		leap += delta / 1.4
		if leap >= 1.0:
			leap = -1.0
			world.splash(position, clampf(size * SCALE * 3.5, 0.08, 1.6))
		else:
			r = wr - depth + sin(leap * PI) * (1.6 + depth)
	position = position.normalized() * r
	moving = 1.0


# ---------------------------------------------------------------- ecosystem
## Night animals sleep during the day (and day animals at night, if marked so)
func _resting() -> bool:
	if bool(sp.get("night", false)):
		return world.daylight > 0.6 and loc != "burrow"
	return false


## Every half second: run from predators, follow the swarm leader, go to food
func _ecosystem(delta: float, pp: Vector3) -> void:
	check_t -= delta
	if leader and is_instance_valid(leader):
		target = leader.position + swarm_off.rotated(leader.position.normalized(), t * 0.3)
		if state != "flee":
			state = "move"
	if check_t > 0.0:
		return
	check_t = 0.5 + rng.randf() * 0.2
	# a noise nearby (running, a splash, a landing, a blast): bold ones come to look, shy ones
	# run, the rest stop and listen
	var nz: Array = world.last_noise
	if not nz.is_empty() and world.t - float(nz[1]) < 2.5 and float(nz[1]) > heard_t and state != "held":
		var np: Vector3 = nz[0]
		var nd := position.distance_to(np)
		if nd < float(nz[2]) * 14.0 and nd > 1.5:
			heard_t = float(nz[1])
			if bold > 0.62 and plan in ["walker", "hopper", "crawler", "tripod", "xeno"]:
				target = world.ground_point(np + (position - np).normalized() * (2.0 + rng.randf() * 2.0))
				state = "move"
				idle_mode = ""
				return
			elif bold < 0.35 or nd < float(nz[2]) * 4.0:
				target = world.ground_point(position + (position - np).normalized() * 10.0)
				state = "flee"
				return
			else:
				state = "idle"
				timer = rng.randf_range(1.0, 2.5)
				idle_mode = "look"
				_face(np - position, 1.0)
				return
	# now and then it goes over to another of its kind (groups stay together, they greet)
	if state == "idle" and partner == null and rng.randf() < 0.1 and plan in ["walker", "hopper", "crawler", "tripod", "xeno"]:
		for a: Wildlife in world.animals:
			if a != self and a.species_id == species_id and a.visible and not a.held and position.distance_squared_to(a.position) < 49.0 \
					and position.distance_squared_to(a.position) > 1.0:
				partner = a
				target = a.position + (position - a.position).normalized() * maxf(size * 4.0, 0.25)
				state = "move"
				break
	# small animals keep away from hunters
	if size < 0.9 * SCALE and not bool(sp.get("predator", false)):
		for a: Wildlife in world.animals:
			if a != self and bool(a.sp.get("predator", false)) and a.visible and position.distance_squared_to(a.position) < 81.0:
				var away := position + (position - a.position).normalized() * 10.0
				target = world.ground_point(away)
				state = "flee"
				return
	# predators stalk the nearest small animal now and then
	if bool(sp.get("predator", false)) and state == "idle" and rng.randf() < 0.3:
		for a: Wildlife in world.animals:
			if a != self and a.size < 0.9 * SCALE and not a.held and a.visible and position.distance_squared_to(a.position) < 400.0:
				target = a.position
				state = "move"
				return


## A sea animal on land: it flops and slides back towards the nearest water
func _stranded(delta: float) -> void:
	timer -= delta
	if timer <= 0.0 or state != "stranded":
		state = "stranded"
		timer = 1.0
		var best := position
		var best_h := INF
		for i in 12:
			var p := _near(position, 3.0)
			var h := world.terrain.height(p.normalized())
			if h < best_h:
				best_h = h
				best = p
		target = best
	var u := position.normalized()
	var dir := target - position
	dir -= u * dir.dot(u)
	# little flops: short hops forward
	var hop_k := absf(sin(t * 5.0))
	var step := dir.normalized() * 0.35 * delta * (0.4 + hop_k) if dir.length() > 0.05 else Vector3.ZERO
	if dir.length() > 0.05:
		_face(dir, delta)
	# re-project onto the ground every frame (no drifting up), plus a small flop
	position = world.ground_point(position + step) + u * hop_k * 0.03
	moving = 0.6


## Burrowers: come up to feed, dig back down (also when you come too close)
func _burrow(delta: float, pp: Vector3) -> void:
	burrow_t -= delta
	var want_down := burrow_t < 0.0
	if not bool(sp.get("curious", false)) and position.distance_to(pp) < 5.0:
		want_down = true
		burrow_t = minf(burrow_t, -3.0)
	if bool(sp.get("night", false)) and world.daylight > 0.6:
		want_down = true
	if burrow_t < -rng.randf_range(5.0, 9.0):
		burrow_t = rng.randf_range(6.0, 12.0)
	var was := submerged
	submerged = move_toward(submerged, 1.0 if want_down else 0.0, delta * 1.5)
	if (was < 0.5 and submerged >= 0.5) or (was > 0.5 and submerged <= 0.5):
		Effects.dust(world, position, position.normalized(), Color(0.45, 0.4, 0.35), 0.6)
	_ground(delta, pp)
	bob.position.y = -submerged * size * 1.3
	if head:
		head.rotation.x = sin(t * 0.9) * 0.3 * (1.0 - submerged)


## Climbers: crawl up and down big trees, spires and ice walls
func _climb(delta: float, pp: Vector3) -> void:
	if climb_r <= 0.0:
		var best := 1e9
		for o: Array in world.obstacles:
			var c: Vector3 = o[0]
			var rr := float(o[1])
			var d := c.distance_squared_to(home)
			if rr >= 1.0 and d < best and d < 900.0:
				best = d
				climb_c = world.ground_point(c)
				climb_r = minf(rr, 2.5)
		if climb_r <= 0.0:
			climb_r = -1.0
	if climb_r < 0.0:
		_ground(delta, pp)
		return
	var u := climb_c.normalized()
	timer -= delta
	if timer <= 0.0:
		climb_goal = rng.randf_range(0.6, 9.0)
		timer = rng.randf_range(3.0, 7.0)
		climb_a += rng.randf_range(-1.0, 1.0)
	if position.distance_to(pp) < 4.0 and not bool(sp.get("curious", false)):
		climb_goal = 10.0                      # climbs up out of reach
	var dh := climb_goal - climb_h
	climb_h += clampf(dh, -speed * delta, speed * delta)
	moving = clampf(absf(dh), 0.0, 1.0)
	var b := SphereTerrain.surface_basis(u, climb_a)
	var out := b.x
	position = climb_c + u * climb_h + out * (climb_r + 0.15)
	# body against the trunk: belly towards it, head up (or down when climbing down)
	var fwd := u if dh >= 0.0 else -u
	basis = Basis(fwd.cross(out).normalized(), out, fwd)
	custom_basis = true


## Rooted organisms: open their feeding crown, close it when something comes close
func _sessile(delta: float, pp: Vector3) -> void:
	moving = 0.0
	position = world.ground_point(home)
	var core: Node3D = get_meta("core", null)
	if core:
		var shy := position.distance_to(pp) < 3.5
		var want := 0.45 if shy else 1.0 + sin(t * 0.8) * 0.05
		core.scale = core.scale.lerp(Vector3.ONE * want, minf(1.0, delta * 3.0))


# ================================================================== cartoon: a 2D drawing
var sprite: Sprite3D = null
var sprite_h := 1.0


## The animal is shown as its flat cartoon drawing (the 3D body is still there for the
## animations and the logic, just not drawn)
func _cartoon_sprite(s: float) -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		var n3 := c as Node3D
		if n3 and not (c is CollisionObject3D):
			n3.visible = false
	sprite = Sprite3D.new()
	sprite.texture = CartoonCritter.texture(species_id, sp, get_tree())
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, CartoonCritter.W, CartoonCritter.W)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.double_sided = true
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# drawings are about 1.7 x the body size high (flyers and floaters a bit smaller)
	sprite_h = s * (1.45 if plan in ["flyer", "floater", "skimmer", "jelly"] else 1.8)
	if plan == "gasbag":
		sprite_h = s * 2.4
	sprite.pixel_size = sprite_h / CartoonCritter.W
	sprite.modulate = Color(1, 1, 1)
	add_child(sprite)


## Every frame: the drawing stands upright on the planet, turned towards the camera, facing
## the way it moves, and switches between its two poses
func _cartoon_update() -> void:
	if sprite == null:
		return
	var cam := world.viewer
	var u := position.normalized()
	var to_cam := cam - global_position
	to_cam -= u * to_cam.dot(u)
	if to_cam.length() < 0.01:
		return
	var z := to_cam.normalized()
	var x := u.cross(z).normalized()
	var moving_k := moving
	var pose := 0
	if plan in ["flyer", "skimmer", "floater", "gasbag", "jelly"] or model_flies():
		pose = int(t * (14.0 if plan in ["flyer", "skimmer"] else 4.0)) % 2
	elif moving_k > 0.15:
		pose = int(t * (6.0 + speed * 3.0)) % 2
	sprite.region_rect = Rect2(pose * CartoonCritter.W, 0, CartoonCritter.W, CartoonCritter.W)
	# the drawing faces right: flip it when the animal walks to the left of the camera's view
	sprite.flip_h = heading.dot(x) > 0.0
	var squash := 1.0 + sin(t * 9.0) * 0.03 * (1.0 + moving_k)
	var bounce := absf(sin(t * (6.0 + speed * 3.0))) * 0.06 * moving_k * sprite_h
	sprite.global_transform = Transform3D(Basis(x, u * squash, z), global_position + u * (sprite_h * 0.4 + bounce))
	# dimmer at night (they are not lit by the sun as flat drawings)
	var day := 0.35 + 0.65 * world.daylight
	sprite.modulate = Color(day, day, day * 1.05)


func model_flies() -> bool:
	return str(sp.get("model", "")) == "giant_fly"


func _animate(delta: float) -> void:
	_cartoon_update()
	var walk := t * speed * 7.0
	for l: Array in legs:
		var pv: Node3D = l[0]
		pv.rotation.x = sin(walk + float(l[1])) * 0.55 * moving
	match plan:
		"walker":
			# standing still: look around, graze or rest (picked anew every time it stops)
			if moving < 0.1 and idle_mode == "":
				idle_mode = ["look", "graze", "rest"][rng.randi() % 3]
			elif moving > 0.5:
				idle_mode = ""
			var still := 1.0 - moving
			var rest := 0.08 * size * still if idle_mode == "rest" else 0.0
			bob.position.y = absf(sin(walk)) * 0.04 * size * moving + sin(t * 2.0) * 0.012 * size - rest
			bob.scale = Vector3(1.0, 1.0 + sin(t * 2.2) * 0.02, 1.0 + sin(t * 2.2) * 0.012)     # breathing
			if head:
				match idle_mode:
					"graze":
						head.rotation.x = lerpf(head.rotation.x, (0.6 + sin(t * 7.0) * 0.06) * still, minf(1.0, delta * 3.0))
						head.rotation.y = sin(t * 0.4) * 0.15 * still
					"look":
						head.rotation.x = lerpf(head.rotation.x, sin(t * 0.8) * 0.12 * still, minf(1.0, delta * 3.0))
						head.rotation.y = sin(t * 0.9) * 0.6 * still
					_:
						head.rotation.x = lerpf(head.rotation.x, 0.1 * still, minf(1.0, delta * 3.0))
						head.rotation.y = sin(t * 0.3) * 0.1 * still
			if tail:
				tail.rotation.y = sin(t * 2.5) * 0.4
		"hopper":
			var h := sin(hop * PI) * (1.6 if world.gravity < 5.0 else 0.6) * size * 1.4 if hop > 0.0 else 0.0
			bob.position.y = h
			var squash := 1.0 + (0.12 * sin(t * 3.0) if hop == 0.0 else -0.1 * sin(hop * PI))
			bob.scale = Vector3(1.0 / sqrt(squash), squash, 1.0 / sqrt(squash))
			for e: Node3D in ears:
				e.rotation.x = sin(t * 4.0 + e.position.x) * 0.15 - hop * 0.4
		"floater":
			for td: Array in tendrils:
				var pv: Node3D = td[0]
				pv.rotation = Vector3(sin(t * 1.7 + float(td[1]) * 2.0) * 0.35, 0, cos(t * 1.4 + float(td[1])) * 0.3)
			bob.rotation.y += delta * 0.3
		"flyer":
			for w: Array in wings:
				var pv: Node3D = w[0]
				pv.rotation.z = sin(t * 14.0) * 0.8 * float(w[1])
			bob.rotation.z = sin(fly_angle) * 0.25
		"swimmer":
			for w: Array in wings:
				var pv: Node3D = w[0]
				pv.rotation.z = sin(t * 2.4) * 0.35 * float(w[1])
			bob.rotation.x = -cos(leap * PI) * 0.6 if leap >= 0.0 else 0.0
		"crawler":
			# the body ripples like a wave from head to tail
			for i in segs.size():
				var sg: Node3D = segs[i]
				sg.position.x = sin(t * speed * 6.0 - i * 0.9) * 0.07 * size * (0.3 + moving)
				sg.position.y = float(sg.get_meta("y0", 0.0)) + absf(sin(t * speed * 6.0 - i * 0.9)) * 0.02 * size * moving
			if head:
				head.rotation.y = sin(t * 1.3) * 0.4 * (1.0 - moving)
		"gasbag":
			var pulse := 1.0 + sin(t * 1.4) * 0.06
			bob.scale = Vector3(pulse, 1.0 / pulse, pulse)
			for td: Array in tendrils:
				var pv: Node3D = td[0]
				pv.rotation = Vector3(sin(t * 1.1 + float(td[1]) * 2.0) * 0.3, 0, cos(t * 0.9 + float(td[1])) * 0.25)
			for w: Array in wings:
				var pv: Node3D = w[0]
				pv.rotation.z = sin(t * 1.8) * 0.35 * float(w[1])
			bob.rotation.y += delta * 0.15
		"tripod":
			bob.position.y = sin(walk * 0.5) * 0.08 * size * moving + sin(t * 1.6) * 0.03 * size
			bob.rotation.y = sin(t * 0.4) * 0.3 * (1.0 - moving)
			if head:
				head.rotation.x = sin(t * 0.7) * 0.25
		"skimmer":
			for w: Array in wings:
				var pv: Node3D = w[0]
				var ph := float(w[2]) if w.size() > 2 else 0.0
				pv.rotation.z = sin(t * 11.0 + ph) * 0.7 * float(w[1])
			bob.rotation.z = sin(fly_angle) * 0.3
			if tail:
				tail.rotation.y = sin(t * 3.0) * 0.4
		"jelly":
			var p2 := 1.0 + sin(t * 2.2) * 0.12
			bob.scale = Vector3(p2, 1.0 / p2, p2)
			for td: Array in tendrils:
				var pv: Node3D = td[0]
				pv.rotation = Vector3(sin(t * 1.5 + float(td[1]) * 2.0) * 0.4, 0, cos(t * 1.2 + float(td[1])) * 0.35)
	if plan == "xeno":
		_animate_xeno(delta)
	# glowing organs breathe (at night they glow brighter and flash together as a signal)
	var night := 1.0 - world.daylight
	for o: Array in organs:
		var om: MeshInstance3D = o[0]
		var signal_flash := 0.0
		if night > 0.5 and bool(sp.get("signals", false)):
			signal_flash = maxf(0.0, sin(world.t * 2.0 + float(hash(species_id) % 7))) * 0.6
		om.scale = Vector3.ONE * float(o[1]) * (1.0 + sin(t * 2.6 + float(o[2])) * 0.15 + signal_flash)


func _animate_xeno(delta: float) -> void:
	var walk := t * speed * 7.0
	var core: Node3D = get_meta("core", null)
	# segmented bodies ripple from head to tail
	for i in segs.size():
		var sg: Node3D = segs[i]
		sg.position.x = sin(t * speed * 6.0 - i * 0.9) * 0.07 * size * (0.3 + moving)
	# knees bend with the step
	for k in get_meta("knees", []):
		var kn: Node3D = k
		kn.rotation.z = sin(walk + kn.get_index()) * 0.25 * moving
	# breathing
	if core and loc != "sessile":
		var br := 1.0 + sin(t * 1.9) * 0.025
		core.scale = Vector3(br, 1.0 / br, br)
		if loc in ["legs", "radial"]:
			core.position.y = float(core.get_meta("h0", core.position.y)) + absf(sin(walk)) * 0.03 * size * moving
	for w: Array in wings:
		var pv: Node3D = w[0]
		var sx := float(w[1])
		if sx == 0.0:
			# membranes, sails and skirts ripple
			pv.rotation.x = sin(t * float(w[2]) * 0.4) * 0.12
			pv.scale.x = 1.0 + sin(t * float(w[2]) * 0.5) * 0.05
		elif loc == "wing":
			pv.rotation.z = sin(t * 9.0 + float(w[2])) * 0.75 * sx
		elif loc == "swim":
			pv.rotation.z = sin(t * 2.8 - float(w[2])) * 0.35 * sx
		else:
			pv.rotation.y = sin(t * float(w[2]) + 0.5) * 0.25 * sx          # fans, mandibles
	for td: Array in tendrils:
		var p: Node3D = td[0]
		p.rotation = Vector3(sin(t * 1.5 + float(td[1]) * 2.0) * 0.35, 0, cos(t * 1.2 + float(td[1])) * 0.3)
	if loc == "swim" and str(genes.get("fin", "")) == "jets":
		var pulse := 1.0 + sin(t * 2.4) * 0.14
		bob.scale = Vector3(pulse, 1.0 / pulse, pulse)
	# eyes blink now and then and look around
	blink_t -= delta
	for e in eyes:
		var ey: Node3D = e
		ey.scale.y = 0.15 if blink_t < 0.12 and blink_t > 0.0 else 1.0
		ey.rotation.y = sin(t * 0.7 + ey.get_index()) * 0.3
	if blink_t < 0.0:
		blink_t = rng.randf_range(2.0, 6.0)
	# feeding: the mouth works while grazing
	var mouth: Node3D = get_meta("mouth", null)
	if mouth:
		mouth.rotation.x = (sin(t * 6.0) * 0.25) if idle_mode == "graze" and moving < 0.3 else 0.0
	if head and idle_mode == "graze" and moving < 0.3:
		head.rotation.x = lerpf(head.rotation.x, 0.45, minf(1.0, delta * 3.0))
	elif head:
		head.rotation.x = lerpf(head.rotation.x, sin(t * 0.6) * 0.1, minf(1.0, delta * 3.0))
		head.rotation.y = sin(t * 0.5) * 0.3 * (1.0 - moving)
	if moving < 0.1 and idle_mode == "":
		idle_mode = ["look", "graze", "rest"][rng.randi() % 3]
	elif moving > 0.5:
		idle_mode = ""
