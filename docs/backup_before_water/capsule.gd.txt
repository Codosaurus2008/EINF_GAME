class_name Capsule
extends Node3D
## The player's small exploration capsule. Flies freely around a round planet (centre at 0,0,0):
## "up" is always away from the planet centre, so the capsule stays level with the ground.
##   mouse / arrow keys  steer (left/right = turn, up/down = nose up/down)
##   W / S               forward / backward      A / D   slide sideways
##   Space / C (or Ctrl) climb / sink - sink close to flat ground to land
##   Shift               boost
## Touching water: the capsule lands on it and surfs (the result depends on speed, angle and
## how the capsule is tilted). Hitting the ground or rocks too fast damages it or makes it crash.
## Damage and repairs are kept in Game.capsule.

signal impact(kind: String, strength: float, message: String)   # for messages and camera shake

const ACCEL := 26.0
const DRAG := 1.5               # higher = stops faster (top speed = ACCEL / DRAG)
const TURN_KEYS := 1.8          # arrow keys: turning speed (radians per second)
const SIZE := 0.5               # the capsule model is shown at half its built size (about 1.3 m long)
const HOVER := 0.6              # lowest height of the capsule's centre above the ground
# hitting solid ground: speed into the surface (m/s)
const SAFE_HIT := 6.0           # below: no damage
const CRASH_HIT := 13.0         # above: crash
# on water
const FLOAT := 0.18             # how high the capsule's centre floats above the water
const WATER_DRAG := 0.45
const TAKEOFF_SPEED := 8.0
const BOOST := 4.5              # Shift: top speed x this (17 -> 78 m/s, smoothly ramped)
const BOOST_RAMP := 2.6         # how fast the boost builds up (it fades a bit slower)
## The capsule stays inside the planet's air: a firm ceiling above the ground (no flying off
## into space - planets are travelled to through the ship's planet selection)
const MAX_ALT := 150.0

var world: SphereWorld
var vel := Vector3.ZERO
var beacon: OmniLight3D
var downwash_t := 0.0
var heading := Vector3.FORWARD  # where the nose points, always along the ground
var pitch := 0.0                # nose up (+) / down (-)
var controls := true
var landed := false
var vel_before_crash := Vector3.ZERO
var boost_k := 1.0              # current boost (1 = normal .. BOOST), the camera widens with it
var view_up := Vector3.UP       # "up" the capsule and camera lean to (follows the ground smoothly)
var wave_pitch := 0.0           # floating: the tilt the waves give the capsule
var wave_roll := 0.0
var float_h := 0.0              # floating: height of the wave under the capsule
var noise_t := 0.0
var surfing := false
var touching := false           # was touching the ground / water last frame
var takeoff_t := 0.0            # > 0 while lifting off the water (no landing checks then)
var sensitivity := 0.0028
var t := 0.0
var roll := 0.0
var turn_rate := 0.0
var wake_t := 0.0
var shake := 0.0
var model: Node3D
var legs: Array = []
var flames: Array = []
var headlights: Array = []
var spray: CPUParticles3D
var smoke: CPUParticles3D = null
var window_mat: StandardMaterial3D


func _ready() -> void:
	_build_model()
	if crashed():
		model.visible = false                    # it was left broken: only smoke remains until repaired


func up() -> Vector3:
	return position.normalized()


func right() -> Vector3:
	return heading.cross(up()).normalized()


## Direction the capsule flies when pressing W
func nose() -> Vector3:
	return heading.rotated(right(), pitch)



func altitude() -> float:
	return position.length() - world.floor_radius(position)


func speed() -> float:
	return vel.length()


## Flying, Descending, Landed, Water surfing, Water takeoff, Crashed
func state() -> String:
	if crashed():
		return "Crashed"
	if surfing:
		return "Water surfing"
	if landed:
		return "Landed"
	if takeoff_t > 0.0:
		return "Water takeoff"
	if vel.dot(up()) < -1.0 and altitude() < 20.0:
		return "Descending"
	return "Flying"


