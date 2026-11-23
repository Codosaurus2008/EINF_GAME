class_name Weather
extends Node
## Changing weather on a planet. Every planet has its own kinds of weather (Weather.KINDS);
## one is active and after a while the next one fades in smoothly (about 15 seconds).
## Weather sets: wind (plants, particles, waves), rain / snow / dust ... (particles around the
## player), fog, cloud cover and darkness, wave height and lightning. SphereWorld reads the
## current values every frame (wind, fog, dark, waves, chop, rain, lightning).

## name, wind 0..2, fog factor, dark 0..1 (clouds hide the sun), waves, chop, rain on water,
## lightning chance, particles {kind: amount 0..1}, how long (seconds)
const KINDS := {
	"pebble": [
		{"name": "Calm", "wind": 0.2, "fog": 1.0, "dark": 0.0, "particles": {"dust": 0.4}},
		{"name": "Dust drift", "wind": 1.2, "fog": 2.6, "dark": 0.15, "particles": {"dust": 1.0, "debris": 0.8}},
	],
	"glacia": [
		{"name": "Clear and cold", "wind": 0.3, "fog": 0.8, "dark": 0.0, "particles": {"snow": 0.15}},
		{"name": "Snowfall", "wind": 0.6, "fog": 1.8, "dark": 0.3, "particles": {"snow": 0.8}},
		{"name": "Blizzard", "wind": 1.9, "fog": 4.5, "dark": 0.55, "particles": {"snow": 1.0, "drift": 1.0}},
	],
	"mycelia": [
		{"name": "Damp", "wind": 0.2, "fog": 1.2, "dark": 0.1, "damp": 0.5, "particles": {"spores": 0.5}},
		{"name": "Thick fog", "wind": 0.1, "fog": 3.8, "dark": 0.25, "damp": 0.7, "particles": {"spores": 0.7}},
		{"name": "Spore bloom", "wind": 0.5, "fog": 1.6, "dark": 0.1, "particles": {"spores": 1.0, "bloom": 1.0}},
	],
	"aquora": [
		{"name": "Sunny", "wind": 0.4, "fog": 0.8, "dark": 0.0, "waves": 0.3, "chop": 0.0, "particles": {"spray": 0.3}},
		{"name": "Rain", "wind": 0.9, "fog": 1.8, "dark": 0.4, "waves": 0.5, "chop": 0.3, "rain": 1.0, "particles": {"rain": 0.8, "spray": 0.5}},
		{"name": "Storm", "wind": 1.9, "fog": 2.6, "dark": 0.7, "waves": 0.9, "chop": 1.0, "rain": 1.0, "lightning": 0.5, "particles": {"rain": 1.0, "spray": 1.0}},
		{"name": "Sea mist", "wind": 0.2, "fog": 3.2, "dark": 0.15, "damp": 0.35, "waves": 0.2, "chop": 0.0, "particles": {"spray": 0.2}},
	],
	"verdis": [
		{"name": "Sunny", "wind": 0.4, "fog": 0.8, "dark": 0.0, "particles": {"pollen": 0.8}},
		{"name": "Rain", "wind": 0.9, "fog": 1.8, "dark": 0.45, "particles": {"rain": 0.9}},
		{"name": "Jungle mist", "wind": 0.2, "fog": 2.8, "dark": 0.2, "damp": 0.5, "particles": {"pollen": 0.4}},
	],
	"ferrum": [
		{"name": "Smoky", "wind": 0.3, "fog": 1.0, "dark": 0.1, "particles": {"embers": 0.6}},
		{"name": "Ash fall", "wind": 0.8, "fog": 2.6, "dark": 0.45, "particles": {"ash": 1.0, "embers": 0.4}},
		{"name": "Ember storm", "wind": 1.6, "fog": 1.8, "dark": 0.35, "particles": {"embers": 1.0, "ash": 0.5}},
	],
	"voltara": [
		{"name": "Thunderstorm", "wind": 1.2, "fog": 1.4, "dark": 0.55, "lightning": 1.0, "particles": {"rain": 1.0}},
		{"name": "Heavy storm", "wind": 2.0, "fog": 2.4, "dark": 0.75, "lightning": 1.8, "particles": {"rain": 1.0, "debris": 0.6}},
		{"name": "Charged calm", "wind": 0.4, "fog": 1.0, "dark": 0.35, "lightning": 0.3, "particles": {"rain": 0.2, "sparks": 1.0}},
	],
	"solara": [
		{"name": "Blazing", "wind": 0.3, "fog": 1.0, "dark": 0.0, "haze": 1.0, "particles": {"sparkle": 0.8}},
		{"name": "Heat wind", "wind": 1.4, "fog": 1.8, "dark": 0.05, "haze": 1.6, "particles": {"sparkle": 0.5, "dust": 1.0}},
	],
}

