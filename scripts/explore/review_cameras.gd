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
		# Sidewalk hero matching the storefront photo (lawn, pink eave, orange sign, mailbox, green house).
		{"name": "Entrance", "pos": Vector3(0.28, 1.58, -11.7), "look": Vector3(1.45, 3.05, 1.15), "fov": 52.0},
		{"name": "Counter", "pos": Vector3(-1.35, 1.45, 3.15), "look": Vector3(0.2, 1.1, 5.4), "fov": 60.0},
		{"name": "Dining", "pos": Vector3(0.15, 1.55, -5.4), "look": Vector3(0.2, 1.35, 1.1), "fov": 58.0},
		{"name": "LeftCorner", "pos": Vector3(-6.2, 1.55, -6.8), "look": Vector3(-1.4, 1.4, 0.8), "fov": 58.0},
		{"name": "RightCorner", "pos": Vector3(4.6, 1.5, -6.4), "look": Vector3(7.6, 1.35, 0.6), "fov": 56.0},
		{"name": "SunshineCloseup", "pos": Vector3(0.05, 4.35, -3.6), "look": Vector3(0.05, 5.55, 1.05), "fov": 36.0},
		{"name": "PastryCase", "pos": Vector3(-1.15, 1.35, 2.85), "look": Vector3(0.1, 1.05, 5.35), "fov": 55.0},
		{"name": "Exterior", "pos": Vector3(-8.4, 2.6, -15.2), "look": Vector3(2.2, 2.8, 1.4), "fov": 58.0},
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
