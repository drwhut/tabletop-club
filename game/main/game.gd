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

extends Node

## The main node, which connects all of the game components together.


## The list of possible menu states we can be in.
enum MenuState {
	STATE_MAIN_MENU, # There is a menu visible, and we are not in-game.
	STATE_GAME_MENU, # There is a menu visible, and we are in-game.
	STATE_NO_MENU,   # There is currently no menu, and we are in-game.
	STATE_MAX        # Used for validation only.
}


## States whether we are in the main menu, the in-game menu, or if there is no
## menu currently visible.
var menu_state: int = MenuState.STATE_MAIN_MENU setget set_menu_state


# Last frame, was the player controller capturing mouse movement?
var _player_controller_using_mouse_last_frame := false


onready var _chat_window := $ChatWindow
onready var _main_menu := $MainMenu
onready var _main_menu_camera := $MainMenuCamera
onready var _menu_background: ColorRect = $MenuBackground
onready var _player_controller := $PlayerController


func _ready():
	# Since we have access to all components of the game here, establish the
	# necessary inter-child dependencies.
	var camera_controller: CameraController = _player_controller.get_camera_controller()
	var player_camera: Camera = camera_controller.get_camera()
	_main_menu_camera.camera_transition_to = player_camera
	
	# Initialize the main menu state.
	set_menu_state(MenuState.STATE_MAIN_MENU)
	
	# As this is the root node for the entire game, this should be the last node
	# to receive the ready signal. Therefore, all nodes should now be ready to
	# receive the apply_settings signal from GameConfig.
	GameConfig.apply_all()


func _process(_delta: float):
	# Check what type of control (if any) has focus right now. If it is one that
	# the player can type into, then we need to stop the player and camera
	# controllers from processing key events. We need to do this since they use
	# the inputs regardless of whether they have been handled or not, because
	# they are constantly checking for controller stick inputs.
	# NOTE: This does not prevent the arrow keys from affecting the camera's
	# rotation while the player is navigating through a window.
	# TODO: Find a nice way to prevent the arrow keys from doing this.
	var control_in_focus := _menu_background.get_focus_owner()
	_player_controller.ignore_key_events = (
		(control_in_focus is LineEdit) or (control_in_focus is TextEdit)
	)
	
	# Check if the player controller has just started, or just stopped, using
	# mouse movement. We need to check so that we can either enable or disable
	# the chat window to give the mouse as much screen real estate as possible.
	var player_controller_using_mouse_this_frame: bool = \
			_player_controller.is_using_mouse()
	
	if (
		player_controller_using_mouse_this_frame !=
		_player_controller_using_mouse_last_frame
	):
		_chat_window.disabled = player_controller_using_mouse_this_frame
	
	_player_controller_using_mouse_last_frame = \
			player_controller_using_mouse_this_frame


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("game_menu"):
		if menu_state == MenuState.STATE_GAME_MENU:
			# Do not hide the main menu if one of its panels is currently being
			# shown to the player.
			if _main_menu.is_popup_visible():
				return
			
			set_menu_state(MenuState.STATE_NO_MENU)
			get_tree().set_input_as_handled()
		elif menu_state == MenuState.STATE_NO_MENU:
			set_menu_state(MenuState.STATE_GAME_MENU)
			get_tree().set_input_as_handled()
	
	elif event.is_action_pressed("ui_cancel"):
		if menu_state == MenuState.STATE_GAME_MENU:
			# We don't need to check if any of the main menu's panels are being
			# shown, since the "ui_cancel" input will be handled by them before
			# it is handled by us.
			set_menu_state(MenuState.STATE_NO_MENU)
			get_tree().set_input_as_handled()
	
	elif event is InputEventMouseButton:
		# If the player clicks on a blank space on the screen, then remove the
		# focus from any control that has it.
		# NOTE: For some reason this only works properly with mouse inputs - for
		# key events used on a GUI, the event is still propagated, whereas mouse
		# inputs are not.
		# TODO: Confirm this works as intended when there is a popup visible,
		# for example, the Objects window.
		if menu_state == MenuState.STATE_NO_MENU:
			if (
				event.pressed and (
					event.button_index == BUTTON_LEFT or
					event.button_index == BUTTON_RIGHT
				)
			):
				var control_with_focus := _menu_background.get_focus_owner()
				if control_with_focus != null:
					control_with_focus.release_focus()
				
				get_tree().set_input_as_handled()


func set_menu_state(value: int) -> void:
	if value < 0 or value >= MenuState.STATE_MAX:
		push_error("Invalid value '%d' for MenuState" % value)
		return
	
	var old_state := menu_state
	menu_state = value
	
	# While the menu is visible, the player should not be able to control the
	# camera.
	_player_controller.disabled = (menu_state != MenuState.STATE_NO_MENU)
	
	# Only show the transparent background if we are in the in-game menu, not
	# the main menu.
	_menu_background.visible = (menu_state == MenuState.STATE_GAME_MENU)
	
	# Show the menu if the state requires us to.
	_main_menu.visible = (menu_state != MenuState.STATE_NO_MENU)
	
	# If we are in-game, we'll need to show the player a different set of
	# buttons in the menu compared to if we are in the main menu.
	_main_menu.ingame_buttons_visible = (menu_state != MenuState.STATE_MAIN_MENU)
	
	# Have the main menu take the keyboard focus if it is now visible.
	if _main_menu.visible:
		_main_menu.take_focus()
	
	if menu_state == MenuState.STATE_MAIN_MENU:
		# If the jukebox is not already playing, start it.
		if not _main_menu.jukebox.is_playing_track():
			_main_menu.jukebox.play_current_track()
		
		# If we just came from in-game, then start moving the camera towards
		# orbit around the centre of the room, and reset the player camera.
		if old_state != MenuState.STATE_MAIN_MENU:
			_main_menu_camera.state = MainMenuCamera.CameraState.STATE_PLAYER_TO_ORBIT
			_player_controller.reset()
	else:
		# If the jukebox is playing outside of the main menu, start fading it.
		if _main_menu.jukebox.is_playing_track():
			_main_menu.jukebox.start_fading_out()
		
		# If we just came from the main menu, then start transitioning the
		# camera from orbit to the player's camera.
		if old_state == MenuState.STATE_MAIN_MENU:
			_main_menu_camera.state = MainMenuCamera.CameraState.STATE_ORBIT_TO_PLAYER


func _on_ChatWindow_text_entered(text: String):
	var command_parser := CommandParser.new()
	command_parser.parse_command(text)


func _on_ChatWindow_focus_leaving():
	# If the focus is leaving the chat window, we need to pass it back to one of
	# the main menu buttons if it is visible so it doesn't get lost.
	if _main_menu.visible:
		_main_menu.take_focus()


func _on_MainMenu_starting_singleplayer():
	set_menu_state(MenuState.STATE_NO_MENU)


func _on_MainMenu_returning_to_game():
	set_menu_state(MenuState.STATE_NO_MENU)


func _on_MainMenu_exiting_to_main_menu():
	set_menu_state(MenuState.STATE_MAIN_MENU)


func _on_MainMenu_popup_about_to_show():
	_chat_window.disabled = true


func _on_MainMenu_popup_about_to_hide():
	_chat_window.disabled = false
