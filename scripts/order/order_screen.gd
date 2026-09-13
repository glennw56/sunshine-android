extends Control
## Native order UI backed by the live bakery-drinks Square catalog.
## WebView/browser is used for Square hosted checkout; catalog itself is HTTP.

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")

enum Tab { MENU, CART, STATUS, STAFF }

var _tab: Tab = Tab.MENU
var _status: Dictionary = {}
var _poll: Timer
var _staff_poll: Timer
var _seen_board_hash: String = ""
var _detail_drink: Dictionary = {}
var _detail_mods: Dictionary = {}
var _detail_qty: int = 1
var _board_preview: String = ""
var _photo_fallback: Texture2D
var _focus_custom_tip: bool = false
var _cart_drinks_lbl: Label
var _cart_tip_lbl: Label
var _cart_total_lbl: Label

@onready var _header: Label = $Safe/VBox/Header/Title
@onready var _back: Button = $Safe/VBox/Header/Back
@onready var _web: Button = $Safe/VBox/Header/Web
@onready var _tabs: HBoxContainer = $Safe/VBox/Tabs
@onready var _body: ScrollContainer = $Safe/VBox/Body
@onready var _content: VBoxContainer = $Safe/VBox/Body/Content
@onready var _cart_bar: PanelContainer = $Safe/VBox/CartBar
@onready var _cart_summary: Label = $Safe/VBox/CartBar/Row/CartSummary
@onready var _cta: Button = $Safe/VBox/CartBar/Row/Cta
@onready var _busy: Label = $Safe/VBox/Busy


func _ready() -> void:
	BakeryTheme.apply(self)
	_back.theme_type_variation = "SecondaryButton"
	_web.theme_type_variation = "SecondaryButton"
	_photo_fallback = load("res://assets/generated/drink.png")
	_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_web.pressed.connect(func(): WebBridge.open_order())
	_cta.pressed.connect(_on_cta)
	_make_tabs()
	_poll = Timer.new()
	_poll.wait_time = 4.0
	_poll.timeout.connect(_poll_status)
	add_child(_poll)
	_staff_poll = Timer.new()
	_staff_poll.wait_time = 10.0
	_staff_poll.timeout.connect(_poll_staff)
	add_child(_staff_poll)
	_cart_bar.add_theme_stylebox_override("panel", BakeryTheme.sticky_bar())
	_cart_summary.add_theme_color_override("font_color", BakeryTheme.CREAM)
	_cart_summary.add_theme_font_size_override("font_size", 18)
	_cta.theme_type_variation = "GoldButton"
	_cta.custom_minimum_size = Vector2(168, 56)
	_cta.add_theme_font_size_override("font_size", 18)
	_header.add_theme_font_size_override("font_size", 28)
	_header.add_theme_color_override("font_color", BakeryTheme.WINE)
	_set_busy("Loading menu…")
	var result := await OrderClient.fetch_menu()
	_set_busy("")
	if not result.get("ok", false) and not result.get("fallback", false):
		_set_busy(str(result.get("error", "Catalog failed.")))
	_render()
	if GameSave.active_order_id != "":
		_poll.start()


