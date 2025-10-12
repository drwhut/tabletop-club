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

extends Node

signal censor_changed()

enum {
	MODE_NONE,
	MODE_ERROR,
	MODE_CLIENT,
	MODE_SERVER,
	MODE_SINGLEPLAYER
}

const LOADING_BLOCK_TIME = 20

# From the tabletop_club_godot_module:
# https://github.com/drwhut/tabletop_club_godot_module
var tabletop_importer = null
var error_reporter = null

var system_locale: String = ""

var censoring_profanity: bool = true setget set_censoring_profanity

# Throttle the piece state transmissions if there are many active physics
# objects.
const SRV_PIECE_UPDATE_TRANSMIT_LIMIT = 20
var srv_num_physics_frames_per_state_update: int = 1

# Do not send state updates to players if they are not ready.
var srv_state_update_blacklist: Array = []

var _current_scene: Node = null
var _loader: ResourceInteractiveLoader = null
var _loader_args: Dictionary = {}
var _wait_frames = 0

var _profanity_list: Array = []

# Given a string, return a new string with profanity hidden.
# Returns: A (hopefully) profanity-less string.
# string: The string to censor.
func censor_profanity(string: String) -> String:
	var lower_string = string.to_lower()
	
	# We are assuming the profanity list is in alphabetical order, and thus
	# prefixes will come first.
	for i in range(_profanity_list.size() - 1, -1, -1):
		var profanity = _profanity_list[i].to_lower()
		var j = 0
		while j >= 0:
			j = lower_string.find_last(profanity)
			if j >= 0:
				var censor = false
				if lower_string.length() == profanity.length():
					censor = true
				elif j == 0:
					# Most control and punctuation characters are below 65.
					if lower_string.ord_at(profanity.length()) < 65:
						censor = true
				elif j == lower_string.length() - profanity.length():
					if lower_string.ord_at(j - 1) < 65:
						censor = true
				else:
					if lower_string.ord_at(j - 1) < 65 and lower_string.ord_at(j + profanity.length()) < 65:
						censor = true
				
				if censor:
					string.erase(j, profanity.length())
					string = string.insert(j, "*".repeat(profanity.length()))
				lower_string = lower_string.substr(0, j)
	
	return string

# Get the directory of the given subfolder in the output folder. This should be
# in the user's documents folder, but if it isn't, the function will resort to
# the user:// folder instead.
# Returns: The directory of the subfolder in the output folder.
# subfolder: The subfolder to get the directory of.
func get_output_subdir(subfolder: String) -> Directory:
	var dir = Directory.new()
	
	if dir.open(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)) != OK:
		if dir.open("user://") != OK:
			push_error("Could not open the output directory!")
			return dir
	
	if not dir.dir_exists("TabletopClub"):
		if dir.make_dir("TabletopClub") != OK:
			push_error("Failed to create the output directory!")
			return dir
	
	if dir.change_dir("TabletopClub") != OK:
		push_error("Failed to change to the output directory!")
		return dir
	
	if not dir.dir_exists(subfolder):
		if dir.make_dir_recursive(subfolder) != OK:
			push_error("Failed to create the '%s' subfolder!" % subfolder)
			return dir
	
	if dir.change_dir(subfolder) != OK:
		push_error("Failed to change to the '%s' subfolder!" % subfolder)
		return dir
	
	return dir

# Rotate the volume of a bounding box to create a new bounding box.
func rotate_bounding_box(size: Vector3, basis: Basis) -> Vector3:
	var corner_0 = basis * size
	var corner_x = (corner_0 - 2 * size.x * basis.x).abs()
	var corner_y = (corner_0 - 2 * size.y * basis.y).abs()
	var corner_z = (corner_0 - 2 * size.z * basis.z).abs()
	corner_0 = corner_0.abs()
	
	var max_x = max(corner_0.x, corner_x.x)
	max_x = max(max_x, corner_y.x)
	max_x = max(max_x, corner_z.x)
	
	var max_y = max(corner_0.y, corner_x.y)
	max_y = max(max_y, corner_y.y)
	max_y = max(max_y, corner_z.y)
	
	var max_z = max(corner_0.z, corner_x.z)
	max_z = max(max_z, corner_y.z)
	max_z = max(max_z, corner_z.z)
	
	return Vector3(max_x, max_y, max_z)

# Set whether the game will censor profanity in player-generated text.
# censor: If the game will censor profanity.
func set_censoring_profanity(censor: bool) -> void:
	var emit_after = (censor != censoring_profanity)
	censoring_profanity = censor
	
	if emit_after:
		emit_signal("censor_changed")

# Start the game as a client.
# room_code: The room code to connect to.
func start_game_as_client(room_code: String) -> void:
	_goto_scene("res://Scenes/Game/Game.tscn", {
		"mode": MODE_CLIENT,
		"room_code": room_code
	})

# Start the game as a server.
func start_game_as_server() -> void:
	_goto_scene("res://Scenes/Game/Game.tscn", {
		"mode": MODE_SERVER
	})

# Start the game in singleplayer mode.
func start_game_singleplayer() -> void:
	_goto_scene("res://Scenes/Game/Game.tscn", {
		"mode": MODE_SINGLEPLAYER
	})

