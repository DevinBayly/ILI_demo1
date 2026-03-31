extends XROrigin3D

signal meta_retrieved_user_id
signal ready_to_transmit_uuid
var fall_back_ids = {"test_mxu9kf":26014973921520855,"devinbayly":26608951088711524}
# this is the opposite of the above for other person lookups
var other_ids_map =  {"test_mxu9kf":26608951088711524,"devinbayly":26014973921520855 }
var passthrough_enabled: bool = false

@onready var spatial_anchor_manager: OpenXRFbSpatialAnchorManager = $OpenXRFbSpatialAnchorManager

# Don't statically type this as `OpenXRMetaEnvironmentDepth` because it doesn't exist on Godot 4.4.
@onready var environment_depth_node = $XRCamera3D/OpenXRMetaEnvironmentDepth
# probably don't need this part actually
#@onready var depth_testing_mesh: MeshInstance3D = $XROrigin3D/RightHand/DepthTestingMesh
@onready var world_environment = $WorldEnvironment
var ourselves:MetaPlatformSDK_User
var our_int_id: int
var other_user_int_id:int
var shared_anchor_uuid:String


signal collider_clicked

const SPATIAL_ANCHORS_FILE = "res://openxr_fb_spatial_anchors.json"

const MAX_DISPLAY_FRIENDS := 5
const SIMPLE_ACHIEVEMENT_NAME := "simple-achievement-example"
const COUNT_ACHIEVEMENT_NAME := "count-achievement-example"
const BITFIELD_ACHIEVEMENT_NAME := "bitfield-achievement-example"
const BITFIELD_ACHIEVEMENT_LENGTH := 5
const DURABLE_ADDON_SCENE_PATH := "res://dlc/durable_addon.tscn"
const DURABLE_ADDON_SKU := "0001"
const CONSUMABLE_ADDON_SKU := "0002"
const SUBSCRIPTION_SKU := "0003"

# You need to supply your own application ID from https://developers.meta.com/ in order to test this app.
var APPLICATION_ID = "27131274483139776"
# After uploading the DLC asset file and releasing a build of the application,
# the asset ID can be found on https://developers.meta.com/ under
# Distribution -> Builds -> (select new build) -> Expansion Files
var DURABLE_ADDON_ID = 0

var platform_sdk_initialized := false

var purchase_processing := false
var durable_displayed := false
var durable_filepath := ""

var simple_achievement_processing := true
var count_achievement_processing := true
var bitfield_achievement_processing := true
var simple_achievement_unlocked := false
var count_achievement_unlocked := false
var bitfield_achievement_unlocked := false


@onready var initialization_info: Node3D = $InitializationInfo
@onready var user_info: Node3D = $UserInfo
@onready var achievement_info: Node3D = $AchievementInfo
@onready var iap_info: Node3D = $IAPInfo
@onready var friend_info: Node3D = $FriendInfo
@onready var dlc_position: Node3D = %DLCPosition

@onready var left_controller_ray_cast: RayCast3D = $LeftController/LeftControllerRayCast
@onready var right_controller_ray_cast: RayCast3D = $RightController/RightControllerRayCast
@onready var initialization_label: Label3D = $InitializationInfo/InitializationLabel
@onready var entitled_label: Label3D = $UserInfo/EntitledLabel
@onready var oculus_id_label: Label3D = $UserInfo/OculusIDLabel
@onready var user_image: Sprite3D = $UserInfo/UserImage
@onready var friend_names_label: Label3D = $FriendInfo/FriendNamesLabel
@onready var simple_achievement_label: Label3D = $AchievementInfo/SimpleAchievementInfo/SimpleAchievementLabel
@onready var count_achievement_label: Label3D = $AchievementInfo/CountAchievementInfo/CountAchievementLabel
@onready var bitfield_achievement_label: Label3D = $AchievementInfo/BitfieldAchievementInfo/BitfieldAchievementLabel
@onready var consumable_addon_label: Label3D = %ConsumableAddonLabel
@onready var durable_addon_label: Label3D = %DurableAddonLabel
@onready var subscription_label: Label3D = %SubscriptionLabel
var xr_interface
func _ready() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		var vp: Viewport = get_viewport()
		vp.use_xr = true

		#vp.transparent_bg = true
		# not sure if this is necessary
		#DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		#xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
		xr_interface.session_begun.connect(_on_openxr_session_begun)

	if ResourceLoader.exists("res://local.gd"):
		var local = load('res://local.gd')
		if local and "APPLICATION_ID" in local:
			APPLICATION_ID = local.APPLICATION_ID
		if local and "DURABLE_ADDON_ID" in local:
			DURABLE_ADDON_ID = local.DURABLE_ADDON_ID

	if APPLICATION_ID == "":
		initialization_label.text += "No app ID provided!"
		hide_non_initialization_info()
		return

	OS.request_permissions()

	initialize_platform_sdk()

