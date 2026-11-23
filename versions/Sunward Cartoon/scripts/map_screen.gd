class_name MapScreen
extends Control
## The galaxy map: from the asteroid belt at the bottom, planet by planet, to the sun.
## Click a planet to see its people, tools and its strength.
## Your spaceship waits next to the planet you are freeing now. The Army button flies the
## camera into the ship (its interior = ArmyScreen, embedded here); Back flies out again.

const SUN_C := Vector2(640, 30)
const ANGLES := [115.0, 62.0, 120.0, 60.0, 122.0, 58.0, 125.0, 55.0]   # where each planet sits on its orbit
const RADII := [26.0, 36.0, 30.0, 34.0, 32.0, 30.0, 34.0, 28.0, 70.0]

var main                     # the Main node (for switching screens)
var stars: Array
var t := 0.0
var selected := -1
var hovered := -1

var info_panel: PanelContainer
var info_box: VBoxContainer
var goal_label: Label

# ---- camera and the trip into the ship
const SCREEN_C := Vector2(640, 360)
const SHIP_W := 84.0                       # ship width on the map (world units = map pixels)
const SHIP_ASPECT := 520.0 / 1200.0
const COCKPIT_UV := Vector2(0.784, 0.325)  # where the camera flies in (on the ship picture)
const NOZZLES_UV := [Vector2(0.03, 0.42), Vector2(0.03, 0.56)]
const ZOOM_TIME := 1.3                     # seconds for the whole move in (and out)
const ZOOM_END := 85.0                     # zoom at the end: the cockpit window is as wide as the screen
const TURN_DEG := 70.0                     # how far the ship turns its nose up towards the viewer
const TURN_SQUASH := 0.55                  # the ship looks shorter while its nose points at us
# One continuous move (trip 0..1):
#   0.00-0.27  the ship turns quickly (about 0.35 s): nose up and foreshortened, front window to us
#   0.12-1.00  the camera zooms into the front window (overlaps the turn, speeds up, then settles)
#   0.50-0.90  the interior appears inside the window and grows with the same zoom
const T_TURN := Vector2(0.0, 0.27)
const T_ZOOM := Vector2(0.12, 1.0)
const T_INTERIOR := Vector2(0.50, 0.90)
var cam_c := SCREEN_C                      # map point shown in the middle of the screen
var cam_z := 1.0
var cam_roll := 0.0                        # camera roll around the viewing axis (radians)
var saved_cam_c := SCREEN_C
var saved_cam_z := 1.0
var saved_cam_roll := 0.0
var ship_state := "map"                    # map, flying_in, ship, flying_out
var trip := 0.0                            # 0 = map view, 1 = inside the ship
var trip_start_screen := Vector2.ZERO      # where the ship's centre was on screen when the move began
var interior: ArmyScreen = null
var veil: Control = null                   # soft edges over the growing interior (hides its border)
var veil_rect := Rect2()
var veil_k := 0.0
var ship_alpha := 1.0
var ship_turn := 0.0                       # extra rotation of the ship sprite during the move
var ship_squash := 1.0                     # length of the sprite (1 = normal)
var dim := 0.0                             # the map darkens a little while the interior appears
var ship_tex: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	stars = Art.make_stars(260, Vector2(1280, 720), 7)
	main.make_top_bar(self, "map")

	info_panel = UI.panel()
	info_panel.position = Vector2(960, 70)
	info_panel.custom_minimum_size = Vector2(304, 0)
	add_child(info_panel)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 6)
	info_panel.add_child(info_box)

	goal_label = UI.label("Goal: free every planet from the Umbra and free the Sun", 15, UI.SOFT)
	goal_label.position = Vector2(20, 690)
	add_child(goal_label)
	if ResourceLoader.exists("res://art/ship/ship_exterior.png"):
		ship_tex = load("res://art/ship/ship_exterior.png") as Texture2D

	selected = min(Game.conquered + 1, Game.SUN)
	_show_info(selected)


## Distance step d = 1 (closest to the sun) ... 8 (asteroid belt)
func orbit_axes(n: int) -> Vector2:
	var d := Game.SUN - n
	return Vector2(90.0 + d * 72.0, 50.0 + d * 76.0)


