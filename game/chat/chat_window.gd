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

extends Container

## The chat window, which contains a [ChatTextLabel] and a [ChatLineEdit].


## Fired when the player has entered text in the [ChatLineEdit].
signal text_entered(text)

## Fired when the focus is leaving the chat window.
signal focus_leaving()


## Sets if the window is disabled or not. If the window is disabled, it becomes
## transparent, and the player cannot interact with it.
var disabled: bool setget set_disabled, is_disabled


## Sets if the window is minimized or not.
var minimized: bool setget set_minimized, is_minimized


onready var _chat_panel := $ChatPanel
onready var _chat_line_edit := $ChatLineEdit
onready var _chat_text_label := $ChatPanel/MarginContainer/ChatTextLabel
onready var _exit_focus_capture := $ExitFocusCapture
onready var _maximize_button := $MaximizeButton
onready var _minimize_button := $ChatPanel/MinimizeButton


func is_disabled() -> bool:
	return not _chat_line_edit.editable


func is_minimized() -> bool:
	return _chat_panel.visible


func set_disabled(value: bool) -> void:
	modulate.a = 0.5 if value else 1.0
	
	_chat_line_edit.editable = not value
	
	var control_mouse_filter := Control.MOUSE_FILTER_IGNORE if value \
			else Control.MOUSE_FILTER_STOP
	
	_chat_line_edit.mouse_filter = control_mouse_filter
	_chat_text_label.mouse_filter = control_mouse_filter
	_maximize_button.mouse_filter = control_mouse_filter
	_minimize_button.mouse_filter = control_mouse_filter


func set_minimized(value: bool) -> void:
	_chat_panel.visible = not value
	_chat_line_edit.visible = not value
	_maximize_button.visible = value
	
	if value:
		_maximize_button.grab_focus()
	else:
		_chat_line_edit.grab_focus()


func _on_ChatLineEdit_entry_added(entry_text: String):
	emit_signal("text_entered", entry_text)


func _on_MinimizeButton_pressed():
	set_minimized(true)


func _on_MaximizeButton_pressed():
	set_minimized(false)


func _on_ExitFocusCapture_focus_entered():
	_exit_focus_capture.release_focus()
	emit_signal("focus_leaving")
