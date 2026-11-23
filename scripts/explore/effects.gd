class_name Effects
extends RefCounted
## One-off visual effects: water splashes, spray, sparks, dust, smoke and flying debris.
## Effects remove themselves when they are finished. `up` = away from the planet centre.

static func _burst(parent: Node, pos: Vector3, up: Vector3, amount: int, life: float, speed: Vector2, spread: float,
		size: float, col_a: Color, col_b: Color, gravity: float, additive: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(4, amount)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = -up * gravity
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.mesh = Particles.soft_quad(size)
	p.material_override = Particles.material(Color.WHITE, additive)
	var g := Gradient.new()
	g.set_color(0, col_a)
	g.set_color(1, col_b)
	p.color_ramp = g
	parent.add_child(p)
	p.global_position = pos
	p.basis = SphereTerrain.surface_basis(up, 0.0)
	p.emitting = true
	parent.get_tree().create_timer(life + 0.5, false).timeout.connect(p.queue_free)
	return p


## Makes water particles look natural instead of mechanical: ragged spray puffs instead of
## round dots, each turned at random, of very different sizes and lifetimes, slowed by the air
## (they fan out and hang for a moment), growing as the spray spreads and thins out
static func natural_water(p: CPUParticles3D, solid := true) -> void:
	p.material_override = Particles.spray_material()
	if solid:
		# defined white shapes: fully white and opaque for most of their life, then they
		# break up quickly (not faint grey dots)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(0.95, 0.98, 1.0, 0.0))
		g.add_point(0.7, Color(1, 1, 1, 0.95))
		p.color_ramp = g
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -40.0
	p.angular_velocity_max = 40.0
	p.lifetime_randomness = 0.45
	p.explosiveness = minf(p.explosiveness, 0.75)
	p.randomness = 0.6
	p.damping_min = 0.2
	p.damping_max = 1.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 2.2
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.45))
	c.add_point(Vector2(0.25, 1.0))
	c.add_point(Vector2(1.0, 1.7))
	p.scale_amount_curve = c
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(p.emission_sphere_radius, 0.08)


## Real spray is mostly single drops flying fast: thin white streaks along their path, of
## very different sizes, falling in arcs. Turns a particle burst into such drops.
static func water_drops(p: CPUParticles3D, length := 0.09) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(length * 0.22, length)
	p.mesh = q
	p.material_override = Particles.drop_material()
	p.particle_flag_align_y = true
	p.lifetime_randomness = 0.5
	p.randomness = 0.7
	p.damping_min = 0.0
	p.damping_max = 0.4
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.6
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(0.9, 0.96, 1.0, 0.0))
	g.add_point(0.75, Color(1, 1, 1, 0.9))
	p.color_ramp = g


## A burst of drops (see water_drops)
static func drops(parent: Node, pos: Vector3, up: Vector3, amount: int, speed: Vector2, spread: float, life: float, length: float) -> CPUParticles3D:
	var p := _burst(parent, pos, up, amount, life, speed, spread, 0.02, Color.WHITE, Color.WHITE, 9.8, false)
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.05 + length * 0.5
	water_drops(p, length)
	return p


## Water splash, sized to what hit the water: 0.05 a hand / small animal, 0.3 the explorer
## jumping in, 1 the capsule touching down, 4 a crash. Droplets fly higher and further, and
## there are more of them, the bigger the splash; big ones also throw up a column of water.
static func splash(parent: Node, pos: Vector3, up: Vector3, intensity: float) -> void:
	var k := clampf(intensity, 0.03, 4.5)
	var drop := 0.012 + k * 0.05
	# single drops flying out in arcs (the most of a real splash), and a few lumps of water
	drops(parent, pos, up, int(20 + 80 * sqrt(k)), Vector2(0.6, 1.6) * (0.8 + k * 1.6), 34.0 + k * 6.0, 0.6 + k * 0.3, 0.05 + k * 0.05)
	drops(parent, pos, up, int(10 + 40 * sqrt(k)), Vector2(0.4, 1.0) * (0.6 + k), 75.0, 0.45 + k * 0.2, 0.03 + k * 0.03)
	natural_water(_burst(parent, pos, up, int(5 + 18 * sqrt(k)), 0.5 + k * 0.3, Vector2(0.4, 1.2) * (0.7 + k * 1.4), 30.0 + k * 6.0,
		drop * 1.4, Color(0.97, 0.99, 1.0, 0.95), Color(0.82, 0.92, 1.0, 0.0), 9.0, false))
	# a crown of low spray all around
	natural_water(_burst(parent, pos, up, int(10 + 34 * sqrt(k)), 0.45 + k * 0.25, Vector2(0.3, 1.1) * (0.6 + k * 1.2), 80.0,
		drop * 2.2, Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0), 5.0, false))
	# white foamy water boiling on the surface where it hit
	natural_water(_burst(parent, pos + up * 0.03, up, int(6 + 14 * sqrt(k)), 0.9 + k * 0.4, Vector2(0.1, 0.5) * (0.5 + k), 88.0,
		0.12 + k * 0.12, Color(1, 1, 1, 0.55), Color(0.9, 0.96, 1.0, 0.0), 0.5, false), false)
	if k > 0.6:
		# a column of water and fine mist
		natural_water(_burst(parent, pos, up, int(24 * k), 0.8 + k * 0.25, Vector2(2.0, 4.2) * sqrt(k), 12.0,
			drop * 1.8, Color(0.97, 0.99, 1.0, 0.9), Color(0.85, 0.92, 1.0, 0.0), 9.0, false))
		natural_water(_burst(parent, pos + up * 0.2 * k, up, int(12 * k), 1.8 + k * 0.4, Vector2(0.3, 0.9) * k, 70.0,
			0.28 * k, Color(1, 1, 1, 0.26), Color(1, 1, 1, 0.0), -0.2, false), false)


