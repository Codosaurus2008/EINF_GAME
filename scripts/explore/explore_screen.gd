class_name ExploreScreen
extends Control
## Exploring a freed planet: fly the capsule around the round world, land, get out and walk
## around on foot (first person), then get back in and take off again.
## Holds the SphereWorld, the Capsule, the Explorer (on foot), one camera that is either behind the
## capsule or at the explorer's eyes, and the interface: flight / time info, markers for points of
## interest, the "E" prompt, windows for animals / objects / sites, the quest log, back to the ship.

const REACH := 2.0                  # on foot: how close you must be to use something
const ENTER_REACH := 3.0            # on foot: how close to the capsule to get in
const SWITCH_TIME := 0.8            # seconds for the camera to move between capsule and eyes

var main: Node
var planet_n := 0
var pl: Dictionary
var pid := ""
var biome: Dictionary
var world: SphereWorld
var capsule: Capsule
var explorer: Explorer
var cam: Camera3D
var lamp: SpotLight3D
var mode := "capsule"               # capsule, foot, getting_out, getting_in
var switch_t := 0.0
var switch_from := Transform3D()
var target: Interactable = null
var near_unlanded: Interactable = null
var can_enter := false
var t := 0.0
var leaving := false
var arriving := 0.0                 # > 0 while the capsule flies down after arriving
var tour := false                   # test photo tour (main.gd F10): no saving, no mouse capture

var prompt_label: Label
var flight_label: Label
var gem_label: Label
var coin_label: Label
var found_label: Label
var toast: Label
var markers: Control
var chase_off := Vector3(0, 1, -3)    # camera position relative to the capsule (flight)
var lamp_fill: OmniLight3D
var plankton: CPUParticles3D
var cannon: Cannon
var aim := Vector3.ZERO           # where the capsule's cannon would hit (crosshair), ZERO = nothing in range
var window: Control = null          # open interaction window (mouse is free while it is open)
var quests: Control = null
var fade: ColorRect
var fade_text: Label
var fx_holder: Node3D                # weather particles follow the player (capsule or on foot)
var fx: Dictionary = {}             # particle kind -> [CPUParticles3D, fall speed]
var flashlight := "auto"            # auto (on at night), on, off  - key F
var held: Wildlife = null           # animal in your hands
var hold_yaw := 0.0
var hold_pitch := 0.3
var inspect_t := 0.0
var inspect_panel: PanelContainer
var inspect_label: Label
var haze_rect: ColorRect = null
var rain_sound: AudioStreamPlayer = null
var wind_sound: AudioStreamPlayer = null
var shake := 0.0
var ambient: AudioStreamPlayer
var engine_sound: AudioStreamPlayer = null
var first_person := false           # V switches; third person (see yourself) is the default
var view_k := 0.0                   # 0 = third person .. 1 = first person (smooth)
var tp_dist := 1.9                  # current third-person camera distance (shrinks near walls)
const TP_DIST := 1.9                 # (for the 60 cm explorer)
var nav_targets: Array = []         # navigator: [{name, pos, kind}]
var nav_i := 0                      # selected target (N = next, B = off)
var nav_on := true
var nav_t := 0.0
var banner: Label = null
var water_tint: ColorRect = null
var bubbles: CPUParticles3D = null
var perf_label: Label = null
var fps_label: Label = null          # always on: FPS, frame time, render resolution
var fps_hist: Array = []             # the last 2 s of frame times (for the average and the worst)
var res_t := 0.0
## adaptive: the 3D picture is drawn a little smaller when the computer can't keep up, sharp
## again when it can (F2 switches this off)
var render_scale := 1.0
var auto_scale := true
var perf_t := 0.0
var perf_frames := 0
var perf_worst := 0.0


var loader: LoadingScreen = null
var riding: Wildlife = null          # the animal you sit on (Q)
var ride_vel := Vector3.ZERO
var ride_alt := 0.0
var ready_done := false            # false while the planet is still being built (loading screen)


func _ready() -> void:
	pl = Game.planet(planet_n)
	pid = pl["id"]
	biome = Biomes.get_biome(pid)
	mouse_filter = Control.MOUSE_FILTER_IGNORE    # mouse moves steer / look
	# a steady 60 frames per second at most: even frame times instead of racing ahead and
	# dropping (and less heat on a laptop)
	Engine.max_fps = 60
	if not tour:
		loader = LoadingScreen.new()
		loader.setup(pl, biome)
		add_child(loader)
	_load()


func _follow_progress() -> void:
	if is_instance_valid(loader) and is_instance_valid(world):
		loader.set_progress(world.load_k * 0.92, world.load_text)


## The planet is built a little every frame while the loading screen shows the progress
func _load() -> void:
	world = SphereWorld.new()
	add_child(world)
	if loader:
		get_tree().process_frame.connect(_follow_progress)
	await world.build(pid)
	if not is_inside_tree():
		return
	if get_tree().process_frame.is_connected(_follow_progress):
		get_tree().process_frame.disconnect(_follow_progress)
	capsule = Capsule.new()
	capsule.world = world
	capsule.process_priority = -10        # moves before the camera follows it
	world.add_child(capsule)
	explorer = Explorer.new()
	explorer.world = world
	explorer.capsule = capsule
	explorer.process_priority = -10
	explorer.visible = false
	explorer.controls = false
	world.add_child(explorer)
	world.player = capsule
	cannon = Cannon.new()
	cannon.name = "Cannon"
	world.add_child(cannon)
	cannon.setup(world)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 6000.0
	world.add_child(cam)
	cam.make_current()
	# suit flashlight: follows where you look
	lamp = SpotLight3D.new()
	lamp.light_color = Color("#e8f6ff")
	# a wide beam with a soft edge (lights up a big area, falls off naturally with distance)
	lamp.spot_range = 30.0
	lamp.spot_angle = 50.0
	lamp.spot_attenuation = 0.85
	lamp.spot_angle_attenuation = 1.6
	lamp.shadow_enabled = true
	lamp.light_energy = 0.0
	lamp.position = Vector3(0.2, -0.15, 0)
	cam.add_child(lamp)
	# spill light: the flashlight's glow around you (ground at your feet, plants beside you)
	lamp_fill = OmniLight3D.new()
	lamp_fill.light_color = Color("#e8f6ff")
	lamp_fill.omni_range = 5.0
	lamp_fill.omni_attenuation = 1.6
	lamp_fill.light_energy = 0.0
	lamp_fill.position = Vector3(0, 0.1, -0.6)
	cam.add_child(lamp_fill)
	capsule.impact.connect(_on_impact)
	Game.capsule_repaired.connect(_on_repaired)
	# weather particles: one emitter for every kind this planet's weather can have
	fx_holder = Node3D.new()
	capsule.add_child(fx_holder)
	var kinds := {}
	for w: Dictionary in Weather.KINDS.get(pid, []):
		for k: String in w["particles"]:
			kinds[k] = true
	if kinds.has("rain"):
		kinds["splash"] = true
	if pid in ["verdis", "mycelia", "aquora"]:
		kinds["fireflies"] = true
	for k: String in kinds:
		var p := Particles.weather(k)
		var g := absf(p.gravity.y)
		p.emitting = false
		fx_holder.add_child(p)
		fx[k] = [p, g]
	var saved_time = Game.dev_state(pid).get("time", null)
	if saved_time != null and not tour:
		world.phase = float(saved_time)
	_place_capsule()
	world.viewer = cam.global_position
	_update_camera(0.0, true)
	_sounds()
	_build_hud()
	_nav_build()
	Game.changed.connect(_refresh)
	_refresh()
	ready_done = true
	if tour:
		fade.color = Color(0, 0, 0, 0)
		capsule.controls = false
		return
	fade.color = Color(0, 0, 0, 0)
	fade_text.modulate.a = 0.0
	# let the ground, plants and animals right around you appear before the curtain lifts
	move_child(loader, -1)
	loader.set_progress(0.93, "Preparing the graphics")
	_update_camera(0.0, true)
	world.viewer = cam.global_position
	await world.warm_up(cam)
	if not is_inside_tree():
		return
	var hold := arriving
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		loader.set_progress(0.92 + 0.08 * clampf((Time.get_ticks_msec() - t0) / 1500.0, 0.0, 1.0), "Landing")
		var busy := not world.spawn_queue.is_empty() or not world.terrain_lod.jobs.is_empty()
		if world.ground_layer and not world.ground_layer.jobs.is_empty():
			busy = true
		if not busy and Time.get_ticks_msec() - t0 > 600:
			break
		await get_tree().process_frame
		if not is_inside_tree():
			return
	arriving = hold
	loader.finish()
	loader = null
	_capture(true)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_viewport().scaling_3d_scale = 1.0
	Engine.max_fps = 0
	if ready_done and is_instance_valid(capsule) and not leaving and not tour:
		_save_state()


## Capsule (and the explorer, if on foot) and the time of day are saved per planet
func _save_state() -> void:
	var on_foot := mode == "foot" or mode == "getting_out"
	Game.dev_state(pid)["time"] = world.phase
	Game.set_explore_pos(pid, capsule.position, capsule.heading, on_foot, explorer.position, explorer.heading)


## Back where the capsule (and you) were last time, or flying down to the landing place
func _place_capsule() -> void:
	var saved: Array = [] if tour else Game.explore_pos(pid)
	if saved.size() >= 6:
		var p := Vector3(float(saved[0]), float(saved[1]), float(saved[2]))
		var h := Vector3(float(saved[3]), float(saved[4]), float(saved[5]))
		var r := maxf(p.length(), world.floor_radius(p) + Capsule.HOVER + 0.5)
		capsule.place(p.normalized() * r, h)
		if saved.size() == 12:
			# you were walking: the capsule is parked, you stand where you were
			capsule.place(p.normalized() * (world.floor_radius(p) + Capsule.HOVER), h)
			capsule.landed = true
			explorer.place(Vector3(float(saved[6]), float(saved[7]), float(saved[8])), Vector3(float(saved[9]), float(saved[10]), float(saved[11])))
			_set_mode("foot")
		return
	var d := world.landing_dir
	var fwd := SphereTerrain.surface_basis(d, 0.0).z
	capsule.place(d * (world.floor_radius(d) + 45.0), fwd)
	capsule.pitch = -0.35
	if not tour:
		arriving = 2.2
		capsule.controls = false


