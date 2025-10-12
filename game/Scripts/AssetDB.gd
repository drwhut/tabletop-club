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

signal completed(dir_found)
signal importing_file(file, files_imported, files_total)

enum {
	ASSET_AUDIO,
	ASSET_SCENE,
	ASSET_SKYBOX,
	ASSET_TABLE,
	ASSET_TEMPLATE,
	ASSET_TEXTURE
}

const ASSET_DIR_PREFIXES = [
	"{BASE_ASSET_DIR}",
	"{EXEC_DIR}/../Resources", # macOS workaround.
	"{DOWNLOADS}/TabletopClub",
	"{DOCUMENTS}/TabletopClub",
	"{DESKTOP}/TabletopClub"
]

const ASSET_PACK_SUBFOLDERS = {
	"boards": { "type": ASSET_SCENE, "scene": "" },
	"cards": { "type": ASSET_TEXTURE, "scene": "res://Pieces/Card.tscn" },
	"containers": { "type": ASSET_SCENE, "scene": "" },
	"dice/d4": { "type": ASSET_SCENE, "scene": "" },
	"dice/d6": { "type": ASSET_SCENE, "scene": "" },
	"dice/d8": { "type": ASSET_SCENE, "scene": "" },
	"dice/d10": { "type": ASSET_SCENE, "scene": "" },
	"dice/d12": { "type": ASSET_SCENE, "scene": "" },
	"dice/d20": { "type": ASSET_SCENE, "scene": "" },
	"games": { "type": ASSET_TABLE, "scene": "" },
	"music": { "type": ASSET_AUDIO, "scene": "" },
	"pieces": { "type": ASSET_SCENE, "scene": "" },
	"skyboxes": { "type": ASSET_SKYBOX, "scene": "" },
	"sounds": { "type": ASSET_AUDIO, "scene": "" },
	"speakers": { "type": ASSET_SCENE, "scene": "" },
	"tables": { "type": ASSET_SCENE, "scene": "" },
	"templates": { "type": ASSET_TEMPLATE, "scene": "" },
	"timers": { "type": ASSET_SCENE, "scene": "" },
	"tokens/cube": { "type": ASSET_TEXTURE, "scene": "res://Pieces/Tokens/Cube.tscn" },
	"tokens/cylinder": { "type": ASSET_TEXTURE, "scene": "res://Pieces/Tokens/Cylinder.tscn" }
}

const VALID_AUDIO_EXTENSIONS = ["mp3", "ogg", "wav"]
const VALID_SCENE_EXTENSIONS = ["dae", "glb", "gltf", "obj"]
const VALID_TABLE_EXTENSIONS = ["tc"]

# List taken from:
# https://docs.godotengine.org/en/3.2/getting_started/workflow/assets/importing_images.html
const VALID_TEXTURE_EXTENSIONS = ["bmp", "dds", "exr", "hdr", "jpeg", "jpg",
	"png", "tga", "svg", "svgz", "webp"]

# The list of extensions that require us to use the TabletopImporter.
const EXTENSIONS_TO_IMPORT = VALID_AUDIO_EXTENSIONS + VALID_SCENE_EXTENSIONS + VALID_TEXTURE_EXTENSIONS

const VALID_SUPPORT_EXTENSIONS = ["bin", "mtl", "txt"]
const VALID_EXTENSIONS = EXTENSIONS_TO_IMPORT + VALID_TABLE_EXTENSIONS + VALID_SUPPORT_EXTENSIONS

const SFX_AUDIO_STREAMS = {
	"generic": {
		"fast": preload("res://Sounds/Generic/GenericFastSounds.tres"),
		"slow": preload("res://Sounds/Generic/GenericSlowSounds.tres")
	},
	"glass": {
		"fast": preload("res://Sounds/Glass/GlassFastSounds.tres"),
		"slow": preload("res://Sounds/Glass/GlassSlowSounds.tres")
	},
	"glass_heavy": {
		"fast": preload("res://Sounds/GlassHeavy/GlassHeavyFastSounds.tres"),
		"slow": preload("res://Sounds/GlassHeavy/GlassHeavySlowSounds.tres")
	},
	"glass_light": {
		"fast": preload("res://Sounds/GlassLight/GlassLightFastSounds.tres"),
		"slow": preload("res://Sounds/GlassLight/GlassLightSlowSounds.tres")
	},
	"metal": {
		"fast": preload("res://Sounds/Metal/MetalFastSounds.tres"),
		"slow": preload("res://Sounds/Metal/MetalSlowSounds.tres")
	},
	"metal_heavy": {
		"fast": preload("res://Sounds/MetalHeavy/MetalHeavyFastSounds.tres"),
		"slow": preload("res://Sounds/MetalHeavy/MetalHeavySlowSounds.tres")
	},
	"metal_light": {
		"fast": preload("res://Sounds/MetalLight/MetalLightFastSounds.tres"),
		"slow": preload("res://Sounds/MetalLight/MetalLightSlowSounds.tres")
	},
	"soft": {
		"fast": preload("res://Sounds/Soft/SoftFastSounds.tres"),
		"slow": preload("res://Sounds/Soft/SoftSlowSounds.tres")
	},
	"soft_heavy": {
		"fast": preload("res://Sounds/SoftHeavy/SoftHeavyFastSounds.tres"),
		"slow": preload("res://Sounds/SoftHeavy/SoftHeavySlowSounds.tres")
	},
	"tin": {
		"fast": preload("res://Sounds/Tin/TinFastSounds.tres"),
		"slow": preload("res://Sounds/Tin/TinSlowSounds.tres")
	},
	"wood": {
		"fast": preload("res://Sounds/Wood/WoodFastSounds.tres"),
		"slow": preload("res://Sounds/Wood/WoodSlowSounds.tres")
	},
	"wood_heavy": {
		"fast": preload("res://Sounds/WoodHeavy/WoodHeavyFastSounds.tres"),
		"slow": preload("res://Sounds/WoodHeavy/WoodHeavySlowSounds.tres")
	},
	"wood_light": {
		"fast": preload("res://Sounds/WoodLight/WoodLightFastSounds.tres"),
		"slow": preload("res://Sounds/WoodLight/WoodLightSlowSounds.tres")
	}
}

# NOTE: All assets are stored in the database in a directory structure, where
# the first level is the pack name, and the second level is the type name (the
# subfolder within the asset pack). For example, an asset in the
# "TabletopClub/dice/d6" folder would be in _db["TabletopClub"]["dice/d6"].
var _db = {}
var _db_mutex = Mutex.new()

# A temporary copy of the AssetDB in the event that the host and client's assets
# differ from one another - in that event, the temporary database is used.
var _temp_db = {}

var _import_dir_found = false
var _import_file_path = ""
var _import_files_imported = 0
var _import_files_total = 0
var _import_mutex = Mutex.new()
var _import_send_signal = false
var _import_stop = false
var _import_thread = Thread.new()

var _import_err_dict: Dictionary = {}
var _import_err_source: String = ""
var _import_err_mutex = Mutex.new()

# Keep track of which locales we've translated to, so we don't re-parse them.
var _tr_locales = []

# Clear the AssetDB.
func clear_db() -> void:
	_db_mutex.lock()
	_db.clear()
	_db_mutex.unlock()

# Clear the temporary AssetDB, and stop it from being used.
func clear_temp_db() -> void:
	_temp_db.clear()

# Get the list of asset directory paths the game will scan.
# Returns: The list of asset directory paths.
func get_asset_paths() -> Array:
	var out = []
	var exec_dir = OS.get_executable_path().get_base_dir()
	var downloads_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var documents_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var desktop_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	if downloads_dir.empty():
		downloads_dir = "."
	if documents_dir.empty():
		documents_dir = "."
	if desktop_dir.empty():
		desktop_dir = "."
	
	var args = OS.get_cmdline_args()
	var base_asset_dir_index = -1
	for index in range(args.size()):
		if args[index] == "--base-asset-dir":
			base_asset_dir_index = index
			break
	
	var base_asset_dir: String = "."
	if base_asset_dir_index >= 0:
		if base_asset_dir_index < args.size() - 1:
			var dir_path: String = args[base_asset_dir_index + 1]
			
			var dir_test = Directory.new()
			if dir_test.dir_exists(dir_path):
				dir_path = dir_path.trim_suffix("/")
				dir_path = dir_path.trim_suffix("\\")
				base_asset_dir = dir_path
			else:
				push_error("Directory '%s' does not exist!" % dir_path)
		else:
			push_error("No path given for --base-asset-dir!")
	
	for prefix in ASSET_DIR_PREFIXES:
		var path = prefix + "/assets"
		path = path.replace("{BASE_ASSET_DIR}", base_asset_dir)
		path = path.replace("{EXEC_DIR}", exec_dir)
		path = path.replace("{DOWNLOADS}", downloads_dir)
		path = path.replace("{DOCUMENTS}", documents_dir)
		path = path.replace("{DESKTOP}", desktop_dir)
		out.append(path)
	return out

# Get the asset database.
# Returns: The asset database.
func get_db() -> Dictionary:
	if _temp_db.empty():
		return _db
	else:
		return _temp_db

# Get the dictionary of import errors and warnings.
# Returns: The errors and warnings generated while importing assets.
func get_error_dict() -> Dictionary:
	_import_err_mutex.lock()
	var dict = _import_err_dict.duplicate(true)
	_import_err_mutex.unlock()
	
	return dict

# Check if the import thread is currently running.
# Returns: If the import thread is running.
func is_importing() -> bool:
	return _import_thread.is_alive()

