extends Control
class_name LoyaltyTrack
## 0–200 Square point track. Free Fruit Tea sits at 100. $10 off the sale is the end.

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")

const MAX_POINTS := 200
const TEA_POINTS := 100

var points: int = 0
var show_fill := false

var _tea_num: Label
var _end_num: Label
var _tea: Label
var _reward: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 176)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tea_num = _marker("100", HORIZONTAL_ALIGNMENT_CENTER)
	_end_num = _marker("200", HORIZONTAL_ALIGNMENT_RIGHT)
	_tea = _caption("Free Fruit Tea", HORIZONTAL_ALIGNMENT_CENTER)
	_reward = _caption("$10.00 off the entire sale", HORIZONTAL_ALIGNMENT_RIGHT)
	resized.connect(_place)
	_place()


func set_balance(value: int, enrolled: bool) -> void:
	points = maxi(0, value)
	show_fill = enrolled
	var reached_tea := show_fill and points >= TEA_POINTS
	var reached_top := show_fill and points >= MAX_POINTS
	_tea_num.add_theme_color_override("font_color", BakeryTheme.WINE if reached_tea else BakeryTheme.MUTED)
	_tea.add_theme_color_override("font_color", BakeryTheme.WINE if reached_tea else BakeryTheme.INK)
	_end_num.add_theme_color_override("font_color", BakeryTheme.WINE if reached_top else BakeryTheme.MUTED)
	_reward.add_theme_color_override("font_color", BakeryTheme.WINE if reached_top else BakeryTheme.INK)
	queue_redraw()


func _marker(text: String, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	label.add_theme_color_override("font_color", BakeryTheme.MUTED)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _caption(text: String, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	label.add_theme_color_override("font_color", BakeryTheme.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _place() -> void:
	var width := size.x
	if width < 8.0:
		return
	var tea_x := width * float(TEA_POINTS) / float(MAX_POINTS)
	_tea_num.position = Vector2(tea_x - 36.0, 0)
	_tea_num.size = Vector2(72, 32)
	_end_num.position = Vector2(width - 88.0, 0)
	_end_num.size = Vector2(88, 32)
	var caption_w := minf(210.0, width * 0.46)
	var tea_left := clampf(tea_x - caption_w * 0.5, 0.0, maxf(0.0, width * 0.52 - caption_w))
	_tea.position = Vector2(tea_left, 96)
	_tea.size = Vector2(caption_w, 76)
	var reward_w := minf(230.0, width * 0.46)
	_reward.position = Vector2(width - reward_w, 96)
	_reward.size = Vector2(reward_w, 76)
	queue_redraw()


func _draw() -> void:
	var width := size.x
	if width < 8.0:
		return
	var bar_y := 36.0
	var bar_h := 40.0
	var track := StyleBoxFlat.new()
	track.bg_color = BakeryTheme.CREAM_DEEP
	track.border_color = BakeryTheme.BLUSH
	track.set_border_width_all(3)
	track.set_corner_radius_all(20)
	track.draw(get_canvas_item(), Rect2(0, bar_y, width, bar_h))
	var ratio := 0.0
	if show_fill:
		ratio = clampf(float(points) / float(MAX_POINTS), 0.0, 1.0)
	var inset := 5.0
	var fill_w := (width - inset * 2.0) * ratio
	if fill_w > 2.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = BakeryTheme.GOLD if points >= MAX_POINTS else BakeryTheme.WINE
		fill.set_corner_radius_all(int(minf(16.0, fill_w * 0.5)))
		fill.draw(get_canvas_item(), Rect2(inset, bar_y + inset, fill_w, bar_h - inset * 2.0))
	var tea_x := width * float(TEA_POINTS) / float(MAX_POINTS)
	var tick := StyleBoxFlat.new()
	tick.bg_color = BakeryTheme.GOLD
	tick.set_corner_radius_all(3)
	tick.draw(get_canvas_item(), Rect2(tea_x - 3.0, bar_y - 8.0, 6.0, bar_h + 16.0))
	var cap := StyleBoxFlat.new()
	cap.bg_color = BakeryTheme.GOLD if show_fill and points >= MAX_POINTS else BakeryTheme.BLUSH_DEEP
	cap.set_corner_radius_all(8)
	cap.draw(get_canvas_item(), Rect2(width - 16.0, bar_y + 8.0, 16.0, bar_h - 16.0))
