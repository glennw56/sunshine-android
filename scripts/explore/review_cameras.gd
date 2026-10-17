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
		# South-lawn spawn looking −Z at the patio seating and Sunshine logo wall.
		{"name": "Entrance", "pos": Vector3(0.0, 1.58, 11.0), "look": Vector3(0.0, 1.75, -6.2), "fov": 52.0},
		{"name": "Counter", "pos": Vector3(3.6, 1.42, 2.4), "look": Vector3(0.0, 1.05, -0.45), "fov": 60.0},
		{"name": "Dining", "pos": Vector3(0.0, 1.55, 7.2), "look": Vector3(0.0, 1.15, 0.0), "fov": 56.0},
		{"name": "LeftCorner", "pos": Vector3(9.2, 1.65, 7.4), "look": Vector3(4.8, 1.15, 3.9), "fov": 56.0},
		{"name": "RightCorner", "pos": Vector3(-9.2, 1.7, 7.4), "look": Vector3(-4.8, 1.15, 3.9), "fov": 54.0},
		{"name": "SunshineCloseup", "pos": Vector3(0.0, 1.85, -3.6), "look": Vector3(0.0, 1.72, -6.2), "fov": 40.0},
		{"name": "PastryCase", "pos": Vector3(-3.8, 1.35, 7.4), "look": Vector3(-6.5, 1.2, 5.75), "fov": 55.0},
		{"name": "Exterior", "pos": Vector3(0.0, 22.0, 32.0), "look": Vector3(0.0, 1.2, -2.0), "fov": 52.0},
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
