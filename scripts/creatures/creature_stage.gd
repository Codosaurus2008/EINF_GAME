class_name CreatureStage
extends SubViewportContainer
## A small lit 3D stage that shows one creature on a hex pedestal: key, fill and rim light,
## a soft sky for reflections on the metal, slow turntable, drag with the mouse to turn it.

signal clicked

var vp: SubViewport
var pivot: Node3D
var cam: Camera3D
var model: CreatureModel
var rim_light: DirectionalLight3D
var turntable := true
var yaw := -0.6
var dragging := false
var drag_moved := 0.0
var cam_height := 0.6
var cam_dist := 3.0


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#1a1f3a")
	sm.sky_horizon_color = Color("#3a3550")
	sm.ground_bottom_color = Color("#0c0a12")
	sm.ground_horizon_color = Color("#2a2434")
	sky.sky_material = sm
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#141629")
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a8fc0")
	env.ambient_light_energy = 0.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffe8cc")
	key.light_energy = 1.25
	key.shadow_enabled = true
	key.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-35), 0)
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#9fb8ff")
	fill.light_energy = 0.3
	fill.rotation = Vector3(deg_to_rad(-20), deg_to_rad(120), 0)
	vp.add_child(fill)
	rim_light = DirectionalLight3D.new()
	rim_light.light_energy = 0.9
	rim_light.rotation = Vector3(deg_to_rad(-15), deg_to_rad(180), 0)
	vp.add_child(rim_light)
	_pedestal()
	pivot = Node3D.new()
	vp.add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)


func _pedestal() -> void:
	var iron := CreatureLook.metal(CreatureLook.kit("ferrum"))
	var brass := CreatureLook.metal(CreatureLook.kit("pebble"), "metal2")
	var base := MeshInstance3D.new()
	base.mesh = CMesh.cyl(1.25, 1.35, 0.16, 6)
	base.material_override = iron
	base.position = Vector3(0, -0.08, 0)
	vp.add_child(base)
	var rim := MeshInstance3D.new()
	rim.mesh = CMesh.cyl(1.36, 1.36, 0.04, 6)
	rim.material_override = brass
	rim.position = Vector3(0, -0.13, 0)
	vp.add_child(rim)
	var ring := MeshInstance3D.new()
	ring.mesh = CMesh.ring(1.05, 1.1, 6)
	ring.material_override = CreatureLook.glow(Color("#58d8ff"), 1.2, 0.3)
	ring.position = Vector3(0, 0.005, 0)
	ring.rotation.y = PI / 6.0
	vp.add_child(ring)


func set_creature(m: CreatureModel) -> void:
	if model:
		model.queue_free()
	model = m
	pivot.add_child(m)
	# the rim light takes the colour of the creature's elements
	var c := Color.WHITE
	for e: String in m.elements:
		c = c.lerp(Color(CreatureLook.kit(e)["glow"]), 0.5)
	rim_light.light_color = c
	var box := bounds(m)
	cam_height = box.get_center().y
	var ext := maxf(box.size.y, maxf(box.size.x, box.size.z) * 0.8)
	cam_dist = maxf(1.6, ext * 2.3)
	_place_cam()


## Box around everything the creature is made of (its rest pose)
static func bounds(m: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.mesh is ImmediateMesh:
			continue
		var xf := m.global_transform.affine_inverse() * mi.global_transform
		var b := xf * mi.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	if first:
		return AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	return box


func play(s: String) -> void:
	if model:
		model.play(s)


func _place_cam() -> void:
	var target := Vector3(0, cam_height, 0)
	cam.position = target + Vector3(0, cam_dist * 0.32, cam_dist)
	cam.look_at(target, Vector3.UP)


func _process(delta: float) -> void:
	if turntable and not dragging:
		yaw += delta * 0.35
	pivot.rotation.y = yaw


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			dragging = true
			drag_moved = 0.0
		else:
			dragging = false
			if drag_moved < 6.0:
				clicked.emit()
		accept_event()
	var mm := event as InputEventMouseMotion
	if mm and dragging:
		yaw += mm.relative.x * 0.01
		drag_moved += absf(mm.relative.x) + absf(mm.relative.y)
		accept_event()
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		cam_dist = maxf(1.2, cam_dist * 0.9)
		_place_cam()
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		cam_dist = minf(9.0, cam_dist * 1.1)
		_place_cam()


func snapshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(path)
