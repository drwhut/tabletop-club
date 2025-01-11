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

class_name CursorTool
extends PlayerTool

## The player tool for selecting, moving, editing, and deleting objects.


## A reference to the [PieceManager] node in the room scene.
var piece_manager: PieceManager = null


func _physics_process(_delta: float):
	perform_raycast(0x1, true, false)


func _unhandled_input(event: InputEvent):
	var is_controller := false
	var is_ctrl := false
	
	if event is InputEventWithModifiers:
		is_ctrl = event.command if OS.get_name() == "OSX" else event.control
	elif event is InputEventJoypadButton:
		is_controller = true
	
	if event.is_action_pressed("game_select_grab"):
		if cursor_over_body is Piece:
			if is_controller or is_ctrl:
				cursor_over_body.selected = not cursor_over_body.selected
			else:
				# If this piece was not in the selection, make it the only
				# selected piece.
				if not cursor_over_body.selected:
					get_tree().call_group(Piece.SELECTED_GROUP, "set_selected",
							false)
				
				cursor_over_body.selected = true
		else:
			if not is_ctrl:
				get_tree().call_group(Piece.SELECTED_GROUP, "set_selected", false)
			
			# TODO: Hold left click to move, box selection.
	
	elif event.is_action_released("game_select_grab"):
		pass
	
	elif event.is_action_pressed("game_delete_piece"):
		var index_arr := get_selected_index_arr()
		if index_arr.empty():
			return
		
		piece_manager.rpc_id(1, "request_remove_multiple", index_arr)
	
	elif event.is_action_pressed("game_lock_piece"):
		var index_arr := PoolIntArray()
		var all_locked := true
		
		for element in get_tree().get_nodes_in_group(Piece.SELECTED_GROUP):
			var piece: Piece = element
			var index := int(piece.name) # TODO: Optimise?
			index_arr.push_back(index)
			
			if piece.state_mode != Piece.MODE_LOCKED:
				all_locked = false
		
		piece_manager.rpc_id(1, "request_set_locked_multiple", index_arr,
				not all_locked)
	
	else:
		if event is InputEventKey:
			if not event.pressed:
				return
			
			# Ctrl+A = Select all pieces.
			# TODO: Make sure this, as well as other tool-related features,
			# can't be used while the player is in the main menu.
			if event.scancode == KEY_A and is_ctrl:
				for element in piece_manager.get_children():
					var piece: Piece = element
					piece.selected = true


## From all of the pieces that are currently selected, return a list of their
## indices. This is mostly used to send requests over the network.
func get_selected_index_arr() -> PoolIntArray:
	var out := PoolIntArray()
	
	for element in get_tree().get_nodes_in_group(Piece.SELECTED_GROUP):
		var piece: Piece = element
		var index := int(piece.name) # TODO: Optimise this step?
		out.push_back(index)
	
	return out
