class_name ArmyScreen
extends Control
## The command deck of your spacecraft, seen from the front: a curved hull with arched frames,
## consoles full of buttons and screens. The deck itself is a pre-rendered picture
## (art/ship/ship_hall.png, made with a small ray tracer); the game adds the moving parts:
## space behind the panorama window, a radar sweep, blinking status lights and your crew.
## Every creature has its own place on the floor (like monsters on an island) and bounces there.
## Click a creature to see it (and to sell it).

# camera of the rendered picture (must match the renderer)
const CAM_Y := 4.5
const PITCH := 0.2443461         # 14 degrees, looking a bit down
const TAN_HALF := 0.5543091         # tan(29 deg): vertical field of view 58 deg
const ASPECT := 16.0 / 9.0
const FOCAL := 649.4572             # pixels (1280x720) per world unit at distance 1
# places in the picture (1280x720), measured by the renderer
const WINDOW := Rect2(438.0, 123.3, 396.4, 105.1)
const RADAR_C := Vector2(753.3, 273.9)
const RADAR_R := 31.7
const LEDS := [Vector2(261.0, 201.5), Vector2(313.6, 201.0), Vector2(212.3, 148.4), Vector2(929.4, 200.7), Vector2(382.3, 200.4),
	Vector2(1001.1, 201.3), Vector2(1060.5, 201.9), Vector2(401.1, 200.2), Vector2(241.3, 201.7), Vector2(831.2, 95.9),
	Vector2(884.9, 200.3), Vector2(966.4, 201.0), Vector2(973.6, 281.0), Vector2(333.7, 385.6), Vector2(1038.7, 201.7),
	Vector2(350.6, 200.7), Vector2(219.5, 201.9), Vector2(195.1, 202.1), Vector2(430.6, 173.7), Vector2(598.6, 95.6),
	Vector2(326.9, 200.9), Vector2(953.1, 200.9), Vector2(781.5, 122.5), Vector2(891.1, 260.5), Vector2(1084.9, 202.1),
	Vector2(1136.9, 321.6), Vector2(358.9, 165.4), Vector2(407.2, 340.6), Vector2(918.9, 200.6), Vector2(192.3, 472.2)]
const CREATURE_SIZE := 0.5          # radius of a creature in world units

var main
var stars: Array
var t := 0.0
var art_nodes: Array = []
var sub: Label
var spots: Array = []          # {u, x, z, phase}
var size_k := 1.0
var hover_id := -1
var popup_open := false
var hall: Texture2D
# when shown inside the galaxy map (the camera flew into the ship)
var embedded := false          # no own top bar; a Back button flies out again
var on_back: Callable
var interactive := true        # false while the camera is flying
var popup_node: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	stars = Art.make_stars(140, WINDOW.size, 3)
	hall = _tex("res://art/ship/ship_hall.png")
	if embedded:
		var back := UI.button("Back to the galaxy map", UI.CYAN, Vector2(260, 44), 16)
		back.position = Vector2(20, 96)
		back.pressed.connect(func():
			if interactive and on_back.is_valid():
				on_back.call())
		add_child(back)
	else:
		main.make_top_bar(self, "army")
	sub = UI.label("", 15, UI.GOLD)
	sub.add_theme_color_override("font_outline_color", Color.BLACK)
	sub.add_theme_constant_override("outline_size", 6)
	sub.position = Vector2(20, 62)
	add_child(sub)
	_refresh_header()
	_layout()
	Game.hatched.connect(func(_c): _layout())


func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _refresh_header() -> void:
	sub.text = "Your ship  ·  %d creatures on board  ·  click a creature to see it" % Game.units.size()


## World point (x right, y up, z into the hall) -> screen position and distance
func _project(x: float, y: float, z: float) -> Vector3:
	var ry := y - CAM_Y
	var cy := ry * cos(PITCH) + z * sin(PITCH)
	var cz := -ry * sin(PITCH) + z * cos(PITCH)
	var nx := x / cz / (TAN_HALF * ASPECT)
	var ny := cy / cz / TAN_HALF
	return Vector3((nx + 1.0) / 2.0 * 1280.0, (1.0 - ny) / 2.0 * 720.0, cz)


