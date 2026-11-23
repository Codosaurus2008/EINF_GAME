class_name CreatureModel
extends Node3D
## One built creature (made by CreatureForge) and all its movement: breathing, looking around,
## blinking, walking / running with feet planted on the ground (two-bone legs), swaying tails,
## antennae, tentacles and wings, turning gears and working pistons, glowing organs, elemental
## effects (frost, spores, water, embers, lightning arcs, light, dust, leaves).
## States: idle, walk, run, attack, hurt, defeat, special  (play(state)).
## The creature looks along +Z, the ground is y = 0.

var elements: Array = []
var size := 1.0                      # rough height of the creature (for the camera)
var state := "idle"
var state_t := 0.0
var t := 0.0
var rng := RandomNumberGenerator.new()

var body: Node3D                     # everything on the torso hangs on this
var body_rest := Vector3.ZERO
var hover := 0.0                     # floating height bob (floating creatures)
var head: Node3D
var head_rest := Basis()
var jaw: Node3D
var jaw_rest := Basis()
var legs: Array = []                 # {hip, knee, l1, l2, rest (foot, model space), side, ks, phase, lift}
var chains: Array = []               # {nodes, rest (bases), amp, speed, lag, axis, walk_amp, droop}
var wings: Array = []                # {pivot, rest, side, amp, speed}
var arms: Array = []                 # {shoulder, elbow, rest_s, rest_e, side}
var spinners: Array = []             # [node, axis, speed]
var pistons: Array = []              # [node, rest_pos, dir, amp, speed]
var grows: Array = []                # [node, rest_scale] - grow in the special move
var skin_mats: Array = []
var glow_mats: Array = []
var eye_mats: Array = []
var fx: Dictionary = {}              # element -> CPUParticles3D
var arc_points: Array = []           # nodes between which lightning jumps (Voltara)
var arc_mesh: MeshInstance3D
var arc_t := 0.0
var blink_t := 2.0
var look_t := 0.0
var look := Vector2.ZERO
var look_goal := Vector2.ZERO
var gait := 0.0
var stride := 0.22
var step_speed := 1.6


func play(s: String) -> void:
	state = s
	state_t = 0.0
	if s == "special":
		for k: String in fx:
			var p: CPUParticles3D = fx[k]
			p.speed_scale = 2.5


func _ready() -> void:
	rng.seed = hash(name) + 11


func _process(delta: float) -> void:
	t += delta
	state_t += delta
	var moving := 0.0
	match state:
		"walk": moving = 1.0
		"run": moving = 2.1
	gait += delta * step_speed * moving
	if state in ["attack", "hurt", "special"] and state_t > _duration(state):
		play("idle")
	_body(delta, moving)
	_legs()
	_chains(moving)
	_wings(moving)
	_arms()
	_head(delta)
	_spin(delta)
	_glows(delta)
	_arcs(delta)


func _duration(s: String) -> float:
	match s:
		"attack": return 0.95
		"hurt": return 0.55
		"special": return 1.8
	return 1.0


