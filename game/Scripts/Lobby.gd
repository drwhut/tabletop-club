# open-tabletop
# Copyright (c) 2020 drwhut
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

const PORT = 26271

func init_client(server: String) -> void:
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(server, PORT)
	get_tree().network_peer = peer

func init_server(max_players: int) -> void:
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(PORT, max_players)
	get_tree().network_peer = peer

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	
	var is_server = true
	
	for arg in OS.get_cmdline_args():
		if arg == "--client":
			is_server = false
			break
	
	if is_server:
		print("Initializing server peer...")
		init_server(10)
	else:
		print("Initializing client peer...")
		init_client("127.0.0.1")

func _player_connected(id: int) -> void:
	print("Player ", id, " connected!")

func _player_disconnected(id: int) -> void:
	print("Player ", id, " disconnected!")

func _connected_ok() -> void:
	print("Connected OK!")

func _connected_fail() -> void:
	print("Connected FAIL!")

func _server_disconnected() -> void:
	print("Server disconnected!")
