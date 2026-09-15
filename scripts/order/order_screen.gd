extends Control
## Native order UI backed by the live bakery-drinks Square catalog.
## WebView/browser is used for Square hosted checkout; catalog itself is HTTP.

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")

enum Tab { MENU, CART, STATUS }

var _tab: Tab = Tab.MENU
var _status: Dictionary = {}
var _my_status: Dictionary = {}
var _poll: Timer
var _detail_drink: Dictionary = {}
var _detail_mods: Dictionary = {}
var _detail_qty: int = 1
var _photo_fallback: Texture2D
var _cart_edit_idx: int = -1
var _focus_custom_tip: bool = false
var _cart_drinks_lbl: Label
var _cart_tip_lbl: Label
var _cart_total_lbl: Label
var _menu_sections: Dictionary = {}
var _menu_groups: Dictionary = {}
var _menu_order: Array = []
var _menu_titles: Dictionary = {}
var _drawn_fp: String = ""

@onready var _header: Label = $Safe/VBox/Header/Title
@onready var _back: Button = $Safe/VBox/Header/Back
@onready var _web: Button = $Safe/VBox/Header/Web
@onready var _tabs: HBoxContainer = $Safe/VBox/Tabs
@onready var _jumps: HBoxContainer = $Safe/VBox/Jumps/Row
@onready var _body: ScrollContainer = $Safe/VBox/Body
@onready var _content: VBoxContainer = $Safe/VBox/Body/Content
@onready var _cart_bar: PanelContainer = $Safe/VBox/CartBar
@onready var _cart_summary: Label = $Safe/VBox/CartBar/Row/CartSummary
@onready var _clear_cart: Button = $Safe/VBox/CartBar/Row/ClearCart
@onready var _cta: Button = $Safe/VBox/CartBar/Row/Cta
@onready var _busy: Label = $Safe/VBox/Busy


func _ready() -> void:
	BakeryTheme.apply(self)
	_back.theme_type_variation = "SecondaryButton"
	_web.theme_type_variation = "SecondaryButton"
	_photo_fallback = load("res://assets/generated/menu/no_photo.png")
	_back.pressed.connect(func(): AppConfig.go("res://scenes/main_menu.tscn"))
	_web.pressed.connect(func(): WebBridge.open_order())
	_cta.pressed.connect(_on_cta)
	_clear_cart.pressed.connect(_on_clear_cart)
	AccountClient.apply_to_cart()
	_make_tabs()
	_poll = Timer.new()
	_poll.wait_time = 4.0
	_poll.timeout.connect(_poll_status)
	add_child(_poll)
	_cart_bar.add_theme_stylebox_override("panel", BakeryTheme.sticky_bar())
	_cart_summary.add_theme_color_override("font_color", BakeryTheme.CREAM)
	_cart_summary.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_clear_cart.theme_type_variation = "SecondaryButton"
	_clear_cart.custom_minimum_size = Vector2(160, 76)
	_clear_cart.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_cta.theme_type_variation = "GoldButton"
	_cta.custom_minimum_size = Vector2(210, 76)
	_cta.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_header.add_theme_font_size_override("font_size", BakeryTheme.SIZE_HERO)
	_header.add_theme_color_override("font_color", BakeryTheme.WINE)
	_body.scroll_deadzone = 12
	_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_set_busy("")
	OrderClient.menu_loaded.connect(_on_menu_loaded)
	if OrderClient.has_menu():
		if bool(OrderClient.cart.get("focus_cart", false)) and OrderClient.cart_count() > 0:
			OrderClient.cart["focus_cart"] = false
			_tab = Tab.CART
		_render()
		OrderClient.preload_menu()
		if GameSave.active_order_id != "":
			_poll.start()
		return
	_set_busy("Loading Square menu…")
	var result := await OrderClient.fetch_menu()
	_set_busy("")
	if not result.get("ok", false):
		_set_busy(str(result.get("error", "Square catalog unavailable.")))
	if bool(OrderClient.cart.get("focus_cart", false)) and OrderClient.cart_count() > 0:
		OrderClient.cart["focus_cart"] = false
		_tab = Tab.CART
	_render()
	if GameSave.active_order_id != "":
		_poll.start()


func _exit_tree() -> void:
	if OrderClient.menu_loaded.is_connected(_on_menu_loaded):
		OrderClient.menu_loaded.disconnect(_on_menu_loaded)


