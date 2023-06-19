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

class_name AssetPackTypeCatalog
extends TaggedDirectory

## Used to import and catalog assets from an asset pack subdirectory.


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


## Collect notebook templates using [method collect_assets].
func collect_templates(from_dir: String) -> Array:
	return collect_assets(from_dir, SanityCheck.VALID_EXTENSIONS_TEMPLATE_IMAGE +
			SanityCheck.VALID_EXTENSIONS_TEMPLATE_TEXT)


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
## If a file has already been imported from before, it is skipped.
func import_tagged() -> void:
	var tagged_arr := get_tagged()
	for tagged_file in tagged_arr:
		if not tagged_file.get_extension() in SanityCheck.VALID_EXTENSIONS_IMPORT:
			continue
		
		# TODO: Check if ResourceLoader.exists() detects if the imported file
		# has disappaeared or not, and if it returns true before importing.
		var tagged_path := dir_path.plus_file(tagged_file)
		if ResourceLoader.exists(tagged_path) and not (is_new(tagged_file) or \
				is_changed(tagged_file)):
			continue
		
		import_file(tagged_file)


## Import a file from [code]dir_path[/code] using the custom module. The file
## itself, as well as any dependencies of the file (e.g. material files), are
## automatically tagged if they are not already. Returns an error code.
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
	
	var import_basename := _get_meta_basename(file_name)
	var err: int = CustomModule.tabletop_importer.import(file_path, import_basename, {})
	if err != OK:
		push_error("Error importing '%s' (error: %d)" % [file_path, err])
		return err
	
	var files_to_tag := [file_path]
	while not files_to_tag.empty():
		var current_path: String = files_to_tag.pop_front()
		if not current_path.is_abs_path():
			push_warning("Dependency path '%s' is not absolute, ignoring" % current_path)
			continue
		
		if current_path.get_base_dir() != dir_path:
			push_warning("Dependency path '%s' is not in expected directory '%s', ignoring" % [
					current_path, dir_path])
			continue
		
		var current_name := current_path.get_file()
		if not is_tagged(current_name):
			# No need to store metadata about generated files, as they will
			# change anyway if the original file changes.
			tag(current_name, false)
		
		# The file needs to be a valid resource to have dependencies.
		if not ResourceLoader.exists(current_path):
			continue
		
		var file_deps := ResourceLoader.get_dependencies(current_path)
		files_to_tag.append_array(file_deps)
	
	return OK


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
