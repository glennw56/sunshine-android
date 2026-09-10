extends SceneTree
## Mock rewarded ad → staff tip jar. Run after scene_smoke.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("SMOKE ad mode=", AdTipService.current_mode(), " before=", GameSave.staff_tips)
	var result: Dictionary = await AdTipService.play_rewarded()
	print("SMOKE ad result=", result)
	if not result.get("ok", false):
		push_error("SMOKE FAIL ad did not credit staff tip")
		quit(1)
		return
	if GameSave.staff_tips < 1:
		push_error("SMOKE FAIL staff jar still empty")
		quit(1)
		return
	print("SMOKE staff jar=", GameSave.staff_tips, " week=", GameSave.staff_tips_week)
	quit(0)
