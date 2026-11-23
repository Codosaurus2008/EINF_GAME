class_name SphereTerrain
extends RefCounted
## The ground of a round planet: a height for every direction from the planet's centre,
## built as a "cube sphere" mesh (6 curved grids). The planet centre is at (0, 0, 0).
## Same planet id = same planet every visit.

const GRID := 144                # (old single mesh - the TerrainLOD chunks are used now)
## Planet size (final values, applied once): planets are 1.8x the radius in Biomes and the
## landscape features (hills, mountains, terraces, craters, lake levels) 1.5x larger, so the tiny
## explorer stands in a vast landscape with a far horizon.
const WORLD_SCALE := 1.8
const FEATURE_SCALE := 1.5
## Craters made by the capsule's cannon, per planet, for the whole session (and in the save):
## [direction, radius, depth, height at the impact, seed]
static var DEFORM := {}
## true while far-away stand-in pictures are made (no rivers needed for those)
static var skip_rivers := false

var pid := ""
var conf: Dictionary
var radius := 110.0
var water := -999.0              # water / ice / lava height above the radius (-999 = none)
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var low := FastNoiseLite.new()
var zone_noise := FastNoiseLite.new()
var mount_mask := FastNoiseLite.new()    # where the mountain ranges are
var mount := FastNoiseLite.new()         # sharp ridges and valleys of the ranges
var micro := FastNoiseLite.new()         # small bumps and hollows (a few metres)
var groove := FastNoiseLite.new()        # erosion grooves / cracks
var rough := 0.2                         # how bumpy and eroded the ground is (per planet)
const ROUGH := {"pebble": 0.5, "glacia": 0.26, "mycelia": 0.34, "aquora": 0.28, "verdis": 0.3,
	"ferrum": 0.58, "voltara": 0.46, "solara": 0.38}
var outcrop := FastNoiseLite.new()       # where bare rock breaks through the ground
var medium := FastNoiseLite.new()        # rolling unevenness (10 - 20 m)
var coast := FastNoiseLite.new()         # ragged shorelines: coves, points, rocky edges
var zones: Array = []            # colour zones: [[low, high, steep], ...] (first = the planet's main colours)
var craters: Array = []          # [direction, radius in metres, depth]
var flat_dir := Vector3.UP       # landing place (kept flat)
# a deep, narrow valley (Mycelia): centre, across and along directions, size
var has_valley := false
var v_c := Vector3.UP
var v_a := Vector3.RIGHT
var v_b := Vector3.FORWARD
var v_len := 110.0
var v_width := 13.0
var v_depth := 20.0
var dune_axis := Vector3.RIGHT


func _init(planet_id: String, terrain_conf: Dictionary, planet_radius: float, water_level: float, landing_dir: Vector3) -> void:
	pid = planet_id
	# landscape features are scaled once here (heights up, frequencies down = bigger shapes)
	conf = terrain_conf.duplicate(true)
	var fs := FEATURE_SCALE
	for key: String in ["amp", "mountains", "terraces"]:
		if conf.has(key):
			conf[key] = float(conf[key]) * fs
	conf["freq"] = float(conf.get("freq", 0.015)) / fs
	radius = planet_radius
	water = water_level
	flat_dir = landing_dir.normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pid)
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED if bool(conf.get("ridged", false)) else FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.frequency = float(conf.get("freq", 0.015))
	noise2.seed = rng.randi()
	noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise2.frequency = 0.05
	low.seed = rng.randi()
	low.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	low.frequency = 0.011 / FEATURE_SCALE
	low.fractal_octaves = 2
	dune_axis = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	mount_mask.seed = rng.randi()
	mount_mask.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mount_mask.frequency = 0.0075 / FEATURE_SCALE
	mount_mask.fractal_octaves = 2
	mount.seed = rng.randi()
	mount.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mount.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	mount.fractal_octaves = 4
	mount.frequency = 0.028 / FEATURE_SCALE
	zone_noise.seed = rng.randi()
	zone_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	zone_noise.frequency = 0.016 / FEATURE_SCALE
	zone_noise.fractal_octaves = 2
	rough = float(conf.get("rough", ROUGH.get(planet_id, 0.2)))
	micro.seed = rng.randi()
	micro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	micro.frequency = 0.28
	micro.fractal_octaves = 2
	groove.seed = rng.randi()
	groove.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	groove.frequency = 0.05
	groove.fractal_octaves = 2
	outcrop.seed = rng.randi()
	outcrop.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	outcrop.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	outcrop.fractal_octaves = 3
	outcrop.frequency = 0.045
	medium.seed = rng.randi()
	medium.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	medium.fractal_octaves = 2
	medium.frequency = 0.07
	coast.seed = rng.randi()
	coast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	coast.fractal_octaves = 3
	coast.frequency = 0.09
	if conf.has("valley"):
		var vc: Dictionary = conf["valley"]
		has_valley = true
		v_len = float(vc.get("len", 110.0))
		v_width = float(vc.get("width", 13.0))
		v_depth = float(vc.get("depth", 20.0))
		var axis := flat_dir.cross(Vector3(0.3, 0.1, 1.0).normalized()).normalized()
		v_c = flat_dir.rotated(axis, float(vc.get("dist", 48.0)) / radius).normalized()
		var away := v_c - flat_dir
		v_a = (away - v_c * away.dot(v_c)).normalized()
		v_b = v_c.cross(v_a).normalized()
	if conf.has("rainforest"):
		# one region of very dense, misty rainforest (Verdis), not far from the landing place
		var rf: Dictionary = conf["rainforest"]
		var rax := flat_dir.cross(Vector3(-0.6, 0.2, 0.8).normalized()).normalized()
		rain_c = flat_dir.rotated(rax, float(rf.get("dist", 100.0)) / radius).normalized()
		rain_r = float(rf.get("r", 80.0))
	zones = [[conf.get("low", Color.GRAY), conf.get("high", Color.WHITE), conf.get("steep", Color.DIM_GRAY)]]
	for z in conf.get("zones", []):
		zones.append(z)
	for i in int(conf.get("craters", 0)) * 2:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		if d.angle_to(flat_dir) * radius < 30.0:
			continue
		var r := rng.randf_range(5.0, 18.0) * FEATURE_SCALE
		craters.append([d, r, r * rng.randf_range(0.25, 0.4)])
	# cannon craters made earlier in this session / saved
	if not DEFORM.has(pid):
		DEFORM[pid] = Game.craters(pid)
	deform = DEFORM[pid]
	DEFORM[pid] = deform
	for c: Array in deform:
		_crater_axes(c)
	# rivers (traced downhill over the finished landscape, then carved into it)
	_trace_rivers()


