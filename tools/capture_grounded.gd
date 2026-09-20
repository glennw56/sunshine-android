extends SceneTree
## Capture the south-lawn spawn to prove feet sit on the grass.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/explore/explore_3d.tscn")
	var root: Node = packed.instantiate()
	root_window.add_child(root)
	for _i in 24:
		await process_frame
	var player := root.get_node_or_null("Player") as Node3D
	if player:
		print("GROUNDED player_y=", player.global_position.y, " pos=", player.global_position)
	var img: Image = root_window.get_texture().get_image()
	if img:
		var path := "/opt/cursor/artifacts/explore_grounded.png"
		img.save_png(path)
		print("CAPTURE ", path, " ", img.get_width(), "x", img.get_height())
	quit()
