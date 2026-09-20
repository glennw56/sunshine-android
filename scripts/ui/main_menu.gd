extends Control

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const StorefrontPhoto := preload("res://scripts/ui/storefront_photo.gd")

@onready var _greeting: Label = $Safe/VBox/Greeting
@onready var _title: Label = $Safe/VBox/Title
@onready var _orders: PanelContainer = $Safe/VBox/Orders
@onready var _order: Button = $Safe/VBox/OrderButton
@onready var _previous: Button = $Safe/VBox/PreviousOrdersButton
@onready var _donate: Button = $Safe/VBox/DonateButton
@onready var _tip: Button = $Safe/VBox/TipButton
@onready var _explore: Button = $Safe/VBox/ExploreButton
@onready var _customize: Button = $Safe/VBox/CustomizeButton
@onready var _account: Button = $Safe/VBox/AccountButton
@onready var _sheet: Control = $OrdersSheet
@onready var _sheet_title: Label = $OrdersSheet/Safe/Card/Pad/Col/Title
@onready var _sheet_hint: Label = $OrdersSheet/Safe/Card/Pad/Col/Hint
@onready var _sheet_list: VBoxContainer = $OrdersSheet/Safe/Card/Pad/Col/Scroll/List
@onready var _sheet_signin: Button = $OrdersSheet/Safe/Card/Pad/Col/SignIn
@onready var _sheet_close: Button = $OrdersSheet/Safe/Card/Pad/Col/Close


func _ready() -> void:
	BakeryTheme.hide_loading_cover(self)
	BakeryTheme.apply(self)
	_style_storefront()
	_account.theme_type_variation = "SecondaryButton"
	_order.pressed.connect(_open_order)
	_previous.pressed.connect(_on_previous_orders)
	_donate.pressed.connect(func(): AppConfig.go("res://scenes/donate/donate.tscn"))
	_tip.pressed.connect(func(): AppConfig.go("res://scenes/tip_ad/tip_ad.tscn"))
	_explore.pressed.connect(func(): AppConfig.go("res://scenes/explore/explore_3d.tscn"))
	if _customize:
		_customize.pressed.connect(_on_customize)
	_account.pressed.connect(_on_account)
	_sheet_close.pressed.connect(func(): _sheet.visible = false)
	_sheet_signin.pressed.connect(_on_account)
	$OrdersSheet/Dim.gui_input.connect(_on_sheet_dim)
	_sheet.visible = false
	_refresh_account_ui()
	AppConfig.warmup_ui_scenes()
	OrderClient.preload_menu()
	if AccountClient.is_logged_in():
		_refresh_square()


func _style_storefront() -> void:
	StorefrontPhoto.apply(get_node_or_null("Storefront") as TextureRect)
	_greeting.add_theme_color_override("font_color", BakeryTheme.CREAM)
	_greeting.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	_title.add_theme_color_override("font_color", Color("ffe8dc"))
	_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	if _orders:
		_orders.visible = false
	_order.custom_minimum_size = Vector2(0, 84)
	_order.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_donate.theme_type_variation = "SecondaryButton"
	_tip.theme_type_variation = "SecondaryButton"
	_explore.theme_type_variation = "SecondaryButton"
	_previous.theme_type_variation = "SecondaryButton"
	if _customize:
		_customize.theme_type_variation = "SecondaryButton"
	for btn in [_previous, _donate, _tip, _explore, _customize]:
		if btn == null:
			continue
		btn.custom_minimum_size = Vector2(0, 72)
		btn.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_account.custom_minimum_size = Vector2(0, 68)
	_account.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	$OrdersSheet/Safe/Card.add_theme_stylebox_override("panel", BakeryTheme.card_style())
	_sheet_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_sheet_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	_sheet_hint.add_theme_color_override("font_color", BakeryTheme.MUTED)
	_sheet_hint.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_sheet_close.theme_type_variation = "SecondaryButton"
	_sheet_close.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_sheet_close.custom_minimum_size = Vector2(0, 64)
	_sheet_signin.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_sheet_signin.custom_minimum_size = Vector2(0, 64)