## Breathing, bobbing while walking, attack lunge, flinch, collapse
func _body(_delta: float, moving: float) -> void:
	if body == null:
		return
	var breath := sin(t * 1.7)
	var pos := body_rest + Vector3(0, breath * 0.012 * size, 0)
	var rot := Vector3.ZERO
	if hover > 0.0:
		pos.y += sin(t * 1.3) * hover
		rot.x = sin(t * 1.3 + 0.8) * 0.04
		rot.z = sin(t * 0.9) * 0.03
	if moving > 0.0:
		pos.y += absf(sin(gait * PI * 2.0)) * 0.025 * size * moving
		rot.z += sin(gait * PI * 2.0) * 0.03
		rot.x += 0.05 * moving
	var st := state_t
	match state:
		"attack":
			var wind := smoothstep(0.0, 0.3, st) * (1.0 - smoothstep(0.3, 0.42, st))
			var hit := smoothstep(0.3, 0.42, st) * (1.0 - smoothstep(0.5, 0.95, st))
			pos.z += (-0.12 * wind + 0.24 * hit) * size
			pos.y += 0.04 * wind * size
			rot.x += -0.18 * wind + 0.22 * hit
		"hurt":
			var k := exp(-st * 6.0)
			pos.z -= 0.12 * size * k
			pos.x += sin(st * 60.0) * 0.02 * size * k
			rot.x -= 0.2 * k
			for m: ShaderMaterial in skin_mats:
				m.set_shader_parameter("hit", k)
		"defeat":
			var k2 := smoothstep(0.0, 1.0, st)
			pos.y = lerpf(pos.y, maxf(size * 0.18, body_rest.y * 0.3), k2) - hover * k2
			rot.z += 1.15 * k2
			rot.x += 0.2 * k2
		"special":
			var k3 := sin(clampf(st / 1.8, 0.0, 1.0) * PI)
			pos.y += 0.06 * size * k3
			rot.x -= 0.15 * k3
	if state != "hurt":
		for m: ShaderMaterial in skin_mats:
			m.set_shader_parameter("hit", 0.0)
	body.position = pos
	body.rotation = rot


## Feet stay on the ground: every leg is solved like a real two-joint leg
func _legs() -> void:
	var down := state == "defeat"
	for l: Dictionary in legs:
		var rest: Vector3 = l["rest"]
		var foot := rest
		if state in ["walk", "run"]:
			var u := fposmod(gait + float(l["phase"]), 1.0)
			var s := stride * (1.6 if state == "run" else 1.0)
			if u < 0.6:
				foot.z += lerpf(s, -s, u / 0.6)
			else:
				var w := (u - 0.6) / 0.4
				foot.z += lerpf(-s, s, smoothstep(0.0, 1.0, w))
				foot.y += float(l["lift"]) * sin(w * PI) * (1.4 if state == "run" else 1.0)
		elif state == "attack" and l.get("front", false):
			foot.z += 0.08 * smoothstep(0.3, 0.45, state_t) * (1.0 - smoothstep(0.6, 0.95, state_t))
		if down:
			# legs fold under the falling body
			var k := smoothstep(0.0, 1.0, state_t)
			foot = foot.lerp(Vector3(foot.x * 1.4, 0.0, foot.z * 0.6), k)
		_solve(l, to_global(foot))


func _solve(l: Dictionary, target: Vector3) -> void:
	var hip: Node3D = l["hip"]
	var knee: Node3D = l["knee"]
	var l1 := float(l["l1"])
	var l2 := float(l["l2"])
	var h := hip.global_position
	var v := target - h
	var d := clampf(v.length(), 0.01, (l1 + l2) * 0.999)
	var dn := v.normalized() if v.length() > 0.0001 else -global_basis.y
	var side: Vector3 = global_basis * Vector3(l["side"])
	var ax := side - dn * side.dot(dn)
	if ax.length() < 0.001:
		return
	ax = ax.normalized()
	var ks := float(l["ks"])
	var a := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var thigh := dn.rotated(ax, a * ks)
	var kang := PI - acos(clampf((l1 * l1 + l2 * l2 - d * d) / (2.0 * l1 * l2), -1.0, 1.0))
	var y := -thigh
	var x := (ax - y * ax.dot(y)).normalized()
	var z := x.cross(y)
	var sc := global_basis.get_scale()
	hip.global_basis = Basis(x * sc.x, y * sc.y, z * sc.z)
	knee.basis = Basis(Vector3.RIGHT, -ks * kang)


