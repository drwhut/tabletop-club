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


## Should the in-game UI be visible to the player?
var game_ui_visible := true setget set_game_ui_visible

## States whether we are in the main menu, the in-game menu, or if there is no
## menu currently visible.
var menu_state: int = MenuState.STATE_MAIN_MENU setget set_menu_state


# Last frame, was the player controller capturing mouse movement?
var _player_controller_using_mouse_last_frame := false

# What was the reason for the last player that left the lobby leaving?
var _reason_last_player_left_lobby := Lobby.REASON_DISCONNECTED


onready var _chat_window := $ChatWindow
onready var _disconnect_host_dialog := $DisconnectHostDialog
onready var _disconnect_master_server_dialog := $DisconnectMasterServerDialog
onready var _game_ui := $GameUI
onready var _import_progress_panel := $ImportProgressPanel
onready var _main_menu := $MainMenu
onready var _main_menu_camera := $MainMenuCamera
onready var _menu_background: ColorRect = $MenuBackground
onready var _player_controller := $PlayerController
onready var _room := $Room


func _ready():
	# Since we have access to all components of the game here, establish the
	# necessary inter-child dependencies.
	_player_controller.set_refs(_room.piece_manager)
	
	var camera_controller: CameraController = _player_controller.get_camera_controller()
	var player_camera: Camera = camera_controller.get_camera()
	_main_menu_camera.camera_transition_to = player_camera
	
	_game_ui.place_object_panel.player_controller = _player_controller
	
	# Initialize the main menu state.
	set_menu_state(MenuState.STATE_MAIN_MENU)
	
	# As this is the root node for the entire game, this should be the last node
	# to receive the ready signal. Therefore, all nodes should now be ready to
	# receive the apply_settings signal from GameConfig.
	GameConfig.apply_all()
	
	# Just in case the controller was used during the splash screen, fire the
	# ControllerDetector's signal so that the UI elements can know for sure what
	# type of input is being used from the start of the game.
	ControllerDetector.send_signal()
	
	# We want to interface with the Lobby rather than the NetworkManager in most
	# cases, but before a client can join the lobby, they first need to check
	# if their game version matches the server's, otherwise there is no point in
	# continuing to add them since they will disconnect anyways.
	NetworkManager.connect("connection_to_peer_established", self,
			"_on_NetworkManager_connection_to_peer_established")
	
	# If we disconnect from the master server while in a multiplayer game, we
	# need to let the player know.
	NetworkManager.connect("lobby_server_disconnected", self,
			"_on_NetworkManager_lobby_server_disconnected")
	
	# If we were a client, and we have just become the host, that means that we
	# disconnected from the original host, and we are now in singleplayer mode.
	Lobby.connect("player_id_changed", self, "_on_Lobby_player_id_changed")
	
	# We only need to know the reason why a player was removed from the lobby.
	Lobby.connect("player_removed", self, "_on_Lobby_player_removed")


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
	
	elif event.is_action_pressed("game_toggle_ui"):
		if menu_state == MenuState.STATE_NO_MENU:
			# Only toggle the in-game UI if we are actually in-game.
			set_game_ui_visible(not game_ui_visible)
	
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


func set_game_ui_visible(value: bool) -> void:
	game_ui_visible = value
	
	_game_ui.ui_visible = value
	_chat_window.visible = value


func set_menu_state(value: int) -> void:
	if value < 0 or value >= MenuState.STATE_MAX:
		push_error("Invalid value '%d' for MenuState" % value)
		return
	
	var old_state := menu_state
	menu_state = value
	
	# While the menu is visible, the player should not be able to control the
	# camera.
	_player_controller.disabled = (menu_state != MenuState.STATE_NO_MENU)
	
	# Show the in-game UI only if a menu isn't being shown.
	# NOTE: This is independent of [member game_ui_visible], which hides a
	# subsection of the in-game UI.
	_game_ui.visible = (menu_state == MenuState.STATE_NO_MENU)
	
	# We also want to hide the chat window if we are hiding the in-game UI, but
	# only when in-game.
	if menu_state == MenuState.STATE_NO_MENU:
		_chat_window.visible = game_ui_visible
	else:
		_chat_window.visible = true
	
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
			
			# We also need to remove all of the players from the lobby, and shut
			# down the multiplayer network if it is still active.
			Lobby.close()
		
		# If any disconnect dialogs are currently being shown, then hide them,
		# since they no longer apply.
		_disconnect_host_dialog.visible = false
		_disconnect_master_server_dialog.visible = false
	else:
		# If the jukebox is playing outside of the main menu, start fading it.
		if _main_menu.jukebox.is_playing_track():
			_main_menu.jukebox.start_fading_out()
		
		# If we just came from the main menu, then start transitioning the
		# camera from orbit to the player's camera.
		if old_state == MenuState.STATE_MAIN_MENU:
			_main_menu_camera.state = MainMenuCamera.CameraState.STATE_ORBIT_TO_PLAYER


