extends Node3D
class_name PracticeTarget
## Cookie-practice post. A hit pops the stand and shows a short Hit! tag.

var hits: int = 0
var _t: float = 0.0
var _label: Label3D


func _ready() -> void:
	add_to_group("practice_target")
	_label = Label3D.new()
	_label.name = "HitTag"
	_label.text = ""
	_label.font_size = 48
	_label.pixel_size = 0.005
	_label.position = Vector3(0, 1.45, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color("f4c430")
	_label.outline_size = 8
	_label.outline_modulate = Color("3d1f24")
	_label.visible = false
	add_child(_label)


func register_hit() -> void:
	hits += 1
	_t = 0.48
	_label.visible = true
	_label.text = "Hit!"
	_label.modulate.a = 1.0
	_label.position.y = 1.35


func _process(delta: float) -> void:
	if _t <= 0.0:
		return
	_t = maxf(0.0, _t - delta)
	var u := 1.0 - (_t / 0.48)
	var pop := 1.0 + sin(u * PI) * 0.22
	scale = Vector3(pop, pop, pop)
	rotation.z = sin(u * TAU * 2.0) * 0.14 * (1.0 - u)
	_label.position.y = 1.35 + u * 0.5
	var tint := _label.modulate
	tint.a = 1.0 - u
	_label.modulate = tint
	if _t <= 0.0:
		scale = Vector3.ONE
		rotation.z = 0.0
		_label.visible = false