## Height of the ground above the planet radius in a direction (metres)
func height(dir: Vector3) -> float:
	var p := dir * radius
	var amp := float(conf.get("amp", 8.0))
	var h := noise.get_noise_3dv(p) * amp
	if bool(conf.get("ridged", false)):
		h = (noise.get_noise_3dv(p) * 0.5 + 0.1) * amp * 1.4
	if bool(conf.get("island", false)):
		# continents and islands in the ocean
		h = low.get_noise_3dv(p) * 22.0 * FEATURE_SCALE - 1.5 + noise.get_noise_3dv(p) * amp * 0.45
	if bool(conf.get("dunes", false)):
		h += sin(dir.dot(dune_axis) * radius * 0.08 / FEATURE_SCALE + noise2.get_noise_3dv(p * 0.4) * 4.0) * 2.2 * FEATURE_SCALE
	for c: Array in craters:
		var cd: Vector3 = c[0]
		var d := dir.angle_to(cd) * radius / float(c[1])
		if d < 1.0:
			h -= float(c[2]) * (1.0 - d * d)
		elif d < 1.7:
			var k := 1.0 - (d - 1.0) / 0.7
			h += float(c[2]) * 0.4 * k * k
	# mountain ranges: long ridged chains in some regions, valleys between them
	var mh := float(conf.get("mountains", 0.0))
	if mh > 0.0:
		var m := smoothstep(0.05, 0.45, mount_mask.get_noise_3dv(p))
		if m > 0.0:
			var r := mount.get_noise_3dv(p) * 0.5 + 0.5
			var land := 1.0 if water < -900.0 else smoothstep(water - 1.0, water + 4.0, h)
			h += r * r * mh * m * land
	# wide flat plains in some colour zones (Verdis savanna): the land only rolls gently there
	if conf.has("flat_zones"):
		var fk := flat_k(dir)
		if fk > 0.0:
			h = lerpf(h, h * 0.18 + 0.4, fk)
	# terraces / mesas: layered rock that breaks into cliffs (Ferrum, Solara ...)
	var tz := float(conf.get("terraces", 0.0))
	if tz > 0.0 and h > 1.0:
		var f := h / tz
		var stepped := (floorf(f) + smoothstep(0.3, 0.7, f - floorf(f))) * tz
		h = lerpf(h, stepped, 0.75)
	if has_valley:
		h = _valley(dir, p, h)
	h += noise2.get_noise_3dv(p) * 0.35
	# surface detail: little bumps everywhere, and erosion grooves (narrow channels that
	# run down the land like dried rivulets / cracks) - stronger on rocky planets
	if rough > 0.0:
		h += micro.get_noise_3dv(p) * rough * 0.7
		var gv := absf(groove.get_noise_3dv(p + Vector3(0.0, micro.get_noise_3dv(p * 0.3) * 6.0, 0.0)))
		var gk := 1.0 - smoothstep(0.0, 0.12, gv)
		h -= gk * gk * rough * 0.7
		# rolling unevenness, and rocky outcrops: ledges of bare rock with steep edges
		h += medium.get_noise_3dv(p) * rough * 1.8
		var ok := _outcrop_k(p)
		if ok > 0.0:
			h += ok * rough * 5.0
		# ragged coasts: coves, points and rocky edges instead of smooth contour lines
		if water > -900.0:
			var dw := absf(h - water)
			if dw < 4.0:
				h += coast.get_noise_3dv(p) * 1.3 * (1.0 - dw / 4.0)
	# the landing place stays flat (and dry)
	var fd := dir.angle_to(flat_dir) * radius
	if fd < 14.0:
		var target := maxf(_landing_height(), water + 1.6) if water > -900.0 else _landing_height()
		h = lerpf(target, h, smoothstep(6.0, 14.0, fd))
	if not lakes.is_empty():
		h = _lake_carve(dir, h)
	if not rivers.is_empty():
		h = _river_carve(dir, p, h)
	if not deform.is_empty():
		h = _deform(dir, h)
	# rocky reefs and boulders on the sandy sea floor
	if bool(conf.get("island", false)) and h < water - 0.6:
		var rk2 := _sea_rock_k(p)
		if rk2 > 0.0:
			h += rk2 * (1.0 + micro.get_noise_3dv(p * 2.0) * 0.6) * 1.3 * smoothstep(water - 0.6, water - 2.5, h)
	return h


