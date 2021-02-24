# open-tabletop
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows
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

extends VBoxContainer

signal preview_clicked(preview, event)

onready var _pack_button = $HBoxContainer/PackButton
onready var _type_button = $HBoxContainer/TypeButton
onready var _search_edit = $HBoxContainer/SearchEdit

onready var _object_preview_grid = $ScrollContainer/VBoxContainer/ObjectPreviewGrid

export(Dictionary) var db_types = {}

const DEFAULT_ASSET_PACK = "OpenTabletop"

var _preview_entries = []
var _preview_entries_filtered = []
var _search_length = 0

func _ready():
	# First check that the db_types dictionary is valid.
	for key in db_types:
		if key is String:
			var value = db_types[key]
			if value is String:
				pass
			elif value is Array:
				for inner_value in value:
					if not inner_value is String:
						push_error("%s inner value in DB types is not a string!" % str(inner_value))
						return
			else:
				push_error("%s value in DB types is neither a string or array of strings!" % str(value))
				return
		else:
			push_error("%s entry in DB types is not a string!" % str(key))
			return
	
	var asset_db = AssetDB.get_db()
	if asset_db.has(DEFAULT_ASSET_PACK):
		_pack_button.add_item(DEFAULT_ASSET_PACK)
		_pack_button.add_separator()
	
	for pack in asset_db:
		if pack != DEFAULT_ASSET_PACK:
			_pack_button.add_item(pack)
	
	_set_type_options()
	
	# Call this a frame later when the rest of the scene tree is ready.
	# That way, we can be sure a network peer exists if pieces are created.
	call_deferred("_display_previews")

# Check that a certain type directory exists within the given asset pack in the
# assets DB.
# Returns: If the type exists within the pack.
# pack: The name of the asset pack.
# type: The type to query.
func _check_pack_type_exists(pack: String, type: String) -> bool:
	var asset_db = AssetDB.get_db()
	if asset_db.has(pack):
		if asset_db[pack].has(type):
			if not asset_db[pack][type].empty():
				return true
	
	return false

# Display the previews, given the currently selected pack and type.
func _display_previews() -> void:
	_preview_entries.clear()
	_preview_entries_filtered.clear()
	
	var asset_db = AssetDB.get_db()
	var pack = _pack_button.get_item_text(_pack_button.selected)
	if not asset_db.has(pack):
		return
	
	var type_display = _type_button.get_item_text(_type_button.selected)
	if not db_types.has(type_display):
		return
	
	var types = db_types[type_display]
	if types is String:
		types = [types]
	if types is Array:
		for type in types:
			if asset_db[pack].has(type):
				for entry in asset_db[pack][type]:
					_preview_entries.append(entry)
	
	# Reset the search text and show everything.
	_preview_entries_filtered = _preview_entries.duplicate()
	_search_edit.text = ""
	_search_length = 0
	
	_update_preview_gui()

# Filter the previews, given the current search text.
# from_filtered: Should we filter from the already filtered list? Use this when
# you know the list of previews should only get smaller.
func _filter_previews(from_filtered: bool) -> void:
	_search_length = _search_edit.text.length()
	
	if not from_filtered:
		_preview_entries_filtered = _preview_entries.duplicate()
	
	var query = _search_edit.text.capitalize()
	if not query.empty():
		for i in range(_preview_entries_filtered.size() - 1, -1, -1):
			var entry = _preview_entries_filtered[i]
			var entry_name = entry["name"].capitalize()
			
			if not query in entry_name:
				_preview_entries_filtered.remove(i)
	
	_update_preview_gui()

# Set the items in the type option button.
func _set_type_options() -> void:
	_type_button.clear()
	
	var asset_db = AssetDB.get_db()
	var pack = _pack_button.get_item_text(_pack_button.selected)
	if not asset_db.has(pack):
		return
	
	for type_display in db_types:
		# Only add the type to the option button if there are assets of that
		# type in the pack!
		var add_type = false
		
		var type_value = db_types[type_display]
		if type_value is String:
			add_type = _check_pack_type_exists(pack, type_value)
		elif type_value is Array:
			for type_inner in type_value:
				if type_inner is String:
					if _check_pack_type_exists(pack, type_inner):
						add_type = true
						break
		
		if add_type:
			_type_button.add_item(type_display)

# Update the preview GUI.
func _update_preview_gui() -> void:
	_object_preview_grid.reset()

func _on_ObjectPreviewGrid_preview_clicked(preview: ObjectPreview, event: InputEventMouseButton):
	# Forward the signal outside the filter.
	emit_signal("preview_clicked", preview, event)

func _on_ObjectPreviewGrid_requesting_objects(start: int, length: int):
	var previews = []
	
	for i in range(start, start+length):
		if i >= _preview_entries_filtered.size():
			break
		
		previews.append(_preview_entries_filtered[i])
	
	var after = max(0, _preview_entries_filtered.size() - start - length)
	_object_preview_grid.provide_objects(previews, after)

func _on_PackButton_item_selected(_index: int):
	_display_previews()

func _on_SearchEdit_text_changed(new_text: String):
	_filter_previews(new_text.length() > _search_length)

func _on_TypeButton_item_selected(_index: int):
	_display_previews()
