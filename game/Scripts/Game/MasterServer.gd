# tabletop-club
# Copyright (c) 2020-2025 Benjamin 'drwhut' Beddows
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

# NOTE: This code is based on the webrtc_signalling demo, which is licensed
# under the MIT license:
# https://github.com/godotengine/godot-demo-projects/blob/master/networking/webrtc_signaling/client/ws_webrtc_client.gd

extends Node

signal answer_received(id, answer)
signal candidate_received(id, mid, index, sdp)
signal connected(id)
signal disconnected()
signal room_joined(room_code)
signal room_sealed()
signal offer_received(id, offer)
signal peer_connected(id)
signal peer_disconnected(id)

const URL: String = "wss://lobby.tabletopclub.net"

# See: https://github.com/drwhut/tabletop_club_master_server/blob/master/server.js
var ERROR_MESSAGES = {
	4001: tr("Could not connect to the master server."),
	4002: tr("Have not joined a room yet."),
	4003: tr("Host has disconnected from the room."),
	4004: tr("Only the host can seal the room."),
	4005: tr("Too many rooms are open."),
	4006: tr("Already in a room."),
	4007: tr("Room does not exist."),
	4008: tr("Room is sealed."),
	4009: tr("Message format is invalid."),
	4010: tr("Message is invalid when not in a room."),
	4011: tr("Internal server error."),
	4012: tr("Invalid destination."),
	4013: tr("Invalid command."),
	4014: tr("Too many players connected."),
	4015: tr("Transfer mode is invalid."),
	4016: tr("Too many connections."),
	4017: tr("Reconnected too quickly."),
	4018: tr("Join queue is full."),
}

export(String) var room_code = "" # If empty, create a new room.

var client = WebSocketClient.new()

# If we suddenly disconnect from the master server without getting an error
# code, assume we couldn't connect to the master server.
var code: int = 4001
var reason: String = ERROR_MESSAGES[code]

# Connect to the master server.
func connect_to_server() -> void:
	close()
	
	# Players can change where the game looks for the master server by passing
	# a "--master-server" argument when running the game, as well as an
	# "--ssl-certificate" argument that points to a .crt file for the "new"
	# master server.
	var cmdline_args = OS.get_cmdline_args()
	var master_server_index = -1
	var ssl_certificate_index = -1
	
	for arg_index in range(cmdline_args.size()):
		var arg = cmdline_args[arg_index]
		if arg == "--master-server" and master_server_index < 0:
			master_server_index = arg_index + 1
		elif arg == "--ssl-certificate" and ssl_certificate_index < 0:
			ssl_certificate_index = arg_index + 1
	
	if master_server_index >= cmdline_args.size():
		push_error("--master-server argument requires an address!")
		master_server_index = -1
	
	if ssl_certificate_index >= cmdline_args.size():
		push_error("--ssl-certificate argument requires a file path!")
		ssl_certificate_index = -1
	
	var custom_server: String = ""
	var custom_certificate: X509Certificate = X509Certificate.new()
	var custom_certificate_ok: bool = false
	
	if master_server_index >= 0:
		var address: String = cmdline_args[master_server_index]
		if address.begins_with("wss://"):
			custom_server = address
		else:
			push_error("--master-server address does not begin with 'wss://'!")
	
	if ssl_certificate_index >= 0:
		var path: String = cmdline_args[ssl_certificate_index]
		if path.is_abs_path() or path.is_rel_path():
			if path.get_extension() == "crt":
				var file: File = File.new()
				if file.file_exists(path):
					var err = custom_certificate.load(path)
					if err == OK:
						custom_certificate_ok = true
					else:
						push_error("Failed to load custom SSL certificate (error: %d)!" % err)
				else:
					push_error("--ssl-certificate path does not exist!")
			else:
				push_error("--ssl-certificate path does not include the 'crt' extension!")
		else:
			push_error("--ssl-certificate is not a valid path!")
	
	if custom_server.empty():
		if custom_certificate_ok:
			push_warning("SSL certificate provided with no custom master server, ignoring.")
		var connect_err = client.connect_to_url(URL)
		if connect_err != OK:
			push_error("Could not connect to the master server (error %d)!" % connect_err)
			emit_signal("disconnected")
	else:
		push_warning("Connecting to an unofficial master server at '%s', proceed with caution!" % custom_server)
		if custom_certificate_ok:
			client.trusted_ssl_certificate = custom_certificate
		else:
			push_warning("No SSL certificate was loaded for '%s', this will not end well..." % custom_server)
		var connect_err = client.connect_to_url(custom_server)
		if connect_err != OK:
			push_error("Could not connect to the custom master server (error %d)!" % connect_err)
			emit_signal("disconnected")

