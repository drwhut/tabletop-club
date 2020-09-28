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
onready var _objects_tree = $ObjectsDialog/ObjectsTree
onready var _options_menu = $OptionsMenu
onready var _player_list = $PlayerList
onready var _rotation_option = $TopPanel/RotationOption

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	pass

# Set the piece tree contents, based on the piece database given.
# pieces: The database from the PieceDB.
func set_piece_tree_from_db(pieces: Dictionary) -> void:
	var root = _objects_tree.create_item()
	_objects_tree.set_hide_root(true)
	
	for game in pieces:
		_add_game_to_tree(game, pieces[game])

func _ready():
	Lobby.connect("player_added", self, "_on_Lobby_player_added")
	Lobby.connect("player_modified", self, "_on_Lobby_player_modified")
	Lobby.connect("player_removed", self, "_on_Lobby_player_removed")
	
	# Make sure we emit the signal when all of the nodes are ready:
	call_deferred("_set_rotation_amount")

func _unhandled_input(event):
	if event.is_action_pressed("game_menu"):
		_game_menu_background.visible = not _game_menu_background.visible
		if not _game_menu_background.visible:
			_options_menu.visible = false

# Add a game's piece entries to the piece tree.
# game_name: The name of the game.
# game_pieces: The game's piece entries.
func _add_game_to_tree(game_name: String, game_pieces: Dictionary) -> void:
	var game_node = _objects_tree.create_item(_objects_tree.get_root())
	game_node.set_text(0, game_name)
	game_node.collapsed = true
	
	_add_type_to_tree(game_node, game_pieces, ["cards"], "Cards")
	
	var dice_node = _objects_tree.create_item(game_node)
	dice_node.set_text(0, "Dice")
	
	_add_type_to_tree(dice_node, game_pieces, ["dice/d4"], "d4")
	_add_type_to_tree(dice_node, game_pieces, ["dice/d6"], "d6")
	_add_type_to_tree(dice_node, game_pieces, ["dice/d8"], "d8")
	
	if not dice_node.get_children():
		dice_node.free()
	
	_add_type_to_tree(game_node, game_pieces, [
		"pieces/cube",
		"pieces/custom",
		"pieces/cylinder"
	], "Pieces")
	
	_add_type_to_tree(game_node, game_pieces, ["stacks"], "Stacks")
	
	_add_type_to_tree(game_node, game_pieces, [
		"tokens/cube",
		"tokens/cylinder"
	], "Tokens")

# Add a piece to the piece tree.
# parent: The parent node of the piece's node in the tree.
# piece: The piece entry of the piece to add.
func _add_piece_to_tree(parent: TreeItem, piece: Dictionary) -> TreeItem:
	var node = _objects_tree.create_item(parent)
	node.set_text(0, piece["name"])
	
	# Keep the piece entry in the node so we can use it later.
	node.set_metadata(0, piece)
	
	return node

# Add a type of piece to the piece tree.
# parent: The parent node to add the type node to.
# game_pieces: The game's piece entries.
# type_names: The names of the type in the dictionary.
# display_name: The name of the type in the piece tree.
func _add_type_to_tree(parent: TreeItem, game_pieces: Dictionary,
	type_names: Array, display_name: String) -> void:
	
	var node = _objects_tree.create_item(parent)
	node.set_text(0, display_name)
	node.collapsed = true
	
	for type_name in type_names:
		if game_pieces.has(type_name):
			var array: Array = game_pieces[type_name]
			for piece in array:
				_add_piece_to_tree(node, piece)
	
	if not node.get_children():
		node.free()

# Call to emit a signal for the camera to set it's piece rotation amount.
func _set_rotation_amount() -> void:
	if _rotation_option.selected >= 0:
		var deg_id = _rotation_option.get_item_id(_rotation_option.selected)
		var deg_text = _rotation_option.get_item_text(deg_id)
		var rad = deg2rad(float(deg_text))
		emit_signal("rotation_amount_updated", rad)

# Update the player list based on what is in the Lobby.
func _update_player_list() -> void:
	var code = "[right][table=1]"
	
	for id in Lobby.get_player_list():
		var player = Lobby.get_player(id)
		code += "[cell]"
		
		var player_color = "ffffff"
		if player.has("color"):
			player_color = player["color"].to_html(false)
		code += "[color=#" + player_color + "]"
		
		var player_name = "<No Name>"
		if player.has("name"):
			player_name = player["name"]
		player_name = player_name.strip_edges()
		if player_name.empty():
			player_name = "<No Name>"
		player_name = player_name.replace("[", "") # For security!
		code += player_name
		
		code += "[/color]"
		code += "[/cell]"
	
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

func _on_ObjectsTree_item_activated():
	var selected = _objects_tree.get_selected()
	
	# Check the selected item has metadata.
	if selected.get_metadata(0):
		emit_signal("piece_requested", selected.get_metadata(0))

func _on_OptionsButton_pressed():
	_options_menu.visible = true

func _on_OptionsMenu_applying_options(config: ConfigFile):
	emit_signal("applying_options", config)

func _on_RotationOption_item_selected(index: int):
	_set_rotation_amount()
