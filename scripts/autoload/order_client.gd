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
	return drink_by_any_id(id)


func drink_by_any_id(id: String) -> Dictionary:
	var needle := id.strip_edges()
	if needle == "":
		return {}
	for item in drinks():
		if not item is Dictionary:
			continue
		for field in ["id", "catalog_object_id", "square_id", "site_product_id"]:
			if str(item.get(field, "")).strip_edges() == needle:
				return item
	return {}


func catalog_item_for_history(item: Dictionary) -> Dictionary:
	for field in ["catalog_object_id", "id", "variation_id", "item_id"]:
		var hit := drink_by_any_id(str(item.get(field, "")))
		if not hit.is_empty():
			return hit
	var name := str(item.get("name", "")).strip_edges()
	var variation := str(item.get("variation_name", "")).strip_edges()
	var hit := _drink_by_name_exact(name)
	if hit.is_empty() and variation != "":
		hit = _drink_by_name_exact("%s %s" % [name, variation])
	if hit.is_empty() and variation != "":
		hit = _drink_by_name_exact(variation)
	if hit.is_empty():
		hit = _drink_by_name_fuzzy(name)
	return hit


func _drink_by_name_exact(name: String) -> Dictionary:
	var needle := name.strip_edges().to_lower()
	if needle == "":
		return {}
	for drink in drinks():
		if drink is Dictionary and str(drink.get("name", "")).strip_edges().to_lower() == needle:
			return drink
	return {}


func _drink_by_name_fuzzy(name: String) -> Dictionary:
	var needle := name.strip_edges().to_lower()
	if needle == "":
		return {}
	var matches: Array = []
	for drink in drinks():
		if not drink is Dictionary:
			continue
		var label := str(drink.get("name", "")).strip_edges().to_lower()
		if label == "":
			continue
		if label.find(needle) >= 0 or needle.find(label) >= 0:
			matches.append(drink)
	if matches.size() == 1:
		return matches[0]
	return {}


func pay_mode() -> String:
	return str(menu.get("pay_mode", "off"))


func catalog_source() -> String:
	return str(menu.get("source", ""))


func fetch_menu() -> Dictionary:
	used_fallback = false
	var drinks_res := await _request_json(AppConfig.menu_api())
	var store_items: Array = await _fetch_all_square_store_items()
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
	for extra in store_items:
		if _catalog_has_name(list, str(extra.get("name", ""))):
			_merge_store_into_named(list, extra)
			continue
		list.append(extra)
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
	if item.has("quantity") and _as_count(item.get("quantity", 1)) <= 0:
		return true
	if item.has("inventory") and _as_count(item.get("inventory", 1)) <= 0:
		return true
	return false


func _as_count(value: Variant) -> int:
	if value is Dictionary:
		for key in ["quantity", "available", "count", "in_stock"]:
			if value.has(key):
				return _as_count(value.get(key, 1))
		return 1
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	if typeof(value) == TYPE_STRING and str(value).is_valid_int():
		return int(str(value))
	return 1


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


func _fetch_all_square_store_items() -> Array:
	## Square Online paginates; page 1 is not guaranteed to be the whole catalog.
	var all: Array = []
	var page := 1
	var total_pages := 1
	while page <= total_pages and page <= 20:
		var url := "%s&page=%d" % [AppConfig.square_store_catalog(), page]
		var store_res := await _request_json(
			url,
			HTTPClient.METHOD_GET,
			"",
			_square_online_headers()
		)
		if not store_res.get("ok", false) or not (store_res.get("data") is Dictionary):
			break
		var payload: Dictionary = store_res["data"]
		all.append_array(_square_store_items(payload))
		total_pages = 1
		var meta: Variant = payload.get("meta", {})
		if meta is Dictionary:
			var pag: Variant = meta.get("pagination", {})
			if pag is Dictionary:
				total_pages = maxi(1, int(pag.get("total_pages", 1)))
		page += 1
	return all


