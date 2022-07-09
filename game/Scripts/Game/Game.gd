# tabletop-club
# Copyright (c) 2020-2022 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2022 Tabletop Club contributors (see game/CREDITS.tres).
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

# NOTE: The WebRTC code in this script is based on the webrtc_signalling demo,
# which is licensed under the MIT license:
# https://github.com/godotengine/godot-demo-projects/blob/master/networking/webrtc_signaling/client/multiplayer_client.gd

extends Node

onready var _connecting_popup = $ConnectingPopup
onready var _connecting_popup_label = $ConnectingPopup/Label
onready var _download_assets_confirm_dialog = $DownloadAssetsConfirmDialog
onready var _master_server = $MasterServer
onready var _missing_assets_dialog = $MissingAssetsDialog
onready var _missing_db_label = $MissingAssetsDialog/VBoxContainer/MissingDBLabel
onready var _missing_db_summary_label = $MissingAssetsDialog/VBoxContainer/MissingDBSummaryLabel
onready var _missing_fs_label = $MissingAssetsDialog/VBoxContainer/MissingDBLabel
onready var _missing_fs_summary_label = $MissingAssetsDialog/VBoxContainer/MissingFSSummaryLabel
onready var _room = $Room
onready var _table_state_error_dialog = $TableStateErrorDialog
onready var _table_state_version_dialog = $TableStateVersionDialog
onready var _ui = $GameUI

export(bool) var autosave_enabled: bool = true
export(int) var autosave_interval: int = 300
export(int) var autosave_count: int = 10

var _rtc = WebRTCMultiplayer.new()
var _established_connection_with = []

var _player_name: String
var _player_color: Color

var _room_state_saving: Dictionary = {}
var _save_screenshot_frames: int = -1
var _save_screenshot_path: String = ""
var _state_version_save: Dictionary = {}
var _time_since_last_autosave: float = 0.0

var _cln_compared_schemas: bool = false
var _srv_schema_db: Dictionary = {}
var _srv_schema_fs: Dictionary = {}

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	_room.apply_options(config)
	_ui.apply_options(config)
	
	autosave_enabled = true
	var autosave_interval_id = config.get_value("general", "autosave_interval")
	
	match autosave_interval_id:
		0:
			autosave_enabled = false
		1:
			autosave_interval = 30
		2:
			autosave_interval = 60
		3:
			autosave_interval = 300
		4:
			autosave_interval = 600
		5:
			autosave_interval = 1800
	
	autosave_count = config.get_value("general", "autosave_file_count")
	
	_player_name = config.get_value("multiplayer", "name")
	_player_color = config.get_value("multiplayer", "color")
	
	if _master_server.is_connection_established():
		Lobby.rpc_id(1, "request_modify_self", _player_name, _player_color)

