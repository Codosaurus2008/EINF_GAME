class_name CreatureLook
extends RefCounted
## The look of the eight peoples (elements): colours, skin, metals, and what each element
## builds on a creature. Also the shaders for skin, metal, glowing organs and eyes.
##
## Every element owns one style for each part of the body ("slots"): body frame and posture,
## legs, head, back, tail, arms. A hybrid takes different slots from different elements, and
## every element also "infuses" small features everywhere (see CreatureForge).

## frame: posture, body length, chest / waist / hip radius, hip height, squareness, lumps,
## tilt (degrees the spine points up), hunch.  legs / head / back / tail / arms: part styles.
## girth: how this element changes the body of a hybrid.  metal: [colour, patina, roughness].
const KITS := {
	"pebble": {"people": "Scrapper",
		"pal": {"body": Color("#8c7a66"), "belly": Color("#d2b98e"), "head": Color("#5d5852"), "limb": Color("#6f5846"), "armor": Color("#9a5434"), "horn": Color("#efe0be"), "fin": Color("#b8875a"), "accent": Color("#ffb347"), "dark": Color("#2a2420")},
		"skin": Color("#7d6c5a"), "second": Color("#b09a7c"), "mark": Color("#4a3c30"), "glow": Color("#ffb347"),
		"pattern": 7, "pattern_scale": 3.0, "rough": 0.92, "bumps": 0.55, "sheen": 0.0,
		"metal": [Color("#6b5040"), Color("#c0602a"), 0.6], "metal2": [Color("#b08d57"), Color("#4f8f6a"), 0.38],
		"frame": {"len": 1.15, "chest": 0.44, "waist": 0.31, "hip": 0.37, "hip_h": 0.58, "square": 0.45, "lumps": 0.22, "tilt": 12.0, "hunch": 0.22},
		"girth": 1.05, "legs": "stout4", "head": "scrap_jaw", "back": "scrap_stack", "tail": "club", "arms": "scrap_claw",
		"slot_love": {"arms": 3, "back": 2, "head": 1}},
	"glacia": {"people": "Frostling",
		"pal": {"body": Color("#2c5fb0"), "belly": Color("#5fe0d4"), "head": Color("#d4f2ff"), "limb": Color("#6650c0"), "armor": Color("#9fe8ff"), "horn": Color("#f2fdff"), "fin": Color("#8a7ae8"), "accent": Color("#6ff8ff"), "dark": Color("#1a1a4a")},
		"skin": Color("#a9d6ee"), "second": Color("#eef8ff"), "mark": Color("#4f8fd8"), "glow": Color("#6fe3ff"),
		"pattern": 8, "pattern_scale": 6.0, "rough": 0.25, "bumps": 0.1, "sheen": 0.25,
		"metal": [Color("#c9d4dc"), Color("#f4fbff"), 0.25], "metal2": [Color("#8fa6b8"), Color("#ffffff"), 0.3],
		"frame": {"len": 0.95, "chest": 0.3, "waist": 0.18, "hip": 0.24, "hip_h": 1.05, "square": 0.15, "lumps": 0.04, "tilt": 48.0, "hunch": 0.05},
		"girth": 0.9, "legs": "stilt2", "head": "crest", "back": "crystal_spines", "tail": "blade", "arms": "ice_scythe",
		"slot_love": {"back": 3, "head": 2, "tail": 2}},
	"mycelia": {"people": "Sporekin",
		"pal": {"body": Color("#7c3aa0"), "belly": Color("#f0b450"), "head": Color("#e2589c"), "limb": Color("#25a69c"), "armor": Color("#ff7ab8"), "horn": Color("#f6d27a"), "fin": Color("#9be05a"), "accent": Color("#a8ff6b"), "dark": Color("#2a1236")},
		"skin": Color("#6e3f80"), "second": Color("#ead2a8"), "mark": Color("#d27ae0"), "glow": Color("#7dffcf"),
		"pattern": 1, "pattern_scale": 5.0, "rough": 0.7, "bumps": 0.45, "sheen": 0.1,
		"metal": [Color("#8a5a3a"), Color("#4f9a78"), 0.45], "metal2": [Color("#a67c4a"), Color("#3f8a70"), 0.4],
		"frame": {"len": 1.15, "chest": 0.42, "waist": 0.38, "hip": 0.52, "hip_h": 0.36, "square": 0.0, "lumps": 0.35, "tilt": 6.0, "hunch": 0.12},
		"girth": 1.1, "legs": "roots", "head": "hood", "back": "mushroom_grove", "tail": "hyphae", "arms": "",
		"slot_love": {"back": 3, "head": 2, "tail": 1}},
	"aquora": {"people": "Tidefolk",
		"pal": {"body": Color("#1d62a8"), "belly": Color("#eef6f2"), "head": Color("#27a8a0"), "limb": Color("#2f8a62"), "armor": Color("#ff7a5a"), "horn": Color("#ffd0b8"), "fin": Color("#ff8a66"), "accent": Color("#ffd84a"), "dark": Color("#0a2440")},
		"skin": Color("#2c6f9e"), "second": Color("#d8f0ee"), "mark": Color("#0f3556"), "glow": Color("#7ff5ff"),
		"pattern": 4, "pattern_scale": 9.0, "rough": 0.3, "bumps": 0.05, "sheen": 0.7,
		"metal": [Color("#c9a35a"), Color("#3fa890"), 0.3], "metal2": [Color("#d8c8a0"), Color("#5fc0b0"), 0.25],
		"frame": {"len": 1.5, "chest": 0.32, "waist": 0.27, "hip": 0.2, "hip_h": 0.62, "square": 0.0, "lumps": 0.02, "tilt": 4.0, "hunch": 0.0},
		"girth": 0.95, "legs": "flipper4", "head": "angler", "back": "dorsal_fin", "tail": "fluke", "arms": "",
		"slot_love": {"tail": 3, "head": 2, "back": 1}},
	"verdis": {"people": "Thornback",
		"pal": {"body": Color("#3f8a2e"), "belly": Color("#c4d46a"), "head": Color("#215a2a"), "limb": Color("#74502c"), "armor": Color("#5c3a20"), "horn": Color("#a8321e"), "fin": Color("#93e04a"), "accent": Color("#ff5fa8"), "dark": Color("#18260e")},
		"skin": Color("#4c6a2c"), "second": Color("#a8b06a"), "mark": Color("#2a3814"), "glow": Color("#d6ff6b"),
		"pattern": 6, "pattern_scale": 5.0, "rough": 0.85, "bumps": 0.3, "sheen": 0.0,
		"metal": [Color("#9a6a3a"), Color("#4f8a5a"), 0.45], "metal2": [Color("#7a5a30"), Color("#6a9a50"), 0.5],
		"frame": {"len": 1.5, "chest": 0.3, "waist": 0.24, "hip": 0.31, "hip_h": 0.48, "square": 0.3, "lumps": 0.12, "tilt": 6.0, "hunch": 0.08},
		"girth": 0.92, "legs": "insect6", "head": "beak", "back": "thorn_ridge", "tail": "root_whip", "arms": "mantis",
		"slot_love": {"back": 2, "arms": 2, "tail": 1}},
	"ferrum": {"people": "Forgeborn",
		"pal": {"body": Color("#3d4250"), "belly": Color("#6a2c1c"), "head": Color("#b07a40"), "limb": Color("#b8643a"), "armor": Color("#2a2d36"), "horn": Color("#d2a050"), "fin": Color("#8a3a1a"), "accent": Color("#ffb347"), "dark": Color("#141418")},
		"skin": Color("#3b2d27"), "second": Color("#6a4c3c"), "mark": Color("#ff5a1a"), "glow": Color("#ff7a1a"),
		"pattern": 3, "pattern_scale": 3.5, "rough": 0.75, "bumps": 0.3, "sheen": 0.0,
		"metal": [Color("#4a4a52"), Color("#8a3a1a"), 0.35], "metal2": [Color("#b07a40"), Color("#3f7060"), 0.35],
		"frame": {"len": 0.8, "chest": 0.5, "waist": 0.42, "hip": 0.42, "hip_h": 0.72, "square": 0.55, "lumps": 0.1, "tilt": 66.0, "hunch": 0.0},
		"girth": 1.22, "legs": "pillar2", "head": "helm", "back": "chimneys", "tail": "cable", "arms": "piston",
		"slot_love": {"arms": 3, "back": 3, "head": 1}},
	"voltara": {"people": "Arcwing",
		"pal": {"body": Color("#262256"), "belly": Color("#7a54e8"), "head": Color("#151a40"), "limb": Color("#3a3478"), "armor": Color("#cf7a3e"), "horn": Color("#ffe066"), "fin": Color("#4a6ae8"), "accent": Color("#fff36b"), "dark": Color("#0c0c22")},
		"skin": Color("#2a2654"), "second": Color("#6b5fd8"), "mark": Color("#fff36b"), "glow": Color("#fff36b"),
		"pattern": 9, "pattern_scale": 4.0, "rough": 0.4, "bumps": 0.05, "sheen": 0.3,
		"metal": [Color("#c06a3a"), Color("#3fa8a0"), 0.3], "metal2": [Color("#d08a50"), Color("#4fb8b0"), 0.3],
		"frame": {"len": 1.1, "chest": 0.26, "waist": 0.15, "hip": 0.17, "hip_h": 1.05, "square": 0.0, "lumps": 0.0, "tilt": 14.0, "hunch": 0.0},
		"girth": 0.85, "legs": "talons", "head": "sleek", "back": "wings", "tail": "forked_coil", "arms": "",
		"slot_love": {"back": 4, "head": 1, "tail": 1}},
	"solara": {"people": "Lumen",
		"pal": {"body": Color("#e6ac3a"), "belly": Color("#fff2cc"), "head": Color("#fffaf0"), "limb": Color("#5e3e26"), "armor": Color("#fff8e6"), "horn": Color("#ffd24a"), "fin": Color("#ff9a3a"), "accent": Color("#ffffff"), "dark": Color("#3a2410")},
		"skin": Color("#efe2c4"), "second": Color("#fffaf0"), "mark": Color("#ffcf4a"), "glow": Color("#ffe9a0"),
		"pattern": 5, "pattern_scale": 4.0, "rough": 0.3, "bumps": 0.0, "sheen": 0.35,
		"metal": [Color("#e0b04a"), Color("#ffffff"), 0.22], "metal2": [Color("#f0d080"), Color("#ffffff"), 0.2],
		"frame": {"len": 0.95, "chest": 0.25, "waist": 0.13, "hip": 0.19, "hip_h": 0.85, "square": 0.2, "lumps": 0.0, "tilt": 78.0, "hunch": 0.0},
		"girth": 0.88, "legs": "petals", "head": "halo", "back": "orrery", "tail": "streamers", "arms": "",
		"slot_love": {"back": 2, "head": 3, "tail": 1}},
}