func _square_store_items(payload: Dictionary) -> Array:
	## Square Online storefront products. Price lives on price.low_subunits
	## (and SKU/variation maps) — not on commerce-links.
	## Modifier lists live on modifiers.data[] (Reheat, Tote Designs/Color, drink extras).
	var out: Array = []
	var rows: Variant = payload.get("data", [])
	if not rows is Array:
		return out
	for entry in rows:
		if not entry is Dictionary:
			continue
		var item_name := str(entry.get("name", "")).strip_edges()
		if item_name == "":
			continue
		var item := {
			"id": str(entry.get("site_product_id", entry.get("square_id", item_name))),
			"name": item_name,
			"category": _ui_category(item_name, ""),
			"description": str(entry.get("short_description", "")),
			"sold_out": _square_store_sold_out(entry),
			"offer_source": "square",
			"square_online": true,
			"site_link": str(entry.get("site_link", "")),
			"catalog_object_id": str(entry.get("square_id", "")),
			"defaults": _defaults_from_entry(entry),
			"groups": _square_groups_from_entry(entry),
		}
		var cents := _square_price_cents(entry)
		if cents >= 0:
			item["price_cents"] = cents
		var photo := _square_store_photo(entry)
		if photo != "":
			item["photo"] = photo
		else:
			var mapped := square_photo_for(item)
			if mapped != "":
				item["photo"] = mapped
		out.append(_stamp_availability(item))
	return out


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
			"defaults": _defaults_from_entry(entry),
			"groups": _square_groups_from_entry(entry),
		}
		var cents := _square_price_cents(entry)
		if cents >= 0:
			item["price_cents"] = cents
		var mapped := square_photo_for(item)
		if mapped != "":
			item["photo"] = mapped
		out.append(_stamp_availability(item))
	return out


func _square_price_cents(entry: Dictionary) -> int:
	## Parse Square money into cents. -1 means Square sent no amount.
	var from_price := _cents_from_square_price_map(entry.get("price", {}))
	if from_price >= 0:
		return from_price
	if entry.has("price_cents"):
		return int(entry.get("price_cents", -1))
	for key in ["skus", "variations", "item_variations"]:
		var c := _cents_from_square_rows(entry.get(key, null))
		if c >= 0:
			return c
	var options: Variant = entry.get("options", entry.get("item_options", null))
	var from_opts := _cents_from_square_rows(options)
	if from_opts >= 0:
		return from_opts
	return -1


func _cents_from_square_rows(bucket: Variant) -> int:
	var rows: Array = []
	if bucket is Dictionary:
		var data: Variant = bucket.get("data", [])
		if data is Array:
			rows = data
		elif bucket.has("price") or bucket.has("price_cents"):
			rows = [bucket]
	elif bucket is Array:
		rows = bucket
	for row in rows:
		if not row is Dictionary:
			continue
		var c := _cents_from_square_price_map(row.get("price", {}))
		if c >= 0:
			return c
		if row.has("price_cents"):
			return int(row.get("price_cents", -1))
		if row.has("price_money") and row.get("price_money") is Dictionary:
			var money: Dictionary = row["price_money"]
			if money.has("amount"):
				return int(money.get("amount", -1))
	return -1


func _cents_from_square_price_map(price: Variant) -> int:
	if not price is Dictionary:
		return -1
	var map: Dictionary = price
	for key in [
		"low_subunits",
		"regular_low_subunits",
		"current_subunits",
		"high_subunits",
		"regular_high_subunits",
	]:
		if map.has(key) and map.get(key) != null:
			return int(map.get(key, -1))
	for nest_key in ["low", "current", "high", "regular"]:
		var nest: Variant = map.get(nest_key, null)
		if nest is Dictionary and nest.has("amount") and nest.get("amount") != null:
			return int(nest.get("amount", -1))
	return -1


func _square_store_sold_out(entry: Dictionary) -> bool:
	var badges: Variant = entry.get("badges", {})
	if badges is Dictionary and bool(badges.get("out_of_stock", false)):
		return true
	return is_sold_out(entry)


func _square_store_photo(entry: Dictionary) -> String:
	var images: Variant = entry.get("images", {})
	var rows: Array = []
	if images is Dictionary:
		var data: Variant = images.get("data", [])
		if data is Array:
			rows = data
	elif images is Array:
		rows = images
	for img in rows:
		if not img is Dictionary:
			continue
		for key in ["url", "absolute_url"]:
			var url := str(img.get(key, "")).strip_edges()
			if _is_square_photo_url(url):
				return url
	var thumb: Variant = entry.get("thumbnail", {})
	if thumb is Dictionary:
		var turl := str(thumb.get("url", thumb.get("absolute_url", ""))).strip_edges()
		if _is_square_photo_url(turl):
			return turl
	return ""


