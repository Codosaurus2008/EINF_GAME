extends Node
## Global game data, rules and save. Available everywhere as `Game`.
## All numbers for balancing are at the top of this file.
##
## LORE: the Umbra, an evil civilization, have occupied the whole system and stolen the
## technology of every planet. Each planet's people developed one element with one strength.
## You start on the asteroid Pebble, free one planet after the other and take the freed folk
## with you on your ship. On the ship you "hybreed" creatures of different elements.
## The last fight frees the Sun.

signal changed
signal hatched(child: Dictionary)   # a hybred creature is ready
signal leveled(u: Dictionary)       # a creature changed its level (see level_up)
signal breeding_ready               # the egg in the lab is ready to hatch (sent once)
signal capsule_repaired             # a capsule repair has finished

# ---------------------------------------------------------------- THE SOLAR SYSTEM
# n = distance step from the outside. The asteroid is n = 0, the sun is n = 8.
# Every planet = one element with one strength (its technology).
const PLANETS := [
	{"id": "pebble", "name": "Pebble", "kind": "Asteroid", "species": "Scrappers", "prefix": "Scrap",
		"tool": "Slingshots", "color": Color("#b39c86"), "accent": Color("#ffcf8a"), "strength": "improvise",
		"desc": "Your home: a lonely rock at the edge. The Umbra thought it worthless - so the Scrappers are still free."},
	{"id": "glacia", "name": "Glacia", "kind": "Ice world", "species": "Frostlings", "prefix": "Frost",
		"tool": "Ice Spears", "color": Color("#9fdcff"), "accent": Color("#ffffff"), "strength": "frost_armor",
		"desc": "A frozen giant. The Umbra stole the Frostlings' ice armor and hold them in the glaciers."},
	{"id": "mycelia", "name": "Mycelia", "kind": "Fungus world", "species": "Sporekin", "prefix": "Spore",
		"tool": "Spore Pods", "color": Color("#9b6cd6"), "accent": Color("#7dffcf"), "strength": "poison",
		"desc": "Giant glowing mushrooms. The Umbra brew their poison from the Sporekin's spores."},
	{"id": "aquora", "name": "Aquora", "kind": "Ocean world", "species": "Tidefolk", "prefix": "Tide",
		"tool": "Tridents", "color": Color("#2f7dde"), "accent": Color("#7ff5ff"), "strength": "healing_waters",
		"desc": "One endless ocean. The Umbra keep the Tidefolk's healing waters for themselves."},
	{"id": "verdis", "name": "Verdis", "kind": "Jungle world", "species": "Thornbacks", "prefix": "Thorn",
		"tool": "Thorn Bows", "color": Color("#3fae5a"), "accent": Color("#d6ff6b"), "strength": "ambush",
		"desc": "A planet-wide jungle. The Thornbacks' ambush tactics now serve the Umbra hunters."},
	{"id": "ferrum", "name": "Ferrum", "kind": "Forge world", "species": "Forgeborn", "prefix": "Forge",
		"tool": "Steam Cannons", "color": Color("#b5653a"), "accent": Color("#ffb347"), "strength": "heavy_shot",
		"desc": "Iron and lava. The Forgeborn must forge heavy guns for the Umbra army."},
	{"id": "voltara", "name": "Voltara", "kind": "Storm world", "species": "Arcwings", "prefix": "Arc",
		"tool": "Lightning Rods", "color": Color("#6b4fd8"), "accent": Color("#fff36b"), "strength": "chain_lightning",
		"desc": "Endless storms. The Umbra caught the Arcwings' lightning in their towers."},
	{"id": "solara", "name": "Solara", "kind": "Light world", "species": "Lumen", "prefix": "Lumi",
		"tool": "Light Lances", "color": Color("#ffd75e"), "accent": Color("#ffffff"), "strength": "sunbeam",
		"desc": "So close to the sun that its people became light. The Umbra use the Lumen's beams as weapons."},
	{"id": "sun", "name": "The Sun", "kind": "Star", "species": "Corona", "prefix": "Sol",
		"tool": "Solar Flares", "color": Color("#ff9a2e"), "accent": Color("#fff2b0"), "strength": "radiance",
		"desc": "The heart of the system and the Umbra's fortress. Free it and the whole system is free."},
]
const SUN := 8
const ENEMY_NAME := "Umbra"

# Base stats of every element (a hybrid gets the average of its elements)
# range and speed are in hexes, cd = seconds between attacks
const SPECIES_STATS := {
	"pebble":  {"hp": 100.0, "atk": 10.0, "range": 1.2, "speed": 2.0, "cd": 1.0},
	"glacia":  {"hp": 95.0,  "atk": 7.0,  "range": 1.2, "speed": 1.6, "cd": 1.1},
	"mycelia": {"hp": 90.0,  "atk": 9.0,  "range": 3.0, "speed": 1.8, "cd": 1.2},
	"aquora":  {"hp": 100.0, "atk": 10.0, "range": 2.0, "speed": 2.2, "cd": 1.0},
	"verdis":  {"hp": 85.0,  "atk": 13.0, "range": 4.0, "speed": 2.0, "cd": 1.2},
	"ferrum":  {"hp": 130.0, "atk": 16.0, "range": 5.0, "speed": 1.4, "cd": 1.8},
	"voltara": {"hp": 80.0,  "atk": 9.0,  "range": 4.0, "speed": 2.6, "cd": 0.7},
	"solara":  {"hp": 75.0,  "atk": 14.0, "range": 6.0, "speed": 2.2, "cd": 1.1},
	"sun":     {"hp": 160.0, "atk": 14.0, "range": 7.0, "speed": 0.0, "cd": 1.0},
}