## Corona, the people of the Sun (final battle): fiery relatives of the Lumen
static func _sun_kit() -> Dictionary:
	var k: Dictionary = KITS["solara"].duplicate(true)
	k["people"] = "Corona"
	k["skin"] = Color("#ff8a2a")
	k["glow"] = Color("#ffd27a")
	k["pal"] = {"body": Color("#ff7a1a"), "belly": Color("#ffe08a"), "head": Color("#fff2c0"), "limb": Color("#8a2a0a"),
		"armor": Color("#ffd24a"), "horn": Color("#fff6d0"), "fin": Color("#ff4a1a"), "accent": Color("#ffffff"), "dark": Color("#4a1404")}
	return k


const UMBRA_SKIN := Color("#24123a")
const UMBRA_GLOW := Color("#ff2e4d")

static var _shaders := {}


static var _sun := {}


static func kit(id: String) -> Dictionary:
	if id == "sun":
		if _sun.is_empty():
			_sun = _sun_kit()
		return _sun
	return KITS.get(id, KITS["pebble"])


# ================================================================== shaders
const NOISE := """
float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 0.0)), h3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(h3(i + vec3(0.0, 0.0, 1.0)), h3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(h3(i + vec3(0.0, 1.0, 1.0)), h3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}
float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * n3(p); p *= 2.07; a *= 0.5; }
	return v;
}
// distance to the nearest cell border (cells, scales, facets, cracks)
vec2 cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(h3(i + g), h3(i + g + 17.3), h3(i + g + 41.1));
				float d = length(g + o - f);
				if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
			}
		}
	}
	return vec2(d1, d2 - d1);
}
"""