func _on_sheet_dim(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_sheet.visible = false


func _open_order() -> void:
	if _order.disabled:
		return
	_order.disabled = true
	AppConfig.go("res://scenes/order/order.tscn")


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
		if _customize:
			_customize.text = "CUSTOMIZE LOOK"
			_customize.tooltip_text = "Saved forever on this Sunshine account"
	else:
		_account.text = "Sign in"
		if _customize:
			_customize.text = "CUSTOMIZE LOOK"
			_customize.tooltip_text = "Sign in to save your look forever"
	_previous.disabled = false
	_previous.tooltip_text = (
		"Your Square orders"
		if AccountClient.is_logged_in()
		else "Sign in with phone to see Square previous orders"
	)


func _on_previous_orders() -> void:
	_fill_orders_sheet()
	_sheet.visible = true
	if not AccountClient.is_logged_in():
		return
	if AccountClient.previous_orders().size() > 0:
		_refresh_previous_orders_quiet()
		return
	_sheet_hint.text = "Loading bakery-drinks tickets…"
	await AccountClient.ensure_previous_orders_retrieved()
	if is_inside_tree() and _sheet.visible:
		_fill_orders_sheet()


func _refresh_previous_orders_quiet() -> void:
	await AccountClient.ensure_previous_orders_retrieved()
	if is_inside_tree() and _sheet.visible:
		_fill_orders_sheet()


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
	_sheet_hint.text = "Paid Square tickets from bakery-drinks for this signed-in customer."
	for row in rows:
		if not row is Dictionary:
			continue
		_sheet_list.add_child(_order_row(row))


func _order_row(row: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var title := Label.new()
	var name := str(row.get("name", "Order"))
	var date := _short_date(str(row.get("date", row.get("created_at", ""))))
	var total := int(row.get("total_cents", 0))
	title.text = "%s · %s · %s" % [name, date, OrderClient.money(total) if total > 0 else "—"]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	title.add_theme_color_override("font_color", BakeryTheme.INK)
	box.add_child(title)
	for item in row.get("items", []):
		if not item is Dictionary:
			continue
		box.add_child(_item_row(item))
	var again := Button.new()
	again.text = "Order again"
	again.theme_type_variation = "SecondaryButton"
	again.custom_minimum_size = Vector2(0, 64)
	again.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	var captured: Dictionary = row
	again.pressed.connect(func(): await _order_again(captured))
	box.add_child(again)
	return box


func _item_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var slot := BakeryTheme.make_photo_slot(BakeryTheme.PHOTO_LINE)
	_bind_history_photo(slot, item)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", 4)
	var line := Label.new()
	var qty := str(item.get("qty", 1))
	var item_name := str(item.get("name", "Item"))
	var cents := int(item.get("price_cents", item.get("total_cents", 0)))
	if cents > 0:
		line.text = "%s × %s · %s" % [item_name, qty, OrderClient.money(cents)]
	else:
		line.text = "%s × %s" % [item_name, qty]
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	line.add_theme_color_override("font_color", BakeryTheme.INK)
	copy.add_child(line)
	var extras := OrderClient.visible_mod_line(item)
	if extras.strip_edges() != "":
		var mod_lbl := Label.new()
		mod_lbl.text = extras
		mod_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mod_lbl.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		mod_lbl.add_theme_color_override("font_color", BakeryTheme.WINE)
		copy.add_child(mod_lbl)
	row.add_child(slot)
	row.add_child(copy)
	return row


func _bind_history_photo(slot: Control, item: Dictionary) -> void:
	var img := BakeryTheme.photo_rect(slot)
	if img == null:
		return
	var placeholder := OrderClient.placeholder_photo(item)
	var url := OrderClient.history_item_photo_url(item)
	var hit := OrderClient.cached_photo(url)
	if hit:
		BakeryTheme.set_photo_loading(slot, false)
		img.texture = hit
		return
	if url.begins_with("http"):
		img.texture = null
		BakeryTheme.set_photo_loading(slot, true)
		_load_history_photo(slot, img, url)
		return
	BakeryTheme.set_photo_loading(slot, false)
	if url.begins_with("res://") and url != placeholder and ResourceLoader.exists(url):
		img.texture = load(url)
	elif ResourceLoader.exists(placeholder):
		img.texture = load(placeholder)


func _load_history_photo(slot: Control, img: TextureRect, url: String) -> void:
	var tex: Texture2D = await OrderClient.fetch_photo(url)
	if not is_instance_valid(img):
		return
	BakeryTheme.set_photo_loading(slot, false)
	if tex:
		img.texture = tex
	else:
		var fallback := "res://assets/generated/menu/no_photo.png"
		if ResourceLoader.exists(fallback):
			img.texture = load(fallback)


func _short_date(raw: String) -> String:
	if raw.length() >= 10:
		return raw.substr(0, 10)
	return raw if raw != "" else "—"


func _order_again(row: Dictionary) -> void:
	_sheet_hint.text = "Replacing your cart with available items…"
	var result: Dictionary = await AccountClient.reorder(row)
	_sheet.visible = false
	if not result.get("ok", false):
		NoticeService.info(str(result.get("error", "Could not check availability. Your cart was not changed.")))
		return
	NoticeService.info(str(result.get("message", "Cart replaced with available items from your previous order")))
	AppConfig.go("res://scenes/order/order.tscn")


func _refresh_square() -> void:
	var result: Dictionary = await AccountClient.refresh()
	if result.get("ok", false):
		_refresh_account_ui()


func _on_customize() -> void:
	if not ProfileStore.can_customize():
		NoticeService.info("Sign in with phone to save your look forever.")
		AppConfig.go("res://scenes/account/login.tscn")
		return
	AppConfig.go("res://scenes/explore/customize.tscn")


func _on_account() -> void:
	AccountClient.logout()
	AppConfig.go("res://scenes/account/login.tscn")
