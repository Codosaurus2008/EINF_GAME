class_name Art
extends RefCounted
## All drawing in one place: planets, the sun, stars and the characters.
## Characters are placeholder art for now. To use real sprites later, put a PNG at
## res://art/units/<planet id>.png (e.g. glacia.png) - it is used automatically.

static var _tex_cache := {}


# ================================================================== helpers
## Horizontal line inside a circle (for bands / stripes that never leave the planet)
static func chord(ci: CanvasItem, c: Vector2, r: float, y: float, col: Color, width: float) -> void:
	if abs(y) >= r:
		return
	var w := sqrt(r * r - y * y)
	ci.draw_line(c + Vector2(-w, y), c + Vector2(w, y), col, width, true)


## Ball with soft light from the top-left (rings of lighter colour inside the circle)
static func shaded_ball(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col.darkened(0.55))
	var steps := 7
	for i in steps:
		var k := float(i) / steps
		var rr := r * (1.0 - k * 0.75)
		var off := Vector2(-1, -1).normalized() * (r - rr) * 0.75
		ci.draw_circle(c + off, rr, col.darkened(0.45 - k * 0.6).lightened(max(0.0, k - 0.6) * 0.5))


static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color, strength := 0.25) -> void:
	for i in 6:
		var k := float(i) / 6.0
		ci.draw_circle(c, r * (1.0 + 0.6 * (1.0 - k)), Color(col, strength * k * 0.35))


## Random point inside a circle that keeps a feature of size s fully inside
static func inside(rng: RandomNumberGenerator, r: float, s: float) -> Vector2:
	var a := rng.randf() * TAU
	var d := sqrt(rng.randf()) * maxf(0.0, r - s)
	return Vector2(cos(a), sin(a)) * d