# ================================================================== capsule <-> on foot
## Only one of the two can be controlled at a time
func _set_mode(m: String) -> void:
	mode = m
	var walking := m == "foot"
	var flying := m == "capsule"
	explorer.visible = m == "foot" or m == "getting_out"
	explorer.controls = walking and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and window == null and quests == null
	capsule.controls = flying and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and window == null and quests == null and arriving <= 0.0
	world.player = explorer if (walking or m == "getting_out") else capsule
	if is_instance_valid(fx_holder):
		fx_holder.reparent(explorer if world.player == explorer else capsule, false)


func _get_out() -> void:
	if not capsule.landed or mode != "capsule":
		return
	# step out next to the door (right side), or wherever there is room
	var u := capsule.up()
	var spot := Vector3.ZERO
	for side: Vector3 in [capsule.right(), -capsule.right(), -capsule.heading, capsule.heading]:
		var p := capsule.position + side * 1.5
		if not world.walk_blocked(p) and world.terrain.slope(p) < 0.5:
			spot = p
			break
	if spot == Vector3.ZERO:
		show_toast("No room to get out here.", UI.ORANGE)
		return
	switch_from = cam.global_transform
	explorer.place(spot - u * 0.5, capsule.heading)
	switch_t = 0.0
	_set_mode("getting_out")
	show_toast("You climb out of the capsule.", UI.CYAN)


func _get_in() -> void:
	if mode != "foot":
		return
	switch_from = cam.global_transform
	switch_t = 0.0
	_set_mode("getting_in")