## A cannon shell exploding under the water: a tall column of water shoots up (10-15 m),
## breaks into thousands of drops and lumps that rain back down, a wide crown of spray
## all around, and a cloud of mist that drifts away. k ~1 (bigger in deep water).
static func geyser(world: SphereWorld, pos: Vector3, up: Vector3, k: float) -> void:
	# the column: fast, narrow, rising high
	var col := drops(world, pos, up, int(260 * k), Vector2(9.0, 16.0) * sqrt(k), 9.0, 2.8, 0.22)
	col.emission_sphere_radius = 0.8
	natural_water(_burst(world, pos, up, int(120 * k), 2.6, Vector2(7.0, 14.0) * sqrt(k), 12.0,
		0.45, Color.WHITE, Color.WHITE, 9.8, false))
	# the crown all around
	drops(world, pos, up, int(200 * k), Vector2(3.0, 7.0) * k, 60.0, 1.8, 0.15)
	natural_water(_burst(world, pos, up, int(70 * k), 1.6, Vector2(2.0, 5.0) * k, 70.0,
		0.35, Color.WHITE, Color.WHITE, 9.8, false))
	# mist that hangs and drifts away
	var mist := _burst(world, pos + up * 3.0, up, int(40 * k), 5.0, Vector2(0.5, 2.5), 80.0,
		2.2 * k, Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0), -0.1, false)
	natural_water(mist, false)
	world.make_noise(pos, 4.0)


## Spray thrown up behind something moving fast through the water (a wake), every call one puff
static func spray(parent: Node, pos: Vector3, up: Vector3, back: Vector3, intensity: float) -> void:
	var k := clampf(intensity, 0.05, 2.5)
	var p := _burst(parent, pos, up, int(8 + 16 * k), 0.45 + 0.3 * k, Vector2(0.5, 1.6) * (0.6 + k), 40.0,
		0.03 + k * 0.06, Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.0), 8.0, false)
	natural_water(p)
	p.direction = (Vector3.UP * 1.0 + p.basis.inverse() * back * 0.8).normalized()
	var d := drops(parent, pos, up, int(14 + 26 * k), Vector2(0.8, 2.0) * (0.6 + k), 30.0, 0.5 + 0.3 * k, 0.06 + 0.04 * k)
	d.direction = p.direction


