class_name CreatureGallery
extends Control
## Preview of the new creature designs (not used in battles yet): six example creatures,
## buttons to play their animations, any element combination (up to 4) to try, Umbra
## versions, new individuals of the same species, and photos (saved to user://screenshots/creatures).
## Open with F6 or the "New looks" button.

const EXAMPLES := [
	[["pebble"], "Single element"],
	[["glacia"], "Single element"],
	[["mycelia"], "Single element"],
	[["glacia", "voltara"], "Ice + Lightning"],
	[["mycelia", "aquora"], "Fungus + Water"],
	[["pebble", "ferrum", "voltara"], "Stone + Fire + Lightning"],
]
const STATES := [["Idle", "idle"], ["Walk", "walk"], ["Run", "run"], ["Attack", "attack"], ["Hurt", "hurt"], ["Defeat", "defeat"], ["Elemental", "special"]]

var main: Node
var stages: Array = []
var names: Array = []
var seeds: Array = [11, 23, 37, 41, 53, 67]
var picked: Array = []
var umbra_b: Button
var elem_buttons := {}
var big: Control = null
var big_stage: CreatureStage = null
var toast: Label
var loop_state := ""
var loop_t := 0.0
var busy := false
var board: Control = null
var board_pose := "idle"
var board_big := false
var bt := 0.0
## the prototypes on the board: [elements, cell, team]
const BOARD_UNITS := [
	[["pebble"], Vector2i(0, 3), 0], [["glacia"], Vector2i(1, 3), 0], [["mycelia"], Vector2i(2, 3), 0],
	[["glacia", "voltara"], Vector2i(0, 2), 0], [["pebble", "ferrum", "voltara"], Vector2i(1, 2), 0], [["glacia", "mycelia", "aquora"], Vector2i(2, 2), 0],
	[["ferrum"], Vector2i(0, 0), 1], [["verdis", "solara"], Vector2i(2, 0), 1],
]


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := UI.label("New creature designs  ·  preview (battles still use the old look)", 20, UI.GOLD)
	title.position = Vector2(24, 14)
	add_child(title)
	var hint := UI.label("drag to turn  ·  wheel to zoom  ·  click a creature for a big view", 14, UI.SOFT)
	hint.position = Vector2(760, 18)
	add_child(hint)
	for i in EXAMPLES.size():
		var col := i % 3
		var row := i / 3
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.style(Color(0.06, 0.07, 0.16, 0.95), Color(UI.CYAN, 0.35), 10, 1))
		card.position = Vector2(24 + col * 416, 52 + row * 282)
		card.size = Vector2(404, 272)
		add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		card.add_child(vb)
		var nl := UI.label("", 16, UI.TEXT)
		vb.add_child(nl)
		names.append(nl)
		var st := CreatureStage.new()
		st.custom_minimum_size = Vector2(396, 232)
		vb.add_child(st)
		st.clicked.connect(_open_big.bind(i))
		stages.append(st)
	_controls()
	toast = UI.label("", 17, UI.GREEN)
	toast.position = Vector2(24, 600)
	add_child(toast)
	_rebuild()


func _controls() -> void:
	var row1 := HBoxContainer.new()
	row1.position = Vector2(24, 618)
	row1.add_theme_constant_override("separation", 8)
	add_child(row1)
	for s: Array in STATES:
		var b := UI.button(str(s[0]), UI.CYAN, Vector2(112, 40), 15)
		b.pressed.connect(_play_all.bind(str(s[1])))
		row1.add_child(b)
	var turn := UI.button("Turntable", UI.GREY.lightened(0.4), Vector2(120, 40), 15)
	turn.pressed.connect(func():
		for st: CreatureStage in _all_stages():
			st.turntable = not st.turntable)
	row1.add_child(turn)
	var again := UI.button("New individuals", UI.PINK, Vector2(170, 40), 15)
	again.pressed.connect(func():
		for i in seeds.size():
			seeds[i] = randi() % 100000
		_rebuild())
	row1.add_child(again)
	var row2 := HBoxContainer.new()
	row2.position = Vector2(24, 668)
	row2.add_theme_constant_override("separation", 6)
	add_child(row2)
	row2.add_child(UI.label("Try:", 15, UI.SOFT))
	for p: Dictionary in Game.PLANETS:
		var id := str(p["id"])
		if id == "sun":
			continue
		var eb := UI.button(str(p["name"]), Color(p["color"]), Vector2(86, 40), 14)
		eb.toggle_mode = true
		eb.toggled.connect(_toggle_element.bind(id))
		row2.add_child(eb)
		elem_buttons[id] = eb
	umbra_b = UI.button("Umbra", UI.RED, Vector2(80, 40), 14)
	umbra_b.toggle_mode = true
	row2.add_child(umbra_b)
	var build := UI.button("Show", UI.GREEN, Vector2(80, 40), 15)
	build.pressed.connect(_show_custom)
	row2.add_child(build)
	var bv := UI.button("Board view", UI.ORANGE, Vector2(120, 40), 15)
	bv.pressed.connect(_toggle_board)
	row1.add_child(bv)
	var photos := UI.button("Save photos", UI.GOLD, Vector2(130, 40), 15)
	photos.pressed.connect(_save_photos)
	row2.add_child(photos)
	var close := UI.button("Close", UI.GREY.lightened(0.4), Vector2(80, 40), 15)
	close.pressed.connect(_close)
	row2.add_child(close)


