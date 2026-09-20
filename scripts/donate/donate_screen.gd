extends Control

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const DonationLinkScript := preload("res://scripts/donate/donation_link.gd")

@onready var _card: PanelContainer = $Safe/Stack/Center/Card
@onready var _logo_frame: PanelContainer = $Safe/Stack/Center/Card/Pad/Col/LogoWrap/LogoFrame
@onready var _title: Label = $Safe/Stack/Center/Card/Pad/Col/Title
@onready var _pitch: Label = $Safe/Stack/Center/Card/Pad/Col/Pitch
@onready var _stats: Label = $Safe/Stack/Center/Card/Pad/Col/Stats
@onready var _bar: ProgressBar = $Safe/Stack/Center/Card/Pad/Col/Bar
@onready var _honesty: Label = $Safe/Stack/Center/Card/Pad/Col/Honesty
@onready var _name: LineEdit = $Safe/Stack/Center/Card/Pad/Col/Name
@onready var _give: Button = $Safe/Stack/Center/Card/Pad/Col/Give
@onready var _back: Button = $Safe/Stack/Header/Back


func _ready() -> void:
	BakeryTheme.apply(self)
	_style_sheet()
	_fit_card()
	resized.connect(_fit_card)
	_back.pressed.connect(func(): AppConfig.go("res://scenes/main_menu.tscn"))
	_give.pressed.connect(_on_give)
	_name.placeholder_text = "Name (optional)"
	_name.text = ""
	_apply_progress(DonationLinkScript.empty_progress())
	_fetch_progress()


func _fit_card() -> void:
	var max_w := maxf(300.0, size.x - 80.0)
	_card.custom_minimum_size.x = minf(560.0, max_w)


func _style_sheet() -> void:
	_card.add_theme_stylebox_override("panel", _sheet_style())
	_logo_frame.add_theme_stylebox_override("panel", _logo_style())
	_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_HERO)
	_pitch.add_theme_color_override("font_color", BakeryTheme.INK)
	_pitch.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_stats.add_theme_color_override("font_color", BakeryTheme.WINE)
	_stats.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_honesty.add_theme_color_override("font_color", BakeryTheme.MUTED)
	_honesty.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_name.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_name.custom_minimum_size = Vector2(0, 64)
	_back.theme_type_variation = "SecondaryButton"
	_back.custom_minimum_size = Vector2(120, 64)
	_back.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_give.custom_minimum_size = Vector2(0, 80)
	_give.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_style_bar()


func _style_bar() -> void:
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 28)
	var bg := StyleBoxFlat.new()
	bg.bg_color = BakeryTheme.CREAM_DEEP
	bg.border_color = BakeryTheme.BLUSH
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BakeryTheme.WINE
	fill.set_corner_radius_all(12)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)


func _sheet_style() -> StyleBoxFlat:
	var s := BakeryTheme.card_style()
	s.set_corner_radius_all(28)
	s.content_margin_left = 28
	s.content_margin_top = 28
	s.content_margin_right = 28
	s.content_margin_bottom = 28
	s.shadow_size = 22
	s.shadow_offset = Vector2(0, 10)
	s.border_color = Color(BakeryTheme.BLUSH, 0.9)
	s.set_border_width_all(2)
	return s


func _logo_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("fffaf3")
	s.border_color = BakeryTheme.BLUSH
	s.set_border_width_all(3)
	s.set_corner_radius_all(66)
	s.content_margin_left = 8
	s.content_margin_top = 8
	s.content_margin_right = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0.42, 0.18, 0.24, 0.12)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s


func _apply_progress(row: Dictionary) -> void:
	var goal := int(row.get("goal_cents", DonationLinkScript.fallback_goal_cents()))
	var raised := int(row.get("raised_cents", -1))
	var donors := int(row.get("donors", -1))
	var source := str(row.get("source", "placeholder"))
	var ratio := float(row.get("ratio", 0.0))
	if raised >= 0 and goal > 0:
		_bar.value = clampf(ratio, 0.0, 1.0) * 100.0
		_stats.text = "Raised %s of %s" % [DonationLinkScript.money(raised), DonationLinkScript.money(goal)]
		if donors >= 0:
			_stats.text += " · %d donor%s" % [donors, "" if donors == 1 else "s"]
	elif source == "square" or source == "square-goal":
		_bar.value = 0
		_stats.text = "Goal %s" % DonationLinkScript.money(goal)
		_honesty.text = "Square published this goal. A live raised total is not on the public donation page yet."
	else:
		_bar.value = 8
		_stats.text = "Goal %s" % DonationLinkScript.money(goal)
		_honesty.text = "Live Square totals are not in the app yet. This bar is a placeholder — checkout still opens the bakery’s donation link."
		return
	if source == "square" and raised >= 0:
		_honesty.text = "Progress from Sunshine’s public Square donation page."
	elif donors < 0 and raised >= 0:
		_honesty.text = "Raised total is from Square. Donor count is not published on this link."


func _fetch_progress() -> void:
	var http := HTTPRequest.new()
	http.timeout = 12.0
	http.use_threads = true
	add_child(http)
	var err := http.request(
		DonationLinkScript.SQUARE_URL,
		PackedStringArray(["Accept: text/html,application/json"])
	)
	if err != OK:
		http.queue_free()
		return
	var completed: Array = await http.request_completed
	http.queue_free()
	if not is_inside_tree():
		return
	if int(completed[0]) != HTTPRequest.RESULT_SUCCESS:
		return
	var text := (completed[3] as PackedByteArray).get_string_from_utf8()
	var row: Dictionary = DonationLinkScript.parse_bootstrap_html(text)
	if row.get("ok", false) or int(row.get("goal_cents", 0)) > 0:
		_apply_progress(row)


func _on_give() -> void:
	var url := DonationLinkScript.checkout_url(_name.text)
	WebBridge.open(url)
