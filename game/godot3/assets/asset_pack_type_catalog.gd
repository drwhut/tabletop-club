# tabletop-club
# Copyright (c) 2020-2024 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2024 Tabletop Club contributors (see game/CREDITS.tres).
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

class_name AssetPackTypeCatalog
extends TaggedDirectory

## Used to import and catalog assets from an asset pack subdirectory.


## Emitted when a file is about to be imported in [method import_tagged].
signal about_to_import_file(file_name)


func _init(path: String).(path):
	pass


## Collect audio assets using [method collect_assets].
func collect_audio(from_dir: String) -> Array:
	return collect_assets(from_dir, SanityCheck.VALID_EXTENSIONS_AUDIO)


## Collect save files using [method collect_assets].
func collect_saves(from_dir: String) -> Array:
	return collect_assets(from_dir, SanityCheck.VALID_EXTENSIONS_SAVE)


## Collect scene assets using [method collect_assets].
func collect_scenes(from_dir: String) -> Array:
	return collect_assets(from_dir, SanityCheck.VALID_EXTENSIONS_SCENE_USER)


## Collect scene support files using [method collect_assets].
func collect_support(from_dir: String) -> Array:
	return collect_assets(from_dir, SanityCheck.VALID_EXTENSIONS_SCENE_SUPPORT)


## Collect notebook text templates using [method collect_assets].
func collect_text_templates(from_dir: String) -> Array:
	return collect_assets(from_dir, SanityCheck.VALID_EXTENSIONS_TEMPLATE_TEXT)


## Collect texture assets using [method collect_assets].
func collect_textures(from_dir: String) -> Array:
	return collect_assets(from_dir, SanityCheck.VALID_EXTENSIONS_TEXTURE)


## Collect assets from the given directory that have a specific set of
## extensions. All assets that are collected are automatically tagged.
## Returns the list of assets that were collected.
func collect_assets(from_dir: String, extension_arr: Array) -> Array:
	var scan_dir := Directory.new()
	if not scan_dir.dir_exists(from_dir):
		push_error("Error scanning '%s' for assets, does not exist" % from_dir)
		return []
	
	var err := scan_dir.open(from_dir)
	if err != OK:
		push_error("Error opening '%s' to scan assets (error: %d)" % [from_dir, err])
		return []
	
	err = scan_dir.list_dir_begin(true, true)
	if err != OK:
		push_error("Error scanning files from '%s' (error: %d)" % [from_dir, err])
		return []
	
	var scanned_assets := []
	var file_name := scan_dir.get_next()
	while not file_name.empty():
		if not scan_dir.current_is_dir():
			if file_name.get_extension() in extension_arr:
				_copy_file(from_dir, file_name)
				
				if not is_tagged(file_name):
					tag(file_name, true)
				
				scanned_assets.push_back(file_name)
		
		file_name = scan_dir.get_next()
	
	return scanned_assets


## Automatically import all of the currently tagged files in the directory.
## Any files generated from the import process are automatically tagged using
## [method tag_dependencies]. If a file has already been imported in the past,
## and its contents are unchanged, then it is not imported again.
func import_tagged() -> void:
	var tagged_arr := get_tagged()
	for tagged_file in tagged_arr:
		if ImportAbortFlag.is_enabled():
			break
		
		emit_signal("about_to_import_file", tagged_file)
		
		if not tagged_file.get_extension() in SanityCheck.VALID_EXTENSIONS_IMPORT:
			continue
		
		var import_file_name: String = tagged_file + ".import"
		
		if is_new(tagged_file) or is_changed(tagged_file) or \
				(not is_imported(tagged_file)):
			var import_err := import_file(tagged_file)
			if import_err != OK:
				# The file failed to import, but there may still be a .import
				# file from a previous import. We need to delete it in order to
				# get is_imported() to return false.
				var type_dir := get_dir()
				if type_dir.file_exists(import_file_name):
					if is_tagged(import_file_name):
						untag(import_file_name)
					
					var err := type_dir.remove(import_file_name)
					if err != OK:
						push_error("Failed to delete '%s' (error: %d)" % [
								import_file_name, err])
				
				# Untag the file so it is removed as a rogue file at the end of
				# the import process.
				untag(tagged_file)
				
				continue
		
		# The importing process will always generate a ".import" file next to
		# the original, so the engine knows where to look for the imported data.
		tag(import_file_name, false)
		
		# The original file is already tagged, but make sure to tag any files
		# that it depends on so they do not get removed.
		tag_dependencies(tagged_file)


