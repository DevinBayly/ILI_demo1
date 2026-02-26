extends Node3D
@onready var cam = $Character/Head/Camera

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# create something at this location
			var new_mesh = MeshInstance3D.new()
			new_mesh.mesh = BoxMesh.new()
			new_mesh.scale = Vector3(.1,.1,.1)
			# get position
			var view:Viewport = get_viewport()
			var halfvec = view.get_visible_rect().size/2
			new_mesh.position = cam.project_position(halfvec,1)
			add_child(new_mesh)
