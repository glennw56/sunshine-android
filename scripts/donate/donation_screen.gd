extends Control
## In-app donate sheet. Payment is the existing Square donation link.

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const DonationLinkScript := preload("res://scripts/donate/donation_link.gd")
const WebBridgeScript := preload("res://scripts/platform/web_bridge.gd")

## --- Ronald: edit this boilerplate ---
const COPY_TITLE := "Help us grow Sunshine"
const COPY_BODY := "Sunshine’s Bakery is raising money for our new Trussville location. Your gift uses the same Square donation page we already share. Leave a name if you want, or stay anonymous."
const COPY_PLACEHOLDER := "Live Square total is not on this phone yet. Goal matches the Square donation page. Ronald can edit this copy."
## --- end edit ---

@onready var _card: PanelContainer = $Safe/Stack/Scroll/Center/Card
@onready var _logo_frame: PanelContainer = $Safe/Stack/Scroll/Center/Card/Pad/Col/LogoWrap/LogoFrame
@onready var _title: Label = $Safe/Stack/Scroll/Center/Card/Pad/Col/Title
@onready var _pitch: Label = $Safe/Stack/Scroll/Center/Card/Pad/Col/Pitch
@onready var _progress_lbl: Label = $Safe/Stack/Scroll/Center/Card/Pad/Col/ProgressLabel
@onready var _progress: ProgressBar = $Safe/Stack/Scroll/Center/Card/Pad/Col/Progress
@onready var _progress_note: Label = $Safe/Stack/Scroll/Center/Card/Pad/Col/ProgressNote
@onready var _name: LineEdit = $Safe/Stack/Scroll/Center/Card/Pad/Col/Name
@onready var _name_hint: Label = $Safe/Stack/Scroll/Center/Card/Pad/Col/NameHint
@onready var _donate: Button = $Safe/Stack/Scroll/Center/Card/Pad/Col/Donate
@onready var _back: Button = $Safe/Stack/Header/Back


func _ready() -> void:
	BakeryTheme.apply(self)
	_style_sheet()
	_fit_card()
	resized.connect(_fit_card)
	_back.pressed.connect(func(): AppConfig.go("res://scenes/main_menu.tscn"))
	_donate.pressed.connect(_on_donate)
	_name.text_submitted.connect(func(_t: String): _on_donate())
	_title.text = COPY_TITLE
	_pitch.text = COPY_BODY
	_name.placeholder_text = "Name optional"
	_name_hint.text = "Leave blank to stay anonymous."
	_prefill_name()
	_show_progress(false, 0, AppConfig.donate_goal_cents)
	_fetch_progress()


func _fit_card() -> void:
	var max_w := maxf(300.0, size.x - 80.0)
	_card.custom_minimum_size.x = minf(520.0, max_w)


func _style_sheet() -> void:
	_card.add_theme_stylebox_override("panel", _sheet_style())
	_logo_frame.add_theme_stylebox_override("panel", _logo_style())
	_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_HERO)
	_pitch.add_theme_color_override("font_color", BakeryTheme.INK)
	_pitch.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_pitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_lbl.add_theme_color_override("font_color", BakeryTheme.WINE)
	_progress_lbl.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	_progress_note.add_theme_color_override("font_color", BakeryTheme.MUTED)
	_progress_note.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_name_hint.add_theme_color_override("font_color", BakeryTheme.MUTED)
	_name_hint.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
	_name.custom_minimum_size = Vector2(0, 64)
	_name.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_back.theme_type_variation = "SecondaryButton"
	_back.custom_minimum_size = Vector2(120, 64)
	_back.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_donate.theme_type_variation = "GoldButton"
	_donate.custom_minimum_size = Vector2(0, 80)
	_donate.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_style_progress()


func _style_progress() -> void:
	_progress.custom_minimum_size = Vector2(0, 28)
	_progress.show_percentage = false
	_progress.min_value = 0.0
	_progress.max_value = 100.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(BakeryTheme.BLUSH, 0.55)
	track.set_corner_radius_all(14)
	track.content_margin_left = 2
	track.content_margin_top = 2
	track.content_margin_right = 2
	track.content_margin_bottom = 2
	var fill := StyleBoxFlat.new()
	fill.bg_color = BakeryTheme.WINE
	fill.set_corner_radius_all(12)
	_progress.add_theme_stylebox_override("background", track)
	_progress.add_theme_stylebox_override("fill", fill)


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


func _prefill_name() -> void:
	var saved := GameSave.last_donate_name.strip_edges()
	if saved != "":
		_name.text = saved
		return
	if AccountClient and AccountClient.is_logged_in():
		var hello := str(AccountClient.hello_line())
		if hello.begins_with("Hi, "):
			_name.text = hello.substr(4).strip_edges()


func _show_progress(live: bool, raised_cents: int, goal_cents: int) -> void:
	var goal := goal_cents if goal_cents > 0 else DonationLinkScript.DEFAULT_GOAL_CENTS
	var raised := maxi(0, raised_cents)
	_progress.max_value = 100.0
	_progress.value = DonationLinkScript.progress_ratio(raised, goal) * 100.0
	_progress_lbl.text = "%s raised of %s goal" % [
		DonationLinkScript.money(raised),
		DonationLinkScript.money(goal),
	]
	if live:
		_progress_note.text = "From the Square donation page."
	else:
		_progress_note.text = COPY_PLACEHOLDER


func _fetch_progress() -> void:
	var html := await _request_html(AppConfig.donate_url)
	if not is_inside_tree():
		return
	var parsed: Dictionary = DonationLinkScript.parse_square_html(html)
	if not parsed.get("ok", false):
		_show_progress(false, 0, AppConfig.donate_goal_cents)
		return
	_show_progress(true, int(parsed.get("raised_cents", 0)), int(parsed.get("goal_cents", AppConfig.donate_goal_cents)))


func _request_html(url: String, hops: int = 4) -> String:
	if url.strip_edges() == "":
		return ""
	var http := HTTPRequest.new()
	http.timeout = 10.0
	http.max_redirects = 8
	add_child(http)
	var err := http.request(
		url,
		PackedStringArray(["Accept: text/html", "User-Agent: SunshineBakery/0.1.64"])
	)
	if err != OK:
		http.queue_free()
		return ""
	var finished: Array = await http.request_completed
	http.queue_free()
	var code := int(finished[1]) if finished.size() > 1 else 0
	var headers: PackedStringArray = finished[2] if finished.size() > 2 else PackedStringArray()
	var body: PackedByteArray = finished[3] if finished.size() > 3 else PackedByteArray()
	var text := body.get_string_from_utf8()
	if code == 200 and text != "":
		return text
	## Godot does not follow Square's 303 from square.link → checkout.square.site.
	if code >= 300 and code < 400 and hops > 0:
		var location := DonationLinkScript.header_value(headers, "Location")
		if location != "":
			return await _request_html(location, hops - 1)
	return text


func _on_donate() -> void:
	var donor := _name.text.strip_edges()
	GameSave.set_last_donate_name(donor)
	var url := DonationLinkScript.checkout_url(AppConfig.donate_url, donor)
	WebBridgeScript.open(url)