## Import a file from [code]dir_path[/code] using the custom module. Note that
## this function does not automatically tag the file or any of its dependencies.
## Returns an error code.
func import_file(file_name: String) -> int:
	if not CustomModule.is_loaded():
		push_error("Cannot import '%s', custom module is not loaded" % file_name)
		return ERR_UNAVAILABLE
	
	if not file_name.is_valid_filename():
		push_error("Error importing '%s', invalid file name" % file_name)
		return ERR_INVALID_PARAMETER
	
	if not file_name.get_extension() in SanityCheck.VALID_EXTENSIONS_IMPORT:
		push_error("Error importing '%s', extension is not importable" % file_name)
		return ERR_INVALID_PARAMETER
	
	var file_path := dir_path.plus_file(file_name)
	var file := File.new()
	if not file.file_exists(file_path):
		push_error("Error importing '%s', file does not exist" % file_path)
		return ERR_FILE_NOT_FOUND
	
	print("Importing: %s" % file_path)
	
	# TODO: If files are deleted from the main directory, then files generated
	# from importing will stay in user://.import - there should be a way to
	# clean these files, probably in a higher-order class.
	
	var import_basename := _get_meta_basename(file_name)
	var err: int = CustomModule.tabletop_importer.call("import", file_path,
			import_basename, {})
	if err != OK:
		push_error("Error importing '%s' (error: %d)" % [file_path, err])
		return err
	
	return OK


## Check if the given file has been imported properly. This function is mainly
## used for testing, and is slightly more robust than
## [code]ResourceLoader.exists[/code].
func is_imported(file_name: String) -> bool:
	if not file_name.is_valid_filename():
		push_warning("Cannot check if '%s' was imported, not a valid file name" % file_name)
		return false
	
	var this_dir := get_dir()
	if not this_dir.file_exists(file_name):
		push_warning("Cannot check if '%s' was imported, file does not exist" % file_name)
		return false
	
	if not this_dir.file_exists(file_name + ".import"):
		return false
	
	var import_file := ConfigFile.new()
	var import_file_path := dir_path.plus_file(file_name + ".import")
	var err := import_file.load(import_file_path)
	if err != OK:
		push_error("Failed to load '%s' (error: %d)" % [import_file_path, err])
		return false
	
	var remap_keys := import_file.get_section_keys("remap")
	var num_paths := 0
	for key in remap_keys:
		if not key.begins_with("path"):
			continue
		
		var path = import_file.get_value("remap", key, "")
		if not path is String:
			return false
		if path.empty():
			return false
		if not this_dir.file_exists(path):
			return false
		
		num_paths += 1
	
	return num_paths > 0


## Recursively tag the given file and all of its dependencies, if it has not
## already been tagged. This will prevent generated files from being deleted by
## [method TaggedDirectory.remove_untagged]. Note that metadata is not stored
## when these files are tagged, as they should be files generated from an
## imported asset, which does have stored metadata.
func tag_dependencies(file_name: String) -> void:
	if not is_tagged(file_name):
		tag(file_name, false)
	
	# The file needs to be a resource to have dependencies.
	var file_path := dir_path.plus_file(file_name)
	if not ResourceLoader.exists(file_path):
		return
	
	var dependencies := ResourceLoader.get_dependencies(file_path)
	for dependency_path in dependencies:
		# We expect all of the paths to be absolute.
		if not dependency_path.is_abs_path():
			push_warning("Dependency path '%s' is not absolute, ignoring" % dependency_path)
			continue
		
		# The dependency should be in the same directory as the original file.
		if dependency_path.get_base_dir() != dir_path:
			push_warning("Dependency path '%s' is not in expected directory '%s', ignoring" % [
					dependency_path, dir_path])
			continue
		
		tag_dependencies(dependency_path.get_file())


## Setup the given scene entry with the information needed to build it later on.
## If [code]texture_path[/code] is not empty, it is added to the entry as the
## only texture override.
func setup_scene_entry(entry: AssetEntryScene, scene_path: String,
		geo_data: GeoData, texture_path: String = "") -> void:
	
	entry.scene_path = scene_path
	if not texture_path.empty():
		entry.texture_overrides = [ texture_path ]
	
	entry.avg_point = geo_data.average_vertex()
	entry.bounding_box = geo_data.bounding_box


