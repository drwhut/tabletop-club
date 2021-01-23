# open-tabletop
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows
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

extends Button

class_name BindButton

signal rebinding_action(action)

export(String) var action: String
var input_event: InputEvent = null

# Get the input event corresponding to the action this button represents.
# Returns: The corresponding input event, or null if there is no input event
# for the action.
func get_action_input_event() -> InputEvent:
	if input_event:
		return input_event
	
	if not InputMap.has_action(action):
		return null
	
	var events = InputMap.get_action_list(action)
	if events.empty():
		return null
	
	return events[0]

# Update the button's text to represent the action's bind.
func update_text() -> void:
	var event = get_action_input_event()
	if not event:
		text = "Not bound"
	
	if event is InputEventKey:
		text = OS.get_scancode_string(event.scancode)
	elif event is InputEventMouseButton:
		match event.button_index:
			BUTTON_LEFT:
				text = "Left Mouse Button"
			BUTTON_RIGHT:
				text = "Right Mouse Button"
			BUTTON_MIDDLE:
				text = "Middle Mouse Button"
			BUTTON_XBUTTON1:
				text = "Extra Mouse Button 1"
			BUTTON_XBUTTON2:
				text = "Extra Mouse Button 2"
			BUTTON_WHEEL_UP:
				text = "Mouse Wheel Up"
			BUTTON_WHEEL_DOWN:
				text = "Mouse Wheel Down"
			BUTTON_WHEEL_LEFT:
				text = "Mouse Wheel Left"
			BUTTON_WHEEL_RIGHT:
				text = "Mouse Wheel Right"
			_:
				text = "Unknown Mouse Button"
	else:
		text = "Unknown event type"

func _ready():
	connect("pressed", self, "_on_pressed")
	
	update_text()

func _on_pressed() -> void:
	emit_signal("rebinding_action", action)