# ================================================================== sound
func _load_loop(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStreamWAV
	if s:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	return s


func _sounds() -> void:
	ambient = AudioStreamPlayer.new()
	ambient.stream = _load_loop("res://audio/ambient/%s.wav" % str(biome["sound"]))
	ambient.volume_db = -5.0
	add_child(ambient)
	if ambient.stream:
		ambient.play()
	var eng := _load_loop("res://audio/ambient/engine.wav")
	if eng:
		engine_sound = AudioStreamPlayer.new()
		engine_sound.stream = eng
		engine_sound.volume_db = -20.0
		add_child(engine_sound)
		engine_sound.play()
	var rs := _load_loop("res://audio/ambient/rain.wav")
	if rs:
		rain_sound = AudioStreamPlayer.new()
		rain_sound.stream = rs
		rain_sound.volume_db = -60.0
		add_child(rain_sound)
		rain_sound.play()
	var ws := _load_loop("res://audio/ambient/wind.wav")
	if ws:
		wind_sound = AudioStreamPlayer.new()
		wind_sound.stream = ws
		wind_sound.volume_db = -60.0
		add_child(wind_sound)
		wind_sound.play()
	if ResourceLoader.exists("res://audio/ambient/thunder.wav"):
		var th := AudioStreamPlayer.new()
		th.stream = load("res://audio/ambient/thunder.wav")
		add_child(th)
		world.thunder = th


# ================================================================== interface
func _build_hud() -> void:
	markers = Control.new()
	markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	markers.draw.connect(_draw_markers)
	add_child(markers)
	if biome.has("heat_haze"):
		var haze := ColorRect.new()
		haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
		haze.material = ExploreShaders.material("haze", {"strength": float(biome["heat_haze"])})
		haze_rect = haze
		add_child(haze)
		move_child(haze, 0)

	var info := VBoxContainer.new()
	info.position = Vector2(18, 14)
	info.add_theme_constant_override("separation", 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	var name_l := UI.label(pl["name"], 26, Color(pl["accent"]).lerp(UI.TEXT, 0.3))
	_shadow(name_l, 2)
	info.add_child(name_l)
	var g := float(biome["gravity"]) / 9.8
	var sub := UI.label("%s  ·  %s  ·  gravity %.1f g" % [pl["kind"], biome["temp"], g], 14, UI.TEXT)
	_shadow(sub)
	info.add_child(sub)
	found_label = UI.label("", 14, UI.GOLD)
	_shadow(found_label)
	info.add_child(found_label)

	var money := UI.panel(UI.GOLD)
	(money.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(8)
	money.position = Vector2(1100, 12)
	money.custom_minimum_size = Vector2(164, 0)
	money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(money)
	var row: Array = UI.currency_row(22.0, 17)
	money.add_child(row[0])
	coin_label = row[1]
	gem_label = row[2]

	flight_label = UI.label("", 16, UI.CYAN)
	flight_label.position = Vector2(18, 640)
	_shadow(flight_label)
	add_child(flight_label)
	var keys := UI.label("", 14, UI.TEXT)
	keys.name = "Keys"
	keys.position = Vector2(18, 668)
	_shadow(keys)
	add_child(keys)
	var keys2 := UI.label("E use / get in & out  ·  G pick up  ·  F flashlight  ·  R repair  ·  J quests  ·  T ship  ·  F7 time  ·  F8 weather (test)", 14, UI.GOLD)
	keys2.position = Vector2(18, 692)
	_shadow(keys2)
	add_child(keys2)

	prompt_label = UI.label("", 18, UI.TEXT)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(340, 560)
	prompt_label.size = Vector2(600, 30)
	_shadow(prompt_label)
	add_child(prompt_label)

	toast = UI.label("", 19, UI.GOLD)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector2(240, 120)
	toast.size = Vector2(800, 30)
	toast.modulate.a = 0.0
	_shadow(toast)
	add_child(toast)

	inspect_panel = UI.panel(Color(pl["accent"]).lerp(UI.CYAN, 0.4))
	inspect_panel.position = Vector2(900, 120)
	inspect_panel.custom_minimum_size = Vector2(360, 0)
	inspect_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect_panel.visible = false
	add_child(inspect_panel)
	inspect_label = UI.wrap_label("", 14, UI.TEXT, 330)
	inspect_panel.add_child(inspect_label)

	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	fade_text = UI.label("", 30, UI.TEXT)
	fade_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade_text.position = Vector2(240, 340)
	fade_text.size = Vector2(800, 40)
	add_child(fade_text)


func _shadow(l: Label, off := 1) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", off)
	l.add_theme_constant_override("shadow_offset_y", off)


func _refresh() -> void:
	gem_label.text = str(Game.gems)
	coin_label.text = str(Game.coins)
	var keys: Array = []
	for id: String in world.species_ids:
		keys.append("animal:" + id)
	for o in world.objects:
		keys.append(o.key)
	var n := 0
	for k in keys:
		if Game.is_found(pid, k):
			n += 1
	found_label.text = "Discovered %d / %d" % [n, keys.size()]


func show_toast(text: String, col := UI.GOLD) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color", col)
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(toast, "modulate:a", 0.0, 0.8)


## Points of interest: [position, text, colour]
func _pois() -> Array:
	var out: Array = []
	for s: BuildSite in world.sites:
		var built := not s.building().is_empty()
		out.append([s.position, "Gem Mine" if built else "Construction site", UI.GREEN if built else UI.GOLD])
	for o: FieldObject in world.objects:
		var found := Game.is_found(pid, o.key)
		out.append([o.position, o.title if found else "Something unusual  ?", UI.CYAN if found else Color("#c48bff")])
	for h: Array in world.habitats:
		out.append([h[0], "%s habitat" % h[1], Color("#7dffb0")])
	return out


# ================================================================== the capsule's cannon
## Where the crosshair points: the ground / sea along the camera's view, within range
func _update_aim() -> void:
	aim = Vector3.ZERO
	if mode != "capsule" or capsule.crashed():
		return
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	aim = Cannon.ray_ground(world, from, dir, Cannon.RANGE + from.distance_to(capsule.position))
	# hold the button for steady fire
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and window == null and quests == null and cannon.ready_to_fire():
		_fire()


func _fire() -> void:
	if mode != "capsule" or window != null or quests != null or arriving > 0.0 or leaving:
		return
	if capsule.crashed():
		show_toast("The cannon is damaged - repair the capsule first (R).", UI.ORANGE)
		return
	var muzzle := capsule.position + capsule.nose() * 0.75 - capsule.up() * 0.08
	var target := aim
	if target == Vector3.ZERO:
		target = cam.global_position - cam.global_transform.basis.z * Cannon.RANGE
	# never into the capsule itself: aim points behind the nose are fired straight ahead
	if (target - muzzle).dot(capsule.nose()) < -0.5:
		target = muzzle + capsule.nose() * 50.0
	if cannon.fire(muzzle, target, capsule.vel):
		shake = maxf(shake, 0.12)


func _draw_crosshair() -> void:
	var c := Vector2(640, 360)
	var can_shoot := cannon.ready_to_fire()
	var col := Color(1.0, 0.45, 0.3, 0.95) if aim != Vector3.ZERO else Color(1, 1, 1, 0.55)
	var g := 7.0
	for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		markers.draw_line(c + d * g, c + d * (g + 9.0), Color(0, 0, 0, 0.5), 3.0, true)
		markers.draw_line(c + d * g, c + d * (g + 9.0), col, 1.6, true)
	markers.draw_circle(c, 1.8, col)
	# reload ring
	var k := 1.0 - cannon.cooldown / Cannon.INTERVAL
	markers.draw_arc(c, 19.0, -PI / 2, -PI / 2 + TAU * k, 40, Color(col, 0.8 if can_shoot else 0.4), 2.0, true)
	if aim != Vector3.ZERO:
		var dist := capsule.position.distance_to(aim)
		var font := UI.font()
		var txt := "%d m" % int(dist)
		markers.draw_string(font, c + Vector2(25, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.7))
		markers.draw_string(font, c + Vector2(24, 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)


func _draw_markers() -> void:
	if window != null or quests != null:
		return
	if nav_on and not nav_targets.is_empty():
		_draw_navigator()
	if mode == "capsule" and not capsule.crashed() and arriving <= 0.0:
		_draw_crosshair()
	if mode == "foot":
		_draw_locator()
		markers.draw_circle(Vector2(640, 360), 2.5, Color(1, 1, 1, 0.8) if target == null else UI.GOLD)
		if target or can_enter:
			markers.draw_arc(Vector2(640, 360), 11.0 + sin(t * 5.0) * 1.5, 0, TAU, 32, Color(UI.GOLD, 0.9), 2.0, true)
	var font := UI.font()
	var cp := cam.global_position
	for poi: Array in _pois():
		var p: Vector3 = poi[0]
		var dist := cp.distance_to(p)
		if dist > 420.0 or dist < 6.0 or cam.is_position_behind(p):
			continue
		if _hidden_by_planet(cp, p):
			continue
		var sp := cam.unproject_position(p + p.normalized() * 3.0)
		# the interface is drawn at 1280 x 720; the 3D view may be bigger
		sp *= Vector2(1280, 720) / get_viewport().get_visible_rect().size
		var col: Color = poi[2]
		var a := clampf(1.3 - dist / 420.0, 0.35, 1.0)
		var pts := PackedVector2Array([sp + Vector2(0, -9), sp + Vector2(7, 0), sp + Vector2(0, 9), sp + Vector2(-7, 0), sp + Vector2(0, -9)])
		markers.draw_polyline(pts, Color(col, a), 2.0, true)
		markers.draw_circle(sp, 2.5, Color(col, a))
		var txt := "%s   %d m" % [poi[1], int(dist)]
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		markers.draw_string(font, sp + Vector2(-w / 2 + 1, -15), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.8 * a))
		markers.draw_string(font, sp + Vector2(-w / 2, -16), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col.lerp(Color.WHITE, 0.4), a))



## Capsule locator (on foot): a marker above the capsule when you can see it, otherwise an arrow
## at the edge of the screen pointing the way along the planet's surface, always with the distance.
func _draw_locator() -> void:
	var col := Color("#7ff5ff")
	var font := UI.font()
	var cp := capsule.position + capsule.up() * 1.6
	var e := cam.global_position
	var u := explorer.up()
	var walk := int(explorer.position.angle_to(capsule.position) * world.radius)
	var label := "CAPSULE  %d m" % walk
	var on_screen := false
	var sp := Vector2.ZERO
	if not cam.is_position_behind(cp) and not _hidden_by_planet(e, cp):
		sp = cam.unproject_position(cp) * Vector2(1280, 720) / get_viewport().get_visible_rect().size
		on_screen = Rect2(30, 30, 1220, 660).has_point(sp)
	if on_screen:
		var pulse := 1.0 + sin(t * 4.0) * 0.12
		var pts := PackedVector2Array([sp + Vector2(0, -12) * pulse, sp + Vector2(10, 0) * pulse, sp + Vector2(0, 12) * pulse, sp + Vector2(-10, 0) * pulse, sp + Vector2(0, -12) * pulse])
		markers.draw_polyline(pts, col, 2.5, true)
		markers.draw_circle(sp, 3.0, col)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		markers.draw_string(font, sp + Vector2(-w / 2 + 1, -19), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.8))
		markers.draw_string(font, sp + Vector2(-w / 2, -20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
		return
	# direction along the ground (works from any side of the planet)
	var v := capsule.position - explorer.position
	v -= u * v.dot(u)
	if v.length() < 0.01:
		v = explorer.heading
	var ang := explorer.heading.signed_angle_to(v.normalized(), u)
	var dir := Vector2(-sin(ang), -cos(ang))
	var c := Vector2(640, 360)
	var edge := c + Vector2(dir.x * 560.0, dir.y * 290.0)
	var tip := edge + dir * 16.0
	var side := Vector2(-dir.y, dir.x)
	markers.draw_colored_polygon(PackedVector2Array([tip, edge - dir * 4.0 + side * 11.0, edge - dir * 4.0 - side * 11.0]), Color(col, 0.9))
	markers.draw_circle(edge - dir * 24.0, 9.0, Color(0.03, 0.06, 0.15, 0.75))
	markers.draw_arc(edge - dir * 24.0, 9.0, 0, TAU, 20, col, 2.0, true)
	var w2 := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var lp := edge - dir * 50.0 - Vector2(w2 / 2, -5)
	markers.draw_string(font, lp + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.8))
	markers.draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)


# ================================================================== objective navigator
## Places worth finding: the Mycelia valley, unusual objects (incl. the Umbra outpost),
## construction sites (quests), the nearest unknown animal species. N = next target, B = on / off.
func _nav_build() -> void:
	nav_targets.clear()
	if world.terrain.has_valley:
		var c := world.terrain.valley_dir(world.terrain.valley_center(0.0), 0.0)
		nav_targets.append({"name": "Mushroom valley", "pos": world.ground_point(c), "kind": "landmark", "col": Color("#ff6fb7")})
	if world.terrain.rain_r > 0.0:
		# the dense rainforest of Verdis: the navigator points to its middle
		nav_targets.insert(0, {"name": "Rainforest", "pos": world.ground_point(world.terrain.rain_c), "kind": "landmark", "col": Color("#4fd86a")})
	for o: FieldObject in world.objects:
		var found := Game.is_found(pid, o.key)
		nav_targets.append({"name": o.title if found else "Something unusual", "pos": o.position, "kind": "object", "col": Color("#c48bff")})
	for s2: BuildSite in world.sites:
		var built := not s2.building().is_empty()
		nav_targets.append({"name": "Gem Mine" if built else "Quest: construction site %d" % (s2.index + 1), "pos": s2.position, "kind": "quest", "col": UI.GOLD})
	nav_targets.append({"name": "Nearest unknown animal", "pos": Vector3.ZERO, "kind": "animal", "col": Color("#7dffb0")})


## The nearest group of a species you have not discovered yet (updated every second)
func _nav_animal() -> Vector3:
	var me := world.player_pos()
	var best := Vector3.ZERO
	var bd := INF
	for g: Dictionary in world.population:
		if Game.is_found(pid, "animal:" + str(g["id"])):
			continue
		var h: Vector3 = g["home"]
		var dd := h.distance_squared_to(me)
		if dd < bd:
			bd = dd
			best = h
	return best


func _nav_cycle(step: int) -> void:
	if nav_targets.is_empty():
		_nav_build()
	if not nav_on:
		nav_on = true
	else:
		nav_i = (nav_i + step + nav_targets.size()) % nav_targets.size()
	var tg: Dictionary = nav_targets[nav_i]
	show_toast("Navigator: %s   (N next · B off)" % tg["name"], tg["col"])


## Arrow at the screen edge (or a marker on the target), with the distance along the surface
## (great circle on the round planet, from wherever you are - walking, swimming or flying)
func _draw_navigator() -> void:
	var tg: Dictionary = nav_targets[nav_i % nav_targets.size()]
	var p: Vector3 = tg["pos"]
	if str(tg["kind"]) == "animal":
		nav_t -= get_process_delta_time()
		if nav_t <= 0.0 or not tg.has("cached"):
			nav_t = 1.0
			tg["cached"] = _nav_animal()
		p = tg["cached"]
		if p == Vector3.ZERO:
			return
	var col: Color = tg["col"]
	var me := world.player_pos()
	var dist := int(me.normalized().angle_to(p.normalized()) * world.radius)
	var label := "%s  %d m" % [str(tg["name"]).to_upper(), dist]
	var font := UI.font()
	var mark := p + p.normalized() * 2.0
	var e := cam.global_position
	if not cam.is_position_behind(mark) and not _hidden_by_planet(e, mark):
		var sp := cam.unproject_position(mark) * Vector2(1280, 720) / get_viewport().get_visible_rect().size
		if Rect2(30, 30, 1220, 660).has_point(sp):
			var pulse := 1.0 + sin(t * 3.0) * 0.15
			markers.draw_colored_polygon(PackedVector2Array([sp + Vector2(-9, -16) * pulse, sp + Vector2(9, -16) * pulse, sp]), Color(col, 0.9))
			markers.draw_arc(sp + Vector2(0, -22), 6.0, 0, TAU, 16, col, 2.0, true)
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			markers.draw_string(font, sp + Vector2(-w / 2 + 1, -33), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.8))
			markers.draw_string(font, sp + Vector2(-w / 2, -34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
			return
	# off screen: which way to turn, measured on the ground around you
	var u := me.normalized()
	var v := p - me
	v -= u * v.dot(u)
	var fwd := -cam.global_transform.basis.z
	fwd -= u * fwd.dot(u)
	if fwd.length() < 0.01:
		fwd = cam.global_transform.basis.y
		fwd -= u * fwd.dot(u)
	if v.length() < 0.01 or fwd.length() < 0.01:
		return
	var ang := fwd.normalized().signed_angle_to(v.normalized(), u)
	var dir := Vector2(-sin(ang), -cos(ang))
	var c := Vector2(640, 360)
	var edge := c + Vector2(dir.x * 540.0, dir.y * 270.0)
	var tip := edge + dir * 20.0
	var side := Vector2(-dir.y, dir.x)
	markers.draw_colored_polygon(PackedVector2Array([tip, edge - dir * 6.0 + side * 14.0, edge - dir * 6.0 - side * 14.0]), Color(col, 0.95))
	markers.draw_polyline(PackedVector2Array([tip, edge - dir * 6.0 + side * 14.0, edge - dir * 6.0 - side * 14.0, tip]), Color(0, 0, 0, 0.6), 1.5, true)
	var w2 := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var lp := edge - dir * 46.0 - Vector2(w2 / 2, -5)
	markers.draw_string(font, lp + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, 0.8))
	markers.draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)


## True if the planet is between the camera and p
func _hidden_by_planet(o: Vector3, p: Vector3) -> bool:
	var d := (p - o)
	var seg := d.length()
	d /= seg
	var r := world.radius - 2.0
	var b := o.dot(d)
	var c := o.dot(o) - r * r
	var h := b * b - c
	if h < 0.0:
		return false
	var t0 := -b - sqrt(h)
	return t0 > 0.0 and t0 < seg - 4.0