## Where rock comes through the sand of the sea floor (0 = sand, 1 = rock)
func _sea_rock_k(p: Vector3) -> float:
	return smoothstep(0.18, 0.42, noise2.get_noise_3dv(p * 0.35))


# ================================================================== craters (real deformation)
var deform: Array = []           # see DEFORM
var _crater_t1: Array = []       # per crater: two axes across it (for the ragged outline)
var _crater_t2: Array = []


func _crater_axes(c: Array) -> void:
	var d: Vector3 = c[0]
	var t1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	_crater_t1.append(t1)
	_crater_t2.append(d.cross(t1))


## Blasts a crater into the ground (or a cavity into a rock wall): everything inside its ragged
## outline is cut down to a bowl below the impact point, with a raised rim around it.
## The height function itself changes, so walking, the capsule, animals and the mesh all see it.
func add_crater(dir: Vector3, r: float, depth: float) -> Array:
	var d := dir.normalized()
	var h0 := height(d)
	var c: Array = [d, r, depth, h0, randf() * 100.0]
	deform.append(c)
	_crater_axes(c)
	return c


func _deform(dir: Vector3, h: float) -> float:
	for i in deform.size():
		var c: Array = deform[i]
		var cd: Vector3 = c[0]
		var r := float(c[1])
		var cosd := dir.dot(cd)
		if cosd < cos(r * 1.8 / radius):
			continue
		var dist := acos(clampf(cosd, -1.0, 1.0)) * radius
		var t1: Vector3 = _crater_t1[i]
		var t2: Vector3 = _crater_t2[i]
		var ang := atan2(dir.dot(t2), dir.dot(t1))
		var sd := float(c[4])
		# ragged outline (never a perfect circle) and a rough, rubbly floor
		var rr := r * (1.0 + 0.18 * sin(ang * 3.0 + sd) + 0.1 * sin(ang * 7.0 + sd * 2.3) + 0.06 * sin(ang * 13.0 + sd * 0.7))
		var k := dist / rr
		var depth := float(c[2])
		var h0 := float(c[3])
		if k < 1.0:
			var bowl := 1.0 - k * k
			var floor_h := h0 - depth * bowl * (0.85 + 0.15 * sin(ang * 5.0 + sd)) + micro.get_noise_3dv(dir * radius * 3.0) * depth * 0.12
			h = minf(h, floor_h)
		elif k < 1.65:
			# thrown-out rock: a raised, uneven rim
			var e := 1.0 - (k - 1.0) / 0.65
			h += depth * 0.22 * e * e * (0.7 + 0.3 * sin(ang * 4.0 + sd))
	return h


## How much bare rock breaks through here (0 none .. 1 a rock ledge); stepped, so ledges
## have edges instead of soft humps
func _outcrop_k(p: Vector3) -> float:
	var oc := outcrop.get_noise_3dv(p)
	if oc < 0.42:
		return 0.0
	var e := (oc - 0.42) / 0.58
	var step := floorf(e * 3.0) / 3.0
	return lerpf(e, step + smoothstep(0.0, 0.25, e * 3.0 - floorf(e * 3.0)) / 3.0, 0.6) * e


## 0 outside any crater, up to 1 in the middle (for freshly exposed rock colours)
func crater_k(dir: Vector3) -> float:
	var best := 0.0
	for c: Array in deform:
		var cd: Vector3 = c[0]
		var r := float(c[1]) * 1.25
		var cosd := dir.dot(cd)
		if cosd < cos(r / radius):
			continue
		best = maxf(best, 1.0 - acos(clampf(cosd, -1.0, 1.0)) * radius / r)
	return best


# ================================================================== rivers and streams
## [rivers, liquid, small streams, lakes] per planet: water on the wet planets, lava on Ferrum.
## Streams are narrow and shallow with a weak current and a stony bed; lakes are deep enough to
## swim and dive in (the little pools at the end of some rivers are not).
const RIVERS := {"aquora": [7, "water", 9, 2], "verdis": [6, "water", 12, 3], "ferrum": [4, "lava", 0, 0], "glacia": [3, "water", 5, 0],
	"mycelia": [4, "water", 7, 2]}
var lakes: Array = []            # {c: centre direction, r: radius (m), surf: water height, depth}
const LAKE_DEPTH := 3.4
const RIVER_CELL := 8.0
var rivers: Array = []           # {pts: dirs, surf: water surface heights, w: half widths, liquid, pool}
var river_hash := {}             # cell -> [[river, segment], ...]
var river_liquid := "water"
var _tracing := false


func _rkey(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / RIVER_CELL), floori(p.y / RIVER_CELL), floori(p.z / RIVER_CELL))