func _on_menu_loaded(_payload: Dictionary) -> void:
	if not is_inside_tree():
		return
	if OrderClient.has_menu():
		_set_busy("")
	if not _detail_drink.is_empty():
		return
	if _tab == Tab.MENU and _drawn_fp != "" and _drawn_fp == OrderClient.menu_fingerprint():
		return
	_render()


func _make_tabs() -> void:
	for child in _tabs.get_children():
		child.queue_free()
	var labels := ["Menu", "Cart", "Status"]
	for i in labels.size():
		var btn := Button.new()
		btn.text = labels[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		var idx := i
		btn.pressed.connect(func(): _set_tab(idx))
		btn.custom_minimum_size = Vector2(0, 64)
		_tabs.add_child(btn)


func _set_tab(idx: int) -> void:
	_detail_drink = {}
	_cart_edit_idx = -1
	_tab = idx as Tab
	if _tab == Tab.STATUS:
		_poll.start()
		_poll_status()
	else:
		if GameSave.active_order_id == "":
			_poll.stop()
	_render()


func _render() -> void:
	var hello := AccountClient.hello_line()
	_header.text = hello if hello != "" else "Order"
	for i in _tabs.get_child_count():
		var btn := _tabs.get_child(i) as Button
		if btn:
			btn.button_pressed = i == int(_tab)
			_style_tab(btn, i == int(_tab))
	for child in _content.get_children():
		child.queue_free()
	var jumps_wrap := get_node_or_null("Safe/VBox/Jumps") as Control
	if jumps_wrap:
		jumps_wrap.visible = _tab == Tab.MENU and _detail_drink.is_empty()
	if not _detail_drink.is_empty():
		_render_detail()
		_refresh_cart_bar()
		return
	match _tab:
		Tab.MENU:
			_render_menu()
		Tab.CART:
			_render_cart()
		Tab.STATUS:
			_render_status()
	_refresh_cart_bar()


func _add_label(text: String, size: int = BakeryTheme.SIZE_BODY, color: Color = Color("4a2c2a")) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_content.add_child(l)
	return l


func _set_busy(text: String) -> void:
	_busy.text = text
	_busy.visible = text.strip_edges() != ""
	if text.strip_edges() != "":
		_busy.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
		_busy.add_theme_color_override("font_color", BakeryTheme.WINE)


func _style_tab(btn: Button, selected: bool) -> void:
	btn.theme_type_variation = "" if selected else "SecondaryButton"
	btn.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)


func _section_label(cat: String, text: String) -> Label:
	var l := Label.new()
	l.name = "Section_%s" % cat
	l.text = text
	l.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	l.add_theme_color_override("font_color", BakeryTheme.WINE)
	_content.add_child(l)
	_menu_sections[cat] = l
	return l


func _group_catalog() -> void:
	_menu_titles = {
		"pastry": "Pastries",
		"bread": "Bread",
		"savory": "Savory",
		"coffee": "Coffee",
		"tea": "Tea",
		"more": "More",
	}
	_menu_order = ["pastry", "bread", "savory", "coffee", "tea", "more"]
	_menu_groups = {}
	for key in _menu_order:
		_menu_groups[key] = []
	for drink in OrderClient.drinks():
		if not drink is Dictionary:
			continue
		var cat := str(drink.get("category", "more")).to_lower()
		if cat == "pastries" or cat == "sweet":
			cat = "pastry"
		if not _menu_groups.has(cat):
			_menu_groups[cat] = []
			if not _menu_order.has(cat):
				_menu_order.append(cat)
		_menu_groups[cat].append(drink)


func _render_jumps() -> void:
	if not is_instance_valid(_jumps):
		return
	for child in _jumps.get_children():
		child.queue_free()
	for cat in _menu_order:
		var list: Array = _menu_groups.get(cat, [])
		if list.is_empty():
			continue
		var title := str(_menu_titles.get(cat, cat.capitalize()))
		var chip := _mod_chip(title, false, func(): _jump_to_section(cat))
		chip.toggle_mode = false
		_jumps.add_child(chip)


func _jump_to_section(cat: String) -> void:
	var node: Variant = _menu_sections.get(cat, null)
	if node is Control:
		_body.ensure_control_visible(node as Control)
		_body.scroll_vertical = maxi(0, int((node as Control).position.y) - 8)