# The strengths (one per element). "fx" is what the battle does, "v" its value at tier I.
const STRENGTHS := {
	"improvise":       {"name": "Improvise",       "fx": "synergy",      "v": 0.08, "desc": "+8% attack for every different element in your team"},
	"frost_armor":     {"name": "Frost Armor",     "fx": "armor",        "v": 0.25, "desc": "Takes 25% less damage"},
	"poison":          {"name": "Poison",          "fx": "poison",       "v": 0.60, "desc": "Hits poison: 60% extra damage over 3s"},
	"healing_waters":  {"name": "Healing Waters",  "fx": "heal_ally",    "v": 1.50, "desc": "Every 3s heals the weakest ally"},
	"ambush":          {"name": "Ambush",          "fx": "first_strike", "v": 3.0,  "desc": "First attack deals triple damage"},
	"heavy_shot":      {"name": "Heavy Shot",      "fx": "pierce",       "v": 0.20, "desc": "Ignores armor and deals +20% damage"},
	"chain_lightning": {"name": "Chain Lightning", "fx": "chain",        "v": 0.50, "desc": "Hits jump to 2 more enemies (50% damage)"},
	"sunbeam":         {"name": "Sunbeam",         "fx": "crit",         "v": 0.25, "desc": "25% chance for a double-damage beam"},
	"radiance":        {"name": "Radiance",        "fx": "burn",         "v": 0.50, "desc": "Hits burn: 50% extra damage over 3s"},
}
const STRENGTH_CAPS := {"armor": 0.7, "dodge": 0.6, "crit": 0.75, "slow": 0.8}

# ---------------------------------------------------------------- LEVELS, TIERS, ELEMENTS
const MAX_ELEMENTS := 4
# The strength of the elements has 3 tiers, depending on the level of the creature
const TIER_LEVELS := [1, 4, 7]          # tier I from level 1, tier II from 4, tier III from 7
const TIER_MULT := [1.0, 1.5, 2.0]      # how strong the strengths are in each tier
const TIER_NAMES := ["I", "II", "III"]
const LEVEL_STATS := 0.10               # +10% health and attack per level above 1
const ELEMENT_BONUS := 0.12             # +12% health and attack for every element above 1

# ---------------------------------------------------------------- HYBREEDING (on your ship)
const BREED_BASE_TIME := 20.0            # seconds per element of the child (2 elements = 40 s)
# Hybreeding can fail: then a copy of one parent hatches. Higher levels = better chance.
const HYBRID_CHANCE_BASE := 0.30          # two level-1 parents
const HYBRID_CHANCE_PER_LEVEL := 0.07     # + for every level above 1 (both parents counted)
const HYBRID_CHANCE_MAX := 0.95
const SELL_ENERGY := 1                    # selling a creature gives this much hybreeding energy

# ---------------------------------------------------------------- BATTLE (several combats per planet)
const BOARD_COLS := 8
const BOARD_ROWS := 8           # you use the bottom 4 rows, the Umbra the top 4
const START_COINS := 2
const START_PLACES := 2
const MAX_PLACES := 8
const WIN_ROUNDS := 4           # combats to win to free the planet
const LIVES := 3                # combats you may lose
const SHOP_SIZE := 5
const BENCH_SIZE := 6
const PREP_TIME := 30.0
const LOSS_REWARD := 1
## How strong the Umbra are compared to the team you can afford (combat 1, 2, 3, 4).
## Below 1.0 = you have the edge if you pick and place well.
const WAVE_FACTOR := [0.7, 0.8, 0.88, 0.95]

const NAMES := ["Rocky", "Zib", "Nova", "Kip", "Vex", "Luma", "Orin", "Tess", "Bix", "Mira", "Juno", "Pax",
	"Quill", "Rex", "Sola", "Tiko", "Umi", "Vega", "Wren", "Yara", "Zed", "Ari", "Bo", "Cyra", "Dax", "Eli", "Fen"]

# ---------------------------------------------------------------- CURRENCIES (kept between battles)
# Rewards after a battle (coins). Gems: how to earn them comes later.
const REWARD_WIN_BASE := 30        # freeing a planet: 30 + 15 per planet step
const REWARD_WIN_PER_PLANET := 15
const REWARD_PER_COMBAT := 5       # +5 for every combat you won in that battle (also when you lose)
const REWARD_DEFEAT_BASE := 5      # consolation for a lost battle