## Follows the land downhill from high places to the sea (or into a pool), then carves the bed.
## The water surface only ever goes down, so the water always flows; where the land drops
## suddenly (cliffs, terraces) the river falls as a waterfall.
func _trace_rivers() -> void:
	if skip_rivers or not RIVERS.has(pid):
		return
	var cfg: Array = RIVERS[pid]
	river_liquid = str(cfg[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pid) + 1717
	_make_lakes(rng, int(cfg[3]) if cfg.size() > 3 else 0)
	_tracing = true
	var n_rivers := int(cfg[0])
	var n_streams := int(cfg[2]) if cfg.size() > 2 else 0
	var tries := 0
	while rivers.size() < n_rivers + n_streams and tries < 700:
		tries += 1
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if d.angle_to(flat_dir) * radius < 45.0:
			continue
		if has_valley and absf(valley_coords(d).y) < v_len * 0.6 + 25.0 and absf(valley_coords(d).x) < 40.0:
			continue
		var stream := rivers.size() >= n_rivers
		var h := height(d)
		var high := (water + 5.0) if water > -900.0 else float(conf.get("amp", 8.0)) * 0.35
		if stream:
			high = (water + 2.5) if water > -900.0 else float(conf.get("amp", 8.0)) * 0.1
		if h < high or slope(d) > 0.5 or lake_surface(d) > -INF:
			continue
		var riv := _trace_one(d, rng, 0.85 if stream else 2.4)
		if not riv.is_empty():
			riv["stream"] = stream
			rivers.append(riv)
	_tracing = false
	# spatial hash: which river segments are near each 8 m cell
	for ri in rivers.size():
		var rv: Dictionary = rivers[ri]
		var pts: Array = rv["pts"]
		var ws: Array = rv["w"]
		for si in pts.size() - 1:
			var a: Vector3 = pts[si] * radius
			var b: Vector3 = pts[si + 1] * radius
			var reach := float(ws[si]) + 4.5
			var lo := _rkey(Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)) - Vector3.ONE * reach)
			var hi := _rkey(Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z)) + Vector3.ONE * reach)
			for x in range(lo.x, hi.x + 1):
				for y in range(lo.y, hi.y + 1):
					for z in range(lo.z, hi.z + 1):
						var key := Vector3i(x, y, z)
						if not river_hash.has(key):
							river_hash[key] = []
						var lst: Array = river_hash[key]
						lst.append([ri, si])
		if bool(rv["pool"]):
			var e: Vector3 = pts[pts.size() - 1] * radius
			var pr := float(rv["pool_r"]) + 4.0
			for x in range(_rkey(e - Vector3.ONE * pr).x, _rkey(e + Vector3.ONE * pr).x + 1):
				for y in range(_rkey(e - Vector3.ONE * pr).y, _rkey(e + Vector3.ONE * pr).y + 1):
					for z in range(_rkey(e - Vector3.ONE * pr).z, _rkey(e + Vector3.ONE * pr).z + 1):
						var key2 := Vector3i(x, y, z)
						if not river_hash.has(key2):
							river_hash[key2] = []
						var lst2: Array = river_hash[key2]
						lst2.append([ri, -1])


func _trace_one(start: Vector3, rng: RandomNumberGenerator, max_w := 2.4) -> Dictionary:
	var step := 2.0
	var d := start
	var flow := Vector3.ZERO
	var pts: Array = [d]
	var h := height(d)
	var surfs: Array = [h - 0.3]
	var ws: Array = [0.5 if max_w > 1.0 else 0.3]
	var stuck := 0
	var to_lake := false
	var to_sea := false
	for i in 240:
		var up := d
		var t1 := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := up.cross(t1)
		var best := Vector3.ZERO
		var best_h := INF
		for k in 10:
			var a := k * TAU / 10.0
			var dirv := t1 * cos(a) + t2 * sin(a)
			if flow != Vector3.ZERO and dirv.dot(flow) < 0.2:
				continue                       # rivers don't turn sharply
			var nd := (d + dirv * step / radius).normalized()
			var nh := height(nd) + rng.randf() * 0.05
			if nh < best_h:
				best_h = nh
				best = nd
		if best == Vector3.ZERO:
			break
		if best_h > h + 0.05:
			stuck += 1
		else:
			stuck = 0
		if stuck > 14:
			break                              # a basin: the river ends in a pool here
		flow = (best - d).normalized()
		d = best
		if d.angle_to(flat_dir) * radius < 20.0:
			return {}                          # never through the landing place
		h = best_h
		var prev := float(surfs[surfs.size() - 1])
		# the water surface only goes down; cut deeper where the land rises a little
		var surf := minf(prev - 0.012, h - 0.25)
		pts.append(d)
		surfs.append(surf)
		ws.append(minf((0.55 + i * 0.012) if max_w > 1.0 else (0.3 + i * 0.005), max_w))
		if water > -900.0 and surf < water - 0.4:
			to_sea = true
			break
		if lake_surface(d) > -INF:
			to_lake = true                     # it flows into a lake
			break
	if pts.size() < (25 if max_w > 1.0 else 15):
		return {}
	var pool := not to_sea and not to_lake
	return {"pts": pts, "surf": surfs, "w": ws, "liquid": river_liquid, "pool": pool, "pool_r": 3.5 + rng.randf() * 2.5}


# ================================================================== lakes
## Lakes: round basins in fairly flat, low places, deep enough to swim (up to LAKE_DEPTH). The
## water level is just under the lowest point of the land around, so the lake never spills.
func _make_lakes(rng: RandomNumberGenerator, count: int) -> void:
	var tries := 0
	while lakes.size() < count and tries < 300:
		tries += 1
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var r := rng.randf_range(11.0, 19.0)
		if d.angle_to(flat_dir) * radius < 40.0 + r:
			continue
		if has_valley and absf(valley_coords(d).y) < v_len * 0.6 + 30.0 and absf(valley_coords(d).x) < 45.0:
			continue
		var h := height(d)
		if water > -900.0 and h < water + 3.0:
			continue
		if slope(d) > 0.18:
			continue
		var clash := false
		for lk: Dictionary in lakes:
			if d.angle_to(lk["c"]) * radius < r + float(lk["r"]) + 25.0:
				clash = true
		if clash:
			continue
		# the rim: the lowest ground in a ring around the lake sets the water level
		var b := surface_basis(d, 0.0)
		var lowest := INF
		var highest := -INF
		for k in 20:
			var a := TAU * k / 20.0
			var q := (d * radius + (b.x * cos(a) + b.z * sin(a)) * (r + 2.5)).normalized()
			var hq := height(q)
			lowest = minf(lowest, hq)
			highest = maxf(highest, hq)
		if highest - lowest > 5.0:
			continue                           # too steep around: it would be a wall on one side
		lakes.append({"c": d, "r": r, "surf": lowest - 0.3, "depth": LAKE_DEPTH * rng.randf_range(0.8, 1.1)})