## Setup the given scene entry using a custom imported scene in this directory.
## This function will automatically call [method scan_scene_geometry], and will
## save the results to a [code].geo[/code] file next to the scene file. If this
## file already exists when this function is called, and the original scene has
## not changed since the last import, then the file is read directly.
func setup_scene_entry_custom(entry: AssetEntryScene, scene_file_name: String) -> void:
	if not scene_file_name.get_extension() in SanityCheck.VALID_EXTENSIONS_SCENE_USER:
		push_error("Cannot setup entry for '%s', invalid extension" % scene_file_name)
		return
	
	# Also proves that the file exists.
	if not is_imported(scene_file_name):
		push_error("Cannot setup entry for '%s', not imported" % scene_file_name)
		return
	
	var scene_file_path := dir_path.plus_file(scene_file_name)
	
	var geo_data := GeoData.new()
	var geo_data_use_cache := false
	var geo_file_name := scene_file_name + ".geo"
	var geo_file_path := dir_path.plus_file(geo_file_name)
	
	if not (is_new(scene_file_name) or is_changed(scene_file_name)):
		if ResourceLoader.exists(geo_file_path):
			# We should only load this data in once during the import process,
			# so don't bother caching the resource in ResourceLoader.
			print("Loading cached scan results from %s ..." % geo_file_name)
			var cached_data := ResourceLoader.load(geo_file_path, "Resource",
					true) as GeoData
			
			if cached_data != null:
				geo_data = cached_data
				geo_data_use_cache = true
				
				# Tag the file so it doesn't get removed as a rogue file.
				tag(geo_file_name, false)
			else:
				push_error("Failed to load geometry data from '%s'" % geo_file_path)
	
	if not geo_data_use_cache:
		# TODO: Since this should be run inside a thread, we need to be really
		# careful about what resources we are loading, as they can be both
		# loaded and freed in the main thread. Looking at the source code, it
		# looks like forcing no cache loading may work, as it should just load
		# the resource from scratch every time as unique references.
		var packed_scene := ResourceLoader.load(scene_file_path, "PackedScene",
				true) as PackedScene
		
		if packed_scene != null:
			var scene := packed_scene.instance()
			
			if scene is Spatial:
				print("Scanning the geometry of %s ..." % scene_file_name)
				geo_data = scan_scene_geometry(scene)
				print("Saving scan results to %s ..." % geo_file_name)
				var err := ResourceSaver.save(geo_file_path, geo_data)
				if err == OK:
					# Tag the file so it doesn't get removed as a rogue file.
					tag(geo_file_name, false)
				else:
					push_error("Failed to save geometry data to '%s' (error: %d)" % [
							geo_file_path, err])
			else:
				push_error("Expected root node of '%s' to be a Spatial" % scene_file_path)
				return
			
			scene.free()
		else:
			push_error("Failed to load scene from '%s'" % scene_file_path)
			return
	
	setup_scene_entry(entry, scene_file_path, geo_data)


## Scan the given scene in its entirety (that is, recursively through the node
## structure) to calculate the geometry metadata for that scene.
static func scan_scene_geometry(node: Spatial,
		parent_transform: Transform = Transform.IDENTITY) -> GeoData:
	
	var new_basis := node.transform.basis * parent_transform.basis
	var new_origin := node.transform.origin + parent_transform.origin
	var new_transform := Transform(new_basis, new_origin)
	
	var out := GeoData.new()
	var set_initial_box := true

	if node is MeshInstance:
		var mesh: Mesh = node.mesh
		for surface in range(mesh.get_surface_count()):
			var vert_arr: Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			out.vertex_count += vert_arr.size()
			
			for vertex in vert_arr:
				var adj_vertex: Vector3 = new_transform * vertex
				out.vertex_sum += adj_vertex
				
				if set_initial_box:
					out.bounding_box = AABB(adj_vertex, Vector3.ZERO)
					set_initial_box = false
				else:
					out.bounding_box = out.bounding_box.expand(adj_vertex)
	
	for child in node.get_children():
		if child is Spatial:
			var child_data := scan_scene_geometry(child, new_transform)
			if child_data.vertex_count == 0:
				continue
			
			out.vertex_count += child_data.vertex_count
			out.vertex_sum += child_data.vertex_sum
			
			if set_initial_box:
				out.bounding_box = child_data.bounding_box
				set_initial_box = false
			else:
				out.bounding_box = out.bounding_box.merge(child_data.bounding_box)
	
	return out


