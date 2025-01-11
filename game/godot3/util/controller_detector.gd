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

## Detects whether a keyboard and mouse, or a controller is being used.
##
## [b]NOTE:[/b] By default, we assume the user is using a keyboard and mouse for
## the purposes of building the UI, and only switch to a controller UI if input
## is detected from this script.


## Fired when a keyboard or mouse event was detected.
signal using_keyboard_and_mouse()

## Fired when a controller event was detected.
signal using_controller()


## The amount of input needed for an [InputEventJoystickMotion] event to trigger
## this script.
const CONTROLLER_DEADZONE := 0.2

## The speed at which a mouse needs to move in order to trigger this script,
## squared.
const MOUSE_MIN_SPEED_SQ := 16.0


# Which type of input was last used?
var _last_input_was_controller := false


func _input(event: InputEvent):
	if event is InputEventJoypadButton:
		_input_detected(true)
	
	elif event is InputEventJoypadMotion:
		if abs(event.axis_value) > CONTROLLER_DEADZONE:
			_input_detected(true)
	
	elif event is InputEventKey:
		_input_detected(false)
	
	elif event is InputEventMouseButton:
		_input_detected(false)
	
	elif event is InputEventMouseMotion:
		if event.speed.length_squared() > MOUSE_MIN_SPEED_SQ:
			_input_detected(false)
	
	elif event is InputEventGesture:
		_input_detected(false)


## Is the player currently using a controller?
func is_using_controller() -> bool:
	return _last_input_was_controller


## Send either [signal using_controller] or [signal using_keyboard_and_mouse],
## depending on which type of input was last used, so that UI elements across
## the game can adjust accordingly.
func send_signal() -> void:
	if _last_input_was_controller:
		emit_signal("using_controller")
	else:
		emit_signal("using_keyboard_and_mouse")


# Called when an input is detected - if the type of input has changed, send a
# signal.
func _input_detected(is_controller: bool) -> void:
	if is_controller == _last_input_was_controller:
		return
	
	_last_input_was_controller = is_controller
	send_signal()
