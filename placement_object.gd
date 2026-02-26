extends Node3D
signal ball_selected

var selected_by_user = false

func _on_area_3d_mouse_entered() -> void:
	print("selected emitting")
	selected_by_user= true
	emit_signal("ball_selected")
	$RigidBody3D.gravity_scale =0

	pass # Replace with function body.


func be_controlled(pos):
	position = pos

func _on_area_3d_mouse_exited() -> void:
	print("unselected")
	selected_by_user= false
	$RigidBody3D.gravity_scale =1

	pass # Replace with function body.
