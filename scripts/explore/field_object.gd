class_name FieldObject
extends Interactable
## Something special to examine (a mineral, plant or strange phenomenon). Definitions: Biomes.OBJECTS.
## Later: collecting samples, solving problems, quest goals.

var obj_id := ""
var def: Dictionary
var spin: Node3D = null
var t := 0.0


func setup(id: String) -> void:
	obj_id = id
	def = Biomes.OBJECTS[id]
	title = def["name"]
	key = "object:" + id
	reach = 5.0
	_build(str(def["model"]))
	add_hitbox(1.4, Vector3(0, 1.0, 0))
	# a few sparkles so it can be found
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 2.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.2
	p.position = Vector3(0, 1.0, 0)
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	p.mesh = Particles.soft_quad(0.12)
	p.material_override = Particles.material(Color.WHITE, true)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 0.8, 0))
	g.add_point(0.4, Color(1, 1, 0.8, 0.9))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 0.8, 0))
	p.color_ramp = g
	add_child(p)


func prompt() -> String:
	return "Examine " + title


func interact(screen: Node) -> void:
	screen.call("open_object", self)


func _process(delta: float) -> void:
	t += delta
	if spin:
		spin.rotation.y += delta * 0.6
		spin.position.y = spin.get_meta("y0", 0.0) + sin(t * 1.5) * 0.08


