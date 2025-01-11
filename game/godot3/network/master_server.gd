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

## The interface for the master server, which is a central server that keeps
## track of all of the multiplayer lobbies that are currently open.
##
## You can find the source code for the master server here:
## [url]https://github.com/drwhut/tabletop_club_master_server[/url]
##
## [b]NOTE:[/b] This script is a modified version of the webrtc_signalling demo,
## which is licensed under the MIT license, and can be found here:
## [url]https://github.com/godotengine/godot-demo-projects/blob/master/networking/webrtc_signaling/client/ws_webrtc_client.gd[/url]


## Fired when the connection to the master server is established successfully.
signal connection_established()

## Fired when the connection to the master server is closed gracefully.
signal connection_closed(code)

## Fired when an attempt to connect to the master server fails.
signal connection_failed()

## Fired when the connection to the master server is lost unexpectedly.
signal connection_lost()


## Fired when the master server notifies us that we have joined a room.
signal room_joined(room_code)

## Fired when the master server notifies us that the room has been sealed.
signal room_sealed()


## Fired when the master server has assigned the client an ID.
signal id_assigned(id)

## Fired when the master server notifies us of a new peer that wants to connect.
signal peer_arriving(id)

## Fired when the master server notifies us of a peer leaving the room.
signal peer_leaving(id)


## Fired when a peer has sent us an offer via the master server.
signal offer_received(id, offer)

## Fired when a peer has sent us an answer via the master server.
signal answer_received(id, answer)

## Fired when a peer has sent us a candidate via the master server.
signal candidate_received(id, mid, index, sdp)


## The list of possible close codes that the master server can give.
## [b]NOTE:[/b] As well as the custom error codes defined by the master server,
## this list also includes standard WebSocket close codes, as can be found here:
## [url]https://www.rfc-editor.org/rfc/rfc6455.html#section-7.4[/url]
enum {
	CODE_NORMAL = 1000, ## Closed normally.
	CODE_GOING_AWAY = 1001, ## Closed due to the server going down.
	CODE_PROTOCOL_ERROR = 1002, ## Closed due to a protocol error.
	CODE_TYPE_NOT_ACCEPTED = 1003, ## Closed due to text/binary mis-match.
	CODE_NO_STATUS = 1005, ## Closed, but with no code given.
	CODE_DISCONNECTED = 1006, ## Closed due to abrupt disconnect.
	CODE_INVALID_UTF8 = 1007, ## Closed due to invalid UTF-8 data.
	CODE_POLICY_VIOLATION = 1008, ## Closed due to policy violation.
	CODE_MESSAGE_TOO_BIG = 1009, ## Closed due to text being too large in size.
	CODE_UNEXPECTED_COND = 1011, ## Closed due to unexpected condition.
	CODE_TLS_ERROR = 1015, ## Closed due to TLS certificate error.
	
	CODE_GENERIC_ERROR = 4000, ## Closed due to a generic error.
	CODE_UNREACHABLE = 4001, ## Closed due to server being unreachable.
	CODE_NOT_IN_LOBBY = 4002, ## Closed due to client not being in a lobby.
	CODE_HOST_DISCONNECTED = 4003, ## Closed due to the host disconnecting.
	CODE_ONLY_HOST_CAN_SEAL = 4004, ## Closed due to attempt to seal as client.
	CODE_TOO_MANY_LOBBIES = 4005, ## Closed due to lobby limit being reached.
	CODE_ALREADY_IN_LOBBY = 4006, ## Closed due to already being in a lobby.
	CODE_LOBBY_DOES_NOT_EXIST = 4007, ## Closed due to non-existant lobby.
	CODE_LOBBY_IS_SEALED = 4008, ## Closed due to given lobby being sealed.
	CODE_INVALID_FORMAT = 4009, ## Closed due to message having invalid format.
	CODE_LOBBY_REQUIRED = 4010, ## Closed due to lobby not given when required.
	CODE_SERVER_ERROR = 4011, ## Closed due to an internal server error.
	CODE_INVALID_DESTINATION = 4012, ## Closed due to an invalid peer ID.
	CODE_INVALID_COMMAND = 4013, ## Closed due to an invalid command.
	CODE_TOO_MANY_PEERS = 4014, ## Closed due to client limit being reached.
	CODE_INVALID_MODE = 4015, ## Closed due to a binary message being sent.
	CODE_TOO_MANY_CONNECTIONS = 4016, ## Connection limit was reached.
	CODE_RECONNECT_TOO_QUICKLY = 4017, ## Re-connected too quickly.
	CODE_JOIN_QUEUE_FULL = 4018, ## Too many players joining rooms at once.
}