# ================================================================== input
## Mouse states (one rule for the whole planet view):
##   flying / walking / swimming, also while a planet is being prepared or handed over
##                         -> mouse captured, mouse-look and controls on
##   a window, the quest list, the pause / exit menu, leaving for the ship, the photo tour,
##   the game window not focused                -> mouse free (cursor visible)
## Nothing else may change the mouse: loading, rendering and planet hand-overs never do.
## Every frame the screen checks the rule and restores capture if it was lost.
func _capture(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
	capsule.controls = on and arriving <= 0.0 and mode == "capsule"
	explorer.controls = on and mode == "foot"


func _wants_mouse_free() -> bool:
	return window != null or quests != null or leaving or tour or get_tree().paused \
		or not get_window().has_focus()


## Called every frame: brings back mouse capture (and the controls) if anything lost it
func _keep_input_state() -> void:
	if _wants_mouse_free():
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture(true)
	elif mode == "capsule" and not capsule.controls and arriving <= 0.0:
		capsule.controls = true
	elif mode == "foot" and not explorer.controls:
		explorer.controls = true


func _notification(what: int) -> void:
	# the pause menu (Esc / Shift+Tab) needs the mouse
	if what == NOTIFICATION_PAUSED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_UNPAUSED and window == null and quests == null and not leaving and not tour:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Mouse / touchpad movement is read here, before the interface can swallow it
func _input(event: InputEvent) -> void:
	if leaving or tour or not ready_done or loader != null:
		return
	var mm := event as InputEventMouseMotion
	if mm and held and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		# turn the animal in your hands to look at it from all sides
		hold_yaw += mm.relative.x * 0.01
		hold_pitch = clampf(hold_pitch + mm.relative.y * 0.01, -1.4, 1.4)
		get_viewport().set_input_as_handled()
		return
	var wheel := event as InputEventMouseButton
	if wheel and held and wheel.pressed and (wheel.button_index == MOUSE_BUTTON_WHEEL_UP or wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		hold_yaw += 0.3 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else -0.3
		get_viewport().set_input_as_handled()
		return
	if mm and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and window == null and quests == null:
		if mode == "foot":
			explorer.look(mm.relative)
		elif mode == "capsule":
			capsule.steer(mm.relative)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if leaving or tour or not ready_done or loader != null:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and window == null and quests == null:
		_capture(true)
		return
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mode == "capsule":
		_fire()
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.physical_keycode:
		KEY_E:
			if window != null:
				close_window()
			elif quests != null:
				pass
			elif mode == "capsule":
				if capsule.surfing:
					show_toast("You can't get out on the water - surf to the beach first.", UI.ORANGE)
				elif capsule.landed:
					_get_out()
				else:
					show_toast("Land first: fly slowly close to flat ground and hold C.", UI.ORANGE)
			elif mode == "foot":
				if held or riding:
					pass
				elif target:
					target.interact(self)
				elif can_enter:
					_get_in()
		KEY_Q:
			if mode == "foot" and window == null and quests == null:
				if riding:
					_dismount()
				elif held == null and target is Wildlife:
					var tw := target as Wildlife
					if tw.rideable():
						_mount(tw)
					else:
						show_toast("The %s is too small to ride - only animals bigger than you." % tw.title, UI.ORANGE)
		KEY_G:
			if mode == "foot" and window == null and quests == null and riding == null:
				if held:
					_put_down()
				elif target is Wildlife:
					_pick_up(target as Wildlife)
		KEY_F12:
			_snap("shot")
		KEY_F2:
			auto_scale = not auto_scale
			if not auto_scale:
				render_scale = 1.0
				get_viewport().scaling_3d_scale = 1.0
			show_toast("Automatic render resolution %s" % ("ON (keeps the game smooth)" if auto_scale else "OFF (always full resolution)"), UI.CYAN)
		KEY_F3:
			if perf_label == null:
				perf_label = UI.label("", 15, UI.GREEN)
				perf_label.position = Vector2(12, 150)
				_shadow(perf_label)
				add_child(perf_label)
			else:
				perf_label.visible = not perf_label.visible
		KEY_F4:
			world.set_optimize(not SphereWorld.optimize)
			show_toast("Optimisations %s (test - compare FPS with F3)" % ("ON" if SphereWorld.optimize else "OFF"), UI.CYAN)
		KEY_X:
			if mode == "capsule":
				_fire()
		KEY_N:
			_nav_cycle(1)
		KEY_B:
			nav_on = not nav_on
			show_toast("Navigator %s" % ("on" if nav_on else "off"), UI.CYAN)
		KEY_V:
			first_person = not first_person
			show_toast("Camera: %s" % ("first person" if first_person else "third person"), UI.CYAN)
		KEY_F:
			flashlight = {"auto": "on", "on": "off", "off": "auto"}[flashlight]
			show_toast("Flashlight: %s" % {"auto": "automatic (on at night)", "on": "on", "off": "off"}[flashlight], UI.CYAN)
		KEY_R:
			if window == null and quests == null and (mode == "capsule" or (mode == "foot" and explorer.position.distance_to(capsule.position) < 6.0)):
				open_repair()
		KEY_F8:
			world.weather.next_kind()
			show_toast("Weather: %s (test)" % world.weather.current_name(), UI.CYAN)
		KEY_J:
			_toggle_quests()
		KEY_T:
			if window == null and quests == null:
				if mode == "capsule" and capsule.crashed():
					show_toast("The capsule can't fly - repair it first (R).", UI.ORANGE)
				elif mode == "capsule":
					open_return()
				else:
					show_toast("Walk back to your capsule first (E to get in).", UI.ORANGE)
		KEY_F7:
			# test: let the day pass faster to see sunset, night and sunrise
			world.time_scale = 1.0 if world.time_scale > 1.0 else 40.0
			show_toast("Time runs %s" % ("40x faster" if world.time_scale > 1.0 else "normally"), UI.CYAN)


# ================================================================== every frame
## Screenshots of the game for checking how things look (F12; and on a planet with a sea a few
## automatic ones after arriving): saved to user://screenshots/game/ (newest = *_latest.png)
var _snap_t := 0.0
var _snap_n := 0
func _snap(kind: String) -> void:
	var dir := "user://screenshots/game"
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	if img.get_width() > 1280:
		img.resize(1280, int(1280.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_BILINEAR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	img.save_png("%s/%s_%s.png" % [dir, kind, stamp])
	img.save_png("%s/%s_latest.png" % [dir, kind])
	if kind == "shot":
		show_toast("Screenshot saved", UI.CYAN)


func _process(delta: float) -> void:
	if not ready_done:
		return
	t += delta
	if world and world.water != null and _snap_n < 4 and loader == null:
		_snap_t += delta
		if _snap_t > 12.0 + _snap_n * 10.0:
			_snap_n += 1
			_snap("auto%d" % _snap_n)
	if arriving > 0.0 and loader == null:
		# automatic descent after arriving from the ship
		arriving -= delta
		var u := capsule.up()
		var alt := capsule.altitude()
		if alt > 7.0:
			capsule.position -= u * minf(alt - 6.0, delta * (alt * 1.6 + 2.0))
		capsule.pitch = lerpf(capsule.pitch, 0.0, delta * 1.5)
		if arriving <= 0.0:
			capsule.controls = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and mode == "capsule"
	if leaving:
		capsule.position += capsule.up() * delta * 40.0
	_keep_input_state()
	_update_camera(delta)
	world.viewer = cam.global_position
	_update_weather_fx()
	_update_underwater(delta)
	_perf(delta)
	_update_lights(delta)
	_update_held(delta)
	_update_ride(delta)
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 1.8)
		cam.global_position += Vector3(sin(t * 61.0), sin(t * 53.0), cos(t * 47.0)) * shake * 0.25
	if engine_sound:
		var vol := -26.0 + clampf(capsule.speed() / 30.0, 0.0, 1.0) * 14.0
		if capsule.landed or mode != "capsule":
			vol = -40.0
		engine_sound.volume_db = lerpf(engine_sound.volume_db, vol, delta * 3.0)
		engine_sound.pitch_scale = 0.8 + clampf(capsule.speed() / 40.0, 0.0, 0.8)
	_find_target()
	_update_aim()
	ExploreShaders.set_capsule(capsule.position if not capsule.crashed() else Vector3(0, -9999, 0))
	var keys := get_node_or_null("Keys") as Label
	var cond := "%s  ·  %s" % [world.time_name(), world.weather.current_name()]
	var hull_txt := ""
	if capsule.crashed():
		hull_txt = "   ·   CRASHED - press R to repair"
	elif capsule.hull() < 100.0:
		hull_txt = "   ·   hull %d%%" % int(capsule.hull())
	if riding:
		flight_label.text = "Riding a %s   ·   %s%s" % [riding.title, cond, hull_txt]
		if keys:
			keys.text = "Mouse look / steer  ·  W S forward / back  ·  A D sideways  ·  Shift faster%s  ·  Q get off" % ("  ·  Space up  ·  C down" if riding.flies() else "")
	elif mode == "foot":
		var how := "Under water  ·  depth %.1f m" % world.underwater if explorer.underwater() else ("Swimming" if explorer.swimming else ("On the sea floor" if explorer.water_state == "seabed" else "On foot"))
		flight_label.text = "%s   ·   %s%s" % [how, cond, hull_txt]
		if keys:
			if explorer.swimming:
				keys.text = "W swim where you look  ·  Space up  ·  Shift down / sink to the floor  ·  Ctrl faster  ·  G carry  ·  V camera  ·  N navigator"
			elif explorer.water_state == "seabed":
				keys.text = "Walking on the bottom  ·  WASD walk  ·  Space swim up  ·  G carry  ·  V camera  ·  N navigator"
			else:
				keys.text = "WASD walk  ·  Space jump  ·  Shift run  ·  V first / third person  ·  N navigator target  ·  B navigator on / off"
	else:
		var status := "LANDED  ·  E to get out" if capsule.landed else ("ON WATER  ·  W to surf, Space to take off" if capsule.surfing else "Flying")
		flight_label.text = "%s   ·   height %d m   ·   speed %d m/s   ·   %s%s" % [status, int(capsule.altitude()), int(capsule.speed()), cond, hull_txt]
		if keys:
			keys.text = "Mouse / arrows steer  ·  W S thrust  ·  A D slide  ·  Space up  ·  C down / land  ·  Shift boost  ·  Left mouse / X fire  ·  T ship / other planets"
	markers.queue_redraw()


## Behind and above the capsule. The distance never depends on speed; it only grows a little
## when flying high inside the air (to see more of the land) and is the same close distance
## in space, so the capsule keeps its size on screen.
func _chase_transform() -> Transform3D:
	var u := capsule.view_up
	var r := capsule.right()
	var look_dir := capsule.heading.rotated(r, capsule.pitch * 0.6)
	var alt := capsule.altitude()
	var k := clampf((alt - 10.0) / 120.0, 0.0, 1.0)
	var dist := lerpf(3.4, 8.0, k)
	var want := capsule.position - look_dir * dist + u * lerpf(0.95, 2.6, k)
	var floor_r := world.floor_radius(want) + 0.6
	if want.length() < floor_r:
		want = want.normalized() * floor_r
	var focus := capsule.position + look_dir * 2.2 + u * 0.4
	return Transform3D(Basis.looking_at(focus - want, u), want)


func _eye_transform() -> Transform3D:
	var e := explorer.eye()
	return Transform3D(Basis.looking_at(explorer.look_dir(), explorer.up()), e)


## Behind and a little above the explorer, looking where they look. The camera moves closer
## when the ground, a rock or a tree is in the way (no looking through walls).
func _third_transform(delta: float) -> Transform3D:
	var u := explorer.up()
	var ld := explorer.look_dir()
	var pivot := explorer.position + u * lerpf(Explorer.HEIGHT * 0.9, 0.06, explorer.swim_k) + explorer.right() * 0.06
	# low behind the explorer: the land rises above you and the horizon is far away
	var back := (-ld + u * 0.2).normalized()
	var want_d := TP_DIST
	if riding:
		# further back on a big animal, so you see it and yourself
		want_d = TP_DIST + riding.size * 2.4
		back = (-ld + u * 0.35).normalized()
	var allowed := want_d
	for i in range(1, 11):
		var k := float(i) / 10.0
		var q := pivot + back * want_d * k
		var floor_r := world.walk_radius(q) + 0.08
		var blocked := q.length() < floor_r
		if not blocked:
			for o: Array in world.obstacles_near(q):
				if o.size() > 2 and int(o[2]) == 2:
					continue
				var c: Vector3 = o[0]
				var dq := q - c
				if dq.length_squared() < 900.0:
					var flat := dq - u * dq.dot(u)
					if flat.length() < float(o[1]) * 0.9 and dq.dot(u) < float(o[1]) * 4.0:
						blocked = true
						break
		if blocked:
			allowed = maxf(0.14, want_d * (k - 0.1))
			break
	# move in quickly when blocked, back out slowly
	tp_dist = lerpf(tp_dist, allowed, minf(1.0, delta * (14.0 if allowed < tp_dist else 3.0)))
	var pos := pivot + back * tp_dist
	var r := pos.length()
	var min_r := world.walk_radius(pos) + 0.05
	if r < min_r:
		pos = pos.normalized() * min_r
	var focus := pivot + ld * 0.9
	return Transform3D(Basis.looking_at(focus - pos, u), pos)


## On foot: third person, first person, or in between while switching (V)
func _foot_transform(delta: float) -> Transform3D:
	view_k = move_toward(view_k, 1.0 if first_person else 0.0, delta * 3.0)
	var k := smoothstep(0.0, 1.0, view_k)
	explorer.set_first_person(k > 0.85)
	if k >= 0.999:
		return _eye_transform()
	var a := _third_transform(delta)
	if k <= 0.001:
		return a
	var b := _eye_transform()
	return Transform3D(a.basis.orthonormalized().slerp(b.basis.orthonormalized(), k), a.origin.lerp(b.origin, k))


## Camera: behind the capsule, at the explorer's eyes, or moving smoothly between the two
func _update_camera(delta: float, snap := false) -> void:
	match mode:
		"capsule":
			# the view widens with the boost (feels faster)
			# the view widens only a little with the boost (the capsule keeps its size)
			var bk := clampf((capsule.boost_k - 1.0) / (Capsule.BOOST - 1.0), 0.0, 1.0)
			cam.fov = lerpf(66.0, 72.0, bk)
			var want := _chase_transform()
			var off_want := want.origin - capsule.position
			if snap:
				chase_off = off_want
			else:
				# the camera follows in the capsule's own frame: only the OFFSET to the capsule is
				# smoothed, never its position in the world - so at any speed (1100 m/s boost too)
				# the capsule stays at the same distance and place on the screen
				chase_off = chase_off.lerp(off_want, 1.0 - exp(-delta * 6.0))
				var want_l := off_want.length()
				var l := chase_off.length()
				if l > want_l * 1.15 or l < want_l * 0.7:
					chase_off = chase_off.normalized() * clampf(l, want_l * 0.7, want_l * 1.15)
			var p := capsule.position + chase_off
			var floor_r := world.floor_radius(p) + 0.4
			if p.length() < floor_r:
				p = p.normalized() * floor_r
			var focus := want.origin + (-want.basis.z) * 10.0
			cam.global_transform = Transform3D(Basis.looking_at(focus - p, capsule.view_up), p)
		"foot":
			cam.global_transform = _foot_transform(delta)
			cam.fov = lerpf(cam.fov, 70.0 if first_person else 62.0, minf(1.0, delta * 4.0))
		"getting_out", "getting_in":
			switch_t += delta / SWITCH_TIME
			var k := smoothstep(0.0, 1.0, minf(switch_t, 1.0))
			var to := _foot_transform(0.0) if mode == "getting_out" else _chase_transform()
			cam.global_transform = Transform3D(switch_from.basis.orthonormalized().slerp(to.basis.orthonormalized(), k), switch_from.origin.lerp(to.origin, k))
			if switch_t >= 1.0:
				if mode == "getting_out":
					_set_mode("foot")
				else:
					explorer.visible = false
					_set_mode("capsule")
					chase_off = cam.global_position - capsule.position
					show_toast("Back in the capsule.", UI.CYAN)


## What can be used right now
func _find_target() -> void:
	var best: Interactable = null
	near_unlanded = null
	can_enter = false
	if window == null and quests == null and not leaving and held == null:
		var cands: Array = world.animals + world.objects + world.sites
		if mode == "foot":
			# on foot: the closest thing in front of you
			var e := explorer.eye()
			var ld := explorer.look_dir()
			var best_score := 1e9
			for it: Interactable in cands:
				var to := it.global_position + it.global_position.normalized() * 0.6 - e
				var d := to.length()
				var reach := REACH + (0.6 if it is Wildlife else 0.0) + (1.5 if it is BuildSite else 0.0)
				if d > reach:
					continue
				var facing := ld.dot(to / maxf(d, 0.01))
				if facing < 0.55:
					continue
				var score := d * (2.0 - facing)
				if score < best_score:
					best_score = score
					best = it
			can_enter = best == null and explorer.position.distance_to(capsule.position) < ENTER_REACH
		elif mode == "capsule" and not capsule.landed:
			var best_d := 14.0
			for it: Interactable in cands:
				var d2 := capsule.position.distance_to(it.global_position)
				if d2 < best_d:
					best_d = d2
					near_unlanded = it
	target = best
	if held:
		prompt_label.text = "[G]  Put the %s down" % held.title
	elif target:
		prompt_label.text = "[E]  " + target.prompt()
		if target is Wildlife and (target as Wildlife).carry_reason() == "":
			prompt_label.text += "      [G]  Pick up"
	elif can_enter:
		prompt_label.text = "[E]  Get into the capsule"
	elif mode == "capsule" and capsule.landed:
		prompt_label.text = "[E]  Get out and walk"
	elif near_unlanded:
		prompt_label.text = "Land nearby (hold C close to the ground) to visit: %s" % near_unlanded.title
	else:
		prompt_label.text = ""


# ================================================================== weather, lights, holding animals
func _update_weather_fx() -> void:
	var w := world.weather
	var u := world.player_pos().normalized()
	var wind := w.wind_dir - u * w.wind_dir.dot(u)
	wind = wind.normalized() * w.wind * 4.0 if wind.length() > 0.01 else Vector3.ZERO
	for k: String in fx:
		var e: Array = fx[k]
		var p: CPUParticles3D = e[0]
		var amount := float(w.amounts.get(k, 0.0))
		if k == "splash":
			amount = float(w.amounts.get("rain", 0.0)) * (1.0 if mode == "foot" or capsule.landed else 0.0)
		elif k == "fireflies":
			amount = clampf((0.75 - world.daylight) * 2.0, 0.0, 1.0) * (1.0 - float(w.amounts.get("rain", 0.0)) * 0.8)
		p.color = Color(1, 1, 1, clampf(amount * 1.2, 0.0, 1.0))   # thinner weather = fainter particles
		p.emitting = amount > 0.01
		p.gravity = -u * float(e[1]) + wind * (0.25 if k == "rain" else (0.0 if k == "splash" else (0.15 if k == "fireflies" else 1.0)))
	if haze_rect:
		(haze_rect.material as ShaderMaterial).set_shader_parameter("strength", float(biome["heat_haze"]) * w.haze)
	if rain_sound:
		var r := float(w.amounts.get("rain", 0.0))
		rain_sound.volume_db = lerpf(rain_sound.volume_db, linear_to_db(maxf(r * 0.9, 0.001)), 0.05)
	if wind_sound:
		wind_sound.volume_db = lerpf(wind_sound.volume_db, linear_to_db(maxf(clampf(w.wind / 2.0, 0.0, 1.0) * 0.8, 0.001)), 0.05)


## F3: frames per second, frame time, draw calls; every 10 s also a line in the log
## (godot.log) so before / after can be compared
func _perf(delta: float) -> void:
	_fps_meter(delta)
	perf_t += delta
	perf_frames += 1
	perf_worst = maxf(perf_worst, delta)
	var fps := Engine.get_frames_per_second()
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var live := world.animals.size()
	if perf_label and perf_label.visible:
		perf_label.text = "FPS %d   ·   frame %.1f ms   ·   worst %.1f ms\ndraw calls %d   ·   objects %d   ·   triangles %dk\nanimals near %d   ·   nodes %d   ·   optimisations %s (F4)" % [
			fps, 1000.0 / maxf(fps, 1.0), perf_worst * 1000.0, draws, objs, prims / 1000, live, get_tree().get_node_count(), "ON" if SphereWorld.optimize else "OFF"]
	if perf_t >= 10.0:
		print("PERF %s %s opt=%s fps=%d avg_ms=%.1f worst_ms=%.1f draws=%d objects=%d tris=%dk animals=%d scale=%.2f rain=%.2f" % [pid, mode, str(SphereWorld.optimize), fps,
			perf_t / perf_frames * 1000.0, perf_worst * 1000.0, draws, objs, prims / 1000, live, render_scale, world.terrain.rain_k(world.viewer)])
		perf_t = 0.0
		perf_frames = 0
		perf_worst = 0.0


## The FPS counter (bottom right, always on) and the adaptive render resolution: when the
## average drops under 45 FPS the 3D picture is drawn at a slightly lower resolution (down to
## 70 %, the interface stays sharp); above 57 FPS it goes back up to full resolution
func _fps_meter(delta: float) -> void:
	if fps_label == null:
		fps_label = UI.label("", 14, UI.GREEN)
		fps_label.position = Vector2(1070, 694)
		_shadow(fps_label)
		add_child(fps_label)
	fps_hist.append(delta)
	var total := 0.0
	for d: float in fps_hist:
		total += d
	while total > 2.0 and fps_hist.size() > 1:
		total -= float(fps_hist[0])
		fps_hist.pop_front()
	var avg := total / maxf(fps_hist.size(), 1.0)
	var worst := 0.0
	for d2: float in fps_hist:
		worst = maxf(worst, d2)
	var fps := 1.0 / maxf(avg, 0.0001)
	fps_label.text = "%d FPS  ·  %.1f ms  (worst %.0f)  ·  3D %d%%%s" % [int(round(fps)), avg * 1000.0, worst * 1000.0, int(round(render_scale * 100.0)),
		("  ·  detail %d%%" % int(round(world.detail_k * 100.0))) if world.detail_k < 0.99 else ""]
	fps_label.add_theme_color_override("font_color", UI.GREEN if fps >= 50.0 else (UI.GOLD if fps >= 30.0 else UI.RED))
	if not auto_scale:
		return
	res_t += delta
	if res_t < 1.5 or fps_hist.size() < 20:
		return
	res_t = 0.0
	var want := render_scale
	if fps < 45.0:
		if render_scale > 0.71:
			want = maxf(0.7, render_scale - 0.1)
		else:
			# the resolution is already as low as it goes: draw ground detail and animals less far
			world.detail_k = maxf(0.6, world.detail_k - 0.1)
	elif fps > 57.0:
		if world.detail_k < 0.99:
			world.detail_k = minf(1.0, world.detail_k + 0.1)
		else:
			want = minf(1.0, render_scale + 0.05)
	if absf(want - render_scale) > 0.001:
		render_scale = want
		get_viewport().scaling_3d_scale = render_scale


## Under water: the picture turns blue-green and darker with depth, bubbles rise from the suit
func _update_underwater(delta: float) -> void:
	if water_tint == null:
		water_tint = ColorRect.new()
		water_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		water_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		water_tint.color = Color(0.05, 0.35, 0.45, 0.0)
		add_child(water_tint)
		move_child(water_tint, 0)
		bubbles = CPUParticles3D.new()
		bubbles.amount = 18
		bubbles.lifetime = 2.0
		bubbles.local_coords = false
		bubbles.direction = Vector3.UP
		bubbles.spread = 15.0
		bubbles.initial_velocity_min = 0.3
		bubbles.initial_velocity_max = 0.6
		bubbles.gravity = Vector3.ZERO
		bubbles.mesh = Particles.soft_quad(0.014)
		bubbles.material_override = Particles.material(Color(0.85, 0.97, 1.0, 0.7), true)
		bubbles.emitting = false
		explorer.add_child(bubbles)
		bubbles.position = Vector3(0, 0.5, 0)
		# tiny particles floating in the sea water around you (marine snow, plankton)
		plankton = CPUParticles3D.new()
		plankton.amount = 220
		plankton.lifetime = 6.0
		plankton.local_coords = false
		plankton.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		plankton.emission_sphere_radius = 3.0
		plankton.spread = 180.0
		plankton.initial_velocity_min = 0.02
		plankton.initial_velocity_max = 0.08
		plankton.gravity = Vector3.ZERO
		plankton.mesh = Particles.soft_quad(0.012)
		plankton.material_override = Particles.material(Color(0.85, 0.95, 1.0, 0.6), true)
		plankton.emitting = false
		add_child(plankton)
	var under := world.underwater > 0.0
	var depth_k := clampf(world.underwater / 25.0, 0.0, 1.0)
	var want := 0.0
	if under:
		want = 0.16 + depth_k * 0.3
	var look := world.water_look()
	var tint_c: Color = look[2]
	var deep_c: Color = look[1]
	water_tint.color = Color(tint_c.darkened(0.2).lerp(deep_c.darkened(0.6), depth_k), lerpf(water_tint.color.a, want, minf(1.0, delta * 6.0)))
	bubbles.emitting = mode == "foot" and explorer.underwater()
	plankton.emitting = under
	if under:
		plankton.global_position = cam.global_position
	bubbles.gravity = explorer.up() * 0.6


## Capsule headlights while you are in it, your flashlight while you walk - stronger in the dark
func _update_lights(delta: float) -> void:
	var dark := clampf(1.0 - world.daylight * (1.0 - world.weather.dark * 0.6), 0.0, 1.0)
	capsule.set_lights(mode == "capsule" and dark > 0.25, dark)
	var want := 0.0
	if mode == "foot":
		match flashlight:
			"on": want = 7.0
			"auto": want = 7.0 * smoothstep(0.3, 0.6, dark)
	# under water the light is bluer and does not reach as far (the water swallows it)
	var under := mode == "foot" and explorer.underwater()
	want *= 0.45 if not under else 0.5
	lamp.spot_range = lerpf(lamp.spot_range, 14.0 if under else 30.0, minf(1.0, delta * 4.0))
	lamp.light_color = Color("#bff4ff") if under else Color("#eef6ff")
	lamp.light_energy = lerpf(lamp.light_energy, want, minf(1.0, delta * 6.0))
	lamp.visible = lamp.light_energy > 0.05
	lamp_fill.light_energy = lamp.light_energy * 0.16
	lamp_fill.light_color = lamp.light_color
	lamp_fill.visible = lamp.visible


# ================================================================== riding
func _mount(w: Wildlife) -> void:
	if not is_instance_valid(w) or not w.rideable() or mode != "foot":
		return
	close_window()
	if held:
		_put_down()
	riding = w
	w.set_ridden(true)
	ride_vel = Vector3.ZERO
	ride_alt = maxf(0.0, w.position.length() - world.walk_radius(w.position))
	explorer.process_mode = Node.PROCESS_MODE_DISABLED
	explorer.heading = (w.heading - explorer.up() * w.heading.dot(explorer.up())).normalized()
	world.play_sfx("chirp", 0.6)
	show_toast("You climb onto the %s.  Q gets you off again." % w.title, UI.GOLD)


func _dismount() -> void:
	if riding == null:
		return
	var w := riding
	riding = null
	explorer.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(w):
		var u := w.position.normalized()
		var side := u.cross(w.heading).normalized()
		var spot := w.position + side * (w.size * 0.8 + 0.35)
		if world.walk_blocked(spot) or world.swim_depth(spot) > 0.3:
			spot = w.position - side * (w.size * 0.8 + 0.35)
		explorer.place(spot, explorer.heading)
		w.set_ridden(false)
		if w.flies():
			# a flyer lands you gently: from up high you would fall
			w.position = w.position.normalized() * (world.walk_radius(w.position) + 0.3)
	_set_mode("foot")


## Every frame while riding: the animal goes where you look (W / S / A / D), Shift makes it run;
## flyers also climb (Space) and sink (C). Land animals stay on the ground and stop at water,
## lava and walls they can't climb.
func _update_ride(delta: float) -> void:
	if riding == null:
		return
	if not is_instance_valid(riding) or mode != "foot":
		riding = null
		explorer.process_mode = Node.PROCESS_MODE_INHERIT
		return
	var w := riding
	var u := w.position.normalized()
	var free := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and window == null and quests == null
	var fwd := 0.0
	var side := 0.0
	var climb := 0.0
	var fast := false
	if free:
		fwd = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)) * 0.5
		side = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		fast = Input.is_physical_key_pressed(KEY_SHIFT)
		climb = float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_C))
	var h := explorer.heading - u * explorer.heading.dot(u)
	h = h.normalized() if h.length() > 0.01 else w.heading
	var right := u.cross(h).normalized()
	var top_speed := clampf(w.speed * 3.2, 2.2, 5.5) * (1.8 if fast else 1.0)
	if w.flies():
		top_speed *= 1.3
	var wish := (h * fwd - right * side)
	if wish.length() > 1.0:
		wish = wish.normalized()
	ride_vel = ride_vel.move_toward(wish * top_speed, (7.0 if fwd != 0.0 or side != 0.0 else 9.0) * delta)
	ride_vel -= u * ride_vel.dot(u)
	var nxt := w.position + ride_vel * delta
	var ground := world.walk_radius(nxt)
	if w.flies():
		ride_alt = clampf(ride_alt + climb * 2.5 * delta, 0.4, 28.0)
		nxt = nxt.normalized() * (ground + ride_alt)
	else:
		var here := world.walk_radius(w.position)
		var step := (nxt - w.position).length()
		var blocked := world.walk_blocked(nxt) or world.swim_depth(nxt) > w.size * 0.9
		if step > 0.0001 and ground - here > step * 1.3:
			blocked = true                       # too steep to climb
		if not blocked:
			for o: Array in world.obstacles_near(nxt):
				if o.size() > 2 and int(o[2]) == 2:
					continue
				var c: Vector3 = o[0]
				var dq := nxt - c
				var flat := dq - u * dq.dot(u)
				var rr := float(o[1]) + w.size * 0.35
				if flat.length() < rr and dq.dot(u) < float(o[1]) * 3.0:
					nxt += flat.normalized() * (rr - flat.length())
		if blocked:
			nxt = w.position
			ride_vel *= 0.3
		nxt = nxt.normalized() * world.walk_radius(nxt)
	w.position = nxt
	var nu := nxt.normalized()
	var mv := ride_vel - nu * ride_vel.dot(nu)
	if mv.length() > 0.2:
		w.heading = w.heading.slerp(mv.normalized(), minf(1.0, delta * 6.0)).normalized()
	w.heading = (w.heading - nu * w.heading.dot(nu)).normalized()
	w.moving = clampf(mv.length() / maxf(top_speed * 0.5, 0.1), 0.0, 1.0)
	w.basis = Basis(nu.cross(w.heading).normalized(), nu, w.heading)
	if w.plan == "hopper" and mv.length() > 0.3:
		w.hop = fmod(w.hop + delta * 2.2, 1.0)
	# you sit on its back
	explorer.position = nxt + nu * (w.seat_height() * 0.95)
	explorer.vel = Vector3.ZERO
	explorer.fall = 0.0
	explorer.on_ground = true
	var eh := explorer.heading - nu * explorer.heading.dot(nu)
	explorer.heading = eh.normalized() if eh.length() > 0.01 else w.heading
	explorer.basis = Basis(nu.cross(explorer.heading).normalized(), nu, explorer.heading)
	if mv.length() > 2.5 and fmod(t, 0.5) < delta:
		world.make_noise(nxt, 0.8)


