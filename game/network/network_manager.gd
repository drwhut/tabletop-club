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

## Fired when we, the client, have disconnected from the host gracefully.
signal connection_to_host_closed()

## Fired when we, the client, have lost the connection to the host.
signal connection_to_host_lost()


## Fired when we have established a connection to another peer.
signal connection_to_peer_established(peer_id)

## Fired when the connection to the given peer has been closed.
signal connection_to_peer_closed(peer_id)


## Fired when there was an error setting up the network.
## [b]NOTE:[/b] If this is fired, the NetworkManager will automatically close
## all network connections.
signal setup_failed(err)

## Fired when we have disconnected from the master server.
## [b]NOTE:[/b] The network may still be healthy afterwards.
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
	connect("setup_failed", self, "_on_setup_failed")
	connect("tree_exiting", self, "_on_tree_exiting")
	
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
		push_error("Failed to start network, network already exists")
		emit_signal("setup_failed", ERR_ALREADY_IN_USE)
		return
	
	_instruction_on_connection = ""
	
	var err := MasterServer.connect_to_official_server()
	if err != OK:
		push_error("Failed to start network, connection to master server failed")
		emit_signal("setup_failed", err)
		return


## Initialise the multiplayer network as a client, and attempt to join the room
## with the given [param room_code].
func start_as_client(room_code: String) -> void:
	print("NetworkManager: Starting the network as a client...")
	
	if get_tree().network_peer != null:
		push_error("Failed to start network, network already exists")
		emit_signal("setup_failed", ERR_ALREADY_IN_USE)
		return
	
	_instruction_on_connection = room_code
	
	var err := MasterServer.connect_to_official_server()
	if err != OK:
		push_error("Failed to start network, connection to master server failed")
		emit_signal("setup_failed", err)
		return


## Shut down the network, closing all network connections.
func stop() -> void:
	print("NetworkManager: Shutting down the network...")
	
	# If we are currently hosting a game, we want to seal the room before we go.
	var master_server_status := MasterServer.get_connection_status()
	var is_network_server := get_tree().is_network_server() \
			if get_tree().has_network_peer() else false
	
	if (
		is_network_server and
		master_server_status == NetworkedMultiplayerPeer.CONNECTION_CONNECTED
	):
		MasterServer.seal_room()
	
	# Do this first so that no more messages come through.
	MasterServer.close_connection()
	
	var network_multiplayer := get_tree().network_peer
	if network_multiplayer is WebRTCMultiplayer:
		print("NetworkManager: Closing all WebRTC connections and channels...")
		network_multiplayer.close()
	
	# It's very possible that this function is being called as a result of a
	# signal being fired from the network peer. We don't want to free it while
	# it is still in the middle of a signal, so defer freeing it until all of
	# its signals are processed.
	get_tree().set_deferred("network_peer", null)


## Check if we are currently connected to a multiplayer network.
func is_connected_to_network() -> bool:
	var network_multiplayer := get_tree().network_peer
	if network_multiplayer == null:
		return false
	
	var conn_status := network_multiplayer.get_connection_status()
	return conn_status == NetworkedMultiplayerPeer.CONNECTION_CONNECTED


func _on_setup_failed(_err: int):
	print("NetworkManager: Setup failed, closing all network connections...")
	stop()


func _on_tree_exiting():
	print("NetworkManager: Shutting down the network before leaving the scene tree...")
	stop()


func _on_SceneTree_connected_to_server():
	print("NetworkManager: Connection to the host has been established.")
	emit_signal("connection_to_host_established")


func _on_SceneTree_connection_failed():
	print("NetworkManager: Failed to connect to the host.")
	
	# There's nothing we can do to recover, so shut down the network.
	stop()
	
	emit_signal("connection_to_host_failed")


func _on_SceneTree_network_peer_connected(peer_id: int):
	print("NetworkManager: Connection to peer with ID '%d' has been established." % peer_id)
	emit_signal("connection_to_peer_established", peer_id)


func _on_SceneTree_network_peer_disconnected(peer_id: int):
	print("NetworkManager: Connection to peer with ID '%d' has been closed." % peer_id)
	emit_signal("connection_to_peer_closed", peer_id)


