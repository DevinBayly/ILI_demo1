extends Node3D


func _on_main_collider_clicked(collider,collision_position) -> void:
	# this would be when we update the text in the label with the collided name and such
	$SubViewport/UI
	pass # Replace with function body.


func _on_main_meta_retrieved_user_id(oculus_id) -> void:
	# send the id over the network to the peers
	print("sending id over rpc from scene root")
	$networking.send_user_id.rpc(oculus_id)
	pass # Replace with function body.
