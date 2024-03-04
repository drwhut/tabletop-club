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

## Fired when we have failed to connect to the given peer.
signal connection_to_peer_failed(peer_id)

## Fired when the connection to the given peer has been closed.
signal connection_to_peer_closed(peer_id)


## Fired when a [NetworkedMultiplayerPeer] has been assigned to the scene tree.
## [b]NOTE:[/b] If [param room_code] is empty, it means the network is using the
## ENet protocol instead of the WebRTC protocol.
signal network_init(room_code)

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


## Initialise the network for singleplayer use. This is required in order for
## RPCs to work locally, even if they won't be sent to another client.
func start_server_solo() -> void:
	print("NetworkManager: Starting the network in singleplayer mode...")
	
	if get_tree().network_peer != null:
		push_error("Failed to start network, network already exists")
		emit_signal("setup_failed", ERR_ALREADY_IN_USE)
		return
	
	var network := NetworkedMultiplayerCustom.new()
	network.set_connection_status(NetworkedMultiplayerPeer.CONNECTION_CONNECTING)
	network.initialize(1) # Sets the connection status to CONNECTED.
	get_tree().network_peer = network
	
	emit_signal("network_init", "") # No room code.


## Initialise the multiplayer network as a WebRTC server, a.k.a. the host.
func start_server_webrtc() -> void:
	print("NetworkManager: Starting the multiplayer network as a WebRTC server...")
	
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


## Initialise the multiplayer network as a WebRTC client, by joining the lobby
## with the given [param room_code].
func start_client_webrtc(room_code: String) -> void:
	print("NetworkManager: Starting the multiplayer network as a WebRTC client...")
	
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
	
	# If there are any connection timers ongoing, stop them and remove them from
	# the scene tree.
	_stop_connection_timer_all()
	
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


## Get the list of peer IDs that have been added to the network.
## [b]NOTE:[/b] This differs from [method SceneTree.get_network_connected_peers]
## in that not all of the peers will be connected. Clients only establish a
## connection to the server, not to other clients.
func get_peer_ids() -> PoolIntArray:
	var ids := PoolIntArray()
	
	var network := get_tree().network_peer
	if network is WebRTCMultiplayer:
		for element in network.get_peers().keys():
			var id: int = element
			ids.push_back(id)
	
	return ids


## Check if we are currently connected to a multiplayer network.
func is_connected_to_network() -> bool:
	var network_multiplayer := get_tree().network_peer
	if network_multiplayer == null:
		return false
	
	var conn_status := network_multiplayer.get_connection_status()
	return conn_status == NetworkedMultiplayerPeer.CONNECTION_CONNECTED


# Start a timer for the peer with the given [param peer_id] which, if it runs
# out, will forcefully remove the peer from the network. If the peer manages to
# establish a connection with us, the timer should be stopped.
func _start_connection_timer(peer_id: int) -> void:
	var node_name := "Timeout_%d" % peer_id
	if has_node(node_name):
		push_error("Cannot start connection timer for peer '%d', timer already exists" % peer_id)
		return
	
	# Use the same timeout duration that other connections use.
	var timeout_sec: int = ProjectSettings.get_setting(
			"network/limits/tcp/connect_timeout_seconds")
	
	var timer := Timer.new()
	timer.name = node_name
	timer.wait_time = timeout_sec
	timer.one_shot = true
	timer.autostart = true
	
	timer.connect("timeout", self, "_on_connection_timer_timeout", [ peer_id ])
	
	print("NetworkManager: Starting connection timer for peer '%d'..." % peer_id)
	add_child(timer)


# Stop the connection timer for the peer with the given [param peer_id], and
# queue it to be removed from the scene tree. This will prevent the peer from
# being removed from the network when the timer runs out.
func _stop_connection_timer(peer_id: int) -> void:
	var node_name := "Timeout_%d" % peer_id
	if not has_node(node_name):
		push_error("Cannot stop connection timer for peer '%d', timer does not exist" % peer_id)
		return
	
	var timer_node := get_node(node_name)
	if not timer_node is Timer:
		push_error("Connection timer for peer '%d' is unexpected type" % peer_id)
		return
	
	if timer_node.is_queued_for_deletion():
		push_warning("Connection timer for peer '%d' is already queued for deletion" % peer_id)
		return
	
	print("NetworkManager: Stopping connection timer for peer '%d'..." % peer_id)
	timer_node.queue_free()


