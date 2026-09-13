extends Node3D
class_name ReviewCameras
## Fixed Camera3D markers for screenshot feedback. Never current during play
## unless tools/capture_review.gd activates them.
## Names: Entrance, Counter, Dining, LeftCorner, RightCorner, SunshineCloseup, PastryCase, Exterior.

const SHOT_NAMES: PackedStringArray = [
	"Entrance",
	"Counter",
	"Dining",
	"LeftCorner",
	"RightCorner",
	"SunshineCloseup",
	"PastryCase",
	"Exterior",
]


func _ready() -> void:
	_ensure_cameras()


func _ensure_cameras() -> void:
	var shots: Array[Dictionary] = [
		{"name": "Entrance", "pos": Vector3(-1.4, 1.85, -11.2), "look": Vector3(1.1, 1.55, 0.8), "fov": 72.0},
		{"name": "Counter", "pos": Vector3(0.15, 1.55, 2.3), "look": Vector3(0.15, 1.15, 5.3), "fov": 60.0},
		{"name": "Dining", "pos": Vector3(0.6, 1.85, -4.6), "look": Vector3(3.4, 1.05, 1.4), "fov": 66.0},
		{"name": "LeftCorner", "pos": Vector3(-5.2, 1.8, -9.4), "look": Vector3(-2.0, 1.2, -6.6), "fov": 58.0},
		{"name": "RightCorner", "pos": Vector3(6.2, 2.1, -5.4), "look": Vector3(8.2, 1.5, 0.4), "fov": 60.0},
		{"name": "SunshineCloseup", "pos": Vector3(-1.8, 2.05, -3.2), "look": Vector3(0.05, 3.05, 0.45), "fov": 44.0},
		{"name": "PastryCase", "pos": Vector3(-0.35, 1.45, 2.7), "look": Vector3(0.15, 1.2, 5.2), "fov": 55.0},
		{"name": "Exterior", "pos": Vector3(4.6, 2.35, 2.4), "look": Vector3(6.6, 2.05, 7.0), "fov": 64.0},
	]
	for shot in shots:
		var cam_name := str(shot["name"])
		var cam := get_node_or_null(cam_name) as Camera3D
		if cam == null:
			cam = Camera3D.new()
			cam.name = cam_name
			add_child(cam)
		cam.current = false
		cam.fov = float(shot["fov"])
		cam.position = shot["pos"]
		cam.look_at(shot["look"], Vector3.UP)


func camera_named(shot: String) -> Camera3D:
	return get_node_or_null(shot) as Camera3D


func all_cameras() -> Array[Camera3D]:
	var out: Array[Camera3D] = []
	for shot_name in SHOT_NAMES:
		var cam := camera_named(shot_name)
		if cam:
			out.append(cam)
	return out
