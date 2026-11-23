class_name BuildSite
extends Interactable
## A place where the player can construct something (first draft: the Gem Mine).
## The site number is the save key in Game.planet_dev[planet]["buildings"].

var pid := ""
var index := 0
var accent := Color.CYAN
var look: Node3D
var ring: Node3D = null
var wheel: Node3D = null
var t := 0.0


func setup(planet_id: String, i: int, planet_accent: Color) -> void:
	pid = planet_id
	index = i
	accent = planet_accent
	key = "site:%d" % i
	reach = 5.5
	add_hitbox(1.8, Vector3(0, 1.2, 0))
	refresh()


func building() -> Dictionary:
	return Game.building_at(pid, index)


func prompt() -> String:
	var b := building()
	if b.is_empty():
		return "Inspect building site"
	return str(PlanetDev.BUILDINGS[b["type"]]["name"])


func interact(screen: Node) -> void:
	screen.call("open_site", self)


func refresh() -> void:
	if look:
		look.queue_free()
	look = Node3D.new()
	add_child(look)
	ring = null
	wheel = null
	var b := building()
	title = "Building site %d" % (index + 1) if b.is_empty() else str(PlanetDev.BUILDINGS[b["type"]]["name"])
	var metal := WorldProps.std(Color("#2a3048"), 0.4, 0.8)
	var brass := WorldProps.std(Color("#c79a4a"), 0.3, 1.0)
	# hexagonal foundation (both free and built)
	WorldProps.part(look, WorldProps.cyl(2.2, 2.4, 0.4, 6), metal, Vector3(0, 0.05, 0))
	WorldProps.part(look, WorldProps.torus(2.15, 2.35, 6), WorldProps.std(Color("#38d6ff"), 0.3, 0.0, Color("#38d6ff"), 2.0), Vector3(0, 0.26, 0), Vector3(0, PI / 6, 0))
	if b.is_empty():
		# survey beacon: brass post, turning hologram ring and a light beam
		WorldProps.part(look, WorldProps.cyl(0.08, 0.12, 2.0, 8), brass, Vector3(1.6, 1.0, 0))
		WorldProps.part(look, WorldProps.sphere(0.16, 10, 5), WorldProps.std(Color("#38d6ff"), 0.3, 0.0, Color("#38d6ff"), 3.0), Vector3(1.6, 2.05, 0))
		ring = Node3D.new()
		ring.position = Vector3(0, 1.3, 0)
		look.add_child(ring)
		var holo := ExploreShaders.material("holo", {"color": Color(0.2, 0.85, 1.0, 0.55), "fade_top": 0.0})
		WorldProps.part(ring, WorldProps.torus(1.1, 1.18, 6), holo, Vector3.ZERO)
		WorldProps.part(ring, WorldProps.torus(0.7, 0.75, 6), holo, Vector3(0, 0.25, 0))
		WorldProps.part(look, WorldProps.cyl(0.35, 0.35, 30.0, 12), ExploreShaders.material("holo", {"color": Color(0.2, 0.85, 1.0, 0.18), "stripes": 8.0}), Vector3(0, 15.3, 0))
	else:
		_build_mine(metal, brass)
	WorldProps.solid_cyl(look, 2.3, 0.5, Vector3(0, 0.1, 0))


## Gem Mine: steampunk headframe with a turning wheel, a shaft and a glowing gem crystal.
## (Different planets can get their own look later: check pid here.)
func _build_mine(metal: StandardMaterial3D, brass: StandardMaterial3D) -> void:
	var crystal := Color("#7ff5ff").lerp(accent, 0.45)
	WorldProps.part(look, WorldProps.cyl(0.8, 0.9, 0.3, 6), WorldProps.std(Color("#05060a")), Vector3(0, 0.3, 0))
	for sx: float in [-1.0, 1.0]:
		WorldProps.part(look, WorldProps.box(Vector3(0.18, 4.2, 0.18)), metal, Vector3(sx * 0.9, 2.2, 0), Vector3(0, 0, sx * 0.18))
		WorldProps.part(look, WorldProps.box(Vector3(0.12, 3.0, 0.12)), metal, Vector3(sx * 0.6, 1.6, -0.9), Vector3(-0.35, 0, sx * 0.15))
	WorldProps.part(look, WorldProps.box(Vector3(1.6, 0.14, 0.14)), metal, Vector3(0, 2.4, 0))
	wheel = Node3D.new()
	wheel.position = Vector3(0, 4.2, 0)
	look.add_child(wheel)
	WorldProps.part(wheel, WorldProps.torus(0.55, 0.7, 24), brass, Vector3.ZERO, Vector3(0, 0, PI / 2))
	for k in 4:
		WorldProps.part(wheel, WorldProps.box(Vector3(0.06, 1.2, 0.06)), brass, Vector3.ZERO, Vector3(k * PI / 4, 0, 0))
	WorldProps.part(look, WorldProps.cyl(0.015, 0.015, 3.9, 4), WorldProps.std(Color("#c0c0c8"), 0.3, 1.0), Vector3(0, 2.3, 0.62))
	# gems that were already found
	var gem := ExploreShaders.nature(crystal, crystal, 2.0, 0.0, 0.5, 0.1, 0.3)
	for i in 4:
		var a := i * 1.4
		WorldProps.part(look, WorldProps.cyl(0.0, 0.16, 0.6, 6), gem, Vector3(1.4 + cos(a) * 0.3, 0.55, 0.9 + sin(a) * 0.3), Vector3(0.3 * cos(a), 0, 0.3 * sin(a)))
	# boiler with a lamp
	WorldProps.part(look, WorldProps.cyl(0.4, 0.4, 1.0, 12), brass, Vector3(-1.4, 0.7, 0.8))
	WorldProps.part(look, WorldProps.sphere(0.12, 8, 4), WorldProps.std(Color("#ffcc66"), 0.3, 0.0, Color("#ffaa33"), 3.0), Vector3(-1.4, 1.3, 0.8))
	var l := OmniLight3D.new()
	l.light_color = crystal
	l.omni_range = 5.0
	l.light_energy = 1.0
	l.position = Vector3(1.4, 1.0, 0.9)
	look.add_child(l)


func _process(delta: float) -> void:
	t += delta
	if ring:
		ring.rotation.y += delta * 0.8
		ring.position.y = 1.3 + sin(t * 1.5) * 0.12
	if wheel:
		wheel.rotation.x += delta * 1.5