## The location of the official master server.
const OFFICIAL_URL := "wss://lobby.tabletopclub.net"


## The web socket client that connects to the master server.
var client := WebSocketClient.new()

## The last disconnect code that was sent by the master server.
var last_close_code := CODE_NORMAL


# A timer which counts down every time we receive a ping packet from the server.
# NOTE: If we cannot register ping packets (as in, the relevant engine patch has
# not been applied), the timer is never created.
var _keep_alive_timer: Timer = null

# A flag that is activated when we expect the connection to be dropped soon.
var _expecting_disconnect_flag := false


func _ready():
	client.verify_ssl = true
	
	client.connect("connection_closed", self, "_on_client_connection_closed")
	client.connect("connection_error", self, "_on_client_connection_error")
	client.connect("connection_established", self, "_on_client_connection_established")
	client.connect("data_received", self, "_on_client_data_received")
	client.connect("server_close_request", self, "_on_client_server_close_request")
	
	if client.has_signal("ping_received"):
		# We have the ability to detect ping packets from the server, so we can
		# check if the connection to the master server is still alive.
		client.connect("ping_received", self, "_on_client_ping_received")
		
		# Use the same timeout duration as for other TCP connections.
		var timeout_sec: int = ProjectSettings.get_setting(
				"network/limits/tcp/connect_timeout_seconds")
		print("MasterServer: Can detect ping packets, setting timeout to %d seconds..." % timeout_sec)
		
		_keep_alive_timer = Timer.new()
		_keep_alive_timer.wait_time = timeout_sec
		_keep_alive_timer.one_shot = true
		
		_keep_alive_timer.connect("timeout", self, "_on_keep_alive_timer_timeout")
		add_child(_keep_alive_timer)
	else:
		push_warning("MasterServer: Cannot detect ping packets, engine patch required.")


func _process(_delta: float):
	var conn_status := client.get_connection_status()
	if conn_status != NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED:
		client.poll() # This allows for data transfer each frame.


## Connect to the official master server. Returns [code]OK[/code] on success,
## or an error code otherwise.
## TODO: Make a similar function for connecting to a custom server.
func connect_to_official_server() -> int:
	var conn_status := client.get_connection_status()
	if conn_status != NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED:
		push_error("Cannot connect to the master server, connection already exists or is being made")
		return ERR_ALREADY_IN_USE
	
	# Reset this flag, since we do not expect a disconnect to happen now that we
	# are connecting to the master server.
	_expecting_disconnect_flag = false
	
	print("MasterServer: Connecting to the official master server at '%s'..." % OFFICIAL_URL)
	var err := client.connect_to_url(OFFICIAL_URL)
	if err != OK:
		push_error("Failed to connect to the master server (error: %d)" % err)
	
	return err


## Returns the status of the client's connection to the master server.
## The value will be one of the [NetworkedMultiplayerPeer] constants.
func get_connection_status() -> int:
	return client.get_connection_status()


