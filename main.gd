extends Node3D

@onready var clue_display = $clue_display
@onready var placement_ob = $placement_object

@export  var screen_position_projection_vector = Vector2(.5,.5)
@export var depth = 1
func _on_node_3d_show_clue(text) -> void:
	clue_display.set_text(text)
	pass # Replace with function body.


func _on_placement_object_ball_selected() -> void:
	print("ball selected")
	# set up to move object around
	# get the character's camera, project_position using the halfway point on the screen and some constant depth
	var char_cam = $Character/Head/Camera
	placement_ob.be_controlled(char_cam.project_position(screen_position_projection_vector,depth))
	pass # Replace with function body.
