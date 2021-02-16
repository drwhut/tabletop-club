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

extends WindowDialog

signal piece_requested(piece_entry)

onready var _add_button = $MarginContainer/HBoxContainer/VBoxContainer2/HBoxContainer/AddButton
onready var _content = $MarginContainer/HBoxContainer/VBoxContainer2/ScrollContainer/Content
onready var _content_container = $MarginContainer/HBoxContainer/VBoxContainer2/ScrollContainer
onready var _packs = $MarginContainer/HBoxContainer/VBoxContainer/ScrollContainer/Packs
onready var _status = $MarginContainer/HBoxContainer/VBoxContainer2/HBoxContainer/StatusLabel

var _available_previews = []
var _object_preview = preload("res://Scenes/ObjectPreview.tscn")
var _piece_db = {}
var _preview_width = 0
var _toggled_pack = ""

# Set the asset database contents, based on the asset database given.
# assets: The database from the AssetDB.
func set_piece_db(assets: Dictionary) -> void:
	_piece_db = assets
	_update_object_packs()
	
	# The object previews take some time to instance (this is mostly due to the
	# rendering engine creating the buffers needed to render the object), so
	# we'll instance all of the previews now while the user is loading in, so
	# we can just add them to the scene tree when needed.
	var max_needed = 0
	for pack in assets:
		var pack_num = 0
		for type in assets[pack]:
			pack_num += assets[pack][type].size()
		if pack_num > max_needed:
			max_needed = pack_num
	
	while _available_previews.size() < max_needed:
		_available_previews.push_back(_object_preview.instance())

func _ready():
	var preview_test = _object_preview.instance()
	add_child(preview_test)
	_preview_width = preview_test.rect_size.x
	remove_child(preview_test)
	preview_test.free()

# Add an object to a control node.
# parent: The control node to add the object to.
# piece_entry: The entry representing the piece.
func _add_content_object(parent: Control, piece_entry: Dictionary) -> void:
	var preview = _available_previews.pop_back()
	if not preview:
		return
	
	parent.add_child(preview)
	preview.set_piece_with_entry(piece_entry)
	
	if not preview.is_connected("clicked", self, "_on_preview_clicked"):
		preview.connect("clicked", self, "_on_preview_clicked")

# Add a set of objects of a given type to a control node, if it exists in the
# asset database.
# parent: The control node to add the content to.
# pack_name: The name of the pack to get the objects from.
# type_names: The names of the types in the database.
# type_display: What the type should be called in the UI.
func _add_content_type(parent: Control, pack_name: String, type_names: Array,
	type_display: String) -> void:
	
	if not _piece_db.has(pack_name):
		return
	
	var type_found = false
	for type_name in type_names:
		if _piece_db[pack_name].has(type_name):
			type_found = true
			break
	if not type_found:
		return
	
	var type_label = Label.new()
	type_label.text = type_display
	parent.add_child(type_label)
	
	var grid_container = GridContainer.new()
	grid_container.columns = _get_num_content_columns()
	parent.add_child(grid_container)
	
	for type_name in type_names:
		if _piece_db[pack_name].has(type_name):
			var piece_entries: Array = _piece_db[pack_name][type_name]
			for piece_entry in piece_entries:
				_add_content_object(grid_container, piece_entry)
	
	var blank_space = Control.new()
	blank_space.rect_min_size = Vector2(0, 10)
	parent.add_child(blank_space)

# Get the number of columns the content grid containers should have.
func _get_num_content_columns() -> int:
	if _preview_width < 1:
		return 1
	return int(_content_container.rect_size.x / _preview_width)

# Retrieve all of the previews currently in the scene tree, and place them back
# in the available list.
func _retrieve_previews() -> void:
	get_tree().call_group("preview_selected", "set_selected", false)
	_add_button.disabled = true
	
	_retrieve_previews_recursive(_content)