# Called by the server to compare it's asset schemas against our own.
# server_schema_db: The server's AssetDB schema.
# server_schema_fs: The server's filesystem schema.
puppet func compare_server_schemas(server_schema_db: Dictionary,
	server_schema_fs: Dictionary) -> void:
	
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if _cln_compared_schemas:
		return
	else:
		_cln_compared_schemas = true
	
	print("Received asset schemas from the host, comparing...")
	
	var client_schema_db = _create_schema_db()
	var client_schema_fs = _create_schema_fs()
	
	var db_extra = {}
	var db_need = {}
	var db_num_extra = 0
	var db_num_missing = 0
	var db_num_modified = 0
	for pack in server_schema_db:
		if not pack is String:
			push_error("Key in server DB schema is not a string!")
			return
		
		if not _check_name(pack):
			push_error("Pack name '%s' in server DB schema is invalid!" % pack)
			return
		
		var have_pack = client_schema_db.has(pack)
		for type in server_schema_db[pack]:
			if not type is String:
				push_error("Key in pack %s in server DB schema is not a string!" % pack)
				return
			
			if not type in AssetDB.ASSET_PACK_SUBFOLDERS:
				push_error("Type name '%s' in pack %s in server DB schema is invalid!" % [type, pack])
				return
			
			var server_type_arr = server_schema_db[pack][type]
			if not server_type_arr is Array:
				push_error("%s/%s in server DB schema is not an array!" % [pack, type])
				return
			
			var have_type = false
			if have_pack:
				have_type = client_schema_db[pack].has(type)
			
			var need_arr = []
			var extra_arr = []
			var client_type_arr = []
			if have_type:
				client_type_arr = client_schema_db[pack][type]
			
			var client_ptr = 0
			var last_name = ""
			for server_ptr in range(server_type_arr.size()):
				var server_meta = server_type_arr[server_ptr]
				if not server_meta is Dictionary:
					push_error("%s/%s/%d in server DB schema is not a dictionary!" % [pack, type, server_ptr])
					return
				
				if server_meta.size() != 2:
					push_error("%s/%s/%d in server DB schema has %d elements (expected 2)!" % [pack, type, server_ptr, server_meta.size()])
					return
				
				if not server_meta.has("name"):
					push_error("%s/%s/%d in server DB schema does not contain a name!" % [pack, type, server_ptr])
					return
				
				if not server_meta["name"] is String:
					push_error("Name in %s/%s/%d in server DB schema is not a string!" % [pack, type, server_ptr])
					return
				
				if not _check_name(server_meta["name"]):
					push_error("Name '%s' in %s/%s/%d in server DB schema is invalid!" % [server_meta["name"], pack, type, server_ptr])
					return
				
				if not server_meta.has("hash"):
					push_error("%s/%s/%d in server DB schema does not contain a hash!" % [pack, type, server_ptr])
					return
				
				if not server_meta["hash"] is int:
					push_error("Hash in %s/%s/%d in server DB schema is not an integer!" % [pack, type, server_ptr])
					return
				
				# Check if the server names are in order! It's a requirement
				# for the AssetDB, and is needed for this function to work
				# properly.
				if server_ptr > 0:
					if server_meta["name"] < last_name:
						push_error("Name '%s' in server DB schema came before the name '%s'!" % [server_meta["name"], last_name])
						return
				last_name = server_meta["name"]
				
				var found_match = false
				while (not found_match) and client_ptr < client_type_arr.size():
					var client_meta = client_type_arr[client_ptr]
					if client_meta["name"] == server_meta["name"]:
						found_match = true
						if client_meta["hash"] != server_meta["hash"]:
							need_arr.append(server_ptr)
							db_num_modified += 1
					
					elif client_meta["name"] > server_meta["name"]:
						break
					
					else:
						extra_arr.append(client_ptr)
						db_num_extra += 1
					
					client_ptr += 1
				
				if not found_match:
					need_arr.append(server_ptr)
					db_num_missing += 1
			
			while client_ptr < client_type_arr.size():
				extra_arr.append(client_ptr)
				db_num_extra += 1
				client_ptr += 1
			
			if not extra_arr.empty():
				if not db_extra.has(pack):
					db_extra[pack] = {}
				db_extra[pack][type] = extra_arr
			
			if not need_arr.empty():
				if not db_need.has(pack):
					db_need[pack] = {}
				db_need[pack][type] = need_arr
	
	var fs_need = {}
	var fs_num_missing = 0
	var fs_num_modified = 0
	for pack in server_schema_fs:
		if not pack is String:
			push_error("Key in server FS schema is not a string!")
			return
		
		if not _check_name(pack):
			push_error("Pack name '%s' in server FS schema is invalid!" % pack)
			return
		
		var have_pack = client_schema_fs.has(pack)
		for type in server_schema_fs[pack]:
			if not type is String:
				push_error("Key in pack %s in server FS schema is not a string!" % pack)
				return
			
			if not type in AssetDB.ASSET_PACK_SUBFOLDERS:
				push_error("Type name '%s' in pack %s in server FS schema is invalid!" % [type, pack])
				return
			
			var server_type_dict = server_schema_fs[pack][type]
			if not server_type_dict is Dictionary:
				push_error("%s/%s in server FS schema is not a dictionary!" % [pack, type])
				return
			
			var have_type = false
			if have_pack:
				have_type = client_schema_fs[pack].has(type)
			
			var need_arr = []
			var client_type_dict = {}
			if have_type:
				client_type_dict = client_schema_fs[pack][type]
			
			for server_name in server_type_dict:
				if not server_name is String:
					push_error("File name in server FS schema is not a string!")
					return
				
				if not _check_name(server_name):
					push_error("File name '%s' in server FS schema is invalid!" % server_name)
					return
				
				var server_md5 = server_type_dict[server_name]
				if not server_md5 is String:
					push_error("%s/%s/%s MD5 in server FS schema is not a string!" % [pack, type, server_name])
					return
				
				if not server_md5.is_valid_hex_number():
					push_error("%s/%s/%s MD5 in server FS schema is not a valid hex number!" % [pack, type, server_name])
					return
				
				if client_type_dict.has(server_name):
					# Do the MD5 hashes not match?
					if client_type_dict[server_name] != server_md5:
						need_arr.append(server_name)
						fs_num_modified += 1
				else:
					need_arr.append(server_name)
					fs_num_missing += 1
			
			if not need_arr.empty():
				if not fs_need.has(pack):
					fs_need[pack] = {}
				fs_need[pack][type] = need_arr
	
	print("AssetDB schema results:")
	print("# Extra entries: %d" % db_num_extra)
	print("# Missing entries: %d" % db_num_missing)
	print("# Modified entries: %d" % db_num_modified)
	_missing_db_summary_label.text = _missing_db_summary_label.text % [db_num_missing, db_num_modified]
	print("- Entries that the host is missing:")
	for pack in db_extra:
		for type in db_extra[pack]:
			for index in db_extra[pack][type]:
				var asset = client_schema_db[pack][type][index]["name"]
				var path = "%s/%s/%s" % [pack, type, asset]
				if _missing_db_label.text.length() > 0:
					_missing_db_label.text += "\n"
				_missing_db_label.text += "+ " + path
				print(path)
	print("- Entries that we need from the host:")
	for pack in db_need:
		for type in db_need[pack]:
			for index in db_need[pack][type]:
				var asset = server_schema_db[pack][type][index]["name"]
				var path = "%s/%s/%s" % [pack, type, asset]
				if _missing_db_label.text.length() > 0:
					_missing_db_label.text += "\n"
				_missing_db_label.text += "- " + path
				print(path)
	
	print("Filesystem schema results:")
	print("# Missing files: %d" % fs_num_missing)
	print("# Modified files: %d" % fs_num_modified)
	_missing_fs_summary_label.text = _missing_fs_summary_label.text % [fs_num_missing, fs_num_modified]
	print("- Files that we need from the host:")
	for pack in fs_need:
		for type in fs_need[pack]:
			for asset in fs_need[pack][type]:
				var path = "%s/%s/%s" % [pack, type, asset]
				if _missing_fs_label.text.length() > 0:
					_missing_fs_label.text += "\n"
				_missing_fs_label.text += "- " + path
				print(path)
	
	_missing_assets_dialog.popup_centered()

