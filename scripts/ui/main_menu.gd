extends Control

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")

@onready var _greeting: Label = $Safe/VBox/Greeting
@onready var _title: Label = $Safe/VBox/Title
@onready var _orders: PanelContainer = $Safe/VBox/Orders
@onready var _order: Button = $Safe/VBox/OrderButton
@onready var _previous: Button = $Safe/VBox/PreviousOrdersButton
@onready var _tip: Button = $Safe/VBox/TipButton
@onready var _explore: Button = $Safe/VBox/ExploreButton
@onready var _account: Button = $Safe/VBox/AccountButton
@onready var _gear: Button = $Safe/VBox/Footer/Gear
@onready var _settings: PanelContainer = $Settings
@onready var _url_edit: LineEdit = $Settings/Pad/VBox/Url
@onready var _mode_edit: OptionButton = $Settings/Pad/VBox/Mode
@onready var _name_edit: LineEdit = $Settings/Pad/VBox/PlayerName
@onready var _sheet: Control = $OrdersSheet
@onready var _sheet_title: Label = $OrdersSheet/Safe/Card/Pad/Col/Title
@onready var _sheet_hint: Label = $OrdersSheet/Safe/Card/Pad/Col/Hint
@onready var _sheet_list: VBoxContainer = $OrdersSheet/Safe/Card/Pad/Col/Scroll/List
@onready var _sheet_signin: Button = $OrdersSheet/Safe/Card/Pad/Col/SignIn
@onready var _sheet_close: Button = $OrdersSheet/Safe/Card/Pad/Col/Close


func _ready() -> void:
	BakeryTheme.apply(self)
	_style_storefront()
	_gear.theme_type_variation = "SecondaryButton"
	_account.theme_type_variation = "SecondaryButton"
	$Settings/Pad/VBox/Close.theme_type_variation = "SecondaryButton"
	_order.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/order/order.tscn"))
	_previous.pressed.connect(_on_previous_orders)
	_tip.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/tip_ad/tip_ad.tscn"))
	_explore.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/explore/explore_3d.tscn"))
	_account.pressed.connect(_on_account)
	_gear.pressed.connect(_toggle_settings)
	$Settings/Pad/VBox/Save.pressed.connect(_save_settings)
	$Settings/Pad/VBox/Close.pressed.connect(func(): _settings.visible = false)
	_sheet_close.pressed.connect(func(): _sheet.visible = false)
	_sheet_signin.pressed.connect(_on_account)
	$OrdersSheet/Dim.gui_input.connect(_on_sheet_dim)
	_url_edit.text = AppConfig.order_base_url
	_name_edit.text = GameSave.player_name
	_mode_edit.clear()
	for mode in ["mock", "test", "live"]:
		_mode_edit.add_item(mode)
		if mode == AppConfig.ad_mode:
			_mode_edit.select(_mode_edit.item_count - 1)
	_settings.visible = false
	_sheet.visible = false
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
	if _orders:
		_orders.visible = false
	_order.custom_minimum_size = Vector2(0, 76)
	_order.add_theme_font_size_override("font_size", 22)
	_tip.theme_type_variation = "SecondaryButton"
	_explore.theme_type_variation = "SecondaryButton"
	_previous.theme_type_variation = "SecondaryButton"
	for btn in [_previous, _tip, _explore]:
		btn.custom_minimum_size = Vector2(0, 58)
		btn.add_theme_font_size_override("font_size", 18)
	_settings.add_theme_stylebox_override("panel", BakeryTheme.card_style())
	$OrdersSheet/Safe/Card.add_theme_stylebox_override("panel", BakeryTheme.card_style())
	_sheet_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_sheet_title.add_theme_font_size_override("font_size", 26)
	_sheet_hint.add_theme_color_override("font_color", BakeryTheme.MUTED)
	_sheet_close.theme_type_variation = "SecondaryButton"


func _on_sheet_dim(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_sheet.visible = false


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
	_previous.disabled = false
	_previous.tooltip_text = (
		"Your Square orders"
		if AccountClient.is_logged_in()
		else "Sign in with phone to see Square previous orders"
	)


func _on_previous_orders() -> void:
	_fill_orders_sheet()
	_sheet.visible = true


func _fill_orders_sheet() -> void:
	for child in _sheet_list.get_children():
		child.queue_free()
	_sheet_title.text = "Previous orders"
	if not AccountClient.is_logged_in():
		_sheet_hint.text = "Sign in with phone to see your Square previous orders."
		_sheet_signin.visible = true
		_sheet_signin.text = "Sign in with phone"
		return
	_sheet_signin.visible = false
	var rows: Array = AccountClient.previous_orders()
	if rows.is_empty():
		_sheet_hint.text = "No Square orders on this phone yet."
		return
	_sheet_hint.text = "Square tickets for this signed-in customer."
	for row in rows:
		if not row is Dictionary:
			continue
		_sheet_list.add_child(_order_row(row))


func _order_row(row: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var title := Label.new()
	var name := str(row.get("name", "Order"))
	var date := _short_date(str(row.get("date", row.get("created_at", ""))))
	var total := int(row.get("total_cents", 0))
	title.text = "%s · %s · %s" % [name, date, OrderClient.money(total) if total > 0 else "—"]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", BakeryTheme.INK)
	box.add_child(title)
	for item in row.get("items", []):
		if not item is Dictionary:
			continue
		var line := Label.new()
		line.text = "· %s × %s" % [str(item.get("name", "Item")), str(item.get("qty", 1))]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 15)
		line.add_theme_color_override("font_color", BakeryTheme.INK)
		box.add_child(line)
		var mods := OrderClient.order_item_mod_summary(item)
		if mods != "":
			var mod_lbl := Label.new()
			mod_lbl.text = mods
			mod_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			mod_lbl.add_theme_font_size_override("font_size", 14)
			mod_lbl.add_theme_color_override("font_color", BakeryTheme.MUTED)
			box.add_child(mod_lbl)
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
	_sheet.visible = false
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
