extends Control
## Switches between the screens: galaxy map, crew, hybreeding lab, battle, planet maps.

var screen: Control
var top_info: Label
var top_coins: Label
var top_gems: Label
var exit_menu: Control = null
var top_map_b: Button
var top_army_b: Button
var top_breed_badge: Control = null
var ready_notice: Control = null      # "Breeding complete!" message (until acknowledged)
var t := 0.0
var touring := false


func _ready() -> void:
	theme = UI.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS   # the menu still works while the game is paused
	# start in fullscreen (F11 switches back to a window)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	show_map()
	Game.hatched.connect(_on_hatched)


# ================================================================== breeding complete
## Shows the message once per finished breeding (also after the game was closed). In the lab the
## lab itself shows the egg, so there the message is not needed. The state is saved in Game.
func _check_ready_notice() -> void:
	if Game.needs_ready_notice():
		if screen is BreedScreen:
			Game.acknowledge_ready()
		elif not is_instance_valid(ready_notice):
			_show_ready_notice()
	elif is_instance_valid(ready_notice):
		_close_ready_notice()


func _show_ready_notice() -> void:
	var p := UI.panel(UI.CYAN)
	var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
	sb.shadow_color = Color(0.3, 0.9, 1.0, 0.45)
	sb.shadow_size = 14
	p.custom_minimum_size = Vector2(470, 0)
	p.position = Vector2(1280 - 490, 720 - 150)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	ready_notice = p
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	var egg := Control.new()
	egg.custom_minimum_size = Vector2(76, 76)
	egg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	egg.draw.connect(func(): Art.draw_icon(egg, "egg", egg.size / 2.0, 30.0, Color.WHITE, t))
	hb.add_child(egg)
	var tw_egg := egg.create_tween().set_loops()
	tw_egg.tween_callback(egg.queue_redraw).set_delay(0.03)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	hb.add_child(vb)
	vb.add_child(UI.wrap_label("Breeding complete! Your new creature is ready to hatch!", 16, UI.TEXT, 360))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var in_battle := screen is BattleScreen
	var go := UI.button("Open the lab (leaves the battle)" if in_battle else "Open the lab", UI.GOLD, Vector2(240 if in_battle else 170, 38), 14)
	go.pressed.connect(func():
		Game.acknowledge_ready()
		_close_ready_notice()
		show_breed())
	row.add_child(go)
	var later := UI.button("Later", UI.GREY.lightened(0.4), Vector2(80, 38), 14)
	later.tooltip_text = "The egg badge on the Hybreeding button stays until you hatch it"
	later.pressed.connect(func():
		Game.acknowledge_ready()
		_close_ready_notice())
	row.add_child(later)
	# slide in from the right
	p.position.x = 1300
	p.create_tween().tween_property(p, "position:x", 1280.0 - 490.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if exit_menu != null:
		move_child(exit_menu, -1)


func _close_ready_notice() -> void:
	if is_instance_valid(ready_notice):
		ready_notice.queue_free()
	ready_notice = null


## Little message at the bottom when a creature has hatched (on any screen)
func _on_hatched(child: Dictionary) -> void:
	var p := UI.panel(UI.PINK)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = Vector2(20, 640)
	var msg := "%s hatched! New %s with %d elements" % [child["name"], Game.species_name(child), Game.elements(child)]
	if child.has("copy_of"):
		msg = "Hybreeding finished: a copy of %s hatched (no hybrid this time)" % child["copy_of"]
	p.add_child(UI.label(msg, 17, UI.PINK.lightened(0.3)))
	add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _set_screen(s: Control) -> void:
	if screen:
		screen.queue_free()
	screen = s
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.process_mode = Node.PROCESS_MODE_PAUSABLE   # screens stop while the menu is open
	add_child(s)
	if is_instance_valid(ready_notice):
		move_child(ready_notice, -1)                 # the message stays on top of every screen
	if exit_menu != null:
		move_child(exit_menu, -1)


func show_map() -> void:
	# already on the map but inside the ship: fly back out instead of rebuilding the map
	if screen is MapScreen:
		var ms := screen as MapScreen
		if ms.ship_state == "ship":
			ms.leave_ship()
		return
	var s := MapScreen.new()
	s.main = self
	_set_screen(s)


## The army lives in the ship next to the active planet: fly the camera into it
func show_army() -> void:
	if not (screen is MapScreen):
		show_map()
	var ms := screen as MapScreen
	if ms.ship_state == "map":
		ms.enter_ship()


func show_breed() -> void:
	var s := BreedScreen.new()
	s.main = self
	_set_screen(s)


## Fly down to a freed planet: explore the round world with the capsule (wildlife, objects, sites, quests)
func show_planet(n: int) -> void:
	if not Game.can_develop(n):
		return
	var s := ExploreScreen.new()
	s.main = self
	s.planet_n = n
	_set_screen(s)


## From one freed planet straight to another: a short travel cinematic, then the destination
## loads as the planet you explore (its saved state, your saved landing place)
func travel_to_planet(from_n: int, to_n: int) -> void:
	if not Game.can_develop(to_n):
		show_planet(from_n)
		return
	var s := TravelScreen.new()
	s.main = self
	s.from_n = from_n
	s.to_n = to_n
	_set_screen(s)


## Test helper (F10, editor only): visits all planet surfaces and saves screenshots
## (whole planet from above, low flight, on foot, an animal, a construction site, sunset, night,
## sunrise) to user://screenshots/.
func _photo_tour() -> void:
	touring = true
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	for n in Game.SUN:
		var s := ExploreScreen.new()
		s.main = self
		s.planet_n = n
		s.tour = true
		_set_screen(s)
		await get_tree().create_timer(2.5).timeout
		for shot: String in ["orbit", "flight", "foot", "animal", "storm", "sunset", "night", "night_foot"]:
			if not is_instance_valid(s):
				break
			s.tour_view(shot)
			await get_tree().create_timer(0.9).timeout
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("user://screenshots/%s_%s.png" % [Game.planet(n)["id"], shot])
			print("Tour screenshot: %s %s" % [Game.planet(n)["id"], shot])
	touring = false
	print("Tour finished")
	show_map()


## From a planet back up to the ship: galaxy map, then the usual flight into the ship
func return_to_ship() -> void:
	show_map()
	var ms := screen as MapScreen
	if ms:
		ms.enter_ship.call_deferred()


func _flash_note(text: String) -> void:
	var l := UI.label(text, 22, UI.GOLD)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.position = Vector2(470, 660)
	add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


## Preview of the new 3D creature designs (F6 / "New looks")
func show_creature_gallery() -> void:
	var s := CreatureGallery.new()
	s.main = self
	_set_screen(s)


func show_battle(n: int) -> void:
	var s := BattleScreen.new()
	s.main = self
	s.planet_n = n
	_set_screen(s)


## Top bar used by the map and the army screen
func make_top_bar(parent: Control, current: String) -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 12)
	bar.add_theme_constant_override("separation", 10)
	parent.add_child(bar)
	var map_b := UI.button("Galaxy map", UI.CYAN, Vector2(150, 40))
	map_b.disabled = current == "map"
	map_b.pressed.connect(show_map)
	bar.add_child(map_b)
	var army_b := UI.button("Army", UI.GREEN, Vector2(110, 40))
	army_b.disabled = current == "army"
	if current == "map":
		top_map_b = map_b
		top_army_b = army_b
	army_b.pressed.connect(show_army)
	bar.add_child(army_b)
	var breed_b := UI.button("Hybreeding", UI.PINK, Vector2(150, 40))
	breed_b.disabled = current == "breed"
	breed_b.pressed.connect(show_breed)
	bar.add_child(breed_b)
	# glowing egg badge while a creature is ready to hatch (same state as the message)
	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(30, 30)
	badge.size = Vector2(30, 30)
	badge.position = Vector2(150 - 20, -12)
	badge.draw.connect(func():
		if Game.is_ready_to_hatch():
			Art.draw_icon(badge, "egg", Vector2(15, 15), 12.0, Color.WHITE, t))
	breed_b.add_child(badge)
	top_breed_badge = badge
	var sym_b := UI.button("Symbols", UI.ORANGE, Vector2(110, 40))
	sym_b.pressed.connect(show_legend)
	bar.add_child(sym_b)
	var looks_b := UI.button("New looks", UI.GOLD, Vector2(100, 40), 15)
	looks_b.pressed.connect(show_creature_gallery)
	bar.add_child(looks_b)
	var info := UI.panel(UI.GOLD)
	(info.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(8)
	bar.add_child(info)
	top_info = UI.label("", 16, UI.GOLD)
	info.add_child(top_info)
	# currencies, top right
	var money := UI.panel(UI.GOLD)
	(money.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(8)
	money.position = Vector2(1100, 12)
	money.custom_minimum_size = Vector2(164, 0)
	parent.add_child(money)
	var row: Array = UI.currency_row(22.0, 17)
	money.add_child(row[0])
	top_coins = row[1]
	top_gems = row[2]
	_update_top()


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
	# TEST ONLY (only when started from the Godot editor): F9 gives 10 gems, because gems can't be earned yet
	elif k.physical_keycode == KEY_F5:
		Art.next_style()
		_flash_note("Creature look: " + str(Art.STYLE_NAMES[Art.style]))
		get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_F6 and not touring:
		show_creature_gallery()
		get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_F9 and OS.is_debug_build():
		Game.add_reward({"gems": 10})
		get_viewport().set_input_as_handled()
	# TEST ONLY: F10 lands on every planet once and saves screenshots to user://screenshots
	elif k.physical_keycode == KEY_F10 and OS.is_debug_build() and not touring:
		get_viewport().set_input_as_handled()
		_photo_tour()
	# Shift+Tab in either order (Shift first or Tab first), or Esc
	elif (k.physical_keycode == KEY_TAB and (k.shift_pressed or Input.is_physical_key_pressed(KEY_SHIFT))) \
			or (k.physical_keycode == KEY_SHIFT and Input.is_physical_key_pressed(KEY_TAB)) \
			or k.physical_keycode == KEY_ESCAPE:
		toggle_exit_menu()
		get_viewport().set_input_as_handled()


func _toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Shift+Tab: pause menu (continue, galaxy map, fullscreen, quit). The game is paused while it is open.
func toggle_exit_menu() -> void:
	if exit_menu != null:
		exit_menu.queue_free()
		exit_menu = null
		get_tree().paused = false
		return
	get_tree().paused = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	exit_menu = dim
	var p := UI.panel(UI.GOLD)
	p.position = Vector2(440, 150)
	p.custom_minimum_size = Vector2(400, 0)
	dim.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	p.add_child(vb)
	var title := UI.label("Menu", 30, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var cont := UI.button("Continue", UI.GREEN, Vector2(370, 50), 19)
	cont.pressed.connect(toggle_exit_menu)
	vb.add_child(cont)
	var map_b := UI.button("Galaxy map", UI.CYAN, Vector2(370, 50), 19)
	map_b.pressed.connect(func():
		toggle_exit_menu()
		show_map())
	vb.add_child(map_b)
	var full_b := UI.button("Fullscreen on / off  (F11)", UI.CYAN, Vector2(370, 50), 19)
	full_b.pressed.connect(_toggle_fullscreen)
	vb.add_child(full_b)
	var new_b := UI.button("New game (reset progress)", UI.ORANGE, Vector2(370, 50), 19)
	new_b.pressed.connect(func():
		if not new_b.has_meta("sure"):
			new_b.set_meta("sure", true)
			new_b.text = "Really? Everything is lost!"
			UI.set_button_color(new_b, UI.RED)
			return
		Game.reset_game()
		toggle_exit_menu()
		show_map())
	vb.add_child(new_b)
	var quit_b := UI.button("Save and quit game", UI.RED, Vector2(370, 50), 19)
	quit_b.pressed.connect(func():
		Game.save_game()
		get_tree().quit())
	vb.add_child(quit_b)
	vb.add_child(UI.wrap_label("Shift+Tab or Esc opens and closes this menu. A battle in progress is paused, not lost.", 13, UI.SOFT, 370))


func _process(delta: float) -> void:
	t += delta
	_check_ready_notice()
	if is_instance_valid(top_breed_badge):
		top_breed_badge.queue_redraw()
	if is_instance_valid(top_info):
		_update_top()


func _update_top() -> void:
	var txt := "Crew %d  ·  Energy %d  ·  Freed %d" % [Game.units.size(), Game.breed_charges, Game.conquered]
	# on the galaxy map the buttons depend on where the camera is
	if screen is MapScreen and is_instance_valid(top_map_b):
		var st: String = (screen as MapScreen).ship_state
		top_map_b.disabled = st != "ship"
		top_army_b.disabled = st != "map"
	if is_instance_valid(top_coins):
		top_coins.text = str(Game.coins)
		top_gems.text = str(Game.gems)
	if Game.is_breeding():
		var s := int(ceil(Game.breeding_left()))
		txt += "  ·  Growing %d:%02d" % [s / 60, s % 60]
	top_info.text = txt


## Window that explains every strength symbol, sorted by planet
func show_legend() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := UI.panel(UI.ORANGE)
	p.position = Vector2(90, 40)
	p.custom_minimum_size = Vector2(1100, 640)
	p.size = Vector2(1100, 640)
	dim.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := UI.label("Elements, strengths & levels", 26, UI.ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UI.button("Close", UI.ORANGE, Vector2(110, 40))
	close.pressed.connect(dim.queue_free)
	head.add_child(close)
	vb.add_child(UI.wrap_label("Every planet = one element with one strength. A creature has the strengths of all its elements (max %d).\nOrange \"Lv\" (bottom right) = level. New creatures start at level 1. Winning battles does not change levels - later you will level creatures with resources from your freed planets.\nThe level sets the tier of the strengths: tier I from level 1 (x1), tier II from level 4 (x1.5), tier III from level 7 (x2). Each level also adds +10%% health and attack.\nShop price = number of elements x tier." % Game.MAX_ELEMENTS, 14, UI.SOFT, 1050))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1070, 530)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	var shown := {}
	for pl in Game.PLANETS:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.custom_minimum_size = Vector2(340, 0)
		box.add_child(UI.label("%s - %s" % [pl["name"], pl["species"]], 16, Color(pl["accent"]).lerp(UI.TEXT, 0.4)))
		var any := false
		var s: String = pl["strength"]
		if not shown.has(s):
			shown[s] = true
			any = true
			box.add_child(UI.strength_line(s, 40.0, 270.0))
		if any:
			grid.add_child(box)
		else:
			box.queue_free()