# Recursively retrieve all previews from a given parent.
# node: The node to start from.
func _retrieve_previews_recursive(node: Node) -> void:
	if node is ObjectPreview:
		node.get_parent().remove_child(node)
		node.clear_piece()
		_available_previews.push_back(node)
	else:
		for child in node.get_children():
			_retrieve_previews_recursive(child)

# Update the content list in the objects menu.
# pack_name: The name of the pack whose content to display. If the pack doesn't
# exist, then nothing is displayed.
func _update_object_content(pack_name: String) -> void:
	_status.text = ""
	
	_retrieve_previews()
	
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	
	_add_content_type(_content, pack_name, ["cards"], "Cards")
	
	_add_content_type(_content, pack_name, [
		"containers/cube",
		"containers/custom",
		"containers/cylinder"
		], "Containers")
	
	_add_content_type(_content, pack_name, ["dice/d4"], "Dice - D4")
	_add_content_type(_content, pack_name, ["dice/d6"], "Dice - D6")
	_add_content_type(_content, pack_name, ["dice/d8"], "Dice - D8")
	
	_add_content_type(_content, pack_name, [
		"pieces/cube",
		"pieces/custom",
		"pieces/cylinder"
		], "Pieces")
	
	_add_content_type(_content, pack_name, [
		"speakers/cube",
		"speakers/custom",
		"speakers/cylinder"
	], "Speakers")
	
	_add_content_type(_content, pack_name, ["stacks"], "Stacks")
	
	_add_content_type(_content, pack_name, [
		"tokens/cube",
		"tokens/cylinder"
		], "Tokens")
	
	# A dirty workaround for a bug where closing the objects dialog while there
	# was content means that when loading new content afterwards the vertical
	# scrollbar disappears... for some reason.
	var v_scrollbar = _content_container.get_v_scrollbar()
	if v_scrollbar.max_value > 0:
		v_scrollbar.visible = true

# Update the pack list in the objects menu.
func _update_object_packs() -> void:
	for child in _packs.get_children():
		_packs.remove_child(child)
		child.queue_free()
	
	for pack_name in _piece_db:
		var pack_button = Button.new()
		pack_button.size_flags_horizontal = SIZE_EXPAND_FILL
		pack_button.text = pack_name
		pack_button.toggle_mode = true
		
		pack_button.connect("toggled", self, "_on_pack_button_toggled")
		
		_packs.add_child(pack_button)

func _on_AddButton_pressed():
	var previews_selected = get_tree().get_nodes_in_group("preview_selected")
	
	var num_pieces = 0
	var piece_name = ""
	for preview in previews_selected:
		if preview is ObjectPreview:
			var piece_entry = preview.get_piece_entry()
			
			num_pieces += 1
			if piece_name.empty():
				piece_name = piece_entry["name"]
			
			emit_signal("piece_requested", piece_entry)
	
	if num_pieces == 0:
		pass
	elif num_pieces == 1:
		_status.text = "Added %s." % piece_name
	else:
		_status.text = "Added %d objects." % previews_selected.size()

func _on_ObjectsDialog_popup_hide():
	for child in _packs.get_children():
		child.pressed = false
	_toggled_pack = ""
	
	_update_object_content("")

func _on_ObjectsDialog_tree_exited():
	for preview in _available_previews:
		preview.free()

func _on_pack_button_toggled(pressed: bool):
	if pressed:
		var _new_pack = ""
		for pack_button in _packs.get_children():
			if pack_button.pressed:
				if pack_button.text == _toggled_pack:
					pack_button.pressed = false
				else:
					_new_pack = pack_button.text
		_toggled_pack = _new_pack
	else:
		_toggled_pack = ""
	
	_update_object_content(_toggled_pack)

func _on_preview_clicked(preview: ObjectPreview, event: InputEventMouseButton):
	var none_selected = get_tree().get_nodes_in_group("preview_selected").empty()
	_add_button.disabled = none_selected