func crashed() -> bool:
	return bool(Game.capsule["crashed"])


func hull() -> float:
	return float(Game.capsule["hull"])


## Start somewhere above the ground, nose pointing along `dir`
func place(p: Vector3, dir: Vector3) -> void:
	position = p
	var u := up()
	view_up = u
	heading = (dir - u * dir.dot(u)).normalized()
	if heading.length() < 0.5:
		heading = SphereTerrain.surface_basis(u, 0.0).z
	pitch = 0.0
	vel = Vector3.ZERO
	surfing = world.is_water(position) and altitude() < 1.0
	_orient(0.0)


func steer(rel: Vector2) -> void:
	if not controls:
		return
	var k := 0.55 if surfing else 1.0                    # boats turn slower
	heading = heading.rotated(up(), -rel.x * sensitivity * k)
	turn_rate += -rel.x * sensitivity * 8.0 * k
	pitch = clampf(pitch - rel.y * sensitivity, -0.9, 0.9) if not surfing else 0.0


func _key(k: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(k) else 0.0


func _process(delta: float) -> void:
	t += delta
	shake = maxf(0.0, shake - delta * 2.0)
	var u := up()
	heading = (heading - u * heading.dot(u)).normalized()     # keep the nose along the ground
	_update_smoke()
	var thrust := 0.0
	var side := 0.0
	var lift := 0.0
	var boost := 1.0
	view_up = view_up.slerp(u, minf(1.0, delta * 5.0)).normalized()
	# the engines are loud close to the ground: animals hear the capsule coming
	noise_t -= delta
	if noise_t <= 0.0 and not landed and vel.length() > 4.0 and altitude() < 18.0:
		noise_t = 1.0
		world.make_noise(position - up() * altitude(), clampf(vel.length() / 15.0, 0.5, 2.5))
	if controls and not crashed():
		thrust = _key(KEY_W) - _key(KEY_S)
		side = _key(KEY_D) - _key(KEY_A)
		lift = _key(KEY_SPACE) - maxf(_key(KEY_C), _key(KEY_CTRL))
		boost = BOOST if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
		var turn := _key(KEY_RIGHT) - _key(KEY_LEFT)
		var tilt := _key(KEY_UP) - _key(KEY_DOWN)
		if turn != 0.0 or tilt != 0.0:
			steer(Vector2(turn, -tilt) * TURN_KEYS * delta / sensitivity)
	# the boost builds up and fades smoothly (no jolt)
	boost_k = move_toward(boost_k, boost, delta * BOOST_RAMP * (1.0 if boost > boost_k else 1.4))
	boost = boost_k
	if surfing:
		_surf(delta, thrust, side, lift, boost)
		_orient(delta)
		return
	if landed or crashed():
		vel = Vector3.ZERO
		landed = true
		position = u * (world.floor_radius(position) + HOVER - 0.13)
		if not crashed() and (thrust != 0.0 or lift > 0.0 or side != 0.0):
			landed = false
			vel = u * 4.0
		_orient(delta)
		return
	if takeoff_t > 0.0:
		takeoff_t -= delta
		vel += u * 9.0 * delta                       # the capsule keeps climbing away from the water
		if takeoff_t <= 0.0 and altitude() < HOVER + 1.0:
			takeoff_t = 0.2                          # not clear yet: stay in takeoff a bit longer
	var r := right()
	# at high speed the sideways push stays normal, so steering stays calm
	var acc := nose() * thrust * ACCEL * boost + r * side * ACCEL * 0.7 + u * lift * ACCEL * 0.8
	vel += acc * delta
	vel *= exp(-DRAG * delta)
	# fast flight: sideways drift is damped harder, the capsule follows its nose
	if boost > 1.05:
		var sidev := vel.dot(r)
		vel -= r * sidev * minf(1.0, delta * 1.5 * (boost - 1.0))
	# keeps its height when nothing is pressed (feels like a hovering craft)
	if lift == 0.0 and thrust == 0.0:
		var radial := vel.dot(u)
		vel -= u * radial * minf(1.0, delta * 2.0)
	# flying low over the sea: the engines' downwash pushes rings into the water and whips up
	# spray; flying fast leaves a wake
	if world.water != null and world.is_water(position):
		var over := position.length() - world.water_radius()
		downwash_t -= delta
		if over < 3.5 and downwash_t <= 0.0:
			var k := (1.0 - over / 3.5)
			var sp := vel.length()
			downwash_t = 0.12 if sp > 6.0 else 0.25
			var surf := u * world.water_radius()
			world.add_ripple(surf, 0.15 + k * 0.5, 0.5 + k * 0.8)
			if k > 0.35:
				var back := -vel.normalized() if sp > 1.0 else Vector3.ZERO
				Effects.spray(world, surf, u, back, k * (0.4 + minf(sp / 20.0, 1.0)))
	# fast: move in small steps and check the ground after each one (no flying through hills)
	var steps := clampi(int(ceil(vel.length() * delta / 0.8)), 1, 12)
	for i in steps:
		position += vel * delta / steps
		_collide()
		if landed or crashed() or surfing:
			break
	_orient(delta)


# ================================================================== water: landing and surfing
func _surf(delta: float, thrust: float, side: float, lift: float, boost: float) -> void:
	var u := up()
	vel -= u * vel.dot(u)
	vel += (heading * thrust * ACCEL * 0.55 * boost + right() * side * ACCEL * 0.25) * delta
	vel *= exp(-WATER_DRAG * delta)
	# the nose slowly pulls the movement round when steering (like a boat)
	var sp := vel.length()
	if sp > 0.1:
		vel = vel.lerp(heading * sp * signf(vel.dot(heading) + 0.001), minf(1.0, delta * 1.2))
	var nxt := position + vel * delta
	if not world.is_water(nxt):
		# reached the beach: stop there (and land if slow)
		var into := sp
		vel = Vector3.ZERO
		surfing = false
		if into > SAFE_HIT:
			_hit_ground(into, "the shore")
		landed = true
		return
	# floats on the real waves: rides up and down with them, tilts with their slope, and is
	# pushed gently down the wave faces; water holds it back more the faster it goes
	var hw := world.wave_at(nxt)
	var hf := world.wave_at(nxt + heading * 0.6)
	var hb := world.wave_at(nxt - heading * 0.6)
	var hr := world.wave_at(nxt + right() * 0.45)
	var hl := world.wave_at(nxt - right() * 0.45)
	wave_pitch = lerpf(wave_pitch, atan2(hf - hb, 1.2), minf(1.0, delta * 6.0))
	wave_roll = lerpf(wave_roll, atan2(hr - hl, 0.9), minf(1.0, delta * 6.0))
	float_h = lerpf(float_h, hw, minf(1.0, delta * 8.0))
	position = nxt.normalized() * (world.water_radius() + FLOAT + float_h)
	var down_slope := heading * (hb - hf) / 1.2 + right() * (hl - hr) / 0.9
	vel += down_slope * world.gravity * 0.35 * delta
	vel *= exp(-0.04 * sp * delta)
	pitch = 0.0
	# wake: rings and spray behind the capsule
	wake_t -= delta
	if sp > 1.5 and wake_t <= 0.0:
		wake_t = 0.18
		# a V of rings behind and to the sides = the wake
		world.add_ripple(position - heading * 0.7, clampf(sp / 18.0, 0.15, 1.0), 0.6)
		world.add_ripple(position - heading * 0.4 + right() * 0.35, clampf(sp / 30.0, 0.1, 0.6), 0.35)
		world.add_ripple(position - heading * 0.4 - right() * 0.35, clampf(sp / 30.0, 0.1, 0.6), 0.35)
	spray.emitting = sp > 2.5
	spray.color = Color(1, 1, 1, clampf(sp / 20.0, 0.25, 1.0))
	spray.gravity = -u * 6.0
	# take off again
	if lift > 0.0 and not crashed():
		if sp >= TAKEOFF_SPEED:
			# water takeoff: its own state - no landing checks until the capsule is clear of the water
			surfing = false
			takeoff_t = 1.2
			spray.emitting = false
			vel += u * 7.0
			position += u * 0.3
			world.splash(position, 0.5 + sp / 25.0)
			world.add_ripple(position - heading * 1.5, clampf(sp / 15.0, 0.3, 1.5))
			Effects.spray(world, position.normalized() * world.water_radius(), u, -heading, 1.2 + sp / 20.0)
			impact.emit("takeoff", 0.0, "")
		elif int(t * 2.0) % 4 == 0 and fmod(t, 0.5) < delta:
			impact.emit("info", 0.0, "Need more speed to take off from the water (W).")


## First touch of the water: perfect, hard or failed landing
func _water_landing(v: Vector3) -> void:
	var u := up()
	var down := -v.dot(u)
	var flat_v := v - u * v.dot(u)
	var flat := flat_v.length()
	var spd := v.length()
	var angle := rad_to_deg(atan2(down, maxf(flat, 0.01)))
	var belly_first := pitch > -0.4 and absf(roll) < 0.45       # underside meets the water
	var keep := 0.85
	var size := 0.0
	var dmg := 0.0
	var kind := ""
	var msg := ""
	if angle < 28.0 and spd < 40.0 and belly_first:
		kind = "perfect"
		keep = 0.88
		size = 0.6 + spd / 20.0
		msg = "Perfect water landing!" if spd > 6.0 else ""
	elif angle < 55.0 and spd < 58.0:
		kind = "hard"
		keep = 0.45
		size = 1.4 + spd / 18.0
		if spd > 28.0 or angle > 40.0 or not belly_first:
			dmg = 4.0 + spd * 0.25
		msg = "Hard water landing!" + (" Hull -%d%%" % int(dmg) if dmg > 0.0 else "")
	else:
		kind = "failed"
		keep = 0.12
		size = 2.6 + spd / 15.0
		dmg = clampf(22.0 + spd * 0.6 + (10.0 if not belly_first else 0.0), 25.0, 75.0)
		msg = "Violent splashdown! Hull -%d%%" % int(dmg)
	vel = flat_v * keep
	surfing = true
	pitch = 0.0
	position = u * (world.water_radius() + FLOAT)
	world.splash(position, size)
	world.add_ripple(position, clampf(size * 0.6, 0.3, 2.5))
	if size > 1.0:
		world.add_ripple(position + flat_v.normalized() * 3.0, clampf(size * 0.4, 0.2, 1.5))
	shake = clampf(size * 0.25, 0.0, 1.0)
	if dmg > 0.0:
		Game.capsule_damage(dmg, false)
		if crashed():
			msg = "The capsule is badly damaged and drifts on the water. It needs a repair."
			_crash_effects(0.8, false)
	impact.emit(kind, size, msg)


# ================================================================== solid ground: landing, damage, crash
func _collide() -> void:
	var u := up()
	var floor_r := world.floor_radius(position)
	var r := position.length()
	var contact := false
	if r < floor_r + HOVER:
		contact = true
		if world.is_water(position):
			# only a real landing: not while taking off and only when coming down (or level)
			if takeoff_t > 0.0 or vel.dot(u) > 0.2:
				position = u * (floor_r + HOVER)
				var up_v := vel.dot(u)
				if up_v < 0.0:
					vel -= u * up_v
			else:
				_water_landing(vel)
			touching = true
			return
		var n := world.terrain.normal_at(position)
		var into := -vel.dot(n)
		if not touching and into > SAFE_HIT:
			_hit_ground(into, "the ground")
		position = u * (floor_r + HOVER)
		var radial := vel.dot(u)
		if radial < 0.0:
			vel -= u * radial
		var push := vel.dot(n)
		if push < 0.0:
			vel -= n * push * 0.6
		# landing: slow, low and sinking on fairly flat ground
		var flat_speed := (vel - u * vel.dot(u)).length()
		if flat_speed < 3.0 and controls and (Input.is_physical_key_pressed(KEY_C) or Input.is_physical_key_pressed(KEY_CTRL)) \
				and world.can_land(position):
			landed = true
	# the ceiling: the capsule can't leave the planet's air
	if r > floor_r + MAX_ALT:
		position = u * (floor_r + MAX_ALT)
		var radial2 := vel.dot(u)
		if radial2 > 0.0:
			vel -= u * radial2
	# big trees, rocks and buildings
	for o: Array in world.obstacles_near(position):
		if o.size() > 2 and int(o[2]) == 1:
			continue                      # (detailed outlines are for walkers)
		var c: Vector3 = o[0]
		var d := position - c
		var rr := float(o[1]) + 0.6
		if d.length_squared() < rr * rr:
			var n2 := d.normalized()
			var into2 := -vel.dot(n2)
			if into2 > SAFE_HIT:
				_hit_ground(into2, "an obstacle")
			position = c + n2 * rr
			if into2 > 0.0:
				vel += n2 * into2 * 1.3                 # bounce off
			contact = true
	touching = contact


## Too fast into something solid: damage, or a crash
func _hit_ground(into: float, what: String) -> void:
	var u := up()
	vel_before_crash = vel
	var steep := pitch < -0.5
	var dmg := (into - SAFE_HIT) * 7.0 * (1.4 if steep else 1.0)
	var crash := into > CRASH_HIT or (steep and into > CRASH_HIT * 0.8)
	Effects.sparks(world, position - u * 0.8, u, into / 6.0)
	Effects.dust(world, position - u * 0.9, u, Color(0.5, 0.45, 0.4), into / 6.0)
	shake = clampf(into / 12.0, 0.2, 1.0)
	world.play_sfx("crash" if crash else "thud", clampf(into / 14.0, 0.3, 1.0))
	Game.capsule_damage(dmg, crash)
	if crashed():
		vel = Vector3.ZERO
		landed = true
		_crash_effects(1.0, true)
		impact.emit("crash", into, "CRASH! The capsule hit %s at %d m/s and can't fly until it is repaired." % [what, int(into)])
	else:
		vel *= 0.35
		impact.emit("damage", into, "Hard impact on %s! Hull -%d%%" % [what, int(dmg)])


func _crash_effects(k: float, on_ground: bool) -> void:
	var u := up()
	Effects.sparks(world, position, u, 2.5 * k)
	Effects.debris(world, position + u * 0.5, u, int(6 * k) + 2, world)
	if on_ground:
		# hitting solid ground at crash speed: a big explosion (never for water landings),
		# and the capsule breaks into pieces that fly off
		Effects.explosion(world, position - u * 0.6, u)
		Effects.shatter(world, model, position, u, vel_before_crash)
		model.visible = false
		for hl: SpotLight3D in headlights:
			hl.visible = false
	shake = 1.0


## A crashed or badly damaged capsule smokes
func _update_smoke() -> void:
	var want := crashed() or hull() < 40.0
	if want and smoke == null:
		smoke = Effects.smoke(self, Vector3(0, 0.6, -0.6))
	elif not want and smoke != null:
		smoke.queue_free()
		smoke = null
	if smoke:
		smoke.gravity = up() * 0.5
		smoke.color = Color(1, 1, 1, 1.0 if crashed() else 0.5)


# ================================================================== looks
func _orient(delta: float) -> void:
	var u := view_up
	var h := (heading - u * heading.dot(u)).normalized()
	if h.length() < 0.5:
		h = heading
	basis = Basis(u.cross(h).normalized(), u, h)
	turn_rate = lerpf(turn_rate, 0.0, minf(1.0, delta * 4.0))
	var side_v := vel.dot(right())
	var lean := 0.12 if surfing else 0.25
	roll = lerpf(roll, clampf(-turn_rate * lean - side_v * 0.03, -0.5, 0.5), minf(1.0, delta * 5.0))
	if crashed() and not surfing:
		roll = lerpf(roll, 0.35, minf(1.0, delta * 2.0))          # lying a bit on its side
	if model:
		var nose_up := clampf(vel.length() / 25.0, 0.0, 0.18) if surfing else 0.0
		var wp := wave_pitch if surfing else 0.0
		var wr := wave_roll if surfing else 0.0
		model.rotation = Vector3(-pitch * 0.45 - clampf(vel.dot(heading) * 0.008, -0.15, 0.15) - nose_up - wp, 0, roll + wr)
		var sh := Vector3(sin(t * 53.0), sin(t * 47.0), cos(t * 59.0)) * shake * 0.12
		model.position = sh + Vector3(0, (0.0 if landed or surfing else sin(t * 2.0) * 0.06), 0)
		if surfing:
			model.position.y += sin(t * 1.7) * 0.015          # (the real waves do the rest)
		var out := 1.0 if (landed or altitude() < 4.0) and not surfing else 0.0
		for l: Node3D in legs:
			l.scale.y = lerpf(l.scale.y, maxf(out, 0.05), minf(1.0, delta * 4.0))
		if beacon:
			# blinking parking light (only when parked)
			beacon.light_energy = (2.5 if fmod(t, 1.4) < 0.18 else 0.0) if landed and not crashed() and not controls else 0.0
		var power := clampf(vel.length() / 20.0, 0.15, 1.0) if not (landed or crashed()) else 0.0
		for f: MeshInstance3D in flames:
			f.scale = Vector3(1, 1, 1) * (0.6 + power * (0.7 + 0.3 * sin(t * 40.0 + f.position.x)))
			f.visible = not (landed or crashed()) and not (surfing and vel.length() < 1.0)


## Headlights: on while you are in the capsule, brighter when it is dark
## After a repair: the capsule is whole again
func restore() -> void:
	if model:
		model.visible = true


func set_lights(on: bool, darkness: float) -> void:
	for l: SpotLight3D in headlights:
		l.visible = on
		l.light_energy = lerpf(1.2, 7.0, darkness) * (0.4 if crashed() else 1.0)


func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	model.scale = Vector3.ONE * SIZE
	var hull_m := WorldProps.std(Color("#1f2c52"), 0.3, 0.8)
	var hull2 := WorldProps.std(Color("#2c3d6e"), 0.35, 0.7)
	var brass := WorldProps.std(Color("#c79a4a"), 0.25, 1.0)
	window_mat = WorldProps.std(Color("#7ff5ff"), 0.1, 0.0, Color("#38d6ff"), 2.2)
	# body: rounded pod, nose to +Z
	WorldProps.part(model, WorldProps.sphere(1.0, 24, 12), hull_m, Vector3.ZERO, Vector3.ZERO, Vector3(0.95, 0.8, 1.35))
	WorldProps.part(model, WorldProps.torus(0.86, 1.0, 32), brass, Vector3(0, -0.05, 0), Vector3.ZERO, Vector3(1.0, 1.0, 1.4))
	# panel lines and rivets
	for i in 3:
		WorldProps.part(model, WorldProps.torus(0.78 - i * 0.12, 0.8 - i * 0.12, 32), hull2, Vector3(0, 0.3 + i * 0.18, -0.15), Vector3.ZERO, Vector3(1.0, 1.0, 1.35))
	# cockpit window
	WorldProps.part(model, WorldProps.sphere(1.0, 18, 9), window_mat, Vector3(0, 0.3, 0.75), Vector3(-0.35, 0, 0), Vector3(0.62, 0.42, 0.55))
	WorldProps.part(model, WorldProps.torus(0.55, 0.64, 24), brass, Vector3(0, 0.33, 0.86), Vector3(PI / 2 - 0.35, 0, 0), Vector3(1.0, 1.0, 0.75))
	# fins and engines
	for sx: float in [-1.0, 1.0]:
		WorldProps.part(model, WorldProps.box(Vector3(0.9, 0.08, 0.7)), hull2, Vector3(sx * 1.1, -0.1, -0.5), Vector3(0, sx * 0.3, sx * 0.25))
		WorldProps.part(model, WorldProps.cyl(0.2, 0.26, 0.7, 12), brass, Vector3(sx * 0.55, -0.15, -1.25), Vector3(PI / 2, 0, 0))
		var f := WorldProps.part(model, WorldProps.cyl(0.0, 0.18, 0.9, 10), WorldProps.std(Color("#7fd8ff"), 0.5, 0.0, Color("#38b6ff"), 4.0, 0.8),
			Vector3(sx * 0.55, -0.15, -1.95), Vector3(-PI / 2, 0, 0))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.append(f)
		# headlight housings
		WorldProps.part(model, WorldProps.cyl(0.11, 0.13, 0.12, 12), brass, Vector3(sx * 0.42, -0.25, 1.22), Vector3(PI / 2, 0, 0))
		WorldProps.part(model, WorldProps.cyl(0.09, 0.09, 0.02, 12), WorldProps.std(Color("#fff8e0"), 0.2, 0.0, Color("#fff4d0"), 4.0),
			Vector3(sx * 0.42, -0.25, 1.29), Vector3(PI / 2, 0, 0))
		var hl := SpotLight3D.new()
		hl.position = Vector3(sx * 0.42, -0.25, 1.3)
		hl.rotation = Vector3(-0.22, PI, 0)        # a spot light shines along -Z: turn it to the front (+Z), a bit down
		hl.spot_range = 70.0
		hl.spot_angle = 40.0
		hl.spot_attenuation = 0.9
		hl.light_color = Color("#fff4e0")
		hl.shadow_enabled = sx > 0.0               # one shadow is enough (faster)
		model.add_child(hl)
		headlights.append(hl)
	WorldProps.part(model, WorldProps.box(Vector3(0.08, 0.6, 0.7)), hull2, Vector3(0, 0.7, -0.75), Vector3(-0.4, 0, 0))
	WorldProps.part(model, WorldProps.sphere(0.08, 8, 4), WorldProps.std(Color("#ffcf6a"), 0.3, 0.0, Color("#ffaa33"), 4.0), Vector3(0, 1.0, -0.95))
	# parking beacon: blinks while the capsule stands parked, so you can see it from afar
	beacon = OmniLight3D.new()
	beacon.light_color = Color("#ffb347")
	beacon.omni_range = 4.0
	beacon.light_energy = 0.0
	beacon.position = Vector3(0, 1.15, -0.95)
	model.add_child(beacon)
	# landing legs (fold away in flight)
	for i in 3:
		var a := TAU * i / 3.0 + PI / 6.0
		var leg := Node3D.new()
		leg.position = Vector3(cos(a) * 0.6, -0.55, sin(a) * 0.8)
		model.add_child(leg)
		WorldProps.part(leg, WorldProps.cyl(0.05, 0.06, 0.6, 6), brass, Vector3(0, -0.3, 0), Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4))
		WorldProps.part(leg, WorldProps.cyl(0.14, 0.16, 0.05, 10), hull2, Vector3(cos(a) * 0.12, -0.6, sin(a) * 0.12))
		legs.append(leg)
	# spray behind the capsule while surfing
	spray = CPUParticles3D.new()
	spray.amount = 70
	spray.lifetime = 1.0
	spray.local_coords = false
	spray.emitting = false
	spray.position = Vector3(0, -0.5, -1.4)
	spray.direction = Vector3(0, 0.8, -1)
	spray.spread = 25.0
	spray.initial_velocity_min = 1.0
	spray.initial_velocity_max = 3.2
	spray.scale_amount_min = 0.5
	spray.scale_amount_max = 1.6
	spray.mesh = Particles.soft_quad(0.12)
	spray.material_override = Particles.material(Color.WHITE, false)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.8))
	g.set_color(1, Color(0.85, 0.95, 1.0, 0.0))
	spray.color_ramp = g
	add_child(spray)
