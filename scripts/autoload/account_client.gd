extends Node
## Phone Continue → POST bakery-drinks login. Session token if drinks sends one.
## No text-code login. No Square/Twilio secrets. No unauthenticated GET by phone.

signal session_changed

const GUEST := "guest"
const CUSTOMER := "customer"

## Live drinks GET /order/api/orders (and optional GET /orders/{id}) with Bearer.
var _order_detail_supported := true


func _ready() -> void:
	apply_to_cart()


func normalize_phone(raw: String) -> String:
	var digits := ""
	for ch in raw.strip_edges():
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits.length() == 10:
		return "+1" + digits
	if digits.length() == 11 and digits.begins_with("1"):
		return "+" + digits
	var text := raw.strip_edges()
	if text.begins_with("+") and digits.length() >= 8 and digits.length() <= 15:
		return "+" + digits
	return ""


func format_phone(raw: String) -> String:
	var e164 := normalize_phone(raw)
	if e164.begins_with("+1") and e164.length() == 12:
		var d := e164.substr(2)
		return "(%s) %s-%s" % [d.substr(0, 3), d.substr(3, 3), d.substr(6, 4)]
	return e164 if e164 != "" else raw.strip_edges()


func is_logged_in() -> bool:
	return GameSave.account_mode == CUSTOMER and GameSave.square_customer_id != ""


func has_session_token() -> bool:
	return GameSave.session_token.strip_edges() != ""


func is_guest() -> bool:
	return GameSave.account_mode == GUEST


func should_skip_login() -> bool:
	return is_logged_in() or is_guest()


func display_name() -> String:
	if not is_logged_in():
		return ""
	var nick := GameSave.square_nickname.strip_edges()
	if nick != "":
		return nick
	var given := GameSave.square_given_name.strip_edges()
	var family := GameSave.square_family_name.strip_edges()
	if given != "" and family != "":
		return "%s %s" % [given, family]
	if given != "":
		return given
	if family != "":
		return family
	var stored := GameSave.square_display_name.strip_edges()
	if stored != "":
		return stored
	return ""


func first_name() -> String:
	var given := GameSave.square_given_name.strip_edges()
	if given != "":
		return given
	var full := display_name()
	if full == "":
		return ""
	return full.split(" ")[0]


func has_usable_name() -> bool:
	if GameSave.square_given_name.strip_edges() != "":
		return true
	if GameSave.square_family_name.strip_edges() != "":
		return true
	if GameSave.square_display_name.strip_edges() != "":
		return true
	if GameSave.square_nickname.strip_edges() != "":
		return true
	return false


func needs_profile() -> bool:
	return is_logged_in() and not has_usable_name()


func hello_line() -> String:
	var first := first_name()
	if first != "":
		return "Hi, %s" % first
	if is_logged_in():
		return "Hi there"
	return ""


func is_email_ok(raw: String) -> bool:
	var email := raw.strip_edges()
	if email.length() < 5 or email.find(" ") >= 0:
		return false
	var at := email.find("@")
	if at <= 0 or at >= email.length() - 3:
		return false
	var domain := email.substr(at + 1)
	var dot := domain.find(".")
	return dot > 0 and dot < domain.length() - 1


func profile_error(given_name: String, family_name: String, email: String) -> String:
	if given_name.strip_edges() == "":
		return "First name is required."
	if family_name.strip_edges() == "":
		return "Last name is required."
	if not is_email_ok(email):
		return "Enter an email address."
	return ""


func previous_orders() -> Array:
	if not is_logged_in():
		return []
	return OrderClient.paid_history_orders(GameSave.previous_orders)


func skip_as_guest() -> void:
	GameSave.set_account_guest()
	apply_to_cart()
	session_changed.emit()


func logout() -> void:
	ProfileStore.on_logout()
	GameSave.clear_square_session()
	OrderClient.cart["name"] = ""
	OrderClient.cart["phone"] = ""
	session_changed.emit()


func apply_to_cart() -> void:
	if not is_logged_in():
		return
	var name := display_name()
	if name != "" and str(OrderClient.cart.get("name", "")).strip_edges() == "":
		OrderClient.cart["name"] = name
	var phone := GameSave.square_phone
	if phone != "" and str(OrderClient.cart.get("phone", "")).strip_edges() == "":
		OrderClient.cart["phone"] = phone


