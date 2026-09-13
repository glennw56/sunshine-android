extends Node
## HTTP client for the live bakery-drinks Square-backed catalog and board.
## No hardcoded menu: drinks come from GET /order/api/menu.
## Cart tip matches POST /order/api/checkout: none | percent 15/18/20 | custom amount_cents.

signal menu_loaded(payload: Dictionary)
signal menu_failed(message: String)

const TIP_PERCENTS: Array[int] = [15, 18, 20]
const CUSTOM_TIP_MAX_CENTS := 10000

var menu: Dictionary = {}
var cart: Dictionary = {"items": [], "pickup": "to-go", "name": "", "phone": "", "tip": {"type": "none"}}
var last_order_id: String = ""
var last_checkout_url: String = ""
var last_status: Dictionary = {}
var photo_cache: Dictionary = {}
var used_fallback: bool = false
var _custom_dollars_re: RegEx


func has_menu() -> bool:
	return (menu.get("drinks", []) as Array).size() > 0


func drinks() -> Array:
	var list: Variant = menu.get("drinks", [])
	if list is Array and not list.is_empty():
		return list
	list = menu.get("items", [])
	return list if list is Array else []


func items() -> Array:
	return drinks()


func drink_by_id(id: String) -> Dictionary:
	for item in drinks():
		if item is Dictionary and str(item.get("id", "")) == id:
			return item
	return {}


func pay_mode() -> String:
	return str(menu.get("pay_mode", "off"))


func catalog_source() -> String:
	return str(menu.get("source", ""))


func fetch_menu() -> Dictionary:
	used_fallback = false
	var result := await _request_json(AppConfig.menu_api())
	if result.get("ok", false):
		var data: Variant = result.get("data", {})
		menu = _adopt_catalog(data if data is Dictionary else {})
		if not drinks().is_empty():
			menu_loaded.emit(menu)
			return {"ok": true, "data": menu}
	var err := str(result.get("error", menu.get("catalog_error", "Live catalog unavailable.")))
	menu = fallback_menu()
	used_fallback = true
	menu_failed.emit(err)
	menu_loaded.emit(menu)
	return {"ok": true, "fallback": true, "error": err, "data": menu}


func fallback_menu() -> Dictionary:
	## Full Irondale-style bakery case + drinks when Square HTTP fails.
	var catalog: Array = [
		_fallback_drink("coffee-house", "Coffee", "coffee", 350, "House drip."),
		_fallback_drink("viet-coffee", "Vietnamese Coffee", "coffee", 550, "Strong + sweet."),
		_fallback_drink("biscoff-coffee", "Biscoff Coffee", "coffee", 850, "Cookie-butter latte."),
		_fallback_drink("milk-tea", "Milk Tea", "tea", 450, "Classic milk tea."),
		_fallback_drink("matcha", "Matcha Latte", "tea", 550, "Earthy + creamy."),
		_fallback_drink("lemonade", "Lemonade", "tea", 400, "Fresh lemon."),
		_fallback_drink("fruit-tea", "Fruit Tea", "tea", 400, "Iced fruit tea."),
		_fallback_drink("water", "Water", "more", 100, "Bottled water."),
	]
	catalog.append_array(bakery_case_items())
	return {
		"source": "fallback",
		"pay_mode": "off",
		"location": "Irondale",
		"drinks": catalog,
	}