func _make_tabs() -> void:
	for child in _tabs.get_children():
		child.queue_free()
	var labels := ["Menu", "Cart", "Status", "Staff"]
	for i in labels.size():
		var btn := Button.new()
		btn.text = labels[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		var idx := i
		btn.pressed.connect(func(): _set_tab(idx))
		btn.custom_minimum_size = Vector2(0, 44)
		_tabs.add_child(btn)


func _set_tab(idx: int) -> void:
	_tab = idx as Tab
	if _tab == Tab.STATUS:
		_poll.start()
		_poll_status()
	else:
		if GameSave.active_order_id == "":
			_poll.stop()
	if _tab == Tab.STAFF:
		_staff_poll.start()
		_poll_staff()
	else:
		_staff_poll.stop()
	_render()


func _render() -> void:
	_header.text = "Order"
	for i in _tabs.get_child_count():
		var btn := _tabs.get_child(i) as Button
		if btn:
			btn.button_pressed = i == int(_tab)
			_style_tab(btn, i == int(_tab))
	for child in _content.get_children():
		child.queue_free()
	match _tab:
		Tab.MENU:
			_render_menu()
		Tab.CART:
			_render_cart()
		Tab.STATUS:
			_render_status()
		Tab.STAFF:
			_render_staff()
	_refresh_cart_bar()


func _add_label(text: String, size: int = 16, color: Color = Color("4a2c2a")) -> Label:
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
		_busy.add_theme_font_size_override("font_size", 16)
		_busy.add_theme_color_override("font_color", BakeryTheme.WINE)


func _style_tab(btn: Button, selected: bool) -> void:
	btn.theme_type_variation = "" if selected else "SecondaryButton"
	btn.add_theme_font_size_override("font_size", 15)


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", BakeryTheme.WINE)
	_content.add_child(l)
	return l


func _render_menu() -> void:
	if OrderClient.drinks().is_empty():
		_add_label("No drinks loaded.", 18, BakeryTheme.MUTED)
		_cta.text = "Open web order"
		_refresh_cart_bar()
		return
	var groups := {"coffee": [], "tea": [], "more": []}
	for drink in OrderClient.drinks():
		if not drink is Dictionary:
			continue
		var cat := str(drink.get("category", "more"))
		if not groups.has(cat):
			cat = "more"
		groups[cat].append(drink)
	var titles := {"coffee": "Coffee", "tea": "Tea", "more": "More"}
	for cat in ["coffee", "tea", "more"]:
		var list: Array = groups[cat]
		if list.is_empty():
			continue
		_section_label(str(titles[cat]))
		for drink in list:
			_content.add_child(_drink_row(drink))
	_refresh_cart_bar()
	var n := OrderClient.cart_count()
	_cta.text = "Checkout" if n > 0 else "Review"


func _drink_row(drink: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BakeryTheme.kiosk_row_style())
	panel.custom_minimum_size = Vector2(0, 76)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(8, 48)
	var cat := str(drink.get("category", "more"))
	swatch.color = BakeryTheme.WINE if cat == "coffee" else (BakeryTheme.BLUSH if cat == "tea" else BakeryTheme.GOLD)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	var name := Label.new()
	name.text = str(drink.get("name", "Drink"))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", BakeryTheme.INK)
	copy.add_child(name)
	var price := Label.new()
	price.text = OrderClient.money(int(drink.get("price_cents", 0)))
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 18)
	price.add_theme_color_override("font_color", BakeryTheme.MUTED)
	row.add_child(swatch)
	row.add_child(copy)
	row.add_child(price)
	panel.add_child(row)
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_open_detail(drink)
		elif ev is InputEventScreenTouch and ev.pressed:
			_open_detail(drink)
	)
	return panel


func _mod_chip(label: String, selected: bool, on_press: Callable) -> Button:
	var pill := Button.new()
	pill.toggle_mode = true
	pill.button_pressed = selected
	pill.text = label
	pill.clip_text = false
	pill.autowrap_mode = TextServer.AUTOWRAP_OFF
	pill.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.custom_minimum_size = Vector2(0, 44)
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
	pill.add_theme_font_size_override("font_size", 16)
	pill.pressed.connect(on_press)
	return pill


func _refresh_cart_bar() -> void:
	if not is_instance_valid(_cart_summary):
		return
	var n := OrderClient.cart_count()
	var due := OrderClient.cart_total_cents()
	if n < 1:
		_cart_summary.text = "0 items · $0.00"
	else:
		_cart_summary.text = "%d item%s · %s" % [n, "" if n == 1 else "s", OrderClient.money(due)]


func _load_photo(img: TextureRect, url: String) -> void:
	var tex := await OrderClient.fetch_photo(url)
	if tex and is_instance_valid(img):
		img.texture = tex


func _open_detail(drink: Dictionary) -> void:
	_detail_drink = drink
	_detail_mods = OrderClient.default_mods(drink)
	_detail_qty = 1
	_render_detail()


func _render_detail() -> void:
	for child in _content.get_children():
		child.queue_free()
	var drink := _detail_drink
	_add_label(str(drink.get("name", "Drink")), 28, BakeryTheme.WINE)
	_add_label(OrderClient.money(int(drink.get("price_cents", 0))), 18, BakeryTheme.MUTED)
	for group in drink.get("groups", []):
		if not group is Dictionary:
			continue
		var gid := str(group.get("id", ""))
		var required: bool = bool(group.get("required", true))
		_add_label("%s%s" % [str(group.get("label", "Options")), "" if required else " · optional"], 18, BakeryTheme.INK)
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
				wrap.add_child(_mod_chip(label, selected.has(oid), func():
					var cur: Array = _detail_mods.get(gid, [])
					if cur.has(oid):
						cur.erase(oid)
					else:
						cur.append(oid)
					_detail_mods[gid] = cur
					_render_detail()
				))
		else:
			var current := str(_detail_mods.get(gid, ""))
			for opt in group.get("options", []):
				if not opt is Dictionary:
					continue
				var oid := str(opt.get("id", ""))
				var extra := int(opt.get("price_cents", 0))
				var label := str(opt.get("label", oid)) + ((" · " + OrderClient.money(extra)) if extra else "")
				wrap.add_child(_mod_chip(label, current == oid, func():
					_detail_mods[gid] = oid
					_render_detail()
				))
	var qty_row := HBoxContainer.new()
	var minus := Button.new()
	minus.text = "−"
	var qty := Label.new()
	qty.text = str(_detail_qty)
	qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty.custom_minimum_size = Vector2(48, 0)
	var plus := Button.new()
	plus.text = "+"
	minus.pressed.connect(func():
		_detail_qty = max(1, _detail_qty - 1)
		_render_detail()
	)
	plus.pressed.connect(func():
		_detail_qty = min(9, _detail_qty + 1)
		_render_detail()
	)
	qty_row.add_child(minus)
	qty_row.add_child(qty)
	qty_row.add_child(plus)
	_content.add_child(qty_row)
	_cta.text = "Add to order"
	_refresh_cart_bar()