## Lowers the ground into the lakes (a bowl with gently sloping shores)
func _lake_carve(dir: Vector3, h: float) -> float:
	for lk: Dictionary in lakes:
		var c: Vector3 = lk["c"]
		var dd := acos(clampf(dir.dot(c), -1.0, 1.0)) * radius
		var r := float(lk["r"])
		if dd > r + 6.0:
			continue
		var sf := float(lk["surf"])
		if dd < r:
			var q := dd / r
			var bowl := sf - float(lk["depth"]) * pow(1.0 - q * q, 0.7) - 0.05
			h = minf(h, bowl)
		else:
			h = minf(h, lerpf(sf + 0.08, h, smoothstep(r, r + 6.0, dd)))
	return h


## Water level of a lake at dir, or -INF outside the lakes
func lake_surface(dir: Vector3) -> float:
	var d := dir.normalized()
	for lk: Dictionary in lakes:
		var c: Vector3 = lk["c"]
		if acos(clampf(d.dot(c), -1.0, 1.0)) * radius < float(lk["r"]):
			return float(lk["surf"])
	return -INF


## Any open water surface here: river, stream, pool or lake (not the sea). -INF if none.
func water_surface(dir: Vector3) -> float:
	var ls := lake_surface(dir)
	if ls > -INF:
		return ls
	return river_surface(dir) if not rivers.is_empty() else -INF


## How far the nearest river / stream / pool / lake edge is (m): < 0 inside the water,
## > 0 on land. INF when no water is near (within about 6 m).
func water_edge(dir: Vector3) -> float:
	var d := dir.normalized()
	var best := INF
	for lk: Dictionary in lakes:
		var c: Vector3 = lk["c"]
		var dl := acos(clampf(d.dot(c), -1.0, 1.0)) * radius - float(lk["r"])
		if dl < 6.0:
			best = minf(best, dl)
	if rivers.is_empty():
		return best
	var p := d * radius
	var key := _rkey(p)
	if not river_hash.has(key):
		return best
	for e: Array in river_hash[key]:
		var rv: Dictionary = rivers[int(e[0])]
		var si := int(e[1])
		var pts: Array = rv["pts"]
		if si < 0:
			var ce: Vector3 = pts[pts.size() - 1]
			best = minf(best, acos(clampf(d.dot(ce), -1.0, 1.0)) * radius - float(rv["pool_r"]))
			continue
		var a: Vector3 = pts[si] * radius
		var b: Vector3 = pts[si + 1] * radius
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var ws: Array = rv["w"]
		best = minf(best, p.distance_to(a + ab * t) - lerpf(float(ws[si]), float(ws[si + 1]), t))
	return best


## The current of a river / stream at dir (m/s, along the ground). Streams flow gently,
## faster where they run steeply; pools and lakes are still.
func river_flow(dir: Vector3) -> Vector3:
	if rivers.is_empty():
		return Vector3.ZERO
	var p := dir.normalized() * radius
	var key := _rkey(p)
	if not river_hash.has(key):
		return Vector3.ZERO
	for e: Array in river_hash[key]:
		var rv: Dictionary = rivers[int(e[0])]
		var si := int(e[1])
		if si < 0:
			continue
		var pts: Array = rv["pts"]
		var surfs: Array = rv["surf"]
		var a: Vector3 = pts[si] * radius
		var b: Vector3 = pts[si + 1] * radius
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var ws: Array = rv["w"]
		var w := lerpf(float(ws[si]), float(ws[si + 1]), t)
		var dist := p.distance_to(a + ab * t)
		if dist < w:
			var drop := (float(surfs[si]) - float(surfs[si + 1])) / maxf(ab.length(), 0.1)
			var spd := (0.35 if bool(rv.get("stream", false)) else 0.6) + clampf(drop * 8.0, 0.0, 1.4)
			# slower near the banks
			spd *= 1.0 - (dist / w) * (dist / w) * 0.6
			var u := dir.normalized()
			var fl := ab - u * ab.dot(u)
			return fl.normalized() * spd
	return Vector3.ZERO


## Lowers the ground into the river's bed (water surface minus a shallow depth), with banks
func _river_carve(dir: Vector3, p: Vector3, h: float) -> float:
	if _tracing:
		return h
	var key := _rkey(p)
	if not river_hash.has(key):
		return h
	for e: Array in river_hash[key]:
		var rv: Dictionary = rivers[int(e[0])]
		var si := int(e[1])
		var pts: Array = rv["pts"]
		var surfs: Array = rv["surf"]
		if si < 0:
			# the pool at the river's end: a round, flat-bottomed basin
			var ce: Vector3 = pts[pts.size() - 1]
			var pr := float(rv["pool_r"])
			var dd := acos(clampf(dir.dot(ce), -1.0, 1.0)) * radius
			var sf := float(surfs[surfs.size() - 1])
			if dd < pr:
				h = minf(h, sf - 0.35 * (1.0 - (dd / pr) * (dd / pr)) - 0.04)
			elif dd < pr + 3.0:
				h = minf(h, lerpf(sf + 0.05, h, smoothstep(pr, pr + 3.0, dd)))
			continue
		var a: Vector3 = pts[si] * radius
		var b: Vector3 = pts[si + 1] * radius
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var dist := p.distance_to(a + ab * t)
		var ws: Array = rv["w"]
		var w := lerpf(float(ws[si]), float(ws[si + 1]), t)
		var bank := 2.5 + w
		if dist > w + bank:
			continue
		var sf2 := lerpf(float(surfs[si]), float(surfs[si + 1]), t)
		var depth := 0.16 + w * 0.05
		if dist < w:
			var q := dist / w
			# the bed itself is shaped exactly (fills small dips too, so the water never floats)
			h = sf2 - depth * (1.0 - q * q) + 0.06 * smoothstep(0.75, 1.0, q)
		else:
			h = minf(h, lerpf(sf2 + 0.06, h, smoothstep(w, w + bank, dist)))
	return h