# Parse translation config files in the assets directory for the given locale.
# NOTE: This must be run AFTER the assets have been imported.
# locale: The locale to parse the config files for.
func parse_translations(locale: String) -> void:
	if locale in _tr_locales:
		return
	
	if _import_thread.is_active():
		_import_thread.wait_to_finish()
	
	if _db.empty():
		return
	
	_tr_locales.append(locale)
	
	var catalog = _catalog_assets()
	for pack_name in catalog["packs"]:
		var pack_catalog = catalog["packs"][pack_name]
		var pack_path = pack_catalog["path"]
		for type in pack_catalog["types"]:
			var cfg_path = pack_path + "/" + type + "/" + "config.%s.cfg" % locale
			var file = File.new()
			if file.file_exists(cfg_path):
				var cfg_file = ConfigFile.new()
				var err = cfg_file.load(cfg_path)
				if err == OK:
					print("Loading translations: %s" % cfg_path)
					_parse_tr_file(pack_name, type, cfg_file, locale)
				else:
					push_error("Could not load '%s'! (error: %d)" % [cfg_path, err])

# Get a random asset from a pack's type directory.
# Returns: A random asset from the given type directory, empty if there are no
# assets to select from.
# pack: The asset pack to search.
# type: The type directory to search.
# default: If true, only assets with the property "default" = true are
# considered.
func random_asset(pack: String, type: String, default: bool = false) -> Dictionary:
	if _db.has(pack):
		if _db[pack].has(type):
			var array: Array = _db[pack][type]
			if default:
				var filtered = []
				for entry in array:
					if entry.has("default"):
						if entry["default"] == true:
							filtered.append(entry)
				array = filtered
			
			if not array.empty():
				randomize()
				return array[randi() % array.size()]
	
	return {}

# Search a pack's type directory for an asset with the given name.
# Returns: The asset's entry in the DB if it exists, empty otherwise.
# pack: The asset pack to search.
# type: The type directory to search.
# asset: The name of the asset to query.
func search_type(pack: String, type: String, asset: String) -> Dictionary:
	var db = get_db() # We may use the temporary DB here!
	if db.has(pack):
		if db[pack].has(type):
			# The array of assets should be sorted by name, so we can use
			# binary search!
			var array: Array = db[pack][type]
			var index = array.bsearch_custom(asset, self, "_search_assets")
			if index < array.size():
				if array[index]["name"] == asset:
					return array[index]
	
	return {}

# Search for an asset in the DB with it's path.
# Returns: The asset's entry in the DB if it exists, empty otherwise.
# path: The path of the asset.
func search_path(path: String) -> Dictionary:
	var pack_split = path.split("/", false, 1)
	if pack_split.size() != 2:
		push_error("Invalid path format: %s" % path)
		return {}
	
	var pack = pack_split[0]
	var asset_split = pack_split[1].rsplit("/", false, 1)
	if asset_split.size() != 2:
		push_error("Invalid path format: %s" % path)
		return {}
	
	var type = asset_split[0]
	var asset = asset_split[1]
	return search_type(pack, type, asset)

# Start the importing thread.
func start_importing() -> void:
	if _import_thread.is_active():
		_import_thread.wait_to_finish()
	
	_import_err_mutex.lock()
	_import_err_dict.clear()
	_import_err_source = ""
	_import_err_mutex.unlock()
	
	_import_mutex.lock()
	_import_stop = false
	_import_mutex.unlock()
	
	_import_thread.start(self, "_import_all")
	
	_tr_locales = []

# Temporarily add an entry to the AssetDB.
# pack: The pack the entry belongs to.
# type: The type of entry.
# entry: The entry to add in the type's array.
func temp_add_entry(pack: String, type: String, entry: Dictionary) -> void:
	if not _is_valid_entry(pack, type, entry):
		push_error("Cannot add entry to AssetDB, entry is invalid!")
		return
	
	if _temp_db.empty():
		_temp_db = _db.duplicate(true)
	
	if not _temp_db.has(pack):
		_temp_db[pack] = {}
	
	if not _temp_db[pack].has(type):
		_temp_db[pack][type] = []
	
	# Insert the entry in the type list, making sure the names of each entry are
	# still in order.
	var type_arr: Array = _temp_db[pack][type]
	var insert_index = type_arr.bsearch_custom(entry, self, "_order_assets")
	
	if insert_index < type_arr.size():
		if type_arr[insert_index]["name"] == entry["name"]:
			# Overwrite entries with the same name.
			type_arr[insert_index] = entry
			return
	
	type_arr.insert(insert_index, entry)

# Temporarily remove an entry from the AssetDB.
# pack: The pack the entry belongs to.
# type: The type of entry.
# index: The index of the entry in the type's array.
func temp_remove_entry(pack: String, type: String, index: int) -> void:
	if _db.empty():
		push_error("Attempted to remove an entry from the AssetDB while it is empty!")
		return
	
	if _temp_db.empty():
		_temp_db = _db.duplicate(true)
	
	if not _temp_db.has(pack):
		push_error("Temporary AssetDB does not contain pack %s!" % pack)
		return
	
	if not _temp_db[pack].has(type):
		push_error("Temporary AssetDB does not contain type %s/%s!" % [pack, type])
		return
	
	var arr_size = _temp_db[pack][type].size()
	if index < 0 or index >= arr_size:
		push_error("Invalid index to temporary AssetDB (index = %d, size = %d)" % [index, arr_size])
		return
	
	_temp_db[pack][type].remove(index)

func _ready():
	connect("tree_exiting", self, "_on_exiting_tree")

func _process(_delta):
	_import_mutex.lock()
	if _import_send_signal:
		if _import_file_path.empty():
			emit_signal("completed", _import_dir_found)
		else:
			emit_signal("importing_file", _import_file_path,
				_import_files_imported, _import_files_total)
		_import_send_signal = false
	_import_mutex.unlock()

# Import assets from all directories.
# _userdata: Ignored, required for it to be run by a thread.
func _import_all(_userdata) -> void:
	var catalog = _catalog_assets()
	
	_send_importing_file_signal(tr("Cleaning old files..."), 0, 1)
	_remove_old_assets(catalog)
	
	var files_imported = 0
	for pack in catalog["packs"]:
		var pack_catalog = catalog["packs"][pack]
		var pack_path = pack_catalog["path"]
		
		for type in pack_catalog["types"]:
			var type_catalog = pack_catalog["types"][type]
			var type_path = pack_path + "/" + type
			
			_import_err_mutex.lock()
			_import_err_source = type_path
			_import_err_mutex.unlock()
			
			var config_file = ConfigFile.new()
			var new_config_md5 = ""
			
			if type_catalog["config_file"]:
				var config_file_path = type_path + "/config.cfg"
				var err = config_file.load(config_file_path)
				if err == OK:
					print("Loaded: %s" % config_file_path)
					var md5_check = File.new()
					new_config_md5 = md5_check.get_md5(config_file_path)
				else:
					_log_error("Failed to load '%s' (error %d)!" % [config_file_path, err])
			
			var old_config_md5 = "?" # if .md5 file does not exist, will differ from new.
			var old_config_md5_file = File.new()
			
			var md5_file_path = "user://assets/%s/%s/config.cfg.md5" % [pack, type]
			if old_config_md5_file.file_exists(md5_file_path):
				var err = old_config_md5_file.open(md5_file_path, File.READ)
				if err == OK:
					old_config_md5 = old_config_md5_file.get_line()
					old_config_md5_file.close()
				else:
					_log_error("Failed to load '%s' (error %d)!" % [md5_file_path, err])
			
			var config_changed = (new_config_md5 != old_config_md5)
			if config_changed:
				# The directory holding the .md5 file might not exist yet if
				# nothing has been imported!
				var md5_dir = Directory.new()
				var md5_dir_path = md5_file_path.get_base_dir()
				if not md5_dir.dir_exists(md5_dir_path):
					var err = md5_dir.make_dir_recursive(md5_dir_path)
					if err != OK:
						_log_error("Failed to create directory at '%s'!" % md5_dir_path)
				
				var err = old_config_md5_file.open(md5_file_path, File.WRITE)
				if err == OK:
					old_config_md5_file.store_line(new_config_md5)
					old_config_md5_file.close()
				else:
					_log_error("Failed to load '%s' (error %d)!" % [md5_file_path, err])
			
			for file in type_catalog["files"]:
				_import_mutex.lock()
				var stop_requested = _import_stop
				_import_mutex.unlock()
				
				if stop_requested:
					return
				
				var file_path = type_path + "/" + file
				_send_importing_file_signal(file_path, files_imported,
					catalog["file_count"])
				
				_import_err_mutex.lock()
				_import_err_source = file_path
				_import_err_mutex.unlock()
				
				var err = _import_asset(file_path, pack, type, config_file, config_changed)
				if err != OK:
					_log_error("Failed to import '%s' (error %d)!" % [file_path, err])
				
				files_imported += 1
			
			_import_err_mutex.lock()
			_import_err_source = type_path
			_import_err_mutex.unlock()
			
			_add_inheriting_assets(pack_path, pack, type)
			
			var type_meta = ASSET_PACK_SUBFOLDERS[type]
			var asset_scene = type_meta["scene"]
			
			var is_stackable = false
			if not asset_scene.empty():
				var piece = load(asset_scene).instance()
				is_stackable = piece is StackablePiece
				piece.free()
			
			if is_stackable and type_catalog["stacks_file"]:
				var stacks_file_path = type_path + "/stacks.cfg"
				var stacks_config = ConfigFile.new()
				var err = stacks_config.load(stacks_file_path)
				if err == OK:
					_import_stack_config(pack, type, stacks_config)
					print("Loaded: %s" % stacks_file_path)
				else:
					_log_error("Failed to load '%s' (error %d)!" % [stacks_file_path, err])
	
	_send_completed_signal(catalog["asset_dir_exists"])