## Tails, tentacles, antennae, roots, streamers: a wave that runs down the chain
func _chains(moving: float) -> void:
	var limp := state == "defeat"
	for c: Dictionary in chains:
		var nodes: Array = c["nodes"]
		var rests: Array = c["rest"]
		var n := nodes.size()
		var amp := float(c["amp"]) + float(c.get("walk_amp", 0.0)) * moving
		if state == "special":
			amp *= 1.8
		var sp := float(c["speed"]) * (1.0 + moving * 0.5)
		for i in n:
			var node: Node3D = nodes[i]
			var k := float(i + 1) / n
			var ph := t * sp - i * float(c["lag"]) + float(c.get("phase", 0.0))
			var yaw := sin(ph) * amp * k
			var pitch := cos(ph * 0.7) * amp * 0.35 * k + float(c.get("droop", 0.0)) * k
			if limp:
				yaw *= 0.2
				pitch += 0.25 * smoothstep(0.0, 1.0, state_t)
			var axis: Vector3 = c.get("axis", Vector3.UP)
			var rb: Basis = rests[i]
			node.basis = rb * Basis(axis, yaw) * Basis(Vector3.RIGHT, pitch)


func _wings(moving: float) -> void:
	for w: Dictionary in wings:
		var pv: Node3D = w["pivot"]
		var rb: Basis = w["rest"]
		var sp := float(w["speed"]) * (1.0 + moving * 0.6)
		var amp := float(w["amp"])
		var a := sin(t * sp) * amp
		match state:
			"attack": a = lerpf(a, -0.9, sin(clampf(state_t / 0.95, 0.0, 1.0) * PI))
			"special": a = sin(t * sp * 2.5) * amp * 1.5
			"defeat": a = lerpf(a, -0.7, smoothstep(0.0, 1.0, state_t))
		pv.basis = rb * Basis(Vector3.FORWARD, a * float(w["side"]))


func _arms() -> void:
	for a: Dictionary in arms:
		var s: Node3D = a["shoulder"]
		var e: Node3D = a["elbow"]
		var rs: Basis = a["rest_s"]
		var re: Basis = a["rest_e"]
		var sway := sin(t * 1.4 + float(a["side"])) * 0.08
		var lift := 0.0
		var bend := 0.0
		match state:
			"attack":
				var st := state_t
				lift = 0.7 * smoothstep(0.0, 0.3, st) * (1.0 - smoothstep(0.3, 0.45, st)) - 1.2 * smoothstep(0.3, 0.45, st) * (1.0 - smoothstep(0.55, 0.95, st))
				bend = 0.6 * smoothstep(0.0, 0.3, st) * (1.0 - smoothstep(0.3, 0.42, st))
			"defeat":
				lift = 0.5 * smoothstep(0.0, 1.0, state_t)
			"special":
				lift = -0.8 * sin(clampf(state_t / 1.8, 0.0, 1.0) * PI)
		s.basis = rs * Basis(Vector3.RIGHT, lift + sway)
		e.basis = re * Basis(Vector3.RIGHT, -bend - sway * 0.6)
	for p: Array in pistons:
		var node: Node3D = p[0]
		var rest: Vector3 = p[1]
		var dir: Vector3 = p[2]
		var k := sin(t * float(p[4])) * 0.5 + 0.5
		if state == "attack":
			k = smoothstep(0.25, 0.4, state_t) * (1.0 - smoothstep(0.5, 0.9, state_t))
		node.position = rest + dir * float(p[3]) * k


func _head(delta: float) -> void:
	if head == null:
		return
	look_t -= delta
	if look_t <= 0.0:
		look_t = rng.randf_range(1.5, 4.0)
		look_goal = Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.15, 0.2))
	look = look.lerp(look_goal, minf(1.0, delta * 2.5))
	var yaw := look.x
	var pitch := look.y + sin(t * 1.7) * 0.03
	var jaw_open := 0.0
	match state:
		"attack":
			pitch = lerpf(pitch, -0.25, smoothstep(0.0, 0.3, state_t)) * (1.0 - smoothstep(0.3, 0.45, state_t)) + 0.15 * smoothstep(0.3, 0.45, state_t)
			yaw *= 0.2
			jaw_open = smoothstep(0.15, 0.35, state_t) * (1.0 - smoothstep(0.5, 0.8, state_t))
		"hurt":
			pitch -= 0.3 * exp(-state_t * 5.0)
			yaw += sin(state_t * 30.0) * 0.1 * exp(-state_t * 5.0)
		"defeat":
			pitch = 0.5 * smoothstep(0.0, 1.0, state_t)
			yaw = 0.3
		"special":
			pitch = -0.35 * sin(clampf(state_t / 1.8, 0.0, 1.0) * PI)
			jaw_open = 0.6 * sin(clampf(state_t / 1.8, 0.0, 1.0) * PI)
	if state in ["walk", "run"]:
		yaw *= 0.3
	head.basis = head_rest * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)
	if jaw:
		jaw.basis = jaw_rest * Basis(Vector3.RIGHT, jaw_open * 0.6 + sin(t * 2.0) * 0.02)
	# blinking
	blink_t -= delta
	var b := 0.0
	if blink_t < 0.0:
		b = 1.0
		if blink_t < -0.13:
			blink_t = rng.randf_range(2.0, 5.0)
	if state == "defeat":
		b = smoothstep(0.3, 1.0, state_t)
	for m: ShaderMaterial in eye_mats:
		m.set_shader_parameter("blink", b)