func _merge_store_into_named(list: Array, extra: Dictionary) -> void:
	## Copy Square Online price (if drinks omitted it) and any extra modifier groups.
	## Keep bakery-drinks group/option ids so checkout still matches Square catalog objects.
	var needle := str(extra.get("name", "")).strip_edges().to_lower()
	for entry in list:
		if not entry is Dictionary:
			continue
		if str(entry.get("name", "")).strip_edges().to_lower() != needle:
			continue
		if extra.has("price_cents") and not entry.has("price_cents"):
			entry["price_cents"] = int(extra.get("price_cents", 0))
		if bool(extra.get("sold_out", false)):
			entry["sold_out"] = true
		entry["groups"] = _merge_group_arrays(entry.get("groups", []), extra.get("groups", []))
		var defaults: Variant = entry.get("defaults", {})
		if not defaults is Dictionary:
			defaults = {}
		var inferred := _defaults_from_groups(entry.get("groups", []))
		for key in inferred.keys():
			if not defaults.has(key):
				defaults[key] = inferred[key]
		entry["defaults"] = defaults
		return


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
	## True when Square (drinks API or Online store catalog) sent an amount.
	return item.has("price_cents")


func display_price(item: Dictionary) -> String:
	if has_square_price(item):
		return money(int(item.get("price_cents", 0)))
	return "—"


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
	copy["groups"] = _square_groups_from_entry(copy)
	var defaults: Variant = copy.get("defaults", {})
	if not defaults is Dictionary:
		defaults = {}
	var inferred := _defaults_from_groups(copy.get("groups", []))
	for key in inferred.keys():
		if not defaults.has(key):
			defaults[key] = inferred[key]
	copy["defaults"] = defaults
	return copy


func _as_mod_array(value: Variant) -> Array:
	if value is Array:
		return value
	if value is Dictionary:
		var data: Variant = value.get("data", value.get("objects", value.get("items", [])))
		if data is Array:
			return data
		if (
			value.has("choices")
			or value.has("options")
			or value.has("modifiers")
			or str(value.get("name", "")).strip_edges() != ""
			or str(value.get("label", "")).strip_edges() != ""
		):
			return [value]
	return []


func _square_groups_from_entry(entry: Dictionary) -> Array:
	## Every Square modifier list on the item — optional and required, drinks and food.
	var raw_groups: Array = _as_mod_array(entry.get("groups", []))
	if raw_groups.is_empty():
		raw_groups = _as_mod_array(entry.get("modifiers", []))
	if raw_groups.is_empty():
		raw_groups = _as_mod_array(entry.get("modifier_lists", []))
	if raw_groups.is_empty():
		raw_groups = _as_mod_array(entry.get("modifier_list_info", []))
	var out: Array = []
	var seen: Dictionary = {}
	for g in raw_groups:
		if not g is Dictionary:
			continue
		var row := _normalize_group(g)
		if row.is_empty():
			continue
		var key := str(row.get("id", "")).strip_edges().to_lower()
		var lab := str(row.get("label", "")).strip_edges().to_lower()
		if key != "" and seen.has(key):
			continue
		if lab != "" and seen.has("l:" + lab):
			continue
		out.append(row)
		if key != "":
			seen[key] = true
		if lab != "":
			seen["l:" + lab] = true
	return out


func _normalize_group(g: Dictionary) -> Dictionary:
	var options_raw: Array = _as_mod_array(g.get("options", []))
	if options_raw.is_empty():
		options_raw = _as_mod_array(g.get("choices", []))
	if options_raw.is_empty():
		options_raw = _as_mod_array(g.get("modifiers", []))
	var options: Array = []
	for opt in options_raw:
		if not opt is Dictionary:
			continue
		var row := _normalize_option(opt)
		if not row.is_empty():
			options.append(row)
	if options.is_empty():
		return {}
	var label := str(g.get("label", g.get("name", "Options"))).strip_edges()
	if label == "":
		label = "Options"
	var gid := str(
		g.get("id", g.get("catalog_object_id", g.get("square_id", g.get("site_modifier_set_id", label))))
	).strip_edges()
	if gid == "":
		gid = label
	var min_sel := int(g.get("min_selected", g.get("min", g.get("min_selected_modifiers", 0))))
	var max_sel := int(g.get("max_selected", g.get("max", g.get("max_selected_modifiers", 0))))
	var required := min_sel > 0 or bool(g.get("required", false))
	var gtype := str(g.get("type", "")).strip_edges().to_lower()
	if gtype == "single" or gtype == "radio" or max_sel == 1:
		gtype = "single"
	else:
		gtype = "multi"
	return {
		"id": gid,
		"label": label,
		"type": gtype,
		"required": required,
		"min_selected": min_sel,
		"max_selected": max_sel,
		"options": options,
	}