func _render_cart() -> void:
	_detail_drink = {}
	_add_label("Your order", 24, BakeryTheme.WINE)
	_add_label("Name for pickup", 16, BakeryTheme.INK)
	var name := LineEdit.new()
	name.text = str(OrderClient.cart.get("name", ""))
	name.placeholder_text = "Your name"
	name.text_changed.connect(func(v: String): OrderClient.cart["name"] = v)
	_content.add_child(name)
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
		_add_label("Cart is empty. Tap a drink on the kiosk list.")
		_cta.text = "Back to drinks"
		_refresh_cart_bar()
		return
	_add_label("Drinks", 18)
	var idx := 0
	for item in items:
		if not item is Dictionary:
			continue
		var drink := OrderClient.drink_by_id(str(item.get("id", "")))
		_add_label("%s × %d  ·  %s" % [str(drink.get("name", item.get("id"))), int(item.get("qty", 1)), OrderClient.money(OrderClient.line_cents(item))], 18)
		var row := HBoxContainer.new()
		var less := Button.new()
		less.text = "−"
		var more := Button.new()
		more.text = "+"
		var captured := idx
		less.pressed.connect(func(): _bump_qty(captured, -1))
		more.pressed.connect(func(): _bump_qty(captured, 1))
		row.add_child(less)
		row.add_child(more)
		_content.add_child(row)
		idx += 1
	_render_cart_tip()
	if OrderClient.pay_mode() == "off":
		_add_label("Pay is not configured on the drinks service yet.")
	_refresh_cart_totals()
	_refresh_cart_bar()


func _render_cart_tip() -> void:
	var tip: Dictionary = OrderClient.cart.get("tip", {"type": "none"}) if OrderClient.cart.get("tip") is Dictionary else {"type": "none"}
	var kind := str(tip.get("type", "none"))
	var pct := int(tip.get("percent", 0))
	_add_label("Tip", 18)
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
	var btn := _mod_chip(label, selected, on_press)
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
		left.add_theme_font_size_override("font_size", 18)
		right.add_theme_font_size_override("font_size", 18)
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
	var status := str(_status.get("status", "pending" if GameSave.active_order_id == "" else "making"))
	var number := str(_status.get("order_number", GameSave.active_order_id))
	_add_label("Customer status", 22)
	_add_label("Paid → Making → Ready", 14, Color("7a4e2e"))
	_add_label("Now: %s%s" % [status, (" · #" + number) if number != "" else ""], 18)
	if status == "ready":
		_add_label("Head to the pickup counter.")
		_cta.text = "Go to pickup"
	elif GameSave.active_order_id == "":
		_add_label("Place an order to track it here. You can also paste an order id.")
		var oid := LineEdit.new()
		oid.placeholder_text = "order id"
		oid.text = GameSave.active_order_id
		oid.text_changed.connect(func(v: String): GameSave.set_active_order_id(v.strip_edges()))
		_content.add_child(oid)
		_cta.text = "Check status"
	else:
		_add_label("We'll notice you in-app when it's ready.")
		_cta.text = "Refresh status"