## Fixed places on the floor in rows between the barrels/crates and the helm
func _layout() -> void:
	spots.clear()
	var list: Array = Game.units.duplicate()
	list.sort_custom(func(a, b): return a["id"] < b["id"])
	var n := list.size()
	if n == 0:
		return
	var rows := clampi(int(ceil(n / 5.0)), 1, 5)
	var zs: Array[float] = []
	for i in rows:
		zs.append(8.0 if rows == 1 else lerpf(13.6, 6.3, i / float(rows - 1)))
	var counts: Array[int] = []
	var given := 0
	for i in rows:
		counts.append(n / rows)
		given += n / rows
	var r_i := rows - 1
	while given < n:            # leftovers go to the front rows
		counts[r_i] += 1
		given += 1
		r_i = rows - 1 if r_i == 0 else r_i - 1
	var most := 0
	for c in counts:
		most = maxi(most, c)
	size_k = clampf(8.0 / (most * CREATURE_SIZE * 2.6), 0.55, 1.0)
	var idx := 0
	for i in rows:
		var z: float = zs[i]
		var half := 3.5 + 0.12 * (z - 6.3)
		for j in counts[i]:
			var k: float = (j + 0.5) / float(counts[i])
			var x := lerpf(-half, half, k) + (0.35 if i % 2 == 1 else 0.0)
			spots.append({"u": list[idx], "x": x, "z": z, "phase": randf() * TAU})
			idx += 1


func _process(delta: float) -> void:
	t += delta
	for a in art_nodes:
		if is_instance_valid(a):
			a.queue_redraw()
	if not popup_open and interactive:
		var h: Variant = _spot_at(get_local_mouse_position())
		hover_id = -1 if h == null else int(h["u"]["id"])
		mouse_default_cursor_shape = Control.CURSOR_ARROW if h == null else Control.CURSOR_POINTING_HAND
	queue_redraw()


func _radius(sp: Dictionary) -> float:
	var p := _project(sp["x"], 0.0, sp["z"])
	return CREATURE_SIZE * size_k * FOCAL / p.z


func _foot(sp: Dictionary) -> Vector2:
	var p := _project(sp["x"], 0.0, sp["z"])
	return Vector2(p.x, p.y)


func _body_pos(sp: Dictionary) -> Vector2:
	var r := _radius(sp)
	var bounce := absf(sin(t * 2.2 + sp["phase"])) * r * 0.18
	return _foot(sp) - Vector2(0, r * 1.05 + bounce)


func _spot_at(p: Vector2) -> Variant:
	var best: Variant = null
	var bd := INF
	for sp in spots:
		var d := _body_pos(sp).distance_to(p)
		if d < _radius(sp) * 1.15 and d < bd:
			bd = d
			best = sp
	return best


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var sp: Variant = _spot_at(mb.position)
	if sp != null:
		_show_unit(sp["u"])


# ================================================================== drawing
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#05060f"))
	_draw_space()
	if hall != null:
		draw_texture_rect(hall, Rect2(0, 0, 1280, 720), false)
	else:
		draw_string(UI.font(), Vector2(400, 360), "Ship picture missing (art/ship/ship_hall.png)", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.RED)
	_draw_systems()
	_draw_crew(UI.font())


## Space behind the panorama window: drifting stars, a nebula, the Sun and the next planet
func _draw_space() -> void:
	var box := WINDOW.grow(4.0)
	draw_rect(box, Color("#020412"))
	Art.glow(self, box.get_center() + Vector2(-90, 20), 110.0, Color("#3b2fa8", 0.35), 0.3)
	Art.glow(self, box.get_center() + Vector2(120, -10), 90.0, Color("#1f6fbf", 0.3), 0.3)
	for st in stars:
		var sp: Vector2 = st[0]
		var q := box.position + Vector2(fmod(sp.x + t * 14.0, box.size.x), fmod(sp.y, box.size.y))
		var tw := 0.6 + 0.4 * sin(t * 2.0 + float(st[2]))
		draw_circle(q, float(st[1]) * 0.8, Color(1, 1, 1, 0.9 * tw))
	Art.draw_planet(self, "sun", box.get_center() + Vector2(120, -6), 24.0, t)
	var nxt := clampi(Game.conquered + 1, 1, Game.SUN - 1)
	Art.draw_planet(self, Game.PLANETS[nxt]["id"], box.get_center() + Vector2(-110 + fmod(t * 1.5, 60.0), 18), 16.0, t)