func planet_pos(n: int) -> Vector2:
	if n == Game.SUN:
		return SUN_C
	var ax := orbit_axes(n)
	var a := deg_to_rad(ANGLES[n])
	return SUN_C + Vector2(cos(a) * ax.x, sin(a) * ax.y)


func _process(delta: float) -> void:
	t += delta
	if ship_state == "flying_in" or ship_state == "flying_out":
		_advance_trip(delta)
	hovered = -1
	if ship_state == "map":
		var m := to_world(get_local_mouse_position())
		for n in Game.PLANETS.size():
			if m.distance_to(planet_pos(n)) < RADII[n] + 10:
				hovered = n
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered >= 0 else Control.CURSOR_ARROW
	if ship_state != "ship":
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if ship_state != "map":
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and hovered >= 0:
		selected = hovered
		_show_info(selected)


# ================================================================== camera + the ship on the map
## map point -> screen point and back (the camera: cam_c in the middle, zoomed by cam_z)
func to_screen(p: Vector2) -> Vector2:
	return ((p - cam_c) * cam_z).rotated(cam_roll) + SCREEN_C


func to_world(p: Vector2) -> Vector2:
	return (p - SCREEN_C).rotated(-cam_roll) / cam_z + cam_c


## The planet being freed right now (the Sun at the end)
func active_planet() -> int:
	return clampi(Game.conquered + 1, 1, Game.SUN)


## The ship orbits close to the active planet: just above it (slightly to one side), with a small
## gap over the planet and its NEXT label. If there is no room above (under the top bar) it orbits
## below. Of the possible spots it takes the one furthest from other planets and their names.
## Returns [centre, rotation in radians].
const SHIP_GAP := 30.0          # from the planet surface to the ship centre (above): belly about 12 px over the planet
const SHIP_GAP_BELOW := 62.0    # below the planet the name labels need room
const SHIP_LEAN := 14.0         # degrees off straight above/below
const SHIP_MAX_TILT := 18.0     # the ship never tilts more than this from horizontal

func ship_place() -> Array:
	var n := active_planet()
	var p := planet_pos(n)
	var r: float = RADII[n]
	# try above/below, leaning left/right; keep the spot with the most room to the other planets
	var best := p
	var best_score := -INF
	for above: bool in [true, false]:
		if above and p.y - (r + SHIP_GAP) - 22.0 < 64.0:
			continue            # no room under the top bar
		for lean_side: float in [-1.0, 1.0]:
			var lean := deg_to_rad(SHIP_LEAN) * lean_side
			var dir := Vector2(sin(lean), -cos(lean)) if above else Vector2(sin(lean), cos(lean))
			var c := p + dir * (r + (SHIP_GAP if above else SHIP_GAP_BELOW))
			var score := 80.0 if above else 0.0        # above the planet looks best
			var room := INF
			for m in Game.PLANETS.size():
				if m != n:
					var q := planet_pos(m)
					# other planets and the two text lines under them
					room = minf(room, c.distance_to(q) - RADII[m] - SHIP_W * 0.5)
					room = minf(room, c.distance_to(q + Vector2(0, RADII[m] + 22.0)) - SHIP_W * 0.5)
			score += minf(room, 60.0)
			if score > best_score:
				best_score = score
				best = c
	return [best, ship_rotation(p, best)]


## Rotation of the ship sprite at orbit position c around planet centre p.
## The sprite's nose points along +x (rotation 0). The orbit tangent is the radius turned by
## 90 degrees (clockwise on screen); that also turns the ship's belly towards the planet.
## The angle is then limited so the ship stays mostly horizontal.
func ship_rotation(p: Vector2, c: Vector2) -> float:
	var radial := (c - p).normalized()
	var tangent := Vector2(-radial.y, radial.x)
	var a := tangent.angle()
	var limit := deg_to_rad(SHIP_MAX_TILT)
	if absf(a) <= PI / 2.0:
		return clampf(a, -limit, limit)                      # flying to the right
	var dev := wrapf(a - PI, -PI, PI)                         # flying to the left
	return PI + clampf(dev, -limit, limit)