## Close the connection to the master server if it exists. No error is thrown if
## the connection is already closed.
## [b]NOTE:[/b] This will cause [signal connection_closed] to be fired with the
## code [code]CODE_NORMAL[/code].
func close_connection() -> void:
	var conn_status := client.get_connection_status()
	if conn_status != NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED:
		print("MasterServer: Closing the connection...")
		
		# What we're about to do will not close the connection cleanly. Usually
		# this would cause the 'connection_lost' signal to be fired, but in this
		# case we know we're disconnecting because we started it.
		_expecting_disconnect_flag = true
		
		# Send the code 1000 as we are disconnecting to signal that we are
		# doing so on purpose.
		# NOTE: If the connection has been lost, there is a chance that this
		# call won't lead to the 'connection_closed' signal being fired.
		# In that event, we are essentially relying on the keep-alive timer to
		# forcefully close the connection before we can start a new one.
		client.disconnect_from_host(CODE_NORMAL)
	else:
		print("MasterServer: Cannot close connection, already disconnected.")


## Request the master server to create a new room, with us as the host.
func host_room() -> void:
	print("MasterServer: Sending request to create a new room...")
	_send_message("J", "", "")


## Request the master server to join the room with the given [param room_code].
func join_room(room_code: String) -> void:
	print("MasterServer: Sending request to join room '%s'..." % room_code)
	_send_message("J", room_code, "")


## Request the master server to seal the room which we are hosting, closing it.
func seal_room() -> void:
	print("MasterServer: Sending request to seal the room...")
	_send_message("S", "", "")


## Send an offer to the peer with ID [param id] via the master server.
## TODO: If these messages fail, or the peers can't find a way to break the ICE,
## then make sure the player has a way to cancel the connection.
func send_offer(id: int, offer: String) -> void:
	print("MasterServer: Sending offer to peer with ID '%d'..." % id)
	_send_message("O", str(id), offer)


## Send an answer to the peer with ID [param id] via the master server.
func send_answer(id: int, answer: String) -> void:
	print("MasterServer: Sending answer to peer with ID '%d'..." % id)
	_send_message("A", str(id), answer)


## Send a candidate to the peer with ID [param id] via the master server.
func send_candidate(id: int, mid: String, index: int, sdp: String) -> void:
	print("MasterServer: Sending candidate to peer with ID '%d'..." % id)
	_send_message("C", str(id), "\n%s\n%d\n%s" % [mid, index, sdp])


# Send a message to the master server. Throws an error if something went wrong.
func _send_message(type: String, arg: String, data: String) -> void:
	var text := "%s: %s\n%s" % [type, arg, data]
	var bytes := text.to_utf8()
	
	var err := client.get_peer(1).put_packet(bytes)
	if err != OK:
		push_error("Failed to send message to the master server (error: %d)" % err)


func _on_client_connection_closed(was_clean_close: bool):
	if _keep_alive_timer != null:
		if not _keep_alive_timer.is_stopped():
			_keep_alive_timer.stop()
			print("MasterServer: Stopped keep-alive timer.")
	
	if _expecting_disconnect_flag:
		print("MasterServer: Connection was closed as expected.")
		emit_signal("connection_closed", CODE_NORMAL)
		
		_expecting_disconnect_flag = false
		return
	
	if was_clean_close:
		print("MasterServer: Connection was closed cleanly.")
		emit_signal("connection_closed", last_close_code)
	else:
		print("MasterServer: Connection was closed unexpectedly.")
		emit_signal("connection_lost")


func _on_client_connection_error():
	print("MasterServer: Failed to connect to the master server.")
	emit_signal("connection_failed")


func _on_client_connection_established(_protocol: String):
	print("MasterServer: Connection was successfully established.")
	
	# Set the write mode to text only, since we only communicate with the master
	# server using plain text.
	client.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	
	emit_signal("connection_established")
	
	if _keep_alive_timer != null:
		_keep_alive_timer.start()
		print("MasterServer: Started keep-alive timer.")