# Close the connection to the master server.
func close() -> void:
	client.disconnect_from_host()

# Check if we are currently connected to the master server.
# Returns: If there is an ongoing connection to the master server.
func is_connection_established() -> bool:
	return client.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTED

# Ask the master server to join the room with the given room code.
# Returns: An Error.
# new_room_code: The room code.
func join_room(new_room_code: String) -> int:
	return client.get_peer(1).put_packet(("J: %s\n" % new_room_code).to_utf8())

# Ask the master server to seal the room, which closes it.
# Returns: An Error.
func seal_room() -> int:
	return client.get_peer(1).put_packet("S: \n".to_utf8())

# Send an answer back to a peer via the master server.
# Returns: An Error.
# id: The ID of the peer.
# answer: The answer to send.
func send_answer(id: int, answer: String) -> int:
	return _send_msg("A", id, answer)

# Send a candidate to a peer via the master server.
# Returns: An Error.
# id: The ID of the peer.
# mid: A candidate parameter.
# index: A candidate parameter.
# sdp: A candidate parameter.
func send_candidate(id: int, mid: String, index: int, sdp: String) -> int:
	return _send_msg("C", id, "\n%s\n%d\n%s" % [mid, index, sdp])

# Send an offer to a peer via the master server.
# Returns: An Error.
# id: The ID of the peer.
# offer: The offer to send.
func send_offer(id: int, offer: String) -> int:
	return _send_msg("O", id, offer)

func _init():
	client.connect("connection_closed", self, "_on_closed")
	client.connect("connection_error", self, "_on_closed")
	client.connect("connection_established", self, "_on_connected")
	client.connect("data_received", self, "_on_data_received")
	client.connect("server_close_request", self, "_on_close_request")
	
	client.verify_ssl = true

func _process(_delta):
	var status: int = client.get_connection_status()
	if status == WebSocketClient.CONNECTION_CONNECTING or status == WebSocketClient.CONNECTION_CONNECTED:
		client.poll()

# Send a message to a peer via the master server.
# Returns: An Error.
# type: The type of message to send.
# id: The ID of the peer.
# data: The data to send.
func _send_msg(type: String, id: int, data: String) -> int:
	return client.get_peer(1).put_packet(("%s: %d\n%s" % [type, id, data]).to_utf8())

func _on_closed(_was_clean: bool = false):
	emit_signal("disconnected")

func _on_close_request(close_code: int, close_reason: String):
	self.code = close_code
	
	if close_code in ERROR_MESSAGES:
		self.reason = ERROR_MESSAGES[close_code]
	else:
		self.reason = close_reason

func _on_connected(_protocol: String = ""):
	client.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	join_room(room_code)

func _on_data_received():
	var pkt_str: String = client.get_peer(1).get_packet().get_string_from_utf8()
	
	var req: PoolStringArray = pkt_str.split("\n", true, 1)
	if req.size() != 2: # Invalid request size
		return
	
	var type: String = req[0]
	if type.length() < 3: # Invalid type size
		return
	
	if type.begins_with("J: "):
		emit_signal("room_joined", type.substr(3, type.length() - 3))
		return
	elif type.begins_with("S: "):
		emit_signal("room_sealed")
		return
	
	var src_str: String = type.substr(3, type.length() - 3)
	if not src_str.is_valid_integer(): # Source id is not an integer
		return
	
	var src_id: int = int(src_str)
	
	if type.begins_with("I: "):
		emit_signal("connected", src_id)
	elif type.begins_with("N: "):
		# Client connected
		emit_signal("peer_connected", src_id)
	elif type.begins_with("D: "):
		# Client connected
		emit_signal("peer_disconnected", src_id)
	elif type.begins_with("O: "):
		# Offer received
		emit_signal("offer_received", src_id, req[1])
	elif type.begins_with("A: "):
		# Answer received
		emit_signal("answer_received", src_id, req[1])
	elif type.begins_with("C: "):
		# Candidate received
		var candidate: PoolStringArray = req[1].split("\n", false)
		if candidate.size() != 3:
			return
		if not candidate[1].is_valid_integer():
			return
		emit_signal("candidate_received", src_id, candidate[0], int(candidate[1]), candidate[2])
