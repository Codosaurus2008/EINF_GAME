class_name BattleSim
extends RefCounted
## One combat on the hex board (no drawing). Every fighter walks hex by hex to the
## nearest enemy and attacks when it is in range. The strengths change how fights go.
## `pos` is the drawing position in hex units (see Hex.center), `cell` the hex it stands on.

const MAX_TIME := 45.0

var fighters: Array = []     # Dictionaries, see _make_fighter
var events: Array = []       # things to show: shots, damage numbers, deaths ...
var time := 0.0
var winner := -1             # -1 = still fighting, 0 = player, 1 = enemy
var cols := 8
var rows := 8


## units: Array of [unit Dictionary, Vector2i cell]
func setup(player_units: Array, enemy_units: Array) -> void:
	cols = Game.BOARD_COLS
	rows = Game.BOARD_ROWS
	for pu in player_units:
		fighters.append(_make_fighter(pu[0], pu[1], 0))
	for eu in enemy_units:
		fighters.append(_make_fighter(eu[0], eu[1], 1))
	# fighters are compared by this number (never with ==, they reference each other)
	for i in fighters.size():
		fighters[i]["idx"] = i
	for team in 2:
		var planets := {}
		for f in fighters:
			if f["team"] == team:
				for s in f["u"]["species"]:
					planets[s] = true
		for f in fighters:
			if f["team"] == team and f["fx"].has("synergy"):
				f["atk"] *= 1.0 + f["fx"]["synergy"] * planets.size()
	# Blink: jump next to the farthest enemy at the start
	for f in fighters:
		if f["fx"].has("blink"):
			var far: Variant = _farthest_enemy(f)
			if far != null:
				for n in Hex.neighbors(far["cell"]):
					if Hex.inside(n, cols, rows) and not _occupied(n):
						var from: Vector2 = f["pos"]
						f["cell"] = n
						f["pos"] = Hex.center(n)
						events.append({"type": "blink", "from": from, "to": f["pos"]})
						break


func _make_fighter(u: Dictionary, cell: Vector2i, team: int) -> Dictionary:
	var st := Game.unit_stats(u)
	var fx := {}
	var lvl := Game.level(u)
	for s in u["strengths"]:
		var d: Dictionary = Game.STRENGTHS[s]
		fx[d["fx"]] = fx.get(d["fx"], 0.0) + Game.strength_value(s, lvl)
	return {
		"u": u, "team": team, "alive": true,
		"cell": cell, "pos": Hex.center(cell),
		"moving": false, "to_cell": cell, "from_pos": Hex.center(cell), "move_t": 0.0, "move_dur": 1.0,
		"hp": st["hp"], "max_hp": st["hp"], "atk": st["atk"],
		"range": maxi(1, int(round(st["range"]))),      # in hexes
		"speed": st["speed"], "cd": st["cd"], "timer": randf_range(0.0, 0.4),
		"fx": fx, "shield": st["hp"] * fx.get("shield", 0.0),
		"slow_t": 0.0, "slow": 0.0, "root_t": 0.0, "dots": [], "first_done": false,
		"heal_t": 3.0, "facing": 1.0 if team == 0 else -1.0, "flash": 0.0, "lunge": 0.0,
		"target": -1,
	}


# ------------------------------------------------------------------ queries
func alive(team: int) -> Array:
	return fighters.filter(func(f): return f["alive"] and f["team"] == team)


func _occupied(cell: Vector2i) -> bool:
	for o in fighters:
		if o["alive"] and (o["cell"] == cell or (o["moving"] and o["to_cell"] == cell)):
			return true
	return false


func _hd(a: Dictionary, b: Dictionary) -> int:
	return Hex.distance(a["cell"], b["cell"])


func _nearest_enemy(f: Dictionary) -> Variant:
	var best: Variant = null
	var bd := 1 << 30
	var bp := INF
	for o in fighters:
		if o["alive"] and o["team"] != f["team"]:
			var d := _hd(f, o)
			var p: float = f["pos"].distance_to(o["pos"])
			if d < bd or (d == bd and p < bp):
				bd = d
				bp = p
				best = o
	return best


func _farthest_enemy(f: Dictionary) -> Variant:
	var best: Variant = null
	var bd := -1
	for o in fighters:
		if o["alive"] and o["team"] != f["team"]:
			var d := _hd(f, o)
			if d > bd:
				bd = d
				best = o
	return best