# Start the importing assets scene.
func start_importing_assets() -> void:
	call_deferred("_terminate_peer")
	_goto_scene("res://Scenes/ImportAssets.tscn", {
		"mode": MODE_NONE
	})

# Start the main menu.
func start_main_menu() -> void:
	call_deferred("_terminate_peer")
	_goto_scene("res://Scenes/MainMenu.tscn", {
		"mode": MODE_NONE
	})

# Start the main menu, and display an error message.
# error: The error message to display.
func start_main_menu_with_error(error: String) -> void:
	call_deferred("_terminate_peer")
	_goto_scene("res://Scenes/MainMenu.tscn", {
		"mode": MODE_ERROR,
		"error": error
	})

func _ready():
	var root = get_tree().get_root()
	_current_scene = root.get_child(root.get_child_count() - 1)
	
	set_process(false)
	
	# We're assuming the locale hasn't been modified yet.
	system_locale = TranslationServer.get_locale()
	
	# We may be running the game with vanilla Godot!
	if type_exists("TabletopImporter"):
		tabletop_importer = ClassDB.instance("TabletopImporter")
	if type_exists("ErrorReporter"):
		error_reporter = ClassDB.instance("ErrorReporter")
	
	_profanity_list = preload("res://Text/Profanity.tres").text.split("\n", false)

func _process(_delta):
	if _loader == null:
		set_process(false)
		return
	
	if _wait_frames > 0:
		_wait_frames -= 1
		return
	
	var time = OS.get_ticks_msec()
	while OS.get_ticks_msec() < time + LOADING_BLOCK_TIME:
		var err = _loader.poll()
		
		if err == ERR_FILE_EOF:
			var scene = _loader.get_resource()
			call_deferred("_set_scene", scene.instance(), _loader_args)
			
			_loader = null
			_loader_args = {}
			break
		elif err == OK:
			# The current scene should be the loading scene, so we should be
			# able to update the progress it is displaying.
			var progress = 0.0
			var stages = _loader.get_stage_count()
			if stages > 0:
				progress = float(_loader.get_stage()) / stages
			_current_scene.set_progress(progress)
		else:
			push_error("Loader encountered an error (error code %d)!" % err)
			_loader = null
			break

# Go to a given scene, with a set of arguments.
# path: The file path of the scene to load.
# args: The arguments for the scene to use after it has loaded.
func _goto_scene(path: String, args: Dictionary) -> void:
	# Are we already loading a scene?
	if _loader != null:
		return
	
	# Create the interactive loader for the new scene.
	_loader = ResourceLoader.load_interactive(path)
	if _loader == null:
		push_error("Failed to create loader for '%s'!" % path)
		return
	_loader_args = args
	
	# Load the loading scene so the player can see the progress in loading the
	# new scene.
	var loading_scene = preload("res://Scenes/Loading.tscn").instance()
	call_deferred("_set_scene", loading_scene, { "mode": MODE_NONE })
	
	set_process(true)
	_wait_frames = 1

# Immediately set the scene tree's current scene.
# NOTE: This function should be called via call_deferred, since it will free
# the existing scene.
# scene: The scene to load.
# args: The arguments for the scene to use after it has loaded.
func _set_scene(scene: Node, args: Dictionary) -> void:
	if not args.has("mode"):
		push_error("Scene argument 'mode' is missing!")
		return
	
	if not args["mode"] is int:
		push_error("Scene argument 'mode' is not an integer!")
		return
	
	match args["mode"]:
		MODE_NONE:
			pass
		
		MODE_ERROR:
			if not args.has("error"):
				push_error("Scene argument 'error' is missing!")
				return
			
			if not args["error"] is String:
				push_error("Scene argument 'error' is not a string!")
				return
		
		MODE_CLIENT:
			if not args.has("room_code"):
				push_error("Scene argument 'room_code' is missing!")
				return
			
			if not args["room_code"] is String:
				push_error("Scene argument 'room_code' is not a string!")
				return
		
		MODE_SERVER:
			pass
		
		MODE_SINGLEPLAYER:
			pass
		
		_:
			push_error("Invalid mode " + str(args["mode"]) + "!")
			return
	
	var root = get_tree().get_root()
	
	# Free the current scene - this should not be done during the main loop!
	root.remove_child(_current_scene)
	_current_scene.free()
	
	AssetDB.clear_temp_db()
	
	root.add_child(scene)
	get_tree().set_current_scene(scene)
	_current_scene = scene
	
	match args["mode"]:
		MODE_ERROR:
			_current_scene.display_error(args["error"])
		MODE_CLIENT:
			_current_scene.start_join(args["room_code"])
		MODE_SERVER:
			_current_scene.start_host()
		MODE_SINGLEPLAYER:
			_current_scene.start_singleplayer()
	
	srv_num_physics_frames_per_state_update = 1

# Terminate the network peer if it exists.
# NOTE: This function should be called via call_deferred.
func _terminate_peer() -> void:
	# TODO: Send a message to say we are leaving first.
	get_tree().network_peer = null