# Add an asset entry to the database.
# pack: The name of the pack.
# type: The type of the asset.
# entry: The entry to add.
func _add_entry_to_db(pack: String, type: String, entry: Dictionary) -> void:
	var entry_path = "%s/%s/%s" % [pack, type, entry["name"]]
	entry["entry_path"] = entry_path
	
	if not _is_valid_entry(pack, type, entry):
		_log_error("Cannot add entry to AssetDB, entry is invalid!")
		return
	
	_db_mutex.lock()
	
	if not _db.has(pack):
		_db[pack] = {}
	
	if not _db[pack].has(type):
		_db[pack][type] = []
	
	var type_arr: Array = _db[pack][type]
	var index = type_arr.bsearch_custom(entry, self, "_order_assets")
	
	var is_duplicate = false
	if index < type_arr.size():
		if type_arr[index]["name"] == entry["name"]:
			is_duplicate = true
	
	if not is_duplicate:
		type_arr.insert(index, entry)
		print("Added: %s" % entry_path)
	else:
		_log_error("Cannot add %s/%s/%s to AssetDB, already exists!" % [pack, type, entry["name"]])
	
	_db_mutex.unlock()

# Add assets to the database that inherit properties frome existing assets.
# pack_path: The path to the asset pack.
# pack_name: The name of the asset pack in the AssetDB. NOTE: This may differ
# from the directory name!
# type: The type of the assets to add.
func _add_inheriting_assets(pack_path: String, pack_name: String, type: String) -> void:
	var type_path = pack_path + "/" + type
	var config_file_path = type_path + "/config.cfg"
	var config_file = ConfigFile.new()
	if config_file.load(config_file_path) != OK:
		return
	
	var children = []
	var file = File.new()
	for section in config_file.get_sections():
		if not "*" in section:
			if not file.file_exists(type_path + "/" + section):
				var parent = config_file.get_value(section, "parent", "")
				if not parent.empty():
					var inherit = search_type(pack_name, type, parent)
					if not inherit.empty():
						var child = inherit.duplicate()
						child["name"] = section
						child["entry_path"] = "%s/%s/%s" % [pack_name, type, section]
						for key in config_file.get_section_keys(section):
							if child.has(key):
								# TODO: Check the value is the same type.
								# TODO: Maybe separate the parsing of the
								# config files into it's own function, so we
								# can use it here?
								child[key] = config_file.get_value(section, key)
								
								# A particular edge-case where the colour stored
								# in the piece entry is of the Colour type, not
								# a string, which is expected in the config file.
								if key == "color":
									child[key] = Color(child[key])
									child[key].a = 1.0
								
								elif key == "face_values":
									for face_value in child[key]:
										var face_rot = child[key][face_value]
										child[key][face_value] = _precalculate_face_value_normal(face_rot)
						
						# We can't insert the new object into the DB now, since
						# the DB needs to be sorted for us to search it
						# efficiently, so we'll keep a list of them and add
						# them all after, then sort the DB again.
						children.append(child)
					else:
						_log_error("Parent '%s' for object '%s' does not exist!" % [parent, section])
				else:
					_log_error("Unknown object '%s' has no 'parent' key!" % section)
	
	if not children.empty():
		for child in children:
			_add_entry_to_db(pack_name, type, child)

# A class holding useful information about geometry.
class GeometryMetadata:
	var box_max: Vector3
	var box_min: Vector3
	
	var vertex_count: int = 0
	var vertex_sum: Vector3 = Vector3.ZERO

# Calculate the geometry metadata of a custom 3D scene.
# Returns: The geometry metadata for the scene.
# scene: The scene to calculate the metadata from.
func _calculate_geometry_metadata(scene: Spatial) -> GeometryMetadata:
	return _calculate_geometry_metadata_recursive(scene, Transform.IDENTITY)

# A helper function for calculating the geometry metadata of a 3D scene.
# Returns: The geometry metadata for the sub-scene.
# scene: The scene to calculate the metadata from.
# transform: The transform of the scene up to this point.
func _calculate_geometry_metadata_recursive(scene: Spatial,
	transform: Transform) -> GeometryMetadata:
	
	var new_basis     = scene.transform.basis * transform.basis
	var new_origin    = scene.transform.origin + transform.origin
	var new_transform = Transform(new_basis, new_origin)
	
	var metadata: GeometryMetadata = GeometryMetadata.new()
	var set_box = true
	
	if scene is MeshInstance:
		var mesh: Mesh = scene.mesh
		for surface in range(mesh.get_surface_count()):
			var vert_arr: Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			metadata.vertex_count += vert_arr.size()
			
			for vertex in vert_arr:
				var adj_vertex: Vector3 = new_transform * vertex
				metadata.vertex_sum += adj_vertex
				
				if set_box:
					metadata.box_max = adj_vertex
					metadata.box_min = adj_vertex
					set_box = false
				else:
					metadata.box_max.x = max(metadata.box_max.x, adj_vertex.x)
					metadata.box_max.y = max(metadata.box_max.y, adj_vertex.y)
					metadata.box_max.z = max(metadata.box_max.z, adj_vertex.z)
					
					metadata.box_min.x = min(metadata.box_min.x, adj_vertex.x)
					metadata.box_min.y = min(metadata.box_min.y, adj_vertex.y)
					metadata.box_min.z = min(metadata.box_min.z, adj_vertex.z)
	
	for child in scene.get_children():
		if child is Spatial:
			var child_meta = _calculate_geometry_metadata_recursive(child, new_transform)
			if child_meta.vertex_count <= 0:
				continue
			
			metadata.vertex_count += child_meta.vertex_count
			metadata.vertex_sum += child_meta.vertex_sum
			
			if set_box:
				metadata.box_max = child_meta.box_max
				metadata.box_min = child_meta.box_min
				set_box = false
			else:
				metadata.box_max.x = max(metadata.box_max.x, child_meta.box_max.x)
				metadata.box_max.y = max(metadata.box_max.y, child_meta.box_max.y)
				metadata.box_max.z = max(metadata.box_max.z, child_meta.box_max.z)
				
				metadata.box_min.x = min(metadata.box_min.x, child_meta.box_min.x)
				metadata.box_min.y = min(metadata.box_min.y, child_meta.box_min.y)
				metadata.box_min.z = min(metadata.box_min.z, child_meta.box_min.z)
	
	return metadata

# Catalog all the assets from every asset directory.
# Returns: A catalog of all asset files.
func _catalog_assets() -> Dictionary:
	var dir = Directory.new()
	
	var scanned_asset_dirs = []
	var asset_dir_exists = false
	var file_count = 0
	var packs = {}
	for asset_dir in get_asset_paths():
		var err = dir.open(asset_dir)
		if err == OK:
			asset_dir_exists = true
			
			# Don't scan the same asset directory twice!
			if dir.get_current_dir() in scanned_asset_dirs:
				continue
			
			dir.list_dir_begin(true, true)
			
			var folder = dir.get_next()
			while folder:
				if dir.current_is_dir():
					var pack_path = dir.get_current_dir() + "/" + folder
					
					_import_err_mutex.lock()
					_import_err_source = pack_path
					_import_err_mutex.unlock()
					
					var pack_dir = Directory.new()
					err = pack_dir.open(pack_path)
					if err == OK:
						var pack_catalog = _catalog_pack_dir(pack_dir)
						var pack_name = folder
						
						if packs.has(pack_name):
							var new_pack = pack_name
							var i = 1
							while packs.has(new_pack):
								new_pack = "%s (%d)" % [pack_name, i]
								i += 1
							print("Pack %s already exists, renaming to %s." % [pack_name, new_pack])
							pack_name = new_pack
						
						packs[pack_name] = pack_catalog
						file_count += pack_catalog["file_count"]
					else:
						_log_error("Failed to open '%s' (error %d)!" % [pack_path, err])
				
				folder = dir.get_next()
			
			scanned_asset_dirs.append(dir.get_current_dir())
		elif err == ERR_INVALID_PARAMETER:
			# The folder doesn't exist.
			pass
		else:
			_log_error("Failed to open '%s' (error %d)!" % [asset_dir, err])
	
	return {
		"asset_dir_exists": asset_dir_exists,
		"packs": packs,
		"file_count": file_count
	}

# Catalog the assets in a pack directory.
# Returns: A catalog of the pack directory.
# pack_dir: The pack directory to catalog.
func _catalog_pack_dir(pack_dir: Directory) -> Dictionary:
	print("Scanning pack '%s'..." % pack_dir.get_current_dir())
	
	var file_count = 0
	var types = {}
	for type in ASSET_PACK_SUBFOLDERS:
		if pack_dir.dir_exists(type):
			var type_dir = Directory.new()
			var type_path = pack_dir.get_current_dir() + "/" + type
			var err = type_dir.open(type_path)
			if err == OK:
				var type_catalog = _catalog_type_dir(type_dir)
				types[type] = type_catalog
				file_count += type_catalog["file_count"]
			else:
				_log_error("Failed to open '%s' (error %d)!" % [type_path, err])
	
	return {
		"path": pack_dir.get_current_dir(),
		"types": types,
		"file_count": file_count
	}

# Catalog the assets in a type directory.
# Returns: A catalog of the type directory.
# type_dir: The type directory to catalog.
func _catalog_type_dir(type_dir: Directory) -> Dictionary:
	print("Scanning subfolder '%s'..." % type_dir.get_current_dir())
	var config_file = type_dir.file_exists("config.cfg")
	var stacks_file = type_dir.file_exists("stacks.cfg")
	
	var files = []
	type_dir.list_dir_begin(true, true)
	
	var file = type_dir.get_next()
	while file:
		if not (file == "config.cfg" or file == "stacks.cfg"):
			if VALID_EXTENSIONS.has(file.get_extension()):
				# Make sure that scenes are imported last, since they can
				# depend on other files like textures and binary files.
				if VALID_SCENE_EXTENSIONS.has(file.get_extension()):
					files.push_back(file)
				else:
					files.push_front(file)
		
		file = type_dir.get_next()
	
	return {
		"config_file": config_file,
		"stacks_file": stacks_file,
		"files": files,
		"file_count": files.size()
	}

