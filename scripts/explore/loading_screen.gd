class_name LoadingScreen
extends Control
## Shown while a planet is being built: the planet turns in space and its surface is "painted"
## band by band as the loading goes on (ground, seas, plants, animals), the capsule circles it
## and spirals down, stars drift past, a progress bar and the current step. Fades out when ready.

var pl: Dictionary
var biome: Dictionary
var k := 0.0                   # shown progress (follows `goal` smoothly)
var goal := 0.0
var step := ""
var t := 0.0
var stars: Array = []
var tip_i := 0
var done := false
var col_ground := Color.DARK_GREEN
var col_high := Color.GREEN
var col_sea := Color.DARK_BLUE
var col_sky := Color.SKY_BLUE
var col_accent := Color.WHITE

const TIPS := [
	"Press E near an animal to look at it - G picks small ones up.",
	"Hold Shift to fly faster. C lands the capsule.",
	"N switches the navigator to the next place of interest.",
	"Every planet has its own day and night - and its own weather.",
	"Your capsule's cannon (left mouse) blasts real craters into the ground.",
	"Some animals are curious and come closer. Others are shy - move slowly.",
	"T opens the way back to the ship and to the other freed planets.",
	"V switches between first and third person when you walk.",
]


func setup(planet: Dictionary, b: Dictionary) -> void:
	pl = planet
	biome = b
	var tc: Dictionary = b.get("terrain", {})
	col_ground = tc.get("low", Color("#3a5a2a"))
	col_high = tc.get("high", Color("#5a8a3a"))
	col_sky = b.get("sky_horizon", Color("#9fd0ff"))
	col_accent = pl.get("accent", Color.WHITE)
	match str(b.get("water", "")):
		"ocean": col_sea = Color("#1f6fb8")
		"lava": col_sea = Color("#ff5a1a")
		"ice": col_sea = Color("#bfe6ff")
		_: col_sea = Color(col_ground).darkened(0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(pl.get("id", "")))
	for i in 160:
		stars.append([Vector2(rng.randf() * 1280.0, rng.randf() * 720.0), rng.randf_range(0.5, 2.0), rng.randf_range(10.0, 60.0)])
	tip_i = rng.randi() % TIPS.size()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_progress(value: float, text: String) -> void:
	goal = maxf(goal, clampf(value, 0.0, 1.0))
	if not text.is_empty():
		step = text


## Fade out, then remove itself
func finish() -> void:
	if done:
		return
	done = true
	goal = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.9)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	t += delta
	k = move_toward(k, goal, delta * 0.9)
	k = lerpf(k, goal, minf(1.0, delta * 3.0))
	if int(t / 5.0) != int((t - delta) / 5.0):
		tip_i = (tip_i + 1) % TIPS.size()
	queue_redraw()


