class_name BattleScreen
extends Control
## Battle for planet `planet_n`. A battle is several combats (rounds):
## 1. Prepare (30 s): buy creatures in the shop below, buy more places, drag them onto your
##    half of the hex board. You can already see the enemy wave.
## 2. Fight: the creatures walk from hex to hex and fight on their own.
## 3. Win a combat: coins (more after every win). Lose: one life is gone.
## Win WIN_ROUNDS combats before your lives run out and the planet is free.

const S := 28.0                       # hex radius in pixels
const ORIGIN := Vector2(458, 64)      # centre of hex (0, 0): the board is centred on the screen
const BENCH_Y := 462.0
const BENCH_STEP := 62.0              # bench slots are centred under the board
const SHOP_TOP := 500.0

var main
var planet_n := 1
var stars: Array
var t := 0.0

# battle state
var phase := "prep"            # prep, fight, result, over
var wins := 0
var losses := 0
var coins: int = Game.START_COINS
var places: int = Game.START_PLACES
var round_no := 1
var locked := false
var timer: float = Game.PREP_TIME
var result_t := 0.0
var speed := 1.0
var owned: Array = []          # creatures bought in this battle
var board: Dictionary = {}     # unit id -> Vector2i cell
var bench: Array = []          # BENCH_SIZE slots: unit Dictionary or null
var shop: Array = []           # SHOP_SIZE slots: unit Dictionary or null (bought)
var wave: Array = []           # [unit, Vector2i cell] pairs
var sim: BattleSim = null
var fx: Array = []
var merc_id := -1

# dragging
var drag_u: Variant = null
var hover_u: Variant = null
var info_pop: Control = null   # right-click window with the strengths

# interface
var round_l: Label
var timer_l: Label
var coins_l: Label
var places_l: Label
var place_b: Button
var fight_b: Button
var speed_b: Button
var lock_b: Button
var wave_l: Label
var detail: VBoxContainer
var banner_l: Label
var shop_box: HBoxContainer
var over_box: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	stars = Art.make_stars(200, Vector2(1280, 720), 11)
	for i in Game.BENCH_SIZE:
		bench.append(null)
	_build_panel()
	_build_shop()
	_roll_shop()
	_new_wave()
	_refresh()


# ================================================================== panels
func _build_panel() -> void:
	var pl: Dictionary = Game.PLANETS[planet_n]
	# left: round, lives, timer, fight
	var lp := UI.panel(UI.GOLD)
	lp.position = Vector2(12, 12)
	lp.custom_minimum_size = Vector2(400, 436)
	add_child(lp)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	lp.add_child(left)
	left.add_child(UI.label("Battle for %s" % pl["name"], 24, Color(pl["accent"]).lerp(UI.TEXT, 0.4)))
	round_l = UI.wrap_label("", 16, UI.TEXT, 370)
	left.add_child(round_l)
	timer_l = UI.label("", 28, UI.CYAN)
	left.add_child(timer_l)
	fight_b = UI.button("Fight now!", UI.GOLD, Vector2(370, 48), 19)
	fight_b.pressed.connect(_start_fight)
	left.add_child(fight_b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	left.add_child(row)
	speed_b = UI.button("Speed 1x", UI.CYAN, Vector2(118, 38), 14)
	speed_b.pressed.connect(_toggle_speed)
	row.add_child(speed_b)
	var sym := UI.button("Symbols", UI.ORANGE, Vector2(118, 38), 14)
	sym.pressed.connect(func(): main.show_legend())
	row.add_child(sym)
	var quit := UI.button("Give up", UI.GREY.lightened(0.4), Vector2(118, 38), 14)
	quit.pressed.connect(func(): main.show_map())
	row.add_child(quit)
	var look_b := UI.button("Creature look: %s  (F5)" % Art.STYLE_NAMES[Art.style], UI.PINK, Vector2(370, 34), 14)
	look_b.pressed.connect(func():
		Art.next_style()
		look_b.text = "Creature look: %s  (F5)" % Art.STYLE_NAMES[Art.style])
	left.add_child(look_b)
	banner_l = UI.wrap_label("", 18, UI.GOLD, 370)
	left.add_child(banner_l)
	over_box = VBoxContainer.new()
	over_box.add_theme_constant_override("separation", 8)
	left.add_child(over_box)

	# right: enemy wave + small info about the creature under the mouse
	var rp := UI.panel(UI.RED.lightened(0.2))
	rp.position = Vector2(868, 12)
	rp.custom_minimum_size = Vector2(400, 0)
	add_child(rp)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	rp.add_child(right)
	wave_l = UI.wrap_label("", 14, UI.SOFT, 370)
	right.add_child(wave_l)
	right.add_child(HSeparator.new())
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 2)
	right.add_child(detail)

	# centre, under the board: coins and the next seat
	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 18)
	mid.position = Vector2(416, 392)
	mid.custom_minimum_size = Vector2(448, 40)
	add_child(mid)
	coins_l = UI.label("", 19, UI.GOLD)
	mid.add_child(coins_l)
	places_l = UI.label("", 15, UI.TEXT)
	mid.add_child(places_l)
	place_b = UI.button("Seat", UI.GREEN, Vector2(150, 36), 14)
	place_b.pressed.connect(_buy_place)
	mid.add_child(place_b)
	_show_detail(null)


