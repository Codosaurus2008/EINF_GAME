class_name Explorer
extends Node3D
## The player on foot on a round planet. Gravity always pulls towards the planet's centre, so
## you can walk all the way around it; "up" is away from the centre wherever you are.
##   WASD walk, Shift run, Space jump, mouse / touchpad or arrow keys look around.
## In the sea (Aquora): you walk in from the beach, start swimming when it gets deep,
## W swims where you look (also down = diving), Space rises, Shift (or C) sinks, Ctrl swims
## faster. Lakes are deep enough to swim as well; streams and small pools are only for wading.
## Steep walls can't be walked up. Mushroom caps (world.platforms) can be stood on and
## some of them throw you up high.
## The explorer has a visible body (suit, helmet, backpack) with walk / run / jump / swim
## animations; in first person the head is hidden.

## Sizes are final values (not multipliers): the explorer is about 60 cm tall (was 34 cm) -
## body, eyes, collision radius, speeds, swimming depths and the cameras all match that size
const MODEL_SCALE := 0.65       # the body model is built 0.92 m tall
const WALK := 2.4
const RUN := 4.8
const JUMP := 5.4               # same push on every planet: low gravity = higher, longer jumps
const FALL_K := 1.35            # you come down a bit faster than you go up (snappy, not floaty)
const STEP_UP := 0.2            # a ledge this much above your feet can be stepped / jumped onto
## In the air you keep (and can build) more speed: a running jump covers about 7 m and reaches
## about 1.5 m high at normal gravity
const AIR_BOOST := 1.4
const EYE := 0.54
const HEIGHT := 0.6
const BODY_R := 0.15
const KEY_TURN := 2.2
const SWIM := 1.8
const SWIM_FAST := 3.0
const MAX_RISE := 1.35          # steepest slope you can walk up (height per metre)
const SWIM_DEPTH := 0.42        # water deeper than this: you float and swim
const SEABED_MAX := 7.0         # down to this depth you can stand and walk on the sea floor
const FLOAT := 0.15             # body centre this far under the surface when floating

var world: SphereWorld
var capsule: Node3D             # the parked capsule (you can't walk through it)
var heading := Vector3.FORWARD  # where you face, along the ground
var pitch := 0.0
var vel := Vector3.ZERO         # along the ground (swimming: in any direction)
var fall := 0.0                 # speed away from (+) / towards (-) the centre
var on_ground := true
var swimming := false          # floating / swimming (at the surface or under water)
var current := Vector3.ZERO     # push of a stream's current while wading
var water_state := "land"       # land, swim, seabed
var controls := true
var sensitivity := 0.003
var bob_t := 0.0
var bob := 0.0
var ripple_t := 0.0
var dust_t := 0.0
var bubble_t := 0.0
var platform := -1              # index of the mushroom cap you stand on (-1 = none)
var first_person := false

# body
var rig: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var gait := 0.0
var swim_k := 0.0               # 0 = upright .. 1 = lying in the water
var air_t := 0.0


func _ready() -> void:
	_build_body()


func up() -> Vector3:
	return position.normalized()


func right() -> Vector3:
	return heading.cross(up()).normalized()


func look_dir() -> Vector3:
	return heading.rotated(right(), pitch)


func eye() -> Vector3:
	return position + up() * (lerpf(EYE, 0.15, swim_k) + bob)


func speed() -> float:
	return vel.length()


## Under the water surface (head included)?
func underwater() -> bool:
	return water_state != "land" and eye().length() < world.swim_surface(position) - 0.03


## Depth of the sea or lake at p (0 = no swimmable water / dry land)
func sea_depth(p: Vector3) -> float:
	return world.swim_depth(p)


func place(p: Vector3, face: Vector3) -> void:
	var u := p.normalized()
	position = u * world.walk_radius(p)
	heading = (face - u * face.dot(u)).normalized()
	if heading.length() < 0.5:
		heading = SphereTerrain.surface_basis(u, 0.0).z
	pitch = 0.0
	vel = Vector3.ZERO
	fall = 0.0
	on_ground = true
	swimming = false
	water_state = "land"


func look(rel: Vector2) -> void:
	heading = heading.rotated(up(), -rel.x * sensitivity)
	pitch = clampf(pitch - rel.y * sensitivity, -1.45, 1.45)


