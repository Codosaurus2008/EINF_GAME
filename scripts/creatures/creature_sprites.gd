class_name CreatureSprites
extends Node
## Shows the 3D creatures in the 2D screens (battle board, bench, army, hybreeding):
## every creature on screen gets a small transparent 3D picture of itself (own SubViewport),
## animated (idle / walk / attack / hurt). To stay fast, only a few pictures are re-rendered
## per frame (round robin) and pictures not shown for 2 seconds are thrown away.

const PER_FRAME := 8           # pictures re-rendered per frame
const KEEP := 2.0              # seconds a picture lives without being shown

static var _inst: CreatureSprites = null

var entries := {}              # key -> {vp, model, pose, used, px}
var queue: Array = []          # requests waiting to be built: [key, u, px]
var order: Array = []
var turn := 0
var clock := 0.0


static func inst() -> CreatureSprites:
	if _inst == null or not is_instance_valid(_inst):
		_inst = CreatureSprites.new()
		_inst.name = "CreatureSprites"
		var tree := Engine.get_main_loop() as SceneTree
		tree.root.add_child.call_deferred(_inst)
	return _inst


## Picture size (pixels) for a creature drawn with radius r on screen
static func px_for(r: float) -> int:
	var scale := float(DisplayServer.window_get_size().y) / 720.0
	var want := r * 3.4 * scale * 1.25
	for b: int in [96, 128, 192, 256, 384, 512]:
		if want <= b:
			return b
	return 640


static func tier_of(u: Dictionary) -> int:
	var lvl := int(u.get("lvl", 1))
	return 2 if lvl >= Game.TIER_LEVELS[2] else (1 if lvl >= Game.TIER_LEVELS[1] else 0)


## Draws the creature standing on point c (radius r). Returns false if the picture is not
## ready yet (then the caller draws something else this frame).
static func draw(ci: CanvasItem, u: Dictionary, c: Vector2, r: float, facing: float, pose: String) -> bool:
	var me := inst()
	var px := px_for(r)
	var species: Array = u["species"]
	var key := "%s|%s|%s|%d|%d" % [str(u.get("id", 0)), ",".join(species), str(u.get("umbra", false)), tier_of(u), px]
	if not me.entries.has(key):
		var waiting := false
		for q: Array in me.queue:
			if q[0] == key:
				waiting = true
		if not waiting:
			me.queue.append([key, u, px])
		return false
	var e: Dictionary = me.entries[key]
	e["used"] = me.clock
	var p := pose if pose != "" else "idle"
	if p != str(e["pose"]):
		e["pose"] = p
		var model: CreatureModel = e["model"]
		# a short attack / hit is played to the end, not cut off when the pose ends
		if p in ["attack", "hurt"] or not (model.state in ["attack", "hurt"]):
			model.play(p)
	var vp: SubViewport = e["vp"]
	var d := r * 3.4
	var anchor := c + Vector2(0, r * 0.95)
	var rect := Rect2(anchor - Vector2(d * 0.5, d * 0.86), Vector2(d, d))
	if facing < 0.0:
		rect.position.x += d
		rect.size.x = -d
	ci.draw_texture_rect(vp.get_texture(), rect, false)
	return true


func _process(delta: float) -> void:
	clock += delta
	# build a few waiting pictures
	var built := 0
	while not queue.is_empty() and built < 2:
		var q: Array = queue.pop_front()
		_build(str(q[0]), q[1], int(q[2]))
		built += 1
	# forget pictures nobody shows any more
	for key in entries.keys():
		var e: Dictionary = entries[key]
		if clock - float(e["used"]) > KEEP:
			(e["vp"] as SubViewport).queue_free()
			entries.erase(key)
			order.erase(key)
	# re-render a few pictures per frame, in turn
	if order.is_empty():
		return
	for i in mini(PER_FRAME, order.size()):
		turn = (turn + 1) % order.size()
		var vp: SubViewport = entries[order[turn]]["vp"]
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _build(key: String, u: Dictionary, px: int) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9096c8")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key_l := DirectionalLight3D.new()
	key_l.light_color = Color("#fff0dc")
	key_l.light_energy = 1.3
	key_l.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-60), 0)
	vp.add_child(key_l)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.8
	rim.rotation = Vector3(deg_to_rad(-15), deg_to_rad(150), 0)
	var c := Color.WHITE
	for e: String in u["species"]:
		c = c.lerp(Color(CreatureLook.kit(e)["glow"]), 0.5)
	rim.light_color = c
	vp.add_child(rim)
	var model := CreatureForge.build(u["species"], int(u.get("id", 0)), bool(u.get("umbra", false)), tier_of(u))
	vp.add_child(model)
	# side-on three-quarter view, the creature looking to the right of the picture
	var box := CreatureStage.bounds(model)
	var h := clampf(maxf(box.size.y, maxf(box.size.x, box.size.z) * 0.85) * 1.15, 1.4, 3.2)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = h
	vp.add_child(cam)
	var look := Vector3(box.get_center().x, h * 0.36, box.get_center().z)
	var dir := Vector3(-1.0, 0.32, 0.55).normalized()
	cam.position = look + dir * 6.0
	cam.look_at(look, Vector3.UP)
	entries[key] = {"vp": vp, "model": model, "pose": "idle", "used": clock, "px": px}
	order.append(key)