# ================================================================== stars
static func make_stars(count: int, size: Vector2, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stars := []
	for i in count:
		stars.append([Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(0.5, 1.8), rng.randf() * TAU])
	return stars


static func draw_space(ci: CanvasItem, size: Vector2, stars: Array, t: float) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
	# nebula clouds
	var neb := [[Vector2(0.15, 0.7), 260.0, Color("#3b1f6e")], [Vector2(0.85, 0.3), 300.0, Color("#123a6b")], [Vector2(0.55, 0.9), 220.0, Color("#4a1747")]]
	for nb in neb:
		var p: Vector2 = nb[0] * size
		for i in 8:
			ci.draw_circle(p, nb[1] * (1.0 - i / 8.0), Color(nb[2], 0.06))
	for s in stars:
		var tw := 0.55 + 0.45 * sin(t * 1.7 + s[2])
		ci.draw_circle(s[0], s[1], Color(1, 1, 1, tw))


# ================================================================== planets
static func draw_planet(ci: CanvasItem, id: String, c: Vector2, r: float, t: float) -> void:
	var p: Dictionary = Game.planet(Game.planet_index(id))
	var col: Color = p["color"]
	var acc: Color = p["accent"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	match id:
		"sun":
			_draw_sun(ci, c, r, t)
			return
		"pebble":
			_draw_asteroid(ci, c, r, col, rng)
			return
	glow(ci, c, r, acc, 0.35)
	shaded_ball(ci, c, r, col)
	match id:
		"glacia":
			for y in [-0.82, -0.7, 0.72, 0.84]:
				chord(ci, c, r, y * r, Color(1, 1, 1, 0.85), r * 0.14)
			for i in 6:
				var a := inside(rng, r, r * 0.3)
				var b := a + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * r * 0.3
				ci.draw_line(c + a, c + b, Color(1, 1, 1, 0.6), 1.5, true)
		"mycelia":
			for i in 14:
				var s := rng.randf_range(0.05, 0.13) * r
				var a := inside(rng, r, s)
				ci.draw_circle(c + a, s, Color(acc, 0.85))
				ci.draw_circle(c + a + Vector2(-s * 0.3, -s * 0.3), s * 0.35, Color(1, 1, 1, 0.6))
		"aquora":
			for i in 5:
				var s := rng.randf_range(0.06, 0.14) * r
				var a := inside(rng, r, s)
				ci.draw_circle(c + a, s, Color("#f3d9a0"))
				ci.draw_circle(c + a, s * 0.75, Color("#58c46a"))
			for i in 4:
				var y := rng.randf_range(-0.6, 0.6) * r
				var w := sqrt(r * r - y * y) * 0.7
				var x0 := rng.randf_range(-w, 0.0)
				ci.draw_line(c + Vector2(x0, y), c + Vector2(x0 + w, y - r * 0.05), Color(1, 1, 1, 0.55), r * 0.05, true)
		"verdis":
			for i in 12:
				var s := rng.randf_range(0.08, 0.18) * r
				var a := inside(rng, r, s)
				ci.draw_circle(c + a, s, Color("#1f7a3a", 0.8))
			for i in 8:
				var s := rng.randf_range(0.03, 0.06) * r
				ci.draw_circle(c + inside(rng, r, s), s, Color(acc, 0.8))
		"ferrum":
			for i in 7:
				var s := rng.randf_range(0.1, 0.2) * r
				var a := inside(rng, r, s * 1.4)
				var pts := PackedVector2Array()
				for k in 5:
					var ang := TAU * k / 5.0 + rng.randf() * 0.4
					pts.append(c + a + Vector2(cos(ang), sin(ang)) * s)
				ci.draw_colored_polygon(pts, Color("#7d8796", 0.85))
			for i in 5:
				var a := inside(rng, r, r * 0.25)
				var b := a + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * r * 0.25
				ci.draw_line(c + a, c + b, Color(acc, 0.6 + 0.4 * sin(t * 3.0 + i)), r * 0.04, true)
		"voltara":
			for i in 7:
				var y := (-0.75 + i * 0.25) * r
				chord(ci, c, r * 0.97, y, Color(col.lightened(0.25 if i % 2 == 0 else -0.1), 0.6), r * 0.1)
			if fmod(t, 2.3) < 0.25:
				var a := Vector2(rng.randf_range(-0.4, 0.4) * r, -0.5 * r)
				var pts := PackedVector2Array([c + a, c + a + Vector2(0.15, 0.3) * r, c + a + Vector2(-0.05, 0.4) * r, c + a + Vector2(0.12, 0.8) * r])
				ci.draw_polyline(pts, acc, 2.5, true)
		"solara":
			for i in 10:
				var s := r * 0.035
				ci.draw_circle(c + inside(rng, r, s), s, Color(1, 1, 1, 0.5 + 0.5 * sin(t * 2.0 + i)))
			# ring
			var ring := PackedVector2Array()
			for k in 65:
				var ang := TAU * k / 64.0
				ring.append(c + Vector2(cos(ang) * r * 1.7, sin(ang) * r * 0.35))
			ci.draw_polyline(ring, Color(acc, 0.7), 2.5, true)
	# soft terminator shadow on the lower right
	for i in 4:
		var rr := r * (1.0 - i * 0.04)
		ci.draw_arc(c, rr, -0.2, PI * 0.95, 32, Color(0, 0, 0, 0.12), r * 0.08, true)


static func _draw_asteroid(ci: CanvasItem, c: Vector2, r: float, col: Color, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var ang := TAU * k / 14.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * r * rng.randf_range(0.78, 1.05))
	ci.draw_colored_polygon(pts, col.darkened(0.35))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.86 + Vector2(-r * 0.06, -r * 0.06))
	ci.draw_colored_polygon(inner, col)
	for i in 6:
		var s := rng.randf_range(0.08, 0.16) * r
		var a := inside(rng, r * 0.75, s)
		ci.draw_circle(c + a, s, col.darkened(0.3))
		ci.draw_arc(c + a, s, PI * 0.9, PI * 1.9, 12, col.lightened(0.25), 1.5, true)


static func _draw_sun(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	for i in 10:
		var k := float(i) / 10.0
		ci.draw_circle(c, r * (2.4 - k * 1.3), Color(1.0, 0.55 + k * 0.2, 0.15, 0.05 + k * 0.03))
	# corona flares
	for i in 18:
		var ang := TAU * i / 18.0 + t * 0.15
		var flare_len := r * (1.25 + 0.15 * sin(t * 2.0 + i * 1.7))
		var a := c + Vector2(cos(ang - 0.08), sin(ang - 0.08)) * r * 0.95
		var b := c + Vector2(cos(ang), sin(ang)) * flare_len
		var d := c + Vector2(cos(ang + 0.08), sin(ang + 0.08)) * r * 0.95
		ci.draw_colored_polygon(PackedVector2Array([a, b, d]), Color(1.0, 0.75, 0.3, 0.55))
	shaded_ball(ci, c, r, Color("#ffb13b"))
	ci.draw_circle(c + Vector2(-r * 0.2, -r * 0.2), r * 0.45, Color(1, 0.95, 0.75, 0.55))


# ================================================================== characters
static func _sprite(id: String) -> Texture2D:
	if not _tex_cache.has(id):
		var path := "res://art/units/%s.png" % id
		_tex_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[id]


## Radius of a character on screen: a bit bigger for every element
static func unit_radius(u: Dictionary, base := 18.0) -> float:
	return base * (1.0 + 0.09 * (u["species"].size() - 1))


## How creatures are drawn: "3d" (3D models as pictures), "2d" (drawn shapes), "classic"
## (the first round look). Switch with F5 or the "Look" buttons.
static var style := "3d"
const STYLES := ["3d", "2d", "classic"]
const STYLE_NAMES := {"3d": "3D models", "2d": "2D drawings", "classic": "Classic"}


static func next_style() -> String:
	style = STYLES[(STYLES.find(style) + 1) % STYLES.size()]
	return style


## Draws one character. team: 0 = player, 1 = enemy. pose: idle / walk / attack / hurt
static func draw_unit(ci: CanvasItem, u: Dictionary, c: Vector2, r: float, team: int, t: float, facing := 1.0, pose := "") -> void:
	var species: Array = u["species"]
	# shadow + team ring
	ci.draw_set_transform(c + Vector2(0, r * 0.95), 0.0, Vector2(1.0, 0.3))
	ci.draw_circle(Vector2.ZERO, r * 0.9, Color(0, 0, 0, 0.35))
	ci.draw_arc(Vector2.ZERO, r * 1.05, 0, TAU, 32, UI.CYAN if team == 0 else UI.RED, 3.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if style == "3d" and CreatureSprites.draw(ci, u, c, r, facing, pose):
		_crown_and_badge(ci, u, c, r)
		return
	if style == "2d":
		CreatureArt2D.draw(ci, u, c, r, t, facing, pose)
		_crown_and_badge(ci, u, c, r)
		return
	var bob := sin(t * 3.0 + float(u["id"])) * r * 0.05
	c += Vector2(0, bob)

	var tex: Texture2D = _sprite(species[0]) if species.size() == 1 else null
	if tex:
		var s := r * 2.4
		ci.draw_texture_rect(tex, Rect2(c - Vector2(s / 2.0, s * 0.6), Vector2(s * facing, s)), false)
		draw_level_badge(ci, c, r, int(u.get("lvl", 1)))
		return

	var cols: Array = Game.unit_colors(u)
	var umbra: bool = u.get("umbra", false)
	if umbra:   # the Umbra: dark, shadowy versions of the planet's people
		for i in cols.size():
			cols[i] = Color(cols[i]).lerp(Color("#24123a"), 0.6)
	# body: hybrids are split into coloured slices
	if cols.size() == 1:
		shaded_ball(ci, c, r, cols[0])
	else:
		ci.draw_circle(c, r, Color(cols[0]).darkened(0.5))
		for i in cols.size():
			var a0 := -PI / 2 + TAU * i / cols.size()
			var a1 := -PI / 2 + TAU * (i + 1) / cols.size()
			var pts := PackedVector2Array([c])
			for k in 13:
				var ang := lerpf(a0, a1, k / 12.0)
				pts.append(c + Vector2(cos(ang), sin(ang)) * r * 0.93)
			ci.draw_colored_polygon(pts, cols[i])
		ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.3, Color(1, 1, 1, 0.25))
	# eyes look towards the enemy
	var ex := r * 0.28 * facing
	for s in [-1.0, 1.0]:
		var e := c + Vector2(ex + s * r * 0.24, -r * 0.12)
		ci.draw_circle(e, r * 0.17, Color.WHITE)
		ci.draw_circle(e + Vector2(r * 0.06 * facing, 0), r * 0.09, Color("#ff2e4d") if umbra else Color("#14102a"))
	# tool of the most advanced species
	var best := 0
	for s in species:
		best = max(best, Game.planet_index(s))
	_draw_tool(ci, Game.PLANETS[best]["id"], c + Vector2(r * 0.95 * facing, r * 0.1), r, facing, Game.PLANETS[best]["accent"])
	if u.get("hero", false):
		var crown := PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.85), c + Vector2(-r * 0.3, -r * 1.25), c + Vector2(-r * 0.1, -r * 0.95),
			c + Vector2(0, -r * 1.35), c + Vector2(r * 0.1, -r * 0.95), c + Vector2(r * 0.3, -r * 1.25), c + Vector2(r * 0.45, -r * 0.85)])
		ci.draw_colored_polygon(crown, UI.GOLD)
	draw_level_badge(ci, c, r, int(u.get("lvl", 1)))