func set_first_person(on: bool) -> void:
	first_person = on
	if head:
		head.visible = not on


func _key(k: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(k) else 0.0


## Water deep enough here to swim (the sea of Aquora)?
func _deep_water(p: Vector3) -> bool:
	return world.swim_depth(p) > SWIM_DEPTH


func _process(delta: float) -> void:
	if not visible:
		return
	delta = minf(delta, 0.05)
	var u := up()
	heading = (heading - u * heading.dot(u)).normalized()
	var fwd := 0.0
	var side := 0.0
	var run := false
	var jump := false
	var sink := false
	if controls:
		fwd = _key(KEY_W) - _key(KEY_S)
		side = _key(KEY_D) - _key(KEY_A)
		jump = Input.is_physical_key_pressed(KEY_SPACE)
		if water_state == "land":
			run = Input.is_physical_key_pressed(KEY_SHIFT)
			sink = Input.is_physical_key_pressed(KEY_C)
		else:
			# in the water: Space rises, Shift (or C) sinks, Ctrl swims faster
			run = Input.is_physical_key_pressed(KEY_CTRL)
			sink = Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_C)
		var turn := _key(KEY_RIGHT) - _key(KEY_LEFT)
		var tilt := _key(KEY_UP) - _key(KEY_DOWN)
		if turn != 0.0 or tilt != 0.0:
			look(Vector2(turn, -tilt) * KEY_TURN * delta / sensitivity)
	# land -> swim (water reaches the chest) -> seabed (sink to a shallow floor) -> swim / land
	var depth := sea_depth(position)
	var wr := world.swim_surface(position)
	match water_state:
		"land":
			if depth > SWIM_DEPTH and wr > -INF and position.length() < wr + 0.38:
				water_state = "swim"
				# jumping in: the faster you come down, the bigger the splash; running in throws
				# spray forwards
				world.splash(position.normalized() * wr, 0.12 + absf(fall) * 0.08 + vel.length() * 0.02)
				if vel.length() > 1.2:
					Effects.spray(world, position.normalized() * wr, position.normalized(), vel.normalized(), 0.2 + vel.length() * 0.08)
				vel *= 0.5
				fall = minf(fall, 0.0) * 0.3
		"swim":
			if depth <= SWIM_DEPTH:
				water_state = "land"
				position = position.normalized() * world.walk_radius(position)
				fall = 0.0
				on_ground = true
			elif depth <= SEABED_MAX and position.length() < world.walk_radius(position) + 0.38 and (sink or (vel.length() < 0.4 and fall < 0.2)):
				water_state = "seabed"
				on_ground = true
				fall = 0.0
		"seabed":
			if depth <= SWIM_DEPTH:
				water_state = "land"
			elif depth > SEABED_MAX or (jump and on_ground):
				water_state = "swim"
				fall = 1.6 if jump else 0.3
				on_ground = false
	swimming = water_state == "swim"
	if swimming:
		_swim(delta, fwd, side, run, jump, sink)
	elif water_state == "seabed":
		_walk(delta, fwd, side, run, false, 0.5, 0.3)
	else:
		_walk(delta, fwd, side, run, jump, 1.0, 1.0)
	var nu := up()
	heading = (heading - nu * heading.dot(nu)).normalized()
	basis = Basis(nu.cross(heading).normalized(), nu, heading)
	_animate(delta)


