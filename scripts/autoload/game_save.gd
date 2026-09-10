extends Node
## Stamp card, weekly finder leaderboard, staff tip jar, shop-device flag.
## Fresh Batch hunt uses America/Chicago (Irondale) wall time.

const SAVE_PATH := "user://sunshine_save.json"
const STAMPS_FOR_DRINK := 8
const FRESH_BATCH_START_HOUR := 9
const FRESH_BATCH_END_HOUR := 11
const FRESH_BATCH_BONUS_CAP := 3
const FRESH_BATCH_STAMP_MULT := 2

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
var fresh_batch_day: String = ""
var fresh_batch_bonus_used: int = 0
## Test hook: unix seconds, or -1 to use the system clock.
var debug_unix: int = -1


func _ready() -> void:
	_load()
	_roll_week_if_needed()
	_roll_fresh_batch_day_if_needed()


func now_unix() -> int:
	if debug_unix >= 0:
		return debug_unix
	return int(Time.get_unix_time_from_system())


func chicago_offset_seconds(unix: int = -1) -> int:
	if unix < 0:
		unix = now_unix()
	var year := int(Time.get_datetime_dict_from_unix_time(unix).get("year", 1970))
	# US DST: 2nd Sunday in March 02:00 CST (08:00 UTC) → 1st Sunday in Nov 02:00 CDT (07:00 UTC).
	var start := _unix_utc(year, 3, _nth_sunday_day(year, 3, 2), 8)
	var finish := _unix_utc(year, 11, _nth_sunday_day(year, 11, 1), 7)
	var hours := -5 if unix >= start and unix < finish else -6
	return hours * 3600


func chicago_datetime(unix: int = -1) -> Dictionary:
	if unix < 0:
		unix = now_unix()
	return Time.get_datetime_dict_from_unix_time(unix + chicago_offset_seconds(unix))


func chicago_day_key(unix: int = -1) -> String:
	var d := chicago_datetime(unix)
	return "%04d-%02d-%02d" % [int(d.get("year", 0)), int(d.get("month", 0)), int(d.get("day", 0))]


func is_fresh_batch_active(unix: int = -1) -> bool:
	var mode := _fresh_batch_mode()
	if mode == "force" or mode == "on" or mode == "1":
		return true
	if mode == "off" or mode == "0":
		return false
	var d := chicago_datetime(unix)
	var hour := int(d.get("hour", 0))
	return hour >= FRESH_BATCH_START_HOUR and hour < FRESH_BATCH_END_HOUR


func fresh_batch_bonus_remaining() -> int:
	_roll_fresh_batch_day_if_needed()
	if not is_fresh_batch_active():
		return 0
	return maxi(0, FRESH_BATCH_BONUS_CAP - fresh_batch_bonus_used)


func fresh_batch_hint() -> String:
	if is_fresh_batch_active():
		return "● FRESH BATCH LIVE · extra pastries inside & out · first 3 finds 2× stamps (%d left)" % fresh_batch_bonus_remaining()
	return "Fresh Batch 9–11 America/Chicago morning · extra indoor+outdoor pickups · first 3 finds 2× stamps"


func _fresh_batch_mode() -> String:
	return str(AppConfig.fresh_batch_mode).strip_edges().to_lower()


func _unix_utc(year: int, month: int, day: int, hour: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({
		"year": year, "month": month, "day": day, "hour": hour, "minute": 0, "second": 0
	}))


func _nth_sunday_day(year: int, month: int, n: int) -> int:
	var first := Time.get_datetime_dict_from_unix_time(_unix_utc(year, month, 1, 12))
	var first_wd := int(first.get("weekday", Time.WEEKDAY_SUNDAY))
	return 1 + (Time.WEEKDAY_SUNDAY - first_wd + 7) % 7 + (n - 1) * 7


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


func _roll_fresh_batch_day_if_needed() -> void:
	var key := chicago_day_key()
	if fresh_batch_day != key:
		fresh_batch_day = key
		fresh_batch_bonus_used = 0
		_save()


func add_find(amount: int = 1) -> Dictionary:
	return _apply_find(amount, amount)


func record_explore_find() -> Dictionary:
	## One weekly-board find. Stamp card gets 2× for the first 3 Fresh Batch pickups.
	_roll_fresh_batch_day_if_needed()
	var stamp_delta := 1
	var bonus := false
	if is_fresh_batch_active() and fresh_batch_bonus_used < FRESH_BATCH_BONUS_CAP:
		stamp_delta = FRESH_BATCH_STAMP_MULT
		bonus = true
		fresh_batch_bonus_used += 1
	var result := _apply_find(1, stamp_delta)
	result["bonus"] = bonus
	result["stamp_delta"] = stamp_delta
	result["fresh_batch"] = is_fresh_batch_active()
	result["bonus_left"] = fresh_batch_bonus_remaining()
	return result


func _apply_find(find_amount: int, stamp_amount: int) -> Dictionary:
	_roll_week_if_needed()
	finds_this_week += find_amount
	stamps += stamp_amount
	var free := false
	while stamps >= STAMPS_FOR_DRINK:
		stamps -= STAMPS_FOR_DRINK
		free_drinks_earned += 1
		free = true
	_upsert_board(player_name, finds_this_week)
	_save()
	return {"stamps": stamps, "free": free, "finds": finds_this_week, "free_total": free_drinks_earned, "stamp_delta": stamp_amount}


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
		fresh_batch_day = str(parsed.get("fresh_batch_day", ""))
		fresh_batch_bonus_used = int(parsed.get("fresh_batch_bonus_used", 0))


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
		"fresh_batch_day": fresh_batch_day,
		"fresh_batch_bonus_used": fresh_batch_bonus_used,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "\t"))
