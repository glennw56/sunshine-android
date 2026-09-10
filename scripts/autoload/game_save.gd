extends Node
## Stamp card, weekly finder leaderboard, staff tip jar, shop-device flag.

const SAVE_PATH := "user://sunshine_save.json"
const STAMPS_FOR_DRINK := 8

var player_name: String = "Guest"
var stamps: int = 0
var free_drinks_earned: int = 0
var finds_this_week: int = 0
var week_key: String = ""
var staff_tips: int = 0
var staff_tips_week: int = 0
var shop_device: bool = false
var active_order_id: String = ""
var last_ready_order_id: String = ""
var leaderboard: Array = []
var local_staff_tickets: Array = []


func _ready() -> void:
	_load()
	_roll_week_if_needed()


func _week_key_now() -> String:
	var now := Time.get_datetime_dict_from_system()
	# ISO-ish week bucket: year + week-of-year from unix.
	var unix := Time.get_unix_time_from_system()
	var week := int(floor((unix + 259200.0) / 604800.0)) # shift so week starts Monday-ish
	return "%04d-W%02d" % [int(now.year), week % 100]


func _roll_week_if_needed() -> void:
	var current := _week_key_now()
	if week_key != current:
		week_key = current
		finds_this_week = 0
		staff_tips_week = 0
		for row in leaderboard:
			if row is Dictionary:
				row["finds"] = 0
		_save()


func add_find(amount: int = 1) -> Dictionary:
	_roll_week_if_needed()
	finds_this_week += amount
	stamps += amount
	var free := false
	if stamps >= STAMPS_FOR_DRINK:
		stamps -= STAMPS_FOR_DRINK
		free_drinks_earned += 1
		free = true
	_upsert_board(player_name, finds_this_week)
	_save()
	return {"stamps": stamps, "free": free, "finds": finds_this_week, "free_total": free_drinks_earned}


func add_staff_tip(amount: int = 1) -> int:
	_roll_week_if_needed()
	staff_tips += amount
	staff_tips_week += amount
	_save()
	return staff_tips_week


func set_player_name(value: String) -> void:
	player_name = value.strip_edges()
	if player_name == "":
		player_name = "Guest"
	_upsert_board(player_name, finds_this_week)
	_save()


func set_shop_device(on: bool) -> void:
	shop_device = on
	_save()


func set_active_order_id(oid: String) -> void:
	active_order_id = oid
	_save()


func mark_order_ready_seen(oid: String) -> void:
	last_ready_order_id = oid
	_save()


func add_local_ticket(ticket: Dictionary) -> void:
	local_staff_tickets.append(ticket)
	_save()


func update_local_ticket(id: String, status: String) -> Dictionary:
	for ticket in local_staff_tickets:
		if ticket is Dictionary and str(ticket.get("id", "")) == id:
			ticket["status"] = status
			_save()
			return ticket
	return {}


func weekly_board() -> Array:
	_roll_week_if_needed()
	var rows: Array = leaderboard.duplicate()
	rows.sort_custom(func(a, b): return int(a.get("finds", 0)) > int(b.get("finds", 0)))
	return rows


func _upsert_board(name: String, finds: int) -> void:
	for row in leaderboard:
		if row is Dictionary and str(row.get("name", "")) == name:
			row["finds"] = finds
			row["week"] = week_key
			return
	leaderboard.append({"name": name, "finds": finds, "week": week_key})


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		player_name = str(parsed.get("player_name", player_name))
		stamps = int(parsed.get("stamps", 0))
		free_drinks_earned = int(parsed.get("free_drinks_earned", 0))
		finds_this_week = int(parsed.get("finds_this_week", 0))
		week_key = str(parsed.get("week_key", ""))
		staff_tips = int(parsed.get("staff_tips", 0))
		staff_tips_week = int(parsed.get("staff_tips_week", 0))
		shop_device = bool(parsed.get("shop_device", false))
		active_order_id = str(parsed.get("active_order_id", ""))
		last_ready_order_id = str(parsed.get("last_ready_order_id", ""))
		leaderboard = parsed.get("leaderboard", [])
		local_staff_tickets = parsed.get("local_staff_tickets", [])


func _save() -> void:
	var payload := {
		"player_name": player_name,
		"stamps": stamps,
		"free_drinks_earned": free_drinks_earned,
		"finds_this_week": finds_this_week,
		"week_key": week_key,
		"staff_tips": staff_tips,
		"staff_tips_week": staff_tips_week,
		"shop_device": shop_device,
		"active_order_id": active_order_id,
		"last_ready_order_id": last_ready_order_id,
		"leaderboard": leaderboard,
		"local_staff_tickets": local_staff_tickets,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "\t"))
