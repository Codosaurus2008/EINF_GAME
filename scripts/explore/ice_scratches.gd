class_name IceScratches
extends Node3D
## Scratches in the frozen lakes (Glacia): when the capsule's leg rods touch the ice while it
## moves, each rod carves a groove - a bundle of fine white hairlines, frosted and a little
## broken, that stays in the ice and fades slowly (about 4 minutes). Ice chips and frost powder
## fly up from the rods (Capsule does that) and the ice screeches (a scraping sound made here
## from filtered noise, louder and higher the faster you scrape).
## The grooves are thin ribbons lying just on the ice, collected in chunks: only the chunk that
## is growing is rebuilt, the oldest chunk is dropped when there are too many.

const CHUNK := 160              # segments per chunk
const MAX_CHUNKS := 14          # older scratches are removed (about 2200 segments in all)
const STEP := 0.12              # a new segment every 12 cm of rod movement
const LIFT := 0.012             # lies this far above the ice (no flicker)
const FADE := 240.0             # seconds until a scratch has faded away

var t := 0.0
var mat: ShaderMaterial
var chunks: Array = []          # [MeshInstance3D, verts, norms, uvs, uv2s, cols, segment count]
var strokes := {}               # rod id -> [last point, distance along, last width]
# scraping sound
var audio: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var scrape := 0.0               # wanted loudness 0..1 (set every frame by the capsule)
var scrape_pitch := 1.0
var _amp := 0.0
var _ph := 0.0
var _hp := 0.0
var _lp := 0.0
var _prev := 0.0
const RATE := 22050.0


func _ready() -> void:
	mat = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SCRATCH_SHADER
	mat.set_shader_parameter("fade_time", FADE)
	audio = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	audio.stream = gen
	audio.volume_db = -9.0
	add_child(audio)
	audio.play()
	playback = audio.get_stream_playback() as AudioStreamGeneratorPlayback


## Rod `id` touches the ice at p (on the ice surface). Call every frame while it touches.
## press 0..1: how hard (deeper, brighter groove)
func scratch(id: int, p: Vector3, press: float) -> void:
	var up := p.normalized()
	var q := p + up * LIFT
	var w := lerpf(0.035, 0.07, clampf(press, 0.0, 1.0))
	if not strokes.has(id):
		strokes[id] = [q, randf() * 20.0, w]
		return
	var st: Array = strokes[id]
	var a: Vector3 = st[0]
	var d := a.distance_to(q)
	if d < STEP:
		return
	if d > 3.0:
		# jumped (teleport, fast lift and touch): start a new groove
		strokes[id] = [q, randf() * 20.0, w]
		return
	var along := float(st[1])
	_add_segment(a, q, float(st[2]), w, along, along + d, clampf(press, 0.25, 1.0))
	strokes[id] = [q, along + d, w]


## Rod `id` left the ice: the groove ends here
func lift(id: int) -> void:
	strokes.erase(id)


func _add_segment(a: Vector3, b: Vector3, wa: float, wb: float, sa: float, sb: float, k: float) -> void:
	if chunks.is_empty() or int(chunks[-1][6]) >= CHUNK:
		_new_chunk()
	var c: Array = chunks[-1]
	var up := ((a + b) * 0.5).normalized()
	var side := (b - a).cross(up).normalized()
	# a slight wobble: a scratch is never quite straight
	var jit := side * randf_range(-0.004, 0.004)
	var verts: PackedVector3Array = c[1]
	var norms: PackedVector3Array = c[2]
	var uvs: PackedVector2Array = c[3]
	var uv2s: PackedVector2Array = c[4]
	var cols: PackedColorArray = c[5]
	var pts := [a - side * wa * 0.5, a + side * wa * 0.5, b - side * wb * 0.5 + jit, b + side * wb * 0.5 + jit]
	var uv := [Vector2(sa, 0.0), Vector2(sa, 1.0), Vector2(sb, 0.0), Vector2(sb, 1.0)]
	for i in [0, 1, 2, 1, 3, 2]:
		verts.append(pts[i])
		norms.append(up)
		uvs.append(uv[i])
		uv2s.append(Vector2(t, 0.0))
		cols.append(Color(1, 1, 1, k))
	# (write the arrays back: packed arrays taken out of an Array may be copies)
	c[1] = verts
	c[2] = norms
	c[3] = uvs
	c[4] = uv2s
	c[5] = cols
	c[6] = int(c[6]) + 1
	_rebuild(c)