var world: Node
var kinds: Array = []
var index := 0
var next_index := 0
var blend := 1.0               # 1 = fully the current weather
var timer := 60.0
var rng := RandomNumberGenerator.new()

# current (blended) values
var wind := 0.3
var wind_dir := Vector3.RIGHT
var fog := 1.0
var dark := 0.0
var waves := 0.3
var chop := 0.0
var rain := 0.0
var lightning := 0.0
var haze := 1.0
var amounts := {}              # particle kind -> 0..1
var wet := 0.0                 # ground and plants get wet in rain, dry slowly afterwards
var snow := 0.0                # snow settles on the ground and plants, melts slowly


func setup(w: Node, planet_id: String, seed_value: int) -> void:
	world = w
	kinds = KINDS.get(planet_id, KINDS["pebble"])
	rng.seed = seed_value
	index = 0
	next_index = 0
	timer = rng.randf_range(70.0, 120.0)
	snow = 0.35 if planet_id == "glacia" else 0.0
	wind_dir = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
	_apply(1.0)


func current_name() -> String:
	if blend < 1.0:
		return "%s -> %s" % [kinds[index]["name"], kinds[next_index]["name"]]
	return str(kinds[index]["name"])


## Jump to a weather (test tour / F8)
func set_kind(i: int) -> void:
	index = i % kinds.size()
	next_index = index
	blend = 1.0
	timer = rng.randf_range(70.0, 140.0)
	_apply(1.0)


func next_kind() -> void:
	set_kind(index + 1)


func _process(delta: float) -> void:
	if kinds.is_empty():
		return
	timer -= delta
	if blend >= 1.0 and timer <= 0.0 and kinds.size() > 1:
		next_index = (index + 1 + rng.randi() % (kinds.size() - 1)) % kinds.size()
		blend = 0.0
	if blend < 1.0:
		blend = minf(1.0, blend + delta / 15.0)
		if blend >= 1.0:
			index = next_index
			timer = rng.randf_range(70.0, 140.0)
	# the wind slowly turns
	wind_dir = wind_dir.rotated(Vector3(0.3, 1.0, 0.2).normalized(), delta * 0.01)
	_apply(blend)
	var want_wet := clampf(float(amounts.get("rain", 0.0)) + _damp(), 0.0, 1.0)
	wet = move_toward(wet, want_wet, delta * (0.08 if want_wet > wet else 0.02))
	var want_snow := clampf(float(amounts.get("snow", 0.0)) * 1.1 + float(amounts.get("drift", 0.0)) * 0.3, 0.0, 1.0)
	snow = move_toward(snow, want_snow, delta * (0.03 if want_snow > snow else 0.01))


func _damp() -> float:
	var a: Dictionary = kinds[index]
	var n: Dictionary = kinds[next_index]
	return lerpf(_val(a, "damp", 0.0), _val(n, "damp", 0.0), smoothstep(0.0, 1.0, blend) if blend < 1.0 else 0.0)


func _val(d: Dictionary, k: String, def: float) -> float:
	return float(d.get(k, def))


func _apply(b: float) -> void:
	var a: Dictionary = kinds[index]
	var n: Dictionary = kinds[next_index] if b < 1.0 else a
	var k := smoothstep(0.0, 1.0, b) if b < 1.0 else 0.0
	if b >= 1.0:
		n = a
	wind = lerpf(_val(a, "wind", 0.3), _val(n, "wind", 0.3), k)
	fog = lerpf(_val(a, "fog", 1.0), _val(n, "fog", 1.0), k)
	dark = lerpf(_val(a, "dark", 0.0), _val(n, "dark", 0.0), k)
	waves = lerpf(_val(a, "waves", 0.3), _val(n, "waves", 0.3), k)
	chop = lerpf(_val(a, "chop", 0.0), _val(n, "chop", 0.0), k)
	rain = lerpf(_val(a, "rain", 0.0), _val(n, "rain", 0.0), k)
	lightning = lerpf(_val(a, "lightning", 0.0), _val(n, "lightning", 0.0), k)
	haze = lerpf(_val(a, "haze", 1.0), _val(n, "haze", 1.0), k)
	amounts = {}
	var pa: Dictionary = a["particles"]
	var pn: Dictionary = n["particles"]
	for key in pa:
		amounts[key] = float(pa[key]) * (1.0 - k)
	for key in pn:
		amounts[key] = float(amounts.get(key, 0.0)) + float(pn[key]) * k