func apply_square_payload(data: Dictionary) -> bool:
	if data.is_empty() or not bool(data.get("ok", false)):
		return false
	var token := extract_session_token(data)
	if token != "":
		GameSave.session_token = token
	var customer: Variant = data.get("customer", {})
	if not customer is Dictionary:
		return false
	var cid := str(customer.get("id", "")).strip_edges()
	if cid == "":
		return false
	var orders: Variant = data.get("orders", [])
	if orders is Array:
		data["orders"] = OrderClient.paid_history_orders(OrderClient.hydrate_history_orders(orders))
	var open_orders: Variant = data.get("open_orders", [])
	if open_orders is Array:
		data["open_orders"] = OrderClient.status_queue_orders(OrderClient.hydrate_history_orders(open_orders))
	GameSave.set_square_session(data)
	if token != "":
		GameSave.session_token = token
		GameSave.persist()
	apply_to_cart()
	var name := display_name()
	if name != "":
		GameSave.set_player_name(name)
	ProfileStore.on_login()
	session_changed.emit()
	return true


func extract_session_token(data: Dictionary) -> String:
	for key in ["session_token", "access_token", "auth_token"]:
		var value := str(data.get(key, "")).strip_edges()
		if value != "":
			return value
	var token: Variant = data.get("token")
	if token is String and str(token).strip_edges() != "":
		return str(token).strip_edges()
	var session: Variant = data.get("session")
	if session is String and str(session).strip_edges() != "":
		return str(session).strip_edges()
	if session is Dictionary:
		for key in ["session_token", "access_token", "token", "id"]:
			var inner := str(session.get(key, "")).strip_edges()
			if inner != "":
				return inner
	return ""


func update_profile(given_name: String, family_name: String, email: String) -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "Sign in with phone first."}
	var given := given_name.strip_edges()
	var family := family_name.strip_edges()
	var mail := email.strip_edges()
	var invalid := profile_error(given, family, mail)
	if invalid != "":
		return {"ok": false, "error": invalid}
	if not has_session_token():
		return {
			"ok": false,
			"error": "Square profile update needs a session on bakery-drinks. Glenn: mint session_token on login, then POST /order/api/account/profile.",
		}
	var body := JSON.stringify({
		"given_name": given,
		"family_name": family,
		"email": mail,
		"email_address": mail,
	})
	var result := {}
	for url in _profile_urls():
		for method in [HTTPClient.METHOD_POST, HTTPClient.METHOD_PATCH, HTTPClient.METHOD_PUT]:
			result = await _request_json(url, method, body, true)
			var code := int(result.get("code", 0))
			if result.get("ok", false):
				break
			if code == 404 or code == 405:
				continue
			return _account_error(result)
		if result.get("ok", false):
			break
	if not result.get("ok", false):
		var code := int(result.get("code", 0))
		if code == 404 or code == 405:
			return {
				"ok": false,
				"error": "bakery-drinks has no profile update yet. Glenn: POST /order/api/account/profile with Bearer session + given_name, family_name, email (Square UpdateCustomer).",
				"code": code,
			}
		return _account_error(result)
	var data: Variant = result.get("data", {})
	if not data is Dictionary:
		return {"ok": false, "error": "Square did not update the customer."}
	var header_token := str(result.get("session_token", "")).strip_edges()
	if header_token != "" and extract_session_token(data) == "":
		data["session_token"] = header_token
	if apply_square_payload(data):
		_apply_local_profile(given, family, mail)
		return {"ok": true, "data": data}
	_apply_local_profile(given, family, mail)
	if is_logged_in() and has_usable_name():
		return {"ok": true, "data": data, "local_name": true}
	return {"ok": false, "error": "Square did not update the customer."}


func _apply_local_profile(given: String, family: String, email: String) -> void:
	if given != "":
		GameSave.square_given_name = given
	if family != "":
		GameSave.square_family_name = family
	if email != "":
		GameSave.square_email = email
	if GameSave.square_display_name.strip_edges() == "" and given != "":
		GameSave.square_display_name = ("%s %s" % [given, family]).strip_edges()
	GameSave.persist()
	apply_to_cart()
	var name := display_name()
	if name != "":
		GameSave.set_player_name(name)
	session_changed.emit()


