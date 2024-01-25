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

extends AttentionPanel

## A dialog asking the player if they want to keep the new video settings that
## have just been applied.


## Fired if the player wishes to keep the new video settings.
signal keeping_changes()

## Fired if the player wishes to discard the new video settings.
signal discarding_changes()


onready var _countdown_label := $MarginContainer/MainContainer/LabelContainer/CountdownLabel
onready var _countdown_timer := $CountdownTimer


func _ready():
	# Don't just close when "ui_cancel" is pressed, since we want to fire at
	# least one of the two signals.
	close_on_cancel = false


func _process(_delta):
	if _countdown_timer.is_stopped():
		return
	
	var time_left := ceil(_countdown_timer.time_left)
	_countdown_label.text = tr("Changes will be automatically discarded in %.0f seconds…") % time_left


func _unhandled_input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		_on_DiscardButton_pressed()
		
		get_tree().set_input_as_handled()


func _on_OptionsKeepVideoDialog_about_to_show():
	_countdown_timer.start()


func _on_OptionsKeepVideoDialog_popup_hide():
	_countdown_timer.stop()


func _on_DiscardButton_pressed():
	visible = false
	emit_signal("discarding_changes")


func _on_KeepButton_pressed():
	visible = false
	emit_signal("keeping_changes")


func _on_CountdownTimer_timeout():
	_on_DiscardButton_pressed()
