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


## Emitted when a file is about to be imported by one of the internal
## [AssetPackTypeCatalog] in [method perform_full_import].
signal about_to_import_file(file_path, file_index, file_count)


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

# The number of files that we expect to import in the asset pack.
var _num_files_to_import := 0

# The number of files that we have imported so far.
var _num_files_imported := 0


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
	
	print("Scanning pack directory: %s" % dir_path)
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


## Check if this catalog has scanned a directory as an asset pack using
## [method scan_dir].
func has_scanned_dir() -> bool:
	return not _last_scan_dir_path.empty()


## Get the internal [class DirectoryEnvironment] for the given sub-directory,
## or [code]null[/code] if it does not exist. Note that this function only
## exists for testing purposes, and shouldn't be used to modify the environment.
func get_dir_env(sub_dir: String) -> DirectoryEnvironment:
	return _type_env_map.get(sub_dir, null)


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
	
	print("%s: Importing assets from directory '%s' ..." % [pack.id, sub_dir])
	type_env.type_catalog.import_tagged()
	
	for main_file in type_env.main_assets:
		if ImportAbortFlag.is_enabled():
			break
		
		var ignore: bool = type_env.type_config.get_value_by_matching(main_file,
				"ignore", false, true)
		if ignore:
			continue
		
		var asset_entry: AssetEntrySingle
		match type:
			"boards": asset_entry = AssetEntryScene.new()
			"cards": asset_entry = AssetEntryStackable.new()
			"containers": asset_entry = AssetEntryContainer.new()
			"dice": asset_entry = AssetEntryDice.new()
			"games": asset_entry = AssetEntrySave.new()
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
		
		var main_path := "user://assets/%s/%s/%s" % [pack_name, sub_dir, main_file]
		
		if asset_entry is AssetEntryAudio:
			asset_entry.audio_path = main_path
			asset_entry.music = (type == "music")
		
		elif asset_entry is AssetEntrySave:
			asset_entry.save_file_path = main_path
		
		elif asset_entry is AssetEntryScene:
			# TODO: Fill out internal resource paths.
			match sub_dir:
				"cards":
					type_env.type_catalog.setup_scene_entry(asset_entry, "",
						GeoData.new(), main_path)
					
					var back_face_name: String = \
							type_env.type_config.get_value_by_matching(main_file,
									"back_face", "", true)
					_set_card_back_face(asset_entry, type_env.type_catalog,
							back_face_name)
				"tokens/cube":
					type_env.type_catalog.setup_scene_entry(asset_entry, "",
						GeoData.new(), main_path)
				"tokens/cylinder":
					type_env.type_catalog.setup_scene_entry(asset_entry, "",
						GeoData.new(), main_path)
				_:
					type_env.type_catalog.setup_scene_entry_custom(asset_entry,
						main_file)
		
		elif asset_entry is AssetEntrySkybox:
			asset_entry.texture_path = main_path
		
		elif asset_entry is AssetEntryTemplate:
			asset_entry.template_path = main_path
		
		# Cards cannot be scaled vertically (on the y-axis).
		var scale_is_vec2 := (type == "cards")
		
		# The number of faces on a die depends on the subdirectory it is in.
		var die_num_faces := _get_num_die_faces(sub_dir)
		
		type_env.type_catalog.apply_config_to_entry(asset_entry,
			type_env.type_config, main_file, scale_is_vec2, die_num_faces)
		
		# If an entry with the same name already exists in the pack, rename the
		# current entry so it can be added.
		if pack.has_entry(type, asset_entry.id):
			var extra_num := 1
			while pack.has_entry(type, asset_entry.id + " (%d)" % extra_num):
				extra_num += 1
			
			asset_entry.id += " (%d)" % extra_num
		
		pack.add_entry(type, asset_entry)