func _render_staff() -> void:
	_add_label("Shop / staff board", 22)
	_add_label("Live drink board from bakery-drinks, plus on-device tickets from this phone's orders.", 14, Color("7a4e2e"))
	if AppConfig.staff_pin != "" and not GameSave.shop_device:
		_add_label("Enter shop PIN")
		var pin := LineEdit.new()
		pin.secret = true
		pin.placeholder_text = "PIN"
		_content.add_child(pin)
		var unlock := Button.new()
		unlock.text = "Unlock shop device"
		unlock.pressed.connect(func():
			if pin.text == AppConfig.staff_pin:
				GameSave.set_shop_device(true)
				NoticeService.staff("Shop device on.")
				_render()
			else:
				NoticeService.info("PIN did not match.")
		)
		_content.add_child(unlock)
		_cta.text = "Open live drink board"
		return
	var toggle := CheckBox.new()
	toggle.text = "This is a shop device (staff notices)"
	toggle.button_pressed = GameSave.shop_device
	toggle.toggled.connect(func(on: bool): GameSave.set_shop_device(on))
	_content.add_child(toggle)
	_add_label("On-device tickets", 18)
	if GameSave.local_staff_tickets.is_empty():
		_add_label("None yet. Customer checkouts on this device show up here.")
	for ticket in GameSave.local_staff_tickets:
		if not ticket is Dictionary:
			continue
		_staff_ticket_row(ticket)
	_add_label("Live board HTML", 18)
	if _board_preview != "":
		_add_label(_board_preview, 13, Color("3d5a45"))
	_cta.text = "Refresh shop board"


func _staff_ticket_row(ticket: Dictionary) -> void:
	var id := str(ticket.get("id", ""))
	var status := str(ticket.get("status", "paid"))
	_add_label("%s · %s · %s" % [str(ticket.get("name", "Order")), str(ticket.get("summary", "")), status], 15)
	var row := HBoxContainer.new()
	var ready := Button.new()
	ready.text = "Mark ready"
	var done := Button.new()
	done.text = "Complete"
	ready.pressed.connect(func():
		GameSave.update_local_ticket(id, "ready")
		NoticeService.staff_ready(str(ticket.get("summary", "order")))
		if GameSave.active_order_id == id:
			NoticeService.order_ready(str(ticket.get("number", id)))
		_render()
	)
	done.pressed.connect(func():
		GameSave.update_local_ticket(id, "complete")
		NoticeService.staff_complete(str(ticket.get("summary", "order")))
		_render()
	)
	row.add_child(ready)
	row.add_child(done)
	_content.add_child(row)


func _on_cta() -> void:
	if not _detail_drink.is_empty() and _tab == Tab.MENU:
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
			await _poll_status()
			_render()
		Tab.STAFF:
			WebBridge.open_board()
			await _poll_staff()
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
		NoticeService.info(str(result.get("error", "Checkout failed.")))
		return
	var data: Dictionary = result.get("data", {})
	var summary_bits: Array[String] = []
	for item in OrderClient.cart.get("items", []):
		if item is Dictionary:
			var drink := OrderClient.drink_by_id(str(item.get("id", "")))
			summary_bits.append(str(drink.get("name", item.get("id"))))
	var ticket := {
		"id": str(data.get("order_id", "local-%d" % Time.get_unix_time_from_system())),
		"number": str(data.get("order_number", "")),
		"name": str(OrderClient.cart.get("name", "")),
		"summary": ", ".join(summary_bits),
		"status": "paid",
	}
	GameSave.add_local_ticket(ticket)
	if GameSave.shop_device:
		NoticeService.staff("New order: %s" % ticket["summary"])
	if OrderClient.last_checkout_url != "":
		WebBridge.open(OrderClient.last_checkout_url)
	_set_tab(Tab.STATUS)
	_poll.start()
	await _poll_status()


func _poll_status() -> void:
	if GameSave.active_order_id == "" and OrderClient.last_order_id == "":
		return
	var result := await OrderClient.fetch_status()
	if not result.get("ok", false):
		return
	_status = result.get("data", {})
	var status := str(_status.get("status", ""))
	var oid := str(_status.get("order_id", GameSave.active_order_id))
	if status == "ready" and GameSave.last_ready_order_id != oid:
		GameSave.mark_order_ready_seen(oid)
		NoticeService.order_ready(str(_status.get("order_number", oid)))
		if GameSave.shop_device:
			NoticeService.staff_ready(str(_status.get("order_number", oid)))
	if is_inside_tree() and _tab == Tab.STATUS:
		_render()


func _poll_staff() -> void:
	var result := await OrderClient.fetch_board_tickets()
	if not result.get("ok", false):
		return
	var html := str(result.get("text", "")).strip_edges()
	var h := str(html.hash())
	if _seen_board_hash != "" and h != _seen_board_hash and html.find("kds-empty") == -1:
		NoticeService.staff("Drink board updated — check the shop tab or live board.")
	_seen_board_hash = h
	var preview := _strip_tags(html)
	_board_preview = preview if preview else "(empty board)"
	if _tab == Tab.STAFF:
		_render()


func _strip_tags(html: String) -> String:
	var re := RegEx.new()
	re.compile("<[^>]+>")
	var text := re.sub(html, " ", true)
	return " ".join(text.split(" ", false)).strip_edges()
