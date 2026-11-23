class_name SphereWorld
extends Node3D
## One freed planet as a small round world (centre at 0,0,0): ground, atmosphere, sea / ice / lava,
## clouds, plants and rocks, native wildlife with their habitats, things to examine and
## building sites - all standing on the curved surface. The same code builds every planet;
## what it looks like comes from Biomes (data). Same planet = same world on every visit.

const SITE_COUNT := PlanetDev.SITE_COUNT

var pid := ""
var pl: Dictionary
var biome: Dictionary
var terrain: SphereTerrain
var radius := 110.0
var water_level := -999.0       # above the radius
var gravity := 9.8
var sun_dir := Vector3.UP       # towards the sun
var landing_dir := Vector3.UP   # where the capsule arrives (day side)
var player: Node3D = null
var env: Environment
var sun: DirectionalLight3D
var clouds_mat: ShaderMaterial = null
var sites: Array = []
var animals: Array = []
var objects: Array = []
var habitats: Array = []        # (unused now - animals live all over the planet)
var obstacles: Array = []       # [position, radius] the capsule can't fly through
var animated: Array = []
var rng := RandomNumberGenerator.new()
var t := 0.0
var lightning_wait := 6.0
var flash := 0.0
var bolt: Node3D = null
var bolt_light: OmniLight3D = null
var thunder: AudioStreamPlayer = null
var base_ambient := 0.6
var base_sun := 1.0

# day and night: the sun circles the planet. phase 0 = noon at the landing place.
var day_length := 420.0         # seconds for one full day
var phase := -0.9               # start in the morning
var time_scale := 1.0           # F7 (test) makes time run faster
var sun_b := Vector3.RIGHT      # second axis of the sun's circle
var sun_tilt := 0.35
var viewer := Vector3.ZERO      # camera position (set by the ExploreScreen every frame)
var daylight := 1.0             # 0 = night .. 1 = day where the viewer is
var sun_height := 1.0           # sine of the sun's height above the viewer's horizon
var cur_ambient := 0.6
var cur_sun := 1.0
var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial = null   # (ice / lava only; the sea is `water`)
var water: WaterSurface = null
var terrain_lod: TerrainLOD = null
var rivers_node: Rivers = null
var atmo_mat: ShaderMaterial
var sky_body_mat: ShaderMaterial = null
var sun_disk: MeshInstance3D
var shafts: Array = []
var weather: Weather
var base_fog := 0.005
var cloud_cover := 0.5
var underwater := 0.0           # how deep the camera is under the sea (0 = above water)
var platforms: Array = []       # mushroom caps you can stand on: {pos (top centre), r, bounce, node, squash, base}
const PLANT_SCALE := 0.24       # cartoon version: plants bigger and bolder (original: 0.18)
const COVER_SCALE := 0.2        # (old global ground cover - replaced by the streamed ground layer)
## ground surface per planet: [glint, ice, wet sheen, rock reflectivity]
const SURFACE := {"pebble": [0.25, 0.0, 0.0, 0.45], "glacia": [0.8, 0.75, 0.0, 0.6],
	"mycelia": [0.1, 0.0, 0.45, 0.4], "aquora": [0.3, 0.0, 0.2, 0.5], "verdis": [0.0, 0.0, 0.15, 0.4],
	"ferrum": [0.45, 0.0, 0.0, 0.65], "voltara": [0.6, 0.0, 0.0, 0.75], "solara": [0.9, 0.0, 0.0, 0.55]}
const PLANT_COUNT := 1.6        # more small plants (the streamed ground layer adds the rest)
## Performance switch (F4 in the planet view, for comparing): shadows only nearby, animals
## further away update less often, far particle effects pause
static var optimize := true
var sfx := {}                   # sound name -> AudioStreamPlayer
var aurora_mat: ShaderMaterial = null
var shaft_mat: ShaderMaterial = null
var mist_mat: ShaderMaterial = null


func build(planet_id: String) -> void:
	_b_terrain(planet_id)
	_b_ground()
	_environment()
	_sun()
	_atmosphere()
	_water()
	_b_rivers()
	_clouds()
	_sites()
	_objects()
	_props()
	_showcase()
	_b_valley()
	_wildlife()
	_b_tail()


func _b_terrain(planet_id: String) -> void:
	pid = planet_id
	pl = Game.planet(Game.planet_index(pid))
	biome = Biomes.get_biome(pid)
	radius = float(biome.get("radius", 110.0)) * SphereTerrain.WORLD_SCALE
	water_level = float(biome["water_level"])
	if water_level > -900.0:
		water_level *= SphereTerrain.FEATURE_SCALE
	gravity = float(biome["gravity"])
	rng.seed = hash(pid) + 77
	# the sun is up and a bit to the side of the landing place, so it is day where you arrive
	landing_dir = SolarSystem.LANDING.normalized()
	sun_b = landing_dir.cross(Vector3(0.3, 0, 1)).normalized()
	sun_tilt = SolarSystem.TILT
	day_length = float(biome.get("day_length", 420.0))
	_sun_from_phase()
	terrain = SphereTerrain.new(pid, biome["terrain"], radius, water_level, landing_dir)
	var tconf: Dictionary = biome["terrain"]
	terrain_mat = ExploreShaders.material("terrain", {"detail": SphereTerrain.detail_texture(0.55),
		"rock_color": Color(tconf.get("steep", Color.DIM_GRAY)).lightened(0.15), "rock_mix": 0.55,
		"planet_r": radius, "water_h": water_level, "shore": 1.0 if str(biome["water"]) == "ocean" else 0.0,
		"roughness": 0.75 if pid == "glacia" else 0.92, "bump": 0.25 if pid == "glacia" else 0.4,
		"amb_color": biome["ambient"], "amb_day": float(biome["ambient_energy"]) * 0.75, "amb_night": 0.05, "sun_dir": sun_dir})
	# what the ground is made of: soil matte, rock varied, crystals and ice glinting, wet sheen
	var surf: Array = SURFACE.get(pid, [0.0, 0.0, 0.0, 0.5])
	terrain_mat.set_shader_parameter("glint", surf[0])
	terrain_mat.set_shader_parameter("ice", surf[1])
	terrain_mat.set_shader_parameter("wet_sheen", surf[2])
	terrain_mat.set_shader_parameter("rock_spec", surf[3])


func _b_ground() -> void:
	terrain_lod = TerrainLOD.new()
	terrain_lod.name = "Ground"
	add_child(terrain_lod)
	terrain_lod.setup(terrain, terrain_mat)


func _b_rivers() -> void:
	if not terrain.rivers.is_empty():
		rivers_node = Rivers.new()
		rivers_node.name = "Rivers"
		add_child(rivers_node)
		rivers_node.setup(self)


func _b_valley() -> void:
	if terrain.has_valley:
		_valley()


func _b_tail() -> void:
	# small life around the player: insects, crawlers, drifting motes
	ambient = AmbientLife.new()
	ambient.name = "AmbientLife"
	ambient.setup(self)
	add_child(ambient)
	if biome.has("aurora"):
		_aurora()
	weather = Weather.new()
	add_child(weather)
	weather.setup(self, pid, hash(pid) + 5)
	# the neighbouring planets in the sky, the sun and the turning stars (cheap stand-ins)
	space = SpaceSky.new()
	space.name = "Space"
	add_child(space)
	space.setup(self)
	_update_sun(0.0)


func player_pos() -> Vector3:
	return player.global_position if player else Vector3(0, -10000, 0)


## How fast the player is moving (shy animals only run from fast or very close visitors)
func player_speed() -> float:
	return float(player.call("speed")) if player and player.has_method("speed") else 0.0


# ================================================================== water and sounds
## Open water (deep enough to land on / swim in), not ice or lava
func is_water(p: Vector3) -> bool:
	return str(biome["water"]) == "ocean" and terrain.height(p.normalized()) < water_level - 0.4


func water_radius() -> float:
	return radius + water_level


## Height of the moving sea surface (waves) above the calm sea level at p (0 without a sea)
func wave_at(p: Vector3) -> float:
	return water.wave_height(p) if water != null else 0.0


## A ring wave on the sea starting at p. strength 0.05 .. 2.5; size = width of the rings
## (0.15 a hand or a small animal, 0.4 the explorer, 1 the capsule, 3 a crash)
func add_ripple(p: Vector3, strength: float, size := -1.0) -> void:
	if water == null:
		return
	if size < 0.0:
		size = clampf(strength * 1.2, 0.15, 3.0)
	water.add_ripple(p, strength, size)


