class_name AccountScreen
extends Control
## "Who is playing?" - the first screen. Every player has their own saved game (no passwords).
## Pick a player to continue their game, make a new player (starts a new game), rename or
## remove players. Also reachable from the pause menu ("Switch player").

var main: Node
var t := 0.0
var list_box: VBoxContainer
var name_edit: LineEdit
var stars: Array = []
var note: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 180:
		stars.append([Vector2(rng.randf() * 1280.0, rng.randf() * 720.0), rng.randf_range(0.6, 2.2), rng.randf() * TAU])
	var p := UI.panel(UI.CYAN)
	p.position = Vector2(290, 70)
	p.custom_minimum_size = Vector2(700, 580)
	p.size = Vector2(700, 580)
	add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	p.add_child(vb)
	var title := UI.label("Who is playing?", 34, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := UI.label("Every player has their own saved game.", 15, UI.SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(670, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 8)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)
	vb.add_child(HSeparator.new())
	vb.add_child(UI.label("New player - starts a new game", 18, UI.GREEN))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Name"
	name_edit.max_length = 20
	name_edit.custom_minimum_size = Vector2(400, 46)
	name_edit.add_theme_font_size_override("font_size", UI.fs(18))
	name_edit.add_theme_stylebox_override("normal", UI.style(Color(0.05, 0.06, 0.14), UI.GREEN, 8, 2))
	name_edit.add_theme_stylebox_override("focus", UI.style(Color(0.07, 0.09, 0.2), UI.GREEN.lightened(0.3), 8, 2))
	name_edit.text_submitted.connect(func(_txt: String): _create())
	row.add_child(name_edit)
	var create := UI.button("Create and play", UI.GREEN, Vector2(240, 46), 18)
	create.pressed.connect(_create)
	row.add_child(create)
	note = UI.label("", 14, UI.ORANGE)
	vb.add_child(note)
	_fill()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
	for s: Array in stars:
		var a := 0.45 + 0.4 * sin(t * 1.3 + float(s[2]))
		draw_circle(s[0], float(s[1]), Color(0.8, 0.88, 1.0, a))
	# a slowly turning planet in the corner
	var c := Vector2(1120, 600)
	draw_circle(c, 120.0, Color("#1c3a6a"))
	for i in 6:
		var y := -100.0 + i * 40.0 + fmod(t * 6.0, 40.0)
		var w := sqrt(maxf(0.0, 120.0 * 120.0 - y * y))
		draw_line(c + Vector2(-w, y), c + Vector2(w, y), Color(0.3, 0.7, 1.0, 0.25), 6.0)
	draw_arc(c, 122.0, 0.0, TAU, 64, Color(0.4, 0.85, 1.0, 0.6), 3.0)


func _fill() -> void:
	for c in list_box.get_children():
		c.queue_free()
	var sorted: Array = Game.users.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["last"]) > float(b["last"]))
	for u: Dictionary in sorted:
		list_box.add_child(_card(u))


func _card(u: Dictionary) -> Control:
	var id := str(u["id"])
	var current := id == Game.user_id
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.style(Color(0.1, 0.12, 0.26, 0.95), UI.GOLD if current else UI.GREY, 10, 2))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	var col := Color.from_hsv(float(absi(hash(str(u["name"]))) % 360) / 360.0, 0.55, 0.95)
	var av := Control.new()
	av.custom_minimum_size = Vector2(56, 56)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var initial := str(u["name"]).substr(0, 1).to_upper()
	av.draw.connect(func():
		av.draw_circle(Vector2(28, 28), 26.0, col.darkened(0.45))
		av.draw_arc(Vector2(28, 28), 26.0, 0.0, TAU, 32, col, 3.0)
		av.draw_string(UI.bold_font(), Vector2(10, 40), initial, HORIZONTAL_ALIGNMENT_CENTER, 36, 28, col.lightened(0.3)))
	hb.add_child(av)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)
	var name_l := UI.label(str(u["name"]) + ("   (last played)" if current else ""), 20, UI.GOLD if current else UI.TEXT)
	info.add_child(name_l)
	var sm := Game.user_summary(id)
	var txt := "New game" if bool(sm["new"]) else "Freed %d planets  ·  Crew %d  ·  %d coins" % [int(sm["freed"]), int(sm["crew"]), int(sm["coins"])]
	if float(u["last"]) > 0.0:
		txt += "  ·  " + Time.get_date_string_from_unix_time(int(float(u["last"])))
	info.add_child(UI.label(txt, 14, UI.SOFT))
	var play := UI.button("Play", UI.GREEN, Vector2(90, 44), 17)
	play.pressed.connect(func(): _play(id))
	hb.add_child(play)
	var ren := UI.button("Rename", UI.CYAN, Vector2(100, 44), 15)
	ren.pressed.connect(func(): _rename(info, name_l, id))
	hb.add_child(ren)
	var del := UI.button("Delete", UI.RED, Vector2(90, 44), 15)
	del.disabled = current or Game.users.size() <= 1
	del.tooltip_text = "Removes this player and their saved game" if not del.disabled else "The last player can't be removed here"
	del.pressed.connect(func():
		if not del.has_meta("sure"):
			del.set_meta("sure", true)
			del.text = "Sure?"
			return
		Game.delete_user(id)
		_fill())
	hb.add_child(del)
	return p


func _rename(info: VBoxContainer, name_l: Label, id: String) -> void:
	if info.has_meta("editing"):
		return
	info.set_meta("editing", true)
	name_l.visible = false
	var ed := LineEdit.new()
	ed.text = str(Game.user_by_id(id)["name"])
	ed.max_length = 20
	ed.custom_minimum_size = Vector2(220, 36)
	ed.add_theme_font_size_override("font_size", UI.fs(17))
	info.add_child(ed)
	info.move_child(ed, 0)
	ed.grab_focus()
	ed.select_all()
	ed.text_submitted.connect(func(_txt: String): _rename_done(ed, id))
	ed.focus_exited.connect(func(): _rename_done(ed, id))


func _rename_done(ed: LineEdit, id: String) -> void:
	if not is_instance_valid(ed) or ed.has_meta("done"):
		return
	var txt := ed.text.strip_edges()
	var other := Game.user_named(txt)
	if not other.is_empty() and str(other["id"]) != id:
		note.text = "There is already a player called %s." % txt
		return
	ed.set_meta("done", true)
	Game.rename_user(id, txt)
	note.text = ""
	_fill.call_deferred()


func _play(id: String) -> void:
	Game.switch_user(id)
	main.show_map()


func _create() -> void:
	var nm := name_edit.text.strip_edges()
	if nm.is_empty():
		note.text = "Type a name first."
		name_edit.grab_focus()
		return
	Game.create_user(nm)
	main.show_map()
