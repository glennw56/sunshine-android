extends Node
## Forces the test patio before the instanced Explore scene builds.
## Store builds do not open this scene unless the test_world export feature is on.


func _enter_tree() -> void:
	AppConfig.test_world = true