## The capsule's cannon shell hits rock: a flash lighting up the area, a fireball, sparks,
## rock fragments flying out (they bounce and lie around, then are cleared away), dust and
## rising smoke, and a sharp bang. power ~1 (size of the crater in metres / 2).
static func impact(world: SphereWorld, pos: Vector3, up: Vector3, power: float, rock: Color) -> void:
	if _fire_sh == null:
		_fire_sh = Shader.new()
		_fire_sh.code = FIRE_SHADER
		_ring_sh = Shader.new()
		_ring_sh.code = RING_SHADER
	var b := Blast.new()
	b.world = world
	b.up = up
	b.k = power
	world.add_child(b)
	b.global_position = pos
	b.setup()
	world.play_sfx("crash", clampf(0.55 + power * 0.2, 0.4, 1.0))
	world.play_sfx("thud", 1.0)
	sparks(world, pos + up * 0.1, up, 1.2 * power)
	_burst(world, pos, up, int(50 * power), 0.7, Vector2(3.0, 8.0) * power, 60.0, 0.05, Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.35, 0.05, 0.0), 6.0, true)
	# rock fragments
	for i in int(10 + 8 * power):
		var f := Fragment.new()
		f.world = world
		var mi := MeshInstance3D.new()
		mi.mesh = WorldProps.pebble_mesh(randi())
		var sz := randf_range(0.04, 0.22) * (0.8 + power * 0.3)
		mi.scale = Vector3(sz, sz * randf_range(0.6, 1.0), sz * randf_range(0.8, 1.3))
		mi.material_override = WorldProps.std(rock.lerp(rock.darkened(0.5), randf()), 0.9, 0.0)
		f.add_child(mi)
		world.add_child(f)
		f.global_position = pos + up * 0.15
		f.mass = clampf(sz * sz * sz * 40.0, 0.01, 2.0)
		var side := Vector3(randfn(0, 1), randfn(0, 1), randfn(0, 1))
		side -= up * side.dot(up)
		var spd := randf_range(3.0, 9.0) * (0.7 + power * 0.3) / sqrt(f.mass + 0.4)
		f.vel = (side.normalized() * randf_range(0.5, 1.0) + up * randf_range(0.5, 1.4)).normalized() * spd
		f.spin = Vector3(randfn(0, 1), randfn(0, 1), randfn(0, 1)) * 8.0
	dust(world, pos, up, rock.lightened(0.15), 1.6 * power)


## The cannon's blast: flash, fireball, short shock ring, smoke (cleans itself up)
class Blast:
	extends Node3D
	var world: SphereWorld
	var up := Vector3.UP
	var k := 1.0
	var t := 0.0
	var light: OmniLight3D
	var ball: MeshInstance3D
	var ball_mat: ShaderMaterial
	var ring: MeshInstance3D
	var ring_mat: ShaderMaterial
	var smoke: CPUParticles3D

	func setup() -> void:
		basis = SphereTerrain.surface_basis(up, 0.0)
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.92, 0.8)
		light.light_energy = 14.0
		light.omni_range = 18.0 * k
		light.position = Vector3(0, 1.0, 0)
		add_child(light)
		ball_mat = ShaderMaterial.new()
		ball_mat.shader = Effects._fire_sh
		ball_mat.set_shader_parameter("seed", randf() * 50.0)
		ball = MeshInstance3D.new()
		ball.mesh = CMesh.ball(1.0, 20, 12)
		ball.material_override = ball_mat
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ball)
		ring_mat = ShaderMaterial.new()
		ring_mat.shader = Effects._ring_sh
		ring = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2, 2)
		q.orientation = PlaneMesh.FACE_Y
		ring.mesh = q
		ring.material_override = ring_mat
		ring.position = Vector3(0, 0.1, 0)
		add_child(ring)
		smoke = CPUParticles3D.new()
		smoke.amount = 18
		smoke.lifetime = 2.5
		smoke.local_coords = false
		smoke.direction = Vector3.UP
		smoke.spread = 18.0
		smoke.initial_velocity_min = 0.8 * k
		smoke.initial_velocity_max = 2.0 * k
		smoke.damping_min = 0.2
		smoke.damping_max = 0.5
		smoke.scale_amount_min = 0.6
		smoke.scale_amount_max = 2.0
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		smoke.emission_sphere_radius = 0.6 * k
		smoke.mesh = Particles.soft_quad(0.9 * k)
		smoke.material_override = Particles.material(Color.WHITE, false)
		var g := Gradient.new()
		g.set_color(0, Color(0.62, 0.58, 0.52, 0.3))
		g.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
		smoke.color_ramp = g
		add_child(smoke)
		smoke.emitting = true

	func _process(delta: float) -> void:
		t += delta
		light.light_energy = 14.0 * exp(-t * 4.0) + 1.5 * maxf(0.0, 1.0 - t)
		light.light_color = Color(1.0, 0.92, 0.8).lerp(Color(1.0, 0.45, 0.15), clampf(t * 3.0, 0.0, 1.0))
		var sz := 1.4 * k * (1.0 - exp(-t * 9.0))
		ball.scale = Vector3(sz, sz * 0.8, sz)
		ball.position = Vector3(0, sz * 0.4 + t * 0.8 * k, 0)
		ball_mat.set_shader_parameter("age", clampf(t / 0.9, 0.0, 1.0))
		ball_mat.set_shader_parameter("smoke", clampf((t - 0.25) / 0.5, 0.0, 1.0))
		ball.visible = t < 1.2
		var rw := clampf(t / 0.3, 0.0, 1.0)
		ring.scale = Vector3.ONE * (0.4 + rw * 3.5) * k
		ring_mat.set_shader_parameter("age", rw)
		ring.visible = rw < 1.0
		smoke.emitting = t < 3.5
		smoke.gravity = up * 0.3
		if t > 10.0:
			queue_free()