## Moving parts of the deck: radar sweep and blinking status lights
func _draw_systems() -> void:
	# radar sweep on the right main screen
	var ang := fmod(t * 1.6, TAU)
	for i in 12:
		var a0 := ang - i * 0.05
		var pts := PackedVector2Array([RADAR_C, RADAR_C + Vector2(cos(a0), sin(a0)) * RADAR_R, RADAR_C + Vector2(cos(a0 - 0.05), sin(a0 - 0.05)) * RADAR_R])
		draw_colored_polygon(pts, Color(0.4, 1.0, 0.7, 0.28 * (1.0 - i / 12.0)))
	draw_line(RADAR_C, RADAR_C + Vector2(cos(ang), sin(ang)) * RADAR_R, Color(0.6, 1.0, 0.8, 0.9), 2.0)
	# status lights blink at their own rhythm
	var cols := [Color("#5affa0"), Color("#50dcff"), Color("#ff9a2e"), Color("#ff5a6e")]
	for i in LEDS.size():
		var on := sin(t * (1.5 + (i % 5) * 0.7) + i * 2.3) > 0.2
		if on:
			var c: Color = cols[i % 4]
			Art.glow(self, LEDS[i], 9.0, Color(c, 0.55), 0.5)
			draw_circle(LEDS[i], 2.2, c.lightened(0.4))


