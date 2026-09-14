extends Control

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")

@onready var _greeting: Label = $Safe/Scroll/VBox/Greeting
@onready var _title: Label = $Safe/Scroll/VBox/Title
@onready var _orders: PanelContainer = $Safe/Scroll/VBox/Orders
@onready var _orders_title: Label = $Safe/Scroll/VBox/Orders/Pad/Col/OrdersTitle
@onready var _orders_list: VBoxContainer = $Safe/Scroll/VBox/Orders/Pad/Col/OrdersList
@onready var _order: Button = $Safe/Scroll/VBox/OrderButton
@onready var _tip: Button = $Safe/Scroll/VBox/TipButton
@onready var _explore: Button = $Safe/Scroll/VBox/ExploreButton
@onready var _account: Button = $Safe/Scroll/VBox/AccountButton
@onready var _gear: Button = $Safe/Scroll/VBox/Footer/Gear
@onready var _settings: PanelContainer = $Settings
@onready var _url_edit: LineEdit = $Settings/Pad/VBox/Url
@onready var _mode_edit: OptionButton = $Settings/Pad/VBox/Mode
@onready var _name_edit: LineEdit = $Settings/Pad/VBox/PlayerName


func _ready() -> void:
	BakeryTheme.apply(self)
	_style_storefront()
	_gear.theme_type_variation = "SecondaryButton"
	_account.theme_type_variation = "SecondaryButton"
	$Settings/Pad/VBox/Close.theme_type_variation = "SecondaryButton"
	_order.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/order/order.tscn"))
	_tip.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/tip_ad/tip_ad.tscn"))
	_explore.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/explore/explore_3d.tscn"))
	_account.pressed.connect(_on_account)
	_gear.pressed.connect(_toggle_settings)
	$Settings/Pad/VBox/Save.pressed.connect(_save_settings)
	$Settings/Pad/VBox/Close.pressed.connect(func(): _settings.visible = false)
	_url_edit.text = AppConfig.order_base_url
	_name_edit.text = GameSave.player_name
	_mode_edit.clear()
	for mode in ["mock", "test", "live"]:
		_mode_edit.add_item(mode)
		if mode == AppConfig.ad_mode:
			_mode_edit.select(_mode_edit.item_count - 1)
	_settings.visible = false
	_refresh_account_ui()
	if AccountClient.is_logged_in():
		_refresh_square()


func _style_storefront() -> void:
	var photo := get_node_or_null("Storefront") as TextureRect
	if photo:
		photo.texture = load("res://assets/branding/storefront-hero.jpg")
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_greeting.add_theme_color_override("font_color", BakeryTheme.CREAM)
	_greeting.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color("ffe8dc"))
	_title.add_theme_font_size_override("font_size", 18)
	_orders.add_theme_stylebox_override("panel", BakeryTheme.card_style())
	_orders_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_orders_title.add_theme_font_size_override("font_size", 20)
	_order.custom_minimum_size = Vector2(0, 76)
	_order.add_theme_font_size_override("font_size", 22)
	_tip.theme_type_variation = "SecondaryButton"
	_explore.theme_type_variation = "SecondaryButton"
	for btn in [_tip, _explore]:
		btn.custom_minimum_size = Vector2(0, 58)
		btn.add_theme_font_size_override("font_size", 18)
	_settings.add_theme_stylebox_override("panel", BakeryTheme.card_style())


func _refresh_account_ui() -> void:
	var hello := AccountClient.hello_line()
	if hello != "":
		_greeting.text = hello
		_title.text = AppConfig.bakery_name + " · Irondale"
	else:
		_greeting.text = AppConfig.bakery_name
		_title.text = "Irondale, Alabama · guest"
	if AccountClient.is_logged_in():
		_account.text = "Log out"
	else:
		_account.text = "Sign in"
	_fill_orders()


func _fill_orders() -> void:
	for child in _orders_list.get_children():
		child.queue_free()
	var rows: Array = AccountClient.previous_orders()
	_orders.visible = AccountClient.is_logged_in()
	if not AccountClient.is_logged_in():
		return
	_orders_title.text = "Previous orders"
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "No Square orders on this phone yet."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", BakeryTheme.MUTED)
		_orders_list.add_child(empty)
		return
	for row in rows:
		if not row is Dictionary:
			continue
		_orders_list.add_child(_order_row(row))


func _order_row(row: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := Label.new()
	var name := str(row.get("name", "Order"))
	var date := _short_date(str(row.get("date", row.get("created_at", ""))))
	var total := int(row.get("total_cents", 0))
	title.text = "%s · %s · %s" % [name, date, OrderClient.money(total) if total > 0 else "—"]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", BakeryTheme.INK)
	box.add_child(title)
	var again := Button.new()
	again.text = "Order again"
	again.theme_type_variation = "SecondaryButton"
	var captured: Dictionary = row
	again.pressed.connect(func(): _order_again(captured))
	box.add_child(again)
	return box


func _short_date(raw: String) -> String:
	if raw.length() >= 10:
		return raw.substr(0, 10)
	return raw if raw != "" else "—"


func _order_again(row: Dictionary) -> void:
	var added := AccountClient.reorder(row)
	if added < 1:
		NoticeService.info("Open Order to pick those items again.")
	else:
		NoticeService.info("Added %d item(s) from that Square order." % added)
	get_tree().change_scene_to_file("res://scenes/order/order.tscn")


func _refresh_square() -> void:
	var result: Dictionary = await AccountClient.refresh()
	if result.get("ok", false):
		_refresh_account_ui()


func _on_account() -> void:
	AccountClient.logout()
	get_tree().change_scene_to_file("res://scenes/account/login.tscn")


func _toggle_settings() -> void:
	_settings.visible = not _settings.visible


func _save_settings() -> void:
	AppConfig.save_user_overrides({
		"order_base_url": _url_edit.text.strip_edges(),
		"ad_mode": _mode_edit.get_item_text(_mode_edit.selected),
	})
	GameSave.set_player_name(_name_edit.text)
	_settings.visible = false
	NoticeService.info("Saved on this device. Env vars still win if set.")