func ship_size() -> Vector2:
	return Vector2(SHIP_W, SHIP_W * SHIP_ASPECT)


## A point on the ship picture (uv 0..1) in map coordinates (the ship gently floats on its orbit)
func ship_point(uv: Vector2) -> Vector2:
	var pl := ship_place()
	var c: Vector2 = pl[0]
	var rot: float = pl[1]
	var sz := ship_size()
	var local := Vector2((uv.x - 0.5) * sz.x * ship_squash, (uv.y - 0.5) * sz.y + _bob())
	return c + local.rotated(rot + ship_turn)


func _bob() -> float:
	return sin(t * 1.4) * 1.6 if ship_state == "map" else 0.0


func _draw_ship() -> void:
	var pl := ship_place()
	var rot: float = pl[1]
	if ship_alpha <= 0.001:
		return
	var fwd := Vector2.RIGHT.rotated(rot + ship_turn + cam_roll)      # direction of flight (on screen)
	var across := Vector2.DOWN.rotated(rot + ship_turn + cam_roll)    # across the ship (towards the planet)
	var sz := ship_size()
	var c := ship_point(Vector2(0.5, 0.5))
	var sc := to_screen(c)
	# engine flames (behind the ship)
	for uv in NOZZLES_UV:
		var nz := to_screen(ship_point(uv))
		var flick := 0.8 + 0.2 * sin(t * 30.0 + uv.y * 9.0)
		var back := -fwd * sz.x * 0.16 * flick * cam_z * ship_squash
		var hw := across * sz.y * 0.06 * cam_z
		draw_colored_polygon(PackedVector2Array([nz - hw, nz + back, nz + hw]), Color(1.0, 0.55, 0.15, 0.85 * ship_alpha))
		draw_colored_polygon(PackedVector2Array([nz - hw * 0.5, nz + back * 0.6, nz + hw * 0.5]), Color(1.0, 0.95, 0.8, 0.95 * ship_alpha))
		Art.glow(self, nz, sz.y * 0.35 * cam_z, Color(1.0, 0.5, 0.1, 0.5 * ship_alpha), 0.4)
	if ship_tex != null:
		draw_set_transform(sc, rot + ship_turn + cam_roll, Vector2(cam_z * ship_squash, cam_z))
		draw_texture_rect(ship_tex, Rect2(-sz / 2.0, sz), false, Color(1, 1, 1, ship_alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:   # simple stand-in if the picture is missing
		draw_set_transform(sc, rot + ship_turn + cam_roll, Vector2(cam_z * ship_squash, cam_z))
		draw_rect(Rect2(-sz / 2.0, sz), Color("#0d1a3a"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a small label on the outer side of the ship while on the map
	if cam_z < 1.5 and ship_state == "map":
		var lp := sc - across * (sz.y * 0.5 + 18.0) + Vector2(-60, 5)
		draw_string_outline(UI.font(), lp, "Your ship", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, 4, Color(0, 0, 0, 0.8))
		draw_string(UI.font(), lp, "Your ship", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, UI.CYAN)


# ================================================================== flying into / out of the ship
## One quick move: the ship turns its nose (front window) towards the viewer, the camera zooms
## straight into that window, and the interior picture grows out of the window and fades in.
func enter_ship() -> void:
	if ship_state != "map":
		return
	saved_cam_c = cam_c
	saved_cam_z = cam_z
	saved_cam_roll = cam_roll
	trip_start_screen = to_screen(ship_point(Vector2(0.5, 0.5)))
	trip = 0.0
	ship_state = "flying_in"
	_close_planet_ui(true)
	interior = ArmyScreen.new()
	interior.main = main
	interior.embedded = true
	interior.on_back = leave_ship
	interior.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interior.pivot_offset = SCREEN_C
	interior.modulate.a = 0.0
	interior.visible = false
	interior.interactive = false
	add_child(interior)
	move_child(interior, 0)          # above the map drawing, below the top bar
	veil = Control.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.draw.connect(_draw_veil)
	add_child(veil)
	move_child(veil, 1)              # just above the interior
	_apply_trip()


func leave_ship() -> void:
	if ship_state != "ship":
		return
	if interior != null:
		interior.interactive = false
		interior.close_popups()
	ship_state = "flying_out"
	_apply_trip()


func _ease(x: float) -> float:          # smooth start and smooth stop
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


func _part(a: float, b: float) -> float:    # where trip is inside [a, b], 0..1
	return clampf((trip - a) / (b - a), 0.0, 1.0)


func _advance_trip(delta: float) -> void:
	var dir := 1.0 if ship_state == "flying_in" else -1.0
	trip = clampf(trip + dir * delta / ZOOM_TIME, 0.0, 1.0)
	_apply_trip()
	if ship_state == "flying_in" and trip >= 1.0:
		ship_state = "ship"
		interior.interactive = true
		queue_redraw()
	elif ship_state == "flying_out" and trip <= 0.0:
		ship_state = "map"
		cam_c = saved_cam_c
		cam_z = saved_cam_z
		cam_roll = saved_cam_roll
		dim = 0.0
		ship_turn = 0.0
		ship_squash = 1.0
		if interior != null:
			interior.queue_free()
			interior = null
		if veil != null:
			veil.queue_free()
			veil = null
		_close_planet_ui(false)


func _apply_trip() -> void:
	var pl := ship_place()
	var ship_rot: float = pl[1]
	# 1. quick turn of the ship around its centre: nose up towards the viewer (2D hint only)
	var tt := _ease(_part(T_TURN.x, T_TURN.y))
	var nose_up := -1.0 if Vector2.RIGHT.rotated(ship_rot).x >= 0.0 else 1.0
	ship_turn = deg_to_rad(TURN_DEG) * nose_up * tt
	ship_squash = lerpf(1.0, TURN_SQUASH, tt)
	# 2. zoom into the front window: even in log scale, speeding up then settling
	var z := _ease(_part(T_ZOOM.x, T_ZOOM.y))
	cam_z = exp(lerpf(log(saved_cam_z), log(ZOOM_END), z))
	cam_roll = saved_cam_roll
	# the camera follows the ship's centre first (it turns around its centre), then the window,
	# and brings it to the middle of the screen
	var f := _ease(_part(0.0, 0.6))
	var target := ship_point(Vector2(0.5, 0.5)).lerp(ship_point(COCKPIT_UV), f)
	var on_screen := trip_start_screen.lerp(SCREEN_C, f)
	cam_c = target - (on_screen - SCREEN_C).rotated(-cam_roll) / cam_z
	var window_on_screen := to_screen(ship_point(COCKPIT_UV))
	# 3. the interior sits in the window, upright, and grows exactly like the zoom
	var k := _ease(_part(T_INTERIOR.x, T_INTERIOR.y))
	dim = k * 0.6
	if interior != null:
		interior.modulate.a = k
		var s := cam_z / ZOOM_END
		interior.scale = Vector2(s, s)
		interior.position = window_on_screen - SCREEN_C     # centred on the front window
		interior.rotation = 0.0
		interior.visible = k > 0.001
		veil_rect = Rect2(window_on_screen - SCREEN_C * s, Vector2(1280, 720) * s)
		veil_k = k
		if veil != null:
			veil.queue_redraw()
	var ui_a := 1.0 - _part(0.0, 0.15)
	info_panel.modulate.a = ui_a
	goal_label.modulate.a = ui_a
	queue_redraw()


## Feathered edges and a soft glass glow over the interior while it grows out of the window,
## so its rectangular border never shows. They vanish when the interior fills the screen.
func _draw_veil() -> void:
	if veil_k <= 0.0 or veil_k >= 1.0 or veil == null:
		return
	var r := veil_rect
	var fw := minf(r.size.x, r.size.y) * 0.32 * sqrt(1.0 - veil_k)
	var edge := Color(0.02, 0.03, 0.08, veil_k)          # same alpha as the interior: its border disappears
	var clear := Color(0.02, 0.03, 0.08, 0.0)
	var o := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var i := [r.position + Vector2(fw, fw), Vector2(r.end.x - fw, r.position.y + fw), r.end - Vector2(fw, fw), Vector2(r.position.x + fw, r.end.y - fw)]
	for k in 4:
		var a: Vector2 = o[k]
		var b: Vector2 = o[(k + 1) % 4]
		var ib: Vector2 = i[(k + 1) % 4]
		var ia: Vector2 = i[k]
		veil.draw_polygon(PackedVector2Array([a, b, ib, ia]), PackedColorArray([edge, edge, clear, clear]))
	# light on the glass
	var g := sin(veil_k * PI)
	Art.glow(veil, r.get_center(), r.size.x * 0.45, Color(0.55, 0.8, 1.0, 0.25 * g), 0.4)


func _close_planet_ui(hidden_ui: bool) -> void:
	info_panel.visible = not hidden_ui
	goal_label.visible = not hidden_ui
	info_panel.modulate.a = 1.0
	goal_label.modulate.a = 1.0


## Stars rushing past while flying (stronger the faster the zoom changes)
func _draw_flight_streaks() -> void:
	if ship_state != "flying_in" and ship_state != "flying_out":
		return
	var speed := sin(_part(T_ZOOM.x, 0.8) * PI) * 0.6 * (1.0 - dim)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 80:
		var a := rng.randf() * TAU
		var d0 := fmod(rng.randf() * 700.0 + t * 900.0 * (1.0 if ship_state == "flying_in" else -1.0), 700.0)
		if d0 < 0.0:
			d0 += 700.0
		var p0 := SCREEN_C + Vector2(cos(a), sin(a)) * d0
		var p1 := SCREEN_C + Vector2(cos(a), sin(a)) * (d0 + 40.0 * speed)
		draw_line(p0, p1, Color(0.7, 0.85, 1.0, 0.5 * speed), 1.5, true)


func _draw() -> void:
	Art.draw_space(self, Vector2(1280, 720), stars, t)
	if ship_state == "ship":
		return                 # the interior covers everything
	draw_set_transform(SCREEN_C - (cam_c * cam_z).rotated(cam_roll), cam_roll, Vector2(cam_z, cam_z))
	var font := UI.font()

	# orbits
	for n in Game.SUN:
		var ax := orbit_axes(n)
		var pts := PackedVector2Array()
		for k in 97:
			var a := TAU * k / 96.0
			pts.append(SUN_C + Vector2(cos(a) * ax.x, sin(a) * ax.y))
		var col := Color(UI.CYAN, 0.22) if n <= Game.conquered else Color(1, 1, 1, 0.07)
		draw_polyline(pts, col, 1.5, true)

	# asteroid belt along the outermost orbit
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var belt := orbit_axes(0)
	for i in 160:
		var a := rng.randf() * PI
		var p := SUN_C + Vector2(cos(a) * (belt.x + rng.randf_range(-18, 18)), sin(a) * (belt.y + rng.randf_range(-14, 14)))
		draw_circle(p, rng.randf_range(1.0, 3.2), Color("#8f8273", 0.8))

	# the route to the sun
	for n in Game.SUN:
		var a := planet_pos(n)
		var b := planet_pos(n + 1)
		if n < Game.conquered:
			draw_line(a, b, UI.GOLD, 3.0, true)
		else:
			var steps := int(a.distance_to(b) / 14.0)
			for k in steps:
				if k % 2 == 0:
					draw_line(a.lerp(b, float(k) / steps), a.lerp(b, float(k + 1) / steps), Color(1, 1, 1, 0.3), 2.0, true)

	# planets
	for n in Game.PLANETS.size():
		var p := planet_pos(n)
		var r: float = RADII[n]
		var pl: Dictionary = Game.PLANETS[n]
		Art.draw_planet(self, pl["id"], p, r, t)
		var status := _status(n)
		if status == "locked":
			draw_circle(p, r + 2, Color(0.04, 0.05, 0.12, 0.45))
		elif status == "next":
			var pulse := 0.5 + 0.5 * sin(t * 4.0)
			draw_arc(p, r + 8 + pulse * 5, 0, TAU, 48, Color(UI.GOLD, 0.5 + 0.5 * pulse), 3.0, true)
		elif status == "united":
			if n == Game.conquered:      # front line (ship is here): green double ring
				draw_arc(p, r + 6, 0, TAU, 48, Color(UI.GREEN, 0.9), 2.5, true)
				draw_arc(p, r + 11, 0, TAU, 48, Color(UI.GREEN, 0.4), 1.5, true)
			else:                        # freed earlier
				draw_arc(p, r + 6, 0, TAU, 48, Color(UI.CYAN, 0.8), 2.5, true)
		if n == selected:
			draw_arc(p, r + 14, t, t + PI * 1.5, 32, UI.PINK, 2.5, true)
		if n == hovered:
			draw_arc(p, r + 4, 0, TAU, 32, Color(1, 1, 1, 0.6), 1.5, true)
		# name + its element's strength
		var title: String = pl["name"]
		var sub: String = Game.STRENGTHS[pl["strength"]]["name"]
		var ly := p.y + r + 18 if n != Game.SUN else p.y + r + 30
		draw_string_outline(font, Vector2(p.x - 80, ly), title, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, 5, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(p.x - 80, ly), title, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, UI.TEXT if status != "locked" else UI.SOFT)
		draw_string(font, Vector2(p.x - 80, ly + 16), sub, HORIZONTAL_ALIGNMENT_CENTER, 160, 13, UI.GOLD if status != "locked" else Color(UI.SOFT, 0.7))
		if status == "next":
			draw_string(font, Vector2(p.x - 80, p.y - r - 14), "NEXT", HORIZONTAL_ALIGNMENT_CENTER, 160, 14, UI.GOLD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_ship()
	_draw_flight_streaks()
	if dim > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.0, 0.01, 0.04, dim))


func _status(n: int) -> String:
	if n == 0 or n <= Game.conquered:
		return "united"
	if n == Game.conquered + 1:
		return "next"
	return "locked"


func _show_info(n: int) -> void:
	for c in info_box.get_children():
		c.queue_free()
	var pl: Dictionary = Game.PLANETS[n]
	var status := _status(n)
	info_box.add_child(UI.label(pl["name"], 28, Color(pl["accent"]).lerp(UI.TEXT, 0.4)))
	info_box.add_child(UI.label("%s  ·  occupied by the Umbra" % pl["kind"] if n > Game.conquered else pl["kind"], 15, UI.GOLD))
	info_box.add_child(UI.wrap_label(pl["desc"], 14, UI.SOFT, 270))
	info_box.add_child(UI.label("People: %s" % pl["species"], 16))
	info_box.add_child(UI.label("Tools: %s" % pl["tool"], 16))
	info_box.add_child(UI.label("Element strength", 17, UI.CYAN))
	info_box.add_child(UI.strength_line(pl["strength"], 36.0, 220.0))

	var sep := HSeparator.new()
	info_box.add_child(sep)
	match status:
		"united":
			info_box.add_child(UI.label("Free! Its folk are in your crew" if n > 0 else "Your home", 17, UI.GREEN))
			if Game.can_develop(n):
				var built := Game.buildings_on(pl["id"]).size()
				var vb := UI.button("Land on %s" % pl["name"], UI.GREEN, Vector2(270, 46), 18)
				vb.pressed.connect(func(): main.show_planet(n))
				info_box.add_child(vb)
				var where := "Your ship is here (front line)" if n == Game.conquered else "Freed earlier"
				var found: int = Game.dev_state(pl["id"])["found"].size()
				info_box.add_child(UI.label("%s  ·  %d buildings  ·  %d discoveries" % [where, built, found], 14, UI.SOFT))
		"next":
			info_box.add_child(UI.wrap_label("The Umbra hold %s with its stolen %s.\nThe fight has several combats: win %d before you lose %d, buying creatures and seats with your coins." % [pl["name"], Game.STRENGTHS[pl["strength"]]["name"], Game.WIN_ROUNDS, Game.LIVES], 14, UI.TEXT, 270))
			var b := UI.button("Free %s!" % pl["name"], UI.GOLD, Vector2(270, 46), 18)
			b.pressed.connect(func(): main.show_battle(n))
			info_box.add_child(b)
		"locked":
			info_box.add_child(UI.wrap_label("Free %s first." % Game.PLANETS[Game.conquered + 1]["name"], 14, UI.SOFT, 270))
