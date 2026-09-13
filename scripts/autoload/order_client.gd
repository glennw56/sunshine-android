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
var _square_photos: Dictionary = {}
var _square_aliases: Dictionary = {}
var _square_links: Dictionary = {}
var _square_refreshing: bool = false


func _ready() -> void:
	_load_square_photo_cache()


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
	var drinks_res := await _request_json(AppConfig.menu_api())
	var online_res := await _request_json(
		AppConfig.square_commerce_links(),
		HTTPClient.METHOD_GET,
		"",
		_square_online_headers()
	)
	var list: Array = []
	var pay_mode_live := "off"
	var location := "Irondale"
	if drinks_res.get("ok", false) and drinks_res.get("data") is Dictionary:
		var data: Dictionary = drinks_res["data"]
		pay_mode_live = str(data.get("pay_mode", "square"))
		location = str(data.get("location", location))
		var raw: Variant = data.get("drinks", data.get("items", []))
		if raw is Array:
			for entry in raw:
				if entry is Dictionary:
					var row: Dictionary = _stamp_availability(entry)
					row["offer_source"] = "square"
					list.append(row)
	if online_res.get("ok", false) and online_res.get("data") is Dictionary:
		for extra in _square_online_items(online_res["data"]):
			if _catalog_has_name(list, str(extra.get("name", ""))):
				continue
			list.append(extra)
	if list.is_empty():
		var err := str(
			drinks_res.get("error", "")
			if str(drinks_res.get("error", "")) != ""
			else "Square catalog unavailable."
		)
		menu = {
			"source": "",
			"pay_mode": "off",
			"location": location,
			"drinks": [],
			"catalog_error": err,
		}
		used_fallback = false
		menu_failed.emit(err)
		menu_loaded.emit(menu)
		return {"ok": false, "error": err, "data": menu}
	menu = _apply_square_photos({
		"source": "square",
		"pay_mode": pay_mode_live,
		"location": location,
		"drinks": list,
	})
	menu_loaded.emit(menu)
	_refresh_square_online()
	return {"ok": true, "data": menu}


func empty_catalog(error_text: String = "Square catalog unavailable.") -> Dictionary:
	return {
		"source": "",
		"pay_mode": "off",
		"drinks": [],
		"catalog_error": error_text,
	}


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
	## Live Square rows only. Never merge a hand-authored bakery case.
	var adopted := data.duplicate(true)
	var list: Array = []
	var raw: Variant = adopted.get("drinks", adopted.get("items", []))
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				list.append(_stamp_availability(entry))
	adopted["drinks"] = list
	return adopted


func _square_online_items(payload: Dictionary) -> Array:
	var out: Array = []
	var products: Variant = payload.get("products", {})
	if not products is Dictionary:
		return out
	for entry in products.values():
		if not entry is Dictionary:
			continue
		var item_name := str(entry.get("name", "")).strip_edges()
		if item_name == "":
			continue
		var item := {
			"id": str(entry.get("site_product_id", item_name)),
			"name": item_name,
			"category": _ui_category(item_name, ""),
			"description": "",
			"sold_out": false,
			"offer_source": "square",
			"square_online": true,
			"site_link": str(entry.get("site_link", "")),
			"defaults": {},
			"groups": [],
		}
		var mapped := square_photo_for(item)
		if mapped != "":
			item["photo"] = mapped
		out.append(item)
	return out


func _ui_category(item_name: String, existing: String) -> String:
	var have := existing.strip_edges().to_lower()
	if have in ["coffee", "tea", "pastry", "bread", "savory", "more"]:
		return have
	var n := item_name.strip_edges().to_lower()
	if n.find("coffee") >= 0 or n.find("latte") >= 0 or n.find("espresso") >= 0:
		return "coffee"
	if n.find("tea") >= 0 or n.find("lemonade") >= 0 or n == "water":
		return "tea"
	if n.find("sourdough") >= 0 or n.find("bread") >= 0 or n.find("loaf") >= 0:
		return "bread"
	if (
		n.find("cajun") >= 0
		or n.find("steak") >= 0
		or n.find("fajita") >= 0
		or n.find("ham") >= 0
		or n.find("turkey") >= 0
		or n.find("sausage") >= 0
		or n.find("pizza") >= 0
		or n.find("savory") >= 0
	):
		return "savory"
	if n.find("tote") >= 0 or n.find("bag") >= 0 or n.find("merch") >= 0:
		return "more"
	return "pastry"


func has_square_price(item: Dictionary) -> bool:
	return item.has("price_cents") and not bool(item.get("square_online", false))


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


func _load_square_photo_cache() -> void:
	var path := "res://assets/generated/menu/square_photos.json"
	if not FileAccess.file_exists(path):
		return
	var fh := FileAccess.open(path, FileAccess.READ)
	if fh == null:
		return
	var parsed: Variant = JSON.parse_string(fh.get_as_text())
	if not parsed is Dictionary:
		return
	var aliases: Variant = parsed.get("aliases", {})
	if aliases is Dictionary:
		for key in aliases.keys():
			_square_aliases[str(key).strip_edges().to_lower()] = str(aliases[key]).strip_edges().to_lower()
	var photos: Variant = parsed.get("photos", {})
	if photos is Dictionary:
		for key in photos.keys():
			var url := str(photos[key]).strip_edges()
			if _is_square_photo_url(url):
				_square_photos[str(key).strip_edges().to_lower()] = url
	for entry in parsed.get("items", []):
		if not entry is Dictionary:
			continue
		var url := str(entry.get("photo", "")).strip_edges()
		if not _is_square_photo_url(url):
			continue
		var item_name := str(entry.get("name", "")).strip_edges()
		if item_name == "":
			continue
		_square_photos[item_name.to_lower()] = url
		var link := str(entry.get("site_link", "")).strip_edges()
		if link != "":
			_square_links[item_name.to_lower()] = link