func _pick_up(w: Wildlife) -> void:
	var why := w.carry_reason()
	if why != "":
		show_toast(why, UI.ORANGE)
		return
	held = w
	hold_yaw = 0.0
	hold_pitch = 0.3
	inspect_t = 0.0
	w.set_held(true)
	world.play_sfx("chirp", 0.7)
	inspect_panel.visible = true


func _put_down() -> void:
	if held == null:
		return
	var w := held
	var front := explorer.position + explorer.heading * 0.2
	var in_sea := explorer.sea_depth(front) > 0.2
	# land animals can't be let go in deep water
	if in_sea and not w.aquatic():
		show_toast("The %s can't swim - carry it back to land first." % w.title, UI.ORANGE)
		return
	held = null
	inspect_panel.visible = false
	w.set_held(false)
	if in_sea:
		w.position = front
		w.swim_goal = clampf(world.water_radius() - front.length(), 0.3, 6.0)
		w.swim_depth = w.swim_goal
		show_toast("You let the %s go - it swims away." % w.title, UI.CYAN)
	else:
		if world.walk_blocked(front) and explorer.sea_depth(front) <= 0.0:
			front = explorer.position
		w.position = world.ground_point(front)
		if w.aquatic():
			show_toast("The %s can't live on land - it flops back towards the water." % w.title, UI.ORANGE)
		else:
			show_toast("You set the %s down." % w.title, UI.CYAN)
	w.heading = -explorer.heading
	var wu := w.position.normalized()
	w.heading = (w.heading - wu * w.heading.dot(wu)).normalized()
	w.basis = Basis(wu.cross(w.heading).normalized(), wu, w.heading).orthonormalized()


