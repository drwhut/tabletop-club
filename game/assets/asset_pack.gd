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

class_name AssetPack
extends ResourceWithErrors

## A collection of assets stored in the AssetDB.
##
## An asset pack is a collection of assets used by the game, which are read from
## specially-made directories on the filesystem. For more information, see:
## https://tabletop-club.readthedocs.io/en/latest/custom_assets/asset_packs/index.html


## The name of the asset pack when referencing it in the AssetDB.
export(String) var id := "_" setget set_id

## The name of the asset pack when displayed in the UI.
export(String) var name := "_" setget set_name

# The contents of the asset pack are stored in these type arrays, in the form
# of asset entries. The entries are sorted by ID so that binary search can be
# used. It is recommended to use the given class methods to manipulate the
# arrays rather than using them directly so the order can be maintained.
# TODO: Make arrays typed in 4.x
export(Array, Resource) var boards: Array = []
export(Array, Resource) var cards: Array = []
export(Array, Resource) var containers: Array = []
export(Array, Resource) var dice: Array = []
export(Array, Resource) var games: Array = []
export(Array, Resource) var music: Array = []
export(Array, Resource) var pieces: Array = []
export(Array, Resource) var skyboxes: Array = []
export(Array, Resource) var sounds: Array = []
export(Array, Resource) var speakers: Array = []
export(Array, Resource) var stacks: Array = []
export(Array, Resource) var tables: Array = []
export(Array, Resource) var templates: Array = []
export(Array, Resource) var timers: Array = []
export(Array, Resource) var tokens: Array = []

## A path to the directory where the asset pack was read from. If empty, it is
## assumed the pack came bundled with the game.
var origin := "" setget set_origin

# A dictionary with references to each of the type arrays, with the keys being
# the name of that type.
var _type_dict := {}

# A list of entries that have been replaced by temporary ones. If the temporary
# entry is removed, the previous entry takes its place again.
var _replaced_entries := []


func _init():
	# This works since arrays are passed by reference.
	_type_dict = {
		"boards": boards,
		"cards": cards,
		"containers": containers,
		"dice": dice,
		"games": games,
		"music": music,
		"pieces": pieces,
		"skyboxes": skyboxes,
		"sounds": sounds,
		"speakers": speakers,
		"stacks": stacks,
		"tables": tables,
		"templates": templates,
		"timers": timers,
		"tokens": tokens,
	}


## Add an entry to the asset pack under the given [code]type[/code].
func add_entry(type: String, entry: AssetEntry) -> void:
	if not _type_dict.has(type):
		push_error("Invalid type '%s'" % type)
		return
	
	var type_arr := get_type(type)
	var insert_index := _bsearch_index(type_arr, entry)
	
	if insert_index < type_arr.size():
		var check_entry: AssetEntry = type_arr[insert_index]
		if check_entry.id == entry.id:
			if entry.temp:
				if not check_entry.temp:
					_replaced_entries.push_back(check_entry)
					
					entry.pack = id
					entry.type = type
					type_arr[insert_index] = entry
					return
				else:
					push_error("Cannot replace one temporary entry with another")
					return
			else:
				push_error("Cannot add entry that already exists")
				return
	
	# Exported arrays share the same reference if they are created empty, so we
	# need to forcefully create a new array so this entry does not get added to
	# all of the other arrays.
	if type_arr.empty():
		type_arr = []
		set(type, type_arr) # <- Assumes type name = variable name.
		_type_dict[type] = type_arr
	
	entry.pack = id
	entry.type = type
	type_arr.insert(insert_index, entry)


## Clear all entries from the asset pack.
func clear_all_entries() -> void:
	for type in _type_dict:
		var type_arr: Array = _type_dict[type]
		type_arr.clear()
	_replaced_entries.clear()


## Only clear temporary entries from the asset pack. If any entries were
## replaced by temporary ones, they are put back into their respective array.
func clear_temp_entries() -> void:
	for type in _type_dict:
		var type_arr: Array = _type_dict[type]
		for index in range(type_arr.size() - 1, -1, -1):
			var test_entry: AssetEntry = type_arr[index]
			if test_entry.temp:
				remove_entry(type, index)


## Erase the given entry ID from the given type array. If the entry had replaced
## another entry, the previous entry is put back in the array.
func erase_entry(type: String, entry_id: String) -> void:
	var type_arr := get_type(type)
	var test_entry := AssetEntry.new()
	test_entry.id = entry_id
	
	var possible_index := _bsearch_index(type_arr, test_entry)
	if possible_index >= type_arr.size():
		return
	
	test_entry = type_arr[possible_index]
	if test_entry.id == entry_id:
		remove_entry(type, possible_index)


