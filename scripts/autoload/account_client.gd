extends Node
## Square customer session via bakery-drinks /order/api/account (token stays server-side).
## No local customer directory — login/signup only from Square-backed HTTP.

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


func hello_line() -> String:
	var name := display_name()
	if name != "":
		return "Hi, %s" % name
	if is_logged_in():
		return "Hi there"
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
	var customer: Variant = data.get("customer", {})
	if not customer is Dictionary:
		return false
	var cid := str(customer.get("id", "")).strip_edges()
	if cid == "":
		return false
	GameSave.set_square_session(data)
	apply_to_cart()
	var name := display_name()
	if name != "":
		GameSave.set_player_name(name)
	session_changed.emit()
	return true


func login_or_signup(phone: String, join_loyalty: bool = true) -> Dictionary:
	var e164 := normalize_phone(phone)
	if e164 == "":
		return {"ok": false, "error": "Enter a US phone number (10 digits)."}
	var body := JSON.stringify({
		"phone": e164,
		"join_loyalty": join_loyalty,
	})
	var result := await _request_json(AppConfig.account_phone_api(), HTTPClient.METHOD_POST, body)
	if not result.get("ok", false):
		return _account_error(result)
	var data: Variant = result.get("data", {})
	if data is Dictionary and apply_square_payload(data):
		return {"ok": true, "data": data, "created": bool(data.get("created", false))}
	return {"ok": false, "error": "Square did not return a customer."}


func refresh() -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "Not signed in."}
	var qs := "customer_id=%s&phone=%s" % [
		GameSave.square_customer_id.uri_encode(),
		GameSave.square_phone.uri_encode(),
	]
	var result := await _request_json(AppConfig.account_api() + "?" + qs)
	if not result.get("ok", false):
		return _account_error(result)
	var data: Variant = result.get("data", {})
	if data is Dictionary and apply_square_payload(data):
		return {"ok": true, "data": data}
	return {"ok": false, "error": "Square account refresh failed."}


func fetch_status() -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "Log in with phone to see your order status."}
	var qs := "customer_id=%s&phone=%s" % [
		GameSave.square_customer_id.uri_encode(),
		GameSave.square_phone.uri_encode(),
	]
	var result := await _request_json(AppConfig.account_status_api() + "?" + qs)
	if not result.get("ok", false):
		return _account_error(result)
	var data: Variant = result.get("data", {})
	if data is Dictionary:
		if data.has("orders") and data.get("orders") is Array:
			GameSave.set_previous_orders(data.get("orders", []))
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
		OrderClient.add_cart_item(str(drink.get("id", "")), {}, qty)
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


func _account_error(result: Dictionary) -> Dictionary:
	var code := int(result.get("code", 0))
	var err := str(result.get("error", "Square account unavailable."))
	if code == 404:
		err = "Phone login is not on the drinks service yet. Skip for now, or ask staff to deploy the Square account routes."
	return {"ok": false, "error": err, "code": code}


func _request_json(url: String, method: int = HTTPClient.METHOD_GET, body: String = "") -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	var err := http.request(
		url,
		PackedStringArray(["Accept: application/json", "Content-Type: application/json"]),
		method,
		body
	)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "Could not start request (%s)" % err, "code": 0}
	var completed: Array = await http.request_completed
	http.queue_free()
	var result: int = completed[0]
	var code: int = completed[1]
	var response_body: PackedByteArray = completed[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "Network error %s" % result, "code": code}
	var text := response_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null and text.strip_edges() != "":
		return {"ok": false, "error": "Bad JSON from account service.", "code": code}
	if code < 200 or code >= 300:
		var message := "HTTP %d" % code
		if parsed is Dictionary and parsed.has("error"):
			message = str(parsed["error"])
		return {"ok": false, "error": message, "code": code, "data": parsed}
	return {"ok": true, "code": code, "data": parsed}