## Living tissue and armour. pattern: 1 glowing spots, 2 bands, 3 molten cracks, 4 scales,
## 5 crystal facets, 6 bark grooves, 7 mottled stone, 8 frost, 9 conductive circuit lines.
## The pattern colour (mark) can glow. sheen = pearl shimmer, rim = light around the edge,
## hit = white-red flash when damaged, dim = glow fading when defeated.
const SKIN_BODY := """
uniform vec4 base : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 second : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform vec4 mark : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform int pattern = 0;
uniform float pattern_scale = 4.0;
uniform float mark_glow = 0.0;
uniform float rough = 0.6;
uniform float metal = 0.0;
uniform float sheen = 0.0;
uniform float bumps = 0.3;
uniform float belly = 0.6;
uniform vec4 rim : source_color = vec4(0.4, 0.5, 0.7, 1.0);
uniform float rim_amount = 0.25;
uniform float alpha = 1.0;
uniform float hit = 0.0;
uniform float dim = 1.0;
uniform float pulse = 0.0;
uniform float gloss = 0.35;
uniform float mark_mix = 0.55;
varying vec3 lp;
varying vec3 ln;
""" + NOISE + """
void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}
// cel shading: a shadow side, a lit side and a bright band, plus a crisp highlight
void light() {
	float nd = dot(NORMAL, LIGHT);
	float band = 0.18 + smoothstep(-0.05, 0.05, nd) * 0.52 + smoothstep(0.55, 0.62, nd) * 0.3;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / 3.14159;
	vec3 hv = normalize(LIGHT + VIEW);
	float sp = pow(max(dot(NORMAL, hv), 0.0), 48.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * smoothstep(0.35, 0.45, sp) * gloss / 3.14159;
}
float pat(vec3 p, out float edge) {
	edge = 0.0;
	float s = pattern_scale;
	if (pattern == 1) { float d = cells(p * s).x; return 1.0 - smoothstep(0.18, 0.3, d); }
	if (pattern == 2) { return smoothstep(0.45, 0.55, fract(p.z * s + fbm(p * 3.0) * 0.6)); }
	if (pattern == 3) { vec2 c = cells(p * s); edge = 1.0 - smoothstep(0.0, 0.07, c.y); return edge; }
	if (pattern == 4) { vec2 c = cells(p * s); edge = 1.0 - smoothstep(0.0, 0.08, c.y); return c.x * 0.8; }
	if (pattern == 5) { vec2 c = cells(p * s); edge = 1.0 - smoothstep(0.0, 0.04, c.y); return edge * 0.6; }
	if (pattern == 6) { float g = fbm(vec3(p.x * s * 3.0, p.y * s * 3.0, p.z * s * 0.4)); edge = smoothstep(0.55, 0.7, g); return edge; }
	if (pattern == 7) { return smoothstep(0.4, 0.7, fbm(p * s)); }
	if (pattern == 8) { vec2 c = cells(p * s); edge = 1.0 - smoothstep(0.0, 0.05, c.y); return smoothstep(0.5, 0.9, fbm(p * s * 2.0)); }
	if (pattern == 9) {
		vec3 q = p * s;
		float l1 = 1.0 - smoothstep(0.0, 0.05, abs(fract(q.z + floor(q.x * 2.0) * 0.37) - 0.5));
		float l2 = 1.0 - smoothstep(0.0, 0.05, abs(fract(q.x * 2.0) - 0.5)) * step(0.5, fract(q.z * 0.5 + 0.25));
		edge = max(l1 * step(0.6, n3(floor(q * 2.0))), l2 * 0.0);
		return edge;
	}
	return 0.0;
}
void fragment() {
	float edge;
	float m = pat(lp, edge);
	// back to belly
	float b = smoothstep(0.1, -0.6, ln.y) * belly;
	vec3 col = mix(base.rgb, second.rgb, b);
	float grain = fbm(lp * 14.0);
	col *= 0.9 + 0.2 * grain;
	col = mix(col, mark.rgb, clamp(m, 0.0, 1.0) * (pattern == 3 || pattern == 9 ? 0.85 : mark_mix));
	if (pattern == 4 || pattern == 5 || pattern == 8) { col = mix(col, col * 0.55, edge * 0.7); }
	if (pattern == 6) { col = mix(col, col * 0.45, edge); }
	// small bumps / pores
	vec3 g = vec3(n3(lp * 22.0 + 1.3) - 0.5, n3(lp * 22.0 + 7.1) - 0.5, n3(lp * 22.0 + 3.7) - 0.5);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(g * bumps * 0.9, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	// pearl shimmer: colours shift with the viewing angle
	col += sheen * fres * (0.5 + 0.5 * cos(6.2831 * (fres * 1.5 + vec3(0.0, 0.33, 0.67)))) * 0.6;
	ALBEDO = mix(col, vec3(1.0, 0.35, 0.3), hit * 0.6);
	ROUGHNESS = clamp(rough * (0.8 + 0.4 * grain), 0.04, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.0;
	float glowk = (pattern == 3 || pattern == 9) ? edge : m;
	float pl = 1.0 + pulse * sin(TIME * 2.6 + lp.z * 4.0);
	EMISSION = glow.rgb * glowk * mark_glow * dim * pl + rim.rgb * fres * rim_amount + vec3(1.0, 0.4, 0.3) * hit * 0.8;
	ALPHA_PLACEHOLDER
}
"""