const SAVE_PATH := "user://sunward_save.json"     # (the save of the first player, kept from before accounts)
const PROFILES_PATH := "user://players.json"

# ---------------------------------------------------------------- PLAYERS (accounts)
## Several people can play on this computer, each with their own saved game. No passwords.
## players.json: {"current": id, "users": [{"id", "name", "file", "created", "last"}]}
var users: Array = []
var user_id := ""
var save_path := SAVE_PATH
signal user_switched

# ---------------------------------------------------------------- STATE
var units: Array = []           # your crew (Dictionaries, see make_unit)
var conquered := 0              # highest freed planet (0 = only the asteroid)
var breed_charges := 0          # hybreeding energy: +1 per freed planet, +1 per sold creature
var breeding: Dictionary = {}   # {} or the creature in the lab: {"a", "b", "elements", "end" (unix time), "total", "chance"}
var next_id := 1
var coins := 0                  # currency kept between battles
var gems := 0                   # second currency (ways to earn them come later)
## Development and exploration of freed planets, per planet id:
## {"buildings": {"<site index>": {"type": "gem_mine", "built_at": unix}},
##  "found": ["animal:snowpuff", "object:ice_core", ...], "pos": [capsule x, y, z, heading x, y, z (+ player on foot)],
##  "time": time of day (sun angle)}
## Building types are defined in PlanetDev (planet_dev.gd), landscapes in Biomes.
var planet_dev: Dictionary = {}
## The exploration capsule: hull 0..100, crashed = can't fly, repair_end = unix time when a running
## repair is done (0 = none). Repairs continue while the game is closed.
var capsule: Dictionary = {"hull": 100.0, "crashed": false, "repair_end": 0.0, "repair_total": 0.0}


func _ready() -> void:
	randomize()
	_load_users()
	load_game()


# ---------------------------------------------------------------- PLAYERS
func _load_users() -> void:
	users = []
	user_id = ""
	if FileAccess.file_exists(PROFILES_PATH):
		var data = JSON.parse_string(FileAccess.open(PROFILES_PATH, FileAccess.READ).get_as_text())
		if typeof(data) == TYPE_DICTIONARY and typeof(data.get("users", [])) == TYPE_ARRAY:
			for u in data["users"]:
				if typeof(u) == TYPE_DICTIONARY and u.has("id") and u.has("file"):
					users.append({"id": str(u["id"]), "name": str(u.get("name", "Player")), "file": str(u["file"]),
						"created": float(u.get("created", now())), "last": float(u.get("last", 0.0))})
			user_id = str(data.get("current", ""))
	if users.is_empty():
		# first start with accounts: the existing saved game becomes the first player's
		users.append({"id": "p1", "name": "Player 1", "file": SAVE_PATH, "created": now(), "last": now()})
		user_id = "p1"
		_save_users()
	if user_by_id(user_id).is_empty():
		user_id = str(users[0]["id"])
	save_path = str(user_by_id(user_id)["file"])


func _save_users() -> void:
	var f := FileAccess.open(PROFILES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"current": user_id, "users": users}, "\t"))


func user_by_id(id: String) -> Dictionary:
	for u: Dictionary in users:
		if str(u["id"]) == id:
			return u
	return {}


func current_user() -> Dictionary:
	return user_by_id(user_id)


