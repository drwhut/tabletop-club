# open-tabletop
# Copyright (c) 2020 drwhut
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

signal piece_requested(piece_entry)

onready var _objects_dialog = $ObjectsDialog
onready var _objects_tree = $ObjectsDialog/ObjectsTree

func set_piece_tree_from_db(pieces: Dictionary) -> void:
	var root = _objects_tree.create_item()
	_objects_tree.set_hide_root(true)
	
	for game in pieces:
		_add_game_to_tree(game, pieces[game])

func _add_game_to_tree(game_name: String, game_pieces: Dictionary) -> void:
	var game_node = _objects_tree.create_item(_objects_tree.get_root())
	game_node.set_text(0, game_name)
	
	var dice_node = _objects_tree.create_item(game_node)
	dice_node.set_text(0, "Dice")
	
	_add_type_to_tree(dice_node, game_pieces, "d4", "d4")
	_add_type_to_tree(dice_node, game_pieces, "d6", "d6")
	_add_type_to_tree(dice_node, game_pieces, "d8", "d8")
	
	# If there are no dice in this game, delete the dice node.
	if not dice_node.get_children():
		dice_node.free()
	
	_add_type_to_tree(game_node, game_pieces, "cards", "Cards")

func _add_piece_to_tree(parent: TreeItem, piece: Dictionary) -> TreeItem:
	var node = _objects_tree.create_item(parent)
	node.set_text(0, piece["name"])
	
	# Keep the piece entry in the node so we can use it later.
	node.set_metadata(0, piece)
	
	return node

func _add_type_to_tree(parent: TreeItem, game_pieces: Dictionary,
	type_name: String, display_name: String) -> void:
	
	if game_pieces.has(type_name):
			
		var node = _objects_tree.create_item(parent)
		node.set_text(0, display_name)
		
		var array: Array = game_pieces[type_name]
		
		if array.size() > 0:
			for piece in array:
				_add_piece_to_tree(node, piece)
		else:
			node.free()

func _on_ObjectsButton_pressed():
	_objects_dialog.popup_centered()

func _on_ObjectsTree_item_activated():
	var selected = _objects_tree.get_selected()
	
	# Check the selected item has metadata.
	if selected.get_metadata(0):
		emit_signal("piece_requested", selected.get_metadata(0))