## The held animal floats in front of the camera, a bit low and to the right
func _update_held(delta: float) -> void:
	if held == null:
		return
	if not is_instance_valid(held) or mode != "foot":
		_put_down()
		return
	var cb := cam.global_transform.basis
	if first_person:
		var s := clampf(0.24 / maxf(held.size * 1.1, 0.01), 0.25, 1.6)
		held.global_position = cam.global_position - cb.z * 0.5 - cb.y * 0.17 + cb.x * 0.08 - cb.y * held.size * s * 0.3
		held.basis = (cb * Basis(Vector3.UP, hold_yaw) * Basis(Vector3.RIGHT, hold_pitch)).scaled(Vector3.ONE * s)
	else:
		# in the explorer's arms, in front of the chest (does not block the view)
		var eb := explorer.basis
		var s2 := clampf(0.17 / maxf(held.size, 0.01), 0.3, 1.2)
		var chest := explorer.position + explorer.up() * Explorer.HEIGHT * (0.55 if not explorer.swimming else 0.0) + explorer.heading * 0.17
		held.global_position = chest - explorer.up() * held.size * s2 * 0.3
		held.basis = (eb * Basis(Vector3.UP, hold_yaw) * Basis(Vector3.RIGHT, hold_pitch * 0.3)).scaled(Vector3.ONE * s2)
	# inspection: after holding it for a moment you learn everything about it
	inspect_t += delta
	var sp: Dictionary = held.sp
	var known := Game.is_found(pid, "inspected:" + held.species_id)
	if not known and inspect_t > 2.5:
		Game.mark_found(pid, "inspected:" + held.species_id)
		Game.mark_found(pid, held.key)
		show_toast("Species inspected: %s" % held.title, UI.GREEN)
		known = true
	var txt := ""
	if known:
		txt = "%s\nNative to %s\n\n%s\n" % [held.title, pl["name"], sp["desc"]]
		for tr: String in sp.get("traits", []):
			txt += "\n·  " + tr
	else:
		txt = "Unknown species\nNative to %s\n\nInspecting...  %d%%" % [pl["name"], int(clampf(inspect_t / 2.5, 0.0, 1.0) * 100.0)]
	txt += "\n\nRight mouse + move / wheel: turn it   ·   G: put it down"
	inspect_label.text = txt


