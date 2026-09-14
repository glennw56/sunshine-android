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
		{"name": "Entrance", "pos": Vector3(0.15, 1.55, -9.6), "look": Vector3(0.35, 2.55, 0.2), "fov": 58.0},
		{"name": "Counter", "pos": Vector3(-1.25, 1.45, 3.15), "look": Vector3(0.2, 1.15, 6.2), "fov": 60.0},
		{"name": "Dining", "pos": Vector3(0.05, 1.48, -5.55), "look": Vector3(0.2, 1.55, 0.1), "fov": 56.0},
		{"name": "LeftCorner", "pos": Vector3(6.4, 1.55, -6.2), "look": Vector3(1.1, 1.7, 0.6), "fov": 56.0},
		{"name": "RightCorner", "pos": Vector3(-8.4, 1.55, -5.4), "look": Vector3(-10.4, 1.7, 1.4), "fov": 54.0},
		{"name": "SunshineCloseup", "pos": Vector3(0.45, 5.85, -3.35), "look": Vector3(0.5, 5.7, -0.2), "fov": 32.0},
		{"name": "PastryCase", "pos": Vector3(-1.05, 1.35, 2.85), "look": Vector3(0.15, 1.1, 6.1), "fov": 55.0},
		{"name": "Exterior", "pos": Vector3(8.2, 2.55, -12.4), "look": Vector3(-1.2, 2.9, 1.2), "fov": 54.0},
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
