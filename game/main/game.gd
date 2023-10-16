# tabletop-club
# Copyright (c) 2020-2023 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2023 Tabletop Club contributors (see game/CREDITS.tres).
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


onready var _main_menu := $MainMenu
onready var _main_menu_camera := $MainMenuCamera
onready var _menu_background := $MenuBackground
onready var _player_controller := $PlayerController


func _ready():
	# Since we have access to all components of the game here, establish the
	# necessary inter-child dependencies.
	var camera_controller: CameraController = _player_controller.get_camera_controller()
	var player_camera: Camera = camera_controller.get_camera()
	_main_menu_camera.camera_transition_to = player_camera
	
	# Initialize the main menu state.
	set_menu_state(MenuState.STATE_MAIN_MENU)


func _unhandled_input(event: InputEvent):
	if event.is_action_released("game_menu"):
		if menu_state == MenuState.STATE_GAME_MENU:
			set_menu_state(MenuState.STATE_NO_MENU)
			get_tree().set_input_as_handled()
		elif menu_state == MenuState.STATE_NO_MENU:
			set_menu_state(MenuState.STATE_GAME_MENU)
			get_tree().set_input_as_handled()


func set_menu_state(value: int) -> void:
	if value < 0 or value >= MenuState.STATE_MAX:
		push_error("Invalid value '%d' for MenuState" % value)
		return
	
	var old_state := menu_state
	menu_state = value
	
	# While the menu is visible, the player should not be able to control the
	# camera.
	get_tree().paused = (menu_state != MenuState.STATE_NO_MENU)
	
	# Only show the transparent background if we are in the in-game menu, not
	# the main menu.
	_menu_background.visible = (menu_state == MenuState.STATE_GAME_MENU)
	
	# Show the menu if the state requires us to.
	_main_menu.visible = (menu_state != MenuState.STATE_NO_MENU)
	if _main_menu.visible:
		_main_menu.take_focus()
	
	# If we are in-game, we'll need to show the player a different set of
	# buttons in the menu compared to if we are in the main menu.
	_main_menu.ingame_buttons_visible = (menu_state != MenuState.STATE_MAIN_MENU)
	
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


func _on_MainMenu_starting_singleplayer():
	set_menu_state(MenuState.STATE_NO_MENU)


func _on_MainMenu_returning_to_game():
	set_menu_state(MenuState.STATE_NO_MENU)


func _on_MainMenu_exiting_to_main_menu():
	set_menu_state(MenuState.STATE_MAIN_MENU)
