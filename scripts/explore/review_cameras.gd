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
		# Sidewalk hero: textured v3 facade, pink trim, grass lot.
		{"name": "Entrance", "pos": Vector3(0.05, 1.58, -7.25), "look": Vector3(0.1, 2.55, -0.91), "fov": 52.0},
		{"name": "Counter", "pos": Vector3(-0.85, 1.42, 1.35), "look": Vector3(0.15, 1.2, 3.6), "fov": 60.0},
		{"name": "Dining", "pos": Vector3(0.05, 1.48, -5.35), "look": Vector3(0.1, 2.15, -0.7), "fov": 56.0},
		{"name": "LeftCorner", "pos": Vector3(5.4, 1.55, -6.0), "look": Vector3(0.8, 2.0, -0.4), "fov": 56.0},
		{"name": "RightCorner", "pos": Vector3(-8.8, 1.7, -6.4), "look": Vector3(-14.5, 2.05, -0.5), "fov": 54.0},
		{"name": "SunshineCloseup", "pos": Vector3(0.12, 2.35, -3.05), "look": Vector3(0.1, 2.45, -0.91), "fov": 40.0},
		{"name": "PastryCase", "pos": Vector3(-0.75, 1.32, 1.15), "look": Vector3(0.1, 1.05, 3.4), "fov": 55.0},
		{"name": "Exterior", "pos": Vector3(8.2, 4.2, -13.5), "look": Vector3(-4.0, 2.4, -0.4), "fov": 52.0},
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
