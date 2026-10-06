extends Node3D
## Cat and dog for the test-world patio. No colliders.

const PetScript := preload("res://scripts/explore/patio_pet.gd")


func _ready() -> void:
	name = "PatioPets"
	add_to_group("patio_pets")
	var cat: Node3D = PetScript.new()
	add_child(cat)
	cat.call("setup", "cat", Vector3(-4.2, 0.0, 2.6))
	var dog: Node3D = PetScript.new()
	add_child(dog)
	dog.call("setup", "dog", Vector3(4.0, 0.0, 1.4))
