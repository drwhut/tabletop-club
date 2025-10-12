# tabletop-club
# Copyright (c) 2020-2025 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2025 Tabletop Club contributors (see game/CREDITS.tres).
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
onready var _download_assets_error_dialog = $DownloadAssetsErrorDialog
onready var _download_assets_progress_dialog = $DownloadAssetsProgressDialog
onready var _download_lock_dialog = $DownloadLockDialog
onready var _download_progress_bar = $DownloadAssetsProgressDialog/VBoxContainer/DownloadProgressBar
onready var _download_progress_label = $DownloadAssetsProgressDialog/VBoxContainer/DownloadProgressLabel
onready var _import_progress_bar = $DownloadAssetsProgressDialog/VBoxContainer/ImportProgressBar
onready var _import_progress_label = $DownloadAssetsProgressDialog/VBoxContainer/ImportProgressLabel
onready var _master_server = $MasterServer
onready var _missing_assets_dialog = $MissingAssetsDialog
onready var _missing_db_label = $MissingAssetsDialog/VBoxContainer/MissingDBLabel
onready var _missing_db_summary_label = $MissingAssetsDialog/VBoxContainer/MissingDBSummaryLabel
onready var _missing_fs_label = $MissingAssetsDialog/VBoxContainer/MissingFSLabel
onready var _missing_fs_summary_label = $MissingAssetsDialog/VBoxContainer/MissingFSSummaryLabel
onready var _room = $Room
onready var _table_state_error_dialog = $TableStateErrorDialog
onready var _table_state_version_dialog = $TableStateVersionDialog
onready var _ui = $GameUI
onready var _verify_progress_bar = $DownloadAssetsProgressDialog/VBoxContainer/VerifyProgressBar
onready var _verify_progress_label = $DownloadAssetsProgressDialog/VBoxContainer/VerifyProgressLabel

export(bool) var autosave_enabled: bool = true
export(int) var autosave_interval: int = 300
export(int) var autosave_count: int = 10

var _rtc = WebRTCMultiplayer.new()
var _established_connection_with = []
var _is_room_sealed = false
var _master_connect_wait_frames = 0

var _player_name: String
var _player_color: Color

var _room_state_saving: Dictionary = {}
var _save_screenshot_frames: int = -1
var _save_screenshot_path: String = ""
var _state_version_save: Dictionary = {}
var _time_since_last_autosave: float = 0.0

var _cln_compared_schemas: bool = false
var _cln_need_db: Dictionary = {}
var _cln_need_fs: Dictionary = {}
var _cln_expect_db: Dictionary = {}
var _cln_expect_fs: Dictionary = {}
var _cln_keep_expecting: bool = false
var _cln_save_chunk_thread: Thread = null
var _srv_expect_sync: Array = []
var _srv_file_transfer_threads: Dictionary = {}
var _srv_schema_db: Dictionary = {}
var _srv_schema_fs: Dictionary = {}
var _srv_skip_sync: bool = false
var _srv_waiting_for: Array = []

const TRANSFER_CHUNK_SIZE   = 50000 # 50Kb
const TRANSFER_CHUNK_DELAY  = 0.1 # 100ms, up to 500Kb/s.
const TRANSFER_MAX_COMMANDS = 5 # Up to 250Kb of RAM.
# We don't have access to WebRTCDataChannel.get_buffered_amount(), so we can't
# tell how much data is in the channel. So we need to give a guess as to how
# long it will take for the outgoing packets to flush, while trying to
# accomodate for slower computers.

var _transfer_clients_stopping: Array = []
var _transfer_commands: Array = []
var _transfer_error_in_thread: bool = false
var _transfer_import_files: bool = false
var _transfer_mutex: Mutex = Mutex.new()
var _transfer_num_expected_rpcs: int = 0
var _transfer_time_since_rpc: float = 0.0

var _progress_total_rpcs: int = 0

