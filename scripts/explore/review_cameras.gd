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
		# Street spawn looking −Z at the bakery facade (logo / sign / 2231).
		{"name": "Entrance", "pos": Vector3(-5.5, 1.58, 1.15), "look": Vector3(-5.5, 2.85, -5.45), "fov": 52.0},
		{"name": "Counter", "pos": Vector3(-0.55, 1.42, -6.85), "look": Vector3(-5.2, 1.35, -8.6), "fov": 60.0},
		{"name": "Dining", "pos": Vector3(-5.5, 1.48, -1.85), "look": Vector3(-5.5, 2.25, -5.45), "fov": 56.0},
		{"name": "LeftCorner", "pos": Vector3(4.6, 1.55, -1.15), "look": Vector3(6.2, 2.05, -5.45), "fov": 56.0},
		{"name": "RightCorner", "pos": Vector3(-11.2, 1.7, -1.55), "look": Vector3(-8.6, 2.15, -5.45), "fov": 54.0},
		{"name": "SunshineCloseup", "pos": Vector3(-5.5, 2.85, -2.85), "look": Vector3(-5.5, 4.15, -5.35), "fov": 40.0},
		{"name": "PastryCase", "pos": Vector3(-0.85, 1.32, -6.35), "look": Vector3(-5.4, 1.15, -8.2), "fov": 55.0},
		{"name": "Exterior", "pos": Vector3(10.5, 6.4, 5.8), "look": Vector3(-2.0, 2.4, -8.0), "fov": 52.0},
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
