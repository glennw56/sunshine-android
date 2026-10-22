extends Node3D
## Opens the north cobblestone gate onto a short apron and the mini-golf arch.
## The course itself loads only after a rewarded ad, and that unlock lasts 24 hours.
## East, south, and west gates stay sealed. grand_gate.glb is not edited.

const Look := preload("res://scripts/explore/authored_look.gd")
const Access := preload("res://scripts/minigolf/access.gd")
const ThemeLib := preload("res://scripts/ui/bakery_theme.gd")
const ARCH := "res://assets/minigolf/entrance_arch/entrance_arch.glb"
const BOARD := "res://assets/minigolf/scoreboard/scoreboard.glb"
const BENCH := "res://assets/minigolf/bench/bench.glb"
const DONUT := "res://assets/minigolf/decor_donut/decor_donut.glb"
const CUPCAKE := "res://assets/minigolf/decor_cupcake/decor_cupcake.glb"
const MACARONS := "res://assets/minigolf/decor_macarons/decor_macarons.glb"
const CROISSANT := "res://assets/minigolf/decor_croissant/decor_croissant.glb"

var _anchor := Vector3(0, 1.2, -103.0)
var _prompt: CanvasLayer
var _status: Label
var _watch: Button
var _busy := false
var _near := false
var _failed := false


func _ready() -> void:
	name = "MiniGolfGate"
	var wall := get_parent().get_node_or_null("PerimeterWall") as Node3D
	if wall == null:
		push_error("Mini golf gate could not find the perimeter wall")
		return
	var gate := wall.get_node_or_null("GateNorth") as Node3D
	if gate == null:
		push_error("Mini golf gate could not find GateNorth")
		return
	_anchor = gate.global_position + Vector3(0, 1.2, -1.2)
	_open_gate(gate)
	_apron()
	_build_prompt()


func _physics_process(_delta: float) -> void:
	if _busy:
		return
	var player := get_tree().get_first_node_in_group("local_baker") as Node3D
	if player == null:
		return
	var near := player.global_position.distance_to(_anchor) < 8.0
	if near == _near:
		return
	_near = near
	if not _failed:
		_refresh_copy()
	_prompt.visible = near


func prompt_open() -> bool:
	return _prompt != null and _prompt.visible


func show_failure(message: String) -> void:
	_failed = true
	_near = true
	_prompt.visible = true
	_status.text = message
	_watch.text = "Try again"
	if not Access.is_unlocked():
		pass


func hide_failure() -> void:
	_failed = false
	_refresh_copy()


func start_watch() -> void:
	if _busy:
		return
	_busy = true
	_failed = false
	_watch.disabled = true
	var result := {"ok": false, "error": "Ads are unavailable right now. Try again in a moment."}
	var ads := get_node_or_null("/root/AdTipService")
	if ads and ads.has_method("play_course_unlock"):
		result = await ads.play_course_unlock()
	_busy = false
	if is_instance_valid(_watch):
		_watch.disabled = false
	if bool(result.get("ok", false)):
		Access.grant()
		_enter_course()
		return
	var err := str(result.get("error", "The ad didn't load."))
	if err == "":
		err = "The ad didn't load."
	show_failure("The ad didn't load. Check your connection and try again.\n" + err)


func _open_gate(gate: Node3D) -> void:
	var block := gate.get_node_or_null("GateBlock") as StaticBody3D
	if block:
		for child in block.get_children():
			if child is CollisionShape3D:
				child.queue_free()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var open_h := 4.8
		box.size = Vector3(6.6, 42.0 - open_h, 1.8)
		col.shape = box
		col.position = Vector3(0, open_h + box.size.y * 0.5, 0)
		block.add_child(col)
	var visual := gate.find_child("GrandGate", true, false) as Node3D
	if visual == null:
		push_error("Mini golf gate is missing grand_gate")
		return
	var door_l := visual.find_child("DoorL", true, false) as Node3D
	var door_r := visual.find_child("DoorR", true, false) as Node3D
	var portcullis := visual.find_child("Portcullis", true, false) as Node3D
	var crossbar := visual.find_child("Crossbar", true, false) as Node3D
	if door_l:
		door_l.position.x = -6.15
	if door_r:
		door_r.position.x = 6.15
	if portcullis:
		portcullis.position.y = 6.8
	if crossbar:
		crossbar.position.y = 7.6


func _apron() -> void:
	_prop(ARCH, "MiniGolfArch", Vector3(0, 0, -106.35), 0.0)
	_prop(BOARD, "MiniGolfBoard", Vector3(5.4, 0, -99.4), PI)
	_prop(BENCH, "MiniGolfBenchL", Vector3(-3.7, 0, -99.5), PI * 0.5)
	_prop(BENCH, "MiniGolfBenchR", Vector3(3.7, 0, -99.5), -PI * 0.5)
	_prop(DONUT, "MiniGolfDonut", Vector3(-3.5, 0, -106.2), 0.4)
	_prop(CUPCAKE, "MiniGolfCupcake", Vector3(3.6, 0, -106.0), -0.3)
	_prop(MACARONS, "MiniGolfMacarons", Vector3(-5.6, 0, -100.6), 0.2)
	_prop(CROISSANT, "MiniGolfCroissant", Vector3(6.6, 0, -105.4), 0.8)


func _prop(path: String, node_name: String, pos: Vector3, yaw: float) -> void:
	if not ResourceLoader.exists(path):
		push_error("Mini golf prop missing " + path)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var node := packed.instantiate() as Node3D
	if node == null:
		return
	node.name = node_name
	node.position = pos
	node.rotation.y = yaw
	add_child(node)
	Look.apply(node)


func _build_prompt() -> void:
	_prompt = CanvasLayer.new()
	_prompt.name = "MiniGolfPrompt"
	_prompt.visible = false
	_prompt.layer = 30
	add_child(_prompt)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(root)
	ThemeLib.apply(root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := ThemeLib.card_style()
	style.set_corner_radius_all(28)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	var title := Label.new()
	title.text = "Sunshine Mini Golf"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", ThemeLib.SIZE_TITLE)
	title.add_theme_color_override("font_color", ThemeLib.WINE)
	box.add_child(title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(460, 0)
	_status.add_theme_font_size_override("font_size", ThemeLib.SIZE_BODY)
	_status.add_theme_color_override("font_color", ThemeLib.INK)
	box.add_child(_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_watch = Button.new()
	_watch.custom_minimum_size = Vector2(220, 78)
	_watch.pressed.connect(start_watch)
	row.add_child(_watch)
	var later := Button.new()
	later.text = "Not now"
	later.theme_type_variation = "SecondaryButton"
	later.custom_minimum_size = Vector2(180, 78)
	later.pressed.connect(func():
		_prompt.visible = false
		_near = false
		_failed = false
	)
	row.add_child(later)
	_refresh_copy()


func _refresh_copy() -> void:
	if Access.is_unlocked():
		var mins := int(ceil(float(Access.seconds_left()) / 60.0))
		_status.text = "The course is open for %d more minutes. No ads during play." % maxi(mins, 1)
		_watch.text = "Play"
	else:
		var unit := ""
		if AppConfig and AppConfig.has_method("course_rewarded_unit"):
			unit = AppConfig.course_rewarded_unit()
		_status.text = "Watch a short ad to play all 18 holes for 24 hours. No ads during play."
		if unit != "":
			_status.text += "\nTest ad: " + unit
		_watch.text = "Watch ad"


func _enter_course() -> void:
	Access.set_return(Vector3(0.0, 0.2, -96.0), 0.0)
	if AppConfig:
		AppConfig.go("res://scenes/minigolf/course.tscn")