func bakery_case_items() -> Array:
	## Case items the drinks API does not return. Sold-out flags are realistic Sunday leftovers.
	return [
		_fallback_food("almond-croissant", "Almond Croissant", "pastry", 550, "Butter croissant, almond cream.", false),
		_fallback_food("pistachio-croissant", "Pistachio Croissant", "pastry", 650, "Sold out most mornings.", true),
		_fallback_food("plain-croissant", "Plain Croissant", "pastry", 450, "Flaky, heat it if you want.", false),
		_fallback_food("cookie-croissant", "Cookie Croissant", "pastry", 600, "Chocolate-chip cookie crown.", false),
		_fallback_food("strawberry-croissant", "Strawberry Croissant", "pastry", 600, "Fruit pastry croissant.", false),
		_fallback_food("blueberry-roll", "Blueberry Roll", "pastry", 450, "Iced sweet roll.", false),
		_fallback_food("plain-sourdough", "Plain Sourdough", "bread", 800, "Apple-starter loaf.", false),
		_fallback_food("rosemary-sourdough", "Rosemary Sourdough", "bread", 850, "Herb loaf.", false),
		_fallback_food("cheese-garlic-sourdough", "Cheese Garlic Sourdough", "bread", 900, "Savory loaf.", false),
		_fallback_food("milk-bread", "Japanese Milk Bread", "bread", 700, "Soft pull-apart loaf.", true),
		_fallback_food("bbq-chicken-pastry", "BBQ Chicken Pastry", "savory", 850, "Savory hand pie.", false),
		_fallback_food("fajita-steak-pastry", "Fajita Steak Pastry", "savory", 850, "Steak + peppers.", false),
		_fallback_food("powerup-mushroom", "Powerup Mushroom", "savory", 800, "Layered mushroom pastry.", false),
		_fallback_food("cajun-blossom", "Cajun Blossom", "savory", 750, "Spiced savory blossom.", false),
	]


func is_sold_out(item: Dictionary) -> bool:
	if bool(item.get("sold_out", false)) or bool(item.get("is_sold_out", false)):
		return true
	if bool(item.get("unavailable", false)):
		return true
	if item.has("available") and not bool(item.get("available")):
		return true
	if item.has("is_available") and not bool(item.get("is_available")):
		return true
	if item.has("in_stock") and not bool(item.get("in_stock")):
		return true
	var status := str(item.get("status", "")).to_lower()
	if status in ["sold_out", "sold-out", "unavailable", "inactive"]:
		return true
	if item.has("quantity") and int(item.get("quantity", 1)) <= 0:
		return true
	if item.has("inventory") and int(item.get("inventory", 1)) <= 0:
		return true
	return false


func _adopt_catalog(data: Dictionary) -> Dictionary:
	var adopted := data.duplicate(true)
	var list: Array = []
	var raw: Variant = adopted.get("drinks", adopted.get("items", []))
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				list.append(_stamp_availability(entry))
	for extra in bakery_case_items():
		if _catalog_has_name(list, str(extra.get("name", ""))):
			continue
		list.append(extra)
	adopted["drinks"] = list
	return adopted


func _catalog_has_name(list: Array, item_name: String) -> bool:
	var needle := item_name.strip_edges().to_lower()
	if needle == "":
		return false
	for entry in list:
		if entry is Dictionary and str(entry.get("name", "")).strip_edges().to_lower() == needle:
			return true
	return false


func _stamp_availability(item: Dictionary) -> Dictionary:
	var copy := item.duplicate(true)
	copy["sold_out"] = is_sold_out(copy)
	return copy


func _fallback_food(id: String, item_name: String, category: String, cents: int, desc: String, sold_out: bool) -> Dictionary:
	return {
		"id": id,
		"name": item_name,
		"category": category,
		"price_cents": cents,
		"description": desc,
		"sold_out": sold_out,
		"local": true,
		"defaults": {},
		"groups": [],
	}


func _fallback_drink(id: String, drink_name: String, category: String, cents: int, desc: String) -> Dictionary:
	return {
		"id": id,
		"name": drink_name,
		"category": category,
		"price_cents": cents,
		"description": desc,
		"sold_out": false,
		"local": true,
		"defaults": {"sweet": "normal", "ice": "normal", "milk": "dairy"},
		"groups": [
			{
				"id": "sweet",
				"label": "Sweet",
				"type": "single",
				"required": true,
				"options": [
					{"id": "normal", "label": "Normal", "price_cents": 0},
					{"id": "less", "label": "Less", "price_cents": 0},
					{"id": "extra", "label": "Extra sweet", "price_cents": 75},
				],
			},
			{
				"id": "ice",
				"label": "Ice",
				"type": "single",
				"required": true,
				"options": [
					{"id": "normal", "label": "Normal", "price_cents": 0},
					{"id": "less", "label": "Less ice", "price_cents": 0},
					{"id": "hot", "label": "Hot / no ice", "price_cents": 0},
				],
			},
			{
				"id": "milk",
				"label": "Milk",
				"type": "single",
				"required": false,
				"options": [
					{"id": "dairy", "label": "Dairy", "price_cents": 0},
					{"id": "oat", "label": "Oat", "price_cents": 75},
					{"id": "none", "label": "None", "price_cents": 0},
				],
			},
		],
	}