func _on_impact(kind: String, strength: float, message: String) -> void:
	shake = maxf(shake, clampf(strength * 0.15, 0.0, 1.0))
	if kind == "crash":
		shake = 1.6
		_banner("CAPSULE CRASHED!\nControls are dead.  Press R to repair (free and instant).", UI.RED)
	if message != "":
		var col := UI.GREEN if kind == "perfect" else (UI.RED if kind in ["crash", "failed"] else (UI.CYAN if kind == "info" else UI.ORANGE))
		show_toast(message, col)


func _banner(text: String, col: Color) -> void:
	if banner == null:
		banner = UI.label("", 30, col)
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.position = Vector2(140, 210)
		banner.size = Vector2(1000, 100)
		banner.add_theme_color_override("font_shadow_color", Color.BLACK)
		banner.add_theme_constant_override("shadow_offset_x", 3)
		banner.add_theme_constant_override("shadow_offset_y", 3)
		add_child(banner)
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	banner.modulate.a = 1.0
	banner.visible = true
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(banner, "modulate:a", 0.0, 1.0)


func _on_repaired() -> void:
	capsule.restore()
	show_toast("The capsule is repaired and ready to fly!", UI.GREEN)
	capsule.landed = not capsule.surfing


func open_repair() -> void:
	var c: Dictionary = Game.capsule
	var hull := float(c["hull"])
	if hull >= 100.0 and not bool(c["crashed"]):
		open_window("Capsule", "Hull 100%", "The capsule is in perfect shape.", [["OK", UI.GREY.lightened(0.4), close_window]], UI.CYAN)
		return
	var cost := int(Game.capsule_repair_price()[0])
	var title := "Capsule crashed" if bool(c["crashed"]) else "Capsule damaged"
	var body := "Hull: %d%%\n\nRepair price: %s.\nThe repair is done immediately." % [int(hull), "free" if cost == 0 else "%d coins (you have %d)" % [cost, Game.coins]]
	if bool(c["crashed"]):
		body = "The capsule can't fly until it is repaired.\n\n" + body
	var pay_cb: Variant = null
	if Game.coins >= cost:
		pay_cb = _start_repair
	else:
		body += "\n\nYou need %d more coins - win battles to earn them." % (cost - Game.coins)
	open_window(title, "Pay to repair", body, [
		["Repair now" + ("" if cost == 0 else " for %d coins" % cost), UI.GREEN, pay_cb],
		["Later", UI.GREY.lightened(0.4), close_window],
	], UI.ORANGE)


func _start_repair() -> void:
	var why := Game.start_capsule_repair()
	close_window()
	if why != "":
		show_toast(why, UI.RED)


# ================================================================== windows
## Opens the interaction window. buttons: [[text, colour, callable or null (= disabled)], ...]
func open_window(title: String, subtitle: String, body: String, buttons: Array, accent := UI.CYAN) -> void:
	close_window()
	_close_quests()
	var p := UI.panel(accent)
	p.position = Vector2(790, 150)
	p.custom_minimum_size = Vector2(440, 0)
	add_child(p)
	window = p
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	vb.add_child(UI.label(title, 24, accent.lerp(UI.TEXT, 0.25)))
	if subtitle != "":
		vb.add_child(UI.wrap_label(subtitle, 14, UI.GOLD, 410))
	vb.add_child(UI.wrap_label(body, 15, UI.TEXT, 410))
	for b: Array in buttons:
		var btn := UI.button(str(b[0]), b[1], Vector2(410, 40), 16)
		if b[2] == null:
			btn.disabled = true
		else:
			var cb: Callable = b[2]
			btn.pressed.connect(cb)
		vb.add_child(btn)
	vb.add_child(UI.label("E  close", 13, UI.SOFT))
	_capture(false)


func close_window() -> void:
	if is_instance_valid(window):
		window.queue_free()
	window = null
	if quests == null and not leaving and not get_tree().paused and not tour:
		_capture(true)


func open_animal(w: Wildlife) -> void:
	var is_new := Game.mark_found(pid, w.key)
	if is_new:
		show_toast("New species discovered: %s!" % w.title)
	open_window(w.title, _animal_sub(is_new), str(w.sp["desc"]), [
		["Observe", UI.CYAN, _observe_animal.bind(w)],
		["Ride  (Q)" if w.rideable() else "Too small to ride", UI.GOLD, _mount.bind(w) if w.rideable() else null],
		["Feed  (coming soon)", UI.GREEN, null],
		["Help  (coming soon)", UI.PINK, null],
		["Leave", UI.GREY.lightened(0.4), close_window],
	], pl["accent"])


