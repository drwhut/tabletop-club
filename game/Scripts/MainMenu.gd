# tabletop-club
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021 Tabletop Club contributors (see game/CREDITS.tres).
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

extends Control

onready var _credits_dialog = $CreditsDialog
onready var _credits_label = $CreditsDialog/CreditsLabel
onready var _error_dialog = $ErrorDialog
onready var _options_menu = $OptionsMenu
onready var _random_music_player = $RandomMusicPlayer
onready var _room_code_edit = $CenterContainer/VBoxContainer/JoinContainer/RoomCodeEdit

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# Display an error.
# error: The error to display.
func display_error(error: String) -> void:
	_error_dialog.dialog_text = error
	_error_dialog.popup_centered()

func _ready():
	_update_credits_text()

# Update the credits dialog text.
func _update_credits_text() -> void:
	var credits_file = preload("res://CREDITS.tres")
	
	var credits_text = credits_file.text
	credits_text = credits_text.replace("ALPHA TESTERS", tr("Alpha Testers"))
	credits_text = credits_text.replace("CONTRIBUTORS", tr("Contributors"))
	credits_text = credits_text.replace("CURSORS", tr("Cursors"))
	credits_text = credits_text.replace("DEVELOPERS", tr("Developers"))
	credits_text = credits_text.replace("FONTS", tr("Fonts"))
	credits_text = credits_text.replace("IMAGES", tr("Images"))
	credits_text = credits_text.replace("TOOL ICONS", tr("Tool Icons"))
	credits_text = credits_text.replace("TRANSLATORS", tr("Translators"))
	
	credits_text = credits_text.replace("FRENCH", tr("French"))
	
	var credits_lines = credits_text.split("\n")
	
	for i in range(credits_lines.size() - 1, -1, -1):
		var line = credits_lines[i]
		if line.begins_with("-"):
			credits_lines[i - 1] = "[i]" + credits_lines[i - 1] + "[/i]"
			credits_lines.remove(i)
		elif line.begins_with("="):
			credits_lines[i - 1] = "[u]" + credits_lines[i - 1] + "[/u]"
			credits_lines.remove(i)
	
	_credits_label.bbcode_text = "[center]"
	for line in credits_lines:
		_credits_label.bbcode_text += line + "\n"
	_credits_label.bbcode_text += "[/center]"

func _on_SingleplayerButton_pressed():
	Global.start_game_singleplayer()

func _on_HostGameButton_pressed():
	Global.start_game_as_server()

func _on_RoomCodeEdit_text_changed(new_text: String):
	var caret_position = _room_code_edit.caret_position
	_room_code_edit.text = new_text.to_upper()
	_room_code_edit.caret_position = caret_position

func _on_JoinGameButton_pressed():
	var room_code = _room_code_edit.text.to_upper()
	
	if room_code.length() != 4:
		display_error(tr("Room code must be four characters long!"))
		return
	
	for c in room_code:
		if not c in ALPHABET:
			display_error(tr("Invalid room code!"))
			return
	
	Global.start_game_as_client(room_code)

func _on_OptionsButton_pressed():
	_options_menu.visible = true

func _on_OptionsMenu_locale_changed(_locale: String):
	_update_credits_text()
	_random_music_player.update_label_text()

func _on_CreditsButton_pressed():
	_credits_dialog.popup_centered()

func _on_QuitButton_pressed():
	get_tree().quit()