func _on_SceneTree_server_disconnected():
	print("NetworkManager: Connection to the host has been lost.")
	
	# We might as well shut down the network now that we have disconnected.
	stop()
	
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
	# If the network has been established as the master server disconnects, we
	# can keep the session going without it - the only downside being no one
	# will be able to join the session until a new one is made.
	var rtc := get_tree().network_peer
	if rtc is WebRTCMultiplayer:
		print("NetworkManager: WebRTC network is still ongoing, checking if any peers are connected...")
		var at_least_one_peer_connected := false
		var peer_conn_dict: Dictionary = rtc.get_peers()
		
		for value in peer_conn_dict.values():
			var peer_dict: Dictionary = value
			var is_connected: bool = peer_dict["connected"]
			if is_connected:
				at_least_one_peer_connected = true
				break
		
		if at_least_one_peer_connected:
			print("NetworkManager: At least one peer is connected, keeping network alive.")
		else:
			print("NetworkManager: Not connected to any peers on the network, closing network...")
			get_tree().network_peer = null
	
	emit_signal("lobby_server_disconnected", code)


func _on_MasterServer_connection_failed():
	# NOTE: This can only be fired if we are trying to setup the network.
	print("NetworkManager: Failed to setup network, could not connect to the master server.")
	emit_signal("setup_failed", ERR_UNAVAILABLE)


func _on_MasterServer_connection_lost():
	print("NetworkManager: Lost connection to the master server, proceeding as if it was closed manually...")
	_on_MasterServer_connection_closed(MasterServer.CODE_UNREACHABLE)


func _on_MasterServer_room_joined(room_code: String):
	if _last_id_from_lobby_server < 1:
		push_error("Master server added client to room '%s' without an ID" % room_code)
		
		emit_signal("setup_failed", ERR_CANT_CREATE)
		return
	
	print("NetworkManager: Setting up the WebRTCMultiplayer network as ID '%d'..." %
			_last_id_from_lobby_server)
	
	var rtc := WebRTCMultiplayer.new()
	var err := rtc.initialize(_last_id_from_lobby_server, true)
	if err != OK:
		push_error("Failed to create WebRTCMultiplayer network (error: %d)" % err)
		
		emit_signal("setup_failed", err)
		return
	
	get_tree().network_peer = rtc
	print("NetworkManager: WebRTCMultiplayer set as network interface.")
	
	# Now that we have the network set up, if the master server sent us any peer
	# IDs beforehand, we can add them to the network now.
	for peer_id in _peer_ids_known_before_init:
		_on_MasterServer_peer_arriving(peer_id)
	
	_peer_ids_known_before_init.resize(0) # Still annoyed there is no clear()...


func _on_MasterServer_room_sealed():
	print("NetworkManager: Host has sealed the room, closing all network connections...")
	stop()
	
	emit_signal("connection_to_host_closed")


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
			
			# Only close the connection if we are the client trying to connect
			# to the host.
			if peer_id == 1:
				emit_signal("setup_failed", err)
			
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
			
			if peer_id == 1:
				emit_signal("setup_failed", err)
			
			return
		
		# Only have the host initiate the connections. That way, the host will
		# create connections to all of the clients, but the clients won't create
		# connections to other clients, since they are not needed.
		# TODO: There is a chance that these exchanges don't result in a valid
		# connection. We need to find a way to remove the peers if they don't
		# create a connection in time (add to CHANGELOG). Needs to be done by
		# the host so a modified client can't linger, regardless of if the
		# master server thinks they are still connected.
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
	var rtc := get_tree().network_peer
	if rtc is WebRTCMultiplayer:
		if rtc.has_peer(peer_id):
			print("NetworkManager: Removing peer '%d' from the network..." % peer_id)
			
			# NOTE: If they were fully connected, this should fire the
			# 'network_peer_disconnected' signal from the scene tree.
			rtc.remove_peer(peer_id)
		else:
			print("NetworkManager: Peer '%d' has already disconnected from the network." % peer_id)
	
	else:
		push_error("Received 'peer_leaving' message from the master server without WebRTC network")


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
			# Instead of calling it quits here, wait for the connection timeout.
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
			# Instead of calling it quits here, wait for the connection timeout.
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
			# Instead of calling it quits here, wait for the connection timeout.
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
			# Instead of calling it quits here, wait for the connection timeout.
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
