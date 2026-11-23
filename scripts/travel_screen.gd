class_name TravelScreen
extends Control
## The short flight from one planet to another (about 3.5 seconds): the planet you leave falls
## away behind, stars stream past, the sun glows to the side, the destination grows ahead -
## then the planet is loaded and you arrive there as usual (descending from above, with its
## saved state). Any key skips it.

var main: Node
var from_n := 0
var to_n := 1
var t := 0.0
const DURATION := 3.6
var stars: Array = []            # [direction (2D), distance 0..1, speed]
var done := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = from_n * 31 + to_n
	for i in 260:
		var a := rng.randf() * TAU
		stars.append([Vector2(cos(a), sin(a)), rng.randf(), rng.randf_range(0.5, 1.5)])
	var name_lbl := UI.label("Flying to %s" % Game.planet(to_n)["name"], 30, UI.TEXT)
	name_lbl.position = Vector2(0, 600)
	name_lbl.size = Vector2(1280, 40)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_lbl)
	var sub := UI.label("%s  ·  %s" % [Game.planet(to_n)["kind"], Game.planet(to_n)["desc"]], 15, UI.SOFT)
	sub.position = Vector2(140, 645)
	sub.size = Vector2(1000, 60)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if t >= DURATION and not done:
		_finish()


func _gui_input(event: InputEvent) -> void:
	if t > 0.5 and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed() and not done:
		_finish()


func _unhandled_key_input(event: InputEvent) -> void:
	if t > 0.5 and event.is_pressed() and not done:
		_finish()


func _finish() -> void:
	done = true
	main.call("show_planet", to_n)


func _draw() -> void:
	var sz := Vector2(1280, 720)
	var c := sz * 0.5
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.01, 0.012, 0.03))
	var k := clampf(t / DURATION, 0.0, 1.0)
	var speed := sin(k * PI)                    # speeds up, then slows down to arrive
	# the sun's glow to the side (brighter for the inner planets)
	var sun_side := Vector2(1150, 120)
	var warm := 0.25 + 0.06 * float(to_n)
	for i in 6:
		draw_circle(sun_side, 260.0 - i * 40.0, Color(1.0, 0.75, 0.4, 0.025 * warm * (i + 1)))
	# stars streaming out of the middle
	for s: Array in stars:
		var d: Vector2 = s[0]
		var dist := fmod(float(s[1]) + t * 0.25 * float(s[2]) * (0.3 + speed * 2.2), 1.0)
		var r := dist * dist * 900.0
		var p := c + d * r
		var streak := 2.0 + speed * 40.0 * dist
		var a := clampf(dist * 1.5, 0.0, 1.0)
		draw_line(p, p + d * streak, Color(0.85, 0.9, 1.0, a * 0.8), 1.0 + dist, true)
	# the planet you leave: big at first, falling away to the lower left
	var fk := clampf(k / 0.55, 0.0, 1.0)
	var from_col: Color = Game.planet(from_n)["color"]
	var fr := lerpf(520.0, 10.0, ease(fk, 0.4))
	var fp := c + Vector2(-260, 420).lerp(Vector2(-600, 360), fk)
	if fk < 1.0:
		_planet(fp, fr, from_col, 1.0 - fk * 0.8)
	# the destination: a dot ahead that grows
	var to_col: Color = Game.planet(to_n)["color"]
	var tk := clampf((k - 0.15) / 0.85, 0.0, 1.0)
	var tr := lerpf(3.0, 230.0, pow(tk, 2.2))
	_planet(c + Vector2(0, -30) * tk, tr, to_col, clampf(tk * 3.0, 0.0, 1.0))
	# fade in / out
	var fade := maxf(1.0 - t / 0.5, 0.0) + maxf((t - (DURATION - 0.5)) / 0.5, 0.0)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, clampf(fade, 0.0, 1.0)))


## A planet disc: lit from the sun side, dark night side, a thin glow of air
func _planet(p: Vector2, r: float, col: Color, a: float) -> void:
	if r < 1.0:
		return
	draw_circle(p, r * 1.06, Color(col.lightened(0.4), 0.18 * a))
	draw_circle(p, r, Color(col.darkened(0.75), a))
	# day side: offset circles towards the sun
	for i in 5:
		var f := 1.0 - i * 0.16
		draw_circle(p + Vector2(r * (1.0 - f) * 0.55, -r * (1.0 - f) * 0.35), r * f, Color(col.lerp(col.darkened(0.6), f * 0.6), a * 0.35))
	draw_arc(p, r, 0, TAU, 64, Color(col.lightened(0.5), 0.5 * a), maxf(1.0, r * 0.02), true)
