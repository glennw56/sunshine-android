extends Object
class_name DonationLink
## Fixed Square donation checkout. Do not invent another pay URL.
## Live totals: bakery-drinks GET /order/api/donations, then Square's public
## checkout page for goal/raised. Donor names need the drinks Payments route.

const SQUARE_URL := "https://square.link/u/9tUzPJZQ"
const SQUARE_CHECKOUT_PAGE := "https://checkout.square.site/merchant/ML089M4WW1WX2/checkout/5L2X3ONG3NYNAR4WUU2S2SL5"
const DEFAULT_GOAL_CENTS := 50000


static func checkout_url(donor_name: String = "") -> String:
	var name := donor_name.strip_edges()
	if name == "":
		return SQUARE_URL
	## Best-effort note/name on the SAME Square link. Static links ignore
	## unknown query keys and still check out. Blank stays anonymous.
	var enc := name.uri_encode()
	return SQUARE_URL + "?name=" + enc + "&note=" + enc


static func fallback_goal_cents() -> int:
	if AppConfig and int(AppConfig.donate_goal_cents) > 0:
		return int(AppConfig.donate_goal_cents)
	return DEFAULT_GOAL_CENTS


static func money(cents: int) -> String:
	if cents < 0:
		cents = 0
	var dollars := cents / 100
	var rem := cents % 100
	var whole := _comma_int(dollars)
	if rem == 0:
		return "$%s" % whole
	return "$%s.%02d" % [whole, rem]


static func _comma_int(n: int) -> String:
	var sign := ""
	if n < 0:
		sign = "-"
		n = -n
	var raw := str(n)
	var out := ""
	var i := raw.length()
	while i > 3:
		out = "," + raw.substr(i - 3, 3) + out
		i -= 3
	return sign + raw.substr(0, i) + out


static func progress_label(raised_cents: int, goal_cents: int) -> String:
	## Dollar amount raised toward the goal — never a donor count.
	var raised := raised_cents
	if raised < 0:
		raised = 0
	var goal := goal_cents
	if goal <= 0:
		goal = fallback_goal_cents()
	return "Raised %s of %s" % [money(raised), money(goal)]


static func bar_amount_label(raised_cents: int, goal_cents: int) -> String:
	var raised := raised_cents
	if raised < 0:
		raised = 0
	var goal := goal_cents
	if goal <= 0:
		goal = fallback_goal_cents()
	return "%s of %s" % [money(raised), money(goal)]


static func empty_progress() -> Dictionary:
	return {
		"ok": false,
		"source": "loading",
		"goal_cents": fallback_goal_cents(),
		"raised_cents": -1,
		"donor_count": -1,
		"donors": [],
		"title": "",
		"description": "",
		"ratio": 0.0,
	}


static func parse_donations_api(data: Dictionary) -> Dictionary:
	var out := empty_progress()
	if data.is_empty():
		return out
	var goal: int = _as_cents(data.get("goal_cents", 0))
	if goal <= 0:
		goal = fallback_goal_cents()
	out["goal_cents"] = goal
	out["ok"] = bool(data.get("ok", false))
	out["source"] = str(data.get("source", "bakery-drinks"))
	out["title"] = str(data.get("title", ""))
	out["description"] = str(data.get("description", ""))
	var raised: Variant = data.get("raised_cents", null)
	if raised != null:
		out["raised_cents"] = _as_cents(raised)
	var count: Variant = data.get("donor_count", null)
	if count != null:
		out["donor_count"] = _as_cents(count)
	var people: Array = []
	var raw_people: Variant = data.get("donors", [])
	if raw_people is Array:
		for row in raw_people:
			if row is Dictionary:
				people.append({
					"name": str(row.get("name", "Anonymous")).strip_edges(),
					"amount_cents": _as_cents(row.get("amount_cents", 0)),
					"at": str(row.get("at", "")),
				})
	out["donors"] = people
	if int(out["donor_count"]) < 0:
		out["donor_count"] = people.size()
	if int(out["raised_cents"]) >= 0 and goal > 0:
		out["ratio"] = clampf(float(out["raised_cents"]) / float(goal), 0.0, 1.0)
	if str(data.get("url", "")) != "" and str(data.get("url")) != SQUARE_URL:
		## Ignore any other checkout URL from the payload.
		pass
	if out["ok"] or int(out["raised_cents"]) >= 0:
		return out
	return out


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
		out["source"] = "config"
	else:
		out["source"] = "square-public"
		out["ok"] = true
	out["goal_cents"] = goal_cents
	out["title"] = str(data.get("checkoutTitle", link_data.get("name", "")))
	out["description"] = str(link_data.get("description", ""))
	var raised := _raised_cents(data, goal_cents)
	out["raised_cents"] = raised
	if raised >= 0 and goal_cents > 0:
		out["ratio"] = clampf(float(raised) / float(goal_cents), 0.0, 1.0)
	if raised == 0:
		out["donor_count"] = 0
		out["donors"] = []
	else:
		out["donor_count"] = -1
		out["donors"] = []
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