func login_or_signup(phone: String, join_loyalty: bool = true) -> Dictionary:
	var e164 := normalize_phone(phone)
	if e164 == "":
		return {"ok": false, "error": "Enter a US phone number (10 digits)."}
	var body := JSON.stringify({
		"phone": e164,
		"join_loyalty": join_loyalty,
	})
	var result := {}
	for url in _login_post_urls():
		result = await _request_json(url, HTTPClient.METHOD_POST, body, false)
		var code := int(result.get("code", 0))
		if result.get("ok", false):
			break
		if code == 404 or code == 405:
			continue
		return _account_error(result)
	if not result.get("ok", false):
		return _account_error(result)
	var data: Variant = result.get("data", {})
	if not data is Dictionary:
		return {"ok": false, "error": "Square did not return a customer."}
	var header_token := str(result.get("session_token", "")).strip_edges()
	if header_token != "" and extract_session_token(data) == "":
		data["session_token"] = header_token
	data = await _ensure_orders(data)
	if apply_square_payload(data):
		return {"ok": true, "data": data, "created": bool(data.get("created", false))}
	return {"ok": false, "error": "Square did not return a customer."}


func refresh() -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "Not signed in."}
	if not has_session_token():
		return {"ok": true, "cached": true}
	var result := await _session_get(AppConfig.account_api())
	if int(result.get("code", 0)) == 404 or int(result.get("code", 0)) == 405:
		result = await _session_get(AppConfig.session_api())
	if int(result.get("code", 0)) == 404 or int(result.get("code", 0)) == 405:
		result = await _session_get(AppConfig.account_me_api())
	if not result.get("ok", false):
		if int(result.get("code", 0)) in [401, 403]:
			return {"ok": true, "cached": true}
		return _account_error(result)
	var data: Variant = result.get("data", {})
	if not data is Dictionary:
		return {"ok": false, "error": "Square account refresh failed."}
	data = await _ensure_orders(data)
	if apply_square_payload(data):
		return {"ok": true, "data": data}
	return {"ok": true, "cached": true}


func _ensure_orders(data: Dictionary) -> Dictionary:
	var orders: Variant = data.get("orders", [])
	if orders is Array and not orders.is_empty():
		return data
	if not has_session_token() and extract_session_token(data) == "":
		return data
	if extract_session_token(data) != "":
		GameSave.session_token = extract_session_token(data)
	var result := await _session_get(AppConfig.customer_orders_api())
	if not result.get("ok", false) or not result.get("data") is Dictionary:
		return data
	var extra: Dictionary = result["data"]
	var parsed := _orders_from_payload(extra)
	var listed: Array = parsed.get("orders", [])
	var open_listed: Array = parsed.get("open_orders", [])
	if not listed.is_empty():
		data["orders"] = OrderClient.paid_history_orders(OrderClient.hydrate_history_orders(listed))
	if not open_listed.is_empty():
		data["open_orders"] = OrderClient.status_queue_orders(OrderClient.hydrate_history_orders(open_listed))
	return data


func fetch_status() -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "Log in with phone to see your order status."}
	if not has_session_token():
		return {
			"ok": true,
			"cached": true,
			"data": {
				"orders": GameSave.previous_orders,
				"open_orders": GameSave.open_orders,
			},
		}
	var result := await _session_get(AppConfig.account_status_api())
	if int(result.get("code", 0)) == 404 or int(result.get("code", 0)) == 405:
		result = await _session_get(AppConfig.customer_orders_api())
	if int(result.get("code", 0)) == 404 or int(result.get("code", 0)) == 405:
		result = await _session_get(AppConfig.account_api())
	if not result.get("ok", false):
		if int(result.get("code", 0)) in [401, 403]:
			return {
				"ok": true,
				"cached": true,
				"data": {"orders": GameSave.previous_orders, "open_orders": GameSave.open_orders},
			}
		return _account_error(result)
	var data: Variant = result.get("data", {})
	if data is Dictionary:
		if data.has("orders") and data.get("orders") is Array:
			GameSave.set_previous_orders(
				OrderClient.paid_history_orders(OrderClient.hydrate_history_orders(data.get("orders", [])))
			)
		if data.has("open_orders") and data.get("open_orders") is Array:
			var hydrated: Array = OrderClient.hydrate_history_orders(data.get("open_orders", []))
			data["open_orders"] = hydrated
			GameSave.open_orders = OrderClient.status_queue_orders(hydrated)
			GameSave.persist()
		return {"ok": true, "data": data}
	return {"ok": false, "error": "Square status unavailable."}