func _new_chunk() -> void:
	if chunks.size() >= MAX_CHUNKS:
		var old: Array = chunks.pop_front()
		(old[0] as MeshInstance3D).queue_free()
	var mi := MeshInstance3D.new()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	chunks.append([mi, PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedVector2Array(), PackedColorArray(), 0])


func _rebuild(c: Array) -> void:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = c[1]
	arr[Mesh.ARRAY_NORMAL] = c[2]
	arr[Mesh.ARRAY_TEX_UV] = c[3]
	arr[Mesh.ARRAY_TEX_UV2] = c[4]
	arr[Mesh.ARRAY_COLOR] = c[5]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	(c[0] as MeshInstance3D).mesh = m


func _process(delta: float) -> void:
	t += delta
	mat.set_shader_parameter("now", t)
	# chunks that have completely faded are removed
	while not chunks.is_empty() and chunks.size() > 1:
		var first: Array = chunks[0]
		var uv2s: PackedVector2Array = first[4]
		if uv2s.is_empty() or t - uv2s[uv2s.size() - 1].x < FADE:
			break
		(first[0] as MeshInstance3D).queue_free()
		chunks.pop_front()
	_sound(delta)
	scrape = 0.0                # the capsule sets it again next frame while it scrapes


## The screech of metal on ice: high-passed noise plus a wavering whistle
func _sound(_delta: float) -> void:
	if playback == null:
		return
	var n := playback.get_frames_available()
	if n <= 0:
		return
	var target := clampf(scrape, 0.0, 1.0)
	var buf := PackedVector2Array()
	buf.resize(n)
	if target <= 0.0 and _amp < 0.0005:
		_amp = 0.0
		playback.push_buffer(buf)            # silence (all zeros)
		return
	var step := 1.0 / float(n)
	for i in n:
		_amp = lerpf(_amp, target, 0.0015)
		var noise := randf() * 2.0 - 1.0
		_hp = noise - _prev + _hp * 0.6         # high-pass: hiss
		_prev = noise
		_lp = lerpf(_lp, _hp, 0.35)
		var f := (1500.0 + 900.0 * sin(t * 7.0 + i * step * 0.4) + 300.0 * randf()) * scrape_pitch
		_ph = fmod(_ph + TAU * f / RATE, TAU)
		var s := _lp * 0.55 + sin(_ph) * 0.12 * (0.6 + 0.4 * sin(t * 23.0))
		buf[i] = Vector2(s, s) * _amp
	playback.push_buffer(buf)


const SCRATCH_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float now = 0.0;
uniform float fade_time = 240.0;
varying float birth;
varying float press;

float h1(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float n1(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(h1(i), h1(i + 1.0), f); }

void vertex() {
	birth = UV2.x;
	press = COLOR.a;
}

void fragment() {
	float along = UV.x;
	float across = UV.y;
	// 5 fine hairlines across the groove, each wavering a little, broken in places
	float lines = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float off = 0.12 + fi * 0.19 + (n1(along * 2.3 + fi * 7.1) - 0.5) * 0.08;
		float w = 0.035 + 0.03 * h1(fi * 3.7);
		float line = 1.0 - smoothstep(w * 0.4, w, abs(across - off));
		float broken = smoothstep(0.25, 0.55, n1(along * (3.0 + fi) + fi * 13.0));
		lines = max(lines, line * mix(0.35, 1.0, broken) * (0.55 + 0.45 * h1(fi + 2.0)));
	}
	// the middle is ground deeper: a soft frosted band
	float groove = (1.0 - smoothstep(0.15, 0.5, abs(across - 0.5))) * 0.35;
	// tiny chips along the edges
	float chips = step(0.93, h1(floor(along * 40.0) + floor(across * 6.0) * 17.0)) * 0.6;
	float age = clamp((now - birth) / fade_time, 0.0, 1.0);
	float fade = 1.0 - smoothstep(0.35, 1.0, age);
	float a = clamp(max(lines, groove) + chips, 0.0, 1.0) * mix(0.55, 1.0, press) * fade;
	ALBEDO = vec3(0.9, 0.96, 1.0);
	ROUGHNESS = 0.45;
	SPECULAR = 0.7;
	// frost scatters light a bit even in the shade
	EMISSION = vec3(0.06, 0.08, 0.1) * a;
	ALPHA = a * 0.9;
}
"""
