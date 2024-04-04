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