func _on_openxr_session_begun():
	load_spatial_anchors_from_file()
	enable_passthrough(true)

	#var environment_depth = Engine.get_singleton("OpenXRMetaEnvironmentDepthExtensionWrapper")
	#if environment_depth:
		#print("Supports environment depth: ", environment_depth.is_environment_depth_supported())
		#print("Supports hand removal: ", environment_depth.is_hand_removal_supported())
		#if environment_depth.is_environment_depth_supported():
			#environment_depth.start_environment_depth()
			#print("Environment depth started: ", environment_depth.is_environment_depth_started())

func enable_passthrough(enable: bool) -> void:
	if passthrough_enabled == enable:
		return

	var supported_blend_modes = xr_interface.get_supported_environment_blend_modes()
	if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in supported_blend_modes and XRInterface.XR_ENV_BLEND_MODE_OPAQUE in supported_blend_modes:
		if enable:
			# Switch to passthrough.
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
			get_viewport().transparent_bg = true
			world_environment.environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
		else:
			# Switch back to VR.
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
			get_viewport().transparent_bg = false
			world_environment.environment.background_color = Color(0.3, 0.3, 0.3, 1.0)
		passthrough_enabled = enable


func initialize_platform_sdk():
	var result: MetaPlatformSDK_Message

	result = await MetaPlatformSDK.initialize_platform_async(APPLICATION_ID).completed
	if result.is_error():
		initialization_label.text += "FAILED"
		hide_non_initialization_info()
		return

	var platform_initialize := result.get_platform_initialize()
	if platform_initialize.result != MetaPlatformSDK.PLATFORM_INITIALIZE_SUCCESS:
		initialization_label.text += "FAILED"
		hide_non_initialization_info()
		return

	platform_sdk_initialized = true
	#initialization_label.text += "SUCCESS"

	MetaPlatformSDK.notification_received.connect(on_notification_received)

	update_user_info()
	#update_friend_info()
	

func on_notification_received(message: MetaPlatformSDK_Message):
	if message.is_error():
		push_error("Error message received. Code: %s | Message: %s" % [message.error.code, message.error.message])
		return

	# This demo only expects messages for asset file download updates.
	if message.get_type_as_string() != "MESSAGE_NOTIFICATION_ASSET_FILE_DOWNLOAD_UPDATE":
		print("Unexpected message received of type %s" % message.get_type_as_string())
		return

	
func load_spatial_anchors_from_file():
	pass


var entities =[]
var entity:OpenXRFbSpatialEntity
func _on_spatial_anchor_tracked(_anchor_node: XRAnchor3D, _spatial_entity: OpenXRFbSpatialEntity, is_new: bool) -> void:
	entities.push_back(_spatial_entity)
	entity = _spatial_entity
	print("entity is tracked, checking enablement")
	print("\n\n")
	_spatial_entity.openxr_fb_spatial_entity_set_component_enabled_completed.connect(on_set_component_enabled)
	_spatial_entity.set_component_enabled(OpenXRFbSpatialEntity.COMPONENT_TYPE_STORABLE,true)
	# set component type to shared
	# set it to save in cloud
	
	
	#entities.push_back(_spatial_entity)
	if is_new:
		save_spatial_anchors_to_file()
func on_set_component_enabled(p_succeeded: bool, p_component: OpenXRFbSpatialEntity.ComponentType, p_enabled: bool)-> void:
	print(p_component," succeeded? ",p_succeeded, " enabled ",p_enabled)
	if p_enabled and p_component == OpenXRFbSpatialEntity.COMPONENT_TYPE_STORABLE:
		if not p_succeeded:
			print("ran into a fail with the storable enabling in callback")
			return
		# once we get here we can try to do a share because things will have been enabled
		print("yes the element got type updated to storable")
		# now we will try to make it sharable, triggering this call back again but with a different conditional
		entity.set_component_enabled(OpenXRFbSpatialEntity.COMPONENT_TYPE_SHARABLE,true)
	elif p_enabled and p_component == OpenXRFbSpatialEntity.COMPONENT_TYPE_SHARABLE:
		# disconnect via reference to last element in entities
		entity.openxr_fb_spatial_entity_set_component_enabled_completed.disconnect(on_set_component_enabled)
		if not p_succeeded:
			print("ran into a fail with the sharable enabling in callback")
			return
		# once we get here we can try to do a share because things will have been enabled
		print("yes the element got type updated to sharable")
		entity.save_to_storage(OpenXRFbSpatialEntity.STORAGE_CLOUD)
		entity.openxr_fb_spatial_entity_saved.connect(saved_cloud_signal_listener)
	
var actively_shared_entity:OpenXRFbSpatialEntity
func saved_cloud_signal_listener(res,loc):
	if res:
		
		print("yes it was saved to", loc, "good job")
		# then 	# share with other user
		actively_shared_entity = entities.pop_back()
		var typed_user:OpenXRFbSpatialEntityUser = OpenXRFbSpatialEntityUser.create_user(other_user_int_id)
		actively_shared_entity.share_with_users([typed_user])
		print("trying to share with user")
		actively_shared_entity.openxr_fb_spatial_entity_shared.connect(shared_with_users_signal_listener)
	else:
		print("nope failed to save to ",loc)