## Water surface height of a river / pool at dir, or -INF when not in one
func river_surface(dir: Vector3) -> float:
	if rivers.is_empty():
		return -INF
	var p := dir.normalized() * radius
	var key := _rkey(p)
	if not river_hash.has(key):
		return -INF
	for e: Array in river_hash[key]:
		var rv: Dictionary = rivers[int(e[0])]
		var si := int(e[1])
		var pts: Array = rv["pts"]
		var surfs: Array = rv["surf"]
		if si < 0:
			var ce: Vector3 = pts[pts.size() - 1]
			if acos(clampf(dir.normalized().dot(ce), -1.0, 1.0)) * radius < float(rv["pool_r"]):
				return float(surfs[surfs.size() - 1])
			continue
		var a: Vector3 = pts[si] * radius
		var b: Vector3 = pts[si + 1] * radius
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var ws: Array = rv["w"]
		if p.distance_to(a + ab * t) < lerpf(float(ws[si]), float(ws[si + 1]), t):
			return lerpf(float(surfs[si]), float(surfs[si + 1]), t)
	return -INF


## Cuts the narrow valley: nearly vertical walls, a bumpy floor, closed ends
func _valley(dir: Vector3, p: Vector3, h: float) -> float:
	var across := asin(clampf(dir.dot(v_a), -1.0, 1.0)) * radius
	var along := atan2(dir.dot(v_b), dir.dot(v_c)) * radius
	var half := v_width * 0.5
	# the walls wind a little, so the valley looks natural
	across += sin(along * 0.07) * 1.6 + noise2.get_noise_3dv(p * 0.5) * 0.8
	if absf(along) > v_len * 0.5 + 3.0 or absf(across) > half + 2.0:
		return h
	var wall := 1.0 - smoothstep(half - 1.0, half + 0.4, absf(across))
	var ends := 1.0 - smoothstep(v_len * 0.5 - 1.5, v_len * 0.5 + 1.0, absf(along))
	var floor_h := h - v_depth + noise2.get_noise_3dv(p * 2.2) * 1.2 + absf(across) * 0.15
	return lerpf(h, floor_h, wall * ends)


## The valley's middle line winds a little: its sideways offset at `along`
func valley_center(along: float) -> float:
	var d := valley_dir(0.0, along)
	return -(sin(along * 0.07) * 1.6 + noise2.get_noise_3dv(d * radius * 0.5) * 0.8)


## Where a point is relative to the valley: [across (m from the middle line), along (m)]
func valley_coords(dir: Vector3) -> Vector2:
	var d := dir.normalized()
	return Vector2(asin(clampf(d.dot(v_a), -1.0, 1.0)) * radius, atan2(d.dot(v_b), d.dot(v_c)) * radius)


## Direction of a point given in valley coordinates (inverse of valley_coords)
func valley_dir(across: float, along: float) -> Vector3:
	# first along the valley's middle line, then sideways
	var d := v_c.rotated(v_c.cross(v_b).normalized(), along / radius)
	var side := (v_a - d * v_a.dot(d)).normalized()
	return d.rotated(d.cross(side).normalized(), across / radius).normalized()


var _landing_h := -INF
func _landing_height() -> float:
	if _landing_h == -INF:
		_landing_h = 0.0
		var p := flat_dir * radius
		_landing_h = noise.get_noise_3dv(p) * float(conf.get("amp", 8.0)) * 0.5
	return _landing_h


## Distance of the ground from the planet centre
func surface_radius(dir: Vector3) -> float:
	return radius + height(dir.normalized())


## Point on the ground below/above p (plus lift along "up")
func ground_point(p: Vector3, lift := 0.0) -> Vector3:
	var d := p.normalized()
	return d * (radius + height(d) + lift)