# Ask the master server to host a game.
func start_host() -> void:
	print("Hosting game...")
	
	_srv_schema_db = _create_schema_db()
	_srv_schema_fs = _create_schema_fs()
	
	_connect_to_master_server("")

# Ask the master server to join a game.
func start_join(room_code: String) -> void:
	print("Joining game with room code %s..." % room_code)
	_connect_to_master_server(room_code)

# Start the game in singleplayer mode.
func start_singleplayer() -> void:
	print("Starting singleplayer...")
	
	# Pretend that we asked the master server to host our own game.
	call_deferred("_on_connected", 1)
	
	_ui.hide_room_code()

# Stop the connections to the other peers and the master server.
func stop() -> void:
	_rtc.close()
	_master_server.close()

# Load a table state from the given file path.
# path: The file path of the state to load.
func load_state(path: String) -> void:
	var file = _open_table_state_file(path, File.READ)
	if file:
		var state = file.get_var()
		file.close()
		
		if state is Dictionary:
			var our_version = ProjectSettings.get_setting("application/config/version")
			if state.has("version") and state["version"] == our_version:
				var compressed_state = _room.compress_state(state)
				_room.rpc_id(1, "request_load_table_state", compressed_state)
			else:
				_state_version_save = state
				if not state.has("version"):
					_popup_table_state_version(tr("Loaded table has no version information. Load anyway?"))
				else:
					_popup_table_state_version(tr("Loaded table was saved with a different version of the game (Current: %s, Table: %s). Load anyway?") % [our_version, state["version"]])
		else:
			_popup_table_state_error(tr("Loaded table is not in the correct format."))