func _p(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	return WorldProps.part(self, mesh, mat, pos, rot, scl)


func _glow(c: Color, e := 2.0) -> StandardMaterial3D:
	return WorldProps.std(c, 0.3, 0.0, c, e)


func _build(model: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(obj_id)
	match model:
		"ore_vein":
			add_child(WorldProps.rock(rng, Color("#4a423c"), 1.6))
			for i in 5:
				_p(WorldProps.box(Vector3(0.08, 0.06, rng.randf_range(0.8, 1.6))), _glow(Color("#ffb347"), 2.5),
					Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.4, 1.0), rng.randf_range(-0.4, 0.4)), Vector3(rng.randf(), rng.randf() * TAU, rng.randf()))
		"wreck":
			var brass := WorldProps.std(Color("#b08a4a"), 0.35, 1.0)
			_p(WorldProps.cyl(0.9, 1.0, 1.8, 16), WorldProps.std(Color("#2a3450"), 0.5, 0.7), Vector3(0, 0.7, 0), Vector3(0.3, 0, 0.2))
			_p(WorldProps.sphere(0.9, 16, 8, true), brass, Vector3(0.15, 1.55, 0.1), Vector3(0.3, 0, 0.2))
			_p(WorldProps.torus(0.25, 0.38), brass, Vector3(0.0, 0.9, 0.95), Vector3(PI / 2 - 0.3, 0, 0))
			_p(WorldProps.cyl(0.25, 0.25, 0.05, 16), _glow(Color("#7ff5ff"), 1.5), Vector3(0.0, 0.9, 0.97), Vector3(PI / 2 - 0.3, 0, 0))
			_p(WorldProps.cyl(0.12, 0.12, 2.2, 8), brass, Vector3(-1.0, 0.3, 0), Vector3(0, 0, 1.2))
		"ice_bubble":
			_p(WorldProps.sphere(1.3, 20, 10), WorldProps.std(Color("#cfefff"), 0.02, 0.1, Color("#5fb8ff"), 0.2, 0.45), Vector3(0, 0.8, 0))
			spin = Node3D.new()
			spin.position = Vector3(0, 0.8, 0)
			spin.set_meta("y0", 0.8)
			add_child(spin)
			WorldProps.part(spin, WorldProps.sphere(1.0, 10, 5), WorldProps.std(Color("#304060")), Vector3(0.35, 0, 0), Vector3.ZERO, Vector3(0.25, 0.18, 0.35))
		"ice_core":
			_p(WorldProps.cyl(0.35, 0.5, 2.6, 6), WorldProps.std(Color("#5fb8ff"), 0.05, 0.2, Color("#3f9fff"), 2.0, 0.85), Vector3(0, 1.2, 0))
			_p(WorldProps.cyl(0.0, 0.35, 0.6, 6), _glow(Color("#9fdcff"), 2.5), Vector3(0, 2.8, 0))
		"spore_cluster":
			for i in 9:
				var r := rng.randf_range(0.15, 0.45)
				_p(WorldProps.sphere(r, 12, 6), ExploreShaders.nature(Color("#5ff7d0"), Color("#5ff7d0"), 2.2, 0.0, 0.8),
					Vector3(rng.randf_range(-0.6, 0.6), r + rng.randf_range(0.0, 0.6), rng.randf_range(-0.6, 0.6)))
		"root_heart":
			for i in 6:
				_p(WorldProps.torus(0.6 + i * 0.1, 0.78 + i * 0.1), WorldProps.std(Color("#6a4a50")), Vector3(0, 0.5, 0), Vector3(rng.randf() * PI, rng.randf() * PI, 0))
			_p(WorldProps.sphere(0.45, 14, 7), ExploreShaders.nature(Color("#ff6fb7"), Color("#ff6fb7"), 2.5, 0.0, 0.7), Vector3(0, 0.6, 0))
		"tide_pool":
			for i in 10:
				var a := TAU * i / 10.0
				add_child(_at(WorldProps.rock(rng, Color("#5f5a54"), rng.randf_range(0.3, 0.55)), Vector3(cos(a) * 1.3, 0, sin(a) * 1.3)))
			_p(WorldProps.cyl(1.3, 1.3, 0.05, 20), ExploreShaders.material("water", {"wave": 0.02, "clarity": 0.8}), Vector3(0, 0.15, 0))
			for i in 6:
				_p(WorldProps.sphere(0.04, 6, 3), _glow(Color("#7ff5ff"), 3.0), Vector3(rng.randf_range(-0.8, 0.8), 0.08, rng.randf_range(-0.8, 0.8)))
		"pearl_shell":
			var sh := WorldProps.std(Color("#f0d8e8"), 0.2, 0.3)
			_p(WorldProps.sphere(1.0, 16, 6, true), sh, Vector3(0, 0.3, 0), Vector3(PI, 0, 0), Vector3(1.0, 0.35, 0.8))
			_p(WorldProps.sphere(1.0, 16, 6, true), sh, Vector3(0, 0.35, -0.35), Vector3(-0.5, 0, 0), Vector3(1.0, 0.35, 0.8))
			_p(WorldProps.sphere(0.22, 14, 7), WorldProps.std(Color("#ffffff"), 0.05, 0.4, Color("#ffeefa"), 1.0), Vector3(0, 0.45, 0.1))
		"giant_flower":
			_p(WorldProps.cyl(0.08, 0.14, 1.6, 8), WorldProps.std(Color("#3a7a2a")), Vector3(0, 0.8, 0))
			for i in 7:
				var holder := Node3D.new()
				holder.position = Vector3(0, 1.6, 0)
				holder.rotation = Vector3(0, TAU * i / 7.0, 0)
				add_child(holder)
				WorldProps.part(holder, WorldProps.sphere(1.0, 10, 5), ExploreShaders.nature(Color("#ff5fa8"), Color("#ff2f88"), 0.3, 0.03),
					Vector3(0, 0.1, 0.55), Vector3(-0.4, 0, 0), Vector3(0.32, 0.05, 0.6))
			_p(WorldProps.sphere(0.25, 12, 6), _glow(Color("#ffe07a"), 2.0), Vector3(0, 1.72, 0))
		"amber":
			add_child(_at(WorldProps.rock(rng, Color("#4a3a26"), 0.8), Vector3.ZERO))
			_p(WorldProps.sphere(0.5, 16, 8), WorldProps.std(Color("#ffa830"), 0.05, 0.1, Color("#ff8a10"), 0.8, 0.75), Vector3(0, 0.9, 0))
			_p(WorldProps.sphere(1.0, 8, 4), WorldProps.std(Color("#3a2a10")), Vector3(0, 0.9, 0), Vector3(0.3, 0, 0), Vector3(0.1, 0.16, 0.08))
		"forge_ruin":
			var brick := WorldProps.std(Color("#4a3a34"))
			for i in 3:
				_p(WorldProps.box(Vector3(0.5, rng.randf_range(0.8, 2.0), 2.4)), brick, Vector3(-1.2 + i * 1.2, 0.6, -0.8), Vector3(0, i * 1.0, rng.randf_range(-0.1, 0.1)))
			_p(WorldProps.box(Vector3(0.7, 0.5, 0.4)), WorldProps.std(Color("#3a3a40"), 0.4, 0.9), Vector3(0, 0.45, 0.5))
			_p(WorldProps.sphere(0.4, 12, 6), _glow(Color("#ff7a2a"), 3.0), Vector3(0, 0.3, -0.6))
			var l := OmniLight3D.new()
			l.light_color = Color("#ff7a2a")
			l.omni_range = 5.0
			l.light_energy = 1.4
			l.position = Vector3(0, 0.8, -0.4)
			add_child(l)
		"hot_spring":
			for i in 9:
				var a := TAU * i / 9.0
				add_child(_at(WorldProps.rock(rng, Color("#6a5a4a"), rng.randf_range(0.35, 0.6)), Vector3(cos(a) * 1.4, 0, sin(a) * 1.4)))
			_p(WorldProps.cyl(1.4, 1.4, 0.05, 20), ExploreShaders.material("water", {"wave": 0.04, "deep": Color("#2a8a7a"), "shallow": Color("#9fffe0"), "clarity": 0.85}), Vector3(0, 0.2, 0))
			var p := CPUParticles3D.new()
			p.amount = 30
			p.lifetime = 3.0
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.8
			p.position = Vector3(0, 0.3, 0)
			p.direction = Vector3.UP
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.0
			p.gravity = Vector3.ZERO
			p.mesh = Particles.soft_quad(1.2)
			p.material_override = Particles.material(Color(1, 1, 1, 0.25), false)
			add_child(p)
		"storm_rod":
			var metal := WorldProps.std(Color("#8a90a0"), 0.3, 1.0)
			_p(WorldProps.cyl(0.08, 0.18, 4.0, 8), metal, Vector3(0, 2.0, 0))
			for i in 3:
				_p(WorldProps.torus(0.2, 0.3), metal, Vector3(0, 1.0 + i * 1.0, 0))
			_p(WorldProps.sphere(0.2, 12, 6), ExploreShaders.nature(Color("#fff36b"), Color("#fff36b"), 3.0, 0.0, 1.0), Vector3(0, 4.1, 0))
		"fulgurite":
			var glass := WorldProps.std(Color("#cfc0ff"), 0.05, 0.3, Color("#9f7bff"), 0.8, 0.85)
			for i in 6:
				_p(WorldProps.cyl(0.03, 0.09, rng.randf_range(0.6, 1.6), 6), glass, Vector3(rng.randf_range(-0.3, 0.3), 0.5, rng.randf_range(-0.3, 0.3)), Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.7, 0.7)))
		"sun_prism":
			_p(WorldProps.cyl(0.0, 0.6, 2.4, 3), WorldProps.std(Color("#fffbe8"), 0.02, 0.1, Color("#ffe8a0"), 3.5, 0.85), Vector3(0, 1.2, 0))
			_p(WorldProps.cyl(0.6, 0.6, 0.2, 3), WorldProps.std(Color("#b08a4a"), 0.3, 1.0), Vector3(0, 0.1, 0))
		"umbra_ruin":
			var dark := WorldProps.std(Color("#14101e"), 0.3, 0.6)
			var purple := Color("#a04bff")
			_p(WorldProps.box(Vector3(0.9, 3.6, 0.9)), dark, Vector3(0, 1.6, 0), Vector3(0.08, 0.4, -0.12))
			_p(WorldProps.box(Vector3(0.7, 1.6, 0.7)), dark, Vector3(1.3, 0.5, 0.4), Vector3(0.5, 0.2, 1.1))
			for i in 3:
				_p(WorldProps.torus(0.55, 0.62, 6), _glow(purple, 2.5), Vector3(0, 0.8 + i * 1.0, 0), Vector3(0.08, 0.4, -0.12))
			for i in 5:
				_p(WorldProps.box(Vector3.ONE * rng.randf_range(0.2, 0.5)), dark, Vector3(rng.randf_range(-1.6, 1.6), 0.1, rng.randf_range(-1.6, 1.6)), Vector3(rng.randf(), rng.randf(), rng.randf()))
			var ul := OmniLight3D.new()
			ul.light_color = purple
			ul.omni_range = 6.0
			ul.light_energy = 1.2
			ul.position = Vector3(0, 2.0, 0)
			add_child(ul)
		"glass_flower":
			var gl := WorldProps.std(Color("#fff4dc"), 0.02, 0.2, Color("#ffd27a"), 0.6, 0.6)
			_p(WorldProps.cyl(0.04, 0.06, 1.0, 6), gl, Vector3(0, 0.5, 0))
			for i in 6:
				var holder := Node3D.new()
				holder.position = Vector3(0, 1.0, 0)
				holder.rotation = Vector3(0, TAU * i / 6.0, 0)
				add_child(holder)
				WorldProps.part(holder, WorldProps.sphere(1.0, 10, 5), gl, Vector3(0, 0.1, 0.3), Vector3(-0.7, 0, 0), Vector3(0.15, 0.03, 0.35))


func _at(n: Node3D, pos: Vector3) -> Node3D:
	n.position = pos
	return n
