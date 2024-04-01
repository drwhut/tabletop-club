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

extends Node

## The player controller, which allows the player to interface with the room
## and manipulate objects.


## Stop all processing for the player controller and the camera.
export(bool) var disabled: bool setget set_disabled, is_disabled

## Sets whether [InputEventKey] events are ignored by the player controller.
## This also affects the camera controller.
## [b]NOTE:[/b] This is not the same as [member disabled], which stops all input
## processing entirely.
export(bool) var ignore_key_events := false setget set_ignore_key_events


onready var _third_person_camera: CameraController = $ThirdPersonCamera

# NOTE: We don't need to disable all of the tools at the start, since the main
# game script disables the entire player controller at the start of the game.
onready var _cursor_tool: CursorTool = $CursorTool
onready var _tool_list := [ _cursor_tool ]


func _ready():
	# Give each of the tools a reference to the camera, so that they can perform
	# raycasting.
	for element in _tool_list:
		var player_tool: PlayerTool = element
		player_tool.camera = _third_person_camera.get_camera()


## Get the currently active camera controller.
func get_camera_controller() -> CameraController:
	return _third_person_camera


## Get a reference to the currently active tool.
func get_current_tool() -> PlayerTool:
	# TODO: Add the ability to switch tools, return null if no tool is active.
	return _cursor_tool


## Returns [code]true[/code] if either the PlayerController or the currently
## active CameraController is capturing mouse movement.
func is_using_mouse() -> bool:
	if is_disabled():
		return false
	
	return get_camera_controller().is_using_mouse()


## Reset the player controller to its default state.
func reset() -> void:
	get_camera_controller().reset_transform()
	
	# TODO: Reset the tools here as well?


func is_disabled() -> bool:
	return not is_processing()


func set_disabled(value: bool) -> void:
	var enable := not value
	
	set_process(enable)
	set_physics_process(enable)
	set_process_input(enable)
	set_process_unhandled_input(enable)
	set_process_unhandled_key_input(enable)
	
	_third_person_camera.set_process(enable)
	_third_person_camera.set_physics_process(enable)
	_third_person_camera.set_process_input(enable)
	_third_person_camera.set_process_unhandled_input(enable)
	_third_person_camera.set_process_unhandled_key_input(enable)


func set_ignore_key_events(value: bool) -> void:
	ignore_key_events = value
	
	_third_person_camera.ignore_key_events = value