static func _crown_and_badge(ci: CanvasItem, u: Dictionary, c: Vector2, r: float) -> void:
	if u.get("hero", false):
		var top := c + Vector2(0, -r * 1.55)
		var crown := PackedVector2Array([top + Vector2(-r * 0.35, r * 0.2), top + Vector2(-r * 0.25, -r * 0.12), top + Vector2(-r * 0.08, r * 0.08),
			top + Vector2(0, -r * 0.2), top + Vector2(r * 0.08, r * 0.08), top + Vector2(r * 0.25, -r * 0.12), top + Vector2(r * 0.35, r * 0.2)])
		ci.draw_colored_polygon(crown, UI.GOLD)
	draw_level_badge(ci, c, r, int(u.get("lvl", 1)))


static func _draw_tool(ci: CanvasItem, id: String, p: Vector2, r: float, f: float, acc: Color) -> void:
	var w := maxf(2.0, r * 0.12)
	match id:
		"pebble":    # slingshot
			ci.draw_line(p, p + Vector2(0, -r * 0.6), Color("#8a6a4a"), w, true)
			ci.draw_line(p + Vector2(0, -r * 0.6), p + Vector2(-r * 0.2, -r * 0.9), Color("#8a6a4a"), w, true)
			ci.draw_line(p + Vector2(0, -r * 0.6), p + Vector2(r * 0.2, -r * 0.9), Color("#8a6a4a"), w, true)
		"glacia":    # ice spear
			ci.draw_line(p + Vector2(0, r * 0.4), p + Vector2(r * 0.3 * f, -r * 1.0), Color("#d8f4ff"), w, true)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(r * 0.3 * f, -r * 1.3), p + Vector2(r * 0.18 * f, -r * 0.95), p + Vector2(r * 0.42 * f, -r * 0.95)]), Color.WHITE)
		"mycelia":   # spore pod
			ci.draw_line(p, p + Vector2(0, -r * 0.5), Color("#6b4f9e"), w, true)
			ci.draw_circle(p + Vector2(0, -r * 0.65), r * 0.22, acc)
		"aquora":    # trident
			ci.draw_line(p + Vector2(0, r * 0.4), p + Vector2(0, -r * 0.9), Color("#d6f6ff"), w, true)
			for dx in [-0.18, 0.0, 0.18]:
				ci.draw_line(p + Vector2(dx * r, -r * 0.8), p + Vector2(dx * r, -r * 1.15), Color("#d6f6ff"), w * 0.8, true)
		"verdis":    # thorn bow
			ci.draw_arc(p + Vector2(-r * 0.15 * f, -r * 0.3), r * 0.55, -PI / 2 if f > 0 else PI / 2, PI / 2 if f > 0 else PI * 1.5, 12, Color("#2f7a3a"), w, true)
		"ferrum":    # steam cannon
			ci.draw_rect(Rect2(p + Vector2(-r * 0.1, -r * 0.35), Vector2(r * 0.7 * f, r * 0.3)), Color("#5c6370"))
			ci.draw_circle(p + Vector2(r * 0.6 * f, -r * 0.2), r * 0.12, acc)
		"voltara":   # lightning rod
			ci.draw_line(p + Vector2(0, r * 0.3), p + Vector2(0, -r * 0.8), Color("#c9c3ff"), w, true)
			ci.draw_polyline(PackedVector2Array([p + Vector2(0, -r * 0.8), p + Vector2(r * 0.15, -r * 1.0), p + Vector2(-r * 0.05, -r * 1.1), p + Vector2(r * 0.12, -r * 1.35)]), acc, w * 0.8, true)
		"solara", "sun":   # light lance
			ci.draw_line(p + Vector2(-r * 0.2 * f, r * 0.2), p + Vector2(r * 0.6 * f, -r * 0.9), Color.WHITE, w, true)
			ci.draw_circle(p + Vector2(r * 0.6 * f, -r * 0.9), r * 0.15, Color(acc, 0.9))