## Sparks when metal hits rock
static func sparks(parent: Node, pos: Vector3, up: Vector3, intensity: float) -> void:
	var k := clampf(intensity, 0.3, 3.0)
	_burst(parent, pos, up, int(35 * k), 0.8, Vector2(4.0, 9.0) * (0.6 + k * 0.4), 70.0, 0.08,
		Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.3, 0.05, 0.0), 12.0, true)


## Dust cloud on the ground
static func dust(parent: Node, pos: Vector3, up: Vector3, col: Color, intensity: float) -> void:
	var k := clampf(intensity, 0.3, 3.0)
	_burst(parent, pos, up, int(20 * k), 1.2 + k * 0.4, Vector2(1.0, 3.0) * k, 85.0, 0.25 + k * 0.35,
		Color(col, 0.55), Color(col, 0.0), 0.5, false)


## Smoke that keeps rising (for a crashed capsule). Remove it with queue_free.
static func smoke(parent: Node3D, offset: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 4.0
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.5
	p.mesh = Particles.soft_quad(1.0)
	p.material_override = Particles.material(Color.WHITE, false)
	var g := Gradient.new()
	g.set_color(0, Color(0.74, 0.74, 0.75, 0.34))
	g.set_color(1, Color(0.8, 0.8, 0.82, 0.0))
	p.color_ramp = g
	p.position = offset
	parent.add_child(p)
	return p


## A few broken pieces that fly off and fall back to the ground
static func debris(parent: Node, pos: Vector3, up: Vector3, count: int, world: SphereWorld) -> void:
	for i in count:
		var d := Debris.new()
		d.world = world
		var mi := MeshInstance3D.new()
		mi.mesh = WorldProps.box(Vector3(0.25, 0.08, 0.3) * randf_range(0.6, 1.4))
		mi.material_override = _wreck_mat(WorldProps.std(Color("#2c3d6e") if i % 2 == 0 else Color("#c79a4a"), 0.4, 0.8))
		d.add_child(mi)
		parent.add_child(d)
		d.global_position = pos
		var side := Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0))
		side -= up * side.dot(up)
		d.vel = up * randf_range(3.0, 7.0) + side.normalized() * randf_range(2.0, 6.0)
		d.spin = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))


## A broken piece flying around (simple gravity towards the planet centre)
class Debris:
	extends Node3D
	var world: SphereWorld
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var life := 4.5

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		if life < 0.6:
			scale = Vector3.ONE * maxf(life / 0.6, 0.01)
		vel -= position.normalized() * world.gravity * delta
		position += vel * delta
		rotation += spin * delta
		var floor_r := world.floor_radius(position)
		if position.length() < floor_r + 0.1:
			position = position.normalized() * (floor_r + 0.1)
			vel *= 0.3
			spin *= 0.5


# ================================================================== the big crash explosion
const FIRE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform float age = 0.0;          // 0 .. 1 over the life of the fireball
uniform float smoke = 0.0;        // 1 = turns into dark smoke
uniform float seed = 0.0;
varying vec3 lp;
float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1.0,0.0,0.0)), f.x), mix(h3(i + vec3(0.0,1.0,0.0)), h3(i + vec3(1.0,1.0,0.0)), f.x), f.y);
	float b = mix(mix(h3(i + vec3(0.0,0.0,1.0)), h3(i + vec3(1.0,0.0,1.0)), f.x), mix(h3(i + vec3(0.0,1.0,1.0)), h3(i + vec3(1.0,1.0,1.0)), f.x), f.y);
	return mix(a, b, f.z);
}
void vertex() {
	lp = VERTEX;
	float n = n3(VERTEX * 3.0 + vec3(seed, TIME * 0.6, 0.0));
	VERTEX += NORMAL * (n - 0.5) * 0.45;
}
void fragment() {
	float n = n3(lp * 4.0 + vec3(seed, -TIME * 1.5, TIME * 0.7)) * 0.6 + n3(lp * 9.0 - vec3(0.0, TIME * 2.5, seed)) * 0.4;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	float heat = clamp(1.0 - age * 1.4 + n * 0.5 - edge * 0.5, 0.0, 1.0);
	vec3 col = mix(vec3(0.55, 0.06, 0.02), vec3(1.0, 0.55, 0.1), smoothstep(0.1, 0.5, heat));
	col = mix(col, vec3(1.0, 0.95, 0.75), smoothstep(0.6, 0.95, heat));
	// the fireball doesn't turn into a dark ball: it pales to light grey and thins out quickly
	vec3 sm = vec3(0.62, 0.6, 0.57) * (0.8 + n * 0.4);
	col = mix(col * (1.5 + heat * 2.5), sm, smoothstep(0.0, 1.0, smoke * (1.0 - heat * 0.8)));
	ALBEDO = col;
	ALPHA = clamp((1.0 - edge * 0.7) * (1.0 - smoothstep(0.75, 1.0, age)) * (0.6 + n * 0.6) * (1.0 - smoke * 0.8), 0.0, 1.0);
}
"""

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float age = 0.0;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float band = smoothstep(0.7, 0.92, r) * (1.0 - smoothstep(0.92, 1.0, r));
	vec3 col = mix(vec3(1.0, 0.9, 0.7), vec3(1.0, 0.4, 0.1), age);
	ALBEDO = col * band * 1.2;
	ALPHA = band * (1.0 - age) * 0.55;
}
"""