## Aged metal: brass, copper, bronze, iron, silver, gold. Patina in the hollows, scratches,
## polished edges.
const METAL := """
shader_type spatial;
uniform vec4 base : source_color = vec4(0.7, 0.55, 0.3, 1.0);
uniform vec4 patina : source_color = vec4(0.3, 0.6, 0.5, 1.0);
uniform float rough = 0.35;
uniform float patina_amount = 0.35;
uniform float hit = 0.0;
varying vec3 lp;
""" + NOISE + """
void vertex() { lp = VERTEX; }
void light() {
	float nd = dot(NORMAL, LIGHT);
	float band = 0.25 + smoothstep(-0.05, 0.05, nd) * 0.45 + smoothstep(0.5, 0.58, nd) * 0.3;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band / 3.14159;
	vec3 hv = normalize(LIGHT + VIEW);
	float sp = pow(max(dot(NORMAL, hv), 0.0), 30.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * (smoothstep(0.3, 0.4, sp) * 1.4 + sp * 0.4) / 3.14159;
}
void fragment() {
	float n = fbm(lp * 9.0);
	float p = smoothstep(0.55 - patina_amount * 0.3, 0.75, n) * patina_amount;
	float scratch = smoothstep(0.92, 1.0, n3(vec3(lp.x * 80.0, lp.y * 4.0, lp.z * 4.0)));
	vec3 col = mix(base.rgb * (0.85 + 0.3 * n), patina.rgb, p);
	col += scratch * 0.25;
	ALBEDO = mix(col, vec3(1.0, 0.4, 0.3), hit * 0.5);
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ROUGHNESS = clamp(mix(rough, 0.85, p) + (n - 0.5) * 0.2 - scratch * 0.2, 0.08, 1.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = base.rgb * fres * 0.25 + vec3(1.0, 0.4, 0.3) * hit * 0.6;
}
"""