func fetch_customer_orders() -> Array:
	## Live bakery-drinks GET /order/api/orders with Bearer — no second GCP service.
	if not is_logged_in():
		return []
	if not has_session_token():
		return previous_orders()
	var result := await _session_get(AppConfig.customer_orders_api())
	var code := int(result.get("code", 0))
	if code == 404 or code == 405:
		result = await _session_get(AppConfig.account_api())
	if not result.get("ok", false):
		return previous_orders()
	var parsed := _orders_from_payload(result.get("data", {}))
	var orders: Array = parsed.get("orders", [])
	var open_orders: Array = parsed.get("open_orders", [])
	if orders.is_empty() and open_orders.is_empty():
		return previous_orders()
	orders = OrderClient.paid_history_orders(OrderClient.hydrate_history_orders(orders))
	GameSave.set_previous_orders(orders)
	if not open_orders.is_empty():
		GameSave.open_orders = OrderClient.status_queue_orders(OrderClient.hydrate_history_orders(open_orders))
	GameSave.persist()
	return orders


func fetch_order(order_id: String) -> Dictionary:
	var oid := order_id.strip_edges()
	if oid == "" or not _order_detail_supported:
		return {}
	var saw_missing := false
	for url in [AppConfig.customer_order_api(oid), AppConfig.account_order_api(oid)]:
		var result := await _session_get(url)
		var code := int(result.get("code", 0))
		if code == 404 or code == 405:
			saw_missing = true
			continue
		if not result.get("ok", false):
			continue
		var data: Variant = result.get("data", {})
		if not data is Dictionary:
			continue
		var row: Variant = data.get("order", data)
		if row is Dictionary and (row.has("items") or row.has("line_items") or row.has("_line_items") or row.has("id")):
			var hydrated: Dictionary = OrderClient.hydrate_history_orders([row])[0]
			hydrated["retrieved"] = true
			_store_retrieved_order(hydrated)
			return hydrated
		if data.get("orders") is Array and not (data.get("orders") as Array).is_empty():
			var first: Variant = data["orders"][0]
			if first is Dictionary:
				var hydrated_list: Array = OrderClient.hydrate_history_orders([first])
				hydrated_list[0]["retrieved"] = true
				_store_retrieved_order(hydrated_list[0])
				return hydrated_list[0]
	if saw_missing:
		_order_detail_supported = false
	return {}


func ensure_full_order(order: Dictionary) -> Dictionary:
	if _order_looks_retrieved(order) or not _order_detail_supported:
		return order
	var oid := str(order.get("id", order.get("order_id", ""))).strip_edges()
	if oid == "":
		return order
	var full := await fetch_order(oid)
	if full.is_empty():
		return order
	return full


func ensure_previous_orders_retrieved() -> Array:
	## Drinks GET /order/api/orders is the source of truth (SearchOrders + enriched `_line_items`).
	var rows: Array = await fetch_customer_orders()
	if rows.is_empty():
		rows = previous_orders()
	var out: Array = []
	for row in rows:
		if not row is Dictionary:
			continue
		out.append(await ensure_full_order(row))
	if not out.is_empty():
		out = OrderClient.paid_history_orders(out)
		GameSave.set_previous_orders(out)
		GameSave.persist()
	return out


func _orders_from_payload(data: Variant) -> Dictionary:
	var orders: Array = []
	var open_orders: Array = []
	if data is Array:
		orders = data
	elif data is Dictionary:
		if data.get("orders") is Array:
			orders = data["orders"]
		elif data.get("data") is Array:
			orders = data["data"]
		if data.get("open_orders") is Array:
			open_orders = data["open_orders"]
	return {"orders": orders, "open_orders": open_orders}


func _order_looks_retrieved(order: Dictionary) -> bool:
	if bool(order.get("retrieved", false)):
		return true
	for item in order.get("items", []):
		if not item is Dictionary:
			continue
		var mods: Variant = item.get("modifiers", null)
		if mods is Array:
			return true
		if item.has("modifiers") and str(item.get("catalog_object_id", "")).strip_edges() != "":
			return true
	return false


func _store_retrieved_order(order: Dictionary) -> void:
	if order.is_empty() or not OrderClient.is_paid_history_order(order):
		return
	var oid := str(order.get("id", "")).strip_edges()
	var rows: Array = GameSave.previous_orders.duplicate()
	var found := false
	for i in rows.size():
		if not rows[i] is Dictionary:
			continue
		if str(rows[i].get("id", "")).strip_edges() == oid and oid != "":
			rows[i] = order
			found = true
			break
	if not found:
		rows.insert(0, order)
	GameSave.set_previous_orders(rows)
	GameSave.persist()