## A short summary of a player's saved game (read from their save file, without loading it)
func user_summary(id: String) -> Dictionary:
	var u := user_by_id(id)
	if u.is_empty() or not FileAccess.file_exists(str(u["file"])):
		return {"freed": 0, "crew": 0, "coins": 0, "new": true}
	var data = JSON.parse_string(FileAccess.open(str(u["file"]), FileAccess.READ).get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {"freed": 0, "crew": 0, "coins": 0, "new": true}
	var crew_n := 0
	var crew = data.get("units", [])
	if typeof(crew) == TYPE_ARRAY:
		var crew_list: Array = crew
		crew_n = crew_list.size()
	return {"freed": int(data.get("conquered", 0)), "crew": crew_n,
		"coins": int(data.get("coins", 0)), "new": false}


## Saves the current player's game, then continues with another player's game
func switch_user(id: String) -> void:
	if user_by_id(id).is_empty():
		return
	if not user_id.is_empty() and id != user_id:
		save_game()
	user_id = id
	save_path = str(user_by_id(id)["file"])
	user_by_id(id)["last"] = now()
	_save_users()
	load_game()
	changed.emit()
	user_switched.emit()


## A new player with a new game (the name is cleaned up and made unique). Returns the id.
func create_user(player_name: String) -> String:
	var nm := player_name.strip_edges().substr(0, 20)
	if nm.is_empty():
		nm = "Player %d" % (users.size() + 1)
	var base := nm
	var k := 2
	while not user_named(nm).is_empty():
		nm = "%s %d" % [base, k]
		k += 1
	var n := 1
	while not user_by_id("p%d" % n).is_empty():
		n += 1
	var id := "p%d" % n
	users.append({"id": id, "name": nm, "file": "user://save_%s.json" % id, "created": now(), "last": now()})
	if not user_id.is_empty():
		save_game()
	user_id = id
	save_path = "user://save_%s.json" % id
	_save_users()
	new_game()
	save_game()
	changed.emit()
	user_switched.emit()
	return id


func user_named(player_name: String) -> Dictionary:
	for u: Dictionary in users:
		if str(u["name"]).to_lower() == player_name.to_lower():
			return u
	return {}


func rename_user(id: String, player_name: String) -> void:
	var u := user_by_id(id)
	var nm := player_name.strip_edges().substr(0, 20)
	if u.is_empty() or nm.is_empty():
		return
	var other := user_named(nm)
	if not other.is_empty() and str(other["id"]) != id:
		return
	u["name"] = nm
	_save_users()
	changed.emit()


## Removes a player and their saved game (not the one playing right now)
func delete_user(id: String) -> void:
	var u := user_by_id(id)
	if u.is_empty() or id == user_id:
		return
	var path := str(u["file"])
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	users.erase(u)
	_save_users()


func new_game() -> void:
	units = []
	conquered = 0
	breed_charges = 0
	breeding = {}
	next_id = 1
	coins = 0
	gems = 0
	planet_dev = {}
	capsule = {"hull": 100.0, "crashed": false, "repair_end": 0.0, "repair_total": 0.0}
	var hero := make_unit(["pebble"], "You")
	hero["hero"] = true
	units.append(hero)
	units.append(make_unit(["pebble"], "Rocky"))


## When the timer is over the egg is only READY - the player hatches it in the lab (hatch_now).
## This also catches timers that ran out while the game was closed (checked on the first frame).
func _process(_delta: float) -> void:
	if float(capsule["repair_end"]) > 0.0 and now() >= float(capsule["repair_end"]):
		capsule = {"hull": 100.0, "crashed": false, "repair_end": 0.0, "repair_total": 0.0}
		save_game()
		changed.emit()
		capsule_repaired.emit()
	if not breeding.is_empty() and not breeding.get("ready", false) and now() >= float(breeding["end"]):
		breeding["ready"] = true
		breeding["notified"] = false
		save_game()
		changed.emit()
		breeding_ready.emit()


static func now() -> float:
	return Time.get_unix_time_from_system()


# ---------------------------------------------------------------- HELPERS
func planet(n: int) -> Dictionary:
	return PLANETS[n]


func planet_index(id: String) -> int:
	for i in PLANETS.size():
		if PLANETS[i]["id"] == id:
			return i
	return 0


## Elements sorted from the outside to the sun, without doubles
func sort_elements(species: Array) -> Array:
	var out := []
	for p in PLANETS:
		if p["id"] in species:
			out.append(p["id"])
	return out


## A creature has exactly the strengths of its elements
func strengths_of(species: Array) -> Array:
	var out := []
	for s in sort_elements(species):
		out.append(PLANETS[planet_index(s)]["strength"])
	return out


func make_unit(species: Array, unit_name := "") -> Dictionary:
	var sp := sort_elements(species)
	var u := {
		"id": next_id,
		"name": unit_name if unit_name != "" else NAMES.pick_random(),
		"species": sp,
		"strengths": strengths_of(sp),
		"hybrid": sp.size() > 1,
		"hero": false,
		"lvl": 1,
	}
	next_id += 1
	return u


func get_unit(id: int) -> Variant:
	for u in units:
		if u["id"] == id:
			return u
	return null


func species_name(u: Dictionary) -> String:
	if u["species"].size() == 1:
		return PLANETS[planet_index(u["species"][0])]["species"]
	var parts := []
	for s in u["species"]:
		parts.append(PLANETS[planet_index(s)]["prefix"])
	return "-".join(parts) + " hybrid"


func unit_colors(u: Dictionary) -> Array:
	var cols := []
	for s in u["species"]:
		cols.append(PLANETS[planet_index(s)]["color"])
	return cols


func elements(u: Dictionary) -> int:
	return u["species"].size()


func level(u: Dictionary) -> int:
	return int(u.get("lvl", 1))


## Tier of the strengths at a level: 1, 2 or 3
func tier(lvl: int) -> int:
	var t := 1
	for i in TIER_LEVELS.size():
		if lvl >= TIER_LEVELS[i]:
			t = i + 1
	return t


func tier_name(lvl: int) -> String:
	return TIER_NAMES[tier(lvl) - 1]


## Value of a strength at a level (with caps, e.g. armor never reaches 100%)
func strength_value(id: String, lvl: int) -> float:
	var d: Dictionary = STRENGTHS[id]
	var v: float = float(d["v"]) * float(TIER_MULT[tier(lvl) - 1])
	if STRENGTH_CAPS.has(d["fx"]):
		v = minf(v, STRENGTH_CAPS[d["fx"]])
	return v


## Battle stats: average of the elements, more with every level and every extra element
func unit_stats(u: Dictionary) -> Dictionary:
	var st := {"hp": 0.0, "atk": 0.0, "range": 0.0, "speed": 0.0, "cd": 0.0}
	for s in u["species"]:
		for k in st:
			st[k] += SPECIES_STATS[s][k]
	var n: float = u["species"].size()
	for k in st:
		st[k] /= n
	var m := (1.0 + LEVEL_STATS * (level(u) - 1)) * (1.0 + ELEMENT_BONUS * (n - 1.0))
	if u.get("hero", false):     # you are a bit tougher than a normal Scrapper
		m *= 1.25
	m *= float(u.get("boost", 1.0))   # only the Umbra use this (to make fair waves)
	st["hp"] *= m
	st["atk"] *= m
	return st


## Rough fighting value of a creature (used to make fair enemy waves)
func unit_value(u: Dictionary) -> float:
	var st := unit_stats(u)
	var v := sqrt(st["hp"] * st["atk"] / maxf(0.3, st["cd"]))
	v *= 1.0 + 0.05 * st["range"]
	v *= 1.0 + 0.1 * u["strengths"].size() * float(TIER_MULT[tier(level(u)) - 1])
	return v


# ---------------------------------------------------------------- ROUNDS / SHOP
## Price in the shop: number of elements x tier of their strength
func unit_price(u: Dictionary) -> int:
	return maxi(1, elements(u) * tier(level(u)))


## A new seat costs as many coins as you already have seats
func place_cost(places: int) -> int:
	return places


## Coins after a won combat: 3, 4, 5 ... (grows with every win)
func win_reward(wins_before: int) -> int:
	return 3 + wins_before


## A creature that only exists for one battle (Umbra, volunteers). Does not use up ids.
func temp_unit(species: Array, unit_name: String, lvl: int, id: int) -> Dictionary:
	var u := make_unit(species, unit_name)
	next_id -= 1
	u["id"] = id
	u["lvl"] = maxi(1, lvl)
	return u


## Volunteers from freed planets (they only fight in this battle)
func mercenary(id: int) -> Dictionary:
	var k := randi_range(0, mini(conquered, SUN - 1))
	var lvl := randi_range(1, maxi(1, conquered))
	var u := temp_unit([PLANETS[k]["id"]], NAMES.pick_random(), lvl, id)
	u["merc"] = true
	return u


## The team a sensible player can afford before each combat: start with 2 coins and 2 seats,
## always buy the strongest creature you can pay for, buy a seat when all seats are full.
func affordable_teams() -> Array:
	var pool: Array = units.duplicate()
	pool.sort_custom(func(x, y): return unit_value(x) > unit_value(y))
	var team: Array = []
	var coins := START_COINS
	var seats := START_PLACES
	var out := []
	for stage in WIN_ROUNDS:
		if stage > 0:
			coins += win_reward(stage - 1)
		var changed_any := true
		while changed_any:
			changed_any = false
			if team.size() < seats:
				for u in pool:
					if not team.has(u) and unit_price(u) <= coins:
						coins -= unit_price(u)
						team.append(u)
						changed_any = true
						break
			elif seats < MAX_PLACES and coins >= place_cost(seats) and team.size() < pool.size():
				coins -= place_cost(seats)
				seats += 1
				changed_any = true
		out.append(team.duplicate())
	return out


## Umbra wave for combat number `stage` (1, 2, 3 ...) on planet n. They fight with the stolen
## element of that planet. Every Umbra is matched to one creature of the team you can afford,
## a bit weaker (WAVE_FACTOR). Returns [unit, Vector2i cell] pairs.
func enemy_wave(n: int, stage: int) -> Array:
	var p: Dictionary = PLANETS[n]
	var teams := affordable_teams()
	var mirror: Array = teams[clampi(stage - 1, 0, teams.size() - 1)]
	var factor: float = WAVE_FACTOR[clampi(stage - 1, 0, WAVE_FACTOR.size() - 1)]
	var out := []
	var used := {}
	for i in maxi(1, mirror.size()):
		var target := 40.0
		var lvl := 1
		if i < mirror.size():
			target = unit_value(mirror[i]) * factor
			lvl = level(mirror[i])
		var title := "%s %s" % [ENEMY_NAME, ["Warden", "Raider", "Hunter", "Guard", "Reaver", "Lancer", "Sentinel", "Brute"][i % 8]]
		if n == SUN and i == 0:
			title = "Umbra Overlord"
		var u := temp_unit([p["id"]], title, lvl, -1000 - i)
		u["umbra"] = true
		u["boost"] = clampf(target / unit_value(u), 0.3, 6.0)
		# melee in front (rows 2-3), long range in the back (rows 0-1)
		var rng: float = unit_stats(u)["range"]
		var rows := [2, 3] if rng <= 1.5 else [0, 1]
		var cell := Vector2i(-1, -1)
		for _try in 40:
			var ry: int = rows.pick_random()
			var c := Vector2i(randi_range(0, BOARD_COLS - 1), ry)
			if not used.has(c):
				cell = c
				break
		if cell.x < 0:
			for y in 4:
				for x in BOARD_COLS:
					if cell.x < 0 and not used.has(Vector2i(x, y)):
						cell = Vector2i(x, y)
		used[cell] = true
		out.append([u, cell])
	return out


## Called after freeing planet n: its folk join your crew.
## (Freeing a planet does NOT change any creature's level - see LEVELING below.)
func conquer(n: int) -> Array:
	conquered = n
	var joined := []
	if n < SUN:
		var p: Dictionary = PLANETS[n]
		for i in 2:
			var u := make_unit([p["id"]])
			units.append(u)
			joined.append(u)
		breed_charges += 1
	changed.emit()
	save_game()
	return joined


# ---------------------------------------------------------------- LEVELING
## The only place where a creature's level changes. Nothing calls this yet: later, resources
## produced on freed planets (mines, food, other facilities) will be spent here to level creatures.
## Planet development -> resource production -> resource collection -> level_up(creature).
func level_up(u: Dictionary, amount := 1) -> void:
	set_level(u, level(u) + amount)


func set_level(u: Dictionary, lvl: int) -> void:
	u["lvl"] = maxi(1, lvl)
	leveled.emit(u)
	changed.emit()
	save_game()


# ---------------------------------------------------------------- HYBREEDING
## Chance of a new hybrid (otherwise a copy of a parent hatches)
func hybrid_chance(a: Dictionary, b: Dictionary) -> float:
	var extra := (level(a) - 1) + (level(b) - 1)
	return minf(HYBRID_CHANCE_MAX, HYBRID_CHANCE_BASE + HYBRID_CHANCE_PER_LEVEL * extra)


## Elements of the child: all elements of both parents
func child_elements(a: Dictionary, b: Dictionary) -> Array:
	return sort_elements(a["species"] + b["species"])


## More elements = longer: 2 elements 40 s, 3 elements 60 s, 4 elements 80 s
func breed_time(element_count: int) -> float:
	return BREED_BASE_TIME * element_count


func is_breeding() -> bool:
	return not breeding.is_empty()


## The single "breeding complete" state used by the notification and the lab button badge
func is_ready_to_hatch() -> bool:
	return not breeding.is_empty() and bool(breeding.get("ready", false))


## True until the player has seen/clicked the notification (saved, so it shows only once)
func needs_ready_notice() -> bool:
	return is_ready_to_hatch() and not bool(breeding.get("notified", false))


func acknowledge_ready() -> void:
	if is_ready_to_hatch() and not bool(breeding.get("notified", false)):
		breeding["notified"] = true
		save_game()


## The player hatches the egg in the lab (same chances as before: hybrid or a copy of a parent)
func hatch_now() -> void:
	if is_ready_to_hatch():
		_hatch()


func breeding_left() -> float:
	if breeding.is_empty():
		return 0.0
	return maxf(0.0, float(breeding["end"]) - now())


## "" if allowed, otherwise the reason
func can_breed(a, b) -> String:
	if not breeding.is_empty():
		return "The lab is busy - only one creature can grow at a time"
	if a == null or b == null or a["id"] == b["id"]:
		return "Pick two different creatures"
	if breed_charges <= 0:
		return "No hybreeding energy left - free the next planet or sell a creature"
	var ch := child_elements(a, b)
	if ch.size() > MAX_ELEMENTS:
		return "Too many elements: the child would have %d, the maximum is %d" % [ch.size(), MAX_ELEMENTS]
	if ch.size() == a["species"].size() or ch.size() == b["species"].size():
		return "Nothing new: one parent already has every element of the other"
	return ""


## Starts hybreeding. When the time is over the egg is ready and the player hatches it (hatch_now).
func breed(a: Dictionary, b: Dictionary) -> void:
	var count := child_elements(a, b).size()
	var total := breed_time(count)
	breeding = {"a": a["id"], "b": b["id"], "elements": count, "end": now() + total, "total": total, "chance": hybrid_chance(a, b)}
	breed_charges -= 1
	changed.emit()
	save_game()


func _hatch() -> void:
	var a = get_unit(int(breeding["a"]))
	var b = get_unit(int(breeding["b"]))
	var backup := breeding
	breeding = {}
	if a == null or b == null:
		changed.emit()
		save_game()
		return
	var chance: float = float(backup.get("chance", HYBRID_CHANCE_BASE))
	var child: Dictionary
	if randf() < chance:
		child = make_unit(child_elements(a, b))
	else:
		var parent: Dictionary = a if randf() < 0.5 else b
		child = make_unit(parent["species"])
		child["copy_of"] = parent["name"]
	units.append(child)
	changed.emit()
	save_game()
	hatched.emit(child)


## Selling a creature gives hybreeding energy. "" if it can be sold, otherwise why not.
func can_sell(u) -> String:
	if u == null:
		return "Pick a creature first."
	if u.get("hero", false):
		return "You can't sell yourself."
	if not breeding.is_empty() and (int(breeding["a"]) == u["id"] or int(breeding["b"]) == u["id"]):
		return "This creature is in the lab right now."
	if units.size() <= 2:
		return "You need to keep at least 2 creatures."
	return ""


func sell_unit(u: Dictionary) -> void:
	if can_sell(u) != "":
		return
	units = units.filter(func(o): return o["id"] != u["id"])
	breed_charges += SELL_ENERGY
	changed.emit()
	save_game()


# ---------------------------------------------------------------- REWARDS
## What a finished battle on planet n gives. `won` = planet freed, `combats_won` = rounds won.
func battle_reward(n: int, won: bool, combats_won: int) -> Dictionary:
	var c := REWARD_PER_COMBAT * combats_won
	if won:
		c += REWARD_WIN_BASE + REWARD_WIN_PER_PLANET * n
	else:
		c += REWARD_DEFEAT_BASE
	return {"coins": c, "gems": 0}


func add_reward(r: Dictionary) -> void:
	coins += int(r.get("coins", 0))
	gems += int(r.get("gems", 0))
	changed.emit()
	save_game()


# ---------------------------------------------------------------- PLANET DEVELOPMENT
## Only freed planets (not the Sun) can be developed.
func can_develop(n: int) -> bool:
	return n <= conquered and PlanetDev.has_world(planet(n)["id"])


## The saved state of one planet (created when needed)
func dev_state(planet_id: String) -> Dictionary:
	if not planet_dev.has(planet_id):
		planet_dev[planet_id] = {"buildings": {}, "found": [], "pos": []}
	var d: Dictionary = planet_dev[planet_id]
	if not d.has("found"):
		d["found"] = []
	if not d.has("pos"):
		d["pos"] = []
	return d


func is_found(planet_id: String, key: String) -> bool:
	return key in dev_state(planet_id)["found"]


## Remembers a discovered animal or object. Returns true if it is new.
func mark_found(planet_id: String, key: String) -> bool:
	if is_found(planet_id, key):
		return false
	(dev_state(planet_id)["found"] as Array).append(key)
	changed.emit()
	save_game()
	return true


## Where the capsule was when leaving the planet: [x, y, z, heading x, y, z] ([] = new arrival),
## plus 6 more numbers (position and facing of the player) if the player was walking.
func explore_pos(planet_id: String) -> Array:
	return dev_state(planet_id)["pos"]


func set_explore_pos(planet_id: String, p: Vector3, heading: Vector3, on_foot := false, foot := Vector3.ZERO, foot_heading := Vector3.ZERO) -> void:
	var a: Array = [p.x, p.y, p.z, heading.x, heading.y, heading.z]
	if on_foot:
		a.append_array([foot.x, foot.y, foot.z, foot_heading.x, foot_heading.y, foot_heading.z])
	dev_state(planet_id)["pos"] = a
	save_game()


## Craters blasted by the capsule's cannon: [x, y, z, radius, depth, height, seed] each
func save_craters(planet_id: String, list: Array) -> void:
	var flat: Array = []
	for c: Array in list:
		var d: Vector3 = c[0]
		flat.append_array([d.x, d.y, d.z, float(c[1]), float(c[2]), float(c[3]), float(c[4])])
	dev_state(planet_id)["craters"] = flat
	save_game()


func craters(planet_id: String) -> Array:
	var out: Array = []
	var flat: Array = planet_dev.get(planet_id, {}).get("craters", [])
	var i := 0
	while i + 6 < flat.size():
		out.append([Vector3(float(flat[i]), float(flat[i + 1]), float(flat[i + 2])).normalized(), float(flat[i + 3]),
			float(flat[i + 4]), float(flat[i + 5]), float(flat[i + 6])])
		i += 7
	return out


func buildings_on(planet_id: String) -> Dictionary:
	return planet_dev.get(planet_id, {}).get("buildings", {})


## The building on a site, or {} if the site is free.
func building_at(planet_id: String, site: int) -> Dictionary:
	return buildings_on(planet_id).get(str(site), {})


func building_price(type: String) -> Dictionary:
	return PlanetDev.BUILDINGS[type]["price"]


## "" if it can be built, otherwise why not.
func can_build(planet_id: String, site: int, type: String) -> String:
	if not PlanetDev.BUILDINGS.has(type):
		return "Unknown building"
	if site < 0 or site >= PlanetDev.SITE_COUNT:
		return "No building site"
	if not building_at(planet_id, site).is_empty():
		return "This site is already taken"
	var price := building_price(type)
	if gems < int(price.get("gems", 0)):
		return "Not enough gems (%d needed)" % int(price.get("gems", 0))
	if coins < int(price.get("coins", 0)):
		return "Not enough coins (%d needed)" % int(price.get("coins", 0))
	return ""


## Pays and places the building. Returns false if it is not possible.
func build(planet_id: String, site: int, type: String) -> bool:
	if can_build(planet_id, site, type) != "":
		return false
	var price := building_price(type)
	gems -= int(price.get("gems", 0))
	coins -= int(price.get("coins", 0))
	dev_state(planet_id)["buildings"][str(site)] = {"type": type, "built_at": now()}
	changed.emit()
	save_game()
	return true


# ---------------------------------------------------------------- CAPSULE DAMAGE AND REPAIR
func capsule_damage(amount: float, crash: bool) -> void:
	capsule["hull"] = clampf(float(capsule["hull"]) - amount, 0.0, 100.0)
	if crash or float(capsule["hull"]) <= 0.0:
		capsule["crashed"] = true
		capsule["hull"] = 0.0
	save_game()
	changed.emit()


func capsule_repairing() -> bool:
	return float(capsule["repair_end"]) > 0.0


func capsule_repair_left() -> float:
	return maxf(0.0, float(capsule["repair_end"]) - now())


## [coins, seconds] for repairing the current damage (worse damage costs more).
## Repairs are instant for now (seconds = 0); a repair time can be added here later.
## Repairs are free for now: set REPAIR_COSTS to true to charge coins again.
const REPAIR_COSTS := false


func capsule_repair_price() -> Array:
	if not REPAIR_COSTS:
		return [0, 0.0]
	var dmg := 100.0 - float(capsule["hull"])
	if bool(capsule["crashed"]):
		return [12 + int(dmg * 0.25), 0.0]
	return [2 + int(dmg * 0.15), 0.0]


## Pays and repairs. "" if it worked, otherwise why not.
func start_capsule_repair() -> String:
	var cost := int(capsule_repair_price()[0])
	if coins < cost:
		return "Not enough coins: the repair costs %d, you have %d. Win battles to earn more." % [cost, coins]
	coins -= cost
	capsule = {"hull": 100.0, "crashed": false, "repair_end": 0.0, "repair_total": 0.0}
	save_game()
	changed.emit()
	capsule_repaired.emit()
	return ""


# ---------------------------------------------------------------- SAVE / LOAD
func save_game() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": 2, "units": units, "conquered": conquered,
			"breed_charges": breed_charges, "next_id": next_id, "breeding": breeding, "coins": coins, "gems": gems,
			"planet_dev": planet_dev, "capsule": capsule}))


