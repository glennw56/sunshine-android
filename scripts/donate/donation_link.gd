extends RefCounted
class_name DonationLink
## Existing Square donation payment link. Do not invent another checkout URL.

const DEFAULT_URL := "https://square.link/u/9tUzPJZQ"
const DEFAULT_GOAL_CENTS := 1000000 ## Square page: $10,000.00
const NAME_QUERY_KEY := "name"


static func checkout_url(base_url: String, donor_name: String = "") -> String:
	var url := base_url.strip_edges()
	if url == "":
		url = DEFAULT_URL
	var name := donor_name.strip_edges()
	if name == "":
		return url
	## Square static links ignore extra query keys. GET still serves the donate page.
	var sep := "&" if url.find("?") >= 0 else "?"
	return "%s%s%s=%s" % [url, sep, NAME_QUERY_KEY, name.uri_encode()]


static func parse_square_html(html: String) -> Dictionary:
	var empty := {
		"ok": false,
		"live": false,
		"raised_cents": 0,
		"goal_cents": DEFAULT_GOAL_CENTS,
		"title": "",
		"description": "",
	}
	var marker := "window.bootstrap = "
	var start := html.find(marker)
	if start < 0:
		return empty
	start += marker.length()
	var end := html.find(";", start)
	if end < 0:
		return empty
	var raw := html.substr(start, end - start).strip_edges()
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return empty
	var data: Dictionary = parsed
	var raised := _intish(data.get("donationGoalProgress", 0))
	var goal := DEFAULT_GOAL_CENTS
	var title := ""
	var description := ""
	var link: Variant = data.get("checkoutLink", {})
	if link is Dictionary:
		var link_data: Variant = (link as Dictionary).get("checkout_link_data", {})
		if link_data is Dictionary:
			title = str(link_data.get("name", "")).strip_edges()
			description = str(link_data.get("description", "")).strip_edges()
			var donation_goal: Variant = link_data.get("donation_goal", {})
			if donation_goal is Dictionary:
				var target: Variant = donation_goal.get("target", {})
				if target is Dictionary:
					var amount := _intish(target.get("amount", 0))
					if amount > 0:
						goal = amount
	return {
		"ok": true,
		"live": true,
		"raised_cents": maxi(0, raised),
		"goal_cents": maxi(1, goal),
		"title": title,
		"description": description,
	}


static func money(cents: int) -> String:
	return "$%.2f" % (cents / 100.0)


static func progress_ratio(raised_cents: int, goal_cents: int) -> float:
	if goal_cents <= 0:
		return 0.0
	return clampf(float(raised_cents) / float(goal_cents), 0.0, 1.0)


static func _intish(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and str(value).is_valid_int():
		return int(value)
	return 0