## Called by the server to verify that this client is running the same version
## of the game.
## [b]NOTE:[/b] The reason this function is in the main game script, rather than
## in the NetworkManager, is for backwards compatibility. Clients running the
## v0.1.x version of the game will be expecting this RPC within this script.
puppet func verify_game_version(server_version: String) -> void:
	var client_version := ""
	if ProjectSettings.has_setting("application/config/version"):
		client_version = ProjectSettings.get_setting("application/config/version")
	else:
		push_warning("Could not determine client version, verification will probably fail")
	
	print("Game: Verifying client version (%s) matches server version (%s)..." % [
			client_version, server_version])
	
	if client_version == server_version:
		print("Game: Client and server versions match, continuing...")
		print("Game: Requesting to join the lobby...")
		Lobby.rpc_id(1, "request_add_self", GameConfig.multiplayer_name,
				GameConfig.multiplayer_color)
	else:
		print("Game: Client and server versions do not match, aborting...")
		
		# Let the player know why we could not connect.
		_main_menu.multiplayer_setup_panel.show_error(
				tr("Client version (%s) does not match the host's (%s). Make sure that you and the host are running the most up-to-date version of the game.") %
				[ client_version, server_version ])
		
		# Don't need to call Lobby.close(), as no players should have been added
		# to the Lobby at this point.
		NetworkManager.stop()


func _on_ChatWindow_text_entered(text: String):
	var command_parser := CommandParser.new()
	command_parser.parse_command(text)


func _on_ChatWindow_focus_leaving():
	# If the focus is leaving the chat window, we need to pass it back to one of
	# the main menu buttons if it is visible so it doesn't get lost.
	if _main_menu.visible:
		_main_menu.take_focus()


func _on_DisconnectHostDialog_save_and_return_to_main_menu():
	# TODO: Save the game.
	set_menu_state(MenuState.STATE_MAIN_MENU)


func _on_GameUI_show_game_menu():
	set_menu_state(MenuState.STATE_GAME_MENU)


func _on_ImportProgressPanel_visibility_changed():
	# If the game is currently importing assets, then we do not want the player
	# to host or join a room yet, as this will cause problems when trying to
	# sync assets with the other clients.
	_main_menu.multiplayer_main_panel.waiting_for_import = \
			_import_progress_panel.visible


func _on_MainMenu_starting_singleplayer():
	print("Game: Starting singleplayer...")
	
	# In order for RPCs across the game to work, we need to have a network.
	# But since this is singleplayer only, we want to set it up such that we
	# will be the only peer. This call will also add ourselves to the lobby.
	NetworkManager.start_server_solo()
	
	# We do not want to show any elements of the UI related to multiplayer.
	_game_ui.player_list.visible = false
	_game_ui.room_code_view.visible = false
	
	set_menu_state(MenuState.STATE_NO_MENU)


func _on_MainMenu_starting_multiplayer(room_code: String, show_code: bool):
	print("Game: Starting multiplayer (Room: %s, Hidden: %s)..." % [
			room_code, str(not show_code)])
	
	# Show elements of the UI related to multiplayer.
	_game_ui.player_list.visible = true
	_game_ui.room_code_view.visible = (not room_code.empty())
	_game_ui.room_code_view.room_code = room_code
	_game_ui.room_code_view.secret = not show_code
	
	set_menu_state(MenuState.STATE_NO_MENU)


func _on_MainMenu_returning_to_game():
	set_menu_state(MenuState.STATE_NO_MENU)


func _on_MainMenu_exiting_to_main_menu():
	set_menu_state(MenuState.STATE_MAIN_MENU)


func _on_MainMenu_popup_about_to_show():
	_chat_window.disabled = true


func _on_MainMenu_popup_about_to_hide():
	_chat_window.disabled = false


func _on_NetworkManager_connection_to_peer_established(peer_id: int):
	if not get_tree().is_network_server():
		return
	
	# We, the server, have managed to successfuly establish a connection to the
	# given peer. However, before we add them to the lobby, we first need to
	# check if their client's version is the same as ours, otherwise things will
	# probably go wrong in the future.
	
	if not ProjectSettings.has_setting("application/config/version"):
		push_warning("Cannot determine server version, client will be left hanging")
		return
	
	var server_version: String = ProjectSettings.get_setting(
			"application/config/version")
	
	print("Game: Sending our game version (%s) to peer '%d' for them to check against..." % [
			server_version, peer_id])
	rpc_id(peer_id, "verify_game_version", server_version)


func _on_NetworkManager_lobby_server_disconnected(code: int):
	if menu_state == MenuState.STATE_MAIN_MENU:
		return
	
	if not get_tree().has_network_peer():
		return
	
	# This dialog does not have priority over the host one.
	if _disconnect_host_dialog.visible:
		return
	
	_disconnect_master_server_dialog.client = not get_tree().is_network_server()
	_disconnect_master_server_dialog.close_code = code
	_disconnect_master_server_dialog.popup_centered()


func _on_Lobby_player_id_changed(player: Player, _old_id: int):
	if menu_state == MenuState.STATE_MAIN_MENU:
		return
	
	if player != Lobby.get_self():
		return
	
	if player.id != 1:
		return
	
	# We got turned into the host, so the original host disconnected.
	
	# The following dialog takes priority over the master server one.
	_disconnect_master_server_dialog.visible = false
	
	_disconnect_host_dialog.room_sealed = (
		_reason_last_player_left_lobby == Lobby.REASON_LOBBY_SEALED
	)
	_disconnect_host_dialog.popup_centered()
	
	# Stop showing UI elements related to multiplayer.
	_game_ui.player_list.visible = false
	_game_ui.room_code_view.visible = false


func _on_Lobby_player_removed(_player: Player, reason: int):
	_reason_last_player_left_lobby = reason
