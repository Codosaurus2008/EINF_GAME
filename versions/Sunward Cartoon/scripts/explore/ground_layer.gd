class_name GroundLayer
extends Node3D
## The living ground around the player: grass, bushes, small plants, flowers, moss, pebbles,
## stones, twigs, fungi and other small things - different on every planet (Biomes "ground").
## The planet's surface is divided into patches (a grid on each of the 6 cube faces). Patches
## near the camera are filled (each kind = a few GPU-instanced MultiMeshes, so thousands of
## blades cost only a few draw calls) and patches that are far away are removed again.
## Every patch is always filled the same way (its own seed). Things grow in natural clumps:
## dense in fertile flat places, sparse on rock; pebbles the other way round.

## kind: [where, smallest, biggest size (m), view distance (m), sink into the ground]
## where: land, shore, water, any, rock (prefers slopes), crack (only slopes)
const KINDS := {
	"grass": ["land", 0.14, 0.28, 30.0, 0.0], "tall_grass": ["land", 0.28, 0.5, 34.0, 0.0],
	"broad_grass": ["land", 0.12, 0.24, 28.0, 0.0], "fern": ["land", 0.12, 0.24, 32.0, 0.0],
	"bush": ["land", 0.12, 0.28, 50.0, 0.0], "wind_bush": ["land", 0.12, 0.26, 50.0, 0.0],
	"flowers": ["land", 0.1, 0.2, 26.0, 0.0], "flower": ["land", 0.1, 0.2, 26.0, 0.0],
	"moss": ["land", 0.25, 0.6, 24.0, 0.0], "leaf_litter": ["land", 0.25, 0.5, 22.0, 0.0],
	"twigs": ["land", 0.25, 0.55, 24.0, 0.0], "pebbles": ["rock", 0.18, 0.45, 26.0, 0.02],
	"stones": ["rock", 0.12, 0.35, 45.0, 0.04], "gravel": ["rock", 0.25, 0.5, 24.0, 0.0],
	"lichen": ["rock", 0.25, 0.5, 24.0, 0.0], "scrap": ["land", 0.2, 0.4, 26.0, 0.0],
	"hardy_sprout": ["crack", 0.12, 0.24, 26.0, 0.0], "crack_moss": ["crack", 0.25, 0.55, 26.0, 0.0],
	"frost_grass": ["land", 0.15, 0.3, 28.0, 0.0], "snow_clump": ["land", 0.15, 0.35, 32.0, 0.02],
	"snow_patch": ["land", 0.3, 0.7, 30.0, 0.0], "ice_shard": ["any", 0.12, 0.3, 32.0, 0.02],
	"frost_fern": ["land", 0.12, 0.26, 30.0, 0.0],
	"mini_mushroom": ["land", 0.12, 0.3, 30.0, 0.0], "bell_mushrooms": ["land", 0.12, 0.3, 32.0, 0.0],
	"spore_puffs": ["land", 0.12, 0.28, 30.0, 0.0], "fungal_thread": ["land", 0.12, 0.28, 26.0, 0.0],
	"beach_grass": ["shore", 0.15, 0.3, 30.0, 0.0], "shells": ["shore", 0.15, 0.3, 22.0, 0.0],
	"wet_stones": ["shore", 0.15, 0.35, 34.0, 0.03], "seaweed": ["water", 0.2, 0.45, 26.0, 0.0],
	"seagrass": ["water", 0.15, 0.35, 24.0, 0.0],
	"heat_plant": ["land", 0.12, 0.26, 28.0, 0.0], "cinders": ["any", 0.2, 0.45, 26.0, 0.0],
	"lava_crack": ["land", 0.3, 0.7, 40.0, 0.0], "ember_plant": ["land", 0.12, 0.25, 30.0, 0.0],
	"storm_grass": ["land", 0.14, 0.28, 28.0, 0.0], "spark_crystal": ["any", 0.12, 0.25, 32.0, 0.02],
	"metal_nodules": ["rock", 0.2, 0.45, 26.0, 0.02],
	"crystal_grass": ["land", 0.12, 0.25, 28.0, 0.0], "glass_pebble": ["any", 0.2, 0.45, 26.0, 0.0],
	"sun_dish": ["land", 0.12, 0.24, 30.0, 0.0], "salt_crust": ["land", 0.3, 0.7, 30.0, 0.0],
}
const CELL := 20.0               # patch size (m)
const SIZE_K := 1.35             # final size of all ground detail (sizes in KINDS x 1.35, for the 60 cm explorer)
const MARGIN := 12.0             # keep patches this much beyond their view distance
const G := 17                    # height samples along a patch (about 1.2 m apart)

