# open-tabletop
# Copyright (c) 2020 Benjamin 'drwhut' Beddows
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

extends Control

signal applying_options(config)
signal piece_requested(piece_entry)
signal rotation_amount_updated(rotation_amount)

onready var _game_menu_background = $GameMenuBackground
onready var _objects_dialog = $ObjectsDialog
onready var _objects_packs = $ObjectsDialog/HBoxContainer/VBoxContainer/ScrollContainer/Packs
onready var _objects_content = $ObjectsDialog/HBoxContainer/ScrollContainer/Content
onready var _objects_content_container = $ObjectsDialog/HBoxContainer/ScrollContainer
onready var _options_menu = $OptionsMenu
onready var _player_list = $PlayerList
onready var _rotation_option = $TopPanel/RotationOption

var _piece_db = {}
var _preview_width = 0
var _toggled_pack = ""

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	pass

# Set the piece database contents, based on the piece database given.
# pieces: The database from the PieceDB.
func set_piece_db(pieces: Dictionary) -> void:
	_piece_db = pieces
	_update_object_packs()

func _ready():
	Lobby.connect("player_added", self, "_on_Lobby_player_added")
	Lobby.connect("player_modified", self, "_on_Lobby_player_modified")
	Lobby.connect("player_removed", self, "_on_Lobby_player_removed")
	
	# Make sure we emit the signal when all of the nodes are ready:
	call_deferred("_set_rotation_amount")
	
	var preview_test = preload("res://Scenes/ObjectPreview.tscn").instance()
	add_child(preview_test)
	_preview_width = preview_test.rect_size.x
	remove_child(preview_test)
	preview_test.free()

func _unhandled_input(event):
	if event.is_action_pressed("game_menu"):
		_game_menu_background.visible = not _game_menu_background.visible
		if not _game_menu_background.visible:
			_options_menu.visible = false

# Add an object to a control node.
# parent: The control node to add the object to.
# piece_entry: The entry representing the piece.
func _add_content_object(parent: Control, piece_entry: Dictionary) -> void:
	var preview = preload("res://Scenes/ObjectPreview.tscn").instance()
	parent.add_child(preview)
	preview.set_piece(piece_entry)

# Add a set of objects of a given type to a control node, if it exists in the
# piece database.
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
	return int(_objects_content_container.rect_size.x / _preview_width)

# Call to emit a signal for the camera to set it's piece rotation amount.
func _set_rotation_amount() -> void:
	if _rotation_option.selected >= 0:
		var deg_id = _rotation_option.get_item_id(_rotation_option.selected)
		var deg_text = _rotation_option.get_item_text(deg_id)
		var rad = deg2rad(float(deg_text))
		emit_signal("rotation_amount_updated", rad)

# Update the content list in the objects menu.
# pack_name: The name of the pack whose content to display. If the pack doesn't
# exist, then nothing is displayed.
func _update_object_content(pack_name: String) -> void:
	for child in _objects_content.get_children():
		_objects_content.remove_child(child)
		child.queue_free()
	
	_add_content_type(_objects_content, pack_name, ["cards"], "Cards")
	
	_add_content_type(_objects_content, pack_name, ["dice/d4"], "Dice - D4")
	_add_content_type(_objects_content, pack_name, ["dice/d6"], "Dice - D6")
	_add_content_type(_objects_content, pack_name, ["dice/d8"], "Dice - D8")
	
	_add_content_type(_objects_content, pack_name, [
		"pieces/cube",
		"pieces/custom",
		"pieces/cylinder"
		], "Pieces")
	
	_add_content_type(_objects_content, pack_name, ["stacks"], "Stacks")
	
	_add_content_type(_objects_content, pack_name, [
		"tokens/cube",
		"tokens/cylinder"
		], "Tokens")

# Update the pack list in the objects menu.
func _update_object_packs() -> void:
	for child in _objects_packs.get_children():
		_objects_packs.remove_child(child)
		child.queue_free()
	
	for pack_name in _piece_db:
		var pack_button = Button.new()
		pack_button.size_flags_horizontal = SIZE_EXPAND_FILL
		pack_button.text = pack_name
		pack_button.toggle_mode = true
		
		pack_button.connect("toggled", self, "_on_pack_button_toggled")
		
		_objects_packs.add_child(pack_button)

# Update the player list based on what is in the Lobby.
func _update_player_list() -> void:
	var code = "[right][table=1]"
	
	for id in Lobby.get_player_list():
		code += "[cell]" + Lobby.get_name_bb_code(id) + "[/cell]"
	
	code += "[/table][/right]"
	_player_list.bbcode_text = code

func _on_BackToGameButton_pressed():
	_game_menu_background.visible = false

func _on_DesktopButton_pressed():
	get_tree().quit()

func _on_GameMenuButton_pressed():
	_game_menu_background.visible = true

func _on_Lobby_player_added(id: int):
	_update_player_list()

func _on_Lobby_player_modified(id: int):
	_update_player_list()

func _on_Lobby_player_removed(id: int):
	_update_player_list()

func _on_MainMenuButton_pressed():
	Global.start_main_menu()

func _on_ObjectsButton_pressed():
	_objects_dialog.popup_centered()

func _on_OptionsButton_pressed():
	_options_menu.visible = true

func _on_ObjectsDialog_popup_hide():
	for child in _objects_packs.get_children():
		child.pressed = false
	_toggled_pack = ""
	
	_update_object_content("")

func _on_OptionsMenu_applying_options(config: ConfigFile):
	emit_signal("applying_options", config)

func _on_pack_button_toggled(pressed: bool):
	if pressed:
		var _new_pack = ""
		for pack_button in _objects_packs.get_children():
			if pack_button.pressed:
				if pack_button.text == _toggled_pack:
					pack_button.pressed = false
				else:
					_new_pack = pack_button.text
		_toggled_pack = _new_pack
	else:
		_toggled_pack = ""
		
	_update_object_content(_toggled_pack)

func _on_RotationOption_item_selected(index: int):
	_set_rotation_amount()
