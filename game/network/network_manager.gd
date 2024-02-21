# tabletop-club
# Copyright (c) 2020-2024 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2024 Tabletop Club contributors (see game/CREDITS.tres).
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

extends Node

## Creates and maintains the [NetworkedMultiplayerPeer] within the [SceneTree].
##
## [b]NOTE:[/b] This global is in the middle of the network stack that consists
## of the MasterServer (the lower level), and the Lobby (the higher level).
## In most circumstances, it is highly advised to use the Lobby global to
## interface with the network rather than this one.


## Fired when we, the client, have established a connection to the host.
signal connection_to_host_established()

## Fired when we, the client, failed to connect to the host.
signal connection_to_host_failed()

## Fired when we, the client, have lost the connection to the host.
signal connection_to_host_lost()


## Fired when we have established a connection to another peer.
signal connection_to_peer_established(peer_id)

## Fired when the connection to the given peer has been closed.
signal connection_to_peer_closed(peer_id)


## Fired when there was an error setting up the network.
signal setup_failed(code)

## Fired when the master server disconnected after setting up the network.
signal lobby_server_disconnected(code)


# Describes what to do once we establish a connection with the master server.
# If empty, host a room. Otherwise, join the given room.
var _instruction_on_connection := ""

# The last ID that the master server assigned us. If 0, we have not been given
# an ID yet.
var _last_id_from_lobby_server := 0

# The list of peer IDs that were sent to us by the master server before creating
# the WebRTC network.
var _peer_ids_known_before_init := PoolIntArray()


func _ready():
	get_tree().connect("connected_to_server", self,
			"_on_SceneTree_connected_to_server")
	get_tree().connect("connection_failed", self,
			"_on_SceneTree_connection_failed")
	get_tree().connect("network_peer_connected", self,
			"_on_SceneTree_network_peer_connected")
	get_tree().connect("network_peer_disconnected", self,
			"_on_SceneTree_network_peer_disconnected")
	get_tree().connect("server_disconnected", self,
			"_on_SceneTree_server_disconnected")
	
	MasterServer.connect("connection_established", self,
			"_on_MasterServer_connection_established")
	MasterServer.connect("connection_closed", self,
			"_on_MasterServer_connection_closed")
	MasterServer.connect("connection_failed", self,
			"_on_MasterServer_connection_failed")
	MasterServer.connect("connection_lost", self,
			"_on_MasterServer_connection_lost")
	
	MasterServer.connect("room_joined", self, "_on_MasterServer_room_joined")
	MasterServer.connect("room_sealed", self, "_on_MasterServer_room_sealed")
	
	MasterServer.connect("id_assigned", self, "_on_MasterServer_id_assigned")
	MasterServer.connect("peer_arriving", self, "_on_MasterServer_peer_arriving")
	MasterServer.connect("peer_leaving", self, "_on_MasterServer_peer_leaving")
	
	MasterServer.connect("offer_received", self,
			"_on_MasterServer_offer_received")
	MasterServer.connect("answer_received", self,
			"_on_MasterServer_answer_received")
	MasterServer.connect("candidate_received", self,
			"_on_MasterServer_candidate_received")


## Initialise the multiplayer network as the server, or host.
func start_as_server() -> void:
	print("NetworkManager: Starting the network as a server...")
	
	if get_tree().network_peer != null:
		push_error("Failed to start network, network peer already exists")
		emit_signal("setup_failed", MasterServer.CODE_ALREADY_IN_LOBBY)
		return
	
	_instruction_on_connection = ""
	
	var err := MasterServer.connect_to_official_server()
	if err != OK:
		push_error("Failed to start network, connection to master server failed")
		emit_signal("setup_failed", MasterServer.CODE_UNREACHABLE)
		return


## Initialise the multiplayer network as a client, and attempt to join the room
## with the given [param room_code].
func start_as_client(room_code: String) -> void:
	print("NetworkManager: Starting the network as a client...")
	
	if get_tree().network_peer != null:
		push_error("Failed to start network, network peer already exists")
		emit_signal("setup_failed", MasterServer.CODE_ALREADY_IN_LOBBY)
		return
	
	_instruction_on_connection = room_code
	
	var err := MasterServer.connect_to_official_server()
	if err != OK:
		push_error("Failed to start network, connection to master server failed")
		emit_signal("setup_failed", MasterServer.CODE_UNREACHABLE)
		return


## Shut down the network, closing all network connections.
func stop() -> void:
	print("NetworkManager: Shutting down the network...")
	
	# Do this first so that no more messages come through.
	MasterServer.close_connection()
	
	var network_multiplayer := get_tree().network_peer
	if network_multiplayer is WebRTCMultiplayer:
		print("NetworkManager: Closing all WebRTC connections and channels...")
		network_multiplayer.close()
	
	get_tree().network_peer = null