# ================================================================== on land
func _walk(delta: float, fwd: float, side: float, run: bool, jump: bool, speed_k: float, grav_k: float) -> void:
	var u := up()
	var wish := heading * fwd + right() * side
	if wish.length() > 1.0:
		wish = wish.normalized()
	wish *= (RUN if run else WALK) * speed_k
	# smooth start and stop; in the air you can still steer (aim for the next mushroom) and you
	# carry more speed (long jumps)
	if not on_ground:
		wish *= AIR_BOOST
	vel -= u * vel.dot(u)
	var accel := (22.0 if on_ground else 7.5) * (0.5 if grav_k < 1.0 else 1.0)
	vel = vel.move_toward(wish, accel * delta)
	if on_ground and jump:
		fall = JUMP * (0.75 if grav_k < 1.0 else 1.0)
		on_ground = false
		platform = -1
		# a running jump throws you forward
		vel *= AIR_BOOST if vel.length() > 0.5 else 1.0
		world.make_noise(position, 0.6)
		if sea_depth(position) > 0.0 or world.terrain.water_surface(u) > -INF:
			world.splash(position, 0.08)
	fall -= world.gravity * grav_k * delta * (FALL_K if fall < 0.0 else 1.0)
	# landing help: coming down over (or just beside) a mushroom cap, you drift gently towards
	# its middle - jumps onto caps land instead of sliding off the edge
	if not on_ground and fall < 0.0:
		var feet_r := position.length()
		for pf: Dictionary in world.platforms:
			var top_p: Vector3 = pf["pos"]
			var dd := top_p - position
			var flat := dd - u * dd.dot(u)
			var below := feet_r - top_p.length()
			if below > -0.2 and below < 4.0 and flat.length() < float(pf["r"]) * 1.7:
				vel += flat.normalized() * minf(flat.length(), 1.0) * 6.0 * delta
				break
	# move in small steps (fast falls, mushroom bounces and running can't skip through a thin
	# cap, a rock outline or a wall)
	var steps := clampi(int(ceil(maxf(vel.length(), absf(fall)) * delta / 0.06)), 1, 10)
	var dt := delta / steps
	# the current of a stream or river pushes you gently downstream while you wade
	var flow := world.terrain.river_flow(u)
	if flow != Vector3.ZERO and on_ground:
		var wade := clampf((world.terrain.river_surface(u) - world.terrain.height(u)) / 0.3, 0.0, 1.0)
		vel += flow * wade * 2.2 * delta
		current = flow * wade
	else:
		current = Vector3.ZERO
	for si in steps:
		if _step(dt, jump):
			return
	_after_walk(delta)


## One small movement step on land. Returns true when a mushroom threw you up again.
func _step(dt: float, jump: bool) -> bool:
	var feet := position.length()
	var nxt := position + (vel + current * 0.55) * dt
	# lava stops you
	if world.walk_blocked(nxt) and sea_depth(nxt) <= 0.0:
		nxt = position
		vel = Vector3.ZERO
	nxt = _push_out(nxt)
	# walls: steep ground ahead that is higher than your feet can't be walked or jumped into
	# (before, a jump into a cliff put you on top of it)
	if platform < 0:
		var step := (nxt - position).length()
		if step > 0.00001:
			var g_here := world.walk_radius(position)
			var g_next := world.walk_radius(nxt)
			var too_steep := (g_next - g_here) > step * MAX_RISE
			if on_ground and too_steep:
				nxt = position
				vel *= 0.2
			elif not on_ground and g_next > feet + STEP_UP and too_steep:
				# in the air against a wall: slide along it, don't climb through it
				var n := (nxt - position).normalized()
				vel -= n * maxf(vel.dot(n), 0.0)
				nxt = position
	nxt += nxt.normalized() * fall * dt
	# stand on the curved ground (exactly as it is drawn) or on a mushroom cap
	var g := world.walk_radius(nxt)
	var pl := _platform_under(nxt)
	if pl >= 0:
		var top_p: Vector3 = world.platforms[pl]["pos"]
		var top := top_p.length()
		if top > g:
			g = top
	var r := nxt.length()
	if r <= g:
		nxt = nxt.normalized() * g
		var landing_speed := -fall
		fall = 0.0
		if not on_ground and landing_speed > 3.0:
			world.make_noise(nxt, clampf(landing_speed * 0.15, 0.3, 1.5))
		if not on_ground and landing_speed > 1.0 and (sea_depth(nxt) > 0.0 or world.terrain.water_surface(nxt.normalized()) > -INF):
			world.splash(nxt, 0.05 + landing_speed * 0.03)
		if not on_ground and pl >= 0 and absf(r - g) < 0.6:
			platform = pl
			var bounce := float(world.platforms[pl]["bounce"])
			if bounce > 0.0 and landing_speed > 0.5:
				# the cap squashes and throws you up again (a little higher if you hold Space)
				fall = bounce * (1.12 if jump else 1.0)
				world.mushroom_bounce(pl, landing_speed)
				nxt = nxt.normalized() * (g + 0.02)
				on_ground = false
				position = nxt
				return true
		on_ground = true
		if pl < 0:
			platform = -1
	elif on_ground and fall <= 0.0 and r - g < 0.5 * HEIGHT:
		nxt = nxt.normalized() * g                # follow the ground downhill
		fall = 0.0
	else:
		on_ground = false
	position = nxt
	return false