static var _fire_sh: Shader
static var _ring_sh: Shader


## Miniature nuclear blast where the capsule hits the ground: flash, fireball, shockwave,
## mushroom cloud, smoke column, burning wreck, secondary blasts, sparks, debris, boom.
static func explosion(world: SphereWorld, pos: Vector3, up: Vector3) -> void:
	if _fire_sh == null:
		_fire_sh = Shader.new()
		_fire_sh.code = FIRE_SHADER
		_ring_sh = Shader.new()
		_ring_sh.code = RING_SHADER
	var b := Boom.new()
	b.world = world
	b.up = up
	world.add_child(b)
	b.global_position = pos
	b.setup()
	# sized for the small capsule: the whole blast is drawn at 45 % (fireball ~6 m, cloud ~12 m)
	b.scale = Vector3.ONE * b.k
	world.play_sfx("crash", 1.0)
	world.play_sfx("thunder", 1.0)
	sparks(world, pos + up * 0.5, up, 3.0)
	sparks(world, pos + up * 0.5, up, 2.5)
	debris(world, pos + up * 0.8, up, 14, world)
	# the dust has the colour of the ground it is thrown up from (snow powder on Glacia)
	dust(world, pos, up, world.ground_color(pos), 3.0)


class Boom:
	extends Node3D
	var world: SphereWorld
	var up := Vector3.UP
	var t := 0.0
	var light: OmniLight3D
	var ball: MeshInstance3D
	var ball_mat: ShaderMaterial
	var cap: MeshInstance3D
	var cap_mat: ShaderMaterial
	var ring: MeshInstance3D
	var ring_mat: ShaderMaterial
	var column: CPUParticles3D
	var fire: CPUParticles3D
	var secondary := [0.35, 0.7, 1.1, 1.6]
	var k := 0.45

	func setup() -> void:
		basis = SphereTerrain.surface_basis(up, 0.0)
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.95, 0.85)
		light.light_energy = 18.0
		light.omni_range = 80.0 * k
		light.position = Vector3(0, 4.0, 0)
		add_child(light)
		ball_mat = ShaderMaterial.new()
		ball_mat.shader = Effects._fire_sh
		ball_mat.set_shader_parameter("seed", randf() * 50.0)
		ball = MeshInstance3D.new()
		ball.mesh = CMesh.ball(1.0, 28, 18)
		ball.material_override = ball_mat
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ball)
		cap_mat = ShaderMaterial.new()
		cap_mat.shader = Effects._fire_sh
		cap_mat.set_shader_parameter("seed", randf() * 50.0)
		cap = MeshInstance3D.new()
		cap.mesh = CMesh.ball(1.0, 28, 18)
		cap.material_override = cap_mat
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cap.visible = false
		add_child(cap)
		ring_mat = ShaderMaterial.new()
		ring_mat.shader = Effects._ring_sh
		ring = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2, 2)
		q.orientation = PlaneMesh.FACE_Y
		ring.mesh = q
		ring.material_override = ring_mat
		ring.position = Vector3(0, 0.3, 0)
		add_child(ring)
		# the column of smoke rising out of the fireball (stays for a while)
		column = CPUParticles3D.new()
		column.amount = 45
		column.lifetime = 5.0
		column.local_coords = false
		column.direction = Vector3.UP
		column.spread = 8.0
		column.initial_velocity_min = 4.0 * k
		column.initial_velocity_max = 7.0 * k
		column.damping_min = 0.3
		column.damping_max = 0.6
		column.scale_amount_min = 2.0
		column.scale_amount_max = 5.0
		column.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		column.emission_sphere_radius = 1.5
		column.mesh = Particles.soft_quad(2.2 * k)
		column.material_override = Particles.material(Color.WHITE, false)
		var g := Gradient.new()
		g.set_color(0, Color(0.8, 0.77, 0.73, 0.32))
		g.set_color(1, Color(0.85, 0.85, 0.86, 0.0))
		column.color_ramp = g
		column.gravity = up * 0.0
		add_child(column)
		column.emitting = true
		# fire that keeps burning on the wreck
		fire = CPUParticles3D.new()
		fire.amount = 40
		fire.lifetime = 1.2
		fire.local_coords = false
		fire.direction = Vector3.UP
		fire.spread = 25.0
		fire.initial_velocity_min = 1.0 * k
		fire.initial_velocity_max = 2.5 * k
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		fire.emission_sphere_radius = 1.0
		fire.scale_amount_min = 0.6
		fire.scale_amount_max = 1.6
		fire.mesh = Particles.soft_quad(0.8 * k)
		fire.material_override = Particles.material(Color.WHITE, true)
		var g2 := Gradient.new()
		g2.set_color(0, Color(1.0, 0.8, 0.3, 1.0))
		g2.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
		fire.color_ramp = g2
		add_child(fire)
		fire.emitting = true

	func _process(delta: float) -> void:
		t += delta
		# flash: white, then orange and red, fading
		var k := clampf(t / 3.0, 0.0, 1.0)
		light.light_energy = 18.0 * exp(-t * 1.6) + 2.0 * (1.0 - k) if t < 3.0 else maxf(0.0, light.light_energy - delta * 2.0)
		light.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.45, 0.15), clampf(t * 1.5, 0.0, 1.0))
		light.omni_range = (80.0 if t < 1.5 else lerpf(80.0, 20.0, clampf((t - 1.5) / 3.0, 0.0, 1.0))) * k
		# fireball grows fast and rises, then turns to smoke
		var fb := clampf(t / 4.0, 0.0, 1.0)
		var sz := 13.0 * (1.0 - exp(-t * 3.5))
		ball.scale = Vector3(sz, sz * 0.85, sz)
		ball.position = Vector3(0, sz * 0.55 + t * 2.5, 0)
		ball_mat.set_shader_parameter("age", fb)
		ball_mat.set_shader_parameter("smoke", clampf((t - 1.0) / 2.0, 0.0, 1.0))
		# mushroom cap forms above the rising column
		if t > 0.8:
			cap.visible = true
			var ct := t - 0.8
			var cs := 14.0 * (1.0 - exp(-ct * 1.2))
			cap.scale = Vector3(cs, cs * 0.45, cs)
			cap.position = Vector3(0, 12.0 + ct * 6.0, 0)
			cap_mat.set_shader_parameter("age", clampf(ct / 7.0, 0.0, 1.0))
			cap_mat.set_shader_parameter("smoke", clampf(ct / 2.5, 0.0, 1.0))
		# the shockwave runs along the ground
		var rw := clampf(t / 0.5, 0.0, 1.0)
		ring.scale = Vector3.ONE * (1.5 + rw * 9.0)
		ring_mat.set_shader_parameter("age", rw)
		ring.visible = rw < 1.0
		column.emitting = t < 7.0
		fire.emitting = t < 25.0
		# secondary explosions around the wreck
		if not secondary.is_empty() and t > float(secondary[0]):
			secondary.pop_front()
			var off := Vector3(randf_range(-4, 4), randf_range(0.5, 3.0), randf_range(-4, 4))
			var p := global_position + basis * off
			Effects._burst(world, p, up, 40, 0.9, Vector2(3.0, 7.0) * k, 180.0, 1.2 * k, Color(1.0, 0.85, 0.4, 1.0), Color(0.8, 0.2, 0.05, 0.0), 1.0, true)
			Effects.sparks(world, p, up, 1.5)
			world.play_sfx("thud", 0.8)
		if t > 30.0:
			queue_free()


