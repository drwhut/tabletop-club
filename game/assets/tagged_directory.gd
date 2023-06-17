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

class_name TaggedDirectory
extends Reference

## A directory with the ability to tag files.
##
## Files that are tagged within the directory have extra metadata stored about
## them in [code]user://.import[/code], which allows us to know whether a file
## is new, has been changed, or has remained the same. Furthermore, untagged
## files can be mass-removed from the directory for cleaning rogue files.


## The path to the directory containing metadata information.
const METADATA_DIR_PATH := "user://.import"

## The path to the tagged directory. Must be absolute, and within
## [code]user://assets[/code]. Must also exist on the filesystem.
var dir_path := "" setget set_dir_path

## Contains metadata about individual files in the directory.
class FileMeta:
	extends Reference
	
	## The MD5 checksum of the file before it was potentially overwritten.
	## If the value is blank, the file either did not exist before, or no
	## metadata was saved for it.
	var old_md5 := ""
	
	## The MD5 checksum of the file after import. If the value is blank, new
	## metadata about the file is not being saved.
	var new_md5 := ""

## A dictionary of tagged files in the directory and their metadata - the keys
## being the file name, and the values being the [class FileMeta].
var _tagged_meta := {}


func _init(path: String):
	set_dir_path(path)


## Get a [Directory] reference for the current [member dir_path]. Returns
## [code]null[/code] if there was an error opening the directory.
func get_dir() -> Directory:
	return _open_dir(dir_path)


## Get a [Directory] reference for the metadata folder. Returns
## [code]null[/code] if there was an error opening the directory.
static func get_metadata_dir() -> Directory:
	return _open_dir(METADATA_DIR_PATH)


func set_dir_path(value: String) -> void:
	if not value.is_abs_path():
		push_error("Directory path must be an absolute path")
		return
	
	if not value.begins_with("user://assets/"):
		push_error("Directory path must begin with 'user://assets/'")
		return
	
	if ".." in value:
		push_error("Directory path cannot contain '..'")
		return
	
	var check_dir := Directory.new()
	if not check_dir.dir_exists(value):
		push_error("Directory does not exist at '%s'" % value)
		return
	
	dir_path = value.simplify_path()
	_tagged_meta.clear()


## Tag the file with the name [code]file_name[/code] within the directory. If
## [code]save_meta[/code] is set to [code]true[/code], metadata about the file
## is saved in a separate directory, from which information about the file can
## be queried.
func tag(file_name: String, save_meta: bool) -> void:
	if not file_name.is_valid_filename():
		push_error("'%s' is not a valid file name" % file_name)
		return
	
	var file_path := dir_path.plus_file(file_name)
	var file := File.new()
	if not file.file_exists(file_path):
		push_error("File '%s' cannot be tagged, does not exist" % file_path)
		return
	
	var new_md5 := file.get_md5(file_path) if save_meta else ""
	var old_md5 := ""
	
	var md5_path := _get_meta_basename(file_name) + ".md5"
	var md5_file := File.new()
	if md5_file.file_exists(md5_path):
		if save_meta:
			var err := md5_file.open(md5_path, File.READ)
			if err == OK:
				old_md5 = md5_file.get_line()
				md5_file.close()
			else:
				push_error("Error reading old MD5 checksum of '%s' (error: %d)" % [
						file_path, err])
		else:
			var meta_dir := Directory.new()
			var err := meta_dir.remove(md5_path)
			if err != OK:
				push_error("Error removing old MD5 checksum of '%s' (error: %d)" % [
						file_path, err])
	
	if save_meta:
		var meta_dir := Directory.new()
		if not meta_dir.dir_exists(METADATA_DIR_PATH):
			var err := meta_dir.make_dir(METADATA_DIR_PATH)
			if err != OK:
				push_error("Error creating directory '%s' (error: %d)" % [
						METADATA_DIR_PATH, err])
		
		var err := md5_file.open(md5_path, File.WRITE)
		if err == OK:
			md5_file.store_line(new_md5)
			md5_file.close()
		else:
			push_error("Error saving new MD5 checksum of '%s' (error: %d)" % [
					file_path, err])
	
	var file_meta := FileMeta.new()
	file_meta.new_md5 = new_md5
	file_meta.old_md5 = old_md5
	
	_tagged_meta[file_name] = file_meta
	print("Tagged file: %s" % file_path)


## Check if the given file in the directory is tagged.
func is_tagged(file_name: String) -> bool:
	return _tagged_meta.has(file_name)


## Untag a file in the directory. Any saved metadata about the file is removed.
func untag(file_name: String) -> void:
	if not _tagged_meta.has(file_name):
		push_warning("Cannot untag '%s', has not been tagged" % file_name)
		return
	
	_tagged_meta.erase(file_name)
	print("Untagged file: %s" % dir_path.plus_file(file_name))
	
	var meta_path := _get_meta_basename(file_name) + ".md5"
	var meta_dir := Directory.new()
	if meta_dir.file_exists(meta_path):
		var err := meta_dir.remove(meta_path)
		if err != OK:
			push_error("Error removing '%s' (error: %d)" % [meta_path, err])


## Return a list of all of the tagged files in this directory.
func get_tagged() -> Array:
	return _tagged_meta.keys()


## Remove all untagged files from the directory.
func remove_untagged() -> void:
	var directory := get_dir()
	if directory == null:
		return
	
	var err := directory.list_dir_begin(true, true)
	if err != OK:
		push_error("Failed listing files in directory '%s' (error: %d)" % [
				dir_path, err])
		return
	
	var file_name := directory.get_next()
	while not file_name.empty():
		if not directory.current_is_dir():
			if not _tagged_meta.has(file_name):
				err = directory.remove(file_name)
				if err == OK:
					print("Removed rogue file: %s" % dir_path.plus_file(file_name))
				else:
					push_error("Error removing file '%s' from directory '%s' (error: %d)" % [
							file_name, dir_path, err])
		
		file_name = directory.get_next()


## Check if a tagged file in the directory is new.
func is_new(file_name: String) -> bool:
	if not _tagged_meta.has(file_name):
		push_error("Cannot check if '%s' is new, not tagged" % file_name)
		return false
	
	var md5_meta: FileMeta = _tagged_meta[file_name]
	return md5_meta.old_md5.empty()


## Check if a tagged file has changed since the last launch.
func is_changed(file_name: String) -> bool:
	if not _tagged_meta.has(file_name):
		push_error("Cannot check if '%s' has changed, not tagged" % file_name)
		return false
	
	var md5_meta: FileMeta = _tagged_meta[file_name]
	return md5_meta.new_md5 != md5_meta.old_md5


## Get the metadata stored for the given tagged file. Returns a blank [FileMeta]
## if the file has not been tagged.
func get_file_meta(file_name: String) -> FileMeta:
	if not _tagged_meta.has(file_name):
		push_error("Cannot retrieve metadata for '%s', not tagged" % file_name)
		return FileMeta.new()
	
	return _tagged_meta[file_name]


# Get the basename of the metadata file for a given filename in this directory.
func _get_meta_basename(file_name: String) -> String:
	var full_path := dir_path.plus_file(file_name)
	return METADATA_DIR_PATH.plus_file(file_name + "-" + full_path.md5_text())


# Open the directory at the given path. Return null if it could not be opened.
static func _open_dir(path: String) -> Directory:
	var dir := Directory.new()
	var err := dir.open(path)
	
	if err != OK:
		push_error("Error opening directory '%s' (error: %d)" % [path, err])
		return null
	
	return dir