func square_cart_items() -> Array:
	var out: Array = []
	for item in cart.get("items", []):
		if not item is Dictionary:
			continue
		var drink := drink_by_id(str(item.get("id", "")))
		if drink.get("local", false):
			continue
		out.append(item)
	return out


func checkout_payload() -> Dictionary:
	var line_items: Array = square_cart_items()
	if line_items.is_empty():
		line_items = cart.get("items", [])
	return {
		"name": str(cart.get("name", "")).strip_edges(),
		"phone": str(cart.get("phone", "")),
		"pickup": str(cart.get("pickup", "to-go")),
		"items": line_items,
		"tip": checkout_tip(),
	}


func checkout() -> Dictionary:
	var tip_err := tip_error()
	if tip_err != "":
		return {"ok": false, "error": tip_err}
	if square_cart_items().is_empty():
		var local_id := "local-%d" % Time.get_unix_time_from_system()
		last_order_id = local_id
		last_checkout_url = ""
		GameSave.set_active_order_id(local_id)
		return {"ok": true, "data": {"order_id": local_id, "order_number": "", "pay_at_counter": true}}
	var payload := checkout_payload()
	var result := await _request_json(AppConfig.checkout_api(), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if result.get("ok", false):
		var data: Dictionary = result.get("data", {})
		last_order_id = str(data.get("order_id", ""))
		last_checkout_url = str(data.get("url", ""))
		if last_order_id != "":
			GameSave.set_active_order_id(last_order_id)
	return result


func fetch_status(oid: String = "", checkout_id: String = "") -> Dictionary:
	if oid == "":
		oid = last_order_id
	if oid == "":
		oid = GameSave.active_order_id
	var qs := []
	if oid != "":
		qs.append("oid=" + oid.uri_encode())
	if checkout_id != "":
		qs.append("checkoutId=" + checkout_id.uri_encode())
	var url := AppConfig.status_api()
	if qs.size() > 0:
		url += "?" + "&".join(qs)
	var result := await _request_json(url)
	if result.get("ok", false) and result.get("data") is Dictionary:
		last_status = result["data"]
	return result


func fetch_board_tickets(minutes: int = 180) -> Dictionary:
	return await _request_text(AppConfig.board_tickets_api(minutes))


func post_demo_tick(minutes: int = 180) -> Dictionary:
	var headers := PackedStringArray([
		"Accept: text/html",
		"HX-Request: true",
		"HX-Target: ticket-list",
	])
	return await _request_text(AppConfig.board_demo_tick_api(minutes), HTTPClient.METHOD_POST, "", headers)


func fetch_photo(url: String) -> Texture2D:
	if url == "":
		return null
	if photo_cache.has(url):
		return photo_cache[url]
	var result := await _request_bytes(url)
	if not result.get("ok", false):
		return null
	var bytes: PackedByteArray = result.get("bytes", PackedByteArray())
	var image := Image.new()
	var err := image.load_jpg_from_buffer(bytes)
	if err != OK:
		err = image.load_png_from_buffer(bytes)
	if err != OK:
		err = image.load_webp_from_buffer(bytes)
	if err != OK:
		return null
	var tex := ImageTexture.create_from_image(image)
	photo_cache[url] = tex
	return tex


func add_cart_item(drink_id: String, modifiers: Dictionary, qty: int = 1) -> void:
	var drink := drink_by_id(drink_id)
	if not drink.is_empty() and is_sold_out(drink):
		return
	var items: Array = cart.get("items", [])
	items.append({"id": drink_id, "qty": qty, "modifiers": modifiers})
	cart["items"] = items


func clear_cart() -> void:
	cart["items"] = []


func cart_count() -> int:
	var n := 0
	for item in cart.get("items", []):
		if item is Dictionary:
			n += int(item.get("qty", 1))
	return n


func line_cents(item: Dictionary) -> int:
	var drink := drink_by_id(str(item.get("id", "")))
	if drink.is_empty():
		return 0
	var unit := int(drink.get("price_cents", 0))
	var mods: Dictionary = item.get("modifiers", {})
	for group in drink.get("groups", []):
		if not group is Dictionary:
			continue
		var gid := str(group.get("id", ""))
		if str(group.get("type", "")) == "multi":
			var selected: Array = mods.get(gid, [])
			for oid in selected:
				unit += _option_cents(group, str(oid))
		else:
			unit += _option_cents(group, str(mods.get(gid, "")))
	return unit * int(item.get("qty", 1))


func cart_subtotal_cents() -> int:
	var n := 0
	for item in cart.get("items", []):
		if item is Dictionary:
			n += line_cents(item)
	return n


func percent_tip_cents(subtotal: int, percent: int) -> int:
	if percent < 1 or subtotal < 1:
		return 0
	return (subtotal * percent + 50) / 100


func parse_custom_tip_cents(raw: String) -> Variant:
	var text := str(raw).strip_edges()
	if text.begins_with("$"):
		text = text.substr(1)
	text = text.replace(",", "").strip_edges()
	if text.ends_with("c") or text.ends_with("C") or text.ends_with("¢"):
		var core := text.substr(0, text.length() - 1).strip_edges()
		if core.is_empty() or not core.is_valid_int():
			return null
		var as_cents := int(core)
		if as_cents < 0:
			return null
		return as_cents
	if text.is_empty():
		return 0
	if _custom_dollars_re == null:
		_custom_dollars_re = RegEx.new()
		_custom_dollars_re.compile("^\\d+(\\.\\d{0,2})?$")
	if _custom_dollars_re.search(text) == null:
		return null
	return int(round(float(text) * 100.0))


func set_tip_none() -> void:
	cart["tip"] = {"type": "none"}


func set_tip_percent(percent: int) -> void:
	cart["tip"] = {"type": "percent", "percent": percent}


func set_tip_custom() -> void:
	var prev: Dictionary = cart.get("tip", {}) if cart.get("tip") is Dictionary else {}
	cart["tip"] = {
		"type": "custom",
		"amount_input": str(prev.get("amount_input", "")),
		"amount_cents": int(prev.get("amount_cents", 0)),
	}


func set_custom_tip_input(raw: String) -> void:
	var parsed: Variant = parse_custom_tip_cents(raw)
	cart["tip"] = {
		"type": "custom",
		"amount_input": raw,
		"amount_cents": 0 if parsed == null else int(parsed),
	}


func set_tip_custom_cents(cents: int) -> void:
	var safe := maxi(0, cents)
	cart["tip"] = {
		"type": "custom",
		"amount_cents": safe,
		"amount_input": "%.2f" % (safe / 100.0),
	}


func checkout_tip() -> Dictionary:
	var tip: Dictionary = cart.get("tip", {"type": "none"}) if cart.get("tip") is Dictionary else {"type": "none"}
	var kind := str(tip.get("type", "none"))
	if kind == "percent":
		return {"type": "percent", "percent": int(tip.get("percent", 0))}
	if kind == "custom":
		if tip.has("amount_input"):
			var parsed: Variant = parse_custom_tip_cents(str(tip.get("amount_input", "")))
			if parsed == null:
				return {"type": "custom", "amount_cents": -1}
			return {"type": "custom", "amount_cents": int(parsed)}
		if not tip.has("amount_cents"):
			return {"type": "custom", "amount_cents": -1}
		return {"type": "custom", "amount_cents": int(tip.get("amount_cents", -1))}
	return {"type": "none"}


func tip_error() -> String:
	return tip_payload_error(checkout_tip())


func tip_payload_error(tip: Dictionary) -> String:
	var kind := str(tip.get("type", "none"))
	if kind == "none":
		return ""
	if kind == "percent":
		if not TIP_PERCENTS.has(int(tip.get("percent", 0))):
			return "Tip percent must be 15, 18, or 20."
		return ""
	if kind == "custom":
		if not tip.has("amount_cents"):
			return "Enter a custom tip like 1.00, or choose No tip."
		var cents := int(tip.get("amount_cents", -1))
		if cents < 0:
			return "Enter a custom tip like 1.00, or choose No tip."
		if cents > CUSTOM_TIP_MAX_CENTS:
			return "Custom tip max is $100.00."
		return ""
	return "Choose 15%, 18%, 20%, custom, or no tip."


func is_checkout_tip_valid(tip: Dictionary = {}) -> bool:
	var payload: Dictionary = checkout_tip() if tip.is_empty() else tip
	return tip_payload_error(payload) == ""


func tip_cents() -> int:
	var tip: Dictionary = cart.get("tip", {"type": "none"}) if cart.get("tip") is Dictionary else {"type": "none"}
	var kind := str(tip.get("type", "none"))
	if kind == "percent":
		return percent_tip_cents(cart_subtotal_cents(), int(tip.get("percent", 0)))
	if kind == "custom":
		var parsed: Variant = parse_custom_tip_cents(str(tip.get("amount_input", ""))) if tip.has("amount_input") else null
		if parsed == null:
			return maxi(0, int(tip.get("amount_cents", 0)))
		return maxi(0, int(parsed))
	return 0


func cart_total_cents() -> int:
	return cart_subtotal_cents() + tip_cents()


func money(cents: int) -> String:
	return "$%.2f" % (cents / 100.0)


func default_mods(drink: Dictionary) -> Dictionary:
	var mods := {}
	var defaults: Dictionary = drink.get("defaults", {})
	for group in drink.get("groups", []):
		if not group is Dictionary:
			continue
		var gid := str(group.get("id", ""))
		if str(group.get("type", "")) == "multi":
			var preset: Variant = defaults.get(gid, [])
			mods[gid] = preset.duplicate() if preset is Array else []
		elif defaults.has(gid):
			mods[gid] = defaults[gid]
		elif group.get("required", true) == false:
			mods[gid] = ""
		else:
			var options: Array = group.get("options", [])
			mods[gid] = str(options[0].get("id", "")) if options.size() > 0 and options[0] is Dictionary else ""
	return mods


func _option_cents(group: Dictionary, option_id: String) -> int:
	if option_id == "":
		return 0
	for opt in group.get("options", []):
		if opt is Dictionary and str(opt.get("id", "")) == option_id:
			return int(opt.get("price_cents", 0))
	return 0


func _request_json(url: String, method: int = HTTPClient.METHOD_GET, body: String = "", extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var headers := PackedStringArray(["Accept: application/json", "Content-Type: application/json"])
	headers.append_array(extra_headers)
	var raw := await _http(url, method, body, headers)
	if not raw.get("ok", false):
		return raw
	var text := (raw.get("bytes", PackedByteArray()) as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null and text.strip_edges() != "":
		return {"ok": false, "error": "Bad JSON from %s" % url, "code": raw.get("code", 0)}
	var code := int(raw.get("code", 0))
	if code < 200 or code >= 300:
		var err := "HTTP %d" % code
		if parsed is Dictionary and parsed.has("error"):
			err = str(parsed["error"])
		elif parsed is Dictionary and parsed.has("detail"):
			err = str(parsed["detail"])
		return {"ok": false, "error": err, "code": code, "data": parsed}
	return {"ok": true, "code": code, "data": parsed}


func _request_text(url: String, method: int = HTTPClient.METHOD_GET, body: String = "", extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var headers := PackedStringArray(["Accept: text/html"])
	headers.append_array(extra_headers)
	var raw := await _http(url, method, body, headers)
	if not raw.get("ok", false):
		return raw
	var text := (raw.get("bytes", PackedByteArray()) as PackedByteArray).get_string_from_utf8()
	var code := int(raw.get("code", 0))
	if code < 200 or code >= 300:
		return {"ok": false, "error": "HTTP %d" % code, "code": code, "text": text}
	return {"ok": true, "code": code, "text": text}


func _request_bytes(url: String) -> Dictionary:
	return await _http(url, HTTPClient.METHOD_GET, "", PackedStringArray())


func _http(url: String, method: int, body: String, headers: PackedStringArray) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "Could not start request (%s)" % err, "code": 0}
	var completed: Array = await http.request_completed
	http.queue_free()
	var result: int = completed[0]
	var code: int = completed[1]
	var response_body: PackedByteArray = completed[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "Network error %s" % result, "code": code, "bytes": response_body}
	return {"ok": true, "code": code, "bytes": response_body, "result": result}