# Save a screenshot from the main viewport.
# Returns: An error.
# path: The path to save the screenshot.
# size_factor: Resize the screenshot by the given size factor.
func save_screenshot(path: String, size_factor: float = 1.0) -> int:
	var image = get_viewport().get_texture().get_data()
	image.flip_y()
	
	if size_factor != 1.0:
		var new_width = int(image.get_width() * size_factor)
		var new_height = int(image.get_height() * size_factor)
		image.resize(new_width, new_height, Image.INTERPOLATE_BILINEAR)
	
	return image.save_png(path)

# Save a table state to the given file path.
# state: The state to save.
# path: The file path to save the state to.
func save_state(state: Dictionary, path: String) -> void:
	var file = _open_table_state_file(path, File.WRITE)
	if file:
		file.store_var(state)
		file.close()
		
		# Save a screenshot alongside the save file next frame, when the save
		# dialog has disappeared.
		_save_screenshot_frames = 1
		_save_screenshot_path = path.get_basename() + ".png"

func _ready():
	_master_server.connect("connected", self, "_on_connected")
	_master_server.connect("disconnected", self, "_on_disconnected")
	
	_master_server.connect("offer_received", self, "_on_offer_received")
	_master_server.connect("answer_received", self, "_on_answer_received")
	_master_server.connect("candidate_received", self, "_on_candidate_received")
	
	_master_server.connect("room_joined", self, "_on_room_joined")
	_master_server.connect("room_sealed", self, "_on_room_sealed")
	_master_server.connect("peer_connected", self, "_on_peer_connected")
	_master_server.connect("peer_disconnected", self, "_on_peer_disconnected")
	
	Lobby.connect("players_synced", self, "_on_Lobby_players_synced")
	
	Lobby.clear_players()

func _process(delta):
	var current_peers = _rtc.get_peers()
	for id in current_peers:
		var peer: Dictionary = current_peers[id]
		
		if peer["connected"]:
			if not id in _established_connection_with:
				_on_connection_established(id)
				_established_connection_with.append(id)
	
	if _save_screenshot_frames >= 0:
		if _save_screenshot_frames == 0:
			if save_screenshot(_save_screenshot_path, 0.1) != OK:
				push_error("Failed to save a screenshot to '%s'!" % _save_screenshot_path)
		
		_save_screenshot_frames -= 1
	
	_time_since_last_autosave += delta
	if autosave_enabled and _time_since_last_autosave > autosave_interval:
		var autosave_dir_path = Global.get_output_subdir("saves").get_current_dir()
		var autosave_path = ""
		var oldest_file_path = ""
		var oldest_file_time = 0
		
		var file = File.new()
		for autosave_id in range(autosave_count):
			autosave_path = autosave_dir_path + "/autosave_" + str(autosave_id) + ".tc"
			
			if file.file_exists(autosave_path):
				var modified_time = file.get_modified_time(autosave_path)
				if oldest_file_path.empty() or modified_time < oldest_file_time:
					oldest_file_path = autosave_path
					oldest_file_time = modified_time
			else:
				break
		
		if file.file_exists(autosave_path):
			autosave_path = oldest_file_path
		
		var state = _room.get_state(false, false)
		save_state(state, autosave_path)
		
		_time_since_last_autosave = 0.0

func _unhandled_input(event):
	if event.is_action_pressed("game_take_screenshot"):
		# Create the screenshots folder if it doesn't already exist.
		var screenshot_dir = Global.get_output_subdir("screenshots")
		
		var dt = OS.get_datetime()
		var name = "%d-%d-%d-%d-%d-%d.png" % [dt["year"], dt["month"],
			dt["day"], dt["hour"], dt["minute"], dt["second"]]
		var path = screenshot_dir.get_current_dir() + "/" + name
		
		if save_screenshot(path) == OK:
			var message = tr("Saved screenshot to '%s'.") % path
			_ui.add_notification_info(message)
		else:
			push_error("Failed to save screenshot to '%s'!" % path)
			return
	
	elif event.is_action_pressed("game_quicksave") or event.is_action_pressed("game_quickload"):
		var save_dir_path = Global.get_output_subdir("saves").get_current_dir()
		var quicksave_path = save_dir_path + "/quicksave.tc"
		
		if event.is_action_pressed("game_quicksave"):
			var state = _room.get_state(false, false)
			save_state(state, quicksave_path)
			
			_ui.add_notification_info(tr("Quicksave file saved."))
		
		elif event.is_action_pressed("game_quickload"):
			var file = File.new()
			if file.file_exists(quicksave_path):
				load_state(quicksave_path)
			else:
				push_warning("Cannot load quicksave file at '%s', does not exist!" % quicksave_path)