# Get the directory of a pack's type in the user://assets directory.
# Returns: The directory as a Directory object.
# pack: The name of the pack.
# type_dir: The relative path from the pack directory.
func _get_asset_dir(pack: String, type_dir: String) -> Directory:
	var dir = Directory.new()
	var dir_error = dir.open("user://")
	
	if dir_error == OK:
		var path = "assets/" + pack + "/" + type_dir
		dir.make_dir_recursive(path)
		dir.change_dir(path)
	else:
		print("Cannot open user:// directory (error ", dir_error, ")")
	
	return dir

# Custom sorter class for _get_file_config_value
# Sorts by string length. Largest to smallest
class AssetDBSorter:
	static func sort_length(a: String, b: String):
		if a.length() > b.length():
			return true
		return false

# Get an asset's config value. It will search the config file with wildcards.
# Wildcards can be at the beginning and/or end.
# E.g.: *Card.png, Card*, *Card*
# Returns: The config value. If it doesn't exist, returns default.
# config: The config file to query.
# query: The section to query (this is the value that is wildcarded).
# key: The key to query.
# default: The default value to return if the value doesn't exist.
# force_type: Only return the value if it is the same type as default. An error
# is thrown if the types differ, and default is returned instead.
func _get_file_config_value(config: ConfigFile, query: String, key: String,
	default, force_type: bool = true):
	
	var found_sections = ["*"]
	
	for section in config.get_sections():
		if section == "*": continue
		
		var wildcard_at_front = section.begins_with("*")
		var wildcard_at_end = section.ends_with("*")
		var search_term = section.replace("*","")
		if ((search_term == query) \
			or (wildcard_at_front and query.ends_with(search_term)) \
			or (wildcard_at_end and query.begins_with(search_term)) \
			or (wildcard_at_front and wildcard_at_end and search_term in query)):
				found_sections.append(section)
	
	found_sections.sort_custom(AssetDBSorter, "sort_length")
	
	var value = default
	for section in found_sections:
		if config.has_section_key(section, key):
			value = config.get_value(section, key, default)
			break
	
	if not force_type:
		return value
	
	var type_value = typeof(value)
	var type_default = typeof(default)
	
	if type_value == type_default:
		return value
	elif type_value == TYPE_INT and type_default == TYPE_REAL:
		return float(value)
	else:
		_log_error("Value of key %s for %s is incorrect type! (expected %d, got %d)" % [
				key, query, type_default, type_value])
		return default