func load_game() -> void:
	new_game()
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.open(save_path, FileAccess.READ).get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not (int(data.get("version", 0)) in [1, 2]):
		return
	units = []
	for u in data["units"]:
		u["id"] = int(u["id"])
		u["lvl"] = int(u.get("lvl", 1))
		u.erase("power")
		u.erase("cell")
		var sp: Array = sort_elements(u["species"])
		u["species"] = sp.slice(0, MAX_ELEMENTS)
		u["strengths"] = strengths_of(u["species"])
		u["hybrid"] = u["species"].size() > 1
		units.append(u)
	conquered = int(data["conquered"])
	breed_charges = int(data["breed_charges"])
	next_id = int(data["next_id"])
	coins = int(data.get("coins", 0))
	gems = int(data.get("gems", 0))
	var cs = data.get("capsule", {})
	if typeof(cs) == TYPE_DICTIONARY:
		capsule = {"hull": clampf(float(cs.get("hull", 100.0)), 0.0, 100.0), "crashed": bool(cs.get("crashed", false)),
			"repair_end": float(cs.get("repair_end", 0.0)), "repair_total": float(cs.get("repair_total", 0.0))}
	var pd = data.get("planet_dev", {})
	if typeof(pd) == TYPE_DICTIONARY:
		for pid in pd:
			var st = pd[pid]
			if typeof(st) != TYPE_DICTIONARY:
				continue
			var blds = st.get("buildings", {})
			var clean := {}
			if typeof(blds) == TYPE_DICTIONARY:
				for site in blds:
					var b = blds[site]
					if typeof(b) == TYPE_DICTIONARY and PlanetDev.BUILDINGS.has(str(b.get("type", ""))) \
							and str(site).is_valid_int() and int(str(site)) < PlanetDev.SITE_COUNT:
						clean[str(site)] = {"type": str(b["type"]), "built_at": float(b.get("built_at", 0))}
			var found: Array = []
			if typeof(st.get("found", [])) == TYPE_ARRAY:
				for k in st["found"]:
					found.append(str(k))
			var pos: Array = []
			var sp = st.get("pos", [])
			if typeof(sp) == TYPE_ARRAY and (sp.size() == 6 or sp.size() == 12):
				for v in sp:
					pos.append(float(v))
			planet_dev[str(pid)] = {"buildings": clean, "found": found, "pos": pos}
			var cr = st.get("craters", [])
			if typeof(cr) == TYPE_ARRAY and cr.size() % 7 == 0:
				var cl: Array = []
				for v in cr:
					cl.append(float(v))
				planet_dev[str(pid)]["craters"] = cl
			if st.has("time"):
				planet_dev[str(pid)]["time"] = float(st["time"])
	var br = data.get("breeding", {})
	if typeof(br) == TYPE_DICTIONARY and not br.is_empty():
		breeding = {"a": int(br["a"]), "b": int(br["b"]), "elements": int(br.get("elements", 2)), "end": float(br["end"]),
			"total": float(br["total"]), "chance": float(br.get("chance", HYBRID_CHANCE_BASE)),
			"ready": bool(br.get("ready", false)), "notified": bool(br.get("notified", false))}


func reset_game() -> void:
	new_game()
	save_game()
	changed.emit()
