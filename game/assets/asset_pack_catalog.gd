# tabletop-club
# Copyright (c) 2020-2023 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2023 Tabletop Club contributors (see game/CREDITS.tres).
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

class_name AssetPackCatalog
extends Reference

## Import an [AssetPack] from the filesystem.
##
## By instancing this class, a directory is created within
## [code]user://assets/[/code] which will be used to store a copy of the assets.
## An external directory, which will usually be one in the user's documents
## folder, can then be scanned as an asset pack. This will then create a series
## of [AssetPackTypeCatalog], which will individually tag and import all of the
## relevant files in each of the pack's subdirectories. Once all of the files
## have been imported, an [AssetPack] can then be created and subsequently added
## to the AssetDB to be used by the player in-game.


## A dictionary containing a list of subdirectories to scan (the keys) within
## the asset pack, and which type the assets are allocated to within an
## [AssetPack] object (the values).
const SUBDIRECTORY_TYPE_SCHEMA := {
	"boards": "boards",
	"cards": "cards",
	"containers": "containers",
	"dice/d4": "dice",
	"dice/d6": "dice",
	"dice/d8": "dice",
	"dice/d10": "dice",
	"dice/d12": "dice",
	"dice/d20": "dice",
	"games": "games",
	"music": "music",
	"pieces": "pieces",
	"skyboxes": "skyboxes",
	"sounds": "sounds",
	"speakers": "speakers",
	"tables": "tables",
	"templates": "templates",
	"timers": "timers",
	"tokens/cube": "tokens",
	"tokens/cylinder": "tokens",
}

## The name of the asset pack this instance is importing. This is also used as
## the internal directory name.
var pack_name: String setget set_pack_name

## A subclass used internally to store data about each subdirectory of the pack.
class DirectoryEnvironment:
	extends Reference
	
	## The [AssetPackTypeCatalog] for this directory.
	var type_catalog: AssetPackTypeCatalog
	
	## The main configuration file for this directory.
	var type_config := AdvancedConfigFile.new()
	
	## The list of assets that will become the entries for this type.
	## TODO: Make array typed.
	var main_assets: Array = []
	
	func _init(type_dir: String):
		type_catalog = AssetPackTypeCatalog.new(type_dir)

# The list of DirectoryEnvironment, where the key is the subdirectory the
# environment is assigned to, and the value is the environment itself.
var _type_env_map := {}

# The path of the last external directory that was scanned for this pack.
var _last_scan_dir_path := ""


func _init(new_pack_name: String):
	set_pack_name(new_pack_name)


## Scan the given directory as an asset pack, and collect the assets within it
## into the internal directory.
func scan_dir(dir_path: String) -> void:
	if pack_name.empty():
		push_error("Cannot scan pack directory, no name given")
		return
	
	var external_dir := Directory.new()
	if not external_dir.dir_exists(dir_path):
		push_error("Cannot scan asset pack at '%s', directory does not exist" % dir_path)
		return
	
	_last_scan_dir_path = dir_path
	
	for sub_dir in SUBDIRECTORY_TYPE_SCHEMA:
		var external_type_path := dir_path.plus_file(sub_dir)
		if not external_dir.dir_exists(external_type_path):
			continue
		
		var internal_type_path := "user://assets/%s/%s" % [pack_name, sub_dir]
		var internal_dir := Directory.new()
		if not internal_dir.dir_exists(internal_type_path):
			var err := internal_dir.make_dir_recursive(internal_type_path)
			if err != OK:
				push_error("Failed to create directory at '%s' (error: %d)" % [
						internal_type_path, err])
				continue
		
		var type_env: DirectoryEnvironment
		if _type_env_map.has(sub_dir):
			type_env = _type_env_map[sub_dir]
		else:
			type_env = DirectoryEnvironment.new(internal_type_path)
			_type_env_map[sub_dir] = type_env
		
		match sub_dir:
			"boards", "containers", "dice/d4", "dice/d6", "dice/d8", "dice/d10", \
			"dice/d12", "dice/d20", "pieces", "speakers", "tables", "timers":
				type_env.type_catalog.collect_textures(external_type_path)
				type_env.type_catalog.collect_support(external_type_path)
				type_env.main_assets = type_env.type_catalog.collect_scenes(external_type_path)
			"cards", "skyboxes", "tokens/cube", "tokens/cylinder":
				type_env.main_assets = type_env.type_catalog.collect_textures(external_type_path)
			"games":
				type_env.main_assets = type_env.type_catalog.collect_saves(external_type_path)
			"music", "sounds":
				type_env.main_assets = type_env.type_catalog.collect_audio(external_type_path)
			"templates":
				var image_assets := type_env.type_catalog.collect_textures(external_type_path)
				var text_assets := type_env.type_catalog.collect_text_templates(external_type_path)
				type_env.main_assets = image_assets + text_assets
			_:
				push_warning("Subdirectory '%s' has not been implemented" % sub_dir)
				type_env.main_assets.clear()
		
		var type_config_path := external_type_path.plus_file("config.cfg")
		if external_dir.file_exists(type_config_path):
			var err := type_env.type_config.load(type_config_path)
			if err != OK:
				push_error("Failed to load config file at '%s' (error: %d)" % [
						type_config_path, err])


