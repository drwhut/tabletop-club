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

extends WindowDialog

## A window which displays directories of assets that the user can choose from.


## Fired when the user has selected an asset.
signal asset_selected(asset_entry)


## The maximum size of the back and front stacks, used when pressing either the
## back or front button.
const DIR_STACK_MAX_SIZE := 50


## The top-level directory that this window uses.
## This is used to specify which types of assets the user can choose from.
export(String) var category := ""

## The default directory path that the window will start at.
## [b]NOTE:[/b] This is appended to [member category] to make the full path.
export(String) var default_path := "/%ALL_PACKS%"


## The directory path that is currently being shown to the user.
var current_path: String setget set_current_path


# The stack used when going back through previously visited directories.
var _back_stack: Array = []

# The stack used to go forward through directories after going back.
var _forward_stack: Array = []


onready var _back_button: Button = $MainContainer/ButtonContainer/BackButton
onready var _forward_button: Button = $MainContainer/ButtonContainer/ForwardButton
onready var _asset_breadcrumb: AssetBreadcrumb = $MainContainer/BreadcrumbScrollContainer/AssetBreadcrumb
onready var _asset_grid: AssetGrid = $MainContainer/AssetScrollContainer/AssetGrid

onready var _settings_button := $MainContainer/ButtonContainer/RightContainer/SettingsButton
onready var _settings_window := $AssetWindowSettings


func _ready():
	# Make sure the settings window displays the correct layout and zoom.
	_settings_window.category = category
	_settings_window.layout = _asset_grid.layout
	_settings_window.zoom = _asset_grid.zoom
	
	# Check to see if the settings for this category were changed in a previous
	# playthrough.
	_settings_window.check_if_saved()
	
	# This should generate the content for the default directory, as the AssetDB
	# should have the default asset pack already added at the start of the game.
	set_current_path("/" + category + default_path)
	
	AssetTree.connect("tree_generated", self, "_on_AssetTree_tree_generated")


func set_current_path(new_value: String) -> void:
	var asset_node := AssetTree.get_asset_node(new_value)
	if asset_node == null:
		push_error("Cannot set path to '%s', node does not exist" % new_value)
		return
	
	current_path = new_value
	
	_asset_breadcrumb.set_dir(current_path)
	_asset_grid.asset_node = asset_node
	_asset_grid.refresh()


# Push a path to the back stack, enabling the back button.
func _push_back_stack(dir_path: String, clear_forward: bool = true) -> void:
	_back_stack.push_back(dir_path)
	_back_button.disabled = false
	
	if clear_forward:
		_forward_stack.clear()
		_forward_button.disabled = true
	
	# If the stack is now too big, pop elements from the bottom of the stack.
	while _back_stack.size() > DIR_STACK_MAX_SIZE:
		_back_stack.pop_front()


# Push a path to the forward stack, enabling the forward button.
func _push_forward_stack(dir_path: String) -> void:
	_forward_stack.push_back(dir_path)
	_forward_button.disabled = false
	
	# If the stack is now too big, pop elements from the bottom of the stack.
	while _forward_stack.size() > DIR_STACK_MAX_SIZE:
		_forward_stack.pop_front()


func _on_AssetTree_tree_generated():
	if AssetTree.get_asset_node(current_path) == null:
		# The node we were displaying no longer exists, so revert back to the
		# default path.
		set_current_path("/" + category + default_path)
	else:
		# The node still exists, but it's contents may have changed.
		_asset_grid.refresh()


func _on_BackButton_pressed():
	# Pop the back stack until we find a valid path - this is because the tree
	# may have changed since the stack was last pushed to.
	while not _back_stack.empty():
		var path: String = _back_stack.pop_back()
		if AssetTree.get_asset_node(path) == null:
			continue
		
		_push_forward_stack(current_path)
		
		set_current_path(path)
		break
	
	if _back_stack.empty():
		_back_button.disabled = true


func _on_ForwardButton_pressed():
	while not _forward_stack.empty():
		var path: String = _forward_stack.pop_back()
		if AssetTree.get_asset_node(path) == null:
			continue
		
		_push_back_stack(current_path, false)
		
		set_current_path(path)
		break
	
	if _forward_stack.empty():
		_forward_button.disabled = true


func _on_SettingsButton_pressed():
	_settings_window.popup_centered()


func _on_AssetBreadcrumb_dir_selected(dir_path: String):
	if dir_path == current_path:
		return
	
	_push_back_stack(current_path)
	set_current_path(dir_path)


func _on_AssetGrid_asset_selected(asset_entry: AssetEntry):
	emit_signal("asset_selected", asset_entry)


func _on_AssetGrid_node_selected(node_id: String):
	var new_path := current_path + "/" + node_id
	var asset_node := AssetTree.get_asset_node(new_path)
	if asset_node == null:
		push_error("Cannot set path to '%s', node does not exist" % new_path)
		return
	
	_push_back_stack(current_path)
	
	current_path = new_path
	_asset_breadcrumb.append_dir(new_path)
	_asset_grid.asset_node = asset_node
	_asset_grid.refresh()
	_asset_grid.take_focus()


func _on_AssetWindow_about_to_show():
	_asset_grid.call_deferred("take_focus")


func _on_AssetWindowSettings_layout_changed(new_layout: int):
	_asset_grid.layout = new_layout


func _on_AssetWindowSettings_zoom_changed(new_zoom: int):
	_asset_grid.zoom = new_zoom


func _on_AssetWindowSettings_popup_hide():
	_settings_button.grab_focus()