## Check if we are currently connected to a multiplayer network.
func is_connected_to_network() -> bool:
	var network_multiplayer := get_tree().network_peer
	if network_multiplayer == null:
		return false
	
	var conn_status := network_multiplayer.get_connection_status()
	return conn_status == NetworkedMultiplayerPeer.CONNECTION_CONNECTED


func _on_SceneTree_connected_to_server():
	print("NetworkManager: Connection to the host has been established.")
	emit_signal("connection_to_host_established")


func _on_SceneTree_connection_failed():
	print("NetworkManager: Failed to connect to the host.")
	emit_signal("connection_to_host_failed")


func _on_SceneTree_network_peer_connected(peer_id: int):
	print("NetworkManager: Connection to peer with ID '%d' has been established." % peer_id)
	emit_signal("connection_to_peer_established", peer_id)


func _on_SceneTree_network_peer_disconnected(peer_id: int):
	print("NetworkManager: Connection to peer with ID '%d' has been closed." % peer_id)
	emit_signal("connection_to_peer_closed", peer_id)


func _on_SceneTree_server_disconnected():
	print("NetworkManager: Connection to the host has been lost.")
	emit_signal("connection_to_host_lost")


func _on_MasterServer_connection_established():
	# We will need to get a new ID from the master server at some point.
	_last_id_from_lobby_server = 0
	
	# We will also get new peer IDs as well.
	_peer_ids_known_before_init.resize(0) # <- No .clear() function??
	
	if _instruction_on_connection.empty():
		MasterServer.host_room()
	else:
		MasterServer.join_room(_instruction_on_connection)


func _on_MasterServer_connection_closed(code: int):
	if is_connected_to_network():
		print("NetworkManager: Master server closed connection during network session.")
		# TODO: Figure out what signal to fire based on the code.
		emit_signal("lobby_server_disconnected", code)
	
	else:
		# TODO: This is almost always called, since it takes time for the master
		# server connection to close, but closing the WebRTC connections is
		# pretty much instant. Need to re-think this section.
		print("NetworkManager: Master server closed connection during network setup.")
		emit_signal("setup_failed", code)


func _on_MasterServer_connection_failed():
	# NOTE: This can only be fired if we are trying to setup the network.
	print("NetworkManager: Failed to setup network, could not connect to the master server.")
	emit_signal("setup_failed", MasterServer.CODE_UNREACHABLE)


func _on_MasterServer_connection_lost():
	print("NetworkManager: Lost connection to the master server, proceeding as if it was closed manually...")
	_on_MasterServer_connection_closed(MasterServer.CODE_UNREACHABLE)


func _on_MasterServer_room_joined(room_code: String):
	if _last_id_from_lobby_server < 1:
		push_error("Master server added client to room '%s' without an ID" % room_code)
		
		# NOTE: This will result in 'setup_failed' being fired with code 1000.
		# TODO: Do we want to be able to send different closing codes?
		MasterServer.close_connection()
		return
	
	print("NetworkManager: Setting up the WebRTCMultiplayer network as ID '%d'..." %
			_last_id_from_lobby_server)
	
	var rtc := WebRTCMultiplayer.new()
	var err := rtc.initialize(_last_id_from_lobby_server, true)
	if err != OK:
		push_error("Failed to create WebRTCMultiplayer network (error: %d)" % err)
		
		MasterServer.close_connection()
		return
	
	get_tree().network_peer = rtc
	print("NetworkManager: WebRTCMultiplayer set as network interface.")
	
	# Now that we have the network set up, if the master server sent us any peer
	# IDs beforehand, we can add them to the network now.
	for peer_id in _peer_ids_known_before_init:
		_on_MasterServer_peer_arriving(peer_id)
	
	_peer_ids_known_before_init.resize(0) # Still annoyed there is no clear()...


func _on_MasterServer_room_sealed():
	# TODO: Handle the room being sealed.
	pass


func _on_MasterServer_id_assigned(self_id: int):
	_last_id_from_lobby_server = self_id