# ================================================================== the capsule breaks apart
## Splits the capsule model into flying pieces: the hull into 8 curved panels, and every other
## part (rings, fins, engines, window, tail fin, legs, lamps) as it is, plus small shards.
## Heavier pieces fly slower and spin less. The biggest pieces burn and smoke.
static func shatter(world: SphereWorld, model: Node3D, centre: Vector3, up: Vector3, carry_vel: Vector3) -> void:
	var pieces: Array = []          # [mesh, material, global transform of the mesh]
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.visible or mi.mesh == null or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue                # (engine flames: not real parts)
		var xf := mi.global_transform
		if mi.mesh is SphereMesh and mi.scale.z > 1.2:
			for p: Array in _split_octants(mi.mesh, xf):
				pieces.append([p[0], _wreck_mat(mi.material_override), Transform3D(Basis(), p[1])])
		else:
			pieces.append([mi.mesh, _wreck_mat(mi.material_override), xf])
	var shard_mat := _wreck_mat(WorldProps.std(Color("#2c3d6e"), 0.4, 0.8))
	for i in 20:
		var s := randf_range(0.06, 0.2)
		var bm := WorldProps.box(Vector3(s * 1.6, s * 0.25, s))
		pieces.append([bm, shard_mat, Transform3D(Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, 0)), centre + Vector3(randf_range(-0.8, 0.8), randf_range(-0.5, 0.8), randf_range(-0.8, 0.8)))])
	var burning := 0
	# sort: biggest first (they burn)
	var sized: Array = []
	for p2: Array in pieces:
		var m: Mesh = p2[0]
		var xf2: Transform3D = p2[2]
		var size := (xf2.basis * m.get_aabb().size).length()
		sized.append([size, p2])
	sized.sort_custom(func(a, b): return a[0] > b[0])
	for e: Array in sized:
		var size2 := float(e[0])
		var p3: Array = e[1]
		var f := Fragment.new()
		f.world = world
		var mi2 := MeshInstance3D.new()
		mi2.mesh = p3[0]
		mi2.material_override = p3[1]
		var gxf: Transform3D = p3[2]
		f.add_child(mi2)
		world.add_child(f)
		# the fragment node sits at the piece's centre, the mesh keeps its shape and scale
		var c := gxf * (p3[0] as Mesh).get_aabb().get_center()
		f.global_position = c
		mi2.transform = Transform3D(gxf.basis, gxf.origin - c)
		f.mass = clampf(size2 * size2 * size2, 0.02, 6.0)
		var out := (c - centre)
		out -= up * out.dot(up) * 0.3
		if out.length() < 0.05:
			out = Vector3(randfn(0, 1), 0, randfn(0, 1))
		var spd := clampf(9.0 / sqrt(f.mass + 0.3), 3.0, 18.0) * randf_range(0.7, 1.2)
		f.vel = carry_vel * 0.25 + (out.normalized() * 0.8 + up * randf_range(0.6, 1.4)).normalized() * spd
		f.spin = Vector3(randfn(0, 1), randfn(0, 1), randfn(0, 1)) * clampf(6.0 / sqrt(f.mass + 0.2), 1.0, 14.0)
		f.stay = randf_range(6.0, 9.0)
		if burning < 5 and size2 > 0.6:
			burning += 1
			f.ignite()


