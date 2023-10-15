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


onready var _main_menu := $MainMenu
onready var _main_menu_camera := $MainMenuCamera
onready var _player_controller := $PlayerController


func _ready():
	# Only allow specific components to run while we are in the main menu.
	get_tree().paused = true
	
	# Since we have access to all components of the game here, establish the
	# necessary inter-child dependencies.
	var camera_controller: CameraController = _player_controller.get_camera_controller()
	var player_camera: Camera = camera_controller.get_camera()
	_main_menu_camera.camera_transition_to = player_camera


func _on_MainMenu_starting_singleplayer():
	# Allow all components to run fully now we have started the game.
	get_tree().paused = false
	
	# Hide the main menu, and slowly fade out the jukebox music.
	_main_menu.visible = false
	_main_menu.jukebox.start_fading_out()
	
	# Start transitioning from the main menu camera to the player camera.
	_main_menu_camera.state = MainMenuCamera.CameraState.STATE_ORBIT_TO_PLAYER