# Import an asset. If it has already been imported before, and it's contents
# have not changed, it is not reimported, but the piece entry is still added to
# the database.
# Returns: An error.
# from: The file path of the asset.
# pack: The name of the pack to import the asset to.
# type: The relative file path from the pack directory.
# config: The configuration file for the asset's directory.
# config_changed: If true, the contents of the configuration file have changed
# since the last import. This may impact cached files.
func _import_asset(from: String, pack: String, type: String, config: ConfigFile,
	config_changed: bool) -> int:
	
	var ignore: bool = _get_file_config_value(config, from.get_file(), "ignore",
			false)
	
	if ignore:
		return OK
	
	var dir = _get_asset_dir(pack, type)
	var to = dir.get_current_dir() + "/" + from.get_file()
	var import_err = _import_file(from, to)
	if not (import_err == OK or import_err == ERR_ALREADY_EXISTS):
		return import_err
	
	var type_meta = ASSET_PACK_SUBFOLDERS[type]
	var asset_scene = type_meta["scene"]
	var asset_type = type_meta["type"]
	
	# We usually deal with the config values at the end, but some assets need
	# these values for the entry initialization.
	var scale: Vector3
	if type == "cards":
		var scale_config = _get_file_config_value(config, from.get_file(),
				"scale", Vector2.ONE, false)
		if typeof(scale_config) == TYPE_VECTOR2:
			scale = Vector3(scale_config.x, 1.0, scale_config.y)
		elif typeof(scale_config) == TYPE_VECTOR3:
			_log_warning("Scale for cards must be Vector2! Default height will be used instead.")
			scale = scale_config
			scale.y = 1.0
		else:
			_log_error("Scale for cards must be Vector2!")
			scale = Vector3.ONE
	else:
		scale = _get_file_config_value(config, from.get_file(), "scale",
				Vector3.ONE, true)
	
	var entry = {}
	if asset_type == ASSET_AUDIO:
		if VALID_AUDIO_EXTENSIONS.has(to.get_extension()):
			entry = { "audio_path": to }
	elif asset_type == ASSET_SCENE:
		if VALID_SCENE_EXTENSIONS.has(to.get_extension()):
			# Determines the kind of collision shape that is made.
			var collision_mode: int = _get_file_config_value(config,
					from.get_file(), "collision_mode",
					PieceBuilder.COLLISION_CONVEX)
			
			if collision_mode < PieceBuilder.COLLISION_CONVEX or collision_mode > PieceBuilder.COLLISION_CONCAVE:
				_log_error("Collision mode is invalid!")
				collision_mode = PieceBuilder.COLLISION_CONVEX
			
			if type == "tables" and collision_mode == PieceBuilder.COLLISION_CONCAVE:
				_log_error("Tables do not support the concave collision mode!")
				collision_mode = PieceBuilder.COLLISION_CONVEX
			
			# Determines the way in which the centre-of-mass is adjusted.
			var com_adjust_str: String = _get_file_config_value(config,
					from.get_file(), "com_adjust", "volume")
			var com_adjust: int = PieceBuilder.COM_ADJUST_VOLUME
			
			match com_adjust_str:
				"off":
					com_adjust = PieceBuilder.COM_ADJUST_OFF
				"volume":
					com_adjust = PieceBuilder.COM_ADJUST_VOLUME
				"geometry":
					com_adjust = PieceBuilder.COM_ADJUST_GEOMETRY
				_:
					_log_error("Value '%s' is invalid for property 'com_adjust'!" % com_adjust_str)
			
			# If the file has been imported before, check that the custom scene
			# has a cached geometry data file (.geo), so we do not have to go
			# and calculate the metadata again.
			var geo_file_path = to + ".box"
			var geo_file = File.new()
			var file_was_read = false
			
			var avg_point: Vector3        = Vector3.ZERO
			var bounding_box_min: Vector3 = Vector3.ZERO
			var bounding_box_max: Vector3 = Vector3.ZERO
			
			if import_err == ERR_ALREADY_EXISTS and geo_file.file_exists(geo_file_path):
				var err = geo_file.open(geo_file_path, File.READ)
				if err == OK:
					var data: Array = geo_file.get_var()
					geo_file.close()
					
					if data.size() == 3:
						avg_point = data[0]
						bounding_box_min = data[1]
						bounding_box_max = data[2]
						
						file_was_read = true
					else:
						_log_error("Geometry data in '%s' is not length 3!" % geo_file_path)
				else:
					_log_error("Failed to open '%s'! (error: %d)" % [geo_file_path, err])
			
			if not file_was_read:
				var custom_scene = load(to).instance()
				var geo_data = _calculate_geometry_metadata(custom_scene)
				custom_scene.free()
				
				bounding_box_max = geo_data.box_max
				bounding_box_min = geo_data.box_min
				avg_point = (1.0 / geo_data.vertex_count) * geo_data.vertex_sum
				
				var err = geo_file.open(geo_file_path, File.WRITE)
				if err == OK:
					geo_file.store_var([ avg_point, bounding_box_min,
						bounding_box_max ])
					geo_file.close()
				else:
					_log_error("Failed to open '%s'! (error: %d)" % [geo_file_path, err])
			
			# For convenience, we'll scale the geometry data here by the scale
			# value so we don't need to do it every time we use the data.
			avg_point *= scale
			bounding_box_min *= scale
			bounding_box_max *= scale
			
			entry = {
				"avg_point": avg_point,
				"bounding_box": [ bounding_box_min, bounding_box_max ],
				"collision_mode": collision_mode,
				"com_adjust": com_adjust,
				"scene_path": to,
				"texture_path": null
			}
	elif asset_type == ASSET_SKYBOX:
		if VALID_TEXTURE_EXTENSIONS.has(to.get_extension()):
			entry = { "texture_path": to }
	elif asset_type == ASSET_TABLE:
		if VALID_TABLE_EXTENSIONS.has(to.get_extension()):
			entry = { "table_path": to }
	elif asset_type == ASSET_TEMPLATE:
		var extension = to.get_extension()
		if extension == "txt" or VALID_TEXTURE_EXTENSIONS.has(extension):
			entry = { "template_path": to }
	elif asset_type == ASSET_TEXTURE:
		if asset_scene and VALID_TEXTURE_EXTENSIONS.has(to.get_extension()):
			entry = { "scene_path": asset_scene, "texture_path": to }
	
	# The file is the wrong file type for this type of asset.
	if entry.empty():
		return OK
	
	entry["name"] = _get_file_config_value(config, from.get_file(), "name",
		to.get_basename().get_file())
	entry["desc"] = _get_file_config_value(config, from.get_file(), "desc", "")
	
	entry["author"] = _get_file_config_value(config, from.get_file(), "author", "")
	entry["license"] = _get_file_config_value(config, from.get_file(), "license", "")
	entry["modified_by"] = _get_file_config_value(config, from.get_file(), "modified_by", "")
	entry["url"] = _get_file_config_value(config, from.get_file(), "url", "")
	
	if type == "games":
		# If there is a picture that goes with the save file, use it, as it
		# should also be imported.
		var check_file = File.new()
		for ext in VALID_TEXTURE_EXTENSIONS:
			var from_image_path = from.get_basename() + "." + ext
			if check_file.file_exists(from_image_path):
				var to_image_path = to.get_base_dir() + "/" + from_image_path.get_file()
				entry["texture_path"] = to_image_path
				break
	elif type == "music":
		entry["main_menu"] = _get_file_config_value(config, from.get_file(),
				"main_menu", false)
	elif type == "skyboxes":
		var default: bool = _get_file_config_value(config, from.get_file(),
				"default", false)
		var rotation: Vector3 = _get_file_config_value(config, from.get_file(),
				"rotation", Vector3.ZERO)
		var strength: float = _get_file_config_value(config, from.get_file(),
				"strength", 1.0)
		
		if strength < 0.0:
			_log_error("Skybox ambient light strength cannot be negative!")
			strength = 1.0
		
		entry["default"] = default
		entry["rotation"] = rotation
		entry["strength"] = strength
	elif type == "sounds":
		pass
	elif type == "tables":
		# These values don't mean anything, but they are needed if we want to
		# display the table like an object in an object preview.
		entry["color"] = Color.white
		entry["mass"] = 1.0
		entry["scale"] = Vector3.ONE
		
		var bounce: float = _get_file_config_value(config, from.get_file(),
				"bounce", 0.5)
		
		if bounce < 0.0 or bounce > 1.0:
			_log_error("Table bounce value must be between 0.0 and 1.0!")
			bounce = 0.5
		
		var default: bool = _get_file_config_value(config, from.get_file(),
				"default", false)
		var hands: Array = _get_file_config_value(config, from.get_file(),
				"hands", [])
		
		if hands.empty():
			_log_warning("No hand positions have been configured!")
		else:
			for hand in hands:
				if hand is Dictionary:
					if hand.has("pos"):
						if not hand["pos"] is Vector3:
							_log_error("'pos' key in hand position is not a Vector3!")
					else:
						_log_error("Hand position missing 'pos' key!")
						
					if hand.has("dir"):
						if not (hand["dir"] is float or hand["dir"] is int):
							_log_error("'dir' key in hand position is not a number!")
					else:
						_log_error("Hand position missing 'dir' key!")
				else:
					_log_error("Hand position is not a dictionary!")
		
		var paint_plane: Vector2 = _get_file_config_value(config, from.get_file(),
				"paint_plane", 100.0 * Vector2.ONE)
		
		if paint_plane.x <= 0.0 or paint_plane.y <= 0.0:
			_log_error("Paint plane size must be positive!")
			paint_plane = 100.0 * Vector2.ONE
		
		entry["bounce"] = bounce
		entry["default"] = default
		entry["hands"] = hands
		entry["paint_plane"] = paint_plane
	elif type == "templates":
		# To avoid redundancy, we rely on _is_valid_entry to check the textbox
		# dictionary for us.
		var textbox_dict: Dictionary = _get_file_config_value(config,
				from.get_file(), "textboxes", {})
		
		for textbox_id in textbox_dict:
			var entry_dict = textbox_dict[textbox_id]
			if entry_dict is Dictionary:
				if not entry_dict.has("x"):
					entry_dict["x"] = 0
				if not entry_dict.has("y"):
					entry_dict["y"] = 0
				if not entry_dict.has("w"):
					entry_dict["w"] = 300
				if not entry_dict.has("h"):
					entry_dict["h"] = 60
				if not entry_dict.has("rot"):
					entry_dict["rot"] = 0.0
				if not entry_dict.has("text"):
					entry_dict["text"] = ""
				if not entry_dict.has("lines"):
					entry_dict["lines"] = 1
		
		entry["textboxes"] = textbox_dict
	else: # Objects.
		var color_str: String = _get_file_config_value(config, from.get_file(),
				"color", "#ffffff")
		
		var color = Color(color_str)
		color.a = 1.0
		
		# Converting from g -> kg -> (Ns^2/cm, since game units are in cm) = x10.
		var mass: float = 10.0 * _get_file_config_value(config, from.get_file(),
				"mass", 1.0)
		
		if mass < 0.0:
			_log_error("Mass cannot be negative!")
			mass = 10.0
		
		var sfx: String = _get_file_config_value(config, from.get_file(), "sfx", "")
		if not sfx.empty():
			if not sfx in SFX_AUDIO_STREAMS:
				_log_error("SFX value does not match any existing preset!")
				sfx = ""
		if sfx.empty():
			# Certain pieces already have their own sound effects - don't
			# replace those.
			if not (type == "cards" or type.begins_with("dice") or type.begins_with("tokens")):
				sfx = "generic"
		
		entry["color"] = color
		entry["mass"] = mass
		entry["scale"] = scale
		entry["sfx"] = sfx
		
		entry["main_menu"] = _get_file_config_value(config, from.get_file(),
				"main_menu", false)
		
		if type == "cards":
			var back_path: String = _get_file_config_value(config,
					from.get_file(), "back_face", "")
			
			if not back_path.empty():
				if "/" in back_path or "\\" in back_path:
					_log_error("'%s' is invalid - back_face cannot point to another folder!" % back_path)
				else:
					back_path = from.get_base_dir() + "/" + back_path
					var back_to = dir.get_current_dir() + "/" + back_path.get_file()
					var back_err = _import_file(back_path, back_to)
					
					if back_err == OK or back_err == ERR_ALREADY_EXISTS:
						entry["texture_path_1"] = back_to
						print("Loaded back face: %s" % back_path)
					else:
						_log_error("Failed to import '%s' (error %d)!" % [back_path, back_err])
			else:
				entry["texture_path_1"] = ""
		
		elif type.begins_with("containers"):
			entry["shakable"] = _get_file_config_value(config, from.get_file(),
					"shakable", false)
		
		elif type.begins_with("dice"):
			var num_faces = 0
			
			if type.ends_with("d4"):
				num_faces = 4
			elif type.ends_with("d6"):
				num_faces = 6
			elif type.ends_with("d8"):
				num_faces = 8
			elif type.ends_with("d10"):
				num_faces = 10
			elif type.ends_with("d12"):
				num_faces = 12
			elif type.ends_with("d20"):
				num_faces = 20
			
			var face_values: Dictionary = _get_file_config_value(config,
					from.get_file(), "face_values", {})
			
			# Maps values (strings) to Arrays of Vector3 (normals).
			# Arrays will never be empty.
			var face_values_entry := {}

			# Total normals to check against faces
			var num_normals := 0

			if not face_values.empty():
				for key in face_values:
					var value = face_values[key]
					# Figure out 0.2.0 A:V versus 0.1.x V:A
					var fv_angle: Vector2
					var fv_value: String
					if key is Vector2:
						# key is known so don't check it
						if not ((value == null) or value is int or value is float or value is String):
							# this is more about 0.2.0 compat (the data is stringified anyway)
							_log_error("New-style value in face_values entry is not a number, string, or null! (%s)" % str(key))
							return ERR_INVALID_DATA
						fv_angle = key
						fv_value = str(value)
					else:
						if not (key is int or key is float):
							_log_error("Old-style key in face_values entry is not a number! (%s)" % str(key))
							return ERR_INVALID_DATA
						if not value is Vector2:
							_log_error("Old-style value in face_values entry is not a Vector2! (%s)" % str(value))
							return ERR_INVALID_DATA
						fv_value = str(key)
						fv_angle = value
					
					if not fv_value in face_values_entry:
						face_values_entry[fv_value] = []
					face_values_entry[fv_value].append(_precalculate_face_value_normal(fv_angle))
					num_normals += 1
			
			entry["face_values"] = face_values_entry
			
			if num_normals != num_faces:
				_log_warning("face_values describes less normals (%d) than the dice should have faces (%d)" % [num_normals, num_faces])
		
		if type == "cards" or type.begins_with("tokens"):
			# If we use null as a default value, ConfigFile will throw an error
			# if there is no value there, so use something else temporarily
			# to represent "nothing".
			var value = _get_file_config_value(config, from.get_file(), "value",
					Reference.new(), false)
			var suit  = _get_file_config_value(config, from.get_file(), "suit",
					Reference.new(), false)
			
			if value is Reference:
				value = null
			elif not (value is int or value is float or value is String):
					_log_error("Value must be a number or a string!")
					return ERR_INVALID_DATA
			
			if suit is Reference:
				suit = null
			elif not (suit is int or suit is float or suit is String):
					_log_error("Suit must be a number or a string!")
					return ERR_INVALID_DATA
			
			entry["value"] = value
			entry["suit"] = suit
	
	_add_entry_to_db(pack, type, entry)
	
	var change_detected = (import_err != ERR_ALREADY_EXISTS or config_changed)
	if PieceCache.should_cache(entry):
		# Should have been added by _add_entry_to_db.
		var entry_path: String = entry["entry_path"]
		
		var piece_cache = PieceCache.new(entry_path, false)
		if change_detected or (not piece_cache.exists()):
			piece_cache.cache()
		
		var thumbnail_cache = PieceCache.new(entry_path, true)
		if change_detected or (not thumbnail_cache.exists()):
			thumbnail_cache.cache()
	
	return OK