## Glowing organs, lenses, energy: pulse and flicker (electric)
const GLOW := """
shader_type spatial;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float energy = 2.0;
uniform float pulse = 0.3;
uniform float speed = 2.0;
uniform float flicker = 0.0;
uniform float dim = 1.0;
uniform float boost = 0.0;
uniform float glass = 0.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hh(float x) { return fract(sin(x * 91.7) * 43758.5); }
void fragment() {
	float p = 1.0 + pulse * sin(TIME * speed + wp.x * 3.0 + wp.z * 2.0);
	float f = 1.0 - flicker * step(0.8, hh(floor(TIME * 18.0) + wp.y * 3.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = color.rgb * 0.25;
	ROUGHNESS = mix(0.4, 0.05, glass);
	SPECULAR = 0.5 + glass * 0.5;
	EMISSION = color.rgb * energy * p * f * dim * (1.0 + boost) * (0.75 + 0.5 * fres);
}
"""

## Eyes: the sphere's top pole faces outward. Dark glossy eye, glowing iris ring, slit pupil.
const EYE := """
shader_type spatial;
uniform vec4 iris : source_color = vec4(1.0, 0.7, 0.2, 1.0);
uniform vec4 sclera : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float slit = 0.4;
uniform float energy = 1.6;
uniform float blink = 0.0;
uniform float dim = 1.0;
void fragment() {
	float v = UV.y;
	float u = abs(fract(UV.x * 2.0) - 0.5);
	float ring = smoothstep(0.08, 0.1, v) * (1.0 - smoothstep(0.2, 0.26, v));
	float pupil = (1.0 - smoothstep(0.07, 0.09, v + (1.0 - u * 2.0) * slit * 0.06));
	vec3 col = mix(sclera.rgb, iris.rgb, ring);
	col = mix(col, vec3(0.0), pupil);
	ALBEDO = col * (1.0 - blink);
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	EMISSION = iris.rgb * ring * energy * dim * (1.0 - blink) * (0.7 + 0.3 * sin(TIME * 1.3));
}
"""


