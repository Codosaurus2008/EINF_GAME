class_name Cannon
extends Node3D
## The capsule's cannon (left mouse button or X while flying). It fires a glowing shell straight
## at the point under the crosshair. The shell flies visibly (light, trail) and is checked
## against the real ground every 0.6 m of its flight; where it hits, the ground is blasted open:
## SphereWorld.blast() changes the terrain's height function (a real crater / a cavity in a
## rock wall) and Effects.impact() makes the explosion. Into the sea: a big splash and a water
## column (and a crater in the sea floor when it is shallow).
## One shot every 0.9 s; at most 4 shells in the air; shells never hit the capsule.

const SPEED := 95.0
const RANGE := 340.0
const INTERVAL := 0.9
const POWER := 1.0

var world: SphereWorld
var cooldown := 0.0
var shells: Array = []


func setup(w: SphereWorld) -> void:
	world = w


func ready_to_fire() -> bool:
	return cooldown <= 0.0 and shells.size() < 4


func fire(from: Vector3, target: Vector3, carry: Vector3) -> bool:
	if not ready_to_fire():
		return false
	cooldown = INTERVAL
	var dir := (target - from).normalized()
	var s := Shell.new()
	s.world = world
	s.cannon = self
	s.vel = dir * SPEED + carry * 0.5
	add_child(s)
	s.global_position = from
	s.setup()
	shells.append(s)
	# muzzle flash
	Effects._burst(world, from, from.normalized(), 18, 0.25, Vector2(1.0, 3.0), 25.0, 0.06,
		Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.5, 0.1, 0.0), 0.0, true)
	world.play_sfx("cannon" if ResourceLoader.exists("res://audio/ambient/cannon.wav") else "thud", 0.9)
	return true


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)


## Where a ray from `from` along `dir` meets the ground (or the sea), or Vector3.ZERO
static func ray_ground(w: SphereWorld, from: Vector3, dir: Vector3, max_dist := RANGE) -> Vector3:
	var prev := from
	var step := 1.5
	var dist := 0.0
	while dist < max_dist:
		var p := from + dir * dist
		if _below(w, p):
			# refine between the last free point and this one
			var a := prev
			var b := p
			for i in 8:
				var m := (a + b) * 0.5
				if _below(w, m):
					b = m
				else:
					a = m
			return b
		prev = p
		dist += step
		step = minf(step * 1.04, 4.0)
	return Vector3.ZERO


static func _below(w: SphereWorld, p: Vector3) -> bool:
	var r := p.length()
	if r < w.radius + w.terrain.height(p.normalized()):
		return true
	return w.water != null and r < w.water_radius()


## A flying shell
class Shell:
	extends Node3D
	var world: SphereWorld
	var cannon: Cannon
	var vel := Vector3.ZERO
	var travelled := 0.0
	var trail: CPUParticles3D

	func setup() -> void:
		var core := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.07
		sm.height = 0.14
		sm.radial_segments = 10
		sm.rings = 5
		core.mesh = sm
		core.material_override = WorldProps.std(Color("#fff2c0"), 0.2, 0.0, Color("#ffb040"), 6.0)
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(core)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.4)
		l.light_energy = 3.0
		l.omni_range = 5.0
		add_child(l)
		trail = CPUParticles3D.new()
		trail.amount = 50
		trail.lifetime = 0.5
		trail.local_coords = false
		trail.spread = 180.0
		trail.initial_velocity_min = 0.0
		trail.initial_velocity_max = 0.3
		trail.gravity = Vector3.ZERO
		trail.scale_amount_min = 0.5
		trail.scale_amount_max = 1.2
		trail.mesh = Particles.soft_quad(0.12)
		trail.material_override = Particles.material(Color.WHITE, true)
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.8, 0.4, 0.9))
		g.set_color(1, Color(0.5, 0.45, 0.4, 0.0))
		trail.color_ramp = g
		add_child(trail)
		trail.emitting = true

	func _process(delta: float) -> void:
		var move := vel * delta
		var steps := maxi(1, int(ceil(move.length() / 0.6)))
		var p := global_position
		for i in steps:
			var q := p + move / steps
			if _hit_test(p, q):
				return
			p = q
		global_position = p
		travelled += move.length()
		if travelled > Cannon.RANGE:
			# out of range: bursts in the air
			Effects._burst(world, p, p.normalized(), 30, 0.5, Vector2(2.0, 5.0), 180.0, 0.08,
				Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.3, 0.05, 0.0), 2.0, true)
			_done()

	## Checks the stretch a -> b: ground, rock / tree obstacles, the sea
	func _hit_test(a: Vector3, b: Vector3) -> bool:
		var w := world
		# obstacles (trees, big rocks): blast at them
		for o: Array in w.obstacles_near(b):
			var op: Vector3 = o[0]
			if op.distance_to(b) < float(o[1]) + 0.1:
				_explode(w.ground_point(op.normalized()), false)
				return true
		var r := b.length()
		var gh := w.radius + w.terrain.height(b.normalized())
		var sea := w.water != null and r < w.water_radius() and gh < w.water_radius()
		if r < gh:
			# exact point on the surface between a and b
			var lo := a
			var hi := b
			for i in 10:
				var m := (lo + hi) * 0.5
				if m.length() < w.radius + w.terrain.height(m.normalized()):
					hi = m
				else:
					lo = m
			_explode(hi, false)
			return true
		if sea:
			var surf := b.normalized() * w.water_radius()
			var depth := w.water_radius() - gh
			w.splash(surf, 2.2)
			w.add_ripple(surf, 1.4, 2.5)
			# shallow water: the blast still digs into the sea floor
			if depth < 3.5:
				_explode(b.normalized() * gh, true)
			else:
				_done()
			return true
		return false

	func _explode(p: Vector3, wet: bool) -> void:
		var w := world
		var u := p.normalized()
		var rock: Color = w.terrain.zone_colors(u)[2]
		w.blast(p, Cannon.POWER)
		if wet:
			Effects.splash(w, u * w.water_radius(), u, 1.5)
		else:
			Effects.impact(w, p, u, Cannon.POWER, rock)
		_done()

	func _done() -> void:
		trail.emitting = false
		# the trail fades, then the shell is gone
		for c in get_children():
			if c != trail:
				c.queue_free()
		set_process(false)
		cannon.shells.erase(self)
		get_tree().create_timer(0.6, false).timeout.connect(queue_free)
