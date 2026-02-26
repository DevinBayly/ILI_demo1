extends Node3D

@export var clue=""
signal show_clue
func _on_area_3d_mouse_entered() -> void:
	print("mouse entered")
	emit_signal("show_clue",clue)
	pass # Replace with function body.