func _animal_sub(is_new: bool) -> String:
	return "Native wildlife of %s%s" % [pl["name"], "  ·  NEW!" if is_new else ""]


func _observe_animal(w: Wildlife) -> void:
	var sp: Dictionary = w.sp
	var mood := "It watches you curiously." if bool(sp.get("curious", false)) else "It keeps its distance - move slowly (no running) to get close."
	var ways := {"walker": "Walks the ground", "hopper": "Hops across the ground", "floater": "Floats through the air",
		"flyer": "Flies low over the land", "swimmer": "Swims in the open sea"}
	var habitat := str(ways.get(str(sp["plan"]), ""))
	if habitat == "" and sp.has("traits"):
		var tr: Array = sp["traits"]
		habitat = str(tr[0]) if not tr.is_empty() else ""
	open_window(w.title, _animal_sub(false), "%s\n\n%s.  %s" % [sp["desc"], habitat, mood], [
		["Feed  (coming soon)", UI.GREEN, null],
		["Leave", UI.GREY.lightened(0.4), close_window],
	], pl["accent"])


func open_object(o: FieldObject) -> void:
	var is_new := Game.mark_found(pid, o.key)
	if is_new:
		show_toast("Discovered: %s!" % o.title)
	open_window(o.title, "Something unusual on %s%s" % [pl["name"], "  ·  NEW!" if is_new else ""], str(o.def["desc"]), [
		["Examine closely", UI.CYAN, _examine_object.bind(o)],
		["Collect a sample  (coming soon)", UI.GREEN, null],
		["Leave", UI.GREY.lightened(0.4), close_window],
	], pl["accent"])


func _examine_object(o: FieldObject) -> void:
	open_window(o.title, "Your scanner hums...", str(o.def["desc"]) + "\n\nThere is more to find out here. (Research comes in a later update.)", [
		["Leave", UI.GREY.lightened(0.4), close_window],
	], pl["accent"])


func open_site(s: BuildSite) -> void:
	var b := s.building()
	if not b.is_empty():
		var info: Dictionary = PlanetDev.BUILDINGS[b["type"]]
		open_window(str(info["name"]), "Construction site %d  ·  built" % (s.index + 1), str(info["desc"]), [
			["Leave", UI.GREY.lightened(0.4), close_window]], UI.GREEN)
		return
	var buttons: Array = []
	for type: String in PlanetDev.BUILDINGS:
		var bi: Dictionary = PlanetDev.BUILDINGS[type]
		buttons.append(["%s   -   %d gems" % [bi["name"], int(bi["price"].get("gems", 0))], UI.CYAN, _offer.bind(s, type)])
	buttons.append(["Leave", UI.GREY.lightened(0.4), close_window])
	open_window("Construction site %d" % (s.index + 1), "Free  ·  your scanner found gems in the ground here",
		"A good place for a construction. What do you want to build here?", buttons, UI.GOLD)


func _offer(s: BuildSite, type: String) -> void:
	var bi: Dictionary = PlanetDev.BUILDINGS[type]
	var price := int(bi["price"].get("gems", 0))
	var why := Game.can_build(pid, s.index, type)
	var body := "%s\n\nPrice: %d gems   (you have %d)" % [bi["desc"], price, Game.gems]
	if why != "":
		body += "\n\n" + why
	var build_cb: Variant = null
	if why == "":
		build_cb = _build.bind(s, type)
	open_window(str(bi["name"]), "Construction site %d" % (s.index + 1), body, [
		["Build for %d gems" % price, UI.GREEN, build_cb],
		["Back", UI.GREY.lightened(0.4), open_site.bind(s)],
	], UI.GOLD)


func _build(s: BuildSite, type: String) -> void:
	if Game.build(pid, s.index, type):
		s.refresh()
		close_window()
		show_toast("%s built!" % PlanetDev.BUILDINGS[type]["name"], UI.GREEN)


func open_return() -> void:
	var buttons: Array = [["Fly up to the ship", UI.CYAN, return_to_ship]]
	# travel straight on to another planet you have freed (a short flight, then you arrive there)
	for n in Game.SUN:
		if n != planet_n and Game.can_develop(n):
			buttons.append(["Fly to %s" % Game.planet(n)["name"], Color(Game.planet(n)["color"]).lerp(Color.WHITE, 0.25), travel_to.bind(n)])
	buttons.append(["Stay here", UI.GREY.lightened(0.4), close_window])
	open_window("Leave %s" % pl["name"], "Ship and planets", "Fly back up to your ship, or straight on to another planet you have freed. Everything you discovered and built here stays saved, and your capsule waits where you left it.", buttons, UI.CYAN)


## Leaving for another planet: the capsule climbs away, then the flight between the planets is
## shown, then you arrive at the destination as usual (its saved state, your saved landing place)
func travel_to(n: int) -> void:
	if leaving:
		return
	_save_state()
	leaving = true
	close_window()
	_capture(false)
	capsule.controls = false
	capsule.landed = false
	fade.color = Color(0, 0, 0, 0.0)
	fade_text.text = "Leaving %s..." % pl["name"]
	fade_text.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(fade, "color:a", 1.0, 1.0)
	tw.parallel().tween_property(fade_text, "modulate:a", 1.0, 0.6)
	tw.tween_callback(func(): main.call("travel_to_planet", planet_n, n))


func return_to_ship() -> void:
	if leaving:
		return
	_save_state()
	leaving = true
	close_window()
	_capture(false)
	capsule.controls = false
	capsule.landed = false
	fade.color = Color(0, 0, 0, 0.0)
	fade_text.text = "Flying up to the ship..."
	fade_text.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(fade, "color:a", 1.0, 1.0)
	tw.parallel().tween_property(fade_text, "modulate:a", 1.0, 0.6)
	tw.tween_callback(func(): main.call("return_to_ship"))


# ================================================================== quests
func _close_quests() -> void:
	if is_instance_valid(quests):
		quests.queue_free()
	quests = null


func _toggle_quests() -> void:
	if quests != null:
		_close_quests()
		if window == null:
			_capture(true)
		return
	close_window()
	var p := UI.panel(UI.GOLD)
	p.position = Vector2(18, 110)
	p.custom_minimum_size = Vector2(390, 0)
	add_child(p)
	quests = p
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	vb.add_child(UI.label("Quests on %s" % pl["name"], 22, UI.GOLD))
	for q: Array in PlanetDev.QUESTS.get(pid, []):
		var card := PanelContainer.new()
		var sb := UI.style(Color(0.12, 0.13, 0.28, 0.92), Color(pl["accent"], 0.5), 8, 1)
		sb.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", sb)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 2)
		card.add_child(cv)
		cv.add_child(UI.label(str(q[0]), 17, UI.TEXT))
		cv.add_child(UI.wrap_label(str(q[1]), 14, UI.SOFT, 350))
		cv.add_child(UI.label(str(q[2]), 13, UI.GOLD.darkened(0.15)))
		vb.add_child(card)
	vb.add_child(UI.label("Quests can't be started yet - coming soon.", 13, UI.SOFT))
	var close := UI.button("Close  (J)", UI.GREY.lightened(0.4), Vector2(360, 38), 15)
	close.pressed.connect(_toggle_quests)
	vb.add_child(close)
	_capture(false)


# ================================================================== test photo tour
## Puts the capsule / explorer and camera somewhere interesting (used by main.gd's F10 photo tour)
func tour_view(kind: String) -> void:
	if not ready_done:
		return
	var d := world.landing_dir
	var fwd := SphereTerrain.surface_basis(d, 0.0).z
	if mode != "capsule":
		explorer.visible = false
		_set_mode("capsule")
	capsule.landed = false
	capsule.surfing = false
	world.set_sun_height(35.0, true)
	world.weather.set_kind(0)
	flashlight = "auto"
	if kind == "storm":
		world.weather.set_kind(world.weather.kinds.size() - 1 if pid != "aquora" else 2)
		kind = "flight"
	if kind == "night_foot":
		kind = "foot"
		flashlight = "on"
	match kind:
		"orbit":
			capsule.place(d * (world.floor_radius(d) + 150.0), fwd)
			capsule.pitch = -0.6
		"flight", "sunset", "night", "sunrise":
			var p := d.rotated(SphereTerrain.surface_basis(d, 0.0).x, 18.0 / world.radius)
			capsule.place(p * (world.floor_radius(p) + 9.0), fwd)
			capsule.pitch = -0.15
			if kind == "sunset":
				world.set_sun_height(2.0, false)
			elif kind == "night":
				world.set_sun_height(-35.0, false)
			elif kind == "sunrise":
				world.set_sun_height(3.0, true)
		"animal", "site", "foot":
			var goal: Node3D = null
			if kind == "site":
				goal = world.sites[0]
			elif kind == "animal":
				for a: Wildlife in world.animals:
					if a.plan == "walker" or a.plan == "hopper":
						goal = a
						break
				if goal == null and not world.animals.is_empty():
					goal = world.animals[0]
				if goal == null:
					goal = world.sites[0]
			if kind == "foot":
				# on foot near the landing place, looking at the landscape
				var p3 := d.rotated(SphereTerrain.surface_basis(d, 0.0).x, 8.0 / world.radius)
				capsule.place(d * (world.floor_radius(d) + Capsule.HOVER), fwd)
				capsule.landed = true
				explorer.place(p3 * world.radius, fwd)
				explorer.pitch = 0.05
				explorer.visible = true
				_set_mode("foot")
			else:
				var gp := goal.position
				var u := gp.normalized()
				var side := SphereTerrain.surface_basis(u, 0.0).x
				var p2 := (gp + side * 7.0).normalized()
				capsule.place(p2 * (world.floor_radius(p2) + Capsule.HOVER), gp - p2 * gp.length())
				capsule.landed = world.can_land(p2 * world.radius)
	if flashlight == "on":
		world.set_sun_height(-35.0, false)
	world.viewer = cam.global_position
	_update_camera(0.0, true)
	world.viewer = cam.global_position
	world._update_sun(0.0)
	_update_weather_fx()
	_update_lights(1.0)
	lamp.light_energy = 7.0 if flashlight == "on" else lamp.light_energy
