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

extends Button

class_name BindButton

signal rebinding_action(action)

export(String) var action: String
var input_event: InputEvent = null

# Get the input event corresponding to the action this button represents.
# Returns: The corresponding input event, or null if there is no input event
# for the action.
func get_button_input_event() -> InputEvent:
	if input_event:
		return input_event
	
	return BindManager.get_action_input_event(action)

# Update the button's text to represent the action's bind.
func update_text() -> void:
	text = BindManager.get_input_event_text(get_button_input_event())

func _ready():
	connect("pressed", self, "_on_pressed")
	
	update_text()

func _on_pressed() -> void:
	emit_signal("rebinding_action", action)