## Cuts a sphere mesh into 8 shell pieces (one per octant). Returns [[mesh, centre], ...]
static func _split_octants(mesh: Mesh, xf: Transform3D) -> Array:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var buckets: Array = []
	for i in 8:
		buckets.append([[], []])
	var nb := xf.basis.inverse().transposed()
	for t in range(0, idx.size(), 3):
		var a := v[idx[t]]
		var b := v[idx[t + 1]]
		var c := v[idx[t + 2]]
		var m := (a + b + c) / 3.0
		var k := (1 if m.x > 0.0 else 0) + (2 if m.y > 0.0 else 0) + (4 if m.z > 0.0 else 0)
		for j in 3:
			buckets[k][0].append(xf * v[idx[t + j]])
			buckets[k][1].append((nb * nrm[idx[t + j]]).normalized())
	var out: Array = []
	for bk: Array in buckets:
		var pv := PackedVector3Array(bk[0])
		if pv.size() < 3:
			continue
		var cen := Vector3.ZERO
		for p in pv:
			cen += p
		cen /= pv.size()
		var local := PackedVector3Array()
		for p2 in pv:
			local.append(p2 - cen)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = local
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(bk[1])
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.append([am, cen])
	return out


static func _two_sided(m: Material) -> Material:
	if m is BaseMaterial3D:
		var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
		d.cull_mode = BaseMaterial3D.CULL_DISABLED
		return d
	return m


