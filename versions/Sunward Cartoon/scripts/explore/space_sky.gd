class_name SpaceSky
extends Node3D
## What you see of the rest of the solar system from the planet you are on (sky only - you
## can't fly there directly; travel goes through the ship / the planet list):
##  - every other planet as a light, cheap stand-in (one sphere with a baked picture of its real
##    ground, sea, lava, clouds, a lit day side and a dark night side, an air glow on the rim),
##    at its real system position
##  - the sun (at its real position and size)
##  - the stars, turning together with everything else as the planet turns
## Far stand-ins are drawn at most CAP metres away (moved closer and made smaller by the same
## factor: they look exactly the same, but stay inside the camera's range).
## The pictures are baked once per game session from each planet's real terrain (a few rows per
## frame, nothing stalls); until then the planet's colour is used.

const CAP := 4200.0
const TEX_W := 128
const TEX_H := 64
static var TEX := {}             # planet n -> ImageTexture (baked pictures, kept for the session)
static var _bake_queue: Array = []
static var _baking := {}          # {n, terrain, img, row}

var world: SphereWorld
var active := 0
var bodies := {}                  # n -> MeshInstance3D
var sky_mat: ShaderMaterial
var checked := false

const CLOUDS := {"voltara": [Color(0.16, 0.15, 0.3), 0.6], "aquora": [Color(1, 1, 1), 0.35],
	"verdis": [Color(1, 1, 1), 0.3], "glacia": [Color(0.92, 0.95, 1.0), 0.35],
	"mycelia": [Color(0.45, 0.32, 0.55), 0.35], "ferrum": [Color(0.25, 0.12, 0.08), 0.4]}


func setup(w: SphereWorld) -> void:
	world = w
	active = Game.planet_index(w.pid)
	var shader := Shader.new()
	shader.code = BODY_SHADER
	for n in SolarSystem.ORBITS.size():
		if n == active:
			continue
		var pid: String = Game.planet(n)["id"]
		var b := Biomes.get_biome(pid)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 64
		sm.rings = 32
		mi.mesh = sm
		var m := ShaderMaterial.new()
		m.shader = shader
		var pc: Color = Game.planet(n)["color"]
		m.set_shader_parameter("base_col", pc)
		var cl: Array = CLOUDS.get(pid, [Color.WHITE, 0.0])
		m.set_shader_parameter("cloud", Color(cl[0], float(cl[1])))
		m.set_shader_parameter("atmo", Color(b.get("sky_horizon", Color(0.6, 0.7, 1.0)), 0.0 if pid == "pebble" else 0.9))
		m.set_shader_parameter("seed", float(n) * 7.3)
		if TEX.has(n):
			m.set_shader_parameter("tex", TEX[n])
			m.set_shader_parameter("has_tex", 1.0)
		elif not (n in _bake_queue):
			_bake_queue.append(n)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		bodies[n] = mi
	# this planet's own picture too (you will see it from the next planet)
	if not TEX.has(active) and not (active in _bake_queue):
		_bake_queue.append(active)
	# the stars: a sky that turns with the system
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = Shader.new()
	sky_mat.shader.code = SKY_SHADER
	sky_mat.set_shader_parameter("stars", w._star_texture())
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	w.env.sky = sky
	# the old decorative sun: now placed at the real sun's position and size
	update_now()


func update_now() -> void:
	var q := SolarSystem.frame(world)
	var me := SolarSystem.position(active)
	var cam := world.viewer if world.viewer.length() > 1.0 else world.landing_dir * world.radius
	if not checked:
		checked = true
		var err := (q * (-me).normalized() - world.sun_dir).length()
		print("SPACE frame check %s: sun direction error %.6f (should be ~0)" % [world.pid, err])
	for n: int in bodies:
		var mi: MeshInstance3D = bodies[n]
		var p := q * (SolarSystem.position(n) - me)
		var r := SolarSystem.radius(n)
		var rot := q * SolarSystem.frame_for(n, SolarSystem.saved_phase(n)).inverse()
		var rel := p - cam
		var d := rel.length()
		var k := 1.0
		if d > CAP:
			k = CAP / d
		mi.transform = Transform3D(rot.scaled(Vector3.ONE * r * k), cam + rel * k)
		var m := mi.material_override as ShaderMaterial
		# light comes from the sun (system centre)
		m.set_shader_parameter("sun_dir", (q * (-SolarSystem.position(n))).normalized())
	# the sun
	var sp := q * (-me)
	var srel := sp - cam
	var sd := srel.length()
	var sk := minf(1.0, CAP / sd)
	world.sun_disk.position = cam + srel * sk
	world.sun_disk.scale = Vector3.ONE * SolarSystem.SUN_RADIUS * sk
	# stars: the sky turns with the planet (system direction of every view direction)
	sky_mat.set_shader_parameter("rot", q.inverse())


func _process(_delta: float) -> void:
	if world == null:
		return
	update_now()
	_bake_step()


