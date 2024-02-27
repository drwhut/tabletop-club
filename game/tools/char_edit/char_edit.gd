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


## A modified version of [LineEdit] that allows the focus to be transferred
## horizontally when pressing either 'ui_left' or 'ui_right' when the caret is
## at the beginning and end of the text respectively.
class ModifiedLineEdit:
	extends LineEdit
	
	func _gui_input(event: InputEvent):
		var focus_path := NodePath()
		var event_is_ui_right := false
		
		if event.is_action_pressed("ui_left", true):
			if caret_position == 0:
				focus_path = focus_neighbour_left
		
		elif event.is_action_pressed("ui_right", true):
			event_is_ui_right = true
			if caret_position == text.length():
				focus_path = focus_neighbour_right
		
		if focus_path.is_empty():
			return
		
		accept_event()
		
		var to_focus: Control = get_node(focus_path)
		# This hack is needed since the editor can't see the LineEdit within a
		# CharEdit, so we need to use the [method CharEdit.take_focus] method.
		# But using the class name results in a cyclical reference. Bleh.
		if to_focus.has_method("take_focus"):
			to_focus.take_focus(event_is_ui_right)
		else:
			to_focus.grab_focus()


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

## Whether the text in the [LineEdit] should be secret or not.
export(bool) var secret := false setget set_secret, is_secret

## The font used for the [LineEdit].
export(Font) var font_override: Font setget set_font_override, get_font_override

## The horizontal size of the [LineEdit], determined by how many space
## characters could fit in before scrolling was activated.
export(int) var minimum_spaces := 12 setget set_minimum_spaces, get_minimum_spaces

## The path to a control to the left of the [LineEdit] where the focus can go.
export(NodePath) var focus_left := NodePath() setget set_focus_left, get_focus_left

## The path to a control to the right of the [LineEdit] where the focus can go.
export(NodePath) var focus_right := NodePath() setget set_focus_right, get_focus_right


# The button that decrements the current character, i.e. it goes backwards
# through the alphabet.
var _decrement_button: TextureButton = null

# The line edit that contains the current character.
var _line_edit: ModifiedLineEdit = null

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
	
	_line_edit = ModifiedLineEdit.new()
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


## Take the focus and pass it to the [LineEdit]. If [param caret_at_beginning]
## is [code]true[/code], the [member LineEdit.caret_position] will be placed at
## the beginning of the text. Otherwise, it will be placed at the end, so that
## the player can immediately press backspace to remove the character.
func take_focus(caret_at_beginning: bool = false) -> void:
	if _line_edit == null:
		return
	
	_line_edit.grab_focus()
	
	_line_edit.caret_position = 0 if caret_at_beginning \
			else _line_edit.text.length()


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


func get_focus_left() -> NodePath:
	if _line_edit == null:
		return NodePath()
	
	var line_edit_path := _line_edit.focus_neighbour_left
	if line_edit_path.is_empty():
		return NodePath()
	
	# Remove the "../" prefix.
	var path := String(line_edit_path).substr(3)
	return NodePath(path)


func get_focus_right() -> NodePath:
	if _line_edit == null:
		return NodePath()
	
	var line_edit_path := _line_edit.focus_neighbour_right
	if line_edit_path.is_empty():
		return NodePath()
	
	# Remove the "../" prefix.
	var path := String(line_edit_path).substr(3)
	return NodePath(path)


func is_secret() -> bool:
	if _line_edit == null:
		return false
	
	return _line_edit.secret


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


func set_secret(value: bool) -> void:
	if _line_edit == null:
		return
	
	_line_edit.secret = value


func set_font_override(value: Font) -> void:
	if _line_edit == null:
		return
	
	_line_edit.add_font_override("font", value)


func set_minimum_spaces(value: int) -> void:
	if _line_edit == null:
		return
	
	_line_edit.add_constant_override("minimum_spaces", value)


func set_focus_left(new_path: NodePath) -> void:
	if _line_edit == null:
		return
	
	if new_path.is_empty():
		_line_edit.focus_neighbour_left = NodePath()
		return
	
	var path_str := String(new_path)
	_line_edit.focus_neighbour_left = "..".plus_file(path_str)


func set_focus_right(new_path: NodePath) -> void:
	if _line_edit == null:
		return
	
	if new_path.is_empty():
		_line_edit.focus_neighbour_right = NodePath()
		return
	
	var path_str := String(new_path)
	_line_edit.focus_neighbour_right = "..".plus_file(path_str)


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
	
	# Re-setting the LineEdit's text does weird things with the caret position,
	# so make sure it's after the character if it was just typed in.
	_line_edit.caret_position = new_text.length()
	
	emit_signal("text_changed", new_text)


func _on_text_entered(new_text: String):
	emit_signal("text_entered", new_text)


func _on_decrement_button_pressed():
	_offset_char(-1)


func _on_increment_button_pressed():
	_offset_char(1)