## Using the [code]config.cfg[/code] files from each of the sub-directories,
## create a list of child entries which are added to the given asset pack.
## Child entries are created by adding the [code]parent[/code] property to a
## section in the config file, which determines the entry that the child's
## properties are inherited from.
func create_child_entries(pack: AssetPack) -> void:
	print("%s: Creating child entries..." % pack.id)
	for sub_dir in _type_env_map:
		var type: String = SUBDIRECTORY_TYPE_SCHEMA[sub_dir]
		var type_env: DirectoryEnvironment = _type_env_map[sub_dir]
		
		var sub_dir_config := type_env.type_config
		for section_name in sub_dir_config.get_sections():
			if not sub_dir_config.has_section_key(section_name, "parent"):
				continue
			
			if not section_name.is_valid_filename():
				push_error("%s/config.cfg: Invalid section name '%s' with 'parent' property" % [
					sub_dir, section_name])
				continue
			
			if pack.has_entry(type, section_name):
				push_error("%s/config.cfg: Entry '%s/%s/%s' already exists" % [
					sub_dir, pack.id, type, section_name])
				continue
			
			var parent_id: String = sub_dir_config.get_value_strict(
				section_name, "parent", "")
			if parent_id.empty():
				push_error("%s: property 'parent' cannot be empty" % section_name)
				continue
			
			if not pack.has_entry(type, parent_id):
				push_error("%s: property 'parent' is invalid, entry '%s/%s/%s' does not exist" % [
					section_name, pack.id, type, parent_id])
				continue
			
			# The 'ignore' property is not read by AssetPackTypeCatalog, so we
			# need to deal with it here if it exists.
			var ignore: bool = sub_dir_config.get_value_strict(section_name,
					"ignore", false)
			if ignore:
				continue
			
			var parent_entry := pack.get_entry(type, parent_id)
			var child_entry := parent_entry.duplicate()
			
			var scale_is_vec2 := (type == "cards")
			var die_num_faces := _get_num_die_faces(sub_dir)
			
			print("Inheriting: %s -> %s" % [parent_id, section_name])
			var new_properties := AdvancedConfigFile.new()
			type_env.type_catalog.write_entry_to_config(parent_entry,
				new_properties, section_name, scale_is_vec2)
			
			# Set the name of the new child entry in the temporary config file,
			# since apply_config_to_entry will write it into the entry anyways.
			new_properties.set_value(section_name, "name", section_name)
			
			if child_entry is AssetEntryScene:
				# The 'back_face' property of cards is not handled by
				# AssetPackTypeCatalog, so if the property is overwritten we
				# need to handle that here.
				if sub_dir == "cards" and sub_dir_config.has_section_key(
						section_name, "back_face"):
					
					var new_back_face_name: String = \
							sub_dir_config.get_value_strict(section_name,
									"back_face", "")
					_set_card_back_face(child_entry, type_env.type_catalog,
							new_back_face_name)
				
				# The scale will have already been applied to the geometry data
				# stored in the entry, so we need to reverse this in order to
				# apply the new scale.
				var scale_before: Vector3 = child_entry.scale
				
				if not (is_zero_approx(scale_before.x) or \
					is_zero_approx(scale_before.y) or \
					is_zero_approx(scale_before.z)):
					
					child_entry.avg_point /= scale_before
					child_entry.bounding_box.position /= scale_before
					child_entry.bounding_box.size /= scale_before
				else:
					push_warning("%s/%s: Element in property 'scale' is 0.0, cannot determine original geometry metadata" % [
						type, parent_id])
				
				# If there is a valid config property for the parent's SFX, then
				# clear the list of sounds in the entry before applying the
				# config. This will ensure that apply_config_to_entry will read
				# the config property and apply the new set of sound effects.
				if new_properties.has_section_key(section_name, "sfx"):
					child_entry.collision_fast_sounds = AudioStreamList.new()
					child_entry.collision_slow_sounds = AudioStreamList.new()
			
			# Overwrite the parent entry's properties with the ones from this
			# particular section.
			for key in sub_dir_config.get_section_keys(section_name):
				if key == "parent":
					continue
				
				var value = sub_dir_config.get_value(section_name, key)
				new_properties.set_value(section_name, key, value)
			
			type_env.type_catalog.apply_config_to_entry(child_entry,
				new_properties, section_name, scale_is_vec2, die_num_faces)
			pack.add_entry(type, child_entry)


## Read the contents of a [code]stacks.cfg[/code] file and create a list of
## [class AssetEntryCollection] entries to be added to the given asset pack.
func read_stacks_config(pack: AssetPack, stack_config: AdvancedConfigFile,
	stack_type: String) -> void:
	
	for section_name in stack_config.get_sections():
		if not stack_config.has_section_key(section_name, "items"):
			push_warning("Stack '%s' does not have 'items' property, ignoring" % section_name)
			continue
		
		# The items within a stack must all be the same size.
		var scale_required := Vector3.ZERO
		var scale_set := false
		
		var item_names: Array = stack_config.get_value_strict(section_name,
			"items", [])
		
		var item_refs := []
		for item_name in item_names:
			if not item_name is String:
				push_error("Item in stack '%s' is not a string" % section_name)
				continue
			
			if not pack.has_entry(stack_type, item_name):
				push_error("Item '%s' does not exist in '%s/%s'" % [item_name,
					pack.id, stack_type])
				continue
			
			var item_entry: AssetEntryScene = pack.get_entry(stack_type, item_name)
			if scale_set:
				if not item_entry.scale.is_equal_approx(scale_required):
					push_error("Scale of '%s' %s does not match that of '%s' %s, cannot be included in '%s'" % [
							item_name, str(item_entry.scale), item_names[0],
							str(scale_required), section_name])
					continue
			else:
				scale_required = item_entry.scale
				scale_set = true
			
			item_refs.push_back(item_entry)
		
		if item_refs.size() < 2:
			push_error("Stack '%s' contains %d items, must have at least 2" % [
					section_name, item_refs.size()])
			continue
		
		# Description is optional.
		var description := ""
		if stack_config.has_section_key(section_name, "desc"):
			description = stack_config.get_value_strict(section_name, "desc", "")
		
		var stack_entry := AssetEntryCollection.new()
		stack_entry.id = section_name
		stack_entry.desc = description
		stack_entry.entry_list = item_refs
		
		pack.add_entry("stacks", stack_entry)


