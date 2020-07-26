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

const ASSET_DIR_PATHS = ["./assets", "../assets"]

const VALID_SCENE_EXTENSIONS = ["glb", "gltf"]

# List taken from:
# https://docs.godotengine.org/en/3.2/getting_started/workflow/assets/importing_images.html
const VALID_TEXTURE_EXTENSIONS = ["bmp", "dds", "exr", "hdr", "jpeg", "jpg",
	"png", "tga", "svg", "svgz", "webp"]

# NOTE: Pieces are stored similarly to the directory structures, but all piece
# types are direct children of the game, i.e. "OpenTabletop/dice/d6" in the
# game directory is _db["OpenTabletop"]["d6"] here.
var _db = {}

# From the open_tabletop_import_module:
# https://github.com/drwhut/open_tabletop_import_module
var _importer = TabletopImporter.new()

func get_db() -> Dictionary:
	return _db

func import_all() -> void:
	var dir = Directory.new()
	
	for asset_dir in ASSET_DIR_PATHS:
		if dir.open(asset_dir) == OK:
			dir.list_dir_begin(true, true)
			
			var entry = dir.get_next()
			while entry:
				
				if dir.current_is_dir():
					dir.change_dir(entry)
					import_game_dir(dir)
					dir.change_dir("..")
				
				entry = dir.get_next()

func import_game_dir(dir: Directory) -> void:
	var game = dir.get_current_dir().get_file()
	
	print("Importing ", game, " ...")
	
	_db[game] = {}
	
	if dir.dir_exists("dice"):
		dir.change_dir("dice")
		
		_import_dir_if_exists(dir, game, "d4", "res://Pieces/Dice/d4.tscn")
		_import_dir_if_exists(dir, game, "d6", "res://Pieces/Dice/d6.tscn")
		_import_dir_if_exists(dir, game, "d8", "res://Pieces/Dice/d8.tscn")
		
		dir.change_dir("..")
	
	_import_dir_if_exists(dir, game, "cards", "res://Pieces/Card.tscn")
	_import_dir_if_exists(dir, game, "chips", "res://Pieces/Chip.tscn")
	_import_dir_if_exists(dir, game, "pieces", "")

func _import_dir_if_exists(current_dir: Directory, game: String, type: String,
	scene: String) -> void:
	
	if current_dir.dir_exists(type):
		current_dir.change_dir(type)
		
		# If the configuration file exists for this directory, try and load it.
		var config_path = current_dir.get_current_dir() + "/" + type + ".cfg"
		var config = ConfigFile.new()
		var config_err = config.load(config_path)
		
		if config_err == OK:
			print("Loaded: " + config_path)
		elif config_err == ERR_FILE_NOT_FOUND:
			pass
		else:
			push_warning("Failed to load: " + config_path + " (error " + str(config_err) + ")")
		
		current_dir.list_dir_begin(true, true)
		
		var file = current_dir.get_next()
		while file:
			var file_path = current_dir.get_current_dir() + "/" + file
			var import_err = _import_asset(file_path, game, type, scene, config)
			
			if import_err:
				push_error("Failed to import: " + file_path + " (error " + str(import_err) + ")")
				
			file = current_dir.get_next()
		
		if scene:
			var stack_config_path = current_dir.get_current_dir() + "/stacks.cfg"
			var stack_config = ConfigFile.new()
			var stack_config_err = stack_config.load(stack_config_path)
			
			if stack_config_err == OK:
				_import_stack_config(stack_config, game, type, scene)
				print("Loaded: " + stack_config_path)
			elif stack_config_err == ERR_FILE_NOT_FOUND:
				pass
			else:
				push_warning("Failed to load: " + stack_config_path + " (error " + str(stack_config_err) + ")")
		
		current_dir.change_dir("..")

func _add_entry_to_db(game: String, type: String, entry: Dictionary) -> void:
	if not _db.has(game):
		_db[game] = {}
	
	if not _db[game].has(type):
		_db[game][type] = []
	
	_db[game][type].push_back(entry)
	
	print("Added: ", game, "/", type, "/", entry.name)

