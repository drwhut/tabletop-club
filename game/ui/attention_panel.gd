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

class_name AttentionPanel
extends PopupPanel

## A popup that will show and hide other controls to make itself more prominent.


## Show this control when the popup is activated.
export(NodePath) var show_on_popup: NodePath

## Hide this control when the popup is activated.
export(NodePath) var hide_on_popup: NodePath

## Give focus to this control when the popup is hidden.
export(NodePath) var focus_on_hide: NodePath


func _init():
	connect("about_to_show", self, "_on_about_to_show")
	connect("popup_hide", self, "_on_popup_hide")


func _input(event: InputEvent):
	if visible and event.is_action_released("ui_cancel"):
		visible = false
		get_tree().set_input_as_handled()


func _set_control_visible(node_path: NodePath, is_visible: bool) -> void:
	if node_path.is_empty():
		return
	
	var node := get_node(node_path)
	if node == null:
		return
	
	if node is Control:
		node.visible = is_visible


func _on_about_to_show():
	_set_control_visible(show_on_popup, true)
	_set_control_visible(hide_on_popup, false)


func _on_popup_hide():
	_set_control_visible(show_on_popup, false)
	_set_control_visible(hide_on_popup, true)
	
	if focus_on_hide.is_empty():
		return
	
	var node := get_node(focus_on_hide)
	if node == null:
		return
	
	if node is Control:
		node.grab_focus()