## Splash with droplets, spray, ring waves and sound. size: 0.05 a hand .. 0.3 the explorer
## jumping in .. 1 the capsule landing .. 4 a crash. The rings and drops grow with it.
func splash(p: Vector3, size: float) -> void:
	var u := p.normalized()
	Effects.splash(self, u * water_radius(), u, size)
	add_ripple(p, clampf(0.25 + size * 0.5, 0.2, 2.5), clampf(0.2 + size * 0.7, 0.15, 3.5))
	make_noise(p, clampf(size * 2.0, 0.3, 3.0))
	if size > 0.6:
		add_ripple(p, clampf(size * 0.3, 0.2, 1.5), clampf(size * 1.4, 0.3, 4.0))
	play_sfx("splash", clampf(0.2 + size * 0.3, 0.15, 1.0))


func play_sfx(sound: String, volume := 1.0) -> void:
	var path := "res://audio/ambient/%s.wav" % sound
	if not ResourceLoader.exists(path):
		return
	if not sfx.has(sound):
		var pl2 := AudioStreamPlayer.new()
		pl2.stream = load(path)
		add_child(pl2)
		sfx[sound] = pl2
	var player_node: AudioStreamPlayer = sfx[sound]
	player_node.volume_db = linear_to_db(clampf(volume, 0.05, 1.0))
	player_node.pitch_scale = randf_range(0.9, 1.1)
	player_node.play()


# ================================================================== walking helpers
## Distance from the centre of the ground a walker stands on (frozen lakes can be walked on)
func walk_radius(p: Vector3) -> float:
	var g := ground_r(p)
	if str(biome["water"]) == "ice":
		return maxf(g, radius + water_level)
	return g


## Deep water and lava can't be walked into
func walk_blocked(p: Vector3) -> bool:
	var kind := str(biome["water"])
	var h := terrain.height(p.normalized())
	# lava rivers can't be waded through
	if terrain.river_liquid == "lava" and not terrain.rivers.is_empty() and terrain.river_surface(p.normalized()) > -INF:
		return true
	if kind == "ocean":
		return h < water_level - 0.9
	if kind == "lava":
		return h < water_level + 0.25
	return false


## Distance from the centre of whatever is below p: ground or the sea / ice / lava
func floor_radius(p: Vector3) -> float:
	var g := ground_r(p)
	if water_level > -900.0:
		return maxf(g, radius + water_level)
	return g


func ground_point(p: Vector3, lift := 0.0) -> Vector3:
	return terrain.ground_point(p, lift)


## Distance of the ground from the centre exactly as it is DRAWN (the same triangles as the
## visible mesh at its current detail). Everything that walks or lands uses this, so what you
## see is what you stand on - no sinking into the ground or floating above it.
func ground_r(p: Vector3) -> float:
	if terrain_lod:
		var h := terrain_lod.surface_height(p.normalized())
		if h > -INF:
			return radius + h
	return terrain.surface_radius(p)


# ================================================================== solid obstacles
## Obstacles are [position, radius, who] (who: 0 everyone, 1 walkers only (detailed outlines
## of rocks and cliffs), 2 the capsule only (one rough sphere around a big landform)).
## A grid of 6 m cells finds the few near ones quickly.
const OB_CELL := 6.0
const OB_MARGIN := 1.5
var obstacle_grid := {}
var _grid_count := -1


func _okey(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / OB_CELL), floori(p.y / OB_CELL), floori(p.z / OB_CELL))


## The obstacles that can touch something at p (within OB_MARGIN of their edge)
func obstacles_near(p: Vector3) -> Array:
	if _grid_count != obstacles.size():
		_rebuild_obstacle_grid()
	return obstacle_grid.get(_okey(p), [])


func _rebuild_obstacle_grid() -> void:
	obstacle_grid.clear()
	_grid_count = obstacles.size()
	for o: Array in obstacles:
		var c: Vector3 = o[0]
		var r := float(o[1]) + OB_MARGIN
		var lo := _okey(c - Vector3.ONE * r)
		var hi := _okey(c + Vector3.ONE * r)
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					var key := Vector3i(x, y, z)
					if not obstacle_grid.has(key):
						obstacle_grid[key] = []
					var lst: Array = obstacle_grid[key]
					lst.append(o)


## Outline of a solid prop at the height where you walk into it: its triangles between 2 cm and
## 2.4 m above its base are sampled onto a 0.5 m grid; every filled cell becomes a small round
## obstacle (walkers only). Arches stay open underneath, long cliffs are solid along their whole
## length, a boulder is as wide as it looks.
func _footprint(n: Node3D, d: Vector3) -> void:
	var cell := 0.5
	var base := n.position
	var t1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := d.cross(t1)
	var cells := {}
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		# transform of the mesh relative to the planet (the prop is not in the tree yet maybe)
		var xf := mi.transform
		var par := mi.get_parent()
		while par != null and par != self:
			var p3 := par as Node3D
			if p3:
				xf = p3.transform * xf
			par = par.get_parent()
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ids: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var pts: Array = []
			if ids.size() >= 3:
				var tri_n := ids.size() / 3
				var stp := maxi(1, tri_n / 900)
				for ti in range(0, tri_n, stp):
					var a := vs[ids[ti * 3]]
					var b := vs[ids[ti * 3 + 1]]
					var cc := vs[ids[ti * 3 + 2]]
					pts.append_array([a, b, cc, (a + b + cc) / 3.0, (a + b) * 0.5, (b + cc) * 0.5, (cc + a) * 0.5])
			else:
				var stp2 := maxi(1, vs.size() / 4000)
				for vi in range(0, vs.size(), stp2):
					pts.append(vs[vi])
			for q: Vector3 in pts:
				var w := xf * q
				var rel := w - base
				var hgt := rel.dot(d)
				if hgt < 0.02 or hgt > 2.4:
					continue
				cells[Vector2i(roundi(rel.dot(t1) / cell), roundi(rel.dot(t2) / cell))] = true
	for key: Vector2i in cells:
		var cp := base + (t1 * key.x + t2 * key.y) * cell
		var cd := cp.normalized()
		obstacles.append([cd * (radius + terrain.height(cd) + 0.3), cell * 0.75, 1])


## Landing is allowed on fairly flat, dry ground (frozen lakes count as ground)
func can_land(p: Vector3) -> bool:
	if str(biome["water"]) == "ice":
		return terrain.slope(p) < 0.3 or terrain.height(p.normalized()) < water_level
	return terrain.is_dry(p) and terrain.slope(p) < 0.3


func up_at(p: Vector3) -> Vector3:
	return p.normalized()


# ================================================================== sky, light, atmosphere
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = _star_texture()
	sky.sky_material = pm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = biome["ambient"]
	base_ambient = float(biome["ambient_energy"]) * 0.8
	env.ambient_light_energy = base_ambient
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = biome["fog"]
	base_fog = float(biome["fog_density"]) * 0.45
	env.fog_density = base_fog
	env.fog_sky_affect = 0.0
	Cartoon.grade(env)
	we.environment = env
	add_child(we)


func _sun() -> void:
	sun = DirectionalLight3D.new()
	sun.light_color = biome["sun_color"]
	base_sun = float(biome["sun_energy"])
	sun.light_energy = base_sun
	# a light shines along its -Z: point it from the sun towards the planet
	sun.basis = Basis.looking_at(-sun_dir, Vector3.UP if absf(sun_dir.y) < 0.95 else Vector3.RIGHT)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0 if optimize else 120.0
	add_child(sun)
	# the sun itself, bigger the closer the planet is
	var disk := MeshInstance3D.new()
	sun_disk = disk
	disk.mesh = WorldProps.sphere(1.0, 24, 12)
	disk.material_override = _sky_body_mat(Color(biome["sun_color"]).lerp(Color.WHITE, 0.5), true)
	disk.scale = Vector3.ONE * 2000.0 * tan(deg_to_rad(float(biome["sun_size"]) * 0.3))
	disk.position = sun_dir * 2000.0
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disk)
	# (the other planets are now real: SpaceSky draws them at their system positions)
	var body: Array = biome["sky_body"]
	if false and str(body[0]) != "":
		var other := Game.planet(Game.planet_index(str(body[0])))
		var m := MeshInstance3D.new()
		m.mesh = WorldProps.sphere(1.0, 32, 16)
		var mat := _sky_body_mat(other["color"], false)
		mat.set_shader_parameter("sun_dir", sun_dir)
		sky_body_mat = mat
		m.material_override = mat
		var dir: Vector3 = body[1]
		dir = dir.normalized()
		m.position = dir * 1900.0
		m.scale = Vector3.ONE * 1900.0 * float(body[2])
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)