## Apply the properties of a config.cfg file to the given entry.
## [code]full_name[/code] is used to decide which sections of the file to get
## properties from.
func apply_config_to_entry(entry: AssetEntrySingle, config: AdvancedConfigFile,
		full_name: String, scale_is_vec2: bool, die_num_faces: int) -> void:
	
	# TODO: Make sure any errors that come up (either from the config file, or
	# from the entry itself) are stored in the entry.
	print("Configuring: %s" % full_name)
	
	entry.id = config.get_value_by_matching(full_name, "name",
			full_name.get_basename(), true)
	entry.desc = config.get_value_by_matching(full_name, "desc", "", true)
	
	entry.author = config.get_value_by_matching(full_name, "author", "", true)
	entry.license = config.get_value_by_matching(full_name, "license", "", true)
	entry.modified_by = config.get_value_by_matching(full_name, "modified_by",
			"", true)
	entry.url = config.get_value_by_matching(full_name, "url", "", true)
	
	# TODO: Ideally would use elif's here, but due to how the autocompletion
	# works, it won't show the subclass's properties. Change once the editor
	# has improved in this regard.
	
	if entry is AssetEntryAudio:
		pass # Everything is determined by the directory the track is in.
	
	if entry is AssetEntrySave:
		pass
	
	if entry is AssetEntryScene:
		var color_str: String = config.get_value_by_matching(full_name, "color",
				"#ffffff", true)
		if color_str.is_valid_html_color():
			entry.albedo_color = Color(color_str)
		else:
			push_error("%s: '%s' is not a valid color" % [full_name, color_str])
		
		# TODO: Throw a warning if values like these are invalid? From within
		# the class itself or here?
		entry.mass = config.get_value_by_matching(full_name, "mass", 1.0, true)
		
		if scale_is_vec2:
			var scale = config.get_value_by_matching(full_name, "scale",
					Vector2.ONE, false)
			var scale_type := typeof(scale)
			
			if scale_type == TYPE_VECTOR2:
				entry.scale = Vector3(scale.x, 1.0, scale.y)
			elif scale_type == TYPE_VECTOR3:
				push_warning("%s: Expected a Vector2 for 'scale' property, received a Vector3 - ignoring Y-scale" % full_name)
				entry.scale = Vector3(scale.x, 1.0, scale.z)
			else:
				push_error("%s: Value of 'scale' is incorrect data type (expected: Vector2, got: %s)" % [
						full_name, SanityCheck.get_type_name(scale_type)])
				entry.scale = Vector3.ONE
		else:
			entry.scale = config.get_value_by_matching(full_name, "scale",
					Vector3.ONE, true)
		
		# Now that we know the scale, we can use it to automatically adjust the
		# meta-properties of the scene.
		entry.avg_point *= entry.scale
		var old_aabb: AABB = entry.bounding_box
		entry.bounding_box = AABB(entry.scale * old_aabb.position,
				entry.scale * old_aabb.size)
		
		if entry.scene_path.begins_with("res://"):
			# In-built scenes should already be configured with the correct
			# collision shape and centre-of-mass, so do not allow the player
			# to modify these.
			entry.collision_type = AssetEntryScene.CollisionType.COLLISION_NONE
			entry.com_adjust = AssetEntryScene.ComAdjust.COM_ADJUST_OFF
		else:
			var collision_cfg: int = config.get_value_by_matching(full_name,
					"collision_mode", 0, true)
			match collision_cfg:
				0:
					entry.collision_type = AssetEntryScene.CollisionType.COLLISION_CONVEX
				1:
					entry.collision_type = AssetEntryScene.CollisionType.COLLISION_MULTI_CONVEX
				2:
					entry.collision_type = AssetEntryScene.CollisionType.COLLISION_CONCAVE
				_:
					push_error("%s: Invalid value '%d' for property 'collision_mode'" % [
							full_name, collision_cfg])
					entry.collision_type = AssetEntryScene.CollisionType.COLLISION_CONVEX
			
			var com_cfg: String = config.get_value_by_matching(full_name,
					"com_adjust", "volume", true)
			match com_cfg:
				"off":
					entry.com_adjust = AssetEntryScene.ComAdjust.COM_ADJUST_OFF
				"volume":
					entry.com_adjust = AssetEntryScene.ComAdjust.COM_ADJUST_VOLUME
				"geometry":
					entry.com_adjust = AssetEntryScene.ComAdjust.COM_ADJUST_GEOMETRY
				_:
					push_error("%s: Invalid value '%s' for property 'com_adjust'" % [
							full_name, com_cfg])
					entry.com_adjust = AssetEntryScene.ComAdjust.COM_ADJUST_VOLUME
		
		# TODO: Allow all properties of the physics material to be configured.
		var default_phys_mat := preload("res://assets/default_physics_material.tres")
		
		# To save on memory, if the properties aren't changed, then just use the
		# default resource. If a property is changed, the resource will need to
		# be duplicated as to not overwrite the original resource.
		var scene_phys_mat := default_phys_mat
		
		var new_bounce: float = config.get_value_by_matching(full_name,
				"bounce", 0.0, true)
		if new_bounce != default_phys_mat.bounce:
			if scene_phys_mat == default_phys_mat:
				scene_phys_mat = scene_phys_mat.duplicate()
			scene_phys_mat.bounce = min(max(new_bounce, 0.0), 1.0)
		
		entry.physics_material = scene_phys_mat
		
		# TODO: If sound effects have already been configured for this entry,
		# then we do not allow the player to change them. Would it make sense
		# for the player to be able to change the SFX of, say, cards?
		var has_fast_sounds: bool = entry.collision_fast_sounds.has_stream()
		var has_slow_sounds: bool = entry.collision_slow_sounds.has_stream()
		
		if not (has_fast_sounds or has_slow_sounds):
			var fast_sfx: AudioStreamList
			var slow_sfx: AudioStreamList
			
			var sfx_cfg: String = config.get_value_by_matching(full_name, "sfx",
					"generic", true)
			match sfx_cfg:
				"generic":
					fast_sfx = preload("res://sounds/generic/generic_fast_sounds.tres")
					slow_sfx = preload("res://sounds/generic/generic_slow_sounds.tres")
				"glass":
					fast_sfx = preload("res://sounds/glass/glass_fast_sounds.tres")
					slow_sfx = preload("res://sounds/glass/glass_slow_sounds.tres")
				"glass_heavy":
					fast_sfx = preload("res://sounds/glass_heavy/glass_heavy_fast_sounds.tres")
					slow_sfx = preload("res://sounds/glass_heavy/glass_heavy_slow_sounds.tres")
				"glass_light":
					fast_sfx = preload("res://sounds/glass_light/glass_light_fast_sounds.tres")
					slow_sfx = preload("res://sounds/glass_light/glass_light_slow_sounds.tres")
				"metal":
					fast_sfx = preload("res://sounds/metal/metal_fast_sounds.tres")
					slow_sfx = preload("res://sounds/metal/metal_slow_sounds.tres")
				"metal_heavy":
					fast_sfx = preload("res://sounds/metal_heavy/metal_heavy_fast_sounds.tres")
					slow_sfx = preload("res://sounds/metal_heavy/metal_heavy_slow_sounds.tres")
				"metal_light":
					fast_sfx = preload("res://sounds/metal_light/metal_light_fast_sounds.tres")
					slow_sfx = preload("res://sounds/metal_light/metal_light_slow_sounds.tres")
				"soft":
					fast_sfx = preload("res://sounds/soft/soft_fast_sounds.tres")
					slow_sfx = preload("res://sounds/soft/soft_slow_sounds.tres")
				"soft_heavy":
					fast_sfx = preload("res://sounds/soft_heavy/soft_heavy_fast_sounds.tres")
					slow_sfx = preload("res://sounds/soft_heavy/soft_heavy_slow_sounds.tres")
				"tin":
					fast_sfx = preload("res://sounds/tin/tin_fast_sounds.tres")
					slow_sfx = preload("res://sounds/tin/tin_slow_sounds.tres")
				"wood":
					fast_sfx = preload("res://sounds/wood/wood_fast_sounds.tres")
					slow_sfx = preload("res://sounds/wood/wood_slow_sounds.tres")
				"wood_heavy":
					fast_sfx = preload("res://sounds/wood_heavy/wood_heavy_fast_sounds.tres")
					slow_sfx = preload("res://sounds/wood_heavy/wood_heavy_slow_sounds.tres")
				"wood_light":
					fast_sfx = preload("res://sounds/wood_light/wood_light_fast_sounds.tres")
					slow_sfx = preload("res://sounds/wood_light/wood_light_slow_sounds.tres")
				_:
					push_error("%s: Invalid value '%s' for property 'sfx'" % [
							full_name, sfx_cfg])
					fast_sfx = preload("res://sounds/generic/generic_fast_sounds.tres")
					slow_sfx = preload("res://sounds/generic/generic_slow_sounds.tres")
			
			entry.collision_fast_sounds = fast_sfx
			entry.collision_slow_sounds = slow_sfx
		
		if entry is AssetEntryContainer:
			entry.shakable = config.get_value_by_matching(full_name, "shakable",
					false, true)
		
		if entry is AssetEntryDice:
			var value_dict: Dictionary = config.get_value_by_matching(full_name,
					"face_values", {}, true)
			
			var face_value_list_raw := []
			for key in value_dict:
				var value = value_dict[key]
				
				var face_normal := Vector3.UP
				var face_rot_deg := Vector2.ZERO
				var face_use_euler := false
				var custom_value := CustomValue.new()
				
				if key is Vector2:
					face_rot_deg = key
					face_use_euler = true
					custom_value.set_value_variant(value)
				elif key is Vector3:
					face_normal = key
					custom_value.set_value_variant(value)
				else:
					# This is for backwards compatibility with v0.1.x, where the
					# keys were the face values, and the values were the face
					# rotations. This method forced unique face values, which
					# is why the values have now been swapped as of v0.2.0
					push_warning("%s: The VALUE: ROTATION notation for 'face_values' is deprecated as of v0.2.0 - consider changing to ROTATION: VALUE" % full_name)
					
					custom_value.set_value_variant(key)
					if value is Vector2:
						face_rot_deg = value
						face_use_euler = true
					else:
						push_error("%s: Rotation value in 'face_values' is not a Vector2" % full_name)
						continue
				
				var face_value := DiceFaceValue.new()
				if face_use_euler:
					var face_rot_rad := Vector2(deg2rad(face_rot_deg.x),
							deg2rad(face_rot_deg.y))
					
					if not SanityCheck.is_valid_vector2(face_rot_rad):
						push_error("%s: Vector2 in 'face_values' contains invalid data" % full_name)
						continue
					
					face_value.set_normal_with_euler(face_rot_rad.x, face_rot_rad.y)
				else:
					if not SanityCheck.is_valid_vector3(face_normal):
						push_error("%s: Vector3 in 'face_values' contains invalid data" % full_name)
						continue
					
					if is_zero_approx(face_normal.length_squared()):
						push_error("%s: Face normal vector length cannot be 0" % full_name)
						continue
					
					face_value.normal = face_normal
				
				face_value.value = custom_value
				face_value_list_raw.push_back(face_value)
			
			if face_value_list_raw.size() != die_num_faces:
				push_warning("%s: 'face_values' size was not the expected value (expected: %d, got: %d)" % [
						full_name, die_num_faces, face_value_list_raw.size()])
			
			if face_value_list_raw.empty():
				var current_list: DiceFaceValueList = entry.face_value_list
				var current_list_raw: Array = current_list.face_value_list
				
				# Only replace the default resource if we need to, there's no
				# point in making a bunch of empty instances.
				if not current_list_raw.empty():
					entry.face_value_list = DiceFaceValueList.new()
			else:
				var res_list := DiceFaceValueList.new()
				res_list.face_value_list = face_value_list_raw
				entry.face_value_list = res_list
		
		if entry is AssetEntryStackable:
			var suit_cfg = config.get_value_by_matching(full_name, "suit", null,
					false)
			var suit_custom_value := CustomValue.new()
			suit_custom_value.set_value_variant(suit_cfg)
			entry.user_suit = suit_custom_value
			
			var value_cfg = config.get_value_by_matching(full_name, "value",
					null, false)
			var value_custom_value := CustomValue.new()
			value_custom_value.set_value_variant(value_cfg)
			entry.user_value = value_custom_value
		
		if entry is AssetEntryTable:
			var hand_cfg: Array = config.get_value_by_matching(full_name,
					"hands", [], true)
			
			var hand_transform_arr := []
			for hand_dict in hand_cfg:
				if not hand_dict is Dictionary:
					push_error("%s: Element of 'hands' is invalid, not a dictionary" % full_name)
					continue
				
				var parser := DictionaryParser.new(hand_dict)
				var hand_pos: Vector3 = parser.get_strict_type("pos", Vector3.ZERO)
				var hand_rot_deg: float = parser.get_strict_type("dir", 0.0)
				
				if not SanityCheck.is_valid_vector3(hand_pos):
					push_error("%s: Value of 'pos' is invalid" % full_name)
					continue
				if not SanityCheck.is_valid_float(hand_rot_deg):
					push_error("%s: Value of 'dir' is invalid" % full_name)
					continue
				
				var hand_transform := Transform.IDENTITY
				hand_transform = hand_transform.rotated(Vector3.UP,
						deg2rad(hand_rot_deg))
				hand_transform.origin = hand_pos
				hand_transform_arr.push_back(hand_transform)
			
			if hand_transform_arr.empty():
				push_warning("%s: Table has no configured hand positions, consider adding at least one via the 'config.cfg' file" % full_name)
			entry.hand_transforms = hand_transform_arr
			
			# TODO: Make this a constant somewhere else?
			var default_plane_size := Vector2(100.0, 100.0)

			var paint_plane_size: Vector2 = config.get_value_by_matching(
					full_name, "paint_plane", default_plane_size, true)
			if SanityCheck.is_valid_vector2(paint_plane_size):
				paint_plane_size = paint_plane_size.abs()
			else:
				push_error("%s: 'paint_plane' contains invalid data" % full_name)
				paint_plane_size = default_plane_size
			
			var paint_plane_transform := Transform.IDENTITY
			paint_plane_transform = paint_plane_transform.scaled(Vector3(
					paint_plane_size.x, 1.0, paint_plane_size.y))
			entry.paint_plane_transform = paint_plane_transform
	
	
	if entry is AssetEntrySkybox:
		entry.energy = config.get_value_by_matching(full_name, "strength", 1.0, true)
		
		var rot_deg: Vector3 = config.get_value_by_matching(full_name,
				"rotation", Vector3.ZERO, true)
		var rot_rad := Vector3(deg2rad(rot_deg.x), deg2rad(rot_deg.y),
				deg2rad(rot_deg.z))
		entry.rotation = rot_rad
	
	if entry is AssetEntryTemplate:
		if entry is AssetEntryTemplateImage:
			var textbox_arr := []
			var textbox_input = config.get_value_by_matching(full_name,
					"textboxes", [], false)
			
			if textbox_input is Array:
				textbox_arr = textbox_input
			elif textbox_input is Dictionary:
				push_warning("%s: 'textboxes' is now an array as of v0.2.0, ignoring keys" % full_name)
				textbox_arr = textbox_input.values()
			else:
				push_error("%s: 'textboxes' is invalid data type (expected: Array, got: %s)" % [
						full_name, SanityCheck.get_type_name(typeof(textbox_input))])
			
			entry.textbox_list = []
			for textbox_meta in textbox_arr:
				if not textbox_meta is Dictionary:
					push_warning("%s: Element of 'textboxes' array is not a dictionary, ignoring" % full_name)
					continue
				
				var new_textbox := TemplateTextbox.new()
				var parser := DictionaryParser.new(textbox_meta)
				
				# TODO: Do we want to check the image size here, even though
				# the textbox can be rotated?
				var x: int = parser.get_strict_type("x", 0)
				var y: int = parser.get_strict_type("y", 0)
				var w: int = parser.get_strict_type("w", 100)
				var h: int = parser.get_strict_type("h", 100)
				new_textbox.rect = Rect2(x, y, w, h)
				
				new_textbox.rotation = parser.get_strict_type("rot", 0.0)
				new_textbox.lines = parser.get_strict_type("lines", 1)
				new_textbox.text = parser.get_strict_type("text", "")
				
				entry.textbox_list.push_back(new_textbox)
		
		if entry is AssetEntryTemplateText:
			pass


