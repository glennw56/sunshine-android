extends Object
class_name CosContracts
## Shared COS contracts. Keep player_id, avatar recipe, catalog IDs,
## room/protocol, chat, and API auth stable before parallel work.
## Version these payloads. Do not treat display names as authorization keys.

const CONTRACT_VERSION := 1
const PROTOCOL_VERSION := 1
const AVATAR_VERSION := 1
const ROOM_CAP := 16
const IRONDALE_LOCATION := "L4CK6YWGT5XQX"

const SKINS: PackedStringArray = ["fair", "peach", "tan", "deep", "rich"]
const HAIRS: PackedStringArray = ["bangs", "wavy", "short", "bun", "none"]
const HAIR_COLORS: PackedStringArray = ["brown", "wine", "black", "honey", "cream"]
const OUTFITS: PackedStringArray = ["blush", "wine", "cream", "apricot"]
const APRONS: PackedStringArray = ["none", "grey", "blush", "wine"]
const HATS: PackedStringArray = ["none", "sun", "beanie", "bow"]
const ACCESSORIES: PackedStringArray = ["none", "glasses", "flower", "scarf"]
const RESERVED_USERNAMES: PackedStringArray = [
	"sunshine", "admin", "staff", "bakery", "ronald", "system", "moderator", "support",
]

const SKIN_COLORS := {
	"fair": Color("f7d3b8"),
	"peach": Color("e8b4b8"),
	"tan": Color("d4a07a"),
	"deep": Color("8b5a2b"),
	"rich": Color("4a2e18"),
}
const HAIR_TINTS := {
	"brown": Color("3d2418"),
	"wine": Color("4a1c28"),
	"black": Color("1a1210"),
	"honey": Color("c4922a"),
	"cream": Color("f3d9a8"),
}
const OUTFIT_COLORS := {
	"blush": Color("e8a8b4"),
	"wine": Color("6b2d3c"),
	"cream": Color("f7f0e6"),
	"apricot": Color("e3922e"),
}


static func default_avatar() -> Dictionary:
	return {
		"v": AVATAR_VERSION,
		"skin": "peach",
		"hair": "bangs",
		"hair_color": "brown",
		"outfit": "blush",
		"apron": "grey",
		"hat": "sun",
		"accessory": "glasses",
	}


static func sanitize_choice(value: String, allowed: PackedStringArray, fallback: String) -> String:
	var key := value.strip_edges().to_lower()
	for option in allowed:
		if option == key:
			return option
	return fallback


static func sanitize_avatar(raw: Dictionary) -> Dictionary:
	var recipe := default_avatar()
	if raw.is_empty():
		return recipe
	recipe["v"] = AVATAR_VERSION
	recipe["skin"] = sanitize_choice(str(raw.get("skin", recipe["skin"])), SKINS, recipe["skin"])
	recipe["hair"] = sanitize_choice(str(raw.get("hair", recipe["hair"])), HAIRS, recipe["hair"])
	recipe["hair_color"] = sanitize_choice(str(raw.get("hair_color", recipe["hair_color"])), HAIR_COLORS, recipe["hair_color"])
	recipe["outfit"] = sanitize_choice(str(raw.get("outfit", recipe["outfit"])), OUTFITS, recipe["outfit"])
	recipe["apron"] = sanitize_choice(str(raw.get("apron", recipe["apron"])), APRONS, recipe["apron"])
	recipe["hat"] = sanitize_choice(str(raw.get("hat", recipe["hat"])), HATS, recipe["hat"])
	recipe["accessory"] = sanitize_choice(str(raw.get("accessory", recipe["accessory"])), ACCESSORIES, recipe["accessory"])
	return recipe


static func avatar_equals(a: Dictionary, b: Dictionary) -> bool:
	var left := sanitize_avatar(a)
	var right := sanitize_avatar(b)
	for key in left.keys():
		if str(left.get(key, "")) != str(right.get(key, "")):
			return false
	return true


static func new_player_id() -> String:
	return "plr_%s" % _hex_id(16)


static func normalize_username(raw: String) -> String:
	var out := ""
	for ch in raw.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_":
			out += ch
	return out


static func username_error(raw: String) -> String:
	var name := normalize_username(raw)
	if name.length() < 3 or name.length() > 20:
		return "Username must be 3–20 letters, numbers, or _."
	for reserved in RESERVED_USERNAMES:
		if name == reserved or name.begins_with(reserved):
			return "That username is reserved."
	return ""


static func display_name_error(raw: String) -> String:
	var name := raw.strip_edges()
	if name.length() < 1 or name.length() > 24:
		return "Display name must be 1–24 characters."
	if name.find("@") >= 0:
		return "Do not use an email as a display name."
	var lower := name.to_lower()
	for reserved in RESERVED_USERNAMES:
		if lower == reserved:
			return "That display name is reserved."
	return ""


static func sanitize_display_name(raw: String, fallback: String = "Sunshine Guest") -> String:
	var name := raw.strip_edges()
	if display_name_error(name) != "":
		return fallback
	return name


static func public_profile(player_id: String, username: String, display_name: String, avatar: Dictionary) -> Dictionary:
	return {
		"player_id": player_id,
		"username": normalize_username(username),
		"display_name": sanitize_display_name(display_name),
		"avatar": sanitize_avatar(avatar),
		"displays": [],
	}


static func catalog_ref(item: Dictionary) -> Dictionary:
	return {
		"item_id": str(item.get("item_id", "")).strip_edges(),
		"variation_id": str(item.get("id", item.get("catalog_object_id", ""))).strip_edges(),
		"canonical_name": str(item.get("square_name", item.get("name", ""))).strip_edges(),
		"aliases": [],
		"asset_id": str(item.get("asset_id", "")).strip_edges(),
		"asset_version": int(item.get("asset_version", 0)),
	}


static func room_hello() -> Dictionary:
	return {
		"protocol": PROTOCOL_VERSION,
		"room_cap": ROOM_CAP,
		"location_id": IRONDALE_LOCATION,
	}


static func join_ticket_shape() -> Dictionary:
	return {
		"ticket_id": "",
		"player_id": "",
		"room_id": "",
		"issued_unix": 0,
		"expires_unix": 0,
		"nonce": "",
		"protocol": PROTOCOL_VERSION,
	}


static func movement_input(seq: int, wish: Vector2, yaw: float, jumping: bool) -> Dictionary:
	return {
		"t": "move",
		"seq": seq,
		"wish": {"x": wish.x, "y": wish.y},
		"yaw": yaw,
		"jump": jumping,
	}


static func throw_request(seq: int, origin: Vector3, direction: Vector3, item_id: String = "practice_cookie") -> Dictionary:
	return {
		"t": "throw",
		"seq": seq,
		"origin": {"x": origin.x, "y": origin.y, "z": origin.z},
		"dir": {"x": direction.x, "y": direction.y, "z": direction.z},
		"item_id": item_id,
	}


static func chat_message(body: String, room_id: String) -> Dictionary:
	return {
		"t": "chat",
		"room_id": room_id,
		"body": body.strip_edges().substr(0, 180),
	}


static func chat_report(target_player_id: String, reason: String, room_id: String) -> Dictionary:
	return {
		"t": "report",
		"target_player_id": target_player_id,
		"reason": reason.strip_edges().substr(0, 120),
		"room_id": room_id,
	}


static func api_error(code: String, message: String, retryable: bool = false) -> Dictionary:
	return {
		"ok": false,
		"error_code": code,
		"error": message,
		"retryable": retryable,
	}


static func _hex_id(n: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := ""
	for _i in n:
		out += "%x" % rng.randi_range(0, 15)
	return out