var _progress_import_current: int = 0
var _progress_import_file: String = ""
var _progress_import_mutex: Mutex = Mutex.new()
var _progress_import_total: int   = 0

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
	
	if get_tree().has_network_peer():
		if Lobby.player_exists(get_tree().get_network_unique_id()):
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
			var registered_names = []
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
				
				# Duplicate names are not allowed in the AssetDB!
				if server_meta["name"] in registered_names:
					push_error("Name '%s' in server DB schema has already been registered!" % server_meta["name"])
					return
				registered_names.append(server_meta["name"])
				
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
	
	for pack in client_schema_db:
		if not pack in server_schema_db:
			var extra_pack = {}
			
			for type in client_schema_db[pack]:
				var extra_type = []
				for i in range(client_schema_db[pack][type].size()):
					extra_type.append(i)
				extra_pack[type] = extra_type
			
			db_extra[pack] = extra_pack
	
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
				
				var server_ext = server_name.get_extension()
				if not server_ext in AssetDB.VALID_EXTENSIONS:
					push_error("File extension '%s' in '%s' in server FS schema is invalid!" % [server_ext, server_name])
					return
				
				var server_meta = server_type_dict[server_name]
				if not server_meta is Dictionary:
					push_error("Value of %s/%s/%s in server FS schema is not a dictionary!" % [pack, type, server_name])
					return
				
				if server_meta.size() != 2:
					push_error("%s/%s/%s meta in server FS schema does not contain two elements!" % [pack, type, server_name])
					return
				
				if not server_meta.has("md5"):
					push_error("%s/%s/%s meta in server FS schema does not contain an md5!" % [pack, type, server_name])
					return
				
				var server_md5 = server_meta["md5"]
				if not server_md5 is String:
					push_error("%s/%s/%s MD5 in server FS schema is not a string!" % [pack, type, server_name])
					return
				
				if not server_md5.is_valid_hex_number():
					push_error("%s/%s/%s MD5 in server FS schema is not a valid hex number!" % [pack, type, server_name])
					return
				
				if not server_meta.has("size"):
					push_error("%s/%s/%s meta in server FS schema does not contain a size!" % [pack, type, server_name])
					return
				
				var server_size = server_meta["size"]
				if not server_size is int:
					push_error("%s/%s/%s size in server FS schema is not an integer!" % [pack, type, server_name])
					return
				
				if server_size < 0:
					push_error("%s/%s/%s size in server FS schema is invalid (%d)!" % [pack, type, server_name, server_size])
					return
				
				if client_type_dict.has(server_name):
					# Do the MD5 hashes not match?
					if client_type_dict[server_name]["md5"] != server_md5:
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
	print("- Files that we need from the host:")
	var total_size_need = 0
	_transfer_num_expected_rpcs = 0
	for pack in fs_need:
		for type in fs_need[pack]:
			for asset in fs_need[pack][type]:
				var path = "%s/%s/%s" % [pack, type, asset]
				var size = server_schema_fs[pack][type][asset]["size"]
				total_size_need += size
				if size == 0:
					_transfer_num_expected_rpcs += 1
				else:
					_transfer_num_expected_rpcs += int(ceil(float(size) / TRANSFER_CHUNK_SIZE))
				
				if _missing_fs_label.text.length() > 0:
					_missing_fs_label.text += "\n"
				_missing_fs_label.text += "- %s (%s)" % [path,
						String.humanize_size(size)]
				print(path)
	print("We expect these files to be delivered in a total of %d RPCs." % _transfer_num_expected_rpcs)
	_progress_total_rpcs = _transfer_num_expected_rpcs
	_missing_fs_summary_label.text = _missing_fs_summary_label.text % [
			fs_num_missing, fs_num_modified, String.humanize_size(total_size_need)]
	
	print("Temporarily removing entries that the host does not have...")
	for pack in db_extra:
		for type in db_extra[pack]:
			# Do not remove templates, since otherwise our own notebook pages
			# may not work.
			if type == "templates":
				continue
			
			var type_arr = db_extra[pack][type]
			for index_arr in range(type_arr.size() - 1, -1, -1):
				var index_asset = type_arr[index_arr]
				AssetDB.temp_remove_entry(pack, type, index_asset)
	
	if not db_extra.empty():
		# Prevent the player from spawning in the extra objects.
		_ui.reconfigure_asset_dialogs()
	
	if not fs_need.empty():
		_clear_download_cache()
	
	if db_need.empty() and fs_need.empty():
		rpc_id(1, "respond_with_schema_results", {}, {})
	else:
		_missing_assets_dialog.popup_centered()
	
	_cln_need_db = db_need
	_cln_need_fs = fs_need
	
	# Store as much information as possible about what we expect from the
	# server so that we can verify everything that comes in later.
	_cln_expect_db.clear()
	for pack in db_need:
		var pack_dict = {}
		
		for type in db_need[pack]:
			var type_arr = []
			
			for index in db_need[pack][type]:
				type_arr.append(server_schema_db[pack][type][index])
			
			pack_dict[type] = type_arr
		_cln_expect_db[pack] = pack_dict
	
	_cln_expect_fs.clear()
	for pack in fs_need:
		var pack_dict = {}
		
		for type in fs_need[pack]:
			var type_dict = {}
			
			for asset in fs_need[pack][type]:
				var meta = server_schema_fs[pack][type][asset]
				type_dict[asset] = meta
			
			pack_dict[type] = type_dict
		_cln_expect_fs[pack] = pack_dict

# Called by the server when they transfer a chunk of a missing asset file to
# the client.
# pack: The pack the file belongs to.
# type: The type of file.
# asset: The name of the file.
# chunk: The chunk of the file.
puppet func receive_missing_asset_chunk(pack: String, type: String,
	asset: String, chunk: PoolByteArray) -> void:
	
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_transfer_mutex.lock()
	var num_expected_rpcs = _transfer_num_expected_rpcs
	_transfer_mutex.unlock()
	
	if num_expected_rpcs <= 0:
		push_warning("Got an asset chunk when we weren't expecting one, ignoring.")
		return
	
	_transfer_mutex.lock()
	_transfer_num_expected_rpcs -= 1
	_transfer_mutex.unlock()
	
	if not _cln_expect_fs.has(pack):
		push_warning("Got asset chunk for pack '%s' which we weren't expecting, ignore." % pack)
		return
	
	if not _cln_expect_fs[pack].has(type):
		push_warning("Got asset chunk for type '%s/%s' which we weren't expecting, ignore." % [pack, type])
		return
	
	if not _cln_expect_fs[pack][type].has(asset):
		push_warning("Got asset chunk for '%s/%s/%s' which we weren't expecting, ignore." % [pack, type, asset])
		return
	
	var size_remaining: int = _cln_expect_fs[pack][type][asset]["size"]
	var chunk_expected_size = min(size_remaining, TRANSFER_CHUNK_SIZE)
	if chunk.size() != chunk_expected_size:
		push_warning("Chunk size should be %d, got %d, ignoring." % [chunk_expected_size, chunk.size()])
		return
	
	print("Got: %s/%s/%s (size = %d)" % [pack, type, asset, chunk.size()])
	_cln_expect_fs[pack][type][asset]["size"] -= chunk.size()
	
	_download_progress_label.text = tr("Downloading %s ...") % asset
	var progress = 100
	if _progress_total_rpcs > 0:
		progress = 100 * (1.0 - (float(num_expected_rpcs - 1) / _progress_total_rpcs))
	_download_progress_bar.value = progress
	
	_transfer_mutex.lock()
	_transfer_commands.push_back({
		"pack": pack,
		"type": type,
		"asset": asset,
		"chunk": chunk
	})
	_transfer_mutex.unlock()
	
	if _cln_save_chunk_thread == null:
		_cln_save_chunk_thread = Thread.new()
		_cln_save_chunk_thread.start(self, "_save_chunks_to_cache")