func _spin(delta: float) -> void:
	var fast := 1.0
	match state:
		"walk": fast = 1.8
		"run": fast = 3.0
		"attack": fast = 3.0
		"special": fast = 5.0
		"defeat": fast = maxf(0.0, 1.0 - state_t)
	for s: Array in spinners:
		var node: Node3D = s[0]
		node.rotate_object_local(s[1], float(s[2]) * fast * delta)


func _glows(_delta: float) -> void:
	var dim := 1.0
	var boost := 0.0
	match state:
		"defeat": dim = lerpf(1.0, 0.12, smoothstep(0.0, 1.2, state_t))
		"special": boost = 2.2 * sin(clampf(state_t / 1.8, 0.0, 1.0) * PI)
		"attack": boost = 0.8 * smoothstep(0.25, 0.4, state_t) * (1.0 - smoothstep(0.45, 0.9, state_t))
	for m: ShaderMaterial in glow_mats:
		m.set_shader_parameter("dim", dim)
		m.set_shader_parameter("boost", boost)
	for m: ShaderMaterial in skin_mats:
		m.set_shader_parameter("dim", dim * (1.0 + boost * 0.6))
	for e: ShaderMaterial in eye_mats:
		e.set_shader_parameter("dim", dim)
	for g: Array in grows:
		var node: Node3D = g[0]
		var rs: Vector3 = g[1]
		var k := 1.0
		if state == "special":
			k = 1.0 + 0.45 * sin(clampf(state_t / 1.8, 0.0, 1.0) * PI)
		node.scale = rs * k
	for k2: String in fx:
		var p: CPUParticles3D = fx[k2]
		p.emitting = state != "defeat" or state_t < 0.4
		if state != "special":
			p.speed_scale = 1.0


## Little lightning arcs jumping between the conductive parts (Voltara)
func _arcs(delta: float) -> void:
	if arc_mesh == null or arc_points.size() < 2:
		return
	arc_t -= delta
	if arc_t > 0.0:
		return
	var busy := state in ["attack", "special"]
	arc_t = rng.randf_range(0.04, 0.09) if busy else rng.randf_range(0.06, 0.22)
	var im: ImmediateMesh = arc_mesh.mesh
	im.clear_surfaces()
	if state == "defeat" or (not busy and rng.randf() < 0.45):
		return
	var count := 3 if busy else 1
	var lines := PackedVector3Array()
	for c in count:
		var a: Node3D = arc_points[rng.randi() % arc_points.size()]
		var b: Node3D = arc_points[rng.randi() % arc_points.size()]
		if a == b:
			continue
		var pa := to_local(a.global_position)
		var pb := to_local(b.global_position)
		var prev := pa
		var steps := 7
		for i in range(1, steps + 1):
			var k := float(i) / steps
			var p := pa.lerp(pb, k)
			if i < steps:
				p += Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.05 * size
			lines.append(prev)
			lines.append(p)
			prev = p
	if lines.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for v: Vector3 in lines:
		im.surface_add_vertex(v)
	im.surface_end()
