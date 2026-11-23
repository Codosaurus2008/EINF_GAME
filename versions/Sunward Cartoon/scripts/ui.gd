class_name UI
extends RefCounted
## Helpers for the space-themed interface: panels, buttons, labels.

const BG := Color("#0b0d1f")
const PANEL := Color(0.08, 0.09, 0.2, 0.92)
const BORDER := Color("#4fd8ff")
const TEXT := Color("#e8ecff")
const SOFT := Color("#9aa3d6")
const CYAN := Color("#38d6ff")
const GOLD := Color("#ffc94a")
const PINK := Color("#ff5fa8")
const GREEN := Color("#4ff2a0")
const RED := Color("#ff5a6e")
const GREY := Color("#3a3f66")
const ORANGE := Color("#ff9a2e")

static var _theme: Theme
static var _bold: Font

## All text is a bit larger than the numbers in the code (and never tiny)
const TEXT_SCALE := 1.15
const MIN_TEXT := 15


static func fs(size: int) -> int:
	return maxi(MIN_TEXT, int(round(size * TEXT_SCALE)))


## Extra-bold font (for the power numbers)
static func bold_font() -> Font:
	if _bold == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI Black", "Arial Black", "Segoe UI", "Verdana"])
		f.font_weight = 900
		_bold = f
	return _bold


static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "Trebuchet MS", "Verdana", "Arial"])
		f.font_weight = 600
		_theme.default_font = f
		_theme.default_font_size = 20
	return _theme


static func font() -> Font:
	return theme().default_font


static func style(bg: Color, border := BORDER, radius := 10, border_w := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	sb.anti_aliasing = true
	return sb


static func panel(border := BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := style(PANEL, border, 12, 2)
	sb.shadow_color = Color(border, 0.25)
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)
	return p


static func button(text: String, color := CYAN, min_size := Vector2(160, 42), size := 17) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_button_color(b, color)
	b.add_theme_font_size_override("font_size", fs(size))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func set_button_color(b: Button, color: Color) -> void:
	var normal := style(Color(color, 0.18), color, 10, 2)
	var hover := style(Color(color, 0.35), color.lightened(0.2), 10, 2)
	var pressed := style(Color(color, 0.5), color, 10, 2)
	var disabled := style(Color(GREY, 0.3), GREY, 10, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", color.lightened(0.35))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("#5c6190"))


static func label(text: String, size := 17, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	return l


static func wrap_label(text: String, size := 15, color := SOFT, width := 300.0) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


## Big numbers: 1, 2, 4 ... 256
static func power_text(p: int) -> String:
	return "%d" % p


## A row of strength symbols (point at one to see its name and effect)
static func strength_row(ids: Array, icon_size := 24.0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	for id in ids:
		hb.add_child(strength_icon(id, icon_size))
	return hb


static func strength_icon(id: String, icon_size := 24.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(icon_size, icon_size)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var d: Dictionary = Game.STRENGTHS[id]
	c.tooltip_text = "%s: %s" % [d["name"], d["desc"]]
	c.draw.connect(func(): Art.draw_strength_icon(c, id, c.size / 2.0, c.size.x / 2.0 - 1.0))
	return c


## Symbol + name + explanation in one line
static func strength_line(id: String, icon_size := 26.0, width := 300.0) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.add_child(strength_icon(id, icon_size))
	var d: Dictionary = Game.STRENGTHS[id]
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.add_child(label(d["name"], 14, TEXT))
	vb.add_child(wrap_label(d["desc"], 12, SOFT, width))
	hb.add_child(vb)
	return hb


## Button that shows a drawn icon instead of a word (see Art.draw_icon). Hover shows `tip`.
static func icon_button(kind: String, tip: String, color := CYAN, min_size := Vector2(56, 42)) -> Button:
	var b := button("", color, min_size)
	b.tooltip_text = tip
	b.set_meta("icon", kind)
	b.set_meta("icon_color", color.lightened(0.35))
	var ic := Control.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.draw.connect(func():
		var col: Color = b.get_meta("icon_color")
		if b.disabled:
			col = Color("#5c6190")
		Art.draw_icon(ic, b.get_meta("icon"), ic.size / 2.0, minf(ic.size.x, ic.size.y) * 0.32, col))
	b.add_child(ic)
	return b


## Change the icon (and its colour) of an icon_button
static func set_icon(b: Button, kind: String, color: Color) -> void:
	b.set_meta("icon", kind)
	b.set_meta("icon_color", color.lightened(0.35))
	set_button_color(b, color)
	for c in b.get_children():
		(c as Control).queue_redraw()


## A drawn icon (see Art.draw_icon), e.g. "coin" or "gem"
static func icon(kind: String, icon_size := 22.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(icon_size, icon_size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): Art.draw_icon(c, kind, c.size / 2.0, c.size.x * 0.45, Color.WHITE))
	return c


## Coins and gems side by side (labels returned so they can be updated)
static func currency_row(icon_size := 22.0, text_size := 17) -> Array:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(icon("coin", icon_size))
	var cl := label("0", text_size, GOLD)
	hb.add_child(cl)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(10, 0)
	hb.add_child(gap)
	hb.add_child(icon("gem", icon_size))
	var gl := label("0", text_size, Color("#9ff3ff"))
	hb.add_child(gl)
	return [hb, cl, gl]