# Called by the server to receive the missing AssetDB entries that the client
# asked for.
# missing_entries: The directory of missing entries.
puppet func receive_missing_db_entries(missing_entries: Dictionary) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if _cln_expect_db.empty():
		push_warning("Received DB entries from the server when we weren't expecting any, ignoring.")
		return
	
	for pack in missing_entries:
		if not pack is String:
			_popup_download_error("Pack in server DB is not a string!")
			return
		
		if not _check_name(pack):
			_popup_download_error("Pack string in server DB is not a valid name!")
			return
		
		var pack_dict = missing_entries[pack]
		if not pack_dict is Dictionary:
			_popup_download_error("Value of pack '%s' in server DB is not a dictionary!" % pack)
			return
		
		for type in pack_dict:
			if not type is String:
				_popup_download_error("Type in pack '%s' in server DB is not a string!" % pack)
				return
			
			if not type in AssetDB.ASSET_PACK_SUBFOLDERS:
				_popup_download_error("Type '%s' in pack '%s' in server DB is not a valid type!" % [type, pack])
				return
			
			var type_arr = pack_dict[type]
			if not type_arr is Array:
				_popup_download_error("Type '%s' value in pack '%s' in server DB is not an array!" % [type, pack])
				return
			
			# We need to add stack entries last, after the entries they rely on
			# have been added!
			var stack_entries = []
			
			for entry in type_arr:
				if not entry is Dictionary:
					_popup_download_error("Entry in '%s/%s' in server DB is not a dictionary!" % [pack, type])
					return
				
				var entry_name = ""
				var has_desc = false
				
				for key in entry:
					if not key is String:
						_popup_download_error("Key in entry in '%s/%s' in server DB is not a string!" % [pack, type])
						return
					
					if not _check_name(key):
						_popup_download_error("Key in entry in '%s/%s' in server DB is not a valid name!" % [pack, type])
						return
					
					var value = entry[key]
					if not _is_only_data(value):
						_popup_download_error("Value of key '%s' in '%s/%s' in server DB is not pure data!" % [key, pack, type])
						return
					
					if key == "name":
						if not value is String:
							_popup_download_error("'name' property in '%s/%s' in server DB is not a string!" % [pack, type])
							return
						if not _check_name(value):
							_popup_download_error("Name '%s' in '%s/%s' in server DB is not a valid name!" % [value, pack, type])
							return
						entry_name = value
					
					elif key == "desc":
						if not value is String:
							_popup_download_error("'desc' property in '%s/%s' in server DB is not a string!" % [pack, type])
							return
						has_desc = true
					
					# TODO: Verify that given the type, the entry is valid by
					# checking every key-value pair.
				
				if entry_name.empty():
					_popup_download_error("Entry in '%s/%s' in server DB does not have a name!" % [pack, type])
					return
				
				if not has_desc:
					_popup_download_error("Entry in '%s/%s' in server DB does not have a description!" % [pack, type])
					return
				
				var entry_hash = _cross_platform_hash(entry)
				var entry_index = -1
				
				for index in range(_cln_expect_db[pack][type].size()):
					var test_entry = _cln_expect_db[pack][type][index]
					if entry_name == test_entry["name"]:
						if entry_hash == test_entry["hash"]:
							entry_index = index
							break
				
				if entry_index < 0:
					_popup_download_error("Entry '%s/%s/%s' in server DB was not expected!" % [pack, type, entry_name])
					return
				
				if entry.has("entry_names"):
					stack_entries.append(entry)
				else:
					AssetDB.temp_add_entry(pack, type, entry)
				
				_cln_expect_db[pack][type].remove(entry_index)
			
			for stack_entry in stack_entries:
				AssetDB.temp_add_entry(pack, type, stack_entry)
	
	var num_missing_db = 0
	for pack in _cln_expect_db:
		for type in _cln_expect_db[pack]:
			num_missing_db += _cln_expect_db[pack][type].size()
	
	if num_missing_db > 0:
		push_warning("Not all missing entries were sent, clearing server DB schema anyway.")
	_cln_expect_db.clear()
	
	if _cln_expect_fs.empty():
		_ui.reconfigure_asset_dialogs()
		rpc_id(1, "request_sync_state")

# Called by the server when they say that we have received all of the asset
# chunks that we requested.
puppet func received_all_asset_chunks() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if _cln_save_chunk_thread != null:
		if _cln_save_chunk_thread.is_active():
			_cln_save_chunk_thread.wait_to_finish()
	else:
		_cln_save_chunk_thread = Thread.new()
	
	_download_progress_label.text = tr("Download completed!")
	
	# We'll use the same thread to import the new assets.
	var instructions = []
	var num_files = 0
	for pack in _cln_expect_fs:
		for type in _cln_expect_fs[pack]:
			for asset in _cln_expect_fs[pack][type]:
				var meta = _cln_expect_fs[pack][type][asset]
				var file_expected_md5 = meta["md5"]
				var remaining_size = meta["size"]
				
				num_files += 1
				
				var act_file_path = "user://assets/%s/%s/%s" % [pack, type, asset]
				var tmp_file_path = "user://tmp/%s.%s.bin" % [asset, act_file_path.md5_text()]
				
				if remaining_size != 0:
					push_warning("Remaining size of %s/%s/%s is %d, not 0 - ignoring." % [pack, type, asset, remaining_size])
					continue
				
				var check_md5 = File.new()
				if check_md5.get_md5(tmp_file_path) != file_expected_md5:
					push_warning("MD5 of %s/%s/%s does not match what the server told us - ignoring." % [pack, type, asset])
					continue
				
				var instruction = {
					"pack": pack,
					"type": type,
					"asset": asset
				}
				
				# Like in the AssetDB, import scenes last, since they may
				# depend on the other assets like textures.
				if AssetDB.VALID_SCENE_EXTENSIONS.has(asset.get_extension()):
					instructions.push_back(instruction)
				else:
					instructions.push_front(instruction)
	
	_verify_progress_label.text = tr("Verified %d out of %d files!") % [instructions.size(), num_files]
	if num_files == 0:
		_verify_progress_bar.value = 100
	else:
		_verify_progress_bar.value = 100 * (float(instructions.size()) / num_files)
	
	_progress_import_total = instructions.size()
	
	_transfer_mutex.lock()
	_transfer_import_files = true
	_transfer_mutex.unlock()
	_cln_save_chunk_thread.start(self, "_import_new_assets", instructions)

# Called by the client to send the current room state back to them. This can be
# called either right after the client joins, or after they have downloaded the
# missing assets.
master func request_sync_state() -> void:
	var client_id = get_tree().get_rpc_sender_id()
	if client_id in _srv_expect_sync:
		var compressed_state = _room.get_state_compressed(true, true)
		_room.rpc_id(client_id, "set_state_compressed", compressed_state, "")
		
		_srv_expect_sync.erase(client_id)
		Global.srv_state_update_blacklist.erase(client_id)
	else:
		push_warning("Client %d requested state sync when we weren't expecting, ignoring." % client_id)

