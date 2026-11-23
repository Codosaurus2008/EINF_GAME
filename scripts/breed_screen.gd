class_name BreedScreen
extends Control
## The hybreeding lab on your ship: pick parent 1 in the left column and parent 2 in the right column.
## Characters of the same species as the parent picked on the other side are darkened
## (they can't be bred together). The lab in the middle shows the result and the timer.

const COL_W := 380.0

var main
var stars: Array
var t := 0.0
var pick := [-1, -1]          # unit ids of parent 1 and parent 2
var rows := [{}, {}]          # per column: unit id -> row PanelContainer
var lists: Array = []         # the two VBoxContainers
var art_nodes: Array = []
var lab_box: VBoxContainer
var progress: ProgressBar
var progress_label: Label


func _ready() -> void:
	stars = Art.make_stars(200, Vector2(1280, 720), 5)
	main.make_top_bar(self, "breed")

	for side in 2:
		var x := 16.0 if side == 0 else 1280.0 - 16.0 - COL_W
		var title := UI.label("Parent %d" % (side + 1), 22, UI.CYAN if side == 0 else UI.PINK)
		title.position = Vector2(x + 6, 62)
		add_child(title)
		var frame := UI.panel(UI.CYAN if side == 0 else UI.PINK)
		frame.position = Vector2(x, 96)
		frame.custom_minimum_size = Vector2(COL_W, 608)
		frame.size = Vector2(COL_W, 608)
		add_child(frame)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(COL_W - 28, 580)
		frame.add_child(scroll)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 6)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		lists.append(list)

	var lab := UI.panel(UI.GOLD)
	lab.position = Vector2(16 + COL_W + 14, 62)
	lab.custom_minimum_size = Vector2(1280 - 2 * (16 + COL_W + 14), 642)
	add_child(lab)
	lab_box = VBoxContainer.new()
	lab_box.add_theme_constant_override("separation", 8)
	lab.add_child(lab_box)

	_build_lists()
	_update_lab()
	Game.hatched.connect(_on_hatched)
	Game.breeding_ready.connect(_on_ready)
	Game.acknowledge_ready()          # being in the lab counts as having seen it


## The egg became ready while the lab is open: show it right away
func _on_ready() -> void:
	Game.acknowledge_ready()
	_update_lab()


func _process(delta: float) -> void:
	t += delta
	for a in art_nodes:
		if is_instance_valid(a):
			a.queue_redraw()
	if Game.is_breeding() and not Game.is_ready_to_hatch() and is_instance_valid(progress):
		var total: float = Game.breeding["total"]
		progress.value = 1.0 - Game.breeding_left() / total
		progress_label.text = "Growing... %s left" % _time_text(Game.breeding_left())
	queue_redraw()


func _draw() -> void:
	Art.draw_space(self, Vector2(1280, 720), stars, t)


static func _time_text(sec: float) -> String:
	var s := int(ceil(sec))
	return "%d:%02d" % [s / 60, s % 60]


func _art(u: Dictionary, box_size: Vector2, r: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = box_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): Art.draw_unit(c, u, c.size / 2.0 + Vector2(0, 3), r, 0, t))
	art_nodes.append(c)
	return c


static func _same_species(a: Dictionary, b: Dictionary) -> bool:
	var sa: Array = a["species"].duplicate()
	var sb: Array = b["species"].duplicate()
	sa.sort()
	sb.sort()
	return sa == sb


# ------------------------------------------------------------------ the two columns
func _build_lists() -> void:
	art_nodes.clear()
	var list_units: Array = Game.units.duplicate()
	list_units.sort_custom(func(a, b): return Game.unit_value(a) > Game.unit_value(b) if Game.unit_value(a) != Game.unit_value(b) else a["id"] < b["id"])
	for side in 2:
		for c in lists[side].get_children():
			c.queue_free()
		rows[side] = {}
		for u in list_units:
			var row := PanelContainer.new()
			row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var hb := HBoxContainer.new()
			hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_theme_constant_override("separation", 10)
			row.add_child(hb)
			hb.add_child(_art(u, Vector2(88, 80), minf(Art.unit_radius(u, 22.0), 32.0)))
			var info := VBoxContainer.new()
			info.mouse_filter = Control.MOUSE_FILTER_IGNORE
			info.add_theme_constant_override("separation", 0)
			hb.add_child(info)
			info.add_child(UI.label(u["name"] + ("  (you)" if u.get("hero", false) else ""), 16, UI.TEXT))
			info.add_child(UI.label(Game.species_name(u), 13, UI.SOFT))
			info.add_child(UI.strength_row(u["strengths"], 30.0))
			row.gui_input.connect(_on_row_input.bind(side, u["id"]))
			lists[side].add_child(row)
			rows[side][u["id"]] = row
	_style_rows()


