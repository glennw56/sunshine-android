extends Node3D
class_name DiscoParty
## Room-wide patio party. The server sends the end time. A new hit refreshes
## that clock to 20s from the hit; it does not stack on top of time left.

const DISCO_SEC := 20.0

const COLORS: Array[Color] = [
	Color("ff2d95"),
	Color("39ff14"),
	Color("00e5ff"),
	Color("ffe600"),
	Color("ff6a00"),
	Color("b44dff"),
]

var _until: float = 0.0
var _spin: float = 0.0
var _rig: Node3D
var _wash: ColorRect
var _orbs: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("disco_party")
	name = "DiscoParty"
	_build()
	_set_shown(false)


func apply_until(until_unix: float) -> void:
	if until_unix <= Time.get_unix_time_from_system():
		return
	_until = maxf(_until, until_unix)
	_set_shown(true)


func party_on() -> bool:
	return _until > Time.get_unix_time_from_system()


func _process(delta: float) -> void:
	if not party_on():
		if _wash and _wash.visible:
			_set_shown(false)
		return
	_spin += delta
	var pulse := 0.5 + 0.5 * sin(_spin * 7.0)
	if _rig:
		_rig.rotation.y = _spin * 1.6
	for i in _orbs.size():
		var orb := _orbs[i]
		var bob := 0.35 * sin(_spin * 3.0 + float(i))
		orb.position.y = bob
		var s := 0.85 + 0.35 * sin(_spin * 5.0 + float(i) * 0.7)
		orb.scale = Vector3(s, s, s)
	if _wash:
		var tint := Color.from_hsv(fposmod(_spin * 0.35, 1.0), 0.9, 1.0)
		tint.a = 0.16 + 0.1 * pulse
		_wash.color = tint


func _set_shown(on: bool) -> void:
	if _rig:
		_rig.visible = on
	if _wash:
		_wash.visible = on


func _build() -> void:
	_rig = Node3D.new()
	_rig.name = "Lights"
	_rig.position = Vector3(0.0, 3.1, 18.0)
	add_child(_rig)
	for i in COLORS.size():
		var orb := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.42
		ball.height = 0.84
		ball.radial_segments = 12
		ball.rings = 6
		orb.mesh = ball
		orb.material_override = _glow(COLORS[i])
		var ang := float(i) / float(COLORS.size()) * TAU
		orb.position = Vector3(cos(ang) * 6.5, 0.0, sin(ang) * 6.5)
		_rig.add_child(orb)
		_orbs.append(orb)
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 2.4, 0.18)
		beam.mesh = box
		beam.position = Vector3(cos(ang) * 4.2, -1.3, sin(ang) * 4.2)
		beam.material_override = _glow(COLORS[i])
		_rig.add_child(beam)
	for i in 4:
		var puddle := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 1.6
		disc.bottom_radius = 1.6
		disc.height = 0.04
		disc.radial_segments = 16
		puddle.mesh = disc
		puddle.position = Vector3(cos(float(i) * TAU / 4.0) * 5.0, -2.95, sin(float(i) * TAU / 4.0) * 5.0)
		var tint := COLORS[i]
		tint.a = 0.55
		puddle.material_override = _glow(tint, true)
		_rig.add_child(puddle)
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_wash = ColorRect.new()
	_wash.name = "DiscoWash"
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.color = Color(1, 0, 0.6, 0.2)
	_wash.visible = false
	layer.add_child(_wash)


func _glow(color: Color, soft: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if soft:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
