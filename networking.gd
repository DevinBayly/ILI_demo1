extends Node
signal received_user_id
# By default, these expressions are interchangeable.
var PORT = 8081
#var IP_ADDRESS = "godotcommunicator.TRA220030.projects.jetstream-cloud.org"
#var IP_ADDRESS="localhost"
var IP_ADDRESS = "192.168.0.151"
var MAX_CLIENTS = 2
var peer
func _ready() -> void:
	if OS.has_feature("linux"):
		var arg = OS.get_cmdline_user_args()[0] # try to see if we started up with the word "server"
		print(OS.get_cmdline_user_args())
		if arg == "server":
			print("I am a server")
			# Create server.
			peer = ENetMultiplayerPeer.new()
			peer.create_server(PORT, MAX_CLIENTS)
			multiplayer.multiplayer_peer = peer
			multiplayer.peer_connected.connect(server_handle_peer_connect)
		
	else:
		print("I am a client")
		var peer = ENetMultiplayerPeer.new()
		peer.create_client(IP_ADDRESS, PORT)
		multiplayer.multiplayer_peer = peer
		multiplayer.connected_to_server.connect(client_connected_to_server)
		multiplayer.connection_failed.connect(con_failed)
		multiplayer.server_disconnected.connect(server_lost)
func server_lost():
	print("server lost")
func con_failed():
	print("failed to connect to server")
func client_connected_to_server():
	print("client made contact with server")
	# start a timeout that will then make an rpc call
	await get_tree().create_timer(2).timeout
	send_user_id.rpc("itsame")
	
func server_handle_peer_connect(id):
	print("server was contacted by peer id",id)
	
# the goal will be to have function that a peer can start to signal to the server that the other peer needs some information
@rpc("any_peer","call_remote","reliable",0)
func send_user_id(other_user_id):
	var sender_id = multiplayer.get_remote_sender_id()
	# ensure it's not our own id, and that we aren't server, well I suppose since we called remote it wont be
	if multiplayer.is_server():
		print("server responding",other_user_id)
		pass
	else:
		# store this as other player's id
		print("client responding",other_user_id)
		received_user_id.emit(other_user_id)

@rpc("any_peer","call_remote","reliable",0)
func send_anchor_uuid(shared_other_uuid):
	var sender_id = multiplayer.get_remote_sender_id()
	# ensure it's not our own id, and that we aren't server, well I suppose since we called remote it wont be
	if multiplayer.is_server():
		pass
	else:
		# store this as other player's id
		received_user_id.emit(shared_other_uuid)


# then we can have signals on this that say, received uuid anchor or user id is... 
#
#we will also maybe need to have something where the peer calls on the server a "vote" after placement, and the server registers that the vote matches a correct criteria?