# Called by the client after they have compared the server's schemas against
# their own.
# client_db_need: What the client reports that they need from the AssetDB.
# client_fs_need: What the client reports that they need from the file system.
master func respond_with_schema_results(client_db_need: Dictionary,
	client_fs_need: Dictionary) -> void:
	
	var client_id = get_tree().get_rpc_sender_id()
	if not client_id in _srv_waiting_for:
		push_warning("Got response from ID %d when we weren't expecting one!" % client_id)
		return
	
	_srv_waiting_for.erase(client_id)
	
	var asset_db = AssetDB.get_db()
	var db_provide = {}
	for pack in client_db_need:
		if not pack is String:
			push_error("Pack in client DB is not a string!")
			return
		
		if not _check_name(pack):
			push_error("Pack string '%s' in client DB is not a valid name!" % pack)
			return
		
		if not asset_db.has(pack):
			push_error("Pack '%s' in client DB does not exist in the AssetDB!" % pack)
			return
		
		var pack_dict = client_db_need[pack]
		if not pack_dict is Dictionary:
			push_error("Value under pack '%s' in client DB is not a dictionary!" % pack)
			return
		
		var pack_provide = {}
		for type in pack_dict:
			if not type is String:
				push_error("Type under pack '%s' in client DB is not a string!" % pack)
				return
			
			if not type in AssetDB.ASSET_PACK_SUBFOLDERS:
				push_error("Type '%s' under pack '%s' in client DB is not a valid type!" % [type, pack])
				return
			
			if not asset_db[pack].has(type):
				push_error("Type '%s' under pack '%s' in client DB is not in the AssetDB!" % [type, pack])
				return
			
			var index_arr = pack_dict[type]
			if not index_arr is Array:
				push_error("Value in '%s/%s' in client DB is not an array!" % [pack, type])
				return
			
			var asset_db_type = asset_db[pack][type]
			var indicies_registered = []
			var type_provide = []
			for index in index_arr:
				if not index is int:
					push_error("Index in '%s/%s' in client DB is not an integer!" % [pack, type])
					return
				
				if index < 0 or index >= asset_db_type.size():
					push_error("Index %d in '%s/%s' in client DB is invalid!" % [index, pack, type])
					return
				
				if index in indicies_registered:
					push_error("Index %d in '%s/%s' in client DB has already been registered!" % [index, pack, type])
					return
				
				indicies_registered.append(index)
				var entry = asset_db_type[index].duplicate()
				
				# In order for the hash of the entry to match what we sent to
				# the client earlier, we need to remove any translations in the
				# entry.
				var tr_keys = ["name", "desc"]
				for key in entry:
					for tr_key in tr_keys:
						if key.begins_with(tr_key):
							if key != tr_key:
								entry.erase(key)
				
				type_provide.append(entry)
			pack_provide[type] = type_provide
		db_provide[pack] = pack_provide
	
	var file = File.new()
	var fs_provide = {}
	for pack in client_fs_need:
		if not pack is String:
			push_error("Pack in client FS is not a string!")
			return
		
		if not _check_name(pack):
			push_error("Pack string '%s' in client FS is not a valid name!" % pack)
			return
		
		if not asset_db.has(pack):
			push_error("Pack '%s' in client FS does not exist in the AssetDB!" % pack)
			return
		
		var pack_dict = client_fs_need[pack]
		if not pack_dict is Dictionary:
			push_error("Value under pack '%s' in client FS is not a dictionary!" % pack)
			return
		
		var pack_provide = {}
		for type in pack_dict:
			if not type is String:
				push_error("Type under pack '%s' in client FS is not a string!" % pack)
				return
			
			if not type in AssetDB.ASSET_PACK_SUBFOLDERS:
				push_error("Type '%s' under pack '%s' in client FS is not a valid type!" % [type, pack])
				return
			
			if not asset_db[pack].has(type):
				push_error("Type '%s' under pack '%s' in client FS is not in the AssetDB!" % [type, pack])
				return
			
			var name_arr = pack_dict[type]
			if not name_arr is Array:
				push_error("Value in '%s/%s' in client DB is not an array!" % [pack, type])
				return
			
			var type_provide = []
			for file_name in name_arr:
				if not file_name is String:
					push_error("Name in '%s/%s' in client DB is not a string!" % [pack, type])
					return
				
				if not _check_name(file_name):
					push_error("Name '%s' in '%s/%s' in client DB is invalid!" % [file_name, pack, type])
					return
				
				var file_path = "user://assets/%s/%s/%s" % [pack, type, file_name]
				if not file.file_exists(file_path):
					push_error("File '%s' in client DB does not exist!" % file_path)
					return
				
				type_provide.append(file_name)
			pack_provide[type] = type_provide
		fs_provide[pack] = pack_provide
	
	if not client_id in _srv_expect_sync:
		_srv_expect_sync.append(client_id)
	
	if db_provide.empty() and fs_provide.empty():
		request_sync_state()
	else:
		if not db_provide.empty():
			rpc_id(client_id, "receive_missing_db_entries", db_provide)
		
		if not fs_provide.empty():
			if client_id in _srv_file_transfer_threads:
				push_error("File transfer thread already created for ID %d!" % client_id)
				return
			
			var peer: Dictionary = _rtc.get_peer(client_id)
			var data_channel: WebRTCDataChannel = peer["channels"][0]
			
			var transfer_thread = Thread.new()
			transfer_thread.start(self, "_transfer_asset_files", {
				"client_id": client_id,
				"data_channel": data_channel,
				"provide": fs_provide
			})
			_srv_file_transfer_threads[client_id] = transfer_thread

# Ask the master server to host a game.
func start_host() -> void:
	print("Hosting game...")
	
	_srv_schema_db = _create_schema_db()
	_srv_schema_fs = _create_schema_fs()
	
	var db_size = var2bytes(_srv_schema_db).size()
	var fs_size = var2bytes(_srv_schema_fs).size()
	
	# TODO: May want to consider compressing the schemas before sending them,
	# this would also have to be done for other dictionaries sent, e.g. the
	# response from the client.
	if db_size + fs_size > TRANSFER_CHUNK_SIZE:
		push_warning("AssetDB schema is too large to send over the network, will skip syncing.")
		
		_srv_skip_sync = true
		_srv_schema_db.clear()
		_srv_schema_fs.clear()
	
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
	
	_ui.hide_multiplayer_ui()

