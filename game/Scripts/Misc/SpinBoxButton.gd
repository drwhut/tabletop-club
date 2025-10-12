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

tool
extends HBoxContainer

class_name SpinBoxButton

signal pressed(value)

export(int) var max_value: int = 100 setget set_max_value, get_max_value
export(String) var prefix: String = "" setget set_prefix, get_prefix
export(String) var text: String = "" setget set_text, get_text

var _button: Button
var _spin_box: SpinBox

# Get the maximum value of the spin box.
# Returns: The maximum value of the spin box.
func get_max_value() -> int:
	return max_value

# Get the prefix used on the spin box.
# Returns: The prefix used on the spin box.
func get_prefix() -> String:
	return prefix

# Get the text displayed on the button.
# Returns: The text displayed on the button.
func get_text() -> String:
	return text

# Set the maximum value of the spin box.
# new_max_value: The new maximum value.
func set_max_value(new_max_value: int) -> void:
	max_value = new_max_value
	_spin_box.max_value = new_max_value

# Set the prefix used on the spin box.
# new_prefix: The new prefix.
func set_prefix(new_prefix: String) -> void:
	prefix = new_prefix
	_spin_box.prefix = prefix

# Set the text displayed on the button.
# new_text: The new text.
func set_text(new_text: String) -> void:
	text = new_text
	_button.text = text

func _init():
	_button = Button.new()
	_button.connect("pressed", self, "_on_button_pressed")
	add_child(_button)
	
	_spin_box = SpinBox.new()
	_spin_box.min_value = 1.0
	_spin_box.rect_min_size.x = 80.0
	add_child(_spin_box)

func _on_button_pressed():
	emit_signal("pressed", _spin_box.value)
