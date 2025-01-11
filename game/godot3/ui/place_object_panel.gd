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

extends PanelContainer

## A panel which is shown when the player is adding an object to the room.
##
## This scene is essentially the interface for the [PlaceTool].


## Fired when the player starts to place a piece.
signal start_placing()

## Fired when the player has stopped placing a piece.
signal stop_placing()


## A reference to the [PlayerController].
##
## This needs to be set by the main game script at the start of the game.
## TODO: Make into a script only and have it be typed?
var player_controller: Node = null


# The name of the tool the player was using before the place tool was enabled.
var _previous_tool := ""


func _unhandled_input(event: InputEvent):
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		stop()
		get_tree().set_input_as_handled()


## Start placing the given object into the room.
func start(piece_entry: AssetEntryScene) -> void:
	if visible:
		push_warning("Cannot start place object panel, already started")
		return
	
	if player_controller == null:
		push_error("Cannot start place object panel, controller reference not set")
		return
	
	_previous_tool = player_controller.current_tool
	if _previous_tool == "PlaceTool":
		push_error("Cannot start place object panel, controller is already using place tool")
		return
	
	player_controller.current_tool = "PlaceTool"
	var place_tool: PlaceTool = player_controller.get_current_tool_node()
	place_tool.start_placing(piece_entry)
	
	visible = true
	emit_signal("start_placing")


## Stop placing objects, and return to the controller's previous state.
func stop() -> void:
	if player_controller != null:
		if player_controller.current_tool == "PlaceTool":
			var place_tool: PlaceTool = player_controller.get_current_tool_node()
			place_tool.stop_placing() # Free the preview from memory.
			
			player_controller.current_tool = _previous_tool
		else:
			push_warning("Current player tool is not place tool")
	else:
		push_error("Player controller reference not set")
	
	visible = false
	emit_signal("stop_placing")