## Dark outline drawn around every solid part (inverted hull): crisp silhouettes
const OUTLINE := """
shader_type spatial;
render_mode unshaded, cull_front;
uniform vec4 color : source_color = vec4(0.05, 0.04, 0.08, 1.0);
uniform float width = 0.012;
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = color.rgb; }
"""


static func _shader(kind: String) -> Shader:
	if not _shaders.has(kind):
		var s := Shader.new()
		match kind:
			"skin":
				s.code = "shader_type spatial;\nrender_mode cull_back;\n" + SKIN_BODY.replace("ALPHA_PLACEHOLDER", "")
			"skin_clear":
				s.code = "shader_type spatial;\nrender_mode blend_mix, cull_back, depth_draw_always;\n" + SKIN_BODY.replace("ALPHA_PLACEHOLDER", "ALPHA = clamp(alpha + fres * 0.5 + m * 0.2, 0.0, 1.0);")
			"skin_2side":
				s.code = "shader_type spatial;\nrender_mode cull_disabled;\n" + SKIN_BODY.replace("ALPHA_PLACEHOLDER", "").replace("void fragment() {\n\tfloat edge;", "void fragment() {\n\tif (!FRONT_FACING) { NORMAL = -NORMAL; }\n\tfloat edge;")
			"membrane":
				s.code = "shader_type spatial;\nrender_mode blend_mix, cull_disabled, depth_draw_always;\n" + SKIN_BODY.replace("ALPHA_PLACEHOLDER", "ALPHA = clamp(alpha + fres * 0.3 + m * 0.3, 0.0, 1.0);").replace("void fragment() {\n\tfloat edge;", "void fragment() {\n\tif (!FRONT_FACING) { NORMAL = -NORMAL; }\n\tfloat edge;")
			"metal":
				s.code = METAL
			"glow":
				s.code = GLOW
			"eye":
				s.code = EYE
			"outline":
				s.code = OUTLINE
		_shaders[kind] = s
	return _shaders[kind]


