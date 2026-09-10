extends Object
class_name BakeryTheme
## Sunshine's Bakery UI: blush pink, wine, cream. FOSS Nunito (OFL) when present.

const BLUSH := Color("e8b4b8")
const BLUSH_DEEP := Color("d4929a")
const WINE := Color("6b2d3c")
const WINE_DARK := Color("4a1c28")
const WINE_SOFT := Color("8a3d4e")
const CREAM := Color("fff6ea")
const CREAM_DEEP := Color("f3e0cc")
const INK := Color("3d1f24")
const MUTED := Color("7a4e4a")
const GOLD := Color("e0b04a")
const ORANGE := Color("e07a45")

const FONT_PATH := "res://assets/fonts/Nunito-Variable.ttf"


static func make() -> Theme:
	var t := Theme.new()
	var font := _font()
	var font_bold := _font_weight(700)
	if font:
		t.default_font = font
		t.set_font("font", "Button", font_bold if font_bold else font)
		t.set_font("font", "Label", font)
		t.set_font("font", "LineEdit", font)
		t.set_font("font", "OptionButton", font)
		t.set_font("font", "CheckBox", font)
		t.set_font("font", "PopupMenu", font)
	t.default_font_size = 16
	t.set_color("font_color", "Label", INK)
	_fill_button(t, "Button", WINE, WINE_SOFT, WINE_DARK, CREAM)
	t.set_type_variation("SecondaryButton", "Button")
	_fill_button(t, "SecondaryButton", CREAM, Color("ffe8dc"), BLUSH, WINE)
	t.set_type_variation("GoldButton", "Button")
	_fill_button(t, "GoldButton", GOLD, Color("f0c86a"), Color("c4922a"), WINE_DARK)
	t.set_stylebox("panel", "PanelContainer", card_style())
	t.set_stylebox("panel", "Panel", card_style())
	t.set_stylebox("normal", "LineEdit", _line_edit(false))
	t.set_stylebox("focus", "LineEdit", _line_edit(true))
	t.set_stylebox("read_only", "LineEdit", _line_edit(false))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", WINE)
	t.set_stylebox("normal", "OptionButton", _line_edit(false))
	t.set_stylebox("hover", "OptionButton", _line_edit(true))
	t.set_stylebox("pressed", "OptionButton", _line_edit(true))
	t.set_color("font_color", "OptionButton", INK)
	t.set_stylebox("normal", "TextEdit", _line_edit(false))
	t.set_color("font_color", "CheckBox", INK)
	return t


static func apply(root: Control) -> void:
	root.theme = make()


static func card_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("fffaf3")
	s.border_color = BLUSH
	s.set_border_width_all(2)
	s.set_corner_radius_all(18)
	s.content_margin_left = 14
	s.content_margin_top = 12
	s.content_margin_right = 14
	s.content_margin_bottom = 12
	s.shadow_color = Color(0.29, 0.17, 0.16, 0.12)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s


static func header_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.91, 0.706, 0.722, 0.92)
	s.set_corner_radius_all(20)
	s.content_margin_left = 12
	s.content_margin_top = 10
	s.content_margin_right = 12
	s.content_margin_bottom = 10
	return s


static func hud_plate() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.42, 0.18, 0.24, 0.72)
	s.border_color = BLUSH
	s.set_border_width_all(2)
	s.set_corner_radius_all(22)
	s.content_margin_left = 8
	s.content_margin_top = 8
	s.content_margin_right = 8
	s.content_margin_bottom = 8
	return s


static func _fill_button(t: Theme, typ: String, bg: Color, hover: Color, pressed: Color, font_col: Color) -> void:
	t.set_stylebox("normal", typ, _btn(bg, BLUSH_DEEP))
	t.set_stylebox("hover", typ, _btn(hover, GOLD))
	t.set_stylebox("pressed", typ, _btn(pressed, GOLD))
	t.set_stylebox("hover_pressed", typ, _btn(pressed, GOLD))
	t.set_stylebox("disabled", typ, _btn(Color(bg, 0.45), BLUSH))
	t.set_stylebox("focus", typ, _btn(bg, GOLD))
	t.set_color("font_color", typ, font_col)
	t.set_color("font_hover_color", typ, font_col)
	t.set_color("font_pressed_color", typ, CREAM if font_col != CREAM else CREAM)
	t.set_color("font_hover_pressed_color", typ, CREAM)
	t.set_color("font_focus_color", typ, font_col)
	t.set_color("font_disabled_color", typ, Color(font_col, 0.45))
	t.set_font_size("font_size", typ, 18)
	t.set_constant("h_separation", typ, 8)


static func _btn(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(18)
	s.content_margin_left = 16
	s.content_margin_top = 12
	s.content_margin_right = 16
	s.content_margin_bottom = 12
	s.shadow_color = Color(0.29, 0.17, 0.16, 0.18)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s


static func _line_edit(focus: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = CREAM
	s.border_color = GOLD if focus else WINE
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	s.content_margin_left = 12
	s.content_margin_top = 10
	s.content_margin_right = 12
	s.content_margin_bottom = 10
	return s


static func _font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		return null
	var res: Resource = load(FONT_PATH)
	if res is Font:
		return res as Font
	return null


static func _font_weight(weight: int) -> Font:
	var base := _font()
	if base == null:
		return null
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {0x77676874: weight} # 'wght'
	return fv