# ================================================================== level badge
## Bold orange level at the bottom right of a character ("Lv3")
static func draw_level_badge(ci: CanvasItem, c: Vector2, r: float, lvl: int) -> void:
	var font := UI.bold_font()
	var fsize := int(clampf(r * 0.8, 15.0, 28.0))
	var txt := "Lv%d" % lvl
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + 14.0
	var h := fsize + 8.0
	var pos := c + Vector2(r * 0.85 - w / 2.0, r * 0.85 - h / 2.0)
	var box := Rect2(pos, Vector2(w, h))
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(UI.ORANGE, 0.35)
	glow.set_corner_radius_all(int(h / 2.0) + 4)
	ci.draw_style_box(glow, box.grow(4.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.ORANGE
	sb.border_color = Color("#2a1203")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(h / 2.0))
	ci.draw_style_box(sb, box)
	var base := Vector2(pos.x, pos.y + h * 0.5 + fsize * 0.36)
	ci.draw_string_outline(font, base, txt, HORIZONTAL_ALIGNMENT_CENTER, w, fsize, 6, Color("#2a1203"))
	ci.draw_string(font, base, txt, HORIZONTAL_ALIGNMENT_CENTER, w, fsize, Color.WHITE)


# ================================================================== strength symbols
## Colour of each strength symbol
const SYMBOL_COLORS := {
	"grit": "#c9a27e", "scavenge": "#9ad86b", "improvise": "#ffd34d",
	"frost_armor": "#9fdcff", "chill": "#d8f4ff", "endurance": "#ff6b81",
	"regrowth": "#6bdc7a", "poison": "#a6ff4d", "spore_burst": "#7dffcf",
	"flow": "#7ff5ff", "tidal_wave": "#3fa9ff", "healing_waters": "#5fd2ff",
	"thorns": "#3fae5a", "ambush": "#e0e4ff", "rooting": "#b07a4a",
	"steel_plating": "#aeb6c4", "heavy_shot": "#ff8a3d", "forge_master": "#ffb347",
	"chain_lightning": "#fff36b", "overcharge": "#ffd23f", "energy_shield": "#b58cff",
	"blink": "#ffffff", "radiance": "#ff9a2e", "sunbeam": "#ffe27a",
}


## Draws the symbol of a strength in a small round badge (r = radius)
static func draw_strength_icon(ci: CanvasItem, id: String, c: Vector2, r: float) -> void:
	var col := Color(SYMBOL_COLORS.get(id, "#ffffff"))
	ci.draw_circle(c, r, Color(0.06, 0.07, 0.16, 0.95))
	ci.draw_arc(c, r, 0, TAU, 24, col, maxf(1.5, r * 0.12), true)
	var k := r * 0.62
	var w := maxf(1.5, r * 0.16)
	match id:
		"grit", "frost_armor":     # shield
			var pts := PackedVector2Array([c + Vector2(-k, -k * 0.8), c + Vector2(k, -k * 0.8), c + Vector2(k * 0.85, k * 0.2), c + Vector2(0, k), c + Vector2(-k * 0.85, k * 0.2)])
			ci.draw_colored_polygon(pts, col)
			if id == "frost_armor":
				ci.draw_line(c + Vector2(0, -k * 0.5), c + Vector2(0, k * 0.5), Color.WHITE, w * 0.8, true)
				ci.draw_line(c + Vector2(-k * 0.45, 0), c + Vector2(k * 0.45, 0), Color.WHITE, w * 0.8, true)
		"scavenge":                # claw marks
			for i in 3:
				var x := (i - 1) * k * 0.55
				ci.draw_line(c + Vector2(x - k * 0.25, -k * 0.8), c + Vector2(x + k * 0.25, k * 0.8), col, w, true)
		"improvise":               # cog
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * k * 0.5, c + Vector2(cos(a), sin(a)) * k, col, w * 1.6, true)
			ci.draw_circle(c, k * 0.62, col)
			ci.draw_circle(c, k * 0.25, Color(0.06, 0.07, 0.16))
		"chill":                   # snowflake
			for i in 3:
				var a := PI * i / 3.0
				ci.draw_line(c - Vector2(cos(a), sin(a)) * k, c + Vector2(cos(a), sin(a)) * k, col, w, true)
		"endurance":               # heart with plus
			_heart(ci, c, k, col)
			ci.draw_line(c + Vector2(-k * 0.3, -k * 0.05), c + Vector2(k * 0.3, -k * 0.05), Color.WHITE, w * 0.8, true)
			ci.draw_line(c + Vector2(0, -k * 0.35), c + Vector2(0, k * 0.25), Color.WHITE, w * 0.8, true)
		"regrowth":                # leaf
			var pts := PackedVector2Array()
			for i in 13:
				var tt := float(i) / 12.0
				pts.append(c + Vector2(lerpf(-k, k, tt), -sin(tt * PI) * k * 0.6 + lerpf(k * 0.5, -k * 0.5, tt)))
			for i in range(11, 0, -1):   # skip both ends (already in the list)
				var tt := float(i) / 12.0
				pts.append(c + Vector2(lerpf(-k, k, tt), sin(tt * PI) * k * 0.6 + lerpf(k * 0.5, -k * 0.5, tt)))
			ci.draw_colored_polygon(pts, col)
		"poison", "healing_waters":   # droplet
			var pts := PackedVector2Array([c + Vector2(0, -k)])
			for i in 13:
				var a := PI * i / 12.0 - PI
				pts.append(c + Vector2(-cos(a) * k * 0.65, k * 0.3 - sin(a) * k * 0.65))
			ci.draw_colored_polygon(pts, col)
			if id == "healing_waters":
				ci.draw_line(c + Vector2(-k * 0.3, k * 0.25), c + Vector2(k * 0.3, k * 0.25), Color.WHITE, w * 0.8, true)
				ci.draw_line(c + Vector2(0, -k * 0.05), c + Vector2(0, k * 0.55), Color.WHITE, w * 0.8, true)
			else:
				ci.draw_circle(c + Vector2(0, k * 0.3), k * 0.2, Color(0.06, 0.07, 0.16))
		"spore_burst", "radiance":    # burst / sun
			for i in 10:
				var a := TAU * i / 10.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * k * 0.45, c + Vector2(cos(a), sin(a)) * k, col, w, true)
			ci.draw_circle(c, k * 0.42, col)
		"flow":                    # two waves
			for j in 2:
				var pts := PackedVector2Array()
				for i in 13:
					var tt := float(i) / 12.0
					pts.append(c + Vector2(lerpf(-k, k, tt), (j - 0.5) * k * 0.8 + sin(tt * TAU) * k * 0.25))
				ci.draw_polyline(pts, col, w, true)
		"tidal_wave":              # big curling wave
			ci.draw_arc(c + Vector2(0, k * 0.1), k * 0.75, PI, TAU * 0.95, 16, col, w * 1.4, true)
			ci.draw_line(c + Vector2(-k, k * 0.6), c + Vector2(k, k * 0.6), col, w, true)
		"thorns":                  # three spikes
			for i in 3:
				var x := (i - 1) * k * 0.65
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - k * 0.3, k * 0.7), c + Vector2(x, -k * 0.8), c + Vector2(x + k * 0.3, k * 0.7)]), col)
		"ambush":                  # eye
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				pts.append(c + Vector2(-cos(a) * k, -sin(a) * k * 0.55))
			for i in range(1, 12):       # skip both ends (already in the list)
				var a := PI * i / 12.0
				pts.append(c + Vector2(cos(a) * k, sin(a) * k * 0.55))
			ci.draw_colored_polygon(pts, col)
			ci.draw_circle(c, k * 0.35, Color(0.06, 0.07, 0.16))
		"rooting":                 # roots
			ci.draw_line(c + Vector2(0, -k), c + Vector2(0, k * 0.3), col, w * 1.3, true)
			for s in [-1.0, 1.0]:
				ci.draw_line(c + Vector2(0, k * 0.1), c + Vector2(s * k * 0.8, k * 0.85), col, w, true)
				ci.draw_line(c + Vector2(0, -k * 0.3), c + Vector2(s * k * 0.6, k * 0.2), col, w, true)
		"steel_plating":           # metal plate with rivets
			ci.draw_rect(Rect2(c - Vector2(k, k * 0.75), Vector2(k * 2, k * 1.5)), col)
			for p in [Vector2(-0.7, -0.5), Vector2(0.7, -0.5), Vector2(-0.7, 0.5), Vector2(0.7, 0.5)]:
				ci.draw_circle(c + p * k, k * 0.13, Color(0.06, 0.07, 0.16))
		"heavy_shot":              # cannonball with speed lines
			ci.draw_circle(c + Vector2(k * 0.3, 0), k * 0.55, col)
			for j in 3:
				var y := (j - 1) * k * 0.35
				ci.draw_line(c + Vector2(-k, y), c + Vector2(-k * 0.35, y), col, w * 0.8, true)
		"forge_master":            # hammer
			ci.draw_line(c + Vector2(-k * 0.6, k * 0.8), c + Vector2(k * 0.2, -k * 0.1), col, w * 1.3, true)
			var head := PackedVector2Array([c + Vector2(-k * 0.1, -k * 0.75), c + Vector2(k * 0.95, k * 0.15), c + Vector2(k * 0.6, k * 0.5), c + Vector2(-k * 0.45, -k * 0.4)])
			ci.draw_colored_polygon(head, col)
		"chain_lightning":         # lightning bolt
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(k * 0.2, -k), c + Vector2(-k * 0.55, k * 0.1), c + Vector2(-k * 0.05, k * 0.1), c + Vector2(-k * 0.25, k), c + Vector2(k * 0.55, -k * 0.15), c + Vector2(k * 0.05, -k * 0.15)]), col)
		"overcharge":              # double arrow (faster)
			for j in 2:
				var x := (j - 0.5) * k * 0.8
				ci.draw_polyline(PackedVector2Array([c + Vector2(x - k * 0.35, -k * 0.65), c + Vector2(x + k * 0.3, 0), c + Vector2(x - k * 0.35, k * 0.65)]), col, w * 1.2, true)
		"energy_shield":           # hexagon
			var pts := PackedVector2Array()
			for i in 7:
				var a := TAU * i / 6.0 + PI / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * k)
			ci.draw_polyline(pts, col, w * 1.3, true)
			ci.draw_circle(c, k * 0.3, col)
		"blink":                   # 4-point sparkle
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k * 0.22, -k * 0.22), c + Vector2(k, 0), c + Vector2(k * 0.22, k * 0.22),
				c + Vector2(0, k), c + Vector2(-k * 0.22, k * 0.22), c + Vector2(-k, 0), c + Vector2(-k * 0.22, -k * 0.22)]), col)
		"sunbeam":                 # beam from a small sun
			ci.draw_circle(c + Vector2(-k * 0.55, -k * 0.55), k * 0.35, col)
			ci.draw_line(c + Vector2(-k * 0.3, -k * 0.3), c + Vector2(k, k), col, w * 1.6, true)
		_:
			ci.draw_circle(c, k * 0.5, col)