func _is_square_photo_url(url: String) -> bool:
	if not url.begins_with("https://"):
		return false
	if url.find("items-images-production.s3") >= 0 or url.find("items-images-sandbox.s3") >= 0:
		return true
	if url.find("cdn6.editmysite.com/uploads/") >= 0:
		return true
	return false


func _photo_key(item: Dictionary) -> String:
	return str(item.get("name", "")).strip_edges().to_lower()


func square_photo_for(item: Dictionary) -> String:
	var keys: Array[String] = []
	var item_name := _photo_key(item)
	if item_name != "":
		keys.append(item_name)
	var item_id := str(item.get("id", "")).strip_edges().to_lower().replace("-", " ")
	if item_id != "" and not keys.has(item_id):
		keys.append(item_id)
	for key in keys:
		if _square_photos.has(key):
			return str(_square_photos[key])
		if _square_aliases.has(key):
			var alias := str(_square_aliases[key])
			if _square_photos.has(alias):
				return str(_square_photos[alias])
	return ""


func placeholder_photo(_item: Dictionary = {}) -> String:
	## Neutral tile only. Never invent a cartoon croissant as the product photo.
	return "res://assets/generated/menu/no_photo.png"


func item_photo_url(item: Dictionary) -> String:
	var photo := str(item.get("photo", "")).strip_edges()
	if _is_square_photo_url(photo):
		return photo
	var mapped := square_photo_for(item)
	if mapped != "":
		return mapped
	if photo.begins_with("res://assets/generated/menu/no_photo.png"):
		return photo
	return placeholder_photo(item)


func _apply_square_photos(data: Dictionary) -> Dictionary:
	var adopted := data.duplicate(true)
	var list: Array = []
	var raw: Variant = adopted.get("drinks", adopted.get("items", []))
	if raw is Array:
		for entry in raw:
			if not entry is Dictionary:
				continue
			var copy: Dictionary = entry.duplicate(true)
			var mapped := square_photo_for(copy)
			var existing := str(copy.get("photo", "")).strip_edges()
			if _is_square_photo_url(existing):
				pass
			elif mapped != "":
				copy["photo"] = mapped
			elif existing.begins_with("res://") and existing.find("no_photo") < 0:
				copy["photo"] = placeholder_photo(copy)
			list.append(copy)
	adopted["drinks"] = list
	return adopted


func _refresh_square_online() -> void:
	if _square_refreshing:
		return
	_square_refreshing = true
	var result := await _request_json(
		AppConfig.square_commerce_links(),
		HTTPClient.METHOD_GET,
		"",
		_square_online_headers()
	)
	if result.get("ok", false) and result.get("data") is Dictionary:
		var products: Variant = result["data"].get("products", {})
		if products is Dictionary:
			for entry in products.values():
				if not entry is Dictionary:
					continue
				var item_name := str(entry.get("name", "")).strip_edges()
				var link := str(entry.get("site_link", "")).strip_edges()
				if item_name != "" and link != "":
					_square_links[item_name.to_lower()] = link
					_square_aliases[item_name.to_lower()] = item_name.to_lower()
	for item in drinks():
		if not item is Dictionary:
			continue
		if _is_square_photo_url(str(item.get("photo", ""))):
			continue
		if square_photo_for(item) != "":
			continue
		var key := _photo_key(item)
		var link := str(_square_links.get(key, ""))
		if link == "" and _square_aliases.has(key):
			link = str(_square_links.get(str(_square_aliases[key]), ""))
		if link == "":
			continue
		var page := AppConfig.square_online_origin() + link
		var html_res := await _request_text(page)
		if not html_res.get("ok", false):
			continue
		var photo := _og_image_from_html(str(html_res.get("text", "")))
		if _is_square_photo_url(photo):
			_square_photos[key] = photo
	menu = _apply_square_photos(menu)
	_square_refreshing = false
	menu_loaded.emit(menu)


func _square_online_headers() -> PackedStringArray:
	return PackedStringArray([
		"Referer: https://www.sunshinebakeshop.com/",
		"User-Agent: SunshineBakery/0.1.7",
	])


func _og_image_from_html(html: String) -> String:
	var re := RegEx.new()
	if re.compile("property=\"og:image\"\\s+content=\"([^\"]+)\"") != OK:
		return ""
	var found := re.search(html)
	if found:
		return found.get_string(1).strip_edges()
	return ""


func square_cart_items() -> Array:
	var out: Array = []
	for item in cart.get("items", []):
		if not item is Dictionary:
			continue
		var drink := drink_by_id(str(item.get("id", "")))
		if drink.is_empty() or bool(drink.get("square_online", false)):
			continue
		if not has_square_price(drink):
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
		last_checkout_url = AppConfig.order_url()
		return {
			"ok": false,
			"error": "Square checkout needs a live drink from the Square menu. Use Web for other Square items.",
			"url": last_checkout_url,
		}
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
