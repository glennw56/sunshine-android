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
		{"name": "Entrance", "pos": Vector3(0.45, 1.5, -13.05), "look": Vector3(-0.15, 2.65, 1.05), "fov": 68.0},
		{"name": "Counter", "pos": Vector3(-1.35, 1.45, 3.15), "look": Vector3(0.2, 1.1, 5.4), "fov": 60.0},
		{"name": "Dining", "pos": Vector3(0.1, 1.5, -5.5), "look": Vector3(0.05, 1.4, 1.1), "fov": 58.0},
		{"name": "LeftCorner", "pos": Vector3(6.1, 1.55, -6.8), "look": Vector3(1.2, 1.4, 0.8), "fov": 58.0},
		{"name": "RightCorner", "pos": Vector3(-4.5, 1.5, -6.5), "look": Vector3(-7.6, 1.3, 0.5), "fov": 56.0},
		{"name": "SunshineCloseup", "pos": Vector3(0.0, 6.15, -3.4), "look": Vector3(0.0, 6.15, 1.0), "fov": 34.0},
		{"name": "PastryCase", "pos": Vector3(-1.15, 1.35, 2.85), "look": Vector3(0.1, 1.05, 5.35), "fov": 55.0},
		{"name": "Exterior", "pos": Vector3(8.2, 2.55, -15.4), "look": Vector3(-1.6, 2.7, 1.3), "fov": 56.0},
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