## Remove all of the rogue files from this pack's internal directory.
func clean_rogue_files() -> void:
	for sub_dir in _type_env_map:
		var type_env: DirectoryEnvironment = _type_env_map[sub_dir]
		type_env.type_catalog.remove_untagged()


## Run all of the import functions after using [method scan_dir], and return the
## [AssetPack] that is generated.
func perform_full_import() -> AssetPack:
	var pack := create_empty_pack()
	
	_num_files_imported = 0
	_num_files_to_import = 0
	for sub_dir in _type_env_map:
		# Before we import the files from each sub-directory, we first need to
		# figure out how many files are going to be imported so the file count
		# in the emitted signal is accurate.
		var type_env: DirectoryEnvironment = _type_env_map[sub_dir]
		_num_files_to_import += type_env.type_catalog.get_tagged().size()
	
	for sub_dir in _type_env_map:
		# Connect the 'about_to_import_file' signal here, since we only want to
		# propagate the signal within this function.
		# NOTE: It should be okay to connect the signal to this object, since it
		# should only be a weak reference, and thus it should not create a
		# cyclical reference.
		var type_env: DirectoryEnvironment = _type_env_map[sub_dir]
		type_env.type_catalog.connect("about_to_import_file", self,
				"_on_type_catalog_about_to_import_file", [ sub_dir ])
		
		import_sub_dir(pack, sub_dir)
		
		type_env.type_catalog.disconnect("about_to_import_file", self,
				"_on_type_catalog_about_to_import_file")
	
	if ImportAbortFlag.is_enabled():
		# There's a high chance that if the abort flag was enabled, not every
		# entry was scanned in, so exit now to prevent errors from occuring
		# later in the function.
		return pack
	
	create_child_entries(pack)
	
	var check_dir := Directory.new()
	for stack_sub_dir in [ "cards", "tokens/cube", "tokens/cylinder" ]:
		var stack_type: String = SUBDIRECTORY_TYPE_SCHEMA[stack_sub_dir]
		
		var sub_dir_path := _last_scan_dir_path.plus_file(stack_sub_dir)
		var stacks_cfg_path := sub_dir_path.plus_file("stacks.cfg")
		if not check_dir.file_exists(stacks_cfg_path):
			continue
		
		var stacks_cfg := AdvancedConfigFile.new()
		var err := stacks_cfg.load(stacks_cfg_path)
		if err != OK:
			push_error("Failed to load '%s' (error: %d)" % [stacks_cfg_path, err])
			continue
		
		print("%s: Reading stacks from '%s' ..." % [pack.id, stacks_cfg_path])
		read_stacks_config(pack, stacks_cfg, stack_type)
	
	# Rogue files should be cleaned across all packs at the end of the import
	# process, so there's no need to clean them after each pack.
	#clean_rogue_files()
	
	return pack


func set_pack_name(value: String) -> void:
	value = value.strip_edges().strip_escapes()
	if not value.is_valid_filename():
		push_error("'%s' is not a valid pack name")
		return
	
	pack_name = value
	_setup_pack_dir()


# Get the number of faces a die should have given the subdirectory it is in.
func _get_num_die_faces(sub_dir: String) -> int:
	match sub_dir:
		"dice/d4":
			return 4
		"dice/d6":
			return 6
		"dice/d8":
			return 8
		"dice/d10":
			return 10
		"dice/d12":
			return 12
		"dice/d20":
			return 20
		_:
			return 0


# Set the second texture override of a card entry to be the path to a texture
# within the given type directory. If the texture does not exist, or it has not
# been imported, or the name is empty, then a fallback texture is used.
func _set_card_back_face(card_entry: AssetEntryScene,
		type_catalog: AssetPackTypeCatalog, back_texture_name: String) -> void:
	
	var back_texture_path := "" # TODO: Use a fallback texture.
	
	if not back_texture_name.empty():
		if type_catalog.is_imported(back_texture_name):
			back_texture_path = type_catalog.dir_path.plus_file(back_texture_name)
		else:
			push_error("Cannot use '%s' as back face for '%s', texture has not been imported" % [
					back_texture_name, card_entry.id])
	
	card_entry.texture_overrides.resize(2)
	card_entry.texture_overrides[1] = back_texture_path


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
		var err := pack_dir.make_dir_recursive(pack_dir_path)
		if err != OK:
			push_error("Error creating pack directory at '%s' (error: %d)" % [
				pack_dir_path, err])


func _on_type_catalog_about_to_import_file(file_name: String, sub_dir: String):
	emit_signal("about_to_import_file", sub_dir.plus_file(file_name),
			_num_files_imported, _num_files_to_import)
	_num_files_imported += 1