static func _heart(ci: CanvasItem, c: Vector2, k: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-k * 0.4, -k * 0.25), k * 0.45, col)
	ci.draw_circle(c + Vector2(k * 0.4, -k * 0.25), k * 0.45, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.83, -k * 0.1), c + Vector2(k * 0.83, -k * 0.1), c + Vector2(0, k * 0.85)]), col)


## Small icons for buttons: "heart" (breeding), "lock" (shop locked), "unlock" (shop not locked)
static func draw_icon(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color, t := 0.0) -> void:
	match kind:
		"egg":   # glowing egg in a small bio-chamber ring
			var pulse := 0.5 + 0.5 * sin(t * 4.0)
			glow(ci, c, r * 1.6, Color(0.3, 0.95, 1.0, 0.35 + 0.25 * pulse), 0.45)
			ci.draw_arc(c + Vector2(0, r * 0.15), r * 0.95, 0, TAU, 40, Color(1.0, 0.8, 0.35, 0.9), maxf(1.5, r * 0.08), true)
			var pts := PackedVector2Array()
			for i in 32:
				var a := TAU * i / 32.0
				var ry := r * (0.78 if sin(a) < 0.0 else 0.62)      # pointy top, round bottom
				pts.append(c + Vector2(cos(a) * r * 0.55, sin(a) * ry + r * 0.08))
			ci.draw_colored_polygon(pts, Color(0.55, 0.95, 1.0).lerp(Color.WHITE, 0.25 * pulse))
			ci.draw_circle(c + Vector2(-r * 0.18, -r * 0.25), r * 0.13, Color(1, 1, 1, 0.8))
			ci.draw_circle(c + Vector2(r * 0.12, r * 0.18), r * 0.09, Color(0.2, 0.6, 0.8, 0.6))
			ci.draw_circle(c + Vector2(-r * 0.05, r * 0.38), r * 0.07, Color(0.2, 0.6, 0.8, 0.6))
		"heart":
			_heart(ci, c + Vector2(0, r * 0.05), r, col)
			ci.draw_circle(c + Vector2(-r * 0.45, -r * 0.35), r * 0.13, Color(1, 1, 1, 0.55))
		"coin":
			ci.draw_circle(c, r, Color("#b8860b"))
			ci.draw_circle(c, r * 0.82, Color("#ffd34d"))
			ci.draw_arc(c, r * 0.58, 0, TAU, 20, Color("#c99a1e"), maxf(1.5, r * 0.12), true)
			ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.16, Color(1, 1, 1, 0.6))
		"gem":
			var top := PackedVector2Array([c + Vector2(-r, -r * 0.25), c + Vector2(-r * 0.5, -r * 0.8), c + Vector2(r * 0.5, -r * 0.8), c + Vector2(r, -r * 0.25)])
			var low := PackedVector2Array([c + Vector2(-r, -r * 0.25), c + Vector2(r, -r * 0.25), c + Vector2(0, r * 0.95)])
			ci.draw_colored_polygon(top, Color("#9ff3ff"))
			ci.draw_colored_polygon(low, Color("#38c8ff"))
			ci.draw_line(c + Vector2(-r * 0.5, -r * 0.25), c + Vector2(0, r * 0.95), Color(1, 1, 1, 0.5), 1.5, true)
			ci.draw_line(c + Vector2(r * 0.5, -r * 0.25), c + Vector2(0, r * 0.95), Color(1, 1, 1, 0.3), 1.5, true)
		"lock", "unlock":
			var w := r * 0.18
			var top := c.y - r * 0.05            # top of the lock body
			var sh_y := top - (r * 0.05 if kind == "lock" else r * 0.4)   # shackle lifted when open
			var sx := r * 0.42
			ci.draw_arc(Vector2(c.x, sh_y), sx, PI, TAU, 16, col, w, true)
			ci.draw_line(Vector2(c.x - sx, sh_y), Vector2(c.x - sx, top + w), col, w, true)
			var right_end := top + w if kind == "lock" else sh_y + r * 0.15
			ci.draw_line(Vector2(c.x + sx, sh_y), Vector2(c.x + sx, right_end), col, w, true)
			var body := Rect2(c.x - r * 0.7, top, r * 1.4, r * 0.95)
			ci.draw_rect(body, col)
			ci.draw_circle(Vector2(c.x, top + r * 0.38), r * 0.14, Color(0, 0, 0, 0.6))
			ci.draw_rect(Rect2(c.x - r * 0.05, top + r * 0.4, r * 0.1, r * 0.3), Color(0, 0, 0, 0.6))
