extends Node3D
## Blush best-scores sign beside the mini-golf gate.
## Reads the local top 10. Nothing here is networked.

const Scores := preload("res://scripts/minigolf/scores.gd")
const ThemeLib := preload("res://scripts/ui/bakery_theme.gd")

const BLUSH := Color("e8b4b8")
const ROW_COUNT := 10

var _rank: Array[Label3D] = []
var _name: Array[Label3D] = []
var _strokes: Array[Label3D] = []
var _plus: Array[Label3D] = []
var _date: Array[Label3D] = []
var _font: Font


func _ready() -> void:
	if ResourceLoader.exists(ThemeLib.FONT_PATH):
		_font = load(ThemeLib.FONT_PATH)
	_build()
	refresh()


func entry_count() -> int:
	return Scores.entries().size()


func entry_line(index: int) -> String:
	if index < 0 or index >= _rank.size():
		return ""
	if _name[index].text == "—":
		return ""
	return "%s  %s  %s  %s  %s" % [
		_rank[index].text, _name[index].text, _strokes[index].text, _plus[index].text, _date[index].text,
	]


func refresh() -> void:
	var list := Scores.entries()
	for i in ROW_COUNT:
		_rank[i].text = str(i + 1)
		if i < list.size():
			var row: Dictionary = list[i]
			var who := str(row.get("name", "Guest"))
			if who.length() > 12:
				who = who.substr(0, 11) + "…"
			_name[i].text = who
			_strokes[i].text = str(int(row.get("strokes", 0)))
			_plus[i].text = Scores.format_plus(int(row.get("plus", 0)))
			_date[i].text = str(row.get("date", ""))
			_paint(i, ThemeLib.INK)
		else:
			_name[i].text = "—"
			_strokes[i].text = ""
			_plus[i].text = ""
			_date[i].text = ""
			_paint(i, ThemeLib.MUTED)
	print("BOARD lines %d" % list.size())
	for i in mini(list.size(), ROW_COUNT):
		print("BOARD show ", entry_line(i))


func _paint(index: int, color: Color) -> void:
	_rank[index].modulate = color
	_name[index].modulate = color
	_strokes[index].modulate = color
	_plus[index].modulate = color
	_date[index].modulate = color


func _build() -> void:
	_box(Vector3(1.86, 0.16, 0.62), Vector3(0, 0.08, 0), Color("5c584f"))
	_box(Vector3(0.12, 0.42, 0.12), Vector3(-0.72, 0.28, 0), ThemeLib.WINE_DARK)
	_box(Vector3(0.12, 0.42, 0.12), Vector3(0.72, 0.28, 0), ThemeLib.WINE_DARK)
	_box(Vector3(1.72, 2.08, 0.08), Vector3(0, 1.42, 0), ThemeLib.WINE)
	_box(Vector3(1.56, 1.92, 0.04), Vector3(0, 1.42, 0.04), BLUSH)
	_box(Vector3(1.46, 0.34, 0.02), Vector3(0, 2.12, 0.07), ThemeLib.WINE)
	_box(Vector3(1.44, 1.48, 0.02), Vector3(0, 1.18, 0.07), ThemeLib.CREAM)
	var title := _label("Best Scores", Vector3(0, 2.12, 0.1), 52, 1.4, HORIZONTAL_ALIGNMENT_CENTER)
	title.modulate = ThemeLib.CREAM
	title.outline_modulate = ThemeLib.WINE_DARK
	title.outline_size = 10
	_header()
	for i in ROW_COUNT:
		var y := 1.64 - float(i) * 0.136
		_rank.append(_label(str(i + 1), Vector3(-0.62, y, 0.1), 28, 0.16, HORIZONTAL_ALIGNMENT_RIGHT))
		_name.append(_label("—", Vector3(-0.22, y, 0.1), 28, 0.58, HORIZONTAL_ALIGNMENT_LEFT))
		_strokes.append(_label("", Vector3(0.22, y, 0.1), 28, 0.22, HORIZONTAL_ALIGNMENT_RIGHT))
		_plus.append(_label("", Vector3(0.44, y, 0.1), 28, 0.22, HORIZONTAL_ALIGNMENT_RIGHT))
		_date.append(_label("", Vector3(0.64, y, 0.1), 26, 0.32, HORIZONTAL_ALIGNMENT_LEFT))
	var foot := _label("On this phone", Vector3(0, 0.52, 0.1), 26, 1.3, HORIZONTAL_ALIGNMENT_CENTER)
	foot.modulate = ThemeLib.WINE_SOFT


func _header() -> void:
	var y := 1.82
	var specs: Array = [
		["#", -0.62, 0.16, HORIZONTAL_ALIGNMENT_RIGHT],
		["Name", -0.22, 0.58, HORIZONTAL_ALIGNMENT_LEFT],
		["Str", 0.22, 0.22, HORIZONTAL_ALIGNMENT_RIGHT],
		["+/-", 0.44, 0.22, HORIZONTAL_ALIGNMENT_RIGHT],
		["Date", 0.64, 0.32, HORIZONTAL_ALIGNMENT_LEFT],
	]
	for spec in specs:
		var label := _label(str(spec[0]), Vector3(float(spec[1]), y, 0.1), 26, float(spec[2]), int(spec[3]))
		label.modulate = ThemeLib.WINE


func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	inst.material_override = mat
	add_child(inst)


func _label(text: String, at: Vector3, size: int, width_m: float, align: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = size
	label.pixel_size = 0.0034
	label.width = width_m / label.pixel_size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.modulate = ThemeLib.INK
	label.outline_size = 0
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	if _font:
		label.font = _font
	add_child(label)
	return label