# Import a generic file.
# Returns: An Error.
# from: The file path of the file to import.
# to: The path of where to copy the file to.
func _import_file(from: String, to: String) -> int:
	if Global.tabletop_importer == null:
		return ERR_UNAVAILABLE
	
	# Two unique files with the same name could end up in the same location
	# (if the pack name is the same), so keep track of where the imported file
	# came from - if it doesn't match, forcefully re-import the new file.
	var force_copy = true
	var src_file = File.new()
	if src_file.file_exists(to + ".src"):
		var err = src_file.open(to + ".src", File.READ)
		if err == OK:
			var src = src_file.get_line()
			src_file.close()
			
			if src == from:
				force_copy = false
		else:
			_log_error("Failed to open %s (error %d)" % [to + ".src", err])
	
	var copy_err = Global.tabletop_importer.copy_file(from, to, force_copy)
	
	if copy_err:
		return copy_err
	else:
		if force_copy:
			var err = src_file.open(to + ".src", File.WRITE)
			if err == OK:
				src_file.store_line(from)
				src_file.close()
			else:
				_log_error("Failed to open %s (error %d)" % [to + ".src", err])
		
		# With Wavefront files, there's an annoying thing where it will only
		# look for the material file relative to the current working directory.
		# So, after we've copied it (the hash file should have been generated),
		# we'll edit the .obj file such that the path to the .mtl file is
		# an absolute path.
		if to.get_extension() == "obj":
			var obj_file = File.new()
			var open_err = obj_file.open(to, File.READ)
			if open_err == OK:
				var obj_contents = obj_file.get_as_text()
				obj_file.close()
				
				obj_contents = obj_contents.replace("mtllib ", "mtllib " + to.get_base_dir() + "/")
				
				open_err = obj_file.open(to, File.WRITE)
				if open_err == OK:
					obj_file.store_string(obj_contents)
					obj_file.close()
				else:
					_log_error("Could not write to file at '%s'." % to)
			else:
				_log_error("Could not read file at '%s'." % to)
		
		# With .mtl material files, the "Ka" property gives a warning in Godot,
		# saying that ambient light is ignored in PBR - so we'll comment out the
		# property in the file.
		elif to.get_extension() == "mtl":
			var mtl_file = File.new()
			var open_err = mtl_file.open(to, File.READ)
			if open_err == OK:
				var mtl_contents = mtl_file.get_as_text()
				mtl_file.close()
				
				mtl_contents = mtl_contents.replace("Ka ", "#Ka ")
				
				open_err = mtl_file.open(to, File.WRITE)
				if open_err == OK:
					mtl_file.store_string(mtl_contents)
					mtl_file.close()
				else:
					_log_error("Could not write to file at '%s'." % to)
			else:
				_log_error("Could not read file at '%s'." % to)
	
	if EXTENSIONS_TO_IMPORT.has(from.get_extension()):
		return Global.tabletop_importer.import(to)
	else:
		return OK

# Import a stack configuration file.
# pack: The name of the pack.
# type: The type of the assets.
# stack_config: The stack config file.
func _import_stack_config(pack: String, type: String, stack_config: ConfigFile) -> void:
	var stack_entries = []
	for stack_name in stack_config.get_sections():
		var desc = stack_config.get_value(stack_name, "desc", "")
		var items = stack_config.get_value(stack_name, "items")
		
		if items != null:
			if items is Array:
				# The only unknown at this point is the scale of one of the
				# objects - which should also be the same for all of them.
				var scale = null
				
				var entry_names = []
				for item in items:
					var entry = search_type(pack, type, item)
					if not entry.empty():
						if scale == null:
							scale = entry["scale"]
						else:
							if entry["scale"] != scale:
								_log_error("'%s' has inconsistent scale in stack '%s'!" % [item, stack_name])
								continue
						entry_names.append(item)
					else:
						_log_error("Item '%s' in stack '%s' does not exist!" % [item, stack_name])
				
				if scale != null:
					var type_meta = ASSET_PACK_SUBFOLDERS[type]
					var type_scene = type_meta["scene"]
					
					var stack_entry = {
						"desc": desc,
						"entry_names": entry_names,
						"name": stack_name,
						"scene_path": type_scene
					}
					
					# For us to read the DB efficiently it needs to be kept in
					# order, so add all of the stacks after we're done.
					stack_entries.append(stack_entry)
				else:
					_log_error("Could not determine the scale of stack '%s'!" % stack_name)
			else:
				_log_error("Items property of '%s' is not an array!" % stack_name)
		else:
			_log_error("'%s' has no 'items' property!" % stack_name)
	
	if not stack_entries.empty():
		for stack_entry in stack_entries:
			_add_entry_to_db(pack, type, stack_entry)