func _get_asset_dir(game: String, type: String) -> Directory:
	var dir = Directory.new()
	var dir_error = dir.open("user://")
	
	if dir_error == OK:
		var path = game + "/" + type
		dir.make_dir_recursive(path)
		dir.change_dir(path)
	else:
		push_error("Cannot open user:// directory! (error " + str(dir_error) + ")")
	
	return dir

func _get_file_config_value(config: ConfigFile, section: String, key: String, default):
	var next_section = section
	
	if section.length() == 0:
		return default
	
	var take_away = 1
	if section.ends_with("*"):
		take_away += 1
	
	var new_len = max(section.length() - take_away, 0)
	
	next_section = section.substr(0, new_len)
	if section != "*":
		next_section += "*"
	
	return config.get_value(section, key, _get_file_config_value(config, next_section, key, default))

func _get_file_without_ext(file_path: String) -> String:
	var file = file_path.get_file()
	return file.substr(0, file.length() - file.get_extension().length() - 1)

func _import_asset(from: String, game: String, type: String, scene: String,
	config: ConfigFile) -> int:
	
	var dir = _get_asset_dir(game, type)
	
	var to = dir.get_current_dir() + "/" + from.get_file()
	var import_err = _import_file(from, to)
	
	if not (import_err == OK or import_err == ERR_ALREADY_EXISTS):
		return import_err
	
	if VALID_SCENE_EXTENSIONS.has(to.get_extension()):
		var entry = {
			"name": _get_file_without_ext(to),
			"scale": _get_file_config_value(config, from.get_file(), "scale", Vector3(1, 1, 1)),
			"scene_path": to,
			"texture_path": null
		}
		_add_entry_to_db(game, type, entry)
	elif scene and VALID_TEXTURE_EXTENSIONS.has(to.get_extension()):
		var entry = {
			"name": _get_file_without_ext(to),
			"scale": _get_file_config_value(config, from.get_file(), "scale", Vector3(1, 1, 1)),
			"scene_path": scene,
			"texture_path": to
		}
		_add_entry_to_db(game, type, entry)
	
	return OK

func _import_file(from: String, to: String) -> int:
	var copy_err = _importer.copy_file(from, to)
	
	if copy_err:
		return copy_err
	
	if VALID_SCENE_EXTENSIONS.has(from.get_extension()):
		return _importer.import_scene(to)
	elif VALID_TEXTURE_EXTENSIONS.has(from.get_extension()):
		return _importer.import_texture(to)
	else:
		return OK

func _import_stack_config(stack_config: ConfigFile, game: String, type: String,
	scene: String) -> void:
	
	for stack_name in stack_config.get_sections():
		var items = stack_config.get_value(stack_name, "items")
		if items and items is Array:
			
			var texture_paths = []
			var scale = null
			for item in items:
			
				# We know everything but the scale of the piece at this point.
				# So, we need to scan through the DB to find the texture, then
				# see what the scale of that texture's piece is.
				if not scale:
					if _db.has(game):
						if _db[game].has(type) and _db[game][type] is Array:
							var piece_entry = null
							
							for piece in _db[game][type]:
								if piece.has("texture_path") and piece.texture_path is String:
									if piece.texture_path.ends_with(item):
										piece_entry = piece
										break
							
							if piece_entry and piece_entry.has("scale"):
								scale = piece_entry.scale
							else:
								push_error("Could not determine scale of " + item)
				
				# TODO: Check the file exists.
				var texture_path = "user://" + game + "/" + type + "/" + item
				texture_paths.push_back(texture_path)
			
			if scale:
				var stack_entry = {
					"name": stack_name,
					"scale": scale,
					"scene_path": scene,
					"texture_paths": texture_paths
				}
				_add_entry_to_db(game, "stacks", stack_entry)
			else:
				push_error("Could not determine scale of stack " + stack_name)
