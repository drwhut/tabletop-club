# tabletop-club
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows
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

const URL: String = "ws://localhost:9080"

export(String) var room_code = "" # If empty, create a new room.

var client = WebSocketClient.new()

var code: int = 1000
var reason: String = "Unknown"

# Connect to the master server.
func connect_to_server() -> void:
	close()
	client.connect_to_url(URL)

# Close the connection to the master server.
func close() -> void:
	client.disconnect_from_host()

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