# Check if the given piece entry is valid, given the pack and type. Throws an
# error if it is not valid.
# Returns: If the piece entry is valid.
# pack: The asset pack containing the entry.
# type: The type of entry.
# entry: The entry to check.
func _is_valid_entry(pack: String, type: String, entry: Dictionary) -> bool:
	if not type in ASSET_PACK_SUBFOLDERS:
		_log_error("Type %s is invalid!" % type)
		return false
	
	var asset_type: int     = ASSET_PACK_SUBFOLDERS[type]["type"]
	var asset_scene: String = ASSET_PACK_SUBFOLDERS[type]["scene"]
	
	# Figure out based on the type which keys should be in the entry - we'll
	# check later if all of the keys were in here.
	var expected_keys = ["desc", "entry_path", "name"]
	
	if entry.has("entry_names"): # A stack entry.
		expected_keys.append_array(["entry_names", "scene_path"])
	else:
		expected_keys.append_array(["author", "license", "modified_by", "url"])
		
		if asset_type == ASSET_AUDIO:
			expected_keys.append("audio_path")
			if type == "music":
				expected_keys.append("main_menu")
		
		elif asset_type == ASSET_SKYBOX:
			expected_keys.append_array(["default", "rotation", "strength",
				"texture_path"])
		
		elif asset_type == ASSET_TABLE:
			expected_keys.append_array(["table_path", "texture_path"])
		
		elif asset_type == ASSET_TEMPLATE:
			expected_keys.append_array(["template_path", "textboxes"])
		
		else: # Objects.
			expected_keys.append_array(["color", "mass", "scale", "scene_path",
				"texture_path"])
			
			if asset_type == ASSET_SCENE:
				expected_keys.append_array(["avg_point", "bounding_box",
					"collision_mode", "com_adjust"])
			
			if type == "tables":
				expected_keys.append_array(["bounce", "default", "hands",
					"paint_plane"])
			else:
				expected_keys.append_array(["main_menu", "sfx"])
				
				if type == "cards":
					expected_keys.append("texture_path_1")
				elif type == "containers":
					expected_keys.append("shakable")
				elif type.begins_with("dice"):
					expected_keys.append("face_values")
				
				if type == "cards" or type.begins_with("tokens"):
					expected_keys.append_array(["suit", "value"])
	
	expected_keys.sort()
	var entry_keys = entry.keys()
	entry_keys.sort()
	
	if entry_keys.hash() != expected_keys.hash():
		for key in expected_keys:
			if not key in entry_keys:
				_log_error("Key '%s' not found in entry!" % key)
		for key in entry_keys:
			if not key in expected_keys:
				_log_error("Key '%s' was not expected!" % key)
		return false
	
	for key in entry:
		# Very unlikely to ever be the case, but just in case!
		if typeof(key) != TYPE_STRING:
			_log_error("Key in entry is not a string!")
			return false
		
		var value = entry[key]
		
		match key:
			"audio_path":
				if typeof(value) != TYPE_STRING:
					_log_error("'audio_path' in entry is not a string!")
					return false
				
				if not _is_valid_path(value, VALID_AUDIO_EXTENSIONS):
					_log_error("'audio_path' in entry is not a valid path!")
					return false
			"author":
				if typeof(value) != TYPE_STRING:
					_log_error("'author' in entry is not a string!")
					return false
			"avg_point":
				if typeof(value) != TYPE_VECTOR3:
					_log_error("'avg_point' in entry is not a Vector3!")
					return false
			"bounce":
				if typeof(value) != TYPE_REAL:
					_log_error("'bounce' in entry is not a float!")
					return false
				
				if value < 0.0 or value > 1.0:
					_log_error("'bounce' in entry must be between 0.0 and 1.0!")
					return false
			"bounding_box":
				if typeof(value) != TYPE_ARRAY:
					_log_error("'bounding_box' in entry is not an array!")
					return false
				
				if value.size() != 2:
					_log_error("'bounding_box' array in entry is not of size 2!")
					return false
				
				if typeof(value[0]) != TYPE_VECTOR3:
					_log_error("First element of 'bounding_box' in entry is not a Vector3!")
					return false
				
				if typeof(value[1]) != TYPE_VECTOR3:
					_log_error("Second element of 'bounding_box' in entry is not a Vector3!")
					return false
				
				if (value[1] - value[0]).sign() != Vector3.ONE:
					_log_error("'bounding_box' in entry is invalid!")
					return false
			"collision_mode":
				if typeof(value) != TYPE_INT:
					_log_error("'collision_mode' in entry is not an integer!")
					return false
				
				if value < PieceBuilder.COLLISION_CONVEX or value > PieceBuilder.COLLISION_CONCAVE:
					_log_error("'collision_mode' in entry is invalid!")
					return false
				
				if type == "tables" and value == PieceBuilder.COLLISION_CONCAVE:
					_log_error("'collision_mode' in entry is concave, but entry is for a table!")
					return false
			"com_adjust":
				if typeof(value) != TYPE_INT:
					_log_error("'com_adjust' in entry is not an integer!")
					return false
				
				if value < PieceBuilder.COM_ADJUST_OFF or value > PieceBuilder.COM_ADJUST_GEOMETRY:
					_log_error("'com_adjust' in entry is invalid!")
					return false
			"color":
				if typeof(value) != TYPE_COLOR:
					_log_error("'color' in entry is not a color!")
					return false
			
				if value.a != 1.0:
					_log_error("'color' in entry cannot be transparent!")
					return false
			"default":
				if typeof(value) != TYPE_BOOL:
					_log_error("'default' in entry is not a boolean!")
					return false
			"desc":
				if typeof(value) != TYPE_STRING:
					_log_error("'desc' in entry is not a string!")
					return false
			"entry_names":
				if typeof(value) != TYPE_ARRAY:
					_log_error("'entry_names' in entry is not an array!")
					return false
				
				if value.size() < 2:
					_log_error("'entry_names' in entry must have at least two items!")
					return false
				
				for element in value:
					if typeof(element) != TYPE_STRING:
						_log_error("'entry_names' element in entry is not a string!")
						return false
					
					var db = get_db()
					if not db.has(pack):
						_log_error("Pack '%s' does not exist in the AssetDB!" % pack)
						return false
					if not db[pack].has(type):
						_log_error("Type '%s/%s' does not exist in the AssetDB!" % [pack, type])
						return false
					
					var type_arr: Array = db[pack][type]
					# TODO: Re-work _sort_assets function?
					var element_index = type_arr.bsearch_custom({"name": element}, self, "_order_assets")
					var element_valid = false
					if element_index < type_arr.size():
						if type_arr[element_index]["name"] == element:
							element_valid = true
					
					if not element_valid:
						_log_error("Element '%s' in stack entry was not found in '%s/%s'!" % [element, pack, type])
			"entry_path":
				if typeof(value) != TYPE_STRING:
					_log_error("'entry_path' in entry is not a string!")
					return false
				# We'll check if it's the value we expect later!
			"face_values":
				if typeof(value) != TYPE_DICTIONARY:
					_log_error("'face_values' in entry is not a dictionary!")
					return false
				
				for element_key in value:
					if typeof(element_key) != TYPE_STRING:
						_log_error("'face_values' key in entry is not a string!")
						return false
					
					var element_value = value[element_key]
					if typeof(element_value) != TYPE_ARRAY:
						_log_error("'face_values' value in entry is not an Array!")
						return false
					
					if len(element_value) == 0:
						_log_error("'face_values' value in entry is empty!")
						return false
					
					for normal in element_value:
						if typeof(normal) != TYPE_VECTOR3:
							_log_error("'face_values' sub-value in entry is not a Vector3!")
							return false
						
						if not is_equal_approx(normal.length_squared(), 1.0):
							_log_error("'face_values' vector in entry is not unit length!")
							return false
			"hands":
				if typeof(value) != TYPE_ARRAY:
					_log_error("'hands' in entry is not an array!")
					return false
				
				for element in value:
					if typeof(element) != TYPE_DICTIONARY:
						_log_error("'hands' element is not a dictionary!")
						return false
					
					if element.size() != 2:
						_log_error("'hands' element must be size 2 (is %d)!" % [element.size()])
						return false
					
					if not element.has("pos"):
						_log_error("'hands' does not contain 'pos' key!")
						return false
					
					if not element.has("dir"):
						_log_error("'hands' does not contain 'dir' key!")
						return false
					
					var pos = element["pos"]
					if typeof(pos) != TYPE_VECTOR3:
						_log_error("'pos' element in 'hands' is not a Vector3!")
						return false
					
					var dir = element["dir"]
					if not (typeof(dir) == TYPE_INT or typeof(dir) == TYPE_REAL):
						_log_error("'dir' element in 'hands' is not a number!")
						return false
			"license":
				if typeof(value) != TYPE_STRING:
					_log_error("'license' in entry is not a string!")
					return false
			"main_menu":
				if typeof(value) != TYPE_BOOL:
					_log_error("'main_menu' in entry is not a boolean!")
					return false
			"mass":
				if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_REAL):
					_log_error("'mass' in entry is not a number!")
					return false
				
				if value <= 0:
					_log_error("'mass' in entry cannot be negative or zero!")
					return false
			"modified_by":
				if typeof(value) != TYPE_STRING:
					_log_error("'modified_by' in entry is not a string!")
					return false
			"name":
				if typeof(value) != TYPE_STRING:
					_log_error("'name' in entry is not a string!")
					return false
				
				if value.empty():
					_log_error("'name' in entry is empty!")
					return false
				
				if not value.is_valid_filename():
					_log_error("'name' in entry is not a valid name!")
					return false
			"paint_plane":
				if typeof(value) != TYPE_VECTOR2:
					_log_error("'paint_plane' is not a Vector2!")
					return false
				
				if value.sign() != Vector2.ONE:
					_log_error("'paint_plane' elements cannot be negative!")
					return false
			"rotation":
				if typeof(value) != TYPE_VECTOR3:
					_log_error("'rotation' in entry is not a Vector3!")
					return false
			"scale":
				if typeof(value) != TYPE_VECTOR3:
					_log_error("'scale' in entry is not a Vector3!")
					return false
				
				if value.sign() != Vector3.ONE:
					_log_error("'scale' element in entry cannot be negative!")
					return false
			"scene_path":
				if typeof(value) != TYPE_STRING:
					_log_error("'scene_path' in entry is not a string!")
					return false
				
				if asset_type == ASSET_TEXTURE:
					if value != asset_scene:
						_log_error("'scene_path' value in entry is not expected value!")
						return false
				else:
					if not _is_valid_path(value, VALID_SCENE_EXTENSIONS):
						_log_error("'scene_path' in entry is not a valid path!")
						return false
			"sfx":
				if typeof(value) != TYPE_STRING:
					_log_error("'sfx' in entry is not a string!")
					return false
				
				if type == "cards" or type.begins_with("dice") or type.begins_with("tokens"):
					if not value.empty():
						_log_error("'sfx' value in entry should be empty!")
						return false
				else:
					if not value in SFX_AUDIO_STREAMS:
						_log_error("'sfx' value in entry does not match any preset!")
						return false
			"shakable":
				if typeof(value) != TYPE_BOOL:
					_log_error("'shakable' in entry is not a boolean!")
					return false
			"strength":
				if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_REAL):
					_log_error("'strength' in entry is not a number!")
					return false
				
				if value < 0.0:
					_log_error("'strength' in entry cannot be negative!")
					return false
			"suit":
				var t = typeof(value)
				if not (t == TYPE_INT or t == TYPE_REAL or t == TYPE_STRING or t == TYPE_NIL):
					_log_error("'suit' in entry is not a number or a string!")
					return false
			"table_path":
				if typeof(value) != TYPE_STRING:
					_log_error("'table_path' in entry is not a string!")
					return false
				
				if not _is_valid_path(value, VALID_TABLE_EXTENSIONS):
					_log_error("'table_path' in entry is not a valid path!")
					return false
			"template_path":
				if typeof(value) != TYPE_STRING:
					_log_error("'template_path' in entry is not a string!")
					return false
				
				if not _is_valid_path(value, VALID_TEXTURE_EXTENSIONS + ["txt"]):
					_log_error("'template_path' in entry is not a valid path!")
					return false
			"textboxes":
				if typeof(value) != TYPE_DICTIONARY:
					_log_error("'textboxes' in entry is not a dictionary!")
					return false
				
				if not value.empty():
					var template_path = entry["template_path"]
					if typeof(template_path) != TYPE_STRING:
						_log_error("'template_path' in entry is not a string!")
						return false
					
					if template_path.get_extension() == "txt":
						_log_error("Text templates cannot have textboxes!")
						return false
				
				for id in value:
					if typeof(id) != TYPE_STRING:
						_log_error("Textbox ID is not a string!")
						return false
					
					if not id.is_valid_identifier():
						_log_error("Textbox ID '%s' is not a valid ID!" % id)
						return false
					
					var subvalue = value[id]
					if typeof(subvalue) != TYPE_DICTIONARY:
						_log_error("Textbox entry in 'textboxes' is not a dictionary!")
						return false
					
					if subvalue.size() != 7:
						_log_error("Invalid number of elements %d for textbox entry!" % subvalue.size())
						return false
					
					if not subvalue.has("x"):
						_log_error("Textbox entry does not contain element 'x'!")
						return false
					var x = subvalue["x"]
					if typeof(x) != TYPE_INT:
						_log_error("Textbox element 'x' is not an integer!")
						return false
					if x < 0:
						_log_error("Invalid value %d for textbox element 'x'!" % x)
						return false
					
					if not subvalue.has("y"):
						_log_error("Textbox entry does not contain element 'y'!")
						return false
					var y = subvalue["y"]
					if typeof(y) != TYPE_INT:
						_log_error("Textbox element 'y' is not an integer!")
						return false
					if y < 0:
						_log_error("Invalid value %d for textbox element 'y'!" % y)
						return false
					
					if not subvalue.has("w"):
						_log_error("Textbox entry does not contain element 'w'!")
						return false
					var w = subvalue["w"]
					if typeof(w) != TYPE_INT:
						_log_error("Textbox element 'w' is not an integer!")
						return false
					if w < 10:
						_log_error("Invalid value %d for textbox element 'w'!" % w)
						return false
					
					if not subvalue.has("h"):
						_log_error("Textbox entry does not contain element 'h'!")
						return false
					var h = subvalue["h"]
					if typeof(h) != TYPE_INT:
						_log_error("Textbox element 'h' is not an integer!")
						return false
					if h < 10:
						_log_error("Invalid value %d for textbox element 'h'!" % h)
						return false
					
					if not subvalue.has("rot"):
						_log_error("Textbox entry does not contain element 'rot'!")
						return false
					var rot = subvalue["rot"]
					if not (typeof(rot) == TYPE_INT or typeof(rot) == TYPE_REAL):
						_log_error("Textbox element 'rot' is not a number!")
						return false
					if is_nan(rot) or is_inf(rot):
						_log_error("Invalid value for textbox element 'rot'!")
						return false
					
					if not subvalue.has("text"):
						_log_error("Textbox entry does not contain element 'text'!")
						return false
					var text = subvalue["text"]
					if typeof(text) != TYPE_STRING:
						_log_error("Textbox element 'text' is not a string!")
						return false
					
					if not subvalue.has("lines"):
						_log_error("Textbox entry does not contain element 'lines'!")
						return false
					var lines = subvalue["lines"]
					if typeof(lines) != TYPE_INT:
						_log_error("Textbox element 'lines' is not an integer!")
						return false
					if lines < 1:
						_log_error("Invalid value %d for textbox element 'lines'!" % lines)
						return false
					var max_lines = floor((float(h) - 9.0) / 10.0)
					max_lines = int(max(max_lines, 1.0))
					if lines > max_lines:
						_log_error("Invalid number of lines for textbox! (lines = %d, max = %d)" % [
								lines, max_lines])
						return false
			"texture_path":
				if asset_type == ASSET_SCENE:
					if typeof(value) != TYPE_NIL:
						_log_error("'texture_path' in scene entry is not null!")
						return false
				else:
					if typeof(value) != TYPE_STRING:
						_log_error("'texture_path' in entry is not a string!")
						return false
					
					if not _is_valid_path(value, VALID_TEXTURE_EXTENSIONS):
						_log_error("'texture_path' in entry is not a valid path!")
						return false
			"texture_path_1":
				if typeof(value) != TYPE_STRING:
					_log_error("'texture_path_1' in entry is not a string!")
					return false
				
				if not (value.empty() or _is_valid_path(value, VALID_TEXTURE_EXTENSIONS)):
					_log_error("'texture_path_1' in entry is not a valid path!")
					return false
			"url":
				if typeof(value) != TYPE_STRING:
					_log_error("'url' in entry is not a string!")
					return false
			"value":
				var t = typeof(value)
				if not (t == TYPE_INT or t == TYPE_REAL or t == TYPE_STRING or t == TYPE_NIL):
					_log_error("'value' in entry is not a number or a string!")
					return false
			_:
				_log_error("Unknown key '%s' in entry!" % key)
				return false
	
	var entry_name = entry["name"]
	var entry_path = entry["entry_path"]
	var expected_entry_path = "%s/%s/%s" % [pack, type, entry_name]
	if entry_path != expected_entry_path:
		_log_error("Entry 'entry_path' (%s) does not match expected value (%s)!" % [
			entry_path, expected_entry_path])
		return false
	
	return true

