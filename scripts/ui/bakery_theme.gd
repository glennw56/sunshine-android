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
## Large type throughout for older customers. Floor is SIZE_CAPTION — no leftover tiny UI.
const SIZE_CAPTION := 24
const SIZE_BODY := 26
const SIZE_BUTTON := 26
const SIZE_TITLE := 34
const SIZE_HERO := 44
const SIZE_TOAST := 28
const SIZE_TOAST_KIND := 24
## Order/menu browse photos fill ~75% of the card width.
## Previous Orders / cart / Status keep the older 96px square thumbs.
const PHOTO_WIDTH_RATIO := 0.75
const PHOTO_CARD_H := 480
const PHOTO_MENU := 120
const PHOTO_LINE := 96
const PHOTO_HERO_H := 520
const GRASS := Color("5a9e3a")
const DIRT := Color("8a5a32")
const SKY := Color("7ec4ee")


static func make() -> Theme:
	var t := Theme.new()
	var font := _font()
	var font_bold := _font_weight(800)
	if font:
		t.default_font = font
		t.set_font("font", "Button", font_bold if font_bold else font)
		t.set_font("font", "Label", font_bold if font_bold else font)
		t.set_font("font", "LineEdit", font)
		t.set_font("font", "OptionButton", font)
		t.set_font("font", "CheckBox", font)
		t.set_font("font", "PopupMenu", font)
	t.default_font_size = SIZE_BODY
	t.set_font_size("font_size", "Label", SIZE_BODY)
	t.set_font_size("font_size", "LineEdit", SIZE_BODY)
	t.set_font_size("font_size", "OptionButton", SIZE_BODY)
	t.set_font_size("font_size", "CheckBox", SIZE_BODY)
	t.set_font_size("font_size", "TextEdit", SIZE_BODY)
	t.set_color("font_color", "Label", INK)
	_fill_button(t, "Button", WINE, WINE_SOFT, WINE_DARK, CREAM, WINE_DARK)
	t.set_type_variation("SecondaryButton", "Button")
	_fill_button(t, "SecondaryButton", CREAM, Color("ffe8dc"), BLUSH, WINE, WINE)
	t.set_type_variation("GoldButton", "Button")
	_fill_button(t, "GoldButton", GOLD, Color("f0c86a"), Color("c4922a"), WINE_DARK, WINE_DARK)
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
	var s := block_panel(Color("fffaf3"), Color(BLUSH, 0.55), 1)
	s.set_corner_radius_all(22)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 6)
	s.shadow_color = Color(0.29, 0.16, 0.16, 0.16)
	s.content_margin_left = 20
	s.content_margin_top = 18
	s.content_margin_right = 20
	s.content_margin_bottom = 18
	return s


static func kiosk_row_style() -> StyleBoxFlat:
	var s := block_panel(Color("fffaf3"), Color(BLUSH, 0.7), 1)
	s.content_margin_left = 10
	s.content_margin_top = 12
	s.content_margin_right = 10
	s.content_margin_bottom = 12
	s.set_corner_radius_all(20)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	s.shadow_color = Color(0.29, 0.16, 0.16, 0.12)
	return s


static func kiosk_row_sold_out() -> StyleBoxFlat:
	var s := kiosk_row_style()
	s.bg_color = Color("efe6df")
	s.border_color = Color("c4b4ae")
	s.shadow_size = 0
	return s


static func kiosk_row_hover() -> StyleBoxFlat:
	var s := kiosk_row_style()
	s.bg_color = Color("ffe8dc")
	s.border_color = GOLD
	return s


static func sticky_bar() -> StyleBoxFlat:
	var s := block_panel(WINE_DARK, Color(0, 0, 0, 0), 0)
	s.content_margin_left = 20
	s.content_margin_top = 20
	s.content_margin_right = 20
	s.content_margin_bottom = 20
	s.set_corner_radius_all(24)
	s.shadow_size = 16
	s.shadow_offset = Vector2(0, -4)
	s.shadow_color = Color(0.18, 0.08, 0.1, 0.28)
	return s