# Check a name that was given to us over the network.
# Returns: If the name is valid.
# name: The name to check.
func _check_name(name: String) -> bool:
	if not name.is_valid_filename():
		return false
	
	if ".." in name:
		return false
	
	return true

# Connect to the master server, and ask to join the given room.
# room_code: The room code to join with. If empty, ask the master server to
# make our own room.
func _connect_to_master_server(room_code: String = "") -> void:
	stop()
	
	_connecting_popup_label.text = tr("Connecting to the master server...")
	_connecting_popup.popup_centered()
	
	print("Connecting to master server at '%s' with room code '%s'..." %
		[_master_server.URL, room_code])
	_master_server.room_code = room_code
	_master_server.connect_to_server()

# Create a schema of the AssetDB, which contains the directory structure, and
# hash values of the piece entries.
# Returns: A schema of the AssetDB.
func _create_schema_db() -> Dictionary:
	var schema = {}
	var asset_db = AssetDB.get_db()
	
	for pack in asset_db:
		var pack_dict = {}
		for type in asset_db[pack]:
			var type_arr = []
			for asset_entry in asset_db[pack][type]:
				var dict_to_hash: Dictionary = asset_entry.duplicate()
				var dict_keys = dict_to_hash.keys()
				
				# If we're going to hash the entry, we need to remove any
				# potential translations, since they will differ between
				# clients.
				var tr_keys = ["name", "desc"]
				for key in dict_keys:
					for tr_key in tr_keys:
						if key.begins_with(tr_key):
							if key != tr_key:
								dict_to_hash.erase(key)
				
				type_arr.append({
					"name": dict_to_hash["name"],
					"hash": dict_to_hash.hash()
				})
			
			pack_dict[type] = type_arr
		schema[pack] = pack_dict
	
	return schema

# Create a schema of the asset file system, under the user:// directory,
# containing the imported files and their md5 hashes.
# Returns: A schema of the asset filesystem.
func _create_schema_fs() -> Dictionary:
	var schema = {}
	
	var dir = Directory.new()
	var err = dir.open("user://assets")
	if err != OK:
		push_error("Failed to open the imported assets directory (error %d)" % err)
		return {}
	
	dir.list_dir_begin(true, true)
	var pack = dir.get_next()
	while pack:
		if dir.dir_exists(pack):
			var pack_dir = Directory.new()
			err = pack_dir.open("user://assets/" + pack)
			
			if err != OK:
				push_error("Failed to open '%s' imported directory (error %d)" % [pack, err])
				return {}
			
			for type in AssetDB.ASSET_PACK_SUBFOLDERS:
				if pack_dir.dir_exists(type):
					var sub_dir = Directory.new()
					err = sub_dir.open("user://assets/" + pack + "/" + type)
					
					if err != OK:
						push_error("Failed to open '%s/%s' imported directory (error %d" %
								[pack, type, err])
						return {}
					
					sub_dir.list_dir_begin(true, true)
					
					var file = sub_dir.get_next()
					while file:
						if AssetDB.VALID_EXTENSIONS.has(file.get_extension()):
							var file_path = "user://assets/" + pack + "/" + type + "/" + file
							var file_md5 = File.new()
							var md5 = file_md5.get_md5(file_path)
							if not md5.empty():
								if not schema.has(pack):
									schema[pack] = {}
								
								if not schema[pack].has(type):
									schema[pack][type] = {}
								
								schema[pack][type][file] = md5
							else:
								push_error("Failed to get md5 of '%s'" % file_path)
							
						file = sub_dir.get_next()
		pack = dir.get_next()
	
	return schema

