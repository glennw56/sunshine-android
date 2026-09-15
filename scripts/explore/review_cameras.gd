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
		# Grass spawn looking −Z at the shop facade (logo / sign).
		{"name": "Entrance", "pos": Vector3(0.0, 1.58, 2.35), "look": Vector3(0.0, 2.95, -1.05), "fov": 52.0},
		{"name": "Counter", "pos": Vector3(-7.4, 1.55, -3.2), "look": Vector3(-5.1, 1.45, -3.9), "fov": 58.0},
		{"name": "Dining", "pos": Vector3(0.0, 1.48, 3.6), "look": Vector3(0.0, 2.4, -1.05), "fov": 56.0},
		{"name": "LeftCorner", "pos": Vector3(7.6, 1.55, -2.2), "look": Vector3(5.2, 1.7, -5.4), "fov": 56.0},
		{"name": "RightCorner", "pos": Vector3(-8.2, 1.7, -1.4), "look": Vector3(-5.2, 1.8, -3.6), "fov": 54.0},
		{"name": "SunshineCloseup", "pos": Vector3(0.0, 3.15, 1.15), "look": Vector3(0.0, 4.55, -1.0), "fov": 40.0},
		{"name": "PastryCase", "pos": Vector3(7.2, 1.35, -5.4), "look": Vector3(5.2, 1.4, -5.6), "fov": 55.0},
		{"name": "Exterior", "pos": Vector3(12.5, 7.2, 8.5), "look": Vector3(0.0, 2.4, -4.5), "fov": 52.0},
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