func _on_MasterServer_peer_arriving(peer_id: int):
	var rtc := get_tree().network_peer
	
	# If the WebRTC network has not been initialised yet, that's OK, we just
	# need to keep track of who the server says is in the lobby.
	if rtc == null:
		print("NetworkManager: Received peer ID '%d' before WebRTC setup." % peer_id)
		_peer_ids_known_before_init.push_back(peer_id)
		return
	
	if rtc is WebRTCMultiplayer:
		print("NetworkManager: Creating WebRTCPeerConnection for peer '%d'..." % peer_id)
		var peer := WebRTCPeerConnection.new()
		var err := peer.initialize({
			"iceServers": [
				{ "urls": [ "stun:stun.l.google.com:19302" ] }
			]
		})
		if err != OK:
			push_error("Failed to initialise WebRTCPeerConnection (error: %d)" % err)
			return
		
		peer.connect("session_description_created", self,
				"_on_webrtc_offer_created", [ peer_id ])
		peer.connect("ice_candidate_created", self,
				"_on_webrtc_new_ice_candidate", [ peer_id ])
		
		print("NetworkManager: Adding peer '%d' to WebRTCMultiplayer network..." % peer_id)
		err = rtc.add_peer(peer, peer_id)
		if err != OK:
			push_error("Failed to add peer '%d' to WebRTCMultiplayer (error: %d)" % [
					peer_id, err])
			return
		
		# Only have the host initiate the connections. That way, the host will
		# create connections to all of the clients, but the clients won't create
		# connections to other clients, since they are not needed.
		# TODO: There is a chance that these exchanges don't result in a valid
		# connection. We need to find a way to remove the peers if they don't
		# create a connection in time (add to CHANGELOG). Needs to be done by
		# the host so a modified client can't linger, regardless of if the
		# master server thinks they are still connected.
		# TODO: Check if the 'connection_failed' signal fires!!
		if rtc.get_unique_id() == 1:
			print("NetworkManager: Creating offer for peer '%d'..." % peer_id)
			err = peer.create_offer()
			if err != OK:
				push_error("Failed to create offer for peer '%d' (error: %d)" % [
						peer_id, err])
				return
	
	else:
		push_error("Received 'peer_arriving' message from the master server without WebRTC network")


func _on_MasterServer_peer_leaving(peer_id: int):
	# TODO: Handle the master server removing a peer from the room.
	pass


func _on_MasterServer_offer_received(peer_id: int, offer: String):
	var rtc := get_tree().network_peer
	if rtc is WebRTCMultiplayer:
		if not rtc.has_peer(peer_id):
			push_error("Cannot use offer from peer '%d', peer not registered" % peer_id)
			return
		
		var peer_dict: Dictionary = rtc.get_peer(peer_id)
		var peer: WebRTCPeerConnection = peer_dict["connection"]
		var err := peer.set_remote_description("offer", offer)
		if err != OK:
			push_error("Failed to set offer from peer '%d' (error: %d)" % [
					peer_id, err])
			return
	
	else:
		push_error("Cannot use offer from peer '%d', WebRTCMultiplayer not created" % peer_id)


func _on_MasterServer_answer_received(peer_id: int, answer: String):
	var rtc := get_tree().network_peer
	if rtc is WebRTCMultiplayer:
		if not rtc.has_peer(peer_id):
			push_error("Cannot use answer from peer '%d', peer not registered" % peer_id)
			return
		
		var peer_dict: Dictionary = rtc.get_peer(peer_id)
		var peer: WebRTCPeerConnection = peer_dict["connection"]
		var err := peer.set_remote_description("answer", answer)
		if err != OK:
			push_error("Failed to set answer from peer '%d' (error: %d)" % [
					peer_id, err])
			return
	
	else:
		push_error("Cannot use answer from peer '%d', WebRTCMultiplayer not created" % peer_id)


func _on_MasterServer_candidate_received(peer_id: int, mid: String, index: int,
		sdp: String) -> void:
	
	var rtc := get_tree().network_peer
	if rtc is WebRTCMultiplayer:
		if not rtc.has_peer(peer_id):
			push_error("Cannot use ICE candidate from peer '%d', peer not registered" % peer_id)
			return
		
		var peer_dict: Dictionary = rtc.get_peer(peer_id)
		var peer: WebRTCPeerConnection = peer_dict["connection"]
		var err := peer.add_ice_candidate(mid, index, sdp)
		if err != OK:
			push_error("Failed to add ICE candidate from peer '%d' (error: %d)" % [
					peer_id, err])
			return
	
	else:
		push_error("Cannot use ICE candidate from peer '%d', WebRTCMultiplayer not created" % peer_id)


func _on_webrtc_offer_created(type: String, data: String, peer_id: int):
	var rtc := get_tree().network_peer
	if rtc is WebRTCMultiplayer:
		if not rtc.has_peer(peer_id):
			push_error("Cannot use WebRTC offer for peer '%d', peer not registered" % peer_id)
			return
		
		print("NetworkManager: Created %s for peer '%d'." % [ type, peer_id ])
		var peer_dict: Dictionary = rtc.get_peer(peer_id)
		var peer: WebRTCPeerConnection = peer_dict["connection"]
		var err := peer.set_local_description(type, data)
		
		if err != OK:
			push_error("Failed setting local %s for peer '%d' (error: %d)" % [
					type, peer_id, err])
			return
		
		if type == "offer":
			MasterServer.send_offer(peer_id, data)
		else:
			MasterServer.send_answer(peer_id, data)
	
	else:
		push_error("Cannot use WebRTC offer, WebRTCMultiplayer not created")


func _on_webrtc_new_ice_candidate(mid: String, index: int, sdp: String, peer_id: int):
	var rtc := get_tree().network_peer
	if rtc is WebRTCMultiplayer:
		print("NetworkManager: Created ICE candidate for peer '%d'." % peer_id)
		MasterServer.send_candidate(peer_id, mid, index, sdp)
	
	else:
		push_error("Cannot use WebRTC ICE candidate, WebRTCMultiplayer not created")