# Create a network peer object.
# Returns: A WebRTCPeerConnection for the given peer.
# id: The ID of the peer.
func _create_peer(id: int) -> WebRTCPeerConnection:
	print("Creating a connection for peer %d..." % id)
	
	var peer = WebRTCPeerConnection.new()
	peer.initialize({
		"iceServers": [
			{ "urls": ["stun:stun.l.google.com:19302"] }
		]
	})
	
	peer.connect("session_description_created", self, "_on_offer_created", [id])
	peer.connect("ice_candidate_created", self, "_on_new_ice_candidate", [id])
	
	_rtc.add_peer(peer, id)
	if id > _rtc.get_unique_id():
		peer.create_offer()
	
	return peer

# Open a table state (.tc) file in the given mode.
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

func _on_connected(id: int):
	print("Connected to the room as peer %d." % id)
	_rtc.initialize(id, true)
	
	# Assign the WebRTCMultiplayer object to the scene tree, so all nodes can
	# use it with the RPC system.
	get_tree().network_peer = _rtc
	
	_connecting_popup.hide()
	
	# If we are the host, then add ourselves to the lobby, and create our own
	# hand.
	if id == 1:
		Lobby.rpc_id(1, "add_self", 1, _player_name, _player_color)
		
		var hand_transform = _room.srv_get_next_hand_transform()
		if hand_transform == Transform.IDENTITY:
			push_warning("Table has no available hand positions!")
		_room.rpc_id(1, "add_hand", 1, hand_transform)
	else:
		_connecting_popup_label.text = tr("Establishing connection with the host...")
		_connecting_popup.popup_centered()

func _on_disconnected():
	stop()
	
	print("Disconnected from the server! Code: %d Reason: %s" % [_master_server.code, _master_server.reason])
	if _master_server.code == 1000:
		Global.start_main_menu()
	else:
		Global.start_main_menu_with_error(tr("Disconnected from the server! Code: %d Reason: %s") % [_master_server.code, _master_server.reason])

func _on_answer_received(id: int, answer: String):
	print("Received answer from peer %d." % id)
	if _rtc.has_peer(id):
		_rtc.get_peer(id).connection.set_remote_description("answer", answer)

func _on_candidate_received(id: int, mid: String, index: int, sdp: String):
	print("Received candidate from peer %d." % id)
	if _rtc.has_peer(id):
		_rtc.get_peer(id).connection.add_ice_candidate(mid, index, sdp)

func _on_connection_established(id: int):
	print("Connection established with peer %d." % id)
	# If a player has connected to the server, let them know of every piece on
	# the board so far.
	if get_tree().is_network_server():
		var compressed_state = _room.get_state_compressed(true, true)
		_room.rpc_id(id, "set_state_compressed", compressed_state)
		
		# If there is space, also give them a hand on the table.
		var hand_transform = _room.srv_get_next_hand_transform()
		if hand_transform != Transform.IDENTITY:
			_room.rpc("add_hand", id, hand_transform)
		
		_room.start_sending_cursor_position()
		
		# Send them our asset schemas to see if they are missing any assets.
		rpc_id(id, "compare_server_schemas", _srv_schema_db, _srv_schema_fs)
	
	# If we are not the host, then ask the host to send us their list of
	# players.
	elif id == 1:
		Lobby.rpc_id(1, "request_sync_players")
		_room.start_sending_cursor_position()
		
		_connecting_popup.hide()

func _on_new_ice_candidate(mid: String, index: int, sdp: String, id: int):
	_master_server.send_candidate(id, mid, index, sdp)

func _on_offer_created(type: String, data: String, id: int):
	if not _rtc.has_peer(id):
		return
	print("Created %s for peer %d." % [type, id])
	_rtc.get_peer(id).connection.set_local_description(type, data)
	if type == "offer":
		_master_server.send_offer(id, data)
	else:
		_master_server.send_answer(id, data)

func _on_offer_received(id: int, offer: String):
	print("Received offer from peer %d." % id)
	if _rtc.has_peer(id):
		_rtc.get_peer(id).connection.set_remote_description("offer", offer)

func _on_peer_connected(id: int):
	print("Peer %d has connected." % id)
	_create_peer(id)