func _all_stages() -> Array:
	var out := stages.duplicate()
	if big_stage:
		out.append(big_stage)
	return out


func _title(els: Array) -> String:
	var u := {"species": els}
	var txt := Game.species_name(u)
	var parts: Array = []
	for e: String in els:
		parts.append(str(Game.PLANETS[Game.planet_index(e)]["name"]))
	return "%s   (%s)" % [txt, " + ".join(parts)]


func _rebuild() -> void:
	for i in EXAMPLES.size():
		var ex: Array = EXAMPLES[i]
		var els: Array = Game.sort_elements(ex[0])
		var st: CreatureStage = stages[i]
		st.set_creature(CreatureForge.build(els, int(seeds[i])))
		var nl: Label = names[i]
		nl.text = "%d. %s  ·  %s" % [i + 1, str(ex[1]), _title(els)]


func _play_all(s: String) -> void:
	board_pose = s if s in ["idle", "walk", "run", "attack", "hurt"] else "idle"
	for st: CreatureStage in _all_stages():
		st.play(s)
	# repeat short moves so they can be watched
	loop_state = s if s in ["attack", "hurt", "special"] else ""
	loop_t = 0.0


func _process(delta: float) -> void:
	bt += delta
	if board:
		board.queue_redraw()
	if loop_state != "" and not busy:
		loop_t += delta
		if loop_t > 2.4:
			loop_t = 0.0
			for st: CreatureStage in _all_stages():
				st.play(loop_state)
			if board_pose in ["attack", "hurt"]:
				var again := board_pose
				board_pose = "idle"
				get_tree().create_timer(0.1).timeout.connect(func(): board_pose = again)


func _toggle_element(on: bool, id: String) -> void:
	if on:
		if picked.size() >= Game.MAX_ELEMENTS:
			var b: Button = elem_buttons[id]
			b.set_pressed_no_signal(false)
			_toast("A creature can have at most %d elements" % Game.MAX_ELEMENTS, UI.RED)
			return
		picked.append(id)
	else:
		picked.erase(id)


func _show_custom() -> void:
	if picked.is_empty():
		_toast("Pick 1 - 4 elements first", UI.RED)
		return
	var els: Array = Game.sort_elements(picked)
	_open_view(els, randi() % 100000, umbra_b.button_pressed)


func _open_big(i: int) -> void:
	var ex: Array = EXAMPLES[i]
	_open_view(Game.sort_elements(ex[0]), int(seeds[i]), false)


func _open_view(els: Array, seed_value: int, umbra: bool) -> void:
	_close_big()
	big = PanelContainer.new()
	big.add_theme_stylebox_override("panel", UI.style(Color(0.04, 0.05, 0.12, 0.98), UI.GOLD, 12, 2))
	big.position = Vector2(24, 52)
	big.size = Vector2(1232, 556)
	add_child(big)
	var vb := VBoxContainer.new()
	big.add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	top.add_child(UI.label(("Umbra  ·  " if umbra else "") + _title(els) + "   ·   individual #%d" % seed_value, 18, UI.GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var x := UI.button("Back to all", UI.GREY.lightened(0.4), Vector2(130, 34), 14)
	x.pressed.connect(_close_big)
	top.add_child(x)
	big_stage = CreatureStage.new()
	big_stage.custom_minimum_size = Vector2(1220, 500)
	vb.add_child(big_stage)
	big_stage.set_creature(CreatureForge.build(els, seed_value, umbra))
	big_stage.cam_dist *= 0.8
	big_stage._place_cam()


func _close_big() -> void:
	if big:
		big.queue_free()
	big = null
	big_stage = null


# ================================================================== the board comparison
## The same creatures on battle hexes at the size they have in a battle (or at army-window
## size): Classic, 2D drawings and 3D models side by side
func _toggle_board() -> void:
	if board:
		if not board_big:
			board_big = true
			return
		board.queue_free()
		board = null
		board_big = false
		return
	_close_big()
	board = Control.new()
	board.position = Vector2(24, 52)
	board.size = Vector2(1232, 556)
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board.draw.connect(_draw_board)
	board.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			board_big = not board_big)
	add_child(board)


func _board_unit(i: int) -> Dictionary:
	var b: Array = BOARD_UNITS[i]
	return {"id": 9001 + i, "species": Game.sort_elements(b[0]), "lvl": 1 + (i % 3) * 3, "umbra": int(b[2]) == 1, "name": "Proto"}


func _draw_board() -> void:
	var font := UI.font()
	board.draw_rect(Rect2(Vector2.ZERO, board.size), Color(0.04, 0.05, 0.12, 0.98))
	board.draw_rect(Rect2(Vector2.ZERO, board.size), UI.GOLD, false, 2.0)
	var styles := ["classic", "2d", "3d"]
	var keep: String = Art.style
	var hs := 28.0 if not board_big else 58.0
	var pose := board_pose
	for si in 3:
		var ox := 18.0 + si * 408.0
		board.draw_string(font, Vector2(ox, 30), str(Art.STYLE_NAMES[styles[si]]) + ("   (battle size)" if not board_big else "   (2x)"), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(17), UI.GOLD)
		var origin := Vector2(ox + 60.0, 110.0) if not board_big else Vector2(ox + 70.0, 120.0)
		var rows := 4 if not board_big else 2
		for y in rows:
			for x in 3:
				var cell := Vector2i(x, y if not board_big else y + 2)
				var cp := origin + Hex.center(Vector2i(x, y)) * hs
				var mine := cell.y >= 2
				var pts := Hex.corners(cp, hs - 1.5)
				board.draw_colored_polygon(pts, Color(UI.CYAN, 0.12) if mine else Color(UI.RED, 0.1))
				pts.append(pts[0])
				board.draw_polyline(pts, Color(UI.CYAN, 0.35) if mine else Color(UI.RED, 0.3), 1.5, true)
		Art.style = styles[si]
		var drawn: Array = []
		for i in BOARD_UNITS.size():
			var b: Array = BOARD_UNITS[i]
			var cell2: Vector2i = b[1]
			var row := cell2.y
			if board_big:
				if row < 2:
					continue
				row -= 2
			var cp2 := origin + Hex.center(Vector2i(cell2.x, row)) * hs
			drawn.append([cp2.y, i, cp2])
		drawn.sort_custom(func(a, c): return a[0] < c[0])
		for dr: Array in drawn:
			var u := _board_unit(int(dr[1]))
			var r := minf(Art.unit_radius(u, 19.0), 25.0) * hs / 28.0
			var team := 1 if bool(u["umbra"]) else 0
			Art.draw_unit(board, u, dr[2], r, team, bt, -1.0 if team == 1 else 1.0, pose)
	Art.style = keep
	board.draw_string(font, Vector2(18, board.size.y - 14), "Same creatures in all three columns. Bottom rows: Pebble, Glacia, Mycelia  ·  Ice+Lightning, Stone+Fire+Lightning, Ice+Fungus+Water.  Top: Umbra enemies.  Click: 2x size  ·  Board view button: close", HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(13), UI.SOFT)


func _toast(text: String, col := UI.GREEN) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color", col)
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.6)


