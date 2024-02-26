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

tool
class_name CharEdit
extends VBoxContainer

## A [LineEdit] that contains a maximum of one character, with buttons that
## cycle through the alphabet when pressed.


## Fired when attempting to input text that is too long to fit in the [LineEdit].
signal text_change_rejected(rejected_substring)

## Fired when the player enters text into the [LineEdit].
signal text_changed(new_text)

## Fired when the player presses the Enter key on the [LineEdit].
signal text_entered(new_text)


## The list of valid characters in a [String]. Also defines the order of the
## characters when they are decremented or incremented.
const VALID_CHARACTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


## The text shown in the [LineEdit].
export(String) var text: String setget set_text, get_text

## The placeholder text for the [LineEdit].
export(String) var placeholder_text := "" setget set_placeholder_text, \
		get_placeholder_text

## The font used for the [LineEdit].
export(Font) var font_override: Font setget set_font_override, get_font_override

## The horizontal size of the [LineEdit], determined by how many space
## characters could fit in before scrolling was activated.
export(int) var minimum_spaces := 12 setget set_minimum_spaces, get_minimum_spaces


# The button that decrements the current character, i.e. it goes backwards
# through the alphabet.
var _decrement_button: TextureButton = null

# The line edit that contains the current character.
var _line_edit: LineEdit = null

# The button that increments the current character, i.e. it goes forwards
# through the alphabet.
var _increment_button: TextureButton = null


func _init():
	_decrement_button = TextureButton.new()
	_decrement_button.texture_normal = preload("up_arrow_normal.svg")
	_decrement_button.texture_pressed = preload("up_arrow_pressed.svg")
	_decrement_button.texture_hover = preload("up_arrow_hover.svg")
	_decrement_button.texture_disabled = preload("up_arrow_disabled.svg")
	_decrement_button.texture_focused = preload("up_arrow_focused.svg")
	_decrement_button.texture_click_mask = preload("up_arrow_click_mask.svg")
	_decrement_button.expand = true
	_decrement_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_decrement_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_decrement_button.connect("pressed", self, "_on_decrement_button_pressed")
	
	_increment_button = TextureButton.new()
	_increment_button.texture_normal = preload("up_arrow_normal.svg")
	_increment_button.texture_pressed = preload("up_arrow_pressed.svg")
	_increment_button.texture_hover = preload("up_arrow_hover.svg")
	_increment_button.texture_disabled = preload("up_arrow_disabled.svg")
	_increment_button.texture_focused = preload("up_arrow_focused.svg")
	# This texture does not get flipped by 'flip_v':
	_increment_button.texture_click_mask = preload("down_arrow_click_mask.svg")
	_increment_button.flip_v = true
	_increment_button.expand = true
	_increment_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_increment_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_increment_button.connect("pressed", self, "_on_increment_button_pressed")
	
	_line_edit = LineEdit.new()
	_line_edit.align = LineEdit.ALIGN_CENTER
	_line_edit.max_length = 1
	_line_edit.virtual_keyboard_enabled = false
	_line_edit.placeholder_alpha = 0.1
	_line_edit.focus_mode = Control.FOCUS_CLICK
	_line_edit.connect("text_change_rejected", self, "_on_text_change_rejected")
	_line_edit.connect("text_changed", self, "_on_text_changed")
	_line_edit.connect("text_entered", self, "_on_text_entered")
	
	add_child(_decrement_button)
	add_child(_line_edit)
	add_child(_increment_button)


## Take the focus and pass it to the [LineEdit].
func take_focus() -> void:
	if _line_edit == null:
		return
	
	_line_edit.grab_focus()
	
	# Set the caret position to after the character, so that the player has the
	# opportunity to press Backspace straight away.
	_line_edit.caret_position = _line_edit.text.length()


func get_text() -> String:
	if _line_edit == null:
		return ""
	
	return _line_edit.text


func get_placeholder_text() -> String:
	if _line_edit == null:
		return ""
	
	return _line_edit.placeholder_text


func get_font_override() -> Font:
	if _line_edit == null:
		return null
	
	if not _line_edit.has_font_override("font"):
		return null
	
	return _line_edit.get_font("font")


func get_minimum_spaces() -> int:
	if _line_edit == null:
		return 0
	
	# Return the default value if there is no override.
	return _line_edit.get_constant("minimum_spaces")


func set_text(value: String) -> void:
	if _line_edit == null:
		return
	
	if value.length() > 1:
		value = value[0]
	
	value = value.to_upper()
	if not value.empty():
		if not value in VALID_CHARACTERS:
			return
	
	_line_edit.text = value


func set_placeholder_text(value: String) -> void:
	if _line_edit == null:
		return
	
	_line_edit.placeholder_text = value


func set_font_override(value: Font) -> void:
	if _line_edit == null:
		return
	
	_line_edit.add_font_override("font", value)


func set_minimum_spaces(value: int) -> void:
	if _line_edit == null:
		return
	
	_line_edit.add_constant_override("minimum_spaces", value)


# Offset the current character by a given amount. If the [LineEdit] is currently
# empty, then the first valid character is set instead.
func _offset_char(offset: int) -> void:
	if _line_edit == null:
		return
	
	var current_char := _line_edit.text
	var current_index := -1
	if not current_char.empty():
		current_index = VALID_CHARACTERS.find(current_char)
	
	var new_index := 0
	if current_index >= 0:
		new_index = (current_index + offset) % VALID_CHARACTERS.length()
	var new_char := VALID_CHARACTERS[new_index]
	
	_line_edit.text = new_char


func _on_text_change_rejected(rejected_substring: String):
	emit_signal("text_change_rejected", rejected_substring)


func _on_text_changed(new_text: String):
	new_text = new_text.to_upper()
	if not new_text.empty():
		if not new_text in VALID_CHARACTERS:
			_line_edit.text = ""
			return
	
	_line_edit.text = new_text
	emit_signal("text_changed", new_text)


func _on_text_entered(new_text: String):
	emit_signal("text_entered", new_text)


func _on_decrement_button_pressed():
	_offset_char(-1)


func _on_increment_button_pressed():
	_offset_char(1)