## Damage bonus from neighbouring allies with Forge Master
func _aura(f: Dictionary) -> float:
	var m := 1.0
	for o in fighters:
		if o["idx"] != f["idx"] and o["alive"] and o["team"] == f["team"] and o["fx"].has("aura"):
			if _hd(f, o) <= 1:
				m += o["fx"]["aura"]
	return m


# ------------------------------------------------------------------ simulation
func step(dt: float) -> void:
	if winner != -1:
		return
	time += dt
	for f in fighters:
		if not f["alive"]:
			continue
		_tick_status(f, dt)
		if not f["alive"]:
			continue
		f["flash"] = max(0.0, f["flash"] - dt)
		f["lunge"] = max(0.0, f["lunge"] - dt)
		f["timer"] -= dt
		# walking from one hex to the next
		if f["moving"]:
			f["move_t"] += dt
			var k: float = clampf(f["move_t"] / f["move_dur"], 0.0, 1.0)
			f["pos"] = f["from_pos"].lerp(Hex.center(f["to_cell"]), k)
			if k >= 1.0:
				f["moving"] = false
				f["cell"] = f["to_cell"]
			continue
		var tgt: Variant = _nearest_enemy(f)
		if tgt == null:
			break
		f["target"] = tgt["idx"]
		var dx: float = tgt["pos"].x - f["pos"].x
		if abs(dx) > 0.05:
			f["facing"] = sign(dx)
		var d := _hd(f, tgt)
		if d <= f["range"]:
			if f["timer"] <= 0.0:
				_attack(f, tgt)
				var cd: float = f["cd"] / (1.0 + f["fx"].get("haste", 0.0))
				if f["slow_t"] > 0:
					cd *= 1.0 + f["slow"]
				f["timer"] = cd
		elif f["root_t"] <= 0.0 and f["speed"] > 0.0:
			_step_towards(f, tgt, d)
	_check_end()


## Move one hex closer to the target (or around a blocking fighter)
func _step_towards(f: Dictionary, tgt: Dictionary, d: int) -> void:
	var best := Vector2i(-1, -1)
	var best_d := d + 1
	var best_p := INF
	for n in Hex.neighbors(f["cell"]):
		if not Hex.inside(n, cols, rows) or _occupied(n):
			continue
		var nd := Hex.distance(n, tgt["cell"])
		var np := Hex.center(n).distance_to(tgt["pos"])
		if nd < best_d or (nd == best_d and np < best_p):
			best_d = nd
			best_p = np
			best = n
	if best.x < 0 or best_d > d:
		return
	var spd: float = f["speed"] * (1.0 - f["slow"] if f["slow_t"] > 0 else 1.0)
	f["moving"] = true
	f["to_cell"] = best
	f["from_pos"] = f["pos"]
	f["move_t"] = 0.0
	f["move_dur"] = 1.0 / maxf(0.3, spd)


func _tick_status(f: Dictionary, dt: float) -> void:
	f["slow_t"] = max(0.0, f["slow_t"] - dt)
	f["root_t"] = max(0.0, f["root_t"] - dt)
	for d in f["dots"]:
		d["t"] -= dt
		_hurt(d["src"], f, d["dps"] * dt, true, false, false)
	f["dots"] = f["dots"].filter(func(d): return d["t"] > 0.0)
	if not f["alive"]:
		return
	if f["fx"].has("regen"):
		f["hp"] = min(f["max_hp"], f["hp"] + f["max_hp"] * f["fx"]["regen"] * dt)
	if f["fx"].has("heal_ally"):
		f["heal_t"] -= dt
		if f["heal_t"] <= 0.0:
			f["heal_t"] = 3.0
			var weakest: Variant = null
			var lowest := 2.0
			for o in fighters:
				if o["alive"] and o["team"] == f["team"]:
					var r: float = o["hp"] / o["max_hp"]
					if r < lowest:
						lowest = r
						weakest = o
			if weakest != null:
				var amount: float = f["atk"] * f["fx"]["heal_ally"]
				weakest["hp"] = min(weakest["max_hp"], weakest["hp"] + amount)
				events.append({"type": "heal", "pos": weakest["pos"], "amount": amount})