func _draw() -> void:
	var w := size.x if size.x > 10.0 else 1280.0
	var h := size.y if size.y > 10.0 else 720.0
	var sc := minf(w / 1280.0, h / 720.0)
	draw_rect(Rect2(0, 0, w, h), Color("#04050d"))
	# stars drifting past (we are flying towards the planet)
	var centre := Vector2(w * 0.5, h * 0.44)
	for s: Array in stars:
		var p0: Vector2 = s[0]
		var dir := (p0 - Vector2(640, 330)).normalized()
		var p := Vector2(fposmod(p0.x + dir.x * t * float(s[2]), 1280.0), fposmod(p0.y + dir.y * t * float(s[2]), 720.0)) * sc
		var tail := dir * float(s[2]) * 0.12 * sc
		draw_line(p - tail, p, Color(0.8, 0.88, 1.0, 0.7), float(s[1]))
	# the planet: glow, then the disc, then its surface painted in bands as loading goes on
	var r := 150.0 * sc * (0.9 + 0.1 * k)
	for i in 6:
		draw_circle(centre, r + (6 - i) * 7.0 * sc, Color(col_sky, 0.05 + i * 0.015))
	draw_circle(centre, r, Color(col_sea).darkened(0.55))
	var bands := 22
	var shown := int(k * bands * 1.05)
	for b in bands:
		if b >= shown:
			break
		var y0 := -r + 2.0 * r * b / bands
		var y1 := -r + 2.0 * r * (b + 1) / bands
		var ym := (y0 + y1) * 0.5
		var half := sqrt(maxf(0.0, r * r - ym * ym))
		# rolling land patches along the band (the planet turns)
		var segs := 9
		for q in segs:
			var a0 := float(q) / segs
			var x0 := -half + 2.0 * half * a0
			var x1 := -half + 2.0 * half * (a0 + 1.0 / segs)
			var land := sin(float(q) * 1.7 + float(b) * 0.9 + t * 0.6) + sin(float(b) * 2.3 - t * 0.4 + q * 0.5)
			var c := col_sea
			if land > -0.3:
				c = col_ground.lerp(col_high, clampf(land * 0.6, 0.0, 1.0))
			var shade := 0.55 + 0.45 * clampf(1.0 - (x0 + half) / (2.0 * half + 0.01), 0.0, 1.0)
			draw_rect(Rect2(centre + Vector2(x0, y0), Vector2(x1 - x0 + 1.0, y1 - y0 + 0.6)), c * Color(shade, shade, shade))
	# night side
	draw_arc(centre + Vector2(r * 0.42, 0), r * 0.82, -PI * 0.5, PI * 0.5, 40, Color(0, 0, 0, 0.35), r * 0.55)
	draw_arc(centre, r + 1.0, 0.0, TAU, 72, Color(col_sky, 0.8), 3.0 * sc)
	# the "scan line" painting the next band
	if k < 1.0:
		var ys := -r + 2.0 * r * minf(k * 1.05, 1.0)
		var hs := sqrt(maxf(0.0, r * r - ys * ys))
		draw_line(centre + Vector2(-hs, ys), centre + Vector2(hs, ys), Color(col_accent, 0.9), 3.0 * sc)
	# the capsule circles the planet and spirals closer while loading
	var orbit := r * (1.75 - 0.55 * k)
	var ang := t * 1.3
	var cp := centre + Vector2(cos(ang) * orbit, sin(ang) * orbit * 0.38)
	var behind := sin(ang) < 0.0
	if not behind or (cp - centre).length() > r:
		var fwd := Vector2(-sin(ang), cos(ang) * 0.38).normalized()
		var side := Vector2(-fwd.y, fwd.x)
		var tip := cp + fwd * 12.0 * sc
		draw_colored_polygon(PackedVector2Array([tip, cp - fwd * 8.0 * sc + side * 6.0 * sc, cp - fwd * 5.0 * sc, cp - fwd * 8.0 * sc - side * 6.0 * sc]), Color("#e8ecff"))
		for i in 6:
			draw_circle(cp - fwd * (10.0 + i * 5.0) * sc, (4.0 - i * 0.55) * sc, Color(1.0, 0.7, 0.3, 0.5 - i * 0.08))
	# text and progress bar
	var f := UI.font()
	var title := "Landing on %s" % str(pl.get("name", "?"))
	draw_string(UI.bold_font(), Vector2(0, h * 0.8 - 40.0 * sc), title, HORIZONTAL_ALIGNMENT_CENTER, w, int(34 * sc), UI.GOLD)
	var facts := "%s  ·  %s  ·  gravity %.1f" % [str(pl.get("kind", "")), str(biome.get("temp", "")), float(biome.get("gravity", 9.8))]
	draw_string(f, Vector2(0, h * 0.8 - 8.0 * sc), facts, HORIZONTAL_ALIGNMENT_CENTER, w, int(17 * sc), UI.SOFT)
	var bw := 520.0 * sc
	var bx := (w - bw) * 0.5
	var by := h * 0.8 + 14.0 * sc
	draw_rect(Rect2(bx, by, bw, 14.0 * sc), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(bx, by, bw * k, 14.0 * sc), col_accent)
	# a shine running along the bar
	var sx := fposmod(t * 260.0 * sc, bw * maxf(k, 0.05))
	draw_rect(Rect2(bx + sx, by, 30.0 * sc, 14.0 * sc), Color(1, 1, 1, 0.35))
	draw_rect(Rect2(bx, by, bw, 14.0 * sc), Color(col_accent, 0.7), false, 2.0)
	var dots := ".".repeat(1 + int(t * 2.5) % 3)
	draw_string(f, Vector2(0, by + 42.0 * sc), "%s%s   %d%%" % [step, dots, int(round(k * 100.0))], HORIZONTAL_ALIGNMENT_CENTER, w, int(18 * sc), UI.TEXT)
	draw_string(f, Vector2(0, h - 26.0 * sc), "Tip: " + str(TIPS[tip_i]), HORIZONTAL_ALIGNMENT_CENTER, w, int(15 * sc), Color(UI.SOFT, 0.85))
