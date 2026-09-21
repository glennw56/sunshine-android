extends Control

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const DonationLinkScript := preload("res://scripts/donate/donation_link.gd")

@onready var _card: PanelContainer = $Safe/Stack/Center/Card
@onready var _logo_frame: PanelContainer = $Safe/Stack/Center/Card/Pad/Col/LogoWrap/LogoFrame
@onready var _title: Label = $Safe/Stack/Center/Card/Pad/Col/Title
@onready var _pitch: Label = $Safe/Stack/Center/Card/Pad/Col/Pitch
@onready var _stats: Label = $Safe/Stack/Center/Card/Pad/Col/Stats
@onready var _bar: ProgressBar = $Safe/Stack/Center/Card/Pad/Col/BarWrap/Bar
@onready var _bar_amount: Label = $Safe/Stack/Center/Card/Pad/Col/BarWrap/BarAmount
@onready var _honesty: Label = $Safe/Stack/Center/Card/Pad/Col/Honesty
@onready var _supporters: Label = $Safe/Stack/Center/Card/Pad/Col/SupportersTitle
@onready var _donors: VBoxContainer = $Safe/Stack/Center/Card/Pad/Col/Donors
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
	_stats.text = "Loading dollars raised…"
	_bar_amount.text = ""
	_honesty.text = "Talking to bakery-drinks and Square…"
	_bar.value = 0
	_clear_donors("Loading supporters…")
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
	_stats.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	_bar_amount.add_theme_color_override("font_color", BakeryTheme.WINE)
	_bar_amount.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_honesty.add_theme_color_override("font_color", BakeryTheme.MUTED)
	_honesty.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_supporters.add_theme_color_override("font_color", BakeryTheme.WINE)
	_supporters.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
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
	_bar.custom_minimum_size = Vector2(0, 40)
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
	var count := int(row.get("donor_count", -1))
	var source := str(row.get("source", ""))
	var people: Array = []
	var raw_people: Variant = row.get("donors", [])
	if raw_people is Array:
		people = raw_people
	if raised < 0:
		raised = 0
	if goal <= 0:
		goal = DonationLinkScript.fallback_goal_cents()
	var ratio := 0.0
	if goal > 0:
		ratio = clampf(float(raised) / float(goal), 0.0, 1.0)
	_bar.value = ratio * 100.0
	_stats.text = DonationLinkScript.progress_label(raised, goal)
	_bar_amount.text = DonationLinkScript.bar_amount_label(raised, goal)
	if ratio >= 0.45:
		_bar_amount.add_theme_color_override("font_color", Color("fffaf3"))
	else:
		_bar_amount.add_theme_color_override("font_color", BakeryTheme.WINE)
	if source == "square-payments" or source.begins_with("square-payments"):
		_honesty.text = "Live totals from Square Payments on bakery-drinks."
	elif source == "square-public" or source == "square-public+payments":
		_honesty.text = "Goal and raised are from Sunshine’s Square donation page. Names appear when bakery-drinks /order/api/donations is live."
	elif source == "config":
		_honesty.text = "Square’s API did not publish a goal, so this uses the app default ($500 unless SUNSHINE_DONATE_GOAL_CENTS is set)."
	else:
		_honesty.text = "Could not reach live Square totals. Checkout still opens the bakery’s donation link."
	_render_donors(people, count, raised)


func _render_donors(people: Array, count: int, raised: int) -> void:
	_clear_donors("")
	if people.size() > 0:
		for row in people:
			if not row is Dictionary:
				continue
			var line := Label.new()
			var who := str(row.get("name", "")).strip_edges()
			if who == "":
				who = "Anonymous"
			var cents := int(row.get("amount_cents", 0))
			var when := str(row.get("at", ""))
			if when.length() >= 10:
				when = when.substr(0, 10)
			if cents > 0:
				line.text = "%s · %s" % [who, DonationLinkScript.money(cents)]
			else:
				line.text = who
			if when != "":
				line.text += " · " + when
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			line.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
			line.add_theme_color_override("font_color", BakeryTheme.INK)
			_donors.add_child(line)
		return
	var empty := Label.new()
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	empty.add_theme_color_override("font_color", BakeryTheme.MUTED)
	if count == 0 or raised == 0:
		empty.text = "No supporters yet — you can be the first."
	elif count < 0:
		empty.text = "Square has not published supporter names on this link yet."
	else:
		empty.text = "Supporters are loading."
	_donors.add_child(empty)


func _clear_donors(placeholder: String) -> void:
	for child in _donors.get_children():
		child.queue_free()
	if placeholder == "":
		return
	var line := Label.new()
	line.text = placeholder
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	line.add_theme_color_override("font_color", BakeryTheme.MUTED)
	_donors.add_child(line)


func _fetch_progress() -> void:
	var from_drinks: Dictionary = await _fetch_drinks_json()
	if bool(from_drinks.get("ok", false)) or int(from_drinks.get("raised_cents", -1)) >= 0:
		if is_inside_tree():
			_apply_progress(from_drinks)
		return
	var from_page: Dictionary = await _fetch_public_page()
	if is_inside_tree():
		_apply_progress(from_page)


func _fetch_drinks_json() -> Dictionary:
	for url in AppConfig.donations_api_fallbacks():
		var row := await _http_json(url)
		if row.is_empty():
			continue
		var parsed: Dictionary = DonationLinkScript.parse_donations_api(row)
		if bool(parsed.get("ok", false)) or int(parsed.get("raised_cents", -1)) >= 0:
			return parsed
	return {}


func _fetch_public_page() -> Dictionary:
	var text := await _http_text(DonationLinkScript.SQUARE_CHECKOUT_PAGE)
	if text == "":
		return DonationLinkScript.empty_progress()
	return DonationLinkScript.parse_bootstrap_html(text)


func _http_json(url: String) -> Dictionary:
	var text := await _http_text(url)
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _http_text(url: String) -> String:
	var http := HTTPRequest.new()
	http.timeout = 12.0
	http.use_threads = true
	add_child(http)
	var err := http.request(
		url,
		PackedStringArray([
			"Accept: application/json,text/html",
			"User-Agent: SunshineBakeryAndroid/0.1.76",
		])
	)
	if err != OK:
		http.queue_free()
		return ""
	var completed: Array = await http.request_completed
	http.queue_free()
	if int(completed[0]) != HTTPRequest.RESULT_SUCCESS:
		return ""
	var code := int(completed[1])
	if code < 200 or code >= 300:
		return ""
	return (completed[3] as PackedByteArray).get_string_from_utf8()


func _on_give() -> void:
	WebBridge.open(DonationLinkScript.checkout_url(_name.text))