static func mat(kind: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(kind)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


## The colour of a body region ("body", "belly", "head", "limb", "armor", "horn", "fin",
## "accent", "dark") in an element's palette
static func pal(e: String, role: String) -> Color:
	return Color(kit(e)["pal"].get(role, kit(e)["skin"]))


## Which element paints which body region of a creature (see CreatureForge)
static func design(els: Array, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + hash(str(els))
	var order := els.duplicate()
	if order.is_empty():
		order = ["pebble"]
	var dom: String = order[rng.randi() % order.size()]
	order.erase(dom)
	var accent: String = order[0] if order.size() > 0 else dom
	var third: String = order[1] if order.size() > 1 else accent
	var owner := {"head": dom, "back": dom, "tail": dom, "arms": dom}
	var free: Array = ["head", "back", "tail", "arms"]
	for e: String in order:
		var love: Dictionary = kit(e)["slot_love"]
		var best := ""
		var best_v := -1
		for sl: String in free:
			var v := int(love.get(sl, 0))
			if sl == "arms" and str(kit(e)["arms"]) == "":
				v = -1
			if v > best_v:
				best_v = v
				best = sl
		if best != "":
			owner[best] = e
			free.erase(best)
	if str(kit(owner["arms"])["arms"]) == "":
		for e2: String in els:
			if str(kit(e2)["arms"]) != "":
				owner["arms"] = e2
				break
	return {"els": els, "dom": dom, "accent": accent, "third": third, "owner": owner, "seed": seed_value}


## Colour of a region for this creature: each region is painted by a different element in hybrids
static func region(d: Dictionary, role: String, umbra := false) -> Color:
	var e: String = d["dom"]
	match role:
		"head": e = d["owner"]["head"]
		"limb": e = d["accent"]
		"armor": e = d["owner"]["back"]
		"horn": e = d["third"] if d["els"].size() >= 3 else d["owner"]["head"]
		"fin": e = d["owner"]["tail"]
		"accent": e = d["accent"]
	var c := pal(e, role)
	if umbra:
		c = c.lerp(UMBRA_SKIN, 0.55 if role != "accent" else 0.0)
		if role == "accent":
			c = UMBRA_GLOW
	return c


## A cel-shaded part material: base colour, lighter second colour (belly / underside),
## the pattern of `pattern_el` (hybrids mix patterns), outline in a dark shade
static func part(base: Color, second: Color, pattern_el: String, umbra: bool, rng: RandomNumberGenerator, kind := "skin", outline_w := 0.012) -> ShaderMaterial:
	var ak := kit(pattern_el)
	var glow_c: Color = ak["glow"]
	var mark_c: Color = Color(ak["pal"]["dark"]).lerp(base, 0.35)
	if int(ak["pattern"]) in [1, 3, 9]:
		mark_c = Color(ak["pal"]["accent"])
	base = Color.from_hsv(wrapf(base.h + rng.randf_range(-0.02, 0.02), 0.0, 1.0), clampf(base.s * rng.randf_range(0.9, 1.1), 0.0, 1.0), clampf(base.v * rng.randf_range(0.92, 1.06), 0.0, 1.0))
	if umbra:
		glow_c = UMBRA_GLOW
		mark_c = mark_c.lerp(UMBRA_SKIN, 0.5)
	var glowing := int(ak["pattern"]) in [1, 3, 9] or pattern_el in ["solara", "glacia"]
	var m := mat(kind, {"base": base, "second": second, "mark": mark_c, "glow": glow_c,
		"pattern": int(ak["pattern"]), "pattern_scale": float(ak["pattern_scale"]) * rng.randf_range(0.85, 1.2),
		"mark_glow": 1.4 if glowing else 0.0, "mark_mix": 0.45, "rough": float(ak["rough"]), "sheen": float(ak["sheen"]),
		"bumps": float(ak["bumps"]) * 0.6, "rim": Color(glow_c, 1.0).lerp(Color.WHITE, 0.4), "rim_amount": 0.22,
		"alpha": 0.55, "pulse": 0.25 if glowing else 0.0, "gloss": 0.6 if float(ak["rough"]) < 0.5 else 0.25})
	if kind == "skin" or kind == "skin_2side":
		m.next_pass = mat("outline", {"color": base.darkened(0.82), "width": outline_w})
	return m


## Skin of an element. pattern / mark / glow can come from another element (hybrids).
static func skin(main_id: String, accent_id: String, umbra: bool, rng: RandomNumberGenerator, kind := "skin") -> ShaderMaterial:
	var main := kit(main_id)
	var accent := kit(accent_id)
	var base: Color = main["skin"]
	var second: Color = main["second"]
	var mark_c: Color = accent["mark"]
	var glow_c: Color = accent["glow"]
	# every individual a little different
	base = Color.from_hsv(wrapf(base.h + rng.randf_range(-0.025, 0.025), 0.0, 1.0), clampf(base.s * rng.randf_range(0.85, 1.15), 0.0, 1.0), clampf(base.v * rng.randf_range(0.88, 1.1), 0.0, 1.0))
	if umbra:
		base = base.lerp(UMBRA_SKIN, 0.65)
		second = second.lerp(UMBRA_SKIN, 0.55)
		mark_c = mark_c.lerp(UMBRA_SKIN, 0.4)
		glow_c = UMBRA_GLOW
	var glowing := int(accent["pattern"]) in [1, 3, 9] or accent_id in ["solara", "glacia"]
	return mat(kind, {"base": base, "second": second, "mark": mark_c, "glow": glow_c,
		"pattern": int(accent["pattern"]), "pattern_scale": float(accent["pattern_scale"]) * rng.randf_range(0.85, 1.2),
		"mark_glow": 1.6 if glowing else 0.0, "rough": float(main["rough"]), "sheen": maxf(float(main["sheen"]), float(accent["sheen"]) * 0.7),
		"bumps": float(main["bumps"]), "rim": Color(glow_c, 1.0).lerp(Color.WHITE, 0.3), "rim_amount": 0.18,
		"alpha": 0.55, "pulse": 0.25 if glowing else 0.0})


static func metal(k: Dictionary, which := "metal", umbra := false) -> ShaderMaterial:
	var m: Array = k[which]
	var col: Color = m[0]
	if umbra:
		col = col.lerp(Color("#3a3040"), 0.5)
	var mm := mat("metal", {"base": col, "patina": m[1], "rough": float(m[2]), "patina_amount": 0.3})
	mm.next_pass = mat("outline", {"color": col.darkened(0.85), "width": 0.01})
	return mm


static func glow(col: Color, energy := 2.2, pulse := 0.3, flicker := 0.0, glass := 0.0) -> ShaderMaterial:
	return mat("glow", {"color": col, "energy": energy, "pulse": pulse, "speed": 2.0 + flicker * 4.0, "flicker": flicker, "glass": glass})


static func eye(col: Color, slit: float) -> ShaderMaterial:
	return mat("eye", {"iris": col, "slit": slit})