func _render_menu() -> void:
	_menu_sections.clear()
	if OrderClient.drinks().is_empty():
		_add_label("Square menu is unavailable.", BakeryTheme.SIZE_TITLE, BakeryTheme.WINE)
		_add_label("Offers come from Square only. Check the network and retry — we will not invent a menu.", BakeryTheme.SIZE_BODY, BakeryTheme.MUTED)
		var retry := Button.new()
		retry.text = "Retry Square"
		retry.custom_minimum_size = Vector2(0, 64)
		retry.pressed.connect(_retry_square_menu)
		_content.add_child(retry)
		_cta.text = "Open web order"
		_refresh_cart_bar()
		return
	_group_catalog()
	_render_jumps()
	_drawn_fp = OrderClient.menu_fingerprint()
	for cat in _menu_order:
		var list: Array = _menu_groups.get(cat, [])
		if list.is_empty():
			continue
		_section_label(cat, str(_menu_titles.get(cat, cat.capitalize())))
		for drink in list:
			_content.add_child(_drink_row(drink))
	_refresh_cart_bar()
	var n := OrderClient.cart_count()
	_cta.text = "Checkout" if n > 0 else "Review"


func _swatch_color(cat: String) -> Color:
	match cat:
		"coffee":
			return BakeryTheme.WINE
		"tea":
			return BakeryTheme.BLUSH
		"pastry":
			return BakeryTheme.GOLD
		"bread":
			return Color("c4922a")
		"savory":
			return Color("8a3d4e")
		_:
			return BakeryTheme.GOLD


func _drink_row(drink: Dictionary) -> PanelContainer:
	var sold := OrderClient.is_sold_out(drink)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BakeryTheme.kiosk_row_sold_out() if sold else BakeryTheme.kiosk_row_style())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_ARROW if sold else Control.CURSOR_POINTING_HAND
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	col.add_child(_photo_banner(drink, sold))
	var name := Label.new()
	name.text = str(drink.get("name", "Item"))
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	name.add_theme_color_override("font_color", Color("7a6a66") if sold else BakeryTheme.INK)
	col.add_child(name)
	var extras := OrderClient.available_mod_preview(drink)
	if extras != "":
		var preview := Label.new()
		preview.text = "Extras: %s" % extras
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		preview.add_theme_color_override("font_color", Color("9a8884") if sold else BakeryTheme.WINE)
		col.add_child(preview)
	if sold:
		var badge := Label.new()
		badge.text = "Sold out"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
		badge.add_theme_color_override("font_color", BakeryTheme.WINE)
		col.add_child(badge)
	var price := Label.new()
	price.text = OrderClient.display_price(drink)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	price.add_theme_color_override("font_color", Color("9a8884") if sold else BakeryTheme.MUTED)
	col.add_child(price)
	panel.add_child(col)
	panel.set_meta("press_pos", Vector2(-999, -999))
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				panel.set_meta("press_pos", ev.global_position)
			else:
				var start: Vector2 = panel.get_meta("press_pos", Vector2(-999, -999))
				if start.distance_to(ev.global_position) <= 28.0:
					_on_row_tapped(drink, sold)
		elif ev is InputEventScreenTouch:
			if ev.pressed:
				panel.set_meta("press_pos", ev.position)
			else:
				var start: Vector2 = panel.get_meta("press_pos", Vector2(-999, -999))
				if start.distance_to(ev.position) <= 28.0:
					_on_row_tapped(drink, sold)
	)
	return panel


func _on_row_tapped(drink: Dictionary, sold: bool) -> void:
	if sold:
		NoticeService.info("Sold out today.")
		return
	_cart_edit_idx = -1
	_open_detail(drink)


func _photo_banner(item: Dictionary, sold: bool, min_h: int = BakeryTheme.PHOTO_CARD_H) -> Control:
	var slot := BakeryTheme.make_photo_banner(min_h)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bind_photo(BakeryTheme.photo_rect(slot), item, sold)
	return BakeryTheme.wrap_photo_95(slot)


func _bind_photo(img: TextureRect, item: Dictionary, sold: bool) -> void:
	## Show the Square catalog photo when one exists. Neutral "no photo" only
	## as a last resort — never a cartoon croissant. Never block the list on HTTP.
	if _photo_fallback:
		img.texture = _photo_fallback
	if sold:
		img.modulate = Color(0.7, 0.7, 0.7, 1)
	var url := OrderClient.item_photo_url(item)
	var hit := OrderClient.cached_photo(url)
	if hit:
		img.texture = hit
		return
	if url.begins_with("http"):
		_load_photo(img, url)
	elif url.begins_with("res://") and ResourceLoader.exists(url):
		img.texture = load(url)