func _after_walk(delta: float) -> void:
	# wading through shallow water makes rings
	var flat := vel.length()
	ripple_t -= delta
	if flat > 0.4 and ripple_t <= 0.0 and water_state == "land" and sea_depth(position) > 0.0:
		ripple_t = 0.3
		world.add_ripple(position, 0.08 + flat * 0.03, 0.25)
		if flat > 2.0:
			Effects.splash(world, position + up() * 0.02, up(), 0.04)
	# wading through a river, stream or pool: little splashes at your feet
	if flat > 0.4 and ripple_t <= 0.0 and world.terrain.water_surface(position.normalized()) > world.terrain.height(position.normalized()):
		ripple_t = 0.3
		Effects.splash(world, position + up() * 0.03, up(), 0.03 + flat * 0.01)
	# running kicks up dust (sand, soil, ash) or snow at your feet
	if on_ground and flat > 3.0 and water_state == "land" and sea_depth(position) <= 0.0:
		dust_t -= delta
		if dust_t <= 0.0:
			dust_t = 0.28
			var dc: Color = world.terrain.zone_colors(position.normalized())[0]
			if world.pid == "glacia":
				dc = Color(0.95, 0.97, 1.0)
			Effects.dust(world, position + up() * 0.03, up(), dc.lightened(0.25), 0.3)
	if on_ground and flat > 0.4:
		bob_t += delta * flat * 4.5
		bob = sin(bob_t) * 0.005
	else:
		bob = lerpf(bob, 0.0, minf(1.0, delta * 8.0))


## The mushroom cap below p (or -1)
func _platform_under(p: Vector3) -> int:
	var u := p.normalized()
	var best := -1
	var best_top := -INF
	for i in world.platforms.size():
		var pf: Dictionary = world.platforms[i]
		var top: Vector3 = pf["pos"]
		var d := p - top
		var flat := (d - u * d.dot(u)).length()
		if flat > float(pf["r"]):
			continue
		var above := d.dot(u)
		# only when you come from above (not from under the cap)
		if above > -0.45 and above < 2.5 and top.length() > best_top:
			best_top = top.length()
			best = i
	return best


# ================================================================== in the sea
func _swim(delta: float, fwd: float, side: float, run: bool, jump: bool, sink: bool) -> void:
	var u := up()
	var wr := world.swim_surface(position)
	if wr == -INF:
		water_state = "land"
		return
	var sp := SWIM_FAST if run else SWIM
	# swim where you look (looking down + W = diving), Space up, C down
	var wish := look_dir() * fwd + right() * side
	if wish.length() > 1.0:
		wish = wish.normalized()
	wish = wish * sp + u * ((1.0 if jump else 0.0) - (1.0 if sink else 0.0)) * sp * 0.8
	var v3 := vel + u * fall
	v3 = v3.move_toward(wish, 5.0 * delta)
	# water resistance: grows with speed (fast strokes are held back more than slow ones)
	v3 *= exp(-(1.1 + v3.length() * 0.45) * delta)
	# the surface moves with the waves: you rise and fall with them while floating
	var on_sea := absf(wr - world.water_radius()) < 0.01
	var surface_r := wr - FLOAT + (world.wave_at(position) if on_sea else 0.0)
	var r := position.length()
	# buoyancy: the deeper the body is under the surface, the stronger it pushes you up
	# (you float when you do nothing; holding C or swimming down works against it)
	if not sink and wish.dot(u) <= 0.05 and r < surface_r:
		var under := clampf((surface_r - r) / HEIGHT, 0.0, 1.5)
		v3 += u * (0.5 + under * 1.6) * delta * (0.4 if fwd != 0.0 else 1.0)
	var nxt := position + v3 * delta
	nxt = _push_out(nxt)
	var nr := nxt.length()
	# never above the surface (no flying out of the water), never into the seabed
	if nr > surface_r:
		nxt = nxt.normalized() * surface_r
		var radial := v3.dot(u)
		if radial > 0.0:
			v3 -= u * radial
	var floor_r := world.terrain.surface_radius(nxt) + HEIGHT * 0.3
	if nxt.length() < floor_r:
		nxt = nxt.normalized() * floor_r
		var radial2 := v3.dot(u)
		if radial2 < 0.0:
			v3 -= u * radial2
	position = nxt
	var nu := nxt.normalized()
	fall = v3.dot(nu)
	vel = v3 - nu * fall
	# rings and bubbles
	ripple_t -= delta
	if position.length() > surface_r - 0.38 and v3.length() > 0.4 and ripple_t <= 0.0:
		# swimming at the surface: a small wake of rings, splashes from the strokes
		ripple_t = 0.22 if run else 0.3
		world.add_ripple(position, 0.1 + v3.length() * 0.05, 0.3)
		Effects.splash(world, nu * wr, nu, 0.03 + (0.04 if run else 0.0))
	# diving down from the surface: a swirl of rings
	if r > surface_r - 0.05 and nxt.length() < surface_r - 0.12 and v3.dot(u) < -0.4:
		world.add_ripple(position, 0.25, 0.35)
	bob = 0.0