## Create a new [AssetPack] with no entries.
func create_empty_pack() -> AssetPack:
	var out := AssetPack.new()
	out.id = pack_name
	out.name = pack_name
	out.origin = _last_scan_dir_path
	return out


## Import the collected assets from the given subdirectory, and create entries
## which will be added to the given [AssetPack] resource.
func import_sub_dir(pack: AssetPack, sub_dir: String) -> void:
	if not _type_env_map.has(sub_dir):
		push_error("Cannot import from '%s', environment does not exist" % sub_dir)
		return
	
	var type: String = SUBDIRECTORY_TYPE_SCHEMA[sub_dir]
	var type_env: DirectoryEnvironment = _type_env_map[sub_dir]
	type_env.type_catalog.import_tagged()
	
	for main_file in type_env.main_assets:
		var asset_entry: AssetEntrySingle
		match type:
			"boards": asset_entry = AssetEntryScene.new()
			"cards": asset_entry = AssetEntryStackable.new()
			"containers": asset_entry = AssetEntryContainer.new()
			"dice": asset_entry = AssetEntryDice.new()
			"games": continue # TODO: IMPLEMENT! 
			"music": asset_entry = AssetEntryAudio.new()
			"pieces": asset_entry = AssetEntryScene.new()
			"skyboxes": asset_entry = AssetEntrySkybox.new()
			"sounds": asset_entry = AssetEntryAudio.new()
			"speakers": asset_entry = AssetEntryScene.new()
			"tables": asset_entry = AssetEntryTable.new()
			"templates":
				if main_file.get_extension() == "txt":
					asset_entry = AssetEntryTemplateText.new()
				else:
					asset_entry = AssetEntryTemplateImage.new()
			"timers": asset_entry = AssetEntryScene.new()
			"tokens": asset_entry = AssetEntryStackable.new()
		
		# TODO: Setup the entry.
		# TODO: Configure the entry.
		# TODO: Add the entry to the pack, without duplicating.


func set_pack_name(value: String) -> void:
	value = value.strip_edges().strip_escapes()
	if not value.is_valid_filename():
		push_error("'%s' is not a valid pack name")
		return
	
	pack_name = value
	_setup_pack_dir()


# Setup the internal pack directory, and create type catalogs for any
# subdirectories that already exist.
func _setup_pack_dir() -> void:
	_type_env_map.clear()
	
	var pack_dir := Directory.new()
	var pack_dir_path := "user://assets/" + pack_name
	
	if pack_dir.dir_exists(pack_dir_path):
		for sub_dir in SUBDIRECTORY_TYPE_SCHEMA:
			var sub_dir_path := pack_dir_path.plus_file(sub_dir)
			if pack_dir.dir_exists(sub_dir_path):
				var env := DirectoryEnvironment.new(sub_dir_path)
				_type_env_map[sub_dir] = env
	else:
		var err := pack_dir.make_dir(pack_dir_path)
		if err != OK:
			push_error("Error creating pack directory at '%s' (error: %d)" % [
					pack_dir_path, err])