func _mod_chip(label: String, selected: bool, on_press: Callable, mark_selected: bool = true) -> Button:
	var pill := Button.new()
	pill.toggle_mode = true
	pill.button_pressed = selected
	pill.text = ("✓  " if selected and mark_selected else "") + label
	pill.clip_text = false
	pill.autowrap_mode = TextServer.AUTOWRAP_OFF
	pill.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.custom_minimum_size = Vector2(0, 64)
	pill.add_theme_stylebox_override("normal", BakeryTheme.chip_style(selected))
	pill.add_theme_stylebox_override("hover", BakeryTheme.chip_style(selected))
	pill.add_theme_stylebox_override("pressed", BakeryTheme.chip_style(true))
	pill.add_theme_stylebox_override("hover_pressed", BakeryTheme.chip_style(true))
	pill.add_theme_stylebox_override("focus", BakeryTheme.chip_style(selected))
	var ink := Color("fff6ea") if selected else BakeryTheme.WINE
	pill.add_theme_color_override("font_color", ink)
	pill.add_theme_color_override("font_hover_color", ink)
	pill.add_theme_color_override("font_pressed_color", Color("fff6ea"))
	pill.add_theme_color_override("font_hover_pressed_color", Color("fff6ea"))
	pill.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	pill.pressed.connect(on_press)
	return pill


func _refresh_cart_bar() -> void:
	if not is_instance_valid(_cart_summary):
		return
	_cart_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cart_summary.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_cart_summary.text = OrderClient.cart_bar_text()
	if is_instance_valid(_clear_cart):
		_clear_cart.visible = OrderClient.cart_count() > 0


func _load_photo(img: TextureRect, url: String) -> void:
	var tex := await OrderClient.fetch_photo(url)
	if tex and is_instance_valid(img):
		img.texture = tex


func _open_detail(drink: Dictionary, preset: Dictionary = {}, qty: int = 1) -> void:
	if OrderClient.is_sold_out(drink):
		NoticeService.info("Sold out today.")
		return
	_detail_drink = drink
	if preset.is_empty():
		_detail_mods = OrderClient.default_mods(drink)
	else:
		_detail_mods = preset.duplicate(true)
	_detail_qty = maxi(1, qty)
	_render()


