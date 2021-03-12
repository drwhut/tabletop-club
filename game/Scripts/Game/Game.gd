# open-tabletop
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

extends Node

onready var _connecting_dialog = $ConnectingDialog
onready var _room = $Room
onready var _table_state_error_dialog = $TableStateErrorDialog
onready var _table_state_version_dialog = $TableStateVersionDialog
onready var _ui = $GameUI

var _player_name: String
var _player_color: Color

var _room_state_saving: Dictionary = {}
var _state_version_save: Dictionary = {}

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
	
	_ui.hide_chat_box()

# Request the server to add a piece to the game.
# piece_entry: The piece's entry in the AssetDB.
# position: The position to spawn the piece at.
master func request_game_piece(piece_entry: Dictionary, position: Vector3) -> void:
	var transform = Transform(Basis.IDENTITY, position)
	
	# Is the piece a pre-filled stack?
	if piece_entry.has("texture_paths") and (not piece_entry.has("texture_path")):
		_room.rpc_id(1, "request_add_stack_filled", transform, piece_entry)
	else:
		# Send the call to create the piece to everyone.
		_room.rpc("add_piece", _room.srv_get_next_piece_name(), transform, piece_entry)

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	
	Lobby.connect("players_synced", self, "_on_Lobby_players_synced")
	
	Lobby.clear_players()

# Create a network peer object.
# Returns: A new network peer object.
func _create_network_peer() -> NetworkedMultiplayerENet:
	var peer = NetworkedMultiplayerENet.new()
	peer.compression_mode = NetworkedMultiplayerENet.COMPRESS_FASTLZ
	return peer

# Open a table state (.ot) file in the given mode.
# Returns: A file object for the given path, null if it failed to open.
# path: The file path to open.
# mode: The mode to open the file with.
func _open_table_state_file(path: String, mode: int) -> File:
	var file = File.new()
	var open_err = file.open_compressed(path, mode, File.COMPRESSION_ZSTD)
	if open_err == OK:
		return file
	else:
		_popup_table_state_error(tr("Could not open the file at path '%s' (error %d).") % [path, open_err])
		return null

# Show the table state popup dialog with the given error.
# error: The error message to show.
func _popup_table_state_error(error: String) -> void:
	_table_state_error_dialog.dialog_text = error
	_table_state_error_dialog.popup_centered()
	
	push_error(error)

# Show the table state version popup with the given message.
# message: The message to show.
func _popup_table_state_version(message: String) -> void:
	_table_state_version_dialog.dialog_text = message
	_table_state_version_dialog.popup_centered()
	
	push_warning(message)

func _player_connected(id: int) -> void:
	print("Player with ID ", id, " connected!")
	
	# If a player has connected to the server, let them know of every piece on
	# the board so far.
	if get_tree().is_network_server():
		_room.rpc_id(id, "set_state", _room.get_state(true, true))
		
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
	Global.start_main_menu_with_error(tr("Failed to connect to the server!"))

func _server_disconnected() -> void:
	print("Lost connection to the server!")
	Global.start_main_menu_with_error(tr("Lost connection to the server!"))

func _on_GameUI_about_to_save_table():
	_room_state_saving = _room.get_state(false, false)

func _on_GameUI_applying_options(config: ConfigFile):
	apply_options(config)

func _on_GameUI_flipping_table(reset_table: bool):
	if reset_table:
		_room.rpc_id(1, "request_unflip_table")
	else:
		_room.rpc_id(1, "request_flip_table", _room.get_camera_transform().basis)

func _on_GameUI_lighting_requested(lamp_color: Color, lamp_intensity: float,
	lamp_sunlight: bool):
	
	_room.rpc_id(1, "request_set_lamp_color", lamp_color)
	_room.rpc_id(1, "request_set_lamp_intensity", lamp_intensity)
	_room.rpc_id(1, "request_set_lamp_type", lamp_sunlight)

func _on_GameUI_load_table(path: String):
	var file = _open_table_state_file(path, File.READ)
	if file:
		var state = file.get_var()
		file.close()
		
		if state is Dictionary:
			var our_version = ProjectSettings.get_setting("application/config/version")
			if state.has("version") and state["version"] == our_version:
				_room.rpc_id(1, "request_load_table_state", state)
			else:
				_state_version_save = state
				if not state.has("version"):
					_popup_table_state_version(tr("Loaded table has no version information. Load anyway?"))
				else:
					_popup_table_state_version(tr("Loaded table was saved with a different version of the game (Current: %s, Table: %s). Load anyway?") % [our_version, state["version"]])
		else:
			_popup_table_state_error(tr("Loaded table is not in the correct format."))

func _on_GameUI_piece_requested(piece_entry: Dictionary, position: Vector3):
	rpc_id(1, "request_game_piece", piece_entry, position)

func _on_GameUI_requesting_room_details():
	_ui.set_room_details(_room.get_table(), _room.get_skybox(),
		_room.get_lamp_color(), _room.get_lamp_intensity(),
		_room.get_lamp_type())

func _on_GameUI_save_table(path: String):
	if _room_state_saving.empty():
		push_error("Room state to save is empty!")
		return
	
	var file = _open_table_state_file(path, File.WRITE)
	if file:
		file.store_var(_room_state_saving)
		file.close()

func _on_GameUI_stopped_saving_table():
	_room_state_saving = {}

func _on_GameUI_skybox_requested(skybox_entry: Dictionary):
	_room.rpc_id(1, "request_set_skybox", skybox_entry)

func _on_GameUI_table_requested(table_entry: Dictionary):
	_room.rpc_id(1, "request_set_table", table_entry)

func _on_Lobby_players_synced():
	if not get_tree().is_network_server():
		Lobby.rpc_id(1, "request_add_self", _player_name, _player_color)

func _on_Room_setting_spawn_point(position: Vector3):
	_ui.spawn_point_origin = position

func _on_Room_spawning_piece_at(position: Vector3):
	_ui.spawn_point_temp_offset = position - _ui.spawn_point_origin
	_ui.popup_objects_dialog()

func _on_Room_table_flipped(table_reset: bool):
	_ui.set_flip_table_status(not table_reset)

func _on_TableStateVersionDialog_confirmed():
	_room.rpc_id(1, "request_load_table_state", _state_version_save)
