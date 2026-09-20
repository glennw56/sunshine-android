extends Object
class_name DonationLink
## Fixed Square donation checkout. Do not invent another pay URL.
## Public checkout HTML may include a donation goal; there is no official
## unauthenticated Square API for raised/donors.

const SQUARE_URL := "https://square.link/u/9tUzPJZQ"
const DEFAULT_GOAL_CENTS := 50000


static func checkout_url(donor_name: String = "") -> String:
	var name := donor_name.strip_edges()
	if name == "":
		return SQUARE_URL
	## Best-effort: Square static links ignore unknown query keys and still
	## check out. Name is not an official prefill field (email/phone/address only).
	return SQUARE_URL + "?name=" + name.uri_encode()


static func fallback_goal_cents() -> int:
	if AppConfig and int(AppConfig.donate_goal_cents) > 0:
		return int(AppConfig.donate_goal_cents)
	return DEFAULT_GOAL_CENTS


static func money(cents: int) -> String:
	if cents < 0:
		cents = 0
	var dollars := cents / 100
	var rem := cents % 100
	if rem == 0:
		return "$%d" % dollars
	return "$%d.%02d" % [dollars, rem]


static func empty_progress() -> Dictionary:
	return {
		"ok": false,
		"source": "placeholder",
		"goal_cents": fallback_goal_cents(),
		"raised_cents": -1,
		"donors": -1,
		"title": "",
		"description": "",
		"ratio": 0.0,
	}


static func parse_bootstrap_html(html: String) -> Dictionary:
	var out := empty_progress()
	var blob := _extract_bootstrap_json(html)
	if blob == "":
		return out
	var parsed: Variant = JSON.parse_string(blob)
	if not parsed is Dictionary:
		return out
	return parse_bootstrap(parsed as Dictionary)


static func parse_bootstrap(data: Dictionary) -> Dictionary:
	var out := empty_progress()
	var link: Dictionary = data.get("checkoutLink", {})
	if not link is Dictionary:
		link = {}
	var link_data: Dictionary = link.get("checkout_link_data", {})
	if not link_data is Dictionary:
		link_data = {}
	var goal: Dictionary = link_data.get("donation_goal", {})
	if not goal is Dictionary:
		goal = {}
	var target: Dictionary = goal.get("target", {})
	if not target is Dictionary:
		target = {}
	var goal_cents := _as_cents(target.get("amount", 0))
	if goal_cents <= 0:
		goal_cents = fallback_goal_cents()
	else:
		out["source"] = "square"
		out["ok"] = true
	out["goal_cents"] = goal_cents
	out["title"] = str(data.get("checkoutTitle", link_data.get("name", "")))
	out["description"] = str(link_data.get("description", ""))
	var raised := _raised_cents(data, goal_cents)
	out["raised_cents"] = raised
	if raised >= 0 and goal_cents > 0:
		out["ratio"] = clampf(float(raised) / float(goal_cents), 0.0, 1.0)
	out["donors"] = _donor_count(data)
	if out["ok"] and raised < 0:
		## Goal came from Square but raised was not published.
		out["source"] = "square-goal"
	return out


static func _raised_cents(data: Dictionary, goal_cents: int) -> int:
	if not data.has("donationGoalProgress"):
		return -1
	var raw: Variant = data.get("donationGoalProgress")
	if raw == null:
		return -1
	if raw is float or raw is int:
		var n := float(raw)
		if n < 0.0:
			return -1
		if n <= 1.0:
			return int(round(n * float(maxi(goal_cents, 0))))
		return int(round(n))
	return -1


static func _donor_count(data: Dictionary) -> int:
	for key in ["donationDonorCount", "donorCount", "donors", "supporter_count"]:
		if data.has(key):
			var n := _as_cents(data.get(key))
			if n >= 0:
				return n
	var link: Dictionary = data.get("checkoutLink", {})
	if link is Dictionary:
		var link_data: Dictionary = link.get("checkout_link_data", {})
		if link_data is Dictionary:
			for key in ["donor_count", "donors"]:
				if link_data.has(key):
					var n2 := _as_cents(link_data.get(key))
					if n2 >= 0:
						return n2
	return -1


static func _as_cents(value: Variant) -> int:
	if value is Dictionary:
		return _as_cents((value as Dictionary).get("amount", 0))
	if value is int:
		return value
	if value is float:
		return int(round(value))
	if value is String and str(value).is_valid_int():
		return int(value)
	return 0


static func _extract_bootstrap_json(html: String) -> String:
	var needle := "window.bootstrap"
	var start := html.find(needle)
	if start < 0:
		return ""
	var brace := html.find("{", start)
	if brace < 0:
		return ""
	var depth := 0
	var i := brace
	var in_str := false
	var escape := false
	while i < html.length():
		var ch := html.substr(i, 1)
		if in_str:
			if escape:
				escape = false
			elif ch == "\\":
				escape = true
			elif ch == "\"":
				in_str = false
		else:
			if ch == "\"":
				in_str = true
			elif ch == "{":
				depth += 1
			elif ch == "}":
				depth -= 1
				if depth == 0:
					return html.substr(brace, i - brace + 1)
		i += 1
	return ""