func _render_detail() -> void:
	var jumps_wrap := get_node_or_null("Safe/VBox/Jumps") as Control
	if jumps_wrap:
		jumps_wrap.visible = false
	for child in _content.get_children():
		child.queue_free()
	var drink := _detail_drink
	_content.add_child(_photo_banner(drink, false, BakeryTheme.PHOTO_HERO_H))
	_add_label(str(drink.get("name", "Item")), BakeryTheme.SIZE_TITLE, BakeryTheme.WINE)
	if OrderClient.has_square_price(drink):
		_add_label(OrderClient.money(int(drink.get("price_cents", 0))), BakeryTheme.SIZE_BODY, BakeryTheme.MUTED)
	else:
		_add_label("—", BakeryTheme.SIZE_CAPTION, BakeryTheme.MUTED)
	for group in drink.get("groups", []):
		if not group is Dictionary:
			continue
		var gid := str(group.get("id", ""))
		var required: bool = bool(group.get("required", false))
		_add_label("%s%s" % [str(group.get("label", "Options")), "" if required else " · optional"], BakeryTheme.SIZE_BODY, BakeryTheme.INK)
		var wrap := HFlowContainer.new()
		_content.add_child(wrap)
		if str(group.get("type", "")) == "multi":
			var selected: Array = _detail_mods.get(gid, [])
			for opt in group.get("options", []):
				if not opt is Dictionary:
					continue
				var oid := str(opt.get("id", ""))
				var extra := int(opt.get("price_cents", 0))
				var label := str(opt.get("label", oid)) + ((" · " + OrderClient.money(extra)) if extra else "")
				if bool(opt.get("sold_out", false)):
					label += " · sold out"
				wrap.add_child(_mod_chip(label, selected.has(oid), func():
					var cur: Array = _detail_mods.get(gid, [])
					if cur.has(oid):
						cur.erase(oid)
					else:
						cur.append(oid)
					_detail_mods[gid] = cur
					_render()
				))
		else:
			var current := str(_detail_mods.get(gid, ""))
			for opt in group.get("options", []):
				if not opt is Dictionary:
					continue
				var oid := str(opt.get("id", ""))
				var extra := int(opt.get("price_cents", 0))
				var label := str(opt.get("label", oid)) + ((" · " + OrderClient.money(extra)) if extra else "")
				if bool(opt.get("sold_out", false)):
					label += " · sold out"
				wrap.add_child(_mod_chip(label, current == oid, func():
					if current == oid and not required:
						_detail_mods[gid] = ""
					else:
						_detail_mods[gid] = oid
					_render()
				))
	var groups: Array = drink.get("groups", [])
	if groups.is_empty():
		_add_label("Square lists no extras on this item.", BakeryTheme.SIZE_CAPTION, BakeryTheme.MUTED)
	else:
		var chosen := OrderClient.visible_mod_line({
			"id": str(drink.get("id", "")),
			"modifiers": _detail_mods,
			"qty": 1,
		})
		_add_label("Selected: %s" % chosen, BakeryTheme.SIZE_BODY, BakeryTheme.WINE)
	var qty_row := HBoxContainer.new()
	var minus := Button.new()
	minus.text = "−"
	var qty := Label.new()
	qty.text = str(_detail_qty)
	qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty.custom_minimum_size = Vector2(72, 64)
	qty.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	var plus := Button.new()
	plus.text = "+"
	minus.custom_minimum_size = Vector2(72, 64)
	plus.custom_minimum_size = Vector2(72, 64)
	minus.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	plus.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	minus.pressed.connect(func():
		_detail_qty = max(1, _detail_qty - 1)
		_render()
	)
	plus.pressed.connect(func():
		_detail_qty = min(9, _detail_qty + 1)
		_render()
	)
	qty_row.add_child(minus)
	qty_row.add_child(qty)
	qty_row.add_child(plus)
	_content.add_child(qty_row)
	_cta.text = "Update extras" if _cart_edit_idx >= 0 else "Add to order"
	_refresh_cart_bar()


func _render_cart() -> void:
	_detail_drink = {}
	_add_label("Your order", BakeryTheme.SIZE_TITLE, BakeryTheme.WINE)
	_add_label("Name for pickup", BakeryTheme.SIZE_BODY, BakeryTheme.INK)
	var name := LineEdit.new()
	name.text = str(OrderClient.cart.get("name", ""))
	name.placeholder_text = "Your name"
	name.text_changed.connect(func(v: String): OrderClient.cart["name"] = v)
	_content.add_child(name)
	_add_label("Phone", BakeryTheme.SIZE_BODY, BakeryTheme.INK)
	var phone := LineEdit.new()
	phone.text = str(OrderClient.cart.get("phone", ""))
	phone.placeholder_text = "(205) 555-0123"
	phone.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PHONE
	phone.text_changed.connect(func(v: String): OrderClient.cart["phone"] = v)
	_content.add_child(phone)
	_add_label("Pickup")
	var pickup := HBoxContainer.new()
	pickup.add_theme_constant_override("separation", 8)
	for mode in ["to-go", "for-here"]:
		var btn := Button.new()
		btn.text = "To go" if mode == "to-go" else "For here"
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.button_pressed = str(OrderClient.cart.get("pickup", "to-go")) == mode
		var captured_mode: String = str(mode)
		btn.pressed.connect(func():
			OrderClient.cart["pickup"] = captured_mode
			_render()
		)
		pickup.add_child(btn)
	_content.add_child(pickup)
	var items: Array = OrderClient.cart.get("items", [])
	if items.is_empty():
		_add_label("Cart is empty. Tap an item on the menu.", BakeryTheme.SIZE_BODY)
		_cta.text = "Back to menu"
		_refresh_cart_bar()
		return
	var clear := Button.new()
	clear.text = "Clear cart"
	clear.theme_type_variation = "SecondaryButton"
	clear.custom_minimum_size = Vector2(0, 68)
	clear.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	clear.pressed.connect(_on_clear_cart)
	_content.add_child(clear)
	_add_label("Items", BakeryTheme.SIZE_TITLE)
	var idx := 0
	for item in items:
		if not item is Dictionary:
			continue
		_content.add_child(_cart_line(item, idx))
		idx += 1
	_render_cart_tip()
	if OrderClient.pay_mode() == "off":
		_add_label("Pay is not configured on the drinks service yet.")
	_refresh_cart_totals()
	_refresh_cart_bar()


