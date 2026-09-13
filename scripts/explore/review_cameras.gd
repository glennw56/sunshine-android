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
		{"name": "Entrance", "pos": Vector3(0.0, 1.7, -6.2), "look": Vector3(0.0, 1.5, -1.35), "fov": 65.0},
		{"name": "Counter", "pos": Vector3(0.15, 1.55, 1.7), "look": Vector3(0.1, 1.2, 4.4), "fov": 60.0},
		{"name": "Dining", "pos": Vector3(-1.2, 1.8, -6.4), "look": Vector3(3.4, 1.0, 1.0), "fov": 62.0},
		{"name": "LeftCorner", "pos": Vector3(-12.2, 2.6, 2.4), "look": Vector3(-8.4, 1.8, -0.4), "fov": 60.0},
		{"name": "RightCorner", "pos": Vector3(12.4, 2.6, 2.8), "look": Vector3(8.6, 1.8, 0.2), "fov": 60.0},
		{"name": "SunshineCloseup", "pos": Vector3(-2.4, 1.4, -3.2), "look": Vector3(0.0, 2.6, -1.4), "fov": 42.0},
		{"name": "PastryCase", "pos": Vector3(-0.4, 1.45, 2.4), "look": Vector3(0.1, 1.25, 4.35), "fov": 55.0},
		{"name": "Exterior", "pos": Vector3(0.6, 4.2, -13.0), "look": Vector3(0.0, 2.0, 1.0), "fov": 68.0},
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