static func chip_style(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = WINE if selected else Color("fffaf3")
	s.border_color = WINE if selected else Color("c9a4a8")
	s.set_border_width_all(2)
	s.set_corner_radius_all(26)
	s.content_margin_left = 20
	s.content_margin_top = 14
	s.content_margin_right = 20
	s.content_margin_bottom = 14
	return s


static func header_style() -> StyleBoxFlat:
	var s := block_panel(Color(0.91, 0.706, 0.722, 0.96), Color(WINE, 0.2), 1)
	s.set_corner_radius_all(18)
	s.content_margin_left = 16
	s.content_margin_top = 12
	s.content_margin_right = 16
	s.content_margin_bottom = 12
	return s


static func hud_plate() -> StyleBoxFlat:
	var s := block_panel(Color(0.42, 0.18, 0.24, 0.82), BLUSH, 2)
	s.set_corner_radius_all(14)
	s.content_margin_left = 12
	s.content_margin_top = 10
	s.content_margin_right = 12
	s.content_margin_bottom = 10
	return s


static func make_photo_banner(min_h: int = PHOTO_CARD_H) -> PanelContainer:
	## Wide clipped well for Order/menu browse. Child TextureRect is "Img".
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, min_h)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = Color("efe6df")
	s.border_color = Color(BLUSH, 0.9)
	s.set_border_width_all(2)
	s.set_corner_radius_all(18)
	s.content_margin_left = 0
	s.content_margin_top = 0
	s.content_margin_right = 0
	s.content_margin_bottom = 0
	frame.add_theme_stylebox_override("panel", s)
	var img := TextureRect.new()
	img.name = "Img"
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(img)
	return frame


static func make_photo_slot(px: int = PHOTO_LINE) -> PanelContainer:
	## Square clipped well for Previous Orders / cart / Status thumbs.
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(px, px)
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var s := StyleBoxFlat.new()
	s.bg_color = Color("efe6df")
	s.border_color = Color(BLUSH, 0.9)
	s.set_border_width_all(2)
	s.set_corner_radius_all(18)
	s.content_margin_left = 0
	s.content_margin_top = 0
	s.content_margin_right = 0
	s.content_margin_bottom = 0
	frame.add_theme_stylebox_override("panel", s)
	var img := TextureRect.new()
	img.name = "Img"
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(img)
	return frame


static func wrap_photo(slot: Control, ratio: float = PHOTO_WIDTH_RATIO) -> HBoxContainer:
	## Photo takes `ratio` of the row; equal gutters on each side.
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	var gutter := 0.5 * (1.0 - ratio)
	var left := Control.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = gutter
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_stretch_ratio = ratio
	var right := Control.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = gutter
	row.add_child(left)
	row.add_child(slot)
	row.add_child(right)
	return row


static func photo_rect(slot: Control) -> TextureRect:
	return slot.get_node("Img") as TextureRect


const LOADING_COVER_NAME := "MenuLoadingCover"


static func _cover_root(host: Node = null) -> Node:
	## Autoload so the overlay survives ORDER scene change (lawn → kiosk).
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var ac: Node = tree.root.get_node_or_null("AppConfig")
		if ac:
			return ac
		return tree.root
	return host


static func has_loading_cover(host: Node = null) -> bool:
	return _find_covers(host).size() > 0


static func hide_loading_cover(host: Node = null) -> void:
	## Must actually leave the tree this frame. A looping ProgressBar tween plus
	## Node.free() during process can leave the AppConfig overlay up forever.
	for cover in _find_covers(host):
		_strip_cover(cover)


static func _find_covers(host: Node = null) -> Array[Node]:
	var found: Array[Node] = []
	var seen := {}
	var tree := Engine.get_main_loop() as SceneTree
	var roots: Array = []
	if tree and tree.root:
		roots.append(tree.root)
	var cr := _cover_root(host)
	if cr:
		roots.append(cr)
	if host:
		roots.append(host)
	for root in roots:
		_gather_covers(root, found, seen)
	return found


static func _gather_covers(n: Node, found: Array[Node], seen: Dictionary) -> void:
	if n == null or seen.has(n):
		return
	seen[n] = true
	if str(n.name) == LOADING_COVER_NAME:
		found.append(n)
	for child in n.get_children():
		_gather_covers(child, found, seen)