func _sky_body_mat(col: Color, emissive: bool) -> ShaderMaterial:
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec4 col : source_color;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float emissive = 0.0;
varying vec3 wn;
void vertex() { wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	float l = clamp(dot(wn, normalize(sun_dir)), 0.0, 1.0);
	ALBEDO = mix(col.rgb * (0.06 + 0.94 * l), col.rgb * 3.0, emissive);
}
"""
	var m := ShaderMaterial.new()
	m.shader = s
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("emissive", 1.0 if emissive else 0.0)
	return m


static var _stars_tex: ImageTexture = null


func _star_texture() -> ImageTexture:
	if _stars_tex != null:
		return _stars_tex
	var w := 2048
	var h := 1024
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.006, 0.007, 0.016))
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	for i in 26000:
		var x := r.randi_range(0, w - 1)
		var y := int(h * 0.42 + sin(float(x) / w * TAU) * h * 0.12 + r.randfn(0.0, h * 0.05))
		if y >= 0 and y < h:
			img.set_pixel(x, y, img.get_pixel(x, y) + Color(0.025, 0.022, 0.035))
	for i in 4200:
		var x := r.randi_range(0, w - 1)
		var y := r.randi_range(0, h - 1)
		var b := pow(r.randf(), 6.0) * 0.9 + 0.08
		var tint := Color(1.0, 0.92, 0.8) if r.randf() < 0.3 else Color(0.85, 0.9, 1.0)
		img.set_pixel(x, y, tint * b)
	_stars_tex = ImageTexture.create_from_image(img)
	return _stars_tex


func _atmosphere() -> void:
	var thin := pid == "pebble"           # an asteroid has almost no air
	var top := radius + (18.0 if thin else 55.0) * SphereTerrain.FEATURE_SCALE * 1.2
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = top
	sm.height = top * 2.0
	sm.radial_segments = 64
	sm.rings = 32
	m.mesh = sm
	atmo_mat = ExploreShaders.material("atmosphere", {
		"sky_color": biome["sky_top"], "horizon_color": biome["sky_horizon"], "sun_dir": sun_dir,
		"planet_r": radius - 2.0, "atmo_r": top, "density": 0.12 if thin else 1.0})
	m.material_override = atmo_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


# ================================================================== water, ice, lava, clouds
func _water() -> void:
	var kind := str(biome["water"])
	if kind == "":
		return
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	var r := radius + water_level
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 160
	sm.rings = 80
	m.mesh = sm
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match kind:
		"ocean":
			# the sea: fine moving patch around you + simple far sphere (WaterSurface)
			m.queue_free()
			water = WaterSurface.new()
			water.name = "Sea"
			add_child(water)
			water.setup(self)
			return
		"ice":
			# clear ice with dark blue depth below it
			m.material_override = WorldProps.std(Color("#8fd0ff"), 0.02, 0.35, Color("#2f6fd0"), 0.3, 0.7)
			var deep := MeshInstance3D.new()
			var dm := SphereMesh.new()
			dm.radius = r - 1.2
			dm.height = dm.radius * 2.0
			dm.radial_segments = 96
			dm.rings = 48
			deep.mesh = dm
			deep.material_override = WorldProps.std(Color("#0a2a6a"), 0.3, 0.0, Color("#0a3a8a"), 0.4)
			deep.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(deep)
		"lava":
			m.material_override = ExploreShaders.material("lava_sphere")
	add_child(m)


func _clouds() -> void:
	var cfg := {"voltara": [Color(0.16, 0.15, 0.3, 0.95), 0.42, 0.02], "aquora": [Color(1, 1, 1, 0.85), 0.55, 0.006],
		"verdis": [Color(1, 1, 1, 0.8), 0.56, 0.005], "glacia": [Color(0.92, 0.95, 1.0, 0.7), 0.55, 0.008],
		"mycelia": [Color(0.45, 0.32, 0.55, 0.8), 0.5, 0.004], "ferrum": [Color(0.25, 0.12, 0.08, 0.85), 0.5, 0.01]}
	if not cfg.has(pid):
		return
	var c: Array = cfg[pid]
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius + 42.0 * SphereTerrain.FEATURE_SCALE * 1.2
	sm.height = sm.radius * 2.0
	sm.radial_segments = 64
	sm.rings = 32
	m.mesh = sm
	cloud_cover = float(c[1])
	clouds_mat = ExploreShaders.material("cloud_shell", {"color": c[0], "cover": c[1], "speed": c[2], "sun_dir": sun_dir})
	m.material_override = clouds_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)


# ================================================================== placing things on the sphere
func _random_dir() -> Vector3:
	return Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()


## A direction about `dist` metres (along the ground) away from `from`
func _dir_near(from: Vector3, dist: float) -> Vector3:
	var f := from.normalized()
	var b := SphereTerrain.surface_basis(f, rng.randf() * TAU)
	return f.rotated(b.x, dist / radius).normalized()


func _free(p: Vector3, r: float) -> bool:
	for o: Array in obstacles:
		var q: Vector3 = o[0]
		if p.distance_to(q) < r + float(o[1]):
			return false
	return true


## Stands n on the ground in direction d (turned randomly around "up")
func _stand(n: Node3D, d: Vector3, sink := 0.08) -> Vector3:
	var p := ground_point(d, -sink)
	n.basis = SphereTerrain.surface_basis(d, rng.randf() * TAU)
	n.position = p
	return p


func _find_dir(around: Vector3, dist: float, max_slope := 0.25) -> Vector3:
	for i in 60:
		var d := _dir_near(around, dist + i * 0.6)
		if terrain.is_dry(d) and terrain.slope(d) < max_slope and _free(ground_point(d), 4.0):
			return d
	return _dir_near(around, dist)


func _sites() -> void:
	for i in SITE_COUNT:
		var d := _find_dir(landing_dir, 25.0 + i * 22.0, 0.18)
		var s := BuildSite.new()
		add_child(s)
		var p := _stand(s, d, 0.1)
		s.setup(pid, i, pl["accent"])
		sites.append(s)
		obstacles.append([p, 2.4])


func _objects() -> void:
	var ids: Array = biome["objects"].duplicate()
	ids.append("umbra_ruin")
	var k := 0
	for id: String in ids:
		k += 1
		# spread around the whole planet: some near, some on the far side
		var d := _find_dir(landing_dir, radius * (0.35 + 0.9 * k), 0.35)
		var o := FieldObject.new()
		add_child(o)
		var p := _stand(o, d)
		o.setup(id)
		objects.append(o)
		obstacles.append([p, 1.4])


## How many of each prop: the Biomes counts are for 200 x 200 m, scaled to this planet's surface
func _density() -> float:
	# more things on bigger planets (the same density), within limits for load time / memory
	return clampf(4.0 * PI * radius * radius / 40000.0 * 0.55, 1.0, 6.5)


func _props() -> void:
	for entry: Array in biome["props"]:
		_props_entry(entry)


func _props_entry(entry: Array) -> void:
	var dens := _density()
	if true:
		var kind: String = entry[0]
		var count := int(int(entry[1]) * dens)
		var aqua := kind.begins_with("aq_")
		var place: String = "water" if aqua else WorldProps.PLACE.get(kind, "land")
		var big := kind in WorldProps.BIG
		var small := aqua or kind in ["pebbles", "small_mushrooms", "fern", "glow_bulb", "bulb_plant", "coral", "kelp", "sea_fan", "tube_sponge", "reef_rock"]
		if small and kind != "reef_rock":
			count = int(count * PLANT_COUNT)    # small plants: more of them, they are tiny now
		var placed := 0
		var tries := 0
		while placed < count and tries < count * 10:
			tries += 1
			var d := _random_dir()
			var h := terrain.height(d)
			var ok := true
			match place:
				"water":
					ok = h < water_level - 1.0
				"shore":
					ok = h > water_level + 0.2 and h < water_level + 3.5
				_:
					ok = (water_level < -900.0 or h > water_level + 0.3) and terrain.slope(d) < (0.3 if big else 0.42)
			if not ok:
				continue
			# keep the landing place free
			if d.angle_to(landing_dir) * radius < (16.0 if big else 9.0):
				continue
			var gp := ground_point(d)
			if not _free(gp, 5.0 if big else (0.0 if small else 1.2)):
				continue
			WorldProps.palette = _palette(d)
			var n := AquaFlora.make(kind, rng) if aqua else WorldProps.make(kind, rng, pl["accent"])
			add_child(n)
			n.add_to_group("prop")
			_stand(n, d)
			var ps := prop_scale(kind)
			if aqua:
				# sea plants are built in metres; tall ones must stay under the surface
				var room := water_level - h - 0.3
				ps = minf(1.0, room / maxf(float(n.get_meta("h", 1.0)), 0.1))
				if ps < 0.35:
					n.queue_free()
					continue
			n.basis = n.basis.scaled(Vector3.ONE * ps)
			if not n.has_meta("anim"):
				CMesh.merge_deep(n)                       # far fewer draw calls
			_limit_distance(n, (90.0 if kind in ["aq_kelp", "aq_tree"] else 55.0) if small else (150.0 if big else 100.0))
			# solid things: rocks, cliffs, arches, crystals get their real outline for walkers;
			# trees keep their trunk; the capsule uses one rough sphere
			var solid := ps != PLANT_SCALE and not n.has_meta("trunk_r") and not aqua
			if solid and big:
				_footprint(n, d)
				obstacles.append([gp + d * 3.0 * ps, 3.0 * ps, 2])
			elif solid:
				# rocks and crystals: one round obstacle as wide as the rock really is
				var box := AABB()
				var first := true
				for c in n.find_children("*", "MeshInstance3D", true, false):
					var mi := c as MeshInstance3D
					if mi and mi.mesh:
						var bb := mi.transform * mi.get_aabb()
						box = bb if first else box.merge(bb)
						first = false
				var rr := 0.6 * ps
				var cpos := gp
				if not first:
					rr = maxf(box.size.x, box.size.z) * 0.5 * ps * 0.85
					var cw := n.transform * box.get_center()
					cpos = cw.normalized() * (radius + terrain.height(cw.normalized()) + 0.2)
				obstacles.append([cpos, maxf(rr, 0.08)])
			elif big:
				obstacles.append([gp + d * 3.0 * ps, maxf(3.0 * ps, (float(n.get_meta("trunk_r", 0.0)) + 0.6) * ps)])
			elif not small:
				obstacles.append([gp, 0.6 * ps])
			if n.has_meta("anim"):
				animated.append(n)
			if not big and feed_points.size() < 900:
				feed_points.append(gp)
			placed += 1


## How big a prop is compared to before: plants and animals half, small rocks a bit smaller,
## crystals a bit smaller, big landforms (cliffs, caves, arches, glaciers, spires) unchanged
func prop_scale(kind: String) -> float:
	if kind in ["cliff", "cave", "rock_arch", "ice_arch", "glacier", "basalt", "metal_spire", "rock_spire", "light_pillar", "geyser", "floater_rock"]:
		return SphereTerrain.FEATURE_SCALE          # landforms grow with the landscape
	if kind in ["boulder", "snow_rock", "beach_rock", "jungle_rock", "dark_rock", "glass_rock", "debris", "ore_deposit", "mineral", "reef_rock"]:
		return 0.3
	if kind in ["ice_spike", "crystal_field", "glow_ice", "sun_crystal", "charged_crystal"]:
		return 0.3
	return PLANT_SCALE


## The capsule's cannon hit the ground at p: a real crater is blasted out (on a steep rock
## wall it cuts a deep cavity into the rock). The ground's height function changes, then only
## the few terrain chunks and ground-detail patches it touches are rebuilt. Plants and rocks in
## the blast are destroyed, things around it settle on the new ground. Kept for the session and
## in the save game.
func blast(p: Vector3, power: float) -> Array:
	var d := p.normalized()
	var sl := terrain.slope(d)
	var r := (2.0 + power * 1.5) * randf_range(0.85, 1.15)
	var depth := r * (0.5 if sl < 0.45 else 0.95)
	var c := terrain.add_crater(d, r, depth)
	make_noise(p, 3.0)
	if terrain.deform.size() > MAX_CRATERS:
		# the oldest crater fills in (keeps the ground fast to compute)
		terrain.deform.pop_front()
		terrain._crater_t1.pop_front()
		terrain._crater_t2.pop_front()
	terrain_lod.refresh(d, r * 1.8)
	if ground_layer:
		ground_layer.refresh(d, r * 1.8)
	if water:
		water.refresh_depth()
	# destroyed plants / rocks, the rest settles on the new ground
	for n in get_tree().get_nodes_in_group("prop"):
		var n3 := n as Node3D
		if n3 == null:
			continue
		var pd := n3.position.distance_to(p)
		if pd < r * 1.15:
			n3.queue_free()
		elif pd < r * 2.0:
			var nd := n3.position.normalized()
			n3.position = nd * (radius + terrain.height(nd) - 0.05)
	var keep: Array = []
	for o: Array in obstacles:
		var op: Vector3 = o[0]
		if op.distance_to(p) > r * 1.15:
			keep.append(o)
	obstacles = keep
	Game.save_craters(pid, terrain.deform)
	return c


const MAX_CRATERS := 80


## The prop colours of the zone at d (Biomes "palettes")
func _palette(d: Vector3) -> Dictionary:
	var pals: Array = biome.get("palettes", [])
	if pals.is_empty():
		return {}
	return pals[mini(terrain.zone_at(d), pals.size() - 1)]


## Far away things are not drawn (faster on laptops)
func _limit_distance(n: Node, dist: float) -> void:
	var gi := n as GeometryInstance3D
	if gi:
		gi.visibility_range_end = dist
		gi.visibility_range_end_margin = 10.0
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF     # fades out, no popping
		if dist <= 80.0:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF          # small things: no shadow
	for c in n.get_children():
		_limit_distance(c, dist)


# ================================================================== wildlife over the whole planet
## Every group of animals has a home somewhere on the sphere, chosen by what its species
## needs (water, shore, height, slope, plants, colour zone). Only groups near the player
## exist as nodes - they appear when you come within SPAWN_DIST and are removed beyond
## DESPAWN_DIST (except an animal you are holding).
const SPAWN_DIST := 70.0
const DESPAWN_DIST := 85.0
const MAX_ALIVE := 170             # never more animals at once than this (performance)
## The last loud noise: [position, time, loudness 0.3 .. 3] - animals react to it
var last_noise: Array = []


func make_noise(p: Vector3, loud: float) -> void:
	last_noise = [p, t, loud]
var population: Array = []      # {id, home, n, seed, nodes: Array}
var species_ids: Array = []     # every species that lives on this planet
var feed_points: Array = []     # plants, crusts and shore spots animals walk to (eat / drink)
var stream_t := 0.0


func _suits(sp: Dictionary, d: Vector3) -> float:
	var h := terrain.height(d)
	var amp := float(biome["terrain"].get("amp", 8.0))
	var loc := str(sp.get("genes", {}).get("loc", ""))
	var plan := str(sp["plan"])
	var zone := str(sp.get("zone", "any"))
	var ok := false
	if plan == "swimmer" or plan == "jelly" or loc == "swim":
		ok = h < water_level - 2.5
	elif bool(sp.get("sideways", false)) or zone == "shore":
		ok = water_level > -900.0 and h > water_level - 0.2 and h < water_level + 2.0
	elif plan in ["flyer", "floater", "gasbag", "skimmer"] or loc in ["wing", "hover"]:
		ok = terrain.is_dry(d) and h > water_level + 0.3
	else:
		ok = terrain.is_dry(d) and h > water_level + 0.3 and terrain.slope(d) < (0.6 if loc == "climb" else 0.32)
	if not ok:
		return 0.0
	var w := 1.0
	match zone:
		"high": w = 3.0 if h > amp * 0.25 else 0.1
		"low": w = 3.0 if h < 0.0 else 0.15
		"forest": w = 3.0 if not _free(ground_point(d), 12.0) else 0.2
	if sp.has("home_zone"):
		w *= 3.0 if terrain.zone_at(d) == int(sp["home_zone"]) else 0.35
	return w


func _add_group(id: String, sp: Dictionary, d: Vector3) -> void:
	var n := 1
	if sp.has("swarm"):
		n = int(sp["swarm"])
	elif bool(sp.get("predator", false)) or str(sp.get("genes", {}).get("loc", "")) == "sessile":
		n = 1
	elif float(sp["size"]) < 0.7:
		n = rng.randi_range(1, 4)
	else:
		n = rng.randi_range(1, 2)
	population.append({"id": id, "home": ground_point(d), "n": n, "seed": rng.randi(), "nodes": []})


func _wildlife() -> void:
	var list := Biomes.planet_species(pid)
	# drinking places at the water's edge
	if water_level > -900.0 and str(biome["water"]) == "ocean":
		for i in 3000:
			var d := _random_dir()
			var h := terrain.height(d)
			if h > water_level - 0.1 and h < water_level + 0.6:
				feed_points.append(ground_point(d))
	var area := 4.0 * PI * radius * radius
	# the same number of animals per area on the bigger planets (they are only built near you)
	var total := clampi(int(area / 260.0), 300, 1600)
	var weights: Array = []
	for entry: Array in list:
		var id: String = entry[0]
		species_ids.append(id)
		var sp := Biomes.species(id)
		weights.append(float(entry[1]) * (0.25 if bool(sp.get("rare", false)) else 1.0))
	# 1. at least one group of every species (rare ones far from the landing place)
	for entry: Array in list:
		var id: String = entry[0]
		var sp := Biomes.species(id)
		var rare := bool(sp.get("rare", false))
		var best := Vector3.ZERO
		for tries in 300:
			var d := _random_dir()
			if rare and d.angle_to(landing_dir) < 1.4:
				continue
			if not _free(ground_point(d), 2.0):
				continue
			if _suits(sp, d) >= 1.0 or (tries > 200 and _suits(sp, d) > 0.0):
				best = d
				break
		if best != Vector3.ZERO:
			_add_group(id, sp, best)
	# 2. the rest: random places all over the sphere, a species that likes the spot
	var attempts := 0
	while population.size() < total and attempts < total * 12:
		attempts += 1
		var d := _random_dir()
		if d.angle_to(landing_dir) * radius < 10.0 or not _free(ground_point(d), 2.0):
			continue
		var cands: Array = []
		var sum := 0.0
		for i in list.size():
			var id: String = list[i][0]
			var sp := Biomes.species(id)
			var wgt := float(weights[i]) * _suits(sp, d)
			if bool(sp.get("rare", false)) and d.angle_to(landing_dir) < 1.0:
				wgt = 0.0
			if wgt > 0.0:
				cands.append([id, wgt])
				sum += wgt
		if cands.is_empty():
			continue
		var r := rng.randf() * sum
		for c: Array in cands:
			r -= float(c[1])
			if r <= 0.0:
				_add_group(str(c[0]), Biomes.species(str(c[0])), d)
				break
	_stream(9999)


## Creates the animals of groups that came close, removes far ones. At most `budget` new
## groups per call so walking around never stutters.
func _stream(budget: int) -> void:
	var pp := player.global_position if player and player.is_inside_tree() else landing_dir * radius
	for g: Dictionary in population:
		var home: Vector3 = g["home"]
		var dist := home.distance_to(pp)
		var nodes: Array = g["nodes"]
		if nodes.is_empty() and dist < SPAWN_DIST and budget > 0 and animals.size() < MAX_ALIVE:
			budget -= 1
			_spawn_group(g)
		elif not nodes.is_empty() and dist > DESPAWN_DIST:
			# keep the group while you hold one of them or one of them is still close to you
			var keep := false
			for w in nodes:
				if is_instance_valid(w) and (w.held or w.position.distance_to(pp) < DESPAWN_DIST):
					keep = true
			if keep:
				continue
			for w in nodes:
				if is_instance_valid(w):
					animals.erase(w)
					w.queue_free()
			g["nodes"] = []


func _spawn_group(g: Dictionary) -> void:
	var id: String = g["id"]
	var sp := Biomes.species(id)
	var centre: Vector3 = g["home"]
	var local := RandomNumberGenerator.new()
	local.seed = int(g["seed"])
	var leader: Wildlife = null
	var nodes: Array = []
	for i in int(g["n"]):
		var home := centre
		if i > 0:
			var u := centre.normalized()
			var b := SphereTerrain.surface_basis(u, local.randf() * TAU)
			var dist := local.randf_range(0.6, 2.0) if sp.has("swarm") else local.randf_range(2.0, 6.0)
			home = ground_point(u.rotated(b.x, dist / radius))
			if not _free(home, 0.8):
				home = centre
		var w := Wildlife.new()
		add_child(w)
		w.setup(id, self, home, int(g["seed"]) + i * 31)
		if sp.has("swarm"):
			if leader == null:
				leader = w
			else:
				w.leader = leader
				w.swarm_off = (home - leader.home).normalized() * local.randf_range(0.4, 1.5) if (home - leader.home).length() > 0.01 else Vector3(0.5, 0, 0)
		animals.append(w)
		nodes.append(w)
	g["nodes"] = nodes


## The nearest food / water spot within `r` metres of p (Vector3.ZERO if none)
func feed_near(p: Vector3, r: float) -> Vector3:
	var best := Vector3.ZERO
	var bd := r * r
	for f: Vector3 in feed_points:
		var dd := f.distance_squared_to(p)
		if dd < bd:
			bd = dd
			best = f
	return best


## Curtains of coloured light high in the sky (seen at night)
func _aurora() -> void:
	var cols: Array = biome["aurora"]
	aurora_mat = ExploreShaders.material("aurora", {"col_a": cols[0], "col_b": cols[1], "strength": 0.0})
	for band in 3:
		var axis := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var ref := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
		var segs := 160
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		var r0 := radius + 48.0 + band * 6.0
		var hgt := 22.0 + band * 4.0
		for i in segs + 1:
			var a := TAU * i / segs
			var d := ref.rotated(axis, a)
			d = (d + axis * sin(a * 3.0 + band) * 0.12).normalized()
			verts.append(d * r0)
			verts.append(d * (r0 + hgt))
			uvs.append(Vector2(float(i) / segs * 4.0, 1.0))
			uvs.append(Vector2(float(i) / segs * 4.0, 0.0))
		for i in segs:
			var k := i * 2
			idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 1, k + 3, k + 2]))
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = aurora_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


# ================================================================== day and night
func _sun_from_phase() -> void:
	var a := sun_b.cross(landing_dir).normalized()
	sun_dir = ((landing_dir * cos(phase) + sun_b * sin(phase)) * cos(sun_tilt) + a * sin(sun_tilt)).normalized()


## Sets the time of day so that the sun stands `deg` degrees above the landing place's horizon
## (morning side if rising, evening side otherwise). Used by the test tour.
func set_sun_height(deg: float, rising: bool) -> void:
	var e := sin(deg_to_rad(deg)) / cos(sun_tilt)
	var p := acos(clampf(e, -1.0, 1.0))
	phase = -p if rising else p
	_update_sun(0.0)


func time_name() -> String:
	var e := sun_height
	if e > 0.25:
		return "Day"
	if e > -0.12:
		return "Sunrise" if phase < 0.0 else "Sunset"
	return "Night"


## Moves the sun and changes the light of the whole world (sun, ambient light, fog, sky, water)
## for the place where the viewer is.
func _update_sun(delta: float) -> void:
	phase = wrapf(phase + TAU * delta / day_length * time_scale, -PI, PI)
	_sun_from_phase()
	sun.basis = Basis.looking_at(-sun_dir, Vector3.UP if absf(sun_dir.y) < 0.95 else Vector3.RIGHT)
	sun_disk.position = sun_dir * 2000.0
	var v := viewer if viewer.length() > 1.0 else landing_dir * radius
	sun_height = v.normalized().dot(sun_dir)
	var high := clampf((v.length() - radius - 50.0) / 110.0, 0.0, 1.0)     # seen from high above: whole planet
	daylight = smoothstep(-0.14, 0.22, sun_height)
	var direct := smoothstep(-0.05, 0.1, sun_height)
	var warm := smoothstep(0.02, 0.35, sun_height)
	cur_sun = base_sun * lerpf(direct, 1.0, high)
	sun.light_color = Color(1.0, 0.55, 0.3).lerp(Color(biome["sun_color"]), lerpf(warm, 1.0, high))
	cur_ambient = lerpf(0.09, base_ambient, lerpf(daylight, 1.0, high * 0.6))
	env.ambient_light_color = Color(0.35, 0.42, 0.65).lerp(Color(biome["ambient"]), daylight)
	env.fog_light_color = Color(biome["fog"]) * lerpf(0.12, 1.0, daylight)
	# weather: clouds hide the sun, fog thickens, wind moves plants and water
	if weather:
		cur_sun *= 1.0 - weather.dark * 0.65 * (1.0 - high)
		cur_ambient *= 1.0 - weather.dark * 0.3
		env.fog_density = base_fog * weather.fog
		env.fog_light_color = env.fog_light_color.darkened(weather.dark * 0.35)
		ExploreShaders.set_wind(weather.wind)
		ExploreShaders.set_surface(weather.wet, weather.snow)
		if clouds_mat:
			clouds_mat.set_shader_parameter("cover", cloud_cover - weather.dark * 0.3)
		if water:
			water.set_param("wave", weather.waves)
			water.set_param("chop", weather.chop)
			water.set_param("rain", weather.rain)
	# under the sea: blue-green, thick fog, less light the deeper you are
	underwater = 0.0
	if str(biome["water"]) == "ocean" and v.length() > 1.0:
		var depth := water_radius() - v.length()
		if depth > 0.02 and terrain.surface_radius(v) < water_radius() - 0.05:
			underwater = depth
			var dk := clampf(depth / 25.0, 0.0, 1.0)
			env.fog_density = lerpf(0.045, 0.11, dk)
			env.fog_light_color = Color(0.1, 0.42, 0.52).lerp(Color(0.01, 0.07, 0.16), dk) * lerpf(0.2, 1.0, daylight)
			env.ambient_light_color = Color(0.35, 0.7, 0.85)
			cur_sun *= lerpf(0.6, 0.12, dk)
			cur_ambient *= lerpf(0.95, 0.45, dk)
			# water swallows red light first: sunlight turns blue-green and dims with depth
			sun.light_color = sun.light_color.lerp(Color(0.35, 0.78, 0.85), clampf(0.45 + dk, 0.0, 0.9))
	if terrain_lod and viewer.length() > 1.0:
		terrain_lod.update_viewer(viewer)
	env.ambient_light_energy = cur_ambient
	sun.light_energy = cur_sun
	terrain_mat.set_shader_parameter("sun_dir", sun_dir)
	atmo_mat.set_shader_parameter("sun_dir", sun_dir)
	if clouds_mat:
		clouds_mat.set_shader_parameter("sun_dir", sun_dir)
	if sky_body_mat:
		sky_body_mat.set_shader_parameter("sun_dir", sun_dir)
	if water:
		water.set_param("day", daylight)
		water.set_param("sun_dir", sun_dir)
	if mist_mat:
		mist_mat.set_shader_parameter("light", daylight)
	if aurora_mat:
		aurora_mat.set_shader_parameter("strength", (1.0 - daylight) * (1.0 - (weather.dark if weather else 0.0) * 0.7))
	Xeno.set_night(1.0 - daylight)
	if shaft_mat:
		shaft_mat.set_shader_parameter("strength", 0.13 * smoothstep(0.15, 0.55, sun_height))
		_aim_shafts(v)


# ================================================================== representative area (visual upgrade)
## Detailed vegetation, ground cover, mist and light shafts. Planets with a "cover" entry in
## Biomes get it (first: Verdis). Dense around the landing place, lighter elsewhere.
func _showcase() -> void:
	if not biome.has("cover"):
		return
	var tint: Color = biome.get("leaf_tint", Color.WHITE)
	var land_ok := func(d: Vector3) -> bool:
		return terrain.is_dry(d) and terrain.slope(d) < 0.45 and d.angle_to(landing_dir) * radius > 4.0
	var shore_ok := func(d: Vector3) -> bool:
		var h := terrain.height(d)
		return h > water_level + 0.1 and h < water_level + 2.5 and terrain.slope(d) < 0.5
	var water_ok := func(d: Vector3) -> bool:
		var h := terrain.height(d)
		return h < water_level - 0.8 and h > water_level - 7.0
	var any_ok := func(d: Vector3) -> bool:
		return terrain.slope(d) < 0.7 and d.angle_to(landing_dir) * radius > 3.0
	if biome.has("ground"):
		# streamed, GPU-instanced ground life (grass, plants, stones ...) around the player
		ground_layer = GroundLayer.new()
		ground_layer.name = "GroundLayer"
		ground_layer.setup(self, biome["ground"])
		add_child(ground_layer)
	for entry: Array in ([] if biome.has("ground") else biome["cover"]):
		var kind: String = entry[0]
		var col: Color = entry[3] if entry.size() > 3 else tint
		var variants := 3
		for vi in variants:
			var cv: Array = Flora.cover(kind, rng, col)
			var mesh: Mesh = cv[0]
			var where: String = cv[1]
			var sz: Vector2 = cv[2] * COVER_SCALE
			var ok: Callable = land_ok
			if where == "shore":
				ok = shore_ok
			elif where == "water":
				ok = water_ok
			elif where == "any":
				ok = any_ok
			# natural patches: dense in fertile flat places, sparse on rocky slopes (pebbles: the
			# other way round), never in an even pattern
			var rocky := kind in ["pebbles", "gravel", "cinders", "glass_pebble", "scrap"]
			ok = _patchy.bind(ok, rocky)
			var vd := 70.0 if kind in ["grass", "frost_grass", "storm_grass", "gravel", "cinders", "glass_pebble", "lichen"] else 120.0
			# dense around the landing place, spread over the whole planet as well
			var tint_fn := Callable(self, "_cover_tint")
			add_child(Flora.scatter(self, mesh, landing_dir, 80.0, int(int(entry[1]) * 1.4) / variants, sz.x, sz.y, ok, rng, vd * 0.8, tint_fn))
			add_child(Flora.scatter(self, mesh, -landing_dir, radius * 2.6, int(int(entry[2]) * 1.3) / variants, sz.x, sz.y, ok, rng, vd * 0.8, tint_fn))
	# extra detailed trees around the landing place: a dense patch of forest
	for i in int(biome.get("showcase_trees", 0)):
		var d := _find_dir(landing_dir, rng.randf_range(22.0, 70.0), 0.3)
		var gp := ground_point(d)
		if not _free(gp, 4.0):
			continue
		var tr: Array = Flora.jungle_tree(rng, tint)
		var n: Node3D = tr[0]
		add_child(n)
		_stand(n, d, 0.15)
		n.basis = n.basis.scaled(Vector3.ONE * PLANT_SCALE)
		_limit_distance(n, 190.0)
		obstacles.append([gp + d * 1.5, (float(tr[1]) + 0.6) * PLANT_SCALE])
	# light shafts under the canopy and low mist
	shaft_mat = ExploreShaders.material("shaft", {"color": Color(1.0, 0.95, 0.75), "strength": 0.13})
	for i in int(biome.get("shafts", 0)):
		var d := _dir_near(landing_dir, rng.randf_range(14.0, 60.0))
		var sh := Flora.light_shaft(shaft_mat, 26.0, rng.randf_range(2.0, 4.0))
		add_child(sh)
		shafts.append([sh, ground_point(d)])
	var mist_col: Color = biome.get("mist", Color(0.8, 0.9, 0.8, 0.0))
	if mist_col.a > 0.0:
		mist_mat = ExploreShaders.material("mist", {"tex": Particles.dot_texture(), "color": mist_col})
		for i in 34:
			var d := _dir_near(landing_dir, rng.randf_range(6.0, 75.0))
			var m := Flora.mist_patch(mist_mat, rng.randf_range(9.0, 16.0))
			m.position = ground_point(d, rng.randf_range(0.6, 1.8))
			add_child(m)


var _patch_noise: FastNoiseLite = null
var ground_layer: GroundLayer = null
var space: SpaceSky = null
var ambient: AmbientLife = null


## Keeps or skips a ground-cover spot so that cover grows in natural patches
func _patchy(d: Vector3, ok: Callable, rocky: bool) -> bool:
	if not bool(ok.call(d)):
		return false
	if _patch_noise == null:
		_patch_noise = FastNoiseLite.new()
		_patch_noise.seed = hash(pid) + 99
		_patch_noise.frequency = 0.06
		_patch_noise.fractal_octaves = 3
	var n := _patch_noise.get_noise_3dv(d * radius) * 0.5 + 0.5
	var sl := clampf(terrain.slope(d) * 2.5, 0.0, 1.0)
	var keep := n * (1.0 - sl * 0.7) if not rocky else (1.0 - n) * 0.6 + sl * 0.6
	return rng.randf() < clampf(keep * 1.3 - 0.15, 0.03, 1.0)


## Ground cover takes on the colours of its zone (Mycelia caps, Glacia ice ...)
func _cover_tint(d: Vector3) -> Color:
	var p := _palette(d)
	for key: String in ["caps", "ice"]:
		if p.has(key):
			var arr: Array = p[key]
			var c: Color = arr[0]
			return c.lightened(0.45)
	return Color.WHITE


## Light shafts lean along the sun and turn towards the camera
func _aim_shafts(v: Vector3) -> void:
	for s: Array in shafts:
		var mi: MeshInstance3D = s[0]
		var g: Vector3 = s[1]
		var y := sun_dir
		if sun_height < 0.0:
			mi.visible = false
			continue
		mi.visible = true
		var c := g + y * 13.0
		var z := v - c
		z -= y * z.dot(y)
		if z.length() < 0.01:
			continue
		z = z.normalized()
		mi.basis = Basis(y.cross(z).normalized(), y, z)
		mi.position = c


# ================================================================== the mushroom valley (Mycelia)
## Giant mushrooms grow out of the deep valley; their caps are springy platforms.
## Three crossings (easy, medium, hard), springs on the valley floor to climb back out,
## hanging roots, glowing fungi on the walls and mist at the bottom.
func _valley() -> void:
	var half := terrain.v_width * 0.5
	# many small decorations are merged into a few big meshes (cheap to draw)
	var deco := Node3D.new()
	add_child(deco)
	# [along, [[offset from the middle, height of the cap top above (+) / below (-) the rim, bounce, cap radius]...]]
	var crossings := [
		# the first and last caps stand right at the cliff edges, a little above the rim (step or
		# hop onto them), the ones in between are higher and closer together than before
		[0.0, [[-7.4, 0.3, 7.5, 1.9], [-3.2, -2.0, 8.5, 1.7], [1.2, -1.5, 8.5, 1.6], [7.4, 0.3, 7.0, 1.9]]],
		[-55.0, [[-7.4, 0.2, 8.0, 1.6], [-3.8, -2.5, 9.0, 1.4], [-0.2, -1.8, 9.0, 1.3], [3.4, -2.6, 9.0, 1.3], [7.4, 0.2, 7.5, 1.6]]],
		[55.0, [[-7.5, -0.5, 9.0, 1.3], [-2.5, -4.0, 10.0, 1.15], [2.6, -2.5, 9.5, 1.15], [7.5, -0.4, 8.0, 1.3]]],
	]
	# (positions and bounces checked with the explorer's running speed (Shift), air control and this
	# planet's gravity - walking is not enough for some hops)
	var pal: Array = biome.get("palettes", [{}])
	for cr: Array in crossings:
		var along := float(cr[0])
		var mid := terrain.valley_center(along)
		var rim := (terrain.surface_radius(terrain.valley_dir(mid - half - 2.5, along)) + terrain.surface_radius(terrain.valley_dir(mid + half + 2.5, along))) * 0.5
		for m: Array in cr[1]:
			var d := terrain.valley_dir(mid + float(m[0]), along)
			_giant_mushroom(d, rim + float(m[1]), float(m[3]), float(m[2]), pal[rng.randi() % pal.size()])
	# springs on the floor near both walls: they throw you back up to the rim
	for along2: float in [-90.0, -30.0, 30.0, 90.0]:
		var mid2 := terrain.valley_center(along2)
		for sx: float in [-1.0, 1.0]:
			var d2 := terrain.valley_dir(mid2 + sx * (half - 2.8), along2)
			var floor_r := terrain.surface_radius(d2)
			var rim2 := terrain.surface_radius(terrain.valley_dir(mid2 + sx * (half + 2.5), along2))
			var need := sqrt(2.0 * gravity * (rim2 - floor_r + 2.0)) + 1.0
			_giant_mushroom(d2, floor_r + 1.3, 1.2, need, {"caps": [Color("#ffb13b")]}, true)
	# landmarks seen from far away: two towering glowing mushrooms at the ends of the valley,
	# glowing fungi along both rims, and a trail of glowing mushrooms from the landing place
	for along6: float in [-terrain.v_len * 0.5 + 8.0, terrain.v_len * 0.5 - 8.0]:
		var mid6 := terrain.valley_center(along6)
		var db := terrain.valley_dir(mid6 + half + 9.0, along6)
		_giant_mushroom(db, terrain.surface_radius(db) + 30.0, 7.0, 0.0, {"caps": [Color("#ff4fa8")]}, true)
		var beam := MeshInstance3D.new()
		beam.mesh = CMesh.cyl(1.2, 2.5, 90.0, 12)
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.albedo_color = Color(1.0, 0.45, 0.8, 0.18)
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = bm
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
		beam.position = db * (terrain.surface_radius(db) + 45.0)
		beam.basis = SphereTerrain.surface_basis(db, 0.0)
	var rim_glow := WorldProps.std(Color("#5a2a6a"), 0.6, 0.0, Color("#ff6fb7"), 2.0)
	var rim_glow2 := WorldProps.std(Color("#1a5a5a"), 0.6, 0.0, Color("#4ff2ff"), 2.0)
	var al := -terrain.v_len * 0.5 + 4.0
	while al < terrain.v_len * 0.5 - 4.0:
		var midr := terrain.valley_center(al)
		for sx4: float in [-1.0, 1.0]:
			var dr := terrain.valley_dir(midr + sx4 * (half + 1.8 + rng.randf() * 1.5), al)
			var gm := MeshInstance3D.new()
			gm.mesh = CMesh.tube([Vector3(0, 0, 0), Vector3(0, 0.25, 0), Vector3(0, 0.38, 0)], [Vector2(0.55, 0.55), Vector2(0.42, 0.42), Vector2(0.05, 0.05)], 10)
			gm.material_override = rim_glow if sx4 < 0.0 else rim_glow2
			deco.add_child(gm)
			gm.position = terrain.ground_point(dr, 0.6)
			gm.basis = SphereTerrain.surface_basis(dr, rng.randf() * TAU)
			var st := MeshInstance3D.new()
			st.mesh = CMesh.cyl(0.08, 0.12, 0.6, 6)
			st.material_override = WorldProps.std(Color("#e8dcc8"), 0.8)
			deco.add_child(st)
			st.transform = gm.transform * Transform3D(Basis(), Vector3(0, -0.3, 0))
		al += 6.0
	var trail_to := terrain.valley_dir(terrain.valley_center(0.0) - half - 4.0, 0.0)
	var steps := int(landing_dir.angle_to(trail_to) * radius / 7.0)
	for i5 in range(2, steps):
		var dtr := landing_dir.slerp(trail_to, float(i5) / steps)
		var tm := MeshInstance3D.new()
		tm.mesh = CMesh.tube([Vector3(0, 0, 0), Vector3(0, 0.12, 0), Vector3(0, 0.2, 0)], [Vector2(0.3, 0.3), Vector2(0.24, 0.24), Vector2(0.03, 0.03)], 10)
		tm.material_override = rim_glow2
		deco.add_child(tm)
		tm.position = terrain.ground_point(dtr, 0.25)
		tm.basis = SphereTerrain.surface_basis(dtr, 0.0)
	# roots hanging down the walls, glowing fungi on them, mist on the floor
	var root_mat := WorldProps.std(Color("#4a3a2a"), 0.9)
	for i in 150:
		var along3 := rng.randf_range(-terrain.v_len * 0.5 + 3.0, terrain.v_len * 0.5 - 3.0)
		var sx2 := -1.0 if rng.randf() < 0.5 else 1.0
		var mid3 := terrain.valley_center(along3)
		var top := terrain.valley_dir(mid3 + sx2 * (half + 0.3), along3)
		var tp := terrain.ground_point(top, -0.2)
		var u := top
		var lng := rng.randf_range(5.0, 20.0)
		var inward := (terrain.valley_dir(mid3, along3) * tp.length() - tp).normalized()
		var mi := MeshInstance3D.new()
		mi.mesh = CMesh.limb(tp, tp - u * lng, rng.randf_range(0.05, 0.14), 0.02, inward * rng.randf_range(0.4, 1.2), 0.1, 6)
		mi.material_override = root_mat
		deco.add_child(mi)
	for j in 110:
		var along4 := rng.randf_range(-terrain.v_len * 0.5 + 3.0, terrain.v_len * 0.5 - 3.0)
		var sx3 := -1.0 if rng.randf() < 0.5 else 1.0
		var mid4 := terrain.valley_center(along4)
		var dw := terrain.valley_dir(mid4 + sx3 * (half - 0.4), along4)
		var r0 := terrain.surface_radius(terrain.valley_dir(mid4, along4))
		var rr := terrain.surface_radius(terrain.valley_dir(mid4 + sx3 * (half + 1.5), along4))
		var hgt := r0 + rng.randf_range(1.0, rr - r0 - 1.0)
		var sh := MeshInstance3D.new()
		var col: Color = [Color("#7dffcf"), Color("#ff6fb7"), Color("#9f8bff"), Color("#ffc84a")][rng.randi() % 4]
		sh.mesh = CMesh.cyl(rng.randf_range(0.3, 0.7), 0.05, 0.12, 12)
		sh.material_override = WorldProps.std(col.darkened(0.3), 0.6, 0.0, col, 1.2)
		deco.add_child(sh)
		sh.position = dw * hgt
		sh.basis = SphereTerrain.surface_basis(dw, rng.randf() * TAU)
	CMesh.merge_deep(deco)
	if mist_mat == null:
		mist_mat = ExploreShaders.material("mist", {"tex": Particles.dot_texture(), "color": Color(0.75, 0.55, 0.9, 0.22)})
	for k in 50:
		var along5 := rng.randf_range(-terrain.v_len * 0.5 + 3.0, terrain.v_len * 0.5 - 3.0)
		var dm := terrain.valley_dir(terrain.valley_center(along5), along5)
		var m2 := Flora.mist_patch(mist_mat, rng.randf_range(6.0, 11.0))
		m2.position = terrain.ground_point(dm, rng.randf_range(0.8, 3.5))
		add_child(m2)


## A giant mushroom: stem from the ground at d up to a springy cap (top at radius top_r)
func _giant_mushroom(d: Vector3, top_r: float, cap_r: float, bounce: float, pal: Dictionary, spring := false) -> void:
	var base_r := terrain.surface_radius(d) - 0.3
	var u := d.normalized()
	var root := Node3D.new()
	add_child(root)
	root.position = u * base_r
	root.basis = SphereTerrain.surface_basis(u, rng.randf() * TAU)
	var h := maxf(0.6, top_r - base_r - cap_r * 0.35)
	var caps: Array = pal.get("caps", [Color("#c46fd8")])
	var cap_col: Color = caps[rng.randi() % caps.size()]
	var stem_mat := WorldProps.std(Color("#e8dcc8").lerp(cap_col, 0.15), 0.8)
	var sway := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * h * 0.06
	var stem := MeshInstance3D.new()
	stem.mesh = CMesh.tube(CMesh.curve(Vector3.ZERO, Vector3(0, h, 0), sway, 8), CMesh.taper(8, cap_r * 0.3, cap_r * 0.18, 0.15), 12, 0.0, 0.12, h)
	stem.material_override = stem_mat
	root.add_child(stem)
	# a frilly ring on the stem and roots at the foot
	var ring := MeshInstance3D.new()
	ring.mesh = CMesh.cyl(cap_r * 0.45, cap_r * 0.22, 0.12, 14)
	ring.material_override = stem_mat
	ring.position = Vector3(0, h * 0.72, 0) + sway * 0.5
	root.add_child(ring)
	for i in 5:
		var a := TAU * i / 5.0
		var rt := MeshInstance3D.new()
		rt.mesh = CMesh.limb(Vector3(0, 0.4, 0), Vector3(cos(a) * cap_r * 0.7, -0.2, sin(a) * cap_r * 0.7), cap_r * 0.1, 0.03, Vector3(0, 0.2, 0), 0.0, 6)
		rt.material_override = stem_mat
		root.add_child(rt)
	# the cap (its own node: it squashes and springs back)
	var cap := Node3D.new()
	cap.position = Vector3(0, h, 0) + sway
	root.add_child(cap)
	var dome := MeshInstance3D.new()
	dome.mesh = CMesh.tube([Vector3(0, 0.0, 0), Vector3(0, cap_r * 0.18, 0), Vector3(0, cap_r * 0.32, 0), Vector3(0, cap_r * 0.38, 0)],
		[Vector2(cap_r, cap_r), Vector2(cap_r * 0.92, cap_r * 0.92), Vector2(cap_r * 0.6, cap_r * 0.6), Vector2(cap_r * 0.05, cap_r * 0.05)], 20, 0.0, 0.06, cap_r)
	dome.material_override = WorldProps.std(cap_col, 0.55, 0.0, cap_col if spring else Color.BLACK, 0.4)
	cap.add_child(dome)
	var gills := MeshInstance3D.new()
	gills.mesh = CMesh.cyl(cap_r * 0.98, cap_r * 0.3, 0.1, 20)
	var glow: Color = [Color("#7dffcf"), Color("#4ff2ff"), Color("#ffc84a")][rng.randi() % 3]
	gills.material_override = WorldProps.std(glow.darkened(0.4), 0.6, 0.0, glow, 1.1)
	gills.position = Vector3(0, -0.04, 0)
	cap.add_child(gills)
	for i2 in rng.randi_range(5, 9):
		var a2 := rng.randf() * TAU
		var rr := sqrt(rng.randf()) * cap_r * 0.75
		var spot := MeshInstance3D.new()
		spot.mesh = CMesh.ball(cap_r * rng.randf_range(0.06, 0.12), 8, 5)
		spot.material_override = WorldProps.std(Color("#fff4e0"), 0.5)
		var yy := cap_r * 0.38 * (1.0 - pow(rr / cap_r, 2.0)) + 0.01
		spot.position = Vector3(cos(a2) * rr, yy, sin(a2) * rr)
		spot.scale = Vector3(1, 0.4, 1)
		cap.add_child(spot)
	_limit_distance(root, 170.0)
	var top := root.position + root.basis * (cap.position + Vector3(0, cap_r * 0.36, 0))
	platforms.append({"pos": top, "r": cap_r * 0.92, "bounce": bounce, "node": cap, "t": 9.0, "hit": 0.0})


## The cap the player landed on squashes, springs back and puffs out spores
func mushroom_bounce(i: int, landing_speed: float) -> void:
	var pf: Dictionary = platforms[i]
	pf["t"] = 0.0
	pf["hit"] = clampf(landing_speed / 8.0, 0.35, 1.0)
	var p: Vector3 = pf["pos"]
	var sp := CPUParticles3D.new()
	sp.one_shot = true
	sp.explosiveness = 0.9
	sp.amount = 40
	sp.lifetime = 1.6
	sp.local_coords = false
	sp.direction = p.normalized()
	sp.spread = 70.0
	sp.initial_velocity_min = 1.5
	sp.initial_velocity_max = 4.0
	sp.gravity = p.normalized() * 0.3
	sp.damping_min = 1.5
	sp.damping_max = 2.5
	sp.mesh = Particles.soft_quad(0.08)
	sp.material_override = Particles.material(Color(0.6, 1.0, 0.85, 0.9), true)
	add_child(sp)
	sp.position = p
	sp.emitting = true
	get_tree().create_timer(2.0).timeout.connect(sp.queue_free)
	play_sfx("thud", 0.5 + float(pf["hit"]) * 0.4)
	play_sfx("chirp", 0.35)


func _animate_platforms(delta: float) -> void:
	var stand := -1
	if player is Explorer:
		stand = (player as Explorer).platform
	for i in platforms.size():
		var pf: Dictionary = platforms[i]
		var cap: Node3D = pf["node"]
		pf["t"] = float(pf["t"]) + delta
		var tt := float(pf["t"])
		# squash: flatter and wider, then a few damped wobbles
		var k := float(pf["hit"]) * exp(-tt * 5.0) * cos(tt * 16.0)
		if i == stand:
			k += 0.08                                 # bends a little under your weight
		if absf(k) < 0.002 and i != stand:
			if cap.scale != Vector3.ONE:
				cap.scale = Vector3.ONE
			continue
		cap.scale = Vector3(1.0 + k * 0.25, 1.0 - k * 0.45, 1.0 + k * 0.25)


# ================================================================== animation, lightning
## F4: switch the optimisations on / off (to compare speed)
func set_optimize(on: bool) -> void:
	optimize = on
	sun.directional_shadow_max_distance = 45.0 if on else 120.0


func _process(delta: float) -> void:
	t += delta
	_update_sun(delta)
	if not platforms.is_empty():
		_animate_platforms(delta)
	if player:
		ExploreShaders.set_player(player.global_position if player is Explorer else Vector3(0, -9999, 0))
	stream_t -= delta
	if stream_t <= 0.0:
		stream_t = 0.25
		_stream(2)
	for n: Node3D in animated:
		var a: Dictionary = n.get_meta("anim")
		match str(a["type"]):
			"float":
				var r: Node3D = a["node"]
				r.rotation.y += delta * float(a["speed"]) * 0.4
				r.rotation.x += delta * float(a["speed"]) * 0.15
				r.position.y = float(a["base"]) + sin(t * float(a["speed"]) + n.position.x) * 0.35
			"geyser":
				var p: CPUParticles3D = a["particles"]
				var c := fmod(t + float(a["phase"]), float(a["period"]))
				p.emitting = c < 3.0 and (not optimize or n.position.distance_squared_to(viewer) < 90.0 * 90.0)
				p.gravity = -n.position.normalized() * 3.0
	if weather and weather.lightning > 0.0:
		_lightning(delta)
	elif flash > 0.0:
		flash = 0.0
		if bolt:
			bolt.queue_free()
			bolt = null


func _lightning(delta: float) -> void:
	lightning_wait -= delta
	if lightning_wait <= 0.0:
		lightning_wait = rng.randf_range(5.0, 12.0) / maxf(weather.lightning, 0.3)
		_strike()
	flash = maxf(0.0, flash - delta * 2.5)
	var f := flash * (0.6 + 0.4 * sin(t * 60.0))
	env.ambient_light_energy = cur_ambient + f * 2.5
	sun.light_energy = cur_sun + f * 1.5
	if clouds_mat:
		clouds_mat.set_shader_parameter("flash", f)
	if bolt and flash < 0.55:
		bolt.queue_free()
		bolt = null
	if bolt_light:
		bolt_light.light_energy = f * 8.0


func _strike() -> void:
	var pp := player_pos()
	var d := _dir_near(pp, rng.randf_range(30.0, 90.0))
	var ground := ground_point(d)
	var u := d
	if bolt:
		bolt.queue_free()
	bolt = Node3D.new()
	add_child(bolt)
	var mat := WorldProps.std(Color("#e8e8ff"), 1.0, 0.0, Color("#b8c0ff"), 6.0)
	var b := SphereTerrain.surface_basis(u, 0.0)
	var p := ground + u * 42.0
	var segs := 12
	for i in segs:
		var q := p.lerp(ground, 1.0 / (segs - i))
		if i < segs - 1:
			q += b.x * rng.randf_range(-4, 4) + b.z * rng.randf_range(-4, 4)
		_bolt_segment(p, q, mat, 0.25)
		if rng.randf() < 0.3:
			_bolt_segment(q, q - u * rng.randf_range(4, 10) + b.x * rng.randf_range(-8, 8), mat, 0.12)
		p = q
	if bolt_light == null:
		bolt_light = OmniLight3D.new()
		bolt_light.omni_range = 70.0
		bolt_light.light_color = Color("#c8ccff")
		add_child(bolt_light)
	bolt_light.position = ground + u * 15.0
	flash = 1.0
	if thunder:
		var dist := pp.distance_to(ground)
		get_tree().create_timer(dist / 340.0 * 2.0, false).timeout.connect(func():
			if is_instance_valid(thunder):
				thunder.volume_db = linear_to_db(clampf(1.4 - dist / 120.0, 0.25, 1.0))
				thunder.play())


func _bolt_segment(a: Vector3, b: Vector3, mat: Material, r: float) -> void:
	var seg := a.distance_to(b)
	if seg < 0.01:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = WorldProps.cyl(r, r, seg, 5)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.add_child(mi)
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.001:
		mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