func _normalize_option(opt: Dictionary) -> Dictionary:
	if bool(opt.get("hidden", false)):
		return {}
	var label := _choice_name(opt)
	if label == "":
		return {}
	var oid := str(
		opt.get("id", opt.get("catalog_object_id", opt.get("square_id", opt.get("site_modifier_set_choice_id", label))))
	).strip_edges()
	if oid == "":
		oid = label
	return {
		"id": oid,
		"label": label,
		"price_cents": _choice_price_cents(opt),
		"sold_out": bool(opt.get("sold_out", opt.get("is_sold_out", false))),
		"selected_by_default": bool(opt.get("selected_by_default", false)),
	}


func _choice_name(choice: Dictionary) -> String:
	for key in ["name", "label", "display_name"]:
		var s := str(choice.get(key, "")).strip_edges()
		if s != "":
			return s
	return ""


func _choice_price_cents(choice: Dictionary) -> int:
	if choice.has("price_cents"):
		return maxi(0, int(choice.get("price_cents", 0)))
	var money: Variant = choice.get("price_money", choice.get("amount_money", {}))
	if money is Dictionary and money.has("amount"):
		return maxi(0, int(money.get("amount", 0)))
	var raw: Variant = choice.get("price", 0)
	if raw is Dictionary:
		if raw.has("amount"):
			return maxi(0, int(raw.get("amount", 0)))
		if raw.has("low_subunits"):
			return maxi(0, int(raw.get("low_subunits", 0)))
		raw = raw.get("value", 0)
	if typeof(raw) == TYPE_STRING:
		var text := str(raw).strip_edges().replace("$", "")
		if text.is_valid_float():
			raw = float(text)
		else:
			return 0
	var f := float(raw)
	if f == 0.0:
		return 0
	## Square Online modifier prices are dollars (0.75, 1.25). Integers >= 50 are already cents.
	if typeof(raw) == TYPE_FLOAT or abs(f - round(f)) > 0.001:
		return int(round(f * 100.0))
	var n := int(round(f))
	if n > 0 and n < 50:
		return n * 100
	return n


func _defaults_from_entry(entry: Dictionary) -> Dictionary:
	var defaults: Variant = entry.get("defaults", {})
	if defaults is Dictionary and not defaults.is_empty():
		return defaults
	return _defaults_from_groups(_square_groups_from_entry(entry))


func _defaults_from_groups(groups: Array) -> Dictionary:
	var defaults := {}
	for g in groups:
		if not g is Dictionary:
			continue
		var gid := str(g.get("id", "")).strip_edges()
		if gid == "":
			continue
		var picked: Array = []
		for opt in g.get("options", []):
			if opt is Dictionary and bool(opt.get("selected_by_default", false)):
				picked.append(str(opt.get("id", "")))
		if picked.is_empty():
			continue
		if str(g.get("type", "")) == "multi":
			defaults[gid] = picked
		else:
			defaults[gid] = str(picked[0])
	return defaults


