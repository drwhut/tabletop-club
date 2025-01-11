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

## The main script for the in-game UI.


## Fired when the player wants to open the game menu.
signal show_game_menu()


## Should the in-game UI be visible to the player?
var ui_visible: bool setget set_ui_visible, is_ui_visible


## The list of players as a series of [PlayerButton].
onready var player_list := $HideableUI/MultiplayerUI/PlayerList

## The room code as displayed in the UI.
onready var room_code_view := $HideableUI/MultiplayerUI/RoomCodeView

## The panel that appears when the player is adding an object to the room.
onready var place_object_panel := $PlaceObjectPanel

onready var _hideable_ui := $HideableUI
onready var _top_bar_controller := $HideableUI/TopBarController
onready var _top_bar_desktop := $HideableUI/TopBarDesktop

onready var _objects_window := $Windows/ObjectsWindow


func _ready():
	ControllerDetector.connect("using_controller", self,
			"_on_ControllerDetector_using_controller")
	ControllerDetector.connect("using_keyboard_and_mouse", self,
			"_on_ControllerDetector_using_keyboard_and_mouse")


func is_ui_visible() -> bool:
	return _hideable_ui.visible


func set_ui_visible(value: bool) -> void:
	_hideable_ui.visible = value


func _on_TopBar_open_objects_window():
	_objects_window.popup_centered()


func _on_TopBar_open_game_menu():
	emit_signal("show_game_menu")


func _on_ObjectsWindow_asset_selected(asset_entry: AssetEntry):
	_objects_window.visible = false
	place_object_panel.start(asset_entry)


func _on_PlaceObjectPanel_start_placing():
	# Don't allow the player to interact with other elements of the UI while
	# they are placing an object.
	_top_bar_controller.visible = false
	_top_bar_controller.input_disabled = true
	_top_bar_desktop.visible = false


func _on_PlaceObjectPanel_stop_placing():
	if ControllerDetector.is_using_controller():
		_on_ControllerDetector_using_controller()
	else:
		_on_ControllerDetector_using_keyboard_and_mouse()


func _on_ControllerDetector_using_controller():
	if place_object_panel.visible:
		return
	
	_top_bar_controller.visible = true
	_top_bar_controller.input_disabled = false
	_top_bar_desktop.visible = false


func _on_ControllerDetector_using_keyboard_and_mouse():
	if place_object_panel.visible:
		return
	
	_top_bar_controller.visible = false
	_top_bar_controller.input_disabled = true
	_top_bar_desktop.visible = true