## Small info box (right side). Right-click a creature for its strengths.
func _show_detail(u) -> void:
	for c in detail.get_children():
		c.queue_free()
	if u == null:
		detail.add_child(UI.wrap_label("Point at a creature for info, right-click it for its strengths. Drag yours to place them, drag one into the shop to sell it.", 13, UI.SOFT, 370))
		return
	var st := Game.unit_stats(u)
	var kind: String = Game.species_name(u)
	if u.get("merc", false):
		kind += " (volunteer)"
	elif u["id"] < 0:
		kind += " (Umbra)"
	detail.add_child(UI.label("%s  -  %s" % [u["name"], kind], 14))
	detail.add_child(UI.label("Lv %d · Tier %s · HP %d · ATK %d · Range %d" % [Game.level(u), Game.tier_name(Game.level(u)), st["hp"], st["atk"], maxi(1, int(round(st["range"])))], 12, UI.GOLD))
	detail.add_child(UI.strength_row(u["strengths"], 22.0))


## Right-click window that explains the strengths of one creature
func _show_strengths(u: Dictionary, at: Vector2) -> void:
	_close_info()
	var p := UI.panel(UI.ORANGE)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	info_pop = p
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(vb)
	vb.add_child(UI.label("%s  -  %s" % [u["name"], Game.species_name(u)], 17, UI.ORANGE))
	vb.add_child(UI.label("Level %d = tier %s: strengths x%.1f" % [Game.level(u), Game.tier_name(Game.level(u)), Game.TIER_MULT[Game.tier(Game.level(u)) - 1]], 13, UI.SOFT))
	for s in u["strengths"]:
		vb.add_child(UI.strength_line(s, 34.0, 300.0))
	p.reset_size()
	var sz := p.get_combined_minimum_size()
	p.position = Vector2(clampf(at.x + 16, 8, 1272 - sz.x), clampf(at.y - sz.y / 2, 8, 712 - sz.y))


func _close_info() -> void:
	if info_pop != null:
		info_pop.queue_free()
		info_pop = null


func _toggle_speed() -> void:
	speed = 2.0 if speed == 1.0 else (4.0 if speed == 2.0 else 1.0)
	speed_b.text = "Speed %dx" % int(speed)


# ================================================================== shop
func _build_shop() -> void:
	var panel := UI.panel(UI.CYAN)
	panel.position = Vector2(12, SHOP_TOP)
	panel.custom_minimum_size = Vector2(1256, 208)
	add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	panel.add_child(hb)
	shop_box = HBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 8)
	hb.add_child(shop_box)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	hb.add_child(side)
	side.add_child(UI.label("SHOP", 22, UI.CYAN))
	side.add_child(UI.wrap_label("Price = elements x tier.\nNew creatures every round.", 13, UI.SOFT, 150))
	lock_b = UI.icon_button("unlock", "Lock the shop: keep these creatures for the next round", UI.CYAN, Vector2(150, 56))
	lock_b.pressed.connect(_toggle_lock)
	side.add_child(lock_b)


func _toggle_lock() -> void:
	locked = not locked
	_refresh()


## Your own creatures you have not bought yet, plus volunteers from freed planets
func _roll_shop() -> void:
	var pool: Array = []
	for u in Game.units:
		if not _is_owned(u):
			pool.append(u)
	# the 2 strongest creatures you have not bought are always offered, the rest is random
	pool.sort_custom(func(x, y): return Game.unit_value(x) > Game.unit_value(y))
	var rest: Array = pool.slice(2)
	rest.shuffle()
	pool = pool.slice(0, 2) + rest
	var own_count := mini(pool.size(), randi_range(3, 4))
	shop.clear()
	for i in own_count:
		shop.append(pool[i])
	while shop.size() < Game.SHOP_SIZE:
		shop.append(Game.mercenary(merc_id))
		merc_id -= 1
	shop.shuffle()
	_build_cards()


func _is_owned(u: Dictionary) -> bool:
	for o in owned:
		if o["id"] == u["id"]:
			return true
	return false