func _cart_line(item: Dictionary, idx: int) -> PanelContainer:
	var drink := OrderClient.drink_by_id(str(item.get("id", "")))
	var photo_src: Dictionary = drink if not drink.is_empty() else item
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BakeryTheme.kiosk_row_style())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.add_child(_photo_banner(photo_src, false))
	var title := Label.new()
	title.text = "%s × %d" % [str(drink.get("name", item.get("id"))), int(item.get("qty", 1))]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	title.add_theme_color_override("font_color", BakeryTheme.INK)
	col.add_child(title)
	var extras := OrderClient.visible_mod_line(item)
	if extras.strip_edges() != "":
		var mods := Label.new()
		mods.text = extras
		mods.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mods.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		mods.add_theme_color_override("font_color", BakeryTheme.WINE)
		col.add_child(mods)
	var price := Label.new()
	price.text = OrderClient.money(OrderClient.line_cents(item))
	price.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	price.add_theme_color_override("font_color", BakeryTheme.MUTED)
	col.add_child(price)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	var less := Button.new()
	less.text = "−"
	var more := Button.new()
	more.text = "+"
	var change := Button.new()
	change.text = "Change extras"
	change.theme_type_variation = "SecondaryButton"
	less.custom_minimum_size = Vector2(72, 64)
	more.custom_minimum_size = Vector2(72, 64)
	change.custom_minimum_size = Vector2(0, 64)
	change.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	change.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	var captured := idx
	less.pressed.connect(func(): _bump_qty(captured, -1))
	more.pressed.connect(func(): _bump_qty(captured, 1))
	change.pressed.connect(func(): _edit_cart_line(captured))
	btns.add_child(less)
	btns.add_child(more)
	btns.add_child(change)
	col.add_child(btns)
	panel.add_child(col)
	return panel


func _render_cart_tip() -> void:
	var tip: Dictionary = OrderClient.cart.get("tip", {"type": "none"}) if OrderClient.cart.get("tip") is Dictionary else {"type": "none"}
	var kind := str(tip.get("type", "none"))
	var pct := int(tip.get("percent", 0))
	_add_label("Tip", BakeryTheme.SIZE_TITLE)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	for percent in OrderClient.TIP_PERCENTS:
		var selected := kind == "percent" and pct == percent
		var captured := percent
		row1.add_child(_tip_choice_button("%d%%" % percent, selected, func():
			OrderClient.set_tip_percent(captured)
			_focus_custom_tip = false
			_render()
		))
	_content.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	row2.add_child(_tip_choice_button("Custom", kind == "custom", func():
		OrderClient.set_tip_custom()
		_focus_custom_tip = true
		_render()
	))
	row2.add_child(_tip_choice_button("No tip", kind == "none" or kind == "", func():
		OrderClient.set_tip_none()
		_focus_custom_tip = false
		_render()
	))
	_content.add_child(row2)
	if kind == "custom":
		_add_label("Custom tip")
		var custom := LineEdit.new()
		custom.placeholder_text = "0.00 or 150c"
		custom.text = str(tip.get("amount_input", ""))
		custom.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
		custom.text_changed.connect(func(v: String):
			OrderClient.set_custom_tip_input(v)
			_refresh_cart_totals()
		)
		_content.add_child(custom)
		if _focus_custom_tip:
			_focus_custom_tip = false
			custom.call_deferred("grab_focus")
	_cart_drinks_lbl = _money_line("Drinks", OrderClient.cart_subtotal_cents())
	_cart_tip_lbl = _money_line("Tip", OrderClient.tip_cents())
	_cart_total_lbl = _money_line("Total", OrderClient.cart_total_cents(), true)


func _tip_choice_button(label: String, selected: bool, on_press: Callable) -> Button:
	var btn := _mod_chip(label, selected, on_press, false)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return btn


func _money_line(title: String, cents: int, emphasize: bool = false) -> Label:
	var row := HBoxContainer.new()
	var left := Label.new()
	left.text = title
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_color_override("font_color", Color("4a2c2a"))
	var right := Label.new()
	right.text = OrderClient.money(cents)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_theme_color_override("font_color", Color("4a2c2a"))
	if emphasize:
		left.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
		right.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	row.add_child(left)
	row.add_child(right)
	_content.add_child(row)
	return right