# Check if a string is a valid path (for a piece entry).
# Returns: If the path is valid.
# path: The string to check.
# valid_ext: The list of valid extensions of the path.
func _is_valid_path(path: String, valid_ext: Array) -> bool:
	if not path.is_abs_path():
		return false
	
	if not path.begins_with("user://assets/"):
		return false
	
	if not valid_ext.has(path.get_extension()):
		return false
	
	return true

# Parse translations from a config file and insert them into the AssetDB.
# pack: The asset pack containing the translations.
# type: The type of asset containing the translations.
# config: The config file containing the translations.
# locale: The locale of the translations.
func _parse_tr_file(pack: String, type: String, config: ConfigFile, locale: String) -> void:
	if not _db.has(pack):
		push_error("AssetDB does not contain pack %s!" % pack)
		return
	
	if not _db[pack].has(type):
		push_error("AssetDB does not contain type %s in pack %s!" % [type, pack])
		return
	
	var sections = config.get_sections()
	for asset_name in sections:
		var result = search_type(pack, type, asset_name)
		if not result.empty():
			for key in ["name", "desc"]:
				if config.has_section_key(asset_name, key):
					var tr_name = config.get_value(asset_name, key)
					if tr_name is String:
						if not tr_name.empty():
							result["%s_%s" % [key, locale]] = tr_name
						else:
							push_error("%s cannot be empty!" % key)
					else:
						push_error("%s under %s is not text!" % [key, asset_name])
		else:
			push_error("Asset %s was not found in %s/%s, ignoring." % [asset_name, pack, type])

# Function used to convert rotation transforms in the form of a Vector2 into
# a Vector3 representing the normal vector of the corresponding face.
# Returns: The normal vector.
# rot: The rotation transformation, where the first element is the x rotation,
# and the second element is the z rotation, both in degrees.
func _precalculate_face_value_normal(rot: Vector2) -> Vector3:
	var quat = Quat(Vector3(deg2rad(rot.x), 0.0, deg2rad(rot.y)))
	return quat.inverse().xform(Vector3.UP)

# Remove unused asset files under the user:// directory, including caches and
# metadata files.
# catalog: The latest catalog of imported files, used to know which files not
# to delete.
func _remove_old_assets(catalog: Dictionary) -> void:
	var asset_dir_path = ""
	
	var asset_dir = Directory.new()
	var err = asset_dir.open("user://assets")
	if err == OK:
		asset_dir_path = asset_dir.get_current_dir()
		
		asset_dir.list_dir_begin(true, true)
		var pack = asset_dir.get_next()
		while not pack.empty():
			if asset_dir.current_is_dir():
				for type in ASSET_PACK_SUBFOLDERS:
					_remove_old_assets_type(catalog, pack, type)
			
			pack = asset_dir.get_next()
	else:
		_log_error("Failed to open user://assets! (error %d)" % err)
	
	var import_dir = Directory.new()
	err = import_dir.open("user://.import")
	if err == OK:
		# We need to simulate what the import module does to the file names so
		# we can compare them to the actual files.
		var safe_files = {}
		for pack in catalog["packs"]:
			var catalog_pack: Dictionary = catalog["packs"][pack]
			var pack_path: String = catalog_pack["path"]
			for type in catalog_pack["types"]:
				var catalog_type: Dictionary = catalog_pack["types"][type]
				for file in catalog_type["files"]:
					var original_path = "%s/%s/%s" % [pack_path, type, file]
					var md5_name = file + "-" + original_path.md5_text()
					safe_files[md5_name] = 0 # Dummy value.
					
					var copy_path = "%s/%s/%s/%s" % [asset_dir_path, pack,
						type, file]
					var import_name = file + "-" + copy_path.md5_text()
					safe_files[import_name] = 0
		
		import_dir.list_dir_begin(true, true)
		var file = import_dir.get_next()
		while not file.empty():
			var base_name = file.get_basename()
			if not safe_files.has(base_name):
				err = import_dir.remove(file)
				if err == OK:
					print("Removed: %s" % file)
				else:
					_log_error("Failed to remove %s! (error: %d)" % [file, err])
			
			file = import_dir.get_next()
	else:
		_log_error("Failed to open user://.import! (error %d)" % err)

# Helper function for _remove_old_assets.
# catalog: The latest catalog of imported files.
# pack: The pack to clean files from.
# type: The type within the pack to clean files from.
func _remove_old_assets_type(catalog: Dictionary, pack: String, type: String) -> void:
	if "/" in pack or "\\" in pack:
		_log_error("Invalid pack name!")
		return
	
	if not type in ASSET_PACK_SUBFOLDERS:
		_log_error("Invalid type!")
		return
	
	var safe_files: Array = []
	var config_cfg_exists: bool = false
	var scene_exists: bool = false
	
	var catalog_packs: Dictionary = catalog["packs"]
	if catalog_packs.has(pack):
		var catalog_types: Dictionary = catalog_packs[pack]["types"]
		if catalog_types.has(type):
			safe_files = catalog_types[type]["files"]
			config_cfg_exists = catalog_types[type]["config_file"]
			
			for file in safe_files:
				if file.get_extension() in VALID_SCENE_EXTENSIONS:
					scene_exists = true
					break
	
	var type_path = "user://assets/%s/%s" % [pack, type]
	var type_dir = Directory.new()
	if not type_dir.dir_exists(type_path):
		return
	
	var err = type_dir.open(type_path)
	if err != OK:
		_log_error("Failed to open '%s'! (error: %d)" % [type_path, err])
		return
	
	var files_to_remove = []
	
	type_dir.list_dir_begin(true, true)
	var file = type_dir.get_next()
	while not file.empty():
		if file.get_extension() in VALID_EXTENSIONS and not file in safe_files:
			# Check for additional files, as well as the original.
			for suffix in ["", ".box", ".geo", ".import", ".src"]:
				var full_file = file + suffix
				if not type_dir.file_exists(full_file):
					continue
				
				files_to_remove.append(full_file)
		
		# Cache files, including thumbnail caches.
		elif file.get_extension() in ["scn", "tscn", "version"]:
			if file.get_basename().ends_with("cache"):
				var match_found = false
				for file_check in safe_files:
					var name_check = file_check.get_basename()
					if file.begins_with(name_check):
						match_found = true
						break
				
				if not match_found:
					files_to_remove.append(file)
		
		elif file == "config.cfg.md5" and not config_cfg_exists:
			files_to_remove.append("config.cfg.md5")
		
		# We cannot easily check which materials belong to which models, so
		# only remove materials if there are no models.
		elif file.get_extension() == "material" and not scene_exists:
			files_to_remove.append(file)
		
		file = type_dir.get_next()
	
	for goodbye in files_to_remove:
		err = type_dir.remove(goodbye)
		if err == OK:
			print("Removed: %s/%s/%s" % [pack, type, goodbye])
		else:
			_log_error("Failed to remove %s! (error: %d)" % [goodbye, err])

# Function used to binary search an array of asset entries by name.
func _search_assets(element: Dictionary, search: String) -> bool:
	return element["name"] < search

# Send the completed signal.
# dir_found: Was there an asset directory?
func _send_completed_signal(dir_found: bool) -> void:
	_import_mutex.lock()
	_import_dir_found = dir_found
	_import_file_path = ""
	_import_send_signal = true
	_import_mutex.unlock()

# Send the importing file signal.
# file: The path of the file being imported.
# files_imported: The number of files imported so far.
# files_total: The total number of files.
func _send_importing_file_signal(file: String, files_imported: int, files_total: int) -> void:
	_import_mutex.lock()
	_import_file_path = file
	_import_files_imported = files_imported
	_import_files_total = files_total
	_import_send_signal = true
	_import_mutex.unlock()

# Function used to sort an array of asset entries.
func _order_assets(a: Dictionary, b: Dictionary) -> bool:
	return a["name"] < b["name"]

func _on_exiting_tree() -> void:
	_import_mutex.lock()
	_import_stop = true
	_import_mutex.unlock()
	
	if _import_thread.is_active():
		_import_thread.wait_to_finish()

func _log_error(error: String):
	push_error(error)
	_import_err_mutex.lock()
	if not _import_err_source.empty():
		var err = "E: %s" % error
		if not _import_err_dict.has(_import_err_source):
			_import_err_dict[_import_err_source] = []
		_import_err_dict[_import_err_source].push_back(err)
	_import_err_mutex.unlock()

func _log_warning(error: String):
	push_warning(error)
	_import_err_mutex.lock()
	if not _import_err_source.empty():
		var err = "W: %s" % error
		if not _import_err_dict.has(_import_err_source):
			_import_err_dict[_import_err_source] = []
		_import_err_dict[_import_err_source].push_back(err)
	_import_err_mutex.unlock()
