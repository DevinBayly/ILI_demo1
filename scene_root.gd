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


func _on_networking_received_user_id() -> void:
	# set this as a variable on the xr origin
	pass # Replace with function body.


func _on_networking_received_anchor_uuid(uuid) -> void:
	# function that make this anchor load on the alternate user
	
	pass # Replace with function body.


func _on_main_ready_to_transmit_uuid(uuid) -> void:
	print("sending shared uuid for anchor",uuid)
	$networking.send_anchor_uuid.rpc(uuid)
	pass # Replace with function body.