func shared_with_users_signal_listener(res):
	if res:
		print("yup the anchor was shared",res)
		#get out uuid and then pass it along to the networking
		# emit the uuid signal
		ready_to_transmit_uuid.emit(actively_shared_entity.uuid)
		
		
		
# last but not least this is where we actually load up an anchor from a uuid that has been shared with us
func load_from_shared_uuid(uuid):
	print("completing the round trip, storing the results on screen")
	shared_anchor_uuid = uuid
	spatial_anchor_manager.load_anchor(shared_anchor_uuid)

func _on_spatial_anchor_untracked(_anchor_node: XRAnchor3D, _spatial_entity: OpenXRFbSpatialEntity) -> void:
	save_spatial_anchors_to_file()
	
func save_spatial_anchors_to_file():
	pass

func update_user_info():
	var result: MetaPlatformSDK_Message

	result = await MetaPlatformSDK.entitlement_get_is_viewer_entitled_async().completed
	if result.is_success():
		print("viewer entitled")
		#entitled_label.text += "TRUE"
	else:
		print("viewer isn't entitled")
		#entitled_label.text += "FALSE"

	result = await MetaPlatformSDK.user_get_logged_in_user_async().completed
	#if result.is_error():
		#print("error failed to get user data")
		#oculus_id_label.text = "Failed to get user data!"
		#push_error("Failed to get user data: ", result.error)
		#return
	var user: MetaPlatformSDK_User = result.get_user()
	print("user id before sending was ",user.id )
	ourselves = user
	#oculus_id_label.text += user.oculus_id
	## refer to the fall back map for id
	#our_int_id = fall_back_ids.get(user.oculus_id)
	our_int_id = user.id
	# use the map to get the other user id 
	other_user_int_id = other_ids_map[user.oculus_id]
	meta_retrieved_user_id.emit(our_int_id)
	#if user.image_url != "":
		#var image_request = HTTPRequest.new()
		#add_child(image_request)
		#image_request.request_completed.connect(self._image_request_completed.bind(image_request))
#
		#var error = image_request.request(user.image_url)
		#if error != OK:
			#push_error("There was an error with the image request.")
	


func update_friend_info():
	var result: MetaPlatformSDK_Message = await MetaPlatformSDK.user_get_logged_in_user_friends_async().completed
	if result.is_error():
		friend_names_label.text = "Error retrieving friends!"
		push_error("Error retrieving friends: ", result.error)
		return


	var friend_array := result.get_user_array()
	if friend_array.size() == 0:
		return

	var friend_count = 0
	friend_names_label.text = ""
	for friend in friend_array:
		if friend_count >= MAX_DISPLAY_FRIENDS:
			break
		var friend_name = friend.display_name if friend.display_name != "" else friend.oculus_id
		friend_names_label.text += friend_name + "\n"
		friend_count += 1





func hide_non_initialization_info():
	user_info.hide()
	achievement_info.hide()
	iap_info.hide()
	friend_info.hide()


func update(collider_name):
	if not platform_sdk_initialized:
		return
	print("trigger clicked on ",collider_name)
	#match collider_name:
		




func _on_left_controller_button_pressed(name: String) -> void:
	if name == "trigger_click" and left_controller_ray_cast.is_colliding():
		var collider = left_controller_ray_cast.get_collider()
		update(collider.name)


func _on_right_controller_button_pressed(name: String) -> void:
	if name == "trigger_click" and right_controller_ray_cast.is_colliding():
		
		var collider = right_controller_ray_cast.get_collider()
		print("trigger clicked on object",collider)
		var position_collide = right_controller_ray_cast.target_position
		print("position of collision is",position_collide)
		collider_clicked.emit(collider,position_collide)
		var anchor_transform := Transform3D()
		anchor_transform.origin = right_controller_ray_cast.get_collision_point()
		print("origin position of collision is",anchor_transform.origin)

		var collision_normal: Vector3 = right_controller_ray_cast.get_collision_normal()
		if collision_normal.is_equal_approx(Vector3.UP):
			anchor_transform.basis = anchor_transform.basis.rotated(Vector3(1.0, 0.0, 0.0), PI / 2.0)
		elif collision_normal.is_equal_approx(Vector3.DOWN):
			anchor_transform.basis = anchor_transform.basis.rotated(Vector3(1.0, 0.0, 0.0), -PI / 2.0)
		else:
			anchor_transform.basis = Basis.looking_at(right_controller_ray_cast.get_collision_normal())
		print("creating anchor")
		spatial_anchor_manager.create_anchor(anchor_transform)
		update(collider.name)
	if name == "ax_button":
		# we will try to resend our identification now
		meta_retrieved_user_id.emit(our_int_id)
		



# processing per frame not necessary just send position when trigger pressed
#var timeout = 1
#func _physics_process(delta: float) -> void:
	#timeout -=delta
	#if timeout <0:
		#
		#timeout=1
		## check if the right controller has hit anything
		#if left_controller_ray_cast.is_colliding():
			#var object = left_controller_ray_cast.get_collider()
			#var position_collision = left_controller_ray_cast.target_position