# ================================================================== baked planet pictures
func _bake_step() -> void:
	if _baking.is_empty():
		if _bake_queue.is_empty():
			return
		var n: int = _bake_queue.pop_front()
		if TEX.has(n):
			return
		var pid: String = Game.planet(n)["id"]
		var b := Biomes.get_biome(pid)
		var rad := float(b.get("radius", 110.0)) * SphereTerrain.WORLD_SCALE
		var wl := float(b["water_level"])
		if wl > -900.0:
			wl *= SphereTerrain.FEATURE_SCALE
		SphereTerrain.skip_rivers = true
		var t := SphereTerrain.new(pid, b["terrain"], rad, wl, SolarSystem.LANDING.normalized())
		SphereTerrain.skip_rivers = false
		_baking = {"n": n, "terrain": t, "img": Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8), "row": 0, "water": str(b["water"]), "wl": wl}
		return
	var t2: SphereTerrain = _baking["terrain"]
	var img: Image = _baking["img"]
	var kind: String = _baking["water"]
	var wl2 := float(_baking["wl"])
	var amp := float(t2.conf.get("amp", 8.0))
	for r in 2:
		var y := int(_baking["row"])
		if y >= TEX_H:
			break
		var lat := (0.5 - (y + 0.5) / TEX_H) * PI
		for x in TEX_W:
			var lon := ((x + 0.5) / TEX_W - 0.5) * TAU
			var d := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			var h := t2.height(d)
			var c := t2.vertex_color(d, h, 0.0)
			var glow := 0.0
			if wl2 > -900.0 and h < wl2:
				match kind:
					"ocean":
						c = Color("#1f8f98").lerp(Color("#0a2f5c"), clampf((wl2 - h) / 8.0, 0.0, 1.0))
					"lava":
						c = Color(1.0, 0.45, 0.1)
						glow = 1.0
					"ice":
						c = Color("#9fd4f5")
			else:
				c = c * (0.85 + 0.3 * clampf(h / maxf(amp * 2.0, 1.0), -0.5, 1.0))
			img.set_pixel(x, y, Color(c.r, c.g, c.b, glow))
		_baking["row"] = y + 1
	if int(_baking["row"]) >= TEX_H:
		var n2 := int(_baking["n"])
		TEX[n2] = ImageTexture.create_from_image(img)
		_baking = {}
		if bodies.has(n2):
			var m := (bodies[n2] as MeshInstance3D).material_override as ShaderMaterial
			m.set_shader_parameter("tex", TEX[n2])
			m.set_shader_parameter("has_tex", 1.0)


const BODY_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform sampler2D tex : source_color, filter_linear, repeat_enable;
uniform float has_tex = 0.0;
uniform vec4 base_col : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec4 atmo : source_color = vec4(0.6, 0.7, 1.0, 0.8);
uniform vec4 cloud : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float seed = 0.0;
varying vec3 ln;
varying vec3 wn;
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() {
	ln = normalize(VERTEX);
	wn = normalize((MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz);
}
void fragment() {
	vec2 uv = vec2(atan(ln.z, ln.x) / 6.2831853 + 0.5, 0.5 - asin(clamp(ln.y, -1.0, 1.0)) / 3.14159265);
	vec4 t = has_tex > 0.5 ? texture(tex, uv) : vec4(base_col.rgb * (0.8 + 0.4 * vnoise(ln * 6.0 + seed)), 0.0);
	float l = dot(wn, normalize(sun_dir));
	float lit = smoothstep(-0.12, 0.2, l);
	vec3 col = t.rgb * (0.03 + 0.97 * clamp(l * 1.1, 0.0, 1.0));
	// clouds drifting slowly
	float cl = smoothstep(0.55, 0.75, vnoise(ln * 5.0 + vec3(TIME * 0.01, 0.0, seed)) * 0.65 + vnoise(ln * 13.0 + seed) * 0.35);
	col = mix(col, cloud.rgb * (0.04 + 0.96 * lit), cl * cloud.a);
	// lava glows also at night
	col += vec3(1.0, 0.45, 0.12) * t.a * (0.6 + 0.4 * (1.0 - lit));
	// air glow on the rim of the day side
	vec3 vn = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	float rim = pow(1.0 - clamp(dot(vn, VIEW), 0.0, 1.0), 3.0);
	col += atmo.rgb * rim * atmo.a * (0.08 + 0.92 * lit);
	ALBEDO = col;
}
"""

const SKY_SHADER := """
shader_type sky;
uniform sampler2D stars : source_color, filter_linear, repeat_enable;
uniform mat3 rot = mat3(1.0);
void sky() {
	vec3 d = normalize(rot * EYEDIR);
	vec2 uv = vec2(atan(d.x, -d.z) / 6.2831853 + 0.5, acos(clamp(d.y, -1.0, 1.0)) / 3.14159265);
	COLOR = texture(stars, uv).rgb;
}
"""