## Ground normal (from 4 nearby heights)
func normal_at(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	var t1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := d.cross(t1)
	var e := 1.0 / radius
	var a := (d + t1 * e).normalized()
	var b := (d - t1 * e).normalized()
	var c := (d + t2 * e).normalized()
	var f := (d - t2 * e).normalized()
	var pa := a * (radius + height(a))
	var pb := b * (radius + height(b))
	var pc := c * (radius + height(c))
	var pf := f * (radius + height(f))
	var n := (pa - pb).cross(pc - pf).normalized()
	return n if n.dot(d) > 0.0 else -n


## Which colour zone a place belongs to (0 = main zone). Areas of a planet look different.
func zone_at(dir: Vector3) -> int:
	if zones.size() <= 1:
		return 0
	return clampi(int(zone_f(dir)), 0, zones.size() - 1)


## The dense rainforest region: 1 inside, 0 outside, a ragged soft edge
var rain_c := Vector3.ZERO
var rain_r := 0.0


func rain_k(dir: Vector3) -> float:
	if rain_r <= 0.0:
		return 0.0
	var d := dir.normalized()
	var dist := acos(clampf(d.dot(rain_c), -1.0, 1.0)) * radius
	if dist > rain_r * 1.35:
		return 0.0
	var ragged := zone_noise.get_noise_3dv(d * radius * 3.0) * rain_r * 0.18
	return 1.0 - smoothstep(rain_r * 0.85, rain_r * 1.1, dist + ragged)


## How much a place lies in a flat-plain zone (0 .. 1, soft borders)
func flat_k(dir: Vector3) -> float:
	var fz: Array = conf.get("flat_zones", [])
	if fz.is_empty() or zones.size() <= 1:
		return 0.0
	var z := zone_f(dir)
	var k := 0.0
	for zi in fz:
		var c := float(zi) + 0.5
		k = maxf(k, 1.0 - smoothstep(0.35, 0.95, absf(z - c)))
	return k


## The zone as a smooth number (0 .. zones - 1): for soft, ragged borders between zones
func zone_f(dir: Vector3) -> float:
	if zones.size() <= 1:
		return 0.0
	var z := clampf((zone_noise.get_noise_3dv(dir.normalized() * radius) * 0.5 + 0.5) * zones.size() * 1.15 - 0.07, 0.0, zones.size() - 0.001)
	if rain_r > 0.0:
		z = lerpf(z, 0.3, rain_k(dir))         # the rainforest is jungle (zone 0)
	return z


## Blend of the zone colours at a place (soft borders between zones)
func zone_colors(dir: Vector3) -> Array:
	if zones.size() <= 1:
		return zones[0]
	var z := minf(zone_f(dir), zones.size() - 1.0)
	var i := int(z)
	var j := mini(i + 1, zones.size() - 1)
	var k := smoothstep(0.65, 1.0, z - i)
	var a: Array = zones[i]
	var b: Array = zones[j]
	return [Color(a[0]).lerp(b[0], k), Color(a[1]).lerp(b[1], k), Color(a[2]).lerp(b[2], k)]


## Steepness 0 (flat) .. 1 (wall)
func slope(dir: Vector3) -> float:
	return 1.0 - normal_at(dir).dot(dir.normalized())


func is_dry(dir: Vector3) -> bool:
	if not rivers.is_empty() and river_surface(dir) > -INF:
		return false
	if not lakes.is_empty() and lake_surface(dir) > -INF:
		return false
	return water < -900.0 or height(dir.normalized()) > water + 0.3


# ================================================================== mesh
func _cube_dir(face: int, u: float, v: float) -> Vector3:
	# u, v from -1 to 1 on the cube face
	var p: Vector3
	match face:
		0: p = Vector3(1, v, -u)
		1: p = Vector3(-1, v, u)
		2: p = Vector3(u, 1, -v)
		3: p = Vector3(u, -1, v)
		4: p = Vector3(u, v, 1)
		_: p = Vector3(-u, v, -1)
	# spread the grid more evenly over the sphere
	var x2 := p.x * p.x
	var y2 := p.y * p.y
	var z2 := p.z * p.z
	return Vector3(p.x * sqrt(1.0 - y2 / 2.0 - z2 / 2.0 + y2 * z2 / 3.0),
		p.y * sqrt(1.0 - z2 / 2.0 - x2 / 2.0 + z2 * x2 / 3.0),
		p.z * sqrt(1.0 - x2 / 2.0 - y2 / 2.0 + x2 * y2 / 3.0)).normalized()


## Colour of the ground at a point (zone colours, height, steepness, scorched lava shores,
## freshly exposed rock layers in craters, wet river banks)
func vertex_color(d: Vector3, h: float, sl: float) -> Color:
	var amp := float(conf.get("amp", 8.0))
	var detail := float(conf.get("detail", 0.25))
	var zc := zone_colors(d)
	var c_low: Color = zc[0]
	var c_high: Color = zc[1]
	var c_steep: Color = zc[2]
	var col: Color
	if bool(conf.get("island", false)):
		col = c_low if h < water + 1.3 else c_high.lerp(c_high.darkened(0.25), clampf((h - 4.0) / 8.0, 0.0, 1.0))
		if h < water:
			# the sea floor: pale sand, a little darker deeper down, with patches of rock
			var dep := water - h
			col = Color("#d6c294").lerp(Color("#a8987a"), clampf(dep / 10.0, 0.0, 1.0))
			var sea_rock := _sea_rock_k(d * radius)
			col = col.lerp(Color("#6e6c64"), sea_rock)
	else:
		col = c_low.lerp(c_high, clampf((h + amp) / (2.0 * amp), 0.0, 1.0))
	col = col.lerp(c_steep, smoothstep(0.12, 0.4, sl))
	var p := d * radius
	col = col.darkened(detail * 0.5 * (0.5 + 0.5 * noise2.get_noise_3dv(p * 3.0)))
	if pid == "ferrum" and water > -900.0 and h < water + 0.9:
		col = col.lerp(Color("#5a1a08"), 0.7)      # scorched shore of the lava lakes
	# bare rock on the outcrops (alpha carries "rock" to the ground shader: 1 = soil, 0 = rock)
	var rk := 0.0
	if rough > 0.0:
		rk = clampf(_outcrop_k(p) * 3.0, 0.0, 1.0)
		if rk > 0.0:
			var band := 0.5 + 0.5 * sin(h * 4.0 + noise2.get_noise_3dv(p * 1.5) * 2.0)
			col = col.lerp(c_steep.lerp(c_high, 0.2 + 0.25 * band), rk * 0.85)
		col.a = 1.0 - rk
	if bool(conf.get("island", false)) and h < water:
		col.a = minf(col.a, 1.0 - _sea_rock_k(p) * 0.9)
	if rain_r > 0.0:
		var rk3 := rain_k(d)
		if rk3 > 0.0:
			# rainforest floor: dark, damp, mossy
			col = col.lerp(Color("#2c4a1e").lerp(Color("#3e3424"), 0.5 + 0.5 * noise2.get_noise_3dv(p * 0.8)), rk3 * 0.7)
	if not lakes.is_empty():
		var ls := lake_surface(d)
		if ls > -INF:
			# lake bed: fine grey-brown sand and mud, darker in the deep middle
			col = Color("#9a8a68").lerp(Color("#4a4636"), clampf((ls - h) / 3.0, 0.0, 1.0))
	if not rivers.is_empty():
		var rs := river_surface(d)
		if rs > -INF:
			# river bed: wet dark stones (or cooled black rock under lava)
			col = col.darkened(0.45).lerp(Color("#3a2a20") if river_liquid == "lava" else Color("#5a6258"), 0.45)
			col.a = 0.25                         # (stony: the ground shader draws rock detail)
	if not deform.is_empty():
		var ck := crater_k(d)
		if ck > 0.0:
			# freshly exposed layers: bands of lighter and darker rock, scorched in the middle
			var band := 0.5 + 0.5 * sin(h * 3.2 + noise2.get_noise_3dv(p * 2.0) * 2.0)
			var fresh := c_steep.lerp(c_high, 0.25).lerp(c_steep.darkened(0.45), band)
			col = col.lerp(fresh, smoothstep(0.0, 0.25, ck))
			col = col.darkened(smoothstep(0.55, 0.95, ck) * 0.15)
			col.a = minf(col.a, 1.0 - smoothstep(0.0, 0.3, ck))
	return col


func build_mesh() -> MeshInstance3D:
	var amp := float(conf.get("amp", 8.0))
	var c_low: Color = conf.get("low", Color.GRAY)
	var c_high: Color = conf.get("high", Color.WHITE)
	var c_steep: Color = conf.get("steep", Color.DIM_GRAY)
	var detail := float(conf.get("detail", 0.25))
	var island := bool(conf.get("island", false))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var n1 := GRID + 1
	var base := 0
	for face in 6:
		var pos := PackedVector3Array()
		var hs := PackedFloat32Array()
		pos.resize(n1 * n1)
		hs.resize(n1 * n1)
		for j in n1:
			for i in n1:
				var d := _cube_dir(face, -1.0 + 2.0 * i / GRID, -1.0 + 2.0 * j / GRID)
				var h := height(d)
				hs[j * n1 + i] = h
				pos[j * n1 + i] = d * (radius + h)
		for j in n1:
			for i in n1:
				var k := j * n1 + i
				var p := pos[k]
				var d := p.normalized()
				var px := pos[j * n1 + mini(i + 1, GRID)] - pos[j * n1 + maxi(i - 1, 0)]
				var pz := pos[mini(j + 1, GRID) * n1 + i] - pos[maxi(j - 1, 0) * n1 + i]
				var nrm := px.cross(pz).normalized()
				if nrm.dot(d) < 0.0:
					nrm = -nrm
				var h := hs[k]
				var sl := 1.0 - nrm.dot(d)
				var zc := zone_colors(d)
				c_low = zc[0]
				c_high = zc[1]
				c_steep = zc[2]
				var col: Color
				if island:
					col = c_low if h < water + 1.3 else c_high.lerp(c_high.darkened(0.25), clampf((h - 4.0) / 8.0, 0.0, 1.0))
					if h < water:
						col = c_low.darkened(0.35).lerp(Color("#3d6b70"), clampf((water - h) / 6.0, 0.0, 1.0))
				else:
					col = c_low.lerp(c_high, clampf((h + amp) / (2.0 * amp), 0.0, 1.0))
				col = col.lerp(c_steep, smoothstep(0.12, 0.4, sl))
				col = col.darkened(detail * 0.5 * (0.5 + 0.5 * noise2.get_noise_3dv(p * 3.0)))
				if pid == "ferrum" and water > -900.0 and h < water + 0.9:
					col = col.lerp(Color("#5a1a08"), 0.7)      # scorched shore of the lava lakes
				cols.append(col)
				norms.append(nrm)
				verts.append(p)
		for j in GRID:
			for i in GRID:
				var a := base + j * n1 + i
				var b := a + 1
				var c := a + n1
				var dd := c + 1
				idx.append_array(PackedInt32Array([a, c, b, b, c, dd]))
		base += n1 * n1
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.35 if pid == "glacia" else 0.9
	mat.albedo_texture = detail_texture(detail)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.09, 0.09, 0.09)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Planet"
	return mi


## Small grey noise that makes the ground look rough up close
static func detail_texture(amount: float) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.04
	n.fractal_octaves = 3
	t.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(1.0 - amount, 1.0 - amount, 1.0 - amount))
	g.set_color(1, Color.WHITE)
	t.color_ramp = g
	return t


## Orientation for something standing on the ground at dir, turned by yaw around "up"
static func surface_basis(up: Vector3, yaw: float) -> Basis:
	var u := up.normalized()
	var ref := Vector3.FORWARD if absf(u.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var fwd := (ref - u * ref.dot(u)).normalized().rotated(u, yaw)
	return Basis(u.cross(fwd).normalized(), u, fwd)
