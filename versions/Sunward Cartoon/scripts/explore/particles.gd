class_name Particles
extends RefCounted
## Weather and floating things around the player (snow, spores, embers, rain ...).

static var _dot: Texture2D


## Soft round dot used by all particles
static func dot_texture() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_dot = t
	return _dot


static func soft_quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	return q


static func material(col: Color, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.albedo_texture = dot_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_receive_shadows = true
	return m


## Particles that follow the player (attach to the player). kind from Biomes "particles".
static func weather(kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22, 6, 22)
	p.position = Vector3(0, 5, 0)
	p.gravity = Vector3.ZERO
	p.direction = Vector3(0, -1, 0)
	p.spread = 20.0
	var col := Color.WHITE
	var size := 0.12
	var additive := false
	match kind:
		"snow":
			p.amount = 700
			p.lifetime = 7.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 2.0
			p.gravity = Vector3(0.6, -0.4, 0.3)
			col = Color(1, 1, 1, 0.9)
			size = 0.14
		"rain":
			p.amount = 1500
			p.lifetime = 1.0
			p.emission_box_extents = Vector3(12, 1.5, 12)
			p.position = Vector3(0, 9, 0)
			p.initial_velocity_min = 14.0
			p.initial_velocity_max = 18.0
			p.spread = 4.0
			col = Color(0.75, 0.75, 1.0, 0.45)
			size = 0.06
			var drop := QuadMesh.new()
			drop.size = Vector2(0.006, 0.16)          # thin streaks, true to the small explorer
			p.mesh = drop
		"splash":
			# raindrops bursting on the ground around your feet
			p.amount = 260
			p.lifetime = 0.35
			p.emission_box_extents = Vector3(9, 0.05, 9)
			p.position = Vector3(0, 0.05, 0)
			p.direction = Vector3(0, 1, 0)
			p.spread = 35.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.0
			p.gravity = Vector3(0, -9.0, 0)
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.2
			col = Color(0.85, 0.9, 1.0, 0.55)
			size = 0.018
		"fireflies":
			# little glowing animals that wander slowly through the night
			p.amount = 70
			p.lifetime = 9.0
			p.emission_box_extents = Vector3(20, 2.5, 20)
			p.position = Vector3(0, 1.8, 0)
			p.spread = 180.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.5
			p.gravity = Vector3.ZERO
			p.damping_min = 0.2
			p.damping_max = 0.5
			col = Color(0.85, 1.0, 0.35, 1.0)
			size = 0.11
			additive = true
		"spores":
			p.amount = 260
			p.lifetime = 9.0
			p.direction = Vector3(0, 1, 0)
			p.spread = 180.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.4
			p.gravity = Vector3(0, 0.05, 0)
			col = Color(0.5, 1.0, 0.85, 0.9)
			size = 0.1
			additive = true
		"pollen":
			p.amount = 160
			p.lifetime = 8.0
			p.spread = 180.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.5
			col = Color(0.95, 1.0, 0.6, 0.8)
			size = 0.07
			additive = true
		"embers":
			p.amount = 220
			p.lifetime = 5.0
			p.direction = Vector3(0, 1, 0)
			p.spread = 30.0
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 2.2
			p.position = Vector3(0, 1, 0)
			col = Color(1.0, 0.5, 0.15, 1.0)
			size = 0.09
			additive = true
		"spray":
			p.amount = 120
			p.lifetime = 4.0
			p.spread = 180.0
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.8
			p.gravity = Vector3(1.0, 0.0, 0.2)
			col = Color(0.9, 1.0, 1.0, 0.5)
			size = 0.08
		"sparkle":
			p.amount = 240
			p.lifetime = 4.0
			p.spread = 180.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.4
			col = Color(1.0, 0.95, 0.7, 1.0)
			size = 0.08
			additive = true
		"ash":
			p.amount = 500
			p.lifetime = 8.0
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 1.0
			p.gravity = Vector3(0, -0.5, 0)
			col = Color(0.45, 0.42, 0.4, 0.85)
			size = 0.09
		"debris":
			p.amount = 120
			p.lifetime = 3.0
			p.emission_box_extents = Vector3(18, 3, 18)
			p.position = Vector3(0, 2, 0)
			p.spread = 60.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.0
			p.gravity = Vector3(0, -1.0, 0)
			col = Color(0.35, 0.32, 0.3, 1.0)
			size = 0.12
		"drift":
			p.amount = 600
			p.lifetime = 2.5
			p.emission_box_extents = Vector3(16, 1.5, 16)
			p.position = Vector3(0, 1.2, 0)
			p.spread = 30.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.5
			col = Color(1, 1, 1, 0.55)
			size = 0.16
		"bloom":
			p.amount = 90
			p.lifetime = 10.0
			p.direction = Vector3(0, 1, 0)
			p.spread = 180.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.3
			col = Color(1.0, 0.5, 0.9, 0.9)
			size = 0.22
			additive = true
		"sparks":
			p.amount = 60
			p.lifetime = 0.6
			p.spread = 180.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 5.0
			p.emission_box_extents = Vector3(14, 4, 14)
			col = Color(0.6, 0.9, 1.0, 1.0)
			size = 0.07
			additive = true
		_:   # dust
			p.amount = 160
			p.lifetime = 10.0
			p.spread = 180.0
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.25
			col = Color(0.85, 0.82, 0.78, 0.5)
			size = 0.06
	# final size of weather particles: about a quarter of the first values (the explorer is only
	# 23 cm tall; drops and flakes looked like snowballs) - rain and splashes are set above
	if not (kind in ["rain", "splash"]):
		size *= 0.3
	if p.mesh == null:
		p.mesh = soft_quad(size)
	var mat := material(Color.WHITE, additive)
	if kind == "rain":
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.albedo_texture = null
	p.material_override = mat
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.add_point(0.15, col)
	g.add_point(0.8, col)
	g.set_color(g.get_point_count() - 1, Color(col, 0.0))
	p.color_ramp = g
	p.preprocess = p.lifetime
	return p