## Write the configurable properties of an entry to the given configuration
## file. This function is essentially the reverse of [method apply_config_to_entry].
func write_entry_to_config(entry: AssetEntrySingle, config: AdvancedConfigFile,
		section: String, scale_is_vec2: bool) -> void:
	
	config.set_value(section, "name", entry.id)
	config.set_value(section, "desc", entry.desc)
	
	config.set_value(section, "author", entry.author)
	config.set_value(section, "license", entry.license)
	config.set_value(section, "modified_by", entry.modified_by)
	config.set_value(section, "url", entry.url)
	
	# TODO: Ideally would use elif's here, but due to how the autocompletion
	# works, it won't show the subclass's properties. Change once the editor
	# has improved in this regard.
	
	if entry is AssetEntryAudio:
		pass # Everything is determined by the directory the track is in.
	
	if entry is AssetEntrySave:
		pass
	
	if entry is AssetEntryScene:
		config.set_value(section, "color", entry.albedo_color.to_html(false))
		config.set_value(section, "mass", entry.mass)
		
		var scale_config = Vector2(entry.scale.x, entry.scale.z) \
				if scale_is_vec2 else entry.scale
		config.set_value(section, "scale", scale_config)
		
		if not entry.scene_path.begins_with("res://"):
			var collision_config := 0
			match entry.collision_type:
				AssetEntryScene.CollisionType.COLLISION_CONVEX:
					collision_config = 0
				AssetEntryScene.CollisionType.COLLISION_MULTI_CONVEX:
					collision_config = 1
				AssetEntryScene.CollisionType.COLLISION_CONCAVE:
					collision_config = 2
			config.set_value(section, "collision_mode", collision_config)
			
			var com_config := "volume"
			match entry.com_adjust:
				AssetEntryScene.ComAdjust.COM_ADJUST_OFF:
					com_config = "off"
				AssetEntryScene.ComAdjust.COM_ADJUST_VOLUME:
					com_config = "volume"
				AssetEntryScene.ComAdjust.COM_ADJUST_GEOMETRY:
					com_config = "geometry"
			config.set_value(section, "com_adjust", com_config)
		
		config.set_value(section, "bounce", entry.physics_material.bounce)
		
		var sfx_config := ""
		match entry.collision_fast_sounds.resource_path:
			"res://sounds/generic/generic_fast_sounds.tres":
				sfx_config = "generic"
			"res://sounds/glass/glass_fast_sounds.tres":
				sfx_config = "glass"
			"res://sounds/glass_heavy/glass_heavy_fast_sounds.tres":
				sfx_config = "glass_heavy"
			"res://sounds/glass_light/glass_light_fast_sounds.tres":
				sfx_config = "glass_light"
			"res://sounds/metal/metal_fast_sounds.tres":
				sfx_config = "metal"
			"res://sounds/metal_heavy/metal_heavy_fast_sounds.tres":
				sfx_config = "metal_heavy"
			"res://sounds/metal_light/metal_light_fast_sounds.tres":
				sfx_config = "metal_light"
			"res://sounds/soft/soft_fast_sounds.tres":
				sfx_config = "soft"
			"res://sounds/soft_heavy/soft_heavy_fast_sounds.tres":
				sfx_config = "soft_heavy"
			"res://sounds/tin/tin_fast_sounds.tres":
				sfx_config = "tin"
			"res://sounds/wood/wood_fast_sounds.tres":
				sfx_config = "wood"
			"res://sounds/wood_heavy/wood_heavy_fast_sounds.tres":
				sfx_config = "wood_heavy"
			"res://sounds/wood_light/wood_light_fast_sounds.tres":
				sfx_config = "wood_light"
		
		if not sfx_config.empty():
			config.set_value(section, "sfx", sfx_config)
		
		if entry is AssetEntryContainer:
			config.set_value(section, "shakable", entry.shakable)
		
		if entry is AssetEntryDice:
			var face_value_config := {}
			var face_value_list_ref: DiceFaceValueList = entry.face_value_list
			for face_value_pair in face_value_list_ref.face_value_list:
				var face_normal: Vector3 = face_value_pair.normal
				var face_value: CustomValue = face_value_pair.value
				face_value_config[face_normal] = face_value.get_value_variant()
			config.set_value(section, "face_values", face_value_config)
		
		if entry is AssetEntryStackable:
			config.set_value(section, "suit", entry.user_suit.get_value_variant())
			config.set_value(section, "value", entry.user_value.get_value_variant())
		
		if entry is AssetEntryTable:
			var hands_config := []
			for hand_transform in entry.hand_transforms:
				var basis: Basis = hand_transform.basis
				var origin: Vector3 = hand_transform.origin
				
				# angle_to gives a value between 0 and PI/2, but that alone does
				# not tell us if the direction was CW or CCW.
				var angle_to_x := Vector3.RIGHT.angle_to(basis.x)
				if basis.x.z > 0.0:
					angle_to_x *= -1.0
				
				hands_config.push_back({
					"pos": origin,
					"dir": rad2deg(angle_to_x)
				})
			config.set_value(section, "hands", hands_config)
			
			var paint_plane_basis: Basis = entry.paint_plane_transform.basis
			var scale_as_vec2 := Vector2(paint_plane_basis.x.x, paint_plane_basis.z.z)
			config.set_value(section, "paint_plane", scale_as_vec2)
	
	if entry is AssetEntrySkybox:
		config.set_value(section, "strength", entry.energy)
		var rot_deg := Vector3(rad2deg(entry.rotation.x),
				rad2deg(entry.rotation.y), rad2deg(entry.rotation.z))
		config.set_value(section, "rotation", rot_deg)
	
	if entry is AssetEntryTemplate:
		if entry is AssetEntryTemplateImage:
			var textboxes_config := []
			for textbox in entry.textbox_list:
				var textbox_rect: Rect2 = textbox.rect
				var textbox_rot_deg: float = textbox.rotation
				var textbox_lines: int = textbox.lines
				var textbox_default_text: String = textbox.text
				
				textboxes_config.push_back({
					"x": int(textbox_rect.position.x),
					"y": int(textbox_rect.position.y),
					"w": int(textbox_rect.size.x),
					"h": int(textbox_rect.size.y),
					"rot": textbox_rot_deg,
					"lines": textbox_lines,
					"text": textbox_default_text
				})
			config.set_value(section, "textboxes", textboxes_config)
		
		if entry is AssetEntryTemplateText:
			pass


# Copy a file from from_dir to dir_path, but only if necessary.
func _copy_file(from_dir: String, file_name: String) -> void:
	var src_path := from_dir.plus_file(file_name)
	var dst_path := dir_path.plus_file(file_name)
	
	var file := File.new()
	var src_md5 := file.get_md5(src_path)
	var dst_md5 := ""
	if file.file_exists(dst_path):
		dst_md5 = file.get_md5(dst_path)
	
	if src_md5 != dst_md5:
		var dir := Directory.new()
		dir.copy(src_path, dst_path)
		print("Copied: %s -> %s" % [src_path, dst_path])