## Photos of all six examples (3 angles + attack, elemental move, walking, defeat) and
## an overview of the gallery, saved to user://screenshots/creatures/
func _save_photos() -> void:
	if busy:
		return
	busy = true
	var dir := "user://screenshots/creatures"
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().process_frame
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(dir + "/overview.png")
	var n := 0
	if board == null:
		_toggle_board()
	for big_v: bool in [false, true]:
		board_big = big_v
		for ps: String in ["idle", "attack"]:
			board_pose = ps
			await get_tree().create_timer(0.8 if ps == "idle" else 0.25).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/board_%s_%s.png" % [dir, "2x" if big_v else "battle", ps])
			n += 1
	board_pose = "idle"
	board.queue_free()
	board = null
	board_big = false
	for i in EXAMPLES.size():
		_open_big(i)
		var st := big_stage
		st.turntable = false
		var tag := "%d_%s" % [i + 1, "_".join(Game.sort_elements(EXAMPLES[i][0]))]
		for view: Array in [["front", -0.55], ["side", 1.4], ["back", 2.6]]:
			st.yaw = float(view[1])
			await get_tree().create_timer(0.5).timeout
			await st.snapshot("%s/%s_%s.png" % [dir, tag, view[0]])
			n += 1
		st.yaw = -0.55
		for mv: Array in [["attack", 0.38], ["special", 0.9], ["walk", 0.45], ["defeat", 1.3]]:
			st.play(str(mv[0]))
			await get_tree().create_timer(float(mv[1])).timeout
			await st.snapshot("%s/%s_%s.png" % [dir, tag, mv[0]])
			n += 1
	# a few hybrids more: all eight peoples once in one mix of two
	for pair: Array in [["aquora", "verdis"], ["ferrum", "solara"], ["glacia", "mycelia", "aquora"], ["pebble", "verdis", "voltara", "solara"]]:
		var els: Array = Game.sort_elements(pair)
		_open_view(els, 777, false)
		big_stage.turntable = false
		big_stage.yaw = -0.55
		await get_tree().create_timer(0.6).timeout
		await big_stage.snapshot("%s/extra_%s.png" % [dir, "_".join(els)])
		n += 1
	_open_view(Game.sort_elements(["glacia", "voltara"]), 41, true)
	big_stage.turntable = false
	await get_tree().create_timer(0.6).timeout
	await big_stage.snapshot("%s/extra_umbra_glacia_voltara.png" % dir)
	n += 1
	_close_big()
	busy = false
	_toast("Saved %d photos to %s" % [n, ProjectSettings.globalize_path(dir)])


func _close() -> void:
	if main:
		main.call("show_map")


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_P:
		_save_photos()
		get_viewport().set_input_as_handled()
	elif k and k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE and big:
		_close_big()
		get_viewport().set_input_as_handled()
