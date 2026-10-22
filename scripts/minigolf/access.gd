extends RefCounted
## 24-hour course unlock and a round the player can resume. Stored apart
## from the store save so a test-world round never rewrites production fields.

const PATH := "user://minigolf_access.cfg"
const Catalog := preload("res://scripts/minigolf/catalog.gd")

static var return_pos := Vector3.ZERO
static var return_yaw := 0.0
static var has_return := false


static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg


static func _save(cfg: ConfigFile) -> void:
	cfg.save(PATH)


static func is_unlocked() -> bool:
	return seconds_left() > 0


static func seconds_left() -> int:
	var until := int(_cfg().get_value("access", "until", 0))
	return maxi(0, until - int(Time.get_unix_time_from_system()))


static func revoke() -> void:
	var cfg := _cfg()
	cfg.set_value("access", "until", 0)
	_save(cfg)


static func grant() -> void:
	var cfg := _cfg()
	cfg.set_value("access", "until", int(Time.get_unix_time_from_system()) + Catalog.UNLOCK_SECONDS)
	_save(cfg)


static func clear_round() -> void:
	var cfg := _cfg()
	cfg.set_value("round", "active", false)
	cfg.set_value("round", "hole", 1)
	cfg.set_value("round", "scores", PackedStringArray())
	cfg.set_value("round", "stars", PackedStringArray())
	_save(cfg)


static func save_round(hole: int, scores: Array, stars: Array, active: bool) -> void:
	var cfg := _cfg()
	cfg.set_value("round", "active", active)
	cfg.set_value("round", "hole", hole)
	cfg.set_value("round", "scores", _pack(scores))
	cfg.set_value("round", "stars", _pack(stars))
	_save(cfg)


static func load_round() -> Dictionary:
	var cfg := _cfg()
	return {
		"active": bool(cfg.get_value("round", "active", false)),
		"hole": int(cfg.get_value("round", "hole", 1)),
		"scores": _unpack(cfg.get_value("round", "scores", PackedStringArray())),
		"stars": _unpack(cfg.get_value("round", "stars", PackedStringArray())),
	}


static func best_total() -> int:
	return int(_cfg().get_value("round", "best", 0))


static func note_best(total: int) -> int:
	var cfg := _cfg()
	var best := int(cfg.get_value("round", "best", 0))
	if best <= 0 or total < best:
		best = total
		cfg.set_value("round", "best", best)
		_save(cfg)
	return best


static func set_return(pos: Vector3, yaw: float) -> void:
	return_pos = pos
	return_yaw = yaw
	has_return = true


static func consume_return() -> Dictionary:
	if not has_return:
		return {}
	has_return = false
	return {"pos": return_pos, "yaw": return_yaw}


static func _pack(values: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for v in values:
		out.append(str(int(v)))
	return out


static func _unpack(raw: Variant) -> Array:
	var out: Array = []
	if raw is PackedStringArray:
		for item in raw:
			out.append(int(item))
	elif raw is Array:
		for item in raw:
			out.append(int(item))
	while out.size() < Catalog.hole_count():
		out.append(0)
	return out