# ================================================================== solid things
## Trees, rocks, buildings and the capsule are solid (checked along the ground)
func _push_out(p: Vector3) -> Vector3:
	var u := p.normalized()
	var out := p
	for o: Array in world.obstacles_near(p):
		if o.size() > 2 and int(o[2]) == 2:
			continue                      # (the capsule's rough sphere around a landform)
		out = _push(out, o[0], float(o[1]), u)
	if capsule:
		out = _push(out, capsule.position, 0.75, u)
	return out


func _push(p: Vector3, c: Vector3, rad: float, u: Vector3) -> Vector3:
	var d := p - c
	if d.length_squared() > 400.0:
		return p
	d -= u * d.dot(u)
	var need := rad + BODY_R
	var l := d.length()
	if l < need and l > 0.001:
		var n := d / l
		var into := vel.dot(n)
		if into < 0.0:
			vel -= n * into
		return p + n * (need - l)
	return p


# ================================================================== the body
func _mat(c: Color, rough := 0.6, metal := 0.0, glow := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow != Color.BLACK:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = 1.6
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## Space suit: white with orange panels, brass fittings, a glowing visor and a backpack lamp
func _build_body() -> void:
	var suit := _mat(Color("#e8ecf2"), 0.55)
	var panel := _mat(Color("#ff8a2a"), 0.5)
	var dark := _mat(Color("#2a2e3a"), 0.7)
	var brass := _mat(Color("#c9a35a"), 0.35, 0.8)
	var visor := _mat(Color("#1a3a5a"), 0.05, 0.3, Color("#38d6ff") * 0.6)
	rig = _pivot(self, Vector3.ZERO)
	rig.scale = Vector3.ONE * MODEL_SCALE
	var hips := _pivot(rig, Vector3(0, 0.44, 0))
	torso = _pivot(hips, Vector3.ZERO)
	_part(torso, CMesh.cyl(0.13, 0.11, 0.3, 12), suit, Vector3(0, 0.16, 0))
	_part(torso, CMesh.cyl(0.115, 0.12, 0.08, 12), panel, Vector3(0, 0.05, 0))
	_part(torso, CMesh.box(Vector3(0.16, 0.09, 0.04)), dark, Vector3(0, 0.2, 0.12))
	_part(torso, CMesh.ball(0.012, 6, 4), _mat(Color("#7dffb0"), 0.3, 0.0, Color("#7dffb0")), Vector3(0.05, 0.22, 0.142))
	# backpack with a lamp and a small antenna
	_part(torso, CMesh.box(Vector3(0.2, 0.24, 0.1)), panel, Vector3(0, 0.18, -0.15))
	_part(torso, CMesh.cyl(0.035, 0.035, 0.22, 10), brass, Vector3(0.07, 0.18, -0.21))
	_part(torso, CMesh.cyl(0.035, 0.035, 0.22, 10), brass, Vector3(-0.07, 0.18, -0.21))
	_part(torso, CMesh.cyl(0.006, 0.006, 0.18, 4), dark, Vector3(-0.08, 0.38, -0.16))
	_part(torso, CMesh.ball(0.014, 6, 4), _mat(Color("#ff5a6e"), 0.3, 0.0, Color("#ff5a6e")), Vector3(-0.08, 0.47, -0.16))
	head = _pivot(torso, Vector3(0, 0.33, 0))
	_part(head, CMesh.ring(0.075, 0.1, 18), brass, Vector3(0, -0.01, 0))
	_part(head, CMesh.ball(0.11, 16, 10), suit, Vector3(0, 0.08, 0))
	_part(head, CMesh.ball(0.09, 16, 10), visor, Vector3(0, 0.085, 0.035), Vector3(1.0, 0.8, 0.85))
	for sx: float in [-1.0, 1.0]:
		var sh := _pivot(torso, Vector3(sx * 0.15, 0.27, 0))
		_part(sh, CMesh.ball(0.05, 10, 6), panel, Vector3.ZERO)
		_part(sh, CMesh.cyl(0.04, 0.035, 0.15, 8), suit, Vector3(0, -0.08, 0))
		var el := _pivot(sh, Vector3(0, -0.16, 0))
		_part(el, CMesh.cyl(0.034, 0.03, 0.14, 8), suit, Vector3(0, -0.07, 0))
		_part(el, CMesh.ball(0.038, 8, 6), dark, Vector3(0, -0.15, 0.01))
		var hp := _pivot(hips, Vector3(sx * 0.065, 0.0, 0))
		_part(hp, CMesh.cyl(0.055, 0.045, 0.21, 8), suit, Vector3(0, -0.1, 0))
		var kn := _pivot(hp, Vector3(0, -0.21, 0))
		_part(kn, CMesh.ball(0.047, 8, 6), panel, Vector3.ZERO)
		_part(kn, CMesh.cyl(0.045, 0.04, 0.19, 8), suit, Vector3(0, -0.1, 0))
		_part(kn, CMesh.box(Vector3(0.09, 0.05, 0.16)), dark, Vector3(0, -0.205, 0.025))
		if sx < 0.0:
			arm_l = sh
			fore_l = el
			leg_l = hp
			shin_l = kn
		else:
			arm_r = sh
			fore_r = el
			leg_r = hp
			shin_r = kn
	for c in rig.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Walk / run cycle, jump pose, swimming strokes, breathing
func _animate(delta: float) -> void:
	if rig == null:
		return
	var spd := vel.length()
	swim_k = move_toward(swim_k, 1.0 if swimming else 0.0, delta * 2.5)
	var t := Time.get_ticks_msec() / 1000.0
	air_t = 0.0 if on_ground or swimming else air_t + delta
	if swimming:
		var v3 := vel + up() * fall
		var sw := v3.length()
		gait += delta * (2.2 + sw * 3.0)
		# the body lies along the swimming direction, face forward (not on its back):
		# rotating the upright body forward by (90 deg - climb angle) about its right axis
		var u := up()
		var climb := 0.0
		var yaw := 0.0
		if sw > 0.15:
			climb = asin(clampf(v3.dot(u) / sw, -1.0, 1.0))
			var flat := v3 - u * v3.dot(u)
			if flat.length() > 0.05:
				var lx := flat.dot(right())
				var lz := flat.dot(heading)
				yaw = clampf(atan2(-lx, lz), -1.4, 1.4) if lz > -0.2 else 0.0
		var theta := PI * 0.5 - climb if sw > 0.15 else (0.25 if position.length() > world.swim_surface(position) - FLOAT - 0.1 else 0.7)
		rig.rotation.x = lerp_angle(rig.rotation.x, theta, minf(1.0, delta * 4.0))
		rig.rotation.y = lerp_angle(rig.rotation.y, yaw, minf(1.0, delta * 4.0))
		# keep the middle of the body where the explorer is
		var half := 0.46 * MODEL_SCALE
		rig.position = rig.position.lerp(-Vector3(0, cos(rig.rotation.x), sin(rig.rotation.x)).rotated(Vector3.UP, rig.rotation.y) * half, minf(1.0, delta * 8.0))
		if sw > 0.15:
			# front crawl: legs kick fast and small, arms pull alternately
			var kick := sin(gait * 2.4) * 0.35
			leg_l.rotation.x = kick
			leg_r.rotation.x = -kick
			shin_l.rotation.x = 0.2 + maxf(0.0, -kick) * 0.5
			shin_r.rotation.x = 0.2 + maxf(0.0, kick) * 0.5
			var stroke := gait * 0.9
			arm_l.rotation.x = -PI + fposmod(stroke, TAU) * 0.5 if fposmod(stroke, TAU) < PI else -PI * 0.5 - (fposmod(stroke, TAU) - PI) * 0.5
			arm_r.rotation.x = -PI + fposmod(stroke + PI, TAU) * 0.5 if fposmod(stroke + PI, TAU) < PI else -PI * 0.5 - (fposmod(stroke + PI, TAU) - PI) * 0.5
			arm_l.rotation.z = -0.15
			arm_r.rotation.z = 0.15
			fore_l.rotation.x = -0.2
			fore_r.rotation.x = -0.2
			head.rotation.x = 0.5             # looks ahead, not down
		else:
			# treading water: slow scissor legs, arms sculling at the sides
			leg_l.rotation.x = sin(t * 2.0) * 0.35
			leg_r.rotation.x = -sin(t * 2.0) * 0.35
			shin_l.rotation.x = 0.5
			shin_r.rotation.x = 0.5
			arm_l.rotation.x = -0.4
			arm_r.rotation.x = -0.4
			arm_l.rotation.z = -0.9 + sin(t * 2.6) * 0.3
			arm_r.rotation.z = 0.9 - sin(t * 2.6) * 0.3
			fore_l.rotation.x = -0.4
			fore_r.rotation.x = -0.4
			head.rotation.x = 0.0
		torso.rotation.x = 0.0
		return
	rig.rotation.y = lerp_angle(rig.rotation.y, 0.0, minf(1.0, delta * 6.0))
	rig.position = rig.position.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))
	rig.rotation.x = lerp_angle(rig.rotation.x, 0.0, minf(1.0, delta * 6.0))
	head.rotation.x = lerpf(head.rotation.x, -pitch * 0.4, minf(1.0, delta * 8.0))
	if not on_ground and air_t > 0.08:
		# jump / fall pose: knees up, arms out for balance
		var k := clampf(air_t * 4.0, 0.0, 1.0)
		leg_l.rotation.x = lerpf(leg_l.rotation.x, -0.7 * k, minf(1.0, delta * 10.0))
		leg_r.rotation.x = lerpf(leg_r.rotation.x, -0.3 * k, minf(1.0, delta * 10.0))
		shin_l.rotation.x = lerpf(shin_l.rotation.x, 1.1 * k, minf(1.0, delta * 10.0))
		shin_r.rotation.x = lerpf(shin_r.rotation.x, 0.7 * k, minf(1.0, delta * 10.0))
		arm_l.rotation.z = lerpf(arm_l.rotation.z, -0.9 * k, minf(1.0, delta * 8.0))
		arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.9 * k, minf(1.0, delta * 8.0))
		arm_l.rotation.x = lerpf(arm_l.rotation.x, -0.5, minf(1.0, delta * 8.0))
		arm_r.rotation.x = lerpf(arm_r.rotation.x, -0.5, minf(1.0, delta * 8.0))
		return
	var running := spd > WALK + 0.3
	gait += delta * spd * (4.8 if running else 5.6) * (0.7 if water_state == "seabed" else 1.0)
	var amp := clampf(spd / (WALK * (0.5 if water_state == "seabed" else 1.0)), 0.0, 1.0) * (0.85 if running else 0.6)
	var s := sin(gait)
	leg_l.rotation.x = s * amp
	leg_r.rotation.x = -s * amp
	shin_l.rotation.x = maxf(0.0, -cos(gait)) * amp * 1.4
	shin_r.rotation.x = maxf(0.0, cos(gait)) * amp * 1.4
	arm_l.rotation.x = -s * amp * 0.9
	arm_r.rotation.x = s * amp * 0.9
	arm_l.rotation.z = lerpf(arm_l.rotation.z, -0.08, minf(1.0, delta * 8.0))
	arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.08, minf(1.0, delta * 8.0))
	fore_l.rotation.x = -0.25 - (0.6 if running else 0.15)
	fore_r.rotation.x = -0.25 - (0.6 if running else 0.15)
	torso.rotation.x = 0.18 if running else 0.04 * amp
	# breathing when standing
	torso.position.y = absf(s) * 0.02 * amp + sin(t * 1.8) * 0.004
	if water_state == "seabed":
		arm_l.rotation.z = -0.5 + sin(t * 1.5) * 0.15       # arms out for balance in the water
		arm_r.rotation.z = 0.5 - sin(t * 1.5) * 0.15