static func _strip_cover(cover: Node) -> void:
	if cover == null or not is_instance_valid(cover):
		return
	cover.name = LOADING_COVER_NAME + "_gone"
	cover.process_mode = Node.PROCESS_MODE_DISABLED
	cover.set("visible", false)
	if cover.has_method("hide"):
		cover.call("hide")
	var parent: Node = cover.get_parent()
	if parent:
		parent.remove_child(cover)
	cover.queue_free()


static func show_loading_cover(host: Node, title: String = "Loading menu…", subtitle: String = "Fetching Square items for Sunshine's Bakery.") -> CanvasLayer:
	## Full-screen blush/wine cover so ORDER tap is never a blank freeze.
	var root := _cover_root(host)
	if root == null:
		return null
	hide_loading_cover(host)
	var layer := CanvasLayer.new()
	layer.name = LOADING_COVER_NAME
	layer.layer = 80
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.color = Color("e8b4b8")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 280)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("fffaf3")
	cs.border_color = WINE
	cs.set_border_width_all(3)
	cs.set_corner_radius_all(24)
	cs.content_margin_left = 28
	cs.content_margin_top = 28
	cs.content_margin_right = 28
	cs.content_margin_bottom = 28
	cs.shadow_size = 16
	cs.shadow_color = Color(0.29, 0.11, 0.16, 0.22)
	card.add_theme_stylebox_override("panel", cs)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	var h := Label.new()
	h.text = title
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_theme_font_size_override("font_size", SIZE_TITLE)
	h.add_theme_color_override("font_color", WINE)
	col.add_child(h)
	var p := Label.new()
	p.text = subtitle
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_theme_font_size_override("font_size", SIZE_BODY)
	p.add_theme_color_override("font_color", MUTED)
	col.add_child(p)
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = 50
	bar.show_percentage = false
	bar.indeterminate = true
	bar.custom_minimum_size = Vector2(0, 28)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = CREAM_DEEP
	bg.set_corner_radius_all(12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = WINE
	fill.set_corner_radius_all(12)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	col.add_child(bar)
	card.add_child(col)
	center.add_child(card)
	layer.add_child(dim)
	layer.add_child(center)
	root.add_child(layer)
	return layer


static func block_panel(bg: Color, border: Color, border_w: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(16)
	s.content_margin_left = 16
	s.content_margin_top = 14
	s.content_margin_right = 16
	s.content_margin_bottom = 14
	s.shadow_color = Color(0.29, 0.17, 0.16, 0.18)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	return s


static func _fill_button(t: Theme, typ: String, bg: Color, hover: Color, pressed: Color, font_col: Color, border: Color = BLUSH_DEEP) -> void:
	t.set_stylebox("normal", typ, _btn(bg, border))
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
	t.set_font_size("font_size", typ, SIZE_BUTTON)
	t.set_constant("h_separation", typ, 8)


static func _btn(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(22)
	s.content_margin_left = 22
	s.content_margin_top = 18
	s.content_margin_right = 22
	s.content_margin_bottom = 18
	s.shadow_color = Color(0.18, 0.08, 0.1, 0.22)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	return s


static func _line_edit(focus: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = CREAM
	s.border_color = GOLD if focus else Color(WINE, 0.45)
	s.set_border_width_all(2)
	s.set_corner_radius_all(14)
	s.content_margin_left = 16
	s.content_margin_top = 14
	s.content_margin_right = 16
	s.content_margin_bottom = 14
	return s


static func _font() -> Font:
	# Load the TTF directly so a missing .godot/imported/*.fontdata is not fatal.
	if FileAccess.file_exists(FONT_PATH):
		var ff := FontFile.new()
		if ff.load_dynamic_font(FONT_PATH) == OK:
			return ff
	if ResourceLoader.exists(FONT_PATH):
		var res: Resource = load(FONT_PATH)
		if res is Font:
			return res as Font
	return ThemeDB.fallback_font


static func _font_weight(weight: int) -> Font:
	var base := _font()
	if base == null:
		return null
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {0x77676874: weight} # 'wght'
	return fv
