class_name SolarSystem
extends RefCounted
## One shared space for the whole system: the sun in the middle, every planet at one position
## (metres, "system coordinates"). The planets you see in the sky are drawn at these positions,
## so every planet sees the others where they really are (travel itself goes through the ship).
##
## The planet you are on is the centre of the game world (0, 0, 0) and turns (day and night):
## frame(world) is the rotation from system directions to that planet's own directions.
## The planets do not orbit yet - positions() is the one place to add orbits later
## (e.g. angle + time * speed); everything else already asks it for positions.
##
## Distances are much shorter than real ones (so you can fly between neighbours in a few
## seconds of boost), sizes of the sun and planets are real to the game's scale.

const SUN_RADIUS := 650.0
## per planet (Game.PLANETS order: Pebble outside .. Solara inside): orbit radius, angle, height
const ORBITS := [
	[36500.0, 0.00, 380.0],     # pebble
	[32000.0, 0.17, -260.0],    # glacia
	[27500.0, 0.33, 150.0],     # mycelia
	[23000.0, 0.50, -120.0],    # aquora
	[18500.0, 0.68, 210.0],     # verdis
	[14000.0, 0.86, -90.0],     # ferrum
	[9500.0, 1.05, 140.0],      # voltara
	[5200.0, 1.26, -60.0],      # solara
]
## the planets' common day settings (as in SphereWorld): landing place, sun circle, tilt
const LANDING := Vector3(0.15, 1.0, 0.1)
const TILT := 0.35


static func position(n: int) -> Vector3:
	if n < 0 or n >= ORBITS.size():
		return Vector3.ZERO                       # the sun
	var o: Array = ORBITS[n]
	var r := float(o[0])
	var a := float(o[1])
	return Vector3(cos(a) * r, float(o[2]), sin(a) * r)


static func radius(n: int) -> float:
	if n < 0 or n >= ORBITS.size():
		return SUN_RADIUS
	var b := Biomes.get_biome(Game.planet(n)["id"])
	return float(b.get("radius", 110.0)) * SphereTerrain.WORLD_SCALE


## Rotation from system directions to planet n's own (turning) directions at day phase `phase`:
## the sun direction it gives is exactly the one SphereWorld uses for light and shadows.
static func frame_for(n: int, phase: float) -> Basis:
	var l := LANDING.normalized()
	var b := l.cross(Vector3(0.3, 0, 1)).normalized()
	var ax := b.cross(l).normalized()
	var s0 := (l * cos(TILT) + ax * sin(TILT)).normalized()
	var to_sun := (-position(n)).normalized()
	var q0 := Basis(Quaternion(to_sun, s0))
	# turn by the day phase around the axis the sun circles around (Rodrigues, explicit)
	var c0 := _rot(q0.x, ax, -phase)
	var c1 := _rot(q0.y, ax, -phase)
	var c2 := _rot(q0.z, ax, -phase)
	return Basis(c0, c1, c2)


static func _rot(v: Vector3, k: Vector3, ang: float) -> Vector3:
	return v * cos(ang) + k.cross(v) * sin(ang) + k * k.dot(v) * (1.0 - cos(ang))


static func frame(w: SphereWorld) -> Basis:
	return frame_for(Game.planet_index(w.pid), w.phase)


## The saved day phase of a planet (or the morning start)
static func saved_phase(n: int) -> float:
	var st: Dictionary = Game.planet_dev.get(Game.planet(n)["id"], {})
	var t = st.get("time", null)
	return float(t) if t != null else -0.9


## Where something at local position p (in world w) is in system coordinates, and back
static func to_system(w: SphereWorld, p: Vector3) -> Vector3:
	return position(Game.planet_index(w.pid)) + frame(w).inverse() * p


static func to_local(w: SphereWorld, sp: Vector3) -> Vector3:
	return frame(w) * (sp - position(Game.planet_index(w.pid)))