var world: SphereWorld
var kinds: Array = []            # [kind, per square metre, tint, [meshes]]
var n := 8                       # patches along a cube face
var centres: Array = []          # [key, centre point]
var loaded := {}                 # key -> Node3D with the patch's MultiMeshes
var max_view := 30.0
var tick := 0.0
var noise := FastNoiseLite.new()


func setup(w: SphereWorld, entries: Array) -> void:
	world = w
	noise.seed = hash(w.pid) + 99
	noise.frequency = 0.07
	noise.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(w.pid) + 5
	for e: Array in entries:
		var kind: String = e[0]
		if not KINDS.has(kind):
			continue
		var tint: Color = e[2] if e.size() > 2 else Color.WHITE
		var meshes: Array = []
		for v in 3:
			var src := "moss" if kind == "crack_moss" else kind
			var cv: Array = Flora.cover(src, rng, tint)
			meshes.append(cv[0])
		kinds.append([kind, float(e[1]), tint, meshes])
		max_view = maxf(max_view, float(KINDS[kind][3]))
	n = clampi(int(round(w.radius * PI * 0.5 / CELL)), 6, 30)
	for f in 6:
		for i in n:
			for j in n:
				var d := _dir(f, (i + 0.5) / n, (j + 0.5) / n)
				centres.append(["%d|%d|%d" % [f, i, j], d * w.radius, f, i, j])


## Point on the unit sphere for cube face f and face coordinates a, b (0 .. 1)
func _dir(f: int, a: float, b: float) -> Vector3:
	var u := a * 2.0 - 1.0
	var v := b * 2.0 - 1.0
	match f:
		0: return Vector3(1, u, v).normalized()
		1: return Vector3(-1, u, v).normalized()
		2: return Vector3(u, 1, v).normalized()
		3: return Vector3(u, -1, v).normalized()
		4: return Vector3(u, v, 1).normalized()
	return Vector3(u, v, -1).normalized()


var jobs: Array = []             # [key, f, i, j, kind index, node, height grid]
const SAMPLES_PER_FRAME := 600


func _process(delta: float) -> void:
	if world == null:
		return
	_work()
	tick -= delta
	if tick > 0.0:
		return
	tick = 0.2
	var cam := world.viewer
	if cam.length() < 1.0:
		return
	# high above the ground (flying): less (or nothing) of this can be seen
	var alt := cam.length() - world.terrain.surface_radius(cam.normalized())
	var reach := max_view + MARGIN - clampf(alt, 0.0, max_view + MARGIN)
	var want: Array = []
	for c: Array in centres:
		var key: String = c[0]
		var p: Vector3 = c[1]
		var dd := p.distance_to(cam)
		if loaded.has(key):
			if dd > reach + CELL + 8.0:
				(loaded[key] as Node3D).queue_free()
				loaded.erase(key)
		elif dd < reach + CELL * 0.7:
			want.append([dd, c])
	# the nearest patches first
	want.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for w: Array in want:
		if jobs.size() >= 4:
			break
		var c2: Array = w[1]
		var node := Node3D.new()
		add_child(node)
		loaded[str(c2[0])] = node
		jobs.append([str(c2[0]), int(c2[2]), int(c2[3]), int(c2[4]), -1, node, []])


## After a crater: the patches it touches are filled again (on the new ground)
func refresh(dir: Vector3, reach: float) -> void:
	var p := dir.normalized() * world.radius
	for c: Array in centres:
		var key: String = c[0]
		var cp: Vector3 = c[1]
		if loaded.has(key) and cp.distance_to(p) < CELL * 0.75 + reach:
			(loaded[key] as Node3D).queue_free()
			loaded.erase(key)
	tick = 0.0


## A little work every frame: a height grid or one kind of plant for one patch at a time
func _work() -> void:
	var budget := SAMPLES_PER_FRAME
	while budget > 0 and not jobs.is_empty():
		var job: Array = jobs[0]
		if not is_instance_valid(job[5]):
			jobs.pop_front()
			continue
		var node: Node3D = job[5]
		var f := int(job[1])
		var i := int(job[2])
		var j := int(job[3])
		if int(job[4]) < 0:
			# the height grid (as fine as the terrain mesh, so nothing floats or sinks), a few
			# rows per frame
			var hs: Array = job[6]
			var g := G
			for r in 4:
				var gi := hs.size() / g
				if gi >= g:
					break
				for gj in g:
					hs.append(world.terrain.height(_dir(f, (i + gi / float(g - 1)) / n, (j + gj / float(g - 1)) / n)))
				budget -= g * 6
			if hs.size() >= g * g:
				job[4] = 0
			continue
		var ki := int(job[4])
		if ki >= kinds.size():
			jobs.pop_front()
			continue
		budget -= _fill_kind(node, f, i, j, kinds[ki], job[6], hash(world.pid + str(job[0]) + str(ki)))
		job[4] = ki + 1


