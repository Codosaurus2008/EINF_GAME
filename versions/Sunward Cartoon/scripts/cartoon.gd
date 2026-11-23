class_name Cartoon
extends RefCounted
## Sunward Cartoon: the deliberately cartoon-looking version of the game.
##  - colours: much more saturated and brighter (vivid)
##  - shading: toon (hard light bands instead of soft gradients), toon highlights, a bright rim
##    light on every edge, flat colours instead of fine noise textures
##  - the picture: extra saturation and contrast for the whole screen (Environment adjustments)
##  - animals: flat 2D cartoon drawings standing in the 3D world (CartoonCritter)

const ON := true
const SAT := 1.55            # colour saturation x this
const VAL := 1.12            # brightness x this


static func vivid(c: Color) -> Color:
	var h := c.h
	var s := clampf(c.s * SAT + 0.06, 0.0, 1.0)
	var v := clampf(c.v * VAL + 0.03, 0.0, 1.0)
	return Color.from_hsv(h, s, v, c.a)


## Turns a standard material into a cartoon one (same object, returned for chaining)
static func toon(m: StandardMaterial3D) -> StandardMaterial3D:
	if m == null:
		return m
	m.albedo_color = vivid(m.albedo_color)
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = clampf(m.roughness, 0.25, 1.0)
	m.metallic = minf(m.metallic, 0.25)
	m.rim_enabled = true
	m.rim = 0.55
	m.rim_tint = 0.35
	# flat colour: no fine grain textures (cartoon surfaces are clean)
	if m.albedo_texture is NoiseTexture2D:
		m.albedo_texture = null
	m.normal_enabled = false
	if m.emission_enabled:
		m.emission = vivid(m.emission)
	return m


## Screen-wide colour boost (on the planet view's Environment)
static func grade(env: Environment) -> void:
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.35
	env.adjustment_contrast = 1.12
	env.adjustment_brightness = 1.04
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
