extends SceneTree
## Mock rewarded ad → staff tip jar. Run after scene_smoke.
## Resolve autoloads from the tree so this tool script does not depend on
## compile-time autoload identifiers (addon class_name order can hide them).

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ads := root.get_node_or_null("AdTipService")
	var save := root.get_node_or_null("GameSave")
	if ads == null or save == null:
		push_error("SMOKE FAIL autoloads missing ads=%s save=%s" % [ads, save])
		quit(1)
		return
	print("SMOKE ad mode=", ads.current_mode(), " describe=", ads.describe(), " before=", save.staff_tips)
	var result: Dictionary = await ads.play_rewarded()
	print("SMOKE ad result=", result)
	if not result.get("ok", false):
		push_error("SMOKE FAIL ad did not credit staff tip")
		quit(1)
		return
	if save.staff_tips < 1:
		push_error("SMOKE FAIL staff jar still empty")
		quit(1)
		return
	print("SMOKE staff jar=", save.staff_tips, " week=", save.staff_tips_week)
	quit(0)