## One kind of plant / stone in one patch. Returns how many places were tried.
func _fill_kind(node: Node3D, f: int, i: int, j: int, k: Array, hs: Array, seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var g := G
	var wl := world.water_level
	var has_sea := str(world.biome["water"]) == "ocean"
	var lava := str(world.biome["water"]) == "lava"
	var cell_m := world.radius * PI * 0.5 / n
	var area := cell_m * cell_m
	var kind: String = k[0]
	var spec: Array = KINDS[kind]
	var where: String = spec[0]
	var want := int(area * float(k[1]))
	var list: Array = []
	var has_rivers := not world.terrain.rivers.is_empty()
	# the patch's own origin (its centre on the ground): visibility distance is measured from here
	var centre := _dir(f, (i + 0.5) / n, (j + 0.5) / n) * world.radius
	for s in want:
		var a := rng.randf()
		var b := rng.randf()
		# height and slope from the little grid
		var fx := a * (g - 1)
		var fy := b * (g - 1)
		var x0 := mini(int(fx), g - 2)
		var y0 := mini(int(fy), g - 2)
		var tx := fx - x0
		var ty := fy - y0
		var h00 := float(hs[x0 * g + y0])
		var h10 := float(hs[(x0 + 1) * g + y0])
		var h01 := float(hs[x0 * g + y0 + 1])
		var h11 := float(hs[(x0 + 1) * g + y0 + 1])
		var h := lerpf(lerpf(h00, h01, ty), lerpf(h10, h11, ty), tx)
		var step := cell_m / (g - 1)
		var slope := clampf(maxf(absf(h10 - h00), absf(h01 - h00)) / step, 0.0, 2.0)
		var ok := true
		match where:
			"land", "crack":
				ok = (not has_sea or h > wl + 0.15) and not (lava and h < wl + 0.4) and slope < 0.9
			"rock":
				ok = (not has_sea or h > wl - 4.0) and not (lava and h < wl + 0.4)
			"shore":
				ok = has_sea and h > wl - 0.1 and h < wl + 1.4
			"water":
				ok = has_sea and h < wl - 0.25 and h > wl - 7.0
			"any":
				ok = (not has_sea or h > wl - 6.0) and not (lava and h < wl + 0.4)
		if not ok:
			continue
		var d2 := _dir(f, (i + a) / n, (j + b) / n)
		# nothing grows in rivers or pools (they have their own water)
		if has_rivers and world.terrain.river_surface(d2) > -INF:
			continue
		# natural clumps
		var nz := noise.get_noise_3dv(d2 * world.radius) * 0.5 + 0.5
		var keep := 1.0
		match where:
			"land", "shore", "water":
				keep = nz * (1.0 - clampf(slope * 1.2, 0.0, 0.85)) * 1.4 - 0.1
			"rock":
				keep = (1.0 - nz) * 0.7 + clampf(slope * 0.8, 0.0, 0.6)
			"crack":
				keep = clampf((slope - 0.15) * 2.5, 0.0, 1.0) * (0.4 + nz)
			"any":
				keep = 0.35 + nz * 0.65
		if rng.randf() > keep:
			continue
		var sz := rng.randf_range(float(spec[1]), float(spec[2])) * SIZE_K
		var bas := SphereTerrain.surface_basis(d2, rng.randf() * TAU).scaled(Vector3.ONE * sz)
		var pos := d2 * (world.radius + h - float(spec[4]) * sz * 3.0)
		var col := Flora._shade(rng, 0.15)
		col *= world._cover_tint(d2)
		list.append([Transform3D(bas, pos - centre), col])
	# one of the 3 variants per patch: few draw calls, but no two neighbouring patches alike
	var meshes: Array = k[3]
	if not list.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[absi(seed_value) % 3]
		mm.instance_count = list.size()
		for q in list.size():
			var e2: Array = list[q]
			mm.set_instance_transform(q, e2[0])
			mm.set_instance_color(q, e2[1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.position = centre
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = float(spec[3])
		mmi.visibility_range_end_margin = 6.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.add_child(mmi)
	return want