func _on_client_data_received():
	# If we started a disconnect, don't read any more messages from the server.
	if _expecting_disconnect_flag:
		return
	
	var packet_err := client.get_peer(1).get_packet_error()
	if packet_err != OK:
		push_error("Packet from master server contained an error (error: %d)" % packet_err)
		return
	
	var packet_bytes := client.get_peer(1).get_packet()
	var packet_text := packet_bytes.get_string_from_utf8()
	
	# The important stuff is on the first line, the rest of the data is on the
	# second line onwards. There should always be at least two lines.
	var split := packet_text.split("\n", true, 1)
	if split.size() != 2:
		push_error("Invalid packet, expected at least one newline character")
		return
	
	# The first line always has at least a character, a colon, and a space.
	var type_and_arg := split[0]
	if type_and_arg.length() < 3:
		push_error("Invalid packet, first line is too short")
		return
	
	var arg := type_and_arg.substr(3)
	
	if type_and_arg.begins_with("J: "):
		print("MasterServer: Client has joined room '%s'." % arg)
		emit_signal("room_joined", arg)
		return
	
	elif type_and_arg.begins_with("S: "):
		print("MasterServer: Host has sealed the room.")
		emit_signal("room_sealed")
		return
	
	# For all of the other messages, the argument is a peer ID.
	if not arg.is_valid_integer():
		push_error("Invalid packet, ID is not an integer")
		return
	
	var source_id := int(arg)
	
	if type_and_arg.begins_with("I: "):
		print("MasterServer: Client has been assigned as ID '%d'." % source_id)
		emit_signal("id_assigned", source_id)
	
	elif type_and_arg.begins_with("N: "):
		print("MasterServer: Peer with ID '%d' has joined the room." % source_id)
		emit_signal("peer_arriving", source_id)
	
	elif type_and_arg.begins_with("D: "):
		print("MasterServer: Peer with ID '%d' has left the room." % source_id)
		emit_signal("peer_leaving", source_id)
	
	elif type_and_arg.begins_with("O: "):
		print("MasterServer: Received an offer from peer with ID '%d'." % source_id)
		emit_signal("offer_received", source_id, split[1])
	
	elif type_and_arg.begins_with("A: "):
		print("MasterServer: Received an answer from peer with ID '%d'." % source_id)
		emit_signal("answer_received", source_id, split[1])
	
	elif type_and_arg.begins_with("C: "):
		var candidate_data := split[1]
		var candidate_parts := candidate_data.split("\n", false)
		
		if candidate_parts.size() != 3:
			push_error("Invalid packet, candidate does not consist of three parts")
			return
		
		var mid := candidate_parts[0]
		var index_str := candidate_parts[1]
		var sdp := candidate_parts[2]
		
		if not index_str.is_valid_integer():
			push_error("Invalid packet, index in candidate is not an integer")
			return
		
		print("MasterServer: Received a candidate from peer with ID '%d'." % source_id)
		emit_signal("candidate_received", source_id, mid, int(index_str), sdp)
	
	else:
		push_error("Invalid packet, unknown instruction")


func _on_client_ping_received():
	# We are still connected to the server, restart the timer.
	if _keep_alive_timer != null:
		_keep_alive_timer.start()


func _on_client_server_close_request(code: int, _reason: String):
	print("MasterServer: Received a close request with code %d." % code)
	
	# The connection will be closed a little bit later, so save the close code
	# for when that happens.
	last_close_code = code


func _on_keep_alive_timer_timeout():
	print("MasterServer: Keep-alive timer expired, assuming connection is lost...")
	
	# Using WebSocketClient.disconnect_from_host() only works properly if we are
	# still connected to the server, so we need to do things manually.
	
	# Before we re-create the WebSocketClient, we need to make sure the signals
	# remain connected afterwards.
	var signal_list := client.get_signal_list()
	var signal_connection_dict := {}
	
	for element in signal_list:
		var signal_dict: Dictionary = element
		var signal_name: String = signal_dict["name"]
		
		var signal_connection_list := client.get_signal_connection_list(
				signal_name)
		if signal_connection_list.empty():
			continue
		
		signal_connection_dict[signal_name] = signal_connection_list
	
	client = WebSocketClient.new()
	
	for key in signal_connection_dict:
		var signal_name: String = key
		var connection_list: Array = signal_connection_dict[key]
		
		for element in connection_list:
			var conn_data: Dictionary = element
			client.connect(signal_name, conn_data["target"],
					conn_data["method"], conn_data["binds"], conn_data["flags"])
	
	_on_client_connection_closed(false)
