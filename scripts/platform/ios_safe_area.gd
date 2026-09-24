extends Node
## Notch and home-indicator insets for iOS. Android and desktop are unchanged.


func _ready() -> void:
	if OS.get_name() != "iOS":
		return
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_refresh_all)
	call_deferred("_refresh_all")


func _on_node_added(node: Node) -> void:
	if OS.get_name() != "iOS":
		return
	if node is MarginContainer and str(node.name) == "Safe":
		call_deferred("_pad_safe", node)


func insets() -> Vector4:
	## x = left, y = top, z = right, w = bottom, in viewport pixels.
	if OS.get_name() != "iOS":
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var window := Vector2(DisplayServer.window_get_size())
	if window.x < 1.0 or window.y < 1.0:
		return Vector4.ZERO
	var vp := get_viewport().get_visible_rect().size
	var sx := vp.x / window.x
	var sy := vp.y / window.y
	return Vector4(
		maxf(0.0, safe.position.x) * sx,
		maxf(0.0, safe.position.y) * sy,
		maxf(0.0, window.x - safe.end.x) * sx,
		maxf(0.0, window.y - safe.end.y) * sy
	)


func _refresh_all() -> void:
	if OS.get_name() != "iOS":
		return
	var root := get_tree().root
	_walk_safe(root)
	var hud := root.find_child("HUD", true, false)
	if hud != null:
		pad_explore(hud)


func _walk_safe(node: Node) -> void:
	if node is MarginContainer and str(node.name) == "Safe":
		_pad_safe(node)
	for child in node.get_children():
		_walk_safe(child)


func _pad_safe(node: MarginContainer) -> void:
	if not is_instance_valid(node):
		return
	if not node.has_meta("_ios_base_margin"):
		node.set_meta("_ios_base_margin", {
			"l": node.get_theme_constant("margin_left", "MarginContainer"),
			"t": node.get_theme_constant("margin_top", "MarginContainer"),
			"r": node.get_theme_constant("margin_right", "MarginContainer"),
			"b": node.get_theme_constant("margin_bottom", "MarginContainer"),
		})
	var base: Dictionary = node.get_meta("_ios_base_margin")
	var pad := insets()
	node.add_theme_constant_override("margin_left", int(base["l"]) + int(ceil(pad.x)))
	node.add_theme_constant_override("margin_top", int(base["t"]) + int(ceil(pad.y)))
	node.add_theme_constant_override("margin_right", int(base["r"]) + int(ceil(pad.z)))
	node.add_theme_constant_override("margin_bottom", int(base["b"]) + int(ceil(pad.w)))


func pad_explore(hud: Node) -> void:
	if OS.get_name() != "iOS" or hud == null:
		return
	var pad := insets()
	_shift(hud, "Root/Top", pad.x, pad.y, -pad.z, pad.y)
	_shift(hud, "Root/Status", pad.x, pad.y, -pad.z, pad.y)
	_shift(hud, "Root/Board", -pad.z, pad.y, -pad.z, pad.y)
	_shift(hud, "Root/ChatDock", pad.x, pad.y, 0.0, pad.y)
	## Lift the stick and toss above the home indicator. Look stays a drag
	## surface but its bottom edge clears the indicator too.
	_shift(hud, "Root/Joy", pad.x, -pad.w, 0.0, -pad.w)
	_shift(hud, "Root/TossCookie", -pad.z, -pad.w, -pad.z, -pad.w)
	_shift(hud, "Root/LookPad", 0.0, pad.y, -pad.z, -pad.w)


func _shift(hud: Node, path: String, dl: float, dt: float, dr: float, db: float) -> void:
	var node := hud.get_node_or_null(path) as Control
	if node == null:
		return
	if not node.has_meta("_ios_base_offsets"):
		node.set_meta("_ios_base_offsets", {
			"l": node.offset_left,
			"t": node.offset_top,
			"r": node.offset_right,
			"b": node.offset_bottom,
		})
	var base: Dictionary = node.get_meta("_ios_base_offsets")
	node.offset_left = float(base["l"]) + dl
	node.offset_top = float(base["t"]) + dt
	node.offset_right = float(base["r"]) + dr
	node.offset_bottom = float(base["b"]) + db
