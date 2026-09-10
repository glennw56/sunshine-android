extends Control
## Native order UI backed by the live bakery-drinks Square catalog.
## WebView/browser is used for Square hosted checkout; catalog itself is HTTP.

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

@onready var _header: Label = $Safe/VBox/Header/Title
@onready var _back: Button = $Safe/VBox/Header/Back
@onready var _web: Button = $Safe/VBox/Header/Web
@onready var _tabs: HBoxContainer = $Safe/VBox/Tabs
@onready var _body: ScrollContainer = $Safe/VBox/Body
@onready var _content: VBoxContainer = $Safe/VBox/Body/Content
@onready var _cta: Button = $Safe/VBox/Cta
@onready var _busy: Label = $Safe/VBox/Busy


func _ready() -> void:
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
	_busy.text = "Loading live Square catalog…"
	var result := await OrderClient.fetch_menu()
	_busy.text = ""
	if not result.get("ok", false):
		_busy.text = str(result.get("error", "Catalog failed."))
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
	_header.text = "Order · %s" % AppConfig.bakery_name
	for i in _tabs.get_child_count():
		var btn := _tabs.get_child(i) as Button
		if btn:
			btn.button_pressed = i == int(_tab)
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


func _add_label(text: String, size: int = 16, color: Color = Color("4a2c2a")) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_content.add_child(l)
	return l


func _render_menu() -> void:
	var source := OrderClient.catalog_source()
	var mode := OrderClient.pay_mode()
	_add_label("Live catalog · source %s · pay %s" % [source if source else "?", mode], 14, Color("7a4e2e"))
	_add_label("No hardcoded menu. Items below are from %s" % AppConfig.menu_api(), 13, Color("7a4e2e"))
	if OrderClient.drinks().is_empty():
		_add_label("The live catalog is empty or unreachable. Use Open web order as a fallback.")
		_cta.text = "Open web order"
		return
	var groups := {"coffee": [], "tea": [], "more": []}
	for drink in OrderClient.drinks():
		if not drink is Dictionary:
			continue
		var cat := str(drink.get("category", "more"))
		if not groups.has(cat):
			cat = "more"
		groups[cat].append(drink)
	for cat in ["coffee", "tea", "more"]:
		var list: Array = groups[cat]
		if list.is_empty():
			continue
		_add_label(cat.capitalize(), 22)
		for drink in list:
			_content.add_child(_drink_row(drink))
	var n := OrderClient.cart_count()
	_cta.text = "Review order · %d" % n if n > 0 else "Review order"


func _drink_row(drink: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var img := TextureRect.new()
	img.custom_minimum_size = Vector2(72, 72)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.texture = _photo_fallback
	var photo_url := str(drink.get("photo", ""))
	if photo_url.begins_with("/"):
		photo_url = AppConfig.order_base_url + photo_url
	if photo_url.begins_with("http"):
		_load_photo(img, photo_url)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := Label.new()
	name.text = str(drink.get("name", "Drink"))
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", Color("4a2c2a"))
	var meta := Label.new()
	var desc := str(drink.get("description", "")).strip_edges()
	meta.text = "%s%s" % [OrderClient.money(int(drink.get("price_cents", 0))), (" · " + desc) if desc else ""]
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_color_override("font_color", Color("7a4e2e"))
	col.add_child(name)
	col.add_child(meta)
	row.add_child(img)
	row.add_child(col)
	panel.add_child(row)
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_open_detail(drink)
		elif ev is InputEventScreenTouch and ev.pressed:
			_open_detail(drink)
	)
	return panel


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
	_add_label(str(drink.get("name", "Drink")), 26)
	_add_label(OrderClient.money(int(drink.get("price_cents", 0))), 16, Color("7a4e2e"))
	for group in drink.get("groups", []):
		if not group is Dictionary:
			continue
		var gid := str(group.get("id", ""))
		var required: bool = bool(group.get("required", true))
		_add_label("%s%s" % [str(group.get("label", "Options")), "" if required else " · optional"], 16)
		var wrap := HFlowContainer.new()
		_content.add_child(wrap)
		if str(group.get("type", "")) == "multi":
			var selected: Array = _detail_mods.get(gid, [])
			for opt in group.get("options", []):
				if not opt is Dictionary:
					continue
				var oid := str(opt.get("id", ""))
				var pill := Button.new()
				pill.toggle_mode = true
				pill.button_pressed = selected.has(oid)
				var extra := int(opt.get("price_cents", 0))
				pill.text = str(opt.get("label", oid)) + ((" · " + OrderClient.money(extra)) if extra else "")
				pill.pressed.connect(func():
					var cur: Array = _detail_mods.get(gid, [])
					if cur.has(oid):
						cur.erase(oid)
					else:
						cur.append(oid)
					_detail_mods[gid] = cur
				)
				wrap.add_child(pill)
		else:
			var current := str(_detail_mods.get(gid, ""))
			for opt in group.get("options", []):
				if not opt is Dictionary:
					continue
				var oid := str(opt.get("id", ""))
				var pill := Button.new()
				pill.toggle_mode = true
				pill.button_pressed = current == oid
				var extra := int(opt.get("price_cents", 0))
				pill.text = str(opt.get("label", oid)) + ((" · " + OrderClient.money(extra)) if extra else "")
				pill.pressed.connect(func():
					_detail_mods[gid] = oid
					_render_detail()
				)
				wrap.add_child(pill)
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


func _render_cart() -> void:
	_detail_drink = {}
	var items: Array = OrderClient.cart.get("items", [])
	if items.is_empty():
		_add_label("Your order is empty. Pick a drink from the live menu.")
		_cta.text = "Back to drinks"
		return
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
	_add_label("Pickup", 18)
	var pickup := HBoxContainer.new()
	for mode in ["for-here", "to-go"]:
		var btn := Button.new()
		btn.text = "For here" if mode == "for-here" else "To go"
		btn.toggle_mode = true
		btn.button_pressed = str(OrderClient.cart.get("pickup", "to-go")) == mode
		var captured_mode: String = str(mode)
		btn.pressed.connect(func():
			OrderClient.cart["pickup"] = captured_mode
			_render()
		)
		pickup.add_child(btn)
	_content.add_child(pickup)
	_add_label("Name for pickup")
	var name := LineEdit.new()
	name.text = str(OrderClient.cart.get("name", ""))
	name.placeholder_text = "Your name"
	name.text_changed.connect(func(v: String): OrderClient.cart["name"] = v)
	_content.add_child(name)
	var sub := OrderClient.cart_subtotal_cents()
	_add_label("Drinks %s" % OrderClient.money(sub), 16)
	var mode := OrderClient.pay_mode()
	if mode == "off":
		_add_label("Pay is not configured on the drinks service yet.")
		_cta.text = "Pay unavailable"
	elif mode == "demo":
		_cta.text = "Demo pay · %s" % OrderClient.money(sub)
	else:
		_cta.text = "Pay now · %s" % OrderClient.money(sub)
	_add_label("Checkout opens the live Square page (browser / WebView). Status stays in-app.", 13, Color("7a4e2e"))


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