## Get all of the entries for this asset pack under one [Dictionary], where each
## key is a type name, and each value is the corresponding type array.
func get_all() -> Dictionary:
	return _type_dict.duplicate()


## Get the entry with the given [code]id[/code] within the given
## [code]type[/code] array. Returns [code]null[/code] if the entry does not
## exist within the asset pack.
func get_entry(type: String, entry_id: String) -> AssetEntry:
	var type_arr := get_type(type) # If type does not exist, array is empty.
	
	var test_entry := AssetEntry.new()
	test_entry.id = entry_id
	var index := _bsearch_index(type_arr, test_entry)
	if index >= type_arr.size():
		push_error("Entry does not exist in pack")
		return null
	
	test_entry = type_arr[index]
	if test_entry.id != entry_id:
		push_error("Entry does not exist in pack")
		return null
	
	return test_entry


## Get the number of asset entries this pack contains.
func get_entry_count() -> int:
	var total := 0
	for type in _type_dict:
		var type_arr: Array = _type_dict[type]
		total += type_arr.size()
	return total


## Get the list of entries that were replaced by temporary ones.
func get_replaced_entries() -> Array:
	return _replaced_entries.duplicate()


## Get the type array with the corresponding name.
func get_type(type: String) -> Array:
	if _type_dict.has(type):
		return _type_dict[type]
	
	# Backwards compatibility with v0.1.x:
	match type:
		"dice/d4", "dice/d6", "dice/d8", "dice/d10", "dice/d12", "dice/d20":
			return dice
		"tokens/cube", "tokens/cylinder":
			return tokens
	
	push_error("Unknown type '%s'" % type)
	return []


## Check if the asset pack has an entry within the given type.
func has_entry(type: String, entry_id: String) -> bool:
	var type_arr := get_type(type)
	
	var test_entry := AssetEntry.new()
	test_entry.id = entry_id
	var search_index := _bsearch_index(type_arr, test_entry)
	if search_index >= type_arr.size():
		return false
	
	test_entry = type_arr[search_index]
	return test_entry.id == entry_id


## Check if the asset pack came bundled with the game.
func is_bundled() -> bool:
	return origin.empty()


## Check if the asset pack is empty.
func is_empty() -> bool:
	return get_entry_count() == 0


## Remove the entry at the given index from the given type array. If the entry
## replaced another, the entry it replaced is put back in the array.
func remove_entry(type: String, index: int) -> void:
	if index < 0:
		push_error("Invalid index %d" % index)
		return
	
	var type_arr := get_type(type)
	if index >= type_arr.size():
		push_error("Invalid index %d (size = %d)" % [index, type_arr.size()])
		return
	
	var entry_to_remove: AssetEntry = type_arr[index]
	var entry_id := entry_to_remove.id
	
	var replaced_entry := _find_replaced_entry(type, entry_id)
	if replaced_entry != null:
		type_arr[index] = replaced_entry
	else:
		type_arr.remove(index)


func set_id(value: String) -> void:
	value = value.strip_edges().strip_escapes()
	
	if value.empty():
		push_error("Pack ID cannot be empty")
		return
	
	if not value.is_valid_filename():
		push_error("Invalid pack ID")
		return
	
	id = value


func set_name(value: String) -> void:
	value = value.strip_edges().strip_escapes()
	
	if value.empty():
		push_error("Pack name cannot be empty")
		return
	
	if not value.is_valid_filename():
		push_error("Invalid pack name")
		return
	
	name = value


func set_origin(value: String) -> void:
	if not value.empty():
		var dir := Directory.new()
		if not dir.dir_exists(value):
			push_error("Directory '%s' does not exist" % value)
			return
	
	origin = value


# Get the binary search index of an asset entry for the given array.
func _bsearch_index(array: Array, entry: AssetEntry) -> int:
	return array.bsearch_custom(entry, AssetEntry, "compare_entries")


# Find the given entry within the list of replaced entries, and remove it from
# the list if it exists. Return null if it does not.
func _find_replaced_entry(type: String, entry_id: String) -> AssetEntry:
	for index in range(_replaced_entries.size()):
		var test_entry: AssetEntry = _replaced_entries[index]
		if test_entry.id == entry_id and test_entry.type == type:
			return _replaced_entries.pop_at(index)
	
	return null
