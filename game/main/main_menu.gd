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

extends Control

## The main menu of the game.


## Fired when the player wants to start a singleplayer game.
signal starting_singleplayer()

## Fired when the player wants to return to the game after looking at the menu.
signal returning_to_game()

## Fired when the player wants to exit the current game and return to the main
## menu.
signal exiting_to_main_menu()

## Fired when a popup is about to be shown in the main menu.
signal popup_about_to_show()

## Fired when a popup is about to be hidden in the main menu.
signal popup_about_to_hide()


## If [code]true[/code], the leave and return buttons are shown instead of the
## singleplayer and multiplayer ones.
var ingame_buttons_visible := false setget set_ingame_buttons_visible, \
		get_ingame_buttons_visible


## The jukebox that plays music while in the main menu.
onready var jukebox := $MainMenuJukebox

onready var _animation_player := $AnimationPlayer
onready var _credits_panel := $CreditsPanel
onready var _game_info_panel := $GameInfoPanel
onready var _leave_button := $MainContainer/PrimaryContainer/LeaveButton
onready var _leave_dialog := $LeaveDialog
onready var _multiplayer_button := $MainContainer/PrimaryContainer/MultiplayerButton
onready var _options_panel := $OptionsPanel
onready var _return_button := $MainContainer/PrimaryContainer/ReturnButton
onready var _singleplayer_button := $MainContainer/PrimaryContainer/SingleplayerButton
onready var _quit_dialog := $QuitDialog
onready var _website_panel := $WebsitePanel


func _ready():
	# We want to emit signals whenever any of the popups are shown or hidden.
	for child in get_children():
		if child is Popup:
			child.connect("about_to_show", self, "_on_popup_about_to_show")
			child.connect("popup_hide", self, "_on_popup_about_to_hide")
	
	_animation_player.play("FadeInMenu")


## Check if one of the main menu's panels or windows (e.g. the options panel) is
## currently visible or not.
func is_popup_visible() -> bool:
	for child in get_children():
		if child is Popup:
			if child.visible:
				return true
	
	return false


## Take the global focus and place it on one of the main menu's buttons.
func take_focus() -> void:
	if _singleplayer_button.visible:
		_singleplayer_button.grab_focus()
	else:
		_return_button.grab_focus()


func set_ingame_buttons_visible(value: bool) -> void:
	_leave_button.visible = value
	_return_button.visible = value
	
	_singleplayer_button.visible = not value
	_multiplayer_button.visible = not value


func get_ingame_buttons_visible() -> bool:
	return _return_button.visible


func _on_SingleplayerButton_pressed():
	emit_signal("starting_singleplayer")


func _on_ReturnButton_pressed():
	emit_signal("returning_to_game")


func _on_LeaveButton_pressed():
	_leave_dialog.popup_centered()


func _on_OptionsButton_pressed():
	_options_panel.popup_centered()


func _on_CreditsButton_pressed():
	_credits_panel.popup_centered()


func _on_WebsiteButton_pressed():
	_website_panel.popup_centered()


func _on_InfoButton_pressed():
	_game_info_panel.popup_centered()


func _on_QuitButton_pressed():
	_quit_dialog.popup_centered()


func _on_LeaveDialog_leaving_session():
	emit_signal("exiting_to_main_menu")


func _on_popup_about_to_show():
	emit_signal("popup_about_to_show")


func _on_popup_about_to_hide():
	emit_signal("popup_about_to_hide")