func reorder(order: Dictionary) -> Dictionary:
	## Pack §10: replace the entire cart with currently available lines.
	var seq := OrderClient.begin_reorder()
	if OrderClient.drinks().is_empty():
		var menu_res: Dictionary = await OrderClient.fetch_menu()
		if not menu_res.get("ok", false) and OrderClient.drinks().is_empty():
			OrderClient.finish_reorder()
			return {
				"ok": false,
				"replaced": false,
				"items": OrderClient.cart.get("items", []),
				"skipped": [],
				"reduced": [],
				"message": "",
				"error": OrderClient.REORDER_FAIL,
			}
	var full: Dictionary = await ensure_full_order(order)
	if full.is_empty() and not order.is_empty():
		full = order
	var result := OrderClient.replace_cart_from_order(full, seq, true)
	OrderClient.finish_reorder()
	if result.get("ok", false):
		apply_to_cart()
	return result


func request_account_json(
	url: String,
	method: int = HTTPClient.METHOD_GET,
	body: String = "",
	use_session: bool = true
) -> Dictionary:
	return await _request_json(url, method, body, use_session)


func _drink_by_name(name: String) -> Dictionary:
	return OrderClient.catalog_item_for_history({"name": name})


func _mods_from_history(drink: Dictionary, item: Dictionary) -> Dictionary:
	return OrderClient.mods_matching_labels(drink, OrderClient.order_item_mod_match_keys(item))


func _profile_urls() -> PackedStringArray:
	var urls := PackedStringArray()
	for url in [AppConfig.account_profile_api(), AppConfig.customer_profile_api()]:
		if str(url).strip_edges() == "":
			continue
		var seen := false
		for existing in urls:
			if existing == url:
				seen = true
				break
		if not seen:
			urls.append(url)
	return urls


func _login_post_urls() -> PackedStringArray:
	var urls := PackedStringArray()
	for url in [
		AppConfig.account_login_api(),
		AppConfig.login_api(),
		AppConfig.session_api(),
		AppConfig.account_phone_api(),
		AppConfig.customer_api(),
	]:
		if str(url).strip_edges() == "":
			continue
		var seen := false
		for existing in urls:
			if existing == url:
				seen = true
				break
		if not seen:
			urls.append(url)
	return urls


func _session_get(url: String) -> Dictionary:
	return await _request_json(url, HTTPClient.METHOD_GET, "", true)


func _account_error(result: Dictionary) -> Dictionary:
	var code := int(result.get("code", 0))
	var err := str(result.get("error", "Square account unavailable."))
	if code == 404:
		err = "Square login is not on bakery-drinks yet. Skip still works."
	elif code == 401 or code == 403:
		if err.to_lower().find("insufficient") >= 0:
			err = "Square token needs CUSTOMERS_READ, CUSTOMERS_WRITE, ORDERS_READ (and LOYALTY_WRITE to enroll)."
		elif not has_session_token():
			err = str(result.get("error", "Sign-in was rejected. Skip still works."))
	return {"ok": false, "error": err, "code": code}


func _request_json(
	url: String,
	method: int = HTTPClient.METHOD_GET,
	body: String = "",
	use_session: bool = true
) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 12.0
	http.use_threads = true
	add_child(http)
	var headers := PackedStringArray([
		"Accept: application/json",
		"Content-Type: application/json",
	])
	if use_session:
		var token := GameSave.session_token.strip_edges()
		if token != "":
			headers.append("Authorization: Bearer " + token)
			headers.append("X-Session-Token: " + token)
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "Could not start request (%s)" % err, "code": 0}
	var completed: Array = await http.request_completed
	http.queue_free()
	var result: int = completed[0]
	var code: int = completed[1]
	var response_headers: PackedStringArray = completed[2]
	var response_body: PackedByteArray = completed[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "Network error %s" % result, "code": code}
	var text := response_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null and text.strip_edges() != "":
		return {"ok": false, "error": "Bad JSON from account service.", "code": code}
	var header_token := _token_from_headers(response_headers)
	if code < 200 or code >= 300:
		var message := "HTTP %d" % code
		if parsed is Dictionary and parsed.has("error"):
			message = str(parsed["error"])
		elif parsed is Dictionary and parsed.has("detail"):
			message = str(parsed["detail"])
		return {"ok": false, "error": message, "code": code, "data": parsed}
	return {"ok": true, "code": code, "data": parsed, "session_token": header_token}


func _token_from_headers(headers: PackedStringArray) -> String:
	for raw in headers:
		var line := str(raw)
		var lower := line.to_lower()
		if lower.begins_with("x-session-token:"):
			return line.substr(line.find(":") + 1).strip_edges()
		if lower.begins_with("x-auth-token:"):
			return line.substr(line.find(":") + 1).strip_edges()
	return ""
