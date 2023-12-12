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

extends Node

## A database of assets currently in use by the game.
##
## In order for an [AssetEntry] to be registered by the game, it first needs to
## be added to an [AssetPack], which is then added to the database. Entries can
## also be added temporarily (e.g. if the host of a multiplayer game gave the
## client assets).

## Emitted when changes have been comitted to the DB.
signal content_changed()


# The list of registered asset packs, in no particular order.
# TODO: Make array typed in 4.x
var _packs: Array = []

# A dictionary of entries with their corresponding paths for faster lookup.
var _path_cache := {}

# A cached dictionary containing lists of all entries of a given type.
var _type_cache := {}


## Add an asset pack to the database. Throws an error if the pack is already in
## the database.
func add_pack(pack: AssetPack) -> void:
	if has_pack(pack.id):
		push_error("Pack '%s' already exists in the AssetDB" % pack.id)
		return
	
	_packs.push_back(pack)
	print("AssetDB: Added %s" % pack.id)


## Commit the changes made to the database. This will not only emit
## [signal content_changed], but will also re-generate internal caches.
func commit_changes() -> void:
	print("AssetDB: Commiting changes...")
	_regenerate_cache()
	emit_signal("content_changed")
	print("AssetDB: Changes commited.")


## Get a list of all [AssetEntry] stored in the database. If [code]type[/code]
## is not empty, only entries of the given type are returned. Note that
## [method commit_changes] needs to be called first before using this method.
func get_all_entries(type: String = "") -> Array:
	if type.empty():
		return _path_cache.values()
	
	var type_arr: Array = _type_cache.get(type, [])
	return type_arr.duplicate()


## Get the full list of asset packs registered in the DB.
func get_all_packs() -> Array:
	return _packs.duplicate()


## Get the [AssetEntry] with the corresponding [code]entry_path[/code]. Returns
## [code]null[/code] if the entry does not exist within the DB.
func get_entry(entry_path: String) -> AssetEntry:
	var cache_hit: AssetEntry = _path_cache.get(entry_path, null)
	if cache_hit != null:
		return cache_hit
	
	print("AssetDB: Cache miss on '%s', searching for entry manually..." % entry_path)
	var pack_split := entry_path.split("/", false, 1)
	if pack_split.size() != 2:
		push_error("Entry path '%s' is invalid" % entry_path)
		return null
	
	var pack_id := pack_split[0]
	var entry_id_split := pack_split[1].rsplit("/", false, 1)
	if entry_id_split.size() != 2:
		push_error("Entry path '%s' is invalid" % entry_path)
		return null
	
	var type := entry_id_split[0]
	var entry_id := entry_id_split[1]
	
	var pack := get_pack(pack_id)
	if pack == null:
		return null
	
	return pack.get_entry(type, entry_id)


## Get the number of entries in the DB's internal cache. This should equal the
## sum of the entry count for all registered packs, but only after
## [method commit_changes] has been called.
func get_entry_count() -> int:
	return _path_cache.size()


## Get the [AssetPack] with the corresponding [code]pack_id[/code]. Returns
## [code]null[/code] if the pack does not exist in the DB.
func get_pack(pack_id: String) -> AssetPack:
	var index := _find_pack_index(pack_id)
	if index < 0:
		push_error("Pack '%s' does not exist in the AssetDB" % pack_id)
		return null
	
	return _packs[index]


## Check if a pack with the given [code]pack_id[/code] exists in the DB.
func has_pack(pack_id: String) -> bool:
	var index := _find_pack_index(pack_id)
	return index >= 0


## Check if an entry path is in the internal cache. This is mostly for testing
## purposes.
func is_path_in_cache(entry_path: String) -> bool:
	return _path_cache.has(entry_path)


## Remove the asset pack with the given [code]pack_id[/code] from the DB.
func remove_pack(pack_id: String) -> void:
	var index := _find_pack_index(pack_id)
	if index < 0:
		push_error("Pack '%s' does not exist in the AssetDB" % pack_id)
		return
	
	_packs.remove(index)
	print("AssetDB: Removed %s" % pack_id)


## Revert temporary changes made to the asset packs in the DB. Note that this
## function will call [method commit_changes] if changes occured.
func revert_temp_changes() -> void:
	print("AssetDB: Reverting temporary changes...")
	var changes_made := false
	
	for index in range(_packs.size() - 1, -1, -1):
		var pack: AssetPack = _packs[index]
		
		var removed_entries := pack.get_removed_entries()
		var replaced_entries := pack.get_replaced_entries()
		if removed_entries.size() > 0 or replaced_entries.size() > 0:
			changes_made = true
		
		var old_entry_count := pack.get_entry_count()
		pack.clear_temp_entries()
		var new_entry_count := pack.get_entry_count()
		
		if new_entry_count == 0:
			changes_made = true
			_packs.remove(index)
		elif new_entry_count != old_entry_count:
			changes_made = true
	
	if changes_made:
		commit_changes()
	else:
		# If nothing changed, then no need to re-generate cache.
		print("AssetDB: No temporary changes to revert.")


# Find the index of an asset pack in the packs array. Returns -1 if the pack
# does not exist in the database.
func _find_pack_index(pack_id: String) -> int:
	for index in range(_packs.size()):
		var pack: AssetPack = _packs[index]
		if pack.id == pack_id:
			return index
	
	return -1


# Re-generate the internal cache for faster lookup times.
func _regenerate_cache() -> void:
	_path_cache.clear()
	_type_cache.clear()
	
	for pack_index in range(_packs.size()):
		var pack: AssetPack = _packs[pack_index]
		var pack_assets := pack.get_all()
		for type in pack_assets:
			var type_arr: Array = pack_assets[type]
			
			if _type_cache.has(type):
				var full_array: Array = _type_cache[type]
				full_array.append_array(type_arr)
			else:
				_type_cache[type] = type_arr.duplicate()
			
			for type_index in range(type_arr.size()):
				var entry: AssetEntry = type_arr[type_index]
				_path_cache[entry.get_path()] = entry
	
	for type in _type_cache:
		var type_arr: Array = _type_cache[type]
		type_arr.sort_custom(AssetEntry, "compare_entries")
