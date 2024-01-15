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

## Allows the direction buttons on controllers to emit echoed input events.
##
## This will help controller users with specific controls, e.g. [Slider], so
## that they can simply hold a direction button down instead of repeatedly
## tapping it to get the same effect.


## The amount of time the button needs to be held down for before the echo input
## events start being fired.
const CONFIRM_WAIT_TIME_MSEC := 500

## The amount of time inbetween echo events being fired.
## [b]NOTE:[/b] This must be less than [const CONFIRM_WAIT_TIME_MSEC] in order
## to function properly.
const ECHO_WAIT_TIME_MSEC := 30


## The name of the action to fire repeatedly as echo events. If empty, no action
## is currently being pressed down that we can echo.
var action_to_echo := ""

## The time at which the last input event, both real and echo, was fired.
var last_input_event_time_msec := 0


# How long we need to wait before sending another echo event.
var _wait_time_msec := 1000


func _process(_delta):
	if action_to_echo.empty():
		return
	
	# This method allows for multiple echo events per frame, in the event that
	# the framerate of the game has dropped.
	while OS.get_ticks_msec() > last_input_event_time_msec + _wait_time_msec:
		last_input_event_time_msec += _wait_time_msec
		
		# Create a custom action, otherwise if we just repeat the same press
		# event that we started with, then we won't be able to tell the
		# difference between the initial press and echo events.
		var action_event := InputEventAction.new()
		action_event.action = action_to_echo
		action_event.pressed = true
		Input.parse_input_event(action_event)
		
		# The first time an echo event is fired, we can start to increase the
		# rate at which they fire.
		if _wait_time_msec > ECHO_WAIT_TIME_MSEC:
			_wait_time_msec = ECHO_WAIT_TIME_MSEC


func _input(event: InputEvent):
	if event is InputEventJoypadButton:
		if event.pressed:
			for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
				if event.is_action(action):
					action_to_echo = action
					last_input_event_time_msec = OS.get_ticks_msec()
					_wait_time_msec = CONFIRM_WAIT_TIME_MSEC
					
					return
		
		elif not action_to_echo.empty() and event.is_action(action_to_echo):
			action_to_echo = ""