## The crew on glowing floor pads: back rows first
func _draw_crew(font: Font) -> void:
	var list := spots.duplicate()
	list.sort_custom(func(a, b): return a["z"] > b["z"])
	for sp in list:
		var r := _radius(sp)
		var foot := _foot(sp)
		var hov := int(sp["u"]["id"]) == hover_id
		# floor plate seen in perspective
		var near := _project(sp["x"], 0.0, sp["z"] - CREATURE_SIZE * size_k * 1.3)
		var far := _project(sp["x"], 0.0, sp["z"] + CREATURE_SIZE * size_k * 1.3)
		var flat := clampf((near.y - far.y) / (2.0 * r * 1.3), 0.15, 1.0)
		draw_set_transform(foot, 0.0, Vector2(1.0, flat))
		# glowing hologram pad
		draw_circle(Vector2.ZERO, r * 1.45, Color(0, 0, 0, 0.4))
		draw_circle(Vector2.ZERO, r * 1.3, Color("#0c1a33"))
		var pulse := 0.6 + 0.4 * sin(t * 2.0 + sp["phase"])
		var rim := Color(0.35, 0.85, 1.0, 0.9) if not hov else Color(1.0, 0.8, 0.35, 1.0)
		draw_arc(Vector2.ZERO, r * 1.3, 0, TAU, 48, rim, maxf(2.0, r * 0.09), true)
		draw_arc(Vector2.ZERO, r * 1.0, 0, TAU, 48, Color(0.35, 0.85, 1.0, 0.35 * pulse), maxf(1.5, r * 0.05), true)
		draw_arc(Vector2.ZERO, r * 1.16, t * 1.5 + sp["phase"], t * 1.5 + sp["phase"] + 1.6, 20, Color(1.0, 0.6, 0.2, 0.9), maxf(1.5, r * 0.06), true)
		draw_circle(Vector2.ZERO, r * 1.3, Color(0.3, 0.8, 1.0, 0.10 * pulse) if not hov else Color(1.0, 0.8, 0.35, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var p := _body_pos(sp)
		if hov:
			Art.glow(self, p, r * 1.8, Color(UI.GOLD, 0.45), 0.4)
		Art.draw_unit(self, sp["u"], p, r, 0, t, 1.0)
		if hov:
			var nm: String = sp["u"]["name"]
			draw_string_outline(font, p + Vector2(-90, -r - 14), nm, HORIZONTAL_ALIGNMENT_CENTER, 180, UI.fs(15), 5, Color.BLACK)
			draw_string(font, p + Vector2(-90, -r - 14), nm, HORIZONTAL_ALIGNMENT_CENTER, 180, UI.fs(15), UI.GOLD)


func _art(u: Dictionary, box_size: Vector2, r: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = box_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): Art.draw_unit(c, u, c.size / 2.0 + Vector2(0, 4), r, 0, t))
	art_nodes.append(c)
	return c


## Big window for one creature: picture, numbers, its strengths explained, and selling
## Closes the creature window (used before the camera flies out)
func close_popups() -> void:
	if popup_node != null and is_instance_valid(popup_node):
		popup_node.queue_free()
	popup_node = null
	popup_open = false
	hover_id = -1


func _show_unit(u: Dictionary) -> void:
	popup_open = true
	var dim := ColorRect.new()
	popup_node = dim
	dim.color = Color(0, 0, 0, 0.65)
	dim.tree_exiting.connect(func(): popup_open = false)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		var m := ev as InputEventMouseButton
		if m != null and m.pressed:
			dim.queue_free())
	add_child(dim)
	var p := UI.panel(UI.CYAN)
	p.position = Vector2(140, 70)
	p.custom_minimum_size = Vector2(1000, 580)
	p.size = Vector2(1000, 580)
	dim.add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 70)   # gap between creature and description
	p.add_child(hb)

	# left: the creature itself, big
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	hb.add_child(left)
	var pic := _art(u, Vector2(380, 500), minf(Art.unit_radius(u, 110.0), 150.0))
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(pic)
	var nm := UI.label(u["name"] + ("  (you)" if u.get("hero", false) else ""), 26, UI.TEXT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(nm)

	# right: statistics and strengths, sell button in the bottom right corner
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	var head := HBoxContainer.new()
	right.add_child(head)
	var title := UI.label(Game.species_name(u), 20, UI.CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UI.button("Close", UI.CYAN, Vector2(100, 38), 15)
	close.pressed.connect(dim.queue_free)
	head.add_child(close)
	var st := Game.unit_stats(u)
	right.add_child(UI.label("Level %d   ·   %d element%s   ·   tier %s" % [Game.level(u), Game.elements(u), "" if Game.elements(u) == 1 else "s", Game.tier_name(Game.level(u))], 18, UI.ORANGE))
	var grid2 := GridContainer.new()
	grid2.columns = 2
	grid2.add_theme_constant_override("h_separation", 30)
	right.add_child(grid2)
	for pair in [["Health", "%d" % st["hp"]], ["Attack", "%d every %.1f s" % [st["atk"], st["cd"]]],
			["Range", "%d hex" % maxi(1, int(round(st["range"])))], ["Speed", "%.1f hex/s" % st["speed"]]]:
		grid2.add_child(UI.label(pair[0], 15, UI.SOFT))
		grid2.add_child(UI.label(pair[1], 15, UI.TEXT))
	if u.get("hybrid", false):
		right.add_child(UI.label("Hybrid: +%d%% health and attack" % int(round(Game.ELEMENT_BONUS * 100 * (Game.elements(u) - 1))), 13, UI.PINK))
	right.add_child(HSeparator.new())
	right.add_child(UI.label("Strengths  (tier %s: x%.1f)" % [Game.tier_name(Game.level(u)), Game.TIER_MULT[Game.tier(Game.level(u)) - 1]], 17, UI.GOLD))
	for s in u["strengths"]:
		right.add_child(UI.strength_line(s, 44.0, 380.0))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	var why := Game.can_sell(u)
	if why != "":
		var wl := UI.label(why, 13, UI.SOFT)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(wl)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(bottom)
	var sell := UI.button("Sell: +%d hybreeding energy" % Game.SELL_ENERGY, UI.GOLD, Vector2(300, 46), 16)
	sell.disabled = why != ""
	sell.pressed.connect(func():
		if not sell.has_meta("sure"):
			sell.set_meta("sure", true)
			sell.text = "Really sell? It leaves for good."
			UI.set_button_color(sell, UI.RED)
			return
		Game.sell_unit(u)
		dim.queue_free()
		_refresh_header()
		_layout())
	bottom.add_child(sell)