func _merge_group_arrays(prefer: Array, extra: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for src in [prefer, extra]:
		if not src is Array:
			continue
		for g in src:
			if not g is Dictionary:
				continue
			var row := _normalize_group(g)
			if row.is_empty():
				continue
			var key := str(row.get("id", "")).strip_edges().to_lower()
			var lab := str(row.get("label", "")).strip_edges().to_lower()
			var existing: Dictionary = {}
			if key != "" and seen.has(key):
				existing = seen[key]
			elif lab != "" and seen.has("l:" + lab):
				existing = seen["l:" + lab]
			if not existing.is_empty():
				existing["options"] = _merge_option_arrays(existing.get("options", []), row.get("options", []))
				continue
			out.append(row)
			if key != "":
				seen[key] = row
			if lab != "":
				seen["l:" + lab] = row
	return out


func _merge_option_arrays(prefer: Array, extra: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for src in [prefer, extra]:
		if not src is Array:
			continue
		for opt in src:
			if not opt is Dictionary:
				continue
			var row: Dictionary = _normalize_option(opt)
			if row.is_empty():
				continue
			var key := str(row.get("id", "")).strip_edges().to_lower()
			var lab := str(row.get("label", "")).strip_edges().to_lower()
			if key != "" and seen.has(key):
				continue
			if lab != "" and seen.has("l:" + lab):
				continue
			out.append(row)
			if key != "":
				seen[key] = true
			if lab != "":
				seen["l:" + lab] = true
	return out


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
		"User-Agent: SunshineBakery/0.1.30",
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
	var payload := {
		"name": str(cart.get("name", "")).strip_edges(),
		"phone": str(cart.get("phone", "")),
		"pickup": str(cart.get("pickup", "to-go")),
		"items": line_items,
		"tip": checkout_tip(),
	}
	if GameSave.square_customer_id != "":
		payload["customer_id"] = GameSave.square_customer_id
	if GameSave.session_token.strip_edges() != "":
		payload["session_token"] = GameSave.session_token.strip_edges()
	return payload


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


func add_cart_item(
	drink_id: String,
	modifiers: Dictionary,
	qty: int = 1,
	history_labels: PackedStringArray = PackedStringArray(),
	force: bool = false
) -> bool:
	var drink := drink_by_id(drink_id)
	if drink_id.strip_edges() == "":
		return false
	if not force and not drink.is_empty() and is_sold_out(drink):
		return false
	var items: Array = cart.get("items", [])
	var row := {"id": drink_id, "qty": qty, "modifiers": modifiers}
	if history_labels.size() > 0:
		row["mod_labels"] = history_labels
	items.append(row)
	cart["items"] = items
	return true


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


func line_mod_labels(item: Dictionary) -> PackedStringArray:
	var labels := PackedStringArray()
	var drink := drink_by_id(str(item.get("id", "")))
	var mods: Variant = item.get("modifiers", {})
	if drink.is_empty() or typeof(mods) != TYPE_DICTIONARY:
		return order_item_mod_labels(item)
	for group in drink.get("groups", []):
		if not group is Dictionary:
			continue
		var gid := str(group.get("id", ""))
		var picked: PackedStringArray = PackedStringArray()
		if str(group.get("type", "")) == "multi":
			var selected: Array = mods.get(gid, [])
			for oid in selected:
				var lab := _option_priced_label(group, str(oid))
				if lab != "":
					picked.append(lab)
		else:
			var lab := _option_priced_label(group, str(mods.get(gid, "")))
			if lab != "":
				picked.append(lab)
		if picked.is_empty():
			continue
		var group_label := str(group.get("label", "")).strip_edges()
		if group_label != "" and picked.size() == 1:
			labels.append("%s: %s" % [group_label, picked[0]])
		elif group_label != "":
			labels.append("%s: %s" % [group_label, " · ".join(picked)])
		else:
			for lab in picked:
				labels.append(lab)
	if labels.is_empty():
		var stored: Variant = item.get("mod_labels", [])
		if stored is PackedStringArray:
			return stored
		if stored is Array:
			var fallback := PackedStringArray()
			for lab in stored:
				var bit := str(lab).strip_edges()
				if bit != "":
					fallback.append(bit)
			if not fallback.is_empty():
				return fallback
		return order_item_mod_labels(item)
	return labels


func line_mod_summary(item: Dictionary) -> String:
	return " · ".join(line_mod_labels(item))


func visible_mod_line(item: Dictionary) -> String:
	## Customer-facing extras. Never invent Square modifiers.
	var summary := history_mod_line(item)
	if summary.strip_edges() != "":
		return summary
	summary = line_mod_summary(item)
	if summary.strip_edges() != "":
		return summary
	## Cart lines and catalog-backed rows use a group-id dictionary (possibly empty).
	if item.get("modifiers") is Dictionary or str(item.get("id", "")).strip_edges() != "":
		return "No extras"
	if _history_has_modifier_field(item):
		return "No extras"
	## Live bakery-drinks currently omits the modifiers key even when Square had extras.
	## Do not print "No extras" for that missing field — that is a false negative.
	return "Extras not listed on this ticket"


func history_mod_line(item: Dictionary) -> String:
	var raw: Variant = item.get("modifiers", item.get("mods", []))
	if not raw is Array:
		return ""
	var drink := catalog_item_for_history(item)
	if drink.is_empty():
		return order_item_mod_summary(item)
	var labels := PackedStringArray()
	var seen := {}
	for row in raw:
		var name := ""
		var oid := ""
		var extra := 0
		if row is String:
			name = str(row).strip_edges()
		elif row is Dictionary:
			name = str(row.get("name", row.get("label", row.get("display_name", "")))).strip_edges()
			oid = str(row.get("id", row.get("catalog_object_id", ""))).strip_edges()
			extra = int(row.get("price_cents", 0))
			if extra <= 0:
				extra = _history_money_cents(row)
			if extra <= 0 and row.has("price"):
				extra = _choice_price_cents(row)
		var mapped := _history_mod_to_group_label(drink, name, oid)
		if mapped == "":
			mapped = name
		if mapped == "":
			continue
		if extra > 0:
			mapped = "%s · %s" % [mapped, money(extra)]
		if seen.has(mapped):
			continue
		seen[mapped] = true
		labels.append(mapped)
	if labels.is_empty():
		return order_item_mod_summary(item)
	return " · ".join(labels)


func _history_mod_to_group_label(drink: Dictionary, name: String, oid: String) -> String:
	var needle := _mod_match_needle(name)
	var id_needle := oid.strip_edges().to_lower()
	for group in drink.get("groups", []):
		if not group is Dictionary:
			continue
		var group_label := str(group.get("label", "")).strip_edges()
		for opt in group.get("options", []):
			if not opt is Dictionary:
				continue
			var label := str(opt.get("label", "")).strip_edges()
			var opt_id := str(opt.get("id", "")).strip_edges()
			var catalog_id := str(opt.get("catalog_object_id", "")).strip_edges()
			if id_needle != "" and (opt_id.to_lower() == id_needle or catalog_id.to_lower() == id_needle):
				return "%s: %s" % [group_label, label] if group_label != "" else label
			if needle != "" and label.strip_edges().to_lower() == needle:
				return "%s: %s" % [group_label, label] if group_label != "" else label
	return ""


func _history_has_modifier_field(item: Dictionary) -> bool:
	for key in [
		"modifiers", "mods", "mod_labels", "line_item_modifiers", "applied_modifiers",
		"customizations", "modifier_list", "extras", "options", "selected_modifiers", "modifiers_data",
	]:
		if item.has(key):
			return true
	if str(item.get("detail", "")).strip_edges() != "":
		return true
	if str(item.get("note", "")).strip_edges() != "":
		return true
	return false


func hydrate_history_orders(orders: Array) -> Array:
	var out: Array = []
	for order in orders:
		if order is Dictionary:
			out.append(_hydrate_history_order(order))
		else:
			out.append(order)
	return out


func _hydrate_history_order(order: Dictionary) -> Dictionary:
	var copy := order.duplicate(true)
	var items: Array = []
	for it in _history_line_bucket(copy):
		if it is Dictionary:
			items.append(_hydrate_history_item(it))
	copy["items"] = items
	return copy


func _history_line_bucket(order: Dictionary) -> Array:
	## Live bakery-drinks may keep a thin `items` list and stash Square extras on `_line_items`.
	var best: Array = []
	var best_score := -1
	for key in ["_line_items", "line_items", "items"]:
		var bucket: Variant = order.get(key, null)
		if not bucket is Array or (bucket as Array).is_empty():
			continue
		var score := _history_items_richness(bucket as Array)
		if score > best_score:
			best = bucket as Array
			best_score = score
	return best


func _history_items_richness(items: Array) -> int:
	var score := items.size()
	for it in items:
		if not it is Dictionary:
			continue
		if it.has("modifiers") or it.has("mods") or it.has("line_item_modifiers") or it.has("applied_modifiers") or it.has("extras") or it.has("options") or it.has("selected_modifiers"):
			score += 10
			var mods: Variant = it.get("modifiers", it.get("mods", it.get("line_item_modifiers", it.get("extras", []))))
			if mods is Array:
				score += mods.size() * 5
			elif mods is Dictionary and not mods.is_empty():
				score += 5
		if str(it.get("catalog_object_id", it.get("catalog_id", ""))).strip_edges() != "":
			score += 2
		if it.has("base_price_money") or it.has("total_money") or it.has("total_price_money"):
			score += 1
	return score


func _hydrate_history_item(item: Dictionary) -> Dictionary:
	var copy := item.duplicate(true)
	for key in [
		"line_item_modifiers",
		"applied_modifiers",
		"customizations",
		"modifier_list",
		"extras",
		"options",
		"selected_modifiers",
		"modifiers_data",
	]:
		if copy.has(key) and not copy.has("modifiers"):
			copy["modifiers"] = copy.get(key)
	if copy.has("modifiers") or copy.has("mods"):
		copy["modifiers"] = _normalize_history_mods(copy.get("modifiers", copy.get("mods", [])))
	if str(copy.get("catalog_object_id", "")).strip_edges() == "":
		for key in ["catalog_id", "item_variation_id", "variation_id"]:
			var oid := str(copy.get(key, "")).strip_edges()
			if oid != "":
				copy["catalog_object_id"] = oid
				break
	copy["qty"] = _history_qty(copy)
	var detail := str(copy.get("detail", copy.get("note", ""))).strip_edges()
	if detail != "" and str(copy.get("detail", "")).strip_edges() == "":
		copy["detail"] = detail
	if int(copy.get("price_cents", 0)) <= 0:
		var cents := _history_money_cents(copy)
		if cents > 0:
			copy["price_cents"] = cents
	return copy


func _history_qty(item: Dictionary) -> int:
	var q: Variant = item.get("qty", item.get("quantity", 1))
	if q is String:
		var text := str(q).strip_edges()
		if text == "":
			return 1
		return maxi(1, int(float(text)))
	return maxi(1, int(q))


func _normalize_history_mods(raw: Variant) -> Array:
	var rows: Array = []
	if raw is Dictionary:
		var nested: Variant = raw.get("data", raw.get("modifiers", raw.get("items", [])))
		if nested is Array:
			raw = nested
		else:
			raw = [raw]
	if raw is Array:
		for row in raw:
			var parsed := _normalize_history_mod_row(row)
			if not parsed.is_empty():
				rows.append(parsed)
	elif raw is String and str(raw).strip_edges() != "":
		rows.append({"name": str(raw).strip_edges()})
	return rows


func _normalize_history_mod_row(row: Variant) -> Dictionary:
	if row is String:
		var label := str(row).strip_edges()
		return {"name": label} if label != "" else {}
	if not row is Dictionary:
		return {}
	var blob: Dictionary = row
	var name := str(
		blob.get("name", blob.get("label", blob.get("display_name", blob.get("detail", ""))))
	).strip_edges()
	if name == "":
		return {}
	var out := {"name": name}
	var oid := str(blob.get("catalog_object_id", blob.get("id", blob.get("uid", "")))).strip_edges()
	if oid != "":
		out["id"] = oid
		out["catalog_object_id"] = oid
	var cents := int(blob.get("price_cents", 0))
	if cents <= 0:
		cents = _history_money_cents(blob)
	if cents > 0:
		out["price_cents"] = cents
	return out


func _history_money_cents(blob: Dictionary) -> int:
	if int(blob.get("price_cents", 0)) > 0:
		return int(blob.get("price_cents", 0))
	for key in ["total_price_money", "base_price_money", "total_money", "gross_sales_money"]:
		var money: Variant = blob.get(key, null)
		if money is Dictionary and int(money.get("amount", 0)) > 0:
			return int(money.get("amount", 0))
	return 0


func available_mod_preview(drink: Dictionary) -> String:
	var names := PackedStringArray()
	for group in drink.get("groups", []):
		if not group is Dictionary:
			continue
		var label := str(group.get("label", "")).strip_edges()
		if label != "":
			names.append(label)
	return " · ".join(names)


func cart_bar_text() -> String:
	var items: Array = cart.get("items", [])
	if items.is_empty():
		return "0 items · $0.00"
	var lines := PackedStringArray()
	var shown := 0
	for item in items:
		if not item is Dictionary:
			continue
		if shown >= 3:
			lines.append("+ more in Cart")
			break
		var drink := drink_by_id(str(item.get("id", "")))
		var name := str(drink.get("name", item.get("id", "Item")))
		var qty := int(item.get("qty", 1))
		lines.append("%s × %d · %s" % [name, qty, visible_mod_line(item)])
		shown += 1
	lines.append("%d item%s · %s" % [cart_count(), "" if cart_count() == 1 else "s", money(cart_total_cents())])
	return "\n".join(lines)


func order_item_mod_labels(item: Dictionary) -> PackedStringArray:
	var labels := PackedStringArray()
	var raw: Variant = item.get("modifiers", item.get("mods", []))
	if raw is Array:
		for row in raw:
			var name := ""
			if row is String:
				name = str(row).strip_edges()
			elif row is Dictionary:
				name = str(row.get("name", row.get("label", row.get("display_name", row.get("detail", ""))))).strip_edges()
				var extra := int(row.get("price_cents", 0))
				if extra <= 0:
					extra = _history_money_cents(row)
				if extra <= 0 and row.has("price"):
					extra = _choice_price_cents(row)
				if name != "" and extra > 0:
					name = "%s · %s" % [name, money(extra)]
			if name != "":
				labels.append(name)
	elif raw is Dictionary:
		for key in raw.keys():
			var val: Variant = raw[key]
			if val is Array:
				for oid in val:
					var n := str(oid).strip_edges()
					if n != "":
						labels.append(n)
			else:
				var n := str(val).strip_edges()
				if n != "":
					labels.append(n)
	var detail := str(item.get("detail", item.get("note", ""))).strip_edges()
	if (labels.is_empty() or _labels_look_like_ids(labels)) and detail != "":
		var from_detail := PackedStringArray()
		for part in detail.split("·"):
			var bit := part.strip_edges()
			if bit != "":
				from_detail.append(bit)
		if not from_detail.is_empty():
			return from_detail
	return labels


func order_item_mod_summary(item: Dictionary) -> String:
	return " · ".join(order_item_mod_labels(item))


func order_item_mod_match_keys(item: Dictionary) -> PackedStringArray:
	var keys := order_item_mod_labels(item)
	var raw: Variant = item.get("modifiers", item.get("mods", []))
	if raw is Array:
		for row in raw:
			if row is Dictionary:
				for field in ["id", "catalog_object_id"]:
					var oid := str(row.get(field, "")).strip_edges()
					if oid != "":
						keys.append(oid)
	return keys


func mods_matching_labels(drink: Dictionary, names: PackedStringArray) -> Dictionary:
	var mods := default_mods(drink)
	if names.is_empty() or drink.is_empty():
		return mods
	var needles: Array = []
	for n in names:
		var bit := _mod_match_needle(str(n))
		if bit != "":
			needles.append(bit)
			var colon := bit.rfind(": ")
			if colon >= 0 and colon + 2 < bit.length():
				needles.append(bit.substr(colon + 2))
	for group in drink.get("groups", []):
		if not group is Dictionary:
			continue
		var gid := str(group.get("id", ""))
		var picked: Array = []
		for opt in group.get("options", []):
			if not opt is Dictionary:
				continue
			var label := str(opt.get("label", "")).strip_edges().to_lower()
			var oid := str(opt.get("id", "")).strip_edges().to_lower()
			for needle in needles:
				if needle == label or needle == oid:
					picked.append(str(opt.get("id", "")))
					break
				if needle.length() >= 4 and label.find(needle) >= 0:
					picked.append(str(opt.get("id", "")))
					break
		if picked.is_empty():
			continue
		if str(group.get("type", "")) == "multi":
			mods[gid] = picked
		else:
			mods[gid] = str(picked[0])
	return mods


func example_checkout_mods(drink: Dictionary) -> Dictionary:
	var wanted := PackedStringArray(["Oat milk", "50%", "Tapioca Boba", "Less Ice"])
	var mods := mods_matching_labels(drink, wanted)
	var probe := {"id": str(drink.get("id", "")), "modifiers": mods, "qty": 1}
	if line_mod_summary(probe) != "":
		return mods
	var filled := 0
	for group in drink.get("groups", []):
		if not group is Dictionary or filled >= 3:
			continue
		var options: Array = group.get("options", [])
		if options.is_empty() or not options[0] is Dictionary:
			continue
		var gid := str(group.get("id", ""))
		var oid := str(options[0].get("id", ""))
		if oid == "":
			continue
		if str(group.get("type", "")) == "multi":
			mods[gid] = [oid]
		else:
			mods[gid] = oid
		filled += 1
	return mods


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


func _labels_look_like_ids(labels: PackedStringArray) -> bool:
	if labels.is_empty():
		return false
	for lab in labels:
		var bit := str(lab).strip_edges()
		if bit.length() < 16 or bit.find(" ") >= 0 or bit.find(":") >= 0:
			return false
	return true


func _mod_match_needle(raw: String) -> String:
	var bit := raw.strip_edges().to_lower()
	var cut := bit.find(" · $")
	if cut >= 0:
		bit = bit.substr(0, cut)
	return bit.strip_edges()


func _option_priced_label(group: Dictionary, option_id: String) -> String:
	var lab := _option_label(group, option_id)
	if lab == "":
		return ""
	var extra := _option_cents(group, option_id)
	if extra > 0:
		return "%s · %s" % [lab, money(extra)]
	return lab


func _option_cents(group: Dictionary, option_id: String) -> int:
	if option_id == "":
		return 0
	for opt in group.get("options", []):
		if opt is Dictionary and str(opt.get("id", "")) == option_id:
			return int(opt.get("price_cents", 0))
	return 0


func _option_label(group: Dictionary, option_id: String) -> String:
	if option_id == "":
		return ""
	for opt in group.get("options", []):
		if opt is Dictionary and str(opt.get("id", "")) == option_id:
			return str(opt.get("label", option_id)).strip_edges()
	return ""


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