func _attack(f: Dictionary, tgt: Dictionary) -> void:
	var dmg: float = f["atk"] * _aura(f)
	var crit := false
	if f["fx"].has("first_strike") and not f["first_done"]:
		dmg *= f["fx"]["first_strike"]
		f["first_done"] = true
		crit = true
	if f["fx"].has("crit") and randf() < f["fx"]["crit"]:
		dmg *= 2.0
		crit = true
	var pierce: bool = f["fx"].has("pierce")
	if pierce:
		dmg *= 1.0 + f["fx"]["pierce"]
	f["lunge"] = 0.15
	events.append({"type": "shot", "from": f["pos"], "to": tgt["pos"], "ranged": f["range"] > 1, "species": f["u"]["species"]})
	if not _hurt(f, tgt, dmg, false, pierce, crit):
		return
	if f["fx"].has("slow"):
		tgt["slow"] = f["fx"]["slow"]
		tgt["slow_t"] = 2.0
	if f["fx"].has("root"):
		tgt["root_t"] = f["fx"]["root"]
	if f["fx"].has("poison"):
		tgt["dots"].append({"dps": dmg * f["fx"]["poison"] / 3.0, "t": 3.0, "src": f, "kind": "poison"})
	if f["fx"].has("burn"):
		tgt["dots"].append({"dps": dmg * f["fx"]["burn"] / 3.0, "t": 3.0, "src": f, "kind": "burn"})
	if f["fx"].has("splash"):
		for o in fighters:
			if o["idx"] != tgt["idx"] and o["alive"] and o["team"] == tgt["team"] and _hd(o, tgt) <= 1:
				_hurt(f, o, dmg * f["fx"]["splash"], true, pierce, false)
		events.append({"type": "burst", "pos": tgt["pos"], "radius": 1.8, "color": Color("#7ff5ff")})
	if f["fx"].has("chain"):
		var jumps := 0
		var from: Dictionary = tgt
		for o in fighters:
			if jumps >= 2:
				break
			if o["idx"] != tgt["idx"] and o["alive"] and o["team"] == tgt["team"] and _hd(o, from) <= 3:
				events.append({"type": "zap", "from": from["pos"], "to": o["pos"]})
				_hurt(f, o, dmg * f["fx"]["chain"], true, pierce, false)
				from = o
				jumps += 1


## Deals damage. indirect = poison/burn/splash (can't be dodged, no thorns). Returns false if dodged.
func _hurt(src, tgt: Dictionary, amount: float, indirect: bool, pierce: bool, crit: bool) -> bool:
	if not tgt["alive"]:
		return false
	if not indirect and tgt["fx"].has("dodge") and randf() < tgt["fx"]["dodge"]:
		events.append({"type": "text", "pos": tgt["pos"], "text": "dodge", "color": Color("#7ff5ff")})
		return false
	if not pierce:
		amount *= 1.0 - min(0.75, tgt["fx"].get("armor", 0.0))
	if tgt["shield"] > 0.0:
		var absorbed: float = min(tgt["shield"], amount)
		tgt["shield"] -= absorbed
		amount -= absorbed
	tgt["hp"] -= amount
	tgt["flash"] = 0.12
	if not indirect or amount > tgt["max_hp"] * 0.02:
		events.append({"type": "dmg", "pos": tgt["pos"], "amount": amount, "crit": crit})
	if not indirect and src != null and src["alive"] and src["range"] <= 1 and tgt["fx"].has("thorns"):
		_hurt(tgt, src, amount * tgt["fx"]["thorns"], true, true, false)
	if tgt["hp"] <= 0.0:
		_die(tgt, src)
	return true


func _die(f: Dictionary, killer) -> void:
	f["alive"] = false
	f["hp"] = 0.0
	f["moving"] = false
	events.append({"type": "death", "pos": f["pos"], "team": f["team"]})
	if f["fx"].has("death_burst"):
		var dmg: float = f["max_hp"] * f["fx"]["death_burst"]
		events.append({"type": "burst", "pos": f["pos"], "radius": 2.0, "color": Color("#7dffcf")})
		for o in fighters:
			if o["alive"] and o["team"] != f["team"] and _hd(o, f) <= 1:
				_hurt(f, o, dmg, true, false, false)
	if killer != null and killer["alive"] and killer["fx"].has("on_kill"):
		var heal: float = killer["max_hp"] * killer["fx"]["on_kill"]
		killer["hp"] = min(killer["max_hp"], killer["hp"] + heal)
		events.append({"type": "heal", "pos": killer["pos"], "amount": heal})


func _check_end() -> void:
	var a := alive(0).size()
	var b := alive(1).size()
	if b == 0 and a > 0:
		winner = 0
	elif a == 0:
		winner = 1
	elif time > MAX_TIME:
		winner = 0 if _health_share(0) > _health_share(1) else 1


func _health_share(team: int) -> float:
	var hp := 0.0
	var mx := 0.0
	for f in fighters:
		if f["team"] == team:
			hp += max(0.0, f["hp"])
			mx += f["max_hp"]
	return hp / max(1.0, mx)