func _on_peer_disconnected(id: int):
	print("Peer %d has disconnected." % id)
	if _rtc.has_peer(id):
		_rtc.remove_peer(id)
	
	if id in _established_connection_with:
		_established_connection_with.erase(id)
	
	if get_tree().is_network_server():
		Lobby.rpc("remove_self", id)
		
		_room.rpc("remove_hand", id)
		_room.srv_stop_player_hovering(id)

func _on_room_joined(room_code: String):
	print("Joined room %s." % room_code)
	_master_server.room_code = room_code
	_ui.set_room_code(room_code)

func _on_room_sealed():
	Global.start_main_menu_with_error(tr("Room has been closed by the host."))

func _on_DownloadAssetsConfirmDialog_confirmed():
	pass # Replace with function body.

func _on_GameUI_about_to_save_table():
	_room_state_saving = _room.get_state(false, false)

func _on_GameUI_applying_options(config: ConfigFile):
	apply_options(config)

func _on_GameUI_flipping_table():
	_room.rpc_id(1, "request_flip_table", _room.get_camera_transform().basis)

func _on_GameUI_leaving_room():
	if get_tree().is_network_server():
		if _master_server.is_connection_established():
			_master_server.seal_room()

func _on_GameUI_lighting_requested(lamp_color: Color, lamp_intensity: float,
	lamp_sunlight: bool):
	
	_room.rpc_id(1, "request_set_lamp_color", lamp_color)
	_room.rpc_id(1, "request_set_lamp_intensity", lamp_intensity)
	_room.rpc_id(1, "request_set_lamp_type", lamp_sunlight)

func _on_GameUI_load_table(path: String):
	load_state(path)

func _on_GameUI_piece_requested(piece_entry: Dictionary, position: Vector3):
	var entry_path = piece_entry["entry_path"]
	_room.rpc_id(1, "request_add_piece", entry_path, position)

func _on_GameUI_piece_requested_in_container(piece_entry: Dictionary, container_name: String):
	var entry_path = piece_entry["entry_path"]
	_room.rpc_id(1, "request_add_piece_in_container", entry_path, container_name)

func _on_GameUI_requesting_room_details():
	_ui.set_room_details(_room.get_table(), _room.get_skybox(),
		_room.get_lamp_color(), _room.get_lamp_intensity(),
		_room.get_lamp_type())

func _on_GameUI_save_table(path: String):
	if _room_state_saving.empty():
		push_error("Room state to save is empty!")
		return
	
	save_state(_room_state_saving, path)

func _on_GameUI_stopped_saving_table():
	_room_state_saving = {}

func _on_GameUI_skybox_requested(skybox_entry: Dictionary):
	var skybox_entry_path = skybox_entry["entry_path"]
	_room.rpc_id(1, "request_set_skybox", skybox_entry_path)

func _on_GameUI_table_requested(table_entry: Dictionary):
	var table_entry_path = table_entry["entry_path"]
	_room.rpc_id(1, "request_set_table", table_entry_path)

func _on_Lobby_players_synced():
	if not get_tree().is_network_server():
		Lobby.rpc_id(1, "request_add_self", _player_name, _player_color)

func _on_MissingYesButton_pressed():
	_download_assets_confirm_dialog.popup_centered()
	_missing_assets_dialog.visible = false

func _on_MissingNoButton_pressed():
	_missing_assets_dialog.visible = false

func _on_Room_setting_spawn_point(position: Vector3):
	_ui.spawn_point_origin = position

func _on_Room_spawning_piece_at(position: Vector3):
	_ui.spawn_point_container_name = ""
	_ui.spawn_point_temp_offset = position - _ui.spawn_point_origin
	_ui.popup_objects_dialog()

func _on_Room_spawning_piece_in_container(container_name: String):
	_ui.spawn_point_container_name = container_name
	_ui.popup_objects_dialog()

func _on_Room_table_flipped():
	_ui.set_flip_table_status(true)

func _on_Room_table_unflipped():
	_ui.set_flip_table_status(false)

func _on_TableStateVersionDialog_confirmed():
	var compressed_state = _room.compress_state(_state_version_save)
	_room.rpc_id(1, "request_load_table_state", compressed_state)
