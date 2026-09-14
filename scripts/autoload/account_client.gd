extends Node
## Phone Continue → POST bakery-drinks login. Session token if drinks sends one.
## No text-code login. No Square/Twilio secrets. No unauthenticated GET by phone.

signal session_changed

const GUEST := "guest"
const CUSTOMER := "customer"


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
	return GameSave.previous_orders


func skip_as_guest() -> void:
	GameSave.set_account_guest()
	apply_to_cart()
	session_changed.emit()


func logout() -> void:
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
	GameSave.set_square_session(data)
	if token != "":
		GameSave.session_token = token
		GameSave.persist()
	apply_to_cart()
	var name := display_name()
	if name != "":
		GameSave.set_player_name(name)
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
	for method in [HTTPClient.METHOD_POST, HTTPClient.METHOD_PATCH, HTTPClient.METHOD_PUT]:
		result = await _request_json(AppConfig.account_profile_api(), method, body, true)
		var code := int(result.get("code", 0))
		if result.get("ok", false):
			break
		if code == 404 or code == 405:
			continue
		return _account_error(result)
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
	if extra.get("orders") is Array:
		data["orders"] = extra["orders"]
	if extra.get("open_orders") is Array:
		data["open_orders"] = extra["open_orders"]
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
			GameSave.set_previous_orders(data.get("orders", []))
		if data.has("open_orders") and data.get("open_orders") is Array:
			GameSave.open_orders = data.get("open_orders", [])
			GameSave.persist()
		return {"ok": true, "data": data}
	return {"ok": false, "error": "Square status unavailable."}


func reorder(order: Dictionary) -> int:
	var added := 0
	for item in order.get("items", []):
		if not item is Dictionary:
			continue
		var drink := _drink_by_name(str(item.get("name", "")))
		if drink.is_empty():
			continue
		var qty := maxi(1, int(item.get("qty", 1)))
		var mods := _mods_from_history(drink, item)
		OrderClient.add_cart_item(str(drink.get("id", "")), mods, qty)
		added += 1
	apply_to_cart()
	return added


func _drink_by_name(name: String) -> Dictionary:
	var needle := name.strip_edges().to_lower()
	if needle == "":
		return {}
	for drink in OrderClient.drinks():
		if drink is Dictionary and str(drink.get("name", "")).strip_edges().to_lower() == needle:
			return drink
	return {}


func _mods_from_history(drink: Dictionary, item: Dictionary) -> Dictionary:
	return OrderClient.mods_matching_labels(drink, OrderClient.order_item_mod_labels(item))


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
	http.timeout = 20.0
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
