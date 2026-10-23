extends RefCounted
## Top 10 rounds on this phone. user://minigolf_scores.cfg survives an app restart.
## A shared online board needs Ronald's OK. submit_remote() is the only hook
## a server would replace. It does not talk to the network.

const PATH := "user://minigolf_scores.cfg"
const LIMIT := 10
const MONTHS: PackedStringArray = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


static func player_name() -> String:
	var picked := ""
	if ProfileStore:
		picked = str(ProfileStore.display_name).strip_edges()
	if picked == "" and AccountClient and AccountClient.has_method("display_name"):
		picked = str(AccountClient.display_name()).strip_edges()
	if picked == "" and GameSave:
		picked = str(GameSave.player_name).strip_edges()
	if picked == "":
		return "Guest"
	return picked


static func format_plus(plus: int) -> String:
	if plus > 0:
		return "+%d" % plus
	if plus == 0:
		return "E"
	return str(plus)


static func best_strokes() -> int:
	var list := entries()
	if list.is_empty():
		return 0
	return int(list[0].get("strokes", 0))


static func entries() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return []
	var parsed: Variant = JSON.parse_string(str(cfg.get_value("board", "rows", "[]")))
	if parsed is Array:
		return parsed
	return []


## Saves one finished round and returns whether it beat the previous best.
## Lower strokes rank first. A tie keeps the earlier round ahead.
static func record_round(total: int, par: int) -> Dictionary:
	var list := entries()
	var previous := 0
	if not list.is_empty():
		previous = int(list[0].get("strokes", 0))
	var now := int(Time.get_unix_time_from_system())
	var row := {
		"name": player_name(),
		"strokes": total,
		"plus": total - par,
		"unix": now,
		"date": _today(),
	}
	var is_best := previous <= 0 or total < previous
	list.append(row)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ascore := int(a.get("strokes", 0))
		var bscore := int(b.get("strokes", 0))
		if ascore == bscore:
			return int(a.get("unix", 0)) < int(b.get("unix", 0))
		return ascore < bscore
	)
	if list.size() > LIMIT:
		list.resize(LIMIT)
	_write(list)
	submit_remote(row)
	var best := int(list[0].get("strokes", 0)) if not list.is_empty() else total
	return {"new_best": is_best, "best": best, "entries": list, "row": row}


## Plug-in point for a shared board. Does nothing until a server is approved.
static func submit_remote(_row: Dictionary) -> void:
	pass


static func _write(list: Array) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("board", "rows", JSON.stringify(list))
	cfg.save(PATH)


static func _today() -> String:
	var d := Time.get_datetime_dict_from_system()
	var month := clampi(int(d.get("month", 1)), 1, 12)
	return "%s %d" % [MONTHS[month - 1], int(d.get("day", 1))]
