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
		{"name": "Entrance", "pos": Vector3(0.0, 1.62, 6.15), "look": Vector3(0.0, 3.15, -1.05), "fov": 50.0},
		{"name": "Counter", "pos": Vector3(-10.2, 2.15, -0.6), "look": Vector3(-5.6, 1.15, -3.5), "fov": 52.0},
		{"name": "Dining", "pos": Vector3(0.0, 1.55, 7.4), "look": Vector3(0.0, 2.6, -1.05), "fov": 52.0},
		{"name": "LeftCorner", "pos": Vector3(10.8, 2.15, -1.6), "look": Vector3(5.4, 1.35, -5.4), "fov": 52.0},
		{"name": "RightCorner", "pos": Vector3(-8.8, 1.7, 0.4), "look": Vector3(-5.4, 1.5, -2.8), "fov": 54.0},
		{"name": "SunshineCloseup", "pos": Vector3(0.0, 3.35, 2.4), "look": Vector3(0.0, 4.85, -1.0), "fov": 38.0},
		{"name": "PastryCase", "pos": Vector3(1.2, 2.05, -13.2), "look": Vector3(1.4, 1.35, -8.7), "fov": 50.0},
		{"name": "Exterior", "pos": Vector3(13.5, 8.2, 10.2), "look": Vector3(0.2, 2.3, -4.2), "fov": 48.0},
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
