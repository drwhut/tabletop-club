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

class_name ChatLineEdit
extends LineEdit

## A specialised [LineEdit] which stores the history of text that is entered.


## An entry containing a message that was entered.
class TextEntry:
	extends Reference
	
	## The text that was actually entered.
	var base_text := ""
	
	## If the text is being modified, the changes are stored here. If the string
	## is empty, then [member base_text] should be used instead.
	var working_text := ""
	
	
	## If the text has been modified, return the modified text. Otherwise,
	## return what was originally entered.
	func get_text() -> String:
		return base_text if working_text.empty() else working_text


## Fired when a text entry is added to the history list.
## [b]NOTE:[/b] This signal is fired alongside [signal text_entered], however,
## it may be preferable to connect to this signal instead, as the text will be
## validated.
signal entry_added(entry_text)


## The maximum number of text entries to store. If the history goes over this
## limit, the earliest entries are removed first.
const HISTORY_SIZE_MAX := 100


# The list of text that has been entered into this line edit.
# NOTE: The last entry is always empty, as it is the "default" entry to be
# modified by the player. Any new entries are inserted just before it.
# TODO: Make array typed in 4.x
var _text_history: Array = [ TextEntry.new() ]

# The index of the entry to modify when the player types into the line edit.
var _modify_index := 0


func _ready():
	connect("text_changed", self, "_on_text_changed")
	connect("text_entered", self, "_on_text_entered")


func _input(event: InputEvent):
	if not has_focus():
		return
	
	if event is InputEventKey:
		if event.scancode == KEY_UP and event.pressed:
			if decrement_index():
				show_current()
				get_tree().set_input_as_handled()
		elif event.scancode == KEY_DOWN and event.pressed:
			if increment_index():
				show_current()
				get_tree().set_input_as_handled()


func _unhandled_input(event: InputEvent):
	if has_focus():
		return
	
	if event.is_action_pressed("game_chat"):
		# Since the Enter key is also used for "ui_accept", only register it if
		# nothing currently has focus.
		var control_with_focus := get_focus_owner()
		if control_with_focus != null:
			return
		
		grab_focus()
		caret_position = text.length()
		
		get_tree().set_input_as_handled()
	
	elif event.is_action_pressed("game_command"):
		# Since the '/' key is not used anywhere else, transfer the focus even
		# if another control currently has it.
		grab_focus()
		
		text = "/"
		caret_position = text.length()
		
		get_tree().set_input_as_handled()


## Add a text entry to the end of the history list.
func append_entry(new_text: String) -> void:
	var text_entry := TextEntry.new()
	text_entry.base_text = new_text
	
	var index := _text_history.size() - 1
	_text_history.insert(index, text_entry)
	
	emit_signal("entry_added", new_text)
	
	while _text_history.size() > HISTORY_SIZE_MAX:
		_text_history.pop_front()


## Set the text to the current entry's value.
func show_current() -> void:
	var current_entry: TextEntry = _text_history[_modify_index]
	text = current_entry.get_text()
	caret_position = text.length()


## Modify the current entry's value.
func modify_current(new_text: String) -> void:
	var current_entry: TextEntry = _text_history[_modify_index]
	current_entry.working_text = new_text


## Revert the current entry to its original state, if it has been modified.
func revert_current() -> void:
	var current_entry: TextEntry = _text_history[_modify_index]
	current_entry.working_text = ""


## Go back one entry in history by decrementing the current index.
## Returns [code]true[/code] if the operation succeeded.
func decrement_index() -> bool:
	if _modify_index <= 0:
		return false
	
	_modify_index -= 1
	return true


## Go forward one entry in history by incrementing the current index.
## Returns [code]true[/code] if the operation succeeded.
func increment_index() -> bool:
	if _modify_index >= _text_history.size() - 1:
		return false
	
	_modify_index += 1
	return true


## Go to the default, blank entry be resetting the index to the end.
func reset_index() -> void:
	_modify_index = _text_history.size() - 1


func _on_text_changed(new_text: String):
	modify_current(new_text)


func _on_text_entered(new_text: String):
	new_text = new_text.strip_edges().strip_escapes()
	if new_text.empty():
		return
	
	var is_past_entry := (_modify_index < _text_history.size() - 1)
	
	revert_current()
	append_entry(new_text)
	reset_index()
	
	# If the blank entry was modified as well as the past entry, then the blank
	# entry needs to be reverted as well.
	if is_past_entry:
		revert_current()
	
	show_current()