func _build_cards() -> void:
	for c in shop_box.get_children():
		c.queue_free()
	for i in shop.size():
		var u: Variant = shop[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(206, 166)
		card.add_theme_stylebox_override("panel", UI.style(Color(UI.PANEL, 0.6), Color(UI.CYAN, 0.4), 10, 1))
		shop_box.add_child(card)
		if u == null:
			card.add_child(UI.label("  sold", 15, UI.GREY.lightened(0.3)))
			continue
		card.mouse_entered.connect(func(): _show_detail(u))
		card.gui_input.connect(func(ev: InputEvent):
			var m := ev as InputEventMouseButton
			if m != null and m.pressed and m.button_index == MOUSE_BUTTON_RIGHT:
				_show_strengths(u, get_local_mouse_position()))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		vb.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_child(vb)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_PASS
		vb.add_child(top)
		var art := Control.new()
		art.custom_minimum_size = Vector2(64, 60)
		art.mouse_filter = Control.MOUSE_FILTER_PASS
		art.draw.connect(func(): Art.draw_unit(art, u, Vector2(32, 32), minf(Art.unit_radius(u, 17.0), 24.0), 0, 0.0, 1.0))
		top.add_child(art)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		top.add_child(info)
		info.add_child(UI.label(u["name"], 15))
		info.add_child(UI.label("volunteer" if u.get("merc", false) else "yours", 12, UI.PINK if u.get("merc", false) else UI.GREEN))
		vb.add_child(UI.strength_row(u["strengths"], 24.0))
		var price := Game.unit_price(u)
		var b := UI.button("Buy  -  %d coin%s" % [price, "" if price == 1 else "s"], UI.GOLD, Vector2(190, 36), 14)
		b.disabled = phase != "prep" or coins < price or not _has_space()
		b.pressed.connect(func(): _buy(i))
		vb.add_child(b)


func _has_space() -> bool:
	return _board_count() < places or bench.has(null)


func _buy(i: int) -> void:
	var u: Variant = shop[i]
	if u == null or phase != "prep":
		return
	var price := Game.unit_price(u)
	if coins < price or not _has_space():
		return
	coins -= price
	owned.append(u)
	shop[i] = null
	if _board_count() < places:
		board[u["id"]] = _free_cell_for(u)
	else:
		bench[bench.find(null)] = u
	_refresh()


func _sell(u: Dictionary) -> void:
	coins += Game.unit_price(u)
	_remove_from_slots(u)
	owned = owned.filter(func(o): return o["id"] != u["id"])
	_refresh()


func _buy_place() -> void:
	var cost := Game.place_cost(places)
	if phase != "prep" or coins < cost or places >= Game.MAX_PLACES:
		return
	coins -= cost
	places += 1
	# a creature waiting on the bench jumps onto the new place
	for i in bench.size():
		if bench[i] != null:
			var u: Dictionary = bench[i]
			bench[i] = null
			board[u["id"]] = _free_cell_for(u)
			break
	_refresh()


# ================================================================== board helpers
func _board_count() -> int:
	return board.size()


func _unit_by_id(id: int) -> Variant:
	for u in owned:
		if u["id"] == id:
			return u
	return null


func _cell_taken(cell: Vector2i) -> bool:
	for id in board:
		if board[id] == cell:
			return true
	return false


## Close fighters in front (rows 4-5), long range in the back (rows 6-7)
func _free_cell_for(u: Dictionary) -> Vector2i:
	var rng: float = Game.unit_stats(u)["range"]
	var rows: Array = [4, 5, 6, 7] if rng <= 1.5 else [7, 6, 5, 4]
	var order := [3, 4, 2, 5, 1, 6, 0, 7]
	for y in rows:
		for x in order:
			var c := Vector2i(x, y)
			if not _cell_taken(c):
				return c
	return Vector2i(0, 4)


func _remove_from_slots(u: Dictionary) -> void:
	board.erase(u["id"])
	for i in bench.size():
		if bench[i] != null and bench[i]["id"] == u["id"]:
			bench[i] = null


func _px(p: Vector2) -> Vector2:
	return ORIGIN + p * S


func _cell_px(cell: Vector2i) -> Vector2:
	return ORIGIN + Hex.center(cell) * S


func _bench_px(i: int) -> Vector2:
	return Vector2(640 + (i - (Game.BENCH_SIZE - 1) / 2.0) * BENCH_STEP, BENCH_Y)


func _cell_at(p: Vector2) -> Vector2i:
	for y in Game.BOARD_ROWS:
		for x in Game.BOARD_COLS:
			var c := Vector2i(x, y)
			if _cell_px(c).distance_to(p) < S * 0.87:
				return c
	return Vector2i(-1, -1)


func _bench_at(p: Vector2) -> int:
	for i in Game.BENCH_SIZE:
		if _bench_px(i).distance_to(p) < S * 0.9:
			return i
	return -1


func _unit_at(p: Vector2) -> Variant:
	if sim != null and phase != "prep":
		for f in sim.fighters:
			if f["alive"] and _px(f["pos"]).distance_to(p) < S * 0.85:
				return f["u"]
	var cell := _cell_at(p)
	if cell.x >= 0:
		for id in board:
			if board[id] == cell:
				return _unit_by_id(id)
		if phase == "prep":
			for w in wave:
				if w[1] == cell:
					return w[0]
	var bi := _bench_at(p)
	if bi >= 0:
		return bench[bi]
	return null


func _radius(u: Dictionary) -> float:
	return minf(Art.unit_radius(u, 19.0), 25.0)


# ================================================================== rounds
func _new_wave() -> void:
	wave = Game.enemy_wave(planet_n, wins + 1)


func _start_fight() -> void:
	if phase != "prep":
		return
	_drop_drag()
	phase = "fight"
	var mine := []
	for id in board:
		mine.append([_unit_by_id(id), board[id]])
	sim = BattleSim.new()
	sim.setup(mine, wave)
	fx.clear()
	_refresh()


func _end_fight() -> void:
	var text := ""
	if sim.winner == 0:
		var reward := Game.win_reward(wins)
		wins += 1
		coins += reward
		text = "Round won!  +%d coins" % reward
	else:
		losses += 1
		coins += Game.LOSS_REWARD
		text = "Round lost...  one life gone (+%d coin)" % Game.LOSS_REWARD
	if wins >= Game.WIN_ROUNDS or losses >= Game.LIVES:
		_finish_battle()
		return
	phase = "result"
	result_t = 2.5
	banner_l.text = text
	banner_l.add_theme_color_override("font_color", UI.GREEN if sim.winner == 0 else UI.RED)
	_refresh()


func _next_round() -> void:
	round_no += 1
	phase = "prep"
	timer = Game.PREP_TIME
	sim = null
	fx.clear()
	if locked:
		_build_cards()
	else:
		_roll_shop()
	_new_wave()
	banner_l.text = ""
	_refresh()


func _finish_battle() -> void:
	phase = "over"
	var pl: Dictionary = Game.PLANETS[planet_n]
	for c in over_box.get_children():
		c.queue_free()
	_close_info()
	_show_detail(null)
	var victory := wins >= Game.WIN_ROUNDS
	var freed_before := Game.conquered
	var reward := Game.battle_reward(planet_n, victory, wins)
	Game.add_reward(reward)
	var lines: Array = []        # progress lines: [text, colour]
	if victory:
		banner_l.add_theme_color_override("font_color", UI.GREEN)
		banner_l.text = "%s is free!" % pl["name"]
		if planet_n == Game.SUN:
			Game.conquer(planet_n)
			lines.append(["The Umbra are defeated - every planet is free again!", UI.GOLD])
		else:
			var joined := Game.conquer(planet_n)
			var names := []
			for u in joined:
				names.append(u["name"])
			lines.append(["New crew: %s (%s)" % [", ".join(names), pl["species"]], UI.GREEN])
			lines.append(["+1 hybreeding energy", UI.PINK])
	else:
		banner_l.add_theme_color_override("font_color", UI.RED)
		banner_l.text = "Defeat on %s" % pl["name"]
		lines.append(["Tip: choose your team and placement more carefully, or hybreed stronger creatures.", UI.SOFT])
	_show_end_screen(victory, reward, lines, freed_before)
	_refresh()


# ================================================================== end screen (victory / defeat)
var end_fx: Control = null
var end_t := 0.0
var end_win := false


## Full-screen animation: big VICTORY / DEFEAT, below it the rewards and your progress
func _show_end_screen(victory: bool, reward: Dictionary, lines: Array, freed_before: int) -> void:
	end_win = victory
	end_t = 0.0
	var pl: Dictionary = Game.PLANETS[planet_n]
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.06, 0.0) if victory else Color(0.08, 0.0, 0.02, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var tw := root.create_tween()
	tw.tween_property(dim, "color:a", 0.82, 0.5)

	# rays / sparks (victory) or falling ash (defeat), drawn every frame
	end_fx = Control.new()
	end_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_fx.draw.connect(_draw_end_fx)
	root.add_child(end_fx)

	# big title
	var title := Label.new()
	title.text = "VICTORY!" if victory else "DEFEAT"
	title.add_theme_font_override("font", UI.bold_font())
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", UI.GOLD if victory else UI.RED)
	title.add_theme_color_override("font_outline_color", Color("#2a1203") if victory else Color("#1a0006"))
	title.add_theme_constant_override("outline_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(1280, 130)
	title.position = Vector2(0, 70)
	title.pivot_offset = Vector2(640, 65)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	var tt := root.create_tween()
	if victory:
		title.scale = Vector2(0.2, 0.2)
		title.modulate.a = 0.0
		tt.set_parallel(true)
		tt.tween_property(title, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tt.tween_property(title, "modulate:a", 1.0, 0.3)
	else:
		title.position.y = -140
		tt.tween_property(title, "position:y", 70.0, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var sub := UI.label(("%s is free from the Umbra!" % pl["name"]) if victory else ("The Umbra kept %s ..." % pl["name"]), 22, UI.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size = Vector2(1280, 40)
	sub.position = Vector2(0, 200)
	sub.modulate.a = 0.0
	root.add_child(sub)
	root.create_tween().tween_property(sub, "modulate:a", 1.0, 0.5).set_delay(0.6)

	# panel with rewards and progress
	var panel := UI.panel(UI.GOLD if victory else UI.RED)
	panel.custom_minimum_size = Vector2(640, 0)
	panel.position = Vector2(320, 262)
	panel.modulate.a = 0.0
	root.add_child(panel)
	var pt := root.create_tween()
	pt.tween_property(panel, "modulate:a", 1.0, 0.5).set_delay(0.9)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	vb.add_child(UI.label("Rewards", 22, UI.GOLD))
	var rew := HBoxContainer.new()
	rew.add_theme_constant_override("separation", 10)
	vb.add_child(rew)
	rew.add_child(UI.icon("coin", 34.0))
	var coin_l := UI.label("+0", 26, UI.GOLD)
	coin_l.custom_minimum_size = Vector2(110, 0)
	rew.add_child(coin_l)
	rew.add_child(UI.icon("gem", 34.0))
	var gem_l := UI.label("+0", 26, Color("#9ff3ff"))
	rew.add_child(gem_l)
	var ct := root.create_tween()
	ct.tween_interval(1.3)
	ct.tween_method(func(v: float): coin_l.text = "+%d" % int(v), 0.0, float(reward["coins"]), 1.0)
	ct.tween_method(func(v: float): gem_l.text = "+%d" % int(v), 0.0, float(reward["gems"]), 0.4)
	vb.add_child(UI.label("You now have %d coins and %d gems" % [Game.coins, Game.gems], 14, UI.SOFT))

	vb.add_child(HSeparator.new())
	vb.add_child(UI.label("Progress", 22, UI.CYAN))
	vb.add_child(UI.label("Combats won: %d / %d   ·   Lives left: %d / %d" % [wins, Game.WIN_ROUNDS, Game.LIVES - losses, Game.LIVES], 16, UI.TEXT))
	vb.add_child(UI.label("Planets freed: %d / %d" % [Game.conquered, Game.SUN], 16, UI.TEXT))
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = float(Game.SUN)
	bar.value = float(freed_before)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(600, 20)
	bar.add_theme_stylebox_override("background", UI.style(Color(0.1, 0.1, 0.2), UI.GREY, 8, 1))
	bar.add_theme_stylebox_override("fill", UI.style(UI.GREEN, UI.GREEN, 8, 0))
	vb.add_child(bar)
	if Game.conquered > freed_before:
		root.create_tween().tween_property(bar, "value", float(Game.conquered), 0.9).set_delay(1.6).set_trans(Tween.TRANS_CUBIC)
	for ln in lines:
		vb.add_child(UI.wrap_label(ln[0], 16, ln[1], 600))

	# buttons
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var map_b := UI.button("Galaxy map", UI.GOLD if victory else UI.CYAN, Vector2(200, 48), 18)
	map_b.pressed.connect(func(): main.show_map())
	row.add_child(map_b)
	if not victory:
		var again := UI.button("Try again", UI.GOLD, Vector2(180, 48), 18)
		again.pressed.connect(func(): main.show_battle(planet_n))
		row.add_child(again)
		var lab := UI.button("Hybreeding", UI.PINK, Vector2(180, 48), 18)
		lab.pressed.connect(func(): main.show_breed())
		row.add_child(lab)


func _draw_end_fx() -> void:
	if end_fx == null:
		return
	var c := Vector2(640, 135)
	if end_win:
		# turning golden rays behind the title
		var a := clampf(end_t / 0.8, 0.0, 1.0)
		for i in 16:
			var ang := end_t * 0.4 + TAU * i / 16.0
			var p1 := c + Vector2(cos(ang - 0.07), sin(ang - 0.07)) * 900.0
			var p2 := c + Vector2(cos(ang + 0.07), sin(ang + 0.07)) * 900.0
			end_fx.draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(1.0, 0.8, 0.3, 0.10 * a))
		Art.glow(end_fx, c, 220.0, Color(UI.GOLD, 0.5 * a), 0.35)
		# sparks flying out
		for i in 40:
			var k := fmod(end_t * 0.5 + i * 0.137, 1.0)
			var ang := i * 2.399
			var p := c + Vector2(cos(ang), sin(ang)) * (60.0 + k * 520.0)
			end_fx.draw_circle(p, 3.0 * (1.0 - k) + 1.0, Color(1.0, 0.9, 0.5, (1.0 - k) * a))
	else:
		# slowly falling grey-red ash
		for i in 60:
			var x := fmod(i * 97.3, 1280.0) + sin(end_t + i) * 12.0
			var y := fmod(i * 53.1 + end_t * (30.0 + (i % 5) * 12.0), 760.0) - 20.0
			end_fx.draw_circle(Vector2(x, y), 2.0 + (i % 3), Color(0.6, 0.25, 0.3, 0.45))


## "Reward: (coin) +40  (gem) +0"
func _add_reward_row(r: Dictionary) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.add_child(UI.label("Reward:", 17, UI.TEXT))
	hb.add_child(UI.icon("coin", 24.0))
	hb.add_child(UI.label("+%d" % int(r["coins"]), 18, UI.GOLD))
	if int(r["gems"]) > 0:
		hb.add_child(UI.icon("gem", 24.0))
		hb.add_child(UI.label("+%d" % int(r["gems"]), 18, Color("#9ff3ff")))
	over_box.add_child(hb)


func _refresh() -> void:
	var hearts := ""
	for i in Game.LIVES:
		hearts += "♥ " if i < Game.LIVES - losses else "♡ "
	round_l.text = "Round %d   ·   Wins %d / %d   ·   Lives %s" % [round_no, wins, Game.WIN_ROUNDS, hearts.strip_edges()]
	coins_l.text = "%d battle coins" % coins
	places_l.text = "Seats %d / %d" % [_board_count(), places]
	var cost := Game.place_cost(places)
	if places >= Game.MAX_PLACES:
		place_b.text = "All seats"
		place_b.disabled = true
	else:
		place_b.text = "Next seat: %d" % cost
		place_b.disabled = phase != "prep" or coins < cost
	fight_b.disabled = phase != "prep"
	UI.set_icon(lock_b, "lock" if locked else "unlock", UI.GOLD if locked else UI.CYAN)
	lock_b.tooltip_text = "Shop locked: same creatures next round (click to unlock)" if locked else "Lock the shop: keep these creatures for the next round"
	if phase != "over":
		wave_l.text = "Umbra wave %d: %d creatures, level %d.\nWin %d combats to free %s." % [wins + 1, wave.size(), Game.level(wave[0][0]) if wave.size() > 0 else 1, Game.WIN_ROUNDS, Game.PLANETS[planet_n]["name"]]
	else:
		wave_l.text = ""
	_build_cards()


# ================================================================== loop + input
func _process(delta: float) -> void:
	t += delta
	match phase:
		"prep":
			timer -= delta
			timer_l.text = "Prepare: %d s" % int(ceil(maxf(timer, 0.0)))
			timer_l.add_theme_color_override("font_color", UI.RED if timer < 8.0 else UI.CYAN)
			if timer <= 0.0:
				_start_fight()
		"fight":
			timer_l.text = "Fighting... %d s" % int(sim.time)
			var left := delta * speed
			while left > 0.0 and sim.winner == -1:
				var dt: float = minf(left, 0.05)
				sim.step(dt)
				left -= dt
			_take_events()
			if sim.winner != -1:
				_end_fight()
		"result":
			result_t -= delta
			timer_l.text = "Next round..."
			if result_t <= 0.0:
				_next_round()
		"over":
			timer_l.text = ""
			end_t += delta
			if end_fx != null:
				end_fx.queue_redraw()
	if drag_u == null and phase != "over":
		var u: Variant = _unit_at(get_local_mouse_position())
		if u != null and (hover_u == null or u["id"] != hover_u["id"]):
			hover_u = u
			_show_detail(u)
	for e in fx:
		e["life"] -= delta
	fx = fx.filter(func(e): return e["life"] > 0.0)
	queue_redraw()


## Any click closes the strengths window (a right-click on a creature opens a new one)
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and info_pop != null:
		_close_info()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		var ru: Variant = _unit_at(mb.position)
		if ru != null:
			_show_strengths(ru, mb.position)
		return
	if phase != "prep" or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		var u: Variant = _unit_at(mb.position)
		if u != null and _is_owned(u):
			drag_u = u
	elif drag_u != null:
		_drop(mb.position)


func _drop_drag() -> void:
	drag_u = null


## Drop a dragged creature on a hex, a bench slot, or the shop (= sell)
func _drop(p: Vector2) -> void:
	var u: Dictionary = drag_u
	drag_u = null
	if p.y > SHOP_TOP:
		_sell(u)
		return
	var on_board := board.has(u["id"])
	var bench_i := -1
	for i in bench.size():
		if bench[i] != null and bench[i]["id"] == u["id"]:
			bench_i = i
	var cell := _cell_at(p)
	if cell.x >= 0 and cell.y >= Game.BOARD_ROWS / 2:
		var other: Variant = null
		for id in board:
			if board[id] == cell:
				other = _unit_by_id(id)
		if other != null and other["id"] == u["id"]:
			return
		if on_board:
			if other != null:
				board[other["id"]] = board[u["id"]]
			board[u["id"]] = cell
		else:
			if other != null:            # swap with the bench
				board.erase(other["id"])
				bench[bench_i] = other
				board[u["id"]] = cell
			elif _board_count() < places:
				bench[bench_i] = null
				board[u["id"]] = cell
			else:
				banner_l.text = "No free seat - buy one first!"
				banner_l.add_theme_color_override("font_color", UI.RED)
		_refresh()
		return
	var bi := _bench_at(p)
	if bi >= 0:
		var other: Variant = bench[bi]
		if on_board:
			var old: Vector2i = board[u["id"]]
			board.erase(u["id"])
			bench[bi] = u
			if other != null:
				board[other["id"]] = old
		elif bench_i >= 0:
			bench[bench_i] = other
			bench[bi] = u
		_refresh()


## Turns simulation events into short visual effects
func _take_events() -> void:
	for e in sim.events:
		var v: Dictionary = e.duplicate()
		match e["type"]:
			"shot", "zap":
				v["life"] = 0.18
			"dmg", "heal", "text":
				v["life"] = 0.8
				v["off"] = Vector2(randf_range(-10, 10), 0)
			_:
				v["life"] = 0.45
		v["max"] = v["life"]
		fx.append(v)
	sim.events.clear()
	if fx.size() > 160:
		fx = fx.slice(fx.size() - 160)


# ================================================================== drawing
func _draw() -> void:
	Art.draw_space(self, Vector2(1280, 720), stars, t)
	var font := UI.font()
	var pl: Dictionary = Game.PLANETS[planet_n]
	draw_string(font, Vector2(436, 26), "%s's army" % pl["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(14), Color(UI.RED).lightened(0.3))

	# hex board
	var drag_cell := Vector2i(-1, -1)
	if drag_u != null:
		drag_cell = _cell_at(get_local_mouse_position())
	for y in Game.BOARD_ROWS:
		for x in Game.BOARD_COLS:
			var c := Vector2i(x, y)
			var mine := y >= Game.BOARD_ROWS / 2
			var col := Color(UI.CYAN, 0.12) if mine else Color(UI.RED, 0.10)
			if (x + y) % 2 == 0:
				col.a += 0.04
			if c == drag_cell and mine:
				col = Color(UI.GOLD, 0.35)
			var pts := Hex.corners(_cell_px(c), S - 1.5)
			draw_colored_polygon(pts, col)
			pts.append(pts[0])
			draw_polyline(pts, Color(UI.CYAN, 0.35) if mine else Color(UI.RED, 0.3), 1.5, true)

	# bench
	var bx := _bench_px(0).x - S - 8
	draw_string(font, Vector2(bx - 150, BENCH_Y - 2), "BENCH", HORIZONTAL_ALIGNMENT_RIGHT, 150, UI.fs(15), UI.SOFT)
	draw_string(font, Vector2(bx - 150, BENCH_Y + 18), "does not fight", HORIZONTAL_ALIGNMENT_RIGHT, 150, UI.fs(11), Color(UI.SOFT, 0.7))
	for i in Game.BENCH_SIZE:
		var pts := Hex.corners(_bench_px(i), S - 2.0)
		draw_colored_polygon(pts, Color(UI.GREY, 0.35))
		pts.append(pts[0])
		draw_polyline(pts, Color(UI.SOFT, 0.5), 1.5, true)

	if phase == "prep" or sim == null:
		_draw_prep()
	else:
		_draw_fight(font)
	for i in bench.size():
		var u: Variant = bench[i]
		if u != null and (drag_u == null or drag_u["id"] != u["id"]):
			Art.draw_unit(self, u, _bench_px(i), _radius(u), 0, t, 1.0)
	if drag_u != null:
		var m := get_local_mouse_position()
		Art.draw_unit(self, drag_u, m, _radius(drag_u), 0, t, 1.0)
		if m.y > SHOP_TOP:
			draw_string_outline(font, m + Vector2(-80, -34), "Sell: +%d coins" % Game.unit_price(drag_u), HORIZONTAL_ALIGNMENT_CENTER, 160, UI.fs(14), 5, Color.BLACK)
			draw_string(font, m + Vector2(-80, -34), "Sell: +%d coins" % Game.unit_price(drag_u), HORIZONTAL_ALIGNMENT_CENTER, 160, UI.fs(14), UI.GOLD)
	_draw_fx(font)


func _draw_prep() -> void:
	for w in wave:
		var u: Dictionary = w[0]
		Art.draw_unit(self, u, _cell_px(w[1]), _radius(u), 1, t, -1.0)
	for id in board:
		if drag_u != null and drag_u["id"] == id:
			continue
		var u: Variant = _unit_by_id(id)
		if u != null:
			Art.draw_unit(self, u, _cell_px(board[id]), _radius(u), 0, t, 1.0)


func _draw_fight(font: Font) -> void:
	var list: Array = sim.fighters.duplicate()
	list.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	for f in list:
		if not f["alive"]:
			continue
		var r := _radius(f["u"])
		var p := _px(f["pos"])
		if f["lunge"] > 0.0 and f["target"] >= 0:
			var tgt: Dictionary = sim.fighters[f["target"]]
			p += (_px(tgt["pos"]) - p).normalized() * 6.0
		var pose := "idle"
		if f["lunge"] > 0.0:
			pose = "attack"
		elif f["flash"] > 0.0:
			pose = "hurt"
		elif f["moving"]:
			pose = "walk"
		Art.draw_unit(self, f["u"], p, r, f["team"], t, f["facing"], pose)
		if f["flash"] > 0.0:
			draw_circle(p, r, Color(1, 1, 1, 0.45))
		if f["slow_t"] > 0.0:
			draw_arc(p, r + 3, 0, TAU, 24, Color("#9fdcff", 0.8), 2.0, true)
		if f["root_t"] > 0.0:
			draw_arc(p + Vector2(0, r * 0.8), r * 0.9, 0, PI, 12, Color("#3fae5a"), 3.0, true)
		if not f["dots"].is_empty():
			draw_circle(p + Vector2(r * 0.8, -r * 0.8), 4.0, Color("#9dff6b") if f["dots"][0]["kind"] == "poison" else Color("#ff9a2e"))
		var w := r * 2.0
		var y := p.y - r - 10
		draw_rect(Rect2(p.x - w / 2, y, w, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(p.x - w / 2, y, w * clampf(f["hp"] / f["max_hp"], 0.0, 1.0), 5), UI.GREEN if f["team"] == 0 else UI.RED)
		if f["shield"] > 0.0:
			draw_rect(Rect2(p.x - w / 2, y - 4, w * clampf(f["shield"] / f["max_hp"], 0.0, 1.0), 3), Color("#c9c3ff"))
	draw_string(font, Vector2(640, 26), "You: %d   ·   Enemy: %d" % [sim.alive(0).size(), sim.alive(1).size()], HORIZONTAL_ALIGNMENT_RIGHT, 206, UI.fs(13), UI.SOFT)


func _draw_fx(font: Font) -> void:
	for e in fx:
		var k: float = e["life"] / e["max"]
		match e["type"]:
			"shot":
				var a := _px(e["from"])
				var b := _px(e["to"])
				var col: Color = Game.PLANETS[Game.planet_index(e["species"][e["species"].size() - 1])]["accent"]
				if e["ranged"]:
					var p := a.lerp(b, 1.0 - k)
					draw_line(a.lerp(b, maxf(0.0, 0.8 - k)), p, Color(col, 0.7), 3.0, true)
					draw_circle(p, 5.0, col)
				else:
					draw_arc(b, 14.0 * (1.0 - k) + 6.0, 0, TAU, 16, Color(1, 1, 1, k), 3.0, true)
			"zap":
				var a := _px(e["from"])
				var b := _px(e["to"])
				var mid := a.lerp(b, 0.5) + Vector2(randf_range(-8, 8), randf_range(-8, 8))
				draw_polyline(PackedVector2Array([a, mid, b]), Color("#fff36b", k), 3.0, true)
			"burst":
				draw_arc(_px(e["pos"]), e["radius"] * S * (1.0 - k * 0.6), 0, TAU, 32, Color(e["color"], k), 4.0, true)
			"death":
				draw_circle(_px(e["pos"]), 26.0 * (1.0 - k) + 4.0, Color(1, 1, 1, k * 0.6))
			"blink":
				draw_line(_px(e["from"]), _px(e["to"]), Color(1, 1, 0.8, k), 4.0, true)
			"dmg", "heal", "text":
				var off: Vector2 = e["off"]
				var p: Vector2 = _px(e["pos"]) + off + Vector2(0, -30 - (1.0 - k) * 26)
				var txt: String
				var col := Color.WHITE
				if e["type"] == "dmg":
					txt = "%d" % maxi(1, int(round(e["amount"])))
					col = UI.GOLD if e["crit"] else Color.WHITE
				elif e["type"] == "heal":
					txt = "+%d" % int(round(e["amount"]))
					col = UI.GREEN
				else:
					txt = e["text"]
					col = e["color"]
				var fsize := 18 if e["type"] == "dmg" and e["crit"] else 14
				draw_string_outline(font, p - Vector2(40, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, fsize, 5, Color(0, 0, 0, k))
				draw_string(font, p - Vector2(40, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, fsize, Color(col, k))
