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
		{"name": "Entrance", "pos": Vector3(0.18, 1.52, -14.4), "look": Vector3(0.05, 2.85, 1.2), "fov": 62.0},
		{"name": "Counter", "pos": Vector3(-1.35, 1.45, 3.25), "look": Vector3(0.2, 1.1, 5.5), "fov": 60.0},
		{"name": "Dining", "pos": Vector3(0.1, 1.48, -5.35), "look": Vector3(0.1, 1.45, 1.2), "fov": 56.0},
		{"name": "LeftCorner", "pos": Vector3(6.2, 1.55, -6.7), "look": Vector3(1.3, 1.5, 0.9), "fov": 56.0},
		{"name": "RightCorner", "pos": Vector3(-4.35, 1.52, -6.2), "look": Vector3(-7.8, 1.35, 0.7), "fov": 54.0},
		{"name": "SunshineCloseup", "pos": Vector3(0.12, 5.85, -3.15), "look": Vector3(0.12, 5.7, 1.2), "fov": 32.0},
		{"name": "PastryCase", "pos": Vector3(-1.15, 1.35, 2.95), "look": Vector3(0.1, 1.05, 5.45), "fov": 55.0},
		{"name": "Exterior", "pos": Vector3(8.0, 2.45, -14.8), "look": Vector3(-1.4, 2.8, 1.4), "fov": 54.0},
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