## Material for a broken piece of the capsule. The hull is dark navy and very metallic: as loose
## pieces on the ground (no sky to reflect, the inside of the curved panels facing away from the
## light) they were drawn almost black and looked like black circles on the ground. Wreck pieces
## are less metallic and a little lighter, lit on both sides, and don't get the bump detail.
static var _wreck_cache := {}
static func _wreck_mat(m: Material) -> Material:
	if not (m is BaseMaterial3D):
		return m
	if _wreck_cache.has(m):
		return _wreck_cache[m]
	var src := m as BaseMaterial3D
	var d := StandardMaterial3D.new()
	var c := src.albedo_color
	var lum := c.get_luminance()
	d.albedo_color = c.lerp(Color(0.62, 0.66, 0.74), 0.45) if lum < 0.3 else c
	d.metallic = minf(src.metallic, 0.3)
	d.roughness = maxf(src.roughness, 0.5)
	d.cull_mode = BaseMaterial3D.CULL_DISABLED
	if src.emission_enabled:
		d.emission_enabled = true
		d.emission = src.emission
		d.emission_energy_multiplier = src.emission_energy_multiplier * 0.3
	_wreck_cache[m] = d
	return d


## A flying piece of the capsule: falls towards the planet centre, tumbles, bounces off the
## ground, slides to a stop, maybe burns, and disappears after a while
class Fragment:
	extends Node3D
	var world: SphereWorld
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var mass := 1.0
	var wet := false
	var life := 0.0
	var resting := false
	var fire: CPUParticles3D = null
	var smoke: CPUParticles3D = null
	var stay := 18.0                 # seconds it lies there before it sinks away

	func ignite() -> void:
		fire = CPUParticles3D.new()
		fire.amount = 24
		fire.lifetime = 0.8
		fire.local_coords = false
		fire.direction = Vector3.UP
		fire.spread = 30.0
		fire.initial_velocity_min = 0.5
		fire.initial_velocity_max = 1.5
		fire.scale_amount_min = 0.5
		fire.scale_amount_max = 1.2
		fire.mesh = Particles.soft_quad(0.35)
		fire.material_override = Particles.material(Color.WHITE, true)
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.8, 0.3, 1.0))
		g.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
		fire.color_ramp = g
		add_child(fire)
		smoke = Effects.smoke(self, Vector3.ZERO)
		smoke.amount = 20
		smoke.scale_amount_max = 1.5

	func _process(delta: float) -> void:
		life += delta
		var u := position.normalized()
		if fire:
			fire.gravity = u * 2.0
			fire.emitting = life < minf(10.0, stay - 1.0)
		if smoke:
			smoke.gravity = u * 0.8
			smoke.emitting = life < minf(14.0, stay - 1.5)
		if life > stay:
			# sinks into the ground and shrinks away, then gone (nothing stays lying around)
			var k := clampf(1.0 - (life - stay) / 1.5, 0.0, 1.0)
			scale = Vector3.ONE * maxf(k, 0.01)
			position -= u * delta * 0.25
			if k <= 0.0:
				queue_free()
			return
		if resting:
			return
		# into the sea: a splash by the piece's weight and speed, then it sinks slowly, held back
		# by the water, and settles on the sea floor
		var in_sea := world.water != null and position.length() < world.water_radius() + world.wave_at(position)
		if in_sea and not wet:
			wet = true
			var hit := vel.length()
			world.splash(position, clampf(mass * 0.4 + hit * 0.05, 0.05, 1.8))
			world.add_ripple(position, clampf(0.2 + hit * 0.04, 0.1, 1.2), clampf(0.2 + mass * 0.5, 0.15, 2.0))
			if fire:
				fire.emitting = false
		if wet:
			vel -= u * world.gravity * 0.18 * delta
			vel *= exp(-3.0 * delta)
			position += vel * delta
			rotate(spin.normalized() if spin.length() > 0.001 else Vector3.UP, spin.length() * delta * 0.3)
			var sea_floor := world.ground_r(position)
			if position.length() < sea_floor + 0.05:
				position = position.normalized() * (sea_floor + 0.05)
				resting = true
			return
		vel -= u * world.gravity * delta
		vel *= exp(-0.05 * delta)
		position += vel * delta
		rotate(spin.normalized() if spin.length() > 0.001 else Vector3.UP, spin.length() * delta)
		var floor_r := world.floor_radius(position)
		if position.length() < floor_r + 0.05:
			position = position.normalized() * (floor_r + 0.05)
			var into := vel.dot(u)
			if into < 0.0:
				vel -= u * into * 1.35                  # bounce a little
			vel *= 0.55                                  # friction on the ground
			spin *= 0.55
			if vel.length() < 0.4:
				resting = true
				if world.is_water(position):
					# pieces that fall into the sea sink out of sight
					life = stay
