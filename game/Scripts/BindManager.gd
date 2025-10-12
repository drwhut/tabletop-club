# tabletop-club
# Copyright (c) 2020-2025 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2025 Tabletop Club contributors (see game/CREDITS.tres).
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

# Get the input event that is assigned to the given action.
# Returns: The input event assigned to the given action, null if it is not
# assigned.
# action: The action to get the input event for.
func get_action_input_event(action: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	
	var events = InputMap.get_action_list(action)
	if events.empty():
		return null
	
	return events[0]

# Get the text representing the input event assigned to the given action.
# NOTE: This is a shortcut for get_action_input_event -> get_input_event_text.
# Returns: The text representing the input event assigned to the given action.
# action: The action to get the input event from.
func get_action_input_event_text(action: String) -> String:
	return get_input_event_text(get_action_input_event(action))

# Get the text representing the given input event.
# Returns: The text representing the given input event.
# event: The input event to get a text representation of.
func get_input_event_text(event: InputEvent) -> String:
	if not event:
		return tr("Not bound")
	
	if event is InputEventKey:
		return OS.get_scancode_string(event.scancode)
	elif event is InputEventMouseButton:
		match event.button_index:
			BUTTON_LEFT:
				return tr("Left Mouse Button")
			BUTTON_RIGHT:
				return tr("Right Mouse Button")
			BUTTON_MIDDLE:
				return tr("Middle Mouse Button")
			BUTTON_XBUTTON1:
				return tr("Extra Mouse Button 1")
			BUTTON_XBUTTON2:
				return tr("Extra Mouse Button 2")
			BUTTON_WHEEL_UP:
				return tr("Mouse Wheel Up")
			BUTTON_WHEEL_DOWN:
				return tr("Mouse Wheel Down")
			BUTTON_WHEEL_LEFT:
				return tr("Mouse Wheel Left")
			BUTTON_WHEEL_RIGHT:
				return tr("Mouse Wheel Right")
			_:
				return tr("Unknown Mouse Button")
	else:
		return tr("Unknown event type")