# Stop all connection timers that are currently running, and queue them to be
# removed from the scene tree.
func _stop_connection_timer_all() -> void:
	var child_count := get_child_count()
	if child_count <= 0:
		return
	
	print("NetworkManager: Stopping all connection timers (total: %d)..." % child_count)
	
	for element in get_children():
		var child: Node = element
		if child.is_queued_for_deletion():
			continue
		
		if child is Timer:
			child.queue_free()


# Check if a connection timer is currently running for the peer with the given
# [param peer_id].
func _is_connection_timer_running(peer_id: int) -> bool:
	var node_name := "Timeout_%d" % peer_id
	return has_node(node_name)


func _on_connection_timer_timeout(peer_id: int):
	print("NetworkManager: Connection timer for peer '%d' has run out, removing them from the network..." % peer_id)
	
	var rtc := get_tree().network_peer
	if rtc is WebRTCMultiplayer:
		# NOTE: While this removes the peer from the WebRTC network, the master
		# server will probably still think the peer is in the lobby.
		# We cannot send a command to the master server to remove them from the
		# lobby, so the peer's ID will still be sent to any new players that
		# join.
		# This is the reason why we rely on the Lobby system to determine the
		# players that have joined, rather than the MasterServer. There is the
		# possibility of a discrepancy between who has actually joined the
		# network, and who the master server *thinks* has joined the network.
		rtc.remove_peer(peer_id)
	else:
		push_error("Cannot remove peer '%d', WebRTC network does not exist" % peer_id)
	
	# Now that the timer has run out, we can queue it to be removed from the
	# scene tree.
	_stop_connection_timer(peer_id)
	
	# If we failed to connect to the host as a client, then we cannot recover in
	# any way, so turn the lights off and say good night.
	if peer_id == 1:
		stop()
	
	# Since the connection was not established, the signals from the multiplayer
	# interface won't fire, but we still need to let the outside world know that
	# the peer has failed to connect.
	emit_signal("connection_to_peer_failed", peer_id)
	if peer_id == 1:
		emit_signal("connection_to_host_failed")


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
	
	# A connection has been established, so we should stop the connection timer
	# for this peer so that they do not get removed from the network.
	_stop_connection_timer(peer_id)
	
	emit_signal("connection_to_peer_established", peer_id)


func _on_SceneTree_network_peer_disconnected(peer_id: int):
	print("NetworkManager: Connection to peer with ID '%d' has been closed." % peer_id)
	
	# This shouldn't happen, but just in case the connection timer was ongoing,
	# we should stop it so that it doesn't end up firing the 'peer_closed'
	# signal a second time.
	if _is_connection_timer_running(peer_id):
		_stop_connection_timer(peer_id)
	
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
			if rtc.get_unique_id() == 1:
				print("NetworkManager: No connected peers, continuing alone...")
				
				# Remove all of the peers from the network, even if they were in
				# the middle of connecting.
				for key in rtc.get_peers():
					var peer_id: int = key
					rtc.remove_peer(peer_id)
			else:
				print("NetworkManager: No connected peers, closing network...")
				get_tree().network_peer = null
			
			# If there were any connection timers ongoing, we can stop them
			# since we are no longer trying to connect to any peers.
			_stop_connection_timer_all()
	
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
	
	emit_signal("network_init", room_code)
	
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
		
		# If an attempt is about to be made to establish a connection, then we
		# will start a timer that will effectively act as a time limit for the
		# connection to be made. We need to make our own timers since the WebRTC
		# library has no way of signalling that after the ICE candidates have
		# been exchanged, no connection could be made - it just sits there...
		# Menacingly...
		# NOTE: Both the host and the client will create these timers.
		if rtc.get_unique_id() == 1 or peer_id == 1:
			_start_connection_timer(peer_id)
		
		# Only have the host initiate the connections. That way, the host will
		# create connections to all of the clients, but the clients won't create
		# connections to other clients, since they are not needed.
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
	# While unlikely, we can check if there was a connection timer for the peer
	# that we can stop and remove from the scene tree.
	if _is_connection_timer_running(peer_id):
		_stop_connection_timer(peer_id)
	
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