func _refresh_cart_totals() -> void:
	var sub := OrderClient.cart_subtotal_cents()
	var tip_n := OrderClient.tip_cents()
	var due := sub + tip_n
	if is_instance_valid(_cart_drinks_lbl):
		_cart_drinks_lbl.text = OrderClient.money(sub)
	if is_instance_valid(_cart_tip_lbl):
		_cart_tip_lbl.text = OrderClient.money(tip_n)
	if is_instance_valid(_cart_total_lbl):
		_cart_total_lbl.text = OrderClient.money(due)
	_set_cart_cta(due)


func _set_cart_cta(due: int) -> void:
	var mode := OrderClient.pay_mode()
	if mode == "off":
		_cta.text = "Pay unavailable"
	elif mode == "demo":
		_cta.text = "Demo pay · %s" % OrderClient.money(due)
	else:
		_cta.text = "Checkout · %s" % OrderClient.money(due)


func _on_clear_cart() -> void:
	if OrderClient.cart_count() < 1:
		return
	OrderClient.clear_cart()
	_cart_edit_idx = -1
	NoticeService.info("Cart cleared.")
	_render()


func _edit_cart_line(idx: int) -> void:
	var items: Array = OrderClient.cart.get("items", [])
	if idx < 0 or idx >= items.size() or not items[idx] is Dictionary:
		return
	var item: Dictionary = items[idx]
	var drink := OrderClient.drink_by_id(str(item.get("id", "")))
	if drink.is_empty():
		return
	_cart_edit_idx = idx
	var preset: Dictionary = item.get("modifiers", {}) if item.get("modifiers") is Dictionary else {}
	_open_detail(drink, preset, maxi(1, int(item.get("qty", 1))))


func _bump_qty(idx: int, delta: int) -> void:
	var items: Array = OrderClient.cart.get("items", [])
	if idx < 0 or idx >= items.size():
		return
	var item: Dictionary = items[idx]
	item["qty"] = int(item.get("qty", 1)) + delta
	if int(item["qty"]) < 1:
		items.remove_at(idx)
	_render()


func _render_status() -> void:
	_add_label("Your orders", BakeryTheme.SIZE_TITLE, BakeryTheme.WINE)
	if not AccountClient.is_logged_in():
		_add_label("Log in with phone to see your order status.", BakeryTheme.SIZE_BODY, BakeryTheme.MUTED)
		var signin := Button.new()
		signin.text = "Sign in with phone"
		signin.pressed.connect(func(): AppConfig.go("res://scenes/account/login.tscn"))
		_content.add_child(signin)
		_cta.text = "Sign in"
		return
	var open_orders: Array = []
	if _my_status.get("open_orders") is Array:
		open_orders = _my_status.get("open_orders", [])
	if open_orders.is_empty() and GameSave.active_order_id != "" and not _status.is_empty():
		open_orders = [_status]
	if open_orders.is_empty():
		_add_label("No open Square orders on this phone.", BakeryTheme.SIZE_BODY, BakeryTheme.MUTED)
		_cta.text = "Refresh status"
		return
	for row in open_orders:
		if not row is Dictionary:
			continue
		_status_order_card(row)
	_cta.text = "Refresh status"


func _status_order_card(row: Dictionary) -> void:
	var status := str(row.get("status", "making"))
	var number := str(row.get("order_number", row.get("id", "")))
	var ahead := int(row.get("ahead", row.get("ahead_count", 0)))
	var name := str(row.get("name", "Your order"))
	_add_label(name, BakeryTheme.SIZE_TITLE, BakeryTheme.INK)
	_add_label("Now: %s%s" % [status, (" · #" + number) if number != "" else ""], BakeryTheme.SIZE_BODY)
	if status == "ready":
		_add_label("Head to the pickup counter.", BakeryTheme.SIZE_BODY, BakeryTheme.WINE)
	else:
		_add_label("%d ahead of you in the queue." % ahead, BakeryTheme.SIZE_BODY, BakeryTheme.MUTED)
	for item in row.get("items", []):
		if item is Dictionary:
			_content.add_child(_status_item_card(item))


