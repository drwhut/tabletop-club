# open-tabletop
# Copyright (c) 2020 Benjamin 'drwhut' Beddows
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

onready var _connecting_dialog = $ConnectingDialog
onready var _room = $Room
onready var _ui = $GameUI

var _player_name: String
var _player_color: Color

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	_room.apply_options(config)
	_ui.apply_options(config)
	
	_player_name = config.get_value("multiplayer", "name")
	_player_color = config.get_value("multiplayer", "color")
	
	if not get_tree().is_network_server():
		if not _connecting_dialog.visible:
			Lobby.rpc_id(1, "request_modify_self", _player_name, _player_color)

# Initialise a client peer.
# server: The server to connect to.
# port: The port number to connect to.
func init_client(server: String, port: int) -> void:
	print("Connecting to ", server, ":", port, " ...")
	var peer = _create_network_peer()
	peer.create_client(server, port)
	get_tree().network_peer = peer
	
	_connecting_dialog.popup_centered()

# Initialise a server peer.
# max_players: The maximum number of peers (excluding the server) that can
# connect to the server.
# port: The port number to host the server on.
func init_server(max_players: int, port: int) -> void:
	print("Starting server on port ", port, " with ", max_players, " max players...")
	var peer = _create_network_peer()
	peer.create_server(port, max_players + 1)
	get_tree().network_peer = peer

# Initialise a singleplayer game, which is a server that refuses connections.
func init_singleplayer() -> void:
	print("Starting singleplayer...")
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	init_server(0, rng.randi_range(10000, 65535))
	
	var hand_transform = _room.srv_get_next_hand_transform()
	if hand_transform == Transform.IDENTITY:
		push_error("Player hand not added, no available hand positions!")
	else:
		_room.rpc_id(1, "add_hand", 1, hand_transform)

# Request the server to add a piece to the game.
# piece_entry: The piece's entry in the PieceDB.
master func request_game_piece(piece_entry: Dictionary) -> void:
	# Is the piece a pre-filled stack?
	if piece_entry.has("texture_paths") and (not piece_entry.has("texture_path")):
		_room.rpc_id(1, "request_add_stack_filled", piece_entry)
	else:
		# Send the call to create the piece to everyone.
		_room.rpc("add_piece",
			_room.srv_get_next_piece_name(),
			Transform(Basis.IDENTITY, Vector3(0, Piece.SPAWN_HEIGHT, 0)),
			piece_entry
		)

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	
	Lobby.connect("players_synced", self, "_on_Lobby_players_synced")
	
	Lobby.clear_players()
	
	# The assets should have been imported at the start of the game.
	_ui.set_piece_db(PieceDB.get_db())

# Create a network peer object.
# Returns: A new network peer object.
func _create_network_peer() -> NetworkedMultiplayerENet:
	var peer = NetworkedMultiplayerENet.new()
	peer.compression_mode = NetworkedMultiplayerENet.COMPRESS_FASTLZ
	return peer

func _player_connected(id: int) -> void:
	print("Player with ID ", id, " connected!")
	
	# If a player has connected to the server, let them know of every piece on
	# the board so far.
	if get_tree().is_network_server():
		_room.rpc_id(id, "set_state", _room.get_state())
		
		# If there is space, also give them a hand on the table.
		var hand_transform = _room.srv_get_next_hand_transform()
		if hand_transform != Transform.IDENTITY:
			_room.rpc("add_hand", id, hand_transform)

func _player_disconnected(id: int) -> void:
	print("Player with ID ", id, " disconnected!")
	
	if get_tree().is_network_server():
		Lobby.rpc("remove_self", id)
		
		_room.rpc("remove_hand", id)
		_room.srv_stop_player_hovering(id)

func _connected_ok() -> void:
	print("Successfully connected to the server!")
	_connecting_dialog.visible = false
	
	Lobby.rpc_id(1, "request_sync_players")
	
	_room.start_sending_cursor_position()

func _connected_fail() -> void:
	print("Failed to connect to the server!")
	Global.start_main_menu_with_error("Failed to connect to the server!")

func _server_disconnected() -> void:
	print("Lost connection to the server!")
	Global.start_main_menu_with_error("Lost connection to the server!")

func _on_GameUI_applying_options(config: ConfigFile):
	apply_options(config)

func _on_GameUI_piece_requested(piece_entry: Dictionary):
	rpc_id(1, "request_game_piece", piece_entry)

func _on_Lobby_players_synced():
	if not get_tree().is_network_server():
		Lobby.rpc_id(1, "request_add_self", _player_name, _player_color)
