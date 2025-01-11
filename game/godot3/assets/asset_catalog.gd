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

class_name AssetCatalog
extends Reference

## Scan folders for asset packs.
##
## By scanning a given folder, this will create a series of [AssetPackCatalog]
## instances, which can then be used to import and register the assets from all
## of the different asset packs at once.


## Emitted when a pack is about to be imported in [method import_all].
signal about_to_import_pack(pack_name, pack_index, pack_count)

## Emitted when a file is about to be imported in [method import_all].
signal about_to_import_file(file_path, file_index, file_count)


# The internal list of AssetPackCatalog from which assets are imported.
# TODO: Make typed in 4.x
var _pack_catalogs: Array = []


func _init():
	var internal_assets_dir := Directory.new()
	if not internal_assets_dir.dir_exists("user://assets"):
		return
	
	var err := internal_assets_dir.open("user://assets")
	if err != OK:
		push_error("Failed to open 'user://assets' (error: %d)" % err)
		return
	
	err = internal_assets_dir.list_dir_begin(true, true)
	if err != OK:
		push_error("Failed to list contents from 'user://assets' (error: %d)" % err)
		return
	
	var dir_name := internal_assets_dir.get_next()
	while not dir_name.empty():
		if internal_assets_dir.current_is_dir():
			var pack_catalog := AssetPackCatalog.new(dir_name)
			_pack_catalogs.push_back(pack_catalog)
		
		dir_name = internal_assets_dir.get_next()


## Get the [AssetPackCatalog] for the pack with the given name. Returns
## [code]null[/code] if the catalog does not exist.
func get_pack_catalog(pack_name: String) -> AssetPackCatalog:
	for pack_catalog in _pack_catalogs:
		if pack_catalog.pack_name == pack_name:
			return pack_catalog
	
	return null


## Scan the external directory for custom asset packs.
func scan_external_dir() -> void:
	scan_dir_for_packs(ExternalDirectory.open_sub_dir("assets"))


## Scan the given directory for custom asset packs.
func scan_dir_for_packs(dir: Directory) -> void:
	var scan_path := dir.get_current_dir()
	print("Scanning for packs: %s" % scan_path)
	
	var err := dir.list_dir_begin(true, true)
	if err != OK:
		push_error("Failed to list contents of '%s' (error: %d)" % [
				dir.get_current_dir(), err])
		return
	
	var dir_name := dir.get_next()
	while not dir_name.empty():
		if dir.current_is_dir():
			var pack_catalog := get_pack_catalog(dir_name)
			if pack_catalog == null:
				pack_catalog = AssetPackCatalog.new(dir_name)
				_pack_catalogs.push_back(pack_catalog)
			
			pack_catalog.scan_dir(scan_path.plus_file(dir_name))
		
		dir_name = dir.get_next()


## Import all of the assets from each of the asset packs that was scanned in,
## and return a list of [AssetPack] after the import process is complete.
## Note that in order for the assets to be used in-game, the [AssetPack] needs
## to be registered in the AssetDB separately.
## TODO: Make returned array typed in 4.x
func import_all() -> Array:
	print("Importing scanned assets...")
	
	var valid_pack_catalogs := []
	for pack_catalog in _pack_catalogs:
		if pack_catalog.has_scanned_dir():
			valid_pack_catalogs.push_back(pack_catalog)
	
	var pack_list: Array = []
	for pack_index in range(valid_pack_catalogs.size()):
		if ImportAbortFlag.is_enabled():
			break
		
		var pack_catalog: AssetPackCatalog = valid_pack_catalogs[pack_index]
		emit_signal("about_to_import_pack", pack_catalog.pack_name, pack_index,
				valid_pack_catalogs.size())
		
		pack_catalog.connect("about_to_import_file", self,
				"_on_pack_catalog_about_to_import_file")
		pack_list.push_back(pack_catalog.perform_full_import())
		pack_catalog.disconnect("about_to_import_file", self,
				"_on_pack_catalog_about_to_import_file")
	
	return pack_list


## Remove all of the rogue files from within [code]user://assets[/code].
func clean_rogue_files() -> void:
	for pack_catalog in _pack_catalogs:
		pack_catalog.clean_rogue_files()


func _on_pack_catalog_about_to_import_file(file_path: String, file_index: int,
		file_count: int):
	
	emit_signal("about_to_import_file", file_path, file_index, file_count)