## Highlight the picked parents, darken everything that can't be picked
func _style_rows() -> void:
	for side in 2:
		var other = Game.get_unit(pick[1 - side])
		for id in rows[side]:
			var row: PanelContainer = rows[side][id]
			var u = Game.get_unit(id)
			var blocked := _is_blocked(side, u, other)
			var picked: bool = pick[side] == id
			var col: Color = UI.CYAN if side == 0 else UI.PINK
			var sb := UI.style(Color(0.1, 0.11, 0.24, 0.92), col if picked else Color(col, 0.25), 10, 3 if picked else 1)
			sb.set_content_margin_all(6)
			row.add_theme_stylebox_override("panel", sb)
			row.modulate = Color(0.35, 0.35, 0.45) if blocked else Color.WHITE
			row.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if blocked else Control.CURSOR_POINTING_HAND


func _is_blocked(side: int, u, other) -> bool:
	if u == null or other == null:
		return false
	return u["id"] == other["id"] or _same_species(u, other)


func _on_row_input(event: InputEvent, side: int, id: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _is_blocked(side, Game.get_unit(id), Game.get_unit(pick[1 - side])):
		return
	pick[side] = -1 if pick[side] == id else id
	_style_rows()
	_update_lab()


# ------------------------------------------------------------------ lab (middle)
func _update_lab() -> void:
	for c in lab_box.get_children():
		if c is Control and art_nodes.has(c):
			art_nodes.erase(c)
		c.queue_free()
	progress = null
	lab_box.add_child(UI.label("Hybreeding lab", 26, UI.GOLD))
	lab_box.add_child(UI.wrap_label("Pick parent 1 on the left and parent 2 on the right. The child gets all elements of both parents (max %d) and their strengths, plus +%d%% health and attack per extra element. Parents stay in your crew. No energy? Sell a creature below." % [Game.MAX_ELEMENTS, int(Game.ELEMENT_BONUS * 100)], 13, UI.SOFT, 400))
	lab_box.add_child(UI.label("Hybreeding energy: %d" % Game.breed_charges, 17, UI.GOLD))

	if Game.is_breeding():
		_show_growing()
		return

	var a = Game.get_unit(pick[0])
	var b = Game.get_unit(pick[1])
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	lab_box.add_child(row)
	var pair := [a, b]
	for i in 2:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(170, 130)
		if pair[i] == null:
			var q := UI.label("?", 56, UI.GREY)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(q)
			var l := UI.label("pick parent %d" % (i + 1), 14, UI.SOFT)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(l)
		else:
			box.add_child(_art(pair[i], Vector2(170, 96), Art.unit_radius(pair[i], 30.0)))
			var l := UI.label(pair[i]["name"], 15)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(l)
		row.add_child(box)
		if i == 0:
			row.add_child(UI.label("+", 36, UI.PINK))

	var err := Game.can_breed(a, b)
	if err == "":
		var child_el := Game.child_elements(a, b)
		var chance := Game.hybrid_chance(a, b)
		lab_box.add_child(UI.label("Chance of a new hybrid: %d%%" % int(round(chance * 100)), 18, UI.GREEN if chance >= 0.6 else UI.GOLD))
		lab_box.add_child(UI.wrap_label("Otherwise a copy of one parent hatches. Higher levels give a better chance.", 13, UI.SOFT, 400))
		lab_box.add_child(UI.wrap_label("Hybrid: %d elements, needs %s to grow.\nIt gets the strengths of all its elements:" % [child_el.size(), _time_text(Game.breed_time(child_el.size()))], 14, UI.TEXT, 400))
		lab_box.add_child(UI.strength_row(Game.strengths_of(child_el), 38.0))
	else:
		lab_box.add_child(UI.wrap_label(err, 14, UI.SOFT, 400))

	var breed_b := UI.button("Breed!", UI.PINK, Vector2(400, 48), 20)
	breed_b.disabled = err != ""
	breed_b.pressed.connect(_on_breed)
	lab_box.add_child(breed_b)
	_add_sell_buttons()


## Sell a picked creature for breeding energy (click twice to be sure)
func _add_sell_buttons() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	lab_box.add_child(row)
	var any := false
	for side in 2:
		var u = Game.get_unit(pick[side])
		if u == null:
			continue
		any = true
		var b := UI.button("Sell %s: +%d energy" % [u["name"], Game.SELL_ENERGY], UI.GOLD, Vector2(196, 40), 13)
		var why := Game.can_sell(u)
		b.disabled = why != ""
		b.tooltip_text = why if why != "" else "The creature leaves your army for good."
		b.pressed.connect(func():
			if not b.has_meta("sure"):
				b.set_meta("sure", true)
				b.text = "Really sell %s?" % u["name"]
				UI.set_button_color(b, UI.RED)
				return
			Game.sell_unit(u)
			pick = [-1, -1]
			_build_lists()
			_update_lab())
		row.add_child(b)
	if not any:
		lab_box.add_child(UI.wrap_label("Need energy? Pick a creature and sell it here for +%d hybreeding energy." % Game.SELL_ENERGY, 12, UI.SOFT, 400))


func _on_breed() -> void:
	var a = Game.get_unit(pick[0])
	var b = Game.get_unit(pick[1])
	if Game.can_breed(a, b) != "":
		return
	Game.breed(a, b)
	pick = [-1, -1]
	_style_rows()
	_update_lab()


## The lab while a creature is growing (or ready to hatch)
func _show_growing() -> void:
	if Game.is_ready_to_hatch():
		_show_ready()
		return
	var br: Dictionary = Game.breeding
	var a = Game.get_unit(int(br["a"]))
	var b = Game.get_unit(int(br["b"]))
	lab_box.add_child(HSeparator.new())
	lab_box.add_child(UI.label("A new creature is growing", 20, UI.PINK))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	lab_box.add_child(row)
	var pair := [a, b]
	for i in 2:
		if pair[i] != null:
			row.add_child(_art(pair[i], Vector2(150, 96), Art.unit_radius(pair[i], 30.0)))
		if i == 0:
			row.add_child(UI.label("+", 36, UI.PINK))
	lab_box.add_child(UI.label("Chance of a new hybrid: %d%%" % int(round(float(br.get("chance", 0.3)) * 100)), 16, UI.GOLD))
	progress = ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 1.0
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(400, 22)
	progress.add_theme_stylebox_override("background", UI.style(Color(0.1, 0.1, 0.2), UI.GREY, 8, 1))
	progress.add_theme_stylebox_override("fill", UI.style(UI.PINK, UI.PINK, 8, 0))
	lab_box.add_child(progress)
	progress_label = UI.label("", 16, UI.TEXT)
	lab_box.add_child(progress_label)
	lab_box.add_child(UI.wrap_label("Only one creature can grow at a time. You can keep playing - it also grows while the game is closed.", 13, UI.SOFT, 400))


## The egg is ready: a glowing egg and the Hatch button
func _show_ready() -> void:
	var br: Dictionary = Game.breeding
	lab_box.add_child(HSeparator.new())
	lab_box.add_child(UI.label("Breeding complete!", 22, UI.GOLD))
	var egg := Control.new()
	egg.custom_minimum_size = Vector2(400, 150)
	egg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	egg.draw.connect(func():
		Art.draw_icon(egg, "egg", egg.size / 2.0, 52.0, Color.WHITE, t))
	art_nodes.append(egg)
	lab_box.add_child(egg)
	lab_box.add_child(UI.wrap_label("Your new creature is ready to hatch! Chance of a new hybrid: %d%%" % int(round(float(br.get("chance", 0.3)) * 100)), 15, UI.TEXT, 400))
	var hb := UI.button("Hatch!", UI.GOLD, Vector2(400, 54), 22)
	hb.pressed.connect(func(): Game.hatch_now())
	lab_box.add_child(hb)


func _on_hatched(child: Dictionary) -> void:
	_build_lists()
	_update_lab()
	lab_box.add_child(HSeparator.new())
	if child.has("copy_of"):
		lab_box.add_child(UI.label("No hybrid this time...", 20, UI.GOLD))
		lab_box.add_child(UI.wrap_label("A copy of %s hatched. Higher levels give a better chance." % child["copy_of"], 14, UI.SOFT, 400))
	else:
		lab_box.add_child(UI.label("A new hybrid is born!", 20, UI.GREEN))
	lab_box.add_child(_art(child, Vector2(400, 100), Art.unit_radius(child, 28.0)))
	lab_box.add_child(UI.wrap_label("%s - %s, %d elements" % [child["name"], Game.species_name(child), Game.elements(child)], 15, UI.TEXT, 400))
	lab_box.add_child(UI.strength_row(child["strengths"], 38.0))