# Stop the connections to the other peers and the master server.
func stop() -> void:
	_rtc.close()
	_master_server.close()

# Clled by the client if they want the server to stop sending them asset chunks.
master func stop_sending_asset_chunks() -> void:
	var client_id = get_tree().get_rpc_sender_id()
	
	if not client_id in _srv_file_transfer_threads:
		push_warning("Client %d asked us to stop sending asset chunks, when we don't have a thread for them - ignoring." % client_id)
		return
	
	if not client_id in _srv_expect_sync:
		push_warning("Client %d asked us to stop sending asset chunks after they synced table state - ignoring." % client_id)
		return
	
	_transfer_mutex.lock()
	var has_stopped = _transfer_clients_stopping.has(client_id)
	_transfer_mutex.unlock()
	
	if has_stopped:
		push_warning("Client %d asked us to stop sending asset chunks more than once - ignoring." % client_id)
		return
	
	_transfer_mutex.lock()
	_transfer_clients_stopping.append(client_id)
	_transfer_mutex.unlock()

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

# Called by the server to verify that the client's game version matches theirs.
puppet func verify_game_version(server_version: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if _is_room_sealed:
		return
	
	# Should always be the case, but if not, well... good luck, I guess :P
	if ProjectSettings.has_setting("application/config/version"):
		var client_version = ProjectSettings.get_setting("application/config/version")
		
		if client_version != server_version:
			Global.start_main_menu_with_error(tr("Client version (%s) does not match server version (%s)!" % [
					client_version, server_version]))

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
	
	# Sometimes we will know when a peer has disconnected before the master
	# server does, e.g. if the peer has crashed.
	_rtc.connect("peer_disconnected", self, "_on_peer_disconnected")
	
	Lobby.connect("players_synced", self, "_on_Lobby_players_synced")
	
	Lobby.clear_players()

func _process(delta):
	if _master_connect_wait_frames > 0:
		_master_connect_wait_frames -= 1
		
		if _master_connect_wait_frames == 0:
			_master_server.connect_to_server()
	
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
	
	if get_tree().is_network_server():
		_transfer_time_since_rpc += delta
		if _transfer_time_since_rpc > TRANSFER_CHUNK_DELAY:
			_transfer_mutex.lock()
			if not _transfer_commands.empty():
				var cmd: Dictionary = _transfer_commands.pop_front()
				var id: int = cmd["id"]
				
				# Check if the client is still connected before sending the
				# data.
				var is_connected = _rtc.has_peer(id)
				if is_connected:
					is_connected = _rtc.get_peer(id)["connected"]
				
				if is_connected:
					# Check if the client has asked us to stop sending chunks.
					if not _transfer_clients_stopping.has(id):
						if cmd.has("done"):
							rpc_id(id, "received_all_asset_chunks")
						else:
							var pack: String = cmd["pack"]
							var type: String = cmd["type"]
							var asset: String = cmd["asset"]
							var buffer: PoolByteArray = cmd["buffer"]
							
							if is_connected:
								print("Sending to %d: %s/%s/%s (size = %d)" % [
										id, pack, type, asset, buffer.size()])
								rpc_id(id, "receive_missing_asset_chunk", pack,
										type, asset, buffer)
						
						_transfer_time_since_rpc = 0.0
			_transfer_mutex.unlock()
	else:
		_transfer_mutex.lock()
		var done_importing_new_assets = false
		if _transfer_commands.size() == 1:
			if typeof(_transfer_commands[0]) == TYPE_STRING:
				if _transfer_commands[0] == "done_importing":
					done_importing_new_assets = true
					_transfer_commands.clear()
		
		if _transfer_error_in_thread:
			_download_assets_error_dialog.popup_centered()
			_transfer_error_in_thread = false
		
		var importing_files = false
		if not done_importing_new_assets:
			importing_files = _transfer_import_files
		_transfer_mutex.unlock()
		
		if done_importing_new_assets:
			var lock = Directory.new()
			if lock.file_exists("user://lock"):
				if lock.remove("user://lock") != OK:
					push_error("Failed to remove user://lock!")
			
			# Do the same as we do when we're done adding the extra AssetDB
			# entries.
			_cln_expect_fs.clear()
			
			_download_assets_progress_dialog.visible = false
			
			if _cln_expect_db.empty():
				_ui.reconfigure_asset_dialogs()
				rpc_id(1, "request_sync_state")
		
		elif importing_files:
			_progress_import_mutex.lock()
			_import_progress_label.text = tr("Importing %s ...") % _progress_import_file
			if _progress_import_total == 0:
				_import_progress_bar.value = 100
			else:
				_import_progress_bar.value = 100 * (float(_progress_import_current) / _progress_import_total)
			_progress_import_mutex.unlock()

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
# name_to_check: The name to check.
func _check_name(name_to_check: String) -> bool:
	if name_to_check.length() < 1 or name_to_check.length() > 256:
		return false
	
	if not name_to_check.is_valid_filename():
		return false
	
	if ".." in name_to_check:
		return false
	
	var after = name_to_check.strip_edges().strip_escapes()
	if after != name_to_check:
		return false
	
	if name_to_check.begins_with("."):
		return false
	
	return true

# Clear the download cache, which consists of all files under user://tmp/
func _clear_download_cache() -> void:
	var download_dir = Directory.new()
	var err = download_dir.open("user://")
	if err == OK:
		if download_dir.dir_exists("tmp"):
			err = download_dir.change_dir("tmp")
			if err == OK:
				print("Deleting the download cache...")
				download_dir.list_dir_begin(true, true)
				
				var file = download_dir.get_next()
				while file:
					if not download_dir.current_is_dir():
						err = download_dir.remove(file)
						if err != OK:
							push_error("Failed to remove tmp/%s (error %d)" % [file, err])
					
					file = download_dir.get_next()
				
				download_dir.list_dir_end()
			else:
				push_error("Failed to open the user://tmp directory (error %d)" % err)
	else:
		push_error("Failed to open the user:// directory (error %d)" % err)

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
	
	# Wait a couple of frames for the scene to be fully ready. The master server
	# has a timeout between the beginning of the connection, and when we provide
	# the room code - so we want to know when the connection is established as
	# soon as possible.
	_master_connect_wait_frames = 2

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
					"hash": _cross_platform_hash(dict_to_hash)
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
							var fp = File.new()
							
							# Has the file been imported?
							var needs_importing = AssetDB.EXTENSIONS_TO_IMPORT.has(file.get_extension())
							var has_been_imported = fp.file_exists(file_path + ".import")
							if (not needs_importing) or has_been_imported:
								err = fp.open(file_path, File.READ)
								if err == OK:
									var file_len = fp.get_len()
									var md5 = fp.get_md5(file_path)
									if not md5.empty():
										if not schema.has(pack):
											schema[pack] = {}
										
										if not schema[pack].has(type):
											schema[pack][type] = {}
										
										schema[pack][type][file] = {
											"md5": md5,
											"size": file_len
										}
									else:
										push_error("Failed to get md5 of '%s'" % file_path)
									
									fp.close()
								else:
									push_error("Failed to open '%s'" % file_path)
						
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

# Hash a dictionary, with respect to the differences in floating-point
# representations and calculations.
# Returns: The hash of the dictionary.
# dict: The dictionary to hash.
func _cross_platform_hash(dict: Dictionary) -> int:
	return _cross_platform_hash_helper(dict).hash()

# A helper function for _cross_platform_hash.
# Returns: The modified value.
# value: The value to potentially modify.
func _cross_platform_hash_helper(value):
	match typeof(value):
		TYPE_REAL:
			# Store floats as integers, with 3 decimal places of precision.
			return [ TYPE_REAL, int(1000.0 * value) ]
		TYPE_VECTOR2:
			return [
				TYPE_VECTOR2,
				_cross_platform_hash_helper(value.x),
				_cross_platform_hash_helper(value.y)
			]
		TYPE_RECT2:
			return [
				TYPE_RECT2,
				_cross_platform_hash_helper(value.end),
				_cross_platform_hash_helper(value.position),
				_cross_platform_hash_helper(value.size)
			]
		TYPE_VECTOR3:
			return [
				TYPE_VECTOR3,
				_cross_platform_hash_helper(value.x),
				_cross_platform_hash_helper(value.y),
				_cross_platform_hash_helper(value.z)
			]
		TYPE_TRANSFORM2D:
			return [
				TYPE_TRANSFORM2D,
				_cross_platform_hash_helper(value.origin),
				_cross_platform_hash_helper(value.x),
				_cross_platform_hash_helper(value.y)
			]
		TYPE_PLANE:
			return [
				TYPE_PLANE,
				_cross_platform_hash_helper(value.d),
				_cross_platform_hash_helper(value.normal),
				_cross_platform_hash_helper(value.x),
				_cross_platform_hash_helper(value.y),
				_cross_platform_hash_helper(value.z)
			]
		TYPE_QUAT:
			return [
				TYPE_QUAT,
				_cross_platform_hash_helper(value.w),
				_cross_platform_hash_helper(value.x),
				_cross_platform_hash_helper(value.y),
				_cross_platform_hash_helper(value.z)
			]
		TYPE_AABB:
			return [
				TYPE_AABB,
				_cross_platform_hash_helper(value.end),
				_cross_platform_hash_helper(value.point),
				_cross_platform_hash_helper(value.size)
			]
		TYPE_BASIS:
			return [
				TYPE_BASIS,
				_cross_platform_hash_helper(value.x),
				_cross_platform_hash_helper(value.y),
				_cross_platform_hash_helper(value.z)
			]
		TYPE_TRANSFORM:
			return [
				TYPE_TRANSFORM,
				_cross_platform_hash_helper(value.basis),
				_cross_platform_hash_helper(value.origin)
			]
		TYPE_COLOR:
			return [
				TYPE_COLOR,
				_cross_platform_hash_helper(value.r),
				_cross_platform_hash_helper(value.g),
				_cross_platform_hash_helper(value.b),
				_cross_platform_hash_helper(value.a)
			]
		TYPE_DICTIONARY:
			var dict = value.duplicate()
			for key in dict:
				dict[key] = _cross_platform_hash_helper(dict[key])
			return dict
		TYPE_ARRAY:
			var new_arr = []
			for subvalue in value:
				new_arr.append(_cross_platform_hash_helper(subvalue))
			return new_arr
		TYPE_REAL_ARRAY:
			var real_arr = [TYPE_REAL_ARRAY]
			for subvalue in value:
				real_arr.append(_cross_platform_hash_helper(subvalue))
			return real_arr
		TYPE_VECTOR2_ARRAY:
			var v2_arr = [TYPE_VECTOR2_ARRAY]
			for subvalue in value:
				v2_arr.append(_cross_platform_hash_helper(subvalue))
			return v2_arr
		TYPE_VECTOR3_ARRAY:
			var v3_arr = [TYPE_VECTOR3_ARRAY]
			for subvalue in value:
				v3_arr.append(_cross_platform_hash_helper(subvalue))
			return v3_arr
		TYPE_COLOR_ARRAY:
			var color_arr = [TYPE_COLOR_ARRAY]
			for subvalue in value:
				color_arr.append(_cross_platform_hash_helper(subvalue))
			return color_arr
		_:
			return value

# Run by a thread to import assets from the user://tmp directory into the
# user://assets directory.
func _import_new_assets(instructions: Array) -> void:
	if Global.tabletop_importer == null:
		push_warning("TabletopImporter does not exist, aborting import of new assets.")
		instructions.clear()
	
	for instruction in instructions:
		_transfer_mutex.lock()
		var keep_importing = _transfer_import_files
		_transfer_mutex.unlock()
		
		if not keep_importing:
			return
		
		var pack: String = instruction["pack"]
		var type: String = instruction["type"]
		var asset: String = instruction["asset"]
		
		var path_to = "user://assets/%s/%s/%s" % [pack, type, asset]
		var path_to_md5 = path_to.md5_text()
		var path_from = "user://tmp/%s.%s.bin" % [asset, path_to_md5]
		
		var dir = Directory.new()
		var base_dir = path_to.get_base_dir()
		if not dir.dir_exists(base_dir):
			var err = dir.make_dir_recursive(base_dir)
			if err != OK:
				push_error("Failed to create directory %s (error %d)" % [base_dir, err])
				_transfer_mutex.lock()
				_transfer_error_in_thread = true
				_transfer_mutex.unlock()
				continue
		
		var err = dir.rename(path_from, path_to)
		if err != OK:
			push_error("Failed to move %s to %s (error %d)" % [path_from, path_to, err])
			_transfer_mutex.lock()
			_transfer_error_in_thread = true
			_transfer_mutex.unlock()
			continue
		
		print("%s -> %s" % [path_from, path_to])
		
		# If there's a potential .md5 file in user://.import for this file, we
		# need to remove it so that the client can overwrite the file on the
		# next game launch.
		if dir.dir_exists("user://.import"):
			err = dir.open("user://.import")
			if err == OK:
				var to_remove = []
				dir.list_dir_begin(true, true)
				
				var file = dir.get_next()
				while file:
					if file.begins_with(asset) and file.get_extension() == "md5":
						to_remove.append(file)
					file = dir.get_next()
				
				dir.list_dir_end()
				
				for md5_file in to_remove:
					err = dir.remove("user://.import/" + md5_file)
					if err != OK:
						push_error("Failed to remove user://.import/%s (error %d)" % [md5_file, err])
			else:
				push_error("Failed to open user://.import (error %d)" % err)
		
		if AssetDB.EXTENSIONS_TO_IMPORT.has(path_to.get_extension()):
			Global.tabletop_importer.import(path_to)
		
		_progress_import_mutex.lock()
		_progress_import_current += 1
		_progress_import_file = asset
		_progress_import_mutex.unlock()
	
	_transfer_mutex.lock()
	_transfer_import_files = false
	_transfer_commands = ["done_importing"] # -> _process().
	_transfer_mutex.unlock()

# Check if some data only consists of data.
# Returns: If the value only contains data.
# data: The value to check.
# depth: The depth of recursion - if it reaches a certain point, it is not
# considered data.
func _is_only_data(data, depth: int = 0) -> bool:
	if depth > 2:
		return false
	
	match typeof(data):
		TYPE_NIL:
			pass
		TYPE_BOOL:
			pass
		TYPE_INT:
			pass
		TYPE_REAL:
			pass
		TYPE_STRING:
			pass
		TYPE_VECTOR2:
			pass
		TYPE_RECT2:
			pass
		TYPE_VECTOR3:
			pass
		TYPE_TRANSFORM2D:
			pass
		TYPE_PLANE:
			pass
		TYPE_QUAT:
			pass
		TYPE_AABB:
			pass
		TYPE_BASIS:
			pass
		TYPE_TRANSFORM:
			pass
		TYPE_COLOR:
			pass
		TYPE_DICTIONARY:
			for key in data:
				if not _is_only_data(key, depth+1):
					return false
				var value = data[key]
				if not _is_only_data(value, depth+1):
					return false
		TYPE_ARRAY:
			for element in data:
				if not _is_only_data(element, depth+1):
					return false
		_:
			return false
	
	return true

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

# Show the download assets error dialog with the given error.
# error: The error message to show.
func _popup_download_error(error: String) -> void:
	_download_assets_error_dialog.popup_centered()
	push_error(error)

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

# Saved downloaded chunks to a cache file in user://tmp.
func _save_chunks_to_cache(_userdata) -> void:
	_transfer_mutex.lock()
	var num_commands = _transfer_commands.size()
	var rpcs_remaining = _transfer_num_expected_rpcs
	_transfer_mutex.unlock()
	
	while num_commands > 0 or rpcs_remaining > 0:
		var cmd = {}
		_transfer_mutex.lock()
		if not _transfer_commands.empty():
			cmd = _transfer_commands.pop_front()
		_transfer_mutex.unlock()
		
		if not cmd.empty():
			var pack: String = cmd["pack"]
			var type: String = cmd["type"]
			var asset: String = cmd["asset"]
			var chunk: PoolByteArray = cmd["chunk"]
			
			var file_path_later = "user://assets/%s/%s/%s" % [pack, type, asset]
			var file_path_md5 = file_path_later.md5_text()
			var file_path_now = "user://tmp/%s.%s.bin" % [asset, file_path_md5]
			
			var tmp_dir = Directory.new()
			if not tmp_dir.dir_exists("user://tmp"):
				var err = tmp_dir.make_dir("user://tmp")
				if err != OK:
					push_error("Could not create user://tmp (error %d)" % err)
					_transfer_mutex.lock()
					_transfer_error_in_thread = true
					_transfer_mutex.unlock()
					continue
			
			var file = File.new()
			var mode = File.READ_WRITE
			if not file.file_exists(file_path_now):
				mode = File.WRITE
			var err = file.open(file_path_now, mode)
			if err != OK:
				push_error("Could not open file %s (error %d)" % [file_path_now, err])
				_transfer_mutex.lock()
				_transfer_error_in_thread = true
				_transfer_mutex.unlock()
				continue
			
			file.seek_end()
			file.store_buffer(chunk)
			file.close()
		else:
			OS.delay_msec(int(1000 * TRANSFER_CHUNK_DELAY))
		
		_transfer_mutex.lock()
		num_commands = _transfer_commands.size()
		rpcs_remaining = _transfer_num_expected_rpcs
		_transfer_mutex.unlock()

# Transfer files from the server to a given client.
# userdata: A dictionary, containing "client_id" (the client to send the files
# to), and "provide" (the directory of files to provide from user://assets).
func _transfer_asset_files(userdata: Dictionary) -> void:
	var client_id: int = userdata["client_id"]
	var data_channel: WebRTCDataChannel = userdata["data_channel"]
	var provide: Dictionary = userdata["provide"]
	
	for pack in provide:
		for type in provide[pack]:
			for asset in provide[pack][type]:
				var file = File.new()
				var file_path = "user://assets/%s/%s/%s" % [pack, type, asset]
				if file.open(file_path, File.READ) == OK:
					var file_size = file.get_len()
					var file_ptr = 0
					while file_ptr < file_size:
						if data_channel.get_ready_state() != WebRTCDataChannel.STATE_OPEN:
							return
						
						_transfer_mutex.lock()
						var client_wants_to_stop = _transfer_clients_stopping.has(client_id)
						_transfer_mutex.unlock()
						
						if client_wants_to_stop:
							return
						
						var bytes_left = file_size - file_ptr
						var buffer_size = min(bytes_left, TRANSFER_CHUNK_SIZE)
						var buffer = file.get_buffer(buffer_size)
						
						_transfer_mutex.lock()
						var num_commands = _transfer_commands.size()
						_transfer_mutex.unlock()
						
						while num_commands >= TRANSFER_MAX_COMMANDS:
							OS.delay_msec(int(1000 * TRANSFER_CHUNK_DELAY))
							
							_transfer_mutex.lock()
							num_commands = _transfer_commands.size()
							_transfer_mutex.unlock()
						
						_transfer_mutex.lock()
						_transfer_commands.push_back({
							"id": client_id,
							"pack": pack,
							"type": type,
							"asset": asset,
							"buffer": buffer
						})
						_transfer_mutex.unlock()
						
						file_ptr += TRANSFER_CHUNK_SIZE
					file.close()
				else:
					push_error("Failed to read file '%s'!" % file_path)
	
	_transfer_mutex.lock()
	_transfer_commands.push_back({
		"id": client_id,
		"done": true
	})
	_transfer_mutex.unlock()

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
	
	# If the room has been sealed (the host left gracefully), then the main menu
	# should already be loading. See: _on_room_sealed().
	if _is_room_sealed:
		return
	
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
	if get_tree().is_network_server():
		# Check that the client's game version matches our own - they'll
		# disconnect if that's not the case.
		if ProjectSettings.has_setting("application/config/version"):
			var version = ProjectSettings.get_setting("application/config/version")
			rpc_id(id, "verify_game_version", version)
		
		# If there is space, also give them a hand on the table.
		var hand_transform = _room.srv_get_next_hand_transform()
		if hand_transform != Transform.IDENTITY:
			_room.rpc("add_hand", id, hand_transform)
		
		_room.start_sending_cursor_position()
		
		if _srv_skip_sync:
			# Send the table state straight away.
			var compressed_state = _room.get_state_compressed(true, true)
			_room.rpc_id(id, "set_state_compressed", compressed_state, "")
		else:
			# Send them our asset schemas to see if they are missing any assets.
			rpc_id(id, "compare_server_schemas", _srv_schema_db, _srv_schema_fs)
			_srv_waiting_for.append(id)
			
			# Don't send the client state updates yet, wait until they've
			# confirmed that their AssetDB is synced with ours.
			if not id in Global.srv_state_update_blacklist:
				Global.srv_state_update_blacklist.append(id)
	
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
	# Do this as soon as possible, so a piece state update doesn't get through.
	if get_tree().is_network_server():
		Global.srv_state_update_blacklist.erase(id)
	
	if _rtc.has_peer(id):
		_rtc.remove_peer(id)
	
	if id in _established_connection_with:
		print("Peer %d has disconnected." % id)
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
	_is_room_sealed = true
	Global.start_main_menu_with_error(tr("Room has been closed by the host."))

func _on_DownloadAssetsConfirmDialog_confirmed():
	_cln_keep_expecting = true
	_download_assets_confirm_dialog.visible = false
	_cln_keep_expecting = false

func _on_DownloadAssetsConfirmDialog_popup_hide():
	if not _cln_keep_expecting:
		_cln_need_db.clear()
		_cln_need_fs.clear()
		_cln_expect_db.clear()
		_cln_expect_fs.clear()
		rpc_id(1, "respond_with_schema_results", {}, {})
		return
	
	var lock_file = File.new()
	if not _cln_need_fs.empty() and lock_file.file_exists("user://lock"):
		_download_lock_dialog.popup_centered()
	else:
		_on_DownloadLockDialog_confirmed()

func _on_DownloadAssetsProgressDialog_popup_hide():
	# Stop downloading/importing asset files from the host.
	if _cln_expect_fs.empty():
		return
	
	_cln_expect_fs.clear()
	_cln_need_fs.clear()
	
	# Same as we do when exiting the scene tree.
	_transfer_mutex.lock()
	_transfer_commands.clear()
	_transfer_import_files = false
	_transfer_num_expected_rpcs = 0
	_transfer_mutex.unlock()
	
	rpc_id(1, "stop_sending_asset_chunks")
	
	if _cln_expect_db.empty():
		_ui.reconfigure_asset_dialogs()
		rpc_id(1, "request_sync_state")

func _on_DownloadLockDialog_confirmed():
	rpc_id(1, "respond_with_schema_results", _cln_need_db, _cln_need_fs)
	
	_cln_need_db.clear()
	_cln_need_fs.clear()
	
	if not _cln_expect_fs.empty():
		_download_assets_progress_dialog.popup_centered()
		
		var lock_file = File.new()
		if lock_file.open("user://lock", File.WRITE) == OK:
			lock_file.close()
		else:
			push_error("Failed to create user://lock!")

func _on_Game_tree_exiting():
	stop()
	
	_transfer_mutex.lock()
	_transfer_commands.clear()
	_transfer_import_files = false
	_transfer_num_expected_rpcs = 0
	_transfer_mutex.unlock()
	
	# With the connection closed, and the commands cleared, the transfer
	# threads should end on their own.
	for thread in _srv_file_transfer_threads.values():
		if thread.is_active():
			thread.wait_to_finish()
	
	if _cln_save_chunk_thread != null:
		if _cln_save_chunk_thread.is_active():
			_cln_save_chunk_thread.wait_to_finish()
	_clear_download_cache()
	
	var lock = Directory.new()
	if lock.file_exists("user://lock"):
		if lock.remove("user://lock") != OK:
			push_error("Failed to remove user://lock!")

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

func _on_MissingAssetsDialog_popup_hide():
	if not _cln_keep_expecting:
		_cln_need_db.clear()
		_cln_need_fs.clear()
		_cln_expect_db.clear()
		_cln_expect_fs.clear()
		rpc_id(1, "respond_with_schema_results", {}, {})

func _on_MissingYesButton_pressed():
	_download_assets_confirm_dialog.popup_centered()
	_cln_keep_expecting = true
	_missing_assets_dialog.visible = false
	_cln_keep_expecting = false

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