func _status_item_card(item: Dictionary) -> PanelContainer:
	var drink := OrderClient.drink_by_id(str(item.get("id", item.get("catalog_object_id", ""))))
	var photo_src: Dictionary = drink if not drink.is_empty() else item
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BakeryTheme.kiosk_row_style())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.add_child(_photo_banner(photo_src, false))
	var line := Label.new()
	line.text = "%s × %s" % [str(item.get("name", "Item")), str(item.get("qty", 1))]
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	line.add_theme_color_override("font_color", BakeryTheme.INK)
	col.add_child(line)
	var extras := OrderClient.visible_mod_line(item)
	if extras.strip_edges() != "":
		var mods := Label.new()
		mods.text = extras
		mods.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mods.add_theme_font_size_override("font_size", BakeryTheme.SIZE_CAPTION)
		mods.add_theme_color_override("font_color", BakeryTheme.WINE)
		col.add_child(mods)
	panel.add_child(col)
	return panel


func _retry_square_menu() -> void:
	_set_busy("Loading Square menu…")
	var result := await OrderClient.fetch_menu()
	_set_busy("" if result.get("ok", false) else str(result.get("error", "Square catalog unavailable.")))
	_render()


func _on_cta() -> void:
	if not _detail_drink.is_empty():
		if OrderClient.is_sold_out(_detail_drink):
			NoticeService.info("Sold out today.")
			return
		if _cart_edit_idx >= 0:
			var items: Array = OrderClient.cart.get("items", [])
			if _cart_edit_idx < items.size() and items[_cart_edit_idx] is Dictionary:
				var row: Dictionary = items[_cart_edit_idx]
				row["modifiers"] = _detail_mods.duplicate(true)
				row["qty"] = _detail_qty
				row.erase("mod_labels")
			_cart_edit_idx = -1
			_detail_drink = {}
			NoticeService.info("Updated extras.")
			_set_tab(Tab.CART)
			return
		OrderClient.add_cart_item(str(_detail_drink.get("id", "")), _detail_mods.duplicate(true), _detail_qty)
		_detail_drink = {}
		NoticeService.info("Added to order.")
		_set_tab(Tab.MENU)
		return
	match _tab:
		Tab.MENU:
			if OrderClient.drinks().is_empty():
				WebBridge.open_order()
			else:
				_set_tab(Tab.CART)
		Tab.CART:
			if OrderClient.cart_count() == 0:
				_set_tab(Tab.MENU)
			else:
				await _start_checkout()
		Tab.STATUS:
			if not AccountClient.is_logged_in():
				AppConfig.go("res://scenes/account/login.tscn")
				return
			await _poll_status()
			_render()


func _start_checkout() -> void:
	if str(OrderClient.cart.get("name", "")).strip_edges() == "":
		NoticeService.info("Add a pickup name.")
		return
	var tip_err := OrderClient.tip_error()
	if tip_err != "":
		NoticeService.info(tip_err)
		return
	_cta.disabled = true
	_busy.text = "Starting Square checkout…"
	var result := await OrderClient.checkout()
	_cta.disabled = false
	_busy.text = ""
	if not result.get("ok", false):
		var err := str(result.get("error", "Checkout failed."))
		NoticeService.info(err)
		if str(result.get("url", "")) != "":
			WebBridge.open_order()
		return
	if OrderClient.last_checkout_url != "":
		WebBridge.open(OrderClient.last_checkout_url)
	_set_tab(Tab.STATUS)
	_poll.start()
	await _poll_status()


func _poll_status() -> void:
	if AccountClient.is_logged_in():
		var mine := await AccountClient.fetch_status()
		if mine.get("ok", false) and mine.get("data") is Dictionary:
			_my_status = mine["data"]
			var open_orders: Variant = _my_status.get("open_orders", [])
			if open_orders is Array:
				for row in open_orders:
					if not row is Dictionary:
						continue
					if str(row.get("status", "")) == "ready":
						var oid := str(row.get("order_id", row.get("id", "")))
						if oid != "" and GameSave.last_ready_order_id != oid:
							GameSave.mark_order_ready_seen(oid)
							NoticeService.order_ready(str(row.get("order_number", oid)))
	elif GameSave.active_order_id != "" or OrderClient.last_order_id != "":
		var result := await OrderClient.fetch_status()
		if result.get("ok", false) and result.get("data") is Dictionary:
			_status = result["data"]
	if is_inside_tree() and _tab == Tab.STATUS:
		_render()
